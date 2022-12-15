###################################################################################
# $Id: XML.pm,v 1.1 2007-12-14 09:50:22 ulm Exp $
###################################################################################
use Apiis::GUI;

###################################################################################
package Apiis::GUI::XML;
use Apiis;
use Apiis::Init;
@Apiis::GUI::XML::ISA=qw (Apiis::GUI);

###############################################################################
sub PrintHeader {
###############################################################################
  my $self= shift;
  print $self->Query->header('application/x-gzip');
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

    use Compress::Zlib ;

    my $xml;
    #-- Schleife über alle Tiere
    foreach $animal (@$data) {
      my @ani=keys %{$animal};

      #-- Schleife über alle Hasheinträge des Tieres
      my @entitaet;
      foreach $ent (keys %{$animal->{$ani[0]}}) {

	 for ($k=0;$k<=$#{$animal->{$ani[0]}->{$ent}->{'Data'}};$k++) {
           
	   my $ent1;
	   for ($i=0;$i<=$#{$animal->{$ani[0]}->{$ent}->{'Fields'}};$i++) {
             $ent1.="\t\t<$animal->{$ani[0]}->{$ent}->{'Fields'}[$i]>".$animal->{$ani[0]}->{$ent}->{'Data'}[$k]->[$i]."</$animal->{$ani[0]}->{$ent}->{'Fields'}[$i]>\n";
	   }
           push(@entitaet,"\t<$ent>\n".$ent1."\t</$ent>");
	 }

      }
      $xml.='<Animal>'."\n".join("\n",@entitaet)."\n".'</Animal>'."\n";
    }
    print $xml;
}  

###############################################################################
sub PrintGUI {
###############################################################################
  my $self = shift;
}

1;


