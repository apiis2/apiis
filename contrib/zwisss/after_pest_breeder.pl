#!/usr/bin/env perl
############################################################
# after_pest_breeder.pl
# usage: after_pest_breeder.pl
#  -a use apiis not mysql (only apiis finished so far)
#  -m <> modelfile
#  -p <> project
#  -u <> database user
#  -w <> database password
#  -e create output also for timedependent effects
#  -z <> array of breedernames (else all breeder with traits)
############################################################

BEGIN {
  use Env qw( APIIS_HOME );
  die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
  push @INC, "$APIIS_HOME/lib";
  push @INC, "$APIIS_HOME/contrib/zwisss";
}
use Apiis;
Apiis->initialize( VERSION => '$Revision: 1.6 $ ');
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

getopts('eafm:r:p:u:w:z:',\%opt) || die "Keine gültige Option";

# use strict;
use Date::Manip;
use FileHandle;
use Data::Dumper;
use Tie::IxHash;
use DBI;
use ref_breedprg_alib;
use Statistics::Descriptive;

my($zwisss,$zwisssb,$c,@b,@traits,%input);
my ($tr);
my $limit = 10; # half number of highest changed bv
my $myclass = 'BREED'; # class for breeds in table codes

$|=1;
if (! $opt{'m'}) {
   print "Kein Modell spezifiziert\n";
   exit 0;
}
if (! $opt{'p'}) {
   print "Kein Project spezifiziert\n";
   exit 0;
}

my $project = $opt{'p'};
# my $modell=File::Basename::basename($opt{'m'},qr{'\.model'});
# $modell=~s/\.model//;

#--- postgres (apiis) oder mysql-Modus
if ( $opt{'a'} ) {
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
my $dbh = $apiis->DataBase->dbh;

#--- Basisverzeichnis ermitteln und als local setzen
$zwisss->SetLocal($ENV{'PWD'});

#--- Optionen übergeben
$zwisss->SetOpt(\%opt);

$zwisss->SetDebugModus('1');

#--- Zuchtwertschätzung; zws-Modelfile (Option -m) wird eingelesen
$zwisssb=$zwisss->ReadZwisssParameterFile();

my $vtb_ref=$zwisss->GetTBVS();
my $model=$zwisss->GetVerband();

my $anz_bars = 12;		# 12 quartals for three years...
$anz_bars = $anz_bars -1;       # starting by 0
my $use_external_values = 1;    # if external code used in modelfile

my @breeder = ();
if ( $opt{'z'} ) {
  @breeder = split(' ', $opt{'z'} );
} else { # all breeders
  ## get breeder
  my $sql = "select distinct db_breeder from animal where birth_dt notnull and db_breeder notnull";

  my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
  $sth->execute;
  while ( my $ss = $sth->fetch ) {
    my @sss = @$ss;
    my $breeder_1 = $sss[0];
    push @breeder, $breeder_1;
  }
}

foreach my $breeder ( @breeder ) {
  write_tex_header( $breeder );

  $out_breeder = get_ext_val( $breeder, 'db_unit', $table );
  open ( $breeder, ">>$APIIS_HOME/tmp/$breeder" );
  print $breeder "\\section{Genetic trends ";
  print $breeder "and timedependent effects " if ( $opt{ 'e' } );
  print $breeder "for breeder: $out_breeder}\n\n";
  print $breeder "\n\n";
  close ( $breeder );
}

my $zahl = ();

foreach my $vtb ( sort keys %{$zwisss->GetTBVS()} ) {
  my ($wi, $traits_ref, $traits_rel_ref)=$zwisss->GetTraitsTBV($vtb);
  ($traits_ref, $traits_rel_ref)=$zwisss->GetTraitsEFF($vtb);
  next if ( ! $zwisss->GetTBVEstimation($vtb) ); #or $zwisss->GetTBVEstimation($vtb) ne $ret_vtb );
  my $table_no = $zwisss->GetTBVEstimation($vtb);

  my $out_trait = ();
  my $bv = ();

  foreach $tr ( @$wi ) {
    my @lines_g = ();
    my @lines_garg = ();
    next if ( ! $tr );
    my $ttab = lc($model). "_" . $table_no. "_bv";
    $ttab = uc($ttab);
    $nam1 = $zwisss->{'tables'}->{$ttab};
    foreach $cols ( keys %$nam1 ) {
	$out_trait = $nam1->{$cols}->{'DESCRIPTION'} if ( $nam1->{$cols}->{'DB_COLUMN'} eq $tr );
    }
    $out_trait = $tr if ( ! $out_trait );
    map { s/_/\\_/g; } $out_trait if ( $out_trait !~ /\\_/ );

    my $first = ();
    if ( $opt{ 'e' } ) {

      foreach $time_eff ( @{$zwisss->{'tbvs'}->{$vtb}->{'timedep_effects'}} ) {
	@t_eff = @$time_eff;

	my $effect_class = uc($t_eff[0]);
	my $effect_table = lc($model). "_" . $table_no. "_effects";
	# my $effect_table = 'mszv_1_effects';
	my $effect_farm = $t_eff[1]; #'^(.+?)\|.*$';
	my $effect_time = $t_eff[2]; #'^.*?\|(.*)$';
	my $tr_eff = $tr;
	$tr_eff =~ s/^bv/ef/g;

	my $sql_eff = "select effect, $tr_eff from $effect_table where effect_class = '$effect_class' and $tr_eff notnull";

	# print "sql>>$sql_eff<<\n";
	my %effects = ();
	my %effects_t = ();
	my %effects_tb = ();
	my %effects_b = ();

	my $sth_eff = $dbh->prepare(qq{ $sql_eff }) or die $dbh->errstr;
	$sth_eff->execute;
	#    my @eff = ();
	while ( my $ss = $sth_eff->fetch ) {
	  my @sss = @$ss;
	  next if ( ! $sss[1] );
	  my $eff_1 = $sss[0];
	  my $breeder_eff = $eff_1;
	  $breeder_eff =~ s/$effect_farm/$1/g;
	  my $time_eff = $eff_1;
	  $time_eff =~ s/$effect_time/$1/g;
	  push @{$effects{ 'all' }} , $sss[1];
	  push @{$effects_t{ $time_eff }} , $sss[1];
	  push @{$effects_tb{ $breeder_eff }{ $time_eff }} , $sss[1];
	  push @{$effects_b{ $breeder_eff }} , $sss[1];
	}
	next if ( $#{$effects{ 'all' }} == -1 );

	my @dat_y = (); my @dat_e = ();
	for my $eff ( sort keys %effects_t ) {

	  my   $stat = Statistics::Descriptive::Full->new();
	  $stat->add_data(@{$effects_t{$eff}});
	  my   $ct=$stat->count();
	  my   $mw=sprintf("%.2f", $stat->mean()) if $ct ne 0;
	  push @dat_y, $eff;
	  push @dat_e, $mw;

	  # my   $mn=$stat->min();
	  # my   $mx=$stat->max();
	  # my   $vr=sprintf("%.2f",$stat->variance());
	  # my   $std=sprintf("%.2f", sqrt($vr));
	  # my   $u = $mw - $range*$std if $ct ne 0;
	  # my   $o = $mw + $range*$std if $ct ne 0;
	  # my   $med=sprintf("%.2f", $stat->median());
	  # my   $perc=$stat->percentile($v);
	  # my   $perca=$stat->percentile($b);
	}

	# anzahl der balken begrenzen
	splice ( @dat_y, 0, $#dat_y - $anz_bars  );
	splice ( @dat_e, 0, $#dat_e - $anz_bars  );

	foreach $breeder ( @breeder ) {
	  # breeder ne testlocation because different class in unit (how
	  # to solve?) probably same db_naming (but this is not so in sn)
	  my $breeder_comp = ();
	  my $out_breeder = get_ext_val( $breeder, 'db_unit', $table );

	  # $breeder_comp = $breeder; # same as in hys my $sql_testloc
	  # if used ext_id for breeder coding this have to changed to
	  # generally stuff!!
 	  my $sql_testloc = "select ext_id from unit a where db_unit = $breeder";
	  # print ">>-->>$sql_testloc<<--<<\n";
	  my $sth_testloc = $dbh->prepare(qq{ $sql_testloc }) or die $dbh->errstr;
	  $sth_testloc->execute;
	  while ( my $ss = $sth_testloc->fetch ) {
	    my @sss = @$ss;
	    $breeder_comp = $sss[0];
	  }

	  my @dat_f_y = (); my @dat_f_e = ();
	  for my $eff2 ( sort keys %effects_tb ) {
	    next if ( $eff2 ne $breeder_comp );
	    for my $eff3 ( sort keys %{$effects_tb{ $eff2 }} ) {
	      push @dat_f_y, $eff3;
	      push @dat_f_e, ${$effects_tb{$eff2}{$eff3}}[0];
	      #  print "++++>$eff3=>@{$effects_tb{$eff2}{$eff3}}<++++\n";
	    }
	  }

	  next if ( ! @dat_f_y );
	  map { s/\|/\./g } @dat_y;
 	  map { s/\|/\./g } @dat_f_y;

	  my $r_out_breeder = $out_breeder;
	  $r_out_breeder =~ s/\\//g;
	  my $r_out_trait = $tr_eff;
	  my $out_trait = $tr_eff;
	  $r_out_trait =~ s/\\//g;
	  $r_out_trait =~ s/^....//g;
	  $out_trait =~ s/^....//g;
	  $out_trait =~ s/_/\\_/g;

	  my %parameter_hash = (
				filename => $APIIS_HOME . '/tmp/' . $breeder . '_' . $tr_eff,
				sql      => '',
				no_sql_elements => '',
				data => [ \@dat_y, \@dat_e, \@dat_f_y, \@dat_f_e],
				legend        => ['all farms', "farm: $r_out_breeder"],
				second_y_axis => 'no',
				export_format => 'pdf',
				chart_type => 'barplot_lines', #'barplot',
				chart_type2 => 'b',
				titel      => '"BLUE values of effect ' . $effect_class . ' for trait ' . $r_out_trait . '"',
				subtitel   => '"' . $r_out_breeder . '"',
				xlabel     => '"Years"',
				ylabel     => '"Average Breeding Values"',
				mtext_l    => '', # additional text
				mtext_r    => '',
				color      => 'yes',
				x_dates    => 'no'
			       );

	  $status = r_plot( \%parameter_hash );
	  print "$status\n";
	  $first = 1;
	  $bv ++;

	  open ( $breeder, ">>$APIIS_HOME/tmp/$breeder" );
 	  print $breeder "\\subsection{Breeding value estimation $vtb}\n\n" if ( $bv == 1 );
 	  print $breeder "\\subsubsection{Trait: $out_trait}\n\n";
	  print $breeder "\\includegraphics[width= 150mm]{$args{ filename }} \n\n";
	  close ( $breeder );
	}			# each breeder

	#    push @breeder, $breeder_1;
      }
    }				# opt e

    # for all genotypes
    foreach $for_groups ( @{$zwisss->{'tbvs'}->{$vtb}->{'for_breeds'}} ) {
      ## rffr
      my $sql = ();
      my $class = $myclass;
      my $internal_for_groups = ();
      if ( $use_external_values == 1 ) {
	  $internal_for_groups = get_db_code($for_groups, $class);
	if ( ! $internal_for_groups ) {
	    print "WARNING: breed $for_groups not defined in table codes!\n";
	    next;
	}
	# print "+++*>$for_groups..$class=>$internal_for_groups<++++\n";
	$sql = "select date_part('year', b.birth_dt::date) as year, avg(". $tr .") from " .lc($model). "_" . $table_no. "_bv a, animal b where a.animal = b.db_animal and b.db_breed = " . $internal_for_groups . "  and b.birth_dt notnull group by year order by year";

      } else {
      $out_breed = get_ext_val( $for_groups, 'db_code', $table );

      $sql = "select date_part('year', b.birth_dt::date) as year, avg(". $tr .") from " .lc($model). "_" . $table_no. "_bv a, animal b where a.animal = b.db_animal and b.db_breed = " . $for_groups . "  and b.birth_dt notnull group by year order by year";
    }

      my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
      $sth->execute;
      my ( @dat_ges_v, @dat_ges_y ) = ();
      while ( my $ss = $sth->fetch ) {
	my @sss = @$ss;
	push @dat_ges_y, $sss[0];
	push @dat_ges_v, $sss[1];
      }
      next if ( ! @dat_ges_y  );
      # push @lines_g, \@dat_ges_y;
      # push @lines_g, \@dat_ges_v;
      @dat_ges_v_sich = @dat_ges_v;
      @dat_ges_y_sich = @dat_ges_y;
      #  dadurch ist aber nur EIN genotyp mgl! :-(
      # @lines_g = ( [ @dat_ges_y ], [ @dat_ges_v ] );
      push @lines_garg, $out_breed;
    }
    map { $_ = 'population breed: ' . $_ } @lines_garg;

    foreach $breeder ( @breeder ) {
      @lines_g = ( [ @dat_ges_y_sich ], [ @dat_ges_v_sich ] );
      $out_breeder = get_ext_val( $breeder, 'db_unit', $table );
      my @lines = ();
      my @lines_arg = ();
      foreach $for_groups (@{$zwisss->{'tbvs'}->{$vtb}->{'for_breeds'}}) {
      if ( $use_external_values == 1 ) {
	  my $class = $myclass;
	  $out_breed = $for_groups;
	  $internal_for_groups = get_db_code($for_groups, $class);
	if ( ! $internal_for_groups ) {
	    print "WARNING: breed $for_groups not defined in table codes!\n";
	    next;
	}
      } else {
	  $internal_for_groups = $for_groups;
	  $out_breed = get_ext_val( $for_groups, 'db_code', $table );
      }

	my $sql_breeder = "select date_part('year', b.birth_dt::date) as year, avg(". $tr .") from " .lc($model). "_" . $table_no . "_bv a, animal b where a.animal = b.db_animal  and db_breed = " . $internal_for_groups . " and b.birth_dt notnull and b.db_breeder = $breeder group by year order by year";

	my $sth_b = $dbh->prepare(qq{ $sql_breeder }) or die $dbh->errstr;
	$sth_b->execute;
	my ( @dat_betr_v, @dat_betr_y ) = ();
	while ( my $ss = $sth_b->fetch ) {
	  @sss = @$ss;
	  push @dat_betr_y, $sss[0];
	  push @dat_betr_v, $sss[1];
	}
	next if ( ! @dat_betr_y ); # $#dat_betr_y == 0 );
	push @lines, \@dat_betr_y;
	push @lines, \@dat_betr_v;
	push @lines_arg, $out_breed;
      }

      @lines_out = ();
      next if ( $#lines eq '-1' );   # rffr # ! @lines ## rffr ##
      #      my $ttemp_out = $#lines;
      push @lines_out, @lines_g;
      push @lines_out, @lines;

      map { $_ = 'breeder: ' . $out_breeder  . ' breed: ' . $_ } @lines_arg;

      my $out_trait = ();
      $nam1 = $zwisss->{'tables'}->{$ttab};
      foreach $cols ( keys %$nam1 ) {
	  $out_trait = $nam1->{$cols}->{'DESCRIPTION'} if ( $nam1->{$cols}->{'DB_COLUMN'} eq $tr );
      }
      $out_trait = $tr if ( ! $out_trait );
      map { s/_/\\_/g; } $out_trait if ( $out_trait !~ /\\_/ );


      my $r_out_breeder = $out_breeder;
      $r_out_breeder =~ s/\\//g;
      my $r_out_trait = $out_trait;
      $r_out_trait =~ s/\\//g;
      my $tex_out_trait = $out_trait;
      $tex_out_trait =~ s/^.....//g;


      my %parameter_hash = (
			    filename =>  $APIIS_HOME . '/tmp/' . $breeder . '_' . $tr,
			    sql      => '',
			    data => [ @lines_out ],
			    no_sql_elements => '',
			    legend        => [@lines_garg, @lines_arg],
			    second_y_axis => 'no',
			    export_format => 'pdf',
			    chart_type => 'b', #'barplot',
			    chart_type2 => 'b',
			    titel      => '"estimated breeding values of all animals with given birth dates"',
			    subtitel   => '"' . $r_out_trait . '"',
			    xlabel     => '"Years"',
			    ylabel     => '"Average Breeding Values"',
			    mtext_l    => '', # additional text
			    mtext_r    => '',
			    color      => 'yes',
			    x_dates    => 'no'
			   );

      $status = r_plot( \%parameter_hash );
      print "$status\n";
      $bv ++;

      open ( $breeder, ">>$APIIS_HOME/tmp/$breeder" );
      print $breeder "\\subsection{Breeding value estimation $vtb}\n\n" if ( $bv == 1 and ! $first );
      print $breeder "\\subsubsection{Trait: $tex_out_trait}\n\n" if ( ! $first );
      print $breeder "\\includegraphics[width= 150mm]{$args{ filename }} \n\n";
      close ( $breeder );
    }
  }

  #   my $estimation=$zwisss->GetTBVEstimation($vtb);
  #   my ($mw, $stdabw)=$zwisss->GetStandardisation($vtb);
  #   my $modus=$zwisss->GetWiRelModus($vtb);
  #   $modus=$zwisss->GetTBVSEModus($vtb);
  #   $modus=$zwisss->GetBVSEModus($vtb);
}

foreach my $breeder ( @breeder ) {
  open ( $breeder, ">>$APIIS_HOME/tmp/$breeder" );
  print $breeder '\end{document}';
  close ( $breeder );
  chdir "$APIIS_HOME/tmp/";
#  system( "cd $APIIS_HOME/tmp/" );
  system( "mv $breeder $breeder.tex" );
  system( "texi2dvi --clean --quit --pdf $breeder.tex" );
#  system( "cd -" );
}

# system( "rm *_*.pdf" );


# ## S U B S ##

sub get_db_code {
  my $extcode = shift;
  my $class = shift;
  my $sql = "select db_code from codes where ext_code = \'$extcode\' and class = \'$class\'";
  my @sss = ();

  my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
  $sth->execute;
  while ( my $ss = $sth->fetch ) {
    @sss = @$ss;
  }
  return( $sss[0] );
}

sub write_tex_header {
  my $filename = shift;
  open ( $filename, ">$APIIS_HOME/tmp/$filename" );
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

### S U B S ###
__END__

=pod

=head1 NAME

after_pest_breeder.pl

=head1 ABSTRACT

the script can be used to give to the special breeder some more
information after PEST run. first he get for all breeding value
estimations where he have animals involved the genetic trends in
comparison of the whole population.

second give a chart to inform about the changing of timedependent
fixed effects (like herd year season) for this breeder. hopefully this
could be used for management decisions, bacause the BLUE values
are independent from the genetic level of the animals on the farm.

=head1 USAGE

after_ped_breeder.pl <options>

=head2 OPTIONS

=head3 -a

use APIIS not mysql. last one meens independent from the
APIIS-software. 

=head3 -m

name of modelfile.

=head3 -p <project_name>

project name

=head3  -u <database user>

name of the database user. only together with option -w. else the
script will ask you about this informations.

=head3 -w <databse pwd>

password for the given user (option -u).

=head3 -e

create output also for timedependent effects. need parametrisation in
modelfile. there we need the name of the effect used by PEST and
regular expressions for spliting the farm and the time part of the effect.

ex:

#  in %TBVS for the wanted breeding value estimation

    timedep_effects => [

#                         effect   farm           time

			[ "BJQ", '^(.+?)\|.*$', '^.*?\|(.*)$' ],

			[ "SJM", '^(.+?)\|.*$', '^.*?\|(.*)$' ]

			],

=head3 -z

array of breeder identification. else all possible breeders are calculated.

=cut
