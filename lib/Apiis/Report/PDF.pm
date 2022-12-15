###################################################################################
# $Id: PDF.pm,v 1.4 2004/09/09 15:14:12 ralf Exp $
###################################################################################
use Apiis::Report::Base;

###################################################################################
package Apiis::Report::PDF;
@Apiis::Report::PDF::ISA=qw (Apiis::Report::Base);

sub PrintHeader {
  my $self= shift;
  print $latex_header;
  # print "\\begin{longtable}{*{" . $self->Reportobj->MaxColumn .  "}{c}}\n";
  return;
}

sub PrintObjects {
  my $self = shift;
  my $objects = shift;

  my $cell; my $row; my @cell; my $column;
  return if ($#{$objects} eq -1);
  my $obj = ${$objects}[0];

  if ( $self->Reportobj->$obj->CallFrom ne 'ReportHeader' and $self->{'_rheaderon'} eq '1' and  $self->Reportobj->$obj->CallFrom ne 'Detail') {
    $self->{'_longtablecontent'} .=  "\\end{longtable}\n\n";
    $self->{'_rheaderon'} = ();
  }
  if ( $self->Reportobj->$obj->CallFrom ne 'ReportHeader' and $self->{'_rheaderon'} eq '1' and  $self->Reportobj->$obj->CallFrom eq 'Detail') {
    $self->{'_longtablecontent'} .=  "\\endhead\n\n";
    $self->{'_rheaderon'} = ();
  }
  if ( $self->Reportobj->$obj->CallFrom ne 'PageHeader' and $self->{'_pheaderon'} eq '1' ) {
    $self->{'_longtablecontent'} .=  "\\endhead\n\n";
    $self->{'_pheaderon'} = ();
  }
  if ( $self->Reportobj->$obj->CallFrom ne 'GroupHeader' and $self->{'_gheaderon'} eq '1' and ( ! $self->Reportobj->PageHeader ) ) {
    $self->{'_longtablecontent'} .=  "\\endhead\n\n";
    $self->{'_gheaderon'} = ();
  }

  if ( $self->Reportobj->$obj->CallFrom eq 'ReportHeader' and  ( $self->{'_rheaderon'} ne '1' ) ) {
    $self->{'_longtablecontent'} .= "\\begin{longtable}{*{" . $self->Reportobj->MaxColumn .  "}{c}}\n";
    $self->{'_rheaderon'} = '1';
  } elsif ( $self->Reportobj->$obj->CallFrom eq 'PageHeader' ) {
    $self->{'_longtablecontent'} .= "\\begin{longtable}{*{" . $self->Reportobj->MaxColumn .  "}{c}}\n";
    $self->{'_pheaderon'} = '1';
  } elsif ( $self->Reportobj->$obj->CallFrom eq 'GroupHeader' and ( ! $self->Reportobj->PageHeader ) ) {
    $self->{'_longtablecontent'} .= "\\begin{longtable}{*{" . $self->Reportobj->MaxColumn .  "}{c}}\n";
    $self->{'_gheaderon'} = '1';
  }

  foreach my $o (@$objects) {
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
  # use Data::Dumper;
  # print "++++++>". Dumper($self) . "<+++++\n";

  my $cell='';			# my @properties=();
  my $query=$self->Query;
  no strict 'refs';
  my $colcount = 1;
  my $align = 'l';
  my $withcolor = 0;
  #-- Datenbehandlung
  #-- Belegte Zellen finden und kennzeichnen
  if ($self->Reportobj->$object->Column=~/.+\-.+/) {
    my ($min, $max)=($self->Reportobj->$object->Column=~/(.+)\-(.+)/);
    $colcount = $max - $min + 1;
    for (my $i=$min; $i<=$max; $i++) {
      $self->Reportobj->SetColumnBusy($i);
    }
    ;
  } else {
    $self->Reportobj->SetColumnBusy($self->Reportobj->$object->Column) if ($self->Reportobj->$object->Column=~/^\d+/);
  }

  #-- Spaltenbelegung ermitteln
  my $column=$self->Reportobj->$object->Column;
  if ($column=~/(.+)\-/) {$column=$1};

  if ($self->Reportobj->$object->ElementType eq 'SubReport') {
    $cell=$self->{$self->Reportobj->$object->ReportSource};
    $cell =~ s/longtable/tabular/g; # no longtable inside possible
    $cell =~ s/\\endhead//g; # endhead is specific longtable
  } elsif (($self->Reportobj->$object->ElementType eq 'Text') or
	   ($self->Reportobj->$object->ElementType eq 'Data')) {

    #--- Wenn Verweis auf anderen Report, dann den ausführen und Tabelle in Zelle abspeichern
    $cell=$self->Reportobj->$object->Content;
    if (($self->Reportobj->$object->DecimalPlaces ne '') and
        ($self->Reportobj->$object->DecimalPlaces ne 'Automatic')) {
      $cell=sprintf('%.'.$self->Reportobj->$object->DecimalPlaces.'f', $cell);
    }
  }
  if (($self->Reportobj->$object->ElementType eq 'Lines')) {
    #     my $r=$self->Reportobj->$object->ForegroundColor;
    #     my $t=$self->Reportobj->$object->LineType ;
    #     my $w=$self->Reportobj->$object->LineWidth;
    if ( $self->Reportobj->$object->Column =~ /(.+)\-/ and $colcount < $self->Reportobj->MaxColumn ) {
      my $column=$self->Reportobj->$object->Column;
      $add_line .= "\\cline{$column}"; # nur eine dicke mgl
    } else {
      $add_line .= '\hline';
      $add_line .= "\\hline" if $self->Reportobj->$object->LineType eq 'double';
      $add_line .= "\\hline" if $self->Reportobj->$object->LineWidth eq 'medium';
      $add_line .= "\\hline" if $self->Reportobj->$object->LineWidth eq 'thick';
    }
    #$cell=$query->img({-src=>"/icons/blank1.gif"},);
    #    push(@properties,"border-top: $t $r $w");
  }

  if ($cell=~/^date\(/) {
    $cell=localtime();
  }

  if ($self->Reportobj->$object->FontStyle ne '') {
    my $t=$self->Reportobj->$object->FontStyle ;
    $t = 'it' if $t =~ /italic/;
    $t = 'sl' if $t =~ /oblique/;
    push(@properties,"\\fontshape{$t}\\selectfont");
  }
  if ($self->Reportobj->$object->FontSize ne '') {
    my $t=$self->Reportobj->$object->FontSize ;
    $t =~ s/px/pt/g;
    push(@properties,"\\fontsize{$t}{ 12pt }\\selectfont");
  }
  if ($self->Reportobj->$object->FontWeight ne '') {
    my $t=$self->Reportobj->$object->FontWeight ;
    $t = 'bx' if $t =~ /bold/;
    push(@properties,"\\fontseries{$t}\\selectfont");
    #    $t = '\bf' if $t =~ /bold/;
    #    push(@properties,"$t");
  }
  if ($self->Reportobj->$object->FontVariant ne '') {
    my $t=$self->Reportobj->$object->FontVariant ;
    $t = 'sc' if $t =~ /small_caps/;
    push(@properties,"\\fontshape{$t}\\selectfont");
  }
  if ($self->Reportobj->$object->FontFamily ne '') {
    my $t=$self->Reportobj->$object->FontFamily ;
    $t = 'cmr' if $t =~ /serif/;
    push(@properties,"\\fontfamily{$t}\\selectfont");
  }
  if ($self->Reportobj->$object->BackgroundColor ne '') {
    $withcolor++;
    my $t=$self->Reportobj->$object->BackgroundColor ;
    my @color = colortrans($t); # sub to define hex -> number
    push(@properties, "\\definecolor{mycol}{rgb}{@color}");
    push(@properties, "\\colorbox{mycol}{");
  }
  if ($self->Reportobj->$object->Color ne '') {
    $withcolor++;
    my $t=$self->Reportobj->$object->Color ;
    my @color = colortrans($t); # sub to define hex -> number
    push(@properties, "\\definecolor{mycol}{rgb}{@color}");
    push(@properties, "\\textcolor{mycol}{");
    # push(@properties,"color: $t");
  }
  #   if ($self->Reportobj->$object->WordSpacing ne '') {
  #     my $t=$self->Reportobj->$object->WordSpacing ;
  #     push(@properties,"word-spacing: $t");
  #   }
  #   if ($self->Reportobj->$object->LetterSpacing ne '') {
  #     my $t=$self->Reportobj->$object->LetterSpacing ;
  #     push(@properties,"letter-spacing: $t");
  #   }
  #   if ($self->Reportobj->$object->TextDecoration ne '') {
  #     my $t=$self->Reportobj->$object->TextDecoration ;
  #     push(@properties,"text-decoration: $t");
  #   }
  #   if ($self->Reportobj->$object->VerticalAlign ne '') {
  #     my $t=$self->Reportobj->$object->VerticalAlign ;
  #     push(@properties,"vertical-align: $t");
  #   }
  #   if ($self->Reportobj->$object->Middle ne '') {
  #     my $t=$self->Reportobj->$object->Middle ;
  #     push(@properties,"middle: $t");
  #   }
  #   if ($self->Reportobj->$object->TextTransform ne '') {
  #     my $t=$self->Reportobj->$object->TextTransform ;
  #     push(@properties,"text-transform: $t");
  #   }
  if ($self->Reportobj->$object->TextAlign ne '') {
    my $t=$self->Reportobj->$object->TextAlign ;
    $align = 'l' if $t =~ /left/;
    $align = 'c' if $t =~ /central/;
    $align = 'r' if $t =~ /right/;
  }

  my $myreturn .= "\\multicolumn{$colcount}{".$align."}{@properties $cell }";
  foreach ( my $w=1; $w<=$withcolor; $w++ ) {
    $myreturn .= "}";
  }
  $withcolor = 0;
  @properties = ();
  return $myreturn;
}

sub PrintRow {
  my $self = shift;
  my $vcell = shift;

  my @cell=@{$vcell};
  my $po = $#cell;
  my $cell=''; my $properites='';
  my $query=$self->Query;

  #--
  for (my $i=0; $i<$self->Reportobj->MaxColumn ;$i++) {
    if (! @{$self->Reportobj->SetColumnBusy}->[$i]) {
      $cell[$i] = ' \rule{0mm}{0mm} ' ;
    }
    #  else {
    #       $cell[$i] = $cell[$i];
    #     }
  }
  my @cellnew = ();
  map { if ( $_ ) { push( @cellnew, $_ ) }; } @cell;
  $cell = join( ' & ', @cellnew );
  $self->{'_longtablecontent'}.= $cell . "\\\\" if ( ! $add_line );
  $self->{'_longtablecontent'}.= "$add_line \n"  if ( $add_line );
  $self->{'_longtablecontent'}.= "\n" ;
  $self->Reportobj->SetColumnBusy(-1);
  $add_line = ();
}

sub PrintLongTable {
  my $self = shift;
  # my $query=$self->Query;
  $self->{'_longtablecontent'} .= "\\end{longtable}\n\n";
  return  $self->{'_longtablecontent'};
}

sub PrintTable {
  my $self = shift;
  # rffr #
  return $self->PrintLongTable;
  #  return $latex_footer;
}

sub PrintFooter {
  my $self = shift;
  $self->{'_longtablecontent'} .= "$latex_footer\n\n";
  print $self->{'_longtablecontent'};
}

sub PrintReport {
  my $self = shift;
#   system( "pdflatex $self->{'_longtablecontent'} >qq.pdf" );
#   system( "acroread qq.pdf &" );
}

#####
$latex_header = '
\documentclass[10pt,a4paper,DIV14,pdftex]{scrartcl}
\usepackage{german}
\usepackage{umlaut}
\usepackage{multicol}
\usepackage{color}
\usepackage{longtable}
\usepackage[pdftex]{graphicx}
%\pagestyle{empty}

\begin{document}
';

$latex_footer = "\n\\end{document}\n";

sub colortrans{
  my @ret=(0,1,0);
  @ret = join( ', ', @ret );
  my $s=shift;
  if(substr($s,0,1) ne '#'){return @ret;}
  my $l=(length($s)-1)/3;
  my $i;
  for $i (0..2){ $ret[$i]=(hex(substr($s,1+$i*$l,$l)))/(16**$l-1); }
  @ret = join( ', ', @ret );
  return @ret;
}

1;


