use lib $apiis->APIIS_LOCAL."/lib";
use SQLStatements;

sub GetData {

  my $sql="Set datestyle to 'german'";
  my $sql_ref = $apiis->DataBase->sys_sql($sql);
  
  my $sql=SQLStatements::sql_adressen();
  my $sql_ref = $apiis->DataBase->sys_sql($sql);
  if ($sql_ref->status == 1) {
    $apiis->status(1);
    $apiis->errors($sql_ref->errors);
    return;
  }

  #-- Schleife über alle Daten, abspeichern im array
  my %daten;my $i=0;my @ar_daten=();
  while( my $q = $sql_ref->handle->fetch ) {
    
    $daten{$q->[0]}=$i;
    my $address={};
    $address->{ext_address}=[$q->[1]];
    my $data=[];
    push(@$data,$q->[2]) if ($q->[2]);
    push(@$data,$q->[3]) if ($q->[3]);
    #push(@$data,$q->[8]) if ($q->[8]);
    #push(@$data,$q->[9]) if ($q->[9]);
    push(@$data,$q->[10]) if ($q->[10]);
    push(@$data,$q->[13]) if ($q->[13]);
    #push(@$data,$q->[14]) if ($q->[14]);
    push(@$data,$q->[15]) if ($q->[15]);
    $address->{anschrift}=[join(', ',@$data)] if ($#{$data}>-1);
    
    my $data=[];
    push(@$data,$q->[4]) if ($q->[4]);
    push(@$data,$q->[5]) if ($q->[5]);
    push(@$data,$q->[6]) if ($q->[6]);
    push(@$data,$q->[7]) if ($q->[7]);
    $address->{nummern}=[join(', ',@$data)] if ($#{$data}>-1);
    
    my $data=[];
    push(@$data,'Tel.: '.$q->[19]) if ($q->[19]);
    push(@$data,'dienstl. :'.$q->[20]) if ($q->[20]);
    push(@$data,'mobil. : '.$q->[21]) if ($q->[21]);
    push(@$data,'Fax: '.$q->[22]) if ($q->[22]);
    push(@$data,'eMail '.$q->[23]) if ($q->[23]);
    push(@$data,'http: '.$q->[24]) if ($q->[24]);
    $address->{Kommunikation}=[join(', ',@$data)] if ($#{$data}>-1);
    
    my $data=[];
    push(@$data,$q->[27]) if ($q->[27]);
    push(@$data,$q->[28]) if ($q->[28]);
    push(@$data,$q->[29]) if ($q->[29]);
    push(@$data,$q->[30]) if ($q->[30]);
    $address->{Bank}=[join(', ',@$data)] if ($#{$data}>-1);
    
    my $data=[];
    push(@$data,$q->[31]) if ($q->[31]);
    push(@$data,$q->[32]) if ($q->[32]);
    push(@$data,$q->[33]) if ($q->[33]);
    push(@$data,$q->[42]) if ($q->[42]);
    $address->{Status}=[join(', ',@$data)] if ($#{$data}>-1);
  
    $address->{Kategorie}=[];
    $ar_daten[$i]=$address;
    $i++;
  }

  my $sql="select distinct a.db_address, b.ext_unit from address a inner join unit b on a.db_address=b.db_address";
  my $sql_ref = $apiis->DataBase->sys_sql($sql);
  if ($sql_ref->status == 1) {
    $apiis->status(1);
    $apiis->errors($sql_ref->errors);
    return;
  }
  while( my $q = $sql_ref->handle->fetch ) {
    push(@{$ar_daten[$daten{$q->[0]}]->{Kategorie}},$q->[1]);
  } 

  return \@ar_daten;
}


sub pdf {
  my $self =shift;
  my $data = shift;
  my $structure = shift;

  #use Data::Dumper;
  #print "++++>".Dumper($data)."<++++\n";

  my $latex_header = '
\documentclass[12pt,a4paper,DIV20,pdftex]{scrartcl}
%\usepackage{ngerman}
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

  $self->{'_longtablecontent'} .= "\\lhead{ }
           \\chead{\\bf \\raisebox{1ex}{Adressliste} }
           \\rhead{\\today\\\\Seite: \\thepage}
           \\lfoot{\\tiny }
           \\cfoot{}\n\n";

  # rffr
  foreach my $adr ( @{$data} ) {
    my @ext_address = @{$adr->{'ext_address'}};
    my @kommunikation =  @{$adr->{'Kommunikation'}};
    my @status =  @{$adr->{'Status'}};
    my @anschrift =  @{$adr->{'anschrift'}};
    my @kategorie =  @{$adr->{'Kategorie'}};
    my @nummern =  @{$adr->{'nummern'}};
    my @bank =  @{$adr->{'Bank'}};
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @anschrift;
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @ext_address;
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @kommunikation;
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @status;
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @kategorie;
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @nummern;
    map { $_ = Apiis::Misc::MaskForLatex( $_ ) } @bank;

    # my $outkat = join( ' \\newline ', @kategorie );
    my $outkat = join( ' ', @kategorie );

    $self->{'_longtablecontent'} .=  "\\fbox{\\begin{minipage}[t][\\totalheight][l]{140mm} \\parindent-1.2mm
";
    $self->{'_longtablecontent'} .=  " \\rule[0mm]{0mm}{0mm}\n";
    $self->{'_longtablecontent'} .= " @anschrift \n" if ( @anschrift );
    $self->{'_longtablecontent'} .= " \\newline @kommunikation  \n" if ( @kommunikation );
    $self->{'_longtablecontent'} .= "  \\newline @bank   \n" if ( @bank );
    $self->{'_longtablecontent'} .= "  \\newline Status: @status   \n" if ( @status );
    $self->{'_longtablecontent'} .= "\\end{minipage}\\hspace{5mm}\n";

    $self->{'_longtablecontent'} .=  "\\begin{minipage}[t]{30mm}";
    $self->{'_longtablecontent'} .=  " \\hfill {\\bf @ext_address }\\newline $outkat \n";

    $self->{'_longtablecontent'} .= "\\end{minipage}} \n\n";
#     $self->{'_longtablecontent'} .=  "\\fbox{\\begin{minipage}{\\textwidth}";
#     $self->{'_longtablecontent'} .=  '
#            \begin{tabular*}{\textwidth}{@{}p{120mm}@{\extracolsep{\fill}}p{30mm}@{}}';
#     $self->{'_longtablecontent'} .=  " \n";
#     $self->{'_longtablecontent'} .= " @anschrift & \\hfill {\\bf @ext_address }\\\\[4mm]  \n";
#     $self->{'_longtablecontent'} .= " @kommunikation &  \\\\  \n" if ( @kommunikation );
#     $self->{'_longtablecontent'} .= " @bank &  \\\\  \n" if ( @bank );
#     $self->{'_longtablecontent'} .= " @Status & $outkat \\\\  \n";
#     $self->{'_longtablecontent'} .= "\\end{tabular*} \n\n \\vspace{2mm}";

#     $self->{'_longtablecontent'} .= "\\end{minipage}} \n\n";
  }
}

1;
