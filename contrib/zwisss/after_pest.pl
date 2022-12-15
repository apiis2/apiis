#!/usr/bin/env perl
###########################################################################
# after pest analyse the pest job
# - fixed effects with a low number of members
# - covariable get histogramm
# - highest changes of BLUPS are result from (number of new information...)
###########################################################################
# after_pest.pl
# usage: after_pest.pl
#  -a use apiis not mysql (only apiis finished so far)
#  -m <> modelfile
#  -p <> project
#  -u <> database user
#  -w <> database password
#  -o without comparing old estimation
#  -t use initially used external animal identification to compare old
#     estimations (use apiis always to code the data) (require only
#     drop table not the whole db!)
#  -x only PEST parameterfile
###########################################################################

BEGIN {
  use Env qw( APIIS_HOME );
  die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
  push @INC, "$APIIS_HOME/lib";
  push @INC, "$APIIS_HOME/contrib/zwisss";
}
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.29 $ ');
our $apiis;
# use Apiis::Auth::AccessControl;
use Apiis::Misc qw ( mychomp LocalToRawDate ); # ...

my (%opt);
use Apiis;
use Getopt::Std;
use File::Basename;
use Date::Manip;
use Term::ReadKey;
use CalcTBV;
use Apiis::DataBase::User;
use r_plot;
use Tie::IxHash;
use ParsePest;

getopts('afm:r:p:u:w:otx',\%opt) || die "Keine gültige Option";

# use strict;
use Date::Manip;
use FileHandle;
use Data::Dumper;
use DBI;
use ref_breedprg_alib;
use Statistics::Descriptive;

my($zwisss,$zwisssb,$c,@b,@traits,%input);
my ($tr);
my $limit = 10;			# number of displayed bv

$| = 1;
if ( !$opt{'m'} ) {
  print "Kein Modell spezifiziert\n";
  exit 0;
}
if ( !$opt{'p'} ) {
    print "Kein Project spezifiziert\n";
    exit 0;
}

my $project = $opt{'p'};
# my $modell=File::Basename::basename($opt{'m'},qr{'\.model'});
# $modell=~s/\.model//;

#--- postgres (apiis) oder mysql-Modus
if ($opt{'a'}) {
  my $not_ok = 1;
  while ($not_ok) {
    if (! $opt{'u'}) {
      print __("Please enter your login name: ");
      chomp( $opt{'u'} = <> );
    }
    if (! $opt{'w'}) {
      print __("... and your password: ");
      ReadMode 2;
      chomp( $opt{'w'} = <> );
    }  
    ReadMode 0;
    print "\n";
    $not_ok = 0 if $opt{'u'} and $opt{'w'};
  }
  $user_obj = Apiis::DataBase::User->new( id => $opt{'u'} );
  goto ERR if ($apiis->status);

  $user_obj->password($opt{'w'});
  goto ERR if ($apiis->status);

  $apiis->join_model($opt{'p'}, userobj => $user_obj);
  goto ERR if ($apiis->status);


  $zwisss=ZwsApiis->new($opt{'p'},$apiis);
} else {
  $zwisss=CalcTBV->new(uc($project));
}

$zwisss->SetTbvParameterFile($opt{'m'});

#--- Basisverzeichnis ermitteln und als local setzen
$zwisss->SetLocal($ENV{'PWD'});

#--- Optionen übergeben
$zwisss->SetOpt(\%opt);

$zwisss->SetDebugModus('1');

#--- Zuchtwertschätzung; zws-Modelfile (Option -m) wird eingelesen
$zwisssb=$zwisss->ReadZwisssParameterFile();

my $vtb_ref=$zwisss->GetTBVS();
my $model=$zwisss->GetVerband();
# oder aus modellname? siehe hszvno_test
# ($a)=($opt{'m'}=~/(.*?)\.model/);
# $model=$a;

my $dbh = $apiis->DataBase->dbh;
my $min_fix = 3; # write the effects which have less than $min_fix members

#all things go to $APIIS_HOME."/tmp"
chdir($APIIS_HOME."/tmp");

write_tex_header( 'pestanalyse' );
open ( PESTANALYSE, ">>pestanalyse" );
print PESTANALYSE "{\\Large \\bf Analyse of breeding value estimation from \\today}\n\n";
print PESTANALYSE "\\tableofcontents \\newpage\n\n";
print PESTANALYSE "\\section{Models / Effects}\n\n";
close ( PESTANALYSE );

# ##
my ( $aa, $bb, $cc ) = ();
my %testalias =  ();
my @sorting = ();

foreach my $vtb ( sort{ length $a  <=> length $b || $a cmp $b } keys %{$zwisss->GetTBVS()} ) {

    my $subsection = 0;
    my  %mcc = ();
    my $ret_vtb = $zwisss->GetEstimation($vtb);
    next if ( ! $zwisss->GetTBVEstimation($vtb) or $zwisss->GetTBVEstimation($vtb) ne $ret_vtb  );
    my $ttab = lc($model) . "_" . $zwisss->GetTBVEstimation($vtb) . "_effects";
    # $ttab = uc($ttab);
    $nam1 = $zwisss->{'tables'}->{$ttab};

    # general informations
    my $myalias = $ret_vtb;
    my $myparin = $zwisss->{'alias'}->{$myalias};
    $myparin =~ s/zwisss\///g;
    my $mypareff = $myparin;
    $mypareff =~ s/pest$/eff/g;

    $aa=CalcTBV->new(uc($vtb));
    $aa->SetLocal($ENV{'PWD'});
    $aa->SetTbvParameterFile($myparin);
    $aa->ParsePestParameter($myparin);

    chdir($APIIS_HOME."/tmp");
    open ( PESTANALYSE, ">>pestanalyse" );
    print PESTANALYSE "\\subsection{Breeding value estimation $vtb}\n\n";
    close( PESTANALYSE );

    if ( ! $zwisss->{'alias'}->{ $ret_vtb } ) { # not a physical estimation
	chdir($APIIS_HOME."/tmp");
	open ( PESTANALYSE, ">>pestanalyse" );
	print PESTANALYSE "there are no real breeding value estimation. only calculation of total breeding values...\n\n";
	close ( PESTANALYSE );
	goto WF;
    }
    if ( $testalias{ $ret_vtb } ) {
	chdir($APIIS_HOME."/tmp");
	open ( PESTANALYSE, ">>pestanalyse" );
	print PESTANALYSE "for static model informations see estimation $testalias{ $ret_vtb } \n\n";
	close ( PESTANALYSE );
	goto WF;
    }

    chdir($APIIS_HOME."/tmp");
    open ( PROBOUT, ">$mypareff" );
    print PROBOUT "# this file contain all effects with less than $min_fix members \n# estimation: $myparin \n";
    close ( PROBOUT );

    if ($myparin=~/^\//) {
	$c=chdir(File::Basename::dirname($myparin));
    } else {
	$c=chdir($aa->GetLocal()."/".File::Basename::dirname($myparin));
    }
    my $myerg = $aa->{'pest'}->{$myparin}->{'PRINTOUT'}->{'OUTFILE'}[0];
    # $myerg =~ s/^..*\///g;
    ( $bb, $cc ) = ReadPestErg("$myerg");
    %cc = %$cc;
    chdir($aa->GetLocal());

    my $res = $aa->{'pest'}->{$myparin}->{'MODEL'}->{'traits'};
    @res = @$res;
    my $mymodel = ();
    my $rescounts = $#res +1;
    if ( $aa->{'pest'}->{$myparin}->{'RELATIONSHIP'}->{'REL_FOR'}[0] eq 'animal') {
	$mymodel = 'animal';
    } elsif ( $aa->{'pest'}->{$myparin}->{'RELATIONSHIP'}->{'REL_FOR'}[0] eq 'sire dam') {
	$mymodel = 'sire-dam';
    }

    chdir($APIIS_HOME."/tmp");
    open ( PESTANALYSE, ">>pestanalyse" );
    print PESTANALYSE "\\subsubsection{General Modelinformations}\n\n";
    print PESTANALYSE "{\\bf $rescounts trait-$mymodel model} \\vspace{3mm}\n\n";
    my $mcc = @{$cc->{ '1' }};
    $mcc = $mcc - 1;
    if ( $mcc == -1 ) {
	print PESTANALYSE "\\begin{longtable}{rll}\n\n";
	for my $mtraits ( @res ) {
	    my @outmod = $aa->{'pest'}->{$myparin}->{'MODEL'}->{uc($mtraits)};
	    my $mouttraits = $mtraits;
	    $mouttraits =~ s/_/\\_/;
	    map { s/_/\_/g; } @outmod;
	    print PESTANALYSE "$mouttraits & = & @{$outmod[0]} \\\\\n";
	}
    } else {
	my $myrow = 1;
	$mcc = $mcc - 2;
	print PESTANALYSE "{\\footnotesize \n" if ( $rescounts > 12 and $rescounts < 16 );
	print PESTANALYSE "{\\tiny \n" if ( $rescounts > 15 );
	print PESTANALYSE "\\begin{longtable}{rcr*{". $mcc ."}{c}}\n\n";
	my @sortcrit = ( 'F', 'C', 'R', 'A' );
	for my $mtraits ( sort { $cc{$a}[2] <=> $cc{$b}[2] } keys %cc ) {
	    $mcc{ ${$cc{ $mtraits }}[0] }  = ${$cc{ $mtraits }}[2];
	    if ( $mtraits == 0 ) {
		$cc{ $mtraits } = [ 'effect', ' ', 'n', @{$cc{ $mtraits }} ];
	    }
	    if ( ${$cc{ $mtraits }}[1] eq 'F' and ${$cc{ $mtraits }}[2] == 1 ) {
		${$cc{ $mtraits }}[0] = ${$cc{ $mtraits }}[0] . '\footnote{probably not needed as effect if you have only one class here}';
	    }
	    my @oo = @{$cc{ $mtraits }};
	    map { s/_/\\_/; } @oo;
	    my $ooo = join( ' & ', @oo );
	    if ( $myrow == 1 ) {
		$ooo = join( '} & \rotatebox{90}{\bf ', @oo );
		$ooo = '\rotatebox{90}{\bf ' . $ooo . '}';
	    }
	    $myrow++;
	    print PESTANALYSE "$ooo \\\\\n";
	    # print STDOUT "++$mtraits++>${$cc{ $mtraits }}[0]<+++\n";
	}
    }

    print PESTANALYSE "\\end{longtable}\n\n";
    print PESTANALYSE "} \n" if ( $rescounts > 12 and $mcc > -1);

    print PESTANALYSE " \\vspace{3mm} {\\bf some statistics....} \\vspace{3mm}\n\n";

    print PESTANALYSE "\\begin{tabular}{rD{.}{.}{-1}D{.}{.}{-1}D{.}{.}{-1}D{.}{.}{-1}D{.}{.}{-1}D{.}{.}{-1}D{.}{.}{-1}}\\hline\n";

    print PESTANALYSE " & \\multicolumn{2}{c}{\\bf Parameterfile} & \\multicolumn{5}{c}{\\bf PEST run} \\\\\n";
    print PESTANALYSE "{\\bf trait} &{\\bf  min} &{\\bf max} &{\\bf  min} &{\\bf  max} &{\\bf n} &{\\bf  mean }&{\\bf  std} \\\\ \\hline\n";

    my @nerg = @{$bb->{'DI'}->{'n'}};
    my @minerg = @{$bb->{'DI'}->{'mi'}};
    my @maxerg = @{$bb->{'DI'}->{'ma'}};
    my @avgerg = @{$bb->{'DI'}->{'mw'}};
    my @stderg = @{$bb->{'DI'}->{'sa'}};
    my @trerg  = @{$bb->{'DI'}->{'traits'}};

    for my $mtraits ( @res ) {
	my @outmod = $aa->{'pest'}->{$myparin}->{'TRANSFORMATION'}->{'TREATED_AS_MISSING'}->{$mtraits};
	my $mouttraits = $mtraits;
	$mouttraits =~ s/_/\\_/;
	map { s/_/\_/g; } @outmod;

	my @myout = (); my $mycount = 0;
	foreach my $mytr ( @trerg ) {
	    if ( uc($mytr) eq uc($mtraits )) {
		push @myout, $minerg[$mycount];
		push @myout, $maxerg[$mycount];
		push @myout, $nerg[$mycount];
		push @myout, $avgerg[$mycount];
		push @myout, $stderg[$mycount];
	    }
	    $mycount ++;
	}

	my $myout = join( ' & ', @myout );
	print PESTANALYSE "{\\bf $mouttraits} & ${$outmod[0]}[1] & ${$outmod[0]}[3] & $myout \\\\\n";
    }
    print PESTANALYSE "\\end{tabular}\n\n";

    # phenotypic and genetic parameter
    print PESTANALYSE "\\vspace{3mm} {\\bf phenotypic and genetic parameter}\n\n";
    my %ve = (); my %vg = ();
    for (my $myc = 0; $myc < $rescounts; $myc ++ ) {
	my $vec = 0;
	for my $nn ( @{$aa->{'pest'}->{$myparin}->{'VE'}->{''}->{$myc}} ) {
	    $ve{ $myc }{ $vec } = $nn;
	    $vec++;
	}
    }
    for my $myvg ( @{$aa->{'pest'}->{$myparin}->{'VG'}->{'VG_FOR'}} ) {
	for (my $myc = 0; $myc < $rescounts; $myc ++ ) {
	    my $vec = 0;
	    for my $nn ( @{$aa->{'pest'}->{$myparin}->{'VG'}->{$myvg}->{$myc}} ) {
		$vg{ $myvg }{ $myc }{ $vec } = $nn;
		$vec++;
	    }
	}
    }
    my %v_sum = ();
    for my $myve ( keys %ve ) {
	for my $inmyve ( keys %{$ve{ $myve }} ) {
	    $v_sum{ $myve }{ $inmyve } = $ve{ $myve }{ $inmyve };
	}
    }
    for my $outmyvg ( keys %vg ) {
	for my $myvg ( keys %{$vg{ $outmyvg }} ) {
	    for my $inmyvg ( keys %{$vg{ $outmyvg }{ $myvg }} ) {
		$v_sum{ $myvg }{ $inmyvg } = $v_sum{ $myvg }{ $inmyvg } + $vg{ $outmyvg }{ $myvg }{ $inmyvg };
	    }
	}
    }

    my %genet = (); my %phen = ();
    for (my $myc = 0; $myc < $rescounts; $myc ++ ) {
	for (my $mycc = 0; $mycc < $rescounts; $mycc ++ ) {
	    if ( $myc  == $mycc ) { # vars / herit
		$phen{ $myc }{ $mycc } = $v_sum{  $myc }{ $mycc };
		my $retgen = $vg{ 'animal' }{ $myc }{ $mycc } / $v_sum{ $myc }{ $mycc };
		$genet{ $myc }{ $mycc } = $retgen;
	    } else {		# korr
		my $retphen = $v_sum{ $myc }{ $mycc } / sqrt( $v_sum{ $myc }{ $myc } * $v_sum{ $mycc }{ $mycc } );
		$phen{ $myc }{ $mycc } = $retphen;
		my $retgen = $vg{ 'animal' }{ $myc }{ $mycc } / sqrt( $vg{ 'animal' }{ $myc }{ $myc } * $vg{ 'animal' }{ $mycc }{ $mycc } );
		$genet{ $myc }{ $mycc } = $retgen;
	    }
	}
    }

    print PESTANALYSE "{\\footnotesize \n" if ( $rescounts > 12 and $rescounts < 16 );
    print PESTANALYSE "{\\tiny \n" if ( $rescounts > 15 );
    if ( $rescounts < 18 ) {
	print PESTANALYSE "\\begin{longtable}{r*{". $rescounts ."}{r}}\n\n";
    } else {
	print PESTANALYSE "\\begin{longtable}{r*{". $rescounts ."}{".'@{\hspace{2mm}}r}}'."\n\n";
    }
    my @outmod = @{$res};
    map{ s/_/\\_/g; } @outmod;
    my $outmod = join( '} & \rotatebox{90}{\bf ', @outmod );
    $outmod = '\rotatebox{90}{\bf ' . $outmod . '}';
    print PESTANALYSE " trait & $outmod \\\\ \\hline\n\n";
    for my $myve ( sort { $a <=> $b } keys %genet ) {
	for my $inmyve ( sort { $a <=> $b } keys %{$genet{ $myve }} ) {
	    my $val = ();
	    $val =  sprintf("%.2f", $genet{ $myve }{ $inmyve } ) if ( $myve <= $inmyve );
	    $val =  sprintf("%.2f", $phen{ $myve }{ $inmyve } ) if ( $myve > $inmyve );
	    if ( $myve eq $inmyve ) {
		$val = '{\bf ' . $val . '}';
	    }
	    if ( $inmyve > 0 ) {
		$val = ' & ' . $val ;
	    }
	    $val = '{\bf ' . $outmod[ $myve ] . '} & ' . $val if ( $inmyve == 0 );
	    print PESTANALYSE " $val ";
	}
	print PESTANALYSE "\\\\ \n";
    }
    print PESTANALYSE "\\end{longtable}\n\n";
    print PESTANALYSE "} \n" if ( $rescounts > 12 );
    print PESTANALYSE "\\vspace{-3mm}\\centerline{\\small heritabilities on diagonale, genetic correlations above and phenotypic below them}\n\n";

    close ( PESTANALYSE );
    ## general informations

    # weighting factors if exist tbv entry
  WF:
    if ( $zwisss->{'tbvs'}->{$vtb}->{'tbv'} ) {
	chdir($APIIS_HOME."/tmp");
	open ( PESTANALYSE, ">>pestanalyse" );
	print PESTANALYSE "\\subsubsection{weighting factors for total breeding  values}\n\n";
	
	close ( PESTANALYSE );
	my @t  = @{$zwisss->{'tbvs'}->{$vtb}->{'tbv'}};
	my @tt = ();
	# get correct variance for trait
	my @pos = ();
	foreach my $test ( @t ) {
	    foreach ( my $test2 = 0; $test2 < @{$aa->{'pest'}->{$myparin}->{'MODEL'}->{'traits'}}; $test2++ ) {
		my $rtest = ${$aa->{'pest'}->{$myparin}->{'MODEL'}->{'traits'}}[$test2]; 
		if ( $test =~ $rtest ) {
		    push @pos, $test2;
		}
	    }
	}
	foreach my $ppos ( @pos ) {
	    push @tt, ${$aa->{'pest'}->{$myparin}->{'VG'}->{'animal'}->{'VARIANZEN'}}[$ppos];
	}

	my @weight = (); my @weight_stand = ();
	my @names = ();
 	for (my $c = 0; $c <= $#t; $c++ ) {
	    my @rest = split('\*', $t[$c]);
	    push @weight, abs($rest[0]);
	    push @names, $rest[1];
	    # if always standardised
	    if ( $zwisss->{'tbvs'}->{$vtb}->{'wi'}[0] eq 'AB' ) {
		push @weight_stand, sprintf("%.2f",abs($rest[0])*(sqrt($tt[$c])));
 	    } else {
 		push @weight_stand, sprintf("%.2f",abs($rest[0])/(sqrt($tt[$c])));
	    }
	}

	if ( $zwisss->{'tbvs'}->{$vtb}->{'wi'}[0] ne 'AB' ) {
	    my %parameter_hash = (
				  filename => "pie_$vtb",
				  sql      => '',
				  data => [ \@names, \@weight ],
				  no_sql_elements => '',
				  legend        => [],
				  second_y_axis => 'no',
				  export_format => 'jpg',
				  chart_type => 'piechart_num',
				  chart_type2 => '',
				  titel      => "'weighting factors'",
				  subtitel   => "'aggregated breeding value: $vtb'",
				  #xlabel     => '"effects"',
				  #ylabel     => '"BLUE"',
				  mtext_l    => '', # additional text
				  mtext_r    => '',
				  color      => 'yes',
				  x_dates    => 'no'
				 );
	
	    $status = r_plot( \%parameter_hash );
	
	    #print "$status\n";
	    chdir($APIIS_HOME."/tmp");
	    open ( PESTANALYSE, ">>pestanalyse" );
	    #print PESTANALYSE "{ \\bf $out_trait}\n\n";
	    print PESTANALYSE "\\includegraphics[angle=270, width=85mm]{$args{ filename }} \n";
	    #print PESTANALYSE "\\nopagebreak\\includegraphics[width=150mm]{$args{ filename }} \\vspace{-7mm}\n\n";
	    close ( PESTANALYSE );
	}

	# standardised
	map { s/'//g; } @names;

	my %parameter_hash = (
			      filename => "pie_stand_$vtb",
			      sql      => '',
			      data => [ \@names, \@weight_stand ],
			      no_sql_elements => '',
			      legend        => [],
			      second_y_axis => 'no',
			      export_format => 'jpg',
			      chart_type => 'piechart_num',
			      chart_type2 => '',
			      titel      => "'standardised weighting factors'",
			      subtitel   => "'aggregated breeding value: $vtb'",
			      #xlabel     => '"effects"',
			      #ylabel     => '"BLUE"',
			      mtext_l    => '', # additional text
			      mtext_r    => '',
			      color      => 'yes',
			      x_dates    => 'no'
			     );
	
	$status = r_plot( \%parameter_hash );
	
	#print "$status\n";
	chdir($APIIS_HOME."/tmp");
	open ( PESTANALYSE, ">>pestanalyse" );
	#print PESTANALYSE "{ \\bf $out_trait}\n\n";
	print PESTANALYSE "\\includegraphics[angle=270, width=85mm]{$args{ filename }} \n";
	#print PESTANALYSE "\\nopagebreak\\includegraphics[width=150mm]{$args{ filename }} \\vspace{-7mm}\n\n";
	close ( PESTANALYSE );

    }

    next if ( $testalias{ $ret_vtb } );
    next if ( ! $zwisss->{'alias'}->{ $ret_vtb } );

    if ( ! $opt{'x'} ) {

	chdir($APIIS_HOME."/tmp");
	open( PESTANALYSE, ">>pestanalyse" );
	print PESTANALYSE "\\subsubsection{Fixed Effects}\n\n";
	close ( PESTANALYSE );


	@dat=@{$zwisss->{'tbvs'}->{$vtb}->{'fix_effects'}};
	@dat_cov=@{$zwisss->{'tbvs'}->{$vtb}->{'cov_effects'}};
	push( @dat,  @dat_cov ) if ( $dat_cov[0] );

	my $ttab_effs = lc($model). "_" . $ret_vtb . "_effects";
	my $eff_class = $eff_search;
	$eff_class =~ s/^.+_//g;
	$eff_class =uc($eff_class);
	my  %ret_fix = ();
	my  %ret_fix2 = ();
	my  %ret_fix3 = ();

	for my $mm ( @{$bb->{'MI'}->{'f'}} ) {
	    my $fmm = 'ef' . $ret_vtb .'_'.lc($mm);
	    for my $mmm ( @{$bb->{'MI'}->{$mm}} ) {
		$fmmm = 'ef' . $ret_vtb .'_'.lc($mmm);
		$fmmm2 = 'efr' . $ret_vtb .'_'.lc($mmm);
		my $sql_effs = "select effect_class, effect, $fmmm, $fmmm2 from $ttab_effs where effect_class = '$mm'";
		# print "++++>$sql_effs<+++\n";
		my $sth_eff = $dbh->prepare(qq{ $sql_effs }) or die $dbh->errstr;
		$ret = $sth_eff->execute;
		while ( my $ss = $sth_eff->fetch ) {
		    my @sss = @$ss;
		    if ( $sss[1] eq '' or ! $sss[1] ) {
			$ret_fix3{ uc( $mm ) } += 1;
		    }
		    push( @{$ret_fix{ $sss[0] }{ $mmm }{ $sss[1] }}, ( $sss[2], $sss[3] ));
		    push( @{$ret_fix2{ $sss[0] }{ $mmm }{ $sss[2] }}, $sss[1]);
	
		}
	    }
	}

	foreach my $eff_search ( @dat ) {
	    next if ( $eff_search =~ /_$/ ); # combined effects ended with '_'
	    # but this means normal effects can not have this behavior
	    my $fix = ();
	    my $eff_use = $eff_search;
	    $eff_use =~ s/^ef/da/g;
	    my $eff_use_woda = $eff_use;
	    $eff_use_woda =~ s/^.*?_//g;
	    # my $eff_use = 'da' . $zwisss->GetTBVEstimation($vtb) . '_'
	    # . lc($eff_search);
	    my $ttab_eff = lc($model). "_" . $ret_vtb . "_daten";

	    $ttab = $ttab_eff;	# formals uc?
	    $nam1 = $zwisss->{'tables'}->{$ttab};
	    my $out_trait = ();
	    my $not = ();
	    use Data::Dumper;
	    foreach $cols ( keys %$nam1 ) {
		$not = 1 if ( $nam1->{$cols}->{'DESTINATION'} and $nam1->{$cols}->{'DESTINATION'} eq lc( $eff_use_woda ));
		$out_trait = $nam1->{$cols}->{'DESCRIPTION'} if ( $nam1->{$cols}->{'DB_COLUMN'} eq $eff_use );
	    }
	    next if ( $not );
	    $out_trait =~ s/_/\\_/g;

	    my $sql_eff_ges = "select $eff_use, count(*) from $ttab_eff group by $eff_use";
	    # my $sql_eff_ges = "select $eff_use, count(*) from
	    # $ttab_eff where $eff_use notnull group by $eff_use";
	    # print "++++>$sql_eff_ges<++++\n";
	    my $sth_eff = $dbh->prepare(qq{ $sql_eff_ges }) or die $dbh->errstr;
	    $ret = $sth_eff->execute;
	    my %eff = (); my @effects_all = ();
	    my %eff_trait = (); # for real used counts
	    while ( my $ss = $sth_eff->fetch ) {
		my @sss = @$ss;
		$sss[0] = 'NULL' if ( ! $sss[0] );
		next if ( ! $sss[1] );
		$eff{ $sss[0] } = $sss[1];
		for ( my $cc = 1; $cc <= $sss[1]; $cc++ ) {
		    push @effects_all, $sss[0]; # used for histogramm
		}
	    }

	    my $effgr1 = 0;	# == 1
	    my $effgr2 = 0;	# <= 5
	    my $effgr3 = 0;	# <=10
	    my $effgr4 = 0;	# <=20
	    my $effgr5 = 0;	# >20
	    my @eff_out = ();
	    my @eff_printout = ();

	    foreach my $eff_out ( sort { $eff{$a} cmp $eff{$b} } keys %eff ) {
		push @eff_out, $eff{ $eff_out };
		$effgr1 ++ if ( $eff{ $eff_out } == 1 );
		$effgr2 ++ if ( $eff{ $eff_out } > 1 and $eff{ $eff_out } < 6 );
		$effgr3 ++ if ( $eff{ $eff_out } > 5 and $eff{ $eff_out } < 11 );
		$effgr4 ++ if ( $eff{ $eff_out } > 10 and $eff{ $eff_out } < 21 );
		$effgr5 ++ if ( $eff{ $eff_out } > 20 );
		push @eff_printout, $eff_out if ( $eff{ $eff_out } < $min_fix );
	    }

	    $fix = 1 if ( ! map { $eff_search =~ $_ } @dat_cov or ! $dat_cov[0] );
	    if ( $fix ) {
		my $ct = ();
		my $mn = ();
		my $mx = ();
		my $mw = ();
		my $stat = Statistics::Descriptive::Full->new();
		$stat->add_data(@eff_out);
		$ct=$stat->count();
		$mw=sprintf("%.2f", $stat->mean()) if $ct ne 0;
		$mn=$stat->min();
		$mx=$stat->max();
		#    $vr=sprintf("%.2f",$stat->variance());
		#    $std=sprintf("%.2f", sqrt($vr));
		#    $u = $mw - $range*$std if $ct ne 0;
		#    $o = $mw + $range*$std if $ct ne 0;
		#    $med=sprintf("%.2f", $stat->median());
		#    $perc=$stat->percentile($v);
		#    $perca=$stat->percentile($b);
		chdir($APIIS_HOME."/tmp");
		open ( PESTANALYSE, ">>pestanalyse" );
		print PESTANALYSE "\n\n{\\bf Effect: $out_trait }\n\n\\begin{minipage}{160mm}";
		print PESTANALYSE '\nopagebreak\begin{tabular*}{\textwidth}{l@{\extracolsep{\fill}}ccccc}';
		print PESTANALYSE "
                         & & \\multicolumn{3}{c}{Members} \\\\
                         & count & min & avg & max \\\\
              $out_trait & $ct";
		if ( $ret_fix3{ uc($out_trait) } ) {
		    print PESTANALYSE "\\footnote{there is one effect with empty coding displayed as \'NULL\' and would be $ret_fix3{ uc($out_trait) } times used in equations}";
		}
		print PESTANALYSE "
 & $mn & $mw & $mx \\\\[2ex] \\hline
                 {\\bf classes} & {\\bf 1} & {\\bf \$\\le\$ 5} & {\\bf \$\\le\$ 10} & {\\bf \$\\le\$ 20} & {\\bf \$>\$ 20} \\\\ % \\hline
                       number of effects in this class  & $effgr1 & $effgr2 & $effgr3 & $effgr4 & $effgr5\\\\
                 \\end{tabular*}\\end{minipage}\n\n\\vspace{5mm}\n ";


		if ( @eff_printout ) { # its possible to have only one
		    my $nout =  $#eff_printout + 1;
		    print PESTANALYSE "The following effects have less than $min_fix members (n = $nout): \\newline ";
		    my @eff_probout = @eff_printout;
		    map{ s/\|/\$\|\$/g; } @eff_printout;
		    print PESTANALYSE "@eff_printout";
		    print PESTANALYSE "\n\n\\vspace{3mm}";
		    print PESTANALYSE "";
		    close ( PESTANALYSE );

		    # write zws.eff
		    chdir($APIIS_HOME."/tmp");
		    open ( PROBOUT, ">>$mypareff" );
		    print PROBOUT "# effect: $out_trait \n";
		    foreach my $mm ( @eff_probout ) {
			print PROBOUT "$myparin \t $out_trait \t $mm \t $mm \n";
		    }
		    close ( PROBOUT );
		}

		my $ccc = 1;
		my %ret_sum = ();
		my %ret_count = ();
		my %ret_graph = ();
		for my $ret_f ( keys %ret_fix ) {
		    next if ( $ret_f ne uc($out_trait) );
		    $ccc++;
		    for my $ret_f1 ( keys %{$ret_fix{ $ret_f }} ) {
			for my $ret_f2 ( keys %{$ret_fix{ $ret_f }{ $ret_f1 }} ) {
			    $ret_graph{ $ret_f }{ $ret_f1 }{ $ret_f2 } = ${$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }}[1];
			    #print "+++*>$ret_f=>$ret_f1=>$ret_f2=>@{$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }}<*+++\n";
			    $ret_sum{ $ret_f }{ $ret_f1 }{ 'min' } = [ $ret_f2, @{$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }} ] if (  ! $ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }  );
			    $ret_sum{ $ret_f }{ $ret_f1 }{ 'min' } = [ $ret_f2, @{$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }} ] if ( ${$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }}[0] <  ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[1] );
			    $ret_sum{ $ret_f }{ $ret_f1 }{ 'max' } = [ $ret_f2, @{$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }} ] if (  ! $ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }  );
			    $ret_sum{ $ret_f }{ $ret_f1 }{ 'max' } = [ $ret_f2, @{$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }} ] if ( ${$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }}[0] >  ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[1] );
			    $ret_count{ $ret_f }{ $ret_f1 }{ ${$ret_fix{ $ret_f }{ $ret_f1 }{ $ret_f2 }}[0] } += 1;
			}
		    }
		}

		chdir($APIIS_HOME."/tmp");
		open ( PESTANALYSE, ">>pestanalyse" );
		my $ccc = 1;
		my @only_one_times = ();
		for my $ret_f ( keys %ret_sum ) {
		    next if ( $ret_f ne uc($out_trait) );
		    print PESTANALYSE "\\begin{minipage}{160mm} The following table shows some extreme BLUE values for the effects together with the number of observations in brackets and additionally the deviation from the middle BLUE.\n\n" if ( $ccc == 1 );
		    print PESTANALYSE "\\begin{longtable}{rlrrrrrl}\\hline\n\n" if ( $ccc == 1 );
		    $ccc++;
		    print PESTANALYSE "{\\bf  } & lowest& \\multicolumn{3}{c}{\\bf PEST}& \\multicolumn{2}{c}{\\bf relativ } & highest \\\\ \n";
		    print PESTANALYSE "trait  & effect (n) & min & max & range & min & max  &  effect (n)\\\\ \\hline\n";

		    for my $ret_f1 ( keys %{$ret_sum{ $ret_f }} ) {
		      # count classes only for this effect rffr
		      my $sql_eff_ges = "select $eff_use, count(*) from $ttab_eff where $eff_use notnull and da" . $ret_vtb . "_$ret_f1 notnull group by $eff_use";
		      # print "++++>$sql_eff_ges<++++\n";
		      my $sth_eff = $dbh->prepare(qq{ $sql_eff_ges }) or die $dbh->errstr;
		      $ret = $sth_eff->execute;
		      while ( my $ss = $sth_eff->fetch ) {
			my @sss = @$ss;
			next if ( ! $sss[1] );
			$eff_trait{ $sss[0] } = $sss[1];
# 			for ( my $cc = 1; $cc <= $sss[1]; $cc++ ) {
# 			  push @effects_all, $sss[0]; # used for histogramm
# 			}
		      }
		      ##

			for my $ret_f2 ( keys %{$ret_sum{ $ret_f }{ $ret_f1 }} ) {
			    if ( $ret_f2 eq 'min' ) {
				my $outcountmax = $ret_count{ $ret_f }{ $ret_f1 }{${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[1]};
				my $outcountmin = $ret_count{ $ret_f }{ $ret_f1 }{${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[1]};

				my $o1 = ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[0];
				my $o2 = ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[0];

				my $outret_f1 = $ret_f1;
				$outret_f1 =~ s/_/\\_/g;
				my $range = sprintf("%.2f",  ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[1] - ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[1]);

				my $a1 = ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[0];
				my $a2 = sprintf("%.2f", ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[1]);
				my $a3 = sprintf("%.2f",${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[2]);
				my $b1 = ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[0];
				my $b2 = sprintf("%.2f",${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[1]);
				my $b3 = sprintf("%.2f", ${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[2]);
				map { s/_/\\_/g; s/\|/\$\|\$/g; } ( $a1, $b1 );

				if ( $a1 eq $b1 ) {
				    push @only_one_times, $outret_f1;
				    next;
				    # goto WHAT_ELSE
				}
				
				my $outp = ();
				if ( $a1 eq '' ) {
				    $outp = " {\\bf undefined }($ret_fix3{ uc($ret_f) })";
				} else {
				    my $outn = $eff_trait{$o1};
				    $outn = '-' if ( ! $outn );
				    $outp = " {\\bf $a1 }($outn)";
				}
				my @outpi =  ();
				if ( $outcountmin > 1 ) {
				    my $testcount = 0;
				    my $onlyoneempty = 1;
				    for my $mm ( @{$ret_fix2{ $ret_f }{$ret_f1}{${$ret_sum{ $ret_f }{ $ret_f1 }{ 'min' }}[1]}} ) {
					$testcount ++;
					if ( $outcountmin > 20 and $testcount > 20 ) {
					    push (@outpi, '....' );
					    last;
					}
					if ( $mm eq '' and $onlyoneempty == 1 ) {
					    push ( @outpi, "undefined ($ret_fix3{ uc($ret_f) })" );
					    $onlyoneempty++;
					} else {
					    push ( @outpi, "$mm ($eff{$mm})" );
					}
				    }
				    map { s/_/\\_/g; s/\|/\$\|\$/g; } @outpi;
				    $outp = $outp . "\\footnote{there are total $outcountmin effects with these lowest BLUE \\newline @outpi} ";
				}

				if ( $b1 eq '' ) {
				    $outp = $outp . " & $a2 & $b2 & $range & $a3 & $b3 & {\\bf undefined} ($ret_fix3{ uc($ret_f) })";
				} else {
				    $outp = $outp . " & $a2 & $b2 & $range & $a3 & $b3 & {\\bf $b1} ($eff{$o2})";
				}
				my @outpa =  ();
				if ( $outcountmax > 1 ) {
				    my $testcount = 0;
				    my $onlyoneempty = 1;
				    for my $mm ( @{$ret_fix2{ $ret_f }{$ret_f1}{${$ret_sum{ $ret_f }{ $ret_f1 }{ 'max' }}[1]}} ) {
					$testcount ++;
					if ( $outcountmax > 20 and $testcount > 20 ) {
					    push (@outpa, '....' );
					    last;
					}
					if ( $mm eq '' and $onlyoneempty == 1 ) {
					    push ( @outpa, "undefined ($ret_fix3{ uc($ret_f) })" );
					    $onlyoneempty++;
					} else {
					    push ( @outpa, "$mm ($eff{$mm})" );
					}
				    }
				    map { s/_/\\_/g; s/\|/\$\|\$/g; } @outpa;
				    $outp = $outp . "\\footnote{there are total $outcountmax effects with these highest BLUE \\newline @outpa} ";
				}
				print PESTANALYSE "{ $outret_f1 } & $outp \\\\ \n";
			    }
			}
		    }
		    print PESTANALYSE "\\end{longtable}\n\n \\end{minipage}\\vspace{3mm} \n\n";
		}

		my $out_only_one_times = join( ', ', @only_one_times );
		chdir($APIIS_HOME."/tmp");
		open ( PESTANALYSE, ">>pestanalyse" );
		print PESTANALYSE "\n\nFor the following traits this effect seems to be useless, because only one effect exist for these traits or all BLUE values are the same (not estimatable?): $out_only_one_times \n\n \\vspace{3mm}\n" if ( @only_one_times );
		close ( PESTANALYSE );

		# graph if less than 15 elements
		for my $ret_f ( keys %ret_graph ) {
		    next if ( $ret_f ne uc($out_trait) );
		    for my $ret_f1 ( keys %{$ret_graph{ $ret_f }} ) {
		      next if ( grep { $ret_f1 =~ $_ } @only_one_times );
			my @graph_name = ();
			my @graph_data = ();
			for my $ret_f2 ( sort keys %{$ret_graph{ $ret_f }{ $ret_f1 }} ) {
			    #print
			    #"+++*>$ret_f=>$ret_f1=>$ret_f2=>@{$ret_graph{
			    #$ret_f }{ $ret_f1 }{ $ret_f2 }}<*+++\n"; 
			    push @graph_data, $ret_graph{ $ret_f }{ $ret_f1 }{ $ret_f2 };
			    $ret_f2 = 'undef' if ( ! $ret_f2 );
			    push @graph_name, $ret_f2;
			}
			if ( $#graph_data < 16 and $#graph_data > 2 ) {
			    my @null_graph = ();
			    for my $tt ( @graph_data ) {
				push @null_graph, '0';
			    }
			    my @graph_name2 = @graph_name;
		my %parameter_hash = (
				      filename => $ret_f . $ret_f1,
				      sql      => '',
				      data => [ \@graph_name, \@graph_data, \@graph_name2, \@null_graph ],
				      no_sql_elements => '',
				      legend        => [],
				      second_y_axis => 'no',
				      export_format => 'jpg',
				      chart_type => 'barplot_lines',
				      chart_type2 => '',
				      titel      => "'BLUE for $ret_f'",
				      subtitel   => "'trait $ret_f1'",
				      xlabel     => '"effects"',
				      ylabel     => '"BLUE"',
				      mtext_l    => '', # additional text
				      mtext_r    => '',
				      color      => 'yes',
				      x_dates    => 'no'
				     );

		$status = r_plot( \%parameter_hash );

		print "$status\n";
		chdir($APIIS_HOME."/tmp");
		open ( PESTANALYSE, ">>pestanalyse" );
		#print PESTANALYSE "{ \\bf $out_trait}\n\n";
		print PESTANALYSE "\\includegraphics[angle=270, width=85mm]{$args{ filename }} \n";
		#print PESTANALYSE "\\nopagebreak\\includegraphics[width=150mm]{$args{ filename }} \\vspace{-7mm}\n\n";
		close ( PESTANALYSE );
			}
		    }
		}
	    } else {		# cov
		next if ( ! @effects_all );

		my %parameter_hash = (
				      filename => $ttab_eff . $eff_search,
				      sql      => '',
				      data => [ \@effects_all ],
				      no_sql_elements => '',
				      legend        => [],
				      second_y_axis => 'no',
				      export_format => 'jpg',
				      chart_type => 'histogramm', #'barplot',
				      chart_type2 => '',
				      titel      => "$eff_search",
				      subtitel   => '""',
				      xlabel     => '""',
				      ylabel     => '""',
				      mtext_l    => '', # additional text
				      mtext_r    => '',
				      color      => 'yes',
				      x_dates    => 'no'
				     );

		$status = r_plot( \%parameter_hash );

		print "$status\n";
		chdir($APIIS_HOME."/tmp");
		open ( PESTANALYSE, ">>pestanalyse" );
		print PESTANALYSE "\\subsubsection{Covariables}\n\n" if ( $subsection++ == 0 );
		print PESTANALYSE "{\\bf Effect: $out_trait}\n\n";
		print PESTANALYSE "\\nopagebreak\\includegraphics[angle=90, width=150mm]{$args{ filename }} \\vspace{-7mm}\n\n";
		#print PESTANALYSE "\\nopagebreak\\includegraphics[width=150mm]{$args{ filename }} \\vspace{-7mm}\n\n";
		close ( PESTANALYSE );

		my @effects_all_a = ();
		my @effects_all_b = ();
		for my $mm ( @{$bb->{'MI'}->{'c'}} ) {
		    next if ( uc($mm) ne uc($out_trait) );
		    my $omm = 'da' . $ret_vtb .'_'.lc($mm);
		    for my $mmm ( @{$bb->{'MI'}->{$mm}} ) {
			my $mybetween = $aa->{'pest'}->{$myparin}->{'TRANSFORMATION'}->{'TREATED_AS_MISSING'}->{lc($mmm)};
			@mybetween = @{$mybetween};
			$ommm = 'da' . $ret_vtb .'_'.lc($mmm);
			my $sql = ();
			# first if for two times none or no between declared
			if ( ( $mybetween[1] =~ /none/i and  $mybetween[3] =~ /none/i) or ! @mybetween ) {
			    $sql = "select $omm, $ommm from $ttab_eff where $omm notnull and $ommm notnull";
			} elsif ( $mybetween[1] =~ /none/i and  $mybetween[3] !~ /none/i ) {
			    $sql = "select $omm, $ommm from $ttab_eff where $omm notnull and $ommm notnull and $ommm > $mybetween[1]";
			} elsif ( $mybetween[1] !~ /none/i and  $mybetween[3] =~ /none/i ) {
			    $sql = "select $omm, $ommm from $ttab_eff where $omm notnull and $ommm notnull and $ommm < $mybetween[3]";
			} else {
			    $sql = "select $omm, $ommm from $ttab_eff where $omm notnull and $ommm notnull and $ommm between $mybetween[1] and $mybetween[3]";
			}

			my $sth_eff = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
			$ret = $sth_eff->execute;
			@effects_all_a = ();
			@effects_all_b = ();
			while ( my $ss = $sth_eff->fetch ) {
			    my @sss = @$ss;
			    #       next if ( ! $sss[1] );
			    #       $eff{ $sss[0] } = $sss[1];
			    #       for ( my $cc = 1; $cc <= $sss[1]; $cc++ ) {
			    push @effects_all_a, $sss[0];
			    push @effects_all_b, $sss[1];
			}

			my $eff_reg = 'ef' . $ret_vtb . '_' . lc($mmm);
			my $tab_daten = $ttab_eff;
			$tab_daten =~ s/daten/effects/g;
			my $lceffect = uc($mm);
			my $sql_reg = "select $eff_reg from $tab_daten where effect = '$lceffect'";
			my $sth_eff = $dbh->prepare(qq{ $sql_reg }) or die $dbh->errstr;
			$ret = $sth_eff->execute;
			my $pestreg = ();
			while ( my $ss = $sth_eff->fetch ) {
			    my @sss = @$ss;
			    $pestreg = $sss[0];
			}

			my %parameter_hash = 
			  (
			   filename => $mm . $mmm . '_' . $ret_vtb,
			   sql      => '',
			   data => [ \@effects_all_a, \@effects_all_b ],
			   no_sql_elements => '',
			   legend        => [],
#			   legendpos     => ['right', 'bottom'],
			   second_y_axis => 'no',
			   export_format => 'jpg',
			   chart_type => 'scatterplot',
			   chart_type2 => '',
#			   range         => [ 0, 'max' ],
			   titel      => "'Regression $mm to $mmm'",
			   subtitel   => "''",
			   xlabel     => "'$mmm'",
			   ylabel     => "'$mm'",
			   mtext_l    => '', # additional text
			   mtext_r    => '',
			   pestreg    => "$pestreg",
			   color      => '',
			   x_dates    => 'no'
			  );

			$status = r_plot( \%parameter_hash );

			print "$status\n";
			chdir($APIIS_HOME."/tmp");
			open ( PESTANALYSE, ">>pestanalyse" );
			print PESTANALYSE "\\includegraphics[angle=0, width=85mm]{$args{ filename }}\n";
			close ( PESTANALYSE );
		    }
		}
	    }
	}
    }
    $testalias{ $ret_vtb } = $vtb;
}
## # #

if ( ! $opt{'o'} and ! $opt{'x'} ) {
  # changing of breeding values
  chdir($APIIS_HOME."/tmp");
  open ( PESTANALYSE, ">>pestanalyse" );
  print PESTANALYSE "\\section{Breeding values}\n\n";
  close ( PESTANALYSE );

  foreach my $vtb ( sort keys %{$zwisss->GetTBVS()} ) {
    my ($wi, $traits_ref, $traits_rel_ref)=$zwisss->GetTraitsTBV($vtb);
    #  ($eff_ref, $eff_rel_ref)=$zwisss->GetTraitsEFF($vtb);
    my $ret_vtb = $vtb;
    $ret_vtb = $zwisss->GetEstimation($vtb);
    next if ( ! $zwisss->GetTBVEstimation($vtb) or $zwisss->GetTBVEstimation($vtb) ne $ret_vtb  );

    chdir($APIIS_HOME."/tmp");
    open ( PESTANALYSE, ">>pestanalyse" );
    print PESTANALYSE "\\subsection{Breeding value estimation $vtb}\n\n";
    close ( PESTANALYSE );

    my $ttab_blup = lc($model). "_" . $zwisss->GetTBVEstimation($vtb) . "_bv";
    my $ttab_blup_old = lc($model). "_" . $zwisss->GetTBVEstimation($vtb) . "_bv_old";
    my $ttab_data = lc($model). "_" . $zwisss->GetTBVEstimation($vtb) . "_daten";
    my $ttab_data_old = lc($model). "_" . $zwisss->GetTBVEstimation($vtb) . "_daten_old";

      if ( $opt{'t'} ) {
	  # v_*_out_animal with distinct db_animal
	  # needed to join the full external numbers...
	  my $retstr = "psql $project -A -U apiis_admin -t -c \'select count(*) from v_".$project."_out_animal\'";
	  my $ret = system("$retstr");
	  if ( $? ) {
	      my $view_sql = "create view v_".$project."_out_animal as ( select distinct on ( db_animal ) db_animal, out_animal from ".$project."_out_animal )";
	      my $sth_view = $dbh->prepare(qq{ $view_sql }) or die $dbh->errstr;
	      $sth_view->execute;
	      $dbh->commit;
	  }
      }

    # @$wi + tbvn (gesamtzuchtwert) möglich?
    my $tblup = $zwisss->GetNameTBV($vtb);
    unshift ( @$wi, $tblup ); # total breeding value but without performances!
    foreach $blup ( @$wi ) {
	print "\nrunning $blup";
      my %animal = ();
      tie %animal, 'Tie::IxHash';
      my $trait = $blup;
      $trait =~ s/^bv/da/g;
      # my $eff_use = 'bv' . $zwisss->GetTBVEstimation($vtb) . '_'
      # . lc($trait);
      my $ttab_eff = lc($model). "_" . $zwisss->GetTBVEstimation($vtb) . "_bv";

      $ttab = lc($ttab_eff);
      $nam1 = $zwisss->{'tables'}->{$ttab};
      my $out_trait = ();
      foreach $cols ( keys %{$nam1} ) {
	$out_trait = $nam1->{$cols}->{'DESCRIPTION'} if ( $nam1->{$cols}->{'DB_COLUMN'} eq $blup );
      }
      $out_trait =~ s/_/\\_/g;

      if ( $blup ne $tblup ) {
	  chdir($APIIS_HOME."/tmp");
	  open ( PESTANALYSE, ">>pestanalyse" );
	  print PESTANALYSE "\\subsubsection{Trait: $out_trait }\n\n";
	  print PESTANALYSE "{\\bf Different countig to old bve }\n\n";
	  close ( PESTANALYSE );

	  chdir($APIIS_HOME."/tmp");
	  open ( PESTANALYSE, ">>pestanalyse" );
	  print PESTANALYSE "\\begin{tabular}{cccccc}\n\n";
	  print PESTANALYSE "\\multicolumn{3}{c}{new} & \\multicolumn{3}{c}{old}\\\\\n\n";
	  print PESTANALYSE "count & avg & std & count & avg & std \\\\ \\hline \n\n";
	  close ( PESTANALYSE );

	  my $sql_d = ();
	  my @sss = ();
	  $sql_d = "select count(a." . $trait . "::numeric), to_char(avg(a." . $trait . "::numeric), '9999D99'), to_char(stddev(a." . $trait . "::numeric), '9999D99') from $ttab_data a where  a." . $trait . " notnull";
	  my $sth_d = $dbh->prepare(qq{ $sql_d }) or die $dbh->errstr;
	  $sth_d->execute;
	  while ( my $ss = $sth_d->fetch ) {
	      @sss = @$ss;
	  }
	  my $retss = join( ' & ', @sss );
	  my $sql_dd = ();
	  my @ttt = ();
	  $sql_dd = "select count(a." . $trait . "::numeric), to_char(avg(a." . $trait . "::numeric), '9999D99'), to_char(stddev(a." . $trait . "::numeric), '9999D99') from $ttab_data_old a where  a." . $trait . " notnull";
	  my $sth_dd = $dbh->prepare(qq{ $sql_dd }) or die $dbh->errstr;
	  $sth_dd->execute;
	  while ( my $tt = $sth_dd->fetch ) {
	      @ttt = @$tt;
	  }
	  my $rettt = join( ' & ', @ttt );
	  chdir($APIIS_HOME."/tmp");
	  open ( PESTANALYSE, ">>pestanalyse" );
	  print PESTANALYSE "$retss & $rettt \n\n";
	  print PESTANALYSE "\\end{tabular}\n\n";
	  print PESTANALYSE "WARNING: there are less performances in the new estimation than in the old one!\n\n" if ( $ttt[0] > $sss[0] );
	  print PESTANALYSE "WARNING: no changes between new and old estimation!\n\n" if ( $ttt[0] ==  $sss[0] and $ttt[1] == $sss[1] and $ttt[2] == $sss[2] );
	  print PESTANALYSE "\\vspace{5mm}\n\n";
	  close ( PESTANALYSE );
      } else {
	my $outblup = $tblup;
        $outblup =~ s/_/\\_/g;
	# print "++++>$outblup<++++\n";
	chdir($APIIS_HOME."/tmp");
	open ( PESTANALYSE, ">>pestanalyse" );
	print PESTANALYSE "\\subsubsection{Total breeding value: $outblup }\n\n";
	close ( PESTANALYSE );
      }

      chdir($APIIS_HOME."/tmp");
      open ( PESTANALYSE, ">>pestanalyse" );
      print PESTANALYSE "{\\bf Highest changing }\n\n";
      close ( PESTANALYSE );

      # which animals!
      my $sql_diff = ();
      if ( $opt{'t'} ) {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b, v_". $project. "_out_animal c, ". $project. "_out_animal_old d where a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull order by a." . $blup . " - b." . $blup . " desc limit $limit";
      } else {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b where a.animal = b.animal and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull order by a." . $blup . " - b." . $blup . " desc limit $limit";
      }
      my $sth_diff = $dbh->prepare(qq{ $sql_diff }) or die $dbh->errstr;
      $sth_diff->execute;
      while ( my $ss = $sth_diff->fetch ) {
	my @sss = @$ss;
	@{$animal{ $sss[0] }} = ( $sss[1], $sss[2], $sss[3] ) ;
      }
      # negative 10 abweichungen
      my $sql_diff2 = ();
      if ( $opt{'t'} ) {
	  $sql_diff2 = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b, v_". $project. "_out_animal c, ". $project. "_out_animal_old d where a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by a." . $blup . " - b." . $blup . " limit $limit";
      } else {
	  $sql_diff2 = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b where a.animal = b.animal and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by a." . $blup . " - b." . $blup . " limit $limit";
      }
      my $sth_diff2 = $dbh->prepare(qq{ $sql_diff2 }) or die $dbh->errstr;
      $sth_diff2->execute;
      while ( my $ss = $sth_diff2->fetch ) {
	my @sss = @$ss;
	@{$animal{ $sss[0] }} = ( $sss[1], $sss[2], $sss[3] ) ;
      }

      if ( $blup ne $tblup ) {
	  # allways the same output (last number give the sorting position)
	  print_table( \%animal, $trait, $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 3 );
      } else {
	  print_table( \%animal, 'NO TRAIT', $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 3 );
      }

      # highest breeding values
      chdir($APIIS_HOME."/tmp");
      open ( PESTANALYSE, ">>pestanalyse" );
      print PESTANALYSE "\n\n{\\bf Highest breeding values }\n\n";
      close ( PESTANALYSE );
      my %animal = ();
      tie %animal, 'Tie::IxHash';

      # which animals!
      my $sql_diff = ();
      if ( $opt{'t'} ) {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b, v_". $project. "_out_animal c, ". $project. "_out_animal_old d where a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by a." . $blup . " desc limit $limit";
      } else {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b where a.animal = b.animal and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by a." . $blup . " desc limit $limit";
      }
      my $sth_diff = $dbh->prepare(qq{ $sql_diff }) or die $dbh->errstr;
      $sth_diff->execute;
      while ( my $ss = $sth_diff->fetch ) {
	my @sss = @$ss;
	@{$animal{ $sss[0] }} = ( $sss[1], $sss[2], $sss[3] ) ;
      }

      if ( $blup ne $tblup ) {
	  # allways the same output (last number give the sorting position)
	  print_table( \%animal, $trait, $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 1 );
      } else {
	  print_table( \%animal, 'NO TRAIT', $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 1 );
      }

      # highest breeding values (sires)
      chdir($APIIS_HOME."/tmp");
      open ( PESTANALYSE, ">>pestanalyse" );
      print PESTANALYSE "\n\n{\\bf Highest breeding values (sires)}\n\n";
      close ( PESTANALYSE );
      my %animal = ();
      tie %animal, 'Tie::IxHash';

      # which animals!
      my $sql_diff = ();
      if ( $opt{'t'} ) {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b, v_". $project. "_out_animal c, ". $project. "_out_animal_old d, animal e where a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal and a.animal = e.db_animal and e.db_sex = ( select db_code from codes where class = 'SEX' and ext_code = '1' ) and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by a." . $blup . " desc limit $limit";
      } else {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b, animal e where a.animal = b.animal  and a.animal = e.db_animal and e.db_sex = ( select db_code from codes where class = 'SEX' and ext_code = '1' ) and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by a." . $blup . " desc limit $limit";
      }
      # print "++(I)++>$sql_diff<+++\n";
      my $sth_diff = $dbh->prepare(qq{ $sql_diff }) or die $dbh->errstr;
      $sth_diff->execute;
      while ( my $ss = $sth_diff->fetch ) {
	my @sss = @$ss;
	@{$animal{ $sss[0] }} = ( $sss[1], $sss[2], $sss[3] ) ;
      }

      if ( $blup ne $tblup ) {
	  # allways the same output (last number give the sorting position)
	  print_table( \%animal, $trait, $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 1 );
      } else {
	  print_table( \%animal, 'NO TRAIT', $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 1 );
      }

      # youngest sires breeding values
      chdir($APIIS_HOME."/tmp");
      open ( PESTANALYSE, ">>pestanalyse" );
      print PESTANALYSE "\n\n{\\bf Youngest sires breeding values}\n\n";
      close ( PESTANALYSE );
      my %animal = ();
      tie %animal, 'Tie::IxHash';

      # which animals!
      my $sql_diff = ();

      # rffr 20 youngest animals with breeding value (better only males!)
#select a.animal, a.bv1_ltz, b.bv1_ltz from hszvno_1_bv a, hszvno_1_bv_old b, hszvno_out_animal c, hszvno_out_animal_old d, animal e where a.animal = e.db_animal and e.birth_dt notnull and a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal order by age(e.birth_dt) limit 20;

      if ( $opt{'t'} ) {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b, v_". $project. "_out_animal c, ". $project. "_out_animal_old d, animal e where a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal and a.animal = e.db_animal and e.db_sex = ( select db_code from codes where class = 'SEX' and ext_code = '1' ) and e.birth_dt notnull and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by age(e.birth_dt) limit $limit";
      } else {
	  $sql_diff = "select a.animal, to_char(a." . $blup . ", '999D99'), to_char(b." . $blup . ", '999D99'), to_char(a." . $blup . " - b." . $blup . ", '999D99') as diff from $ttab_blup a, $ttab_blup_old b, animal e where a.animal = b.animal  and a.animal = e.db_animal and e.db_sex = ( select db_code from codes where class = 'SEX' and ext_code = '1' ) and e.birth_dt notnull and to_char(a." . $blup . " - b." . $blup . ", '999D99') notnull  order by age(e.birth_dt) limit $limit";
      }
      # print "++++>$sql_diff<+++\n";
      my $sth_diff = $dbh->prepare(qq{ $sql_diff }) or die $dbh->errstr;
      $sth_diff->execute;
      while ( my $ss = $sth_diff->fetch ) {
	my @sss = @$ss;
	@{$animal{ $sss[0] }} = ( $sss[1], $sss[2], $sss[3] ) ;
      }

      if ( $blup ne $tblup ) {
	  # allways the same output (last number give the sorting position)
	  print_table( \%animal, $trait, $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 1 );
      } else {
	  print_table( \%animal, 'NO TRAIT', $project, $ttab_blup, $ttab_blup_old, $ttab_data, $ttab_data_old, 1 );
      }

    }				# each blup

    chdir($APIIS_HOME."/tmp");
    open ( PESTANALYSE, ">>pestanalyse" );
    print PESTANALYSE '\clearpage';
    close ( PESTANALYSE );

  }
}

chdir($APIIS_HOME."/tmp");
open ( PESTANALYSE, ">>pestanalyse" );
print PESTANALYSE '\end{document}';
close ( PESTANALYSE );

system("mv pestanalyse pestanalyse.tex");
system( "texi2dvi --clean --quiet --pdf pestanalyse.tex" );

# system( "rm *_*.pdf" );


## S U B S ##
# get_nk( trait, table, animal )
# return @( count, avg, std )
sub get_nk {
  my $trait = shift;
  my $table = shift;
  my $anim   = shift;
  return ( 0, 0, 0 ) if ( $anim == 1 or $anim == 2 or ! $anim );
  my @nk = ();
  my $sql_nk_m = ();

  if ( $trait ne 'NO TRAIT' ) {
      $sql_nk_m = "select count(a." . $trait . "), to_char(avg(a." . $trait . "), '9999D99'),  to_char(stddev(a." . $trait . "), '9999D99') from $table a, animal b where a." . $trait . " notnull and a.animal = b.db_animal and ( b.db_sire = $anim or b.db_dam = $anim )";
  } else {
      $sql_nk_m = "select count(a.*) from $table a, animal b where a.animal = b.db_animal and ( b.db_sire = $anim or b.db_dam = $anim )";
  }
  # print "++++>$sql_nk_m<++++\n";
  my $sth_nk_m = $dbh->prepare(qq{ $sql_nk_m }) or die $dbh->errstr;
  $sth_nk_m->execute;
  while ( my $ss = $sth_nk_m->fetch ) {
      my @sss = @$ss;
      next if ( ! $sss[1] and $trait ne 'NO TRAIT' );
      @nk = ( $sss[0], $sss[1], $sss[2], );
  }
  $nk[0] = '0' if ( ! $nk[0] );
  $nk[1] = '0' if ( ! $nk[1] );
  $nk[2] = '0' if ( ! $nk[2] );
  print ".";
  return @nk;
}

sub print_table {
    my $inanimalref = shift;
    my %inanimal = %$inanimalref;
    my $trait = shift;
    my $project = shift;
    my $ttab_blup = shift;
    my $ttab_blup_old = shift;
    my $ttab_data = shift;
    my $ttab_data_old = shift;
    my $sort = shift;

    chdir($APIIS_HOME."/tmp");
    open ( PESTANALYSE, ">>pestanalyse" );
    # print PESTANALYSE '\begin{table}[htb]';
    print PESTANALYSE "\n\n{\\footnotesize"; # oder quer... ???
    print PESTANALYSE '\begin{tabular*}{\textwidth}{@{}l@{\hspace{2mm}}@{\extracolsep{\fill}}rrrcrrrrrr@{}}\hline';
    print PESTANALYSE "\n & \\multicolumn{3}{c}{\\bf BLUP} & \\multicolumn{1}{c}{\\bf EL} &
                            \\multicolumn{2}{c}{\\bf ancestors} &
                            \\multicolumn{2}{c}{\\bf pat.~half sibs } &
                            \\multicolumn{2}{c}{\\bf mat.~half sibs }\\\\ \n";
    #     print PESTANALYSE "\n & & & & & & &
    #                             \\multicolumn{2}{c}{\\bf mat. full sibs } \\\\ \n";
    print PESTANALYSE " animal & \\multicolumn{1}{c}{new}  & \\multicolumn{1}{c}{old} & \\multicolumn{1}{c}{diff} & \\multicolumn{1}{c}{n/o} & \\multicolumn{1}{c}{new} & \\multicolumn{1}{c}{old}  & \\multicolumn{1}{c}{new} & \\multicolumn{1}{c}{old} & \\multicolumn{1}{c}{new} & \\multicolumn{1}{c}{old} \\\\ \\hline \n";
    close ( PESTANALYSE );


    # which animals
    my @sortani = ();
    if ( $sort == 1 ) {
        foreach my $anii ( sort { ${$inanimal{$b}}[0] <=> ${$inanimal{$a}}[0] } keys %inanimal ) {
	    push @sortani, $anii;
	}
    } elsif ( $sort == 3 ) {
        foreach my $anii ( sort { ${$inanimal{$b}}[2] <=> ${$inanimal{$a}}[2] } keys %inanimal ) {
	    push @sortani, $anii;
	}
    } else {
        foreach my $anii ( sort keys %inanimal ) {
	    push @sortani, $anii;
	}
    }

        foreach my $ani ( @sortani ) {
	my @ext_ani = get_ext_animal( '3:sminus', 3, $ani );
	my $ext_ani = $ext_ani[0];
	$ext_ani =~ s/\|/\$\\mid\$/g;
	$ext_ani =~ s/_/\\_/g;
	# print "++++>$ani..$ext_ani<+++\n";
	chdir($APIIS_HOME."/tmp");
	open ( PESTANALYSE, ">>pestanalyse" );
	print PESTANALYSE "$ext_ani & ${$inanimal{ $ani }}[0] & ${$inanimal{ $ani }}[1] & ${$inanimal{ $ani }}[2] & ";
	close ( PESTANALYSE );


	my $sql_el = ();
	if ( $trait ne 'NO TRAIT' ) {
	    if ( $opt{'t'} ) {
		$sql_el = "select a.animal, a." . $trait . ", b." . $trait . " from $ttab_data a, $ttab_data_old b,  v_". $project. "_out_animal c, ". $project. "_out_animal_old d where a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal and a.animal = $ani limit 1";
	    } else {
		$sql_el = "select a.animal, a." . $trait . ", b." . $trait . " from $ttab_data a, $ttab_data_old b where a.animal = b.animal and a.animal = $ani";
	    }
	} else {
	    if ( $opt{'t'} ) {
		$sql_el = "select a.animal, a.animal, b.animal from $ttab_data a, $ttab_data_old b,  v_". $project. "_out_animal c, ". $project. "_out_animal_old d where a.animal = c.db_animal and c.out_animal = d.out_animal and d.db_animal = b.animal and a.animal = $ani limit 1";
	    } else {
		$sql_el = "select a.animal, a.animal, b.animal from $ttab_data a, $ttab_data_old b where a.animal = b.animal and a.animal = $ani";
	    }
	}
	my $sth_el = $dbh->prepare(qq{ $sql_el }) or die $dbh->errstr;
	$sth_el->execute;
	my $el = ();
	while ( my $ss = $sth_el->fetch ) {
	    my @sss = @$ss;
	    $el = 1 if ( $sss[1] and ! $sss[2] );
	    $el = 2 if ( ! $sss[1] and $sss[2] );
	    $el = 3 if ( $sss[1] and $sss[2] );
	}

	chdir($APIIS_HOME."/tmp");
	open ( PESTANALYSE, ">>pestanalyse" );
	print PESTANALYSE "+/+ &" if ( $el and $el == 3 );
	print PESTANALYSE "+/- &  " if ( $el and $el == 1 );
	print PESTANALYSE "-/+ &" if ( $el and $el == 2 );
	print PESTANALYSE "-/- &  " if ( ! $el );
	#       print PESTANALYSE "\$\\times\$ &  \$\\times\$ &" if ( $el == 3 );
	#       print PESTANALYSE "\$\\times\$ & &  " if ( $el == 1 );
	#       print PESTANALYSE "&  \$\\times\$ &" if ( $el == 2 );
	#       print PESTANALYSE "& &  " if ( ! $el );
	close ( PESTANALYSE );


	# hg
	my $sql_parent = ();
	if ( $opt{ 't' } ) {
	    $sql_parent = "select db_animal, db_sire, db_dam, (select b.db_animal from animal x, v_" . $project . "_out_animal a, " . $project . "_out_animal_old b where x.db_sire = a.db_animal and a.out_animal=b.out_animal and x.db_animal = $ani limit 1), (select b.db_animal from animal x, " . $project . "_out_animal a, " . $project . "_out_animal_old b where x.db_dam = a.db_animal and a.out_animal=b.out_animal and x.db_animal = $ani limit 1), (select b.db_animal from animal x, " . $project . "_out_animal a, " . $project . "_out_animal_old b where x.db_animal = a.db_animal and a.out_animal=b.out_animal and x.db_animal = $ani limit 1) from animal where db_animal = $ani limit 1";
	} else {
	    $sql_parent = "select db_animal, db_sire, db_dam from animal where db_animal = $ani";
	}
	# print "++++>$sql_parent<++++\n";
	$sth_par = $dbh->prepare(qq{ $sql_parent }) or die $dbh->errstr;
	$sth_par->execute;
	while ( my $ss = $sth_par->fetch ) {
	    my @sss = @$ss;
	    next if ( ! $sss[1] );
	    @par = ( $sss[1], $sss[2] );
	    push ( @par, ( $sss[3], $sss[4], $sss[5] ) ) if ( $opt{ 't' } );
	}
	my @hg_m = get_nk( $trait, $ttab_data, $par[0] );
	my @hg_f = get_nk( $trait, $ttab_data, $par[1] );
	my @hg_mo = ();
	my @hg_fo = ();
	if ( $opt{'t'} ) {
	    @hg_mo = get_nk( $trait, $ttab_data_old, $par[2] );
	    @hg_fo = get_nk( $trait, $ttab_data_old, $par[3] );
	} else {
	    @hg_mo = get_nk( $trait, $ttab_data_old, $par[0] );
	    @hg_fo = get_nk( $trait, $ttab_data_old, $par[1] );
	}

	# nk
	my @nk_d = get_nk( $trait, $ttab_data, $ani );
	my @nk_do = ();
	if ( $opt{'t'} ) {
	    @nk_do = get_nk( $trait, $ttab_data_old, $par[4] );
	} else {
	    @nk_do = get_nk( $trait, $ttab_data_old, $ani );
	}

	
	if ( $trait ne 'NO TRAIT' ) {
	    chdir($APIIS_HOME."/tmp");
	    open ( PESTANALYSE, ">>pestanalyse" );
	    print PESTANALYSE "$nk_d[0] ( $nk_d[1]  ) & $nk_do[0] ( $nk_do[1] ) &";
	    print PESTANALYSE "$hg_m[0] ( $hg_m[1]  ) & $hg_mo[0] ( $hg_mo[1] ) &";
	    print PESTANALYSE "$hg_f[0] ( $hg_f[1] ) & $hg_fo[0] ( $hg_fo[1] ) \\\\ \n";
	    # print PESTANALYSE "$nk_d[0] ( $nk_d[1] \$\\pm\$ $nk_d[2] ) & $nk_do[0] ( $nk_do[1] \$\\pm\$ $nk_do[2] ) &";
	    # print PESTANALYSE "$hg_m[0] ( $hg_m[1] \$\\pm\$ $hg_m[2] ) & $hg_mo[0] ( $hg_mo[1] \$\\pm\$ $hg_mo[2] ) \\\\ ";
	    # print PESTANALYSE " & & & & & & & $hg_f[0] ( $hg_f[1] \$\\pm\$ $hg_f[2] ) & $hg_fo[0] ( $hg_fo[1] \$\\pm\$ $hg_fo[2] ) \\\\ \n";
	    close ( PESTANALYSE );
	} else {
	    chdir($APIIS_HOME."/tmp");
	    open ( PESTANALYSE, ">>pestanalyse" );
	    print PESTANALYSE "$nk_d[0]  & $nk_do[0]  &";
	    print PESTANALYSE "$hg_m[0]  & $hg_mo[0]  &";
	    print PESTANALYSE "$hg_f[0]  & $hg_fo[0]  \\\\ \n";
	    close ( PESTANALYSE );
	}
    }

    chdir($APIIS_HOME."/tmp");
    open ( PESTANALYSE, ">>pestanalyse" );
    print PESTANALYSE "\\hline \n\\end{tabular*}\\\\[0.6ex]\n";
    print PESTANALYSE 'each entry represent the count of observations ( average )}'; #$\pm$ standarddeviation )}';
    # print PESTANALYSE "\n\\end{table}\n\n";
    close ( PESTANALYSE );
}

sub write_tex_header {
  my $filename = shift;
  chdir($APIIS_HOME."/tmp");
  open ( $filename, ">$filename" );
  print $filename ('\documentclass[10pt,a4paper,DIV16,pdftex]{scrartcl}
%\usepackage{german}
\usepackage[english]{babel}
\usepackage[latin1]{inputenc}
%\usepackage[latin1,latin2,latin3]{inputenc}
\usepackage{multicol}
\usepackage[pdftex]{graphicx}
\usepackage{wasysym} % some symbols \male...
\usepackage{longtable}
\usepackage{color}
\usepackage{colortbl}
\usepackage{graphicx}
\usepackage{fancyhdr}
\usepackage{dcolumn}

\pagestyle{fancy}
\rhead{ breeding value estimation from \today}
\cfoot{\thepage}

%\pagestyle{empty}
\parindent0mm

\begin{document}

');
  close ( $filename );
}

ERR:
if ($opt{'a'}) {
  if ( $apiis->errors ) {
    $_->print for $apiis->errors;
  }
}

###############################################################################
sub ReadPestErg {
  ###############################################################################
  my $vfile = shift;
  use CalcTBV;

  #####################################################
  # Einlesen der Zuchtwerte, Zerhacken des LST-Files
  #####################################################
  %hs_effekte=(); my %pmodel=();
  eval {
    open (i_file,$vfile) || die "Datei $vfile nicht gefunden";
  };
  if (! $@) {
    (@ar_datum)=localtime((stat($vfile))[9]);
    $sc_datum=($ar_datum[3]+1).'.'.($ar_datum[4]+1).'.'.($ar_datum[5]+1900);
    $skip=0;$counter=0;$block=0;$match='M o d e l';

    #--- Schleife über alle Datensätze
    my $c=0;
    $hs_statistik={};
    while (<i_file>) {
      chop;
      if ($skip>0) {
        $skip--;
        next;
      }
      if ($_=~/__________/) {
        $block='';
	next;
      }	

      if ($_=~/G e n e r a l  I n f o r m a t i o n/) {
        $block='GI';
        $skip=2;
        next;
      } elsif ($_=~/R u n  T i m e  I n f o r m a t i o n/) {	
        $block='TI';
        $skip=1;
        next;
      } elsif ($_=~/D a t a  F i l e  I n f o r m a t i o n/) {	
        $block='DI';
        $skip=4;
        next;
      } elsif ($_=~/R E L A T I O N S H I P  I n f o r m a t i o n/) {	
        $block='RI';
        $skip=1;
        next;
      } elsif ($_=~/S O L V E R  I n f o r m a t i o n/) {	
        $block='SI';
        $skip=4;
        next;
      } elsif ($_=~/M o d e l  I n f o r m a t i o n/) {	
        $block='MI';
        $skip=3;
        next;
      } elsif ($_=~/Covariances/) {	
        $match='\s+('.join('|',keys %hs_effekte).')\s+'.join('\s+',@ar_fields);
        $block=0;
        next;
      } elsif ($_=~/$match/) {
        $self->{estimations}->{$valias}->{statistik}=$hs_statistik;
        $block=3;
        @temp=split('\s+',$_);
        $effekt_name=$temp[1];
        $skip=1;
        next;
      } elsif (($_=~/\+\+\+\+\+\+/) or ($_=~/^\s*$/) or ($_=~/^\s+$/) or ($_=~/\.{30}/)) {
        next;
      }

      if ($block eq 'GI') {
        if ($_=~/equations        :\s+(\S+)/) {
          $hs_statistik->{'GI'}->{'dim_equ'}=$1;
	} 
        if ($_=~/nonzero elements :\s+(\S+)/) {
          $hs_statistik->{'GI'}->{'rank_equ'}=$1;
	}  
        if ($_=~/data records     :\s+(\S+)/) {
          $hs_statistik->{'GI'}->{'data_rec'}=$1;
	}  
      } elsif ($block eq 'DI') {
        my @a=split('\s+',$_);
	push(@{$hs_statistik->{'DI'}->{'traits'}},$a[1]);
	push(@{$hs_statistik->{'DI'}->{'n'}},$a[2]);
	push(@{$hs_statistik->{'DI'}->{'mw'}},$a[3]);
	push(@{$hs_statistik->{'DI'}->{'sa'}},$a[4]);
	push(@{$hs_statistik->{'DI'}->{'vc'}},$a[5]);
	push(@{$hs_statistik->{'DI'}->{'mi'}},$a[6]);
	push(@{$hs_statistik->{'DI'}->{'ma'}},$a[7]);
      } elsif ($block eq 'RI') {
        if ($_=~/number of genetic groups   :\s+(\S+)/) {
          $hs_statistik->{'RI'}->{'gen_groups'}=$1;
	} 
        if ($_=~/number of animals          :\s+(\S+)/) {
          $hs_statistik->{'RI'}->{'nr_animal'}=$1;
	}  
        if ($_=~/animals \+ groups:\s+(\S+)/) {
          $hs_statistik->{'RI'}->{'nr_total'}=$1;
	}  
      } elsif ($block eq 'MI') {
        ($_)=($_=~/^\s+(\S.*)/);
        @ar_fields=split('\s+',$_);
        $hs_statistik->{'MI'}->{'traits'}=\@ar_fields;
        $block='MI2';
	$pmodel{ 0 } = [@ar_fields];
        next
      } elsif ($block eq 'MI2') {
        my @a=split('\s+',$_);
	my @b = @a;
	shift @b;
	my $mypos = shift @b;
	$pmodel{ $mypos } = [@b];

	push(@{$hs_statistik->{'MI'}->{'effects'}},$a[2]);
	push(@{$hs_statistik->{'MI'}->{'f'}},$a[2]) if ($a[3] eq 'F');
	push(@{$hs_statistik->{'MI'}->{'r'}},$a[2]) if ($a[3] eq 'R');
	push(@{$hs_statistik->{'MI'}->{'c'}},$a[2]) if ($a[3] eq 'C');
	push(@{$hs_statistik->{'MI'}->{'a'}},$a[2]) if ($a[3] eq 'A');
   
        for (my $i=5;$i<=$#a;$i++) {
          push(@{$hs_statistik->{'MI'}->{$a[2]}},$ar_fields[$i-5]) if ($a[$i] eq 'x');
        }	
        @temp=(split('\s+',$_));
        $t=$temp[2];

        #sehr spezifisch LM(GVML) -> LM.GVML und LM*GVML und LM.*.GVML
        $t=~s/\./\.\*\./;

        $hs_effekte{$t}=[splice(@temp,5,$#temp)];
        next;
      } elsif ($block eq '3') {
        @zw=();@se=();
        next if ($_=~/^\s{20}/);
        next if ($_=~/\<\sPEST\s\>/);
        next if ($_=~/\.\.\.PEST/);
        next if ($_=~/\^L/);


        foreach $x (@{$hs_effekte{$effekt_name}}) {
          if ($x eq 'x') {
	    push(@dat,shift(@zw1));
	    push(@field,$vorsatz.$valias."_".$ar_fields[$l]);
          }
          $l++;
	}
	close (i_file);
      }
    }
  }
  return ( $hs_statistik, \%pmodel );
}




__END__

=pod

=head1 NAME

after_pest.pl

=head1 ABSTRACT

this script analyze the output from the PEST run, which are written in
a temporary database (see Ulf).

first get little statistic of fixed effects. should help you to find
effects with only a few memebers which could not be good estimated by
PEST. to analyze this further and merge some effects you have to more
information about what the neighbor could be and therefore this
couldn't be implemented here.

for covariables you get here an histogramm. help you to find values
out of normal range. have in mind that the whole range have to fit to
the function you describe for this covariable.

the third part handle with differences between different breeding
value estimations and can use to compare the results of different
models or old ones with newer ones. here you get information for the
20 highest changed breeding values for each trait and give an idea
what informations come along.

=head1 USAGE

after_ped.pl <options>

=head2 OPTIONS

=head3 -a

use APIIS not mysql. last one means independent from the
APIIS-software.

=head3 -m

name of modelfile.

=head3 -p <project_name>

project name

=head3 -u <database user>

name of the database user. only together with option -w. else the
script will ask you about this informations.

=head3 -w <databse pwd>

password for the given user (option -u).

=head3 -o

not analyse the changing of breeding values.

=head3 -t

use different animal-ids from successive PEST-runs if the
datamanipulation are always trough APIIS. this option require the
loading from file ext_id_db_id.txt after each apiis run. (the file
contain the whole concatenated animal-ids together with the used
internal db_animal)

using this option no other internal effects could be evaluated (such
as closed codes....)

=head1 ToDo

some informations from the solver section to get a idea about the
stopping criterion...

analyse of PEV if solver SMP is used

=cut



