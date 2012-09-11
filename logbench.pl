#!/usr/bin/env perl

use strict;
use warnings;
use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Plack::Test;
use Plack::Builder;
use Benchmark qw/cmpthese timethese/;

my $app = builder {
    sub{ [ 200, [], [ "Hello "] ] };
};

my $log_app = builder {
    enable 'AccessLog', format => "combined";
    sub{ [ 200, [], [ "Hello "] ] };
};


my $axslog_app = builder {
    enable 'AxsLog', combined => 1, timed => 1;
    sub{ [ 200, [], [ "Hello "] ] };
};

my $axslog_error_only_app = builder {
    enable 'AxsLog', combined => 1, timed => 1, error_only => 1;
    sub{ [ 200, [], [ "Hello "] ] };
};


my $env = req_to_psgi(GET "/");
open(STDERR,'>','/dev/null');

cmpthese(timethese(0,{
    'nolog' => sub {
        $app->($env);
    },
    'log'   => sub {
        $log_app->($env);
    },
    'axslog'   => sub {
        $axslog_app->($env);
    },
    'error_only_axslog'   => sub {
        $axslog_error_only_app->($env);
    }
}));

__END__
Benchmark: running axslog, error_only_axslog, log, nolog for at least 3 CPU seconds...
    axslog:  3 wallclock secs ( 3.09 usr +  0.02 sys =  3.11 CPU) @ 16011.90/s (n=49797)
error_only_axslog:  3 wallclock secs ( 3.08 usr +  0.02 sys =  3.10 CPU) @ 57725.48/s (n=178949)
       log:  3 wallclock secs ( 3.16 usr +  0.01 sys =  3.17 CPU) @ 3338.17/s (n=10582)
     nolog:  2 wallclock secs ( 3.08 usr +  0.00 sys =  3.08 CPU) @ 426523.70/s (n=1313693)
                      Rate         log      axslog error_only_axslog       nolog
log                 3338/s          --        -79%              -94%        -99%
axslog             16012/s        380%          --              -72%        -96%
error_only_axslog  57725/s       1629%        261%                --        -86%
nolog             426524/s      12677%       2564%              639%          --


