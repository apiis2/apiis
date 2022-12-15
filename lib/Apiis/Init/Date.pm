##############################################################################
# $Id: Date.pm,v 1.15 2008-09-09 09:59:10 heli Exp $
# most of the methods are documented in Apiis::Init.pm
##############################################################################
package Apiis::Init::Date;
$VERSION = '$Revision: 1.15 $';

use warnings;
use strict;
# use Data::Dumper;
use Carp;
use Date::Calc qw( check_date check_time );

##############################################################################

=head2 $apiis->_check_date_conf (internal)

Internal routine to run some checks on the configured date format.
Sets the _date_parts array in case of success.

=cut

sub _check_date_conf {
   my ( $self, %args ) = @_;

   if ( !%args or !exists $args{'order'} or !exists $args{'sep'} ) {
      my ( $package, $file, $line ) = caller;
      $self->status(1);
      $self->{'_date_conf_err'} = 1;
      $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Apiis::Init::Date::_check_date_conf',
            msg_short => main::__("Required parameters ([_1], [_2]) missing",
                                  'order', 'sep'),
            msg_long => sprintf("Called from package %s in file %s, line %s",
                                $package, $file, $line),
         )
      );
      last EXIT;
   }

   my $sep = $args{'sep'};
   my $order = $args{'order'};
   my ( @conf_date, $local_status );
   my ( $package, $file, $line ) = caller;

   EXIT: {
      if ( $sep eq '' ) {
         # empty separator for YYYYMMDD format:
         if ( $order =~ /[^YMD]/ ){
            my $err_string = $order;
            $err_string =~ tr/YMD//d;
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_date_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid date configuration"),
                  msg_long  => main::__("Unsupported characters in order string '[_1]'", $err_string ),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         if ( length( $order ) ne 8 ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_date_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid date configuration"),
                  msg_long  => main::__("Date order string without separators must be exactly 8 chars long"),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         if ( index( $order, 'YYYY' ) == 0 ) {
            $conf_date[0] = 'YYYY';
            if ( index( $order, 'MM' ) == 4 ) {
               $conf_date[1] = 'MM';
               $conf_date[2] = 'DD';
            } else {
               $conf_date[1] = 'DD';
               $conf_date[2] = 'MM';
            }
         } elsif ( index( $order, 'YYYY' ) == 2 ) {
            $conf_date[1] = 'YYYY';
            if ( index( $order, 'MM' ) == 0 ) {
               $conf_date[0] = 'MM';
               $conf_date[2] = 'DD';
            } else {
               $conf_date[0] = 'DD';
               $conf_date[2] = 'MM';
            }
         } elsif ( index( $order, 'YYYY' ) == 4 ) {
            $conf_date[2] = 'YYYY';
            if ( index( $order, 'MM' ) == 0 ) {
               $conf_date[0] = 'MM';
               $conf_date[1] = 'DD';
            } else {
               $conf_date[0] = 'DD';
               $conf_date[1] = 'MM';
            }
         } else {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_date_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid date configuration"),
                  msg_long  => main::__("Error in date order string without separators"),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
      } else {
         if ( $order =~ /[^${sep}YMD]/ ){
            my $err_string = $order;
            $err_string =~ tr/YMD//sd;
            $err_string =~ s/[$sep]//g; # tr won't accept variables
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_date_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid date configuration"),
                  msg_long  => main::__("Unsupported characters in order string '[_1]'", $err_string ),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         @conf_date = split /[$sep]/, $order;
         if ( length( $order ) ne 10 ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_date_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid date configuration"),
                  msg_long  => main::__("Date order string with separators must be exactly 10 chars long"),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         # ToDo: reduced date formats like YYYY-MM, YYYY-DDD, or year with week of the year
         #       (currently) not supported
         if ( $#conf_date != 2 ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_date_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid date configuration"),
                  msg_long  => main::__("date separator '[_1]' does not split date into 3 parts",
                                  $sep),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
         }
         for ( my $i = 0 ; $i <= $#conf_date ; $i++ ) {
            if ( $conf_date[$i] =~ /Y+/i ) {
               # year part must have 4 digits
               if ( $conf_date[$i] ne 'YYYY' ) {
                  $self->errors(
                     Apiis::Errors->new(
                        type      => 'CONFIG',
                        severity  => 'ERR',
                        from      => 'check_date_conf',
                        data      => "sep: '$sep' order: '$order'",
                        msg_short => main::__("Invalid date configuration"),
                        msg_long  => main::__("Only YYYY year part is allowed (4 digits, upper case)"),
                        backtrace => Carp::longmess('invoked'),
                     )
                  );
                  $local_status = 1;
               }
            }
         }
      }
   }
   if ($local_status) {
      $self->{'_date_conf_err'} = 1;
      $self->status(1);
   } else {
      $self->{'_date_parts'}    = \@conf_date;
      $self->{'_date_conf_err'} = 0;
      $self->{"_date_order"} eq 'YYYY-MM-DD'
        ? ( $self->{"_isodate"} = 1 )
        : ( $self->{"_isodate"} = 0 );
   }
}
##############################################################################

=head2 $apiis->_check_time_conf (internal)

Internal routine to run some checks on the configured time format.
Sets the _time_parts array in case of success.

=cut

sub _check_time_conf {
   my ( $self, %args ) = @_;

   if ( !%args or !exists $args{'order'} or !exists $args{'sep'} ) {
      my ( $package, $file, $line ) = caller;
      $self->status(1);
      $self->{'_time_conf_err'} = 1;
      $self->errors(
         Apiis::Errors->new(
            type      => 'PARAM',
            severity  => 'ERR',
            from      => 'Apiis::Init::Date::_check_time_conf',
            msg_short => main::__("Required parameters ([_1], [_2]) missing",
                                  'order', 'sep'),
            msg_long => sprintf("Called from package %s in file %s, line %s",
                                $package, $file, $line),
         )
      );
      last EXIT;
   }

   my $sep = $args{'sep'};
   my $order = $args{'order'};
   my ( @conf_time, $local_status );
   my ( $package, $file, $line ) = caller;

   EXIT: {
      if ( $sep eq '' ) {
         # empty separator for hhmmss format:
         if ( $order =~ /[^hms]/ ){
            my $err_string = $order;
            $err_string =~ tr/hms//d;
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_time_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid time configuration"),
                  msg_long  => main::__("Unsupported characters in order string '[_1]'", $err_string ),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         if ( length( $order ) ne 6 ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_time_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid time configuration"),
                  msg_long  => main::__("time order string without separators must be exactly 6 chars long"),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         $order eq 'hhmmss' && (@conf_time = qw/ hh mm ss /);
         $order eq 'hhssmm' && (@conf_time = qw/ hh ss mm /);
         $order eq 'mmhhss' && (@conf_time = qw/ mm hh ss /);
         $order eq 'sshhmm' && (@conf_time = qw/ ss hh mm /);
         $order eq 'mmsshh' && (@conf_time = qw/ mm ss hh /);
         $order eq 'ssmmhh' && (@conf_time = qw/ ss mm hh /);
         unless ( @conf_time ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_time_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid time configuration"),
                  msg_long  => main::__("Error in time order string without separators"),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
      } else {
         if ( $order =~ /[^${sep}hms]/ ){
            my $err_string = $order;
            $err_string =~ tr/hms//sd;
            $err_string =~ s/[$sep]//g; # tr won't accept variables
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_time_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid time configuration"),
                  msg_long  => main::__("Unsupported characters in order string '[_1]'", $err_string ),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         @conf_time = split /[$sep]/, $order;
         if ( length( $order ) ne 8 ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_time_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid time configuration"),
                  msg_long  => main::__("time order string with separators must be exactly 8 chars long"),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
            last EXIT;
         }
         if ( $#conf_time != 2 ) {
            $self->errors(
               Apiis::Errors->new(
                  type      => 'CONFIG',
                  severity  => 'ERR',
                  from      => 'check_time_conf',
                  data      => "sep: '$sep' order: '$order'",
                  msg_short => main::__("Invalid time configuration"),
                  msg_long  => main::__("Time separator '[_1]' does not split time into 3 parts",
                                  $sep),
                  backtrace => Carp::longmess('invoked'),
               )
            );
            $local_status = 1;
         }
      }
   }
   if ($local_status) {
      $self->{'_time_conf_err'} = 1;
      $self->status(1);
   } else {
      $self->{'_time_parts'}    = \@conf_time;
      $self->{'_time_conf_err'} = 0;
      $self->{"_time_order"} eq 'hh:mm:ss'
        ? ( $self->{"_isotime"} = 1 )
        : ( $self->{"_isotime"} = 0 );
   }
}

##############################################################################

sub _date_order {
   my ( $self, %args ) = @_;
   EXIT: {
      if ( %args ) {
         if ( !exists $args{'order'} or !exists $args{'sep'} ) {
            my ( $package, $file, $line ) = caller;
            $self->status(1);
            $self->errors(
               Apiis::Errors->new(
                  type      => 'PARAM',
                  severity  => 'ERR',
                  from      => 'Apiis::Init::date_order',
                  msg_short => main::__("Required parameters ([_1], [_2]) missing",
                                  'order', 'sep'),
                  msg_long  => sprintf ("Called from package %s in file %s, line %s",
                                        $package, $file, $line ),
               )
            );
            last EXIT;
         }
         my %old_args;
         $self->Apiis::Init::Date::_check_date_conf(%args);
         $old_args{'order'} = $self->{"_date_order"};
         $old_args{'sep'} = $self->{"_date_sep"};
         $self->{"_date_order"} = $args{'order'};
         $self->{"_date_sep"} = $args{'sep'};
         if ( $args{'order'} eq 'YYYY-MM-DD' ) {
            $self->{"_isodate"} = 1;
         } else {
            $self->{"_isodate"} = 0;
         }
         return \%old_args;
      }
   }
   return $self->{"_date_order"};
}

##############################################################################
sub _time_order {
   my ( $self, %args ) = @_;
   EXIT: {
      if ( %args ) {
         if ( !exists $args{'order'} or !exists $args{'sep'} ) {
            my ( $package, $file, $line ) = caller;
            $self->status(1);
            $self->errors(
               Apiis::Errors->new(
                  type      => 'PARAM',
                  severity  => 'ERR',
                  from      => 'Apiis::Init::time_order',
                  msg_short => main::__("Required parameters ([_1], [_2]) missing",
                                  'order', 'sep'),
                  msg_long  => sprintf ("Called from package %s in file %s, line %s",
                                        $package, $file, $line ),
               )
            );
            last EXIT;
         }
         my %old_args;
         $self->Apiis::Init::Date::_check_time_conf(%args);
         $old_args{'order'} = $self->{"_time_order"};
         $old_args{'sep'} = $self->{"_time_sep"};
         $self->{"_time_order"} = $args{'order'};
         $self->{"_time_sep"} = $args{'sep'};
         if ( $args{'order'} eq 'hh:mm:ss' ) {
            $self->{"_isotime"} = 1;
         } else {
            $self->{"_isotime"} = 0;
         }
         return \%old_args;
      }
   }
   return $self->{"_time_order"};
}

##############################################################################
=head2 $apiis->date_parts (public)

B<date_parts()> is a readonly public methods that returns an array (or an
arrayref, depending on the invoking context) of the configured parts of the
date format in the correct order (e.g. ["YYYY", "MM", "DD"]).

This method is mainly usefull in internal date calculations.

=cut

sub _date_parts {
    my $class;
    $main::apiis ? ( $class = $main::apiis ) : ( $class = shift );
    return if !$class;
    return if $class->date_conf_err;
    wantarray && return @{ $class->{'_date_parts'} };
    return $class->{'_date_parts'};
}

##############################################################################
=head2 $apiis->time_parts (public)

B<time_parts()> is a readonly public methods that returns an array (or an
arrayref, depending on the invoking context) of the configured parts of the
time format in the correct order (e.g. ["hh", "mm", "ss"]).

This method is mainly usefull in internal date calculations.

=cut

sub _time_parts {
   return if $_[0]->date_conf_err;
   wantarray && return @{$main::apiis->{'_time_parts'}};
   return $main::apiis->{'_time_parts'};
}

##############################################################################
sub _extdate2iso {
    my ( $self, $extdate ) = @_;
    return unless defined $extdate;
    return if $extdate eq '';
    my ( @return_date, @iso_time, $local_status, $datesep );

    EXIT: {
        if ( $self->date_conf_err ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'extdate2iso',
                    data      => $extdate,
                    msg_short => main::__(
                        "Processing stopped due to invalid date configuration"),
                )
            );
            $local_status = 1;
            last EXIT;
        }
        # separate date and time:
        my ( $date, $time ) = split /\s+/, $extdate;
        @iso_time = $self->Apiis::Init::Date::_exttime2iso($time) if $time;

        my @date;
        my @conf_date = $self->date_parts;
        $datesep = $main::apiis->date_sep;
        if ( $datesep eq '' ) {
            if ( $date =~ /\D/ ) {
                my $err_string = $date;
                $err_string =~ tr/0-9//d;
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DATA',
                        severity  => 'ERR',
                        from      => 'extdate2iso',
                        data      => $extdate,
                        msg_short => main::__("Wrong date format"),
                        msg_long  => main::__(
                            "Unsupported characters in order string '[_1]'",
                            $err_string
                        ),
                    )
                );
                $local_status = 1;
                last EXIT;
            }
            if ( length($date) != 8 ) {
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DATA',
                        severity  => 'ERR',
                        from      => 'extdate2iso',
                        data      => $extdate,
                        msg_short => main::__("Wrong date format"),
                        msg_long  =>
                            main::__("Date length without separator must be 8"),
                    )
                );
                $local_status = 1;
                last EXIT;
            }
            my $template;
            $template = 'a4a2a2' if $conf_date[0] eq 'YYYY';
            $template = 'a2a4a2' if $conf_date[1] eq 'YYYY';
            $template = 'a2a2a4' if $conf_date[2] eq 'YYYY';
            @date = unpack $template, $extdate;
        }
        else {
            @date = split /[$datesep]/, $date;    # [] to catch . as sep
            for my $part (@date) {
                my $err_string = $part;
                $err_string =~ tr/0-9//d;
                if ($err_string) {
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DATA',
                            severity  => 'ERR',
                            from      => 'extdate2iso',
                            data      => $extdate,
                            msg_short => main::__("Wrong date format"),
                            msg_long  => main::__(
                                "Unsupported characters in date part: '[_1]'",
                                $err_string
                            ),
                        )
                    );
                    $local_status = 1;
                    last EXIT;
                }
            }
        }

        if ( $#date != 2 ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'extdate2iso',
                    data      => "sep: '$datesep' data: $extdate",
                    msg_short => main::__("Wrong date format"),
                    msg_long  => main::__("Could not split date into 3 parts"),
                )
            );
            $local_status = 1;
            last EXIT;
        }
        for ( my $i = 0; $i <= $#conf_date; $i++ ) {
            if ( $conf_date[$i] eq 'YYYY' ) {
                # year part:
                if ( length( $date[$i] ) != 4 ) {
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DATA',
                            severity  => 'ERR',
                            from      => 'extdate2iso',
                            data      => $extdate,
                            msg_short => main::__("Wrong date format"),
                            msg_long  => main::__(
                                "Only 4 digit years are allowed ([_1])",
                                $date[$i]
                            ),
                        )
                    );
                    $local_status = 1;
                    last EXIT;
                }
                $return_date[0] = $date[$i];
            }
            elsif ( $conf_date[$i] eq 'MM' ) {
                # month part:
                if ( length( $date[$i] ) > 2 ) {
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DATA',
                            severity  => 'ERR',
                            from      => 'extdate2iso',
                            data      => $extdate,
                            msg_short => main::__("Wrong date format"),
                            msg_long  => main::__(
                                "Length of month part ([_1]) exceeds 2",
                                $date[$i]
                            ),
                        )
                    );
                    $local_status = 1;
                    last EXIT;
                }
                $return_date[1] = $date[$i];
            }
            elsif ( $conf_date[$i] eq 'DD' ) {
                if ( length( $date[$i] ) > 2 ) {
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DATA',
                            severity  => 'ERR',
                            from      => 'extdate2iso',
                            data      => $extdate,
                            msg_short => main::__("Wrong date format"),
                            msg_long  => main::__(
                                "Length of day part ([_1]) exceeds 2",
                                $date[$i]
                            ),
                        )
                    );
                    $local_status = 1;
                    last EXIT;
                }
                # day part:
                $return_date[2] = $date[$i];
            }
            else {
                # Error:
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DATA',
                        severity  => 'ERR',
                        from      => 'extdate2iso',
                        data      => $date[$i],
                        msg_short => main::__("Wrong date format"),
                        msg_long  => main::__("Unspecified error"),
                    )
                );
                $local_status = 1;
                last EXIT;
            }
        }
        # check if date is valid:
        if ( not check_date(@return_date) ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'extdate2iso',
                    data      => $extdate,
                    msg_short => main::__("Not a valid date"),
                )
            );
            $local_status = 1;
            last EXIT;
        }
    }
    if ($local_status) {
        $self->status(1);
        return;
    }

    # format date:
    $return_date[0] = sprintf( "%04d", $return_date[0] );
    $return_date[1] = sprintf( "%02d", $return_date[1] );
    $return_date[2] = sprintf( "%02d", $return_date[2] );

    # return an array with year, month, day, hour, minute, second:
    return ( @return_date, @iso_time ) if wantarray;

    if (@iso_time) {
        return join( '-', @return_date ) . ' ' . join( ':', @iso_time );
    }
    else {
        return join( '-', @return_date );
    }
}

##############################################################################
sub _iso2extdate {
   my ( $self, $isodate ) = @_;
   return unless defined $isodate;
   return if $isodate eq '';
   my ( @iso_date, @return_date, $return_time, $local_status );
   my $date_sep = $main::apiis->date_sep;

   EXIT: {
      if ( $self->date_conf_err ) {
         $self->errors(
            Apiis::Errors->new(
               type      => 'DATA',
               severity  => 'ERR',
               from      => 'iso2extdate',
               data      => $isodate,
               msg_short => main::__("Processing stopped due to invalid date configuration"),
            )
         );
         $local_status = 1;
         last EXIT;
      }
      # no conversion needed if everything relies on iso.
      return $isodate if $self->isodate and $self->isotime and not wantarray;

      # no conversion needed if everything relies on iso.
      my ( $split_date, $split_time ) = split /\s+/, $isodate;
      my @iso_time;
      # array context always return ISO order:
      @iso_time = $self->Apiis::Init::Date::_iso2exttime($split_time)
        if $split_time;
      my @iso_date = split /-/, $split_date;
      $iso_date[0] = sprintf( "%04d", $iso_date[0] );    # year
      $iso_date[1] = sprintf( "%02d", $iso_date[1] );    # month
      $iso_date[2] = sprintf( "%02d", $iso_date[2] );    # day

      # Attention!
      # Also for _iso2extdate we return in ISO-order in *array context*.
      # This is only a programmer interface.
      # See 'perldoc $APIIS_HOME/lib/Apiis/Init.pm'.
      return ( @iso_date, @iso_time ) if wantarray;

      # no isodate and no array context:
      $return_time = $self->Apiis::Init::Date::_iso2exttime($split_time)
        if $split_time;

      my @conf_date = $self->date_parts;
      for ( my $i = 0 ; $i <= $#conf_date ; $i++ ) {
         $conf_date[$i] eq 'YYYY'
           && ( $return_date[$i] = sprintf( "%04d", $iso_date[0] ) );
         $conf_date[$i] eq 'MM'
           && ( $return_date[$i] = sprintf( "%02d", $iso_date[1] ) );
         $conf_date[$i] eq 'DD'
           && ( $return_date[$i] = sprintf( "%02d", $iso_date[2] ) );
      }
   }
   if ( $local_status ){
      $self->status(1);
      return;
   }
   if ( $return_time ){
      return join("$date_sep", @return_date) . ' ' . $return_time;
   } else {
      return join("$date_sep", @return_date);
   }
}

##############################################################################
sub _exttime2iso {
    my ( $self, $exttime ) = @_;
    return unless defined $exttime;
    return if $exttime eq '';
    my ( @return_time, @isodate, $local_status, $timesep );

    EXIT: {
        if ( $self->time_conf_err ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'exttime2iso',
                    data      => $exttime,
                    msg_short =>
                        main::__("Processing stopped due to invalid time configuration"),
                )
            );
            $local_status = 1;
            last EXIT;
        }
        if ( $exttime =~ /\s/ ) {
            my ( $date, $time ) = split /\s+/, $exttime;
            @isodate = $self->Apiis::Init::Date::_extdate2iso($date) if $date;
            $exttime = $time unless $self->date_conf_err;
        }

        my @time;
        my @conf_time = $self->time_parts;
        $timesep = $main::apiis->time_sep;
        if ( $timesep eq '' ) {
            if ( $exttime =~ /\D/ ) {
                my $err_string = $exttime;
                $err_string =~ tr/0-9//d;
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DATA',
                        severity  => 'ERR',
                        from      => 'exttime2iso',
                        data      => $exttime,
                        msg_short => main::__("Wrong time format"),
                        msg_long  =>
                            main::__("Unsupported characters in order string '[_1]'",
                            $err_string
                        ),
                    )
                );
                $local_status = 1;
                last EXIT;
            }
            if ( length($exttime) != 6 ) {
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DATA',
                        severity  => 'ERR',
                        from      => 'exttime2iso',
                        data      => $exttime,
                        msg_short => main::__("Wrong time format"),
                        msg_long =>
                            main::__("time length without separator must be 6"),
                    )
                );
                $local_status = 1;
                last EXIT;
            }
            @time = unpack 'a2a2a2', $exttime;
        }
        else {
            my @tmp_time;
            @tmp_time = split /[$timesep]/, $exttime;    # [] to catch . as sep
            # remove empty fields:
            for my $idx ( 0 .. $#tmp_time ) {
                push @time, $tmp_time[$idx]
                    if defined $tmp_time[$idx] and $tmp_time[$idx] ne '';
            }
            PART:
            for my $part (@time) {
                my $err_string = $part;
                $err_string =~ tr/0-9//d;
                if ($err_string) {
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'DATA',
                            severity  => 'ERR',
                            from      => 'exttime2iso',
                            data      => $exttime,
                            msg_short => main::__("Wrong time format"),
                            msg_long  =>
                                main::__("Unsupported characters in time part: '[_1]'",
                                $err_string
                            ),
                        )
                    );
                    $local_status = 1;
                    last EXIT;
                }
            }
        }

        if ( $#time != 2 ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'exttime2iso',
                    data      => "sep: '$timesep' data: $exttime",
                    msg_short => main::__("Wrong time format"),
                    msg_long  => main::__("Could not split time into 3 parts"),
                )
            );
            $local_status = 1;
            last EXIT;
        }
        for ( my $i = 0; $i <= $#conf_time; $i++ ) {
            if ( $conf_time[$i] eq 'hh' ) {
                # hours:
                $return_time[0] = $time[$i];
            }
            elsif ( $conf_time[$i] eq 'mm' ) {
                # minutes:
                $return_time[1] = $time[$i];
            }
            elsif ( $conf_time[$i] eq 'ss' ) {
                # seconds:
                $return_time[2] = $time[$i];
            }
            else {
                # Error:
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'DATA',
                        severity  => 'ERR',
                        from      => 'exttime2iso',
                        data      => $time[$i],
                        msg_short => main::__("Wrong time format"),
                        msg_long  => main::__("Unspecified error"),
                    )
                );
                $local_status = 1;
                last EXIT;
            }
        }
        if ( not check_time(@return_time) ) {
            $self->errors(
                Apiis::Errors->new(
                    type      => 'DATA',
                    severity  => 'ERR',
                    from      => 'exttime2iso',
                    data      => $exttime,
                    msg_short => main::__("Not a valid time"),
                )
            );
            $local_status = 1;
            last EXIT;
        }
    }
    if ($local_status) {
        $self->status(1);
        return;
    }

    # format the time:
    $_ = sprintf( "%02d", $_ ) for @return_time;

    if (@isodate) {
        wantarray && return ( @isodate, @return_time );
        return join( '-', @isodate ) . ' ' . join( ':', @return_time );
    }
    else {
        wantarray && return (@return_time);
        return join( ':', @return_time );
    }
}

##############################################################################
sub _iso2exttime {
   my ( $self, $isotime ) = @_;
   return unless defined $isotime;
   return if $isotime eq '';
   my ( @iso_time, @return_time, $return_time, $split_date, $ext_date, $local_status );
   my $time_sep = $main::apiis->time_sep;

   EXIT: {
      if ( $self->time_conf_err ) {
         $self->errors(
            Apiis::Errors->new(
               type      => 'DATA',
               severity  => 'ERR',
               from      => 'iso2exttime',
               data      => $isotime,
               msg_short => main::__("Processing stopped due to invalid time configuration"),
            )
         );
         $local_status = 1;
         last EXIT;
      }

      # if we accidentely have date *and* time:
      if ( $isotime =~ /\s/ ) {
         ( $split_date, $isotime ) = split /\s+/, $isotime;
      }

      @iso_time = split /:/, $isotime;
      if ( scalar @iso_time != 3 ) {
         $self->errors(
            Apiis::Errors->new(
               type      => 'DATA',
               severity  => 'ERR',
               from      => 'iso2exttime',
               data      => $isotime,
               msg_short => main::__("Incorrect ISO time"),
            )
         );
         $local_status = 1;
         last EXIT;
      }
      my @conf_time = $self->time_parts;
      for ( my $i = 0 ; $i <= $#conf_time ; $i++ ) {
         $conf_time[$i] eq 'hh'
           && ( $return_time[$i] = sprintf( "%02d", $iso_time[0] ) );
         $conf_time[$i] eq 'mm'
           && ( $return_time[$i] = sprintf( "%02d", $iso_time[1] ) );
         $conf_time[$i] eq 'ss'
           && ( $return_time[$i] = sprintf( "%02d", $iso_time[2] ) );
      }
   }
   if ( $local_status ){
      $self->status(1);
      return;
   }

   if ($split_date) {
      if (wantarray) {
         # Note: in array context date and time always return in ISO order!
         my @return_date = $self->Apiis::Init::Date::_iso2extdate($split_date);
         return ( @return_date, @iso_time );
      } else {
         $ext_date = $self->Apiis::Init::Date::_iso2extdate($split_date);
         return $ext_date . ' ' . join( "$time_sep", @return_time );
      }
   } else {
      wantarray && return (@iso_time);
      return join( "$time_sep", @return_time );
   }
}

##############################################################################
1;
