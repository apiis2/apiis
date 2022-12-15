package CalcTBV;

use Getopt::Std;
use File::Basename;
use Proc::Simple;
use DBI;
use Tie::IxHash;
use Apiis;

my( %opt,$vzwisssdb);
use ParsePest;
@ISA=qw(ParsePest);

#  FormatDate
#  DruckLog
#  FormatReal
#  SetDBH
#  GetDBH
#  TestParameterFile
#  @fields= @{$n->GetTableFields($table)}
#  @traits= @{$n->GetTraits($alias_estimation)}
#  @effects=@{$n->GetEffects($alias_estimation)}
#  @effects=@{$n->GetFixEffects($alias_estimation)}
#  @effects=@{$n->GetRandomEffects($alias_estimation)}
#  @effects=@{$n->GetAnimalEffects($alias_estimation)}
#  @effects=@{$n->GetCovariateEffects($alias_estimation)}
#  @traits= @{$n->GetTraitPerEffects($alias_estimation,$effect)}
#  
#################################################################
sub new {
#################################################################
  my $class =shift;
  my $self=ParsePest->new();
  $self->{'verband'}=shift;
  $self->{'hs_pop'}={};
  $self->{'hs_parent'}={};
  $self->{'hs_animal'}={};
  $self->{'tbvparameterfile'}=undef;
  bless ($self,$class);
}

#################
sub FormatDate {
#################
  my($dat)=shift(@_);
  my($format)=shift(@_);
  if ($dat ne '') {
    if ($format eq '-') {
      if ($dat=~/.*\..*\...../) {
        if ($dat=~/^.\..\..*/) {
          $dat=substr($dat,4,4).'-0'.substr($dat,2,1).'-0'.substr($dat,0,1);
        } elsif ($dat=~/^.\..{2}\..*/) {
          $dat=substr($dat,5,4).'-'.substr($dat,2,2).'-0'.substr($dat,0,1);
        } elsif ($dat=~/^.{2}\..\..*/) {
          $dat=substr($dat,5,4).'-0'.substr($dat,3,1).'-'.substr($dat,0,2);
        } else {
          $dat=substr($dat,6,4).'-'.substr($dat,3,2).'-'.substr($dat,0,2);
        }
      } if ($dat=~/..\...\.../) {
        if ($dat=~/^.\..\.../) {
          $dat=substr($dat,4,2).'-0'.substr($dat,2,1).'-0'.substr($dat,0,1);
        } elsif ($dat=~/^.\..{2}\.../) {
          $dat=substr($dat,5,2).'-'.substr($dat,2,2).'-0'.substr($dat,0,1);
        } elsif ($dat=~/^.{2}\..\.../) {
          $dat=substr($dat,5,2).'-0'.substr($dat,3,1).'-'.substr($dat,0,2);
        } else {
          $dat=substr($dat,6,2).'-'.substr($dat,3,2).'-'.substr($dat,0,2);
        }
      } 
    } else {
      if ($dat=~/.*-.*-.*/) {
        $dat=substr($dat,8,2).'.'.substr($dat,5,2).'.'.substr($dat,0,4);
      }
    }
  }
  return \$dat;
}

#########################
sub DruckLog {
########################
  my $self=shift;
  open (o_file, ">zws.log");
  foreach (@{$self->{'fehlerprotokoll'}}) {
    print o_file $_;
  }
  close o_file;
}
###################
sub FormatReal {
##################
  my($v1); my($v2);
  my($dat,$dezi)=@_;
 
  $dat=~/(-?\d*)\.?(.{0,$dezi})/;
  $v1=$1;
  $v2=$2;
  if ($dat=~/\./) {
    if ($dezi == 0) {
      $dat=$v1;
    } else {
      if (length($v2) < $dezi) {
        $dat=$dat.substr('0000000000',0,$dezi-length($v2));
      }
      if (length($v2) >= $dezi) {
        $dat="$v1.$v2";
      }
    }
  }  else {
    if ($dezi == 0) {
       $dat=$dat
    } else {
       $dat=$dat.".".substr('0000000000',0,$dezi);
    }
  }
  return \$dat;
} 


#################################################################
sub GetEstimation {
#################################################################
  my $self=shift;
  my $vtb=shift;
  return $self->{'tbvs'}->{$vtb}->{'estimation'}[0];
}

#################################################################

#################################################################
sub SetDBH {
#################################################################
  my $self=shift;
   my $db_driver=$self->{'database'}->{'db_driver'};
   my $db_name=$self->{'database'}->{'db_name'};
   my $db_user=$self->{'database'}->{'db_user'};
   my $db_password=$self->{'database'}->{'db_password'};
   my $connect;
   if (lc($db_driver) eq 'pg') {
     $connect="DBI:Pg:dbname=$db_name;host=$db_host;port=$db_port";
   } elsif (lc($db_driver) eq 'mysql') {
     $connect="DBI:mysql:$db_name";
   } else {
     print "Kein gültiger Datenbanktreiber Pg|MySql\n";
     exit;
   }
   eval {
     $self->{'dbh'}=DBI->connect($connect,$db_user,$db_password,{AutoCommit => 0}) || die "Fehler beim connect zur Datenbank";
   };
   if (! $@) {
     $self->FehlerProtokoll("Öffnen der Datenbank",'O');
   }  else {
     $self->FehlerProtokoll("$@ => Programmabbruch!",'W');
     exit 0;
   } 
}

#################################################################
sub GetDBH {
#################################################################
  my $self=shift;
  return $self->{'dbh'};
}

#################################################################
sub FehlerProtokoll {
#################################################################
  my $self=shift;
  my($vtext,$vstatus)=@_;
  if ($vstatus eq 'O') {
    $vstatus1=' => oK';
  } elsif ($vstatus eq 'E') {
    $vstatus1=' => Fehler';
  } elsif ($vstatus eq 'W') {
    $vstatus1=' => Warnung';
  } else {
    $vstatus1='';
  }
  $self->{'fehlerprotokoll'}=[] if (! exists $self->{'fehlerprotokoll'});
  push(@{$self->{'fehlerprotokoll'}},"$vtext".$vstatus1."\n") if ($vtext ne "");
  if ($self->GetDebugModus() eq  '1') {
    print "$vtext".$vstatus1."\n" if ($vtext ne "");
  }
} 

#################################################################
sub SetTbvParameterFile {
#################################################################
  my ($self, $pfile)=@_;
  $self->{'tbvparameterfile'}=$pfile;
}

#################################################################
sub GetTbvParameterFile {
#################################################################
  my ($self, $pfile)=@_;
  return $self->{'tbvparameterfile'};
}

#################################################################
sub TestParameterFile {
#################################################################
  my (@merkmale,$m);
  my $self=shift;

  if (! $self->{'tbvparameterfile'}) {
    $self->FehlerProtokoll('Kein Parameterfile (-m) angegeben -> Abbruch','E');
    return 1;
  } else {
    eval
  }
}

#################################################################
sub SetParameter {
#################################################################
  my ($self,$par,$value)=@_;
  $self->{'parameter'}->{$par}=$value;
}

#################################################################
sub ReadZwisssParameterFile {
#################################################################
  my (@merkmale,$m,$wert);
  my $self=shift;

  my($err)=0;
  if (! $self->{'tbvparameterfile'} ) {
    $self->FehlerProtokoll('Kein Parameterfile (-m) angegeben -> Abbruch','E');
    exit 0;
  } else {
    eval{require "$self->{'tbvparameterfile'}";};
    if (! $@) {
      $self->{'database'}->{'db_driver'}=$db_driver;
      $self->{'database'}->{'db_name'}=$db_name;
      $self->{'database'}->{'db_host'}=$db_host;
      $self->{'database'}->{'db_port'}=$db_port;
      $self->{'database'}->{'db_user'}=$db_user;
      $self->{'database'}->{'db_password'}=$db_password;
      $self->{'tables'}=\%TABLES;
      $self->{'estimations'}=\%ESTIMATIONS;
      $self->{'groups'}=\%GROUPS;
      $self->{'tbvs'}=\%TBVS;
      $self->{'format'}=\%FORMAT;
      $self->{'export'}=\%EXPORT;
      $self->{'alias'}=\%ALIAS;

      #Test auf fehlende Eingaben
      foreach $key (keys %GROUPS) {
        if ($key eq '!') {
          print "ERROR\t--> $key\tUngültige Gruppenbezeichnungin GROUPS \n";
          $err=1;
        }
        while (($key1,$value)=each %{$GROUPS{$key}}) {
          foreach (@{$value}) {
            if ($_=~/!/) {
              print "ERROR\t--> $_\tUngültige Bezeichnung in GROUPS->$key1=>[???]\n";
              $err=1;
            }
          }
        } 
      }
      foreach $key (keys %TBVS) {
        if ($key eq '!') {
          print "ERROR\t--> $key\tUngültige Gruppenbezeichnungin TBVS\n";
          $err=1;
        }
        while (($key1,$value)=each %{$TBVS{$key}}) {
          foreach (@{$value}) {
            if ($_=~/!/) {
              print "ERROR\t--> $_\tUngültige Bezeichnung in TBVS->$key1=>[???]\n";
              $err=1;
            }
          }
        } 
      }
      exit 0 if ($err==1);
      return 0;
    } else {
      $self->FehlerProtokoll('Ungültiges Parameterfile angegeben -> Abbruch','E');
      exit 0;
    }
  }
}

###############################################################################
sub PestStarten {
###############################################################################
  my(@ar_running,@ar_todo,$sc_base,$sc_pfad,$vdebug,$proc,$key,$value,$sc_max_parallele_jobs,$job);
  my $self=shift;
 
  @ar_running=();
  @ar_todo=();
  while (($key,$value)=each %{$self->{'estimations'}}) {
    push(@ar_todo,$value->{'pest_prg'}." ".$value->{'pest_par'}." ".$value->{'pest_mem'});
    ($sc_base,$sc_pfad)=fileparse($self->{'alias'}->{$key});
    push(@ar_pfade,$sc_pfad);
  }
 
  while (($#ar_todo>=0) or ($#ar_running>=0)) {
    @ar_running=grep{$_->poll()} @ar_running;
 
    if (($#ar_running+1<$self->GetMaxParalleleJobs())  and (defined($job=shift(@ar_todo)))) {
      $proc=Proc::Simple->new();
      chdir($self->GetLocal()."/".shift(@ar_pfade));
      $proc->start($job) || die "$job kann nicht gestartet werden";
      if (! $@) {
        $self->FehlerProtokoll("$job gestartet",'O');
      } else {
        $self->FehlerProtokoll("$@","E");
      }
 
      push(@ar_running,$proc);
      next;
    }
    sleep(60);
  }
  chdir($self->GetLocal());
} 

###############################################################################
sub SetOpt {
###############################################################################
  $self=shift;
  $opt= shift;
  %opt=%{$opt};
  return;
}
###############################################################################
sub SetLocal {
###############################################################################
  my $a;
  my $self=shift;
  $self->{'local'}=shift @_;
  $a=chdir($self->GetLocal());
  return 0;
}

###############################################################################
sub GetLocal {
###############################################################################
  my $self=shift;
  return $self->{'local'};
}

###############################################################################
sub GetMaxParalleleJobs {
###############################################################################
  my $self=shift;
  return $self->{'max_parallele_jobs'};
}

###############################################################################
sub SetMaxParalleleJobs {
###############################################################################
  my $self=shift;
  $self->{'max_parallele_jobs'}=shift @_;
}

###############################################################################
sub GetDebugModus {
###############################################################################
  my $self=shift;
  return $self->{'debugmodus'};
}

###############################################################################
sub SetDebugModus {
###############################################################################
  my $self=shift;
  $self->{'debugmodus'}=shift @_;
}


###############################################################################
sub GetExecute {
###############################################################################
  my(@arr,$dbh);
  my $self=shift;
  my $statement=shift @_;
  my $text=shift @_;
  $dbh=$self->GetDBH();
  eval {
    $sth = $dbh->prepare($statement);
    $rv = $sth->execute;
    while (@row=$sth->fetchrow_array) {
      push(@arr,[@row]);
    }
    $rv = $sth->finish;
    $dbh->commit;
  };
  if (! $@) {
    $self->FehlerProtokoll($text,'O');
  } else {
    $self->FehlerProtokoll("$text: $@","E");
  }
  return @arr;
}

###############################################################################
sub Execute {
###############################################################################
  my(@arr,$dbh);
  my $self=shift;
  my $statement=shift @_;
  my $text=shift @_;
  $dbh=$self->GetDBH();
  eval {
    $sth = $dbh->prepare($statement);
    $rv = $sth->execute;
    $rv = $sth->finish;
    $dbh->commit;
  };
  if (! $@) {
    $self->FehlerProtokoll($text,'O');
    return 0;
  } else {
    print $statement;
    $self->FehlerProtokoll("$text: $@","E");
    return 1;
  }
}

###############################################################################
sub GetTableFields {
###############################################################################
  my $self=shift;
  my $table=shift;
  return $self->{tables}->{$table}->{fields};
}

###############################################################################
sub CreateDB {
###############################################################################
  my (@ar_row,$dat,$dbh,@feld,$feld);
  my $self=shift;

  $dbh=$self->GetDBH();
#  $statement="SHOW tables";
#  @ar_row=$self->GetExecute($statement,'Einlesen aller Tabellen');
#  foreach $dat (@ar_row) {
#    $hs_table{$dat->[0]}=1;
#  }

  my $in=0;
  while (($key,$value1)=each %{$self->{'tables'}}) {
#    if (exists $hs_table{$key}) {
      $statement="DROP TABLE $key"."_old CASCADE";
      $self->Execute($statement,"Löschen von $key"."_old");
      $statement="alter table $key rename to $key"."_old";
      $self->Execute($statement,"Umbenennen von $key in $key"."_old");
#    }

    $fields=[];
    @feld=();
    while (($key1,$value)=each %{$value1}) {
      next if (exists $value->{'DESTINATION'});
      if ($value->{'DB_COLUMN'} eq 'animal') {
        if ($opt{'a'}) {
          push(@feld,$value->{'DB_COLUMN'}.' INTEGER NOT NULL');
	} else {
          push(@feld,$value->{'DB_COLUMN'}.' CHAR('.$value->{'LENGTH'}.') NOT NULL');
	}  
      } elsif  ($value->{'DB_COLUMN'} eq 'db_id') {
        push(@feld,$value->{'DB_COLUMN'}.' INTEGER NOT NULL ');
      } else {
        push(@feld,$value->{'DB_COLUMN'}.' VARCHAR('.$value->{'LENGTH'}.') NULL') if ($value->{'DATATYPE'} eq 't');
        push(@feld,$value->{'DB_COLUMN'}.' TEXT NULL') if ($value->{'DATATYPE'} eq 'y');
        push(@feld,$value->{'DB_COLUMN'}.' DATE NULL') if ($value->{'DATATYPE'} eq 'd');
        push(@feld,$value->{'DB_COLUMN'}.' FLOAT NULL') if ($value->{'DATATYPE'} eq 'z');
      }
      push (@$fields,$value->{'DB_COLUMN'});
    }
    $hs_tables{$key}=$fields;
    $self->{tables}->{$key}->{fields}=$fields;
    $feld=join(',',@feld);
    $statement='CREATE TABLE '.$key.' ('.$feld.');';
    $self->Execute($statement,"Erstellen von $key");
    
    $statement='CREATE INDEX animal_'.$in++.' ON '.$key.' (animal);';
    $self->Execute($statement,"Erstellen von Index animal für $key");

  }
  $statement="DROP TABLE ".$self->GetVerband."_save_old";
  $self->Execute($statement,"Löschen von ".$self->GetVerband."_save");
  $statement="ALTER TABLE ".$self->GetVerband."_save RENAME TO ".$self->GetVerband."_save_old";
  $self->Execute($statement,"Löschen von ".$self->GetVerband."_save_old");
  #--- Tabelle zur Sicherung von Zuchtwertinformationen
  $statement='CREATE TABLE '.$self->GetVerband.'_save (
    					      vgroup  char(16),
    					      vclass  char(16),
					      veffect char(16),
					      vtrait  char(16), 
					      vvalue  float not null);';
  $self->Execute($statement,"Erstellen von ".$self->GetVerband."_save");
}

###############################################################################
sub GetDataTyp {
###############################################################################
  my $self=shift;
  my $value=shift @_;
  return $self->{'zw_fld'}->{$value}->[2];
}

###############################################################################
sub SetAlias {
###############################################################################
  my $self=shift;
  my %hs_rev=reverse %{$self->{'alias'}};
  while (($key,$value)=each %hs_rev) {
    $self->{'pest'}->{$key}->{'ALIAS'}=$value if (exists $self->{'pest'}->{$key});
  }
}

###############################################################################
sub GetAlias {
###############################################################################
  my $self=shift;
  my $key=shift @_;
  return $self->{'pest'}->{$key}->{'ALIAS'};
}

###############################################################################
sub ConvertValueForInsert {
###############################################################################
  my $self=shift;
  my $typ=shift @_;
  my $value=shift @_;
  my $hk=shift @_;

  if (($typ eq 't') or ($typ eq 'd')) {
    if ($typ eq 'd') {
      $value=${FormatDate($value,'-')};
    }
    if ($hk) {
      $value="'".$value."'";
    } 
  } elsif ($typ eq 'z') {
    $value=~s/,/./ if ($value=~/,/);
  } else {
    if ($value eq '') {
      $value=NULL;
    }
  }
  return $value;
}

###############################################################################
sub GetPestFile {
###############################################################################
  my $self=shift;
  my ($valias,$vfile)=@_;
  return $self->{'estimations'}->{$valias}->{$vfile}[0];
}

###############################################################################
sub GetVerband {
###############################################################################
  my $self=shift;
  return $self->{'verband'};
}

###############################################################################
sub GetOwner {
###############################################################################
  my $self=shift;
  return "'".$self->{'verband'}."'";
}

###############################################################################
sub ReadWriteRelationship {
###############################################################################
  my $self=shift;
  my $key; my $value;
  my %hs_parent=();
  my %hs_animal=();
  my %hs_group=();
  my $c;
  if (! $opt{'a'}) {
    while (($key,$value)=each %{$self->{'pest'}}) {
      if ($key=~/^\//) {
        $c=chdir(File::Basename::dirname($key));
      } else {
        $c=chdir($self->GetLocal()."/".File::Basename::dirname($key));
      }

      my($vfile)=$self->GetInFile($key,'RELATIONSHIP');
      eval {
        open (i_file,$vfile) || die "Datei $vfile nicht gefunden";
      };
      my $animal; my $m_p; my $f_p;my $counter=0;
      if (! $@) {
        while (<i_file>) {
          #Speichern jedes Wertes als Feld in einem Array, Reihenfolge entspricht Struktur
          foreach $dat (values %{$self->GetInput($key,'RELATIONSHIP')}) {
            ($animal)=(substr($_,$dat->[1]-1,$dat->[2])=~/(\S+)/) if ($dat->[0] eq 'animal');
            ($m_p)=(substr($_,$dat->[1]-1,$dat->[2])=~/(\S+)/) if ($dat->[0] eq 'm_p');
            ($f_p)=(substr($_,$dat->[1]-1,$dat->[2])=~/(\S+)/) if ($dat->[0] eq 'f_p');
          }

          #--- Eltern auf '' setzen, wenn String unbekannte Eltern bedeutet.
          if (defined $value->{'RELATIONSHIP'}->{'UNDEFINED'}) {
            $m_p='' if ($m_p eq $value->{'RELATIONSHIP'}->{'UNDEFINED'}->[0]);
            $f_p='' if ($f_p eq $value->{'RELATIONSHIP'}->{'UNDEFINED'}->[0]);
          }
          #--- Eltern auf '' setzen, wenn Genetische Gruppe (Sachsenspezifisch).
          #$m_p='' if ($m_p=~/^0.*SN$/);
          #$f_p='' if ($f_p=~/^0.*SN$/);

          if (exists $hs_animal{$animal}) {
            #--- alte Abstammung ersetzen, wenn Eltern '' sind
            if (($hs_animal{$animal}->[1] eq '') and ($hs_animal{$animal}->[2] eq '')) {
              $hs_animal{$animal}=[$animal,$m_p,$f_p];
            }
          } else {
            $hs_animal{$animal}=[$animal,$m_p,$f_p];
          }
          $counter++;
        }
        close (i_file);
        (@ar_datum)=localtime((stat($vfile))[9]);
        $sc_datum=($ar_datum[3]+1).'.'.($ar_datum[4]+1).'.'.($ar_datum[5]+1900);
        $self->FehlerProtokoll("Lesen Datei ".$vfile." ($sc_datum)",'O');

        $c=chdir($self->GetLocal());
      } else {
        $self->FehlerProtokoll("Lesen Datei ".$vfile.":$@",'E');
      }
      if ($counter==0) {
        $self->FehlerProtokoll("\t$counter Pedigreedaten gelesen",'E');
        exit 0;
      } else {
        $self->FehlerProtokoll("\t$counter Pedigreedaten gelesen",'O');
      }
    }

  #--- Daten wegschreiben
  #--- Zieltabelle suchen
  my $vzwisssdb;my $verband;
  foreach (keys %{$self->{'tables'}}) {
    ($verband,$vzwisssdb)=($_=~/(.*)(_animal)/) if ($_=~/_animal/);
  }
  $self->{'verband'}=$verband;
  $vzwisssdb=$verband.$vzwisssdb;
  $counter=0;

  my %hs_fields;
  if ($opt{'f'}) {
    #--- Felder holen und Reihenfolge abspeichern
    my $i=0;
    map {$hs_fields{$_}=$i++} @{$self->GetTableFields($vzwisssdb)};
    
    open (o_file_d,">temp_r") || die "Datei $opt{'o'} kann nicht geschrieben werden";
    print o_file_d 'COPY '.lc($self->GetVerband).'_animal FROM stdin;'."\n";
  }

  while (($key,$value)=each %hs_animal) {
   if ($opt{'f'}) {
     @tt=();
     map {push(@tt,'\N')} @{$self->GetTableFields($vzwisssdb)};
     $tt[$hs_fields{animal}]=$value->[0];
     $tt[$hs_fields{m_p}]=$value->[1];
     $tt[$hs_fields{f_p}]=$value->[2];
     $tt[$hs_fields{db_owner}]=$self->GetOwner;
     $tt[$hs_fields{db_id}]=$counter;
     print o_file_d join("\t", @tt)."\n";
   } else {
      my $geto=$self->GetOwner;
      $statement="INSERT INTO $vzwisssdb (animal,m_p,f_p,db_owner,db_id) VALUES ('$value->[0]','$value->[1]','$value->[2]',$geto, $counter);";
      $self->Execute($statement,"");
   }
    $counter++;
  }
  if ($counter==0) {
    $self->FehlerProtokoll("\t$counter INSERT animals",'E');
    exit 0;
  } else {
    $self->FehlerProtokoll("\t$counter INSERT animals",'O');
  }

  if ($opt{'f'}) {
    close (o_file_d);
    $verband=lc($verband);
    $verband=$opt{'l'} if ($opt{'l'});
    system("psql -U apiis_admin -d $verband -f temp_r");
    system("rm temp_r");
  }
  $statement='CREATE UNIQUE INDEX ianimal ON '.$vzwisssdb.' (animal);';
  $self->Execute($statement,'Erstellen INDEX ianimal');

#   $self->Execute("insert into temp_parents (animal,geschlecht) select m_p,'1' as geschlecht from $vzwisssdb group by m_p",'m_p nach temp_parents');
#   $self->Execute("insert into temp_parents (animal,geschlecht) select f_p,'2' as geschlecht from $vzwisssdb group by f_p",'f_p nach temp_parents');
  }
  return;
}
###############################################################################
sub ReadDataPest {
###############################################################################
  my (@ar_row,$dat,$dbh,@feld,$feld,@estimations,$sc_datum,@ar_datum,$counter,$icounter,$t,$ddef,$i,%hs_pop,%hs_parent,%hs_animal);
  my $self=shift;
  my ($key)=@_;

  %hs_pop=%{$self->{'hs_pop'}};
  %hs_parent=%{$self->{'hs_parent'}};
  %hs_animal=%{$self->{'hs_animal'}};

  my $verband=$self->GetVerband;
  my $valias=$self->GetAlias($key);
  my $vzwisssdb=$self->GetVerband."_".$self->GetAlias($key)."_daten";
  my $vzwisssdb1=$self->GetStTable($self->GetVerband);

  #####################################################################
  #  Einlesen der Daten entsprechend der Struktur für das Datenfile
  #  Das Array wird dem Tier-Hash unter dem Namen DATEN zugeordnet
  #####################################################################
  $vfile=$self->GetInFile($key,'DATA');
  my %hs_fields=();
  
  if ($opt{'f'}) {
    #--- Felder holen und Reihenfolge abspeichern
    my $i=0;
    map {$hs_fields{$_}=$i++} @{$self->GetTableFields($vzwisssdb)};
    open (o_file_d,">temp_r") || die "Datei $opt{'o'} kann nicht geschrieben werden";
    print o_file_d 'COPY '.lc($vzwisssdb).' FROM stdin;'."\n";
  }

  eval {
    open (i_file,$vfile) || die "Datei $vfile nicht gefunden";
  };
  if (! $@) {
    $counter=0;
    my $field=(); my $value=();
    while (<i_file>) {
      my @dat=();
      my @fld=();
      my @update=();
      my $c=0;
      if ($opt{'f'}) {
        @tt=();
        map {push(@tt,'\N')} @{$self->GetTableFields($vzwisssdb)};
      }						 
      while (($key1,$value)=each %{$self->{'tables'}->{$vzwisssdb}}) {
        next if (ref $value eq 'ARRAY');
        next if ($value->{'DB_COLUMN'} eq 'db_id');
        next if ($value->{'DB_COLUMN'} eq 'db_owner');

        #--- alle DATA-Felder befüllen
        ($t)=(substr($_,$value->{'START'}-1,$value->{'LENGTH'})=~/(\S+)/);
        if (defined $t) {
          $vanimal=$t if ($value->{'DB_COLUMN'} eq 'animal');
          if (defined $value->{'DESTINATION'}) {
           push(@update,$value->{'DESTINATION'}."=".$self->ConvertValueForInsert($value->{'DATATYPE'},$t,1));
            next;
          }
          push(@dat,$self->ConvertValueForInsert($value->{'DATATYPE'},$t,1));
	  $tt[$hs_fields{$value->{'DB_COLUMN'}}]=$self->ConvertValueForInsert($value->{'DATATYPE'},$t,undef) if ($opt{'f'});
        } else {
          next;
        }
        push(@fld,$value->{'DB_COLUMN'});
      }
      #--- Daten wegschreiben
      push(@dat,$self->GetOwner);
      push(@fld,'db_owner');
      push(@dat,$c++);
      push(@fld,'db_id');
    
      if ($opt{'f'}) {
        $tt[$hs_fields{db_owner}]=$self->GetOwner;
	$tt[$hs_fields{db_id}]=$c;
        print o_file_d join("\t", @tt)."\n";
      } else {
        $statement="INSERT INTO ".$vzwisssdb." (".join(',',@fld).") VALUES (".join(',',@dat).")";
        $self->Execute($statement,"");
      }	

      if ($#update>-1) {
        $statement="UPDATE ".$vzwisssdb1." SET ".join(',',@update)." WHERE animal='$vanimal'";
        $self->Execute($statement,"");
      }
      $counter++
     }
    close (i_file);
    (@ar_datum)=localtime((stat($vfile))[9]);
    $sc_datum=($ar_datum[3]+1).'.'.($ar_datum[4]+1).'.'.($ar_datum[5]+1900);
    $self->FehlerProtokoll("Öffnen Datei ".$vfile." ($sc_datum)",'O');
  } else {
    $self->FehlerProtokoll("Öffnen Datei ".$vfile.":$@",'E');
  }
  if ($counter==0) {
    $self->FehlerProtokoll("\t$counter Daten gelesen",'E');
  } else {
    $self->FehlerProtokoll("\t$counter Daten gelesen",'O');
  }
  if ($opt{'f'}) {
    close (o_file_d);
    $verband=$opt{'l'} if ($opt{'l'});
    system("psql -U apiis_admin -d $verband -f temp_r");
    system("rm temp_r");
  }
  $statement='DROP INDEX '
      .$self->GetVerband."_".$self->GetAlias($key)."_daten_animal" ;
  $self->Execute($statement,'INDEX '
          .$self->GetVerband."_".$self->GetAlias($key)."_daten_animal löschen");
  $statement='CREATE INDEX '
      .$self->GetVerband."_".$self->GetAlias($key).'_daten_animal ON '
      .$vzwisssdb.' (animal);';
  $self->Execute($statement,'Erstellen INDEX
          '.$self->GetVerband."_".$self->GetAlias($key)."_daten_animal");

}

###############################################################################
sub ReadBvPest {
###############################################################################
  my (@ar_row,$dat,$dbh,@feld,$feld,@estimations,$sc_datum,@ar_datum,$counter,$icounter,$t,$ddef,$i,%hs_pop,%hs_parent,%hs_animal);
  my $self=shift;
  my ($key)=@_;

  my $verband=$self->GetVerband;
  my $valias=$self->GetAlias($key);
  my $vzwisssdb=$self->GetVerband."_".$self->GetAlias($key)."_daten";
  my $vzwisssdb1=$self->GetVerband."_animal";

  #####################################################
  # Einlesen der Zuchtwerte, Zerhacken des LST-Files
  #####################################################
  %hs_effekte=();
  $vzwisssdb=$self->GetVerband."_".$self->GetAlias($key)."_effects";
  if ($opt{'o'}) {
    eval {
      open (o_file_ef,">temp_ef") || die "Datei $opt{'o'} kann nicht geschrieben werden";
      open (o_file_bv,">temp_bv") || die "Datei $opt{'o'} kann nicht geschrieben werden";
    };
  }
  if ($opt{'f'}) {
    open (o_file_b,">temp_b") || die "Datei $opt{'o'} kann nicht geschrieben werden";
    print o_file_b 'COPY "'.lc($self->GetVerband).'_'.$self->GetAlias($key).'_bv" FROM stdin;'."\n";
    open (o_file_e,">temp_e") || die "Datei $opt{'o'} kann nicht geschrieben werden";
    print o_file_e 'COPY "'.lc($self->GetVerband).'_'.$self->GetAlias($key).'_effects" FROM stdin;'."\n";
  }
  $vfile=$self->GetOutFile($key,'PRINTOUT');
  eval {
    open (i_file,$vfile) || die "Datei $vfile nicht gefunden";
  };
  if (! $@) {
    (@ar_datum)=localtime((stat($vfile))[9]);
    $sc_datum=($ar_datum[3]+1).'.'.($ar_datum[4]+1).'.'.($ar_datum[5]+1900);
    $self->FehlerProtokoll("Öffnen Datei ".$vfile." ($sc_datum)",'O');
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
      } elsif (($_=~/\+\+\+\+\+\+/) or ($_=~/^\s*$/) or ($_=~/^\s+$/) or ($_=~/\.{30}/)){
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
        next
      } elsif ($block eq 'MI2') {
        my @a=split('\s+',$_);
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
        next if ($_=~/^\s{27}/); # 20 rffr warum? leere effekte raus
        next if ($_=~/\<\sPEST\s\>/);
        next if ($_=~/\.\.\.PEST/);
        next if ($_=~/\^L/);

        if ($self->GetPEV($key) eq 't') {
          ($w0,$w1,$w2)=($_=~/^\s{5}(.{16})\s+(.*?)\+\-\s+(.*)$/);
          @se=split('\s+',$w2);
        } else {
          ($w0,$w1)=($_=~/^\s{5}(.{16})\s+(.*)/);
        }
	$w1=0 if ($w1=~/\*/);
        @zw=split('\s+',$w1);
        $w0=~s/^\s*//g;
        $w0=~s/\s*$//g;
	$gg=0;
	if ($w0=~/\*$/) {
          ($effekt)=($w0=~/(.*)\*+$/);
	  if (exists $self->{'pest'}->{$key}->{'RELATIONSHIP'}->{'GROUP'}) {
            $gg=1;
	    $effect_name='GenGroup';
	  }  
	  if (exists $self->{'pest'}->{$key}->{'RELATIONSHIP'}->{'UNDEFINED'}) {
	    next;
	  }
        } else {
          $effekt=$w0;
        }
        #--- Leerzeichen entfernen
        my $vorsatz='';
        my  @field=(); my @dat=();
        if (($effekt_name eq 'ANIMAL') and ($gg == 0)) {
          $vzwisssdb=$self->GetVerband."_".$self->GetAlias($key)."_bv";
	  $table_bv=$vzwisssdb;
          push(@field,"animal");
          push(@dat,$effekt);
          $vorsatz='bv';
        } else {
          $vzwisssdb=$self->GetVerband."_".$self->GetAlias($key)."_effects";
	  $table_ef=$vzwisssdb;
          push(@field,"effect");                            
          push(@dat,$effekt);
          push(@field,"effect_class");
          push(@dat,$effekt_name);
          $vorsatz='ef';
        }
        @zw1=@zw; @se1=@se;
        $l=0;
        push(@dat,$c++);
        push(@field,'db_id');
        push(@field,"db_owner");
        push(@dat,$self->GetOwner);

        foreach $x (@{$hs_effekte{$effekt_name}}) {
          if ($x eq 'x') {
            if ($self->GetPEV($key) eq 't') {
              push(@dat,shift(@zw1));
              push(@dat,shift(@se1));
              push(@field,$vorsatz.$valias."_".$ar_fields[$l]);
              push(@field,$vorsatz."se".$valias."_".$ar_fields[$l]);
            } else {
              push(@dat,shift(@zw1));
              push(@field,$vorsatz.$valias."_".$ar_fields[$l]);
            }
          }
          $l++;
        }

        if ($opt{'o'}) {
          @zw1=@zw; @se1=@se;
          $l=0;
          foreach $x (@{$hs_effekte{$effekt_name}}) {
            if ($x eq 'x') {
              if ($self->GetPEV($key) eq 't') {
	        if ($vorsatz eq 'bv') {
                  print o_file_bv "BVE".$self->GetAlias($key).";".$effekt_name.";".$effekt.";".$ar_fields[$l].";".shift(@zw1).";".shift(@se1)."\n";
		} else {
                  print o_file_ef "BVE".$self->GetAlias($key).";".$effekt_name.";".$effekt.";".$ar_fields[$l].";".shift(@zw1).";".shift(@se1)."\n";
		}
              } else {
	        if ($vorsatz eq 'bv') {
                  print o_file_bv "BVE".$self->GetAlias($key).";".$effekt_name.";".$effekt.";".$ar_fields[$l].";".shift(@zw1)."\n";
                } else {
                  print o_file_ef "BVE".$self->GetAlias($key).";".$effekt_name.";".$effekt.";".$ar_fields[$l].";".shift(@zw1)."\n";
	        }
	      }	
            }
            $l++;
          }
        } else {
	  if ($opt{'f'}) {
	    @tt=();%hs_t=();
            for ($i=0;$i<=$#field;$i++) {
	      $hs_t{lc($field[$i])}=$dat[$i];
	    }  
	    foreach (@{$hs_tables{$vzwisssdb}}) {
	      if (exists $hs_t{lc($_)}) {
	        push(@tt,$hs_t{lc($_)});
              } else {		
	        push(@tt,'\N');
 	      }
	    }
	    map {if (($_=~/\*\*\*/) or ($_ eq '') or (! $_)) {$_ = 0} } @tt;
	    if ($vorsatz eq 'bv') {
              print o_file_b join("\t",@tt)."\n";
	    } else {  
   	      print o_file_e join("\t",@tt)."\n";
	    }  
          } else {  
	    map {if  (($_=~/\*\*\*/) or ($_ eq '') or (! $_)) {$_ = '\N' }} @dat;
            $statement="INSERT INTO ".$vzwisssdb." (".join(',',@field).") 
  	              VALUES (".join(',',@dat).")";
            $self->Execute($statement,"");
	  }  
	}
      }
      $counter++;
    }
    close (i_file);
    if ($opt{'f'}) {
      close (o_file_b);
      close (o_file_e);
      $verband=$opt{'l'} if ($opt{'l'});
      system("psql -U apiis_admin -d $verband -f temp_b");
      system("psql -U apiis_admin -d $verband -f temp_e");
      system("rm temp_b");
      system("rm temp_e");
    }
    $statement="DROP INDEX ".$self->GetVerband."_".$self->GetAlias($key)."_bv_animal";
    $self->Execute($statement,'INDEX löschen');
    $statement="DROP INDEX ".$self->GetVerband."_".$self->GetAlias($key)."_effects_effect";
    $self->Execute($statement,'INDEX löschen');
    $statement="CREATE UNIQUE INDEX ".$self->GetVerband."_".$self->GetAlias($key)."_bv_animal ON ".$self->GetVerband."_".$self->GetAlias($key)."_bv (animal)";
    $self->Execute($statement,"");
    $statement="CREATE INDEX ".$self->GetVerband."_".$self->GetAlias($key)."_bv_effect ON ".$self->GetVerband."_".$self->GetAlias($key)."_effects (effect)";
    $self->Execute($statement,"");
    if ($opt{'o'}) {
      close (o_file_bv);
      close (o_file_ef);
    }
    if ($counter==0) {
      $self->FehlerProtokoll("\t$counter Zuchtwerte gelesen",'E');
      exit 0;
    } else {
      $self->FehlerProtokoll("\t$counter Zuchtwerte gelesen",'O');
    }
  } else {
    $self->FehlerProtokoll("Öffnen Datei ".$vfile.":$@",'E');
  }
}

#####################################################################
sub GetNameTBV {
#####################################################################
  my $self=shift;
  my $vtb=shift;
  return $self->{'tbvs'}->{$vtb}->{'tbvn'}[0];
}

#####################################################################
sub GetTBVS {
#####################################################################
  my $self=shift;
  return $self->{'tbvs'};
}

#####################################################################
sub GetParents {
#####################################################################
  my $self=shift;
  my $key=shift @_;
  return @{$self->{'groups'}->{$key}->{'base_only_parents'}}[0]
}

#####################################################################
sub GetStandardisation {
#####################################################################
  my ($t1,$t2);
  my $self=shift;
  my $key=shift @_;
  ($t1,$t2)=(${$self->{'tbvs'}->{$key}->{'standardisation'}}[0]=~/(.*)\+-(.*)/);
  return $t1,$t2;
}

#####################################################################
sub GetTBVEstimation {
#####################################################################
  my $self=shift;
  my $key=shift @_;
  if ((exists  $self->{'tbvs'}->{$key}->{'estimation'}) and ($self->{'tbvs'}->{$key}->{'estimation'} ne '')) {
    return $self->{'tbvs'}->{$key}->{'estimation'}[0];
  } else {
    return '';
  }
}

#####################################################################
sub GetTBVSEModus {
#####################################################################
  my $self=shift;
  my $key=shift @_;
  if (exists  $self->{'tbvs'}->{$key}->{'r_for_tbv'}) {
    return $self->{'tbvs'}->{$key}->{'r_for_tbv'}[0];
  } else {
    return '';
  }
}

#####################################################################
sub GetBVSEModus {
#####################################################################
  my $self=shift;
  my $key=shift @_;
  if (exists $self->{'tbvs'}->{$key}->{'bv_r2'}) {
    return $self->{'tbvs'}->{$key}->{'bv_r2'}[0];
  } else {
    return '';
  }
}

#####################################################################
sub GetWiRelModus {
#####################################################################
  my $self=shift;
  my $key=shift @_;
  if (exists $self->{'tbvs'}->{$key}->{'wi'}) {
    return $self->{'tbvs'}->{$key}->{'wi'}[0];
  } else {
    return ''
  }
}

#####################################################################
sub GetTraitsEFF {
#####################################################################
  my ($t,$t1,$traits,$traits_rel);
  my $self=shift;
  my $key=shift @_;
  return if ($self->{'tbvs'}->{$key}->{'tbv'}->[0] eq '');
  foreach (@{$self->{'tbvs'}->{$key}->{'tbv'}}) {
    if ($_=~/^.*\*.*\*/) {
      ($t,$t1)=($_=~/^(.*?)\*(.*?)\*/);
    } else {
      ($t,$t1)=($_=~/^(.*?)\*(.*)/);
    }
    $t1=~s/^bv/ef/g;
    push(@{$traits},$t1);
    $t1=~s/^ef/efr/g;
    push(@{$traits_rel},$t1);
  }
  return $traits,$traits_rel;
}

#####################################################################
sub GetTraitsTBV {
#####################################################################
  my ($t,$t1,$traits,$wi,$traits_rel,$tables);
  my $self=shift;
  my $key=shift @_;
  foreach (@{$self->{'tbvs'}->{$key}->{'tbv'}}) {
    next if($_ eq '');
    if ($_=~/^.*\*.*\*/) {
      ($t,$t1)=($_=~/^(.*?)\*(.*?)\*/);
    } else {
      ($t,$t1)=($_=~/^(.*?)\*(.*)/);
    }
    push(@{$wi},$t);
    push(@{$traits},$t1);
    $t1=~s/^bv/bvr/g;
    push(@{$traits_rel},$t1);
  }
  return $traits,$wi,$traits_rel,$tables;
}

#####################################################################
sub GetVGVarianzTrait {
#####################################################################
  my $self=shift;
  my $trait=shift @_;

  my(@traits)=$self->GetTraits($self->ResolveAlias($alias));
  my(@var)=$self->GetVGVarianz($self->ResolveAlias($alias),'animal');
  my($i)=0;
  foreach (@traits) {
    return $var[$i] if ($_ eq $trait) ;
    $i++;
  }
  return undef;
}

###############################################################################
sub ResolveAlias {
###############################################################################
  my $self=shift;
  my $key=shift @_;
  return $self->{'alias'}->{$key};
}

###############################################################################
sub MxMulti_vDvv {
###############################################################################
  my $self=shift;
  my @ar1=shift @_;
  my @ar2=shift @_;
  my($sum)=0;
  my($sum2)=0;
  for($i=0;$i<=$#ar1;$i++) {
    $sum=$sum+($ar1[$i]*$ar2[$i]);
  }
  for($i=0;$i<=$#ar1;$i++) {
    $sum2=$sum2+($sum*$ar1[$i]);
  }
  return $sum2;

}

sub GetStTable {
  my $self = shift;
  my $bv=shift;
  return $bv.'_animal';
}

sub GetStAnimal {
  my $self=shift;
  return "animal";
}



#####################################################################
sub Save {
#####################################################################
=head1 Save

save=>[['-','GI','','','']]

=head2 Position 2:

The output of pest has several sections. A part of this sections can be saved into table _save. The parts can be defined with:

GI - General Information
RU - Runtime Information
DI - Data Information
MI - Model Information
nk - Nachkommen (only sire)
vg - Vollgeschwister 

=head2 Position 3:

Definition of an sql-statment

=head2 Position 4:

Definition of traits, which should be saved

=cut


  my $self=shift;
  my $vtb=shift(@_);
  my ($nr_vgzw)=($vtb=~/tbv(.+)/);
  my $pest_par=$self->{'alias'}->{$nr_vgzw};
  foreach $t (@{$self->{'tbvs'}->{$vtb}->{'save'}}) {
    my @groups =split(',',$t->[0]);
    my @classes=split(',',$t->[1]);
    my $sql    =$t->[2];
    my @traits =split(',',$t->[3]);
    push(@groups,'-') if ($#groups<0);
    if (($#classes<0) or (($#traits<0) and ($t->[1]!~/GI|DI|RI|MI/))) {
      print "Keine Klassen oder Merkmale definiert"."\n";
      return;
    }  
    foreach my $group (@groups) {
      foreach my $class (@classes) {
        if ($class=~/GI|RI/) {
          while (($key, $value)=each %{$self->{estimations}->{$nr_vgzw}->{statistik}->{$class}}) {
  	    $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue) 
 	                     VALUES ('-','$class','','$key',$value)";
            $self->Execute($statement,"Daten nach *_save.");
	  }  
        } elsif ($class=~/DI/) {
	  my $i=0;
          foreach $tr (@{$self->{estimations}->{$nr_vgzw}->{statistik}->{$class}->{traits}}) {
  	    $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue) 
 	                VALUES ('-','$class','n','$tr',$self->{estimations}->{$nr_vgzw}->{statistik}->{$class}->{n}->[$i])";
            $self->Execute($statement,"Daten nach mszv_save.");
  	    $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue) 
 	                VALUES ('-','$class','mw','$tr',$self->{estimations}->{$nr_vgzw}->{statistik}->{$class}->{mw}->[$i])";
            $self->Execute($statement,"Daten nach mszv_save.");
  	    $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue) 
 	                VALUES ('-','$class','sa','$tr',$self->{estimations}->{$nr_vgzw}->{statistik}->{$class}->{sa}->[$i])";
            $self->Execute($statement,"Daten nach mszv_save.");
  	    $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue) 
 	                VALUES ('-','$class','mi','$tr',$self->{estimations}->{$nr_vgzw}->{statistik}->{$class}->{mi}->[$i])";
            $self->Execute($statement,"Daten nach mszv_save.");
  	    $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue) 
 	                VALUES ('-','$class','ma','$tr',$self->{estimations}->{$nr_vgzw}->{statistik}->{$class}->{ma}->[$i])";
            $self->Execute($statement,"Daten nach _save.");
	    $i++;
	  }  
        } else {

        foreach my $trait (@traits) {
          if ($group ne '-') {	  
  	    $funkt=" $group($trait) ";
	    $group_by=" GROUP BY a.$class ";
	  } else {
	    $funkt=$trait;
	    $group_by='';
	  }  
          $kat='bv';
	  $kat='effects' if ($trait=~/^ef/);
	  $kat='daten'   if ($trait=~/^da/);

          $ssql=' '; $where=' ';
	  if ($sql) {
 	    $ssql=", ($sql) as b ";
	    $where=" WHERE a.".$class."=b.".$class;
	  }
	  if ($class=~/vg/i) {
	   #$ssql="select distinct m_p from ".$self->GetVerband."_animal" if ($ssql eq ' ');
	   #$ssql="select distinct db_sire from animal" if ($ssql eq ' ');
	   #$statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue)
	   #            SELECT '".$group."', '".$class."',$self->GetStAnimal($self->GetVerband).
 ##		               ",'".$trait."',".$funkt."
#		       FROM ".$self->GetVerband."_".$nr_vgzw."_".$kat." as a, ".
#		              "animal as b,". 
#		              "animal as c 
#		       WHERE a.animal IN (".$ssql.") and 
#		             a.animal=b.db_animal and
#			     a.animal=c.db_animal and
#		             b.db_sire=c.db_sire and
#			     b.db_dam=c.db_dam
#		       GROUP BY b.db_animal";
	   
	  } elsif ($class=~/nk/i) {
	   $ssql="select distinct ".$self->GetFieldNameSire." from ".$self->GetStTable($self->GetVerband) if ($ssql eq ' ');
	   $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue)
	               SELECT '".$group."', '".$class."',". $self->GetFieldNameSire .",'".$trait."',".$funkt."
		       FROM ".$self->GetVerband."_".$nr_vgzw."_".$kat." as a, ".
		              $self->GetStTable($self->GetVerband)." as b 
		       WHERE a.animal=".$self->GetStAnimal($self->GetVerband)." and 
		             b.".$self->GetFieldNameSire." IN (".$ssql.")
		       GROUP BY b.".$self->GetFieldNameSire;
	   
	  } else { 
 	    $statement="INSERT INTO ".$self->GetVerband."_save (vgroup,vclass,veffect,vtrait,vvalue) 
                      SELECT '".$group."' as a, '".$class."' as b, a.".$class.",'".$trait."',".$funkt." 
	              FROM ".$self->GetVerband."_".$nr_vgzw."_".$kat." as a ".$ssql . 
		      $where .
		      $group_by;
	  }	      
          $self->Execute($statement,"Daten nach mszv_save.");
	}
       }
      }
    }
  }
}


#####################################################################
sub Relativierung {
#####################################################################
    my($t1,$t2);
    my $self=shift;
    my $vtb=shift(@_);
    my $nr_vgzw=$self->{'tbvs'}->{$vtb}->{'estimation'}[0];
    my $vtbn=$self->{'tbvs'}->{$vtb}->{'tbvn'}[0];
    my $pest_par=$self->{'alias'}->{$nr_vgzw};
 
    undef $traits;
    undef $traits_rel;
    
    #######################################################
    # Relativierung
    #######################################################
    #Wenn 'estimation'='', dann wird davon ausgegangen, daß die Merkmale
    #bereits relativiert sind.
    
    #--- Mittelwert ermitteln für Effekte, wenn es ein ZWS-Listfile gibt
    if ((defined $pest_par) and ($pest_par ne '')) {
        ($traits,$traits_rel)=$self->GetTraitsEFF($vtb);
        my @fields=();
        my @mfields=();
        my @mfields1=();
        foreach (@{$traits}) {
            push(@fields,"mw".$_." FLOAT");
            push(@mfields,"AVG(".$_.")");
            push(@mfields1,"mw".$_);
        }

        #-- temporäre Tabelle erstellen
        $statement="CREATE TABLE temp (class text,".join(',',@fields).")";
        $self->Execute($statement,"temp erstellen");

        #--- temporäre Tabelle mit Mittelwerten der Effekte füllen
        $statement="INSERT INTO temp SELECT effect_class,".join(',',@mfields).
                   " FROM ".$self->GetVerband."_".$nr_vgzw."_effects GROUP BY effect_class";
        $self->Execute($statement,"Mittelwerte für $nr_vgzw berechnen");

        #--- Mittelwerte aus temp holen
        $statement="SELECT class,".join(',',@mfields1)." FROM temp";
        my @feld=$self->GetExecute($statement,"$nr_vgzw : $@");

        #--- Schleife über alle Effektklassen und Abweichung für diese Effektlasse bilden
        foreach $row (@feld) {
            my @field=();
            my $class=shift @$row;
            my $i=0;
            foreach $dat (@$traits){
                push(@field,"$traits_rel->[$i] = $dat - $row->[$i]") if (defined $row->[$i]);
                $i++;
            }
      
            $statement="UPDATE ".$self->GetVerband."_".$nr_vgzw."_effects SET ".join(',',@field)." WHERE effect_class='$class'";
            $self->Execute($statement,"Abweichungen für den Effekt:$class  der ZWS:$nr_vgzw berechnen");
        }   

        $statement="DROP TABLE temp";
        $self->Execute($statement,"temp löschen");
    }

    #--- Wenn Daten über eine SQL geholt werden sollen, data=$SQL
    if (exists $self->{'tbvs'}->{$vtb}->{'data'}) {
        ($traits,$wi,$traits_rel)=$self->GetTraitsTBV($vtb);
        my $j=0;
        my @feld=$self->GetExecute($self->{'tbvs'}->{$vtb}->{'data'},"$nr_vgzw : $@");
    
        #--- Schleife über alle Effektklassen und Abweichung für diese Effektlasse bilden
        foreach $row (@feld) {
            my @field=();
            for ($i=0;$i<=$#{$row};$i++) {
                push(@field,$row->[$i]);
            }
        
            $statement="INSERT INTO ".$self->GetVerband."_".$nr_vgzw
                       ."_bv (db_owner,db_id,animal,".join(',', @{$traits}).") VALUES ('"
                       .$self->GetOwner."',".$j++.",".join(',',@field).")";
            $self->Execute($statement,"");
        }
    }

    #--- Berechnung der Relativzuchtwerte und des Gesamtzuchtwertes
    #---------------  Schleife über alle Gruppen für die der Gesamtzuchtwert gilt
    my $i=0;$std='';@ar_std=();@ar_wi=();@ar_vg=();@ar_se=();@ar_wig=();
    my @ar_wiv=();
    my @ar_se_traits=();

    #--- genetische Varianz ermitteln
    if (($self->GetWiRelModus($vtb) eq 'SG') or ($self->GetWiRelModus($vtb) eq 'SZ')) {
        @ar_vg=@{$self->{'pest'}->{$pest_par}->{'VG'}->{'animal'}->{'VARIANZEN'}};
    }

    $vzwisssdb=$self->GetVerband."_".$nr_vgzw."_".'bv';
  
    #-- Loop over all groups    
    foreach $t (@{$self->{'tbvs'}->{$vtb}->{'for_groups'}}) {

        #-- population 
        $stp=@{$self->{'groups'}->{$t}->{'breed'}}[0];

        #-- base-populatoin 
        $stb=@{$self->{'groups'}->{$t}->{'base_animals'}}[0];

        #--- Alle gültigen Tiere ermitteln, die gemittelt werden sollen
        $st_table=$self->GetStTable($self->GetVerband);

        #-- fieldname for animal (apiis=>db_animal)
        $st_animal=$self->GetStAnimal();

        #-- create statement
        $statement='SELECT '.$st_table.'.'.$st_animal.'
                    FROM  '.$st_table.', '.$vzwisssdb.' as b
                    WHERE ('.$st_table.'.'.$st_animal.'=b.animal) and ('.$stp.')';

        #-- execute statement                             
        my @animals=$self->GetExecute($statement,"$t -> $@");

        #-- declare 
        @ar_std=();@ar_se=(); @ar_se_traits=(); @ar_wig=(); @ar_wiv=(); $t1='-'; $t2='-';

        #-------------- Schleife über alle Merkmale aller Zuchtwertschätzungen ----------------
        if ((! exists $self->{'tbvs'}->{$vtb}->{'relat'}) or ($self->{'tbvs'}->{$vtb}->{'relat'} eq 'yes')) {
      
            ($traits,$wi,$traits_rel)=$self->GetTraitsTBV($vtb);
      
            #-- umspeichern 
            @ar_wi=@{$wi};
            my $i=0;

            foreach (@{$traits}) {
        
                $se_value=$_;
                $se_value=~s/^bv/bvse/;


                push(@ar_se,'(1-(('.$se_value.'*'.$se_value.')/'.$ar_vg[$i].'))');
                push(@ar_se_traits,$se_value);
        
                #-- berücksichtige die Genauigkeit der Zuchtwerte
                if ($self->GetBVSEModus($vtb)=~/yes|ja|true|y|j|t/i) {
                    push(@ar_std,'count('.$_.') as CO'.$i
                                .', AVG('."$ar_se[$i]*$_".') as AV'.$i
                                .', '.$self->GetFunctionStddev.'('."$ar_se[$i]*$_".') as ST'.$i
                                .', MIN('."$ar_se[$i]*$_".') as MI'.$i
                                .', MAX('."$ar_se[$i]*$_".') as MA'.$i);
                } else {
                    push(@ar_std,'count('.$_.') as CO'.$i
                                .', AVG('.$_.') as AV'.$i
                                .', '.$self->GetFunctionStddev.'('.$_.') as ST'.$i
                                .', MIN('.$_.') as MI'.$i.', MAX('.$_.') as MA'.$i);
                }
                $i++;
            }
      
            $std=join(',',@ar_std);

            #-- Wenn Gruppen definiert sind
            if ($self->{'groups'}->{$t}->{'breed'} ne '') {

                #--- Basistiere müssen Eltern sein
                if ($self->GetParents($t)=~/yes|y|ja|j|true|t/i) {

                    #--- Eltern für die aktuelle Zuchtwertschätzung bestimmen und Abspeichern
                    $statement="DROP TABLE temp_parents";
                    $self->Execute($statement,'Löschen von TEMP_PARENTS');
	  
                    #-- if a apiis-database    
                    if ($opt{'a'} ) {
                        $statement='CREATE TABLE temp_parents (animal INTEGER, geschlecht char(1));';
	                } else {  
                        $statement='CREATE TABLE temp_parents (animal CHAR(16), geschlecht char(1));';
	                }  
                    
                    #-- Execute statement 
                    $self->Execute($statement,'Erstellen von TEMP_PARENTS');

                    #-- Schreibe alle Eltern nach temp_parents 
                    $statement="insert into temp_parents (animal,geschlecht) select distinct "
                              .$self->GetFieldNameSire.", 1 from ".$st_table.","
                              .$self->GetVerband."_".$nr_vgzw."_bv as b where (".$st_table.".".$st_animal."=b.animal) and ".$stb.";";

                    #-- execute
                    $self->Execute($statement,'m_p nach temp_parents');

                    $statement="insert into temp_parents (animal,geschlecht) select distinct "
                               .$self->GetFieldNameDam.", 2 from ".$st_table.","
                               .$self->GetVerband."_".$nr_vgzw."_bv as b where (".$st_table.".".$st_animal."=b.animal) and ".$stb.";";

                    #-- execute 
                    $self->Execute($statement,'f_p nach temp_parents');

                    #-- create index 
                    $statement='CREATE UNIQUE INDEX temp_parents_animal ON temp_parents (animal);';
                    $self->Execute($statement,'Erstellen INDEX animal TEMP_PARENTS');
	  

                    $statement='SELECT '.$std.'
                                FROM  '.$vzwisssdb.' as o RIGHT JOIN temp_parents as d ON (d.animal=o.animal)';
                } else {
                    $statement='SELECT '.$std.'
                                FROM  '.$vzwisssdb.' as o
                                RIGHT JOIN '.$st_table.' ON '.$st_table.'.'.$st_animal.'=o.animal
                                WHERE ('.$stb.')';
                }

                @statistik_base=$self->GetExecute($statement,"$t -> $@");
            } else {
                @statistik_base=();
            }


            #--- Statistik für die Population
            $statement='SELECT '.$std.'
                        FROM  '.$vzwisssdb.' as o
                        RIGHT JOIN '.$st_table.' ON '.$st_table.'.'.$st_animal.'=o.animal
                        WHERE ('.$stp.')';
            
            #-- execute                           
            @statistik_population=$self->GetExecute($statement,"$t -> $@");

            #Wichtungsfaktoren relativieren
            $j=0;
      
            #-- Schleife über alle ZuchtwertMerkmale 
            for ($i=0;$i<=$#{$traits};$i++){
    
                #-- Wenn Wichtungsfaktoren auf genetische Standardabweichung beziehen 
                if ($self->GetWiRelModus($vtb) eq 'SG'){

                    #-- wenn Genetische Standardabweichung > 0
                    if ($ar_vg[$i] > 0) {

                        #-- Gewicht = Faktor/Wurzel(genetische Varianz)
                        $vwi =$wi->[$i]/sqrt($ar_vg[$i]);
                        
                        #-- Gewicht = Faktor/genetische Varianz
                        $vwiv=$wi->[$i]/$ar_vg[$i];

                    } else {

                        #-- Wichtungsfaktoren werden nicht verändert 
                        $vwi=$wi->[$i];
                    }

                    #-- umspeichern in ein ARRAY 
                    push(@ar_wig,$vwi);
                    push(@ar_wiv,$vwiv);
                }

                #-- Relativierung auf die Standardabweichung der Zuchtwerte 
                elsif ($self->GetWiRelModus($vtb) eq 'SZ') {

                    #-- wenn Standardabweichung > 0
                    if ($statistik_population[0]->[$j+2] >0) {
                        
                        #-- Wichtung/Standardabweichung 
                        $vwi=$wi->[$i]/$statistik_population[0]->[$j+2];

                        #-- Wichtung / Varianz der Zuchtwerte 
                        $vwiv=$wi->[$i]/($statistik_population[0]->[$j+2]*$statistik_population[0]->[$j+2]);
                    } else {
                        $vwi=$wi->[$i];
                    }

                    #-- umspeichern in ein ARRAY 
                    push(@ar_wig,$vwi);
                    push(@ar_wiv,$vwiv);
                } 
                
                #--- wi sind bereits auf eine genetische Standardabweichung bezogen.
                else {

                    $vwi=$wi->[$i];
                    push(@ar_wig,$vwi);
                    
                    #---noch nicht ganz klar
                    push(@ar_wiv,$vwi);
                }
            }

            #--- Für die benannte Zucht die Abweichungen von Vergleichsmaßstab berechnen
            #--- und Vorzeichen umkehren, wenn im züchterischen Sinne interpretiert wird.
            
            #-- declare    
            my @field=();
            my $j=0;
            @ar_std=();
            $i=0;
      
            #-- Schleife über alle Zuchtzielmerkmale 
            for ($i=0;$i<=$#{$traits};$i++){

                #-- Vorzeichen setzen in Abhängigkeit der WI-Faktors  
                if ($ar_wi[$i]<0) {
                    $vz=-1;
                } else {
                    $vz=1;
                }

                #-- Wenn jeden Zuchtwert regressieren
                if ($self->GetBVSEModus($vtb)=~/yes|ja|true|y|j|t/i) {

                    #-- Abweichungen im züchterischen Sinne
                    #-- ZWrel=((Genauigkeit*ZWnat)-BASISmw)*Vorzeichen
                    push(@field,"$traits_rel->[$i] = (($ar_se[$i]*$traits->[$i]) - $statistik_base[0]->[$j+1])*$vz");
          
                    # ohne $vz für den GZW
                    $field="($ar_se[$i]*$traits->[$i]) - $statistik_base[0]->[$j+1]";

                } 

                #-- Wenn Zuchtwerte nicht regressieren
                else {
    
                    #-- wenn es Population gibt
                    if ($self->{'groups'}->{$t}->{'breed'} ne '') {

                        #-- ZWrel=((ZWnat-BASISmw)*Vorzeichen
                        push(@field,"$traits_rel->[$i] = ($traits->[$i] - $statistik_base[0]->[$j+1])*$vz");

                        #-- Zwischenspeichern für Berechnung des GZW
                        $field="$traits->[$i] - $statistik_base[0]->[$j+1]";
                    } 

                    #-- wenn kein breed definiert ist
                    else {

                        
                        #-- ZWrel=((ZWnat)*Vorzeichen
                        push(@field,"$traits_rel->[$i] = ($traits->[$i])*$vz");

                        #-- Zwischenspeichern für Berechnung des GZW
                        $field="$traits->[$i]";
                    }
                }
       
                #-- um 5 erhöhen -> nächstes Merkmale (N,AVG,STD,MIN,MAX) 
                $j=$j+5;

                push(@ar_std,'('.$field.')'.'*'.$ar_wig[$i]);
            }

            #-- GWZ=Trait1+Trait2+Trait3...
            $std="$vtbn=(".join(')+(',@ar_std).")";      

            #--Wenn Genauigkeit des Gesamtzuchtwertes ausgegeben werden soll
            $std1=''; # berechnungsgrundlage prüfen! (rffr)

            if (($self->GetTBVSEModus($vtb)=~/r/) and ($#ar_vg>-1)) {
#            
#                #-- init 
#                @a1=();
#                @a2=();
#
#                #-- Loop über alle Wichtungsfaktoren 
#                for ($i=0;$i<=$#ar_wiv;$i++) {
#
#                    #-- |wichtungsfaktor|*Genauigkeit 
#                    push(@a1,abs($ar_wiv[$i]).'*'.$ar_se_traits[$i]);
#                }
#
#                #$t0='('.join(')+(',@a1).')';
#                $t0=join('+',@a1);
#
#                for ($i=0;$i<=$#ar_wiv;$i++) {
#                    push(@a2,'('.$t0.')*'.abs($ar_wiv[$i]));
#                }
#                
#                $t5='('.join(')+(',@a2).')';
#
#                @a1=();
#                @a2=();
#            
#                for ($i=0;$i<=$#ar_wiv;$i++) {
#                    push(@a1,abs($ar_wiv[$i]).'*'.$ar_vg[$i]);
#                }
#        
#                $t1=join('+',@a1);
#
#                for ($i=0;$i<=$#ar_wiv;$i++) {
#                    
#                    push(@a2,'('.$t1.')*'.abs($ar_wiv[$i]));
#                }
#        
#                $t3='('.join('+',@a2).')';
#
#                if ($self->GetTBVSEModus($vtb)=~/r2/) {
#                    $t4='1-('.$t5.'/'.$t3.')';
#                } 
#                else {
#
#                    $t4='sqrt(1-('.$t5.'/'.$t3.'))';
#                }
#
#                $std1=', se'.$vtbn.'='.$t4;
#                $std1=', se'.$vtbn.'=('.$t4.')*100' if ($self->GetTBVSEModus($vtb)=~/%/);
#                
                if (( $self->GetTBVSEModus($vtb) eq 'r%' ) or ( $self->GetTBVSEModus($vtb) eq 'r' )){
                    map{$_='sqrt(case when '.$_.'>0 then '.$_.' else 0 end )'} @ar_se;
                }

                #-- mittlere Genauigkeit der Merkmale
                my $setbv='('.join('+',@ar_se).')/('.$#ar_se.'+1)';
                
                $std1=', se'.$vtbn.'='.$setbv;
                $std1=', se'.$vtbn.'=('.$setbv.')*100' if ($self->GetTBVSEModus($vtb)=~/%/);
            }

            foreach $a (@animals) {
                $statement="UPDATE ".$self->GetVerband."_".$nr_vgzw."_bv SET ".join(',',@field).", ".$std." ". $std1 ." WHERE animal=".$a->[0];
                $self->Execute($statement,"");
            }

            ($t1,$t2)=$self->GetStandardisation($vtb);

            #Berechnen des Mittelwertes und der Standardabweichung des Gesamtzuchtwertes
            $std='';$statement='';

            $std='count('.$vtbn.') as CO'.$i.', AVG('.$vtbn.') as AV'.$i.', '.$self->GetFunctionStddev.'('.$vtbn.') as ST'.$i.
                 ', MIN('.$vtbn.') as MI'.$i.', MAX('.$vtbn.') as MA'.$i;

            $statement='SELECT '.$std.'
                        FROM  '.$vzwisssdb.' as o
                        RIGHT JOIN '.$st_table.' ON '.$st_table.'.'.$st_animal.'=o.animal
                        WHERE ('.$stp.')';

            @row=$self->GetExecute($statement,"$vtb -> Statistik Standardisierung Gesamtzuchtwert");
            $vmw=0;$vsa=1;
            
            # relative Zuchtwerte in den Statistik-Hash schreiben
            foreach (@row) {
                $vmw=$_->[1];
                $vsa=$_->[2];
            }

            #Zuchtwerte standardisieren;
            foreach $a (@animals) {
#                $statement='UPDATE '.$vzwisssdb.' SET '.$vtbn.' = ('.$vtbn.'-'.$vmw.')/'.$vsa.'*'.$t2.'+'.$t1   
#                          ." WHERE animal='".$a->[0]."'";
                $statement='UPDATE '.$vzwisssdb.' SET '.$vtbn.' = ('.$vtbn.')/'.$vsa.'*'.$t2.'+'.$t1   
                          ." WHERE animal=".$a->[0];
                $self->Execute($statement,"");
            }
        }

        ###########################################################
        # Statistik
        ###########################################################
        $self->FehlerProtokoll("Statistik der Basis",'-');
        $self->FehlerProtokoll("\n############### $vtb ##############\n","");
        $self->FehlerProtokoll("$vtb\tMittelwert = $t1, Standardabweichung = $t2",'-');
        $i=0;
        $self->FehlerProtokoll("\tMerkmale und Wichtung",'-');
        foreach $dat (@{$traits}) {
            $self->FehlerProtokoll("\t  $dat * @{$wi}[$i]",'-');
            $i++
        }

        $self->FehlerProtokoll("\tBasistiere: ",'-');
        $self->FehlerProtokoll("\t  $stb",'-');
        $self->FehlerProtokoll("\tGZW gilt für: ",'-');
        $self->FehlerProtokoll("\t  $stp",'-');
        $self->FehlerProtokoll("\tStatistik der Basistiere",'-');
        $druck="";
        $druck.="Merkmale\tN\t\tMW\t\tSTA\t\tMIN\t\tMAX";
        $self->FehlerProtokoll("$druck",'-');
        if ($self->{'groups'}->{$t}->{'breed'} ne '') {
            $j=0;
            foreach (@{$traits}) {
                if (length($_) <= 8) {
                    $druck="$_\t\t".${FormatReal($statistik_base[0]->[$j],0)};
                } else {
                    $druck="$_\t".${FormatReal($statistik_base[0]->[$j],0)};
                }
                $druck.="\t".${FormatReal($statistik_base[0]->[$j+1],8)};
                $druck.="\t".${FormatReal($statistik_base[0]->[$j+2],8)};
                $druck.="\t".${FormatReal($statistik_base[0]->[$j+3],8)};
                $druck.="\t".${FormatReal($statistik_base[0]->[$j+4],8)};
                $self->FehlerProtokoll("$druck",'-');
                $j=$j+5;
            }
        } 
        else {
            $self->FehlerProtokoll("\tKeine Basis angegeben",'-');
        }
        $self->FehlerProtokoll("\tStatistik der Population",'-');
        $druck="";
        $druck.="Merkmale\tN\t\tMW\t\tSTA\t\tMIN\t\tMAX";
        $self->FehlerProtokoll("$druck",'-');
        $j=0;
        
        foreach (@{$traits}) {
            if (length($_) <= 8) {
                $druck="$_\t\t".${FormatReal($statistik_population[0]->[$j],0)};
            } else {
                $druck="$_\t".${FormatReal($statistik_population[0]->[$j],0)};
            }
            $druck="$_\t".${FormatReal($statistik_population[0]->[$j],0)};
            $druck.="\t".${FormatReal($statistik_population[0]->[$j+1],8)};
            $druck.="\t".${FormatReal($statistik_population[0]->[$j+2],8)};
            $druck.="\t".${FormatReal($statistik_population[0]->[$j+3],8)};
            $druck.="\t".${FormatReal($statistik_population[0]->[$j+4],8)};
            $self->FehlerProtokoll("$druck",'-');
            $j=$j+5;
        }
        $self->FehlerProtokoll("",'-');
        $self->FehlerProtokoll("",'-');
    }
    
    return 0;
}

#####################################################################
sub CreateNewPest {
#####################################################################
  my $self=shift;
  my %opts;
  $opts{MODEL} = $model_file;
  $opts{-t}    = 'new_pest';
  #$opts{-d}    = '1'; # get error because indices would also be dropped
  # indices are already deleted when table drop

  my $return_list_ref = MakeSQL( \%opts );
#   open ( OUT, ">tmp" );
#   print OUT "@$return_list_ref";
#   close ( OUT );

  my $sqld = "DROP TABLE old_pest";
  ( $sth, $status, $err_msg ) = RunSQL( $sqld );
  if ( $status ) {
    print "table old_pest cannot deleted\n";
  } else {
    $dbh->commit;
  }
  my $sqlc = "CREATE TABLE old_pest AS SELECT * FROM new_pest";
  ( $sth, $status, $err_msg ) = RunSQL( $sqlc );
  if ( $status ) {
    print "table pest_old cannot created\n";
  } else {
    $dbh->commit;
  }
  my $sqld2 = "DROP TABLE new_pest";
  ( $sth, $status, $err_msg ) = RunSQL( $sqld2 );
  if ( $status ) {
    print "table old_pest cannot deleted\n";
  } else {
    $dbh->commit;
  }

  foreach $tt ( @$return_list_ref ) {
    my @ttt = split( ';', $tt );
    foreach $ttt ( @ttt ) {
      if ( $ttt =~ /-- DROP VIEW/ ) {
        my $sqltt = $ttt;
        $sqltt =~ s/-- (.*?)// ;
        ( $sth, $status, $err_msg ) = RunSQL( $sqltt );
        $dbh->commit;
      }
      if ( $ttt =~ /CREATE .*? INDEX/ ) {
        my $sqltt = $ttt;
        $sqltt =~ s/new/old/g;
        ( $sth, $status, $err_msg ) = RunSQL( $sqltt );
      }
    }
  }

  $statement="DROP TABLE old_pest";
  $self->Execute($statement,'Löschen von old_pest');
  $statement='CREATE TABLE new_pest (class text, key text, type text,  estimator float, pev float;';
  $self->Execute($statement,'Erstellen von ');


}

#####################################################################
sub Export {
#####################################################################
#################################################################
sub Round {
#################################################################
  my ($num,$dez)=@_;
  my ($nk,$vk,$i);
  $dez=0 	if (! defined $dez);
  return undef 	if ((! defined $num) or ($num=~/e/));

  $num=~s/,/./;
  my $vz='';
  if ($num=~/^\-|\+/) {
    $vz=substr($num,0,1) if ($num=~/^\-|\+/);
    $num=substr($num,1,length($num)-1);
  }
  ($vk,$nk)=split('\.',$num);
  return $vz.$num if ((! defined ($nk)) and ($dez==0));

  if (((! defined $nk) and ($dez>0))  or (length($nk)<$dez)) {
    $num.='.' if (! defined $nk);
    if (! defined $nk) {
       $j=0;
    } else {
       $j=length($nk);
    }
    for ($i=$j;$i<$dez;$i++) {
      $num.='0';
    }
  } else {
    if (length($nk)>$dez) {
      if ($dez>0) {
        $num=$vk.'.'.substr($nk,0,$dez) ;
      } else {
        $num=$vk;
      }
      if (substr($nk,$dez,$dez+1)>=5) {
        $num=$num+1*10**-($dez);
      }
    }
  }
  #-- Nochmal wiederholen, falls beim Runden die Kommastellen weggefallen sind.
  ($vk,$nk)=split('\.',$num);
  return $vz.$num if ((! defined ($nk)) and ($dez==0));
  if (((! defined $nk) and ($dez>0))  or (length($nk)<$dez)) {
    if (! defined $nk) {
      $num.='.';
      $j=0;
    } else {
      $j=length($nk);
    }
    for ($i=$j;$i<$dez;$i++) {
      $num.='0';
    }
  }
  return $vz.$num;
}


use Compress::Zlib;
#use MIME::Lite;
#use Net::Telnet;
#use Net::FTP;

  my $self=shift;
  my $vformat=shift(@_);
  my $j=0;my $dat; my $i;
  my %hs_traits=();my $stb='';my @export_fmt=();

  # $self->SetExport($vformat);

  #--- Schleife über alle zu exportierenden Felder eines Exportformates
  $i=0;%hs_export=();
  foreach $dat (@{$self->{'export'}->{$vformat}->{'fields'}}) {
    $hs_export{$dat}=$i++;
    push(@export_fmt,$dat);
  }

  #--- Alle Tiere einlesen
  my @ar_daten=(); 
  $statement="SELECT animal from ".$self->GetVerband."_animal";
  @row=$self->GetExecute($statement," -> SELECT: $@");
  $i=0;
  foreach $dat1 (@row) {
    $hs_animal{$dat1->[0]}=$i++;
    push(@ar_daten,[]);
  }

  #--- Schleife über alle Tabellen
  while (($key,$value)=each %{$self->{'tables'}}) {
    @fields=();
    @alias=();
    @col=();
    #--- alle Aliase aus der Tabelle herausfiltern mit den entsprechenden COLUMNS und nur die übernehmen
    #--- die in der Schnittstelle definiert sind.
    foreach $dat (keys %$value) {
      if ((exists $value->{$dat}->{'EXPORT_ALIAS'}) and (exists $hs_export{$value->{$dat}->{'EXPORT_ALIAS'}})){
        push(@col,$dat);
        push(@fields,$value->{$dat}->{'DB_COLUMN'});
        push(@alias,$value->{$dat}->{'EXPORT_ALIAS'});
      }
    }
    next if ($#col==-1);
    $statement="SELECT animal as __a__,".join(',',@fields)." FROM $key";
    @row=$self->GetExecute($statement," -> SELECT: $key: $@");
    foreach $dat1 (@row) {
#      $tt=$hs_animal{$dat1->[0]};
      $animal=shift @$dat1;
      #für Test
      next if (! exists $hs_animal{$animal});
#      if ($animal eq '132331203') {
#        print "kk";
#      }

      for ($j=0;$j<=$#{$dat1};$j++) {
        next if (! defined $dat1->[$j]);
        #-- Formatieren
        if ($value->{$col[$j]}->{'DATATYPE'}  eq 'z') {
           $dat1->[$j]=&main::Round($dat1->[$j],$value->{$col[$j]}->{'DECIMALS'});
        } else {
          if (($self->{'export'}->{$vformat}->{'typ'} eq 'CSV')) {
            $dat1->[$j]='"'.$dat1->[$j].'"';
          }
        }
#        if ((! defined $alias[$j]) or (! defined $hs_export{$alias[$j]}) or 
#            (! defined $hs_animal{$animal}) or (! defined $ar_daten[$hs_animal{$animal}])) {
# print "KK";
#        }
        $ar_daten[$hs_animal{$animal}]->[$hs_export{$alias[$j]}]=$dat1->[$j];
      }
#     $hs_animal{$dat1->[0]}=$tt;
    }
  }

  #--- Wegschreiben der Daten in ein ZIP-File
  $self->FehlerProtokoll("ZIP von $self->{'export'}->{$vformat}->{'datei'}","-");
  $sc_base=$self->{'export'}->{$vformat}->{'datei'}.".gz";
  $gz = gzopen($sc_base, "wb");

  if ($self->{'export'}->{$vformat}->{'typ'} eq 'CSV') {
    $gz->gzwrite(join(',',@export_fmt)."\r\n");
  } else {
    $gz->gzwrite(join(';',@export_fmt)."\r\n");
  }
  foreach (sort keys %hs_animal) {
    #Zeile zippen und rausschreiben
    @tt=@{$ar_daten[$hs_animal{$_}]};
    #überspringen, wenn nur die Tiernummer drinsteht
    my $z=0;
    foreach (@tt) {
      $z++ if (defined $_);
    }
    next if ($z == 1
) ;
    $i=0;
    for ($i=0;$i<=$#export_fmt;$i++) {
      $tt[$i]='' if (! defined $tt[$i]);
    }  
    if ($self->{'export'}->{$vformat}->{'typ'} eq 'CSV') {
      $gz->gzwrite(join(',',@tt)."\r\n")  || die "Schreiben $sc_base: $gzerrno" ;
    } else {
      $gz->gzwrite(join(';',@tt)."\r\n")  || die "Schreiben $sc_base: $gzerrno" ;
    }
  }
  $gz->gzclose ;
  if (! $@) {
    $self->FehlerProtokoll("Schreiben $sc_base",'O');
  } else {
    $self->FehlerProtokoll("$@","E");
  }

  #Mail an die angegebene Adresse versenden, wenn TO definiert ist
  if (exists $self->{'export'}->{$vformat}->{'to'}) {
    $self->FehlerProtokoll("Mail an $self->{'export'}->{$vformat}->{'to'}","-");
    $msg = MIME::Lite->new(
           From     =>$self->{'export'}->{$vformat}->{'from'},
           To       =>$self->{'export'}->{$vformat}->{'to'},
           Cc       =>$self->{'export'}->{$vformat}->{'cc'},
           Subject  =>$self->{'export'}->{$vformat}->{'subject'},
           Type     =>"multipart/mixed",
           );
    $msg->attach(
           Type     =>"application/zip",
           Encoding =>"base64",
           Path     =>$sc_base,
           filename =>$sc_base
          );
    eval {
      $msg->send('smtp', "mailto.btx.dtag.de", Timeout=>60);
    };

    if (! $@) {
      $self->FehlerProtokoll("    - $sc_base versenden",'O');
    } else {
      $self->FehlerProtokoll("    - $sc_base versenden",'E');
    }
  }
}

#####################################################################
sub SetExport {
#####################################################################
  my $self=shift;
  my $vformat=shift(@_);
  my $hs_alias_pos={};
  my $j=0; my $dat; my $i;

  #--- alle Aliase aus export ermitteln und mit einer positionsnummer versehen
  $hs_alias_pos->{'animal'}=$j++;
  foreach $dat (@{$self->{'export'}->{$vformat}->{'fields'}}) {
    for ($i=1;$i<= $#$dat;$i++) {
      $hs_alias_pos->{$dat->[$i]}=$j++ if (! exists  $hs_alias_pos->{$dat->[$i]});
    }
  }
}
sub GetFunctionStddev {return 'STD'};
sub GetFieldNameSire {return 'm_p'};
sub GetFieldNameDam {return 'f_p'};


#################################################################
package ZwsApiis;
@ZwsApiis::ISA=qw (CalcTBV);
#################################################################
use strict;
use Apiis::Init;
###################################################################################
sub new {
  my $class =shift;
  my $model=shift;
  my $apiis=shift;
  
  my $self=$class->SUPER::new($model);
  $self->{'apiis'}=$apiis;
  #$apiis->join_model($model);
  $self->{'dbh'}=$apiis->DataBase->dbh;
  return $self;
}
#################################################################
sub SetDBH {
  my $self=shift;
}

###############################################################################
sub Execute {
###############################################################################
  my(@arr,$dbh);
  my $self=shift;
  my $statement=shift @_;
  my $text=shift @_;
  eval {
    my $sql_ref = $self->{'apiis'}->DataBase->sys_sql($statement);
    $apiis->check_status;
    $apiis->DataBase->dbh->commit;
  };
  if (! $@) {
    $self->FehlerProtokoll($text,'O');
    return 0;
  } else {
    #print $statement;
    $self->FehlerProtokoll("$text: $@","E");
    return 1;
  }
}

###############################################################################
#sub ReadDataPest {
#}

###############################################################################
#sub ReadWriteRelationship {
#}  

################################################################################
sub GetStTable {
  my $self = shift;
  return 'animal';
}

###############################################################################
sub GetOwner {
###############################################################################
  my $self=shift;
  return $self->{'apiis'}->User->id;
}

################################################################################
sub GetStAnimal {
################################################################################
  my $self=shift;
  return "db_animal";
}

sub GetFunctionStddev {return 'STDDEV'};
sub GetFieldNameSire {return 'db_sire'};
sub GetFieldNameDam {return 'db_dam'};

1;

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

