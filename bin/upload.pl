#!/usr/bin/perl -w
#
use strict;
use CGI; # Modul fuer CGI-Programme
#
my $cgi = new CGI; # neues Objekt erstellen
#
# Content-type fuer die Ausgabe
print $cgi->header(-type => 'text/html');

# die datei-daten holen
my $file = $cgi->param("myfile");

# dateinamen erstellen und die datei auf dem server speichern
my $fname = 'file_'.$$.'_'.$ENV{REMOTE_ADDR}.'_'.time;
open DAT,'>/tmp/'.$fname or die 'Error processing file: ',$!;

# Dateien in den Binaer-Modus schalten
binmode $file;
binmode DAT;

my $data;
while(read $file,$data,1024) {
  print DAT $data;
}
close DAT;

print <<"HTML";
  <html>
  <head>
  <title>Fileupload</title>
  </head>
  <body bgcolor="#FFFFFF">
  <h1>Die Datei $file wurde erfolgreich hochgeladen.</h1>

  <p>
  Die Datei $file wurde erfolgreich auf dem Server
     gespeichert.
       </p>
  </body>
</html>
HTML

