package AWSSES::CMS::CRUD;
use strict;
use warnings;
use base qw(Class::Data::Inheritable);
use FormValidator::Lite;
use HTML::FillInForm::Lite;
use UNIVERSAL::require;
use Data::Page;
use Readonly;
use Class::Accessor::Lite (
    new => 0,
    rw  => [ qw(app tmpl_name) ],
);

__PACKAGE__->mk_classdata('model'); 
__PACKAGE__->mk_classdata('class');
__PACKAGE__->mk_classdata('tmpl_dir');
__PACKAGE__->mk_classdata('rows' => 25);
__PACKAGE__->mk_classdata('constraints');
__PACKAGE__->mk_classdata('method' => qr/^(?:list|edit|confirm|save|delete)$/); 

Readonly our $PAGER => [qw/
    total_entries
    entries_per_page
    entries_on_this_page
    current_page
    first_page
    last_page
    first
    last
    previous_page
    next_page
/];

sub new {
    my ($class, $app) = @_;
    my $self = bless {
        app => $app,
    }, $class;

    return $self;
}

sub dispatch {
    my $self = shift;
    my $action = $self->app->param('__action') || 'list';

    my $method = $self->method;

    return $self->app->trans_error('Unknown action [_1]', $action)
        unless $action =~ m/$method/;

    $self->tmpl_name($action);

    if($self->is_post_request){
        $action = sprintf'post_%s', $action;
    }
    #セッション切れ等の理由で強制的にpostされるため
    $action = 'list' unless $self->can($action);

    unless ($self->permission){
        return $self->app->trans_error('Permission denied.');
    }

    # フィルイン
    my $html = $self->$action;
    my $fif = HTML::FillInForm::Lite->new;
    return $fif->fill(\$html,$self->app->{query});
}

sub permission {
    die 'abstract method';
}

sub is_post_request {
    shift->app->request_method eq 'POST' ? 1 : 0;
}

sub list {
    my $self = shift;

    $self->app->session->set($self->_cache_key('edit_data'), '');

    my $count = $self->app->model($self->model)->count($self->set_terms);
    my $page = $self->app->param('page') || 1;
    my $pager = Data::Page->new($count, $self->rows, $page); 

    my @records = $self->app->model($self->model)->load($self->set_terms,{
        offset => $pager->skipped,
        limit  => $pager->entries_per_page,
    });

    my @loop;
    for my $record (@records) {
        push @loop, $self->normalize_hash($record->to_hash);
    }

    #pager用のsetvar作成
    my %pager = map { 'pager_' . $_ => $pager->$_ } @$PAGER;

    return $self->tmpl_build({
        records => \@loop,
        columns => $self->columns,
        %pager,
    });
}

sub columns {
    my $self = shift;
    return +{};
}

#to_hashされたものがあれなので整形する
sub normalize_hash {
    my ($self, $to_hash) = @_;

    my $fdat;
    for my $key (keys %$to_hash) {
        my $model = $self->model;
        my $new_key = $key;
        #DBカラムの接頭辞を消す
        $new_key =~ s/$model\.//;
        $fdat->{$new_key} = $to_hash->{$key};
    }
    return $fdat;
}

sub set_terms {
	my $self = shift;
	return +{};
}

sub edit {
    my $self = shift;

    my $record;
    my $id;

    if ($id = $self->app->param('id') ) {
        $record = $self->app->model($self->model)->load($id) or
            return $self->app->trans_error('Invalid request.');
    }

    my $fdat = $self->app->session($self->_cache_key('edit_data')); 
    
    if ( !$fdat && $record ) { 
        my $hash = $self->normalize_hash($record->to_hash);
        $fdat = $self->format_fdat($hash);
    }

    return $self->tmpl_build({
        id      => $id,
        data    => $fdat,
        columns => $self->columns,
    });
}

sub format_fdat {
    my ($self, $fdat) = @_;
    return $fdat;
}

sub post_edit {
    my $self = shift;
    $self->app->validate_magic() or return;

    my $validator = $self->create_validator;
    $self->validate($validator);

    if ($validator->has_error()){

        # FCGI時の問題解消
        no warnings qw/redefine/;
        no strict qw/refs/;        
        local *{'FormValidator::Lite::get_error_message'} = \&_get_error_message;
        my $errors = $validator->get_error_messages;

        return $self->tmpl_build({
            errors  => $errors,
            columns => $self->columns,
            id      => $self->app->param('id') || undef,
            data    => +{
                $self->app->param_hash,
            },
        });
    }

    my $data;

    my %param = $self->app->param_hash;

    my $properties = $self->app->model($self->model)->properties;

    # 必要なカラムのみセーブ対象とする
    for my $key (keys %param) {
        if ( exists $properties->{column_names}->{$key} ) {
            $data->{$key} = $param{$key} if defined $param{$key};
        }
    }

    $self->app->trans_error('Invalid request.') unless keys %$data;

    $self->app->session($self->_cache_key('edit_data'), $data);

    return $self->app->redirect(
        $self->app->uri(
            mode => $self->app->mode,
            args => {
                __action    => 'confirm',
                magic_token => $self->app->current_magic,
            },
        ),
    );
}

sub validate {
    my ($self, $validator) = @_;
    return $validator;
}

sub confirm {
    my $self = shift;

    $self->app->validate_magic() or return;

    my $data = $self->app->session($self->_cache_key('edit_data')) or
        return $self->app->trans_error('Invalid request.');

    return $self->tmpl_build({
        data    => $data,
        columns => $self->columns,
    });
}

sub post_confirm {
    my $self = shift;

    $self->app->validate_magic() or return;

    my $data = $self->app->session($self->_cache_key('edit_data')) or
        return $self->app->trans_error('Invalid request.');

    $data = $self->confirm_data_format($data);
    my $record;
    if(my $id = delete $data->{id}){
        $record = $self->app->model($self->model)->load($id) or
            return $self->app->trans_error('Invalid request.');
    }
    else {
        $record = $self->app->model($self->model)->new;
    }

    $record->set_values($data);
    $record->save;
    $self->app->session->set($self->_cache_key('edit_data'), '');

    $self->on_confirm($record);

    return $self->app->redirect(
        $self->app->uri(
            mode => $self->app->mode,
            args => {
                __action => 'list',
                magic_token => $self->app->current_magic,
            },
        ),
    );
}

sub on_confirm {
    my ($self, $record) = @_;
}

sub confirm_data_format {
    my ($self, $data) = @_;
    return $data;
}

sub delete {
    my $self = shift;
    my $id = $self->app->param('id');

    $self->app->session->set($self->_cache_key('delete_id'), '');

    my $record = $self->app->model($self->model)->load($id) or
        return $self->app->trans_error('Invalid request.');

    $self->app->session($self->_cache_key('delete_id') => $id);

    my $fdat = $self->normalize_hash($record->to_hash); 

    return $self->tmpl_build({
        data    => $fdat,
        columns => $self->columns,
    });
}

sub post_delete {
    my $self = shift;

    $self->app->validate_magic() or return;

    my $id = $self->app->session($self->_cache_key('delete_id')) or
        return $self->app->trans_error('Invalid request.');
    
    my $record = $self->app->model($self->model)->load($id) or
        return $self->app->trans_error('Invalid request.');

    $self->app->session->set($self->_cache_key('delete_id'), '');

    $self->on_delete($record);
    $record->remove;

    return $self->app->redirect(
        $self->app->uri(
            mode => $self->app->mode,
            args => {
                __action => 'list',
                magic_token => $self->app->current_magic,
            },
        ),
    );
}

sub on_delete {
    my ($self, $record) = @_;
}

sub plugin {
    my $self = shift;
    $self->app->component($self->class);
}

sub tmpl_build {
    my ($self, $param, $tmpl_name) = @_;

    $tmpl_name ||= sprintf'%s/%s.tmpl', $self->tmpl_dir, $self->tmpl_name;

    my $tmpl = $self->plugin->load_tmpl($tmpl_name)
        or return $self->app->error($self->plugin->translate("Couldn't load template file. : [_1]", $tmpl_name));
    return $self->app->build_page($tmpl, $param);
}

sub _cache_key {
    my ($self, $key) = @_;
    sprintf '%s::%s', $self->app->mode, $key;
}

sub create_validator {
    my $self = shift;

    my $lang = $self->app->current_language || $self->app->config->DefaultLanguage;

    my $q = $self->normalize_query($self->app->{query});

    my $validator = FormValidator::Lite->new($q);
    $validator->load_function_message($lang);
    $validator->load_constraints($self->constraints) if $self->constraints;

    my $l10n = sprintf'%s::L10N::%s', $self->class, $lang;
    $l10n->require;

    {
        no strict qw/refs/;
        $validator->set_param_message( %{$l10n . '::Lexicon'} );
    }
    return $validator;
}

sub normalize_query {
    my ($self, $query) = @_;
    return $query;
}

# from FormValidator::Lite
sub _get_error_message {
    my ($self, $param, $function) = @_;

    $function = lc($function);

    my $msg = $self->{_msg};
    Carp::croak("please load message file first") unless $msg;

    my $err_message  = $msg->{message}->{"${param}.${function}"};

    my $err_param    = $msg->{param}->{$param};
    my $err_function = $msg->{function}->{$function};


    # fcgi時にSCALARリファンレスになってしまう問題の解消
    my $gen_msg = sub {
        my ($tmpl, @args) = @_;
        local $_ = $tmpl;
        $_ =~ s{\[_(\d+)\]}{
            my $str = $args[$1-1];
            ref $str eq 'SCALAR' ? $$str : $str;
        }xge;
        $_;
    };
    
    if ($err_message) {
        return $gen_msg->($err_message, $err_param);
    } elsif ($err_function && $err_param) {
        return $gen_msg->($err_function, $err_param);
    } else {
        Carp::carp  "${param}.${function} is not defined in message file.";
        if ($msg->{default_tmpl}) {
            return $gen_msg->($err_function || $msg->{default_tmpl}, $err_function || $param);
        } else {
            return '';
        }
    }
}

1;
__END__
