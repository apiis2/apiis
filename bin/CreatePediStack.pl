#!/usr/bin/perl
##############################################################################
#  Based on the animal IDs in PerfRec-MC.dat connected
#  pedigree records are flagged for out put to IB
#  based on IB verified pedigree file (PED-IB.ped)
#  those already at IB get deflagged so that only the 
#  balance needs to get sent to IB
#  Requirements for RC:
#  0. the Reporting Country is set in $RC=GBR;
#     the following XXX is replaced by $RC (here GBR)
#  1. the national pedigree is stored in file. PediStack-nat.ped
#  2. the national performance data are store is PerfRec-XXX.dat
#  3. the pedigree file to be transmitted and generated 
#  4  the validated pedigrees from IB are always PediStack-IBE.ped
#     through this program is PediStack-XXX.ped
#  4. Unknown parents are coded as UUUUUUUUUUUUUUUUUUU (19xU)
#  5. the IID in PerfRec-XXX.dat musst only contain GBR
#
# beware: !!!!
# loops in pedigree will lead to infinite loops in this program. Thus they
# should not exist in the database (test for by pedigree_loops.pl)
# the following checks should get implemented:
# - valid breed codes
# - valid country codes
# - valid sex
# - valid characters in IID (ASCII, no blanks)
# The following statistics should get printed:
# - number of IIDs where RC is CFRID
# - number of IIDs where RC is not CFR
# - the latter should be broken down by CSR
# Eildert Groeneveld Sa 21. Jun 20:17:41 CET 2008
# ToDO:
# include pedigree loops check
#
# ############################################################################
use vars qw /$n,$i $db_id $line_ref @line $sire $dam  %ped $birth 
             $PERF_RC $PEDI_nat $PEDI_nat $PEDI_dif $opt_h $opt_f $opt_c $opt_v $opt_o $opt_t
             $nPERF_RC $nPEDI_nat $nPEDI_nat $nPEDI_dif $nflaggged $stop 
             $ndeflagged $npederror $animal $job_start $job_end
             $RC @val_cntry @val_breed $b_an, $b_si $b_da $unknown
             $c_an $c_si $c_da %cntry %breed %sex $stra $strs $strd
             $cntry_err $breed_err $sex_err $npruned/;
use strict;
#use warnings;
use List::Util;
use FileHandle;
use Data::Dumper;
use Getopt::Std;
getopts('hf:c:v:o:t');

########################################
## define legal countries and breeds   
@val_cntry= qw /GBR FRA IRL /;
@val_breed= qw /LIM /;
$unknown = 'UUUUUUUUUUUUUUUUUUU';# unknown animal
########################################

if ($opt_h) {
   print "\nusage:\n";
   print " -v <F> for Full Interbeef check OR <P> for only a Pedigree check\n\n";
   print "Option -c is require for Full Interbeef check, \n";
   print "  while option -f is require for performing only a Pedigree check\n\n";
   print " -c <Country Code>\n";
   print " -f <Pedigree_file_name> \n";
   print " -t If IDs is not in International ID format as describe below\n";
   print " -o <Pedigree_output_file_name> (If not specified no output file will be created)\n\n";
   print "Pedigree_file_format: Animal ID (19 characters)\n";
   print "                      Sire ID   (19 characters)\n";
   print "                      Dam ID    (19 characters)\n";
   print "                      Birth Date( 8 characters)\n";
   print "followed by other fields of users preference\n\n";
   print "Animal, Sire and Dam numbers must be in the International ID format:\n";
   print "    Concatenation of: Breed code   ( 3 characters)\n";
   print "                      Country code ( 3 characters)\n";
   print "                      Sex of animal( 1 characters)\n";
   print "                      Animals ID   (12 characters)\n";
   print "        Example: NELBRZ000GFD020234\n";
   print " Unknow Animals, Sires and Dams must be coded by 19x'U'. Example: $unknown\n\n";
   print "Birth date format: YYYYMMDD\n";
   print "        Example: 20021024\n\n";
   print "****MAKE SURE THAT THERE IS ONE SPACE BETWEEN ALL FIELDS!!!!****\n\n";
   print " Or if IDs in Pedigree_file is not in the International ID format\n";
   print " use option -t\n";
   print " With the use of -t the pedigree file must be '|' delimited and the format required is:\n";
   print "      Animal_ID | Sire_ID | Dam_ID | birth_date | sex | breed\n\n";
   exit;
} 

if (! $opt_v){
   print "\nPlease include option -v as a starting parameter\n";
   print " -v <F> for Full Interbeef check OR <P> for only a Pedigree check>\n\n";
   print "Or run CreatePediStack.pl -h  for more info\n\n";
 exit;
}

if ($opt_v eq 'P' and ! $opt_f){
   print "\nYou have selected the Pedigree check only:\n";
   print "Please rerun the program with option -f or -h for more info\n\n";
   print " -f <Pedigree_file_name> \n";
   print " -t If IDs is not in International ID format as describe below\n";
   print " -o <Pedigree_output_file_name> (If not specified no output file will be created)\n\n";
   print "Pedigree_file_format: Animal ID (19 characters)\n";
   print "                      Sire ID   (19 characters)\n";
   print "                      Dam ID    (19 characters)\n";
   print "                      Birth Date( 8 characters)\n";
   print "followed by other fields of users preference\n\n";
   print "Animal, Sire and Dam numbers must be in the International ID format:\n";
   print "  Concatenation of:   Breed code   ( 3 characters)\n";
   print "                      Country code ( 3 characters)\n";
   print "                      Sex of animal( 1 characters)\n";
   print "                      Animals ID   (12 characters)\n";
   print "        Example: NELBRZ000GFD020234\n";
   print " Unknow Animals, Sires and Dams must be coded by 19x'U'. Example: $unknown\n\n";
   print "Birth date format: YYYYMMDD\n";
   print "        Example: 20021024\n\n";
   print "****MAKE SURE THAT THERE IS ONE SPACE BETWEEN ALL FIELDS!!!!****\n\n";
   print " Or if IDs in Pedigree_file is not in the International ID format\n";
   print " use option -t\n";
   print " With the use of -t the pedigree file must be '|' delimited and the format required is:\n";
   print "      Animal_ID | Sire_ID | Dam_ID | birth_date | sex | breed\n\n";
   exit;
}

if ($opt_v eq 'F' and ! $opt_c){
   print "\nYou have select the Full INTERBEEF pedigree check:\n";
   print "Please rerun the program with option -c or -h for more info\n\n";
   print " -c <Country Code>\n\n";
   exit;
}

if ($opt_c) {
   $RC=$opt_c;
}


$cntry_err = 0;
$breed_err = 0;
$sex_err = 0;
$job_start = &localtime();
%ped   = ();%breed = ();%cntry = ();%sex = ();

format PED_FM =
@>>>>>>>>>>>>>>>>>>>>@>>>>>>>>>>>>>>>>>>>>@>>>>>>>>>>>>>>>>>>>> @||||||||||
$animal,              $sire,                $dam
.

# #########################################
# parameterization
# #########################################
############################################################
############################################################
#
my $PERF_RC  = 'PerfRec-'.$RC.'.dat';   # filename of RC data
my $PEDI_nat = 'PediStack-nat.ped';     # filename of RC pedigree
my $PEDI_IB  = 'PediStack-IBE.ped';     # filename of IB validated ped.
my $PEDI_dif = 'PediStack-'.$RC.'.ped'; # filename of RC to be sent to IB

if ($opt_v eq 'P' and $opt_f){
$PEDI_nat = $opt_f;
}

open (PEDI_nat,"<$PEDI_nat") or die "cant open $PEDI_nat";

if($opt_v eq 'F'){
open (PERF_RC, "<$PERF_RC")  or die "cant open $PERF_RC";
open (PEDI_IB, "<$PEDI_IB")  or die "cant open $PEDI_IB";
open (PEDI_dif,">$PEDI_dif") or die "cant open $PEDI_dif";
}

###############################################
## read the complete RC pedigree into RAM
###############################################

my $i=0;
$nPEDI_nat=0;
my %si;
my %da;
my $tel_sire=0;
my $tel_dam=0;
my $tel_anim=0;
my $tel_bdate=0;
print "\nStart loading country pedigree from $PEDI_nat:\n";
while (<PEDI_nat>){
my ($animal, $sire, $dam, $bdate, $sex_1, $breed_1);
 if($opt_t){
 $nPEDI_nat++;
 chomp;
 my $line = $_;
 ($animal, $sire, $dam, $bdate, $sex_1, $breed_1) = split('\|', $line);
   if (! $sire){
    $sire=$unknown;
   }
   if (! $dam){
    $dam=$unknown;
   }
   if (! $animal){
    $animal=$unknown;
   }
 } else{
   $nPEDI_nat++;
   chomp;
   my $line = $_;
   my $template="A19 x1 A19 x1 A19 x1 A8";
   ($animal, $sire, $dam, $bdate)= unpack $template, $line;
 }
  if ($animal ne $unknown){
   $ped{$animal}[0]=$sire;
   $ped{$animal}[1]=$dam;
   $ped{$animal}[2]=0;  # preset to 'not flagged'
   $ped{$animal}[3]=$bdate;
   $tel_anim++;
   if ($opt_t){ 
    $ped{$animal}[10]=$sex_1;
    $ped{$animal}[11]=$breed_1;
   }
  }

  if($sire ne $unknown){
   $si{$sire}[0]++;
  }

  if($dam ne $unknown){
   $da{$dam}[0]++;
  }

  if($bdate>10000000){
   $tel_bdate++;
  }

  if($opt_v eq 'F'){
   chkIID($animal,$sire,$dam); # check for legal values
  }
}

foreach my $tt(sort keys %si){
 $tel_sire++;
}
foreach my $tt(sort keys %da){
 $tel_dam++;
}

%si=();
%da=();

print "\nCountry data loaded $nPEDI_nat\n";
$stop=0;

my $log_file='CreatePediStack.log';
system("rm -f $log_file");
open (OUT_LOG,">$log_file") or die "cant open $log_file";

print OUT_LOG "This is the log file for CreatePediStack.pl run at $job_start\n\n";
if($opt_v eq 'F'){
print OUT_LOG "You have selected to run the ful INTERBEEF pedigree and data check \nfor the $opt_c population.\n\n";
} elsif($opt_v eq 'P'){
print OUT_LOG "You have selected to run only a PEDIGREE check.\n\n";
}
if ($opt_o){
print OUT_LOG "New '|' delimited pedigree file was created with the name $opt_o.\n";
print OUT_LOG "(Format of $opt_o: <Animal|Sire|Dam|Birth_date|Sex|Breed>)\n\n";
}
print OUT_LOG "****************************************************************\n";
print OUT_LOG "\n\nUseful stats on your pedigree:\n";
print OUT_LOG "------------------------------\n";
print OUT_LOG "Number of animals in pedigree file:     $tel_anim\n";
print OUT_LOG "Number of known sires in pedigree file: $tel_sire\n";
print OUT_LOG "Number of known dams in pedigree file:  $tel_dam\n";
print OUT_LOG "Number of animals with Birth dates:     $tel_bdate\n";
print OUT_LOG "****************************************************************\n\n";


###########################################################
print "\nTesting for loops in the pedigree file\n";
print OUT_LOG "#########   Testing for loops in the pedigree file   ###########\n";
###########################################################

    my $href_in = \%ped;
    my @erg = ();
    @erg = testloop( $href_in, '', '1' );
    if ( scalar @erg == 0 ) {
        print OUT_LOG "     Congratulation, there are now loops in your pedigree file!\n";
        print OUT_LOG "----------------------------------------------------------------\n\n";
    } else {
        print OUT_LOG "!!!!!!!!!!!!!!   Error: Pedigree loops in pedigree file   !!!!!!!!!!!!!!\n\n";
        print OUT_LOG "Sorry there are loops in the $PEDI_nat pedigree file.\n";
        print OUT_LOG "Please take the time to correct these loops and then rerun this program.\n";
        print OUT_LOG "The program will not produce an output file before all pedigree loops are corrected.\n\n";
        print OUT_LOG "These loops are:\n";

        foreach my $x (@erg) {
            my @ergpart = split( '->', $x );
            my $c       = 0;
            my $first   = $ergpart[0];
            foreach my $y (@ergpart) {
                $c++;
                if ( $y ne $first or $c == 1 ) {
                    print OUT_LOG "$y -> ";
                } else {
                    print OUT_LOG "$y\n";
                }
                if ( $c == 2 ) {

                }
            }
        }
     print OUT_LOG "----------------------------------------------------------------\n\n";
     $stop=1;
    }

#############################################################
print "Test for wrong birth dates\n";
print OUT_LOG "######  Testing for wrong birth dates the pedigree file   ######\n";
#############################################################

my %wrong_bd;
my $telbd=0;

foreach my $tt(sort keys %ped){
   if($ped{$tt}[3] > 0 and $ped{$ped{$tt}[0]}[3] > 0 and $ped{$tt}[3] <= $ped{$ped{$tt}[0]}[3]){
   $wrong_bd{$tt.'|'.'sire'}[0]=$ped{$tt}[3]; #Animals Birth_dt
   $wrong_bd{$tt.'|'.'sire'}[1]=$ped{$tt}[0]; #Parent ID
   $wrong_bd{$tt.'|'.'sire'}[2]=$ped{$ped{$tt}[0]}[3]; #Perant Birth_dt
   $wrong_bd{$tt.'|'.'sire'}[3]='Sire'; #Sire or Dam
#   print OUT_LOG "Animal $tt birth date is $ped{$tt}[3] while the sire $ped{$tt}[0] birth date is $ped{$ped{$tt}[0]}[3]\n";
   $telbd++;
   }
   if($ped{$tt}[3] > 0 and $ped{$ped{$tt}[1]}[3] > 0 and $ped{$tt}[3] <= $ped{$ped{$tt}[1]}[3]){
   $wrong_bd{$tt.'|'.'dam'}[0]=$ped{$tt}[3]; #Animals Birth_dt
   $wrong_bd{$tt.'|'.'dam'}[1]=$ped{$tt}[1]; #Parent ID
   $wrong_bd{$tt.'|'.'dam'}[2]=$ped{$ped{$tt}[1]}[3]; #Perant Birth_dt
   $wrong_bd{$tt.'|'.'dam'}[3]='Dam'; #Sire or Dam
#   print OUT_LOG "Animal $tt birth date is $ped{$tt}[3] while the dam $ped{$tt}[1] birth date is $ped{$ped{$tt}[1]}[3]\n";
   $telbd++;
   }
}

if ($telbd>0){
#Include error mgs!!
        print OUT_LOG "!!!!!!!!!!!!   Error: Wrong birth dates in pedigree file   !!!!!!!!!!!!!\n\n";
        print OUT_LOG "Sorry there are animals who is born before the parents were born.\n";
        print OUT_LOG "Please take the time to correct these birth dates and then rerun this program.\n";
        print OUT_LOG "The program will not continue before these birth dates are not fixed.\n\n";
        print OUT_LOG "These Animals are:\n";
        
        foreach my $tt (sort keys %wrong_bd){
         my ($dier, $tt3) = split('\|', $tt);
         if($wrong_bd{$tt}[3] eq 'Sire'){
          print OUT_LOG "Animal, $dier, birth date is $wrong_bd{$tt}[0] while the $wrong_bd{$tt}[3], $wrong_bd{$tt}[1], birth date is $wrong_bd{$tt}[2]\n";
         }
        }
        foreach my $tt (sort keys %wrong_bd){
         my ($dier, $tt3) = split('\|', $tt);
         if($wrong_bd{$tt}[3] eq 'Dam'){
          print OUT_LOG "Animal, $dier, birth date is $wrong_bd{$tt}[0] while the $wrong_bd{$tt}[3], $wrong_bd{$tt}[1], birth date is $wrong_bd{$tt}[2]\n";
         }
        }
  print OUT_LOG "----------------------------------------------------------------\n\n";
  $stop=1;
} elsif ($telbd==0){
        print OUT_LOG "     Congratulation, animals birth dates are correct.\n";
        print OUT_LOG "----------------------------------------------------------------\n\n";
} 

%wrong_bd=();

system("rm -f $opt_o");
if ($opt_o and $opt_v eq 'P' and $stop==0){
open (OUT,">$opt_o") or die "cant open $opt_o";
foreach my $tt (sort keys %ped){
my ($ssex,$bbreed);
  if ($tt ne $unknown){
      if ($ped{$tt}[0] eq $unknown){
        $ped{$tt}[0]=undef;
      }
      if ($ped{$tt}[1] eq $unknown){
        $ped{$tt}[1]=undef;
      }
      if ($ped{$tt}[3]<10000000){
        $ped{$tt}[3]=undef;
      }

      if ($opt_t){
       $ssex=$ped{$tt}[10];
       $bbreed=$ped{$tt}[11];
      } else{
       $ssex=substr($tt,6,1);
       $bbreed=substr($tt,0,3);
      }
   print OUT "$tt|$ped{$tt}[0]|$ped{$tt}[1]|$ped{$tt}[3]|$ssex|$bbreed\n";
  }
 }
close OUT;
}

if($stop==1){
print "\n\n!!!!!!!!!!!!!!!!!!!  ERRORs !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
print "Sorry there are errors in the $PEDI_nat pedigree file.\n";
print "All errors are listed in the $log_file files.\n";
print "Due to these errors no output files were created.\n";
print "Please correct these errors and rerun this program.\n\n";
print "                GOOD LUCK!    \n";
print "--------------------------------------------------------------\n";
exit;
}

if ($opt_v eq 'P'){
print OUT_LOG "\n\n************************************************************************\n";
print OUT_LOG "*                       Thank you for using this application           *\n";
print OUT_LOG "************************************************************************\n";

print "\n\n**********************************************************************************\n";
print "*        Find pegigree statistics and information in the $log_file            \n";
if($opt_o){
print "*        A new '|' delimited pedigree filed was created as $opt_o           \n";
}
print "*                       Thank you for using this application                  \n";
print "**********************************************************************************\n";

exit;
}
#######################################################
## complete pedigree is in RAM
####################################################### 
# print Dumper(\%ped);
#######################################################
## now process each IID from Perf and tag PED
####################################################### 
# pick up pedigree for each db_id

my $nPERF_RC =0; 
my $npederror=0;

while (<PERF_RC>){
   $nPERF_RC++;
   chomp;
   my $line = $_;
   my $template="A19";
   my ($db_id)= unpack $template, $line;#print "DB-ID $db_id\n";

   # does ID at all exist? it has to else error
   if (exists $ped{$db_id}) {
      my $status = get_ped_mem($db_id);#print "DB-ID: $db_id stat:$status \n";
   }
   else
   {
      print OUT_LOG "MC Pedi Error : $db_id\n";# these should be collected
      $npederror++;
   };

}

###################################################
#  lets quickly count the number of flagged pedigrees
#################################################

my $nflagged=0;$i=0;
foreach $db_id (keys %ped) {
   $i++;
   if ($ped{$db_id}[2] == 1) {  # tagged for output?
      $nflagged++;
   }
}
#  print "total keys $i\n";
###################################################
#  now deflag those that already exist in IB.ped
###################################################
#  read IB.ped sequentially and detag corresponding
#  animal in MC.ped hash
my $nPEDI_IB=0;my $ndeflagged=0;
while (<PEDI_IB>){
   $nPEDI_IB++;
   chomp;
   my $line = $_;
   my $template="A19";
   my ($db_id)= unpack $template, $line;#print "DB-ID $db_id\n";

   # does ID exist?  then deflag it
   if (exists $main::ped{$db_id} and $main::ped{$db_id}[2] == 1) {
      $main::ped{$db_id}[2]=0; #print "DB-ID: $db_id deflagged \n";
      $ndeflagged++;
   };
}

#################################################
###### now print the remaining pedigree:
# the pedistack requires more information than this
# for implementation see structure of PediStack-MC.ped
# skip ANIMAL that are not CFR = RC 
# The procedure:
#   read PediStack-nat.ped sequentially
#   for each IID check in ped.hash if it is flagged
#   if it is transfer complete record to 
#   PediStack-GBR.dat
#################################################
$nPEDI_nat=0;
print "Start copying country pedigree from $PEDI_nat:\n";
seek(PEDI_nat, 0, 0) or die "Can't seek to beginning of file: $!";

while (<PEDI_nat>){
   $nPEDI_nat++;
   chomp;
   my $line = $_;
   my $template="A19";
   my ($animal)= unpack $template, $line;

   if ($main::ped{$animal}[2] == 1) {  # tagged for output?
      if (substr($animal,3,3) eq $RC){
         $nPEDI_dif++;
         print  PEDI_dif "$line\n";
      } else {
         $npruned++; # ANIMAL country is not $RC
         print "Pruned : $animal \n";
      }
   }

}
print "Pedigree Stack written: $nPEDI_dif pruned: $npruned\n";
print OUT_LOG "Pedigree Stack written: $nPEDI_dif pruned: $npruned\n";
close (PEDI_dif);
$job_end = &localtime();
################################################
# write some stats on breeds and countries
# ##############################################
print OUT_LOG " Breeds    Occurence\n";
foreach  (sort keys %breed) {
   print OUT_LOG "  $_  -- $breed{$_}\n";
}
print OUT_LOG " Countries Occurence\n";
foreach  (sort keys %cntry) {
   print OUT_LOG "   $_  -- $cntry{$_}\n";
}
print OUT_LOG " Sex        Occurence\n";
foreach  (sort keys %sex  ) {
   print OUT_LOG "   $_  -- loading$sex{$_}\n"
}

print OUT_LOG "\n\n";
############## write final statistics:
STDOUT->format_name    ("final_rep"); 
STDOUT->format_top_name("final_rep_top"); 

OUT_LOG->format_name    ("final_rep"); 
OUT_LOG->format_top_name("final_rep_top"); 

$-=0;    # force new page
write (STDOUT);
write (OUT_LOG);

format final_rep_top = 
----------------------------------------------------------------------------------
-                                   Run time log                                 -
-                                 CreatePediStack.pl                             -
-                               for Reporting Country                            -
-                                       @|||                                     -
                                         $RC
-                  job start:  @|||||||||||||||||||||||                          -
                                          $job_start
-                  job end  :  @|||||||||||||||||||||||                          -
                                          $job_end
----------------------------------------------------------------------------------
.
format final_rep =
File : @<<<<<<<<<<<<<<<< : Records read:      @#######  
       $PERF_RC          ,                $nPERF_RC
File : @<<<<<<<<<<<<<<<< : Records read:      @#######  
       $PEDI_nat         ,                 $nPEDI_nat
File : @<<<<<<<<<<<<<<<< : Records read:      @#######  
       $PEDI_IB          ,                $nPEDI_IB
File : @<<<<<<<<<<<<<<<< : Records flagged:   @#######  
       $PEDI_nat         ,                    $nflagged
File : @<<<<<<<<<<<<<<<< : Records deflagged: @#######  
       $PEDI_nat         ,                      $ndeflagged
File : @<<<<<<<<<<<<<<<< : Records written:   @#######  
       $PEDI_dif         ,                   $nPEDI_dif
File : @<<<<<<<<<<<<<<<< : Records pruned:    @#######  
       $PEDI_nat         ,                   $npruned
File : @<<<<<<<<<<<<<<<< : Records not contained in File : @<<<<<<<<<<<< : @#######  
       $PERF_RC          ,                                  $PEDI_nat   ,      $npederror
Errors: Country Coding Errors : @<<<<<
       $cntry_err
Errors: Breed   Coding Errors : @<<<<<
       $breed_err
Errors: Sex     Coding Errors : @<<<<<
       $sex_err
.

###################################
# get pedigree in recursive manner#
###################################

sub get_ped_mem {
   my $db_animal = shift;
   # flag:
   if (exists $ped{$db_animal}) {
      my $loc_sire = $ped{$db_animal}[0];
      my $loc_dam  = $ped{$db_animal}[1];
#    print "Get $db_animal $loc_sire $loc_dam\n";
      $ped{$db_animal}[2]=1;   # this record is tagged for output

      ###############################################
      # test for end of recursion
      if (defined $loc_sire){ # dont use base parents
         my $status = get_ped_mem($loc_sire);
         if ($status == -1) {return (-1);}
      }
      if (defined $loc_dam ){ # base parent
         my $status = get_ped_mem($loc_dam);
         if ($status == -1) {return (-1);}
      }
      return (0);
   }
}
# return formatted date time
sub localtime {
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   $year += 1900;
   $mon++;
   $mon  = sprintf "%.2d", $mon;
   $mday = sprintf "%.2d", $mday;
   $hour = sprintf "%.2d", $hour;
   $min  = sprintf "%.2d", $min;
   $sec  = sprintf "%.2d", $sec;
return ($year.'-'.$mon.'-'. $mday.'  '. $hour.':'. $min.':'. $sec);
}
sub chkbreed {
   foreach (@_) {
      my $stra = $_;
      if (!defined List::Util::first { $_ eq $stra} @val_breed )  {
         print "Illegal breed in record $nPEDI_nat $stra \n";
         $breed_err=1;
      }
   }
}
sub chkcntry {
   foreach (@_) {
      my $stra = $_;
      if (!defined List::Util::first { $_ eq $stra} @val_cntry )  {
         print "Illegal country in record $nPEDI_nat $stra \n";
         $cntry_err=1;
      }
   }
}
sub chksex {
   foreach (@_) {
      my $stra = $_;
      if ($stra eq 'F' or $stra eq 'M') {
         return;
      } else {
         print "Illegal sex code in record $nPEDI_nat $stra\n";
         $sex_err=1;
      }
   }
}
sub chkIID {
   # checks if IID conforms to definition and legal sex/country/breeds code
   # checking for legal characters needs to get added:
   # a-z A-Z 0-1 or are there others?
   # no further checking is done if ANIMAL is unknown


   foreach (@_) {
      my $iid = $_;
      my $nat_idd = substr($iid,7,12);#unknown animals where national number is 000000000000

      if ($iid eq $unknown) { return; } # unknown animal
      if ($nat_idd eq '000000000000') { return; };
      my $stra = substr($iid,0,3);#breed
      chkbreed($stra);
      $breed{$stra}++;

      $stra = substr($iid,3,3);#country
      chkcntry($stra);
      $cntry{$stra}++;

      $stra =substr($iid,6,1); #sex
      chksex($stra);
      $sex{$stra}++;
   }
}

sub testloop {
    my $href = shift;
    my $unknown = shift;
    my $initial = shift;

my %tree;
my @ret_ges;
my @path;

    if ( $initial == 1 ) {
        %tree = ();
        @ret_ges = ();
    }

    %tree = %$href;
    my @ret = ();
    my %rethash = ();
    my $k = (); my $l = ();

    if ($unknown) {
        $tree{"$unknown"}[4]=2;
    } else {
        $tree{"1"}[4]=2; $tree{"2"}[4]=2;
    }

    foreach my $k (keys %tree) {
        test($k);
    }
    sub test {                  # using global variables %tree and @path
        # $tree{$node}[4]= 0 - unknown
        #                  1 - under investigation
        #                  2 - clear
        my $node=shift;
        if (!exists($tree{$node}) || $tree{$node}[4]==2) {
            return;
        }
        if ($tree{$node}[4]==1) { # now we have a problem
            push @ret, $node;
            # print "loop are: $node ";
            my $l = @path-1;
            while ($path[$l] ne $node) {
                push @ret, $path[$l];
                # print "-> $path[$l] ";
                $l--;
            }
            push @ret, $node;
            my $str = join( '->', @ret );
            push @ret_ges, $str;
            @ret = ();
            # print "-> $node\n";
        } else {                # $tree{$node}[0]==0
            $tree{$node}[4]=1; push(@path,$node);
            test($tree{$node}[0]);
            test($tree{$node}[1]);
            $tree{$node}[4]=2; pop(@path);
        }
    }                           #end test
    return ( @ret_ges );

}                               # test_loop
print OUT_LOG "\n\n************************************************************************\n";
print OUT_LOG "*                       Thank you for using this application           *\n";
print OUT_LOG "************************************************************************\n";

print "\n\n**********************************************************************************\n";
print "*        Find pegigree statistics and information in the $log_file            \n";
if($opt_o){
print "*        A new '|' delimited pedigree filed was created as $opt_o           \n";
}
print "*                       Thank you for using this application                  \n";
print "**********************************************************************************\n";

close OUT_LOG;
__END__
