#!/usr/bin/perl 
##############################################################################
# $Id: selection.pl,v 1.9 2004/02/10 06:52:12 heli Exp $
# create a report to count number of selected/not selected animals from
# Eigenleistung grouped by month/year.
# current problems:
# this is very crude as it reads all animals into hash!!!!!!!
##############################################################################
BEGIN { # execute some initialization before compilation
   use Env qw( APIIS_HOME );
   die "APIIS_HOME is not set!\n" unless $APIIS_HOME;
   use lib "$APIIS_HOME/lib";
   require apiis_init;
   initialize_apiis( VERSION => '$Revision: 1.9 $' );
}


use strict qw/ vars subs /;
use vars qw/ $model_file $dbh %id_hash $thisyear $thismonth $year
             *REPORT %sel %notsel $thiscount $notselcount $percent $tmp_year /;
$| = 1;

$model_file = GetModelName();
require "$model_file";

use DataBase;   # database routines
my $loctim = localtime();
ConnectDB() unless defined $dbh;
Get_Selection_IDs_Hash( \%id_hash );
my $today = localtime();

# get data from testing:
# here you need to select those animals fro which you want to
# get the percentage selected (i.e. Station Test or field test)
#  here we select the field test records
my $sth1 = $dbh->prepare(q{
                 SELECT db_animal,
                        date_part('year' ,test_dt),
                        date_part('month',test_dt)
                 FROM   weight
		 WHERE  db_weight_type=(
                              select db_code from codes
                              where class ='WEIGHT_TYPE' and
                                    ext_code ='field');
                }) or die $dbh->errstr;
#######

print "Reading data from fieldtest ...\n";
$sth1->execute();
my $tbl_ary_ref = $sth1->fetchall_arrayref();    # fetch all data
$sth1->finish;                               
DisconnectDB();

my $i = 0;
print "Processing data ...\n\n";
foreach ( @$tbl_ary_ref ) {
   my @line = @$_;
   my ($db_id, $year, $month) = @line;
	if ( exists $id_hash{$db_id} ) {
		$sel{$year}{$month} += 1 if ( $year and $month );
      $i++;
	} else {
		$notsel{$year}{$month} += 1 if ( $year and $month );
	}
}

$^ = 'SELECTION_TOP';
$~ = 'SELECTION';

# driving the report:
foreach $thisyear ( sort numerically keys %sel ) {
	$tmp_year = $thisyear; # $tmp_year is shifted by report, don't use $thisyear
	foreach $thismonth ( sort numerically keys %{$sel{$thisyear}} ) {
		$thiscount = $sel{$thisyear}{$thismonth};
		$notselcount = $notsel{$thisyear}{$thismonth};
		$percent = round( $thiscount * 100 / ($thiscount + $notselcount) ) 
			if ($thiscount + $notselcount);
		$percent = '-' unless $percent;
	   write;
	}
}

##############################################################################
sub numerically { $a <=> $b; }
##############################################################################
sub round {
	my $number = shift;
	return int($number + .5 * ($number <=> 0));
}
################################################################################
# get a hash with the db_ids where status = 'S' (selected)
# the global hash is passed by reference
# assumption: if we have at least 2 records for an db_id in transfer
# the animal is assumed to have been selected.
sub Get_Selection_IDs_Hash {
   local $dbh->{RaiseError} = 1;
   print "Fetching selected animals...";
# here you need to select all animals selected. the example below
# assumes that db_id with at least two entries (renumbered at selection)
# are selected.
   my $sth = $dbh->prepare(q{
                 SELECT   db_animal,count(db_animal)
                 FROM     transfer
		 GROUP BY db_animal
		 HAVING   count(db_animal) > 1
                }) or die $dbh->errstr;
                # this should be read from table TIER column FLAG

   $sth->execute;
   my $kennung_ary_ref = $sth->fetchall_arrayref();
   $sth->finish;                               

   my $row;
   my $k = 0;
   # creating hash (key = db_id)
   foreach $row ( @$kennung_ary_ref ) {
         $id_hash{$$row[0]} = ();
         $k++;
   }     
   print " ($k IDs stored)\n";
}
##############################################################################
#ub GetToday {
#  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#  $mday . '.' . ++$mon . '.19' . $year;
# 
##############################################################################
format SELECTION_TOP =
   Report generated on               @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                                                      $today
                    Animals selected per year and month

 Year     Month        not selected        selected      percentage
----------------------------------------------------------------------
.                                         
                                          
format SELECTION =                        
 ^<<<<    ^>>>>          ^>>>>>>>>>>       ^>>>>>>>>      ^>>>
$tmp_year,$thismonth,    $notselcount,     $thiscount,    $percent
~~        ^<<<<          ^>>>>>>>>>>       ^>>>>>>>>      ^>>>
          $thismonth,    $notselcount,     $thiscount,    $percent
.
################################################################################

