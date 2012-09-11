use strict;
use warnings;
use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Plack::Builder;
use Plack::Test;
use Test::More;

{
    my $log = '';
    my $app = builder {
        enable 'AxsLog', combined => 1, timed => 1, error_only => 1, logger => sub { $log .= $_[0] };
        sub{ [ 200, [], [ "Hello "] ] };
    };
    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;
            my $res = $cb->(GET "/");
            chomp $log;
            ok !$log;
        };
}

{
    my $log = '';
    my $app = builder {
        enable 'AxsLog', combined => 1, timed => 1, error_only => 1, logger => sub { $log .= $_[0] };
        sub{ [ 404, [], [ "Hello "] ] };
    };
    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;
            my $res = $cb->(GET "/");
            chomp $log;
            ok $log;
        };
}

{
    my $log = '';
    my $app = builder {
        enable 'AxsLog', combined => 1, timed => 1, long_response_time => 500_000, logger => sub { $log .= $_[0] };
        sub{ [ 200, [], [ "Hello "] ] };
    };
    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;
            my $res = $cb->(GET "/");
            chomp $log;
            ok !$log;
        };
}

{
    my $log = '';
    my $app = builder {
        enable 'AxsLog', combined => 1, timed => 1, long_response_time => 500_000, logger => sub { $log .= $_[0] };
        sub{ sleep 1; [ 200, [], [ "Hello "] ] };
    };
    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;
            my $res = $cb->(GET "/");
            chomp $log;
            ok $log;
        };
}


done_testing;

