requires 'perl', '5.008001';
requires 'Carton';
requires 'Class::Tiny';
requires 'CPAN::Audit';
requires 'CPAN::Changes';
requires 'CPAN::DistnameInfo';
requires 'HTTP::Tinyish';
requires 'JSON::PP';
requires 'Module::CPANfile';
requires 'Module::CPANfile::Writer';
requires 'URI';

on 'test' => sub {
    requires 'Test2::V0', '0.000121';
    requires 'Capture::Tiny';
};

