package AWSSES::Constants;
use strict;
use warnings;
use base qw(Exporter);
use Readonly;
use utf8;

our @EXPORT = qw/
 $ON
 $OFF
/;

Readonly our $ON   => 10;
Readonly our $OFF  => 20;

1;
__END__
