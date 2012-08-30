package Plack::Middleware::AxsLog;

use strict;
use warnings;
use parent qw/Plack::Middleware/;
use Plack::Util;
use Time::HiRes qw/gettimeofday/;
use Plack::Util::Accessor qw/filename rotationtime maxage combined sleep_before_remove blackhole/;
use POSIX qw//;
use Time::Local qw//;
use File::RotateLogs;

our $VERSION = '0.01';

## copy from Plack::Middleware::AccessLog
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
    $self->combined(1) if ! defined $self->combined;
    $self->sleep_before_remove(3) if ! defined $self->sleep_before_remove;
    if ( $self->filename ) {
        $self->{rotatelogs} = File::RotateLogs->new(
            logfile => $self->filename . '.%Y%m%d%H%M',
            linkname => $self->filename,
            rotationtime => $self->rotationtime,
            maxage => $self->maxage || 0,
            sleep_before_remove => $self->sleep_before_remove,
        );
    }
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
                . ($self->combined ? q!"! . _string($env->{HTTP_REFERER}) . q!" ! : '')
                . ($self->combined ? q!"! . _string($env->{HTTP_USER_AGENT}) . q!" ! : '')
                . $elapsed
                . "\n";

    if ( $self->blackhole ) {
        return;
    }
    if ( ! $self->filename ) {
        $env->{'psgi.errors'}->print($log_line);
    }
    else {
        $self->{rotatelogs}->print($log_line);
    }
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
    enable 'AxsLog',
        filename => '/var/log/app/access_log',
        rotationtime => 3600,
        maxage => 86400, #1day
        combined => 0;
      $app
  };
  
  $ ls -l /var/log/app
  lrwxr-xr-x   1 ... ...       44 Aug 22 18:00 access_log -> /var/log/app/access_log.201208221800
  -rw-r--r--   1 ... ...  1012973 Aug 22 17:59 access_log.201208221759
  -rw-r--r--   1 ... ...     1378 Aug 22 18:00 access_log.201208221800

=head1 DESCRIPTION

Alternative implementation of Plack::Middleware::AccessLog.
Supports auto logfile rotation and makes symlink to newest logfile.

=head1 LOG FORMAT

AxsLog supports combined and common format. And adds elapsed time in microseconds to last of log line

=over 4

=item combined (NCSA extended/combined log format)

  %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\" %D
  => 127.0.0.1 - - [23/Aug/2012:00:52:15 +0900] "GET / HTTP/1.1" 200 645 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.79 Safari/537.1" 10941

=item common (Common Log Format)

  %h %l %u %t \"%r\" %>s %b %D 
  => 127.0.0.1 - - [23/Aug/2012:00:52:15 +0900] "GET / HTTP/1.0" 200 645 10941

=back

=head1 CONFIGURATION

=over 4

=item combined

log format. if disabled, "common" format used. default: 1 (combined format used)

=item filename

default: none (output to stderr)

=item rotationtime

default: 86400 (1day)

=item maxage

Maximum age of files (based on mtime), in seconds. After the age is surpassed, 
files older than this age will be deleted. Optional. Default is undefined, which means unlimited.
old files are removed at a background unlink worker.

=item sleep_before_remove

Sleep seconds before remove old log files. default: 3
if sleep_before_remove == 0, files are removed within plack processes, does not fork background 
unlink worker.

=back 

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<File::RotateLogs>, L<Plack::Middleware::AccessLog>, http://httpd.apache.org/docs/2.2/en/mod/mod_log_config.html

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
