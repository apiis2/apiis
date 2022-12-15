##############################################################################
# $Id: LastAction.pm,v 1.15 2007/01/09 14:33:54 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::LastAction;
$VERSION = '$Revision: 1.15 $';

use strict;
use warnings;
use Apiis::Init;
use Date::Calc qw( Delta_Days );

##############################################################################

=head2 LastAction

Syntax:

LastAction table=>chain_col LA_chain min_diff max_diff

LastAction is a conditional DateDiff depending on the value of LA_chain,
which is stored in table=>chain_col. The dates to compare are
table=>chain_col_dt (_dt extension is hardcoded!) and the passed current
value $data.

If the date difference between chain_col_dt and $data for this LastAction
in table=>chain_col is B<not> within the defined range, the (error)status
$self->status is set to 1 and an appropriate error object is created. If
this rule is not violated, the (error)status is 0.

Example for an entry in the model file:

   CHECK => ['LastAction animal=>la_rep
                  SERVICE 18 62
                  FARROW  40 80'],

B<Note!> As LastAction is a very specific check rule there are some details
hardcoded. The connecting column between tables (foreign key) is db_animal
in both tables. The column, that contains the date for the last action is
assumed to have the last-action-column name with '_dt' appended.

If LastAction turns out to be a useful check rule for other purposes where
the hardcoding is an obstacle, it can be rewritten in a generic manner,
likely with the drawback of some changes in parameter passing.

=cut

sub LastAction {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;
    my $log_prefix = 'LastAction:';

    EXIT: {
        if ( $local_status = $self->check_LastAction( $col_name, @args ) ) {
            last EXIT;
        }
        last EXIT if $self->status;

        # this rule makes no sense for historic data:
        return 0 if $apiis->running_check_integrity;

        # extract some variables:
        my ($data) = $self->column($col_name)->extdata;
        return 0 if !$data;
        $self->encode_column( { column => 'db_animal' } );
        my $db_animal = $self->column('db_animal')->intdata;
        my $table_col = shift @args;    # table=>column to compare

        # get min/max for each last action type:
        my %rule_hash;
        while (@args) {
            my $la_type = shift @args;
            my $min      = shift @args;
            my $max      = shift @args;
            $rule_hash{$la_type}{MIN} = $min;
            $rule_hash{$la_type}{MAX} = $max;
        }

        my ( $thistable, $thiscolumn ) = split /=>/, $table_col;
        my $compare_record =
            Apiis::DataBase::Record->new( tablename => $thistable );
        if ( not $compare_record ) {
            $local_status = 1;
            my $err_id = $self->errors(
                Apiis::Errors->new(
                    type      => 'UNKNOWN',
                    severity  => 'ERR',
                    from      => 'LastAction',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    msg_short => __(
                        "Could not create table object for '[_1]'", $thistable
                    ),
                )
            );
            last EXIT;
        }
        if ( $compare_record->status ) {
            $local_status = 1;
            $self->errors( scalar $compare_record->errors );
            last EXIT;
        }

        # joining column is hardcoded 'db_animal'!:
        $compare_record->column('db_animal')->intdata($db_animal);
        $compare_record->column('db_animal')->encoded(1);
        my @query_records = $compare_record->fetch(
            expect_rows    => 'one',
            expect_columns => [ $thiscolumn, $thiscolumn . '_dt' ],
            user           => 'system',
        );
        if ( $compare_record->status ) {
            $local_status = 1;
            $self->errors( scalar $compare_record->errors );
            last EXIT;
        }

        LOOP: {
            foreach my $thisrecord (@query_records) {
                # should only be one record.
                $thisrecord->decode_column( { column => $thiscolumn } );
                my ($this_la) = $thisrecord->column($thiscolumn)->extdata;
                my $this_la_dt =
                    $thisrecord->column( $thiscolumn . '_dt' )->intdata;
                last LOOP if !defined $this_la;
                last LOOP if $this_la eq '';
                last LOOP if !$this_la_dt;
                last LOOP if !exists $rule_hash{$this_la};

                my $thismin = $rule_hash{$this_la}{MIN};
                my $thismax = $rule_hash{$this_la}{MAX};
                my ( $year1, $month1, $day1 ) =
                    $apiis->iso2extdate($this_la_dt);
                my ( $year2, $month2, $day2 ) = $apiis->extdate2iso($data);
                if ( $apiis->status ) {
                    # date conversion errors:
                    $local_status = 1;
                    $self->errors( scalar $apiis->errors );
                    last EXIT;
                }
                # use Date::Calc directly as DateDiff has too much overhead:
                my $range = Delta_Days( $year1, $month1, $day1,
                                        $year2, $month2, $day2 );
                $apiis->log(
                    'debug', sprintf
                        "%s computed difference: %s, allowed: %s",
                    $log_prefix, $range, $thismin - $thismax
                );

                # success: one date within range is enough;
                last LOOP if ( $thismin <= $range and $range <= $thismax );

                # here we have data but it is not in the range:
                $local_status = 1;
                my $err_id = $self->errors(
                    Apiis::Errors->new(
                        type      => 'DATA',
                        severity  => 'ERR',
                        db_column => $col_name,
                        db_table  => $self->tablename,
                        from      => 'LastAction',
                        msg_short => __('Rule violated'),
                        msg_long  => __(
                            "Date ([_1] to [_2] = [_3]) not in range ($this_la: min [_4], max [_5])",
                            $this_la_dt, "$year2-$month2-$day2", $range,
                            $thismin, $thismax
                        ),
                    )
                );
            }
        }    # LOOP label end
    }    # EXIT label end

    if ($local_status) {
        if ( my @ext_fields = $self->column($col_name)->ext_fields ) {
            $_->ext_fields( \@ext_fields ) for $self->errors;
        }
    }

    $apiis->log( 'debug', "$log_prefix done" );
    return $local_status || 0;
}

=head2 skip_LastAction()

B<skip_LastAction()> returns the actions, when checking of this rule should be
skipped. For LastAction, checks during an update operation are useless.

Input: none
Output: arrayref


=cut

sub skip_LastAction { return [qw/ update check_integrity /]; }

=head2 check_LastAction()

B<check_LastAction()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

=cut

sub check_LastAction {
    my ( $self, $col_name, @args ) = @_;
    my $table_col = shift @args;    # table=>column to compare
    my $local_status;
    EXIT: {
        if ( scalar @args % 3 ) {
            $local_status = 1;
            my $err_id = $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'LastAction',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    msg_short => __('Syntax error in parameter'),
                    msg_long  => __(
                        "Wrong number of parameters in CHECK rule [_1]",
                        'LastAction'
                    ),
                )
            );
            last EXIT;
        }
        unless ( $table_col =~ /=>/ ) {
            $local_status = 1;
            my $err_id = $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'LastAction',
                    db_table  => $self->tablename,
                    db_column => $col_name,
                    data      => $table_col,
                    msg_short => __('Syntax error in parameter'),
                    msg_long  => __(
                        "Parameter '[_1]' must contain '[_2]'", $table_col, '=>'
                    ),
                )
            );
            last EXIT;
        }
        # rest of args must be in the form 'LA_ACTION min max', maybe
        # multiple times:
        while (@args) {
            my $thisrule = shift @args;
            my $min      = shift @args;
            my $max      = shift @args;

            # check the parameters:
            if ( defined $thisrule and ( !defined $min or !defined $max ) ) {
                $local_status = 1;
                my $err_id = Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'LastAction',
                    data      => $thisrule,
                    msg_short => __('Parameter missing'),
                    msg_long  => __('LA defined but not min or max'),
                );
                last EXIT;
            }

            require Apiis::DataBase::Record::Check::IsANumber;
            if ( Apiis::DataBase::Record::Check::IsANumber->_is_a_number($min) )
            {
                $local_status = 1;
                my $err_id = $self->errors(
                    Apiis::Errors->new(
                        type      => 'PARAM',
                        severity  => 'ERR',
                        from      => 'LastAction',
                        db_table  => $self->tablename,
                        db_column => $col_name,
                        data      => $min,
                        msg_short =>
                            __( "Parameter '[_1]' is not a number", $min ),
                    )
                );
                last EXIT;
            }
            if ( Apiis::DataBase::Record::Check::IsANumber->_is_a_number($max) )
            {
                $local_status = 1;
                my $err_id = $self->errors(
                    Apiis::Errors->new(
                        type      => 'PARAM',
                        severity  => 'ERR',
                        from      => 'LastAction',
                        db_table  => $self->tablename,
                        db_column => $col_name,
                        data      => $max,
                        msg_short =>
                            __( "Parameter '[_1]' is not a number", $min ),
                    )
                );
                last EXIT;
            }
        }
    }    # EXIT label
    return $local_status;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

__END__

