package AWSSES::Worker;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );
use TheSchwartz::Job;
use AWSSES::Constants;
use Email::Send;
use Email::MIME::CreateHTML;
use File::Slurp;
use MT::Memcached;
use Cache::MemoryCache;

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;

    my $plugin = MT->component('AWSSES');
    my $config = $plugin->get_config_hash('system');

    my @jobs;
    push @jobs, $job;
    if ( my $key = $job->coalesce ) {
        while (
            my $job
            = MT::TheSchwartz->instance->find_job_with_coalescing_value(
                $class, $key
            )
            )
        {
            push @jobs, $job;
        }
    }

    foreach $job (@jobs) {

        my $hash       = $job->arg;
        my $entry_id   = $hash->{entry_id};
        my $email_id   = $hash->{email_id};
        my $body       = $hash->{body};
        my $text       = $hash->{text};

        my $entry = MT->model('entry')->load($entry_id);
        my $email = MT->model('aws_ses_email')->load({
            id => $email_id,
        },{
            limit => 1,
        });

        if ( $entry && $email ) {

            return unless $entry->status == MT::Entry::RELEASE();

            my $path = $entry->blog->site_path . '/' . $entry->archive_file;
            open my $fh, "<:encoding(UTF-8)", $path
                or  die "failed to open file: $!";
            my $content = do { local $/; <$fh> };
            close $fh;

            my $mime = Email::MIME->create_html(
                header => [
                    From => $config->{from},
                    To => $email->email,
                    Subject => $entry->title,
                ],
                inline_css => 1,
                body => $content,
                text_body => $entry->text_more,
                base => $entry->blog->site_url,
            );

            my $mailer = Email::Send->new( {
                mailer => 'SMTP::TLS',
                mailer_args => [
                    Hello=> $entry->blog->site_url,
                    Host => $config->{region},
                    Port => 587,
                    User => $config->{access_key},
                    Password => $config->{secret_key},
                ]
            } );

            eval { $mailer->send($mime) };

            if ( !$@ ) {
                $job->completed();
            }
            else {
                $email->status($OFF);
	            $email->save;
                $job->failed($@ . $email->email);
                MT->log($@);
            }
        }
    }
}

sub grab_for    {60}
sub max_retries {100000}
sub retry_delay {1} #

1;
__END__
