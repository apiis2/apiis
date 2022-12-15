##############################################################################
# $Id: CondRange.pm,v 1.1 2011-07-05 07:43:58 ulm Exp $
##############################################################################
package Apiis::DataBase::Record::Check::CondRange;
$VERSION = '$Revision: 1.1 $';
##############################################################################

=head1 NAME

CondRange

=head1 SYNOPSIS

=head1 DESCRIPTION

The Rule B<CondRange> is given a range of values in the model file. It then
checks, if the provided data is within this range.

=head2 CondRange()

Syntax: CondRange min max table.field  where min_value max_value  where min_value max_value 

Example: Check="CondRange 10 29 animal.db_breed  5 20 60   1 30 70"

In table animal is searched db_animal. The return value is ext_code from db_breed. 
Has an animal the breed 5 and the value 65 then the data is out of range. Would it be
ext_breed eq 1, then it would be valid. For all other breed the min/max 10/29 are valid. 
Is the data within a range? min_value and max_value are predefined in the
model file.

Note: 
- "CondRange 10 29" is like "Range 10 29" and is valie for all others animal which has no filter
- animal.db_breed= Tabelle.Spalte, table has to contain column db_animal
- CondRange runs only for tables with column "db_animal"
- where: 5 20 60; 5=ext_breed 20=min 60=max
         1 30 70; 1=ext_breed 30=min 70=max 

Returnvalues:
   0 if data is within this range, 1 otherwise
   errors are stored in $record->errors

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub CondRange {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   my $data = $self->column($col_name)->intdata;
   if ( defined $data and $data ne '' ) {
      EXIT: {
         require Apiis::DataBase::Record::Check::IsANumber;
         
         my $min        = shift @args;
         my $max        = shift @args;
         my $table_col  = shift @args;
         my $ext_value='';

         #-- tabelle/spalte trennen 
         my ($table, $column) = ($table_col=~/(.*?)\.(.*)/);

         if ($self->column('db_animal')->intdata()) { 
             #-- litter speichern
            my $animal = Apiis::DataBase::Record->new( tablename => $table );


            $animal->column('db_animal')->intdata($self->column('db_animal')->intdata() );
            $animal->column('db_animal')->encoded(1);

            my @fetch = $animal->fetch( expect_columns => [$column ], );

            if ( $animal->status ) {
                $local_status = 1;
                 $self->errors( $animal->errors);
                 $self->status(1);
            }

            if ( $#fetch == -1 ) {
                $local_status = 1;
                $self->errors(
                   Apiis::Errors->new(
                       type       => 'DATA',
                       severity   => 'CRIT',
                       from       => 'CondRange',
                       msg_short =>  "This animal is not in table animal.",
                    )
                 );
                 
                 last EXIT;
            }

            # Auslesen des Ergebnisses der Datenbankabfrage
            $fetch[0]->decode_record;
            $ext_value = $fetch[0]->column($column)->extdata();
            $ext_value = $ext_value->[0];
         }
         else {
            $local_status = 1;
            my $err_id = $self->errors(
               Apiis::Errors->new(
                  type      => 'DATA',
                  severity  => 'ERR',
                  from      => 'CondRange',
                  db_table  => $self->tablename,
                  db_column => $col_name,
                  action    => $self->action || 'unknown',
                  msg_short => __('Table has no column db_animal'),
                  msg_long  => __('Table has no column db_animal'),
               )
            );
            last EXIT ;
         }


         my %hs_comp;
         #-- order min max to a compared value
         for (my $i=0; $i<=$#args;$i++) {

             #-- 1. Element vom Dreierpack, Vergleichswert 
             $hs_comp{$args[$i]}=[]                          if (($i+3) % 3 == 0) ;
             
             #-- min 
             push( @{$hs_comp{$args[$i-1]}}, $args[$i]) if (($i+2) % 3 == 0) ;

             #-- max
             push( @{$hs_comp{$args[$i-2]}}, $args[$i]) if (($i+1) % 3 == 0) ;
            
         }

         #-- Check of $min/$max for else
         last EXIT if $local_status = $self->check_CondRange( $col_name, $min,$max );
         
         #-- Check of last conditions
         foreach (keys %hs_comp) {
         
             last EXIT if $local_status = $self->check_CondRange( $col_name, $hs_comp{$_}->[0], $hs_comp{$_}->[1] );
         }

         #-- overwrite min max, if a condition exists.  
         if (exists $hs_comp{$ext_value}) {
            $min=$hs_comp{$ext_value}->[0];
            $max=$hs_comp{$ext_value}->[1];
         }

         #-- check, if data is a number 
         if ( Apiis::DataBase::Record::Check::IsANumber->_is_a_number($data) ) {
            $local_status = 1;
            my $err_id = $self->errors(
               Apiis::Errors->new(
                  type      => 'DATA',
                  severity  => 'ERR',
                  from      => 'CondRange',
                  db_table  => $self->tablename,
                  db_column => $col_name,
                  action    => $self->action || 'unknown',
                  record_id => $self->column($apiis->DataBase->rowid)->intdata,
                  data      => $data,
                  msg_short => __('Data error in CHECK rule'),
                  msg_long  => __( "Parameter '[_1]' is not a number", $data ),
               )
            );
            $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
               if $self->column($col_name)->ext_fields;
            last EXIT;
         }

         if ( $data > $max or $data < $min ) {
            $local_status = 1;
            my $err_id = $self->errors(
               Apiis::Errors->new(
                  type      => 'DATA',
                  severity  => 'ERR',
                  from      => 'CondRange',
                  db_table  => $self->tablename,
                  db_column => $col_name,
                  action    => $self->action || 'unknown',
                  record_id => $self->column($apiis->DataBase->rowid)->intdata,
                  data      => $data,
                  msg_short => __('Data error in CHECK rule'),
                  msg_long  => __("Data '[_1]' exceeds CondRange limits '[_2]'",
                     $data, "$min <=> $max" ),
               )
            );
            $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
               if $self->column($col_name)->ext_fields;
         }
      }
   }
   return $local_status || 0;
}

=head2 check_CondRange()

B<check_CondRange()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

Checks are:
   if min_value and max_value are defined
   if min_value and max_value are numbers

=cut

sub check_CondRange {
   my ( $self, $col_name, $min, $max ) = @_;
   my $local_status;

   if ( not defined $min or not defined $max ) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'CondRange',
            db_table  => $self->tablename,
            db_column => $col_name,
            action    => $self->action || 'unknown',
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __('Parameter min or max is not defined'),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }

   if ( Apiis::DataBase::Record::Check::IsANumber->_is_a_number($min)
        or Apiis::DataBase::Record::Check::IsANumber->_is_a_number($max) ) {
      $local_status = 1;
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'CondRange',
            db_table  => $self->tablename,
            db_column => $col_name,
            action    => $self->action || 'unknown',
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
            msg_long  => __("Parameter '[_1],[_2]' is not a number", $min, $max),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status || 0;
}

1;

=head1 BUGS

B<CondRange> is intended to work only for numerical values.

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>
Ulf Müller <um@zwisss.de>

=cut

