##############################################################################
# $Id: Init.pm,v 1.79 2022/02/25 22:16:07 ulf Exp $
##############################################################################
package Apiis::Form::Init;
##############################################################################

=head1 NAME

Apiis::Form::Init -- base package for Form objects of all types

=head1 SYNOPSIS

This base package provides the main functionality and methods needed for
all Form object types (Tk, Html, etc.).

=head1 DESCRIPTION

The generic public methods of this base class are described below. Most of
them can be inherited by subsequent Form objects.

=head1 METHODS

=cut

##############################################################################

use strict;
use warnings;

# use version;
# our $VERSION = version->new(qw$Revision: 1.79 $);
our $VERSION = '$Revision: 1.79 $';

use Carp qw( longmess croak );
use Data::Dumper;
use List::MoreUtils qw( uniq );
use XML::LibXML;

use Apiis;
use base 'Apiis::Init';
use Apiis::Form::Init::Config;
use Apiis::Form::Init::DataSource;
use Apiis::Form::Init::Misc;
use Apiis::Form::Event::Insert;
use Apiis::Form::Event::Update;
use Apiis::Form::Event::Query;
use Apiis::Form::Event::Clear;
use Apiis::Form::Event::Misc;

use utf8::all;

our $apiis;

##############################################################################
# Closure to encapsulate the element access:
{
    # Table for fieldtypes. The specific values are filled in the Tk, Html, etc.
    # modules. Some of them are not really fieldtypes, but elements.
    my @_fieldtypes = qw(
        filefield     button        link      scrollinglist
        browseentry   popupmenue    textfield textblock
        radiogroup    checkboxgroup checkbox  calendar
        label         image         line      frame
        tabular       tabular2      message
    );
    my %_fieldtypes = map { ( $_ => 1 ) } @_fieldtypes;

    # Table of fieldtypes with list context:
    my %_is_a_listfield = (
        scrollinglist => 1,
        browseentry   => 1,
        popupmenue    => 1,
    );

    # collect elements of Block which are not Field or DataSource:
    my $_misc_blockelements = {
        tabular  => 1,
        tabular2 => 1,
        label    => 1,
        image    => 1,
        line     => 1,
        frame    => 1,
    };

    # Table for DataSource types:
    my $_ds_types = {
        sql      => 1,
        record   => 1,
        function => 1,
        sqlfunction => 1,
        bash     => 1,
        none     => 1,
    };
##############################################################################

=head2 exists_fieldtype (public)

Subroutines to check, if the passed type exists in the
list of hardcoded fieldtypes.

=cut

    sub exists_fieldtype {
        return 1 if exists $_fieldtypes{ lc $_[1] };
        return;
    }

    sub _initial_fieldtypes { return \%_fieldtypes; }

=head2 exists_ds_type (internal)

Returns true if the passed parameter is in the list of hardcoded DataSource
Types (like sql, record, function, none).

=cut

    sub exists_ds_type {
        return 1 if exists $_ds_types->{ lc $_[1] };
        return;
    }

=head2 is_a_listfield (internal)

Returns true if the passed parameter is in the list of hardcoded fields, that
have a list character (like ScrollingList, BrowseEntry, etc.).

=cut

    sub is_a_listfield {
        return 1 if exists $_is_a_listfield{ lc $_[1] };
        return;
    }

=head2 is_misc_blockelement (internal)

Subroutines to check, if the passed element exists in the
list of hardcoded Block elements, which are not Field, DataSource, etc..

=cut

    sub is_misc_blockelement {
        return 1 if exists $_misc_blockelements->{ lc $_[1] };
        return;
    }
}    # end closure

##############################################################################

=head2 new (public)

B<new> creates a new form object.
Input parameter is an anonymous hash with the key 'xmlfile' and the path to this
file as its value. 

The B<new> method of Init.pm is not invoked directly but via inheritance through
the widget specific modules.

Example:

   my $form_obj = Apiis::Form::Tk->new(
      xmlfile => '/path/to/xmlfile.frm'
   );

=cut

sub new {
    my ( $invocant, %args ) = @_;
    my $class = ref($invocant) || $invocant;
    my $self = bless {}, $class;

    EXIT: {
        if ( !exists $args{'xmlfile'} ){
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'CRIT',
                    from      => __PACKAGE__,
                    msg_short => sprintf(
                        "No key '%s' passed to '%s'",
                        'xmlfile', __PACKAGE__
                    ),
                    msg_long =>
                        sprintf( "Passed Parameters: %s", Dumper( \%args ) ),
                )
            );
            last EXIT;
        }

        my $xmlfile = $args{'xmlfile'};

        if ( !-f $xmlfile ) {

            use Encode;
            $xmlfile=decode('utf8',$xmlfile);

            if ( !-f $xmlfile ) {
                $xmlfile = $apiis->formpath . '/' . $xmlfile;
            }
            if ( !-f $xmlfile ) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'PARAM',
                        severity  => 'CRIT',
                        from      => __PACKAGE__,
                        msg_short =>
                            sprintf( "XML file '%s' does not exist", $xmlfile ),
                    )
                );
                last EXIT;
            }
        }
        $args{'xmlfile'} = $xmlfile; # in case we changed it
        $self->{_xmlfile} = $xmlfile;

        # cache or not:
        my ( $xml_ref, $memcache, $memval );
        my $memkey = $class . q{_};
        CACHE: {
            last CACHE if !$apiis->Cache->hasMemcached();

            if ( open my $xmlfh, '<', $xmlfile ) {
                binmode($xmlfh); # in case of UTF-8 characters
                my $ctx = Digest::MD5->new;
                $ctx->addfile(*$xmlfh);
                close $xmlfh;
                my $digest = $ctx->hexdigest;
                last CACHE if !$digest;
                $memkey .= $digest;
                $memcache = $apiis->Cache->memcache();
                $memval   = $memcache->get( $memkey );
                if ($memval) {
                    $self = $memval;
                    $apiis->log( 'info',
                        sprintf "Loaded Form %s (%s) from memcached\n",
                        $memkey, $xmlfile );
                }
            }

        }

        # ok, we could not load from cache:
        if ( !$memval ) {
            

#                    use XML::LibXML;
#                    use XML::Hash::LX ':inject';
#                    my $raw_xml; 
#
#                    open(IN, $xmlfile);
#    
#                    while (<IN>) {
#                        $raw_xml.=$_;
#                    }
#                    close(IN);
#    
#                    $raw_xml = Encode::encode_utf8($raw_xml);
#    
#                    my $d = XML::LibXML->load_xml(string => $raw_xml );
#
#                    #-- prepare it as hash 
#                    my $xp          = XML::LibXML::XPathContext->new($d);
#                    my $hs_xml_file = $d->toHash();
#


            # let libxml parse the xml/dtd:
            $xml_ref = $self->Apiis::Form::Init::Config::_parse_xml( \%args );
            last EXIT if $self->status;

            # create internal structures, starting with root element:
            $self->Apiis::Form::Init::Config::_read_node(
                node => $xml_ref->documentElement );
            # Reorder Events:
            $self->Apiis::Form::Init::Config::_reorder_events;
            # copy _data_ref of Connected Fields:

            last EXIT if $self->status;

            # create some auxiliary data structures:
            my $_status;    # for displaying status messages
            $self->{'_flat'}{'__form_status_msg'}{'_data_ref'} = \$_status;
            $self->{'_flat'}{'_gui_type'} = undef;

            # load object into memcache:
            if ($memcache) {
                $memcache->set( $memkey, $self, 3600 ); #expire in 1 hour
                $apiis->log( 'info',
                    sprintf "Loading Form %s (%s) into memcached\n",
                    $memkey, $xmlfile );
            }
        }

        #-- collect fields from a form which has to be updated  
        $self->{'_activ_update_fields_from_cgi'}={};

        # get the data sources for list fields:
        $self->Apiis::Form::Init::DataSource::_get_datasources;
        $self->Apiis::Form::Init::Config::_connect_fields;
        last EXIT if $self->status;

        # basic init is done, now run the _init of the invoking class:
        $self->_init( \%args );
        last EXIT if $self->status;
        # die Dumper(keys %{$self->{_flat}}); # debugg
        # die Dumper($self->{_flat}->{'F_db_sire'}{'_displays_intdata'}); # debugg
        # die Dumper($self->{_flat}->{'Col4'}); # debugg
    }
    return $self;
}

##############################################################################

=head2 _init (internal)

B<_init()> is only invoked if you want to create an object of type
Apiis::Form directly. As this is only a base class an error is yielded.

=cut

sub _init {
    croak "You reached _init in the base class 'Apiis::Form::Init'.\n"
        . "This should not happen.";
}
##############################################################################

=head2 xmlfile (public)

B<xmlfile()> returns the full path of the xml file for this form.

=cut

sub xmlfile { return $_[0]->{_xmlfile} }
##############################################################################

=head2 add_formlib_path (public)

B<add_formlib_path> will prepended some Form/Project specific directories to
the library search for Form modules in up to down order. So the most specific
will be searched first and wins over the more generic ones. Form modules for
example for Form_0 and GUI-type Tk are searched in:

   $APIIS_HOME/lib/Apiis/Form/Tk/Form_0/
   $APIIS_HOME/lib/Apiis/Form/Tk/
   $APIIS_HOME/lib/Apiis/Form/Form_0/
   $APIIS_HOME/lib/Apiis/Form/Event/

As Form-name and GUI-type are determined at runtime, the addition of this
search paths also have to happen at runtime.

B<add_formlib_path> expects as input parameters:

   1. the GUI-type (e.g. Tk, HTML, Qt )
   2. the form name as in $self->formname

Usage:

   $self->add_formlib_path( 'Tk', $self->formname );

=cut

sub add_formlib_path {
    my ( $self, $gui_type, $formname ) = @_;

    # Order is important!
    my @_formlib_path_core = (
        q{Apiis/Form/Event},           # generic
        qq{Apiis/Form/${gui_type}},    # GUI spezific
    );

    # add first the more generic path:
    my $apiis_home = $apiis->APIIS_HOME . '/lib';
    for (@_formlib_path_core) {
        unshift( @INC, qq(${apiis_home}/$_) );
    }

    # and then the project specific one on top (accessed first):
    my @_formlib_path_local = (
        q{Apiis/Form/Event},                       # generic
        qq{Apiis/Form/${formname}},                # Form spezific
        qq{Apiis/Form/${gui_type}},                # GUI spezific
        qq{Apiis/Form/${gui_type}/${formname}},    # GUI/Form spezific
    );

    # forms without project have no APIIS_LOCAL:
    if ( $apiis->APIIS_LOCAL ) {
        my $apiis_local = $apiis->APIIS_LOCAL . '/lib';
        for (@_formlib_path_local) {
            unshift( @INC, qq(${apiis_local}/$_) );
        }
    }
}

##############################################################################
# some public access methods:
##############################################################################

=head2 form_status_msg (public)

B<form_status_msg> is a write-only method to put form-global status messages
somewhere. They can be displayed e.g. in a status line (textfield) in the form.

Example:

   $self->form_status_msg('Retrieved 20 records');

=cut

sub form_status_msg {
    my ( $self, $mesg ) = @_;
    if ( defined $mesg ) {
        my $data_ref = $self->GetValue( '__form_status_msg', '_data_ref' );
        $$data_ref = $mesg;
#         my $widget_refs =
#             $self->GetValue( '__form_status_msg', '_widget_refs' );
#         if ($widget_refs) {
#             $widget_refs->[0]->insert( '1.0', $mesg . "\n" );
#         }
    }
}


=head2 GetValue (public)

B<GetValue> is the main method to access the configuration data and the data
references of this form object. All the real elements (not the pseudo auxiliary
elements) of the xml file have a unique name and are accessible trough this
name. All elements without the identifying name are flattened into their parent
element. Their attributes become attributes of the parent.

Syntax:

   my $attr_value = $form_obj->GetValue($elementname, $attribut);

Example:

   my $label = $form_obj->GetValue('Field_1', 'Label');

B<GetValue> returns also the values for dynamically created items like
'_field_list' for each block or '_column_list' for each datasource.

Example:

   foreach my $field ( @{ $form_obj->GetValue( 'Block_0', '_field_list')} ){
      # do something
   }

The list values return an array reference so they must be dereferenced for usage
in loops.

=cut

sub GetValue {
    my ( $self, $nodename, $att_name ) = @_;
    EXIT: {
        if ( !defined $nodename or !defined $att_name ) {
            $self->status(1);
            $nodename || ( $nodename = 'undef' );
            $att_name || ( $att_name = 'undef' );
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => __PACKAGE__,
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' or '%s' passed to '%s'",
                        "nodename($nodename)", "attribute_name($att_name)",
                        'GetValue()'
                    ),
                )
            );
            last EXIT;
        }
        if ( !exists $self->{'_flat'}{$nodename} ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => __PACKAGE__,
                    msg_short => sprintf( "Unknown element '%s'", $nodename ),
                    msg_long  => 'Check your xml form file for this element',
                    backtrace => longmess('invoked'),
                )
            );
            last EXIT;
        }
        return if !exists $self->{'_flat'}{$nodename}{$att_name};

        # always return in scalar context:
        return $self->{'_flat'}{$nodename}{$att_name};
    }
    return;
}
##############################################################################


=head2 SetValue (public)

B<SetValue> is the counterpart to GetValue.

Syntax:

   my $old_value = $form_obj->SetValue($elementname, $attribut, $new_value);

B<SetValue> returns the old value.

=cut

sub SetValue {
    my ( $self, $nodename, $att_name, $value ) = @_;
    if ( !defined $nodename or !defined $att_name ) {
        $self->status(1);
        $nodename || ( $nodename = 'undef' );
        $att_name || ( $att_name = 'undef' );
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => __PACKAGE__,
                backtrace => longmess('invoked'),
                msg_short => sprintf(
                    "No key '%s' or '%s' passed to '%s'",
                    "nodename($nodename)", "attribute_name($att_name)",
                    'GetValue()'
                ),
            )
        );
        # leave early:
        return;
    }

    if (   !exists $self->{'_flat'}{$nodename}
        or !exists $self->{'_flat'}{$nodename}{$att_name} )
    {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => __PACKAGE__,
                backtrace => longmess('invoked'),
                msg_short => sprintf(
                    "Structure '%s' -> '%s' does not exist",
                    $nodename, $att_name, 'SetValue()'
                ),
            )
        );
        return;
    }

    # now finally do the work:
    my $old_value = $self->{'_flat'}{$nodename}{$att_name};
    $self->{'_flat'}{$nodename}{$att_name} = $value;
    return $old_value;
}
##############################################################################

=head2 IncValue | DecValue (public)

Increment and decrement values in the flattened structure.

Syntax:

   $form_obj->IncValue($elementname, $attribut);
   $form_obj->DecValue($elementname, $attribut);

=cut

sub IncValue  { $_[0]->{'_flat'}{ $_[1] }{ $_[2] }++; }
sub DecValue  { $_[0]->{'_flat'}{ $_[1] }{ $_[2] }--; }
sub PushValue {
    my ( $self, $element, $attr, $value ) = @_;
    return if !defined $element;
    return if !defined $attr;
    return if !defined $value;
    push @{ $self->{'_flat'}{$element}{$attr} }, $value;
    # push @{ $_[0]->{'_flat'}{ $_[1] }{$_[2]} }, $_[3];
}
##############################################################################

=head2 GetEvent (public)

B<GetEvent> should make access to event definitions at certain levels easy.

Syntax:

   my $events_ref = $form_obj->GetEvent($elementname, 'OnClick');

B<GetEvent> returns an arrayreference to all 'OnClick'-Eventnames
of $elementname or undef if none exists.

=cut

sub GetEvent {
    my ( $self, $node, $event_type ) = @_;
    EXIT: {
        # check correctness:
        if ( !defined $node or !defined $event_type ) {
            $self->status(1);
            $node       || ( $node       = 'undef' );
            $event_type || ( $event_type = 'undef' );
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => __PACKAGE__,
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' or '%s' passed to '%s'",
                        "nodename ($node)",
                        "event_type ($event_type)",
                        'GetEvent()'
                    ),
                )
            );
            last EXIT;
        }
        last EXIT if !exists $self->{'_flat'}{$node}{'_events'}{$event_type};
        last EXIT if !defined $self->{'_flat'}{$node}{'_events'}{$event_type};
        last EXIT if $self->{'_flat'}{$node}{'_events'}{$event_type} eq '';

        # always return in scalar context:
        return $self->{'_flat'}{$node}{'_events'}{$event_type};
    }    # end label EXIT
    return;
}
##############################################################################
sub PushEvent {
    my ( $self, $node, $event_type, $event_name ) = @_;
    if ( !defined $node or !defined $event_type or !defined $event_name ) {
        $self->status(1);
        $node       || ( $node       = 'undef' );
        $event_type || ( $event_type = 'undef' );
        $event_name || ( $event_name = 'undef' );
        $self->errors(
            Apiis::Errors->new(
                type      => 'PARAM',
                severity  => 'ERR',
                from      => __PACKAGE__,
                backtrace => longmess('invoked'),
                msg_short => sprintf(
                    "No key '%s' or '%s' or '%s' passed to '%s'",
                    "nodename ($node)",
                    "event_type ($event_type)",
                    "event_name ($event_name)",
                    'PushEvent()'
                ),
            )
        );
    }
    else {
        push @{ $self->{'_flat'}{$node}{'_events'}{$event_type} },
            $event_name;
    }
    return;
}
##############################################################################

=head2 RunEvent (public)

input: hash reference with required keys: elementname, eventtype

output: array reference with the names of the processed events

=cut

sub RunEvent {
    my ( $self, $args_ref ) = @_;
    my $elementname   = $args_ref->{'elementname'};
    my $eventtype     = $args_ref->{'eventtype'};
    my $eventargs_ref = $args_ref->{'eventargs'};
    my @events_run;

    EXIT: {
        if ( !defined $elementname or !defined $eventtype ) {
            $self->status(1);
            $elementname || ( $elementname = 'undef' );
            $eventtype || ( $eventtype = 'undef' );
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'ERR',
                    from      => 'RunEvent',
                    backtrace => longmess('invoked'),
                    msg_short => sprintf(
                        "No key '%s' or '%s' passed to '%s'",
                        "elementname($elementname)",
                        "eventtype($eventtype)",
                        'RunEvent()'
                    ),
                ),
            );
            last EXIT;
        }
        # could be several events of this type:
        my $event_ref = $self->GetEvent( $elementname, $eventtype );
        last EXIT if !$event_ref;  # ok, no events found

        EVENT:
        for my $event (@$event_ref) {
            # fully qualify short module names:
            my %qual_modules = (
                Main     => 'Apiis::Form::' . $self->gui_type,
                HandleDS => 'Apiis::Form::Event::HandleDS',
                CallForm => 'Apiis::Form::Event::CallForm',
                Misc     => 'Apiis::Form::Event::Misc',
                Function => 'Apiis::Form::Event::Function',
            );

            my $module = $self->GetValue( $event, 'Module' );
            if ( exists $qual_modules{$module} ){
                $module = $qual_modules{$module};
            }
            my $action = $self->GetValue( $event, 'Action' );
            next EVENT if !$module;
            next EVENT if !$action;

            eval "require $module"; ## no critic
            if ($@) {
                # no module in this path
                $self->status(1);
                my $msg = $@;
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => 'RunEvent',
                        backtrace => longmess('invoked'),
                        msg_long  => $msg,
                        msg_short => sprintf(
                            "Error in loading Module '%s.pm' for event '%s'",
                            $module, $event,
                        ),
                    ),
                );
                next EVENT;
            }

            my $command = $module . '::' . $action;
            eval {
                $self->$command(
                    {   eventname => $event,
                        eventargs => $eventargs_ref,
                    }
                );
            };
            if ($@) {
                my $mesg = $@;
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => 'RunEvent',
                        backtrace => longmess('invoked'),
                        msg_long  => $mesg,
                        msg_short => sprintf(
                            "Error when executing event '%s' (%s)",
                            $event, $module . '::' . $action
                        ),
                    )
                );
                next EVENT;
            }
            push @events_run, $event;
        }
    } # end label EXIT
    return \@events_run;
}

sub runevents {
    my ( $self, $args_ref ) = @_;
    my $elementname = $args_ref->{'elementname'};
    my $eventlist_ref = $self->GetValue( $elementname, '_event_list' );
    my @events;
    @events = @$eventlist_ref if $eventlist_ref;
    for my $thisevent (@events) {
        my $e_type = $self->GetValue( $thisevent, 'Type' );
        $self->RunEvent(
            {   elementname => $elementname,
                eventtype   => $e_type,
            }
        );
    }
}
##############################################################################

=head2 gui_type (public)

B<gui_type> returns (and sets) the type of the running Graphical User
Interface, e.g. Tk, HTML.

=cut

sub gui_type {
    $_[0]->{_gui_type} = $_[1] if $_[1];
    return $_[0]->{_gui_type};
}

##############################################################################

=head2 top (public)

B<top> returns (and sets) a reference to toplevel window (Tk, query => HTML).

=cut

sub top {
    if ( $_[1] ) {
        my $old_top = $_[0]->{_top};
        $_[0]->{_top} = $_[1];
        return $old_top;
    }
    return $_[0]->{_top};
}

sub balloon_ref {
    if ( $_[1] ) {
        $_[0]->{_balloon_ref} = $_[1];
    }
    return $_[0]->{_balloon_ref};
}

##############################################################################

=head2 formname (public)

B<formname> returns the name of the Form.

For the consistency of method names, there is also a method B<formnames>,
which returns an arrayref of the list of formnames.

Both methods might be seldom used.

=cut

sub formname { return $_[0]->{'_form_list'}[0]; }

sub formnames {
    wantarray && return @{ $_[0]->{'_form_list'} };
    return $_[0]->{'_general_list'};
}
##############################################################################

=head2 generalname (public)

B<generalname> returns the name of the General section. There could only be
one General section.

For the consistency of method names, there is also a method B<generalnames>,
which returns an arrayref of the list of generalnames.

=cut

sub generalname { return $_[0]->{'_general_list'}[0]; }

sub generalnames {
    wantarray && return @{ $_[0]->{'_general_list'} };
    return $_[0]->{'_general_list'};
}
##############################################################################

=head2 blocknames | datasourcenames | fieldnames |columnnames (public)

These methods all return an arrayref of the list of names.

=cut

sub blocknames {
    wantarray && return @{ $_[0]->{'_block_list'} };
    return $_[0]->{'_block_list'};
}
##############################################################################
sub datasourcenames {
    wantarray && return @{ $_[0]->{'_datasource_list'} };
    return $_[0]->{'_datasource_list'};
}
##############################################################################
sub fieldnames {
    wantarray && return @{ $_[0]->{'_field_list'} };
    return $_[0]->{'_field_list'};
}
##############################################################################
sub columnnames {
    wantarray && return @{ $_[0]->{'_column_list'} };
    return $_[0]->{'_column_list'};
}
##############################################################################

=head2 misc_blockelements (public)

B<misc_blockelements> return an array (or reference) to a list of non-Field
elements of a block (Line, Image, Frage, etc.).

=cut

sub misc_blockelements {
    wantarray && return @{ $_[0]->{'_misc_blockelement_list'} };
    return $_[0]->{'_misc_blockelement_list'};
}
##############################################################################

=head2 master_detail (public)

Form level flag, if this form is a more complex one with master/detail
relationships.

Usage:

   $self->master_detail(1); # set flag
   &easy_going if not $self->master_detail;

=cut

sub master_detail {
    $_[0]->{'_master_detail'} = $_[1] if $_[1];
    return $_[0]->{'_master_detail'};
}
##############################################################################

=head2 query_block_order (public)

B<query_block_order> return the blocks in the right order for Master/Detail
handling. The query order depends on the master/detail relationships between
blocks. This order is determined in Event/Query.pm, when the first query is
started. After this it is usually used readonly.

=cut

sub query_block_order {
    $_[0]->{'_query_block_order'} = $_[1] if $_[1];
    wantarray && return @{ $_[0]->{'_query_block_order'} };
    return $_[0]->{'_query_block_order'};
}
##############################################################################

=head2 encode_list_ref | decode_list_ref

B<encode_list_ref> and B<decode_list_ref> exchange the primary/foreignkey
value with the more readable one and vice versa. These methods are used, if a
field-specific DataSource exists.

Both take as input parameters:

   1. Fieldname
   2. The data to en/de-code

They return the en/de-coded value.

=cut

sub encode_list_ref {
    shift()->Apiis::Form::Init::DataSource::_list_ref_coding( @_, 'encode' );
}

sub decode_list_ref {
    shift()->Apiis::Form::Init::DataSource::_list_ref_coding( @_, 'decode' );
}

sub get_field_list_ref { &Apiis::Form::Init::DataSource::_get_field_list_ref; }
sub get_field_data_ref { &Apiis::Form::Init::DataSource::_get_field_data_ref; }
# get the parameters for a SQL statement with placeholders:
sub get_bind_params { &Apiis::Form::Init::DataSource::_get_bind_params; }

# get the parameters of a certain event:
sub get_event_par_ref { &Apiis::Form::Event::Misc::_get_event_par_ref; }
# compose the font string for a certain Field (according to xfontsel):
sub font_string_for { &Apiis::Form::Init::Misc::_font_string_for; }
# fill _data_refs with values from a Record object:
sub _ro2fields { &Apiis::Form::Init::DataSource::_ro2fields; }
# execute the block's DataSource to fill the fields:
sub get_block_ds { &Apiis::Form::Init::DataSource::_get_block_ds; }
##############################################################################
sub set_fieldtypes {
    my ( $self, $types_ref ) = @_;
    return if !defined $types_ref;
    return if ref $types_ref ne 'HASH';

    my $_flat_types_ref = $self->{_flat}{_field_types};
    while ( my ( $type, $val ) = each %$types_ref ) {
        next if !exists $_flat_types_ref->{$type};
        $_flat_types_ref->{$type} = $val;
    }
    return;
}

=head2 fieldtype (internal)

B<fieldtype> returns the widget-set specific fieldtype for a passed metatype.

Example:

   my $ft = $self->fieldtype('textfield');   # returns 'TextField' for Tk

All metatypes are in lower case.

To make error messages more helpfull, you should add a second parameter,
the fieldname:

   my $ft = $self->fieldtype( $type, $fieldname );

If no error occurs, the fieldname is simply ignored, otherwise it will
give a valueable hint, where to search in the XML file.

=cut

sub fieldtype {
    my ( $self, $metatype, $fieldname ) = @_;
    return if !defined $metatype;
    my $_flat_types_ref = $self->{_flat}{_field_types};
    if ( exists $_flat_types_ref->{$metatype} ) {
        return $_flat_types_ref->{$metatype};
    }

    $self->status(1);
    my %type_is_ok;
    for my $key ( keys %$_flat_types_ref ) {
        my $val = $_flat_types_ref->{$key};
        next if $val eq '1';
        $type_is_ok{$key} = $val;
    }
    $self->errors(
        Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Apiis::Form::Init::fieldtype',
            backtrace => longmess('invoked'),
            msg_short => sprintf(
                "Metatype '%s' does not exist, Field: %s",
                $metatype, ( $fieldname || 'unknown' )
            ),
            msg_long => sprintf(
                "Implemented Field types are:\n* %s\n"
                . "Check your XML file for this field!",
                join( qq{\n* }, uniq sort values %type_is_ok ) ),
        )
    );
    return;
}

##############################################################################

=head2 insert_block | insert_form | update_block | query_block | clear_block | clear_form (public)

These methods handle form events on block level, initiated by the user. These
are the public interfaces, the real methods are rolled out into the
Apiis::Form::Event namespace. See details there.

The blockname is provided during the invocation of the do_<commands> in the
widget-specific button handling, e.g. in Tk/Button.pm.

=head2 insert_blocks | insert_form | clear_form (public)

These are the same methods except that they act on multiple/all blocks.
The blocknames for B<insert_blocks> are defined in the xml file.

=cut

# Inserts:
sub _insert {
    my ( $self, $args_ref ) = @_;
    my $blocks_ref = $args_ref->{blocks};

    IBLOCK:
    for my $block ( @$blocks_ref ) {
        $self->Apiis::Form::Event::Insert::_insert_block(
            { blockname => $block } );
        last IBLOCK if $self->status;
    }

    if ( $self->status ){
        $apiis->DataBase->rollback;
        $self->form_status_msg('Rollback due to errors');
    }
    else {
        $apiis->DataBase->commit;
    }
    return;
}

sub insert_block {
    my ( $self, $args_ref ) = @_;
    # get the blockname of this element:
    my $block = $args_ref->{blockname};
    if ( defined $block ) {
        $args_ref->{blocks} = [$block];
    }
    else {
        my $field = $args_ref->{elementname};
        $block = $self->GetValue( $field, '_my_block' );
        $args_ref->{blocks} = [$block];
    }
    $self->_insert($args_ref);
    return;
}

sub insert_blocks {
    my ( $self, $args_ref ) = @_;

    # get the blocknames from xml-paramters:
    my $field = $args_ref->{elementname};
    my $params_ref = $self->GetValue( $field, '_parameter_list' );
    return if ! $params_ref;

    my @blocks;
    PARAM:
    for my $par ( @$params_ref ){
        my $key = $self->GetValue( $par, 'Key' );
        next PARAM if $key ne 'block';
        push @blocks, $self->GetValue( $par, 'Value' );
    }
    $args_ref->{blocks} = \@blocks if @blocks;
    $self->_insert($args_ref);
    return;
}

sub insert_form {
    my ( $self, $args_ref ) = @_;
    $args_ref->{blocks} = scalar $self->blocknames;
    $self->_insert($args_ref);
    return;
}

# Updates:
sub _update {
    my ( $self, $args_ref ) = @_;
    my $blocks_ref = $args_ref->{blocks};
    delete $args_ref->{blocks};

    UBLOCK:
    for my $block ( @$blocks_ref ) {
        $args_ref->{blockname} = $block;
        $self->Apiis::Form::Event::Update::_update_block( $args_ref );
        last UBLOCK if $self->status;
    }

    if ( $self->status ){
        $apiis->DataBase->rollback;
        $self->form_status_msg('Rollback due to errors');
    }
    else {
        $apiis->DataBase->commit;
    }
    return;
}

sub update_block {
    my ( $self, $args_ref ) = @_;
    if ( defined $args_ref->{blockname} ) {
        $args_ref->{blocks} = [ $args_ref->{blockname} ];
    }
    else {
        my $field = $args_ref->{elementname};
        my $block = $self->GetValue( $field, '_my_block' );
        $args_ref->{blocks} = [$block];
    }
    $self->_update($args_ref);
    return;
}

sub update_blocks {
    my ( $self, $args_ref ) = @_;

    my $field = $args_ref->{elementname};
    my $params_ref = $self->GetValue( $field, '_parameter_list' );
    return if ! $params_ref;

    my @blocks;
    PARAM:
    for my $par ( @$params_ref ){
        my $key = $self->GetValue( $par, 'Key' );
        next PARAM if $key ne 'block';
        push @blocks, $self->GetValue( $par, 'Value' );
    }
    $args_ref->{blocks} = \@blocks;
    $self->_update($args_ref) if @blocks;
    return;
}

sub update_form {
    my ( $self, $args_ref ) = @_;
    $args_ref->{blocks} = scalar $self->blocknames;
    $self->_update($args_ref);
    return;
}

# Queries:
sub query_block {
    my ( $self, $args_ref ) = @_;
    if ( !defined $args_ref->{blockname} ) {
        my $field = $args_ref->{elementname};
        $args_ref->{blockname} = $self->GetValue( $field, '_my_block' );
    }
    $self->Apiis::Form::Event::Query::_query_block($args_ref);
    return;
}

# Clear:
sub clear_block {
    my ( $self, $args_ref ) = @_;
    if ( !defined $args_ref->{blockname} ) {
        my $field = $args_ref->{elementname};
        $args_ref->{blockname} = $self->GetValue( $field, '_my_block' );
    }
    $self->Apiis::Form::Event::Clear::_clear_block($args_ref);
    return;
}

sub clear_form {
    my ( $self, $args_ref ) = @_;
    for my $block ( $self->blocknames ) {
        $args_ref->{'blockname'} = $block;
        $self->Apiis::Form::Event::Clear::_clear_block( $args_ref );
    }
}

=head2 next | prev | first | last (public)

These methods are for navigation through the records while querying data.

=cut

sub _navigate {
    my ( $self, $args_ref ) = @_;
    if ( !defined $args_ref->{blockname} ) {
        my $field = $args_ref->{elementname};
        $args_ref->{blockname} = $self->GetValue( $field, '_my_block' );
    }
    $self->Apiis::Form::Event::Query::_query_block($args_ref);
}

sub next_block {
    $_[1]->{navigate} = '_next';
    $_[0]->_navigate( $_[1] );
}


sub prev_block {
    $_[1]->{navigate} = '_prev';
        $_[0]->_navigate( $_[1] );
}

sub first_block {
    $_[1]->{navigate} = '_first';
    $_[0]->_navigate( $_[1] );
}

sub last_block {
    $_[1]->{navigate} = '_last';
    $_[0]->_navigate( $_[1] );
}

##############################################################################

=head2 return_value (public)

B<return_value> stores and gives back a SCALAR value, which could be either a
simple scalar, a reference to a hash, to an array or even to another object.
It's up to the configuration, what type of return value is expected.

=cut

sub return_value { 
  $_[0]->{_return_value} = $_[1] if $_[1];
  return $_[0]->{_return_value};
}
##############################################################################
1;
