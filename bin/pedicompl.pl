#!/usr/bin/env perl
##############################################################################
# ./pedicompl.pl -p reference -d zwisss -w st06nsrg
# This program calculates the degree of pedigree completeness according to
# MacCluer et al. Inbreeding and pedigree structure in StandardBred Horses
# J.of Heredity 74:394--399 1983
# ############################################################################

BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}
use Apiis;
use strict; no strict 'refs';
Apiis->initialize( VERSION => '$Revision: 1.4 $ ');
our $apiis;
use Apiis::Auth::AccessControl;
use Apiis::Misc qw ( mychomp LocalToRawDate ); # ...

initialize();

sub initialize {
   use Tie::IxHash;
   use Text::ParseWords;
   use Statistics::Descriptive;
# use ref_breedprg_alib;
   use vars qw / $dbh /;
use vars qw / %inputs $db_id %ped @line $undef_animal $sire $dam $birth %comp
              $gen_counter $completeness $maxgen $breed $dbb $brd $sine $filename/;
   }

   $brd='BREED';
   use vars qw( $opt_h $opt_d $opt_p $opt_w $opt_g $opt_b $opt_c $opt_o);
   use Getopt::Std;
   getopts('hd:w:p:g:b:c:o:');
   if ($opt_h) {
   print "usage:\n";
   print " -h this message \n";
   print " -p <project_name>\n";
   print " -d <> database user \n";
   print " -w <> database password \n";
   print " -g 1 - n for max generation depth (Default = 5)\n";
   print " -b short name for breed (If not entered all breeds will run, very long)\n";
   print " -c Your name for BREED in class = 'BREED' in table codes (Default = $brd)\n";
   print " -o filename if you want output to csv file\n";
   die("\n");
   }

   my $project_name;
   if ($opt_p) {
      $project_name = $opt_p;
      print "project = $project_name\n";
   } else {
      print __("no project given use option -p\n");
      die;
   }
   if ($opt_d){print "user = $opt_d\n";}
   if ($opt_w){print "passwrd= $opt_w\n";}
   if (! $opt_g){
     $maxgen = 5;
     print "max generation = default 5\n";
  } else {
    $maxgen = $opt_g;
    print "max generation = $maxgen\n";    
  }
  if ($opt_b){
     $breed = $opt_b;
     $sine = '=';
     print "BREED $sine $breed \n";
  } else {
    $sine = '>=';
    $breed=undef;
    print "Going to run for all breeds \n";
  }
  if ($opt_c){
    $brd = $opt_c;
    print "Your class for breed = $brd\n";
  } else {
    print "Using default class name for breed as BREED\n";
  }
   if ($opt_o){
      $filename = "$opt_o"."$breed".'.csv';
      print "Wright data to $filename\n";
   } else {
      print "Wright data to screen \n";
   }
use Apiis::DataBase::User;
my $user_obj;

if ( $opt_d and $opt_w ) {
$user_obj = Apiis::DataBase::User->new( id => $opt_d );
$user_obj->password($opt_w);
$apiis->join_model( $project_name, userobj => $user_obj );
} else {
$apiis->join_model($project_name);
}
$apiis->check_status;
$dbh = $apiis->DataBase->dbh;
$dbh->{AutoCommit} = 0;
my $today = $apiis->today;


$gen_counter = 0;
$completeness= 0;
#################### EDIT START ###############################################
$undef_animal = '0'; # undefined animals
###############################################################################
#sort breed loop out
my $sql1;
if (! defined $breed){
  $sql1 = "select min(db_breed) from animal";
  my $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
  $apiis->check_status ;
  while( my $line_ref = $sql_ref1->handle->fetch ) {
    my @line = @$line_ref;
    $dbb=$line[0];
  }
} else {
  $sql1 = "select db_code from codes where class='$brd' and short_name = '$breed'";
  my $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
  $apiis->check_status ;
  while( my $line_ref = $sql_ref1->handle->fetch ) {
     my @line = @$line_ref;
     $dbb=$line[0];
  }
}
###############################################
## read the complete pedigree into RAM
###############################################
my $sql ="select db_animal, db_sire, db_dam, date_part('year',birth_dt),short_name
          from animal, codes where birth_dt notnull and db_breed=db_code and db_breed $sine $dbb";
my $sql_ref = $apiis->DataBase->sys_sql($sql);
$apiis->check_status;
%ped=();
%comp=();
my $j=0;
# here we make the selection like breeds of birthdates
print "Start loading pedigree:\n";
while( my $line_ref = $sql_ref->handle->fetch ) {
   $inputs{'pedi'}{'in'}++;
   my @line = @$line_ref;
   my ($db_id, $sire, $dam, $birth, $breed)=@line;
   print '.' unless ++$j%500;
   print " --> $j\n" unless $j%10000;
   if ($sire == 1) {$sire = $undef_animal;} # i have base parents with records...
   if ($dam  == 2) {$dam  = $undef_animal;} # i need also these parents
   $ped{$db_id}[2]=$birth;
   $ped{$db_id}[4]=$breed;
   
   $ped{$db_id}[3]=0;  # completeness

   if ( $sire ) {
      $ped{$db_id}[0]=$sire;
   }
   if ( $dam ) {
      $ped{$db_id}[1]=$dam;
   }
}
print "\nPedigree loaded with $j records\n";

my $start_animal;
foreach $start_animal (keys %ped) {
   #my $start_animal= "44250"; print "doing animal $start_animal\n";
   my $its_sire = $main::ped{$start_animal}[0];
   my $its_dam  = $main::ped{$start_animal}[1];
   my $sire_comp = 0;
   my $dam_comp  = 0;
   # SIRE
   #print "Doing SIRE of $start_animal \n";
   if (defined $its_sire) {
      $completeness = .5/(2**(1-1)); $gen_counter  = 1; my ($status) = &get_ped_mem ($its_sire);
   } else { 
      $completeness = 0;
   }
   $sire_comp   = $completeness / $maxgen;

   # DAM
   #print "\nDoing DAM of $start_animal \n";
   if (defined $its_dam) {
      $completeness = .5/(2**(1-1)); $gen_counter  = 1; my ($status) = &get_ped_mem ($its_dam);
   } else {
      $completeness = 0;
   }
   $dam_comp    = $completeness / $maxgen;
   my $indiv_comp = 0 ;
   ## print "$start_animal SC $sire_comp DC $dam_comp\n";
   # the result:
   if ($sire_comp+$dam_comp > 0) {
      $indiv_comp = (4*$sire_comp*$dam_comp)/($sire_comp+$dam_comp);
   }
   $main::ped{$start_animal}[3]=$indiv_comp ;
   ## print "$start_animal $ped{$start_animal}[2] $indiv_comp\n";

   # store per birth year:
   my $year = $main::ped{$start_animal}[4].'|'.$main::ped{$start_animal}[2];
      $comp{$year}[0] = $comp{$year}[0] + $indiv_comp;
      $comp{$year}[1]++;
}

print "yearly statistics\n";
print "Max Generation : $maxgen\n";
if ($filename){
open (OUT, ">$filename") or die "Can not open $filename\n";
}
my $year=0;
if ($opt_o){
  print OUT '"Year","Completeness","Number'."\n";
}

my $sum_avg;
my $tot_avg;

foreach $year (sort keys %comp) {
  my $avg= $comp{$year}[0]/$comp{$year}[1];
  $avg = round3($avg);
  $avg = sprintf("%.3f",$avg) if $avg;
  $sum_avg += ($avg*$comp{$year}[1]);
  $tot_avg += $comp{$year}[1];
  print "$year -- $avg $comp{$year}[1]\n";
  if ($opt_o){
      print OUT '"'."$year".'","'."$avg".'","'."$comp{$year}[1]".'"'."\n";
  }  
}


my $weeg= ($sum_avg/$tot_avg);
$weeg = sprintf("%.3f",$weeg) if $weeg;

print "$breed"."|Avarage -- $weeg $tot_avg\n";
if ($opt_o){
    print OUT '"Average","'."$weeg".'","'."$tot_avg".'"'."\n";
}
####################################
# get pedigree in recursive manner #
####################################
# we start with an animal ID, this may or may not have a known parent.
#
sub get_ped_mem {
   my $db_animal = shift;
   my $loc_sire = $main::ped{$db_animal}[0];
   my $loc_dam  = $main::ped{$db_animal}[1];

   if (defined $loc_sire or defined $loc_dam) {
      $main::gen_counter++; # increment gen
      # the pedigree may be deeper that maxgen, then return
      if ($main::gen_counter > 100) { # pedigree loop?
         print "----- LOOP? $db_animal \n";
         $main::gen_counter=1;
         return (-1);
      }
   } else { 
      #rint "Return\n";
      return (0);
   }
   #print "      A $db_animal";
   #print " S $loc_sire";
   #print " D $loc_dam ";
   #print " Gen: $main::gen_counter\n";

   # 1. (recursively) handle sire
   #print "     Going to do Sire  $loc_sire)\n";
   if (defined $loc_sire){
      if ($main::gen_counter <= $main::maxgen ){
         $main::completeness=$main::completeness+(.5/2**($main::gen_counter-1));
         ##print                        "     S adding : .5/2**($main::gen_counter-1)";
         ##print "sum $main::completeness\n";
      }
      my $status = &get_ped_mem ($loc_sire);
      if ($status == -1) { return (-1)}; # error: exit everything
   }
   # 2. (recursively) handle dam
   #print "     Going to do Dams  $loc_dam)\n";
   if (defined $loc_dam){ 
      if ($main::gen_counter <= $main::maxgen ){
         $main::completeness=$main::completeness+(.5/2**($main::gen_counter-1));
         ##print                        "     D adding : .5/2**($main::gen_counter-1)";
         ##print "sum $main::completeness\n";
      }
      my $status = &get_ped_mem ($loc_dam); 
      if ($status == -1) {  return (-1);} # error: exit everything

   }
   $main::gen_counter--; #print "decrement $main::gen_counter\n";
   return (0);
}

sub round3 {
       my $number  = shift; 
       $number = (int(($number * 1000) + .5) / 1000);
  return ($number);
}

__END__
