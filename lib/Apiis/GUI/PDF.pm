###################################################################################
# $Id: PDF.pm,v 1.22 2020/11/03 19:03:32 ulf Exp $
###################################################################################
use Apiis::GUI;

###################################################################################
package Apiis::GUI::PDF;
@Apiis::GUI::PDF::ISA=qw (Apiis::GUI);

sub PrintHeader {
  my $self= shift;
  $self->{'_longtablecontent'}=$latex_header;
  return;
}

sub PrintObjects {
  my $self = shift;
  my $objects = shift;
  my $parent=shift;
  my $cell; my $row; my @cell; my $column;

  return if ($#{$objects} eq -1);
  if (! $parent) {
    if ($self->GUI eq "Report") {
      $parent=$self->GUIobj->{$objects->[0]}->CallFrom;
      $parent=$self->GUIobj->$parent->[0];
    }
  }
  if (! defined $parent) {
    $parent=$self->GUIobj->{$objects->[0]}->Parent;
  }

  my $check_parent = $parent;
  $check_parent =~ s/_.+$//;

  if ( $check_parent ne 'GUIHeader' and $self->{'_rheaderon'} eq '1' and  $check_parent ne 'Detail') {
    $self->{'_longtablecontent'} .=  "\\end{longtable}\n\n";
    $self->{'_rheaderon'} = ();
  }
  if ( $check_parent ne 'GUIHeader' and $self->{'_rheaderon'} eq '1' and  $check_parent eq 'Detail') {
    $self->{'_longtablecontent'} .=  "\\endhead\n\n";
    $self->{'_rheaderon'} = ();
  }
  if ( $check_parent ne 'PageHeader' and $self->{'_pheaderon'} eq '1' ) {
    $self->{'_longtablecontent'} .=  "\\endhead\n\n";
    $self->{'_pheaderon'} = ();
  }
  if ( $check_parent ne 'GroupHeader' and $self->{'_gheaderon'} eq '1' and ( ! $self->GUIobj->PageHeader ) ) {
    $self->{'_longtablecontent'} .=  "\\endhead\n\n";
    $self->{'_gheaderon'} = ();
  }

  if ( $check_parent eq 'GUIHeader' and  ( $self->{'_rheaderon'} ne '1' ) ) {
    $self->{'_longtablecontent'} .= "\\begin{longtable}[l]{*{" . $self->GUIobj->MaxColumn .  "}{c}}\n";
    $self->{'_rheaderon'} = '1';
  } elsif ( $check_parent eq 'PageHeader' ) {
    $self->{'_longtablecontent'} .= "\\begin{longtable}[l]{*{" . $self->GUIobj->MaxColumn .  "}{c}}\n";
    $self->{'_pheaderon'} = '1';
  } elsif ( $check_parent eq 'GroupHeader' and ( ! $self->GUIobj->PageHeader ) ) {
    $self->{'_longtablecontent'} .= "\\begin{longtable}[l]{*{" . $self->GUIobj->MaxColumn .  "}{c}}\n";
    $self->{'_gheaderon'} = '1';
  }

  if ($#{$self->GUIobj->$parent->OrderByRow} eq -1) {
    my @s=();
    foreach (@{$self->GUIobj->$parent->Children}) {
      push(@s,[$self->GUIobj->$_->Row, $_]);
    }
    map {push(@{$self->GUIobj->$parent->OrderByRow},$_->[1])} sort {$a->[0] <=> $b->[0]} @s;
  }

  foreach my $o (@{$self->GUIobj->$parent->OrderByRow}) {
    next if ($self->GUIobj->$o->ElementType eq 'Hidden');
    #-- if object a new row, then init new else collect
    no strict 'refs';
    # pagebreak
    if ($self->GUIobj->$o->ElementType eq 'PageBreak') {
      $self->{'_longtablecontent'}.= "\\pagebreak";
    }
    if ($row and ($self->GUIobj->$o->Row ne $row)) {
      $self->PrintRow(\@cell);
      @cell=();
    }
    $row=$self->GUIobj->$o->Row;
    $column=$self->GUIobj->$o->Column;

    if ($row) { 
      $cell[$column-1]=$self->PrintCell($o);
    } else {
      if ($self->GUIobj->$o->ElementType eq 'Block') {
        $self->PrintObjects($self->GUIobj->$o->Children,$self->GUIobj->$o->Name);
      }
    }
  }
  $self->PrintRow(\@cell);
  return;
}

sub PrintCell {
  my $self = shift;
  my $object = shift;
  my $cell=''; my @properties=(); my @propertiesend=(); my @propertiesfirst=();
  my $query=$self->Query;
  no strict 'refs';
  my $controled;
  my $replace;
  # special tex
  my $colcount = 1;
  my $withcolor = 0;
  my $align = 'l';

  #-- Datenbehandlung
  my $et=$self->GUIobj->$object->ElementType;
  my $column=$self->GUIobj->$object->Column;

  no strict 'refs';
  #-- Belegte Zellen finden und kennzeichnen
  if ($column=~/.+\-.+/) {
    my ($min, $max)=($column=~/(.+)\-(.+)/);
    $colcount = $max - $min + 1;
    for (my $i=$min; $i<=$max; $i++) {
      $self->GUIobj->SetColumnBusy($i);
    }
    ;
  } else {
    $self->GUIobj->SetColumnBusy($column) if ($column=~/^\d+/);
  }

  #-- Spaltenbelegung ermitteln
  #if ($column=~/(.+)\-/) {$column=$1};

  if ($et eq 'SubGUI') {
    my $vsr=$self->GUIobj->$object->GUISource;
    my $sr=$self->{$vsr};
    my $name=${$sr->GUIobj->General}[0];
    #--- Parameter auflösen
    my @a; my @b; my @c; 
    my ($d)=($sr->GUIobj->$name->DataSource=~/\((.*)\)/);
    @a=split(',',$d);
    foreach my $a (@a) {
      @b=($a=~/\[(.*?)\]/g);
      next if ($#b==-1);
      if ($b[1] and (! exists $self->{$b[0]}) and ($self->GUIobj->fullname ne $b[0])) {
        $self->Apiis->errors(
			     Apiis::Errors->new(
						type      => 'CODE',
						severity  => 'ERR',
						from      => 'Apiis::GUI::PDF',
						msg_short => __("GUI [_1] isn't aktiv", $b[0] )
					       ));
	$self->Apiis->status(1);
	return;
      }
      $name=$b[1];
      if ( $self->GUIobj->$name->can('Content')) {
        $sr->{'_Parameter'}->{$a}=[$a,$b[0],$b[0],$self->GUIobj->$name->Content];
      }	
    }
    $cell=$sr->MakeGUI;
    $sr->{_longtablecontent}='';

    $cell =~ s/longtable/tabular/g; # no longtable inside possible
    $cell =~ s/\\endhead//g;	# endhead is specific longtable
    # $cell=$self->{$self->GUIobj->$object->GUISource};

  } elsif (($et eq 'Text') or ($et eq 'Data') or ($et eq 'Label') or ($et eq 'Field') ) {

    $cell=$self->GUIobj->$object->Content;

    if ($et eq 'Data') {
      if (($self->GUIobj->$object->DecimalPlaces ne '') and
          ($self->GUIobj->$object->DecimalPlaces ne 'Automatic') and 
  	  ($self->GUIobj->$object->DecimalPlaces ne 'none')) {
        $cell=sprintf('%.'.$self->GUIobj->$object->DecimalPlaces.'f', $cell);
      }	
    }
    $cell = special_tex( $cell );
  }


  if (($et eq 'Lines') or ($self->GUIobj->$object->FieldType eq 'Line')) {
    if ( $self->GUIobj->$object->Column =~ /(.+)\-/ and $colcount < $self->GUIobj->MaxColumn ) {
      my $column=$self->GUIobj->$object->Column;
      $add_line .= "\\cline{$column}"; # nur eine dicke mgl
    } else {
      $add_line .= '\hline';
      $add_line .= "\\hline" if $self->GUIobj->$object->LineType eq 'double';
      $add_line .= "\\hline" if $self->GUIobj->$object->LineWidth eq 'medium';
      $add_line .= "\\hline" if $self->GUIobj->$object->LineWidth eq 'thick';
    }
  }
  if ($cell=~/^date\(/) {
    $cell=localtime();
  }

  if ($self->GUI eq 'Report') {
    my $testwidth = 1;
    if ($self->GUIobj->$object->{'PaddingLeft'} ) {
      my $t = $self->GUIobj->$object->{'PaddingLeft'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t =~ s/px/pt/g;
	push(@properties, "\\hspace*{$t} ");
      }
    }
    if ($self->GUIobj->$object->{'PaddingTop'} ) {
      my $t = $self->GUIobj->$object->{'PaddingTop'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t =~ s/px//g;
	$t = $t + 12;
	$t = $t . 'pt';
	push(@properties, "\\rule[0mm]{0mm}{$t} ");
      }
    }
    if ($self->GUIobj->$object->{'Width'} ) {
      my $t = $self->GUIobj->$object->{'Width'};
      if (! (($t eq 'none') or ($t eq ''))) {
	if ( $t =~ /px/ ) {
	  $t =~ s/px//g;
	  $t = $t . 'pt';
	} elsif ( $t =~ /%/ ) {
	  $t =~ s/%//g;
	  $t = $t * 170 / 100;
	  $t = $t . 'mm';
	}
	$testwidth = 2;
	push(@properties, "\\parbox[t]{$t \\vspace{1.0ex}}{ ");
      }
    }
    if ($self->GUIobj->$object->{'FontStyle'} ) {
      my $t = $self->GUIobj->$object->{'FontStyle'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t = 'it' if $t =~ /italic/;
	$t = 'sl' if $t =~ /oblique/;
	push(@properties,"\\fontshape{$t}\\selectfont");
      }
    }
    if ($self->GUIobj->$object->{'FontSize'} ) {
      my $t = $self->GUIobj->$object->{'FontSize'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t =~ s/px/pt/g;
	push(@properties,"\\fontsize{$t}{ 12pt }\\selectfont");
      }
    }
    if ($self->GUIobj->$object->{'FontWeight'} ) {
      my $t = $self->GUIobj->$object->{'FontWeight'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t = 'bx' if $t =~ /bolder/;
	$t = 'b' if $t =~ /bold/;
	push(@properties,"\\fontseries{$t}\\selectfont");
	#    $t = '\bf' if $t =~ /bold/;
	#    push(@properties,"$t");
      }
    }
    if ($self->GUIobj->$object->{'FontVariant'} ) {
      my $t = $self->GUIobj->$object->{'FontVariant'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t = 'sc' if $t =~ /small_caps/;
	push(@properties,"\\fontshape{$t}\\selectfont");
      }
    }
    if ($self->GUIobj->$object->{'FontFamily'} ) {
      my $t = $self->GUIobj->$object->{'FontFamily'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t = 'cmr' if $t =~ /serif/;
	push(@properties,"\\fontfamily{$t}\\selectfont");
      }
    }
    if ($self->GUIobj->$object->{'BackgroundColor'} ) {
      my $t = $self->GUIobj->$object->{'BackgroundColor'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$withcolor++;
	my @color = colortrans($t); # sub to define hex -> number
	push(@properties, "\\definecolor{mycol}{rgb}{@color}");
	push(@properties, "\\colorbox{mycol}{");
      }
    }
    if ($self->GUIobj->$object->{'Color'} ) {
      $withcolor++;
      my $t = $self->GUIobj->$object->{'Color'};
      if (! (($t eq 'none') or ($t eq ''))) {
	my @color = colortrans($t); # sub to define hex -> number
	push(@properties, "\\definecolor{mycol}{rgb}{@color}");
	push(@properties, "\\textcolor{mycol}{");
      }
    }
    if ($self->GUIobj->$object->{'TextDecoration'} ) {
      my $t = $self->GUIobj->$object->{'TextDecoration'};
      if (! (($t eq 'none') or ($t eq ''))) {
	if ( $t =~ /underline/ ) {
          push(@properties, "\\underline{ ");
	  push(@propertiesend, " }" );
	}
      }
    }
    if ($self->GUIobj->$object->{'PaddingRight'} ) {
      my $t = $self->GUIobj->$object->{'PaddingRight'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t =~ s/px/pt/g;
	push(@propertiesend, "\\hspace*{$t} ");
      }
    }
    if ($self->GUIobj->$object->{'PaddingBottom'} ) {
      my $t = $self->GUIobj->$object->{'PaddingBottom'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$t =~ s/px/pt/g;
	push(@properties, "\\vspace*{$t} ");
      }
    }
    if ($self->GUIobj->$object->{'TextAlign'} ) {
      my $t = $self->GUIobj->$object->{'TextAlign'};
      if (! (($t eq 'none') or ($t eq ''))) {
	$align = 'l' if $t =~ /left/;
	$align = 'r' if $t =~ /right/;
	$align = 'c' if $t =~ /center/;
      }
    }

    foreach my $item (@{$self->GUIobj->$object->Functions}) {
      #--- initialize
      $replace='';
      $t='';

      #--- if content a function, then solve function and save return value
      if ($self->GUIobj->$object->$item=~/^([_a-zA-Z0-9_]*)\((.*)\)$/) {
	my @vparam=split(',',$2);
	my $vfunction="Apiis::GUI::$1";

	#--- test if module exists
	if (! $self->GUIobj->CheckModul) {
	  $self->LinkModul($self->GUIobj->path.'/'.$self->GUIobj->basename.".pm");
	  return if ($self->Apiis->status==1);
	}

	#--- set parameters and auflösen
	my @vvparam=();
	foreach my $v (@vparam) {
	  if ($v=~/\[(.*?)\]/) {
	    push(@vvparam,$self->GUIobj->$1->Content);
	  } else {
	    push(@vvparam,$v);
	  }
	}

	#--- execute function
	eval {
	  $replace = &$vfunction($self, @vvparam);
	};
	if ($@) {
	  $self->Apiis->errors(
			       Apiis::Errors->new(
						  type      => 'CODE',
						  severity  => 'ERR',
						  from      => 'Apiis::GUI',
						  msg_short => "Can't execute function $vfunction in module: $module",
						  msg_long =>  "$@"
						 ));
	  $self->Apiis->status(1);
	  return;
	}

	my $t=$replace;
	next if (($t eq 'none') or ($t eq ''));

	if ( $item eq 'PaddingLeft' ) {
	  $t =~ s/px/pt/g;
	  push(@properties, "\\hspace*{$t} ");
	}
	if ($self->GUIobj->$object->{'PaddingTop'} ) {
	  if (! (($t eq 'none') or ($t eq ''))) {
	    $t =~ s/px//g;
	    $t = $t + 12;
	    $t = $t . 'pt';
	    push(@properties, "\\rule[0mm]{0mm}{$t} ");
	  }
	}
	if ( $item eq 'FontStyle' ) {
	  $t = 'it' if $t =~ /italic/;
	  $t = 'sl' if $t =~ /oblique/;
	  push(@properties,"\\fontshape{$t}\\selectfont");
	}
	if ( $item eq 'FontSize' ) {
	  $t =~ s/px/pt/g;
	  push(@properties,"\\fontsize{$t}{ 12pt }\\selectfont");
	}
	if ( $item eq 'FontWeight' ) {
	  $t = 'bx' if $t =~ /bolder/;
	  $t = 'b' if $t =~ /bold/;
	  push(@properties,"\\fontseries{$t}\\selectfont");
	  #    $t = '\bf' if $t =~ /bold/;
	  #    push(@properties,"$t");
	}
	if ( $item eq 'FontVariant' ) {
	  $t = 'sc' if $t =~ /small_caps/;
	  push(@properties,"\\fontshape{$t}\\selectfont");
	}
	if ( $item eq 'FontFamily' ) {
	  $t = 'cmr' if $t =~ /serif/;
	  push(@properties,"\\fontfamily{$t}\\selectfont");
	}
	if ( $item eq 'BackgroundColor' ) {
	  $withcolor++;
	  my @color = colortrans($t); # sub to define hex -> number
	  push(@properties, "\\definecolor{mycol}{rgb}{@color}");
	  push(@properties, "\\colorbox{mycol}{");
	}
	if ( $item eq 'Color' ) {
	  $withcolor++;
	  my @color = colortrans($t); # sub to define hex -> number
	  push(@properties, "\\definecolor{mycol}{rgb}{@color}");
	  push(@properties, "\\textcolor{mycol}{");
	  # push(@properties,"color: $t");
	}
	if ( $item eq 'TextDecoration' ) {
	  if ( $t =~ /underline/ ) {
	    push(@properties, "\\underline{ ");
	  }
	}
	if ( $item eq 'PaddingRight' ) {
	  $t =~ s/px/pt/g;
	  push(@propertiesend, "\\hspace*{$t} ");
	}
	if ($self->GUIobj->$object->{'PaddingBottom'} ) {
	  my $t = $self->GUIobj->$object->{'PaddingBottom'};
	  if (! (($t eq 'none') or ($t eq ''))) {
	    $t =~ s/px/pt/g;
	    push(@properties, "\\vspace*{$t} ");
	  }
	}
	if (  $item eq 'TextAlign' ) {
	  $align = 'l' if $t =~ /left/;
	  $align = 'r' if $t =~ /right/;
	  $align = 'c' if $t =~ /center/;
	}
	# end properties
      }
    }

    my $myreturn .= "@propertiesfirst \\multicolumn{$colcount}{".$align."}{ @properties $cell @propertiesend }";
    foreach ( my $w=1; $w<=$withcolor; $w++ ) {
      $myreturn .= "}";
    }
    if ( $testwidth == 2 ) {
      $myreturn .= "}";
    }
    $withcolor = 0;
    @properties = ();
    return $myreturn;
  }
}

sub PrintRow {
  my $self = shift;
  my $vcell = shift;

  my @cell=@{$vcell};
  my $po = $#cell;
  my $cell=''; my $properites='';
  my $query=$self->Query;

  #--
  for (my $i=0; $i<$self->GUIobj->MaxColumn ;$i++) {
#    if (!$self->Reportobj->SetColumnBusy->[$i] ) {
      $cell[$i] = ' \rule{0mm}{0mm} ' ;
#    }
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
  $self->GUIobj->SetColumnBusy(-1);
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

sub PrintGUI {
  my $self = shift;
  $self->{'_longtablecontent'} .= "$latex_footer\n\n";
  
  my $filename=$self->GetParameter(opt_e);
  $filename=$self->Apiis->APIIS_HOME.'/tmp/'.rand() if (! $filename);
  my $dirt=$filename.'.tex';
  my $dirp=$filename.'.pdf';
  open (OUT, ">$dirt");
  print OUT $self->{'_longtablecontent'};
  close (OUT);
  
  if ($self->GetParameter(opt_e)) {
    system( "latexmk -pdf -quiet $dirt >/dev/null" );
    system( "acroread $filename.pdf &" );
  } else {  

    my ($filename1)=($filename=~/.*\/(.*)/);
    ($filename1)=($filename=~/(.*)$filename1/);
    chdir $filename1;
	
    #-- creates pdf from tex as system-command 
    system( "latexmk -pdf -quiet $dirt >/dev/null" );

    #-- send header to browser 
    print $self->Query->header('application/pdf');
    
    #-- print pdf to browser 
    open(IN, "$dirp");
    print <IN>;
    close (IN);
		    
  }  
}

#####
$latex_header = '
\documentclass[10pt,a4paper,DIV14,pdftex]{scrartcl}
\usepackage{german}
\usepackage[utf8]{inputenc}
\usepackage{multicol}
\usepackage{color}
\usepackage{longtable}
\usepackage[pdftex]{graphicx}
%\pagestyle{empty}

\begin{document}
';

$latex_footer = "\n\\end{document}\n";

sub colortrans {
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

sub special_tex {
  my $dat = shift;
  # $cell manipulation for special TeX signs
  map { s/\\/ \$\\backslash\$ /g; s/"/\\"/g; s/&/\\&/g; s/\$/\\\$/g; } $dat;
  map { s/</\$<\$/g; s/>/\$>\$/g;} $dat;
  map { s/%/\\%/g; s/#/\\#/g; s/}/\\}/g; s/{/\\{/g; s/_/\\_/g; s/~/\\~/g; } $dat;
  return( $dat );
}

1;


