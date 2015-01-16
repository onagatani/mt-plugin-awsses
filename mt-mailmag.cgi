#!/usr/local/perl-5.16.3/bin/perl

use strict;
use warnings;

use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/lib" : '../../lib';
use lib $ENV{MT_HOME} ? "$ENV{MT_HOME}/plugins/AWSSES/lib" : '../../plugins/AWSSES/lib';
use MT::Bootstrap App => 'AWSSES::MailMag::App';

1;
__END__
