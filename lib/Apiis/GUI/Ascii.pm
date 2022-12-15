###################################################################################
# $Id: Ascii.pm,v 1.2 2009-06-22 18:10:37 ulm Exp $
###################################################################################
use Apiis::GUI;

###################################################################################
package Apiis::GUI::Ascii;
use Apiis;
use Apiis::Init;
@Apiis::GUI::Ascii::ISA=qw (Apiis::GUI);

###############################################################################
sub PrintHeader {
###############################################################################
  my $self= shift;
  print $self->Query->header('application/plain');
  return;
}


###############################################################################
sub MakeGUI {
###############################################################################
  my $self=shift;
  my $children=shift;
  my @data;my $data;my $structure;

  #--- GetData from Database over a function/statement 
  ($data,$structure)=$self->GetData;
  return if $apiis->status;

    #-- Schleife über alle Tiere
    foreach my $animal (@$data) {

      print $animal->[0]."\n";
    }

}  

###############################################################################
sub PrintGUI {
###############################################################################
  my $self = shift;
}

1;


