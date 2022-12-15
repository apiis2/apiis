##############################################################################
# $Id: ButtonLib.pm,v 1.21 2006/10/09 09:10:41 heli Exp $
##############################################################################
package Apiis::Form::Tk::ButtonLib;

use warnings;
use strict;
our $VERSION = '$Revision: 1.21 $';

use Data::Dumper;
use Apiis::Init;

# use Apiis::Form::Tk::Misc qw( ask_ync );

=head1 NAME

Apiis::Form::Tk::ButtonLib -- Common subroutines for Button commands

=head1 DESCRIPTION

Maybe it is not neccessary to have this separate file. I could also
invoke $self->insert directly instead of $self->do_insert. But insert()
handles the data part while do_insert can also do some toolkit-specific
error/status handling. So this a toolkit specific layer bitween the forms and the internal data structure.

=head1 METHODS

=cut

=head2 do_exit

Do something useful and close the window.

=cut

sub do_exit { $_[0]->top->destroy }
# sub do_exit {
#     exit if $_[0]->ask_ync( text => &main::__('Do you really want to exit?') )
#         eq 'yes';
# }
##############################################################################

=head2 do_commit

Invoke $self->commit; to commit changes of all blocks.

=cut

sub do_commit {
    my $self = shift;
    $self->commit(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_clear_block

Invoke $self->clear_block to empty all fields of a certain block.

=cut

sub do_clear_block {
    my ( $self, $args_ref ) = @_;
    $self->clear_block($args_ref);
    $self->form_error( die => 0 ) if $self->status;

    # restore _list_ref:
    my $block = $args_ref->{'blockname'};
    my $fields_ref = $self->GetValue( $block, '_all_field_list' );
    return if !$fields_ref;
    return;
}
##############################################################################

=head2 do_clear_form

Invoke $self->clear_form to empty all fields of the form

=cut

sub do_clear_form {
    my $self = shift;
    $self->clear_form(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_clear_form_and_die

Invoke $self->clear_form to empty all fields of the form and terminate the
form afterwards

=cut

sub do_clear_form_and_die {
    my $self = shift;
    $self->clear_form(@_);
    $self->form_error( die => 0 ) if $self->status;
    $self->top->destroy;
}
##############################################################################

=head2 do_insert_form

Invokes $self->insert_form.

=cut

sub do_insert_form {
    my $self = shift;
    $self->insert_form(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_insert_blocks

Invokes $self->insert_blocks.
The blocknames are Parameters from the xml file.

=cut

sub do_insert_blocks {
    my $self = shift;
    $self->insert_blocks(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_insert_block

Invoke $self->insert_block.

=cut

sub do_insert_block {
    my $self = shift;
    $self->insert_block(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_query_block

Invoke $self->query_block.

=cut

sub do_query_block {
    my $self = shift;
    $self->query_block(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_update_block

Invoke $self->update_block.

=cut

sub do_update_block {
    my $self = shift;
    $self->update_block(@_);
    $self->form_error( die => 0 ) if $self->status;
}

=head2 do_first_block | do_next_block | do_prev_block | do_last_block

Invoke the according base methods of Init.pm to navigate query records within a block:
got to the first | next | previous | last record.

=cut

sub do_first_block {
    my $self = shift;
    $self->first_block(@_);
    $self->form_error( die => 0 ) if $self->status;
}

sub do_next_block {
    my $self = shift;
    $self->next_block(@_);
    $self->form_error( die => 0 ) if $self->status;
}

sub do_prev_block {
    my $self = shift;
    $self->prev_block(@_);
    $self->form_error( die => 0 ) if $self->status;
}

sub do_last_block {
    my $self = shift;
    $self->last_block(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_dump

For development only. Dump the values of all fields on the screen.

=cut

sub do_dump {
    my ($self) = @_;
    foreach my $thisfield ( @{ $self->fieldnames } ) {
        # next unless defined $self->GetValue( $thisfield, 'DSColumn' );

        # loop thru all data refs:
        my $values_ref = $self->GetValue( $thisfield, '_data_refs' );
        for my $ref_idx ( 0..$#{$values_ref} ) {
            my $value = ${$values_ref->[$ref_idx]};
            defined $value
                ? ( $value = q{'} . $value . q{'} )
                : ( $value = 'undef' );

            # check if _data_ref is an array reference:
            if ( ref $value eq 'ARRAY' ){
                $value = q{['} . join(q{','}, @$value) . q{']};
            }

            # print it out nicely:
            printf "   %s->[% 2u]\t=>\t%s\n", $thisfield, $ref_idx, $value;
        }
    }
    print "\n";
}
##############################################################################

=head2 do_runevent

Run a defined event.

=cut

sub do_runevents {
    my $self = shift;
    $self->runevents(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_loadblob

Loads file in the database.

=cut

sub do_loadblob {
    my $self = shift;
    $self->loadblob(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_exportblob

Exports file from the database.

=cut

sub do_exportblob {
    my $self = shift;
    $self->exportblob(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_showhelp

Shows context help.

=cut

sub do_showhelp {
    my $self = shift;
    $self->showhelp(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_call_LO

Calls Load Object.

=cut

sub do_call_LO {
    my $self = shift;
    $self->call_LO(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_call_Report

Calls Report subroutine.

=cut

sub do_call_Report {
    my $self = shift;
    $self->call_Report(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_form_actions

Calls the insert or update action for several blocks from one form.

=cut

sub do_form_actions {
    my $self = shift;
    $self->form_actions(@_);
    $self->form_error( die => 0 ) if $self->status;
}
##############################################################################

=head2 do_delete_block

Invoke $self->delete_block.

=cut

sub do_delete_block {
    my $self   = shift;

    my $dialog = $self->top->Dialog(
        -title   => __("Delete the record?"),
        -font    => 'variable',
        -text    => __("Are you sure?"),
        -buttons => [ 'Yes', 'No' ],
    );
    my $answer = $dialog->Show;

    if ( $answer eq 'Yes' ) {
        $self->delete_block(@_);
        $self->form_error( die => 0 ) if $self->status;
    }
}
##############################################################################

1;

