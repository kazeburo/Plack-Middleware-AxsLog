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
    enable 'AccessLog', format => "combined", logger => sub {};
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
    enable 'AxsLog', blackhole => 1;
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
#    'logdispatch'   => sub {
#        $logdispatch_app->($env);
#    },
    'axslog'   => sub {
        $axslog_app->($env);
    }
}));

__END__
Benchmark: running axslog, log, logdispatch, nolog for at least 3 CPU seconds...
    axslog:  3 wallclock secs ( 3.17 usr +  0.00 sys =  3.17 CPU) @ 13352.68/s (n=42328)
       log:  4 wallclock secs ( 3.13 usr +  0.09 sys =  3.22 CPU) @ 3414.91/s (n=10996)
logdispatch:  3 wallclock secs ( 3.12 usr +  0.13 sys =  3.25 CPU) @ 2152.62/s (n=6996)
     nolog:  4 wallclock secs ( 3.13 usr +  0.00 sys =  3.13 CPU) @ 341703.83/s (n=1069533)
                Rate logdispatch         log      axslog       nolog
logdispatch   2153/s          --        -37%        -84%        -99%
log           3415/s         59%          --        -74%        -99%
axslog       13353/s        520%        291%          --        -96%
nolog       341704/s      15774%       9906%       2459%          --
