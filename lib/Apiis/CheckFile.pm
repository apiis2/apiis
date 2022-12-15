##############################################################################
# $Id: CheckFile.pm,v 1.19 2006-05-15 06:14:16 heli Exp $
##############################################################################
package Apiis::CheckFile;
$VERSION = '$Revision: 1.19 $';
##############################################################################

=head1 NAME

Apiis::CheckFile -- Find configuration files

=head1 SYNOPSIS

   my $a = CheckFile->new( file=>'apiis.model' ); 

CheckFile gets a file name as argument and looks where it finds this file
under $apiis_local.

=head1 DESCRIPTION

CheckFile gets a file name as argument and looks where to find this file
under $apiis_local.
The file name argument can either be

=over 4

a complete path (e.g.  $apiis_local/model/apiis.model)
or only the file (e.g. apiis.model)
or only the basename of the file (e.g. apiis)

=back

Examples:

   my $a = CheckFile->new(file=>'apiis.model'); 
   my $a = CheckFile->new(file=>'apiis'); 
   my $a = CheckFile->new(file=>"$apiis_local/model/forms/abc");
   my $a = CheckFile->new(file=>"../../apiis/reports/jjj");

The recognized filename extensions are defined in $self->{_suffixes},
the locations for doing the search in $self->{_locations}.

=cut

##############################################################################

use strict;
use warnings;
use Carp;
use Apiis::Init;
use File::Basename;

@Apiis::CheckFile::ISA = qw( Apiis::Init );
our $apiis;

##############################################################################
sub _init {
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++; # Conway p. 243

   $self->{"_base"} = undef;
   $self->{"_path"} = undef;
   $self->{"_ext"}  = undef;
   $self->{"_full"} = undef;
   $self->{"_found"} = undef; # debug

   if ( exists $args{file} ) {
      $self->_disassemble_filename( file => $args{file} );
      $self->FindFile( $args{file} );
   } else {
      # programming error, should not happen:
      croak "No key 'file' passed to Apiis::CheckFile.";
   }
}
##############################################################################
sub _disassemble_filename {
   my ( $self, %args ) = @_;
   my $thisfile;
   if ( exists $args{file} ) {
      $thisfile = $args{file};
   } else {
      # programming error, should not happen:
      # TODO: Error object
      croak "No key 'file' passed to Apiis::CheckFile.";
   }

   fileparse_set_fstype($^O);    # set filename conventions for operating system
   my @_suffixes = qw (
       \.model
       \.pfrm \.frm  \.form
       \.frpt \.srpt \.rpt  \.report
       \.log  \.xml  \.dtd
   );
   my ($_base,$_path,$_ext) = fileparse( $thisfile, @_suffixes );
   $_path =~ s|/$|| if defined $_path;
   return ( $_base,$_path,$_ext );
}

sub FindFile {
   my ( $self, $thisfile ) = @_;
   my $debug = 0;

   # fileparse_set_fstype( $^O ); # set filename conventions for operating system

   my @_suffixes  = qw ( \.model \.pfrm \.frm \.form \.frpt \.srpt \.rpt \.report );
   my @_locations = (
      '.',
      $apiis->APIIS_LOCAL . '/etc',
      $apiis->APIIS_LOCAL . '/etc/forms',
      $apiis->APIIS_LOCAL . '/etc/reports',
   );
   my ($_base,$_path,$_ext) = $self->_disassemble_filename( file => $thisfile );

   $self->status(1);
   FIND: {
      -f $thisfile && do {    # passed arg qualifies file correctly
         $self->{"_full"}   = $_path . '/' . $_base . $_ext;
         $self->{"_path"}   = $_path;
         $self->{"_ext"}    = $_ext;
         $self->{"_base"}   = $_base;
         $self->status(0);
         $self->{"_found"}  = 1 if $debug;
         last FIND;
      };

      # add passed path to _locations and check for all paths:
      unshift @_locations, $_path if $_path;
      foreach my $_thispath (@_locations) {
         -f $_thispath . '/' . $_base . $_ext && do {
            $self->{"_full"}   = $_thispath . '/' . $_base . $_ext;
            $self->{"_path"}   = $_thispath;
            $self->{"_ext"}    = $_ext;
            $self->{"_base"}   = $_base;
            $self->status(0);
            $self->{"_found"}  = 2 if $debug;
            last FIND;
         };

         # try other extensions:
         unless ($_ext) {
            foreach my $_thisext (@_suffixes) {
               -f $_thispath . '/' . $_base . $_thisext && do {
                  $self->{"_full"}   = $_thispath . '/' . $_base . $_thisext;
                  $self->{"_path"}   = $_thispath;
                  $self->{"_ext"}    = $_thisext;
                  $self->{"_base"}   = $_base;
                  $self->status(0);
                  $self->{"_found"}  = 3 if $debug;
                  last FIND;
               };
            }
         }
      }
   }; # end FIND
   if ( $self->status ) {
      my $err_ref = Apiis::Errors->new(
         type      => 'PARAM',
         severity  => 'ERR',
         from      => 'CheckFile',
         msg_short => __('Problems opening file [_1]', $thisfile),
      );
      my $_string;
      if ( not defined $_ext or $_ext eq '' ) {
         $_string =
           __( "Did not find '[_1]' in [_2] with extensions [_3]", $thisfile,
            join ( ', ', @_locations ), join ( ', ', @_suffixes ) );
         $err_ref->msg_long($_string);
      }
      $self->errors($err_ref);
   }
}

foreach my $thiskey ( qw/ path base ext full found / ) {
   no strict "refs";
   *$thiskey = sub { return $_[0]->{"_$thiskey"} };
}
##############################################################################

1;
