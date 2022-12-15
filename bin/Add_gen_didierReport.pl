#!/usr/bin/perl -w
##############################################################################
# this program extracts records from tables and produces data for special use
# ############################################################################
BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
   push @INC, "$APIIS_HOME/bin";
}
                                                                                                                            
use strict; no strict 'refs';
use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.4 $' );
our $apiis;
use Apiis::Auth::AccessControl;
use Apiis::Misc qw ( mychomp LocalToRawDate ); # ...
                                                                                                                            
initialize();

sub initialize {
  use Tie::IxHash;
  use Text::ParseWords;
  use Statistics::Descriptive;
  use ref_breedprg_alib;
  use vars qw / $dbh $breed $gen /;
}

#
use vars qw( $opt_h $opt_d $opt_p $opt_w $opt_b $opt_g $opt_s);
use Getopt::Std;
getopts('hd:w:p:b:g:s:');
if ($opt_h) {
  print "usage:\n";
  print "  require gnuplot 4.2  !!!!!\n";
  print " -h this message \n";
  print " -d <> database user \n";
  print " -w <> database password \n";
  print " -p <project_name>\n";
  print " -b <> database short_name for breed  \n";
  print " -g <> generation interval if you want a fixed generation else\n";
  print "       the generation will be pigup from Population report\n";
  print " -s <> your table codes short_name for Male (Default = Male)\n";
  die("\n");
}

#$opt_p='breedprg';
#$opt_d='frits';
#$opt_w='pass';
#$opt_b=DL;

my $breed;
my $gen;
my $male;
my $project_name;
if ($opt_p) {
  $project_name = $opt_p;
  print "project = $project_name\n";
} else {
  print __("no project given use option -p\n");
  die;
}
##
if ($opt_b) {
  $breed = $opt_b;
  print "breed = $breed\n";
}

if ($opt_g) {
  $gen = $opt_g;
  print "generation interval = $gen\n";
} else {
#  $opt_g = 1;
#  $gen = $opt_g;
#  print "generation interval = $gen\n";
   print "generation fetch from tables \n";
}

if ($opt_s) {
  $male = $opt_s;
  print "Sex = $male\n";
} else {
  $opt_s = 'Male';
  $male = $opt_s;
  print "Sex = $male\n";
}

############################################################
print "# Get the project and user sort out \n";
############################################################
use Apiis::DataBase::User;
my $not_ok=1;
my $loginname;
my $passwd;
$loginname= $opt_d if $opt_d;
$passwd= $opt_w if $opt_w;
                                                                                                                            
if (! $opt_d and ! $opt_w){
  while ($not_ok) {
    print __("Please enter your login name: ");
    chomp( $loginname = <> );
    print __("... and your password: ");
#    ReadMode 2;
    chomp( $passwd = <> );
#    ReadMode 0;
    print "\n";
    $not_ok = 0 if $loginname and $passwd;
  }
} else {
  $not_ok=1;
}
my $thisobj = Apiis::DataBase::User->new(
   id       => "$loginname",
   password => "$passwd",
   );
   $thisobj->check_status;
$apiis->join_model($project_name, userobj => $thisobj);
$apiis->check_status;
                                                                                                                            
$dbh=$apiis->DataBase->dbh;
$dbh->{AutoCommit}=0;
my $user = $apiis->User->id;
my $now = $apiis->now;
###########################################################
my $hd = "$APIIS_HOME/etc/PopReport/";
my $tmp = "$APIIS_HOME/var/";
my $today = $apiis->today;
my %delfile;

use vars qw /%ped %newid %sortid /;
tie %ped, 'Tie::IxHash';
tie %newid, 'Tie::IxHash';
tie %sortid, 'Tie::IxHash';

my $dbbname;
my $dbb;
my $short;
my $sql1;

if (defined $breed){
  $sql1 = "select long_name,db_code,short_name from codes where short_name='$breed'";
} else {
  $sql1 = "select distinct on (a.db_breed) c.long_name, a.db_breed ,short_name
           from animal a, codes c
           where a.db_breed=c.db_code";
}
my $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
$apiis->check_status ;
while( my $line_ref = $sql_ref1->handle->fetch ) {
   my @line = @$line_ref;
   $dbbname=$line[0];
   $dbb    = $line[1];
   $short  = $line[2];

$sql1 = "select year,ss,sd,ds,dd,pop from tmp1_gen where breed = '$short'  order by year";
my $sth2;
my %gen;
my $npop=undef;
my $sql_ref2 = $apiis->DataBase->sys_sql($sql1);
$apiis->check_status ;
while( my $line_ref2 = $sql_ref2->handle->fetch ) {
   my @line = @$line_ref2;
   $gen{Total}[0] += $line[1] if $line[1];#ss
   $gen{Total}[1] += 1 if $line[1];
   $gen{Total}[2] += $line[2] if $line[2];#sd
   $gen{Total}[3] += 1 if $line[2];
   $gen{Total}[4] += $line[3] if $line[3];#ds
   $gen{Total}[5] += 1 if $line[3];
   $gen{Total}[6] += $line[4] if $line[4];#dd
   $gen{Total}[7] += 1 if $line[4];
   $npop = $line[5] if !$npop;
}
my $genn=round(($gen{Total}[0] + $gen{Total}[2] + $gen{Total}[4] + $gen{Total}[6])/
               ( $gen{Total}[1] + $gen{Total}[3] + $gen{Total}[5] + $gen{Total}[7])) if  $gen{Total}[0];
#if ($genn and $genn != $gen){$gen = $genn;}

my $sql = "select a.db_animal, a.db_sire, a.db_dam, a.birth_dt, c.short_name 
          from animal a, codes c
          where a.db_sex=c.db_code
          and a.db_breed = $dbb";
@line=();
my $ext_animal;
my $j=0;
my %ped;
my %newid;
my %sortid;
my $sql_ref3 = $apiis->DataBase->sys_sql($sql);
$apiis->check_status ;
while( my $line_ref3 = $sql_ref3->handle->fetch ) {
   @line = @$line_ref3;
   if (! $line[3]){$line[3]='1900-01-01';}
   $ped{$line[3].'|'.$line[0]}[0]=$line[0];#dierid
   if ($line[1] == 2){$line[1] = '0';}
   $ped{$line[3].'|'.$line[0]}[1]=$line[1];#sire
   if ($line[2] == 1){$line[2] = '0';}
   $ped{$line[3].'|'.$line[0]}[2]=$line[2];#dam
   $ped{$line[3].'|'.$line[0]}[5]=$line[3];#birth_dt
   #Male and Female hards coded for par3 calculations ############
   if ($line[4] eq "$male"){$line[4] = '1';} else {$line[4] = '2';}
   ################################################################
   $ped{$line[3].'|'.$line[0]}[4]=$line[4];#sex
   my ($y, $m, $d) = split '-', $line[3] if $line[3];
   $ped{$line[3].'|'.$line[0]}[3]=$y;#birth year
   print '.' unless ++$j%100;
   print " --> $j\n" unless $j%1000;
}
print "\nPedigree loaded with $j records\n";
print "\nCreate new sequens numbers\n";

my $new=0;
my @tel;
foreach my $id (sort keys %ped){
  #$id='yyyy-mm-dd|?????
  $new++;
  push @tel, $new;
  $newid{$new}[0]=$id;  
  $newid{$new}[1]=$ped{$id}[1];#sire
  $newid{$new}[2]=$ped{$id}[2];#dam
  $newid{$new}[3]=$ped{$id}[3];#birth year
  $newid{$new}[4]=$ped{$id}[4];#sex
  $newid{$new}[5]=1;#
  $newid{$new}[6]='0';#
  $newid{$new}[7]=$ped{$id}[5];#birth dt
  $sortid{$ped{$id}[0]}[0]=$new;#dier
}
foreach my $id (sort keys %newid){
  $newid{$id}[1]= $sortid{$newid{$id}[1]}[0];
  $newid{$id}[2]= $sortid{$newid{$id}[2]}[0];
}
print 'Print now Ped'."$short".'.txt'."\n";
my $pedfile='Ped'."$short".'.txt';
$delfile{$pedfile}[0]=1;
my $kk='>Ped'."$short".'.txt';
open (OUT1, "$kk") or die "Can not open $kk\n";
my $small=9999999999;
$j=0;
foreach my $id ( @tel){
  if ($newid{$id}[3] > 1900){if ($newid{$id}[3] < $small){$small = $newid{$id}[3] ;}}
  my $str='A10';
  my $a;
  print OUT1 pack($str, $id);
  for ($a = 1; $a < 7; $a++){
  if (! $newid{$id}[$a]){$newid{$id}[$a]='0';}
  print OUT1 pack($str, ($newid{$id}[$a]*1));
  }
  print OUT1 "\n";
   print '.' unless ++$j%100;
   print " --> $j\n" unless $j%1000;
}
close OUT1;
print "\nPedigree printed with $j records\n";
next if -z $pedfile;

my %datafile;
my $datafile;
print "Create now the data files per year\n\n";
foreach my $id ( @tel){
  if ($newid{$id}[3] > 1900){
    if ($newid{$id}[3] == $small){
      $datafile='Breed'."$short".'_'."$small".'.txt';
      my $kk='>>Breed'."$short".'_'."$small".'.txt';
      $datafile{$datafile}[0]=1;
      open (OUT1, "$kk") or die "Can not open $kk\n";
      my $str='A10';
      print OUT1 pack($str, $id);
      print OUT1 pack($str, $newid{$id}[4]);
      print OUT1 "\n";
    } else {
      close OUT1;
      print "$datafile \n";
      $small = $newid{$id}[3];
    }
  }
}
my %calc;
print "Run now Relationship Coefficients for easch year\n\n";
foreach my $id (sort keys %datafile){
   my $str='A10';
   my ($t1,$t2) = split '\_', $id;
   my ($tt1, $tt2) = split '\.', $t2;
   $tt1 = $tt1 * 1;
   print "Run now YEAR $tt1\n";
   open (OUT, '>par3_temp') or die "Can not open par4_temp\n";
   print OUT "$pedfile \n";
   print OUT "$id \nno \n";
   close OUT;
   system("add_gen_didier < par3_temp > par3_out$tt1");
   my $file = "par3_out$tt1";
   $delfile{$file}[0]=1;
   $delfile{'par3_temp'}[0]=1;
   open (IN, $file) or die "Problems opening $file \n";
   my $one;
   my $two;
   my ($a1, $a2);
   my ($a3, $a4);
   my ($a5, $a6);
   my $nn=1;
   while (<IN>) {
      mychomp($_);
      my $lyn = $_;
      if ($lyn =~ /Group 1 :/ or $lyn =~ /Number of individual studied :/){
        ($a1, $a2) = split '\:', $lyn;
        $a2 = $a2 * 1;
        $a6=0;
      } elsif ($lyn =~ /Group 2 :/){
        ($a5, $a6) = split '\:', $lyn;
        $a6 = $a6 * 1;
      } else {
        if ($lyn =~ /Mean of coefficients       /){$nn++;}
        if ($nn == 2 and $lyn =~ /Mean of coefficients          /){
        ($a3, $a4) = split '\:', $lyn;
        $a4 = $a4 * 1;
        last;
        }
      }     
   }
   close IN;
   $calc{$tt1}[0]= $a2 + $a6;#number
   $calc{$tt1}[1]= $a4;#coeff
}

my $dbbout='Breed'."$short".'.out';
my $yyy='>Breed'."$short".'.out';
$delfile{$dbbout}[0]=1;
open (OUT1, "$yyy") or die "Can not open $dbbout\n";

my $outputfile= 'Additivegenetic_'."$short".'.tex';
my $output='Additivegenetic_'."$short";
open (OUT, ">$outputfile") or die "Problems opening file $outputfile: $!\n";

###############                                                                                                
##Create header
###############
#my $file = "doc.hd";
my $file = "$hd"."AdditiveReportDoc.hd";
open (IN, $file) or die "Problems opening $file \n";

my $bb=uc$project_name;
while (<IN>) {
  mychomp($_);
  my $aa = $_;
  if ($aa =~ /title\{APIIS/){
    print OUT '\\title{'."$bb".'\\\\'."\n";
  } elsif ($aa =~ /Large\{The APIIS/){
    print OUT '\\Large{The '."$bb".'\\\\'."\n";
  } elsif ($aa =~ /chead{APIIS/){
    print OUT '\\chead{'."$bb".' - Reference Database}'."\n";
  } else {
    print OUT "$_ \n";
  }
}
############################################################

my $xmin=9999999999;
my $xmax=-9999999999;
my $y1min=9999999999;
my $y1max=-9999999999;
my $y2min=9999999999;
my $y2max=-9999999999;
my $y3min=9999999999;
my $y3max=-9999999999;
my $y4min=9999999999;
my $y4max=-9999999999;

my $yy2;
if ($gen){
   $npop=$gen;
} else {
   my $vv;
   foreach my $yy (sort keys %calc){
     $vv=$yy;
     last;   
   }
   $yy2=$vv+(round2($npop));
}
foreach my $yy (sort keys %calc){
  if (($yy * 1) > $xmax){$xmax = $yy;}#year
  if (($yy * 1) < $xmin){$xmin = $yy;}
  my $vv;
  if ($gen){
     $vv=($yy*1) + $npop;
  } else {
     $yy2=$yy+(round2($npop));     
     my $sq = "select pop from tmp1_gen where year = '$yy2'";
     my $sql_ref33 = $apiis->DataBase->sys_sql($sq);
     $apiis->check_status ;
     while( my $line_ref33 = $sql_ref33->handle->fetch ) {
        @line = @$line_ref33;
        $npop = round2($line[0]);
     }
     $vv=($yy*1) + $npop;
     
  }
  #Force a 0 value to be seen
  if (! $calc{$yy}[1] and defined $calc{$yy}[0]){$calc{$yy}[1]='0.0000000000000001';}
  if (! $calc{$vv}[1] and defined $calc{$vv}[0]){$calc{$vv}[1]='0.0000000000000001';}
 #if animals in both years
  if ($calc{$vv}[0] and $calc{$yy}[0]){
     #calqulate Delta F
     $calc{$vv}[2] = (($calc{$vv}[1] - $calc{$yy}[1])/(1 - $calc{$yy}[1]));
     #if both years coefficients = each other Delta F = 0
     #Force a 0 value to be seen
     if ($calc{$vv}[1] == $calc{$yy}[1]){$calc{$vv}[2] = '0.0000000000000001';}
     #Force a - value to undefined
     #if ($calc{$vv}[2] < 0){$calc{$vv}[2] = undef;}
     #calqulate efective population size 
     if ($calc{$vv}[2] and $calc{$vv}[2] > 0.0000000000000001){
       $calc{$vv}[3] = round(1 / ($calc{$vv}[2] * 2));
     } else {
       $calc{$vv}[3]=undef;
     }
  }
  if ($calc{$yy}[0] and $calc{$yy}[0] > $y1max){$y1max = $calc{$yy}[0];}#number
  if ($calc{$yy}[0] and $calc{$yy}[0] < $y1min){$y1min = $calc{$yy}[0];}
  if ($calc{$yy}[1] and $calc{$yy}[1] > $y2max){$y2max = $calc{$yy}[1];}#coef
  if ($calc{$yy}[1] and $calc{$yy}[1] < $y2min){$y2min = $calc{$yy}[1];}
  if ($calc{$yy}[2] and $calc{$yy}[2] > $y3max){$y3max = $calc{$yy}[2];}#cof
  if ($calc{$yy}[2] and $calc{$yy}[2] < $y3min){$y3min = $calc{$yy}[2];}
  if ($calc{$yy}[3] and $calc{$yy}[3] > $y4max){$y4max = $calc{$yy}[3];}#pop
  if ($calc{$yy}[3] and $calc{$yy}[3] < $y4min){$y4min = $calc{$yy}[3];}
}##############

my $startyear=$xmin;
my $endyear=$xmax;
my $sql2 = "select year, number, sires, dams from tmp2_repne2 
where year notnull and breed ='$short' and (year >= $startyear and year <= $endyear) and number > 0 order by breed,year";#tabel 1 for numbers

my $sql_ref4 = $apiis->DataBase->sys_sql($sql2);
$apiis->check_status ;
while( my $line_ref4 = $sql_ref4->handle->fetch ) {
   my @line = @$line_ref4;
   my $yy=$line[0];
   next if $yy eq 'over years' or $yy eq 'total';
   $calc{$yy}[4] = $line[1] if $line[1];#number
   $calc{$yy}[5] = $line[2] if $line[2];#sires
   $calc{$yy}[6] = $line[3] if $line[3];#dams
}
my $sql3 = "select year, number, minimum, maximum, average,variance from tmp2_inbryear 
where year notnull and breed='$short' and (year >= $startyear and year <= $endyear)  and number > 0 order by breed,year";#table 2 for inbreeding

$sql_ref4 = $apiis->DataBase->sys_sql($sql3);
$apiis->check_status ;
while( my $line_ref4 = $sql_ref4->handle->fetch ) {
   my @line = @$line_ref4;
   my $yy=$line[0];
   next if $yy eq 'over years' or $yy eq 'total';
   $calc{$yy}[7] = $line[1] if $line[1];#number
   $calc{$yy}[8] = $line[4] if $line[4];#avg coeff
}

my $sql4 = "select year, progenyf, parentsf, deltaf, ne from tmp2_repne1 
where year notnull and breed='$short' and (year >= $startyear and year <= $endyear) and number > 0 order by breed,year";#table 3 for Ne deltaF

$sql_ref4 = $apiis->DataBase->sys_sql($sql4);
$apiis->check_status ;
while( my $line_ref4 = $sql_ref4->handle->fetch ) {
   my @line = @$line_ref4;
   my $yy=$line[0];
   next if $yy eq 'over years' or $yy eq 'total';
   $calc{$yy}[9] = $line[3] if $line[3];#DeltaF inbreed
   $calc{$yy}[10] = $line[4] if $line[4];#Ne Inbreed
}
my $ff = 'Tabel1'."$short".'.txt';
$delfile{$ff}[0]=1;
open (OUT4, ">$ff") or die "Problems opening file $ff: $!\n";
foreach my $yy (sort keys %calc){
  if ($yy >= $startyear and $yy <= $endyear){
  my $str='A15';
  print OUT4 pack($str, $yy);
  if ($calc{$yy}[0]){print OUT4 pack($str, $calc{$yy}[0]);#number AGR 
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[4]){print OUT4 pack($str, $calc{$yy}[4]);#number Real
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[5]){print OUT4 pack($str, $calc{$yy}[5]);#sires
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[6]){print OUT4 pack($str, $calc{$yy}[6]);#dams
  } else {print OUT4 pack($str,'-');}
  print OUT4 "\n";
}
}
close OUT4;
$ff = 'Tabel2'."$short".'.txt';
$delfile{$ff}[0]=1;
open (OUT4, ">$ff") or die "Problems opening file $ff: $!\n";
foreach my $yy (sort keys %calc){
  if ($yy >= $startyear and $yy <= $endyear){
  my $str='A15';
  print OUT4 pack($str, $yy);
  if ($calc{$yy}[0]){print OUT4 pack($str, $calc{$yy}[0]);#number AGR
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[7]){print OUT4 pack($str, $calc{$yy}[7]);#number Inbreed
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[8]){print OUT4 pack($str, $calc{$yy}[8]);#avg Inbreed coeff
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[1]){print OUT4 pack($str, $calc{$yy}[1]);#AGR coeff
  } else {print OUT4 pack($str,'-');}
  print OUT4 "\n";
}
}
close OUT4;
$ff = 'Tabel3'."$short".'.txt';
$delfile{$ff}[0]=1;
open (OUT4, ">$ff") or die "Problems opening file $ff: $!\n";
foreach my $yy (sort keys %calc){
  if ($yy >= $startyear and $yy <= $endyear){
  my $str='A20';
  print OUT4 pack($str, $yy);
  if ($calc{$yy}[0]){print OUT4 pack($str, $calc{$yy}[0]);#number AGR
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[9]){print OUT4 pack($str, $calc{$yy}[9]);#DeltaF Inbreed
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[10]){print OUT4 pack($str, $calc{$yy}[10]);#Ne Inbreed
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[2]){$calc{$yy}[2]=sprintf("%.8f", $calc{$yy}[2]);print OUT4 pack($str,$calc{$yy}[2] );#DeltaF AGR
  } else {print OUT4 pack($str,'-');}
  if ($calc{$yy}[3]){print OUT4 pack($str, $calc{$yy}[3]);#Ne AGR
  } else {print OUT4 pack($str,'-');}
  print OUT4 "\n";
}
}
close OUT4;


##Create report.0
#################
#$file = "report.0.hd";
$file = "$hd"."AdditiveReport_0.hd";
open (IN, $file) or die "Problems opening $file \n";
while (<IN>) {
  mychomp($_);
  print OUT "$_ \n";
}
my $title = 'Average Additive Genetic Relationships (AGR) for '."$dbbname";                                                                                                
my $tabalign='c';

print OUT '\begin{center}{
    \begin{longtable}{|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|}
\caption{'." $title".' } \\\\
\hline ';
print OUT 'Year& Number& Average& Delta & Effective \\\\'."\n".' \hline';
print OUT ' Born & Born & AGR & AGR & Population Size \\\\'."\n";
print OUT '\hline \endfirsthead '."\n";

  print OUT '\caption*{\textit{Continue...}} \\\\
  \hline ';
print OUT 'Year& Number& Average& Delta & Effective \\\\'."\n".' \hline';
print OUT ' Born & Born & AGR & AGR & Population Size \\\\'."\n";
print OUT '\hline \endhead '."\n";


$yy2=undef;
if ($gen){
   $npop=$gen;
} else {
   my $vv;
   foreach my $yy (sort keys %calc){
     $vv=$yy;
     last;   
   }
   $yy2=$vv+(round2($npop));
}

foreach my $yy (sort keys %calc){
  if ($yy >= $startyear and $yy <= $endyear){
  if (($yy * 1) > $xmax){$xmax = $yy;}#year
  if (($yy * 1) < $xmin){$xmin = $yy;}
  my $vv;
  if ($gen){
     $vv=($yy*1) + $npop;
  } else {
  $yy2=$yy+(round2($npop));
     my $sq = "select pop from tmp1_gen where year = '$yy2'";
     my $sql_ref33 = $apiis->DataBase->sys_sql($sq);
     $apiis->check_status ;
     while( my $line_ref33 = $sql_ref33->handle->fetch ) {
        @line = @$line_ref33;
        $npop = round2($line[0]);
     }
     $vv=($yy*1) + $npop;
  }
  my $i=0;
  my $str = 'A15';
  print OUT "$yy".' & ';
  print OUT1 pack($str, $yy);
  for ($i=0; $i < 4; $i++){
   if ($i < 1){
     #print number
     if ($calc{$yy}[$i]){print OUT "$calc{$yy}[$i]".' & ';} else {print OUT ' & ';}
     if ($calc{$yy}[$i]){print OUT1 pack($str, $calc{$yy}[$i]);} else {print OUT pack($str,'-');}
   } else {
    #   previuos year N       current year N     following year Delta F
    if ($calc{$yy-$npop}[0] and $calc{$vv}[0] and (defined $calc{$yy}[2] and $calc{$yy}[2] > 0.0000000000000001)){
       if ($i < 2){
       my $bb=sprintf("%.4f",$calc{$yy}[$i]);
       print OUT "$bb".' & ';
       print OUT1 sprintf("%.8f",$calc{$yy}[$i]);
       print OUT1 '     ';
       } elsif ($i < 3) {
       my $bb=sprintf("%.4f",$calc{$yy}[$i]);
       print OUT "$bb".' & ';
       print OUT1 sprintf("%.8f",$calc{$yy}[$i]);
       print OUT1 '     ';
       } else {
       my $bb = sprintf("%.0f",$calc{$yy}[$i]);
       print OUT "$bb";
       print OUT1 sprintf("%.0f",$calc{$yy}[$i]);
       print OUT1 '     ';
       }
    } else {
       if ($calc{$yy}[$i]){
         $str='A15';
         if ($i < 3){
           if ($i == 1){
             my $bb =sprintf("%.4f",$calc{$yy}[$i]);
             print OUT "$bb".'&';
           } else {
             my $bb =sprintf("%.4f",$calc{$yy}[$i]);
             print OUT "$bb".' & ';
           }
         print OUT1 sprintf("%.8f", $calc{$yy}[$i]);
         print OUT1 '     ';
         } else {
         print OUT "$calc{$yy}[$i]";
         print OUT1 sprintf("%.0f", $calc{$yy}[$i]);
         print OUT1 '     ';
         }
         $str='A15';
       } else {
         if ($i < 3){
           print OUT ' & ';
         }
         print OUT1 pack($str, '-');
       }
     }
   }
  }
  print OUT '\\\\'."\n";
  print OUT1 "\n";
}
}
print OUT '\hline'."\n".'
\end{longtable}
}'."\n".'\end{center}'."\n".'

\begin{flushleft}
Time interval used to calculate Delta AGR: '."$npop".'\\\\'."\n";
print OUT 'Effective population size is based on Delta AGR
\end{flushleft}
\clearpage
'."\n";

close OUT1;

next if -z $dbbout;

######################################################################
#Create graphics
######################################################################
# x=year, y1=num, y2=cof, y3=Delta, y4=pop
$y1min=0; $y2min=0; $y3min=0; $y4min=0;
######################################################################
open (OUT2, '>gnu_bobplot1.txt') or die "Can not open gnu_bobplot.txt\n";
$delfile{'gnu_bobplot1.txt'}[0]=1;
print OUT2 "set terminal postscript \n";
#print OUT2 "set terminal corel \n";
print OUT2 'set output "' . "ADDGEN_Breed1_". "$short".'.ps"'."\n";
$delfile{'ADDGEN_Breed1_'. "$short".'.ps'}[0]=1;
print OUT2 'set xrange ['."$xmin".':'."$xmax".']'."\n";
my $ss;
if (($xmax-$xmin) > 10) {$ss = round(($xmax-$xmin)/10);} else {$ss = 1;}
print OUT2 "set xtics $ss \n";
$y2max=$y2max+0.01;
print OUT2 'set yrange ['."$y2min".':'."$y2max".']'."\n"; #min and max of AGR coef
print OUT2 'set ytics '."$y2max".'/10'."\n";
$y1max=$y1max+5;
print OUT2 'set y2range ['."$y1min".':'."$y1max".']'."\n"; #min and max of number of animals
print OUT2 'set y2tics '."$y1max".'/10'."\n";
print OUT2 "set ytics nomirror \n";
print OUT2 "set xtics nomirror \n";
print OUT2 "set border 11 \n";
print OUT2 'set title "'.'Average additive genetic relationships for '."$dbbname".'" font "'.'Times-Roman-Bold,20"'."\n";
print OUT2 'set y2label "'.'Number of Animals"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 'set ylabel "'.'Additive Genetic Relationship"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 "set style line 1 lt 1 lw 15 \n";
print OUT2 "set key below \n";
print OUT2 'plot "'."$dbbout".'" using 1:2 title "'.'Number of animals"'.' lt 5 lw 3 axis x1y2 smooth csp  w lines , "'."$dbbout".'" using 1:3 title "'.'Additive Rel."'.' lt 1 lw 2 axis x1y1  smooth csp w lines'."\n";
##########################################################################END
close OUT2;

######################################################################
open (OUT3, '>gnu_bobplot2.txt') or die "Can not open gnu_bobplot.txt\n";
$delfile{'gnu_bobplot2.txt'}[0]=1;
print OUT3 "set terminal postscript \n";
#print OUT3 "set terminal corel \n";
print OUT3 'set output "' . "ADDGEN_Breed2_". "$short".'.ps"'."\n";
$delfile{'ADDGEN_Breed2_'. "$short".'.ps'}[0]=1;
print OUT3 'set xrange ['."$xmin".':'."$xmax".']'."\n";
print OUT3 "set xtics $ss \n";
print OUT3 'set yrange ['."$y2min".':'."$y2max".']'."\n"; #min and max of AGR coef
print OUT3 'set ytics '."$y2max".'/10'."\n";
print OUT3 'set y2range ['."$y1min".':'."$y1max".']'."\n"; #min and max of number of animals
print OUT3 'set y2tics '."$y1max".'/10'."\n";
print OUT3 "set ytics nomirror \n";
print OUT3 "set xtics nomirror \n";
print OUT3 "set border 11 \n";
print OUT3 'set title "'.'Average additive genetic relationships for '."$dbbname".'" font "'.'Times-Roman-Bold,20"'."\n";
print OUT3 'set y2label "'.'Number of Animals"'.' font "'.'Times-Italic,20"'."\n";
print OUT3 'set ylabel "'.'Additive Genetic Relationship"'.' font "'.'Times-Italic,20"'."\n";
print OUT3 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,20"'."\n";
print OUT3 "set style line 1 lt 1 lw 15 \n";
#print OUT3 'plot "'."$dbbout".'" using 1:2 title "'.'Number of animals"'.' lt 5 lw 2 axis x1y2 smooth csp  w lines , "'."$dbbout".'" using 1:3 title "'.'Additive Rel."'.' lt 1 lw 2 axis x1y1  smooth csp w lines'."\n";
#######
#
print OUT3 'set yrange ['."$y4min".':'."$y4max".']'."\n"; #min and max of effective pop size
print OUT3 'set ytics '."$y4max".'/10'."\n";
print OUT3 'set y2range ['."$y1min".':'."$y1max".']'."\n"; #min and max of number of animals
print OUT3 'set y2tics '."$y1max".'/10'."\n";
print OUT3 "set ytics nomirror \n";
print OUT3 "set xtics nomirror \n";
print OUT3 "set border 11 \n";
print OUT3 'set title "'.'Effective Population Size base on Additive Relationship for '."$dbbname".'" font "'.'Times-Roman-Bold,20"'."\n";
print OUT3 'set y2label "'.'Number of Animals Born"'.' font "'.'Times-Italic,20"'."\n";
print OUT3 'set ylabel "'.'Effective Population Size"'.' font "'.'Times-Italic,20"'."\n";
print OUT3 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,20"'."\n";
print OUT3 "set key below \n";
print OUT3 'plot "'."$dbbout".'" using 1:2 title "'.'Number of animals"'.'  lt 5 lw 2 axis x1y2 smooth csp  w lines  , "'."$dbbout".'" using 1:5 title "'.'Effect. Popul. Size"'.' axis x1y1 w imp ls 1'."\n";
##########################################################################END
close OUT3;


system("gnuplot < gnu_bobplot1.txt >/dev/null");
system("gnuplot < gnu_bobplot2.txt >/dev/null");

print OUT '
\begin{figure}[h]
\subsection{Graph 1:  Average additive genetic relationships for '."$dbbname".'}'.'
\begin{flushleft}
\includegraphics[scale=.8]{./ADDGEN_Breed1_'."$short".'.ps}
\end{flushleft}
\end{figure}
'."\n";


print OUT '
\begin{figure}[h]
\begin{flushleft}
\subsection{Graph 2:  Effective Population Size base on Additive Relationship for '."$dbbname".'}'.'
\includegraphics[scale=.8]{./ADDGEN_Breed2_'."$short".'.ps}
\label{fig:blabla}
\end{flushleft}
\end{figure}
'."\n";

#################
##Create tabel.1
#################
#$file = "tabel.1.hd";
$file = "$hd"."AdditiveReport_1.hd";

open (IN, $file) or die "Problems opening $file \n";
while (<IN>) {
  mychomp($_);
  print OUT "$_ \n";
}
$title = 'Real numbers of animals and parents for '."$dbbname";
$tabalign='c';
print OUT '\begin{center}{
    \begin{longtable}{|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|}
\caption{'." $title".' } \\\\
\hline ';
print OUT 'Year& Number& Number& Sires & Dams \\\\'."\n".' \hline';
print OUT ' Born & AGR & animals & Used & Used \\\\'."\n";
print OUT '\hline \endfirsthead '."\n";

  print OUT '\caption*{\textit{Continue...}} \\\\
  \hline ';
print OUT 'Year& Number& Number& Sires & Dams \\\\'."\n".' \hline';
print OUT ' Born & AGR & animals & Used & Used \\\\'."\n";
print OUT '\hline \endhead '."\n";

$xmin=9999999999;
$xmax=-9999999999;
$y1min=9999999999;
$y1max=-9999999999;
$y2min=9999999999;
$y2max=-9999999999;

foreach my $yy (sort keys %calc){
  if ($yy >= $startyear and $yy <= $endyear){
  if (($yy * 1) > $xmax){$xmax = ($yy * 1);}
  if (($yy * 1) < $xmin){$xmin = ($yy * 1);}
  print OUT "$yy".' & ';#year
  my $bb = sprintf("%.0f",$calc{$yy}[0]) if $calc{$yy}[0];#number AGR
  if ($calc{$yy}[0]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  $bb = sprintf("%.0f",$calc{$yy}[4]) if $calc{$yy}[4];#number Real
  if ($calc{$yy}[4] and $calc{$yy}[4] < $y1min){ $y1min = $calc{$yy}[4];}
  if ($calc{$yy}[4] and $calc{$yy}[4] > $y1max){ $y1max = $calc{$yy}[4];}
  if ($calc{$yy}[4]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  $bb = sprintf("%.0f",$calc{$yy}[5]) if $calc{$yy}[5];#sires
  if ($calc{$yy}[5] and $calc{$yy}[5] < $y2min){ $y2min = $calc{$yy}[5];}
  if ($calc{$yy}[5] and $calc{$yy}[5] > $y2max){ $y2max = $calc{$yy}[5];}
  if ($calc{$yy}[5]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  $bb = sprintf("%.0f",$calc{$yy}[6]) if $calc{$yy}[6];#dams
  if ($calc{$yy}[6] and $calc{$yy}[6] < $y2min){ $y2min = $calc{$yy}[6];}
  if ($calc{$yy}[6] and $calc{$yy}[6] > $y2max){ $y2max = $calc{$yy}[6];}
  if ($calc{$yy}[6]){print OUT "$bb";} else {print OUT ' ';}
  print OUT '\\\\'."\n";
}
}
print OUT '\hline
\end{longtable}
}
\end{center}
'."\n";
######################################################################
#Create graphics1
######################################################################
$y1min=0;
$y1max=$y1max+50;
$y2min=0;
$y2max=$y2max+50;
open (OUT2, '>gnu_tabel1.txt') or die "Can not open gnu_tabel1.txt\n";
$delfile{'gnu_tabel1.txt'}[0]=1;
print OUT2 "set terminal postscript \n";
print OUT2 'set output "' . "Graph1". "$short".'.ps"'."\n";
$delfile{'Graph1'. "$short".'.ps'}[0]=1;
print OUT2 'set xrange ['."$xmin".':'."$xmax".']'."\n";
$ss;
if (($xmax-$xmin) > 10) {$ss = round(($xmax-$xmin)/10);} else {$ss = 1;}
print OUT2 "set xtics $ss \n";
print OUT2 'set yrange ['."$y2min".':'."$y2max".']'."\n"; #min and max of AGR coef
print OUT2 'set ytics '."$y2max".'/10'."\n";
print OUT2 'set y2range ['."$y1min".':'."$y1max".']'."\n"; #min and max of number of animals
print OUT2 'set y2tics '."$y1max".'/10'."\n";
print OUT2 "set ytics nomirror \n";
print OUT2 "set xtics nomirror \n";
print OUT2 "set border 11 \n";
print OUT2 'set title "'.'Real numbers of animals and parents for '."$dbbname".'" font "'.'Times-Roman-Bold,20"'."\n";
print OUT2 'set y2label "'.'Number of Animals"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 'set ylabel "'.'Real number of sires and dams"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 "set style line 1 lt 1 lw 15 \n";
print OUT2 "set key below \n";
$ff = 'Tabel1'."$short".'.txt';
print OUT2 'plot "'."$ff".'" using 1:3 title "'.'Animals"'.' lt 5 lw 3 axis x1y2 smooth csp  w lines , "'."$ff".'" using 1:4 title "'.'Sires"'.' lt 1 lw 2 axis x1y1 smooth csp  w lines , "'."$ff".'" using 1:5 title "'.'Dams"'.' lt 2 lw 2 axis x1y1  smooth csp w lines'."\n";
system("gnuplot < gnu_tabel1.txt >/dev/null");
close OUT2;
##########################################################################END
print OUT '
\begin{figure}[h]
\subsection{Graph 3:  Real numbers of animals and parents for '."$dbbname".'}'.'
\begin{flushleft}
\includegraphics[scale=.8]{./Graph1'."$short".'.ps}
\end{flushleft}
\end{figure}
'."\n";

#################
##Create tabel.2
#################
#$file = "tabel.2.hd";
$file = "$hd"."AdditiveReport_2.hd";
open (IN, $file) or die "Problems opening $file \n";
while (<IN>) {
  mychomp($_);
  print OUT "$_ \n";
}
$title = 'Average AGR and Inbreeding Coefficient for '."$dbbname";
$tabalign='c';
print OUT '\begin{table}[h]
\centering{
\caption{'." $title".' }
\begin{tabular}{|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|}
\hline ';
print OUT 'Year& Number& Number&Avg Inbreeding  & Average \\\\'."\n".' \hline';
print OUT ' & AGR & animals & Coeffisient & AGR \\\\'."\n";
print OUT '\hline';
$xmin=9999999999;
$xmax=-9999999999;
$y1min=9999999999;
$y1max=-9999999999;
$y2min=9999999999;
$y2max=-9999999999;

foreach my $yy (sort keys %calc){
  if ($yy >= $startyear and $yy <= $endyear){
  if (($yy * 1) > $xmax){$xmax = ($yy * 1);}
  if (($yy * 1) < $xmin){$xmin = ($yy * 1);}
  print OUT "$yy".' & ';
  my $bb = sprintf("%.0f",$calc{$yy}[0]) if $calc{$yy}[0];#number AGR
  if ($calc{$yy}[0]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  $bb = sprintf("%.0f",$calc{$yy}[7]) if $calc{$yy}[7];#number Inbreed
  if ($calc{$yy}[7]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  if ($calc{$yy}[8] and $calc{$yy}[8] < $y1min){ $y1min = $calc{$yy}[8];}
  if ($calc{$yy}[8] and $calc{$yy}[8] > $y1max){ $y1max = $calc{$yy}[8];}
  $bb = sprintf("%.8f",$calc{$yy}[8]) if $calc{$yy}[8];#avg Inbreed coeff
  if ($calc{$yy}[8]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  if ($calc{$yy}[1] and $calc{$yy}[1] < $y1min){ $y1min = $calc{$yy}[1];}
  if ($calc{$yy}[1] and $calc{$yy}[1] > $y1max){ $y1max = $calc{$yy}[1];}
  $bb = sprintf("%.8f",$calc{$yy}[1]) if $calc{$yy}[1];#AGR coeff
  if ($calc{$yy}[1]){print OUT "$bb";} else {print OUT ' ';}
  print OUT '\\\\'."\n";
  }
}
print OUT '\hline
\end{tabular}
}
\end{table}
'."\n";
######################################################################
#Create graphics2
######################################################################
$y1min=$y1min-0.01;
$y1max=$y1max+0.01;
open (OUT2, '>gnu_tabel2.txt') or die "Can not open gnu_tabel1.txt\n";
$delfile{'gnu_tabel2.txt'}[0]=1;
print OUT2 "set terminal postscript \n";
print OUT2 'set output "' . "Graph2". "$short".'.ps"'."\n";
$delfile{'Graph2'. "$short".'.ps'}[0]=1;
print OUT2 'set xrange ['."$xmin".':'."$xmax".']'."\n";
$ss;
if (($xmax-$xmin) > 10) {$ss = round(($xmax-$xmin)/10);} else {$ss = 1;}
print OUT2 "set xtics $ss \n";
print OUT2 'set yrange ['."$y1min".':'."$y1max".']'."\n"; #min and max of AGR coef
print OUT2 'set ytics '."$y1max".'/10'."\n";
print OUT2 "set ytics nomirror \n";
print OUT2 "set xtics nomirror \n";
print OUT2 "set border 11 \n";
print OUT2 'set title "'.'Average AGR and Inbreeding Coefficient for '."$dbbname".'" font "'.'Times-Roman-Bold,20"'."\n";
print OUT2 'set ylabel "'.'Coeffisient"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 "set style line 1 lt 1 lw 15 \n";
print OUT2 "set key below \n";
$ff = 'Tabel2'."$short".'.txt';
print OUT2 'plot "'."$ff".'" using 1:4 title "'.'Inbreeding"'.' lt 5 lw 3 axis x1y1 smooth csp  w lines , "'. "$ff".'" using 1:5 title "'.'AGR"'.' lt 1 lw 2 axis x1y1  smooth csp w lines'."\n";
system("gnuplot < gnu_tabel2.txt >/dev/null");
close OUT2;
##########################################################################END
print OUT '
\begin{figure}[h]
\subsection{Graph 4:  Average AGR and Inbreeding Coefficient for '."$dbbname".'}'.'
\begin{flushleft}
\includegraphics[scale=.8]{./Graph2'."$short".'.ps}
\end{flushleft}
\end{figure}
'."\n";

#################
##Create tabel.3
#################
#$file = "tabel.3.hd";
$file = "$hd"."AdditiveReport_3.hd";
open (IN, $file) or die "Problems opening $file \n";
while (<IN>) {
  mychomp($_);
  print OUT "$_ \n";
}
$title = 'Ne from DeltaF inbreeding and Ne from AGR for '."$dbbname";
$tabalign='c';
print OUT '\begin{table}[h]
\centering{
\caption{'." $title".' }
\begin{tabular}{|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|'."$tabalign".'|}
\hline ';
print OUT 'Year& Number& DeltaF     &Ne  & DeltaF & Ne \\\\'."\n".' \hline';
print OUT ' & AGR      & Inbreeding & Inbreeding & AGR & AGR \\\\'."\n";
print OUT '\hline';
$xmin=9999999999;
$xmax=-9999999999;
$y1min=9999999999;
$y1max=-9999999999;
$y2min=9999999999;
$y2max=-9999999999;
$yy2=undef;
if ($gen){
   $npop=$gen;
} else {
   my $vv;
   foreach my $yy (sort keys %calc){
     $vv=$yy;
     last;   
   }
   $yy2=$vv+(round2($npop));
}

foreach my $yy (sort keys %calc){
  if ($yy >= $startyear and $yy <= $endyear){
  if (($yy * 1) > $xmax){$xmax = ($yy * 1);}
  if (($yy * 1) < $xmin){$xmin = ($yy * 1);}
  my $vv;
  if ($gen){
     $vv=($yy*1) + $npop;
  } else {
  $yy2=$yy+(round2($npop));
     my $sq = "select pop from tmp1_gen where year = '$yy2'";
     my $sql_ref33 = $apiis->DataBase->sys_sql($sq);
     $apiis->check_status ;
     while( my $line_ref33 = $sql_ref33->handle->fetch ) {
        @line = @$line_ref33;
        $npop = round2($line[0]);
     }
     $vv=($yy*1) + $npop;
  }
#  my $vv=($yy*1) + $gen;
  print OUT "$yy".' & ';
  my $bb = sprintf("%.0f",$calc{$yy}[0]) if $calc{$yy}[0];#number AGR
  if ($calc{$yy}[0]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  if ($calc{$yy}[9] and $calc{$yy}[9] < $y1min){ $y1min = $calc{$yy}[9];}
  if ($calc{$yy}[9] and $calc{$yy}[9] > $y1max){ $y1max = $calc{$yy}[9];}
  $bb = sprintf("%.5f",$calc{$yy}[9]) if $calc{$yy}[9];#DeltaF Inbreed
  if ($calc{$yy}[9]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  if ($calc{$yy}[10] and $calc{$yy}[10] < $y2min){ $y2min = $calc{$yy}[10];}
  if ($calc{$yy}[10] and $calc{$yy}[10] > $y2max){ $y2max = $calc{$yy}[10];}
  $bb = sprintf("%.0f",$calc{$yy}[10]) if $calc{$yy}[10];#Ne Inbreed
  if ($calc{$yy}[10]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  if ($calc{$yy-$npop}[0] and $calc{$vv}[0] and (defined $calc{$yy}[2] and $calc{$yy}[2] > 0.0000000000000001)){
  if ($calc{$yy}[2] and $calc{$yy}[2] < $y1min){ $y1min = $calc{$yy}[2];}
  if ($calc{$yy}[2] and $calc{$yy}[2] > $y1max){ $y1max = $calc{$yy}[2];}
  $bb = sprintf("%.4f",$calc{$yy}[2]) if $calc{$yy}[2];#DeltaF AGR
  if ($calc{$yy}[2]){print OUT "$bb".' & ';} else {print OUT ' & ';}
  if ($calc{$yy}[3] and $calc{$yy}[3] < $y2min){ $y2min = $calc{$yy}[3];}
  if ($calc{$yy}[3] and $calc{$yy}[3] > $y2max){ $y2max = $calc{$yy}[3];}
  $bb = sprintf("%.0f",$calc{$yy}[3]) if $calc{$yy}[3];#Ne AGR
  if ($calc{$yy}[3]){print OUT "$bb";} else {print OUT ' ';}
  } else {
    if ($calc{$yy}[2]){
  if ($calc{$yy}[2] and $calc{$yy}[2] < $y1min){ $y1min = $calc{$yy}[2];}
  if ($calc{$yy}[2] and $calc{$yy}[2] > $y1max){ $y1max = $calc{$yy}[2];}
      $bb = sprintf("%.4f",$calc{$yy}[2]);#DeltaF AGR
      if ($calc{$yy}[2]){print OUT "$bb".' & ';} else {print OUT ' & ';}
    } else {
      print OUT  ' & ';
    }
    if ($calc{$yy}[3]){
  if ($calc{$yy}[3] and $calc{$yy}[3] < $y2min){ $y2min = $calc{$yy}[3];}
  if ($calc{$yy}[3] and $calc{$yy}[3] > $y2max){ $y2max = $calc{$yy}[3];}
      $bb = sprintf("%.0f",$calc{$yy}[3]);#Ne AGR
      if ($calc{$yy}[3]){print OUT "$bb";} else {print OUT '';}
    } else {
      print OUT  '                ';
    }
  }
  
  print OUT '\\\\'."\n";
}
}
print OUT '\hline
\end{tabular}
}
\end{table}
'."\n";
######################################################################
#Create graphics3
######################################################################
$y1min=$y1min-.01;
$y1max=$y1max+.01;
$y2min=0;
$y2max=$y2max+50;
open (OUT2, '>gnu_tabel3.txt') or die "Can not open gnu_tabel3.txt\n";
$delfile{'gnu_tabel3.txt'}[0]=1;
print OUT2 "set terminal postscript \n";
print OUT2 'set output "' . "Graph3". "$short".'.ps"'."\n";
$delfile{'Graph3'. "$short".'.ps'}[0]=1;
print OUT2 'set xrange ['."$xmin".':'."$xmax".']'."\n";
$ss;
if (($xmax-$xmin) > 10) {$ss = round(($xmax-$xmin)/10);} else {$ss = 1;}
print OUT2 "set xtics $ss \n";
print OUT2 'set y2range ['."$y2min".':'."$y2max".']'."\n"; #min and max of number
print OUT2 'set y2tics '."$y2max".'/10'."\n";
my $vv;
if (($y1max-$y1min) > 10) {$vv = round(($y1max-$y1min)/10);} else {$vv = 1;}
print OUT2 'set yrange ['."$y1min".':'."$y1max".']'."\n"; #min and max of Delta
print OUT2 'set ytics '."$y1max".'/10'."\n";
print OUT2 "set ytics nomirror \n";
print OUT2 "set xtics nomirror \n";
print OUT2 "set border 11 \n";
print OUT2 "set boxwidth 0.2 \n";
print OUT2 'set title "'.'Ne from DeltaF inbreeding and Ne from AGR for '."$dbbname".'" font "'.'Times-Roman-Bold,20"'."\n";
print OUT2 'set ylabel "'.'DeltaF"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 'set y2label "'.'Effective population size"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,20"'."\n";
print OUT2 "set style line 1 lt 1 lw 15 \n";
print OUT2 "set key below \n";
$ff = 'Tabel3'."$short".'.txt';
print OUT2 'plot "'."$ff".'" using 1:3 title "'.'DeltaF Inb"'.' lt 5 lw 3 axis x1y1 smooth csp w lines , "'."$ff".'" using 1:5 title "'.'DeltaF AGR"'.' lt 4 lw 3 axis x1y1 smooth csp w lines , "'."$ff".'" using 1:4 title "'.'Ne Inbeeding"'.' axis x1y2  w boxes fs pattern 1 , "'."$ff".'" using ($1+0.3):6 title "'.'Ne AGR"'.' axis x1y2 w boxes fs solid lw 0.5'."\n";
system("gnuplot < gnu_tabel3.txt >/dev/null");
close OUT2;
##########################################################################END
print OUT '
\begin{figure}[h]
\subsection{Graph 5:  Ne from DeltaF inbreeding and Ne from AGR for '."$dbbname".'}'.'
\begin{flushleft}
\includegraphics[scale=.8]{./Graph3'."$short".'.ps}
\end{flushleft}
\end{figure}
'."\n";


#################################

print OUT "\n".'\end{document}'."\n";

close OUT;

system("latex $outputfile");
system("latex $outputfile");
system("latex $outputfile");
system("dvips -q -f $output.dvi -o $output.ps");
system("ps2pdfwr $output.ps $output.pdf");
#system("gv $output.ps");
                                                                                                
system("rm -f $output.dvi");
system("rm -f $output.aux");
#system("rm -f $output.tex");
system("rm -f $output.log");
system("rm -f $output.lot");
system("rm -f $output.lof");
system("rm -f $output.toc");
##################################################
# Cleanup
##################################################
foreach my $id (sort keys %datafile){
  system("rm -f $id");
}
foreach my $id (sort keys %delfile){
  system("rm -f $id");
}

##################################################

}#end of breed loop

sub round {
        my $number  = shift;
        return int($number + .5);
}

sub round2 {
        my $number  = shift;
        return int($number + .9);
}


1;
  __END__
