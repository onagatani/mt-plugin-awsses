package AWSSES::MailMag::App;
use strict;
use warnings;
use base qw(MT::App);

sub script {
   'mt-malmag.cgi';
}

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        'regist' => \&regist,
        'delete' => \&delete,
    );
    $app->{default_mode} = 'regist';
}

sub init_request{
    return 1;
}

sub regist {
MT->log('regist');
    my $app = shift;
    $app->{no_print_body} = 1;
    my $plugin = MT->component('AWSSES');
    my $tmpl = $plugin->load_tmpl('mailmag/regist.mtml');

    return $app->error(
        $plugin->translate('template not found')
    ) unless $tmpl;

    my $ctx = $app->prepare_context;
    my $html = $tmpl->build($ctx);
    $app->charset('UTF8');
    return $html;
}

sub delete {
    my $app = shift;
    $app->{no_print_body} = 1;
    my $plugin = MT->component('AWSSES');
    my $tmpl = $plugin->load_tmpl('mailmag/regist.mtml');

    return $app->error(
        $plugin->translate('template not found')
    ) unless $tmpl;

    my $ctx = $app->prepare_context;
    my $html = $tmpl->build($ctx);
    $app->charset('UTF8');
    return $html;
}

1;
__END__
