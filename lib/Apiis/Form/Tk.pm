##############################################################################
# $Id: Tk.pm,v 1.36 2014/12/08 08:56:55 heli Exp $
# This Init package provides specific methods for Tk:
##############################################################################

package Apiis::Form::Tk;
use strict;
use warnings;
our $VERSION = '$Revision: 1.36 $';

use Carp qw( longmess );

use base "Apiis::Form::Init";
use Tk 804.027;
use Tk::Balloon;
# use Tk::ErrorDialog;
use Apiis;
use Apiis::Form::Tk::Misc;
use base 'Apiis::Form::Tk::ButtonLib';
our @ISA;
our $apiis;

sub _init {
    my ( $self, $args_ref ) = @_;
    return if $self->{"_init"}{ scalar __PACKAGE__ }++;    # Conway p. 243
    
    # we know the type of GUI here:
    $self->gui_type('Tk');

    # store an existing toplevel reference:
    if ( exists $args_ref->{toplevel} ) {
        # $self->top( $args_ref->{toplevel} ) if $args_ref->{toplevel};
    }

    # Tk-specific names for fieldtypes:
    $self->set_fieldtypes(
        {   button        => 'Button',
            frame         => 'LabFrame',
            tabular       => 'Tabular',
            tabular2      => 'Tabular2',
            scrollinglist => 'ScrollingList',
            browseentry   => 'BrowseEntry',
            popupmenue    => 'BrowseEntry',
            textfield     => 'TextField',
            textblock     => 'TextBlock',
            label         => 'Label',
            message       => 'Message',
            calendar      => 'DateEntry',
            filefield     => 'Button',
        }
    );

    # extend the search path for modules:
    $self->add_formlib_path( 'Tk', $self->formname );
}

##############################################################################
# run the configured form:
# flow control:
#  * create top widget
#  * loop through each block
#  * create all fields and other elements like Label, Line in $self->top. Also
#    the special Tabular-'Field'.
#  * start the Tk loop

sub run {
    my ( $self, $args_ref ) = @_;
    return if $self->status;
    my $toplevel;
    my $master_toplevel = $args_ref->{'toplevel'};
    my $wait_var_ref = $args_ref->{'waitvariable'};

    if ( $master_toplevel ) {
        # create new toplevel on old reference:
        $toplevel = $master_toplevel->Toplevel;
    }
    else {
        # create new toplevel object:
        $toplevel = MainWindow->new();
    }
    $self->top($toplevel);

    my $title = $self->GetValue( $self->generalname, 'Description' );
    $toplevel->configure( -title => $title );

    # balloons:
    $self->balloon_ref( $toplevel->Balloon(-background => 'yellow') );
    # $self->balloon_ref( $self->top->Balloon(-background => 'yellow') );

    # running OnOpenForm-Events:
    $self->RunEvent(
        {   elementname => $self->formname,
            eventtype   => 'OnOpenForm',
        }
    );
    my %_done;
    BLOCK:
    foreach my $blockname ( $self->blocknames ) {
        my ( @fieldnames, @widgets );
        my $field_ref = $self->GetValue( $blockname, '_field_list' );
        my $misc_list_ref =
            $self->GetValue( $blockname, '_misc_blockelement_list' );

        FIELD:
        for my $fieldname ( @$field_ref, @$misc_list_ref ) {
            my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
            my $tk_fieldtype = $self->fieldtype($fieldtype, $fieldname);
            next FIELD if !$tk_fieldtype; # do we need an error here?

            if ( $tk_fieldtype eq 1 ) {
                $self->status;
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'PARAM',
                        severity  => 'ERR',
                        from      => 'Apiis::Form::Tk::run',
                        backtrace => longmess('invoked'),
                        msg_short => "error on converting fieldnames to Tk",
                        msg_long  => sprintf(
                            "Fieldtype '%s' not configured for widget set '%s'.",
                            $fieldtype, 'Tk'
                        ),
                    )
                );
                $self->form_error( die => 0 );
            }

            # require the widget module:
            my $module = 'Apiis::Form::Tk::' . $tk_fieldtype;
            if ( not exists $_done{$module} ) {
                # load modules only once
                eval "require $module";    ## no critic
                if ($@) {
                    $self->status(1);
                    my $msg = $@;
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'CODE',
                            severity  => 'CRIT',
                            from      => 'Apiis::Form::Tk::run',
                            backtrace => longmess('invoked'),
                            msg_long  => $msg,
                            msg_short =>
                                sprintf( "Error loading module '%s'", $module ),
                        )
                    );
                    last BLOCK;
                }
                else {
                    push @ISA, $module;
                }
            }
            $_done{$module}++;
            $self->form_error( die => 0 ) if $self->status;

            # the commands are named after the Fieldtype, e.g _textfield for
            # type TextField or _label for type Label:
            my $command = '_' . $fieldtype;
            my $widget;
            eval { $widget = $self->$command( elementname => $fieldname ) };
            if ($@) {
                $self->status(1);
                my $msg = $@;
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'CRIT',
                        from      => 'Apiis::Form::Tk::run',
                        backtrace => longmess('invoked'),
                        msg_long  => $msg,
                        msg_short => __(
                            "Error running command '[_1]'", $command ),
                    )
                );
                $self->form_error( die => 0 );
                last BLOCK;
            }

            if ( not defined $widget ) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'CRIT',
                        from      => 'Apiis::Form::Tk::run',
                        backtrace => longmess('invoked'),
                        msg_short => __(
                            "Method '[_1]' returned no valid widget", $command ),
                    )
                );
                $self->form_error( die => 0 );
                last BLOCK;
            }
            push @fieldnames, $fieldname;
            push @widgets,    $widget;
            # store widget reference for later use (error handling):
            $self->PushValue( $fieldname, '_widget_refs', $widget );
        }

        for my $index ( 0 .. $#fieldnames ) {
            my $field  = $fieldnames[$index];
            my $widget = $widgets[$index];
            $widget->grid(
                -row        => $self->GetValue( $field, 'Row' ),
                -column     => $self->GetValue( $field, 'Column' ),
                -columnspan => $self->GetValue( $field, 'Columnspan' ),
                -padx       => $self->GetValue( $field, 'PaddingRight' )  || 0,
                -pady       => $self->GetValue( $field, 'PaddingTop' )    || 0,
                -ipadx      => $self->GetValue( $field, 'IPaddingRight' ) || 0,
                -ipady      => $self->GetValue( $field, 'IPaddingTop' )   || 0,
                -sticky     => $self->GetValue( $field, 'Sticky' ),
            );
            my $visible = $self->GetValue( $field, 'Visibility' );
            $widget->gridForget if $visible and $visible eq 'hidden';
        }
    }

    $self->top->OnDestroy(
        sub {
            if ( defined $wait_var_ref ) {
                $$wait_var_ref = 1;
            }
        }
    );
    # $self->top->protocol('WM_DELETE_WINDOW', \&before_exit);
    MainLoop() unless $self->status;

    # running OnCloseForm-Events:
    $self->RunEvent(
        {   elementname => $self->formname,
            eventtype   => 'OnCloseForm',
        }
    );
}
##############################################################################
sub form_error       {&Apiis::Form::Tk::Misc::form_error}
sub clear_form_error {&Apiis::Form::Tk::Misc::clear_form_error}
##############################################################################

1;

