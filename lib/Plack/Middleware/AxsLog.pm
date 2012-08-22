package Plack::Middleware::AxsLog;

use strict;
use warnings;
use parent qw/Plack::Middleware/;
use Plack::Util;
use Time::HiRes qw/gettimeofday/;
use Plack::Util::Accessor qw/filename rotationtime blackhole/;
use SelectSaver;
use POSIX qw//;
use Time::Local qw//;
use Fcntl qw/:DEFAULT/;
use File::Temp qw//;

our $VERSION = '0.01';

my $tzoffset = POSIX::strftime("%z", localtime);
if ( $tzoffset !~ /^[+-]\d{4}$/ ) {
    my @t = localtime(time);
    my $s = Time::Local::timegm(@t) - Time::Local::timelocal(@t);
    $tzoffset = sprintf '%+03d%02u', int($s/3600), $s % 3600;
}
my @abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );

sub prepare_app {
    my $self = shift;
    $self->rotationtime(86400) if ! $self->rotationtime;
    die 'rotationtime couldnot less than 60' if $self->rotationtime < 60;
}

sub call {
    my $self = shift;
    my($env) = @_;

    my $t0 = [gettimeofday];

    my $res = $self->app->($env);
    Plack::Util::response_cb($res, sub {
	my $res = shift;
	my $length = Plack::Util::content_length($res->[2]);
	if ( defined $length ) {
	    $self->log_line($t0, $env,$res,$length);
	    return;
	}
        return sub {
            my $chunk = shift;
            if ( ! defined $chunk ) {
		$self->log_line($t0, $env,$res,$length);
                return;
            }
	    $length += length($chunk);
            return $chunk;
        };	
    });
}

sub log_line {
    my $self = shift;
    my ($t0, $env, $res, $length) = @_;

    my $elapsed = int(Time::HiRes::tv_interval($t0) * 1_000_000);

    my @lt = localtime($t0->[0]);
    my $t = sprintf '%02d/%s/%04d:%02d:%02d:%02d %s', $lt[3], $abbr[$lt[4]], $lt[5]+1900, 
	$lt[2], $lt[1], $lt[0], $tzoffset;
    my $log_line =  _string($env->{REMOTE_ADDR}) . " "
	. '- '
	. _string($env->{REMOTE_USER}) . " "
	. q![!. $t . q!] !
	. q!"! . _safe($env->{REQUEST_METHOD}) . " " . _safe($env->{REQUEST_URI}) . " " . _safe($env->{SERVER_PROTOCOL}) . q!" !
	. $res->[0] . " "
	. (defined $length ? "$length" : '-') . " "
	. q!"! . _string($env->{HTTP_REFERER}) . q!" !
	. q!"! . _string($env->{HTTP_USER_AGENT}) . q!" !
	. $elapsed
	. "\n";

    if ( $self->blackhole ) {
	return;
    }

    if ( ! $self->filename ) {
	$env->{'psgi.errors'}->print($log_line);
    }
    else {
	$self->log_file($log_line);
    }
}

sub _gen_filename {
    my $self = shift;
    my $now = time;
    my $time = $now - ($now % $self->rotationtime);
    my @lt = localtime($time);
    return $self->filename .'.'. (
	( $self->rotationtime < 3600 ) 
            ? sprintf('%04d%02d%02d%02d%02d', $lt[5]+1900,$lt[4]+1,$lt[3],$lt[2],$lt[1]) 
	    : sprintf('%04d%02d%02d%02d', $lt[5]+1900,$lt[4]+1,$lt[3],$lt[2])
    )
}


sub log_file {
    my ($self,$log) = @_;
    my $fname = $self->_gen_filename;
    my $fh;
    if ( $self->{fh} ) {
	if ( $fname eq $self->{fname} && $self->{pid} == $$ ) {
	    $fh = delete $self->{fh};
	}
	else {
	    $fh = delete $self->{fh};
	    close $fh if $fh;
	    undef $fh;
	}
    }

    unless ($fh) {
	my $is_new = ( ! -f $fname || ! -l $self->filename ) ? 1 : 0;
	open $fh, '>>:utf8', $fname or die "Cannot open file($fname): $!";
	if ( $is_new ) {
	    eval {
		my $tmp = File::Temp::mktemp($self->filename .'.XXXXXX');
		symlink $fname, $tmp or die $!;
		rename $tmp, $self->filename or die $!;
	    };
	    warn "couldnot make symlink: $@" if $@;
	}
	my $saver = SelectSaver->new($fh);
	$| = 1;
    }

    $fh->print($log)
	or die "Cannot write to $fname: $!";

    $self->{fh} = $fh;
    $self->{fname} = $fname;
    $self->{pid} = $$;

}


sub _safe {
    my $string = shift;
    $string =~ s/([^[:print:]])/"\\x" . unpack("H*", $1)/eg
        if defined $string;
    $string;
}

sub _string {
    my $string = shift;
    return '-' if ! defined $string;
    return '-' if ! length $string;
    _safe($string);
}

1;
__END__

=head1 NAME

Plack::Middleware::AxsLog - Alternative AccessLog Middleware

=head1 SYNOPSIS

use Plack::Builder;

builder {
  enable AxsLog,
      filename => '/var/log/app/access_log',
      rotationtime => 3600;
  $app
};

$ ls -l /var/log/app
lrwxr-xr-x   1 ... ...       44 Aug 22 18:00 access_log -> /var/log/app/access_log.2012082218
-rw-r--r--   1 ... ...  1012973 Aug 22 17:59 access_log.2012082217
-rw-r--r--   1 ... ...     1378 Aug 22 18:00 access_log.2012082218

=head1 DESCRIPTION

Alternative implementation of Plack::Middleware::AccessLog.
Supports auto logfile rotation and makes symlink to newest logfile.

=head1 CONFIGURATION

=over 4

=item filename

default: none (print to stderr)

=item rotationtime

default: 86400 (1day)

=back 

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
