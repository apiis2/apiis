sub GetData {

  #my $sql="Set datestyle to 'german'";
  #my $sql_ref = $apiis->DataBase->sys_sql($sql);
  
  my $sql="select class, db_code, ext_code, short_name, long_name, description, opening_dt, closing_dt
    from codes order by class, ext_code";
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

  return \@ar_daten, ['class','db_code','ext_code','short_name', 'long_name','description','opening_dt','closing_dt'];
}


sub pdf {
  my $self =shift;
  my $data = shift;
  my $structure = shift;

  #use Data::Dumper;
  #print "++++>".Dumper($data)."<++++\n";

  my $latex_header = '
\documentclass[12pt,a4paper,DIV14,pdftex,landscape]{scrartcl}
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


  my $oldunit = '99';
  my $count = 1;
  foreach my $adr ( @{$data} ) {
    my @line = @{$adr};

    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @line;

    if ( $oldunit ne $line[0] ) {
      $self->{'_longtablecontent'} .= "\\end{longtable}\n" if ( $count > 1 );
      $self->{'_longtablecontent'} .= "\\clearpage\n\n " if ( $count > 1 );
      $self->{'_longtablecontent'} .= "\\rhead{\\large \\bf  $line[0] }
           \\chead{\\bf \\raisebox{1ex}{Codesliste} }
           \\lhead{\\today\\\\Seite: \\thepage}
           \\lfoot{\\tiny }
	   \\cfoot{}\n\n";

      $self->{'_longtablecontent'} .= "\\begin{longtable}{\@{}lll>{\\raggedright}p{52mm}>{\\raggedright}p{54mm}ll\@{}}\\hline\n\n";
      $self->{'_longtablecontent'} .= "{\\bf db\\_code} & {\\bf externer code} & {\\bf Kurzname} &{\\bf Langer Name} &{\\bf Beschreibung} & von & bis \\\\  ";
    $self->{'_longtablecontent'} .= " \\hline \\endhead\n";
    }
    $count++;
    $oldunit = $line[0];

    shift @line;
    $line[4] = '{\small ' . $line[4] . '}';
    my $outline = join( ' & ', @line );
    $self->{'_longtablecontent'} .= "$outline \\\\ \n";

    $self->{'_longtablecontent'} .= "\n";
    $self->{'_longtablecontent'} .= "\n";
    $self->{'_longtablecontent'} .= "\n";
    $self->{'_longtablecontent'} .= "\n";
    $self->{'_longtablecontent'} .= "\n";



  }

  $self->{'_longtablecontent'} .= "\\end{longtable}\n";

}

1;
