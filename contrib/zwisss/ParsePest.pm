#!/usr/bin/perl -w
package ParsePest;
use strict;

#################################################################  
sub new {
#################################################################  
  my $class =shift;
  my $self={};
  $self->{'pest'}={};
  bless ($self,$class);
}

#################################################################  
sub SplitRow {
#################################################################  
  my ($case,@ar_case,$temp);
  $temp= shift @_;
  ($case,$temp)=($temp=~/(.*)=(.*)/);
  ($case)=($case=~/(\S+)/);
  $case=uc($case);
  ($temp)=($temp=~/\s*(.*)/);
  if ($case ne 'UNDEFINED') {
    @ar_case=split(' ',$temp);
  } else {
    $temp=~s/\s//g;
    $temp=~s/\'//g;
    push(@ar_case,$temp);
  }
  return $case,\@ar_case;
}

#################################################################  
sub PushParameter {
#################################################################  
  my ($zeile,$section,$case,$ifile,@files,@merkmale,$n,$ar_case,$dat1,@test1,@test,$dat);
  my $self=shift;
  ($zeile,$section,$case)=@_;
  
  if ($case=~/(PEV)/i) {
    $self->{'pest'}->{$self->{'tfile'}}->{$section}->{$case}='t';
  }
  if ($zeile=~/(VG_FOR|VE_FOR)\s+(\S*)/i) {
    push(@{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{$case}},lc($2)) if ($zeile=~/(VG_FOR|VE_FOR)\s+(\S*)/i);
    $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'N'}=0;
    $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'temp'}=lc($2);
  }

  $self->{'pest'}->{$self->{'tfile'}}->{$section}->{$case}=[lc($2)] if ($zeile=~/(REL_FOR|HETERO_IN)\s+(\S*)/i);
  $self->{'pest'}->{$self->{'tfile'}}->{$section}->{$case}=''	if ($zeile=~/SMP|DISK|XPX|XPY|BASE_ZERO|MEMORY_MAP|GROUP|INBREEDING|CHOLESKY|CANONICAL/i);

  if ($zeile=~/=/) {
    if ($zeile=~/(INFILE|OUTFILE).*'(\S*)'/i) {
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{$case}=[lc($2)];
    } else {
      ($case,$ar_case)=SplitRow($zeile);
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{$case}=$ar_case;
    }
  }
  if (($case=~/OUTPUT|INPUT|TREATED_AS_MISSING|SCALING/) and ($zeile=~/^\s+(.*)/i) and not (/$case/i)){
    @test1=split('\s+',$1);
    $self->{'pest'}->{$self->{'tfile'}}->{$section}->{$case}->{lc($test1[0])}=[@test1];
  }
 
  if ((/^\s*([\d\-\.]+.*)/) and (($section eq 'VG') or ($section eq 'VE'))){
    if ((! exists $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'VG_FOR'}) and ($section eq 'VG')){
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'VG_FOR'}=[];
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'N'}=0;
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'temp'}='';
      #$self->{'pest'}->{$self->{'tfile'}}->{$section}->{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'temp'}}->{'VARIANZEN'}=[];
    }
    if ((! exists $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'VE_FOR'}) and ($section eq 'VE')) {
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'VE_FOR'}=[];
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'N'}=0;
      $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'temp'}='';
      #$self->{'pest'}->{$self->{'tfile'}}->{$section}->{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'temp'}}->{'VARIANZEN'}=[];
    }
    @test1=split('\s+',$1);
    $self->{'pest'}->{$self->{'tfile'}}->{$section}->{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'temp'}}->{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'N'}}=[@test1];
    push(@{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'temp'}}->{'VARIANZEN'}},$test1[$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'N'}]);
    $self->{'pest'}->{$self->{'tfile'}}->{$section}->{'N'}++;
  }

  if ($section eq 'COMMENT') { 
    $self->{'pest'}->{$self->{'tfile'}}->{$section}.=$zeile if ($section eq 'COMMENT'); 
  }
  if ($section eq 'MODEL') {
    push(@{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'traits'}},lc($case));
    foreach $dat1 (@$ar_case) {
      @test=grep{/$dat1/i} @{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'effects'}};
      if (! defined $test[0]) {
        push(@{$self->{'pest'}->{$self->{'tfile'}}->{$section}->{'effects'}},lc($dat1)) if ($dat1 ne 'animal');
      }
    } 
  }
}
#################################################################  
sub ParsePestParameter {
#################################################################  
  my ($section,$case,$ifile,@files,@merkmale,$n,$ar_case);
  my $self=shift;
  (@files)=@_;

# open (o_file, ">zwisss.par") || die "Fehler beim Schreiben von zwisss.par"; 
 foreach $ifile (@files) {
   open (i_file,"<$ifile") || die "Fehler beim Einlesen des Parameterfiles $ifile";
   $self->{'tfile'}=$ifile;
   $self->{'talias'}++;
   $self->{'pest'}->{$self->{'tfile'}}->{'ALIAS'}=$self->{'talias'};
   while (<i_file>) {
     next if ((/^$/) or (/^\s*$/));
     next if ((/^[cC]/) and !(/COMMENT|CONTRAST|CANONICAL|CHOLESKY/));

     if (uc($_)=~/^(HYPOTHESIS|STARTING_VALUES|MODEL|COMMENT|RELATIONSHIP|DATA|VG|VE|PRINTOUT|SOLVER|SYSTEM_SIZE|TRANSFORMATION)/) {
       $section=uc($1);
       $case='';
       next;
     }

     $case=uc($1) if (uc($_)=~/(PEV|INFILE|INPUT|MAX_CHAR|DISK|OUTFILE|OUTPUT|PAGE|LINE|SIGN_DIGITS|XPX|XPY|BASE_ZERO|MEMORY_MAP|REL_FOR|GROUP|INBREEDING|UNDEFINED|IOC|IOD|IOD_GS|SMP|DENSE|NON_ZERO|TREATED_AS_MISSING|SCALING|CHOLESKY|CANONICAL|VE_FOR|VG_FOR|HETERO_IN|CONTRAST)/);
     $_=lc($_);
   
     $self->PushParameter($_,$section,$case);
   }
   close i_file;
 }
# close o_file;
}


#################################################################  
sub GetInputEntry {
#################################################################  
  my $self=shift;
  my $vpar=shift @_;
  my $vtrait=shift @_;
  my $vsection=shift @_;

  return $self->{'pest'}->{$vpar}->{$vsection}->{'INPUT'}->{$vtrait};
}

#################################################################  
sub GetTraitsZw {
#################################################################  
  my (@traits,@traits1);
  my $self=shift;
  my $file=shift @_;
  my $uc=shift @_;
  @traits=@{$self->{'pest'}->{$file}->{'MODEL'}->{'zw_traits'}}; 
  if (defined $uc) {
    @traits1=@traits;
    @traits=();
    foreach (@traits1) {
      push(@traits,uc($_));
    }
  }
  return @traits;
}

#################################################################  
sub GetTraitsSe {
#################################################################  
  my (@traits,@traits1);
  my $self=shift;
  my $file=shift @_;
  my $uc=shift @_;
  @traits=@{$self->{'pest'}->{$file}->{'MODEL'}->{'se_traits'}}; 
  if (defined $uc) {
    @traits1=@traits;
    @traits=();
    foreach (@traits1) {
      push(@traits,uc($_));
    }
  }
  return @traits;
}

#################################################################  
sub GetTraits {
#################################################################  
  my (@traits,@traits1);
  my $self=shift;
  my $file=shift @_;
  my $uc=shift @_;
  @traits=@{$self->{'pest'}->{$file}->{'MODEL'}->{'traits'}}; 
  if (defined $uc) {
    @traits1=@traits;
    @traits=();
    foreach (@traits1) {
      push(@traits,uc($_));
    }
  }
  return @traits;
}

#################################################################  
sub GetEffects {
#################################################################  
  my (@traits,@traits1);
  my $self=shift;
  my $file=shift @_;
  my $uc=shift @_;
  @traits=@{$self->{'pest'}->{$file}->{'MODEL'}->{'effects'}}; 
  if (defined $uc) {
    @traits1=@traits;
    @traits=();
    foreach (@traits1) {
      push(@traits,uc($_));
    }

  }
  return @traits;
}

#################################################################  
sub GetRanEffects {
#################################################################  
  my (@rand);
  my $self=shift;
  my $file=shift @_;
  @rand=@{$self->{'pest'}->{$file}->{'VG'}->{'VG_FOR'}};
  return @rand;
}

#################################################################  
sub GetCovEffects {
#################################################################  
  my (@cov);
  my $self=shift;
  my $file=shift @_;
  my $uc=shift @_;
  my @effects=$self->GetEffects($file,$uc); 
  foreach my $eff (@effects) {
    if (exists $self->{'pest'}->{$file}->{'DATA'}->{'INPUT'}->{$eff}) {
      push(@cov, $eff) if ($self->{'pest'}->{$file}->{'DATA'}->{'INPUT'}->{$eff}->[1] eq 0);
    } else {
      if ($eff=~/.+\(.+\)/) {
        $eff=~/(.+)\(.+\)/;
	$eff=~s/\(/_/g;
	$eff=~s/\)/_/g;
        push(@cov, $eff) if ($self->{'pest'}->{$file}->{'DATA'}->{'INPUT'}->{$1}->[1] eq 0);
      }	
    }
  }
  return @cov;
}

#################################################################  
sub GetFixEffects {
#################################################################  
  my (@fix);
  my $self=shift;
  my $file=shift @_;
  my $uc=shift @_;
  my @effects=$self->GetEffects($file,$uc); 
  my @cov=$self->GetCovEffects($file,$uc); 
  my @rand=@{$self->{'pest'}->{$file}->{'VG'}->{'VG_FOR'}};
  foreach my $eff (@effects) {
    my $t=0;
    map {if ($_ eq $eff) {$t=1}} @rand;
    map {if ($_ eq $eff) {$t=1}} @cov;
    push(@fix, $eff) if ($t==0);
  }
  return @fix;
}


#################################################################
sub GetParameterFiles {
#################################################################
  my (@parameter);
  my $self=shift;
  my $file=shift @_;
 
  #-- Alle Parameterfiles auslesen oder nur das angegebene
  if (! defined $file) {
    @parameter=keys %{$self->{'pest'}};
  } else {
    push(@parameter,$file);
  }
  return @parameter;
} 

#################################################################  
sub WriteVG {
#################################################################  
  my ($i,$text,$dat);
  my $self=shift;
  my $file=shift @_;
  $text='';
  if (defined $self->{'pest'}->{$file}->{'VG'}->{'VG_FOR'}[0]) {
    foreach $dat (@{$self->{'pest'}->{$file}->{'VG'}->{'VG_FOR'}}) {
      $text.="  VG_FOR ".$dat."\n";
      for ($i=0;$i<$self->{'pest'}->{$file}->{'VG'}->{'N'};$i++) {
        $text.="    ".join("   ",@{$self->{'pest'}->{$file}->{'VG'}->{$dat}->{$i}})."\n";
      }
      $text.="  \n";
    }
  } else {
    for ($i=0;$i<$self->{'pest'}->{$file}->{'VG'}->{'N'};$i++) {
      $text.="  ".join("   ",@{$self->{'pest'}->{$file}->{'VG'}->{''}->{$i}})."\n";
    }
  }
  return $text;
}

#################################################################  
sub WriteVE {
#################################################################  
  my ($i,$text,$dat);
  my $self=shift;
  my $file=shift @_;
  $text='';
  if (defined $self->{'pest'}->{$file}->{'VE'}->{'VE_FOR'}[0]) {
    foreach $dat (@{$self->{'pest'}->{$file}->{'VE'}->{'VE_FOR'}}) {
      $text.="  VE_FOR ".$dat."\n";
      for ($i=0;$i<$self->{'pest'}->{$file}->{'VE'}->{'N'};$i++) {
        $text.="    ".join("   ",@{$self->{'pest'}->{$file}->{'VE'}->{$dat}->{$i}})."\n";
      }
      $text.="  \n";
    }
  } else {
    for ($i=0;$i<$self->{'pest'}->{$file}->{'VE'}->{'N'};$i++) {
      $text.="  ".join("   ",@{$self->{'pest'}->{$file}->{'VE'}->{''}->{$i}})."\n";
    }
  }
  return $text;
}

#################################################################  
sub GetVGVG_FOR {
#################################################################  
  my ($i,@varianzen);
  my $self=shift;
  my $file=shift @_;
  @varianzen=@{$self->{'pest'}->{$file}->{'VG'}->{'VG_FOR'}};
  return @varianzen;
}

#################################################################  
sub GetVEVE_FOR {
#################################################################  
  my ($i,@varianzen);
  my $self=shift;
  my $file=shift @_;
  @varianzen=@{$self->{'pest'}->{$file}->{'VE'}->{'VE_FOR'}};
  return @varianzen;
}

#################################################################  
sub GetVEVarianz {
#################################################################  
  my ($i,@varianzen);
  my $self=shift;
  my $file=shift @_;
  my $vg=shift @_;
  $vg='' if (! defined $vg);
  @varianzen=@{$self->{'pest'}->{$file}->{'VE'}->{$vg}->{'VARIANZEN'}};
  return @varianzen;
}

#################################################################  
sub GetVGVarianz {
#################################################################  
  my ($i,@varianzen);
  my $self=shift;
  my $file=shift @_;
  my $vg=shift @_;
  $vg='' if (! defined $vg);
  @varianzen=@{$self->{'pest'}->{$file}->{'VG'}->{$vg}->{'VARIANZEN'}};
  return @varianzen;
}

#################################################################  
sub GetInput {
#################################################################  
  my ($i,@varianzen);
  my $self=shift;
  my $file=shift @_;
  my $section=shift @_;
  return $self->{'pest'}->{$file}->{$section}->{'INPUT'};
}

#################################################################  
sub WriteModel {
#################################################################  
  my ($dat,$text,@traits);
  my $self=shift;
  my $file=shift @_;
  @traits=$self->GetTraits($file);
  $text='';
  foreach $dat (@traits) {
    $text.="  $dat = ".join('   ',@{$self->{'pest'}->{$file}->{'MODEL'}->{uc($dat)}})."\n";
  }
  return $text;
}

#################################################################  
sub WriteTransformation {
#################################################################  
  my ($key,$value,$text,@traits);
  my $self=shift;
  my $file=shift @_;
  $text="  TREATED_AS_MISSING\n";
  while (($key,$value)=each %{$self->{'pest'}->{$file}->{'TRANSFORMATION'}->{'TREATED_AS_MISSING'}}) {
    $text.="    ".join('   ',@{$self->{'pest'}->{$file}->{'TRANSFORMATION'}->{'TREATED_AS_MISSING'}->{$key}})."\n";
  }
  return $text;
}

#################################################################  
sub WriteSystem_Size {
#################################################################  
  my ($key,$value,$text,@traits);
  my $self=shift;
  my $file=shift @_;
  $text="";
  while (($key,$value)=each %{$self->{'pest'}->{$file}->{'SYSTEM_SIZE'}}) {
    $text.="  ".uc($key)."=".join('   ',@{$self->{'pest'}->{$file}->{'SYSTEM_SIZE'}->{$key}})."\n";
  }
  return $text;
}

#################################################################  
sub WritePrintout {
#################################################################  
  my ($key,$value,$text,$key1,$value1);
  my $self=shift;
  my $file=shift @_;
  while (($key,$value)=each %{$self->{'pest'}->{$file}->{'PRINTOUT'}}) {
    if (ref($value) eq 'ARRAY') {
      $text.="  ".uc($key)."=".join('   ',@{$self->{'pest'}->{$file}->{'PRINTOUT'}->{$key}})."\n";
    } else {
      $text.="  ".uc($key)."\n";  
      while (($key1,$value1)=each %{$self->{'pest'}->{$file}->{'PRINTOUT'}->{$key}}) {
        $text.="    ".join('   ',@{$self->{'pest'}->{$file}->{'PRINTOUT'}->{$key}->{$key1}})."\n";
      }
    }
  }
  return $text;
}

#################################################################  
sub WriteData {
#################################################################  
  my ($key,$value,$text,$key1,$value1);
  my $self=shift;
  my $file=shift @_;
  while (($key,$value)=each %{$self->{'pest'}->{$file}->{'DATA'}}) {
    if (ref($value) eq 'ARRAY') {
      $text.="  ".uc($key)."=".join('   ',@{$self->{'pest'}->{$file}->{'DATA'}->{$key}})."\n";
    } elsif (ref($value) eq 'HASH') {
      $text.="  ".uc($key)."\n";  
      while (($key1,$value1)=each %{$self->{'pest'}->{$file}->{'DATA'}->{$key}}) {
        $text.="    ".join('   ',@{$self->{'pest'}->{$file}->{'DATA'}->{$key}->{$key1}})."\n";
      }
    } else {
      $text.="  ".uc($key)." ".$value."\n";
    } 
  }
  return $text;
}

#################################################################  
sub WriteRelationship {
#################################################################  
  my ($key,$value,$text,$key1,$value1,$p);
  my $self=shift;
  my $file=shift @_;
  while (($key,$value)=each %{$self->{'pest'}->{$file}->{'RELATIONSHIP'}}) {
    if (ref($value) eq 'ARRAY') {
      $text.="  ".uc($key)."=".join('   ',@{$self->{'pest'}->{$file}->{'RELATIONSHIP'}->{$key}})."\n";
    } elsif (ref($value) eq 'HASH') {
      $text.="  ".uc($key)."\n";
      while (($key1,$value1)=each %{$self->{'pest'}->{$file}->{'RELATIONSHIP'}->{$key}}) {
        $text.="    ".join('   ',@{$self->{'pest'}->{$file}->{'RELATIONSHIP'}->{$key}->{$key1}})."\n";
      }
    } else {
      $text.="  ".uc($key)." ".$value."\n";
    }
  } 
  return $text;
}

#################################################################  
sub WriteSolver {
#################################################################  
  my ($key,$value,$text,$key1,$value1,$p);
  my $self=shift;
  my $file=shift @_;
  while (($key,$value)=each %{$self->{'pest'}->{$file}->{'SOLVER'}}) {
    if (ref($value) eq 'ARRAY') {
      $text.="  ".uc($key)."=".join('   ',@{$self->{'pest'}->{$file}->{'SOLVER'}->{$key}})."\n";
    } elsif (ref($value) eq 'HASH') {
      $text.="  ".uc($key)."\n";
      while (($key1,$value1)=each %{$self->{'pest'}->{$file}->{'SOLVER'}->{$key}}) {
        $text.="    ".join('   ',@{$self->{'pest'}->{$file}->{'SOLVER'}->{$key}->{$key1}})."\n";
      }
    } else {
      $text.="  ".uc($key)." ".$value."\n";
    }
  } 
  return $text;
}

#################################################################  
sub WriteDataInputEntry {
#################################################################  
  my ($variables);
  my $self=shift;
  my $file=shift @_;
  my $entry=shift @_;
  $variables=$self->{'pest'}->{$file}->{'DATA'}->{'INPUT'}->{$entry};
  return $variables;
}

#################################################################  
sub WriteDataInput {
#################################################################  
  my ($variables);
  my $self=shift;
  my $file=shift @_;
  $variables=$self->{'pest'}->{$file}->{'DATA'}->{'INPUT'};
  return $variables;
}

#################################################################  
sub WriteRelationshipInput {
#################################################################  
  my ($variables);
  my $self=shift;
  my $file=shift @_;
  $variables=$self->{'pest'}->{$file}->{'RELATIONSHIP'}->{'INPUT'};
  return $variables;
}

#################################################################  
sub GetPEV {
#################################################################  
  my ($variables);
  my $self=shift;
  my $file=shift @_;
  if (exists $self->{'pest'}->{$file}->{'HYPOTHESIS'}->{'PEV'}) {
    return $self->{'pest'}->{$file}->{'HYPOTHESIS'}->{'PEV'};
  } else {
    return 'n';
  }
}

#################################################################  
sub GetPositionZw {
#################################################################  
  my ($variables);
  my $self=shift;
  my $file=shift @_;
  if (exists $self->{'zw_fld'}->{$file}) {
    return $self->{'zw_fld'}->{$file}->[3];
  } else {
    return undef;
  }
}

#################################################################  
sub GetPosition {
#################################################################  
  my ($variables);
  my $self=shift;
  my $file=shift @_;
  if (exists $self->{'zw_value'}->{$file}) {
    return $self->{'zw_value'}->{$file}->[3];
  } else {
    return undef;
  }
}

#################################################################  
sub WritePestParameterFile {
#################################################################  
  my ($dat, @files,$key,$value,$key1,$text);
  my $self=shift;
  my $file=shift @_;

  #-- Alle Parameterfiles auslesen oder nur das angegebene
  @files=$self->GetParameterFiles($file);

  #-- Schleife über alle Parameterfiles
  foreach $dat (@files) {
    open (O_FILE, ">$dat.neu") || die "Fehler beim Schreiben von $dat.neu";
    foreach $key ('COMMENT','RELATIONSHIP','DATA','MODEL','TRANSFORMATION','VG','VE','PRINTOUT','SOLVER','SYSTEM_SIZE') {
      $text='';
      next if (! exists $self->{'pest'}->{$dat}->{$key});
      print O_FILE uc($key)."\n";
      $text=$self->{'pest'}->{$dat}->{$key}	if ($key eq 'COMMENT');
      $text=$self->WriteVE($dat) 		if ($key eq 'VE');
      $text=$self->WriteVG($dat) 		if ($key eq 'VG');
      $text=$self->WriteModel($dat) 		if ($key eq 'MODEL');
      $text=$self->WriteTransformation($dat)	if ($key eq 'TRANSFORMATION');
      $text=$self->WriteSystem_Size($dat)	if ($key eq 'SYSTEM_SIZE');
      $text=$self->WritePrintout($dat)		if ($key eq 'PRINTOUT');
      $text=$self->WriteData($dat)		if ($key eq 'DATA');
      $text=$self->WriteRelationship($dat)	if ($key eq 'RELATIONSHIP');
      $text=$self->WriteSolver($dat)		if ($key eq 'SOLVER');
      print O_FILE $text."\n";
    }
    close O_FILE;
  }
}

#################################################################  
sub GetCorTraits {
#################################################################  
  my ($dat,@merkmale,$n);
  my $self=shift;
  my $file=shift @_;
  
  @merkmale=();$n=0;
  foreach $dat ($self->GetTraits($file)) {
    $dat="co_".$dat;
    while (exists $self->{'fields_zwisss'}->{$dat}) {
      $n++; 
      $dat="co".$n."_".$dat;
    }
    push(@merkmale,$dat);
  }
  return @merkmale;
}

#################################################################  
sub TestTrait {
#################################################################  
  my $n;
  my $self=shift;
  my $dat=shift @_;
  my $vg=shift @_;
  $n=0;
  ($vg)=($vg=~/(.*?)_/);
  while (exists $self->{'zw_fld'}->{$dat}) {
    $n++; 
    $dat="$vg".$n."_".$dat;
  }
  return $dat;
}

#################################################################  
sub GetZwFld {
#################################################################  
  my @keys;
  my $self=shift;
  @keys=(keys %{$self->{'zw_fld'}});
  return @keys;
}

#################################################################  
sub GetFieldBox  {
#################################################################  
  my $self=shift;
  my %box=@_;
  foreach ('DATA','DB_COLUMN','DATATYPE','LENGTH','DESCRIPTION','DEFAULT','CHECK','MODIFY','ERROR',
           'DECIMALS','DESCRIPTION_SHORT','VISIBLE','FORMAT','EXPORT_ALIAS') {
    next if (($box{'DATATYPE'} eq 't') and ($_ eq 'DECIMALS'));
    if (exists $box{$_}) {
      $box{$_}="'".$box{$_}."'";
    } else {
      if ($_=~/CHECK|MODIFY|ERROR/)  {
        $box{$_}='[]';
      } else {
        if ($_=~/VISIBLE/)  {
          $box{$_}="'y'"; 
        } else {
          $box{$_}="''"; 
        }
      }
    }
  }
  my $lz="                 ";
  my $t='';
  foreach (sort keys %box) {
    $t.="      $_".substr($lz,0,18-length($_))."=> ".$box{$_}.",\n";
  }
  return $t;
}


#################################################################  
sub FormatCol {
#################################################################  
  my $col=shift;
  return '00'.$col  if ($col<10);
  return '0'.$col  if (($col<100) and ($col>9));
  return $col  if ($col>99);
}
#################################################################  
sub SetZwFld {
#################################################################  
  # Reihenfolge: alias,  Wert, typ, position, start, länge, Dezimalstelle, Abk., Beschr., Einheit, Gruppe, InList
  my (@merkmale,@merkmale1,$n,$key,$value,$dat,$dec,$key1,$value1,$i,$vtyp,$text,$verband);
  my $self=shift;
  $text="%TABLES=(\n";
  while (($key,$value)=each %{$self->{'pest'}}) {

    @merkmale1=();
    @merkmale=();
    while (($key1,$value1)=each %{$value->{'DATA'}->{'INPUT'}}) {
      push(@merkmale,$value1);
      push(@merkmale1,"da".$value->{'ALIAS'}."_".$key1);
    }
    $n=0;

    #-- Data
    my $col=0;

    $text.="\n#########################################\n";
    $text.="#  Definition der Datentabelle          #\n";
    $text.="#########################################\n\n";
    $text.=lc($self->{'verband'})."_".$value->{'ALIAS'}."_daten=>{\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_id",'DATATYPE'=>'z');
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_owner",'DATATYPE'=>'t','LENGTH'=>15);
    $text.="    },\n";
    foreach $dat (@merkmale) {
      if ($dat->[0] eq 'animal') {
        $text.="    col".FormatCol($col++)." => {\n";
        $text.=$self->GetFieldBox('DB_COLUMN'=>'animal','DATATYPE'=>'t',
                                  'START'=>$dat->[2],'LENGTH'=>$dat->[3],'DESCRIPTION'=>'Tiernummer');
        $text.="    },\n";
      } else {
        (defined $dat->[4]) ? $dec=$dat->[4] : $dec=0;
        if ($dat->[1] == 0) {
          $vtyp="z";
        } else {
          $vtyp="t";
        }
        $text.="    col".FormatCol($col++)." => {\n";
        $text.=$self->GetFieldBox('DB_COLUMN'=>"da".$value->{'ALIAS'}."_".$dat->[0],'DATATYPE'=>$vtyp,
                                  'START'=>$dat->[2],'LENGTH'=>$dat->[3],'DESCRIPTION'=>$dat->[0],
      		 		  'DECIMALS'=>$dec,'EXPORT_ALIAS'=>"da".$value->{'ALIAS'}."_".$dat->[0]);
        $text.="    },\n";
      }
    }
    $text.="  },\n\n";

    #--Zuchtwerte und Effekte
    @merkmale1=();
    @merkmale=@{$value->{'MODEL'}->{'traits'}};
    foreach $dat (@merkmale) {    
      push(@merkmale1,"bv".$value->{'ALIAS'}."_".$dat);
    }
    $value->{'MODEL'}->{'zw_traits'}=[@merkmale1];
    if (exists $value->{'HYPOTHESIS'}->{'PEV'}) {
      $value->{'MODEL'}->{'se_traits'}=[@merkmale1];
    }

    #-- Effekte 
    $col=0;
    $text.="\n#########################################\n";
    $text.="#  Definition der Effektetabelle        #\n";
    $text.="#########################################\n\n";
    $text.=lc($self->{'verband'})."_".$value->{'ALIAS'}."_effects=>{\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_id",'DATATYPE'=>'z');
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_owner",'DATATYPE'=>'t','LENGTH'=>15);
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"effect_class",'DATATYPE'=>'t','LENGTH'=>15);
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"effect",'DATATYPE'=>'t','LENGTH'=>15);
    $text.="    },\n";

    foreach $dat (@merkmale) {
      (defined $merkmale[4]) ? $dec=$merkmale[4] : $dec=0;
      #--- Originalwerte
      $text.="    col".FormatCol($col++)." => {\n";
      $text.=$self->GetFieldBox('DB_COLUMN'=>"ef".$value->{'ALIAS'}."_$dat",'DATATYPE'=>'z',
                                'DESCRIPTION'=>"$dat",
     		  		'DESCRIPTION_SHORT'=>"ef.".$dat,'DECIMALS'=>$dec);
      $text.="    },\n";

      #--- Relativwerte
      $text.="    col".FormatCol($col++)." => {\n";
      $text.=$self->GetFieldBox('DB_COLUMN'=>"efr".$value->{'ALIAS'}."_$dat",'DATATYPE'=>'z',
                                'DESCRIPTION'=>"$dat",
     		  		'DESCRIPTION_SHORT'=>"efr.".$dat,'DECIMALS'=>$dec);
      $text.="    },\n";
      if (exists $value->{'HYPOTHESIS'}->{'PEV'}) {
        $text.="    col".FormatCol($col++)." => {\n";
        $text.=$self->GetFieldBox('DB_COLUMN'=>"efse".$value->{'ALIAS'}."_".$dat,'DATATYPE'=>'z',
                                  'DESCRIPTION'=>"$dat",
       		  		  'DESCRIPTION_SHORT'=>"efse.".$dat,'DECIMALS'=>$dec);
        $text.="    },\n";
      }
    }
    $text.="  },\n\n";

    #-- Zuchtwerte 
    $col=0;
    $text.="\n#########################################\n";
    $text.="#  Definition der Zuchtwerttabelle      #\n";
    $text.="#########################################\n\n";
    $text.=lc($self->{'verband'})."_".$value->{'ALIAS'}."_bv=>{\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_id",'DATATYPE'=>'z');
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_owner",'DATATYPE'=>'t','LENGTH'=>15);
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"animal",'DATATYPE'=>'t','LENGTH'=>15);
    $text.="    },\n";

    foreach $dat (@merkmale) {
      (defined $merkmale[4]) ? $dec=$merkmale[4] : $dec=0;
      #---Originalwerte
      $text.="    col".FormatCol($col++)." => {\n";
      $text.=$self->GetFieldBox('DB_COLUMN'=>"bv".$value->{'ALIAS'}."_".$dat,'DATATYPE'=>'z',
                                'DESCRIPTION'=>$dat,
     		  		'DESCRIPTION_SHORT'=>"bv.".$dat,'DECIMALS'=>$dec);
      $text.="    },\n";

      #--- Relativwerte
      $text.="    col".FormatCol($col++)." => {\n";
      $text.=$self->GetFieldBox('DB_COLUMN'=>"bvr".$value->{'ALIAS'}."_".$dat,'DATATYPE'=>'z',
                                'DESCRIPTION'=>$dat,
     		  		'DESCRIPTION_SHORT'=>"bvr.".$dat,'DECIMALS'=>$dec,
				'EXPORT_ALIAS'=>"bvr".$value->{'ALIAS'}."_".$dat);
      $text.="    },\n";
      if (exists $value->{'HYPOTHESIS'}->{'PEV'}) {
        $text.="    col".FormatCol($col++)." => {\n";
        $text.=$self->GetFieldBox('DB_COLUMN'=>"bvse".$value->{'ALIAS'}."_".$dat,'DATATYPE'=>'z',
                                  'DESCRIPTION'=>$dat,
       		  		  'DESCRIPTION_SHORT'=>"bvse.".$dat,'DECIMALS'=>$dec);
        $text.="    },\n";
      }
    }
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"tbv".$value->{'ALIAS'},'DATATYPE'=>'z',
                          'DESCRIPTION'=>"tbv".$value->{'ALIAS'},
    	  		  'DESCRIPTION_SHORT'=>"tbv".$value->{'ALIAS'},'DECIMALS'=>$dec,
			  'EXPORT_ALIAS'=>"tbv".$value->{'ALIAS'});
    $text.="    },\n";

    if (exists $value->{'HYPOTHESIS'}->{'PEV'}) {
    $text.="    col".FormatCol($col++)." => {\n";
      $text.=$self->GetFieldBox('DB_COLUMN'=>"setbv".$value->{'ALIAS'},'DATATYPE'=>'z',
                            'DESCRIPTION'=>"setbv".$value->{'ALIAS'},
      	  		  'DESCRIPTION_SHORT'=>"setbv".$value->{'ALIAS'},'DECIMALS'=>$dec);
      $text.="    },\n";
    }
    $text.="  },\n\n";
  }
  
  #-- if apiis-environment, then animal-table not neccessary
  if (! exists $self->{'parameter'}->{'a'}) {
    my $col=0;
    $text.="\n#########################################\n";
    $text.="#  Definition der animaltabelle         #\n";
    $text.="#########################################\n\n";
    $text.="  '".lc($self->{'verband'})."_animal'=>{\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_id",'DATATYPE'=>'z');
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"db_owner",'DATATYPE'=>'t','LENGTH'=>15);
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"animal",'DATATYPE'=>'t','LENGTH'=>15,'EXPORT_ALIAS'=>"animal");
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"m_p",'DATATYPE'=>'t','LENGTH'=>15,'EXPORT_ALIAS'=>"m_p");
    $text.="    },\n";
    $text.="    col".FormatCol($col++)." => {\n";
    $text.=$self->GetFieldBox('DB_COLUMN'=>"f_p",'DATATYPE'=>'t','LENGTH'=>15,'EXPORT_ALIAS'=>"f_p");
    $text.="    }\n";
    $text.="  }\n";
  }
  
  $text.=");\n\n";
  return $text;
}

#################################################################  
sub GetPos {
#################################################################  
  my $self=shift;
  $self->{'pos'}=-1 if (! exists $self->{'pos'});
  $self->{'pos'}++;
  return $self->{'pos'};
}

#################################################################  
sub PushTraits {
#################################################################  
  my ($key,$value,@trait,$trait,$typ,@temp,@value,$dat);
  my $self=shift;
  my $ref=shift @_;
  $self->{'pos'}=0;
  if (ref($ref) eq 'HASH') {
    while (($key,$value)=each %{$ref}) {
      @trait=(); $trait=$key;$typ='t';
      @temp=split(' ',@{$value});
      $trait=$self->TestTrait($key,'do');

      #neu,typ,länge,digits,pos,
      
      $typ='z' if ($value[1] eq '0');
      push(@trait,($dat,$typ,$value[3],$value[2]));
      $self->{'fields_zwisss'}->{$trait}=[@trait];
    }
  }
}

#################################################################  
sub GetInFile {
#################################################################  
  my $self=shift;
  my $key=shift @_;
  my $case=shift @_;
  return $self->{'pest'}->{$key}->{$case}->{'INFILE'}[0];
}


#################################################################  
sub GetOutFile {
#################################################################  
  my $self=shift;
  my $key=shift @_;
  my $case=shift @_;
  return $self->{'pest'}->{$key}->{$case}->{'OUTFILE'}[0];
}

#################################################################  
sub WriteZwisssParameterFile {
#################################################################  
  my ($text,$key,$value,@merkmale);
  my $self=shift;
  my $file=shift @_;

  open (O_FILE, ">$file") || die "Fehler beim Schreiben von $file";
 
  $text.="#!/usr/bin/perl -w\n";

  $text.="#########################################\n";
  $text.="#  Definition der ALIAS                 #\n";
  $text.="#########################################\n";
  $text.="%ALIAS=(\n";
  while (($key,$value)=each %{$self->{pest}}) {
    $text.="  '$value->{'ALIAS'}'=>'$key',\n";
  }
  $text.=");\n\n";
 
  $text.=$self->SetZwFld."\n";
  
  my $vpar=$key;
  $vpar=~s/\/(.*)/$1/g;

  $text.="#########################################\n";
  $text.="#  Definition der Zuchtwertschätzungen  #\n";
  $text.="#########################################\n";
  $text.="%ESTIMATIONS=(\n";
  while (($key,$value)=each %{$self->{pest}}) {
    $text.="  '$value->{'ALIAS'}'=>{\n";
    $text.="    short_label=>['!'],\n";
    $text.="    pest_prg=>'pest'".",\n";
    $text.="    pest_par=>'".$vpar."',\n";
    $text.="    pest_mem=>500,\n";
    $text.="    show=>['ENZ','ENZ','ENZ']\n";
    $text.="  },\n";
  }
  $text.=");\n\n";

  $text.="#########################################\n";
  $text.="#  Definition der Gesamtzuchtwerte      #\n";
  $text.="#########################################\n";
  $text.="%TBVS=(\n";
  while (($key,$value)=each %{$self->{pest}}) {
    
    $text.="  tbv"."$value->{'ALIAS'}=>{\n";
    $text.="    #---> do not change\n";   
    $text.="    estimation=>['$value->{'ALIAS'}'],\n";
    $text.="    traits=>['da"."$value->{'ALIAS'}"."_".join("','da"."$value->{'ALIAS'}"."_",$self->GetTraits($key))."'],\n";
    $text.="    effects=>['ef"."$value->{'ALIAS'}"."_".join("','ef"."$value->{'ALIAS'}"."_",$self->GetEffects($key))."'],\n";
    $text.="    fix_effects=>['ef"."$value->{'ALIAS'}"."_".join("','ef"."$value->{'ALIAS'}"."_",$self->GetFixEffects($key))."'],\n";
    $text.="    cov_effects=>['ef"."$value->{'ALIAS'}"."_".join("','ef"."$value->{'ALIAS'}"."_",$self->GetCovEffects($key))."'],\n";
    $text.="    ran_effects=>['".join("','ef"."$value->{'ALIAS'}"."_",$self->GetRanEffects($key))."'],\n";
    $text.="    #---> edit\n";   
    $text.="    tbvn=>['tbv".$value->{'ALIAS'}."'],\n";
    $text.="    tbv=>['!*bv"."$value->{'ALIAS'}"."_".join("','!*bv"."$value->{'ALIAS'}"."_",$self->GetTraits($key))."'],\n";
    $text.="    cor_traits=>['da"."$value->{'ALIAS'}"."_".join("','da"."$value->{'ALIAS'}"."_",$self->GetTraits($key))."'],\n";
    $text.="    add_traits=>['?'],\n";
#    $text.="\n",
#    $text.='    # ["Mittelwert+-Standardabweichung"]'."\n";
    $text.="    standardisation=>['100+-20'],\n";
#    $text.="\n",
#    $text.='    # [""|"SZ"|"SG"] = "" - WI sind standardisiert | '."\n";
#    $text.='    #                   SZ - WI auf Standardabweichung der ZW beziehen | '."\n";
#    $text.='    #                   SG - WI auf genetische Standardabweichung beziehen'."\n";
    $text.="    wi=>['SG'],\n";
    $text.="    bv_r2=>['f'],\n";
    if (exists $value->{'HYPOTHESIS'}->{'PEV'}) {
      $text.="    r_for_tbv=>['r%'],\n";
    } else {
      $text.="    r_for_tbv=>[''],\n";
    }
    $text.="    for_groups=>[$value->{'ALIAS'}],\n";
    $text.="    for_breeds=>['!'],\n";
    $text.="    save=>[['-','GI','','','']],\n";
    $text.="    timedep_effects=>[['! name','! regex for farm','! regex for time']],\n";
    $text.="  },\n";
  }
  $text.=");\n\n";

  $text.="#########################################\n";
  $text.="#  Definition der Gruppen               #\n";
  $text.="#########################################\n";
  $text.="%GROUPS=(\n";
  while (($key,$value)=each %{$self->{pest}}) {
    $text.="  '$value->{'ALIAS'}'=>{\n";
#    $text.="    group=>['!'],\n";
    $text.="    breed=>['!=!'],\n";
    $text.="    base_animals=>['!=!'],\n";
    $text.="    base_only_parents=>['yes']},\n";
  }
  $text.=");\n";
  

  $text.="#########################################\n";
  $text.="#  Formate für ZwISSS                   #\n";
  $text.="#########################################\n";
  $text.="%FORMAT=(\n";
  $text.="  zwisss_label=>['!'],\n";
  $text.="  mail_to=>['?'],\n";
  $text.="  mail_from=>['?'],\n";
  $text.="  mail_user=>['?'],\n";
  $text.="  mail_pw=>['?'],\n";
  $text.="  mail_host=>['?'],\n";
  $text.="  ft_animal=>['?'],\n";
  $text.="  ft_hb=>['?'],\n";
  $text.="  ft_katalog=>['?'],\n";
  $text.="  ft_pb=>['?'],\n";
  $text.="  ft_pdf=>['?'],\n";
  $text.="  ft_pdf1=>['?'],\n";
  $text.="  ft_jpg=>['?'],\n";
  $text.="  ft_jpg1=>['?'],\n";
  $text.="  ft_dez=>['?'],\n";
  $text.=");\n";

  print O_FILE $text;

  close O_FILE;
}
1
__END__

=pod

=head1 NAME

ParsePest.pm
 
=head1 SYNOPSIS 

use ParsePest;
$pp=ParsePest->new('Pest_Parameterfile_1','Pest_Parameterfile_n');

$pp->ParsePestParameter($Pest_Parameterfile);
$pp->WritePestParameter($New_Pest_Parameterfile);

$pp->WriteZwisssParameterFile($New_ZwISSS_Parameterfile);

=head1 ABSTRACT
 
ParsePest.pm ist ein Modul zum Parsen von Pest-Parameterfiles sowie
zum Erstellen einer ZwISSS-Steuerdatei.  Mit den Funktionen von
ParsePest.pm können die Informationen aus den einzelnen Sektionen
herausgelesen werden. 

=head1 PROGRAMMING STYLE
 
ParsePest.pm wurde im objekt-orientierten Stil geschrieben. 

=head1 DESCRIPTION

Mit der Funktion ParsePestParameter() wird das angegebene File
geparst. Dabei wird die Datei in die einzelnen Sektionen zerlegt 
und diese wiederum in die Untersektionen. Unter Angabe des 
Pest-Parameterfiles kann mit den unten beschreibenen Funktionen 
auf das Ergebnis des Parsings zurückgegriffen werden. 

     $ret=$pp->ParsePestParameter($Pest_Parameterfile);

Diese Funktion schreibt ein Pest-Parameterfile anhand der über
ParsePestParameter() eingelesenen Daten.

     $ret=$pp->WritePestParameterFile($New_Pest_Parameterfile);

Im Zuchtwertinformationssystem ZwISSS werden für eine Rasse alle
Zuchtwerte dargestellt. Dazu müssen alle Pest-Parameterfiles eingelesen 
und analysiert werden. Alle Pest-Parameterfiles werden in einem Zwisss-
Parameterfile zusammengefaßt. Namensdopplungen von Leistungsdaten und
Effekten (außer der animal-Effekt) werden durch Vergabe eines Alias 
berücksichtigt.
 
     $ret=$pp->WriteZwisssParameterFile($New_ZwISSS_Parameterfile); 

Das ZwISSS-Parameterfile besteht aus 5 Sektionen:

=over 4

=item - TABLES

Tabelle mit allen für ZwISSS relevanten Informationen. Ein Großteil der
Informationen wird automatisch aus den Informationen des Pest-Parameterfiles 
generiert bzw. es werden für den Programmablauf mindestens notwendige 
Default-Werte gesetzt, die aber alle editiert werden können. Die einzelnen 
Positionen haben folgende Bedeutung

=over 4

=item 0 - Feldbezeichnung für ZwISSS

Alias für die Daten aus den Parameterfiles. Diese Feldbezeichnungen dürfen 
B<nicht> verändert werden. 

=item 1 - Herkunft

Ursprünglicher Name im Pest-Parameterfile. Wird geführt in der Form 
B<Parameterfile!Feldbezeichnung>

=item 2 - Typ

Datentyp; Gegenwärtig sind folgende Typen gültig: t, z, y, d

=item 3 - Postion

Position im Textfile - wenn ZwISSS über ein Textfile initialisiert wird.

=item 4 - Start 

Position im DATA/PEDIGREE-File für Pest

=item 5 - Länge

Länge des Feldes im DATA/PEDIGREE-File für Pest

=item 6 - Dezimalstellen

Dezimalstellen für numerische Felder. Für Textfelder wird diese Angabe ignoriert. 

=item 7 - Abkürzung

Name, unter dem das Feld in ZwISSS in den Listen angezeigt wird. 

=item 8 - ?? 

=item 9 - ??

=item 10 - Gruppe

Noch nicht unterstützt 

=item 11 - Anzeige

y/n
y, wenn das Feld in den Auswahllisten von ZwISSS angezeigt werden soll.

=back



=item - ESTIMATIONS

Beschreibung der Zuchtwertschätzung. Für jede Zuchtwertschätzung gibt
 es eine Sektion 

=item - TBVS

Definition des Gesamtzuchtwertes. Es wird automatisch ein Gesamtzuchtwert
je ESTIMATION generiert. 

=item - GROUPS

Definition der Gruppen, für die Gesamtzuchtwerte geschätzt werden.

=item - FORMAT

Formate zur Darstellung von Nummern 

=head2 Parsen des Pest-Parameterfiles
 
Im folgenden werden die einzelnen Funktionen näher beschrieben. Für
alle Funktionen muß das Pest_Parameterfile spezifiziert werden.

Gibt die Zuchtzielmerkmale aus der MODEL-Section als Array zurück.

     @traits=$pp->GetTraits('Pest_Parameterfile');

Gibt alle Effekte aus der MODEL-Section zurück. Effekte mit gleichem
Namen werden nur einmal berücksichtigt.

     @effects=$pp->GetEffects('Pest_Parameterfile');

Array der Namen der Effekte, für die eine genetische Varianz-Covarianz-Matrix
definiert wurde.

     @vg_effekte=$pp->GetVGVG_FOR('Pest_Parameterfile');

Array mit den genetischen Varianzen und Covarianzen. Die Matrix ergibt sich aus
der Anzahl Merkmale in der MODEL-Section

     @vg_varianzen=$pp->GetVGVarianz('Pest_Parameterfile',$vg_effekte[i]);

Array der Namen der Effekte, für die eine Residual-Varianz-Covarianz-Matrix
definiert wurde.
 
     @ve_effekte=$pp->GetVEVE_FOR('Pest_Parameterfile');

Array mit den Varianzen und Covarianzen für das Residual. Die Matrix ergibt sich aus
der Anzahl Merkmale in der MODEL-Section

     @ve_varianzen=$pp->GetVEVarianz('Pest_Parameterfile',$ve_effekte[i]);

Name des Datenfiles. Gültige Einträge unter $section sind DATA oder
RELATIONSHIP 

     $infile=$pp->GetInFile('Pest_Parameterfile',$section);

Name des Output-Files

     $outfile=$pp->GetOutFile('Pest_Parameterfile','PRINTOUT');


=head2 Schreiben eines Pest-Parameterfiles

Erstellt die VE-Section für das $pest_parameterfile

     $text=$pp->WriteVE($pest_parameterfile);

Erstellt die VG-Section für das $pest_parameterfile

     $text=$pp->WriteVG($pest_parameterfile);

Erstellt die MODEL-Section für das $pest_parameterfile

     $text=$pp->WriteModel($pest_parameterfile);

Erstellt die TRANSFORMATION-Section für das $pest_parameterfile

     $text=$pp->WriteTransformation($pest_parameterfile);

Erstellt die SYSTEM-Section für das $pest_parameterfile

     $text=$pp->WriteSystem_Size($pest_parameterfile);

Erstellt die PRINTOUT-Section für das $pest_parameterfile

     $text=$pp->WritePrintout($pest_parameterfile);

Erstellt die DATA-Section für das $pest_parameterfile

     $text=$pp->WriteData($pest_parameterfile);

Erstellt die RELATIONSHIP-Section für das $pest_parameterfile

     $text=$pp->WriteRelationship($pest_parameterfile);

Erstellt die SOLVER-Section für das $pest_parameterfile

     $text=$pp->WriteSolver($pest_parameterfile);


=head1 AUTHOR INFORMATION
 
Copyright 2002, Ulf Müller. 
 
Das Modul ist freie Software. Es kann verteilt und/oder modifiziert
werden unter den gleichen Bedingungen wie PERL.
 
Bitte sendet Bugs und Hinweise an die Adresse info@zwisss.de.

=head1 BUGS

Die Sektionen Hypothesis und Solver werden noch nicht korrekt geparst. 

=head1 SEE ALSO

L<ZwISSS>

=cut
      


#__END__
#################################################################  
package main;
#################################################################  
use strict;
my($a,$b,@b,@traits,%input);
$a=ParsePest->new();
$b=$a->ParsePestParameter('snstpi.par');
$b=$a->WritePestParameterFile('snstpi.par');
$b=$a->SetZwFld();
@traits=$a->GetTraits('snstpi.par');
@traits=$a->GetEffects('snstpi.par');

@b=$a->GetVGVG_FOR('snstpi.par');
@b=$a->GetVGVarianz('snstpi.par',$b[0]);

@b=$a->GetVEVG_FOR('snstpi.par');
@b=$a->GetVEVarianz('snstpi.par',$b[0]);

my $input=$a->GetDataInput('snstpi.par');
$input=$a->GetRelationshipInput('snstpi.par');

$b=$a->WriteZwisssParameterFile('zwisss.model');
print "\n";

__END__


PROBLEME:
Hetero_in funktioniert noch nicht, Solverzerlegung ebenfalls nicht korrekt Hypothesis noch nicht

