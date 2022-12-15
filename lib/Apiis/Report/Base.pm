###################################################################################
#
# $Id: Base.pm,v 1.8 2004/11/24 09:01:00 ulm Exp $
###################################################################################

package Apiis::Report::Base;
use Carp;
#use i18n_apiis;
  
#@Apiis::Report::Base::ISA = qw( Apiis::Report::Init );

sub new {
   my ( $invocant, %args ) = @_;
   #  croak _("Missing initialisation in main file ([_1]).", __PACKAGE__ ) . "\n"
   #   #    unless defined $apiis;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);
   return $self;
}

##############################################################################
sub _init {
  use Apiis::Report::InitXML;
  my ( $self, %args ) = @_;
  my $pack = __PACKAGE__;
  return if $self->{"_init"}{$pack}++;    # Conway p. 243

  $self->{"_SetColumnBusy"} = [];
  $self->{"_Apiis"}=$args{'apiis'};
  $self->{"_Report"}=$args{'report'};
  $args{"xml"}=$args{'report'};
  $self->{"_Status"} = undef;
  $self->{"_Query"}='';
  $self->{"_Errors"}=[];
  $self->{'_Reportobj'}=Apiis::Report::InitXML->new(%args);

  if ($self->{'_Reportobj'}->Status) {
    $self->{"_Errors"}=$self->{'_Reportobj'}->Errors;
    $self->{'_Status'}=1;
  }  

  if ( exists $args{'query'} ) {
    $self->{'_Query'}=$args{'query'};
  } else {
    push @{ $self->{"_Errors"} },
    Apiis::Errors->new(
      type      => 'CODE',
      severity  => 'ERR',
      from      => 'Apiis::Report::Base',
     #   msg_short => __("No query from CGI", 'report', 'Apiis::Report::Base'),
    );
  }

  foreach my $thiskey (qw/ Query Apiis Report Status Errors XMLElements Reportobj/) {
     no strict "refs";
     *{$thiskey} = sub { return $_[0]->{"_$thiskey"} };
  }


}

###################################################################################
sub GetModelName {
###################################################################################
  my $self=shift;
 
 eval {
  opendir(DIR, "$APIIS_LOCAL/etc/") or
     push @{ $self->{"_Errors"} },
       Apiis::Errors->new(
           type      => 'CODE',
           severity  => 'ERR',
           from      => 'Apiis::Report::Base',
           msg_short => __("Can't open directory $APIIS_LOCAL/etc/", 'report', 'Apiis::Report::Base'),
       );
  };
  
  my $model;
  while (defined($file = readdir(DIR))) {
    $model=$file if $file =~ /\.model$/; 
  }
  closedir(DIR);
} 
		  


###################################################################################
sub Refresh {
###################################################################################
  my $self=shift;

  #-- Schleife über alle Content-Felder alle Elemente,
  #-- Reihenfolge der Aktualisierung ermitteln
  my @right=();my @left; my %hs_v=();
  foreach my $field (@{$self->Reportobj->ContentFields}) {
    if ($self->Reportobj->$field->PositionSQL ne '') {
      if (($self->Reportobj->$field->ElementType eq 'Data') or 
          ($self->Reportobj->$field->ElementType eq 'Hidden')) {
        push(@left,$field);
      }	
      $hs_v{$field}=1;
    } else {
      if (($self->Reportobj->$field->ElementType eq 'Data') or 
          ($self->Reportobj->$field->ElementType eq 'Hidden')) {
        push(@right,$field);
      }	
    }
  }

  my $l=0;
  for (my $j=0;$j<=($#right * $#right);$j++) {
    foreach $name (@right) {
      if ($self->Reportobj->$name->{'Content'}=~/\[(.*)\]/) {
        if ((exists $hs_v{$1}) and (! exists $hs_v{$name})) {
          push(@left,$self->Reportobj->$name->Name);
	  $hs_v{$self->Reportobj->$name->Name}=1;
	}
      }
    }
  }

  #--- Felder hinten dran hängen, auf die kein Verweis zeigt, doppelte entfernen
  foreach my $name (@right) {
    if (! exists $hs_v{$name}) {
      push(@left,$name);
      $hs_v{$name}=1;
    }
  }

  #--- richtige Reihenfolge
  foreach my $name (@left) {
    if (( $self->Reportobj->$name->PositionSQL eq '') and ($self->Reportobj->$name->{'Content'}=~/\[(.*)\]/)) {
      if (! UNIVERSAL->can( $self->Reportobj->$name->Content)) {
        push @{ $self->{"_Errors"} },
           Apiis::Errors->new(
            type      => 'CODE',
            severity  => 'ERR',
            from      => 'Apiis::Report::Base',
            msg_short => "$1 ist nicht in *.rpt definiert",
         );
	 $self->{_Status}=1;
         return;
      } else {
        $self->Reportobj->$name->Content($self->Reportobj->$1->Content);
      }	 
    }
  }
}

sub ResetFooterObjects {
  my $self=shift;
  my $object=shift;
  foreach my $name (@{$self->Reportobj->$object->GroupFooterObjects}) {
    if ($self->Reportobj->$name->ElementType eq 'Data') {
      $self->Reportobj->$name->{'_n'}=0;
      $self->Reportobj->$name->{'_min'}=0;
      $self->Reportobj->$name->{'_max'}=0;
      $self->Reportobj->$name->{'_sum'}=0;
      $self->Reportobj->$name->{'_sum2'}=0;
      $self->Reportobj->$name->{'_first'}=0;
      $self->Reportobj->$name->{'_last'}=0;
      $self->Reportobj->$name->{'_QuestionChangeValue'}=undef;
    }
  }
}



###############################################################################
sub GetData {
###############################################################################
  my $self=shift;
  my $query=$self->Query;

  my $name=${$self->Reportobj->General}[0];
  no strict 'refs';
  my $statement=$self->Reportobj->$name->DataSource;
#  my @parameter=@{$self->{'_Parameter'}};
  #--- Parameter extrahieren
#         my @parameter=(); my $field;
#         push(@parameter,[$1,$2]) while $statement =~ m{ (\{([_a-zA-Z]?[_a-zA-Z0-9\s\.\,\:]*)\}) }xg;
#         foreach my $para (@parameter) {
#         if ($para->[1]=~/Name:(.*)/) {
#         $field=$1;
#         } else {
#         $field=$para->[1];
#         }
#         push(@{$para},$field);
#
#         #-- Argumente zuordnen von console oder aus CGI
#         if ($#ARGV==-1) {
#         push(@{$para},$query->param($field));
#         } else {
#         foreach (@ARGV) {
#                 if ($_=~/$field\=(.*)/) {
#                 push(@{$para},"'".$1."'") ;
#                 }
#         }
#         }
#         }

  #--- xml spezifika ersetzen
  $statement=~s/&gt;/>/g;
  $statement=~s/&lt;/</g;

  #--- Parameter ersetzen mit Eingabewerten
  while ((my $key, my $parameter)=each %{$self->{'_Parameter'}}) {
    $parameter->[0]=quotemeta($parameter->[0]);
    $statement=~s/$parameter->[0]/$parameter->[3]/;
    $err="Keine Parameter spezifiziert für $parameter->[2]\n" if (! $parameter->[3]);
  }

  #---
  #--- SQL
  my @data; my @structure; my $a;
  if ($statement=~/^\((.*)\)$/) {

    #--- offen: generale Abarbeitung, unabhängig von apiis
    my $sql_ref = $self->Apiis->DataBase->sys_sql($1);
    $self->Apiis->check_status;

    #-- Schleife über alle Daten, abspeichern im array
    while( my $q = $sql_ref->handle->fetch ) {
      push(@data,[@$q]);
    }
    ($a)=($statement=~/select(.*)from/ig);
    (@structure)=($a=~/\s+as\s+([\w|\d]*)/ig); 
    return \@data, [@structure];
  } elsif ($statement=~/^([_a-zA-Z0-9_]*)\((.*)\)$/) {
    my $module;
    my $vfunction=$1;
    my @vparam=split(',',$2);
    if (exists $ENV{'APIIS_LOCAL'}) {
      $module=$ENV{'APIIS_LOCAL'}."/etc/reports/".$self->Reportobj->basename.".pm";
    } else {
      $module="$1.pm";
    }  
    eval {
      require $module; #offen: Verzeichnisrechte und öffnen
    };
    if ($@) {
      push @{ $self->{"_Errors"} },
        Apiis::Errors->new(
         type      => 'CODE',
         severity  => 'ERR',
         from      => 'Apiis::Report::Base',
        # msg_short => __("Can't open modul ".$ENV{'APIIS_LOCAL'}."/etc/reports/".$self->Reportobj->basename.".pm",'report', 'Apiis::Report::Base'),
         msg_short => "Can't open modul ".$ENV{'APIIS_LOCAL'}."/etc/reports/".$self->Reportobj->basename.".pm",
         msg_long =>  "$@"
     );
     $self->{'_Status'}=1;
     return;
    }	
    # execute loadobject
    eval {
      @d = &$vfunction($self, @vparam);
    };  
    if ($@) {
      push @{ $self->{"_Errors"} },
       Apiis::Errors->new(
       type      => 'CODE',
       severity  => 'ERR',
       from      => 'Apiis::Report::Base',
      # msg_short => __("Can't open modul ".$ENV{'APIIS_LOCAL'}."/etc/reports/".$self->Reportobj->basename.".pm",'report', 'Apiis::Report::Base'),
       msg_short => "Can't execute function $vfunction in module: $module",
       msg_long =>  "$@"
       );
       $self->{'_Status'}=1;
       return;
     } 
     return @d;
  }
}

###############################################################################
sub MakeReport {
###############################################################################
  my $self=shift;
  my @data;

  my ($data,$structure)=$self->GetData;
  return if $self->Status;

  #--- Wenn kein Detailbereich angegeben
  if ($#{$self->Reportobj->DetailObjects} == -1) {
    my $name=${$self->Reportobj->General}[0];
    no strict 'refs';
    my $statement=$self->Reportobj->$name->DataSource;
    my %hs_name;
    if ($statement =~/[\s\.]+\*[\s\,]+/) { #offen:Kombinationen "tab.*,tab1.test,tab2.a as b" noch nicht geparst
      my $i=0;
      for (my $j=0;$j<=$#{$data->[0]}; $j++) {
        $hs_name{'value'.$i}=$i;
        $i++;
      }
    } else {
      $statement=~/select (.*) from/i;
      my @a=split(',',$1);
      my $i=0;
      #-- take alias or correct name without blank from select and save position in %hs_name
      map{if ($_=~/.*\s+as\s+.*/) {($_)=($_=~/as (.*)/)} ;$_=~s/\s//g;$hs_name{$_}=$i;$i++} @a;
    }

    #--- Initialisierung von PageHeader and Detail und setzen der Positionen
    no strict 'subs';
    my %hs_name_rev=reverse %hs_name;
    $self->Reportobj->{'_MaxColumn'}=$#{keys %hs_name};
    my $maxposition=-1;
    foreach my $position ( sort {$a <=> $b} keys %hs_name_rev) {
      $maxposition++;
      #--- Detailbereich füllen
      my $name=$hs_name_rev{$position};
      push(@{$self->Reportobj->DetailObjects},$name);
      my $b="Apiis::Report::Detail";
      my %attr=();
      #--- default-Attribute setzen
      %attr=('Name'=>$name,'Content'=>"[$name]",'PositionSQL'=>$position,'Visible'=>"yes",'Column'=>$position,
             'ElementType'=>"Data",'Row'=>"1");
      $self->Reportobj->{$name}=$b->new( $name, %attr);
      no strict 'refs';
      *{$name} = sub {
        return $self->Reportobj->{$name};
      };

      #--- PageHeader füllen
      $name='ph'.$hs_name_rev{$position};
      push(@{$self->Reportobj->PageHeader},$name);
      $b="Apiis::Report::PageHeader";
      %attr=('Name'=>$name,'Content'=>"[$name]",'PositionSQL'=>$position,'Visible'=>"yes",'Column'=>$position,
             'ElementType'=>"Text",'Row'=>"1");
      $self->Reportobj->{$name}=$b->new( $name, %attr);
      no strict 'refs';
      *{$name} = sub {
        return $self->Reportobj->{$name};
       };
    }
    $self->Reportobj->{'_MaxColumn'}=$maxposition;

  } else {
    #-- Positionen setzen
    if ($structure) {
      my $i=1;my %hs_v;
      #map {$hs_v{$_}=$i;$i++} @{$structure->[0]};
      map {$hs_v{$_}=$i;$i++} @{$structure};
      foreach my $s (@{$self->Reportobj->ContentFields} ) {
        if ((exists $self->Reportobj->$s->{'Content'}) and ($self->Reportobj->$s->{'Content'}=~/\[(.*)\]/)) {
          $self->Reportobj->$s->PositionSQL($hs_v{$1});
        }
      }
    }

    #-- Gruppen bilden und zusammen mit den SQL-Daten abspeichern
    foreach my $q (@{$data}) {
      my @g=();
      foreach my $grouph (@{$self->Reportobj->GroupHeader}) {
        foreach my $group (@{$self->Reportobj->$grouph->GroupHeaderObjects}) {
          push(@g,$q->[$self->Reportobj->$group->PositionSQL]) if ($self->Reportobj->$group->PositionSQL ne '');
        }
      }
      push(@data,[@g,@$q]);
    }

    #--- Sortieren nach Gruppen
    my @sort=();my $i=0;
    foreach my $grouph (@{$self->Reportobj->GroupHeader}) {
      if ($self->Reportobj->$grouph->Sort eq 'Desc') {
        push(@sort,' $b->['.$i.'] cmp $a->['.$i.'] ');
      } else {
        push(@sort,' $a->['.$i.'] cmp $b->['.$i.'] ');
      }
      $i++;
    }

    #--- nur wenn nach irgendwas sortiert werden soll
    if ($i>0) {
      my @data_neu;
      @data=eval('@data_neu=sort{'. join( '||',reverse @sort) .'} @data');
      @data=@data_neu;
    }
  }

  #--- print ReportHeader
  $self->PrintObjects($self->Reportobj->ReportHeaderObjects);

  #--- print PageHeader
  $self->PrintObjects($self->Reportobj->PageHeaderObjects);

  foreach my $data (@data) {

    #-- Schleife über alle Gruppen
    foreach my $grouph (@{$self->Reportobj->GroupHeader}) {
      foreach my $group (@{$self->Reportobj->$grouph->GroupHeaderObjects}) {
        $self->Reportobj->$group->Content(shift @{$data}) if ($self->Reportobj->$group->ElementType eq 'Data');
      }
    }

    #--- wenn neue Gruppe, dann Footer drucken
    foreach my $grouph (reverse @{$self->Reportobj->GroupHeader}) {
      my $groupf=$self->Reportobj->$grouph->GroupFooterName;
      my $ok=0;
      foreach my $group (@{$self->Reportobj->$grouph->GroupHeaderObjects}) {
        if ($self->Reportobj->$group->QuestionChangeValue and
            ($self->Reportobj->$group->QuestionChangeValue == 1) and
            ($self->Reportobj->$group->ElementType eq 'Data')) {
          $ok=1;
        }
      }
      if ($ok==1) {
        $self->PrintObjects($self->Reportobj->$groupf->GroupFooterObjects);
        $self->ResetFooterObjects($groupf)
      }
    }

    #--- wenn neue Gruppe, dann Header drucken
    foreach my $grouph (@{$self->Reportobj->GroupHeader}) {
      foreach my $group (@{$self->Reportobj->$grouph->GroupHeaderObjects}) {
        if ($self->Reportobj->$group->QuestionChangeValue) {
          $self->PrintObjects($self->Reportobj->$grouph->GroupHeaderObjects);
        }
      }
    }

    foreach my $detail (@{$self->Reportobj->DetailObjects}) {
      if ($self->Reportobj->$detail->PositionSQL ne '') {
        $self->Reportobj->$detail->Content( $data->[ $self->Reportobj->$detail->PositionSQL - 1  ] );
      }
    }
    $self->Refresh;

    $self->PrintObjects($self->Reportobj->DetailObjects);
  }

  #--- wenn neue Gruppe, dann Footer drucken
  foreach my $grouph (reverse @{$self->Reportobj->GroupHeader}) {
    my $groupf=$self->Reportobj->$grouph->GroupFooterName;
      $self->PrintObjects($self->Reportobj->$groupf->GroupFooterObjects);
      $self->ResetFooterObjects($groupf)
  }

  #--- print ReportFooter
  $self->PrintObjects($self->Reportobj->ReportFooterObjects);
  return $self->PrintTable;
}

###############################################################################
sub PrintReport {
###############################################################################
  my $self=shift;
  print $self->PrintTable;

}
###############################################################################
sub PrintFooter {
###############################################################################
  my $self=shift;
}

###############################################################################
sub LinkModul {
###############################################################################
  my $self=shift;
  my $module=shift;
  
  eval {
    require $module; #offen: Verzeichnisrechte und öffnen
  };
  if ($@) {
    push @{ $self->{"_Errors"} },
      Apiis::Errors->new(
      type      => 'CODE',
      severity  => 'ERR',
      from      => 'Apiis::Report::Base',
      msg_short => "Can't open modul $module",
      msg_long =>  "$@"
      );
    $self->{'_Status'}=1;
    return;
  }	
  $self->Reportobj->{'CheckModul'}=1;
}
1;


