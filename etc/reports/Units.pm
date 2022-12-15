use lib $apiis->LOCAL."/lib";
use SQLStatements;

sub GetData {

  my $sql="Set datestyle to 'german'";
  my $sql_ref = $apiis->DataBase->sys_sql($sql);
  
  my $sql=SQLStatements::sql_units();
  my $sql_ref = $apiis->DataBase->sys_sql($sql);
  if ($sql_ref->status == 1) {
    $apiis->status(1);
    $apiis->errors($sql_ref->errors);
    return;
  }

  #-- Schleife über alle Daten, abspeichern im array
  my %daten;my $i=0;my @ar_daten=();
  while( my $q = $sql_ref->handle->fetch ) {
    push(@ar_daten,[@$q]);
  }

  return \@ar_daten, ['ext_unit','ext_id','ext_address', 'adresse'];
}


sub pdf {
  my $self =shift;
  my $data = shift;
  my $structure = shift;

  #use Data::Dumper;
  #print "++++>".Dumper($data)."<++++\n";

  my $latex_header = '
\documentclass[12pt,a4paper,DIV18,pdftex,twocolumn]{scrartcl}
%\usepackage{german}
\usepackage[utf8]{inputenc}
\usepackage{multicol}
\usepackage{color}
\usepackage{longtable}
\usepackage[pdftex]{graphicx}
%\pagestyle{empty}
\usepackage{marvosym} % some symboles
\usepackage{colortbl}
\usepackage{ifthen}

\usepackage{fancyhdr}
\pagestyle{fancy}
\parindent0mm
\sloppy{}

\begin{document}

\definecolor{mg}{gray}{.60}
\definecolor{lgrey}{rgb}{0.9,0.9,0.9}
%%\fancyheadoffset[r]{2.5mm}

';

  $self->{'_longtablecontent'} .= $latex_header;

  # rffr ['ext_unit','ext_id','ext_address', 'adresse']
  my $oldunit = '99';
  my $count = 1;
  foreach my $adr ( @{$data} ) {
    my @line = @{$adr};
    
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @line;
    
    if ( $oldunit ne $line[0] ) {
      $self->{'_longtablecontent'} .= "\\clearpage\n\n " if ( $count > 1 );
      $self->{'_longtablecontent'} .= "\\lhead{\\large \\bf  $line[0] }
           \\chead{\\bf \\raisebox{1ex}{Unitliste} }
           \\rhead{\\today\\\\Seite: \\thepage}
           \\lfoot{\\tiny }
           \\cfoot{}\n\n";
    }
    $count++;
    $oldunit = $line[0];

    $self->{'_longtablecontent'} .=  "\\fbox{\\begin{minipage}[t][\\totalheight][l]{84mm} \%\\parindent-1.2mm
";
    $self->{'_longtablecontent'} .= "{\\bf $line[1] }";
    $self->{'_longtablecontent'} .= "\\hfill $line[2] " if ( $line[2] );
    $self->{'_longtablecontent'} .= "\\newline $line[3] " if ( $line[3] );
    $self->{'_longtablecontent'} .= "\\newline $line[4] " if ( $line[4] );

    $self->{'_longtablecontent'} .= "\n";
    $self->{'_longtablecontent'} .= "\\end{minipage}} %\\vspace{.4mm} \n\n";

  }
}

1;
