package AWSSES::CMS::CRUD::Email;
use strict;
use warnings;
use base qw(AWSSES::CMS::CRUD);
use AWSSES::Object::Email;
use MT::Util qw/remove_html/;

__PACKAGE__->model('aws_ses_email');
__PACKAGE__->class('AWSSES');
__PACKAGE__->tmpl_dir('email');

sub permission {
    my $self = shift;
    my $user = $self->app->user or return 0;

    return $self->app->return_to_dashboard( error => $self->app->translate('Invalid request') )
        if $self->app->blog;

    my $perm = $user->permissions(0);
    if ($user->is_superuser || ($perm and $perm->can_do('administer')) ) {
        return 1;
    }

}

sub columns {
    my $self = shift;

    return +{
        email   => $self->plugin->translate('email'),
        status  => $self->plugin->translate('status'),
        failure => $self->plugin->translate('failure'),
    };
}

1;
__END__
