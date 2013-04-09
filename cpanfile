requires 'Apache::LogFormat::Compiler', '0.02';
requires 'HTTP::Status';
requires 'Plack';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.36';
    requires 'Test::More';
};
