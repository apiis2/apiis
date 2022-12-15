#!/usr/bin/perl -w
##############################################################################
# $Id: Create_inbreeding_tables.pl,v 1.60 2014/07/22 05:42:02 kehr Exp $
##############################################################################
# inbreeding.pl: calculates the inbreeding coefficients for the animals from
# DB after testloop and testbd for check errors in pedigree.  the results are
# recorded in temporary table gene_stuff in DB temp tables are created gor
# statistics descriptive analysis: inbreed_total and inbreed_inbreed use table
# animal according to APIIS structure

BEGIN {
    use Env qw( APIIS_HOME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
    push @INC, "$APIIS_HOME/bin";
}

# use strict;
use warnings;
use Parallel::ForkManager;
use Sys::CPU;
use Data::Dumper;
use Tie::IxHash;
use Text::ParseWords;
use Statistics::Descriptive;
use Date::Calc qw/ Delta_DHMS /;

use ref_breedprg_alib;
use Apiis;
use Apiis::DataBase::User;
use Popreport;    # provides print_list()
Apiis->initialize( VERSION => '$Revision: 1.60 $' );
our $apiis;

use vars qw(
    %animcomp $birth $brd $breed %comp $completeness $dam $dbb $dbh $db_id
    $db_user $filename $f_loop $gen_counter $gen_interval $i %inputs $k @line $line_ref
    $maxgen $opt_a $opt_b $opt_c $opt_d $opt_e $opt_f $opt_g $opt_h $opt_I
    $opt_k $opt_L $opt_o $opt_p $opt_r $opt_s $opt_t $opt_u $opt_w $outfile
    %ped $project_name $sine $sire $sql %tree2 %treein $undef_animal $unknown_ani
    $debug $info
);
$debug = 0;
$info  = 1;

use Getopt::Std;
getopts('f:haourt:sp:d:w:ck:b:e:g:I:L:');
if ($opt_h) {
    print "usage:\n";
    print " -h this message \n";
    print " -f formatted print of external animal id\n";
    print " -a print all animals with inbreeding coefficient\n";
    print " -o print only animals with inbreeding coefficient\n";
    print " -u <> unknown animal \n";
    print " -r Re-calqulate gene_stuf \n";
    print " -s make faster but need much RAM \n";
    print " -t <filename> create numerical sorted ped and translation file\n";
    print " -p <project_name> \n";
    print " -d <> database user \n";
    print " -w <> database password \n";
    print " -c Count all tmp2 tables \n";
    print " -k Delete all tmp2 tables \n";
    print " -e Your name for BREED in class = 'BREED' in table codes (Default = $brd)\n";
    print " -b database short_name for breed (If not entered all breeds will run) \n";
    print " -g 1 - n for max generation depth in pedigree completeness (Default = 5)\n";
    print " -I <GI> Generation Interval\n";
    print " -L <listfile> listfile for program output \n";
    print "example Create_inbreeding_tables.pl -p breedprg -d demo -w Demo -k 1\n";
    print "        Create_inbreeding_tables.pl -p breedprg -d demo -w Demo -b DUR -r 1 -c 1 -s 1\n\n";
    die("");
}

my ( $sec1, $min1, $hour1, $mday1, $mon1, $year1, $wday1, $yday1, $isdst1 ) =
    localtime(time);
$year1 = 1900 + $year1;
$mon1  = 1 + $mon1;
$brd   = 'BREED';

our $listfile = $opt_L if $opt_L;
my $texlist   = $listfile;
$texlist      =~ s/lst$/tex/ if $texlist;

$outfile = $opt_t;
$f_loop  = $opt_f;
$undef_animal = $unknown_ani = $opt_u;
$project_name = $opt_p;
$breed = $opt_b;
$gen_interval = $opt_I;
$brd = $opt_e;
$maxgen = $opt_g || 5;

if ($info) {
    print "print only animals with inbreeding:\n" if $opt_o;
    print "print all animals:\n"                  if $opt_a;
    print "unknown animal = $opt_u\n" if $opt_u;
    print "project = $project_name\n";
    print "breed = $breed\n" if $breed;
    print "BREED = $brd\n" if $brd;
    print "max generation = $maxgen\n";
    $opt_s ? ( print "opt_s = $opt_s\n" ) : ( print "opt_s not set\n" );
    $opt_r ? ( print "opt_r = $opt_r\n" ) : ( print "opt_r not set\n" );
    $opt_c ? ( print "opt_c = $opt_c\n" ) : ( print "opt_c not set\n" );
}

############################################################
print "# Get the project and user sort out \n" if $info;
############################################################
my $not_ok = 1;
my $loginname;
my $passwd;
$loginname = $opt_d if $opt_d;
$passwd    = $opt_w if $opt_w;

if ( !$opt_d and !$opt_w ) {
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
}
else {
    $not_ok = 1;
}
my $thisobj = Apiis::DataBase::User->new(
    id       => "$loginname",
    password => "$passwd",
);
$thisobj->check_status;
$apiis->join_model( $project_name, userobj => $thisobj );
$apiis->check_status;

$dbh = $apiis->DataBase->dbh;
$dbh->{AutoCommit} = 0;
my $user = $apiis->User->id;
my $now  = $apiis->now;

###########################################################
if ( defined $opt_k ) {    # delete all auxiliary tables:
    print "# Delete all tmp2 tables\n" if $info;
    deltables();
    exit;
}
############################################################

$sine = '=';
my $sql1;
if ( !defined $breed ) {
    $sql1 = "SELECT min(db_breed) FROM animal";
    $sine = '>=';
}
else {
    $sql1 =
        "SELECT db_code FROM codes
        WHERE class       = '$brd' AND
              (ext_code   = '$breed' OR
               short_name = '$breed' OR
               long_name  = '$breed')";
}
my $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
$apiis->check_status;
while ( my $line_ref = $sql_ref1->handle->fetch ) {
    my @line = @$line_ref;
    $dbb = $line[0];
}

if ( !$dbb and $opt_b ) {
    my @die_msg_breed;
    push @die_msg_breed, "ERROR:\n";
    push @die_msg_breed, "Breed $breed does not exist in the database\n";
    push @die_msg_breed, "No inbreeding report can be created.\n";
    print_tex_item( join( '\\\\', @die_msg_breed ), $texlist );
    die "\n**** Breed $breed does not exist in database ****\n\n";
}
############################################################

print "## read the complete pedigree into RAM \n" if $info;
$sql =
    "SELECT db_animal,db_sire,db_dam,
            birth_dt,date_part('year',birth_dt),short_name
     FROM   animal, codes
     WHERE  db_breed=db_code AND db_breed $sine $dbb";
print "$sql\n" if $info;
# we should read all pedigrees in the database, irrespective of AR
my $sql_ref = $apiis->DataBase->sys_sql($sql);
$apiis->check_status;
%ped    = ();
%treein = ();
$i      = 0;
while ( my $line_ref = $sql_ref->handle->fetch ) {
    $inputs{'pedi'}{'in'}++;
    my @line = @$line_ref;
    my ( $db_animal, $sire, $dam, $birth_dt, $birth, $name ) = @line;

    if ( defined $db_animal and $db_animal ne 1 and $db_animal ne 2 )
    {    # these are base parents, record skipped

        $treein{$db_animal}[4] = 0;
        $treein{$db_animal}[0] = $sire;
        $treein{$db_animal}[1] = $dam;
        $treein{$db_animal}[2] = $birth_dt;
        if ( $birth and $birth > 0 ) {
            if ( $sire == 1 ) { $sire = $undef_animal; }
            if ( $dam == 2 )  { $dam  = $undef_animal; }
            $ped{$db_animal}[2] = $birth;
            $ped{$db_animal}[3] = 0;        # completeness
            $ped{$db_animal}[4] = $name;    # completeness
            if ($sire) {
                $ped{$db_animal}[0] = $sire;
            }
            if ($dam) {
                $ped{$db_animal}[1] = $dam;
            }
        }
    }
    if ($debug) {
        print '.' unless ++$i % 1000;
        print " info_ped --> $i\n" unless $i % 10000;
    }
}
print "\n      ...Pedigree loaded with $i records\n" if $info;

# at this point we know the number of records and can disable parallelization
# for too big datasets (depends on RAM):
my $cpus = Sys::CPU::cpu_count();
$cpus = 0 if $i > 500000;
my $parallel = new Parallel::ForkManager($cpus);
printf "\nRunning pedicompl for generations (using %u CPUs)\n", ( $cpus || 1 )
    if $info;

if ($opt_r) {
    print "## test loops in pedigree \n" if $info;

    $href_in = \%treein;
    @erg = testloop( $href_in, $unknown_ani );    # ( $href, $unknown_animal )

    if ( $f_loop and $f_loop =~ /^#/ ) {
        @p     = split( /#/, $f_loop );
        $qual  = $p[1];
        $which = $p[2];
    }
    else { $qual = ''; $which = ''; }

    if ( scalar @erg == 0 ) {
        print "\n Congratulation, your pedigree looks fine!\n\n" if $info;
    }
    else {
        print "\n The following loops are inside:\n";
        foreach $x (@erg) {
            my @ergpart = split( '->', $x );
            my $c       = 0;
            my $first   = $ergpart[0];
            foreach $y (@ergpart) {
                $c++;
                @ext = get_ext_animal( $qual, $which, $y );
                if ( $y ne $first or $c == 1 ) {
                    print "\'$ext[0]\' ($y) -> ";
                }
                else {
                    print "\'$ext[0]\' ($y)\n";
                }
            }
        }
        print "No inbreeding information available as you have a pedigree loop\n";
        exit;
    }

    #############################################################
    print "# test for errors in birth_dt of animals \n" if $info;

    $href_in = \%treein;
    %errbd = testbd( $href_in, $unknown_ani );

    if ( $f_loop and $f_loop =~ /^#/ ) {
        @p     = split( /#/, $f_loop );
        $qual  = $p[1];
        $which = $p[2];
    }
    else { $qual = ''; $which = ''; }

    if ( $#errbd == 0 ) {
        print "\n Birth_dt are correct!\n\n" if $info;
    }
    else {
        print "\n The following animals and parents have wrong birthdays:\n";
        print "=========================================================\n";
        foreach $x ( keys %errbd ) {
            @ext = get_ext_animal( $qual, $which, $x );
            print "\n$ext[0]\t $treein{$x}[2] \n";
            if ( $errbd{$x}[1] ) {
                @ext_dam = get_ext_animal( $qual, $which, $treein{$x}[1] );
                print "       dam: $ext_dam[0]\t $treein{$treein{$x}[1]}[2]\n";
            }
            if ( $errbd{$x}[0] ) {
                @ext_sire = get_ext_animal( $qual, $which, $treein{$x}[0] );
                print "      sire: $ext_sire[0]\t $treein{$treein{$x}[0]}[2]\n";
            }
        }
    }
    undef %href_in; # cleanup

    ############################################################
    my $msg1 = 'Running INBREED  calculations';
    print_list( $msg1, $listfile );
    print "#  I N B R E E D  calculations according to Henderson (?) \n"
        if $info;
    $href = \%treein;    # animal => sire, dam, birth_dt

    if ($opt_t) {
        if ($opt_s) {
            ( $retref, $transref, $transref2 ) =
                inbreed( $href, $unknown_ani, 'st' );
        }
        else {
            ( $retref, $transref, $transref2 ) =
                inbreed( $href, $unknown_ani, 't' );
        }
    }
    elsif ($opt_s) {
        $retref = inbreed( $href, $unknown_ani, 's' );
    }
    else {
        $retref = inbreed( $href, $unknown_ani );    # see ref_breedprg_alib.pm
    }
    %tree = %$retref;    # animal => F(inbreeding), birth_dt

    if ($opt_t) {        # transfer output as example: start known animal with 1
        print
            "create new files with numerical sorted pedigree ( $outfile.newsort, $outfile.trans ) \n"
            if $info;
        open( TRANS,  ">$outfile.newsort" );
        open( TRANS2, ">$outfile.trans" );
        tie %trans,  'Tie::IxHash';
        tie %trans2, 'Tie::IxHash';
        %trans  = %$transref;     # new numerical animal pedigree
        %trans2 = %$transref2;    # transfer new old animal id
        foreach $y ( keys %trans ) {

            if ( $y <= 2 ) {      # not more unknown animals (1 and 2)
                next;
            }
            for ( $x = 0; $x < 2; $x++ ) {    # start first known animal with 1
                if ( $trans{$y}[$x] <= 2 ) {
                    $trans{$y}[$x] = 'unknown';    # yet 'unknown'
                }
                else {
                    $trans{$y}[$x] = $trans{$y}[$x] - 2;
                }
            }
            my $out = $y - 2;
            print TRANS "$out\t$trans{ $y }[0]\t$trans{ $y }[1]\n";
        }
        foreach $yy ( keys %trans2 ) {
            if ( $yy <= 2 ) {                      # delete unknown animals
                next;
            }
            my $out = $yy - 2;
            print TRANS2 "$out\t$trans2{ $yy }\n";
        }
        close(TRANS);
        close(TRANS2);
    }

    my $count    = 0;
    my $count_i  = 0;
    my %ausw     = ();
    my %ausw_tot = ();
    foreach $k ( keys %tree ) {
        $count++;
        $year = $tree{$k}[1];
        if ($year) {
            $year = 'unknown' if ( $year !~ /-/ );    # fix '-' as seperator
            $year =~ s/-.*$//;
        }
        else {
            $year = 'unknown';
        }
        push @{ $ausw_tot{$year} }, $tree{$k}[0];
        if ( $tree{$k}[0] != 0.0 ) {
            push @{ $ausw{$year} }, $tree{$k}[0];
            $count_i++;
        }
    }

    if ($opt_a) {
        foreach $k ( sort { $tree{$a}[0] <=> $tree{$b}[0] } keys %tree ) {
            @ext = get_ext_animal( $qual, $which, $k );
            print "\'$ext[0]\' ($k) \t: \t$tree{$k}[0]\n";
        }
    }

    if ($opt_o) {
        foreach $k ( sort { $tree{$a}[0] <=> $tree{$b}[0] } keys %tree ) {
            @ext = get_ext_animal( $qual, $which, $k ) if ( $tree{$k}[0] ne 0 );
            print "\'$ext[0]\' ($k) \t: \t$tree{$k}[0]\n"
                if ( $tree{$k}[0] ne 0 );
        }
    }

############################################################
    my $msg2 = 'Creating table GEN_STUFF';
    print_list( $msg2, $listfile );
    print $msg2, "\n" if $info;

    # create a table for inbreeding
    my   @sql_statements;
    push @sql_statements, "DROP TABLE IF EXISTS GENE_STUFF";
    push @sql_statements, "CREATE TABLE GENE_STUFF (
        db_animal         int8,
        inbreeding        numeric,
        founders          numeric,
        year              text,
        gci               numeric,
        completeness      numeric,
        generation        int8,
        breed             numeric,
        last_change_dt    timestamp,
        last_change_user  text)";
    push @sql_statements,
        "CREATE UNIQUE INDEX uidx_gene_stuff_1 ON GENE_STUFF ( db_animal )";
    push @sql_statements,
        "SELECT db_animal,db_sire,db_dam,1 AS generation
         INTO    tmp2_generations
         FROM    animal
         WHERE   db_breed $sine $dbb AND db_animal > 2";

    push @sql_statements,
        "CREATE INDEX ind_tmp2_generations ON tmp2_generations (db_animal)";

    my $sth;
    foreach my $s (@sql_statements) {
        print "SQL: $s\n" if $info;
        my $sql_ref = $apiis->DataBase->sys_sql($s);
        $apiis->check_status;
        $apiis->DataBase->sys_dbh->commit;
    }

    #insert values in GENE_STUFF
    my $today = localtime(time);
    my $sth2;
    my $sql2;

    my $j = 0;
    foreach $k ( keys %tree ) {
        $year = $tree{$k}[1];
        if ($year) {
            $year = 'unknown' if ( $year !~ /-/ );
            $year =~ s/-.*$//;
        }
        else {
            $year = 'unknown';
        }
        $sql2 =
            "INSERT INTO GENE_STUFF
                (db_animal, inbreeding, year,
                 last_change_dt, last_change_user,breed)
             VALUES ('$k', '$tree{$k}[0]', '$year', '$today', '$user',$dbb)";

        my $sql_ref2 = $apiis->DataBase->sys_sql($sql2);
        $apiis->check_status;
        if ($debug) {
            print '.' unless ++$j % 1000;
            print " commit--> $j\n" unless $j % 10000;
        }
        $apiis->DataBase->sys_dbh->commit || die $dbh->errstr unless $j % 10000;
    }
    print "\ncommit last $j records\n" if $info;
    $apiis->DataBase->sys_dbh->commit || die $dbh->errstr;

    if ( $opt_a or $opt_o ) {
        report();
    }
}    # end of if $opt_r

# some cleanup:
undef %treein;
undef %href;
undef %retref;
undef %tree;

my $msg3 = sprintf 'Running pedigree completeness  using %u CPU',
    ( $cpus || 1 );
print_list( $msg3, $listfile );
print $msg3, "\n" if $info;

my $spp = "CREATE TABLE tmp2_pedcompl (
               generation        numeric,
               year              text,
               breed             numeric,
               completeness      numeric,
               number            numeric)";
print "SQL: $spp\n" if $info;
my $sql_ref_spp = $apiis->DataBase->sys_sql($spp);
$apiis->check_status;
$apiis->DataBase->sys_dbh->commit;
$apiis->disconnect_project;

###############################################################
for ( $i = 1; $i <= 6; $i++ ) {
    # try to run the following jobs in parallel (fork) (29.10.2007 - heli):
    my $pid = $parallel->start and next;    # forks a child process
    ped_completeness($i);
    $parallel->finish;                      # Terminates the child process
}                                #end of loop for 6 generations
$parallel->wait_all_children;    # wait for all children to terminate
print "Parallel jobs finished.\n" if $info;

for ( $i = 1; $i <= 6; $i++ ) {
    open( IN, "<tmp$i.txt" );
    while (<IN>) {
        mychomp($_);
        my $aa = $_;
        my ( $a, $b, $c ) = split( '\#', $aa );
        $comp{$a}[0] += $b;
        $comp{$a}[1]++;
    }
    close IN;
}

my $aa = scalar( keys %comp );
print "Number=$aa\n" if $info;

$apiis->join_model( $project_name, userobj => $thisobj );
$apiis->check_status( die => 'ERR' );
$dbh = $apiis->DataBase->dbh;

foreach my $year ( sort keys %comp ) {
    my ( $gen, $br, $yr ) = split( '\|', $year );
    my $avg = $comp{$year}[0] / $comp{$year}[1];
    $avg = round3($avg);
    $avg = sprintf( "%.3f", $avg ) if $avg;
    my $sql =
        "INSERT INTO tmp2_pedcompl (generation, breed, year, completeness, number)
        VALUES ('$gen','$dbb','$yr', '$avg', '$comp{$year}[1]')";
    my $sql_ref2 = $apiis->DataBase->sys_sql($sql);
    $sql_ref2->check_status( die => 'ERR' );
    $apiis->check_status;
    $apiis->DataBase->sys_dbh->commit || die $dbh->errstr;
}

#cleanup:
undef %ped;
undef %comp;

###########################################################
my $msg4 = 'Running generation calculations of all animals';
print_list( $msg4, $listfile );
print $msg4, "\n" if $info;

my $table = 'tmp2_generations';
my $rv4   = 1;
my ( $rv5, $rv6 );
my $sql4     = "UPDATE $table SET generation=1";
my $sql_ref3 = $apiis->DataBase->sys_sql($sql4);
# $sql_ref3->check_status( die => 'ERR' );
$apiis->check_status;
$rv4 = $sql_ref3->rows;    #number of all rows, animals in total_inbr
$apiis->DataBase->sys_dbh->commit || die $dbh->errstr;

my ( $sql5, $sql6 );
$rv6 = $rv5 = $rv4;
$i   = 1;                  # seq. number of generations
# update sql of generation $i
while ( ( $rv5 and $rv5 != 0 ) && ( $rv6 and $rv6 != 0 ) ) {
    $sql5 = "UPDATE $table SET generation=d.generation+1
       FROM $table AS d
       WHERE $table.db_animal=d.db_dam AND d.generation=$i";
    my $sql_ref4 = $apiis->DataBase->sys_sql($sql5);
    $apiis->check_status;
    $rv5 = $sql_ref4->rows;
    print "rows dams:$rv5\n" if $rv5 and $debug;

    $sql6 =
        "UPDATE $table SET generation=s.generation+1
         FROM $table AS s
         WHERE $table.db_animal = s.db_sire AND
               s.generation     = $i";
    my $sql_ref5 = $apiis->DataBase->sys_sql($sql6);
    $apiis->check_status;
    $rv6 = $sql_ref5->rows;
    print "rows sires:$rv6\n" if $rv6 and $debug;
    $apiis->DataBase->sys_dbh->commit || die $dbh->errstr;
    $i++;
}

# update table gene_stuff with generation number
my $sql7;
$sql7 =
    "UPDATE gene_stuff
    SET     generation=$table.generation
    FROM    $table
    WHERE   $table.db_animal=gene_stuff.db_animal";
my $sql_ref6 = $apiis->DataBase->sys_sql($sql7);
$apiis->check_status;
$apiis->DataBase->sys_dbh->commit || die $dbh->errstr;

my $msg5 = 'Done with generations calculating of all animals';
print_list( $msg5, $listfile );
print $msg5, "\n" if $info;
###########################################################
sub report {
    my $ges_mn = 1000;
    my $gesn = $ges_mx = $gessm  = 0;
    print "======================================\n";
    print "INBREED ANIMALS:\nyear\tno\tmin\tmax\tavg\n";
    print "--------------------------------------\n";
    foreach $y ( sort keys %ausw ) {
        $stat = Statistics::Descriptive::Full->new();
        $stat->add_data( @{ $ausw{$y} } );
        $ct = $stat->count();
        $mw = sprintf( "%.4f", $stat->mean() );
        $mn = sprintf( "%.4f", $stat->min() );
        $mx = sprintf( "%.4f", $stat->max() );
        $sm = $stat->sum();
        # $vr=sprintf("%.2f",$stat->variance());
        print "$y\t$ct\t$mn\t$mx\t$mw\n";
        $gesn   = $gesn + $ct;
        $gessm  = $gessm + $sm;
        $ges_mn = $mn if ( $mn < $ges_mn );
        $ges_mx = $mx if ( $mx > $ges_mx );
    }
    $ges_av = sprintf( "%.4f", ( $gessm / $gesn ) );
    print "--------------------------------------\n";
    print "total\t$gesn\t$ges_mn\t$ges_mx\t$ges_av\n";
    print "======================================\n\n";

    my $ges_mna = 1000;
    my $gesna   = $ges_mxa = $gessma  = 0;
    print "======================================\n";
    print "ALL ANIMALS:\nyear\tno\tmin\tmax\tavg\n";
    print "--------------------------------------\n";

    foreach $z ( sort keys %ausw_tot ) {
        $stata = Statistics::Descriptive::Full->new();
        $stata->add_data( @{ $ausw_tot{$z} } );
        $ct = $stata->count();
        $mw = sprintf( "%.4f", $stata->mean() );
        $mn = sprintf( "%.4f", $stata->min() );
        $mx = sprintf( "%.4f", $stata->max() );
        $sm = $stata->sum();
        print "$z\t$ct\t$mn\t$mx\t$mw\n";
        $gesna   = $gesna + $ct;
        $gessma  = $gessma + $sm;
        $ges_mna = $mn if ( $mn < $ges_mna );
        $ges_mxa = $mx if ( $mx > $ges_mxa );
    }
    $ges_av = sprintf( "%.4f", ( $gessma / $gesna ) );
    print "--------------------------------------\n";
    print "total\t$gesna\t$ges_mna\t$ges_mxa\t$ges_av\n";
    print "======================================\n\n";
    return 0;
}

######Create temp_tables for Inbreeding
my $sql1a =
    "SELECT a.breed,a.year,a.inbreeding,a.db_animal,b.db_sire,
            b.db_dam,c.inbreeding AS s_inbred,d.inbreeding AS d_inbred
     FROM   gene_stuff a, animal b
     LEFT OUTER JOIN  gene_stuff c ON b.db_sire=c.db_animal
     LEFT OUTER JOIN  gene_stuff d ON b.db_dam=d.db_animal
     WHERE a.db_animal =    b.db_animal AND
           a.year      <>   'unknown'   AND
           b.db_breed $sine $dbb";

my ( %loop, %loop_s );
my $i = 0;

my $sth_ref = $apiis->DataBase->sys_sql("$sql1a");
$sth_ref->check_status( die => 'ERR' );

print "Bussy reading Gene_stuff.................>\n" if $info;
while ( my $line_ref = $sth_ref->handle->fetch ) {
    my ( $breed, $year, $inbreeding, $animal, $sire, $dam, $s_inbred,
        $d_inbred ) = @$line_ref;

    $loop{ $breed . '|' . $year }[0] += 1
        if $inbreeding >= 0 and $inbreeding <= 0.05;
    $loop{ $breed . '|' . $year }[1] += 1
        if $inbreeding > 0.05 and $inbreeding <= 0.10;
    $loop{ $breed . '|' . $year }[2] += 1
        if $inbreeding > 0.10 and $inbreeding <= 0.15;
    $loop{ $breed . '|' . $year }[3] += 1
        if $inbreeding > 0.15 and $inbreeding <= 0.20;
    $loop{ $breed . '|' . $year }[4] += 1
        if $inbreeding > 0.20 and $inbreeding <= 0.25;
    $loop{ $breed . '|' . $year }[5] += 1
        if $inbreeding > 0.25 and $inbreeding <= 0.30;
    $loop{ $breed . '|' . $year }[6] += 1
        if $inbreeding > 0.30 and $inbreeding <= 0.35;
    $loop{ $breed . '|' . $year }[7] += 1
        if $inbreeding > 0.35 and $inbreeding <= 0.40;
    $loop{ $breed . '|' . $year }[8] += 1
        if $inbreeding > 0.40 and $inbreeding <= 0.45;
    $loop{ $breed . '|' . $year }[9] += 1
        if $inbreeding > 0.45 and $inbreeding <= 0.50;
    $loop{ $breed . '|' . $year }[10] += 1 if $inbreeding > 0.50;

    $loop{ $breed . '|' . $year }[11] += 1
        if $breed and $year;    #Total off-spring

    #Total off-spring inbred:
    $loop{ $breed . '|' . $year }[12] += 1
        if $breed and $year and $inbreeding > 0.00;
    #Total sum of inbreeding for off-spring:
    $loop{ $breed . '|' . $year }[13] += $inbreeding
        if $breed and $year and $inbreeding > 0.00;
    #Total sires:
    $loop{ $breed . '|' . $year }[14] += 1
        if $breed and $year and $sire and $sire > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $sire }[0];
    $loop{ $breed . '|' . $year }[15] += 1
        if $breed and $year and $sire and $sire > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $sire }[0]
            and $s_inbred > 0.00;      #total inbred sires
    $loop{ $breed . '|' . $year }[16] += $s_inbred
        if $breed and $year and $sire and $sire > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $sire }[0]
            and $s_inbred > 0.00;      #Total sum of inbreeding for sires
    $loop{ $breed . '|' . $year }[20] += $s_inbred
        if $breed and $year and $sire and $sire > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $sire }[0]
            and $s_inbred > 0.00;
    $loop_s{ $breed . '|' . $year . '|' . $sire }[0] += 1
        if $breed and $year and $sire and $sire > 2;

    #Total dams:
    $loop{ $breed . '|' . $year }[17] += 1
        if $breed and $year and $dam and $dam > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $dam }[0];
    $loop{ $breed . '|' . $year }[18] += 1
        if $breed and $year and $dam and $dam > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $dam }[0]
            and $d_inbred > 0.00;    #Total inbred dams
    $loop{ $breed . '|' . $year }[19] += $d_inbred
        if $breed and $year and $dam and $dam > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $dam }[0]
            and $d_inbred > 0.00;    #Total sum of inbreeding for dams
    $loop{ $breed . '|' . $year }[20] += $d_inbred
        if $breed and $year and $dam and $dam > 2
            and !defined $loop_s{ $breed . '|' . $year . '|' . $dam }[0]
            and $d_inbred > 0.00;
    $loop_s{ $breed . '|' . $year . '|' . $dam }[0] += 1
        if $breed and $year and $dam and $dam > 2;
}

foreach my $tt ( sort keys %loop ) {
    for ( $i = 0; $i < 21; $i += 1 ) {
        $loop{$tt}[$i] = 'NULL' if !$loop{$tt}[$i];
    }
}

##########TABLE 1
print "Bussy creating Inbreeding Table 1........>\n" if $info;
my $sql2 =
    "CREATE TABLE tmp2_table1 (breed numeric,year numeric,c1 numeric,
                               c2 numeric, c3 numeric, c4 numeric, c5 numeric,
                               c6 numeric, c7 numeric, c8 numeric, c9 numeric,
                               c10 numeric, c11 numeric)";
my $sth2 = $dbh->prepare($sql2)
    or die "Error in prepare statement: $sql2" . $dbh->errstr;
my $rv2 = $sth2->execute()
    or die "Error executing statment:$sql2 " . $sth2->errstr;
$sth2->finish();
$dbh->commit;

foreach my $tt ( sort keys %loop ) {
    my ( $breeda, $yeara ) = split( '\|', $tt );

    $sql2 =
        "INSERT INTO tmp2_table1 (breed,year,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11)
        VALUES ($breeda,$yeara,$loop{$tt}[0],$loop{$tt}[1],$loop{$tt}[2],
                $loop{$tt}[3],$loop{$tt}[4],$loop{$tt}[5],$loop{$tt}[6],
                $loop{$tt}[7],$loop{$tt}[8],$loop{$tt}[9],$loop{$tt}[10])";
    $sth2 = $dbh->prepare($sql2)
        or die "Error in prepare statement: $sql2" . $dbh->errstr;
    $rv2 = $sth2->execute()
        or die "Error executing statment:$sql2 " . $sth2->errstr;
    $sth2->finish();
}
$dbh->commit;

########TABLE 2
print "Bussy creating Inbreeding Table 2........>\n" if $info;
my $sql3 =
    "CREATE TABLE tmp2_table2 (breed numeric,year numeric,off_num numeric,
                               off_bred_num numeric,off_bred_inb numeric,
                               s_num numeric,s_bred_num numeric,
                               s_bred_inb numeric,d_num numeric,
                               d_bred_num numeric,d_bred_inb numeric,
                               p_bred_inb numeric)";
my $sth3 = $dbh->prepare($sql3)
    or die "Error in prepare statement: $sql3" . $dbh->errstr;
my $rv3 = $sth3->execute()
    or die "Error executing statment:$sql3 " . $sth3->errstr;
$sth3->finish();
$dbh->commit;

foreach $tt ( sort keys %loop ) {
    ( $breeda, $yeara ) = split( '\|', $tt );

    my ( $avg_of_inb, $avg_s_inb, $avg_d_inb, $avg_p_inb );

    if (    $loop{$tt}[13] ne 'NULL'
        and $loop{$tt}[11]
        and $loop{$tt}[11] > 0
        and $loop{$tt}[11] ne 'NULL' )
    {
        $avg_of_inb = round3( $loop{$tt}[13] / $loop{$tt}[11] );
    }
    else {
        $avg_of_inb = 'NULL';
    }

    if (    $loop{$tt}[16] ne 'NULL'
        and $loop{$tt}[14]
        and $loop{$tt}[14] > 0
        and $loop{$tt}[14] ne 'NULL' )
    {
        $avg_s_inb = round3( $loop{$tt}[16] / $loop{$tt}[14] );
    }
    else {
        $avg_s_inb = 'NULL';
    }

    if (    $loop{$tt}[19] ne 'NULL'
        and $loop{$tt}[17]
        and $loop{$tt}[17] > 0
        and $loop{$tt}[17] ne 'NULL' )
    {
        $avg_d_inb = round3( $loop{$tt}[19] / $loop{$tt}[17] );
    }
    else {
        $avg_d_inb = 'NULL';
    }

    if (    $loop{$tt}[20] ne 'NULL'
        and $loop{$tt}[14] ne 'NULL'
        and $loop{$tt}[17] ne 'NULL' )
    {
        $avg_p_inb =
            round3( $loop{$tt}[20] / ( $loop{$tt}[14] + $loop{$tt}[17] ) );
    }
    else {
        $avg_p_inb = 'NULL';
    }

    $sql2 =
        "INSERT INTO tmp2_table2 (breed,year,off_num,off_bred_num,off_bred_inb,
                                  s_num,s_bred_num,s_bred_inb,d_num,d_bred_num,
                                  d_bred_inb,p_bred_inb)
         VALUES ($breeda,$yeara,$loop{$tt}[11],$loop{$tt}[12],$avg_of_inb,
                 $loop{$tt}[14],$loop{$tt}[15],$avg_s_inb,$loop{$tt}[17],
                 $loop{$tt}[18],$avg_d_inb,$avg_p_inb)";
    $sth2 = $dbh->prepare($sql2)
        or die "Error in prepare statement: $sql2" . $dbh->errstr;
    $rv2 = $sth2->execute()
        or die "Error executing statment:$sql2 " . $sth2->errstr;
    $sth2->finish();
}
$dbh->commit;

%loop   = ();
%loop_s = ();
###Table 3 and 4:
print "Bussy creating Inbreeding Table 3 and 4..>\n" if $info;

push @sql_statements,
    "SELECT a.breed,a.year,count(*) as number,
            round(min(a.inbreeding),4) as a_min,
            round(max(a.inbreeding),4) as a_max,
            round(avg(a.inbreeding),4) as a_avg,
            round(stddev(a.inbreeding),4) as a_dev
     INTO   tmp2_table3
     FROM gene_stuff a
     WHERE a.breed$sine$dbb
     GROUP BY a.breed,a.year
     ORDER BY a.breed,a.year";

push @sql_statements,
    "SELECT a.breed,a.year,count(*) as number,
            round(min(a.inbreeding),4) as a_min,
            round(max(a.inbreeding),4) as a_max,
            round(avg(a.inbreeding),4) as a_avg,
            round(stddev(a.inbreeding),4) as a_dev
     INTO tmp2_table4
     FROM gene_stuff a
     WHERE a.inbreeding>0 and
           a.breed$sine$dbb
     GROUP BY a.breed,a.year
     ORDER BY a.breed,a.year";

push @sql_statements, "CREATE TABLE tmp2_gen_depth (veld numeric)";

push @sql_statements, "INSERT INTO tmp2_gen_depth (veld) SELECT $maxgen";

foreach $tt (@sql_statements) {
    $sth2 = $dbh->prepare($tt)
        or die "Error in prepare statement: $tt" . $dbh->errstr;
    $rv2 = $sth2->execute()
        or die "Error executing statment:$tt " . $sth2->errstr;
    $sth2->finish();
}
$dbh->commit;

###Table 5
print "Bussy creating Inbreeding Table 5........>\n" if $info;

$sql3 =
    "CREATE TABLE tmp2_table5 (breed numeric,year numeric,off_bred_inb numeric,
                               s_bred_inb numeric,d_bred_inb numeric,
                               p_bred_inb numeric,deltaf numeric,ne numeric,
                               off_num numeric,s_num numeric,d_num numeric,
                               ne_num numeric)";
$sth3 = $dbh->prepare($sql3)
    or die "Error in prepare statement: $sql3" . $dbh->errstr;
$rv3 = $sth3->execute()
    or die "Error executing statment:$sql3 " . $sth3->errstr;
$sth3->finish();
$dbh->commit;

$sql2 =
    "SELECT breed,year,off_bred_inb,s_bred_inb,d_bred_inb,p_bred_inb,off_num,
            s_num,d_num
     FROM tmp2_table2
     ORDER BY breed,year";
$sth_ref = $apiis->DataBase->sys_sql("$sql2");
$sth_ref->check_status( die => 'ERR' );

while ( my $line_ref = $sth_ref->handle->fetch ) {
    my @line = @$line_ref;
    my ($breed, $year,  $a_inb, $s_inb, $d_inb,
        $p_inb, $a_num, $s_num, $d_num
    ) = @line;

    $a_inb = 0 if !$a_inb;
    $s_inb = 0 if !$s_inb;
    $d_inb = 0 if !$d_inb;
    $p_inb = 0 if !$p_inb;

    $a_num = 0 if !$a_num;
    $s_num = 0 if !$s_num;
    $d_num = 0 if !$d_num;

    my $f = round3( ( $a_inb - $p_inb ) / ( 1 - $p_inb ) );
    my $ne;
    if ( $f > 0 ) {
        $ne = round0( 1 / ( 2 * $f ) );
    }
    else {
        $ne = 'NULL';
    }

    my $ne_num;
    if ( ( $s_num + $d_num ) > 0 ) {
        $ne_num = round0( ( 4 * $s_num * $d_num ) / ( $s_num + $d_num ) * 0.7 );
    }
    else {
        $ne_num = 'NULL';
    }

    $a_num = 'NULL' if $a_num == 0;
    $s_num = 'NULL' if $s_num == 0;
    $d_num = 'NULL' if $d_num == 0;

    my $sql =
        "INSERT INTO tmp2_table5 (breed,year,off_bred_inb,s_bred_inb,d_bred_inb,
                                  p_bred_inb,deltaf,ne,off_num,s_num,d_num,
                                  ne_num)
         VALUES ($breed,$year,$a_inb,$s_inb,$d_inb,$p_inb,$f,$ne,$a_num,$s_num,
                 $d_num,$ne_num)";
    my $sth2 = $dbh->prepare($sql)
        or die "Error in prepare statement: $sql" . $dbh->errstr;
    my $rv2 = $sth2->execute()
        or die "Error executing statment:$sql " . $sth2->errstr;
    $sth2->finish();
}

###cens carina###################
unlink("prmon-cens-ne.data");

#preparing for new values###################
my $sql66 = "DELETE FROM tmp2_table5";
my $sth66 = $dbh->prepare(qq{ $sql66 }) or die $dbh->errstr;
my $ret66 = $sth66->execute;

###loop for birth-years###########carina
my @years;
my $sql = "SELECT year FROM  gene_stuff , codes
           WHERE db_code = breed AND
                 short_name='$breed' AND
                 year != 'unknown'
           GROUP by year ORDER BY year DESC";

my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
my $ret = $sth->execute;

my $outfile_cens_ne = "prmon-cens-ne.data";
open my $OUT_CENS_NE, '>', $outfile_cens_ne
    or die "Problems opening $outfile_cens_ne: $!\n";

while ( my $ss = $sth->fetch ) {
    @years = @$ss;
    #  calculating  cens-ne ###############
    foreach $year (@years) {
        my $sql =
            "SELECT a.db_code, a.year, a.animal, a.sire, a.dam,
                    round((4*(a.sire*a.dam)/(cast(a.sire AS decimal)
                          +cast(a.dam AS decimal)))*0.7) AS cens_ne
             FROM   (SELECT db_code, max(extract(year from birth_dt)) AS year,
                            count(distinct db_animal) AS animal,
                            count(distinct db_sire) AS sire,
                            count(distinct db_dam) AS dam
                     FROM   animal, codes,
                            (SELECT  cast(year AS numeric), round(pop,0) AS gi
                             FROM   tmp1_gen
                             WHERE  year!= 'Total') AS g
                     WHERE  extract(year from birth_dt) <= $year AND
                            extract(year from birth_dt) > $year - $gen_interval AND
                            db_breed=db_code AND
                            short_name='$breed' group by db_code ) AS a
             ORDER BY a.year DESC";
        my $sth = $dbh->prepare(qq{ $sql })
            or die "Prepare error: $sql" . $dbh->errstr;
        $sth->execute or die "Execute error: $sql" . $sth->errstr;
        while ( my $ss = $sth->fetch ) {
            my @line = @$ss;
            print $OUT_CENS_NE "@line\n";
        }
    }
}
close $OUT_CENS_NE;
$dbh->commit;

# update old values (carina):
my $in40_file = "prmon-cens-ne.data";
open my $IN40, '<', $in40_file or die "Problems opening file $in40_file: $!\n";
foreach (<$IN40>) {
    chomp;
    next if /^#/;
    next if /^\s*$/;
    s/^\s*//;
    s/\s*$//;
    my ( $breed, $dbyear, $num_off, $num_s, $num_d, $cens_ne ) = split /\s+/, $_;
    $num_off = 'NULL' if !defined $num_off;
    $num_s   = 'NULL' if !defined $num_s;
    $num_d   = 'NULL' if !defined $num_d;
    $cens_ne = 'NULL' if !defined $cens_ne;

    print "$breed|$dbyear|$num_off|$num_s|$num_d|$cens_ne\n" if $debug;
    my $sql40 =
        "INSERT INTO tmp2_table5 (breed,year, off_num, s_num, d_num, ne_num)
         VALUES ($breed, $dbyear, $num_off, $num_s, $num_d, $cens_ne)";

    my $sth40 = $dbh->prepare($sql40)
        or die "Error in prepare statement: $sql40" . $dbh->errstr;
    $sth40->execute() or die "Error executing statment:$sql40" . $sth40->errstr;
    $sth40->finish();
}
close $IN40;
$dbh->commit;

# deltaF_parents Ne (carina):
# loop for birth-years (carina):
my $sql_years = "SELECT year FROM  gene_stuff , codes
           WHERE db_code = breed AND
                 short_name='$breed' AND
                 year != 'unknown'
           GROUP by year ORDER BY year DESC";
my $sth_years = $dbh->prepare($sql_years) or die $dbh->errstr;
$sth_years->execute;

my $deltafp_ne_file = 'prmon-deltafp-ne.data';
open my $OUT_DFP, '>', $deltafp_ne_file
    or die "Problems opening $deltafp_ne_file: $!\n";

while ( my $ss = $sth_years->fetch ) {
    my @years = @$ss;
    # calculating deltaFp-ne:
    foreach my $year (@years) {
#         my $sql =
#             "SELECT z.breed, z.year, round(z.inb_off, 4) AS inb_off,
#                     round(z.inb_sire, 4) AS inb_sire,
#                     round(z.inb_dam, 4)  AS inb_dam,
#                     round(z.inb_par, 4)  AS inb_par,
#                     round(z.delta, 4)    AS deltaFp,
#                     CASE
#                         WHEN z.delta > 0
#                         THEN round((1/(2*z.delta)), 0)
#                         ELSE NULL
#                     END AS deltaFp_ne
#             FROM (SELECT b.breed, $year    AS year,
#                          a.inbreeding_off  AS inb_off,
#                          c.inbreeding_sire AS inb_sire,
#                          d.inbreeding_dam  AS inb_dam,
#                          b.inbreeding_par  AS inb_par ,
#                          (a.inbreeding_off - b.inbreeding_par)/(1 - b.inbreeding_par) AS delta
#                   FROM   (SELECT avg(a.inbreeding) AS inbreeding_off
#                           FROM gene_stuff  a
#                           WHERE cast(a.year AS numeric) <= $year AND
#                                 cast(a.year AS numeric) > $year - $gen_interval AND
#                                 a.year != 'unknown' ) AS a ,
#                                 (SELECT avg(b.inbreeding) AS inbreeding_sire
#                                  from codes a, gene_stuff b, animal c
#                                  WHERE b.year != 'unknown' AND
#                                        b.db_animal = c.db_sire AND
#                                        extract(year from c.birth_dt)
#                                            between ($year - ($gen_interval - 1)) AND $year AND
#                                        c.db_breed = a.db_code AND
#                                        a.short_name = '$breed' ) AS c,
#                                 (SELECT avg(b.inbreeding) AS inbreeding_dam
#                                  FROM codes a, gene_stuff b, animal c
#                                  WHERE b.year != 'unknown' AND
#                                        b.db_animal = c.db_dam AND
#                                        extract(year from c.birth_dt)
#                                            between ($year - ($gen_interval - 1))  AND $year AND
#                                        c.db_breed = a.db_code AND
#                                        a.short_name = '$breed' ) AS d,
#                                 (SELECT b.breed, avg(b.inbreeding) AS inbreeding_par
#                                  FROM codes a, gene_stuff b, animal c
#                                  WHERE b.year != 'unknown' AND
#                                        (b.db_animal = c.db_sire OR
#                                         b.db_animal = c.db_dam) AND
#                                        extract(year from c.birth_dt)
#                                            between $year - ($gen_interval - 1) AND $year AND
#                                        c.db_breed = a.db_code AND
#                                        a.short_name = '$breed'
#                                  GROUP BY b.breed) AS b
#                  ) AS z
#             ORDER BY z.year desc ";
        my $sql =
            "SELECT z.breed, z.year, round(z.inb_off, 4) AS inb_off,
                    round(z.inb_sire, 4) AS inb_sire,
                    round(z.inb_dam, 4)  AS inb_dam,
                    round(z.inb_par, 4)  AS inb_par,
                    round(z.delta, 4)    AS deltaFp,
                    CASE
                        WHEN z.delta > 0 or z.delta < 0
                        THEN round((1/(2*z.delta)), 0)
                        ELSE NULL
                    END AS deltaFp_ne
            FROM (SELECT b.breed, $year    AS year,
                         a.inbreeding_off  AS inb_off,
                         c.inbreeding_sire AS inb_sire,
                         d.inbreeding_dam  AS inb_dam,
                         b.inbreeding_par  AS inb_par ,
                         (a.inbreeding_off - b.inbreeding_par)/(1 - b.inbreeding_par) AS delta
                  FROM   (SELECT avg(a.inbreeding) AS inbreeding_off
                          FROM gene_stuff  a
                          WHERE cast(a.year AS numeric) <= $year AND
                                cast(a.year AS numeric) > $year - $gen_interval AND
                                a.year != 'unknown' ) AS a ,
                                (SELECT avg(b.inbreeding) AS inbreeding_sire
                                 from codes a, gene_stuff b, animal c
                                 WHERE b.year != 'unknown' AND
                                       b.db_animal = c.db_sire AND
                                       extract(year from c.birth_dt)
                                           between ($year - ($gen_interval - 1)) AND $year AND
                                       c.db_breed = a.db_code AND
                                       a.short_name = '$breed' ) AS c,
                                (SELECT avg(b.inbreeding) AS inbreeding_dam
                                 FROM codes a, gene_stuff b, animal c
                                 WHERE b.year != 'unknown' AND
                                       b.db_animal = c.db_dam AND
                                       extract(year from c.birth_dt)
                                           between ($year - ($gen_interval - 1))  AND $year AND
                                       c.db_breed = a.db_code AND
                                       a.short_name = '$breed' ) AS d,
                                (SELECT b.breed, avg(b.inbreeding) AS inbreeding_par
                                 FROM codes a, gene_stuff b, animal c
                                 WHERE b.year != 'unknown' AND
                                       (b.db_animal = c.db_sire OR
                                        b.db_animal = c.db_dam) AND
                                       extract(year from c.birth_dt)
                                           between $year - ($gen_interval - 1) AND $year AND
                                       c.db_breed = a.db_code AND
                                       a.short_name = '$breed'
                                 GROUP BY b.breed) AS b
                 ) AS z
            ORDER BY z.year desc ";
        my $sth = $dbh->prepare(qq{ $sql })
            or die "Error in prepare statement: $sql" . $dbh->errstr;
        $sth->execute or die "Error executing statment:$sql" . $sth->errstr;

        my @line = @$ss;
        while ( my $ss = $sth->fetch ) {
            # my @line = @$ss;
            my @line = map { defined $_ ? $_ : '' } @$ss;
            print $OUT_DFP "@line\n";
        }
    }
}
close $OUT_DFP;

# update old values (carina):
#  year | inb_off | inb_sire | inb_dam | inb_par | deltafp | deltafp_ne
# ------+---------+----------+---------+---------+---------+------------
#  2008 |  0.0311 |   0.0182 |  0.0214 |  0.0198 |  0.0115 |         44

open my $IN50, '<', $deltafp_ne_file
    or die "Problems opening file $deltafp_ne_file: $!\n";
foreach (<$IN50>) {
    chomp;
    next if /^#/;
    next if /^\s*$/;
    s/^\s*//;
    s/\s*$//;
    my ( $breed, $dbyear, $inb_off, $inb_s, $inb_d, $inb_p, $deltaFp,
        $deltaFp_ne ) = split /\s+/, $_;
    $inb_off    = 'NULL' if !defined $inb_off;
    $inb_s      = 'NULL' if !defined $inb_s;
    $inb_d      = 'NULL' if !defined $inb_d;
    $inb_p      = 'NULL' if !defined $inb_p;
    $deltaFp    = 'NULL' if !defined $deltaFp;
    $deltaFp_ne = 'NULL' if !defined $deltaFp_ne;
    print "$breed|$dbyear|$inb_off|$inb_s|$inb_d|$inb_p|$deltaFp|$deltaFp_ne\n" if $debug;
    my $sql50 = "UPDATE tmp2_table5
                 SET    off_bred_inb = $inb_off,
                        s_bred_inb   = $inb_s,
                        d_bred_inb   = $inb_d,
                        p_bred_inb   = $inb_p,
                        deltaf       = $deltaFp,
                        ne           = $deltaFp_ne
                 WHERE  year = $dbyear and breed = $breed";
    my $sth50 = $dbh->prepare($sql50)
        or die "Error in prepare statement: $sql50" . $dbh->errstr;
    $sth50->execute() or die "Error executing statment:$sql50" . $sth50->errstr;
    $sth50->finish();
}
close $IN50;
$dbh->commit;

# Table 6 wird mit agr und DeltaFg (bei DeltaFg noch Cohorten nach Jahren) aus inbreeding_report gefüllt (carina):
print "Busy creating Inbreeding Table 6........>\n" if $info;

my $sql8 = "CREATE TABLE tmp2_table6
                (breed numeric,year numeric,num_off numeric,
                 agr_f numeric,agr_delta_f numeric, agr_ne numeric,
                 Fg_off numeric, Fg_par numeric,deltaFg_ne numeric)";
my $sth8 = $dbh->prepare($sql8)
    or die "Error in prepare statement: $sql8" . $dbh->errstr;
$sth8->execute() or die "Error executing statment:$sql8 " . $sth8->errstr;
$sth8->finish();
$dbh->commit;

# Table 7 (carina):
print "Busy creating Inbreeding Table 7........>\n" if $info;

my $sql9 = "CREATE TABLE tmp2_table7
                (breed numeric,year numeric,num_off numeric,
                 Fg_off numeric, Fg_par numeric, deltaFg numeric, deltaFg_ne numeric)";
my $sth9 = $dbh->prepare($sql9)
    or die "Error in prepare statement: $sql9" . $dbh->errstr;
$sth9->execute() or die "Error executing statment:$sql9 " . $sth9->errstr;
$sth9->finish();
$dbh->commit;


# deltaF_generation Ne (carina):
my $deltafg_ne_file = 'prmon-deltafg-ne.data';
open my $OUT_DFG, '>', $deltafg_ne_file
    or die "Problems opening $deltafg_ne_file: $!\n";

# loop for birth-years (carina):
my $sql_by = "SELECT year FROM  gene_stuff , codes
              WHERE db_code    = breed    AND
                    short_name = '$breed' AND
                    year      != 'unknown'
              GROUP by year ORDER BY year DESC";

my $sth_by = $dbh->prepare(qq{ $sql_by }) or die $dbh->errstr;
$sth_by->execute;

while ( my $ss = $sth_by->fetch ) {
    my @years = @$ss;
    # calculating deltaFg-ne:
    foreach my $year (@years) {
#         my $sql =
#             "SELECT z.breed,
#                     z.year,
#                     z.number,
#                     round(z.inb_off, 4) AS inb_off,
#                     round(z.inb_par, 4) AS inb_par,
#                     round(z.deltaFg, 4) AS deltaFg,
#                     CASE
#                         WHEN z.deltaFg > 0
#                         THEN round((1/(2*z.deltaFg)), 0)
#                         ELSE NULL
#                     END AS deltaFg_ne
#              FROM (SELECT $year AS year, a.breed, a.number,
#                           a.inbreeding_off AS inb_off,
#                           b.inbreeding_par AS inb_par,
#                           (a.inbreeding_off - b.inbreeding_par)/(1 - b.inbreeding_par) AS deltaFg
#                    FROM (SELECT breed, count(db_animal) AS number,
#                                 avg(a.inbreeding) AS inbreeding_off
#                          FROM gene_stuff a
#                          WHERE cast(a.year AS numeric) <= $year AND
#                                cast(a.year AS numeric) > $year - $gen_interval AND
#                                a.year != 'unknown' group by breed) AS a,
#                                (SELECT avg(a.inbreeding) AS inbreeding_par
#                                 FROM  gene_stuff a
#                                 WHERE cast(a.year AS numeric) <= $year - $gen_interval AND
#                                       cast(a.year AS numeric) > $year - $gen_interval - $gen_interval AND
#                                       a.year != 'unknown') AS b ) AS z
#                                 ORDER BY year DESC";
	              my $sql =
            "SELECT z.breed,
                    z.year,
                    z.number,
                    round(z.inb_off, 4) AS inb_off,
                    round(z.inb_par, 4) AS inb_par,
                    round(z.deltaFg, 4) AS deltaFg,
                    CASE
                        WHEN z.deltaFg > 0 or z.deltaFg < 0
                        THEN round((1/(2*z.deltaFg)), 0)
                        ELSE NULL
                    END AS deltaFg_ne
             FROM (SELECT $year AS year, a.breed, a.number,
                          a.inbreeding_off AS inb_off,
                          b.inbreeding_par AS inb_par,
                          (a.inbreeding_off - b.inbreeding_par)/(1 - b.inbreeding_par) AS deltaFg
                   FROM (SELECT breed, count(db_animal) AS number,
                                avg(a.inbreeding) AS inbreeding_off
                         FROM gene_stuff a
                         WHERE cast(a.year AS numeric) <= $year AND
                               cast(a.year AS numeric) > $year - $gen_interval AND
                               a.year != 'unknown' group by breed) AS a,
                               (SELECT avg(a.inbreeding) AS inbreeding_par
                                FROM  gene_stuff a
                                WHERE cast(a.year AS numeric) <= $year - $gen_interval AND
                                      cast(a.year AS numeric) > $year - $gen_interval - $gen_interval AND
                                      a.year != 'unknown') AS b ) AS z
                                ORDER BY year DESC";
        my $sth = $dbh->prepare(qq{ $sql })
            or die "Error in prepare statement: $sql" . $dbh->errstr;
        $sth->execute or die "Error executing statment:$sql" . $sth->errstr;

        my @line = @$ss;
        while ( my $ss = $sth->fetch ) {
            # my @line = @$ss;
            my @line = map { defined $_ ? $_ : '' } @$ss;
            print $OUT_DFG "@line\n";
        }
    }
}
close $OUT_DFG;

# insert data into table 7
open my $IN_DFG, '<', $deltafg_ne_file
    or die "Problems opening $deltafg_ne_file: $!\n";
my %animal1;
my $sql11 = "INSERT INTO tmp2_table7
                 (breed , year , num_off , Fg_off , Fg_par ,deltaFg, deltaFg_ne)
             VALUES (?,?,?,?,?,?,?)";
my $sth11 = $dbh->prepare($sql11)
    or die "Error in prepare statement: $sql11" . $dbh->errstr;

foreach ( <$IN_DFG> ) {
    next if /^#/;
    chomp;
    s/^\s*//;
    s/\s*$//;
    my ( $breed, $year, $num_ani_Fg, $Fg_off, $Fg_par, $deltaFg, $deltaFg_ne ) =
        split /\s+/, $_;
    printf "%s, %s, %s, %s, %s, %s, %s\n",
        $breed, $year, $num_ani_Fg || '', $Fg_off || '', $Fg_par || '',
        $deltaFg || '', $deltaFg_ne || '' if $debug;

    if ( defined $num_ani_agr ) { $num_ani_agr = undef if $num_ani_agr eq '-' }
    if ( defined $avg_agr )     { $avg_agr     = undef if $avg_agr     eq '-' }
    if ( defined $delta_agr )   { $delta_agr   = undef if $delta_agr   eq '-' }
    if ( defined $avg_Fg )      { $avg_Fg      = undef if $avg_Fg      eq '-' }
    if ( defined $deltaFg )     { $deltaFg     = undef if $deltaFg     eq '-' }
    if ( defined $gi )          { $gi          = undef if $gi          eq '-' }

    $sth11->execute( $breed, $year, $num_ani_Fg, $Fg_off, $Fg_par, $deltaFg,
        $deltaFg_ne ) or die "Execute error: $sql11 " . $sth11->errstr;
}
close $IN_DFG;
$sth11->finish();
$dbh->commit;

# #carina
# ##starten von Programmen zum Berechnen von Log-Reg-Ne pro Generation
# ##nicht im InbreedingReport enthalten
# ##wird bei PRMON genutzt

system ("prmon_log_reg.pl -p $opt_p -u $opt_d -P $opt_w -b $opt_b -g $opt_I");
print " prmon_log_reg.pl -p $opt_p -u $opt_d -P $opt_w -b $opt_b -g $opt_I \n";

#carina
##starten von Programmen zum Berechnen von ECG-Ne
##nicht im InbreedingReport enthalten
##wird bei PRMON genutzt

system ("prmon_ecg_data.pl -p $opt_p -u $opt_d -P $opt_w -b $opt_b -g $opt_I");
print "prmon_ecg_data.pl -p $opt_p -u $opt_d -P $opt_w -b  $opt_b -g $opt_I\n";

# end (carina)

# do count(*) on auxiliary tables:
if ( defined $opt_c and not defined $opt_k ) {
    counttable();
}

##### Sub-routines
sub deltables {
    print "\nDelete tables:\n" if $info;
    my @temp_tables_used;
    my $sql = "SELECT tablename FROM pg_tables";
    my $sth = $apiis->DataBase->sys_sql("$sql");
    while ( my $data_ref = $sth->handle->fetch ) {
        my $table = $$data_ref[0];
        if ( $table =~ /^tmp2/ ) {
            push @temp_tables_used, $table;
        }
    }

    foreach my $this_table (@temp_tables_used) {
        my $sth = $apiis->DataBase->sys_sql("DROP TABLE IF EXISTS $this_table");
        print "Dropping table $this_table:\n" if $info;
        $apiis->DataBase->sys_dbh->commit || die $dbh->errstr;
    }

    return 0;
}

sub counttable {
    print "\nNumber of records created:\n" if $info;
    my @temp_tables_used;
    my $sql = "SELECT tablename FROM pg_tables";
    my $sth = $apiis->DataBase->sys_sql("$sql");
    while ( my $data_ref = $sth->handle->fetch ) {
        my $table = $$data_ref[0];
        if ( $table =~ /^tmp2/ ) {
            push @temp_tables_used, $table;
        }
    }

    foreach my $this_table (@temp_tables_used) {
        my $sth = $apiis->DataBase->sys_sql("SELECT count(*) FROM $this_table");
        while ( my $data_ref = $sth->handle->fetch ) {
            my $counts = $$data_ref[0];
            print "$this_table: $counts records\n" if $info;
        }
    }
    return 0;
}

####################################
# get pedigree recursively
####################################
# we start with an animal ID, this may or may not have a known parent.
sub get_ped_mem {
    my $db_animal = shift;
    my $loc_sire  = $main::ped{$db_animal}[0];
    my $loc_dam   = $main::ped{$db_animal}[1];

    if ( defined $loc_sire or defined $loc_dam ) {
        $main::gen_counter++;
        # the pedigree may be deeper that maxgen, then return
        if ( $main::gen_counter > 100 ) {    # pedigree loop?
            print "----- LOOP? $db_animal \n";
            $main::gen_counter = 1;
            return (-1);
        }
        elsif ( $main::gen_counter > $main::maxgen ) {
            $main::gen_counter--;
            return (0);
        }
    }
    else {
        return 0;
    }
    # 1. (recursively) handle sire
    if ( defined $loc_sire ) {
        if ( $main::gen_counter <= $main::maxgen ) {
            $main::completeness =
                $main::completeness + ( .5 / 2**( $main::gen_counter - 1 ) );
        }
        my $status = &get_ped_mem($loc_sire);
        return -1 if $status == -1; # error: exit everything
    }
    # 2. (recursively) handle dam
    if ( defined $loc_dam ) {
        if ( $main::gen_counter <= $main::maxgen ) {
            $main::completeness =
                $main::completeness + ( .5 / 2**( $main::gen_counter - 1 ) );
        }
        my $status = &get_ped_mem($loc_dam);
        return -1 if $status == -1; # error: exit everything
    }
    $main::gen_counter--;
    return 0;
}

sub round3 {
    my $number = shift;
    $number = ( int( ( $number * 10000 ) + .5 ) / 10000 );
    return ($number);
}

sub round0 {
    my $number = shift;
    $number = ( int( ( $number * 1 ) + .5 ) / 1 );
    return ($number);
}

sub ped_completeness {
    my $i = shift @_;
    my $start_animal;
    $j = 0;
    print "\n# start pedicompleteness for $i generations\n";
    $maxgen = $i;
    open( OUT, ">tmp$i.txt" );
    foreach $start_animal ( keys %ped ) {
        next if !$main::ped{$start_animal}[2];

        my $its_sire  = $main::ped{$start_animal}[0];
        my $its_dam   = $main::ped{$start_animal}[1];
        my $sire_comp = 0;
        my $dam_comp  = 0;

        # SIRE
        if ( defined $its_sire ) {
            $completeness = .5 / ( 2**( 1 - 1 ) );
            $gen_counter = 1;
            my ($status) = &get_ped_mem($its_sire);
        }
        else {
            $completeness = 0;
        }
        $sire_comp = $completeness / $maxgen;

        # DAM
        if ( defined $its_dam ) {
            $completeness = .5 / ( 2**( 1 - 1 ) );
            $gen_counter = 1;
            my ($status) = &get_ped_mem($its_dam);
        }
        else {
            $completeness = 0;
        }
        $dam_comp = $completeness / $maxgen;
        my $indiv_comp = 0;

        # the result:
        if ( $sire_comp + $dam_comp > 0 ) {
            $indiv_comp =
                ( 4 * $sire_comp * $dam_comp ) / ( $sire_comp + $dam_comp );
        }
        # store per birth year:
        my $year =
              $i . '|'
            . $main::ped{$start_animal}[4] . '|'
            . $main::ped{$start_animal}[2];
        print OUT "$year" . '#' . "$indiv_comp" . '#' . "$start_animal\n";
    }
    close OUT;
}

# vim:tw=100
