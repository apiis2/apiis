#!/usr/bin/perl
##############################################################################
# this program extracts records from tables and produces data and pedigree
# files suitable for PEST genetic evaluation.
# Eildert Groeneveld
# loops in pedigree will lead to infinite loops in this program. Thus they
# should not exist in the database (test for by pedigree_loops.pl)
# ############################################################################
use vars qw /$i $db_id $line_ref @line $sire $dam $tot_ped @col $sql %ped $table 
             %count_in %count_out $nped $birth $con $dbh $rdbm $dbn %inputs
             @sql $job_start $job_end/;
use strict;
use Env qw( APIIS_HOME );
use Env qw( APIIS_LOCAL );        
use lib "$APIIS_HOME/lib";    
use FileHandle;
use Data::Dumper;
use DBI;
use apiis_lib;           # standard apiis lib          
$dbn  = 'lt';			#<-# name of the database 
$rdbm = 'Pg';			#<-# used RDBM  - Pg for PostgreSQL
$con = "DBI:" . $rdbm . ":dbname=" . $dbn; 
%inputs = (
		station  => {
			      sql         =>"select t1.db_id,station,sex,origin,dam,birth_dt,
                              fat_thin,fat_last,concpv from animal t0,station t1 
                              where t1.db_id=t0.db_id and breed=407" ,
			      in          => '',
			      out         => '',
               outf        => 'blupdat.txt'
			     },
		test    => {
			      sql         => "select t1.db_id,sex,origin,test_dt,test_type,test_wt,
                               bf1,muscle,lean_meat from animal t0,test t1
                               where t1.db_id=t0.db_id and breed=407 and
                               test_type=6",
			      in          => '',
			      out         => '',
               outf        => 'blupdat.txt'
			     },
      pedi    => {
              sql          => "select db_id,sire,dam,birth_dt from animal
                               where breed=407",
              in           => '',
              out          => '',
              outf        => 'blupped.txt'
              }
	       );
$dbh = DBI->connect($con,undef,undef);

$job_start = GetNow();
my $n  = 0;
%ped   = ();

open (BLUPDATA,">blupdata.txt")  or die "cant open blupdata";
open (PED,     ">blupped.txt")   or die "cant open pedigree";
#######################################################
# db_id   sex  ori  t_dt         t_type wt     bf   musc lean
format TEST_FM =
@>>>>>>>>>> @>>> @>>>> @>>>>>>>>>> @>>>> @>>> @>>> @>>> @>>>
$db_id, $line[1], $line[2],$line[3],$line[4],$line[5],$line[6],$line[7],$line[8]
.
# station ...............
# db_id   sex  ori  t_dt         t_type wt     bf   musc # lean||dam,b_dt,fat_t,fat_l,concpv
format STATION_FM =
@>>>>>>>>>> @>>> @>>>> @>>>>>>>>>> @>>>> @>>> @>>> @>>> @>>> @##.# @>>>>>>>>>> @|||||||||| @##.# @##.# @##.#
$db_id,$line[1],$line[2],"","","","","","",$line[3],$line[4],$line[5],$line[6],$line[7],$line[8]
.
format PED_FM =
@>>>>>>>>>>>> @>>>>>>>>>>>> @>>>>>>>>>>>> @||||||||||
$db_id,      $sire,       $dam,           $birth
.
###############################################
## read the complete pedigree into RAM
###############################################
my $sql =$inputs{'pedi'}{'sql'};
my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
%ped=();
$sth->execute;
$i=0;
# here we make the selection like breeds of birthdates
print "Start loading pedigree:\n";
while ( $line_ref = $sth->fetch ) {
   #$i++;
   $inputs{'pedi'}{'in'}++;
   my @line = @$line_ref;
   my ($db_id, $sire, $dam, $birth)=@line;
   print '.' unless ++$i%100;
   print " --> $i\n" unless $i%2000;       
   if ($sire == 1) {$sire = undef;} # these are base parents, record skipped
   if ($dam  == 2) {$dam  = undef;}
   $ped{$db_id}[2]=$birth;
   $ped{$db_id}[3]=0;  # preset to not flagged
   if (defined $sire) {
      $ped{$db_id}[0]=$sire;
   }
   if (defined $dam) {
      $ped{$db_id}[1]=$dam;
   }
}
print "Pedigree loaded with $i records\n";
#######################################################
## complete pedigree is in RAM
####################################################### 

foreach $table ( keys %inputs ) {
  print "Table : $table\n";
  # skip pedigree.
  if ($table eq 'pedi'){next;}
  # select format:
  if ($table eq "test")    { BLUPDATA->format_name("TEST_FM"); }
  if ($table eq "station") { BLUPDATA->format_name("STATION_FM"); }
  @line =();
  $sql = $inputs{$table}{sql};
  print "SELECT: $sql\n";
  my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
  $sth->execute;
  $i=0;
  # pick up pedigree for each db_id
  while ( $line_ref = $sth->fetch ) { 
    $inputs{$table}{'in'}++; # count inputs    
    @line = @$line_ref;
    $db_id = $line[0];
    $tot_ped = 0;
    my $status = &get_ped_mem ($db_id);
    #print "--$db_id - @line .. $tot_ped - $table\n";
    print '.' unless ++$i%100;
    print " --> $i\n" unless $i%1000;      
    $inputs{$table}{'out'}++; # count outputs  
    write BLUPDATA;
    $n++;
  }
  print "from table $table we have read $n records\n";
  print "read: $inputs{$table}{'in'}\n";
  $n=0;
}
close (BLUPDATA);
###### now print the pedigree:
PED->format_name("PED_FM"); 
$i=0;$nped=0;
foreach $db_id (keys %ped) {
   if ($ped{$db_id}[3] == 1) {  # tagged for output?
      $sire = $ped{$db_id}[0];
      $dam  = $ped{$db_id}[1];
      $birth= $ped{$db_id}[2];
      #print "ped-- $db_id $sire $dam  $birth\n";
      write (PED);
      $nped++;
      $inputs{'pedi'}{'out'}++;
      print '.' unless ++$i%100;
      print " -ped-> $i\n" unless $i%1000;  
   }
}
print "....done\n";
close (PED);
$job_end = GetNow();
############## write final statistics:
STDOUT->format_name    ("final_rep"); 
STDOUT->format_top_name("final_rep_top"); 

$-=0;    # force new page
foreach $table (keys %inputs) { 
   write (STDOUT);
}
format final_rep_top = 
----------------------------------------------------------------------------------
-                                   Run time log                                 -
-                              extract_for_blupMEM.pl                            -
-                                    on database                                 -
-                                    @||||||||||                                 -
                                         $dbn
-                  job start:  @|||||||||||||||||||||||                          -
                                          $job_start
-                  job end  :  @|||||||||||||||||||||||                          -
                                          $job_end
----------------------------------------------------------------------------------
.
format final_rep =
Table: @<<<<<<<<< :   Records read: @#######  Records written: @####### 
$table                $inputs{$table}{'in'}, $inputs{$table}{'out'}
Output file       :   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                      $inputs{$table}{'outf'}
Select            :   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                      $inputs{$table}{'sql'} 
                      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                      $inputs{$table}{'sql'} 
                      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                      $inputs{$table}{'sql'} 
                      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                      $inputs{$table}{'sql'} 
                      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                      $inputs{$table}{'sql'} 
.
###################################
# get pedigree in recursive manner#
###################################
sub get_ped_mem {
  my $db_animal = shift;
  # flag:
  my $loc_sire = $main::ped{$db_animal}[0];
  my $loc_dam  = $main::ped{$db_animal}[1];
  if (defined $loc_sire or defined $loc_dam) {
     $main::ped{$db_animal}[3]=1;   # this record is tagged for output
  }
  ###############################################
  if (defined $loc_sire){ # dont use base parents
    my $status = &get_ped_mem ($loc_sire);
    if ($status == -1) {return (-1);}
  }
  if (defined $loc_dam ){ # base parent
    my $status = &get_ped_mem ($loc_dam);
    if ($status == -1) {return (-1);}
  }
return (0);
}
__END__
__END__                                   
