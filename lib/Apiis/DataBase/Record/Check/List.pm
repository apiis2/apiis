##############################################################################
# $Id: List.pm,v 1.11 2006/04/19 06:32:43 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Check::List;
$VERSION = '$Revision: 1.11 $';
##############################################################################

=head1 NAME

List

=head1 SYNOPSIS

B<List()> is the poor man's foreign key. The data is checked against a
small list which is provided in the model file.

=head1 DESCRIPTION

The model file can provide a small list where the data is checked against.
Example, column db_sex:

   CHECK => ['List Male Female'],

The external data is allowed to have the values 'Male' or 'Female'. The
number of List entries is not limited:

   CHECK => ['List val1 val2 ... valN'],

To circumvent upper/lower case problems you can combine MODIFY and CHECK
rules:

   MODIFY => ['UpperCase'],
   CHECK  => ['List MALE FEMALE'],

The data is first modified and then checked.

Undefined or NULL data is accepted as it can get controlled with NotNull.

Returnvalues:
   0 if $data is one of the list values (success),
   1 otherwise (error)

=cut

##############################################################################

use strict;
use warnings;
use Apiis::Init;
use List::Util qw(first);

sub List {
    my ( $self, $col_name, @args ) = @_;
    my ( $local_status, @errors );
    EXIT: {
        last EXIT if $local_status = $self->check_List( $col_name, @args );

        if ( $apiis->running_check_integrity ){
            $self->decode_column($col_name);
        }
        my ( $data, @rest ) = $self->column($col_name)->extdata;
        if (@rest) {
            # only take the first element of the array extdata. If we have more
            # than one (e.g. concatenated PK) we have a problem anyway:
            $local_status = 1;
            push @errors, Apiis::Errors->new(
                type      => 'DATA',
                severity  => 'ERR',
                db_column => $col_name,
                db_table  => $self->name,
                from      => 'Check::List',
                msg_short => __('Data error in CHECK rule'),
                msg_long  => __(
                    "Don't know how to handle multiple external data: [_1]",
                    join( q{,}, $data, @rest ) ),
            );
            last EXIT;
        }

        last EXIT if !defined $data;
        last EXIT if $data eq '';
        last EXIT if first { $_ eq $data } @args; # found!

        $local_status = 1;
        push @errors, Apiis::Errors->new(
            type      => 'DATA',
            severity  => 'ERR',
            db_column => $col_name,
            db_table  => $self->name,
            from      => 'Check::List',
            msg_short => __('Data error in CHECK rule'),
            msg_long  => __(
                "Data '[_1]' is not in List values ([_2])",
                $data, join( q{,}, @args ) ),
        );
    } # end label EXIT

    if ($local_status) {
        # add ext_fields to errors:
        if ( my $ext_fields_ref = $self->column($col_name)->ext_fields ) {
            for my $err (@errors) {
                $err->ext_fields($ext_fields_ref);
            }
        }
        $self->errors( \@errors );
    }
    return $local_status || 0;
}

=head2 check_List()

B<check_List()> checks the correctness of the input parameters.

In case of errors it sets $self->status and additionally returns a non-true
returnvalue.

=cut

sub check_List {
    my ( $self, $col_name, @args ) = @_;
    my $local_status;
    unless ( scalar @args ) {
        $local_status = 1;
        $self->errors(
            Apiis::Errors->new(
                type      => 'CONFIG',
                severity  => 'ERR',
                from      => 'List',
                db_table  => $self->tablename,
                db_column => $col_name,
                msg_long  => __('No List values given'),
                msg_short =>
                    __( 'Incorrect [_1] entry in model file', 'CHECK' ),
            )
        );
    }
    return $local_status || 0;
}

1;

=head1 AUTHORS

Helmut Lichtenberg <heli@tzv.fal.de>

=cut

