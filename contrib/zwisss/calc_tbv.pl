#!/usr/bin/env perl
##########################################################################
# -i: wenn apiis und 



BEGIN {
   use Env qw( APIIS_HOME );
   die "\n\tAPIIS_HOME is not set!\n\n" unless $APIIS_HOME;
   push @INC, "$APIIS_HOME/lib";
}
use lib "$APIIS_HOME/contrib/zwisss";
use strict;
use warnings;
use Apiis;
use Getopt::Std;
use File::Basename;
use Date::Manip;
use Term::ReadKey;
use CalcTBV;
use Apiis::DataBase::User;

my($a, $b, $c, @b, @traits, %input, %opt, $user_obj);
our ($dbh);
getopts('afp:dbr:cm:o:e:l:w:u:i',\%opt) || die "Keine gültige Option";

if ($opt{'a'}){
  Apiis->initialize( VERSION => '$Revision: 1.10 $' );
}

$|=1;

#my $thisproject = $ARGV[0];
#my $proj_apiis_local = $apiis->project($thisproject);
#$apiis->APIIS_LOCAL($proj_apiis_local);
#my $xml_file = $apiis->APIIS_LOCAL."/etc/".$thisproject.'.xml';
#my $model_file = $apiis->APIIS_LOCAL."/etc/".$thisproject.'.model';

if (! $opt{'m'}) {
   print "Kein Zuchtwertschätzmodell spezifiziert\n";
   exit 0;
}   
my $projekt=File::Basename::basename($opt{'m'},qr{'\.model'});
$projekt=~s/\.(model|tbv)$//;

#--- postgres (apiis) oder mysql-Modus
if ($opt{'a'}){
  $apiis->APIIS_LOCAL($apiis->{_projects}{$opt{'l'}});
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

  $apiis->join_model($opt{'l'}, userobj => $user_obj); 
  goto ERR if ($apiis->status);


  $a=ZwsApiis->new(lc($projekt),$apiis);
} else {
  $a=CalcTBV->new(lc($projekt));
}
$a->SetParameter('a',$opt{'a'});

#--- Parameterfile für zws setzen
$a->SetTbvParameterFile($opt{'m'});

#--- Basisverzeichnis ermitteln und als local setzen
$a->SetLocal($ENV{'PWD'});

#--- Optionen übergeben
$a->SetOpt(\%opt);

$a->SetDebugModus('1');
#--- Schleife über alle Parameterfiles, Parsen der Informationen und Schreiben in den Hash
if ($opt{'r'}){
  foreach (split("[ |,|;]",$opt{'r'})) {
    $b=$a->ParsePestParameter($_);
  }
  if ($opt{'c'}) {
    $b=$a->WriteZwisssParameterFile($opt{'m'}) if ($opt{'c'});
    exit 0;
  }
}

#--- Zuchtwertschätzung; zws-Modelfile (Option -m) wird eingelesen
$b=$a->ReadZwisssParameterFile();

my $vtb_ref=$a->GetTBVS();
my $model=$a->GetVerband();

foreach my $vtb (sort keys %{$a->GetTBVS()}) {
  my ($wi, $traits_ref, $traits_rel_ref)=$a->GetTraitsTBV($vtb);
  ($traits_ref, $traits_rel_ref)=$a->GetTraitsEFF($vtb);
  my $estimation=$a->GetTBVEstimation($vtb);
  my ($mw, $stdabw)=$a->GetStandardisation($vtb);
  my $modus=$a->GetWiRelModus($vtb);
  $modus=$a->GetTBVSEModus($vtb);
  $modus=$a->GetBVSEModus($vtb);
} 

#--- Steuerung der Zuchtwertschätzugen
$b=$a->SetAlias();
if ($opt{'p'}){
  $a->SetMaxParalleleJobs($opt{'p'});
  $b=$a->PestStarten();
}




#--- Datenbank anlegen und Einlesen des Pedigrees und der Daten für alle angegebenen Parameterfiles
#
$a->SetDBH();
if (($opt{'r'}) and ($opt{'d'})) {
  $b=$a->CreateDB();

  if (($opt{'a'}) or ($opt{'i'})) {

    # old
    # this step require an additionally line in runall.pl (line 26)
    # system('mv ext_id_db_id.txt ext_id_db_id.txt_old'); # save the old one
    #                                                     # for using always
    #                                                     # APIIS to prepare
    #                                                     # data for the bve

    my  @datao=();
    if ( -f $apiis->APIIS_LOCAL."/initial/ext_id_db_id.txt_old") {
    	open( MYIN, "<".$apiis->APIIS_LOCAL."/initial/ext_id_db_id.txt_old" ) or die "Cannot open: ext_id_db_id.txt_old";
    	@datao    = <MYIN>;
    	close(MYIN);
    }

    my $countero = 1;
    if ( $countero == 1 ) {
      my $sqla = "create table " . $opt{'l'} . "_out_animal_old (
                           out_animal text, db_animal int4
                )";
      $a->Execute($sqla,"");
    }
    foreach my $line (@datao) {
      my @line = split( ':', $line );

      my @subline = split( '--', $line[1] );
      my $statement = "insert into " . $opt{'l'}
      . "_out_animal_old ( out_animal, db_animal ) values ( '$line[0]', $subline[0] )";

      $a->Execute($statement,"");
      print "."              unless $countero % 100;
      print " => $countero\n" unless $countero % 1000;
      $countero++;
    }
    print "\n... => end ( $countero )\n\n";

    # actually
    my @data=();
    if (-f $apiis->APIIS_LOCAL."/initial/ext_id_db_id.txt") {
    	open( MYIN, "<".$apiis->APIIS_LOCAL."/initial/ext_id_db_id.txt" ) or die "Cannot open: ext_id_db_id.txt";
    	@data    = <MYIN>;
    	close(MYIN);
    }

    my $counter = 1;
    if ( $counter == 1 ) {
      my $sqla = "create table " . $opt{'l'} . "_out_animal (
                           out_animal text, db_animal int4
                )";
      $a->Execute($sqla,"");
    }
    foreach my $line (@data) {
      my @line = split( ':', $line );

      my @subline = split( '--', $line[1] );
      my $statement = "insert into " . $opt{'l'}
      . "_out_animal ( out_animal, db_animal ) values ( '$line[0]', $subline[0] )";
  
      $a->Execute($statement,"");
      print "."              unless $counter % 100;
      print " => $counter\n" unless $counter % 1000;
      $counter++;
    }
    print "\n... => end ( $counter )\n\n";

  }

  #--- nicht wenn apiis
  $b=$a->ReadWriteRelationship();

  foreach my $par (split("[ |,|;]",$opt{'r'})) {
    if ($par=~/^\//) {
      $c=chdir(File::Basename::dirname($par));
    } else {
      $c=chdir($a->GetLocal()."/".File::Basename::dirname($par));
    }
    $a->ReadDataPest($par);
    $a->ReadBvPest($par);
    $c=chdir($a->GetLocal());
  }
}

if ($opt{'b'}){
  foreach (sort keys %{$a->GetTBVS()}) {
    $b=$a->Relativierung($_);
    $b=$a->Save($_);
  }
}

# $a->CreateNewPest();

if ($opt{'e'}){
  foreach (split(' ',$opt{'e'})) {
    $b=$a->Export($_);
  }
}


ERR:
if ($opt{'a'}){
  if ( $apiis->errors ) {
    $_->print for $apiis->errors;
  }
}

__END__
ToDo:
- genet. Gruppen erkennen und auf '' setzen
- Beim Tabelle erstellen müssen zusützliche Merkmale bekannt sein, STruktur wird angelegt, befüllt über update, wenn
entsprechende Tabelle dran ist.

- DESTINATION wird als Feld in der betreffenden Tabelle nicht berücksichtigt
- EXPORT_ALIAS gibt die Exportfelder an.
- Datumsfelder müssen gekennzeichnet sein


- Bei Insert von Gesamtzcuhtwerten müssen die Felder noch gezählt werden und das insert-statement dynamisch gehalten werden. 

- Vorzeichen werden bei der Berechnung der Abweichungen vom Mittel der Zuchtwerte umgedreht.

