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
    enable 'AxsLog', combined => 1, response_time => 1;
    sub{ [ 200, [], [ "Hello "] ] };
};

my $axslog_format_app = builder {
    enable 'AxsLog', format => '%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-agent}i" %D';
    sub{ [ 200, [], [ "Hello "] ] };
};


my $axslog_error_only_app = builder {
    enable 'AxsLog', combined => 1, response_time => 1, error_only => 1;
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
    'axslog_format'   => sub {
        $axslog_format_app->($env);
    },
    'error_only_axslog'   => sub {
        $axslog_error_only_app->($env);
    }
}));

__END__
Benchmark: running axslog, axslog_format, error_only_axslog, log, nolog for at least 3 CPU seconds...
    axslog:  4 wallclock secs ( 3.17 usr +  0.02 sys =  3.19 CPU) @ 16083.39/s (n=51306)
axslog_format:  3 wallclock secs ( 3.02 usr +  0.02 sys =  3.04 CPU) @ 15986.84/s (n=48600)
error_only_axslog:  4 wallclock secs ( 3.20 usr +  0.03 sys =  3.23 CPU) @ 41389.16/s (n=133687)
       log:  3 wallclock secs ( 3.05 usr +  0.02 sys =  3.07 CPU) @ 3200.65/s (n=9826)
     nolog:  3 wallclock secs ( 3.18 usr +  0.01 sys =  3.19 CPU) @ 438384.64/s (n=1398447)
                      Rate    log axslog_format axslog error_only_axslog   nolog
log                 3201/s     --          -80%   -80%              -92%    -99%
axslog_format      15987/s   399%            --    -1%              -61%    -96%
axslog             16083/s   403%            1%     --              -61%    -96%
error_only_axslog  41389/s  1193%          159%   157%                --    -91%
nolog             438385/s 13597%         2642%  2626%              959%      --


