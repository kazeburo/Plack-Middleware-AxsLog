#!/usr/bin/env perl

use strict;
use warnings;
use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Plack::Test;
use Plack::Builder;
use Log::Dispatch;
use File::Temp qw/tempfile/;
use Benchmark qw/cmpthese timethese/;

my $app = builder {
    enable sub {
        my $app = shift;
        sub {
            my $env =  shift;
            $app->($env);
        }
    };
    sub{ [ 200, [], [ "Hello "] ] };
};

my $log_app = builder {
    enable 'AccessLog', format => "common", logger => sub {};
    sub{ [ 200, [], [ "Hello "] ] };
};

my ($fh,$filename) = tempfile(UNLINK=>1);
my $logger = Log::Dispatch->new(
    outputs => [
        [ 'File', min_level => 'debug', filename => $filename ],
    ],
);
my $logdispatch_app = builder {
    enable 'AccessLog', format => "combined", logger => sub { $logger->log(level => 'info', message => $_[0]) };
    sub{ [ 200, [], [ "Hello "] ] };
};

my $axslog_app = builder {
    enable 'AxsLog', combined => 0, blackhole => 1;
    sub{ [ 200, [], [ "Hello "] ] };
};


my $env = req_to_psgi(GET "/");

cmpthese(timethese(0,{
    'nolog' => sub {
        $app->($env);
    },
    'log'   => sub {
        $log_app->($env);
    },
    'logdispatch'   => sub {
        $logdispatch_app->($env);
    },
    'axslog'   => sub {
        $axslog_app->($env);
    }
}));

__END__
Benchmark: running axslog, log, logdispatch, nolog for at least 3 CPU seconds...
    axslog:  3 wallclock secs ( 3.21 usr +  0.00 sys =  3.21 CPU) @ 15707.17/s (n=50420)
       log:  4 wallclock secs ( 3.18 usr +  0.00 sys =  3.18 CPU) @ 4031.13/s (n=12819)
logdispatch:  4 wallclock secs ( 3.12 usr +  0.08 sys =  3.20 CPU) @ 2186.25/s (n=6996)
     nolog:  4 wallclock secs ( 3.07 usr +  0.00 sys =  3.07 CPU) @ 337825.08/s (n=1037123)
                Rate logdispatch         log      axslog       nolog
logdispatch   2186/s          --        -46%        -86%        -99%
log           4031/s         84%          --        -74%        -99%
axslog       15707/s        618%        290%          --        -95%
nolog       337825/s      15352%       8280%       2051%          --
