#!/usr/bin/env perl
##############################################################################
BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}

use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.7 $ ');
our $apiis;
use Apiis::Auth::AccessControl;
use Apiis::Misc qw ( mychomp LocalToRawDate ); # ...

initialize();
my $generation;

use vars qw( $opt_h $opt_d $opt_p $opt_w $db_user $opt_b $opt_m $opt_g);
use Getopt::Std;
getopts('f:hd:p:w:b:m:g:');
if ($opt_h) {
  print "  \n\n The next are  required by this script!!!\n";
#  print "1) A working ODBC driver for postgresql and a ODBCCconfiguration file for your database\n";
  print " An installed R-base (R statistics) on you PC\n";
  print "    Needed R packages are: gplots and RODBC\n\n";
  print "usage:\n";
  print " -h this message \n";
  print " -p <project_name>\n";
  print " -d <> database user \n";
  print " -w <> database password \n";
  print " -b <> database Short_name for db_breed \n";
  print " -m <> database class name for breed in table, codes (Default BREED) \n";
  print " -g <> generation interval if you want a fixed generation else\n";
#  print "       the generation will be pigup from Population report\n\n";
die("");
}

my $breed_class;

if ($opt_m){
    $breed_class=$opt_m;
}
if (! $opt_m){
    $breed_class='BREED';
}

if ($opt_g){
   $generation=$opt_g;
}

if (! $opt_g){
  print "\n\nPLEASE SPECIFIED THE GENERATION INTERVAL FOR THIS BREED USING THE -g OPTION\n\n";
  exit;
}

print "BREED CLASS ==> $breed_class\n";

if ($opt_p) {
  $project_name = $opt_p;
  print "project = $project_name\n";
} else {
  print "usage:\n";
  print " -h this message \n";
  print " -p <project_name>\n";
  print " -d <> database user \n";
  print " -w <> database password \n";
  print " -b <> Database Short_name for db_breed \n";
#  print " -m <> your table codes short_name for Male (Default = Male) \n";
#  print " -g <> generation interval if you want a fixed generation else\n";
#  print "       the generation will be pigup from Population report\n\n";
die("");
}

#if ($opt_m) {
#  $male = $opt_m;
#  print "Sex = $male\n";
#} else {
#  $opt_m = 'Male';
#  $male = $opt_m;
#  print "Sex = $male\n";
#}

if ($opt_b){
    print "BREED = $opt_b\n";
} else {
    print "No breed was specified, please use the -b option to declair the breed.\n";
    die();
}

sub initialize {
  use Tie::IxHash;
  use Text::ParseWords;
  use Statistics::Descriptive;
  use vars qw / $i $line_ref $k %treein $sql %ped $dbh $male $gen %delfile / ;
}

############################################################
# Get the project and user sort out
############################################################
use Apiis::DataBase::User;
my $not_ok=1;
my $loginname= $opt_d if $opt_d;
my $passwd= $opt_w if $opt_w;

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

$db_user=$apiis->User->id;
$apiis->check_status;
$dbh=$apiis->DataBase->dbh;
$dbh->{AutoCommit}=0;
my $user = $apiis->User->id;
my $now = $apiis->now;

my $dbb;

#############START PROJECT

if ($opt_b){
    my $sqlb ="select db_code from codes where short_name='$opt_b' and class='$breed_class' limit 1";
    my $sql_ref = $apiis->DataBase->sys_sql($sqlb);
    while ( my $line_ref = $sql_ref->handle->fetch ) {
	$dbb = $line_ref->[0];
    }
}

## rffr #
#my @dat1a = ();
#my @dat1b = ();
#my @dat2  = ();
#my $sql1 = "select g.year,round(log(1-g.inbreeding),7) from gene_stuff g,animal a where g.db_animal=a.db_animal and a.db_breed=$dbb and g.year != 'unknown'";
#  my $sth1 = $dbh->prepare(qq{ $sql1 }) or die $dbh->errstr;
#  my $ret1 = $sth1->execute;
#  while ( my $ss = $sth1->fetch ) {
#     @tt = @$ss;
#     push @dat1a, $tt[0];
#     push @dat1b, $tt[1];
#}
#
#my $sql2 = "select min(g.year),min(log(1-g.inbreeding)),max(g.year),max(log(1-g.inbreeding)) from gene_stuff g,animal a where g.db_animal=a.db_animal and a.db_breed=$dbb and g.year != 'unknown'";
#  my $sth2 = $dbh->prepare(qq{ $sql2 }) or die $dbh->errstr;
#  my $ret2 = $sth2->execute;
#  while ( my $ss = $sth2->fetch ) {
#     @dat2 = @$ss;
#}
#my $dat3 = join(', ', @dat2);
### rffr ##
#
##### FOR R
#
#open (OUT1, ">R_plot") or die "Can not open R_plot\n";
#
#print OUT1 "
#library(gplots)
#postscript(".'"temp1.ps" , paper = "a4")'."
#\n";
#
## rffr #
#for ( my $l = 0; $l < $#dat1a; $l = $l + 20 ) {
#    @dat_1 = splice ( @dat1a, 0 , 20 );
#    $dat1  = join(',',@dat_1) if ( @dat_1 );
#    @dat_2 = splice ( @dat1b, 0 , 20 );
#    $dat2  = join(',',@dat_2) if ( @dat_2 );
#    if ( $l == 0 ) {
#	print OUT1 "m<-c($dat1)\n n<-c($dat2)\n";
#    } else {
#	print OUT1 "m<-c(m, $dat1)\n n<-c(n, $dat2)\n";
#    }
#}
#print OUT1 "\ny<-data.frame(m,n)\ny2<-c($dat3)\n";
### rffr ##
#
### print the R commands to file R_plot
#print OUT1 '
#
#a     <- y[[1]]
#b     <- y[[2]]
#
#zz    <- lm(b ~ a)
#int   <- round(zz[[1]][1],4)
#slope <- zz[[1]][2]
#int
#slope
#
#ne    <- paste("The Ne therefore is ", round((1/(2*('."$opt_g".'*(-(slope))))),0),"")
#rate  <- paste("Rate of inbreeding per generation", " is " , round(('."$opt_g".'*(-(slope))),4),"")
#
#slope <- round(zz[[1]][2],5)
#f_line <- paste("y = ",slope,"x + ",int)
#
#plot(b '."~".' a , main="Log(1-Inbreeding) for the '."$opt_b".'" ,xlab="Year of birth" ,ylab="Log(1-Inbreeding)")
#abline(zz)
#
#';
#print OUT1 "
#smartlegend (x='left', y='bottom', legend=c(f_line,ne,rate))
#";
#
#close OUT1;
#
#system ("R -q < R_plot --save > R_plot.out");
#system ("ps2pdf temp1.ps R_Log_inbreeding_$opt_b.pdf");
#system ("rm -f temp1.ps R_plot R_plot.out");
#
##### END OF R-BASE PLOTS THE REST OF THE SCRIPT IS FOR PLOTTING THE GRATHP IN GNUPLOT
#exit;

my $t_tel=0;
my %hash;

my $out_put=">Inbreeding_log_.$opt_b";
my $check=">chek_log.txt";

open (OUT1, "$out_put") or die "Can not open $dbbout\n";
#open (OUT11, "$check") or die "Can not open chek filed\n";

my $sqlb ="select b.db_breed,a.db_animal,log(1-a.inbreeding),a.year from gene_stuff a, animal b where a.db_animal=b.db_animal and b.db_breed=$dbb and a.year != 'unknown'";
my $sql_ref = $apiis->DataBase->sys_sql($sqlb);
my $ttel=0;
my $ybegin=99999999;
my $yend=0;
while( my $line_ref = $sql_ref->handle->fetch ) {
  my @line = @$line_ref;
  my ($breed, $animal, $inb_log, $year )=@line;
#  my $inb_log=log(1-($inbreeding*1));
  $ttel++;
  if ($year>$yend){
   $yend=$year;
  }
  if ($year<$ybegin){
   $ybegin=$year;
  }
  print OUT1 "$year          $inb_log\n";
#  if ($year==1995){print OUT11 "$year,$inbreeding,$inb_log,$animal\n"; }
}

close OUT1;
#close OUT11;

  system("rm -f fit_run reg_log_inbred.log fit.log");

  open (OUT123,">fit_run") or die "Problems opening fit1_run \n";

  print OUT123 "set terminal postscript \n";
  print OUT123 'set output "' . "log_of_Inbreeding_". "$opt_b".'.ps"'."\n";
  $delfile{'log_of_Inbreeding_'. "$opt_b".'.ps'}[0]=1;


  print OUT123 'set ylabel "'.'Coefficient"'.' font "'.'Times-Italic,14"'."\n";
  print OUT123 'set xlabel "'.'Year of Birth"'.' font "'.'Times-Italic,14"'."\n";
  print OUT123 "set style line 1 lt 1 lw 15 \n";
  print OUT123 "set key below \n";
  print OUT123 "set autoscale xy \n";
  print OUT123 'f(x)=a*x+b'."\n";
  print OUT123 'FIT_LIMIT =1E-20'."\n";
  print OUT123 'fit f(x) "'."Inbreeding_log_.$opt_b".'" via a,b'."\n";
#  print OUT123 'plot "'."Inbreeding_log_.$opt_b".'" using 1:2 title "'.'Log of Inbreed Coeff"'.' lt 5 lw 3 axis x1y1 smooth csp  w lines ';
  print OUT123 'plot "'."Inbreeding_log_.$opt_b".'" using 1:2 title "'.'Log of Inbreed Coeff", f(x)'."\n";

  close OUT123;

  system("rm -f fit.log reg_log_inbred.log");
  system("gnuplot < fit_run");
  system("mv fit.log reg_log_inbred.log");
#  system("rm -f fit_run fit.log");

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



my $ne=round((1/(2*(-($generation*$a4)))));
my $rrade=round4($opt_g*(-($a4)));

system("rm -f fit_run reg_log_inbred.log");
#print "The effective population size for the $opt_b with a generation interval of $generation is $ne.\n";

open (OUT1, "$out_put") or die "Can not open $dbbout\n";

$sqlb ="select b.db_breed,round((avg(log(1-a.inbreeding))),6),a.year from gene_stuff a, animal b where a.db_animal=b.db_animal and b.db_breed=$dbb and a.year != 'unknown' group by b.db_breed,a.year order by a.year";
my $sql_ref = $apiis->DataBase->sys_sql($sqlb);
#my $ttel=0;
#my $ybegin=99999999;
#my $yend=0;
while( my $line_ref = $sql_ref->handle->fetch ) {
  my @line = @$line_ref;
    my ($breed, $inb_log, $year )=@line;
    #  my $inb_log=log(1-($inbreeding*1));
#      $ttel++;
#      if ($year>$yend){
#         $yend=$year;
#      }
#      if ($year<$ybegin){
#         $ybegin=$year;
#      }
print OUT1 "$year          $inb_log\n";
}

close OUT1;
  open (OUT123,">fit_run") or die "Problems opening fit1_run \n";
  print OUT123 "set terminal postscript \n";
  print OUT123 'set output "' . "log_of_Inbreeding_". "$opt_b".'.ps"'."\n";
  $delfile{'log_of_Inbreeding_'. "$opt_b".'.ps'}[0]=1;

#  print OUT123 'set title "Log(1 - F) by year of birth for the '."$opt_b".' breed, born between '."$ybegin and $yend\n";

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
  print OUT123 'set xlabel "'.'Year of Birth'.'\n (The rate of inbreeding per generation for the '."$opt_b".' breed, \nbased on the Log(1-Inbreeding) is '."$rrade".' which presents an Ne of '."$ne".'.\n Calculations were performed on '."$ttel animals born between $ybegin and $yend".'.)" font "'.'Times-Italic,14"'."\n";
  print OUT123 "set style line 1 lt 1 lw 15 \n";
  print OUT123 "set key below \n";

#  print OUT123 'f(x)=a*x+b'."\n";
#  print OUT123 'fit f(x) "'."Inbreeding_log_.$opt_b".'" via a,b'."\n";
#  print OUT123 'plot "'."Inbreeding_log_.$opt_b".'" using 1:2 title "'.'Log of Inbreed Coeff"'.' lt 5 lw 3 axis x1y1 smooth csp  w lines ';
  print OUT123 'plot "'."Inbreeding_log_.$opt_b".'" using 1:2 title "'.'"'."\n";

  close OUT123;

  system("gnuplot < fit_run");
  system("rm -f reg_log_inbred.log fit_run Inbreeding_log_.$opt_b");
 
sub round {
    my $number  = shift;
    return int($number + .5);
}

sub round4 {
    my $number = shift;
    return (int($number*10000 + .5)/10000);
}


exit;
