###################################################################################
# $Id: FixPDF.pm,v 1.22 2020/03/30 08:51:40 ulf Exp $
###################################################################################
use Apiis::GUI;

###################################################################################
package Apiis::GUI::FixPDF;
use Apiis;
use Apiis::Init;
@Apiis::GUI::FixPDF::ISA=qw (Apiis::GUI);


###############################################################################
sub MakeGUI {
###############################################################################
  my $self=shift;
  my $children=shift;
  my @data;my $data;my $structure;

  #--- GetData from Database over a function/statement 
  ($data,$structure)=$self->GetData;
  return if $apiis->status;


  #--- execute funktion to create fixpdf
  my $module=$self->GUIobj->{$self->GUIobj->General->[0]}->CreatePDF;
  my ($vfunction)=($module=~/^(.*)\(/);
  my $vgui=$self->GUIobj->path;
  ($vgui)=($vgui=~/\/etc\/(.*)/);
    
  $module=$apiis->APIIS_LOCAL."/etc/$vgui/".$self->GUIobj->basename.".pm";
  eval {
    require $module; #offen: Verzeichnisrechte und öffnen
  };
  if ($@) {
    $apiis->errors(
      Apiis::Errors->new(
       type      => 'CODE',
       severity  => 'ERR',
       from      => 'Apiis::GUI',
       msg_short => "Can't open modul ".$ENV{'APIIS_LOCAL'}."/etc/$vgui/".$self->GUIobj->basename.".pm",
       msg_long =>  "$@"
   ));
   $apiis->status(1);
   return;
  }
  
  # execute loadobject
  no strict "refs";
  $vfunction="Apiis::GUI::$vfunction";
  eval {
    $d = &$vfunction($self,$data,$structure);
  };  
  if ($@) {
    $apiis->errors(
     Apiis::Errors->new(
     type      => 'CODE',
     severity  => 'ERR',
     from      => 'Apiis::GUI',
     msg_short => "Can't execute function $vfunction in module: $module",
     msg_long =>  "$@"
     ));
     $apiis->status(1);
     return;
  } 
}  

sub PrintHeader {
  my $self= shift;
  return;
}

sub PrintGUI {
  my $self = shift;
  my $opt_o=shift;
  my $opt_e=shift;
  my ($dirp,$dirt, $dirl, $dira);
 
  if ( $self->{'_longtablecontent'}=~/\.pdf$/) {
     $dirp=$self->{'_longtablecontent'};
  } else {
    $self->{'_longtablecontent'} .= "$latex_footer\n\n";
    my $filename=$opt_e;
    $filename=$apiis->APIIS_HOME.'/tmp/'.rand() if (! $opt_e);
    $dirt=$filename.'.tex';
    $dirl=$filename.'.log';
    $dira=$filename.'.aux';
    $dirp=$filename.'.pdf';
    open (OUT, ">$dirt");
    print OUT $self->{'_longtablecontent'};
    close (OUT);

    my ($filename1)=($filename=~/.*\/(.*)/);
    
    ($filename1)=($filename=~/(.*)$filename1/);
    chdir $filename1;
    system( "latexmk -pdf -quiet $dirt >/dev/null" );

    if ( $self->GetParameter(opt_k) ) {
      my $dirt_out = $dirt;
      $dirt_out =~ s/\.tex/\.pdf/g;
      system( "pdftops $dirt_out $ENV{'APIIS_HOME'}/tmp/print1.ps" );
      # system( "pdf2ps $dirt_out print1.ps" );
      # system( "acroread -toPostScript < $dirt_out >print1.ps" );
      if ( $self->GetParameter(opt_b) ) {
      system( "psbook $ENV{'APIIS_HOME'}/tmp/print1.ps >$ENV{'APIIS_HOME'}/tmp/print2.ps" )
    } else {
      system( "cp $ENV{'APIIS_HOME'}/tmp/print1.ps $ENV{'APIIS_HOME'}/tmp/print2.ps" )
    }
      # system( "pstops '2:0L@.7(21cm,0)+1L@.7(21cm,14.85cm)' print2.ps >print3.ps" );
      system( "pstops '2:0L@.74(21cm,-9mm)+1L@.74(21cm,14.85cm)' $ENV{'APIIS_HOME'}/tmp/print2.ps >$ENV{'APIIS_HOME'}/tmp/print3.ps" );
      system( "ps2pdf $ENV{'APIIS_HOME'}/tmp/print3.ps $dirt_out" );
    }

  }
  if ($opt_o eq 'con2pdf') {
    if (! $opt_e) { 
      system( "acroread $dirp &" );
    }  
  } elsif ($opt_o eq 'htm2pdf') {
    print $self->Query->header('application/pdf');
    open(IN, "$dirp");
    print <IN>;
    close (IN);
  }  
  #system("rm $dirt $dirl $dira");
}

#####
$latex_header = '
\documentclass[12pt,a4paper,DIV14,pdftex]{scrartcl}
\usepackage{german}
\usepackage[utf8]{inputenc}
\usepackage{multicol}
\usepackage{color}
\usepackage{longtable}
\usepackage[pdftex]{graphicx}
%\pagestyle{empty}
\usepackage{fancyhdr}

\pagestyle{fancy}
\parindent0mm
\sloppy{}

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


