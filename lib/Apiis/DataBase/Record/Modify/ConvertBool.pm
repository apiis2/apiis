##############################################################################
# $Id: ConvertBool.pm,v 1.5 2005/01/24 13:19:25 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Modify::ConvertBool;
$VERSION = '$Revision: 1.5 $';
##############################################################################

=head1 NAME

ConvertBool

=head1 SYNOPSIS

B<ConvertBool> converts YyJjNn to the boolean values 1 or 0.

=head1 DESCRIPTION

B<ConvertBool> is usually used as a MODIFY-rule in the model file.

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub ConvertBool {
   my ( $self, $col_name ) = @_;
   my @data = $self->column( $col_name )->extdata;

   for ( my $i = 0 ; $i <= $#data ; $i++ ) {
      next unless $data[$i];
      if ( $data[$i] =~ /^n/i or $data[$i] =~ /^false$/i ) {
         $data[$i] = 0;
      } elsif ( $data[$i] =~ /^\d+$/ and $data[$i] == 0 ) {
         $data[$i] = 0;
      } elsif ( $data[$i] =~ /^\d+$/ and $data[$i] == 1 ) {
         $data[$i] = 1;
      } elsif ( $data[$i] =~ /^[yj]/i or $data[$i] =~ /^true$/i ) {
         $data[$i] = 1;
      } else {
         $self->status(1);
         my $err_id = $self->errors(
            Apiis::Errors->new(
               type      => 'DATA',
               severity  => 'ERR',
               from      => 'ConvertBool',
               db_column => $col_name,
               msg_short => __("Cannot translate value '[_1]' to boolean datatype", $data[$i] ),
            )
         );
         $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
            if $self->column($col_name)->ext_fields;
      }
   }
   $self->column( $col_name )->extdata( @data );
}

1;
