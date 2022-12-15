##############################################################################
# $Id: Misc.pm,v 1.15 2006/10/10 14:31:35 heli Exp $
##############################################################################
package Apiis::Form::Tk::Misc;

use strict;
use warnings;
our $VERSION = '$Revision: 1.15 $';

require Exporter;
require Tk::Dialog;
use Apiis::Init;
use Apiis::Form::Tk;

# symbols to export on request
@Apiis::Form::Tk::Misc::EXPORT_OK = qw(
    tk_login
    popup
    ask_ync
);

@Apiis::Form::Tk::Misc::ISA = qw( Exporter );


=head1 NAME

Apiis::Form::Tk::Misc -- Provides some usefull Tk subroutines and also some
Form object methods.

=head1 SYNOPSIS

   use Apiis::Form::Tk::Misc qw( <subroutine_name> );

=head1 DESCRIPTION

Apiis::Form::Tk::Misc contains both object methods (e.g. form_error and
clear_form_error) and simple subroutines (e.g. tk_login, popup, and ask_ync)
which must be imported into the callers namespace.

The latter ones are not implemented as object methods as they provide some
popup windows which might be of use before you created a Form object.


Example:

   use Apiis::Form::Tk::Misc qw( tk_login );
   my ( $loginname, $password ) =
       tk_login( { toplevel => $top, project => $thisproject } );

The Form object methods are used like always:

   $form_obj->form_error( die => 0 ) if $form_obj->status;

=head1 Subroutines

=head2 popup

B<popup> opens a popup window with some informational or error message
and waits for a notification by the user.

B<popup> is a slightly changed derivat from Hartmut's yaform version.

Usage:

   popup(
       {   toplevel => $top,
           title    => $title,
           bitmap   => $bitmap,
           text     => $text,
           buttons  => $buttons_ref,
       }
   );

=cut

sub popup {
    my $args_ref = shift;
    require Tk::Dialog;
    my $buttons_ref = $args_ref->{buttons} || ['OK'];

    my $d = $args_ref->{toplevel}->Dialog(
        -title      => $args_ref->{title},
        -bitmap     => $args_ref->{bitmap},
        -font       => 'fixed',
        -text       => $args_ref->{text},
        -wraplength => '180m',         # in mm
        -buttons    => $buttons_ref,
        -anchor     => 'w',
    )->Show;
    return;
}
##############################################################################

=head2 ask_ync

B<ask_ync> Raises a window and asks the user for ync -- yes, no, or cancel by
default.
It returns the strings 'yes', 'no', or 'cancel', according to the button,
the user clicked.

Required input parameter is a reference to a hash with the keys 'toplevel' and
'text'. The value of 'text' will be displayed on the popup window.

For other buttons, you can provide the optional input parameter 'buttons',
like demonstrated in the example.

B<Note:> B<ask_ync> is ( like B<popup> and B<tk_login>) not a method of a Form
object as you might want to use it (within Tk) without having created any Form
object before.

Example:

   my $answer = ask_ync(
       toplevel => $top,
       text     => 'Do you believe in magic?'
       buttons  => [ __('Yes'), __('No') ],
   );

=cut

sub ask_ync {
    my $args_ref = shift;
    my ( $buttons_ref, @buttons );

    # defaults:
    push @buttons, __('Yes');
    push @buttons, __('No');
    push @buttons, __('Cancel');

    if ( $args_ref->{buttons} ) {
        $buttons_ref = $args_ref->{buttons};
    }
    else {
        $buttons_ref = \@buttons;
    }

    my $answer = $args_ref->{toplevel}->Dialog(
        -title          => __('Question'),
        -bitmap         => 'question',
        -font           => 'variable',
        -text           => $args_ref->{'text'},
        -wraplength     => '180m',                # in mm
        -buttons        => $buttons_ref,
        -default_button => __('Yes'),
        -anchor         => 'w',
    )->Show;
    return lc $answer;
}
##############################################################################

=head2 tk_login

B<tk_login> Pops up a new window and asks for username and password, which it
then will return.

The popup window is a standard Apiis::Form::Tk form with the xml-file located
at $apiis->APIIS_HOME . '/etc/forms/login.xml'. Change this file to refurbish 
the window's appearence.

Required input parameter is a reference to a hash with the keys 'toplevel'
(required) and 'project' (optional).

'toplevel' is needed to make the invoking Tk-Window wait for the delivery of
username/password. 'project' only changes the window-title to show, which
project you want to log in.

Usage:

   my ( $loginname, $password ) = tk_login(
       {   toplevel => $top,
           project  => $thisproject
       }
   );

=cut

sub tk_login {
    my $args_ref = shift;
    my $top      = $args_ref->{toplevel};
    my $project  = $args_ref->{project};

    # create Form object:
    my $f_obj =
        Apiis::Form::Tk->new(
        xmlfile => $apiis->APIIS_HOME . '/etc/forms/login.frm' );
    $f_obj->form_error if $f_obj->status;

    # change title of form:
    if ($project) {
        my $desc = $f_obj->GetValue( 'General_0', 'Description' );
        $desc = __($desc) . " $project";
        $f_obj->SetValue( 'General_0', 'Description', $desc );
    }

    my $wait_for = 0;
    my %run_args = (
        toplevel     => $top,
        waitvariable => \$wait_for,
    );
    $f_obj->run( \%run_args );
    $top->waitVariable( \$wait_for );
    $f_obj->form_error if $f_obj->status;

    my $loginname = ${ $f_obj->GetValue( 'Field_0', '_data_ref' ) };
    my $password  = ${ $f_obj->GetValue( 'Field_1', '_data_ref' ) };
    return ( $loginname, $password );
}
##############################################################################

=head1 Object methods

=head2 form_error

B<form_error> Raises error windows for all error objects and dies by
default. B<form_error> is a method of the form object, so it does not need
any additional parameter. The error messages are taken from the error
objects.

Common usage:

   $form_obj->form_error if $form_obj->status;

You can configure it not to die with: 

   $form_obj->form_error( die => 0 );

=cut

sub form_error {
    my ( $self, %args ) = @_;
    my $do_die = 1;
    $do_die = $args{'die'} if exists $args{'die'};

    ERROR:
    for my $err ( $self->errors ) {
        my $err_id = $err->id;

        # is the error field-specific?:
        if ( $err->ext_fields ) {
            my $visible = 1;
            my $displayed = 0;

            FIELD:
            for my $field ( @{ $err->ext_fields } ) {
                $visible = 0
                    if lc $self->GetValue( $field, 'Visibility' ) eq 'hidden';
                if ( !$visible and !$displayed ) {
                    # display errors on invisible fields with a popup window:
                    $self->top->Dialog(
                        -title      => &main::__('Error'),
                        -bitmap     => 'error',
                        -font       => 'fixed',
                        -text       => $err->sprint,
                        -wraplength => '180m',               # in mm
                        -buttons    => ['OK'],
                        -anchor     => 'w',
                    )->Show;
                    $displayed = 1;
                    next FIELD;
                }

                my $ds_name = $self->GetValue( $field, '_my_datasource' );
                my $curr_index = $err->ext_fields_idx || 0;    # 0 if undef

                # make error field with red background:
                my $bg = $self->GetValue( $field, 'BackGround' ) || 'grey';
                my $err_bg = $self->GetValue( $field, 'ErrorBackGround' )
                    || 'red';
                my $widget_refs = $self->GetValue( $field, '_widget_refs' );
                my $widget = $widget_refs->[$curr_index];
                if ($widget) {
                    $widget->configure( -background => $err_bg );

                    # fill balloon:
                    my %attach_args = ( -msg => $err->sprint, );
                    $self->balloon_ref->attach( $widget, %attach_args );

                    # remove error background and balloon with Enter:
                    $widget->bind(
                        '<Enter>',
                        sub {
                            $widget->configure( -background => $bg );
                            $widget->after(
                                10000,    # timeout for balloon
                                sub {
                                    $self->balloon_ref->detach($widget);
                                }
                            );
                        }
                    );
                    next FIELD;
                }
            }
            $self->form_status_msg( $err->sprint ) if $visible;
            # delete $err_id only if still exists:
            $self->del_error( $err_id ) if $err_id;
            $err_id = undef;
            next ERROR;
        }

        # catch non-field-specific errors with a popup window:
        $self->top->Dialog(
            -title      => &main::__('Error'),
            -bitmap     => 'error',
            -font       => 'fixed',
            -text       => $err->sprint,
            -wraplength => '180m',               # in mm
            -buttons    => ['OK'],
            -anchor     => 'w',
        )->Show;
        $self->del_error( $err_id ) if $err_id;
        $err_id = undef;
    } # end label ERROR

    $self->status(0);
    $self->top->exit if $do_die;
    return;
}
##############################################################################

=head2 clear_form_error

Work in progress.
Does not work as expected (to reset background and remove balloon message
when text is entered).

=cut

sub clear_form_error {
    my ( $self, $args_ref ) = @_;
    my $fieldname = $args_ref->{fieldname};
    return if !defined $fieldname;

    # get widget reference:
    my $widget_refs = $self->GetValue( $fieldname, '_widget_refs' );
    my $widget      = $widget_refs->[0];

    if ($widget) {
        # remove balloon:
        $self->balloon_ref->detach($widget);

        # reset background color:
        my $bg = $self->GetValue( $fieldname, 'BackGround' ) || 'grey';
        $widget->configure( -background => $bg );
    }
}
##############################################################################

1;
