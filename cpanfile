requires 'perl', '5.008001';
requires 'App::CpanfileSlipstop';
requires 'Carton';
requires 'Class::Tiny';
requires 'CPAN::Audit';
requires 'CPAN::Changes';
requires 'CPAN::DistnameInfo';
requires 'HTTP::Tinyish';
requires 'JSON::PP';
requires 'Module::CPANfile';
requires 'URI';

on 'test' => sub {
    requires 'Test::More';
};

