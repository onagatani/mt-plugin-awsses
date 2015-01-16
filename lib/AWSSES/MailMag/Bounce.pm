package AWSSES::MailMag::Bounce;
use strict;
use warnings;
use base qw(MT::App);
use AWSSES::Constants;
use JSON qw/encode_json decode_json/;

sub script {
   'mt-bounce.cgi';
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->add_methods(
        'failed' => \&failed,
    );
    $app->{default_mode} = 'failed';
    $app->{requires_login} = 0;
    return $app;
}

sub failed {
    my $app = shift;
    my $plugin = MT->component('AWSSES');
    my $config = $plugin->get_config_hash('system');

    if (my $json = $app->param('POSTDATA')) {
        my $data = decode_json(decode_json($json)->{Message}); 
        if ($data->{notificationType} eq 'Bounce' && $data->{mail}->{source} eq $config->{from} ) {
            for my $bounce (@{$data->{bounce}->{bouncedRecipients}}) {
                my $address = $bounce->{emailAddress};
                my @emails = MT->model('aws_ses_email')->load({
                    email => $address
                });
                for my $email (@emails) {
                    $email->status($OFF);
                    $email->save;
                }
            }
        }
    }

    $app->charset('UTF-8');
    $app->{no_print_body} = 1;
    $app->response_content_type("text/html; ". "charset=UTF-8");
    $app->set_header('Expires' => '+1h');
    $app->send_http_header;
    $app->print('OK');
    return $app;
}

1;
__END__
