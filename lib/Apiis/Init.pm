#############################################################################
# $Id: Init.pm,v 1.117 2014/12/08 08:56:55 heli Exp $
package Apiis::Init;
##############################################################################

=head1 NAME

Apiis::Init -- Basic initialisation object for the complete APIIS structure

=head1 SYNOPSIS

   our $apiis = Apiis::Init->new(
     version     => $version,
         programname => $programname
   );

This is the basic module for spreading the APIIS configuration during
runtime.  It is invoked automatically if you run the common
initialisation block which includes $APIIS_HOME/lib/apiis_init.pm. You
can access this basic object via the global variable $apiis.

=head1 DESCRIPTION

Apiis::Init creates an internal structure and public methods to access
this structure.


Public and internal methods are:

=head1 INTERNAL METHODS

=cut

##############################################################################

use strict;
use warnings;
our $VERSION = '$Revision: 1.117 $';
require Exporter;
@Apiis::Init::EXPORT    = qw( $apiis __ ); # symbols to export by default
@Apiis::Init::EXPORT_OK = qw( loc translate ); # symbols to export on request
@Apiis::Init::ISA = qw( Exporter );
use Apiis::Init::Config;
use Apiis::Init::Date;
use Apiis::I18N::L10N;

our $apiis;
use vars '$AUTOLOAD';

use Sys::Hostname;
use Carp qw( croak shortmess longmess );
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
use Scalar::Util qw( blessed );

use Env qw/ PATH APIIS_HOME /;
croak "APIIS_HOME is not set!\n" unless $APIIS_HOME;

use lib "$APIIS_HOME/lib";

##############################################################################

=head2 new (mostly internal)

new creates the object where we usually refer to as $apiis.

=cut

sub new {
    my ( $invocant, %args ) = @_;
    my $class = ref($invocant) || $invocant;
    my $self = bless {}, $class;
    $self->_init(%args);    # run the _init of the invoking class:
    return $self;
}

##############################################################################

=head2 _init (internal)

_init does the main initialization and creates the internal structure for:

=over 4

APIIS_HOME os_user version programname date_format
entry_views reserved_strings language codes_table browser fileselector

=back

This is done by querying parameter from the operating system (username) and
the user environment (APIIS_HOME). APIIS_LOCAL is set after a certain
project is selected and the model file is joined into $apiis.

The main resources for this basic structure are the configuration files
$APIIS_HOME/etc/apiisrc and later $APIIS_LOCAL/etc/apiisrc.

=cut

sub _init {
    my ( $self, %args ) = @_;
    my $pack = __PACKAGE__;
    return if $self->{"_init"}{$pack}++;    # Conway p. 243
    $self->{"_starttime"}  = [ gettimeofday() ];
    $self->{"_servername"} = hostname;
    $self->{"_pid"}        = $$;

    $self->{"_APIIS_HOME"}              = $APIIS_HOME;
    $self->{"_running_check_integrity"} = 0;

    $self->{"_os_user"} = $self->_get_user_from_os();

    # importing the default apiis apiisrc config file:
    $self->Apiis::Init::Config::_import_apiisrc();

    # import ~os_user/.apiisrc (if any) for redefinition of projects only:
    if ( $self->{"_os_user"} and $self->{"_os_user"} ne 'unknown' ) {
        $self->Apiis::Init::Config::_import_user_apiisrc();
    }

    if (%args) {
        $self->{"_version"} = $args{version}
            if exists $args{version};
        $self->{"_programname"} = $args{programname}
            if exists $args{programname};
    }

    $self->_join_cache;

    $self->l10n_init( $self->{"_language"} );

    # date:
    $self->check_date_conf(
        order => ( $self->{"_date_order"} || 'YYYY-MM-DD' ),    # default is ISO
        sep => $self->{"_date_sep"},
    );
    if ( $self->date_conf_err ) {
        for ( $self->errors ) {
            my $old = $_->from;
            $_->from( 'while reading global apiisrc ' . "($old)" );
        }
    }
    # time:
    $self->check_time_conf(
        order => ( $self->{"_time_order"} || 'hh:mm:ss' ),      # default is ISO
        sep => $self->{"_time_sep"},
    );
    if ( $self->time_conf_err ) {
        for ( $self->errors ) {
            my $old = $_->from;
            $_->from( 'while reading global apiisrc ' . "($old)" );
        }
    }

    $self->{"_version"} =~ tr/$://d;
    my $text = __('Version');
    $self->{"_version"} =~ s/Revision/$text/;
    $self->_section_methods('local');
    $self->_section_methods('rapidapiis');
}

sub _section_methods {
    my ( $self, $section ) = @_;
    for my $thiskey ( keys %{ $self->{"_$section"} } ) {
        no strict 'refs';    ## no critic
        *$thiskey = sub { return $self->{"_$section"}{$thiskey} }
            if !$self->can($thiskey);
    }
}

##############################################################################

=head2 _get_user_from_os (internal)

The username $apiis->os_user is determined by the operating system. This is
mainly needed for initial log messages, who started the program.

=cut

sub _get_user_from_os {
    return ( getpwuid($<) )[0]
        || getlogin()
        || ( getpwuid($>) )[0]
        || 'unknown';
}

##############################################################################
=head2 APIIS_LOCAL (public)

   $apiis->APIIS_LOCAL

must be read/write because the user can choose a project (if there are more
than one configured in $APIIS_HOME/etc/apiisrc) which sets APIIS_LOCAL.

If $apiis->APIIS_LOCAL is set to a value it adds $apiis->APIIS_LOCAL/lib to
@INC and prepends $apiis->APIIS_LOCAL/bin to $PATH.

Note: APIIS_LOCAL is now built only from the project entries in apiisrc. If
there is an environment variable $APIIS_LOCAL it is *ignored*!

=cut

sub APIIS_LOCAL {
    my ( $self, $val ) = @_;
    if ($val) {
        $self->{'_APIIS_LOCAL'} = $val;
        unshift( @INC, "$val/lib" );
        $PATH = "$val/bin:" . $PATH;
    }
    return $self->{'_APIIS_LOCAL'};
}

=head2 projects (public)

Returns the names of the projects defined in $APIIS_HOME/etc/apiisrc.

=cut

sub projects { return keys %{$_[0]->{_projects}}; }

=head2 project (public)

Returns the $APIIS_LOCAL path for a specific project and is therefore mostly
redundant with $apiis->APIIS_LOCAL().

Example:

   $local_path = $apiis->project('ref_breedprg');

=cut

sub project {
   my ( $self, $project ) = @_;
   if ( not defined $project ) {
      $apiis->status(1);
      $apiis->errors(
         Apiis::Errors->new(
            type      => 'CODE',
            severity  => 'CRIT',
            from      => 'Apiis::Init::project',
            msg_short => __( "[_1] not defined", 'project name' ),
         )
      );
   } else {
      return $self->{'_projects'}{$project};
   }
}

=head2 formpath (public)

Returns the default path for a specific project where the form definitions are
stored, usually at $APIIS_LOCAL/etc/forms. This default location is set during
join_model.

It can be set to a different value with:

Example:

   $apiis->formpath( './forms' );

=cut

sub formpath {
    $_[0]->{'_formpath'} = $_[1] if $_[1];
    return $_[0]->{'_formpath'};
}

sub servername { return $_[0]->{'_servername'} }
sub pid { return $_[0]->{'_pid'} }
##############################################################################

=head2 l10n_init (public)

B<l10n_init> does the localisation from Apiis::I18N::L10N. The language is
passed as input parameter.

The failure handler for Locale::Maketext is set to return the untranslated
english string (default language).

Also the defined projects translations table is imported into the l10n
schema.

Input: language

Output: none

=cut

sub l10n_init {
    my ( $self, $lang ) = @_;
    my $lh = Apiis::I18N::L10N->get_handle($lang);
    $lh->fail_with( sub { return $_[1] } );
    if ( $apiis and $apiis->APIIS_LOCAL ) {
        my $lexicon = $apiis->APIIS_LOCAL . "/lib/Apiis/I18N/L10N/${lang}.mo";
        $self->l10n_import( $lang, $lexicon ) if -f $lexicon;
    }
    no warnings "redefine";
    *__        = sub { $lh->maketext(@_) };
    *loc       = sub { $lh->maketext(@_) }; # alias
    *translate = sub { $lh->maketext(@_) }; # alias
    return;
}

=head2 l10n_import (public)

B<l10n_import> imports an additional lexicon. This is usually done by
B<l10n_init>. In case you want to load another lexicon, use B<l10n_import>.

Input:

   1. language
   2. file

Output: none

Example:

   $self->l10n_import( $lang, $lexicon ) if -f $lexicon;

=cut

sub l10n_import {
    my ( $self, $lang, $file ) = @_;
    return if !$lang;
    return if !$file;
    Apiis::I18N::L10N->l10n_import( { lang => $lang, file => $file } );
    return;
}

=head2 __()

After initialization of the language handle $lh:

   $lh = Apiis::L10N->get_handle( $apiis->language );

you could write for localising text:

   print $lh->maketext('Just another Perl hacker'), "\n";

To make it more convenient I created a shortcut wrapper around this,
the subroutine __(). So you can write:

   print __('Just another Perl hacker'), "\n";

Note: I must use an anonymous subroutine to have access to $lh. See
'Programming Perl', p. 976 for error message: 'Variable "$lh" will not stay
shared'.

Note2: The bare underscore _ is treated specially, as it is always forced into
the package main ( like $_, @_ ). See "Programming Perl', p. 591.
So we don't have to export it.

Note3: The single underscore _ produced errors several times when it clashed
with the "Perl special filehandle used to cache the information from the
last successfull stat, lstat, or file test operator". ('Programming Perl',
p. 657).
This global underline subroutine is used e.g. in the CPAN or CGI modules. So
it's better to *not* use _() for localisation. Preferred shortcut now is
__().  (5. Aug. 2004 - heli)

=cut

##############################################################################

sub disconnect_project {
    my $self = shift;

    for my $part (qw/ Model DataBase User Auth Compat Cache /) {
        # remove this branch from internal apiis structure:
        if ( exists $self->{$part} ) {
            # disconnect database:
            if ( $part eq 'DataBase' ) {
                # undefined dbh could come from join_model(..., database => 0);
                eval {
                    $apiis->DataBase->disconnect( $apiis->DataBase->user_dbh )
                        if $apiis->DataBase->connected_user;
                    $apiis->DataBase->disconnect( $apiis->DataBase->sys_dbh )
                        if $apiis->DataBase->connected_sys;
                };
                if ($@) {
                    $self->status(1);
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DB',
                            severity  => 'CRIT',
                            from      => 'Apiis::Init::disconnect_project',
                            msg_short => 'Error disconnecting database handles',
                            msg_long  => scalar @_,
                        )
                    );
                }
            }
            # remove this part from the apiis structure:
            delete $self->{$part};
        }

        # undef the method to access this branch:
        if ( $self->can($part) ) {
            undef &$part;
        }
    }
    $self->_join_cache;    # reload Cache with default values
}

##############################################################################

=head2 _add_obj (internal)

$self->_add_obj is used to mount an additional object structure into the
apiis core structure. An example is the addition of the model file
information under $apiis->Model.

usage:

   $self->_add_obj(
      Model  => [ $mod_obj ],
      caller => [ $package, $file, $line ]
   );

=cut

sub _add_obj {
   my ( $self, %args ) = @_;
   my ( $oldpackage, $oldfile, $oldline ) = @{ $args{'caller'} };
   delete $args{'caller'};

   my %allowed_keys = (
      Model    => 1,
      DataBase => 1,
      User     => 1,
      Auth     => 1,
      Cache    => 1,
      Compat   => 1,
   );

   KEY:
   foreach my $thiskey ( keys %args ){
      # check for allowed keys:
      if ( !exists $allowed_keys{ $thiskey } ){
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'CRIT',
               from      => 'Apiis::Init::_add_obj',
               msg_short => __("Unknown key '[_1]' passed", $thiskey),
            )
         );
         last KEY;
      }

      # check if object already exists:
      if ( exists $self->{$thiskey} ) {
         my ( $pack, $file, $line ) = caller;
         warn "Recreating of $thiskey object from package $pack "
           . "in file $file at line $line ignored. " .
           "Invoked from package $oldpackage in file $oldfile line $oldline\n";
         last KEY;
      }
      $self->{$thiskey} = $args{$thiskey}->[0];

      # create a method to access the new object only the first time:
      # Note: Seems like can() cannot handle undefining of methods.
      # if ( ! $self->can($thiskey) ){ # }
      if ( ! blessed($thiskey) ){
         no strict 'refs'; ## no critic
         *$thiskey = sub { return $_[0]->{$thiskey} };
      }
   }
}
##############################################################################

=head1 PUBLIC METHODS


=head2 $apiis->[ os_user | APIIS_HOME | version | programname | date_format | entry_views | reserved_strings | codes_table | browser | fileselector | use_filelog | filelog_filename |use_syslog | syslog_facility | use_sql_logging | sql_logfile | sql_log_dml_only | node_name | node_ip | sequence_interval | multilanguage ] (all public)

These public methods provide an interface for the user to access the
internal structure.

They are readonly and usually return a scalar value except entry_views and
reserved_strings.

$apiis->entry_views returns a hash reference with the table names as keys
and the according entry views (which only contain active records of this
table) as values:

   codes => entry_codes
   unit => entry_unit
   transfer => entry_transfer

$apiis->reserved_strings returns a hash reference to the names and values
of the reserved strings for data entry:

   v_concat => ' >=< '

(One problem here could be the intended blanks as part of the delimiter.
 Maybe they get lost by reading the config file with Config::IniFiles.)

=cut

for my $thiskey ( qw{
    APIIS_HOME      version           programname
    os_user         entry_views       reserved_strings  codes_table
    isodate         isotime           date_sep          time_sep
    date_conf_err   time_conf_err     date_format
    gui_version     browser           fileselector
    sql_logfile     sql_log_dml_only  filelog_filename  syslog_facility 
    node_name       node_ip           sequence_interval
    profiling       starttime         multilanguage     access_rights www
    } )
{
    no strict "refs"; ## no critic
    *$thiskey = sub { return $_[0]->{"_$thiskey"}; };
}

##############################################################################

=head2 $apiis->[ language ] (public)

B<language> is a public read/write method. Initially it's populated by the
apiisrc configuration files, but it can be changed during program
execution. When you set a new language, the old one is returned:

   my $oldlang = $apiis->language( <newlang> );

=cut

sub language {
    my ( $self, $lang ) = @_;
    return $self->{"_language"} if !$lang;

    # switch to new language:
    my $old_lang = $self->{"_language"};
    return $old_lang if $old_lang eq $lang;

    $self->{"_language"} = $lang;
    $self->l10n_init( $lang );
    $self->log( "notice", sprintf "Language changed from %s to %s",
        $old_lang, $lang );
    return $old_lang;
}

##############################################################################

=head2 $apiis->[ date_order | time_order | extdate2iso | iso2extdate | exttime2iso | iso2exttime | date_parts | time_parts | isodate | isotime | date_sep | time_sep | date_conf_err | time_conf_err ] (public)

The Apiis default format for date and time accords to the widely accepted
ISO 8601 standard. Have a look at

   http://www.cl.cam.ac.uk/~mgk25/iso-time.html

for a good summary or other resources for detailed descriptions. You are
strongly encouraged, to also use ISO 8601 date formats in your software.

B<date_order> returns the initially in apiisrc defined order of the date as
a scalar string. You can set the date format during program execution (e.g.
when you batch process several data streams) in the following syntax:

   my $oldformat = $apiis->date_order(
      order => 'DD.MM.YYYY',
      sep   => '.',
   );

The two required parameters are the order of the parts and the separator.
The string to define the order has the following limitations:

=over 4

=item * only the separator and the capital letters Y, M, and D are allowed.

=item * the year has to be specified in the 4 digit form YYYY to avoid
     ambiguity.

=item * the day (DD) and month (MM) formats have 2 digits each.

=item * a valid order string with separators therefore must have the length of
     10 characters.

=item * a valid order string without separator must have the length of 8
     characters.

=item * for year, month, and day values only digits are allowed.

=back

Example without separator:

   my $oldformat = $apiis->date_order(
      order => 'YYYYMMDD',
      sep   => '',
   );

If you want to set B<date_order> to new values, it returns a reference to
the hash of the previously configured parameters order and sep. You thus
can reset the old date format with:

   $apiis->date_order( %$oldformat );

If the chosen date order accords to ISO 8601 (YYYY-MM-DD) the status flag
$apiis->isodate() is set to 1, otherwise its 0. The same applies to the
time order (hh:mm:ss) and isotime().

Another flag B<date_conf_err()> is internally used to mark a bad date
format configuration and as a result of it skip all date tests.

If you really have to parse dates on your own you can get the separators
(besides the format string with B<date_order>) by invoking:

   my $d_sep = $apiis->date_sep();
   my $t_sep = $apiis->time_sep();

B<date_parts()> is a readonly public methods that returns an array (or an
arrayref, depending on the invoking context) of the configured parts of the
date format in the correct order (e.g. ["YYYY", "MM", "DD"]).

This method is mainly usefull in internal date calculations.

B<extdate2iso> converts your external date format into the internal
ISO 8601 format.  It additionally checks, if the passed date is valid.

In scalar context, a formatted date string is returned. In list context,
you get the date parts in the shown order:

   Example:
   $apiis->date_order( order => 'DD.MM.YYYY', sep => '.' );

   # scalar context;
   my $ext_date = '11.2.2005 13:37:00';
   print $apiis->extdate2iso($ext_date), "\n";
   # prints: 2005-02-11 13:37:00

   # list context:
   my ( $year, $month, $day, $hour, $minute, $second )
      = $apiis->extdate2iso($ext_date);

The same return schema for scalar and list context applies to
B<exttime2iso>, B<iso2extdate>, and B<iso2exttime>.

Note, that also the B<iso2extdate> and B<iso2exttime> methods keep this order in
list context. It does not make sense to make them return in the configured
external order as the list context is useful for programming purposes and a
changing order would force you to parse the configuration. And this is not,
what you want.

=cut

sub date_order      { &Apiis::Init::Date::_date_order }
sub extdate2iso     { &Apiis::Init::Date::_extdate2iso }
sub iso2extdate     { &Apiis::Init::Date::_iso2extdate }
sub date_parts      { &Apiis::Init::Date::_date_parts }
sub time_parts      { &Apiis::Init::Date::_time_parts }
sub time_order      { &Apiis::Init::Date::_time_order }
sub exttime2iso     { &Apiis::Init::Date::_exttime2iso }
sub iso2exttime     { &Apiis::Init::Date::_iso2exttime }
sub check_date_conf { &Apiis::Init::Date::_check_date_conf }
sub check_time_conf { &Apiis::Init::Date::_check_time_conf }

##############################################################################

=head2 substitute_env (internal)

Does some postprocessing for special cases (substitution of APIIS_HOME and
APIIS_LOCAL with their values).

The value to check for substituting is passed as a reference so that
substituting is done in place:

   $self->substitute_env( \$val_to_substitute );

It doesn't matter if there is a dollar sign $ in front of APIIS_HOME and
APIIS_LOCAL or not.

=cut

sub substitute_env  {&Apiis::Init::Config::_substitute_env}
##############################################################################

=head2 _join_user (internal)

B<$apiis->_join_user> takes a hashref with a User object (required) and
verifies this user against the database. If it's a valid user, his data gets
mounted into the $apiis structure as the User object.

Example:
   $apiis->_join_user( { userobj => $user_obj } );

=cut

sub _join_user {
    my ( $self, $args_ref ) = @_;
    my $local_status = 0;
    my $ar_type      = lc $apiis->access_rights;

    EXIT: {
        my $thisobj = $args_ref->{'userobj'};
        if ( !$thisobj ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'CRIT',
                    from      => 'Apiis::Init->_join_user',
                    msg_short => __( "Missing parameter [_1]", 'userobj' ),
                )
            );
            last EXIT;
        }

        my $verify_error = 1;
        if ( $ar_type eq 'none' ) {
            # skip authentication:
            $verify_error = 0;
        }
        else {
            $verify_error = $self->DataBase->verify_user($thisobj);
        }

        if ($verify_error) {
            $local_status = 1;
            $self->errors( scalar $self->DataBase->errors );
            $self->status(1);
            last EXIT;
        }

        if ( $thisobj and not $thisobj->status ) {
            # Add all additional data from the database object for this id.
            # This could also overwrite old settings, e.g. if roles are set
            # in the passed object. But this should be desired.
            my $thisid = $thisobj->id;
            # loop thru all methods (only if access_rights are not 'none'):
            if ( $ar_type ne 'none' ) {
                for my $thismethod ( $thisobj->methods ) {
                    # don't overwrite cleartext password with encrypted one!:
                    next if $thismethod eq 'password';
                    my $result = $apiis->DataBase->user($thisid)->$thismethod;
                    if ($result) {
                        $thisobj->$thismethod($result);
                    }
                }
            }

            # now join the model into the apiis-structure:
            my ( $package, $file, $line ) = caller;
            $apiis->_add_obj(
                User   => [$thisobj],
                caller => [ $package, $file, $line ]
            );

            # also set the overall language:
            $apiis->language( $thisobj->language ) if $thisobj->language;

            delete $args_ref->{'userobj'} if exists $args_ref->{'userobj'};
        }
        else {
            $apiis->log( 'err',
                "Joining the user into the apiis-structure failed" );
            $local_status = 1;
        }
    }
    return $local_status;
}

##############################################################################

=head2 exists_user (public)

$apiis->exists_user returns 1 if the User object is already mounted into the
$apiis structure, 0 otherwise.

=cut

sub exists_user {
   return 1 if exists $_[0]->{"User"};
   return 0;
}

##############################################################################

=head2 use_filelog/use_syslog/use_sql_logging (public)

These methods mainly reflect the settings in apiisrc. They are read/write to
enable changing these values in rare cases, e.g. when running check_integrity,
where logging make only little sense.

=cut

sub use_filelog {
    $_[0]->{_use_filelog} = $_[1] if defined $_[1];
    return $_[0]->{_use_filelog};
}

sub use_syslog {
    $_[0]->{_use_syslog} = $_[1] if defined $_[1];
    return $_[0]->{_use_syslog};
}

sub use_sql_logging {
    $_[0]->{_use_sql_logging} = $_[1] if defined $_[1];
    return $_[0]->{_use_sql_logging};
}

=head2 syslog_priority/filelog_priority (public)

syslog_priority is read/write although it mostly won't be overwritten. But
in some cases you may want to switch the logging level for a certain part
of the code to e.g. 'debug', while other parts stay at e.g. 'warn'.
The allowed priorities are debug, info, notice, warn, warning, error, err, crit,
alert, emerg, panic in this order (err = error, warn = warning, emerg =
panic).

If syslog_priority is set with

   my $oldvalue = $apiis->syslog_priority('debug');

it returns the old value of syslog_priority. You then can reset it with

   $apiis->syslog_priority( $oldvalue );

Otherwise it returns the current value of syslog_priority.

The same applies to B<filelog_priority>.

=cut

sub syslog_priority {
    my ( $self, $arg ) = @_;
    if ($arg) {
        # store the old value persistently:
        $self->{'_old_syslog_priority'} = $self->{'_syslog_priority'};
        $self->{'_syslog_priority'}     = $arg;
        $self->Cache->_create_syslog_priorities($arg);
        $self->{'_debug'} = 1 if lc $arg eq 'debug';
        return $self->{'_old_syslog_priority'};
    }
    $self->{'_debug'} = 1 if $self->{'_syslog_priority'} eq 'debug';
    return $self->{'_syslog_priority'};
}

sub filelog_priority {
    my ( $self, $arg ) = @_;
    if ($arg) {
        # store the old value persistently:
        $self->{'_old_filelog_priority'} = $self->{'_filelog_priority'};
        $self->{'_filelog_priority'}     = $arg;
        $self->Cache->_create_filelog_priorities($arg);
        $self->{'_debug'} = 1 if lc $arg eq 'debug';
        return $self->{'_old_filelog_priority'}
    }
    $self->{'_debug'} = 1 if $self->{'_filelog_priority'} eq 'debug';
    return $self->{'_filelog_priority'};
}

=head2 log_priority (public)

B<log_priority> is write-only and sets the values of syslog_priority and
filelog_priority to the same value which is passed as the argument. This is
mainly a development help as you don't know if the configuration is just set
to syslog or filelog.

=cut

sub log_priority {
   my ( $self, $arg ) = @_;
   if ($arg) {
      $self->filelog_priority($arg);
      $self->syslog_priority($arg);
   }
}

=head2 debug (public)

B<debug> returns 1 if the debug level is set, 0 otherwise.
Any true input value sets $self->debug to 1, any false value to 0.

B<debug> can be used to query or set a debug flag, which can be used to
prevent the expensive invokation of $apiis->log on debug level. This flag
depends on the settings of filelog_priority and syslog_priority. If either of
them is set to 'debug', $self->debug always returns 1, even if you pass 0
to it. If you set $self->debug(1), filelog_priority and syslog_priority keep
their values;

=cut

sub debug {
    my ( $self, $arg ) = @_;
    if ( defined $arg ) {
        if ($arg) {
            # true
            $self->{'_debug'} = 1;
            $self->filelog_priority('debug');
            $self->syslog_priority('debug');
        }
        else {
            # false
            $self->{'_debug'} = 0;
            $self->filelog_priority( $self->{'_old_filelog_priority'} );
            $self->syslog_priority( $self->{'_old_syslog_priority'} );
        }
    }
    return $self->{'_debug'};
}
##############################################################################

=head2 log (public)

   $apiis->log('warn', "Cannot open file: $!");

or

   $apiis->log('warn', 'Cannot open file: %s', $!);

log() is the interface to the syslog utility. It takes as first input
parameter the syslog priority, at which it shall be printed into the system
log files (debug info notice warn warning error err crit alert emerg
panic). All levels below $apiis->syslog_priority are suppressed, all of
$apiis->syslog_priority and above are sent to syslog.

As an addition it can also log the sql statements into a file for basic
database recovery. It the passed priority is of type 'sql' like in

   $apiis->log('sql', $sqltext);

and use_sql_logging is set to a true value in apiisrc, the sqltext will get
logged into the configured sql_logfile together with a timestamp,
dabasename, and username (in a separate line with a sql comment). After a
defined backup state you simply have to run this file through your favorite
frontend to the database to recover the current state. If sql_log_dml_only
is true in apiisrc, select statements are not logged.
Messages of priority 'sql' are not passed to syslog.

=cut

sub log {
   my $self     = shift;
   my $priority = lc shift;
   my ( @msg_filelog, @msg_syslog );
   @msg_filelog = @msg_syslog = @_;

   # if profiling is set:
   my $elapsed = sprintf "[%.4f]",                               ## no critics
       tv_interval( $self->starttime, [ gettimeofday() ] ) if $self->profiling;

   # file logging:
   if ( $self->use_filelog ){
      if ( exists $self->Cache->filelog_priorities()->{$priority} ) {
         my $filelog_priority = $self->filelog_priority;
         my $log_prefix;
         my $long_prefix = 1; # switch off for shorter logs while debugging
         if ($long_prefix) {
             $log_prefix = sprintf "%s %s %s[%s]: [%7s]", $self->now,
                 $self->servername, $self->programname, $self->pid, $priority;
         }
         else {
             $log_prefix = sprintf "[%7s]", $priority;
         }

         $log_prefix .= $elapsed if $self->profiling;
         my @args;
         push @args, $log_prefix;
         push @args, @msg_filelog, "\n";
         my $old_fh = select;
         select $self->Cache->fh_filelog;
         $| = 1;    # autoflush the current handle after every print.
         print join ( ' ', @args );
         select $old_fh;
      }
   }

   # now syslog, first catch sql logging:
   if ( $priority eq 'sql' and $self->use_sql_logging ) {
      my $logfile = $self->sql_logfile;
      my $logtext = join(', ', @msg_syslog);
      JUMP: {
     last JUMP if $self->sql_log_dml_only and $logtext =~ /^\s*SELECT/i;
         my $old_fh = select;
         select $self->Cache->fh_sqllog;
         $| = 1;    # autoflush the current handle after every print.
         printf "%s\n", join(' ', @msg_syslog);
         select $old_fh;
      }
   } elsif ( $self->use_syslog ) { # now syslog
      if ( exists $self->Cache->syslog_priorities()->{$priority} ) {
         unless ( $self->_syslog_already_open ) {
            require Sys::Syslog;
            Sys::Syslog::openlog( 'Apiis::' . $self->programname, 'cons,pid',
               $self->syslog_facility )
              or warn "Cannot open syslog: $!\n";
            $self->_syslog_already_open(1);
         }
         my $par = $self->syslog_facility . '|' . $priority;
         my @args;
         # prepend the priority in front of log message:
         push @args, "%s" . shift @msg_syslog;
         if ( $self->profiling ) {
            push @args, "[$priority]$elapsed ";
         } else {
            push @args, "[$priority] ";
         }
         push @args, @msg_syslog;
         Sys::Syslog::syslog( $par, @args ) or warn "Cannot write syslog: $!\n";
      }
   }
}
##############################################################################
# simple switch for opening syslog only once:
sub _syslog_already_open {
   $_[0]->{'_syslog_already_open'} = $_[1] if $_[1];
   return $_[0]->{'_syslog_already_open'} || 0;
}
##############################################################################

=head2 status (public)

$apiis->status returns a general status which is accessible everywhere and
at any time during execution. A status of 0 means success, all true values
indicate an error.

If you pass a parameter this will set the status to this value.

=cut
sub status {
    # no strict 'refs';
    $_[0]->{_status} = $_[1] if defined $_[1];
    return $_[0]->{_status};
}
##############################################################################

=head2 running_check_integrity (public)

$apiis->running_check_integrity is a simple switch that has to be set in
the program check_integrity. Some checks on record level have different
behaviour (less checks) if they are invoked by check_integrity.

=cut

sub running_check_integrity{
   $_[0]->{_running_check_integrity} = $_[1] if defined $_[1];
   return $_[0]->{_running_check_integrity};
}
##############################################################################

=head2 check_status (public)

Checks $apiis->status and prints errors (if any). Optionally dies above a
certain severity level and ignores errors below a certain security level.

Input parameter can be a hash with the keys:

=over 4

=item * B<die> -- you can pass a level of severity to let the program die
        at this point and all levels above (in severity).

=item * B<ignore> -- below this level of severity the error messages are ignored

=back

B<check_status> returns the boolean value of the status stored in
$obj->status().

Example:

   $apiis->check_status(
       die => 'CRIT',
       ignore => 'INFO',
   );

=cut

sub check_status {
    my ( $self, %args ) = @_;
    return if !$self->status;
    return $self->status if !$self->errors;

    my ( %ignore_at, %die_at );
    my @severity_values = Apiis::Errors->severity_values;

    # ignore levels?:
    if ( exists $args{'ignore'} ) {
        my $found1;
        foreach my $val ( reverse @severity_values ) {
            if ( uc $args{'ignore'} eq uc $val ) {
                $ignore_at{$val} = ++$found1;
            }
            else {
                $ignore_at{$val} = 1 if $found1;
            }
        }
        delete $args{'ignore'};
    }

    # die or not:
    my $die_msg;
    if ( exists $args{'die'} ) {
        my $found2;
        foreach my $val (@severity_values) {
            if ( uc $args{'die'} eq uc $val ) {
                $found2++;
                $die_at{$val} = 1;
            }
            else {
                $die_at{$val} = 1 if $found2;
            }
        }
        $die_msg = sprintf "Died at severity level %s on your request\n",
            uc $args{'die'};
        delete $args{'die'};
    }

    my $do_die;
    for my $err ( $self->errors ) {
        my $severity = $err->severity;
        $err->print(%args) if !exists $ignore_at{$severity};
        $do_die++          if  exists $die_at{$severity};
    }

    die longmess($die_msg) if $do_die;
    return $self->status;
}
##############################################################################

=head2 errors (public)

$apiis->errors returns the stored errors as an array of objects or an array
reference, just as requested by the caller.
If new errors are stored, errors() returns the error id(s). If you store
one error object, the error id of this error is returned as a scalar. If
you store an array of error objects, an array or arrayref of the error ids
of these error objects is returned in the order of the error objects.

Examples:
   my $err_id      = $apiis->errors($error_object);
   my @err_ids     = $apiis->errors(@error_objects);
   my $err_ids_ref = $apiis->errors(@error_objects);


=cut

sub errors {
   my ( $self, $input ) = @_;
   # no strict 'refs'; # to allow invocation from all object types
   if ($input) {
      if ( ref $input eq 'Errors' or ref $input eq 'Apiis::Errors' ) {
         # one error object passed directly:
         push @{ $self->{_errors} }, $input;
         # print new error to syslog:
         $apiis->log( lc $input->severity, $input->syslog_print ) if $apiis;
         return $input->id;
      } elsif ( ref $input eq 'ARRAY' ) {
          # arrayref of error objects (should already be printed to syslog):
         push @{ $self->{_errors} }, @{$input};
         my @err_ids;
         foreach my $thiserror ( @{$input} ) {
            push @err_ids, $thiserror->id;
         }
         wantarray && return @err_ids;
         return \@err_ids;
      } else {
         $apiis->status(1);
         $apiis->errors(
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'CRIT',
               from      => 'Apiis::Init->errors',
               msg_short => __('Unknown error type passed'),
            )
         );
      }
   } else {
      return unless defined $self->{_errors};
      wantarray && return @{ $self->{_errors} };
      return $self->{_errors};
   }
}
##############################################################################

=head2 error (public)

$apiis->error takes as parameter an error id and returns the error object
for this id. This enables you to write code like this:

   $apiis->error(3)->print;
   $apiis->error(4)->severity('CRIT');

If you pass an invalid error id, an error object is created and passed back
to the caller.

=cut

sub error {
   my ( $self, $err_id ) = @_;
   if ( defined $err_id ) {
      if ( $err_id =~ /\D/ ) {
         my $err = Apiis::Errors->new(
            type      => 'CODE',
            severity  => 'ERR',
            from      => 'Apiis::Init->error',
            msg_short => __( "Non numeric error id '[_1]' passed", $err_id ),
         );
         $self->status(1);
         $self->errors($err);
         return $err;
      } else {
         for my $thiserr ( $self->errors ) {
            return $thiserr if $thiserr->id == $err_id;
         }
         # when we come here, this err_id does not exist:
         my $err = Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Apiis::Init->error',
            msg_short => __( "error id '[_1]' does not exist", $err_id ),
         );
         $self->status(1);
         $self->errors($err);
         return $err;
      }
   } else {
      my ( $package, $file, $line ) = caller;
      my $err = Apiis::Errors->new(
         type      => 'PARAM',
         severity  => 'ERR',
         from      => 'Apiis::Init->error',
         msg_short => __("no error id passed"),
         msg_long  => "called from package $package, file $file, line $line",
      );
      $self->status(1);
      $self->errors($err);
      return $err;
   }
}
##############################################################################

=head2 del_errors (public)

$apiis->del_errors deletes all error objects.

=cut

sub del_errors { $_[0]->{"_errors"} = undef; }
##############################################################################

=head2 del_error (public)

$apiis->del_error takes as parameter an error id and deletes this error object
from the $apiis->errors array. Example:

   $apiis->del_error(3);

If you pass an invalid error id, an error object is created, added to
$apiis->errors and additionally passed back to the caller.

=cut

sub del_error {
   my ( $self, $err_id ) = @_;
   if ( defined $err_id ) {
      if ( $err_id =~ /\D/ ) {
         my $err = Apiis::Errors->new(
            type      => 'CODE',
            severity  => 'ERR',
            from      => 'Apiis::Init->del_error',
            msg_short => __( "Non numeric error id '[_1]' passed", $err_id ),
         );
         $self->status(1);
         $self->errors($err);
         return $err;
      } else {
         my @errors = $self->errors;
         my $found = 0;
         LOOP: for ( my $i = 0 ; $i <= $#errors ; $i++ ) {
            if ( $errors[$i]->id == $err_id ) {
               splice( @{ $self->errors }, $i, 1 );
               $found++;
               last LOOP;
            }
         }
         if ( not $found ) {
            my $err = Apiis::Errors->new(
               type      => 'PARAM',
               severity  => 'ERR',
               from      => 'Apiis::Init->del_error',
               msg_short => __( "error id '[_1]' does not exist", $err_id ),
            );
            $self->status(1);
            $self->errors($err);
            return $err;
         }
      }
   } else {
      my ( $package, $file, $line ) = caller;
      my $err = Apiis::Errors->new(
         type      => 'PARAM',
         severity  => 'ERR',
         from      => 'Apiis::Init->del_error',
         msg_short => __("no error id passed"),
         msg_long  => "called from package $package, file $file, line $line",
      );
      $self->status(1);
      $self->errors($err);
      return $err;
   }
}
##############################################################################

=head2 localtime (public)

$apiis->localtime provides you with an unformatted timestamp. Usually this
is not used. The preferred methods are $apiis->today and $apiis->now as
they convert the date/time to the localized format.

$apiis->localtime returns a list of parameters. Example:

   my ($year, $mon, $mday, $hour, $min, $sec)
      = $apiis->localtime;

=cut

sub localtime {
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
      localtime(time);
   $year += 1900;
   $mon++;
   $mon  = sprintf "%.2d", $mon;
   $mday = sprintf "%.2d", $mday;
   $hour = sprintf "%.2d", $hour;
   $min  = sprintf "%.2d", $min;
   $sec  = sprintf "%.2d", $sec;
   return ($year, $mon, $mday, $hour, $min, $sec);
}
##############################################################################

=head2 today (public)

$apiis->today returns a formatted string of the current day.

=cut

sub today { return $_[0]->now( format => 'today' ); }

##############################################################################

=head2 now (public)

$apiis->now returns a formatted string of the current day and time.
For internal use it accepts an input parameter

   $apiis->now( format => 'today' );

to return only the day without time. This is the whole magic behind
$apiis->today. :^)

=cut

sub now {
   my $self = shift;
   my %args = @_;
   my $today;
   $today = 1 if exists $args{'format'} and $args{'format'} eq 'today';
   my ($year, $mon, $mday, $hour, $min, $sec) = $self->localtime;

   # formatted strings:
   my (@return_date, @return_time);
   my @conf_date = $self->date_parts;
   for ( my $i = 0 ; $i <= $#conf_date ; $i++ ) {
      $conf_date[$i] eq 'YYYY'
        && ( $return_date[$i] = sprintf( "%04d", $year ) );
      $conf_date[$i] eq 'MM'
        && ( $return_date[$i] = sprintf( "%02d", $mon ) );
      $conf_date[$i] eq 'DD' && ( $return_date[$i] = sprintf( "%02d", $mday ) );
   }
   $return_time[0] = sprintf("%02d", $hour);
   $return_time[1] = sprintf("%02d", $min);
   $return_time[2] = sprintf("%02d", $sec);
   # Catch errors maybe due to incorrect date/time configuration in apiisrc files.
   # Return code ($@) does not matter as there should be an error object anyway.
   my ( $date_sep, $time_sep );
   eval { $date_sep = $apiis->date_sep; $time_sep = $apiis->time_sep };
   $date_sep = '?' unless $date_sep;
   $time_sep = '?' unless $time_sep;

   return join("$date_sep", @return_date) if $today;
   return join("$date_sep", @return_date) . ' ' .  join("$time_sep",@return_time);
}

##############################################################################

=head2 join_model (public)

B<$apiis->join_model("modelfile")> mounts all informations of the model file
into the core apiis structure and provides methods to access them.

As required input you have to provide the key 'userobj'. The value must be a
valid User-object.

Example:

   $apiis->join_model('breedprg',
      userobj => $user_obj,
   );

B<join_model> creates an Apiis::Model object and passes it to _add_obj.
With the key 'Model', the model object is passed as the first and
only element of an anon array reference.

Besides the model file name there is another (hash) parameter 'database' to
B<join_model>.

With 'database => 0', the model file will be joined into $apiis without
connection to the database.  For later joining the database into $apiis, use
the public method B<$apiis->join_database>.

Using B<join_model> without connecting to the database will be
used in quite rare cases. One usefull operation will be when you want to
drop the complete database during basic initialisation.
In this case you have to provide some dummy User object like:

   require Apiis::DataBase::User;
   my $dummy = Apiis::DataBase::User->new(
       id       => ($apiis->os_user || 'nobody'),
       password => 'nopassword',
   );

   $apiis->join_model('breedprg',
      userobj => $dummy,
      database => 0,
   );


=cut

sub join_model {
    my ( $self, $modelname, %args ) = @_;
    my $db_connect = 1;
    $db_connect = $args{'database'} if exists $args{'database'};
    EXIT: {
        if ( ! exists $args{userobj} ) {
            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type      => 'PARAM',
                    severity  => 'CRIT',
                    from      => 'Apiis::Init::join_model',
                    msg_short => __( "Missing parameter [_1]", 'userobj' ),
                )
            );
            last EXIT;
        }

        # do we get a User obj with error status:
        if ( $args{userobj}->status ) {
            $self->status(1);
            $self->errors( scalar $args{userobj}->errors );
            last EXIT;
        }

        require Apiis::Model; # works not with 'use'! Strange.
        my $mod_obj = Apiis::Model->new( model => $modelname, %args );

        # creating of Model object failed:
        if ( not $mod_obj ) {
            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'CRIT',
                    from      => 'Apiis::Init::join_model',
                    msg_short => 'Apiis::Model returned undef',
                    msg_long  =>
                        'Unspecific error while loading the model file',
                )
            );
            last EXIT;
        }

        # object returned error status:
        if ( $mod_obj->status ) {
            $apiis->errors( scalar $mod_obj->errors );
            $apiis->status( $mod_obj->status );
            last EXIT;
        }

        # join Model into $apiis structure:
        my ( $package, $file, $line ) = caller;
        $self->_add_obj(
            Model  => [$mod_obj],
            caller => [ $package, $file, $line ]
        );
        last EXIT if !$apiis->exists_model;

        # set default formpath here to allow later overwriting:
        $apiis->formpath( $apiis->APIIS_LOCAL . '/etc/forms' );

        # overwrite global apiisrc defaults with project specific ones:
        $self->Apiis::Init::Config::_import_apiisrc_local();

        # date (default is ISO):
        $self->check_date_conf(
            order => ( $self->{'_date_order'} || 'YYYY-MM-DD' ),
            sep => $self->{'_date_sep'},
        );
        if ( $self->date_conf_err ) {
            for ( $self->errors ) {
                my $old = $_->from;
                $_->from(qq{while reading apiisrc of project ($old)});
            }
            $apiis->status(1);
            last EXIT;
        }

        # time (default is ISO):
        $self->check_time_conf(
            order => ( $self->{'_time_order'} || 'hh:mm:ss' ),
            sep => $self->{'_time_sep'},
        );
        if ( $self->time_conf_err ) {
            for ( $self->errors ) {
                my $old = $_->from;
                $_->from( qq{while reading global apiisrc ($old)} );
            }
            last EXIT;
        }

        # add methods for [LOCAL] section in project-apiisrc sys-/filelog:
        $self->_section_methods('local');

        # add some compatibility definitions
        $self->_join_compat;

        # ordering/caching logging parameters:
        $self->Cache->fh_close('fh_filelog');
        $self->Cache->_create_filelog_priorities(
            $self->{'_filelog_priority'} )
            if $self->{'_filelog_priority'};
        $self->Cache->_create_syslog_priorities( $self->{'_syslog_priority'} )
            if $self->{'_syslog_priority'};
        last EXIT if $self->status;

        # connect the system user anyway:
        $self->_join_database(\%args);
        last EXIT if $self->status;

        # now the common non-system user:
        if ( $db_connect ) {
            # connect user:
            last EXIT if $apiis->_join_user(\%args);

            # skip authentication completely if configured so:
            if ( $apiis->access_rights eq 'none' ) {
                # connect to the database:
                $apiis->DataBase->connect(
                    user => 'application',
                    %args
                );
                if ( $apiis->DataBase->status ) {
                    $self->status(1);
                    $self->errors( scalar $apiis->DataBase->errors );
                }
                last EXIT;
            }

            # connect with access rights:
            delete $args{'userobj'} if exists $args{'userobj'};
            my $thisuser = $apiis->User->id;

            # user authentication:
            if ( $apiis->join_auth($thisuser) ) {
                # an error occurred:
                $self->status(1);
                if ( $apiis->exists_auth ) {
                    $self->errors( scalar $apiis->Auth->errors );
                    last EXIT;
                }
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'AUTH',
                        severity  => 'ERR',
                        from      => 'Apiis::Init::join_model',
                        msg_short => __("Auth object could not be created"),
                        msg_long  => __(
                            "Authentication for user '[_1]' failed", $thisuser
                        ),
                    )
                );
                last EXIT;
            }

            # connect to the database:
            $apiis->DataBase->connect(
                user => 'application',
                %args
            );
            if ( $apiis->DataBase->status ) {
                $self->status(1);
                $self->errors( scalar $apiis->DataBase->errors );
                last EXIT;
            }
        }
    }    # end label EXIT
    $self->disconnect_project if $self->status;
    return;
}
##############################################################################

=head2 exists_model (public)

$apiis->exists_model returns 1 if the model file is already mounted into the
$apiis structure, 0 otherwise.

=cut

sub exists_model {
    return 1 if exists $_[0]->{"Model"};
    return 0;
}
##############################################################################

=head2 _join_database (internal)

$apiis->_join_database initializes the database access.

It adds the newly created Apiis::DataBase::Init object into the existing
$apiis-tree with the key 'DataBase':

=cut

sub _join_database {
    my ( $self, $args_ref ) = @_;
    require Apiis::DataBase::Init;

    EXIT: {
        if ( not $apiis->exists_model ) {
            my ( $package, $filename, $line ) = caller;
            $self->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'ERR',
                    from      => 'Apiis::Init::_join_database',
                    msg_short => 'First join the model to $apiis',
                    msg_long  => __(
                        "error initiated in [_1] at line [_2]", $filename, $line
                    ),
                )
            );
            $self->status(1);
            last EXIT;
        }

        # only initialize once:
        if ( $apiis->exists_database ) {
            $apiis->log( 'warning', 'join_database: You tried to join the '
                    . 'database structure into $apiis twice, ignored.' );
            last EXIT;
        }

        my $db = Apiis::DataBase::Init->new( %{$args_ref} );
        if ( $db->status ) {
            $apiis->errors( scalar $db->errors );
            $apiis->status( $db->status );
            last EXIT;
        }

        my ( $package, $file, $line ) = caller;
        $self->_add_obj(
            DataBase => [$db],
            caller   => [ $package, $file, $line ]
        );
        last EXIT if $self->status;

        if ( exists $args_ref->{'database'} and $args_ref->{'database'} == 0 ) {
            $apiis->log( 'notice', 'Apiis::DataBase::_init: Object created '
                    . 'without database connection by os_user '
                    . $apiis->os_user );
        }
        else {
            $self->DataBase->_connect_db( %{$args_ref} );
        }
    }
}
##############################################################################

=head2 join_database (public)

$apiis->join_database is simply a public wrapper for _join_database.

The public method join_database is usually not needed as join_model()
automatically joins the database into $apiis. For some rare cases (e.g.
initial creation of database), you can join_model() without connection to
the database by passing the parameter 'database => 0'.

So
   $apiis->join_model('breedprg', database => 0);
   $apiis->join_database;

is equivalent to
   $apiis->join_model('breedprg');

=cut

sub join_database { shift()->_join_database( @_ ); }
##############################################################################

=head2 exists_database (public)

$apiis->exists_database returns 1 if the database initialisation is already
done, 0 otherwise. The existance of the database object does not
necessarily include the database connection. If you invoke join_model with
the parameter 'database => 0' the database object is created without
connecting to the database. This is needed for special cases like mksql,
where you need the configuration data like the db-specific datatype for the
metatypes like TIMESTAMP to create the database.

=cut

sub exists_database {
   return 1 if exists $_[0]->{"DataBase"};
   return 0;
}
##############################################################################
=head2 join_auth (public)

$apiis->join_auth creates a new authentication object and joins it into the $apiis
structure as 'Auth'.

Example:
   my $user = $apiis->os_user;
   $apiis->join_auth($user);

The new access rights setup (Dec. 2005) also allows to pass object types:

   $apiis->join_auth('user_login','obj_type')
   where 'obj_type' can be defined as:
      'STandDBT'  - creates Auth Object for system and database tasks
      'ST'        - creates Auth Object for system tasks
      'DBT'       - creates Auth Object for database tasks

=cut

sub join_auth {
    my ( $self, $objuser, $objtype ) = @_;
    my $localstatus = 1;
    my $auth_obj;
    my $err_msg = 'unknown error';
    my $ar_type = lc $apiis->access_rights;

    EXIT: {
        # access rights completely switched off:
        last EXIT if $ar_type eq 'none';
#         if ( $ar_type eq 'none' ) {
#             eval {
#                 require Apiis::Auth::None;
#                 $auth_obj = Apiis::Auth::None->new();
#             };
# 
#             $@ ? ($err_msg = $@) : ($localstatus = 0);
#             last EXIT;
#         }

        # new access rights (AR) setup (Dec. 2005):
        if ( $ar_type eq 'ar' ) {
            # is this work already done?:
            if ( $apiis->exists_auth ) {
                $apiis->log( 'warning',
                    "join_auth: auth object already exists, ignored." );
                last EXIT;
            }

            $objtype = "Complete Object" if !defined $objtype;
            eval {
                require Apiis::Auth::AR_Auth;
                $auth_obj = Apiis::Auth::AR_Auth->new(
                    auth_user     => $objuser,
                    auth_obj_type => $objtype
                );
            };
            $@ ? ($err_msg = $@) : ($localstatus = 0);
            last EXIT;
        }

        # old access rights (auth) setup:
        if ( $ar_type eq 'auth' ) {
            eval {
                require Apiis::Auth::AppAuth;
                $auth_obj = Apiis::Auth::AppAuth->new( app_user => $objuser );
            };
            $@ ? ($err_msg = $@) : ($localstatus = 0);
        }

        # catch errors:
        if ( !$auth_obj ) {
            $apiis->status(1);
            $apiis->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'CRIT',
                    from      => 'Apiis::Init::join_auth',
                    msg_long  => $err_msg,
                    msg_short =>
                        q{Unspecific error while creating auth object. }
                        . q{Did you configure access_rights in apiisrc?},
                )
            );
            last EXIT;
        }
        if ( $auth_obj->status ) {
            $apiis->status(1);
            $apiis->errors( scalar $auth_obj->errors );
            last EXIT;
        }
    }    # end label EXIT

    # now we succeeded and join the object into the structure:
    if ( !$localstatus ) {
        my ( $package, $file, $line ) = caller;
        $apiis->_add_obj(
            Auth   => [$auth_obj],
            caller => [ $package, $file, $line ]
        );
        $apiis->log( 'info', sprintf
            "Auth object (type '%s', user '%s') joined into apiis-structure",
            $ar_type, $objuser );
    }
    return $localstatus;
}

=head2 exists_auth (public)

B<exists_auth> is a boolean switch to show, if the Auth object for
authentication/authorisation is joined into the global $apiis structure. It is
0/undef, if no Auth object/method exists, 1 otherwise.

=cut

sub exists_auth {
    return 1 if exists $_[0]->{"Auth"};
    return 0;
}
##############################################################################

sub _join_cache {
    my ( $self, %args ) = @_;
    require Apiis::Init::Cache;
    my $cacheobj = Apiis::Init::Cache->new;

    EXIT: {
        if ( not $cacheobj ) {
            $self->status(1);
            $self->errors(
                Apiis::Errors->new(
                    type      => 'CODE',
                    severity  => 'ERR',
                    from      => 'Apiis::Init::_join_cache',
                    msg_short => __("Problems creating new cache object"),
                )
            );
            last EXIT;
        }

        $self->_add_obj(
            Cache  => [$cacheobj],
            caller => [ caller() ]
        );
    }
    $self->Cache->_create_filelog_priorities( $self->{'_filelog_priority'} )
        if $self->{'_filelog_priority'};
    $self->Cache->_create_syslog_priorities( $self->{'_syslog_priority'} )
        if $self->{'_syslog_priority'};
    return;
}
##############################################################################
# provide some compatibility switches and configuration:
sub _join_compat {
   my ( $self, %args ) = @_;
   require Apiis::Init::Compat;
   my $compatobj = Apiis::Init::Compat->new;

   EXIT: {
      if ( not $compatobj ) {
         $self->status(1);
         $self->errors(
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'ERR',
               from      => 'Apiis::Init::_join_compat',
               msg_short => __( "Problems creating new compat object" ),
            )
         );
         last EXIT;
      }

      $self->_add_obj(
         Compat  => [$compatobj],
         caller => [ caller() ]
      );
   }
   return;
}
##############################################################################

=head2 get_db_conf (mainly internal)

Read the config file for the passed Database from
$APIIS_HOME/etc/apiis/<Database>.conf and return a hash reference of this
structure.

=cut

sub get_db_conf { $_[0]->Apiis::Init::Config::_get_db_conf($_[1]); }
##############################################################################

sub DESTROY {
   # empty by intention
   # otherwise AUTOLOAD() would always croak about missing DESTROY() methods.
   # (see Conway p. 168, german edition)
}

=head2 AUTOLOAD (internal)

B<AUTOLOAD()> catches all invocations of methods, that don't exist. On this
level it makes mainly sense for the structural elements Cache, Model,
DataBase, User, etc. It's difficult to catch them otherwise in
expressions like $apiis->Model->tables, when join_model has failed before
and therefore no method Model() exists. This case usually produces Error
objects, but every developer is free to ignore them.

Currently some more or less useful error messages are generated, printed
to STDOUT and the process dies. This is not optimal for processes that run
in a grapical environment (Tk, Html) and don't have access to a terminal.
But does it make sense to create an Error object if the developer tends to
ignore them?

Additionally, the produced error message is stored in the logfile/syslog,
if configured.

=cut

sub AUTOLOAD {
   my $self = shift;
   my @msg;
   $AUTOLOAD =~ /(.*)::(.*)$/;
   my $pack = $1;
   my $meth = $2;
   my $prepend = '>   ';
   # some analyses:
   my @available;
   for my $meth ( qw/ Cache Model DataBase Auth User / ){
      push @available, $meth if $self->can( $meth );
   }

   # now let's create some usefull error message:
   push @msg, "\n";
   push @msg, $prepend .
      __("You requested the unknown method '[_1]' from package '[_2]',\n[_3]invoked [_4]",
      ($meth || $AUTOLOAD), ($pack || $AUTOLOAD), $prepend, shortmess);
   push @msg, $prepend . __("Hint: ");

   if ( $AUTOLOAD eq 'Apiis::Init::User' ) {
      # User:
      push @msg, $prepend . __("Maybe the authentication process failed and no 'User' object was created.");
   } elsif ( $AUTOLOAD eq 'Apiis::Init::Model' ) {
      # Model:
      push @msg, $prepend . __("Maybe joining the model file into the apiis structure failed
[_1]and no 'Model' object was created.", $prepend);
   } elsif ( $AUTOLOAD eq 'Apiis::Init::DataBase' ) {
      # DataBase:
      push @msg, $prepend . __("Maybe joining the database into the apiis structure failed
[_1]and no 'DataBase' object was created.", $prepend);
   } elsif ( $AUTOLOAD eq 'Apiis::Init::Auth' ) {
      # Auth:
      push @msg, $prepend . __("Maybe the authentication process failed
[_1]and no 'Auth' object was created.", $prepend);
   } else {
      push @msg, $prepend . __("Sorry, I could not make a guess about this error. Maybe a typo?");
   }

   if ( @available ){
      push @msg, $prepend . __("Available structural \$apiis methods are: [_1]",
            join(', ', @available));
   }
   push @msg, "\n";
    
   push @msg, $prepend . __("Usually this error is caused by an earlier error,
[_1]which was not caught by the software.", $prepend);
   push @msg, $prepend . __('Please contact your local Apiis representative or
[_1]write a bug report to the development group at
[_1]     apiis-bugs@tzv.fal.de', $prepend, $prepend);
   push @msg, $prepend . __('Please insert at least this error message into your bug report.');
   push @msg, "\n";
   push @msg, $prepend . __('The calling stack of this unknown method follows:.');
   push @msg, $prepend .longmess;
   print join ( "\n", @msg ), "\n";
   $self->log('crit', join ( "\n", @msg ));
   die "\n";
}

##############################################################################

1;

