package AWSSES::Object::Email;
use strict;
use warnings;
use base qw/MT::Object/;

__PACKAGE__->install_properties({
    column_defs => {
        'id'           => 'integer not null auto_increment',
        'email'        => 'string(255)',
        'status'       => 'integer', 
        'failure'      => 'integer', 
    },
    indexs => {
        emaal        => 1,
        status       => 1,
    },
    audit              => 1,
    datasource         => 'aws_ses_email',
    primary_key        => [qw/ id /],
});

sub class_label {
    my $plugin = MT->component('AWSSES'); 
    return $plugin->translate('AWSSES');
}

1;
__END__
 
