##############################################################################
# $Id: DateDiff.pm,v 1.12 2007/03/06 13:43:09 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::DateDiff;
$VERSION = '$Revision: 1.12 $';

##############################################################################

=head1 NAME

DateDiff

=head1 SYNOPSIS

Syntax in model file: 

   DateDiff min_diff max_diff compare_date [reference_column]

Examples:
   CHECK => ['DateDiff 0 365 2001-03-22'],
   CHECK => ['DateDiff 1 100 buy_dt'],
   CHECK => ['DateDiff 1 50  animal=>birth_dt db_animal'],

=head1 DESCRIPTION

DateDiff takes the current value ($data) of the passed column and computes the difference to the
date, given in the third parameter (compare_date). If the difference (in
days) between $data and compare_date is in the range given by min_diff and
max_diff, DateDiff will return 0 for success, otherwise 1. In other words:

   min_diff <= ($data - compare_date) <= max_diff    # success

compare_date can either be a fixed format date like '2001-03-22' (must be
in ISO 8601 format) or a date in a column of this record or a date in the
column of another table.  In the latter case, the format is
'tablename=>columname' and you additionally have to give the referencing
column of both tables. This referencing column connects both tables
(usually a foreign key).

Examples:

   # fixed format:
   DateDiff 1 365 2000-01-15

   # compare to another column in the current record:
   DateDiff 30 50 buy_dt

   # compare to another table.column:
   DateDiff 80 120 animal=>birthdate db_animal

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;
use Date::Calc qw( Delta_Days check_date );

sub DateDiff {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   my $log_prefix = 'DateDiff:';
   my $db_table = $self->tablename;
   # my $old_priority = $apiis->filelog_priority('debug');
   EXIT: {
      last EXIT if $local_status = $self->check_DateDiff( $col_name, @args );
      my ( $min, $max, $compare_date, $ref_col ) = @args;
      # $col_name contains a date, so encode gives us the ISO format:
      $self->encode_column($col_name);
      last EXIT if $local_status = $self->status;
      my $data = $self->column($col_name)->intdata;
      last EXIT if not defined $data or $data eq ''; # skip if NULL

      $apiis->log('debug', "$log_prefix Starting date calculations for date '$data' ($db_table.$col_name)");

      my ( $year2, $month2, $day2 );
      my ( $year1, $month1, $day1 );
      my @all_dates;
      unless ( ( $year2, $month2, $day2 ) = $self->_check_date( $col_name, $data ) ) {
         $local_status = 1;
         last EXIT;
      }

      # test compare date:
      ( $year1, $month1, $day1 ) = $self->_check_date( $col_name, $compare_date ); 
      if ( defined $year1 and defined $month1 and defined $day1 ) {
         # fixed date:
         $apiis->log('debug', "$log_prefix fixed date format (Y: $year1, M: $month1, D: $day1)");
         push @all_dates, [ $year1, $month1, $day1 ];
      } elsif ( grep /^${compare_date}$/, $self->columns ) {
         # compare_date points to a column in this record:
         $self->encode_column($compare_date);
         my $this_date = $self->column($compare_date)->intdata;
         last EXIT unless defined $this_date; # NULL values allowed ???
         unless ( ( $year1, $month1, $day1 ) = $self->_check_date( $col_name, $this_date ) ) {
            $local_status = 1;
            last EXIT;
         }
         push @all_dates, [ $year1, $month1, $day1 ];
         $apiis->log( 'debug',
                      sprintf "$log_prefix comparing to current record (%s.%s) (%s-%s-%s)",
                      $db_table, $compare_date, $year1, $month1, $day1 );
      } elsif ( $compare_date =~ /([^\s]+)\s*=>\s*([^\s]+)/ ) {
         # compare_date is a database value
         my $thistable = $1;
         my $thiscolumn = $2;
         if ( not defined $ref_col ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'PARAM',
                  severity  => 'ERR',
                  from      => 'DateDiff',
                  db_table  => $db_table,
                  db_column => $col_name,
                  msg_short => __( "Error in model file: [_1]", __('reference column') ),
                  msg_long  => __( "You point to [_1] but did not specify a referencing column",
                                 "$thistable=>$thiscolumn" ),
               )
            );
            $local_status = 1;
            last LOOP;
         }

         $apiis->log('debug', "$log_prefix getting date from table $thistable, column $thiscolumn");
         # ToDo: check if $1 and $2 are defined and correct (table.column)
         my $compare_record = Apiis::DataBase::Record->new(
               tablename => $thistable
         );
         if ( not $compare_record ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'UNKNOWN',
                  severity  => 'ERR',
                  from      => 'DateDiff',
                  db_table  => $db_table,
                  db_column => $col_name,
                  msg_short => __( 'Error in model file: [_1]', __('external table') ),
                  msg_long  => __( "Could not create table object for '[_1]'", $thistable ),
               )
            );
            $local_status = 1;
            last LOOP;
         }
         if ( $compare_record->status ) {
            $self->errors( $compare_record->errors );
            $local_status = 1;
            last LOOP;
         }
         if ( not grep /^${ref_col}$/, $compare_record->columns ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'PARAM',
                  severity  => 'ERR',
                  from      => 'DateDiff',
                  db_table  => $db_table,
                  db_column => $col_name,
                  data      => $ref_col,
                  msg_short => __( 'Error in model file: [_1]', __('reference column') ),
                  msg_long  => __( "Reference column '[_1]' does not exist in table '[_2]'", $ref_col, $thistable ),
               )
            );
            $local_status = 1;
            last LOOP;
         }
         $compare_record->column($ref_col)->intdata( $self->column($ref_col)->intdata );
         $compare_record->column($ref_col)->encoded(1);

         my @fetched_records = $compare_record->fetch(
             expect_columns => [$thiscolumn],
             user           => 'system',
         );

         foreach my $this_fetched ( @fetched_records ){
            $this_fetched->decode_column($thiscolumn);
            my $this_compare_date = $this_fetched->column($thiscolumn)->intdata;
            next if not defined $this_compare_date; # NULL values allowed
            $this_compare_date =~ /^([0-9]{4}-[0-9][0-9]?-[0-9][0-9]?)\s*/;
            $this_compare_date = $1;    # discard time if any
            ( $year1, $month1, $day1 ) = split /-/, $this_compare_date;    # ISO 8601 format!
            push @all_dates, [ $year1, $month1, $day1 ];
         }
      } else {
         # invalid compare_date:
         $self->errors(
            Apiis::Errors->new(
               type      => 'DATA',
               severity  => 'ERR',
               from      => 'DateDiff',
               db_table  => $db_table,
               db_column => $col_name,
               data      => $data,
               msg_short => __('data error: [_1]', __('wrong date format')),
               msg_long  => __("Could not resolve compare date '[_1]' to a valid date",
                               $compare_date ),
            )
         );
         $local_status = 1;
         last EXIT;
      }

      # no compare values exist -> return
      last EXIT if $#all_dates == -1;

      my $succeeded = 0;
      LOOP:
      foreach my $this_date (@all_dates) {
         my ( $comp_year, $comp_month, $comp_day ) = @$this_date;
         my $range =
           Delta_Days( $comp_year, $comp_month, $comp_day, $year2, $month2, $day2 );
         $apiis->log('debug', "$log_prefix computed difference: $range, allowed: $min - $max");
         if ( $min <= $range and $range <= $max ) {
            $succeeded = 1;
            last LOOP;    # one date within range is enough
         }
      }
      unless ($succeeded) {
         my $err_ref = Apiis::Errors->new(
               type      => 'DATA',
               severity  => 'ERR',
               from      => 'DateDiff',
               db_table  => $db_table,
               db_column => $col_name,
               data      => $data,
               msg_short => __('data error: [_1]', __('date not in range')),
            );
         $err_ref->msg_long(
              __('compared dates are: [_1]',
                join ( ',', map { join ( ', ', @$_ ) } @all_dates ))
           ) if @all_dates;
         $self->errors( $err_ref );
         $local_status = 1;
         last EXIT;
      }
   }
   # $apiis->filelog_priority($old_priority);
   return $local_status || 0;
}

##############################################################################
=head2 _check_date (internal)

B<_check_date()> checks the date if it is correct

In case of errors it returns undef, otherwise a list of variables in the
order: $year, $month, $day.

=cut

sub _check_date {
   my ( $self, $col_name, $datestring ) = @_;
   my ( $year, $month, $day );
   $datestring =~ s/^\s*//;
   if ( $datestring =~ /^([0-9]{4}-[0-9][0-9]?-[0-9][0-9]?)\s*/ ) {
      $datestring = $1;    # discard time if any
      ( $year, $month, $day ) = split /-/, $datestring;    # ISO 8601 format!
      return ( $year, $month, $day ) if check_date( $year, $month, $day );
   }
   return undef;
}

##############################################################################
=head2 check_DateDiff()

B<check_DateDiff()> checks the correctness of the input parameters:

   * correct number of parameters
   * if the min_diff and max_diff values are not empty
   * if the min_diff and max_diff values are numerical

In case of errors it returns a non-true value.

=cut

sub check_DateDiff {
   my ( $self, $col_name, @args ) = @_;
   my $local_status;
   my $db_table = $self->tablename;
   LOOP: {
      # number of passed parameters:
      if ( scalar @args < 3 or scalar @args > 4 ) {
         $local_status = 1;
         $self->errors(
            Apiis::Errors->new(
               type      => 'CONFIG',
               severity  => 'ERR',
               from      => 'DateDiff',
               db_table  => $db_table,
               db_column => $col_name,
               msg_short => __( 'Incorrect [_1] entry in model file', 'CHECK' ),
               msg_long  => __( '[_1] needs [_2] parameters', 'DateDiff', '3 or 4' ),
            )
         );
         $local_status = 1;
         last LOOP;
      }

      # empty (but defined) min/max values:
      my ( $min, $max, $compare_dt, $ref_col ) = @args;
      if ( $min eq '' or $max eq '' ) {
         $self->errors(
            Apiis::Errors->new(
               type      => 'PARAM',
               severity  => 'ERR',
               from      => 'DateDiff',
               db_table  => $db_table,
               db_column => $col_name,
               msg_short => __('Error in model file: [_1]', __('empty parameter')),
               msg_long  => __('min or max value is empty'),
            )
         );
         $local_status = 1;
         last LOOP;
      }

      # non-numerical min/max-values:
      require Apiis::DataBase::Record::Check::IsANumber;
      if ( Apiis::DataBase::Record::Check::IsANumber->_is_a_number($min)
           or Apiis::DataBase::Record::Check::IsANumber->_is_a_number($max) ) {
         $self->errors(
            Apiis::Errors->new(
               type      => 'PARAM',
               severity  => 'ERR',
               from      => 'DateDiff',
               db_table  => $db_table,
               db_column => $col_name,
               data      => "min: $min, max: $max",
               msg_short => __('Error in model file: [_1]', __('non-numerical parameter') ),
               msg_long  => __('min or max value is not a number'),
            )
         );
         $local_status = 1;
         last LOOP;
      }
      if ( defined $ref_col and not grep /^${ref_col}$/, $self->columns ) {
         $self->errors(
            Apiis::Errors->new(
               type      => 'PARAM',
               severity  => 'ERR',
               from      => 'DateDiff',
               db_table  => $db_table,
               db_column => $col_name,
               data      => $ref_col,
               msg_short => __('Error in model file: [_1]', __('reference column') ),
               msg_long  => __("'[_1]' does not exist in the current table", $ref_col),
            )
         );
         $local_status = 1;
         last LOOP;
      }
   }
   return $local_status || 0;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

