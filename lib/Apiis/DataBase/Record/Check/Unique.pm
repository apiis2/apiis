##############################################################################
# $Id: Unique.pm,v 1.7 2005/01/24 13:19:25 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::Unique;
$VERSION = '$Revision: 1.7 $';
##############################################################################

=head1 NAME

Unique

=head1 SYNOPSIS


=head1 DESCRIPTION

=head2 Unique()

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;

sub Unique {
   my ( $self, $col_name, @args ) = @_;
   my $err_id = $self->errors(
      Apiis::Errors->new(
         type      => 'CODE',
         severity  => 'WARNING',
         db_column => $col_name,
         db_table  => $self->name,
         from      => 'Apiis::DataBase::Record::Check::Unique',
         msg_short => __( "[_1] not implemented", 'Unique' ),
      )
   );
   $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
      if $self->column($col_name)->ext_fields;
   print "Unique not implemented\n";
}

=head2 check_Unique()

B<check_Unique()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

=cut

sub check_Unique {
   my ( $self, $col_name, @args ) = @_;
   my ( $fk_table, $fk_col, $comp_col, $comp_val ) = @args;
   my $local_status;
   unless ( $fk_table or $fk_col or $comp_col or defined $comp_val ) {
      $local_status = 1;
      $self->status(1);
      my $err_id = $self->errors(
         Apiis::Errors->new(
            type      => 'CONFIG',
            severity  => 'ERR',
            from      => 'Unique',
            db_table  => $self->tablename,
            db_column => $col_name,
            msg_short => __('Incorrect [_1] entry in model file', 'CHECK'),
         )
      );
      $self->error( $err_id )->ext_fields( $self->column($col_name)->ext_fields )
         if $self->column($col_name)->ext_fields;
   }
   return $local_status;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

__END__

=head2 Unique

Syntax:

Unique $table $data_column [$column=$value]

Unique looks in database if the passed data is unique within this combination
of column(s).
$table is the concerning database table.
$data_column is the column of the passed data. It therefore must *not* have
the =value.
To create composite keys you can specify additional columns
with the expected value. Note: char values have to be surrounded by "'".

Example:

Unique( employee name department='sale' salary=3000 $data);

Returnvalues:

=over 4

=item 1

if $data does exist more than once in this Unique combination in the table,

=item 0

otherwise, also accepting NULL values.

=back

=cut

sub Unique {
   my ($arr_ref) = @_;
   my $table  = shift @{$arr_ref};
   my $col    = shift @{$arr_ref};
   my $data   = pop @{$arr_ref};
   my @rest   = @{$arr_ref};     # if any
   my (@all_cols, %all_cols);
   my $status = 0;
   my $err_msg;

   ConnectDB() unless defined $dbh;
   unless ( $table ){
      $status = -1;
      $err_msg = "-Error in model file: No table for Unique in table ".
                 "$table(column $col) given-";
   }
   unless ( $col ){
      $status = -1;
      $err_msg .= "-Error in model file: No column for Unique in table ".
                 "$table(column $col) given-";
   }

   if ( defined $data or $data ne '' ) {
      %all_cols = ( $col => $data );

      if ( scalar @rest ) { # still columns left
         foreach ( @rest ) {
       if ( $_ !~ /=/ ){
               $status = -1;
               $err_msg .= "-Wrong syntax in model file in Unique (table " .
                 "$table, column $col) '=' missing.-";
       }
         }
         %all_cols = map { split /=/ } @rest;
      }

      VALS:
      foreach ( keys %all_cols) {
         unless ( defined $all_cols{$_} ) {
            delete $all_cols{$_}; # delete entries with empty values
            next VALS;
         }
         push @all_cols, $_ . '=' .  $dbh->quote($all_cols{$_});
      }

      my $sql = "SELECT $col FROM $table WHERE " . join(' and ', @all_cols);
      my $sth = ExecuteSQL($sql);
      my $tbl_ary_ref = $sth->fetchall_arrayref;  # fetch all rows for this select
      $sth->finish;
      $status = 1 if scalar @$tbl_ary_ref > 1;
   }
   return [ $status, $err_msg ];                              
}
