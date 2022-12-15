##############################################################################
# $Id: Compare.pm,v 1.12 2008-09-09 11:43:09 duchev Exp $
##############################################################################
package Apiis::DataBase::Record::Check::Compare;
$VERSION = '$Revision: 1.12 $';
##############################################################################

=head1 NAME

Compare

=head1 SYNOPSIS

=head1 DESCRIPTION

The Rule B<Compare> expects  a comparison operator and a column name from the same table.
It then checks, if the provided data is comparable with this operator to the data in the second column.


=head2 Compare()

Syntax: Compare operator column_name|constant:const_value

        Operator can be any one of the following:
        '>','<', '==', '!=', '>=', '<=', 'eq', 'ne', 'lt', 'gt', 'le', 'ge'

Examples: Compare > birth_weight
          Compare <= constant:120
          Compare ne constant:'weaning'

Returnvalues:
   0 if comparison is OK, 1 otherwise
   errors are stored in $record->errors

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;
use Date::Calc qw( Delta_DHMS check_date check_time);

sub Compare {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;
    my $data = $self->column($col_name)->intdata;
    my ( $stat, $data2, $arg1, $arg2, $op, $col_name2 );
    if ( defined $data and $data ne '' ) {
    EXIT1: {
        EXIT: {
            last EXIT1
                if $local_status = $self->check_Compare( $col_name, @args );
            ( $op, $col_name2 ) = @args;
            if ( $col_name2 !~ /^constant:/ ) {
                $data2 = $self->column($col_name2)->intdata;
            }
            else {
                $col_name2 =~ /^constant:(.*)$/;
                $data2 = $1;
            }
            last EXIT1 unless ( defined $data2 );
            my $numeric_op = 0;
            grep {
                if ( $_ eq $op ) { $numeric_op = 1; }
            } ( '>', '<', '==', '!=', '>=', '<=' );
            #in case of comparing dates or timestamps with numeric operator special treatment
            if ((  lc $self->column($col_name)->datatype eq 'date'
                    or lc $self->column($col_name)->datatype eq 'timestamp' )
		
		and (  ($col_name2 =~ /^constant:(.*)$/) 
		       or ( $self->column($col_name)->datatype eq
                    $self->column($col_name2)->datatype)
                )

                and $numeric_op
                )
            {
                my ( $year1, $month1, $day1, $hour1, $min1, $sec1 );
                my ( $year2, $month2, $day2, $hour2, $min2, $sec2 );
                my $dateonly =
                    0;    #for restricting the cheking only of the date part
                $dateonly = 1
                    if ( lc $self->column($col_name)->datatype eq 'date' );
                unless ( ( $year1, $month1, $day1, $hour1, $min1, $sec1 ) =
                    $self->_check_timestamp( $col_name, $data, $dateonly ) )
                {
		    $local_status =1;
                    last EXIT1;
                }
                unless ( ( $year2, $month2, $day2, $hour2, $min2, $sec2 ) =
                    $self->_check_timestamp( $col_name2, $data2, $dateonly ) )
                {
		    $local_status =1;
                    last EXIT1;
                }
                my ( $days, $hours, $minutes, $seconds ) = Delta_DHMS(
                    $year1, $month1, $day1, $hour1, $min1, $sec1,
                    $year2, $month2, $day2, $hour2, $min2, $sec2
                );
                my $diff =
                    $days + $hours + $minutes
                    + $seconds;    #positive if date1 is before $date2
                $arg1 = 0;
                $arg2 = $diff;

            }
            else {
                $arg1 = $data;
                $arg2 = $data2;
            }
        }
        eval { $stat = eval "$arg1 $op $arg2" };
        if ($@) {
            $local_status = 1;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'Compare',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => $data,
                    msg_short => __('Data error in CHECK rule'),
                    msg_long  => __( "System returned error:'[_1]'", $@ ),
                )
            );
            last EXIT1;
        }

        unless ( $stat == 1 ) {
            $local_status = 1;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'Compare',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => $data,
                    msg_short => __('Data error in CHECK rule'),
                    msg_long  => __(
                        "Data '[_1]' is not  '[_2]'",
                        $data,
                        $col_name2 =~ /^constant:/
                        ? "$op $data2"
                        : "$op $data2 $col_name2"
                    ),
                )
            );
	  };
	}
    }
    return $local_status || 0;
}

=head2 check_Compare()

B<check_Compare()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

Checks are:
           Number of parameters should be two
           First parameter should be one of the operators:
           '>','<', '==', '!=', '>=', '<=', 'eq', 'ne', 'lt', 'gt', 'le', 'ge'
           Second parameter should be column name from the same table or constant:value.

=cut

sub check_Compare {
    my ( $self, $col_name, $op, $col_name2 ) = @_;
    my $local_status;

    if ( not defined $op or not defined $col_name2 ) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'Compare',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
                msg_long => __('Parameter op or column_name is not defined'),
            )
        );
    }

    if (    ( $col_name2 !~ /^constant:/ )
        and ( not grep /^${col_name2}$/, $self->columns ) )
    {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'Compare',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
                msg_long =>
                    __( "Parameter '[_1]' is not a column name", $col_name2 ),
            )
        );
    }

    my $ok = 0;
    grep {
        if ( $_ eq $op ) { $ok = 1; }
        } ( '>', '<', '==', '!=', '>=', '<=', 'eq', 'ne', 'lt', 'gt', 'le',
        'ge' );
    unless ($ok) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => 'Compare',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
                msg_long =>
                    __( "Parameter '[_1]' is not an allowed operator", $op ),
            )
        );
    }

    return $local_status || 0;
}

##############################################################################

=head2 _check_timestamp (internal)

B<_check_timestamp()> checks the timestamp if it is correct

In case of errors it returns undef, otherwise a list of variables in the
order: $year, $month, $day, $hour, $minute, $seconds.

=cut

sub _check_timestamp {
    my ( $self, $col_name, $datestring, $dateonly ) = @_;
    my ( $year, $month, $day, $hour, $minute, $seconds, $datepart, $timepart );
    $datestring =~ s/^\s*//;
    if ( $datestring
        =~ /^([0-9]{4}-[0-9][0-9]?-[0-9][0-9]?)\s*([0-2][0-9]?:[0-5][0-9]?:[0-5][0-9]?)?\s*$/
        )
    {
        $datepart = $1;                       # date part
        $timepart = $2 unless ($dateonly);    # time part
        ( $year, $month,  $day )     = split /-/, $datepart;  # ISO 8601 format!
        ( $hour, $minute, $seconds ) = split /:/, $timepart
            unless ($dateonly);                               # ISO 8601 format!
        if ($dateonly) {
            return ( $year, $month, $day, '00', '00', '00' )
                if ( check_date( $year, $month, $day ) );
        }
        else {
            return ( $year, $month, $day, $hour, $minute, $seconds )
                if (check_date( $year, $month, $day )
                and check_time( $hour, $minute, $seconds ) );
        }
    }
    return undef;
}

##############################################################################

1;

=head1 AUTHORS

Zhivko Duchev duchev@tzv.fal.de

=cut

