requires 'Apache::LogFormat::Compiler', '0.12';
requires 'HTTP::Status';
requires 'Plack';

on 'test' => sub {
    requires 'Test::More';
    requires 'HTTP::Request::Common';
    requires 'HTTP::Message::PSGI';
};

