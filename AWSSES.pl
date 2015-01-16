package MT::Plugin::AWSSES;
use strict;
use warnings;
use base qw( MT::Plugin );
use AWSSES::CMS::CRUD::Email;
use AWSSES::MailMag::App;
use AWSSES::MailMag::Bounce;

our $PLUGIN_NAME = 'AWSSES';
our $VERSION = '0.1';
our $SCHEMA_VERSION = '0.1';

my $DESCRIPTION =<<__HTML__;
Send for AWS-SES
__HTML__

my $plugin = __PACKAGE__->new({
    name           => $PLUGIN_NAME,
    version        => $VERSION,
    key            => $PLUGIN_NAME,
    id             => $PLUGIN_NAME,
    author_name    => 'onagatani',
    author_link    => 'http://onagatani.com/',
    description    => $DESCRIPTION,
    l10n_class     => $PLUGIN_NAME. '::L10N',
    schema_version => $SCHEMA_VERSION,
    system_config_template => \&_system_config,
    settings => MT::PluginSettings->new([
        ['access_key' ,{ Default => undef , Scope => 'system' }],
        ['secret_key' ,{ Default => undef , Scope => 'system' }],
        ['region'     ,{ Default => undef , Scope => 'system' }],
        ['from'       ,{ Default => undef , Scope => 'system' }],
    ]),
});

MT->add_plugin( $plugin );

sub init_registry {
    my $plugin = shift;

    $plugin->registry({
        object_types => {
            aws_ses_email  => 'AWSSES::Object::Email',
        },
        callbacks => {
            scheduled_post_published => '$AWSSES::AWSSES::Callbacks::scheduled_post_published',
        },
        applications => {
            bounce => +{
                'handler'  => 'AWSSES::MailMag::Bounce',
                'script'   => sub { return MT->config->AWSSESBounceScript },
                'cgi_path' => sub { return MT->config->AWSSESBounceCGIPath },
                'methods'  => +{
                    failed => '$AWSSES::AWSSES::MailMag::Bounce::failed',
                },
            },
            mailmag => +{
                'handler'  => 'AWSSES::MailMag::App',
                'script'   => sub { return MT->config->AWSSESMailMagScript },
                'cgi_path' => sub { return MT->config->AWSSESMailMagCGIPath },
                'methods'  => +{
                    regist => '$AWSSES::AWSSES::MailMag::App::regist',
                    delete => '$AWSSES::AWSSES::MailMag::App::delete',                    
                },
            },
            cms => {
                methods => {
                    aws_ses_email => \&_aws_ses_email,
                    save_aws_ses_email => sub { return $_[0]->error( $_[0]->translate( 'Invalid request.' ) ); },
                    delete_aws_ses_email => sub { return $_[0]->error( $_[0]->translate( 'Invalid request.' ) ); },
                },
                menus => +{
                    'tools:aws_ses_email' => +{
                        label             => "aws_ses_email",
                        order             => 10100,
                        mode              => 'aws_ses_email',
                        permission        => 'administer',
                        system_permission => 'administer',
                        view              => 'system',
                    },
                },
            },
        },
        config_settings => {
            AWSSESMailMagScript => {
                default => 'mt-mailmag.cgi',
            },
            AWSSESMailMagCGIPath => {
                default => '/cgi-bin/mt/plugins/AWSSES',
            },
            AWSSESBounceScript => {
                default => 'mt-bounce.cgi',
            },
            AWSSESBounceCGIPath => {
                default => '/cgi-bin/mt/plugins/AWSSES',
            },
        },
        task_workers => {
            aws_ses_email_send => { 
                class => 'AWSSES::Worker',
                label => 'aws_ses_email_send',
            },
        }
    });
}

sub _aws_ses_email {
    my $handler = AWSSES::CMS::CRUD::Email->new(shift);   
    $handler->dispatch;
}

sub _system_config {
    return <<'__HTML__';
<mtapp:setting
    id="access_key"
    label="<__trans phrase="access_key">">
<input type="text" name="access_key" value="<$mt:getvar name="access_key" escape="html"$>" />
<p class="hint"><__trans phrase="access_key"></p>
</mtapp:setting>
<mtapp:setting
    id="secret_key"
    label="<__trans phrase="secret_key">">
<input type="text" name="secret_key" value="<$mt:getvar name="secret_key" escape="html"$>" />
<p class="hint"><__trans phrase="secret_key"></p>
</mtapp:setting>
<mtapp:setting
    id="from"
    label="<__trans phrase="from">">
<input type="text" name="from" value="<$mt:getvar name="from" escape="html"$>" />
<p class="hint"><__trans phrase="from"></p>
</mtapp:setting>
<mtapp:setting
    id="region"
    label="<__trans phrase="region">">
<input type="text" name="region" value="<$mt:getvar name="region" escape="html"$>" />
<p class="hint"><__trans phrase="region"></p>
</mtapp:setting>
__HTML__
}

1;
__END__
