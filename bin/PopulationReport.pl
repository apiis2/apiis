#!/usr/bin/env perl
##############################################################################
BEGIN {
    use Env qw( APIIS_HOME );
    die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
    push @INC, "$APIIS_HOME/lib";
}

use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.66 $ ' );
use open ':utf8';    # input and output default layer will be UTF-8
binmode STDOUT, ":utf8";
use Popreport;       # provides print_list()
our $apiis;
use Apiis::Auth::AccessControl;
use Apiis::Misc qw ( mychomp LocalToRawDate );    # ...
use Apiis::DataBase::User;

initialize();

use vars qw(
    $opt_h $opt_f $opt_a $opt_o $opt_u $opt_b $opt_d $opt_a $opt_t $opt_p $opt_w
    $opt_L $db_user $opt_g);

use Getopt::Std;
$opt_g = 'year';
getopts('f:hod:u:st:p:w:b:a:g:L:');
if ($opt_h) {
    print "usage:\n";
    print " -h this message \n";
    print " -u <> database user \n";
    print " -w <> database password \n";
    print " -p <project_name>\n\n";
    print " -a name of class for breed, default is BREED\n";
    print " -b database short_name for breed\n";
    print " -g Gestation measure year, month or day (Default = $opt_g)\n\n";
    die "\n";
}

if ($opt_p) {
    $project_name = $opt_p;
    print "project = $project_name\n";
}
else {
    print "usage:\n";
    print " -h this message \n";
    print " -u <> database user \n";
    print " -w <> database password \n";
    print " -p <project_name>\n\n";
    print " -a name of class for breed, default is BREED\n";
    print " -b database short_name for breed\n";
    print " -g Gestation measure year, month or day (Default = $ges_len)\n";
    print " -L <listfile> listfile for program output \n\n";
    die "\n";
}

sub initialize {
    use Tie::IxHash;
    use Text::ParseWords;
    use Statistics::Descriptive;
    use vars qw / $i $line_ref $k %treein $sql
        %ped $dbh $breed $sine $dbb %delfiles /;
}

############################################################
# Get the project and user sort out
############################################################
my $not_ok    = 1;
my $loginname = $opt_u if $opt_u;
my $passwd    = $opt_w if $opt_w;

if ( !$opt_u and !$opt_w ) {
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
$db_user = $apiis->User->id;

$dbh = $apiis->DataBase->dbh;
$dbh->{AutoCommit} = 0;
my $user = $apiis->User->id;
my $now  = $apiis->now;
our $listfile = $opt_L if $opt_L;
my $texlist = $listfile;
$texlist =~ s/lst$/tex/;

############################################################
## sort breed out
############################################################
if ($opt_b) {
    $breed = $opt_b;
    print "BREED = $breed\n\n";
}
if ($opt_a) {
    $brd = $opt_a;
}
else {
    $brd = 'BREED';
}
print "CLASS = $brd\n\n";
$sine = '=';
my $sql1;
if ( !defined $breed ) {
    $sql1 = "select min(db_breed) from animal";
    $sine = '>=';
    my $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
    $apiis->check_status;
    while ( my $line_ref = $sql_ref1->handle->fetch ) {
        my @line = @$line_ref;
        $dbb = $line[0];
    }
}
else {
    $sql1 =
        "select db_code from codes where class='$brd' and (ext_code='$breed' or
          short_name = '$breed' or long_name='$breed')";
    my $sql_ref1 = $apiis->DataBase->sys_sql($sql1);
    $apiis->check_status;
    while ( my $line_ref = $sql_ref1->handle->fetch ) {
        my @line = @$line_ref;
        $dbb = $line[0];
    }
}
if ( !$dbb and $opt_b ) {
    my @die_msg_breed;
    push @die_msg_breed, "ERROR:\n";
    push @die_msg_breed, "Breed $breed does not exist in the database\n";
    push @die_msg_breed, "No inbreeding report can be created.\n";
    print_tex_item( join( '\\\\', @die_msg_breed ), $texlist );
    die sprintf "\n**** Breed $breed does not exist in database ****\n\n";
}

############################################################
my $sql         = "";
my @table_names = $dbh->tables;
my $exsist;
foreach my $tb (@table_names) {
    $exsist = $tb if $tb =~ /tmp1/;
}
if ( !$exsist ) {
    my @die_msg_breed;
    push @die_msg_breed, "ERROR:\n";
    push @die_msg_breed, "No Population report due to previous errors\n";
    print_tex_item( join( '\\\\', @die_msg_breed ), $texlist );
    die sprintf
        "\n**** Can not create Population report due to previous errors ****\n";
}

############################################################
## Start the report
############################################################
my $hd    = "$APIIS_HOME/etc/PopReport/";
my $local = $apiis->APIIS_LOCAL;

my $outputfile = "Population-$opt_b.tex";
my $output     = "Population-$opt_b";
my $csv;
open( OUT, ">$outputfile" ) or die "Problems opening file $outputfile: $!\n";

##Create header
##############
my $file = "$hd" . "PopulationDoc.hd";
open( IN, $file ) or die "Problems opening $file: $!\n";
my $bb = uc $project_name;
$bb =~ s/_/\\_/g;

while (<IN>) {
    my $line = $_;
    chomp $line;
    $line =~ s/XX-BREED-XX/${opt_b}/;
    print OUT $line, "\n";
}
close IN;

##Create report.1.
#################
$file = "$hd" . "Population_1.hd";
open( IN, $file ) or die "Problems opening $file: $!\n";
while (<IN>) {
    mychomp($_);
    print OUT "$_ \n";
}

my $title =
    'Number of sires and dams in reproduction by year of birth of offspring';
$sql = "SELECT a.breed,a.year,a.parent,a.service,a.borns,a.sel,b.number 
        FROM tmp1_1 a, tmp1_pas b
        WHERE a.breed=b.breed AND
              a.year=b.year
        ORDER BY a.breed,a.year,a.parent";
my $sql_ref = $apiis->DataBase->sys_sql($sql);
$apiis->check_status;
$sql_ref->check_status( die => 'ERR' );

my $tabalign = 'c';
my ( %clear, %hash, %breed );

while ( my $line_ref = $sql_ref->handle->fetch ) {
    my @line = @$line_ref;
    my ( $breed, $year, $parent, $service, $borns, $sel, $nbirth ) = @line;
    #####  ####  ######  #######  ###### ###
    my $aa = $parent;
    $aa =~ s/ //g;
    $hash{ $breed . '|' . $year }{$aa}[0] = $service;
    $hash{ $breed . '|' . $year }{$aa}[1] = $borns;
    $hash{ $breed . '|' . $year }{$aa}[2] = $sel;
    $hash{ $breed . '|' . $year }{$aa}[3] = $breed;
    $hash{ $breed . '|' . $year }{$aa}[4] = $year;
    $hash{ $breed . '|' . $year }{$aa}[5] = $parent;
    $hash{ $breed . '|' . $year }{$aa}[6] = $nbirth;
    $breed{$breed}                        = $breed;
    $breed{$breed}[1]++ if $aa eq 'sire' and $year;

    if ( !$hash{ $breed . '|' . $year }{$aa}[0] ) {
        $hash{ $breed . '|' . $year }{$aa}[0] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }{$aa}[1] ) {
        $hash{ $breed . '|' . $year }{$aa}[1] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }{$aa}[2] ) {
        $hash{ $breed . '|' . $year }{$aa}[2] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }{$aa}[3] ) {
        $hash{ $breed . '|' . $year }{$aa}[3] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }{$aa}[4] ) {
        $hash{ $breed . '|' . $year }{$aa}[4] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }{$aa}[5] ) {
        $hash{ $breed . '|' . $year }{$aa}[5] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }{$aa}[6] ) {
        $hash{ $breed . '|' . $year }{$aa}[6] = '-';
    }
}

##### print explanation in header ######
my ( $jr, $sser, $slit, $sof, $dser, $dlit, $dof ) = undef;
my $servtab = undef;
foreach my $tt ( sort keys %breed ) {
    next if $breed{$tt}[1] < 3;
    foreach my $ttt ( sort keys %hash ) {
        if ( "$hash{$ttt}{sire}[3]" eq "$tt" ) {
            if ( $hash{$ttt}{sire}[0] and $hash{$ttt}{sire}[0] > 0 ) {
                $servtab = 1;
                last;
            }
        }
    }
    last if $servtab;
}

my $tmp;
foreach my $tt ( sort keys %breed ) {
    next if $breed{$tt}[1] < 3;
    foreach my $ttt ( sort keys %hash ) {
        if ( "$hash{$ttt}{sire}[3]" eq "$tt" ) {
            if ( defined $servtab ) {
                if (    $hash{$ttt}{sire}[0] > 10
                    and $hash{$ttt}{sire}[1] > 0
                    and $hash{$ttt}{sire}[2] > 0
                    and $hash{$ttt}{dam}[0] > 0
                    and $hash{$ttt}{dam}[1] > 0
                    and $hash{$ttt}{dam}[2] > 0 )
                {
                    $tmp  = $tt;
                    $jr   = $hash{$ttt}{sire}[4];    #year
                    $sser = $hash{$ttt}{sire}[0];    #sire service
                    $slit = $hash{$ttt}{sire}[1];    #sire litters
                    $sof  = $hash{$ttt}{sire}[2];    #sire offspring
                    $dser = $hash{$ttt}{dam}[0];     #dam service
                    $dlit = $hash{$ttt}{dam}[1];     #dam litters
                    $dof  = $hash{$ttt}{dam}[2];     #dam ofspring
                    last;
                }
            }
            else {
                if (    $hash{$ttt}{sire}[1] > 10
                    and $hash{$ttt}{sire}[2] > 0
                    and $hash{$ttt}{dam}[1] > 0
                    and $hash{$ttt}{dam}[2] > 0 )
                {
                    $tmp = $tt;
                    $jr  = $hash{$ttt}{sire}[4];     #year
                    # $sser=$hash{$ttt}{sire}[0];    #sire service
                    $slit = $hash{$ttt}{sire}[1];    #sire litters
                    $sof  = $hash{$ttt}{sire}[2];    #sire offspring
                    # $dser=$hash{$ttt}{dam}[0];     #dam service
                    $dlit = $hash{$ttt}{dam}[1];     #dam litters
                    $dof  = $hash{$ttt}{dam}[2];     #dam ofspring
                    last;
                }
            }
        }
    }
    last;
}

my $bborn = 0;
foreach my $ttt ( sort keys %hash ) {
    if ( $tmp eq $hash{$ttt}{sire}[3] ) {
        if ( $jr eq $hash{$ttt}{sire}[4] ) {
            $bborn = $hash{$ttt}{sire}[6];
        }
    }
}

if ( defined $servtab ) {
    print OUT '\begin{center}' . "\n"
        . '\textbf{For example:}'
        . "For the $tmp breed in $jr, $sser sires participated in services while
          $slit sires and $dlit dams produced the $bborn offspring during this
          year.  In the batch of future parents (select) born in this year $jr
          $sof sires and $dof dams were represented.\\ \n"
        . '\end{center}' . "\n";
}
else {
    print OUT '\begin{center}' . "\n"
        . '\textbf{For example:}'
        . "For the $tmp breed in $jr, $slit sires and $dlit dams produced the
          $bborn offspring during this year.  In the batch of future parents
          (select) born in this year $jr  $sof sires and $dof dams were
          represented. \\ \n"
        . '\end{center}' . "\n";
}
##########################################################

foreach my $tt (sort keys %breed){
    if ( $breed{$tt}[1] < 3 ) {
        my @lousy_data;
        push @lousy_data, "WARNING:\n";
        push @lousy_data,
            "Calculations missing due to lousy data (no of sires < 3)\n";
        print_tex_item( join( '\\\\', @lousy_data ), $texlist );

        print OUT '
            \begin{center}
            \begin{longtable}{|c|} 
                    \caption{' . " $title" . ' } \\\\  
                    \hline  
                    Data insufficient for calculations \\\\  
                    \hline  
            \end{longtable} 
            \end{center}' . "\n";
        next;
    }
    $csv ="PopulationReportTabel1_$tt.csv";
    open (OUT5, ">$csv") or die "Problems opening file $csv: $!\n";
    print OUT '
        \begin{center}
        \begin{longtable}{ |' . "$tabalign" . ' |' . "$tabalign" . ' |'
                              . "$tabalign" . ' |' . "$tabalign" . ' |'
                              . "$tabalign" . ' |' . "$tabalign" . ' |'
                              . "$tabalign" . ' |' . "$tabalign" . ' | }
        \caption{' . " $title" . '} \\\\
        \hline
        Year& \multicolumn{3}{|' . "$tabalign"
                                 . '|}{sires}& \multicolumn{3}{|'
                                 . "$tabalign"
                                 . '|}{dams} & Number of animals\\\\
        \hline  
        & services & births & select & services & births & select & born \\\\'
        . "\n"
        . '\hline
        \endfirsthead
      
        \caption*{\textit{Continue...}} \\\\
        \hline
        Year& \multicolumn{3}{|' . "$tabalign"
            . '|}{sires}& \multicolumn{3}{|'
            . "$tabalign"
            . '|}{dams} & Number of animals \\\\
        \hline
        & services & births & select & services & births & select & born \\\\'
        . "\n" . '
        \hline
        \endhead ';

    print OUT5 '"Year",' . '"services",' . '"births",' . '"offspr sel",'
        . '"services",' . '"births",' . '"offspr sel"' . '"number born"' . "\n";
    foreach my $ttt ( sort keys %hash ) {
        if ( "$hash{$ttt}{sire}[3]" eq "$tt" ) {
            my $bbb = '-';
            $bbb = $hash{$ttt}{dam}[6] if $hash{$ttt}{dam}[6];
            $bbb = $hash{$ttt}{sire}[6] if $bbb = '-';
            print OUT ''
                . "$hash{$ttt}{sire}[4]" . '  & '
                . "$hash{$ttt}{sire}[0]" . '  & '
                . "$hash{$ttt}{sire}[1]" . '  & '
                . "$hash{$ttt}{sire}[2]" . '  & '
                . "$hash{$ttt}{dam}[0]"  . '  & '
                . "$hash{$ttt}{dam}[1]"  . '  & '
                . "$hash{$ttt}{dam}[2]"  . '  & '
                . "$bbb" . '  \\\\' . " \n";
            print OUT5 '"'
                . "$hash{$ttt}{sire}[4]" . '","'
                . "$hash{$ttt}{sire}[0]" . '","'
                . "$hash{$ttt}{sire}[1]" . '","'
                . "$hash{$ttt}{sire}[2]" . '","'
                . "$hash{$ttt}{dam}[0]"  . '","'
                . "$hash{$ttt}{dam}[1]"  . '","'
                . "$hash{$ttt}{dam}[2]"  . '","'
                . "$bbb" . '"' . " \n";
        }
    }
    print OUT '\hline 
    \end{longtable}'."\n";
    print OUT '\end{center}'."\n";
    close OUT5;
}

### Create report.2BOB ####
$title =
    'Age distribution of males in reproduction by year of birth of their offspring';
$sql = "SELECT  breed, year AS Year, parent AS Parent,
                age AS Age, number as Number
        FROM tmp1_age
        WHERE age notnull
        ORDER BY breed, year";

$sql_ref = $apiis->DataBase->sys_sql($sql);
$apiis->check_status;
$sql_ref->check_status( die => 'ERR' );
$tabalign = 'c';
%hash     = ();
%breed    = ();
my ( %hash1, %hash2, @age, @age1, %agg );
while ( my $line_ref = $sql_ref->handle->fetch ) {
    my @line = @$line_ref;
    my ( $breed, $year, $parent, $age, $number ) = @line;

    my $aa = $parent;
    $aa =~ s/ //g;
    $agg{$age}                            = 1;
    $hash{ $breed . '|' . $year }{$aa}[0] = $breed;
    $hash{ $breed . '|' . $year }{$aa}[1] = $year;
    $hash{ $breed . '|' . $year }{$aa}[2] = $parent;
    $hash{ $breed . '|' . $year }{$aa}[3] = $age;
    $hash{ $breed . '|' . $year }{$aa}[4] = $number;
    $breed{$breed}                        = $breed;
    $breed{$breed}[2]++ if $aa eq 'sire' and $year > 0;
    $breed{$breed}[3]++ if $aa eq 'dam'  and $year > 0;
    $hash1{ $breed . '|' . $year }{ $aa . '|' . $age }[0] = $breed;
    $hash1{ $breed . '|' . $year }{ $aa . '|' . $age }[1] = $year;
    $hash1{ $breed . '|' . $year }{ $aa . '|' . $age }[2] = $parent;
    $hash1{ $breed . '|' . $year }{ $aa . '|' . $age }[3] = $age;
    $hash1{ $breed . '|' . $year }{ $aa . '|' . $age }[4] = $number;

    $hash2{$breed}{ $aa . '|' . $age }[0] = $breed  if $age < 17;
    $hash2{$breed}{ $aa . '|' . $age }[1] = 'Total' if $age < 17;
    $hash2{$breed}{ $aa . '|' . $age }[2] = $parent if $age < 17;
    $hash2{$breed}{ $aa . '|' . $age }[3] = $age    if $age < 17;
    $hash2{$breed}{ $aa . '|' . $age }[4] += $number if $age < 17;
    if ( $age == 17 ) {
        $hash2{$breed}{ $aa . '|' . $age }[0] = $breed;
        $hash2{$breed}{ $aa . '|' . $age }[1] = 'Total';
        $hash2{$breed}{ $aa . '|' . $age }[2] = $parent;
        $hash2{$breed}{ $aa . '|' . $age }[3] = $age;
        if ( !$hash2{$breed}{ $aa . '|' . $age }[4] ) {
            $hash2{$breed}{ $aa . '|' . $age }[4] = $number;
        }
        else {
            $hash2{$breed}{ $aa . '|' . $age }[4] =
                ( $hash2{$breed}{ $aa . '|' . $age }[4] + $number ) / 2;
        }
    }
}

foreach my $tt ( sort keys %hash2 ) {
    $hash2{$tt}{ 'sire' . '|' . '17' }[4] =
        sprintf( "%.1f", $hash2{$tt}{ 'sire' . '|' . '17' }[4] );
    $hash2{$tt}{ 'dam' . '|' . '17' }[4] =
        sprintf( "%.1f", $hash2{$tt}{ 'dam' . '|' . '17' }[4] );
}

my $sland = 0;
my $dland = 0;
foreach my $ttt ( sort keys %breed ) {
    foreach my $tt ( sort keys %agg ) {
        $sland += length( $hash2{$ttt}{ 'sire' . '|' . $tt }[4] );    #number
        $dland += length( $hash2{$ttt}{ 'dam' . '|' . $tt }[4] );     #number
    }
}

my ( %nu2, %jr2, %nu3, %avg, $stmp, $dtmp );
my $sq11 = "SELECT distinct age
            FROM tmp1_age
            WHERE parent='sire' AND breed='$tt' AND age notnull
            ORDER BY age";

foreach my $tt ( sort keys %breed ) {
    next if $breed{$tt}[2] < 3;
    foreach my $ttt ( sort keys %hash ) {
        if ( $hash{$ttt}{sire}[0] eq $tt ) {    #breed
            my $ss2  = 'sire|' . "2";
            my $ss3  = 'sire|' . "3";
            my $ss17 = 'sire|' . "17";
            if ( $hash1{$ttt}{$ss2}[4] > 1 and $hash1{$ttt}{$ss3}[4] > 1 ) {
                $stmp     = $tt;
                $jr2{$tt} = $hash{$ttt}{sire}[1];
                $nu2{$tt} = $hash1{$ttt}{$ss2}[4];
                $nu3{$tt} = $hash1{$ttt}{$ss3}[4];
                $avg{$tt} = $hash1{$ttt}{$ss17}[4];
                last;
            }
        }
    }
    last if $jr2{$tt};
}

my ( %jr2f, %nu3f, %avgf );
my $sq12 = "SELECT distinct age
            FROM tmp1_age
            WHERE parent='dam' AND breed='$tt' AND age notnull
            ORDER BY age";

foreach my $tt ( sort keys %breed ) {
    next if $breed{$tt}[3] < 3;
    foreach my $ttt ( sort keys %hash ) {
        if ( $hash{$ttt}{dam}[0] eq $tt ) {    #breed
            my $ss2f  = 'dam|' . "2";
            my $ss3f  = 'dam|' . "3";
            my $ss17f = 'dam|' . "17";
            if ( $hash1{$ttt}{$ss2f}[4] > 1 and $hash1{$ttt}{$ss3f}[4] > 1 ) {
                $dtmp      = $tt;
                $jr2f{$tt} = $hash{$ttt}{dam}[1];
                $nu2f{$tt} = $hash1{$ttt}{$ss2f}[4];
                $nu3f{$tt} = $hash1{$ttt}{$ss3f}[4];
                $avgf{$tt} = $hash1{$ttt}{$ss17f}[4];
                last;
            }
        }
    }
    last if $jr2f{$tt};
}

$file = "$hd" . "Population_2.hd";
open( IN, $file ) or die "Problems opening $file: $!\n";
print OUT '\begin{landscape}' . "\n" if $sland > 40;
while (<IN>) {
    mychomp($_);
    print OUT "$_ \n";
}

print OUT '\begin{center}' . "\n" . '\textbf{For example:}';
print OUT sprintf ' For the %s breed in %s, %s two %s-old males were used in '
    . 'reproduction while %s three %s-old males were used. '
    . 'The average age of males that produced offspring '
    . 'during %s was %s %s.\\',
    $stmp, $jr2{$stmp}, $nu2{$stmp}, $opt_g, $nu3{$stmp}, $opt_g, $jr2{$stmp},
    $avg{$stmp}, $opt_g;
print OUT "\n" . '\end{center}' . "\n";

foreach my $tt (sort keys %breed){ 
    if ( $breed{$tt}[2] < 3 ) {
        my @lousy_data;
        push @lousy_data, "WARNING:\n";
        push @lousy_data,
            "Calculations missing due to lousy data (no of sires < 3)\n";
        print_tex_item( join( '\\\\', @lousy_data ), $texlist );

        print OUT '
            \begin{center}
            \begin{longtable}{|c|} 
                \caption{' . " $title" . ' } \\\\  
                \hline  
                Data insufficient for calculations \\\\  
                \hline  
            \end{longtable} 
            \end{center}' . "\n";
        next;
    }
  
    $csv = "PopulationReportTabel2_$tt.csv";
    open( OUT5, ">$csv" ) or die "Problems opening file $csv: $!\n";
    @age  = ();
    @age1 = ();
    $SI   = 0;
    $DA   = 0;
    print OUT '
        \begin{center}
        \begin{longtable}{ |c|';

    my $sq1 =
        "SELECT distinct age
        FROM tmp1_age
        WHERE parent='sire' AND breed='$tt' AND age notnull
        ORDER BY age";
    my $sql_ref1 = $apiis->DataBase->sys_sql($sq1);
    $apiis->check_status;
    $sql_ref1->check_status( die => 'ERR' );
    while ( my $line_ref = $sql_ref1->handle->fetch ) {
        my @line = @$line_ref;
        my ($ag1) = @line;
        $SI = $SI + 1;
        if ( $ag1 == 0 ) {
            push @age1, "\<1";
        }
        elsif ( $ag1 == 16 ) {
            push @age1, "\$\\ge\$ 16";
        }
        elsif ( $ag1 == 17 ) {
            push @age1, 'Avg';
        }
        else { push @age1, $ag1; }
        push @age, $ag1;
        print OUT " $tabalign" . ' | ';
    }

    print OUT '}
        \caption{' . " $title " . ' } \\\\
        \hline 
        Year& \multicolumn{' . " $SI"
        . ' }{|c|}{age of males in '
        . "$opt_g" . '}\\\\' . "\n"
        . '\hline' . "\n";

    print OUT5 '"year"';

    foreach my $ag (@age1) {
        print OUT '&' . " $ag";
        print OUT5 ',"' . "$ag" . '"';
    }

    print OUT5 "\n";
    print OUT '\\\\' . "\n" . '\hline' . "\n" . '\endfirsthead' . "\n" . '

    \caption*{\textit{Continue...}} \\\\
    \hline
    Year& \multicolumn{' . " $SI"
        . ' }{|c|}{age of males in '
        . "$opt_g" . '}\\\\' . "\n"
        . ' \hline' . "\n";

    foreach my $ag (@age1) {
        print OUT '&' . " $ag";
    }
    print OUT '\\\\'."\n".'\hline'."\n".'\endhead'."\n";

    foreach my $ttt ( sort keys %hash ) {
        if ( $hash{$ttt}{sire}[0] eq $tt ) {    #breed
            print OUT "$hash{$ttt}{sire}[1]";    #year
            print OUT5 '"' . "$hash{$ttt}{sire}[1]" . '"';
            foreach my $ag (@age) {
                my $ss = 'sire|' . "$ag";
                if ( $hash1{$ttt}{$ss}[3] == $ag ) {    #age
                    if ( $hash1{$ttt}{$ss}[4] ) {
                        print OUT ' & ' . "$hash1{$ttt}{$ss}[4]";        #number
                        print OUT5 ',"' . "$hash1{$ttt}{$ss}[4]" . '"';  #number
                    }
                    else {
                        print OUT ' & --';
                        print OUT5 ',"--"';
                    }
                }
                else {
                    print OUT ' & --';
                    print OUT5 ',"--"';
                }
            }
            print OUT '\\\\' . "\n";
            print OUT5 "\n";
        }
    }
    #######################################
    foreach my $ttt ( sort keys %hash2 ) {
        print OUT5 '"' . 'Total' . '"';
        print OUT 'Total';
        foreach my $tt (@age) {
            print OUT5 ',"' . "$hash2{$ttt}{'sire'.'|'.$tt}[4]" . '"';   #number
            print OUT ' & ' . "$hash2{$ttt}{'sire'.'|'.$tt}[4]";         #number
        }
    }
    print OUT '\\\\' . "\n";
    #######################################
    print OUT '\hline 
        \end{longtable}
        \end{center}';
    print OUT '\end{landscape}' . "\n" if $sland > 40;
    print OUT "\n";
}
close OUT5;

#### Create report.2BOBb:
$title =
    'Age distribution of females in reproduction by year of birth of their offspring';
print OUT '\begin{landscape}' . "\n" if $dland > 40;
print OUT "\n"
    . '\begin{center}' . "\n"
    . '\pagebreak[4]' . "\n"
    . '\textbf{For example:}';
print OUT sprintf
    ' For the %s breed in %s, %s two %s-old females were used in '
    . 'reproduction while %s three %s-old females were used. The avarage '
    . 'age of females that produced offspring during %s was %s %s.\\',
    $dtmp, $jr2f{$dtmp}, $nu2f{$dtmp}, $opt_g, $nu3f{$dtmp}, $opt_g,
    $jr2f{$dtmp}, $avgf{$dtmp}, $opt_g;
print OUT "\n" . '\end{center}' . "\n";

foreach my $tt ( sort keys %breed ) {
    if ( $breed{$tt}[3] < 3 ) {
        my @lousy_data;
        push @lousy_data, "WARNING:\n";
        push @lousy_data,
            "Calculations missing due to lousy data (no of dams < 3)\n";
        print_tex_item( join( '\\\\', @lousy_data ), $texlist );

        print OUT '
            \begin{center}
            \begin{longtable}{|c|} 
                    \caption{' . " $title" . ' } \\\\  
                    \hline  
                    Data insufficient for calculations \\\\  
                    \hline  
            \end{longtable} 
            \end{center}' . "\n";
        next;
    }
    $csv = "PopulationReportTabel3_$tt.csv";
    open( OUT5, ">$csv" ) or die "Problems opening file $csv: $!\n";
    $SI   = 0;
    $DA   = 0;
    @age  = ();
    @age1 = ();
    print OUT '
        \begin{center}
        \begin{longtable}{ |c|';
    my $sq1 =
        "SELECT distinct age
        FROM tmp1_age
        WHERE parent='dam' AND breed='$tt' AND age notnull
        ORDER BY age";

    my $sql_ref1 = $apiis->DataBase->sys_sql($sq1);
    $apiis->check_status;
    $sql_ref1->check_status( die => 'ERR' );
    while ( my $line_ref = $sql_ref1->handle->fetch ) {
        my @line = @$line_ref;
        my ($ag1) = @line;
        $SI = $SI + 1;
        if ( $ag1 == 0 ) {
            push @age1, '<1';
        }
        elsif ( $ag1 == 16 ) {
            push @age1, "\$\\ge\$ 16";
        }
        elsif ( $ag1 == 17 ) {
            push @age1, 'Avg';
        }
        else { push @age1, $ag1; }
        push @age, $ag1;
        print OUT " $tabalign" . ' | ';
    }
    print OUT '}
        \caption{' . " $title " . ' } \\\\
        \hline 
        Year& \multicolumn{' . " $SI"
        . ' }{|c|}{age of females in '
        . "$opt_g" . '}\\\\' . "\n"
        . '\hline' . "\n";

    print OUT5 '"Year"';
    foreach my $ag (@age1) {
        print OUT '&' . " $ag";
        print OUT5 ',"' . "$ag" . '"';
    }
    print OUT5 "\n";
    print OUT '\\\\' . "\n" . '
        \hline' . "\n" . '\endfirsthead' . "\n" . '
        \caption*{\textit{Continue...}} \\\\
          \hline
            Year& \multicolumn{' . " $SI"
        . ' }{|c|}{age of females in '
        . "$opt_g" . '}\\\\' . "\n"
        . ' \hline' . "\n";

    foreach my $ag (@age1) {
        print OUT '&' . " $ag";
    }
    print OUT '\\\\' . "\n" . '\hline' . "\n" . '\endhead' . "\n";

    foreach my $ttt ( sort keys %hash ) {
        if ( $hash{$ttt}{dam}[0] eq $tt ) {
            print OUT "$hash{$ttt}{dam}[1]";
            print OUT5 ',"' . "$hash{$ttt}{dam}[1]" . '"';
            foreach my $ag (@age) {
                my $ss = 'dam|' . "$ag";
                if ( $hash1{$ttt}{$ss}[3] == $ag ) {
                    if ( $hash1{$ttt}{$ss}[4] ) {
                        print OUT ' & ' . "$hash1{$ttt}{$ss}[4]";
                        print OUT5 ',"' . "$hash1{$ttt}{$ss}[4]" . '"';
                    }
                    else {
                        print OUT ' & --';
                        print OUT5 ',"--"';
                    }
                }
                else {
                    print OUT ' & --';
                    print OUT5 ',"--"';
                }
            }
            print OUT '\\\\' . "\n";
            print OUT5 "\n";
        }
    }

    foreach my $ttt ( sort keys %hash2 ) {
        print OUT5 '"' . 'Total' . '"';
        print OUT 'Total';
        foreach my $tt (@age) {
            print OUT5 ',"' . "$hash2{$ttt}{'dam'.'|'.$tt}[4]" . '"';    #number
            print OUT ' & ' . "$hash2{$ttt}{'dam'.'|'.$tt}[4]";          #number
        }
    }
    print OUT '\\\\' . "\n";
    print OUT '\hline 
        \end{longtable}
        \end{center}' . "\n";
    print OUT '\end{landscape}' . "\n" if $dland > 40;
}
close OUT5;

#### Create report.4:
$title = 'Distribution of females by parity number';
$sql   = "SELECT breed, year, parity, count(dam)
    FROM tmp1_parity
    WHERE parity notnull
    GROUP BY breed, year, parity";
$sql_ref = $apiis->DataBase->sys_sql($sql);
$apiis->check_status;
$sql_ref->check_status( die => 'ERR' );
%breed = %hash = %hash1 = %clear = ();
my ( @parity, @parity1 );
while ( my $line_ref = $sql_ref->handle->fetch ) {
    my @line = @$line_ref;
    my ( $breed1, $year, $parity, $number ) = @line;
    my $aa = $parent;
    $aa =~ s/ //g;
    $hash{ $breed1 . '|' . $year . '|' . $parity }[0] = $breed1;
    $hash{ $breed1 . '|' . $year . '|' . $parity }[1] = 'Total';
    $hash{ $breed1 . '|' . $year . '|' . $parity }[2] = $parity;
    $hash{ $breed1 . '|' . $year . '|' . $parity }[3] = $number;

    $hash{ $breed1 . '|' . 'Total' . '|' . $parity }[0] = $breed1;
    $hash{ $breed1 . '|' . 'Total' . '|' . $parity }[1] = $year;
    $hash{ $breed1 . '|' . 'Total' . '|' . $parity }[2] = $parity;
    $hash{ $breed1 . '|' . 'Total' . '|' . $parity }[3] += $number;

    $breed{$breed1} = $breed1;
    $breed{$breed1}[4]++ if $parity;
    $hash1{ $breed1 . '|' . $year }[0] = $breed1;
    $hash1{ $breed1 . '|' . $year }[1] = $year;
    $hash1{ $breed1 . '|' . $year }[2] = $parity;
    $hash1{ $breed1 . '|' . $year }[3] = $number;

    $hash1{ $breed1 . '|' . 'Total' }[0] = $breed1;
    $hash1{ $breed1 . '|' . 'Total' }[1] = 'Total';
    $hash1{ $breed1 . '|' . 'Total' }[2] = $parity;
    $hash1{ $breed1 . '|' . 'Total' }[3] += $number;
}

my $land;
foreach my $tt ( sort keys %hash ) {
    my ( $a, $b, $c ) = split( '\|', $tt );
    if ( $b eq 'Total' ) {
        $land += length( $hash{$tt}[3] );    #number
    }
}

my $pn = 1;
my ( $jr, $jr2, $nm, $nm2, $tmp );
foreach my $tt ( sort keys %breed ) {
    next if $breed{$tt}[4] < 3;
    $sql =
        "SELECT distinct parity
        FROM tmp1_parity
        WHERE breed = '$tt'
        ORDER BY parity";
    $sql_ref = $apiis->DataBase->sys_sql($sql);
    $apiis->check_status;
    $sql_ref->check_status( die => 'ERR' );
    @parity  = ();
    @parity1 = ();
    while ( my $line_ref = $sql_ref->handle->fetch ) {
        my @line = @$line_ref;
        my ($parity) = @line;

        if ( $parity == 0 ) {
            push @parity1, "\<1";
        }
        elsif ( $parity == 16 ) {
            push @parity1, "\$\\ge\$ 16";
        }
        elsif ( $parity == 17 ) {
            push @parity1, 'Avg';
        }
        else {
            push @parity1, $parity;
        }
        push @parity, $parity;
    }
    if ( $pn == 1 ) {
        foreach my $ww ( sort keys %hash1 ) {
            if ( $hash1{$ww}[0] eq $tt ) {
                foreach my $kk (@parity) {
                    my $ss = $hash1{$ww}[0] . '|' . $hash1{$ww}[1] . '|' . $kk;
                    if ( $hash{$ss}[2] eq $kk ) {
                        if ( $kk == 2 and $hash{$ss}[3] > 1 ) {
                            $tmp = $tt;
                            $jr  = $hash1{$ww}[1];
                            $nm  = $hash{$ss}[3];
                            $pn  = 2;
                            last;
                        }
                    }
                }
                if ( $pn == 2 ) { last; }
            }
        }
        $pn = 2;
        if ( $pn == 2 ) {
            foreach my $ww ( sort keys %hash1 ) {
                if ( $hash1{$ww}[0] eq $tt ) {
                    foreach my $kk (@parity) {
                        my $ss =
                            $hash1{$ww}[0] . '|' . $hash1{$ww}[1] . '|' . $kk;
                        if ( $hash{$ss}[2] eq $kk ) {
                            ;
                            if ( $kk == 3 and $hash{$ss}[3] > 1 ) {
                                $jr2 = $hash1{$ww}[1];
                                $nm2 = $hash{$ss}[3];
                                $pn  = 3;
                                last;
                            }
                        }
                    }
                    if ( $pn == 3 ) { last; }
                }
            }
            $pn = 3;
        }
        last;
    }
}    #end of breed

$file = "$hd" . "Population_4.hd";
open( IN, $file ) or die "Problems opening $file: $!\n";
print OUT '\begin{landscape}' . "\n" if $land > 58;
while (<IN>) {
    mychomp($_);
    print OUT "$_ \n";
}

print OUT '\begin{center}' . "\n" . '
    \textbf{For example:}';
print OUT " For breed $tmp in $jr, $nm females were in their second parity "
    . "while in $jr2, $nm2 were in their third parity."
    . '\end{center}' . "\n";

foreach my $tt ( sort keys %breed ) {
    if ( $breed{$tt}[4] < 3 ) {
        my @lousy_data;
        push @lousy_data, "WARNING:\n";
        push @lousy_data,
            "Calculations missing due to lousy data (no of parity < 3)\n";
        print_tex_item( join( '\\\\', @lousy_data ), $texlist );

        print OUT '
            \begin{center}
            \begin{longtable}{|c|} 
                \caption{' . " $title" . ' } \\\\  
                \hline  
                Data insufficient for calculations \\\\  
                \hline  
            \end{longtable} 
            \end{center}' . "\n";
        next;
    }

    $csv = "PopulationReportTabel4_$tt.csv";
    open( OUT5, ">$csv" ) or die "Problems opening file $csv: $!\n";

    $SI = 0;
    print OUT "\n" . '
        \begin{center}
        \begin{longtable}{ |c|';
    foreach my $tt (@parity) {
        print OUT "$tabalign" . '|';
        $SI = $SI + 1;
    }
    print OUT '}
        \caption{' . " $title" . ' } \\\\
        \hline 
        Year& \multicolumn{' . " $SI"
        . '}{|c|}{parity number}\\\\' . "\n"
        . ' \hline';

    print OUT5 '"Year"';
    foreach my $ww (@parity1) {
        print OUT '&' . "$ww";
        print OUT5 ',"' . "$ww" . '"';
    }
    print OUT '\\\\' . "\n" . '\hline' . "\n" . '\endfirsthead' . "\n" . '
        \caption*{\textit{Continue...}} \\\\
          \hline
          Year& \multicolumn{' . " $SI"
        . '}{|c|}{parity number}\\\\' . "\n"
        . ' \hline';

    print OUT5 '"Year"';

    foreach my $ww (@parity1) {
        print OUT '&' . "$ww";
        print OUT5 ',"' . "$ww" . '"';
    }
    print OUT '\\\\' . "\n" . '\hline' . "\n" . '\endhead';
    print OUT5 "\n";

    foreach my $ww ( sort keys %hash1 ) {
        if ( $hash1{$ww}[0] eq $tt ) {
            print OUT "$hash1{$ww}[1]";
            print OUT5 '"' . "$hash1{$ww}[1]" . '"';
            foreach my $kk (@parity) {
                my $ss = $hash1{$ww}[0] . '|' . $hash1{$ww}[1] . '|' . $kk;
                if ( $hash{$ss}[2] eq $kk ) {
                    ;
                    print OUT '&' . "$hash{$ss}[3]";
                    print OUT5 ',"' . "$hash{$ss}[3]" . '"';
                }
                else {
                    print OUT '& --';
                    print OUT5 ',"--"';
                }
            }
            print OUT '\\\\' . "\n";
            print OUT5 "\n";
        }
    }
    print OUT '
            \hline 
        \end{longtable}
        \end{center}' . "\n";
    print OUT '\end{landscape}' . "\n" if $land > 58;
}    #end of foreach breed
close OUT5;

#### Create report.5:
$csv = "PopulationReportTabel5_$tt.csv";
open( OUT5, ">$csv" ) or die "Problems opening file $csv: $!\n";

$title = 'Generation interval and number of animals by '
    . 'year of birth for different selection paths';
$sql =
    "SELECT breed,year,ss,ssn,sd,sdn,ds,dsn,dd,ddn,sire,siren,dam,damn,pop,popn
    FROM tmp1_gen ORDER BY breed,year";
$sql_ref = $apiis->DataBase->sys_sql($sql);
$apiis->check_status;
$sql_ref->check_status( die => 'ERR' );

%breed=%hash=%hash1=%clear;
my ($vyear, $vss, $vssn, $vsd, $vsdn, $vds, $vdsn, $vdd,
    $vddn,  $vsi, $vsin, $vda, $vdan, $vpo, $vpon, @landsc );
while ( my $line_ref = $sql_ref->handle->fetch ) {
    my ($breed, $year, $ss,  $ssn,  $sd, $sdn, $ds,  $dsn,
        $dd,    $ddn,  $sir, $sirn, $da, $dan, $pop, $popn ) = @$line_ref;
    $breed{$breed} = $breed;
    $breed{$breed}[5]++ if $year;
    $hash{ $breed . '|' . $year }[0]  = $breed;
    $hash{ $breed . '|' . $year }[1]  = $year;
    $hash{ $breed . '|' . $year }[2]  = $ss;
    $hash{ $breed . '|' . $year }[3]  = $ssn;
    $hash{ $breed . '|' . $year }[4]  = $sd;
    $hash{ $breed . '|' . $year }[5]  = $sdn;
    $hash{ $breed . '|' . $year }[6]  = $ds;
    $hash{ $breed . '|' . $year }[7]  = $dsn;
    $hash{ $breed . '|' . $year }[8]  = $dd;
    $hash{ $breed . '|' . $year }[9]  = $ddn;
    $hash{ $breed . '|' . $year }[10] = $sir;
    $hash{ $breed . '|' . $year }[11] = $sirn;
    $hash{ $breed . '|' . $year }[12] = $da;
    $hash{ $breed . '|' . $year }[13] = $dan;
    $hash{ $breed . '|' . $year }[14] = $pop;
    $hash{ $breed . '|' . $year }[15] = $popn;

    $landsc[0]  = length($year) if length($year) > $landsc[0];
    $landsc[1]  = length($ss)   if length($ss) > $landsc[1];
    $landsc[2]  = length($ssn)  if length($ssn) > $landsc[2];
    $landsc[3]  = length($sd)   if length($sd) > $landsc[3];
    $landsc[4]  = length($sdn)  if length($sdn) > $landsc[4];
    $landsc[5]  = length($ds)   if length($ds) > $landsc[5];
    $landsc[6]  = length($dsn)  if length($dsn) > $landsc[6];
    $landsc[7]  = length($dd)   if length($dd) > $landsc[7];
    $landsc[8]  = length($ddn)  if length($ddn) > $landsc[8];
    $landsc[9]  = length($sir)  if length($sir) > $landsc[9];
    $landsc[10] = length($sirn) if length($sirn) > $landsc[10];
    $landsc[11] = length($da)   if length($da) > $landsc[11];
    $landsc[12] = length($dan)  if length($dan) > $landsc[12];
    $landsc[13] = length($pop)  if length($pop) > $landsc[13];
    $landsc[14] = length($popn) if length($popn) > $landsc[14];

    if ( !$hash{ $breed . '|' . $year }[2] ) {
        $hash{ $breed . '|' . $year }[2] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[3] ) {
        $hash{ $breed . '|' . $year }[3] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[4] ) {
        $hash{ $breed . '|' . $year }[4] = '-';
    }

    if ( !$hash{ $breed . '|' . $year }[5] ) {
        $hash{ $breed . '|' . $year }[5] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[6] ) {
        $hash{ $breed . '|' . $year }[6] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[7] ) {
        $hash{ $breed . '|' . $year }[7] = '-';
    }

    if ( !$hash{ $breed . '|' . $year }[8] ) {
        $hash{ $breed . '|' . $year }[8] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[9] ) {
        $hash{ $breed . '|' . $year }[9] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[10] ) {
        $hash{ $breed . '|' . $year }[10] = '-';
    }

    if ( !$hash{ $breed . '|' . $year }[11] ) {
        $hash{ $breed . '|' . $year }[11] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[12] ) {
        $hash{ $breed . '|' . $year }[12] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[13] ) {
        $hash{ $breed . '|' . $year }[13] = '-';
    }

    if ( !$hash{ $breed . '|' . $year }[14] ) {
        $hash{ $breed . '|' . $year }[14] = '-';
    }
    if ( !$hash{ $breed . '|' . $year }[15] ) {
        $hash{ $breed . '|' . $year }[15] = '-';
    }
}

$land = 0;
foreach my $tt (@landsc) {
    $land += $tt;
}

foreach my $tt ( sort keys %breed ) {
    next if $breed{$tt}[5] < 3;
    my ( $yr, $nu, $tmp );
    foreach my $ww ( sort keys %hash ) {
        if ( $hash{$ww}[0] eq $tt ) {
            if (    $hash{$ww}[3] > 5
                and $hash{$ww}[5] > 5
                and $hash{$ww}[7] > 5
                and $hash{$ww}[9] > 5 )
            {
                $vyear = $hash{$ww}[1];
                $vss   = $hash{$ww}[2];
                $vssn  = $hash{$ww}[3];
                $vsd   = $hash{$ww}[4];
                $vsdn  = $hash{$ww}[5];
                $vds   = $hash{$ww}[6];
                $vdsn  = $hash{$ww}[7];
                $vdd   = $hash{$ww}[8];
                $vddn  = $hash{$ww}[9];
                $vsi   = $hash{$ww}[10];
                $vsin  = $hash{$ww}[11];
                $vda   = $hash{$ww}[12];
                $vdan  = $hash{$ww}[13];
                $vpo   = $hash{$ww}[14];
                $vpon  = $hash{$ww}[15];
                $tmp   = $tt;
                last;
            }
        }
    }
    last if $vyear;
}    #end of breeds

$file = "$hd" . "Population_5.hd";
open( IN, $file ) or die "Problems opening $file: $!\n";
print OUT '\begin{landscape}' . "\n" if $land > 58;
while (<IN>) {
    mychomp($_);
    print OUT "$_ \n";
}

if ( !scalar %breed ) {
    my @lousy_data;
    push @lousy_data, "WARNING:\n";
    push @lousy_data, "Calculations missing due to missing breed data\n";
    print_tex_item( join( '\\\\', @lousy_data ), $texlist );

    print OUT '
        \begin{center}
        \begin{longtable}{|c|}
            \caption{' . " $title" . ' } \\\\
            \hline
            Data insufficient for calculations \\\\
            \hline
        \end{longtable}
        \end{center}' . "\n";
}
else {
    print OUT "\n" . '\textbf{For example:}';
    print OUT "  For the $tmp breed the Generation interval "
        . "(average age of parents when their selected offspring were born) "
        . "for the selection path between sire to son (ss) was $vss $opt_g "
        . "in $vyear. This values was calculated based on the avarage ages of "
        . "$vssn selected sons, born during $vyear. During the same year the "
        . "generation intervals for the sire to daughter (sd), dam to son (ds) "
        . "and dam to daughter (dd) selection paths were $vsd, $vds and "
        . "$vdd $opt_g, respectively. During $vyear, the generation interval "
        . "for the males was $vsi $opt_g and $vda $opt_g for the female born "
        . "during this year. The generation interval in $vyear for all four "
        . "selection paths together, or for the population in total (pop), "
        . "was $vpo $opt_g, based on the average age of parents of $vpon "
        . "selected offspring.\n";
}

foreach my $tt ( sort keys %breed ) {
    if ( $breed{$tt}[5] < 3 ) {
        my @lousy_data;
        push @lousy_data, "WARNING:\n";
        push @lousy_data,
            "Calculations missing due to lousy data (no of years < 3)\n";
        print_tex_item( join( '\\\\', @lousy_data ), $texlist );

        print OUT '
            \begin{center}
            \begin{longtable}{|c|} 
                \caption{' . " $title" . ' } \\\\  
                \hline  
                Data insufficient for calculations \\\\  
                \hline  
            \end{longtable} 
            \end{center}' . "\n";
        next;
    }

    print OUT "\n" . '
        \begin{center}
        \begin{longtable}{|'
            . "$tabalign" . '|' . "$tabalign" . '|'
            . "$tabalign" . '|' . "$tabalign" . '|'
            . "$tabalign" . '|' . "$tabalign" . '|'
            . "$tabalign" . '|' . "$tabalign" . '|'
            . "$tabalign" . '|' . "$tabalign" . '|'
            . "$tabalign" . '|' . "$tabalign" . '|'
            . "$tabalign" . '|' . "$tabalign" . '|'
            . "$tabalign" . '|}' . "\n";
    print OUT '
        \caption{' . " $title" . ' } \\\\' . "\n"
        . '\caption*{\textit{(ss=sire to son,Nss=number of selected males for '
        . 'ss,sd=sire to daughter,Nsd=number of females for sd,ms=dams to '
        . 'sons,Nms=number of males for ms,md=dams to daugthers and '
        . 'Nmd=number of females for md,male=avg age of sires,Nmale=number '
        . 'of sires where age is known,female=avg age of dams,Nmale=number '
        . 'of dams where age is known,pop=interval for the '
        . 'population,Npop=number of selected offspring)}} \\\\
        \hline 
        Year&\multicolumn{14}{|'
        . "$tabalign"
        . '|}{Generation interval and number of animal} \\\\' . "\n";
    print OUT '
        \hline
        &ss&Nss&sd&Nsd&ms&Nms&md&Nmd&male&Nmale&female&Nfemale&pop&Npop \\\\'
        . "\n";
    print OUT '\hline' . "\n" . '\endfirsthead';

    print OUT '  \caption*{\textit{Continue...}} \\\\
        \hline
        Year&\multicolumn{14}{|'
        . "$tabalign"
        . '|}{Generation interval and number of animal} \\\\' . "\n";
    print OUT '\hline
          &ss&Nss&sd&Nsd&ms&Nms&md&Nmd&male&Nmale&female&Nfemale&pop&Npop\\\\'
        . "\n";
    print OUT '\hline' . "\n" . '\endhead';

    print OUT5
        '"Year","sire-son","s-s-numb","sire-daughter","s-d-numb","mother-son",'
        . '"m-s-numb","mother-daughter","m-d-numb","sires","sires-numb",'
        . '"dams","dams-numb","population","pop-number"' . "\n";
    foreach my $ww ( sort keys %hash ) {
        if ( $hash{$ww}[0] eq $tt ) {
            print OUT "$hash{$ww}[1]" . '&'
                . "$hash{$ww}[2]" . '&'
                . "$hash{$ww}[3]" . '&'
                . "$hash{$ww}[4]" . '&'
                . "$hash{$ww}[5]" . '&'
                . "$hash{$ww}[6]" . '&'
                . "$hash{$ww}[7]" . '&'
                . "$hash{$ww}[8]" . '&'
                . "$hash{$ww}[9]" . '&'
                . "$hash{$ww}[10]" . '&'
                . "$hash{$ww}[11]" . '&'
                . "$hash{$ww}[12]" . '&'
                . "$hash{$ww}[13]" . '&'
                . "$hash{$ww}[14]" . '&'
                . "$hash{$ww}[15]" . '\\\\' . "\n";
            print OUT5 '"'
                . "$hash{$ww}[1]" . '","'
                . "$hash{$ww}[2]" . '","'
                . "$hash{$ww}[3]" . '","'
                . "$hash{$ww}[4]" . '","'
                . "$hash{$ww}[5]" . '","'
                . "$hash{$ww}[6]" . '","'
                . "$hash{$ww}[7]" . '","'
                . "$hash{$ww}[8]" . '","'
                . "$hash{$ww}[9]" . '","'
                . "$hash{$ww}[10]" . '","'
                . "$hash{$ww}[11]" . '","'
                . "$hash{$ww}[12]" . '","'
                . "$hash{$ww}[13]" . '","'
                . "$hash{$ww}[14]" . '","'
                . "$hash{$ww}[15]" . '"' . "\n";
        }
    }
    print OUT '
            \hline
        \end{longtable}
        \end{center}' . "\n";
    print OUT '\end{landscape}' . "\n" if $land > 58;
}
close OUT5;

#### Create report.6:
$title   = 'The maximum and average number of family sizes';
$sql     = "select distinct breed from tmp1_family";
$sql_ref = $apiis->DataBase->sys_sql($sql);
$apiis->check_status;
$sql_ref->check_status( die => 'ERR' );
%breed = %hash = %hash1 = %clear;
while ( my $line_ref = $sql_ref->handle->fetch ) {
    my @line = @$line_ref;
    my ($breed) = @line;
    $breed{$breed} = $breed;
}
my $lscp=1;

foreach my $tt ( sort keys %breed ) {
    $sql =
        "SELECT a_max_sire, a_max_dam, s_max_sire, s_max_dam,
                ss_max_sire, ss_max_dam, sd_max_sire, sd_max_dam
         FROM tmp1_family
         WHERE breed='$tt' AND year = '9999'";
    $sql_ref = $apiis->DataBase->sys_sql($sql);
    $apiis->check_status;
    $sql_ref->check_status( die => 'ERR' );
    while ( my $line_ref = $sql_ref->handle->fetch ) {
        my @line = @$line_ref;
        $lscp = 2 if ( length( $line[0] ) + length( $line[2] ) +
                       length( $line[4] ) + length( $line[6] ) ) > 15;
        $lscp = 2 if ( length( $line[1] ) + length( $line[3] ) +
                       length( $line[5] ) + length( $line[7] ) ) > 15;
    }
}

$file = "$hd" . "Population_6.hd";
open( IN, $file ) or die "Problems opening $file: $!\n";
print OUT '\begin{landscape}' . "\n" if $lscp == 2;
while (<IN>) {
    mychomp($_);
    print OUT "$_ \n";
}

foreach my $tt ( sort keys %breed ) {
    $csv = "PopulationReportTabel6_$tt.csv";
    open( OUT5, ">$csv" ) or die "Problems opening file $csv: $!\n";
    print OUT '
        \begin{center}
        \begin{longtable}{|c|c|c|c|c|c|c|c|c|c|c|c|c|c|c|c|c|}
            \caption{' . "$title" . ' } \\\\
            \hline' . "\n";
    print OUT ' &\multicolumn{4}{|c|}{All offspring}&\multicolumn{4}{|c|}'
        . '{Selected offspring}&\multicolumn{4}{|c|}{Selected sons}&'
        . '\multicolumn{4}{|c|}{Selected daughters} \\\\' . "\n";
    print OUT '\hline' . "\n";
    print OUT ' &\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}'
        . '&\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}'
        . '&\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}'
        . '&\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}\\\\' . "\n";
    print OUT5
        '#,,All offspring,,,,,Selected offspring,,,,,Selected sons,,,Selected '
        . "daughters\n";
    print OUT5 '#,,sires,,dams,,sires,,dams,,sires,,dams,,sires,,dams' . "\n";
    print OUT5
        '#Year,max,avg,max,avg,max,avg,max,avg,max,avg,max,avg,max,avg,max,avg'
        . "\n";
    print OUT '\hline
        Year & max & avg & max & avg
        & max & avg & max & avg
        & max & avg & max & avg
        & max & avg & max & avg \\\\' . "\n";
    print OUT '\hline ' . "\n";
    print OUT '  \endfirsthead  \caption*{\textit{Continue...}} \\\\' . "\n";
    print OUT '\hline' . "\n";
    print OUT ' &\multicolumn{4}{|c|}{All offspring}&'
        . '\multicolumn{4}{|c|}{Selected offspring}&'
        . '\multicolumn{4}{|c|}{Selected sons}&\multicolumn{4}{|c|}'
        . '{Selected daughters} \\\\' . "\n";
    print OUT '\hline' . "\n";
    print OUT ' &\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}'
        . '&\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}'
        . '&\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}'
        . '&\multicolumn{2}{|c|}{sires}&\multicolumn{2}{|c|}{dams}\\\\' . "\n";
    print OUT '\hline
       Year & max & avg & max & avg
       & max & avg & max & avg
       & max & avg & max & avg
       & max & avg & max & avg \\\\' . "\n";
    print OUT '\hline \\endhead' . "\n";

    $sql =
        "SELECT year, a_max_sire, a_avg_sire, a_max_dam, a_avg_dam, s_max_sire,
                s_avg_sire, s_max_dam, s_avg_dam, ss_max_sire, ss_avg_sire,
                ss_max_dam, ss_avg_dam, sd_max_sire, sd_avg_sire, sd_max_dam,
                sd_avg_dam
         FROM tmp1_family
         WHERE breed='$tt' ORDER BY year";
    $sql_ref = $apiis->DataBase->sys_sql($sql);
    $apiis->check_status;
    $sql_ref->check_status( die => 'ERR' );
    while ( my $line_ref = $sql_ref->handle->fetch ) {
        my @line = @$line_ref;
        if ( $line[0] eq '9999' ) { $line[0] = 'Total'; }
        print OUT "$line[0]";
        print OUT5 "$line[0]";
        for ( $i = 1; $i <= $#line; $i++ ) {
            $line[$i] = '-' if !$line[$i];
            print OUT " & $line[$i]";
            print OUT5 ",$line[$i]";
        }
        print OUT '\\\\' . "\n";
        print OUT5 "\n";
    }
    print OUT '\hline' . "\n";
    print OUT '\end{longtable} 
        \end{center}' . "\n";
    print OUT '\end{landscape}' . "\n\n" if $lscp == 2;
    close OUT5;
}

# Wunder gibt es immer wieder ... (28.5.2014 - heli):
if ( 1 == 2 ) {
    foreach my $tt ( sort keys %breed ) {
        print OUT '
  \begin{table}[ht]
  \centering{
  \caption{' . "$title" . ' }
  \begin{tabular}{|'
            . "$tabalign" . '|'
            . "$tabalign" . '|'
            . "$tabalign" . '|'
            . "$tabalign" . '|'
            . "$tabalign" . '|'
            . "$tabalign" . '|'
            . "$tabalign" . '| }
  \hline' . "\n";
        print OUT
            '  &\multicolumn{3}{|c|}{sires}&\multicolumn{3}{|c|}{dams} \\\\'
            . "\n";
        print OUT '\hline
  offspring & min & max & avg & min & max & avg \\\\' . "\n";
        print OUT '\hline
  All offspring & ';
        $sql =
            "select min(count) as x from tmp1_family_all where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );

        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_all where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_all where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select min(count) as x from tmp1_family_all where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_all where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_all where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT '\\\\' . "\n";
        print OUT 'Selected offspring & ';
        $sql =
            "select min(count) as x from tmp1_family_sel where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_sel where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_sel where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select min(count) as x from tmp1_family_sel where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_sel where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_sel where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT '\\\\' . "\n";
        print OUT 'Selected sons  & ';
        $sql =
            "select min(count) as x from tmp1_family_sel_s where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_sel_s where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_sel_s where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select min(count) as x from tmp1_family_sel_s where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_sel_s where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_sel_s where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT '\\\\' . "\n";
        print OUT 'Selected daughters & ';
        $sql =
            "select min(count) as x from tmp1_family_sel_d where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_sel_d where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_sel_d where parent='sire' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select min(count) as x from tmp1_family_sel_d where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select max(count) as x from tmp1_family_sel_d where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT ' & ';
        $sql =
            "select round(avg(count),1) as x from tmp1_family_sel_d where parent='dam' and breed='$tt'";
        $sql_ref = $apiis->DataBase->sys_sql($sql);
        $apiis->check_status;
        $sql_ref->check_status( die => 'ERR' );
        while ( my $line_ref = $sql_ref->handle->fetch ) {
            my @line = @$line_ref;
            my ($x) = @line;
            $x = '-' if !$x;
            print OUT "$x";
        }
        print OUT '\\\\' . "\n";
        print OUT '\hline' . "\n" . '
\end{tabular}
}
' . "\n";
        #.'\end{center}'.
        print OUT '\end{table}';
    }
}    #end if 1 == 2

# new_tabel:
close OUT;
print "$opt_b\n";
my $comm;
$comm = new_tabel($opt_b);
# end of new_tabel

open( OUT, ">>$outputfile" ) or die "Problems opening file $outputfile: $!\n";
print OUT "$comm" . '\\\\' . "\n" if $comm;

print OUT '
\end{document}' . "\n";

close OUT;

system("latex $outputfile");
system("latex $outputfile");
system("latex $outputfile");
system("dvips -q -f $output.dvi -o $output.ps");
system("ps2pdfwr $output.ps $output.pdf");

system("rm -f $output.dvi");
system("rm -f $output.aux");
system("rm -f $output.log");
system("rm -f $output.lot");
system("rm -f $output.toc");

unlink keys %delfiles;
$apiis->DataBase->disconnect;
exit;

sub new_tabel {
    my $breed = shift;
    my $sine  = '=';

    my $outputfile = "Population-$opt_b.tex";
    open( OUT, ">>$outputfile" )
        or die "Problems opening file $outputfile: $!\n";

    my ( %hash1, %calc, %calc1, %hash3, %breed, $err );
    %hash2 = ();
    my $sql2 =
        "SELECT breed, parent, count(*) AS number, round(avg(count),0),
                round(stddev(count),1)
        FROM tmp1_family_all
        WHERE breed $sine '$breed'
        GROUP BY breed,parent
        ORDER BY breed,parent";
    my $sql =
        "SELECT a.breed,a.id_nr,a.parent,a.count,b.ext_animal
        FROM tmp1_family_all a,
            (SELECT distinct on (db_animal) ext_animal,db_animal
            FROM transfer) b
        WHERE  a.id_nr=b.db_animal AND breed $sine '$breed'
        ORDER BY a.breed,a.parent,a.count desc";
    # read family_all table
    my $sql_ref = $apiis->DataBase->sys_sql($sql2);
    $sql_ref->check_status( die => 'ERR' );

    while ( my $line_ref = $sql_ref->handle->fetch ) {
        my @line = @$line_ref;
        my ( $breed, $parent, $number, $avg, $std ) = @line;
        $calc1{ $breed . '|' . $parent }[0]  = $avg;
        $calc1{ $breed . '|' . $parent }[1]  = $std;
        $calc1{ $breed . '|' . $parent }[11] = $std;
        $calc1{ $breed . '|' . $parent }[2]  = 0;            #for max count
        $calc1{ $breed . '|' . $parent }[3]  = 999999999;    #for min count
        $calc1{ $breed . '|' . $parent }[4]  = 0;            #for max levels
        $calc1{ $breed . '|' . $parent }[5]  = 999999999;    #for min levels

        if ( $calc1{ $breed . '|' . $parent }[1] and $parent eq 'sire' ) {
            $calc1{ $breed . '|' . $parent }[1] =
                ( $calc1{ $breed . '|' . $parent }[1] * 3 )
                ;    #3 stddev from mean for sires
        }
        if ( $calc1{ $breed . '|' . $parent }[1] and $parent eq 'dam' ) {
            $calc1{ $breed . '|' . $parent }[1] =
                ( $calc1{ $breed . '|' . $parent }[1] * 4 )
                ;    #4 stddev from mean for dams
        }
    }

    $err = 'Can not determine the Sire and Dam with the most Progeny '
        . 'in the Population. No data available' if scalar(%calc1) == 0;
    return ($err) if scalar(%calc1) == 0;

    $sql_ref = $apiis->DataBase->sys_sql($sql);
    $sql_ref->check_status( die => 'ERR' );
    my $yy;

    while ( my $line_ref = $sql_ref->handle->fetch ) {
        my @line = @$line_ref;
        my ( $breed, $id_nr, $parent, $count, $id ) = @line;
        $id =~ s/ /-/g;
        $breed{$breed}[0]++ if $parent eq 'dam';
        $breed{$breed}[1]++ if $parent eq 'sire';
        $hash1{ $breed . '|' . $id_nr }[0]  = $breed;
        $hash1{ $breed . '|' . $id_nr }[1]  = $parent;
        $hash1{ $breed . '|' . $id_nr }[2]  = $count;
        $calc1{ $breed . '|' . $parent }[2] = $count
            if $count > $calc1{ $breed . '|' . $parent }[2];    #max
        $calc1{ $breed . '|' . $parent }[3] = $count
            if $count < $calc1{ $breed . '|' . $parent }[3];    #min

        $yy++;
        $hash2{ $breed . '|' . $parent }[0]++;

        $hash3{$yy}[0] = $id_nr;
        $hash3{$yy}[1] = $breed;
        $hash3{$yy}[2] = $parent;
        $hash3{$yy}[3] = $hash2{ $breed . '|' . $parent }[0];
        $hash3{$yy}[4] = $count;
        $hash3{$yy}[5] = $id;

    }

    $err = 'Can not determine the Sire and Dam with the most Progeny in the '
        . 'Population. No data available' if scalar(%hash1) == 0;

    #if there are less than 3 sires or 3 dams we can not plot the data
    my $i;
    foreach my $tt ( sort keys %breed ) {
        $err = 'Can not determine the Sire and Dam with the most Progeny in '
            . 'the Population. No data available'
            if $breed{$tt}[0] < 3 or $breed{$tt}[1] < 3;
        return ($err) if $breed{$tt}[0] < 3 or $breed{$tt}[1] < 3;
    }

    foreach my $tt ( sort keys %hash1 ) {

        for (
            $i = $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[3];
            $i <= ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]
                    + ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[1] ) );
            $i++
            )
        {

            if ( $hash1{$tt}[1] eq 'sire' ) {
                if ((   $hash1{$tt}[2] >= (
                            ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[3])
                            + ( $i - 1 ))
                    )
                    and (
                        $hash1{$tt}[2] < (
                            ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[3])
                            + ($i))
                    )
                    )
                {
                    $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[$i]++;
                }
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4] = $i
                    if $i > $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4]
                ;    #max levels
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5] = $i
                    if $i < $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5]
                ;    #min levels

            }
            elsif ( $hash1{$tt}[1] eq 'dam' ) {
                if ((   $hash1{$tt}[2] >= (
                            ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[3])
                            + ( $i - 1 ))
                    )
                    and (
                        $hash1{$tt}[2] < (
                            ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[3])
                            + ($i))
                    )
                    )
                {
                    $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[$i]++;
                }

                # max levels:
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4] = $i
                    if $i > $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4];
                # min levels:
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5] = $i
                    if $i < $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5];
            }
        }

        if ( $hash1{$tt}[1] eq 'sire' ) {
            if ($hash1{$tt}[2] > (
                    $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]
                    + ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[1] )))
            {
                $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]++;
            }
        }
        elsif ( $hash1{$tt}[1] eq 'dam' ) {
            if ($hash1{$tt}[2] > (
                    $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]
                    + ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[1] )))
            {
                $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]++;
            }
        }
        else { }
    }

    foreach my $tt ( sort keys %calc ) {
        my ( $bb1, $pp1 ) = split( '\|', $tt );

        my $file  = $bb1 . $pp1 . '_Gnuplot.txt';
        my $rfile = 'PopulationReportHist_' . $bb1 . '_' . $pp1 . '_all.csv';
        open( OUT1,  ">$file" )  or die "Can not open $file: $!\n";
        open( ROUT1, ">$rfile" ) or die "Can not open $rfile: $!\n";

        my $file2 = $bb1 . $pp1 . '_Gnuplot';
        open( OUT2, ">$file2" ) or die "Can not open $file2: $!\n";

        my $file3 = $bb1 . $pp1 . '_Gnuplot_p';
        open( OUT3, ">$file3" ) or die "Can not open $file3: $!\n";

        my $pp2;
        my $pp3;
        if ( $pp1 eq 'sire' ) {
            $pp2 = 'Sire';
            $pp3 = 'Sires';
        }
        else {
            $pp2 = 'Dam';
            $pp3 = 'Dams';
        }

        print OUT '
            \begin{figure}[h]
            \begin{center}{
            \caption{' . "$pp3" . ' with the most Progeny in the Population}' . '
              %%\begin{flushleft}
              \includegraphics[scale=.9]{./' . "$file3" . '.ps}
              %%\end{flushleft}
              }\end{center}
              \end{figure}
              ' . "\n";
        $delfiles{ "$file3" . '.ps' } = 1;

        print OUT3 'set terminal postscript
set output "' . "$file3" . '.ps"
set title "' . "$pp3" . ' with the most Progeny in the Population"
set datafile missing "-"
set style data histogram
set style histogram cluster gap 1 title offset 2,0.25
set style fill solid noborder
set ytics font "Times,11"
set grid y
set auto y
set ylabel "Number of Progeny per ' . "$pp2" . '" font "Times-Italic,14"
set xlabel "ID-numbers of 30 ' . "$pp3"
            . ' with the most Progeny" font "Times-Italic,14" offset  0,-5
set xtics nomirror rotate by -70 font "Times,11"
set bmargin 10
set rmargin 6
plot "' . "$bb1" . "$pp1" . '_Gnuplot_p.txt" using 2:xtic(1) notitle';

        print OUT '
            \begin{figure}[h]
            \begin{center}{
            \caption{Number of Progeny per ' . "$pp2" . ' }' . '
              %%\begin{flushleft}
              \includegraphics[scale=.9]{./' . "$file2" . '.ps}
              %%\end{flushleft}
              }\end{center}
              \end{figure}
              ' . "\n";
        $delfiles{ "$file2" . '.ps' } = 1;

        print OUT2 'set terminal postscript
set output "' . "$file2" . '.ps"
set title "Number of Progeny per ' . "$pp2" . ' breed
set datafile missing "-"
set style data histogram
set style histogram cluster gap 1 title offset 2,0.25
set style fill solid noborder
unset xtics
set ytics font "Times,11"
set grid y
set auto y
set ylabel "Number of ' . "$pp3" . '" font "Times-Italic,14"
set xlabel "Number of Progeny per ' . "$pp2"
            . '\n (note: Min: '
            . "$calc1{$tt}[3]"
            . ',Avg: '
            . "$calc1{$tt}[0]"
            . ',Std: .'
            . "$calc1{$tt}[11]"
            . ',Max: '
            . "$calc1{$tt}[2]"
            . ')" font "Times-Italic,14"
set bmargin 5
set xtics (';

        my $ry2;
        if ( $calc1{$tt}[4] > 30 ) {
            my $ry = round( $calc1{$tt}[4] / 30 );
            for ( $i = $ry; $i < $calc1{$tt}[4]; $i += $ry ) {
                $ry2 = $i - 1;
                print OUT2 '"' . "$i" . '" ' . "$ry2" . ',';
            }
            $ry2 = $calc1{$tt}[4];
            print OUT2 '">' . "$calc1{$tt}[4]" . '" ' . "$ry2";
            print OUT2 ') rotate by -45 font "Times,11"' . "\n";
        }
        else {

            for ( $i = $calc1{$tt}[5]; $i <= $calc1{$tt}[4]; $i++ ) {
                $ry2 = $i - 1;
                print OUT2 '"' . "$i" . '" ' . "$ry2" . ',';
            }
            $ry2 = $calc1{$tt}[4];
            print OUT2 '">' . "$calc1{$tt}[4]" . '" ' . "$ry2";
            print OUT2 ') rotate by -45 font "Times,11"' . "\n";
        }

        print OUT2 'plot "' . "$file" . '" using 2 notitle';

        if ( $pp1 eq 'sire' ) {
            for ( $i = $calc1{$tt}[5]; $i <= $calc1{$tt}[4]; $i++ ) {
                if ( !$calc{$tt}[$i] ) {
                    $calc{$tt}[$i] = 0;
                }
                my $kk = ($i);
                print ROUT1"$kk,$calc{$tt}[$i]\n";
                $kk = pack( "A10", $kk );
                $calc{$tt}[$i] = sprintf( "%10d", $calc{$tt}[$i] );
                print OUT1"$kk$calc{$tt}[$i]\n";
            }

            print ROUT1">$calc1{$tt}[4],$calc{$tt}[0]\n";
            $calc1{$tt}[4] = pack( "A9", $calc1{$tt}[4] ) if $calc1{$tt}[4];
            $calc{$tt}[0] = sprintf( "%10d", $calc{$tt}[0] ) if $calc{$tt}[0];
            print OUT1">$calc1{$tt}[4]$calc{$tt}[0]\n";

        }
        elsif ( $pp1 eq 'dam' ) {
            for ( $i = $calc1{$tt}[5]; $i <= $calc1{$tt}[4]; $i++ ) {
                if ( !$calc{$tt}[$i] ) {
                    $calc{$tt}[$i] = 0;
                }
                my $kk = ($i);
                print ROUT1"$kk,$calc{$tt}[$i]\n";
                $kk = pack( "A10", $kk );
                $calc{$tt}[$i] = sprintf( "%10d", $calc{$tt}[$i] );
                #    print "$bb1,$pp1,$kk,$calc{$tt}[$i]\n";
                print OUT1"$kk$calc{$tt}[$i]\n";
            }

            print ROUT1">$calc1{$tt}[4],$calc{$tt}[0]\n";
            $calc1{$tt}[4] = pack( "A9", $calc1{$tt}[4] ) if $calc1{$tt}[4];
            $calc{$tt}[0] = sprintf( "%10d", $calc{$tt}[0] ) if $calc{$tt}[0];
            #    print "$bb1,$pp1,>$calc1{$tt}[4],$calc{$tt}[0]\n";
            print OUT1">$calc1{$tt}[4]$calc{$tt}[0]\n";
        }
        else { }
        close OUT1;
        close OUT2;
        close OUT3;
        close ROUT1;

        system("gnuplot < $file2 >/dev/null");
        system("rm $file");
        system("rm $file2");
    }


    foreach my $tt ( sort keys %calc ) {
        my ( $bb1, $pp1 ) = split( '\|', $tt );

        my $file  = $bb1 . $pp1 . '_Gnuplot_p.txt';
        my $rfile = 'PopulationReportHist_' . $bb1 . '_' . $pp1 . '_used.csv';
        my $ff    = 'OUT_' . $bb1 . $pp1;
        my $ff2   = 'ROUT_' . $bb1 . $pp1;

        open( "$ff",  ">$file" )  or die "Can not open $file: $!\n";
        open( "$ff2", ">$rfile" ) or die "Can not open $rfile: $!\n";
    }


    foreach my $tt ( sort { $a <=> $b } keys %hash3 ) {
        if ( $hash3{$tt}[3] <= 30 ) {
            my $gf2 = 'ROUT_' . $hash3{$tt}[1] . $hash3{$tt}[2];
            print $gf2 "$hash3{$tt}[5],$hash3{$tt}[4]\n";
            $hash3{$tt}[5] = pack( "A20", $hash3{$tt}[5] );
            $hash3{$tt}[4] = sprintf( "%10d", $hash3{$tt}[4] );
            my $gf = 'OUT_' . $hash3{$tt}[1] . $hash3{$tt}[2];
            print $gf "$hash3{$tt}[5]$hash3{$tt}[4]\n";
        }
    }

    foreach my $tt ( sort keys %calc ) {
        my ( $bb1, $pp1 ) = split( '\|', $tt );
        my $gh2 = $bb1 . $pp1 . '_Gnuplot_p.txt';
        close 'OUT_' . $bb1 . $pp1;
        close 'ROUT_' . $bb1 . $pp1;
        my $gh = $bb1 . $pp1 . '_Gnuplot_p';

        system("gnuplot < $gh >/dev/null");
        system("rm $gh");
        system("rm $gh2");
    }
    # END OF ALL-PROGENY

    # BEGIN SELECTED PROGENY
    %hash1 = ();
    %calc  = ();
    %calc1 = ();
    %hash2 = ();
    %hash3 = ();
    $sql2 =
        "SELECT breed, parent, count(*) AS number, round(avg(count), 0),
                round(stddev(count), 1)
        FROM tmp1_family_sel
        WHERE breed $sine '$breed'
        GROUP BY breed,parent ORDER BY breed,parent";
    $sql =
        "SELECT a.breed,a.id_nr,a.parent,a.count,b.ext_animal
        FROM tmp1_family_sel a,
             (SELECT distinct on (db_animal) ext_animal,db_animal
             FROM transfer) b
        WHERE  a.id_nr=b.db_animal AND breed $sine '$breed'
        ORDER BY a.breed,a.parent,a.count desc";

    # read family_all table
    $sql_ref = $apiis->DataBase->sys_sql($sql2);
    $sql_ref->check_status( die => 'ERR' );

    while ( my $line_ref = $sql_ref->handle->fetch ) {
        my @line = @$line_ref;
        my ( $breed, $parent, $number, $avg, $std ) = @line;
        $calc1{ $breed . '|' . $parent }[0]  = $avg;
        $calc1{ $breed . '|' . $parent }[1]  = $std;
        $calc1{ $breed . '|' . $parent }[11] = $std;
        $calc1{ $breed . '|' . $parent }[2]  = 0;            #for max count
        $calc1{ $breed . '|' . $parent }[3]  = 999999999;    #for min count
        $calc1{ $breed . '|' . $parent }[4]  = 0;            #for max levels
        $calc1{ $breed . '|' . $parent }[5]  = 999999999;    #for min levels

        if ( $calc1{ $breed . '|' . $parent }[1] and $parent eq 'sire' ) {
            # 3 stddev from mean for sires
            $calc1{ $breed . '|' . $parent }[1] =
                ( $calc1{ $breed . '|' . $parent }[1] * 3 );
        }
        if ( $calc1{ $breed . '|' . $parent }[1] and $parent eq 'dam' ) {
            # 4 stddev from mean for dams
            $calc1{ $breed . '|' . $parent }[1] =
                ( $calc1{ $breed . '|' . $parent }[1] * 4 );
        }
    }

    $sql_ref = $apiis->DataBase->sys_sql($sql);
    $sql_ref->check_status( die => 'ERR' );
    my $yy2;

    while ( my $line_ref = $sql_ref->handle->fetch ) {
        my @line = @$line_ref;
        my ( $breed, $id_nr, $parent, $count, $id ) = @line;
        $id =~ s/ /-/g;
        $hash1{ $breed . '|' . $id_nr }[0]  = $breed;
        $hash1{ $breed . '|' . $id_nr }[1]  = $parent;
        $hash1{ $breed . '|' . $id_nr }[2]  = $count;
        $calc1{ $breed . '|' . $parent }[2] = $count
            if $count > $calc1{ $breed . '|' . $parent }[2];    #max
        $calc1{ $breed . '|' . $parent }[3] = $count
            if $count < $calc1{ $breed . '|' . $parent }[3];    #min

        $yy2++;
        $hash2{ $breed . '|' . $parent }[0]++;

        $hash3{$yy2}[0] = $id_nr;
        $hash3{$yy2}[1] = $breed;
        $hash3{$yy2}[2] = $parent;
        $hash3{$yy2}[3] = $hash2{ $breed . '|' . $parent }[0];
        $hash3{$yy2}[4] = $count;
        $hash3{$yy2}[5] = $id;

    }

    foreach my $tt ( sort keys %hash1 ) {

        for (
            $i = $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[3];
            $i <= (
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]
                    + ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[1] )
            );
            $i++
            )
        {

            if ( $hash1{$tt}[1] eq 'sire' ) {
                if ((   $hash1{$tt}[2] >= (
                            (   $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }
                                    [3]
                            ) + ( $i - 1 )
                        )
                    )
                    and (
                        $hash1{$tt}[2] < (
                            (   $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }
                                    [3]
                            ) + ($i)
                        )
                    )
                    )
                {
                    $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[$i]++;
                }
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4] = $i
                    if $i > $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4]
                ;    #max levels
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5] = $i
                    if $i < $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5]
                ;    #min levels

            }
            elsif ( $hash1{$tt}[1] eq 'dam' ) {
                if ((   $hash1{$tt}[2] >= (
                            (   $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }
                                    [3]
                            ) + ( $i - 1 )
                        )
                    )
                    and (
                        $hash1{$tt}[2] < (
                            (   $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }
                                    [3]
                            ) + ($i)
                        )
                    )
                    )
                {
                    $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[$i]++;
                }

                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4] = $i
                    if $i > $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[4]
                ;    #max levels
                $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5] = $i
                    if $i < $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[5]
                ;    #min levels

            }
            else {
            }
        }

        if ( $hash1{$tt}[1] eq 'sire' ) {
            if ($hash1{$tt}[2] > (
                    $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]
                        + ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[1] )
                )
                )
            {
                $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]++;
            }
        }
        elsif ( $hash1{$tt}[1] eq 'dam' ) {
            if ($hash1{$tt}[2] > (
                    $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]
                        + ( $calc1{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[1] )
                )
                )
            {
                $calc{ $hash1{$tt}[0] . '|' . $hash1{$tt}[1] }[0]++;
            }
        }
        else {
        }
    }

    foreach my $tt ( sort keys %calc ) {
        my ( $bb1, $pp1 ) = split( '\|', $tt );

        my $file = $bb1 . $pp1 . '_sel_Gnuplot.txt';
        open( OUT1, ">$file" ) or die "Can not open $file: $!\n";

        my $rfile =
            'PopulationReportHist_' . $bb1 . '_' . $pp1 . '_all_sel.csv';
        open( ROUT1, ">$rfile" ) or die "Can not open $rfile: $!\n";

        my $file2 = $bb1 . $pp1 . '_sel_Gnuplot';
        open( OUT2, ">$file2" ) or die "Can not open $file2: $!\n";

        my $file3 = $bb1 . $pp1 . '_sel_Gnuplot_p';
        open( OUT3, ">$file3" ) or die "Can not open $file3: $!\n";

        my $pp2;
        my $pp3;
        if ( $pp1 eq 'sire' ) {
            $pp2 = 'Sire';
            $pp3 = 'Sires';
        }
        else {
            $pp2 = 'Dam';
            $pp3 = 'Dams';
        }

        print OUT '
\begin{figure}[h]
\begin{center}{
\caption{' . "$pp3" . ' with the most Selected Progeny in the Population}' . '
  %%\begin{flushleft}
  \includegraphics[scale=.9]{./' . "$file3" . '.ps}
  %%\end{flushleft}
  }\end{center}
  \end{figure}
  ' . "\n";
        $delfiles{ "$file3" . '.ps' } = 1;

        print OUT3 'set terminal postscript
set output "' . "$file3" . '.ps"
set title "' . "$pp3" . ' with the most Selected Progeny in the Population"
set datafile missing "-"
set style data histogram
set style histogram cluster gap 1 title offset 2,0.25
set style fill solid noborder
set ytics font "Times,11"
set grid y
set auto y
set ylabel "Number of Selected Progeny per ' . "$pp2"
            . '" font "Times-Italic,14"
set xlabel "ID-numbers of 30 ' . "$pp3"
            . ' with the most Selected Progeny" font "Times-Italic,14" offset  0,-5
set xtics nomirror rotate by -70 font "Times,11"
set bmargin 10
set rmargin 6
plot "' . "$bb1" . "$pp1" . '_sel_Gnuplot_p.txt" using 2:xtic(1) notitle';

        print OUT '
\begin{figure}[h]
\begin{center}{
\caption{Number of Selected Progeny per ' . "$pp2" . '}' . '
  %%\begin{flushleft}
  \includegraphics[scale=.9]{./' . "$file2" . '.ps}
  %%\end{flushleft}
  }\end{center}
  \end{figure}
  ' . "\n";
        $delfiles{ "$file2" . '.ps' } = 1;

        print OUT2 'set terminal postscript
set output "' . "$file2" . '.ps"
set title "Number of Selected Progeny per ' . "$pp2" . '
set datafile missing "-"
set style data histogram
set style histogram cluster gap 1 title offset 2,0.25
set style fill solid noborder
unset xtics
set ytics font "Times,11"
set grid y
set auto y
set ylabel "Number of ' . "$pp3" . '" font "Times-Italic,14"
set xlabel "Number of Selected Progeny per ' . "$pp2"
            . '\n (note: Min: '
            . "$calc1{$tt}[3]"
            . ',Avg: '
            . "$calc1{$tt}[0]"
            . ',Std: .'
            . "$calc1{$tt}[11]"
            . ',Max: '
            . "$calc1{$tt}[2]"
            . ')" font "Times-Italic,14"
set bmargin 5
set xtics (';

        my $ry2;
        if ( $calc1{$tt}[4] > 30 ) {
            my $ry = round( $calc1{$tt}[4] / 30 );
            for ( $i = $ry; $i < $calc1{$tt}[4]; $i += $ry ) {
                $ry2 = $i - 1;
                print OUT2 '"' . "$i" . '" ' . "$ry2" . ',';
            }
            $ry2 = $calc1{$tt}[4];
            print OUT2 '">' . "$calc1{$tt}[4]" . '" ' . "$ry2";
            print OUT2 ') rotate by -45 font "Times,11"' . "\n";
        }
        else {

            for ( $i = $calc1{$tt}[5]; $i <= $calc1{$tt}[4]; $i++ ) {
                $ry2 = $i - 1;
                print OUT2 '"' . "$i" . '" ' . "$ry2" . ',';
            }
            $ry2 = $calc1{$tt}[4];
            print OUT2 '">' . "$calc1{$tt}[4]" . '" ' . "$ry2";
            print OUT2 ') rotate by -45 font "Times,11"' . "\n";
        }
        print OUT2 'plot "' . "$file" . '" using 2 notitle';

        if ( $pp1 eq 'sire' ) {
            for ( $i = $calc1{$tt}[5]; $i <= $calc1{$tt}[4]; $i++ ) {
                if ( !$calc{$tt}[$i] ) {
                    $calc{$tt}[$i] = 0;
                }
                my $kk = ($i);
                print ROUT1"$kk,$calc{$tt}[$i]\n";
                $kk = pack( "A10", $kk );
                $calc{$tt}[$i] = sprintf( "%10d", $calc{$tt}[$i] );
                #    print "$bb1,$pp1,$kk,$calc{$tt}[$i]\n";
                print OUT1"$kk$calc{$tt}[$i]\n";
            }

            print ROUT1">$calc1{$tt}[4],$calc{$tt}[0]\n";
            $calc1{$tt}[4] = pack( "A9", $calc1{$tt}[4] ) if $calc1{$tt}[4];
            $calc{$tt}[0] = sprintf( "%10d", $calc{$tt}[0] ) if $calc{$tt}[0];
            #    print "$bb1,$pp1,>$calc1{$tt}[4],$calc{$tt}[0]\n";
            print OUT1">$calc1{$tt}[4]$calc{$tt}[0]\n";

        }
        elsif ( $pp1 eq 'dam' ) {
            for ( $i = $calc1{$tt}[5]; $i <= $calc1{$tt}[4]; $i++ ) {
                if ( !$calc{$tt}[$i] ) {
                    $calc{$tt}[$i] = 0;
                }
                my $kk = ($i);
                print ROUT1"$kk,$calc{$tt}[$i]\n";
                $kk = pack( "A10", $kk );
                $calc{$tt}[$i] = sprintf( "%10d", $calc{$tt}[$i] );
                #    print "$bb1,$pp1,$kk,$calc{$tt}[$i]\n";
                print OUT1"$kk$calc{$tt}[$i]\n";
            }

            print ROUT1">$calc1{$tt}[4],$calc{$tt}[0]\n";
            $calc1{$tt}[4] = pack( "A9", $calc1{$tt}[4] ) if $calc1{$tt}[4];
            $calc{$tt}[0] = sprintf( "%10d", $calc{$tt}[0] ) if $calc{$tt}[0];
            #    print "$bb1,$pp1,>$calc1{$tt}[4],$calc{$tt}[0]\n";
            print OUT1">$calc1{$tt}[4]$calc{$tt}[0]\n";
        }
        else { }

        close OUT1;
        close OUT2;
        close OUT3;
        close ROUT1;
        system("gnuplot < $file2 >/dev/null");
        system("rm $file");
        system("rm $file2");
    }

    foreach my $tt ( sort keys %calc ) {
        my ( $bb1, $pp1 ) = split( '\|', $tt );
        my $file = $bb1 . $pp1 . '_sel_Gnuplot_p.txt';
        my $ff   = 'OUT_' . $bb1 . $pp1;
        my $rfile = 'PopulationReportHist_' . $bb1 . '_' . $pp1 . '_sel.csv';
        my $ff2   = 'ROUT_' . $bb1 . $pp1;
        open( "$ff2", ">$rfile" ) or die "Can not open $rfile: $!\n";
        open( "$ff", ">$file" ) or die "Can not open $file: $!\n";
    }

    foreach my $tt ( sort { $a <=> $b } keys %hash3 ) {
        if ( $hash3{$tt}[3] <= 30 ) {
            my $gf2 = 'ROUT_' . $hash3{$tt}[1] . $hash3{$tt}[2];
            print $gf2 "$hash3{$tt}[5],$hash3{$tt}[4]\n";
            $hash3{$tt}[5] = pack( "A20", $hash3{$tt}[5] );
            $hash3{$tt}[4] = sprintf( "%10d", $hash3{$tt}[4] );
            my $gf = 'OUT_' . $hash3{$tt}[1] . $hash3{$tt}[2];
            print $gf "$hash3{$tt}[5]$hash3{$tt}[4]\n";
        }
    }

    foreach my $tt ( sort keys %calc ) {
        my ( $bb1, $pp1 ) = split( '\|', $tt );
        my $gh2 = $bb1 . $pp1 . '_sel_Gnuplot_p.txt';
        my $gh4 = 'PopulationReportHist_' . $bb1 . '_' . $pp1 . '_sel.csv';
        close 'OUT_' . $bb1 . $pp1;
        close 'ROUT_' . $bb1 . $pp1;
        my $gh = $bb1 . $pp1 . '_sel_Gnuplot_p';
        system("gnuplot < $gh >/dev/null");
        system("rm $gh");
        system("rm $gh2");
    }
    ###END OF SELECTED PROGENY
    close OUT;
    return ();
} # end of sub new_tabel()

sub round {
    my $number = shift;
    $number = int( ( $number * 1 ) + 1 );
    return ($number);
}

##############################################################################
1;                
__END__


