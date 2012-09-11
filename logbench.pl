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
Benchmark: running axslog, log, nolog for at least 3 CPU seconds...
    axslog:  3 wallclock secs ( 3.10 usr +  0.00 sys =  3.10 CPU) @ 16550.32/s (n=51306)
       log:  4 wallclock secs ( 3.09 usr +  0.01 sys =  3.10 CPU) @ 3310.00/s (n=10261)
     nolog:  4 wallclock secs ( 3.18 usr +  0.00 sys =  3.18 CPU) @ 426020.75/s (n=1354746)
           Rate    log axslog  nolog
log      3310/s     --   -80%   -99%
axslog  16550/s   400%     --   -96%
nolog  426021/s 12771%  2474%     --


