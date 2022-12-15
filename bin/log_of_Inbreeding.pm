#!/usr/bin/env perl
##############################################################################
BEGIN {
    use Env qw( APIIS_HOME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
}
#######################################################################################
# After a run of inbreeding_report you can reprint log(1 - F) between any 2 given years
# you must hafe a idea what is the generation interval
####################################################################################### 
use strict;
use warnings;

use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.4 $ ' );
our $apiis;
use Apiis::DataBase::User;
use Apiis::Misc qw ( mychomp );    # ...
use Data::Dumper;
use vars qw / $i $line_ref $k %treein $sql %ped $breed $dbh $male $gen %delfiles $dbb $avg_pop_gen $nn/;
use vars qw( $opt_h $opt_a $opt_b $opt_c $opt_d $opt_e $opt_f);
use Getopt::Std;
getopts('h:a:b:c:d:e:f:');

usage() if $opt_h;
usage() if !$opt_a;
usage() if !$opt_b;
usage() if !$opt_c;
usage() if !$opt_d;

$avg_pop_gen=$opt_d;
$breed = $opt_a;
my $bbreed = $opt_b.'_'.$opt_c.$breed;

my $out_put=">Inbreeding_log_$breed";
open (OUT1BB, "$out_put") or die "Can not open $out_put\n";

my $out_put2="<Inbreeding_log_.$breed.csv";
open (IN, "$out_put2") or die "Can not open $out_put2\n";

my $ttel=0;
my $ybegin=99999999;
my $yend=0;
my %average;
while (<IN>) {
   mychomp $_;
   my $lyn = $_;
   $lyn =~ s/\"//g;
   next if $lyn =~ /[A-Za-z]/;
#   '"yeat","inb_log","gen_1","gen_2","gen_3"."gen_4"."gen_5","gen_6"."animal"'
#  my ($yr, $inb_log) = split(',', $lyn);
  my @data = split(',', $lyn);
  my $yr=$data[0];
  my $inb_log=$data[1];
  next if $yr < $opt_b or $yr > $opt_c;
  next if $data[$opt_e+1] < $opt_f and ($opt_e and $opt_f);
#  print ">$yr<>$inb_log<>$data[$opt_e+1]<>($opt_e and $opt_f)<\n";
  $ttel++;
  if ($yr>$yend){
   $yend=$yr;
  }
  if ($yr<$ybegin){
   $ybegin=$yr;
  }
  $average{$yr}[0]+= $inb_log;
  $average{$yr}[1]++;
  
  print OUT1BB "$yr          $inb_log\n";
}
close IN;
close OUT1BB;

  system("rm -f fit_run reg_log_inbred.log fit.log");

  open (OUT123,">fit_run") or die "Problems opening fit_run \n";

  print OUT123 "set terminal postscript \n";
  print OUT123 'set output "' . "log_of_Inbreeding_". "$breed".'.ps"'."\n";

  print OUT123 'set ylabel "'.'Coefficient"'.' font "'.'Times-Italic,14"'."\n";
  print OUT123 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,14"'."\n";
  print OUT123 "set style line 1 lt 1 lw 15 \n";
  print OUT123 "set key below \n";
  print OUT123 "set autoscale xy \n";
  print OUT123 'f(x)=a*x+b'."\n";
  print OUT123 'FIT_LIMIT =1E-20'."\n";
  print OUT123 'fit f(x) "'."Inbreeding_log_$breed".'" via a,b'."\n";
  print OUT123 'plot "'."Inbreeding_log_$breed".'" using 1:2 title "'.'Log of Inbreed Coeff", f(x)'."\n";

  close OUT123;
  system("cp fit_run gnuplot.cmd");
# system("rm -f fit.log reg_log_inbred.log");
  system("gnuplot < fit_run");
  system("mv fit.log reg_log_inbred.log");

    open (IN, "reg_log_inbred.log") or die "Problems opening reg_log_inbred.log \n";
    my $one;
    my $two;
    my ($a1, $a2);
    my ($a3, $a4);
    $nn=0;
    while (<IN>) {
      mychomp($_);
      my $lyn = $_;
        if ($lyn =~ /a               =/){$nn++;}
        if ($nn == 2 and $lyn =~ /a               =/){
        ($a1, $a2) = split '\+', $lyn;
            ($a3,$a4) = split '\=', $a1;
        last;
    }
    }
    close IN;


my $rne=round((1/(2*(-($avg_pop_gen*$a4)))));
my $rrade=round4($avg_pop_gen*(-($a4)));

$out_put=">Inbreeding_log_$breed";
open (OUT1BB, "$out_put") or die "Can not open $out_put\n";
foreach my $tt (sort keys %average){
  my $aa = $average{$tt}[0] / $average{$tt}[1];
  $aa = sprintf("%.6f", $aa) if $aa;
  print OUT1BB "$tt          $aa             $average{$tt}[1]\n";
}
close OUT1BB;
system("rm -f fit_run reg_log_inbred.log");

  open (OUT123,">fit_run") or die "Problems opening fit_run \n";
  print OUT123 "set terminal postscript \n";
  print OUT123 'set output "' . "log_of_Inbreeding_"."$breed".'.ps"'."\n";

  print OUT123 "set autoscale xy \n";
  print OUT123 'set xrange [' . "$ybegin" . ':' . "$yend" . ']' . "\n";
  my $ss;
   if ( ( $yend - $ybegin ) > 10 ) {
           $ss = round( ( $yend - $ybegin ) / 10 );
   }
   else { $ss = 1; }
  print OUT123 'set xtics ' ."$ybegin".', '. "$ss" . ', ' . "$yend"."\n";

  print OUT123 "set bmargin 10 \n";
  print OUT123 'set ylabel "'.'Avg. Log(1 - F)"'.' font "'.'Times-Italic,14"'."\n";
  print OUT123 'set xlabel "'.'Year of Birth'.'\n (The rate of inbreeding per generation for the '."$breed".' breed, \nbased on the Log(1-Inbreeding) is '."$rrade".' which presents an Ne of '."$rne".'.\n Calculations were performed on '."$ttel animals born between $ybegin and $yend".'.)" font "'.'Times-Italic,14"'."\n";
  print OUT123 "set style line 1 lt 1 lw 15 \n";
  print OUT123 "set key below \n";

  print OUT123 'plot "'."Inbreeding_log_$breed".'" using 1:2 title "'.'"'."\n";

  close OUT123;

  system("gnuplot < fit_run");
  system("rm -f reg_log_inbred.log fit_run Inbreeding_log_.$breed");
  my $file = 'log_of_Inbreeding_'.$opt_b.'_'.$opt_c.'_'.$breed.'.ps';
  system("mv log_of_Inbreeding_$breed.ps $file");
print "\n\nOutput is in $file\n\n";

sub round {
    my $number = shift;
    return int( $number + .5 );
}
        
sub round1 {
    my $number = shift;
    return (int($number*10 + .5)/10);
}
                
sub round2 {
    my $number = shift;
    return int( $number + .9 );
}
                        
sub round4 {
    my $number = shift;
    return (int($number*10000 + .5)/10000);
}
                                
sub usage {
    print "usage:\n"
      . "    -h this message \n"
      . "    -a <> breed \n"
      . "    -b <> start year\n"
      . "    -c <> end year\n"
      . "    -d <> generation interval\n"
      . "    -e <> pedigree depth (1 - 6)\n"
      . "    -f <> % pedigree completeness\n"
      . "     \n\n";
      die "";
}
                                
