package AWSSES::Callbacks;
use strict;
use warnings;
use AWSSES::Constants;
use MT::TheSchwartz;
use TheSchwartz::Job;

sub scheduled_post_published {
    my ( $cb, $mt, $obj ) = @_;

    my $email_iter = MT->model('aws_ses_email')->load_iter({
        status  => $ON,
    }) or return;

    while (my $email = $email_iter->() ) {

        my $job = TheSchwartz::Job->new();
        $job->funcname( 'AWSSES::Worker' );
        $job->arg({
            entry_id => $obj->id,
            email_id => $email->id,
        });
        $job->uniqkey( $obj->id );
        $job->coalesce( $$ . ':' . ( time - ( time % 100 ) ) );
        MT::TheSchwartz->insert($job);
    };    
}

1;
__END__
