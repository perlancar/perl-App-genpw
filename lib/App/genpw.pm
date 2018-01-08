package App::genpw;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Random::Any 'rand', -warn => 1;
use List::Util qw(shuffle);

our %SPEC;

my $symbols            = [split //, q(~`!@#$%^&*()_-+={}[]|\\:;"'<>,.?/)];
my $letters            = ["A".."Z","a".."z"];
my $digits             = ["0".."9"];
my $letterdigits       = [@$letters, @$digits];
my $letterdigitsymbols = [@$letterdigits, @$symbols];

my $default_patterns = [
    '%w %w %w',
    '%w %w %w %w',
    '%w %w %w %w %w',
    '%w %w %w %w %w %w',
    '%w%4d%w',
    '%w%6d%s',
];

our %arg_patterns = (
    patterns => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'pattern',
        summary => 'Pattern(s) to use',
        schema => ['array*', of=>'str*', min_len=>1],
        description => <<'_',

A pattern is string that is similar to a printf pattern. %P (where P is certain
letter signifying a format) will be replaced with some other string. %Nw (where
N is a number) will be replaced by a word of length N, %N$MP (where N and M is a
number) will be replaced by a word of length between N and M. Anything else will
be used as-is. Available conversions:

    %w   Random word
    %l   Random Latin letter (A-Z, a-z)
    %d   Random digit (0-9)
    %a   Random letter/digit (Alphanum) (A-Z, a-z, 0-9; combination of %l and %d)
    %s   Random ASCII symbol, e.g. "-" (dash), "_" (underscore), etc.
    %x   Random letter/digit/ASCII symbol (combination of %a and %s)
    %%   A literal percent sign

_
        default => $default_patterns,
        cmdline_aliases => {p=>{}},
    },
);

sub _fill_conversion {
    my ($matches, $words) = @_;

    my $n = $matches->{N};
    my $m = $matches->{M};
    my $len = defined($n) && defined($m) ? $n+int(rand()*($m-$n+1)) :
        defined($n) ? $n : 1;

    if ($matches->{CONV} eq '%') {
        return join("", map {'%'} 1..$len);
    } elsif ($matches->{CONV} eq 'd') {
        return join("", map {$digits->[rand(@$digits)]} 1..$len);
    } elsif ($matches->{CONV} eq 'l') {
        return join("", map {$letters->[rand(@$letters)]} 1..$len);
    } elsif ($matches->{CONV} eq 'a') {
        return join("", map {$letterdigits->[rand(@$letterdigits)]} 1..$len);
    } elsif ($matches->{CONV} eq 's') {
        return join("", map {$symbols->[rand(@$symbols)]} 1..$len);
    } elsif ($matches->{CONV} eq 'x') {
        return join("", map {$letterdigitsymbols->[rand(@$letterdigitsymbols)]} 1..$len);
    } elsif ($matches->{CONV} eq 'w') {
        die "Ran out of words while trying to fill out conversion '$matches->{all}'" unless @$words;
        my $i = 0;
        my $word;
        while ($i < @$words) {
            if (defined $n && defined $m) {
                if (length($words->[$i]) >= $n && length($words->[$i]) <= $m) {
                    $word = splice @$words, $i, 1;
                    last;
                }
            } elsif (defined $n) {
                if (length($words->[$i]) == $n) {
                    $word = splice @$words, $i, 1;
                    last;
                }
            } else {
                $word = splice @$words, $i, 1;
                last;
            }
            $i++;
        }
        die "Couldn't find suitable random words for conversion '$matches->{all}'"
            unless defined $word;
        return $word;
    }
}

sub _fill_pattern {
    my ($pattern, $words) = @_;

    $pattern =~ s/(?<all>%(?:(?<N>\d+)(?:\$(?<M>\d+))?)?(?<CONV>[Wwds%]))/
        _fill_conversion({%+}, $words)/eg;

    $pattern;
}

$SPEC{genpw} = {
    v => 1.1,
    summary => 'Generate random password',
    description => <<'_',

This is yet another utility to generate random password. Features:

* Allow specifying pattern(s), e.g. '%8a%s' means 8 random alphanumeric
  characters followed by a symbol.
* Use strong random source (<pm:Math::Random::Secure>) when available, otherwise
  fallback to Perl's builtin `rand()`.

_
    args => {
        num => {
            schema => ['int*', min=>1],
            default => 1,
            cmdline_aliases => {n=>{}},
        },
        %arg_patterns,
    },
    examples => [
    ],
};
sub genpass {
    my %args = @_;

    my $num = $args{num} // 1;
    my $wordlists = $args{wordlists} // ['EN::Enable'];
    my $patterns = $args{patterns} // $default_patterns;

    my $res = App::wordlist::wordlist(
        (wordlists => $wordlists) x !!defined($wordlists),
    );
    return $res unless $res->[0] == 200;

    my @words = shuffle @{ $res->[2] };

    my @passwords;
    for my $i (1..$num) {
        push @passwords,
            _fill_pattern($patterns->[rand @$patterns], \@words);
    }

    [200, "OK", \@passwords];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See the included script L<genpass-wordlist>.
