##############################################################################
# $Id: Misc.pm,v 1.16 2010-05-27 09:27:49 popreport Exp $
##############################################################################
package Apiis::Misc;
$VERSION = '$Revision: 1.16 $';
##############################################################################

use strict;
use warnings;
use FindBin qw($RealBin);
use List::Util qw( first );
use File::Basename;
require Exporter;
# use apiis_alib qw (mimetype);
use MIME::Types;
use File::Type;

# symbols to export on request
@Apiis::Misc::EXPORT_OK = qw(
  show_progress mychomp elapsed
  is_true
  Info Error
  LocalToRawDate RawToLocalDate Decode_Date_NativeRDBMS
  find_pod_path file2variable mimetype_of
  MaskForLatex
);

# export/import groups
%Apiis::Misc::EXPORT_TAGS = (
   Tk   => [qw( Info Error )],
   date => [qw( LocalToRawDate RawToLocalDate Decode_Date_NativeRDBMS )],
   all  => [
      qw( show_progress mychomp elapsed is_true
      Info Error
      LocalToRawDate RawToLocalDate Decode_Date_NativeRDBMS
      find_pod_path file2variable mimetype_of
      MaskForLatex
      )
   ],
);

@Apiis::Misc::ISA = qw( Exporter );

our $apiis;
*apiis = \$main::apiis;

=head1 NAME

Apiis::Misc -- Provides some usefull subroutines, mainly for compatibility reasons

=head1 SYNOPSIS

   use Apiis::Misc qw( <subroutine_name> );

=head1 DESCRIPTION

Apiis::Misc gives you access to the subroutines (not object methods!):

   show_progress mychomp elapsed is_true
   Info Error
   LocalToRawDate RawToLocalDate Decode_Date_NativeRDBMS
   find_pod_path file2variable mimetype_of

You can load some of them by writing:

   use Apiis::Misc qw( show_progress mychomp );

They are also grouped:

   use Apiis::Misc qw( :Tk );    # exports the Tk routines Info and Error
   use Apiis::Misc qw( :date );  # exports the date routines
   use Apiis::Misc qw( :all );   # exports all routines

=head1 Subroutines

=head2 show_progress

B<show_progress> gives you some kind of progress view. It prints a dot every $mod
times (default 100), every $mod*10 times it prints the number.
   input:  1.) a reference to the counter (usually starting with 1).
           2.) optional: modulus operator $mod
   return: none. The counter has to be incremented outside this routine!

=cut

sub show_progress {
   my ( $counter_ref, $mod ) = @_;
   $mod = 100 unless $mod;
   print '.' unless $$counter_ref%${mod};
   print " --> $$counter_ref\n" unless $$counter_ref%(${mod} *10);
}


##############################################################################

=head2  MaskForLatex 

Creates Escape-sequences for print in latex

=cut

sub MaskForLatex {
	my $text=shift;

    if (!defined $text) {
	      $text='';
	      return $text;
	}   
    
    $text=~s/([_%&'])/\\$1/g;
    $text=~s/µ/\$\\mu\$/g;
    $text=~s/\|/\$|\$/g;
    $text=~s/\#/\\#/g;
    $text=~s/\^/\\\^\{\}/g;
	return $text;
}
##############################################################################

=head2 mychomp

By: Chris Nandor (from the Perl Function Repository)
removes end-of-line regardless of originating platform
of file

=cut

sub mychomp {
   return unless @_;
   local ($/) = ( $_[0] =~ /(\015?\012|\015)\z/ );
   chomp @_;
}
##############################################################################

=head2 Info

show an Tk-Info window

  usage: Info("Infomessage");

=cut

sub Info {
      my $message = shift;
      if ( defined $main::top ){
         my $d = $main::top->Dialog(-title=> __("Info"),
                              -bitmap=>"info",
                              -text=> $message );
         $d->Show;
      } else {
         print STDERR $message,"\n";
      }
      return;
}
###########################################################################

=head2 Error

show an error window

  usage: Error("Errormessage");

=cut

sub Error {
   my $message = shift;
   if ( defined $main::top ){
      my $d = $main::top->Dialog(-title=> __("Error"),
                           -bitmap=>"error",
                           -text=> $message );
      $d->Show;
   } else {
      print STDERR $message,"\n";
   }
   return;
}
##############################################################################

=head2 LocalToRawDate

Date conversion.

Standard SQL format seems to be 'DD-MON-YYYY', e.g. '24-MAY-2000'. At
least PostgreSQL and Oracle6 accept this.
As long as DBI/DBD does not convert different date formats to the standard
formats of the databases we have to provide this conversion in apiis.
Date::Calc has date formats EU (european format day-month-year) and US
(US american format month-day-year)
   input:  type of local dateformat [EU|US]
           local date
   return: old version (before Aug. 2001):
           date in native database format or -1 in case of errors
           LocalToRawDate('EU', '24.5.2000') will return '24-MAY-2000'.
           new version:
           list of ( "new_date_string", $status, $err_msg )
           LocalToRawDate('EU', '24.5.2000') will return ('24-MAY-2000',0,undef).

Note: This is old stuff and remains here only for compatibility reasons. It
will be removed in the near future. (2005-02-28 heli)

=cut

sub LocalToRawDate {
   my ($format, $localdate) = @_;
   my ($dd, $mm, $month, $yyyy);
   my $status = 1;
   my $err_msg;
   
   if ( defined $localdate and $localdate ne '' ){
      use Date::Calc qw( Month_to_Text Decode_Date_EU Decode_Date_US );
      if ( $format eq 'EU' ) {
         if ( ($yyyy, $mm, $dd) = Decode_Date_EU( $localdate ) ) {
            $status = 0;
         } else { $err_msg = "Malformed date: $localdate"; }
      } elsif ( $format eq 'US' ) {
         if ( ($yyyy, $mm, $dd) = Decode_Date_US( $localdate ) ) {
            $status = 0;
         } else { $err_msg = "Malformed date: $localdate"; }
      } else {
        $err_msg = "Unknown format in LocalToRawDate: $format";
      }
      $month = Month_to_Text($mm) unless $status;
      if ( wantarray ){  # new extended version
         if ( $status ){
            return (undef, $status, $err_msg);
         } else {
            return ( "$dd-$month-$yyyy" , $status, $err_msg);
         }
      } else { # old version
         if ( $status ){
            return -1;
         } else {
            return "$dd-$month-$yyyy";
         }
      }
   } else { # NULL value allowed
      if ( wantarray ){
         return (undef, 0, undef);
      } else {
         return undef;
      }
   }
}
##############################################################################

=head2 RawToLocalDate

RawToLocalDate - change native database date format to EU/US-format (Date::Calc)
   input:  type of local dateformat [EU|US]
           native database date
   return: date in local format or -1 in case of errors

RawToLocalDate('EU', '24-MAY-2000') will return '24.5.2000'.

Note: This is old stuff and remains here only for compatibility reasons. It
will be removed in the near future. (2005-02-28 heli)

=cut

sub RawToLocalDate {
   my ($format, $nativedate) = @_;
   my ($dd1, $mm1, $yyyy1);
   my ($dd, $mm, $yyyy);
   our $apiis;

   return undef if not defined $nativedate or $nativedate eq '';

   use Date::Calc qw( Month_to_Text Decode_Date_EU Decode_Date_US );
   # my %settings = %{ DBspecific( $db_driver ) }; # get date format from Database.pm
   # my $sep = $settings{FORMAT}{DATESEP};
   # my $order = $settings{FORMAT}{DATEORDER};
   my $sep = $apiis->DataBase->datesep;
   my $order = $apiis->DataBase->dateorder;

   if ( $order =~ /YY+${sep}M+${sep}D+/i ) {
      ($yyyy1, $mm1, $dd1) = split /$sep/, $nativedate;
   } elsif ( $order =~ /M+${sep}D+${sep}YY+/i ) {
      ($mm1, $dd1, $yyyy1) = split /$sep/, $nativedate;
   } elsif ( $order =~ /D+${sep}M+${sep}YY+/i ) {
      ($dd1, $mm1, $yyyy1) = split /$sep/, $nativedate;
   }
   
   my $month;
   if ( $format eq 'US' ) {
      ($yyyy, $mm, $dd) = Decode_Date_US( "${mm1}-${dd1}-${yyyy1}" );
      $month = Month_to_Text($mm);
      return "$month-$dd-$yyyy";
   } elsif ( $format eq 'EU' ) {
      ($yyyy, $mm, $dd) = Decode_Date_EU( "${dd1}-${mm1}-${yyyy1}" );
      $month = Month_to_Text($mm);
      return "$dd-$month-$yyyy";
   }
   return $nativedate;  # fallback
}
##############################################################################

=head2 Decode_Date_NativeRDBMS

This sub is used like Decode_Date_EU and Decode_Date_US, where 'EU' and 'US'
is set in apiisrc. For check_integrity only the native date values from the
database is used. It takes DATESEP and DATEORDER from the definitions in
Database.pm and parsed the passed date (which is in DATEORDER). It returns
($year, $month, $day) like the Decode_Date_ routines from Date::Calc.

Example: ($year, $month, $day) = Decode_Date_NativeRDBMS('1999-5-13')

Note: This is old stuff and remains here only for compatibility reasons. It
will be removed in the near future. (2005-02-28 heli)

=cut

sub Decode_Date_NativeRDBMS {
   my $date = shift;
   return () unless (defined $date and $date ne '');
   our $apiis;
   # use Database;
   # my %settings = %{ DBspecific( $db_driver ) }; # get date format from Database.pm
   # my $sep = $settings{FORMAT}{DATESEP};
   # my $order = $settings{FORMAT}{DATEORDER};
   my $sep = $apiis->DataBase->datesep;
   my $order = $apiis->DataBase->dateorder;
   my %parse;
   my @names = split /$sep/, $order;
   my @values = split /$sep/, $date;
   foreach ( @names ){
      $parse{$_} = shift @values;
   }
   my ($year, $month, $day);
   foreach ( keys %parse ){
      $year  = $parse{$_} if /y/i;
      $month = $parse{$_} if /m/i;
      $day   = $parse{$_} if /d/i;
   }
   if ( $year and $month and $day ){
      return ($year,$month,$day);
   } else {
      return ();
   }
}
##############################################################################

=head2 elapsed

do some profiling:
   input:  array reference with entries in order of Now()
   output: String "Hours:Minutes:Seconds" elapsed since passed start time 

=cut

sub elapsed {
   my $start_ref = shift;
   my @nowtime   = $apiis->now;
   my ( $Dd, $Dh, $Dm, $Ds ) = Date::Calc::Delta_DHMS(
      $start_ref->[0], $start_ref->[1], $start_ref->[2], $start_ref->[3],
      $start_ref->[4], $start_ref->[5], $nowtime[0],     $nowtime[1],
      $nowtime[2],     $nowtime[3],     $nowtime[4],     $nowtime[5]
   );
   return "$Dh:$Dm:$Ds";
}
##############################################################################

=head2 is_true

B<is_true> tests the passed scalar value, if it is true or false in the
boolean sense.

False are:

   * undef
   * 0       (zero, either as number or as string of length 1)
   * ''      (the empty string)
   * all other strings and numbers that are not true

True are:

   * all numbers different from 0
   * the number 0E0 is zero, but true (Perl internal)
   * all strings, which are defined as representing true like
     'true', 'yes'. For different languages you can add the according string
     for 'yes' like 'ja' in german.
     Only the first character of the string in lowercase is checked.

   input:  any scalar value that has to be checked for being true or not

   return: 1 if the passed value is true, 0 or undef or the empty string
           otherwise

=cut

sub is_true {
    my $val = shift;
    return if !$val;

    my %the_truth = (
        'true' => undef,
        'y' => undef,
        '1' => undef,
        0E0 => undef, # zero but true
    );
    # add language specific true strings:
    my $lang = $main::apiis->language;
    $lang eq 'de' && ($the_truth{'j'} = undef); # ja
    $lang eq 'fr' && ($the_truth{'o'} = undef); # oui
    $lang eq 'es' && ($the_truth{'s'} = undef); # si

    return 1 if exists $the_truth{ lc $val };
    return 1 if exists $the_truth{ lc substr( $val, 0, 1 ) };
    return;
}
##############################################################################

=head2 find_pod_path

B<find_pod_path> tries to find the appropriate Perl POD documentation for the
invoked programm. It first looks for language specific pod-files (taking
$apiis->language) and continues the search to the less specific versions. Last
ressort is the program itself:

    <programname>_<lang>.pod
    <programname>.<lang>.pod
    <programname>.pod
    <programname>

The <programname> contains the complete path, found by the Perl core module
FindBin.

=cut

sub find_pod_path {
    my $program = basename($0);
    my $lang    = $apiis->language;
    my @choices = (
        "${RealBin}/${program}_${lang}.pod",
        "${RealBin}/${program}.${lang}.pod",
        "${RealBin}/${program}.pod",
        "${RealBin}/${program}",
    );
    return first { -f $_ } @choices;
}
##############################################################################

=head2 file2variable

B<file2variable> loads file from the local file system and tries to guess its
mime-type

   input:  file name
   return: scalar with the file content and scalar with the mime-type

=cut

sub file2variable {
    my $file_name = shift;
    my ( $mimetype, $buffer, $data );
    eval {
        open( FILE, "<$file_name" )
            or &{
                $apiis->log( 'warning', "file2variable: Missing file $file_name" );
                die __( "Missing file:[_1]", $file_name );
            };

        while ( read( FILE, $data, 1024 ) ) {
            $buffer .= $data;
        }
        close FILE;

        if ( !$buffer ) {
            $apiis->log( 'warning',
                "file2variable: Error loading file - $file_name" );
            die __( "Error loading file: [_1]", $file_name );
        }

        $mimetype = mimetype_of($file_name);
        # $mimetype=mimetype($file_name); # from apiis_alib
    };

    if ($@) {
        $apiis->log( 'err', sprintf "file2variable: %s", scalar $@ );
        return;
    }
    $apiis->log( 'debug',
        "file2variable: Successfully loaded file $file_name in variable" );
    return $buffer, $mimetype;
}

##############################################################################

=head2 mimetype_of

B<mimetype_of> tries to find out the mimetype of a given filename. It first
uses MIME::Types, which seems to give the best results. Only if this module is
not installed or doesn't find any entry, a second test with File::Type is
done. B<mimetype_of> returns the found mimetype (e.g.
application/vnd.ms-powerpoint) or undef otherwise.

   Input:  filename with full path.
   Return: mimetype or undef

Example:

   use Apiis::Misc qw( mimetype_of );
   my $mt = mimetype_of($file_name);

=cut

sub mimetype_of {
    my $file_name = shift;
    return if !$file_name;
    my $mt;

    # try with MIME::Types:
    eval { require MIME::Types };
    if ( !$@ ) {
        my $mimetypes = MIME::Types->new;
        $mt = $mimetypes->mimeTypeOf($file_name);
    }
    if ($mt) {
        $apiis->log( 'debug', sprintf '%s: %s found mimetype %s for file %s',
            'mimetype_of', 'MIME::Types', $mt, $file_name );
        return $mt;
    }

    # second try with File::Type:
    eval { require File::Type };
    if ( !$@ ) {
        my $ft = File::Type->new();
        $mt = $ft->mime_type($file_name);
    }

    if ($mt) {
        $apiis->log( 'debug', sprintf '%s: %s found mimetype %s for file %s',
            'mimetype_of', 'File::Type', $mt, $file_name );
        return $mt;
    }

    # sorry, nothing:
    $apiis->log( 'notice', sprintf '%s: no mimetype found for file %s',
        'mimetype_of', $file_name );
    return;
}

##############################################################################

1;
