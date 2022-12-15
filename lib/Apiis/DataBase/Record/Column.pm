##############################################################################
# $Id: Column.pm,v 1.26 2014/12/08 08:56:55 heli Exp $
##############################################################################
package Apiis::DataBase::Record::Column;
$VERSION = '$Revision: 1.26 $';

use strict;
use warnings;
use Apiis::Init;
use base 'Apiis::DataBase::Record';
use Scalar::Util qw( weaken );
use List::MoreUtils qw( pairwise any );
use Text::ParseWords;

##############################################################################

=head1 NAME

Apiis::DataBase::Record::Column -- package for DataBase Record columns

=head1 SYNOPSIS

B<Apiis::DataBase::Column> creates database columns that build an
Apiis::DataBase::Record and provides methods to access them.

=head1 DESCRIPTION

The public and internal methods of this class are described below.

=head1 METHODS

=cut

##############################################################################

sub _init {
    my ( $self, $args_ref ) = @_;
    my $pack = __PACKAGE__;
    return if $self->{"_init"}{$pack}++;    # Conway p. 243

    # predefine _encoded and _decoded for new columns:
    $self->{'_encoded'} = 1;
    $self->{'_decoded'} = 1;

    # ToDo: keys of $args_ref are not checked, if they exist (except 'name' in
    # new()).  During creation of the object it is possible to set initial
    # values even for 'readonly' attributes.
    foreach my $attrname (
        qw{
        _name       _tablename   _tableobj   _db_column   _datatype
        _extdata    _struct_type _form_type  _ar_check    _intdata
        _ext_fields _updated     _length     _description _default
        _check      _modify      _foreignkey _encoded     _decoded
        _id_set     _best_id_set _use_entry_view
        } )
    {
        if ( exists $args_ref->{$attrname} ) {
            $self->{$attrname} = $args_ref->{$attrname};
        }
    }
    # weaken the reference to the record object to avoid a memory leak:
    weaken( $self->{_tableobj} );

    # parse the check-/modify-rules here once instead of in the
    # check_record/modify_record-loop:
    # ToDo: this should be done while reading the Model file, not here!
    if ( my $check_ref = $self->{"_check"} ) {
        foreach my $thischeck (@$check_ref) {
            push @{ $self->{"_check_rules"} },
                [ parse_line( '\s+', 0, $thischeck ) ]; # push an array ref!
        }
    }
    if ( my $modify_ref = $self->{"_modify"} ) {
        foreach my $thismodify (@$modify_ref) {
            push @{ $self->{"_modify_rules"} },
                [ parse_line( '\s+', 0, $thismodify ) ]; # LoL!
        }
    }

}
##############################################################################

# takes an array:
sub extdata {
    my ( $self, @values ) = @_;
    if (@values) {    # to allow passing of undef
        if ( scalar @values == 1 and ref $values[0] eq 'ARRAY' ) {
            $self->{_extdata} = $values[0];
        }
        else {
            $self->{_extdata} = \@values;
        }
        $self->encoded(0);              # reset encoded status
        $self->tableobj->encoded(0);    # reset encoded-status on record level
        # $apiis->log( 'debug',
        #     sprintf 'extdata: resetting encoded status for column %s to 0',
        #     $self->name );
    }
    return undef unless $self->{_extdata};
    wantarray && return @{ $self->{_extdata} };
    return $self->{_extdata};
}
##############################################################################
# mirroring of column data:
# mirror the values of extdata to m_extdata:
sub mirror_extdata {
    $_[0]->{_m_extdata} = $_[0]->{_extdata};
    $_[0]->ext_mirrored(1);
    $_[0]->mirrored(1) if $_[0]->int_mirrored;
    return;
}

# flag column if extdata is mirrored:
sub ext_mirrored {
    $_[0]->{_ext_mirrored} = $_[1] if defined $_[1];
    return $_[0]->{_ext_mirrored};
}

# return the value of m_extdata:
sub m_extdata {
    return $_[0]->{"_m_extdata"};
}

# returns 1 if extdata and m_extdata differ, otherwise false:
sub m_diff_extdata {
    my $self = shift;
    my @ed = @{$self->{_extdata}} if $self->{_extdata};
    my @m_ed = @{$self->{_m_extdata}} if $self->{_m_extdata};
    no warnings qw( uninitialized ); # some array elements could be undef
    my @x = pairwise { $a ne $b } @ed, @m_ed;
    return any { $_ } @x;
}

# returns 1 if either ext- or intdata differ to their mirrors, otherwise false:
sub m_diff {
    $_[0]->m_diff_intdata ? return 1 : return $_[0]->m_diff_extdata;
}

# mirror the values of intdata to m_intdata:
sub mirror_intdata {
    $_[0]->{_m_intdata} = $_[0]->{_intdata};
    $_[0]->int_mirrored(1);
    $_[0]->mirrored(1) if $_[0]->ext_mirrored;
    return;
}

# flag column if intdata is mirrored:
sub int_mirrored {
    $_[0]->{_int_mirrored} = $_[1] if defined $_[1];
    return $_[0]->{_int_mirrored};
}

# return the value of m_intdata:
sub m_intdata {
    return $_[0]->{"_m_intdata"};
}

# returns 1 if intdata and m_intdata differ, otherwise false:
sub m_diff_intdata {
    no warnings qw( uninitialized );
    return 1 if $_[0]->{_intdata} ne $_[0]->{_m_intdata};
    return;
}
##############################################################################
# takes an array:
sub ext_fields {
    my ( $self, @values ) = @_;
    if ( $#_ > 0 ) {    # to allow passing of undef
        $self->{_ext_fields} = \@values;
    }
    return if !defined $self->{_ext_fields};
    wantarray && return @{ $self->{_ext_fields} };
    return $self->{_ext_fields};
}
##############################################################################

=head2 use_entry_view (public)

B<use_entry_view> is a column method to allow encoding distinguish between
values from a table <Table> or from the view entry_<Table>. In case of
transfer this flag decides, if encoding takes the db_animal from
entry_transfer (an active animal) or from transfer directly, which may be any
db_animal with these external data.

=cut

sub use_entry_view {
    $_[0]->{'_use_entry_view'} = $_[1] if defined $_[1];
    return $_[0]->{'_use_entry_view'};
}
##############################################################################

=head2 id_set (public)

The read/write method B<id_set> stores and offers the ID set information to
retrieve the right record from table transfer when decoding db_animal.

Input:

   $rec_obj->column('db_animal')->id_set('HB');             # single value
   $rec_obj->column('db_animal')->id_set( 'HB', 'Piglet' ); # list
   my @id_sets = (qw/ HB Piglet Lifetime /);
   $rec_obj->column('db_animal')->id_set(@id_sets);         # array
   $rec_obj->column('db_animal')->id_set( \@id_sets );      # arrayref

Output:

   my $id_set_ref = $rec_obj->column('db_animal')->id_set   # arrayref
   my @id_sets    = $rec_obj->column('db_animal')->id_set   # array

=cut

sub id_set {
    my ( $self, @values ) = @_;
    if (@values) {
        if ( ref( $values[0] ) eq 'ARRAY' ) {
            $self->{_id_set} = $values[0];
        }
        else {
            $self->{_id_set} = \@values;
        }
    }
    return if !$self->{_id_set};
    wantarray && return @{ $self->{_id_set} };
    return $self->{_id_set};
}
##############################################################################

=head2 best_id_set (public)

The read/write method B<best_id_set> stores that ID set information, that has
been the best/first while trying to decode through the array of ID sets in
id_set().

=cut

sub best_id_set {
    $_[0]->{'_best_id_set'} = $_[1] if defined $_[1];
    return $_[0]->{'_best_id_set'};
}

##############################################################################
sub updated {
    my ( $self, $value ) = @_;
    $self->{'_updated'} = $value if defined $value;
    return $self->{'_updated'};
}
##############################################################################

sub intdata {
    my ( $self, $value, @rest ) = @_;
    if ( $#_ == 1 ) {    # to allow passing of undef
        $self->{_intdata} = $value;
        $self->decoded(0);              # reset decoded status
        $self->tableobj->decoded(0);    # reset decoded-status on record level
        # $apiis->log( 'debug',
        #     sprintf 'intdata: resetting decoded status for column %s to 0',
        #     $self->name );
    }
    if (@rest) {
        # only one scalar parameter allowed:
        $self->tableobj->errors(
            Apiis::Errors->new(
                type      => 'CODE',
                severity  => 'ERR',
                from      => 'Apiis::DataBase::Record::Column::intdata',
                msg_short => __("Internal programming error"),
                msg_long  => __(
                    "Too many parameters passed to intdata: [_1]",
                    join( ', ', $value, @rest )
                ),
            )
        );
        $self->tableobj->status(1);
    }
    return $self->{"_intdata"};
}
##############################################################################

# read/write methods:
sub length {
    $_[0]->{"_length"} = $_[1] if defined $_[1];
    return $_[0]->{"_length"};
}

sub description {
    $_[0]->{"_description"} = $_[1] if defined $_[1];
    return $_[0]->{"_description"};
}

sub default {
    $_[0]->{"_default"} = $_[1] if defined $_[1];
    return $_[0]->{"_default"};
}

sub encoded {
    $_[0]->{"_encoded"} = $_[1] if defined $_[1];
    return $_[0]->{"_encoded"};
}

sub decoded {
    $_[0]->{"_decoded"} = $_[1] if defined $_[1];
    return $_[0]->{"_decoded"};
}

# readonly methods:
sub name         { return $_[0]->{"_name"} }
sub tablename    { return $_[0]->{"_tablename"} }
sub tableobj     { return $_[0]->{"_tableobj"} }
sub db_column    { return $_[0]->{"_db_column"} }
sub datatype     { return $_[0]->{"_datatype"} }
sub struct_type  { return $_[0]->{"_struct_type"} }
sub form_type    { return $_[0]->{"_form_type"} }
sub ar_check     { return $_[0]->{"_ar_check"} }
sub check_rules  { return $_[0]->{"_check_rules"} }
sub modify_rules { return $_[0]->{"_modify_rules"} }

sub check {
    wantarray && return @{ $_[0]->{"_check"} };
    return $_[0]->{"_check"};
}

sub modify {
    wantarray && return @{ $_[0]->{"_modify"} };
    return $_[0]->{"_modify"};
}

sub foreignkey {
    return if !$_[0]->{"_foreignkey"};
    wantarray && return @{ $_[0]->{"_foreignkey"} };
    return $_[0]->{"_foreignkey"};
}
##############################################################################
1;

