#!/usr/bin/perl
##############################################################################
# Eildert Groeneveld (mostly; print loops [bf])
# this code cecks for loops in pedigrees. To do this it does:
# 1 - read into a hash the complete pedigree from ANIMAL (db_animal,sire,dam).
# 2 - reads db_animal from ANIMAL (could also be another table)
# 3 - goes recursively into the pedigree: find sire as animal etc
# 4 - if more than 5000 entries are found this is considered a loop.
# 5 - for print loops you must specify the var $p_loop to 1 else 'undef'
#
# considerations: need to have enough RAMM to hold pedigree.
# ( duplicated for print loops :-( but possible help to analyse )
# there is also DB only version but this is veeery slow.
# usage: -h some help (not so much)
#        -p print loops
#        -l loop limit to define a loop (default = 1000)
##############################################################################

BEGIN {                              # execute before compilation
   use Env qw( APIIS_HOME );     # get environment variable
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}
use strict;
use warnings;
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.13 $' );

# allowed parameters:
use vars qw( $opt_p $opt_h $opt_l $p_loop $loop_limit $qual);
use vars qw( $opt_v $opt_m $which $path $l );
use Getopt::Std;
getopts('phlvm:'); # option -m <modelfile>  => Modelfile
                   #        -v              => Version
                   #        -h              => Help
#die usage()         if $opt_h;
if ($opt_h) {
   print "usage:\n";
   print " -h this message \n";
   print " -m modelfile \n";
   print " -p loops printed\n";
   print " -l loop limit to define a loop (default = 1000)\n";
   print " -v version \n";
   die("\n");
}
if ($opt_p) {
  $p_loop = 1;
#  use apiis_alib;
}
else { $p_loop = undef; }
if ($opt_l) {
  $loop_limit = $opt_l; # definition of a loop
}
else { $loop_limit = 1000; }
die $apiis->programname . ': ' . $apiis->version . "\n" if $opt_v;



my $model_file = $opt_m if $opt_m;
unless ($model_file) {
   $model_file = $ARGV[0] if $ARGV[0];
   }
$apiis->join_model($model_file);

$apiis->check_status;

initialize(); # what for?


sub initialize {
  use Tie::IxHash;
  use Text::ParseWords;
  use vars qw /$loop %lp $i $start_animal $line_ref $tot_ped @col $k %tree
          $sql %ped $table $con $dbh $rdbm $dbn %data_tables $loop_limit
          $among_ancestors $first_loop /;
}
####################
#$model_file = GetModelName();
#require "$model_file";
#ConnectDB() unless defined $dbh;
####################
%data_tables = (
		'animal'    => {
	              'db_animal'      => ''
		}
	       );

###############################################
## read the complete pedigree into RAM
###############################################
my $sql ="select db_animal,db_sire,db_dam from animal";

%ped=();
%tree=();
my $sth = $apiis->DataBase->sys_sql($sql);

$i=0;

while ( my $line_ref = $sth->handle->fetch ) {
   $i++;
   my @line = @$line_ref;
   my ( $db_animal, $sire, $dam ) = @line;

   if ( defined $db_animal and $db_animal ne 1 and $db_animal ne 2 )
   {    # these are base parents, record skipped

      if ( $sire ne 0 ) {
         $ped{$db_animal}[0] = $sire;
      }
      if ( $dam ne 1 ) {
         $ped{$db_animal}[1] = $dam;
      }
      if ($p_loop) {
         ## rffr %tree
         $tree{$db_animal}[0] = 0;
         $tree{$db_animal}[1] = $sire;
         $tree{$db_animal}[2] = $dam;
      }
   }
}
print "Pedigree loaded with $i records\n";
###############################################
## complete pedigree is in  RAM
###############################################

foreach $table ( keys %data_tables ) {
  
  print "Table : $table\n";
  @col =keys %{$data_tables{$table} }  ;
  
  $sql = join ',', @col;	# string all columns names together
  
  my $sql = "SELECT $sql  FROM $table";
  #my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
  # $sth->execute;
  my $sth = $apiis->DataBase->sys_sql($sql);
  
  my $i=0; my $n=0; my $nok=0;
  
  while ( my $line_ref = $sth->handle->fetch ) {
    $n++;
    my @line = @$line_ref;
    my $db_animal = shift @line;
    $main::tot_ped=0;
    $start_animal = $db_animal;
    $among_ancestors = 0;
    my ($status) = &get_ped ($start_animal);
    print '.' unless ++$i%100;
    print " pedigree_loops --> $i\n" unless $i%1000;         
    if ($status eq -1) {               # here we have a loop animal
      #print " loop ? $start_animal,$among_ancestors\n";
      if ($among_ancestors == -1) {
         $loop++;
         $lp{$start_animal}=$loop;}
         # if $start_animal does not show up itself in its pedigree
         # it can be discarded as the cause of this mistake. It is then
         # simply an offspring of the cause
      }
    else {
      $nok++;
    }
  }
  print "from table $table we have read $n records\n";
  if ($i == 0 ) {print " the following db_animal have loops:\n";}
  $i=0;
  foreach $table( keys %lp ){
    $i++;
    print "$i -> $table \n";
  }
  print "Total number of records processed: $n\n";
  print "Number of animals ok             : $nok\n";
  if ($i == 0 ) { 
      print "Congratulation, your pedigrees look fine!\n";
   }
  else {
  print "Sorry, it seems that you have loops in your pedigree\n";
  print "Number of records with loops     : $i\n";
  }
  
}
###################################
# get pedigree in recursive manner#
###################################
# this is not correct (the loop stuff) we can get this also with inbreeding.
sub get_ped {
  my $db_animal = shift (@_);
  my $loc_sire = $main::ped{$db_animal}[0];
  my $loc_dam  = $main::ped{$db_animal}[1];

  # among ancestors?
  if ($start_animal and $loc_sire and $start_animal == $loc_sire) {$among_ancestors = -1;}
  if ($start_animal and $loc_dam and $start_animal == $loc_dam ) {$among_ancestors = -1;}

  if (defined ($loc_sire)){ # dont use base parents
    $main::tot_ped++;
    if ($main::tot_ped == $loop_limit) { return ( -1); }
    my $status = &get_ped ($loc_sire);
    if ( $status == -1) { return (-1); }
  }
  if (defined ($loc_dam) ){ # base parent
    $main::tot_ped++;
    # a pedigree beyond $loop_limit ancestors is considered a loop
    if ($main::tot_ped == $loop_limit) { return (-1); }
    my $status = &get_ped ($loc_dam);
    if ( $status == -1) { return (-1); }
  }
return (0);
}

##########################################
#### [bf] print loops
##########################################
if ( $p_loop ) {
  $qual = ''; $which = '';
  my @path=();
  $tree{"1"}[0]=2; $tree{"2"}[0]=2;
  foreach $k (keys %tree) {
    test($k);
  }
  sub test{	                # using global variables %tree and @path
    # $tree{$node}[0]= 0 - unknown
    #                  1 - under investigation
    #                  2 - clear
    my $node=shift;
    if (!exists($tree{$node}) || $tree{$node}[0]==2) {
      return;
    }
    if ($tree{$node}[0]==1) {	# now we have a problem
      my @node_ext = get_ext_animal( $qual, $which, $node );
      my $node_ext = $node_ext[0];
      print "loop are: $node_ext ($node) ";
      $l=@path-1; 
      while ($path[$l] ne $node) {
 	@node_ext = get_ext_animal( $qual, $which, $path[$l] );
	$node_ext = $node_ext[0];
 	print "-> $node_ext ($path[$l])";
	$l--;
      }
      @node_ext = get_ext_animal( $qual, $which, $node );
      $node_ext = $node_ext[0];
      print "-> $node_ext ($node)\n";
    } else {			# $tree{$node}[0]==0
      $tree{$node}[0]=1; push(@path,$node);
      test($tree{$node}[1]);
      test($tree{$node}[2]);
      $tree{$node}[0]=2; pop(@path);
    }
  }
}

__END__


