use inc::Module::Install;
name 'Plack-Middleware-AxsLog';
all_from 'lib/Plack/Middleware/AxsLog.pm';

requires 'Plack';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
#auto_include;
WriteAll;
