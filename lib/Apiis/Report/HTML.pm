###################################################################################
# $Id: HTML.pm,v 1.13 2009-08-14 07:56:25 ulm Exp $
###################################################################################
use Apiis::Report::Base;

###################################################################################
package Apiis::Report::HTML;
@Apiis::Report::HTML::ISA=qw (Apiis::Report::Base);

sub PrintHeader {
  my $self = shift;
  my $query=$self->Query;
  
  my $css=$ENV{'APIIS_HOME'}."/etc/apiis.css";
  if (! exists $ENV{'DOCUMENT_ROOT'}) {
    if (exists $ENV{'APIIS_HOME'}) {
      $css='file://'.$ENV{'APIIS_HOME'}.'/etc/apiis.css';
    } else {
      $css='apiis.css';
    }
  }
  no strict 'refs';
  my $name=${$self->Reportobj->General}[0];
  my $enc=$self->Reportobj->$name->CharSet;
  
  #-- print html-header 
  print $query->header(-charset=>"$enc");

  print $query->start_html(-encoding=>$enc,-style=>{-src=>$css});
  return;
}

sub PrintObjects {
  my $self = shift;
  my $objects = shift;
  my $cell; my $row; my @cell; my $column;

  return if ($#{$objects} eq -1);

  foreach my $o (@$objects) {
    next if ($self->Reportobj->$o->ElementType eq 'Hidden');
    #-- if object a new row, then init new else collect
    no strict 'refs';
    if ($row and ($self->Reportobj->$o->Row ne $row)) {
      $self->PrintRow(\@cell);
      @cell=();
    }
    $row=$self->Reportobj->$o->Row;
    $column=$self->Reportobj->$o->Column;
    $cell[$column-1]=$self->PrintCell($o);
  }
  $self->PrintRow(\@cell);
  return;
}

sub PrintCell {
  my $self = shift;
  my $object = shift;
  my $cell=''; my @properties=(); my $cell1='';
  my $query=$self->Query;
  no strict 'refs';
  my $controled;
  my $replace;
  #-- Datenbehandlung

  no strict 'refs';

  #-- Belegte Zellen finden und kennzeichnen
  if ($self->Reportobj->$object->Column=~/.+\-.+/) {
    my ($min, $max)=($self->Reportobj->$object->Column=~/(.+)\-(.+)/);
    for (my $i=$min; $i<=$max; $i++) {
      $self->Reportobj->SetColumnBusy($i);
    };
  } else {
    $self->Reportobj->SetColumnBusy($self->Reportobj->$object->Column) if ($self->Reportobj->$object->Column=~/^\d+/);
  }

  #-- Spaltenbelegung ermitteln
  my $column=$self->Reportobj->$object->Column;
  if ($column=~/(.+)\-/) {$column=$1};

  if ($self->Reportobj->$object->ElementType eq 'SubReport') {
    my $vsr=$self->Reportobj->$object->ReportSource;
    my $sr=$self->{$vsr};
    my $name=${$sr->Reportobj->General}[0];
    #--- Parameter auflösen
    my @a; my @b; my @c; 
    my ($d)=($sr->Reportobj->$name->DataSource=~/\((.*)\)/);
    @a=split(',',$d);
    foreach my $a (@a) {
      @b=($a=~/\[(.*?)\]/g);
      if ($b[1] and (! exists $self->{$b[0]}) and ($self->Reportobj->fullname ne $b[0])) {
        push @{ $self->{"_Errors"} },
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'ERR',
               from      => 'Apiis::Report::HTML',
               msg_short => __("Report [_1] isn't aktiv", $b[0] )
	    );
	$self->{'_Status'}=1;
	return;
      }
      if (! UNIVERSAL->can( $self->Reportobj->$name->Content)) {
      }
      
      $name=$b[1];
      $sr->{'_Parameter'}->{$a}=[$a,$b[0],$b[0],$self->Reportobj->$name->Content];
    }
    $cell=$sr->MakeReport;
    $sr->{_tablecontent}='';

   # $cell=$self->{$self->Reportobj->$object->ReportSource};
  } elsif (($self->Reportobj->$object->ElementType eq 'Text') or
           ($self->Reportobj->$object->ElementType eq 'Data')) {

    $cell=$self->Reportobj->$object->Content;
    if (($self->Reportobj->$object->DecimalPlaces ne '') and
        ($self->Reportobj->$object->DecimalPlaces ne 'Automatic') and 
	($self->Reportobj->$object->DecimalPlaces ne 'none')) {
      $cell=sprintf('%.'.$self->Reportobj->$object->DecimalPlaces.'f', $cell);
    }
  }
  if (($self->Reportobj->$object->ElementType eq 'Lines')) {
    $cell=$query->img({-src=>"/icons/blank1.gif"},);
    my $r=$self->Reportobj->$object->ForegroundColor;
    my $t=$self->Reportobj->$object->LineType ;
    my $w=$self->Reportobj->$object->LineWidth;
    push(@properties,"border-top: $t $r $w");
  }

  if ($cell=~/^date\(/) {
    $cell=localtime();
  }

  #--- loop over all elements
  foreach  my $item (keys %{$self->Reportobj->$object}) {

    #--- initialize
    $replace='';
    $t='';

    #--- skip internal methods
    next if ($item=~/^_/);
    
    #--- if content a function, then solve function and save return value
    if ($self->Reportobj->$object->$item=~/^([_a-zA-Z0-9_]*)\((.*)\)$/) {
      my @vparam=split(',',$2); 
      my $vfunction="Apiis::Report::Base::$1";
      
      #--- test if module exists
      if (! $self->Reportobj->CheckModul) {
        $self->LinkModul($self->Reportobj->path.'/'.$self->Reportobj->basename.".pm");
	return if ($self->Status==1);
      }
      
      #--- set parameters and auflösen
      my @vvparam=();
      foreach my $v (@vparam) {
        if ($v=~/\[(.*?)\]/) {
	  push(@vvparam,$self->Reportobj->$1->Content);
	} else {
	  push(@vvparam,$v);
	}
      }
      
      #--- execute function
      eval {
        $replace = &$vfunction($self, @vvparam);
      };  
      if ($@) {
        push @{ $self->{"_Errors"} },
         Apiis::Errors->new(
         type      => 'CODE',
         severity  => 'ERR',
         from      => 'Apiis::Report::Base',
         msg_short => "Can't execute function $vfunction in module: $module",
         msg_long =>  "$@"
        );
        $self->{'_Status'}=1;
        return;
      }
    }
  
    if ($self->Reportobj->$object->$item ne '') {
      my $t=$self->Reportobj->$object->$item ;
      $t=$replace if ($replace);
      next if (($t eq 'none') or ($t eq ''));
      
      #--- 
      push(@properties,"width: $t")   if ($item eq 'Width');
      
      #--- Font 
      push(@properties,"font-family: $t")   if ($item eq 'FontFamily');
      push(@properties,"font-size: $t")     if ($item eq 'FontSize');;
      push(@properties,"font-style: $t")    if ($item eq 'FontStyle');;
      push(@properties,"font-weight: $t")   if ($item eq 'FontWeight');;
      push(@properties,"font-variant: $t")  if ($item eq 'FontVariant');;
      push(@properties,"font: $t")          if ($item eq 'Font');;
  
      #--- Color
      push(@properties,"background-color: $t") if ($item eq 'BackgroundColor');
      push(@properties,"color: $t")            if ($item eq 'Color');
      push(@properties,"background-image: $t") if ($item eq 'BackgroundImage');
      push(@properties,"background-repeat: $t") if ($item eq 'BackgroundRepeat');
      push(@properties,"background-attachment: $t") if ($item eq 'BackgroundAttachment');
      push(@properties,"background-position: $t")   if ($item eq 'BackgroundPosition');
      push(@properties,"background: $t")            if ($item eq 'Background');
  
      #--- Text
      push(@properties,"word-spacing: $t")        if ($item eq 'WordSpacing');
      push(@properties,"letter-spacing: $t")      if ($item eq 'LetterSpacing');
      push(@properties,"text-decoration: $t")     if ($item eq 'TextDecoration');
      push(@properties,"vertical-align: $t")      if ($item eq 'VerticalAlign');
      push(@properties,"text-transform: $t")      if ($item eq 'TextTransform');
      push(@properties,"text-align: $t")          if ($item eq 'TextAlign');
      push(@properties,"text-indent: $t")         if ($item eq 'TextIndent');
      push(@properties,"text-height: $t")         if ($item eq 'LineHeight');
  
      #--- Block
      push(@properties,"margin-top: $t")    if ($item eq 'MarginTop');
      push(@properties,"margin-right: $t")  if ($item eq 'MarginRight');
      push(@properties,"margin-bottom: $t") if ($item eq 'MarginBottom');
      push(@properties,"margin-left: $t")   if ($item eq 'MarginLeft');
      push(@properties,"margin: $t")        if ($item eq 'Margin');
      
      push(@properties,"padding-top: $t")    if ($item eq 'PaddingTop');
      push(@properties,"padding-right: $t")  if ($item eq 'PaddingRight');
      push(@properties,"padding-bottom: $t") if ($item eq 'PaddingBottom');
      push(@properties,"padding-left: $t")   if ($item eq 'PaddingLeft');
      push(@properties,"padding: $t")        if ($item eq 'Padding');
      
      push(@properties,"border-top-width: $t")    if ($item eq 'BorderTopWidth');
      push(@properties,"border-right-width: $t")  if ($item eq 'BorderRightWidth');
      push(@properties,"border-bottom-width: $t") if ($item eq 'BorderBottomWidth');
      push(@properties,"border-left-width: $t")   if ($item eq 'BorderLeftWidth');
      push(@properties,"border-width: $t")        if ($item eq 'BorderWidth');
      
      push(@properties,"border-style: $t")   if ($item eq 'BorderStyle');
      push(@properties,"border-color: $t")   if ($item eq 'BorderColor');
      
      push(@properties,"border-top: $t")    if ($item eq 'BorderTop');
      push(@properties,"border-right: $t")  if ($item eq 'BorderRight');
      push(@properties,"border-bottom: $t") if ($item eq 'BorderBottom');
      push(@properties,"border-left: $t")   if ($item eq 'BorderLeft');
      push(@properties,"border: $t")        if ($item eq 'Border');
  
      push(@properties,"width: $t")       if ($item eq 'BlockWidth');
      push(@properties,"height: $t")      if ($item eq 'BlockHeight');
      push(@properties,"float: $t")       if ($item eq 'BlockFloat');
      push(@properties,"clear: $t")       if ($item eq 'Clear');
      push(@properties,"display: $t")     if ($item eq 'Display');
      push(@properties,"white-space: $t") if ($item eq 'WhiteSpace');

      #--- List
      push(@properties,"list-style-type: $t")     if ($item eq 'ListStyleType');
      push(@properties,"list-style-image: $t")    if ($item eq 'ListStyleImage');
      push(@properties,"list-style-position: $t") if ($item eq 'ListStylePosition');
      push(@properties,"list-style: $t")          if ($item eq 'ListStyle');
    }
  }
  my $a; my $properties2='';
  if ($self->Reportobj->$object->Column=~/^(.+)\-(.+)/) {
    $a=$2 - $1 + 1;
    $properties2='colspan="'.$a.'"';
  } 
  if ($self->Reportobj->$object->Row=~/^(.+)\-(.+)/) {
    $a=$2 - $1 + 1;
    $properties2.=' rowspan="'.$a.'"';
  } 

  my $properties='STYLE="'.join(';',@properties).'"';
  return $query->td({$properties .' '. $properties2},$cell);
}

sub PrintRow {
  my $self = shift;
  my $vcell = shift;
  my @cell=@{$vcell};
  my $cell=''; my $properites='';
  my $query=$self->Query;

  #--
  for (my $i=0; $i<$self->Reportobj->MaxColumn ;$i++) {
    if (! @{$self->Reportobj->SetColumnBusy}[$i]) {
      $cell.=$query->td({},"");
    } else {
      $cell.=@cell[$i];
    }
  }
  $self->{'_tablecontent'}.=$query->TR({$properties},$cell);
  $self->Reportobj->SetColumnBusy(-1);
}

sub PrintTable {
  my $self = shift;
  my $query=$self->Query;

#  if ($self->$object->Border ne '') {
#    my $t=$self->Reportobj->$object->Border ;
#    push(@properties,"border: $t");
#  }

#  my $t=$self->{'_tablecontent'};
#  $self->{'_tablecontent'}='';
  return $query->table({border=>"0", cellspacing=>"0", cellpadding=>"0"},$self->{'_tablecontent'});
}

1;


