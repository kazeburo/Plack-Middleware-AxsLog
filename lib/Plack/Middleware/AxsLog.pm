package Plack::Middleware::AxsLog;

use strict;
use warnings;
use parent qw/Plack::Middleware/;
use Plack::Util;
use Time::HiRes qw/gettimeofday/;
use Plack::Util::Accessor qw/response_time combined error_only long_response_time logger/;
use POSIX qw//;
use Time::Local qw//;
use HTTP::Status qw//;

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
    $self->combined(1) if ! defined $self->combined;
    $self->response_time(0) if ! defined $self->response_time;
    $self->error_only(0) if ! defined $self->error_only;
    $self->long_response_time(0) if ! defined $self->long_response_time;
}

sub call {
    my $self = shift;
    my($env) = @_;

    my $t0 = [gettimeofday];

    my $res = $self->app->($env);
    if ( ref($res) && ref($res) eq 'ARRAY' ) {
        my $length = Plack::Util::content_length($res->[2]);
        if ( defined $length ) {
            $self->log_line($t0, $env,$res,$length);
            return $res;
        }        
    }
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

    unless (
         ( $self->{long_response_time} == 0 && !$self->{error_only} )
      || ( $self->{long_response_time} != 0 && $elapsed >= $self->{long_response_time} ) 
      || ( $self->{error_only} && HTTP::Status::is_error($res->[0]) ) 
    ) {
        return;
    }

    my @lt = localtime($t0->[0]);
    my $t = sprintf '%02d/%s/%04d:%02d:%02d:%02d %s', $lt[3], $abbr[$lt[4]], $lt[5]+1900, 
        $lt[2], $lt[1], $lt[0], $tzoffset;
    my $log_line =  _string($env->{REMOTE_ADDR}) . " "
        . '- '
            . _string($env->{REMOTE_USER}) . " "
                . q![!. $t . q!] !
                . _safe(q!"! . $env->{REQUEST_METHOD} . " " . $env->{REQUEST_URI} . " " . $env->{SERVER_PROTOCOL} . q!" !)
                . $res->[0] . " "
                . (defined $length ? "$length" : '-')
                . ($self->{combined} ? q! "! . _string($env->{HTTP_REFERER}) . q!" ! : '')
                . ($self->{combined} ? q!"! . _string($env->{HTTP_USER_AGENT}) . q!"! : '')
                . ($self->{response_time} ? " $elapsed" : '')
                . "\n";

    if ( ! $self->{logger} ) {
        $env->{'psgi.errors'}->print($log_line);
    }
    else {
        $self->{logger}->($log_line);
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

Plack::Middleware::AxsLog - Fixed format but Fast AccessLog Middleware

=head1 SYNOPSIS

  use Plack::Builder;
  use File::RotateLogs;

  my $logger = File::RotateLogs->new();

  builder {
      enable 'AxsLog',
        combined => 1,
        response_time => 1,
        error_only => 1,
        logger => sub { $logger->print(@_) }
      $app
  };

=head1 DESCRIPTION

Alternative implementation of Plack::Middleware::AccessLog.
Only supports combined and common format, but 3x-4x faster than Plack::Middleware::AccessLog 
in micro benchmarking.
AxsLog also supports filter logs by response_time and status code.

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

=item combined: Bool

log format. if disabled, "common" format used. default: 1 (combined format used)

=item response_time: Bool

Adds time to serve the request. default: 0

=item error_only: Bool

Display logs if response status is error (4xx or 5xx). default: 0

=item long_response_time: Int (microseconds)

Display log if time to serve the request is above long_response_time. default: 0 (all request logged)

=item logger: Coderef

Callback to print logs. default:none ( output to psgi.errors )

=back

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<File::RotateLogs>, L<Plack::Middleware::AccessLog>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
