package App::genpw;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Random::Any 'rand', -warn => 1;
use List::Util qw(shuffle);

our %SPEC;

my $symbols            = [split //, q(~`!@#$%^&*()_-+={}[]|\\:;"'<>,.?/)];                          # %s
my $letters            = ["A".."Z","a".."z"];                                                       # %l
my $digits             = ["0".."9"];                                                                # %d
my $letterdigits       = [@$letters, @$digits];                                                     # %a
my $letterdigitsymbols = [@$letterdigits, @$symbols];                                               # %x
my $base58characters   = [split //, q(ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123456789)]; # %b
my $base56characters   = [split //, q(ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789)];   # %B

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

    %l   Random Latin letter (A-Z, a-z)
    %d   Random digit (0-9)
    %a   Random letter/digit (Alphanum) (A-Z, a-z, 0-9; combination of %l and %d)
    %s   Random ASCII symbol, e.g. "-" (dash), "_" (underscore), etc.
    %x   Random letter/digit/ASCII symbol (combination of %a and %s)
    %b   Base58 character (A-Z, a-z, 0-9 minus IOl0)
    %b   Base56 character (A-Z, a-z, 0-9 minus IOol01)
    %%   A literal percent sign
    %w   Random word

_
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
    } elsif ($matches->{CONV} eq 'b') {
        return join("", map {$base58characters->[rand(@$base58characters)]} 1..$len);
    } elsif ($matches->{CONV} eq 'B') {
        return join("", map {$base56characters->[rand(@$base56characters)]} 1..$len);
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

sub _set_case {
    my ($str, $case) = @_;
    if ($case eq 'upper') {
        return uc($str);
    } elsif ($case eq 'lower') {
        return lc($str);
    } elsif ($case eq 'title') {
        return ucfirst(lc($str));
    } elsif ($case eq 'random') {
        return join("", map { rand() < 0.5 ? uc($_) : lc($_) } split(//, $str));
    } else {
        return $str;
    }
}

sub _fill_pattern {
    my ($pattern, $words) = @_;

    $pattern =~ s/(?<all>%(?:(?<N>\d+)(?:\$(?<M>\d+))?)?(?<CONV>[adlswx%]))/
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
            pos => 0,
        },
        %arg_patterns,
        min_len => {
            summary => 'If no pattern is supplied, will generate random '.
                'alphanum characters with this minimum length',
            schema => 'posint*',
        },
        max_len => {
            summary => 'If no pattern is supplied, will generate random '.
                'alphanum characters with this maximum length',
            schema => 'posint*',
        },
        len => {
            summary => 'If no pattern is supplied, will generate random '.
                'alphanum characters with this exact length',
            schema => 'posint*',
            cmdline_aliases => {l=>{}},
        },
        case => {
            summary => 'Force casing',
            schema => ['str*', in=>['default','random','lower','upper','title']],
            default => 'default',
            description => <<'_',

`default` means to not change case. `random` changes casing some letters
randomly to lower-/uppercase. `lower` forces lower case. `upper` forces
UPPER CASE. `title` forces Title case.

_
        },
    },
    examples => [
    ],
};
sub genpw {
    my %args = @_;

    my $num = $args{num} // 1;
    my $min_len = $args{min_len} // $args{len} // 8;
    my $max_len = $args{max_len} // $args{len} // 20;
    my $patterns = $args{patterns} // ["%$min_len\$${max_len}a"];
    my $case = $args{case} // 'default';

    my @passwords;
    for my $i (1..$num) {
            my $password =
                _fill_pattern($patterns->[rand @$patterns], $args{_words});
            $password = _set_case($password, $case);
        push @passwords, $password;
    }

    [200, "OK", \@passwords];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See the included script L<genpw>.


=head1 SEE ALSO

A few other utilities based on genpw: L<genpw-id> (from L<App::genpw::id>) and
L<genpw-wordlist> (from L<App::genpw::wordlist>).
