##############################################################################
# $Id: NavigationBar.pm,v 1.2 2005-11-18 15:55:09 ulm Exp $
# Handling Buttons
##############################################################################
package Apiis::Form::HTML::NavigationBar;
$VERSION = '$Revision $';

use warnings;
use strict;
use Data::Dumper;
use base 'Apiis::Form::HTML::NavigationBar';

=head1 NAME

Apiis::Form::HTML::NavigationBar

=head1 DESCRIPTION

create a navigationbar.

=head1 METHODS

=head2 _navigationbar

 first part: writes JavaScript-code to load icons and two javascript-functions to make a rollover effect.
 second part: create a table of html which contain html img-tags using this javascript functions.

 The navigationbar is a separate table and can use in combination with different forms. 
 
=cut


sub _navigationbar {
   my ( $self ) = shift;
   my $query=$self->{_query};

my $script='<SCRIPT LANGUAGE="JavaScript">
  <!--

  if (document.images) {
    var do_first = new Image();
    do_first.src = "/icons/do_first.png";
    var do_first2 = new Image();
    do_first2.src = "/icons/do_first2.png";
    
    var do_prev = new Image();
    do_prev.src = "/icons/do_prev.png";
    var do_prev2 = new Image();
    do_prev2.src = "/icons/do_prev2.png";
    
    var do_next = new Image();
    do_next.src = "/icons/do_next.png";
    var do_next2 = new Image();
    do_next2.src = "/icons/do_next2.png";
    
    var do_last = new Image();
    do_last.src = "/icons/do_last.png";
    var do_last2 = new Image();
    do_last2.src = "/icons/do_last2.png";
    
    var do_new   = new Image();
    do_new.src   = "/icons/do_new.png";
    var do_new2  = new Image();
    do_new2.src  = "/icons/do_new2.png";
}
function act(imgName) {
  if (document.images) document.images[imgName].src = eval(imgName + "2.src");
}
function inact(imgName) {
  if (document.images) document.images[imgName].src = eval(imgName + ".src");
}
// -->
</SCRIPT>';

  print $script;

   my $table='<table style="background:#eeeeee" cellpadding="0" cellspacing="0"><TR>
      <td style="border-top:solid black 2px;padding:2px" >
         <img name="do_first" src="/icons/do_first.png" alt="erster Datensatz"  
	            onClick="alert('. "'Springt zum ersten Datensatz'" .')" 
	            onMouseOver="act('."'do_first')".'" onMouseOut="inact(' ."'do_first')". '">
         <img name="do_prev" src="/icons/do_prev.png" alt="vorheriger Datensatz" 
	            onClick="alert('. "'Spring zum vorherigen Datensatz'" .')" 
	            onMouseOver="act('."'do_prev')".'" onMouseOut="inact(' ."'do_prev')". '">
         <input style="font-size:12px; vertical-align:top; text-align:right" 
	        id="_nav_r" name="_nav_r" type"textfield" maxlength="5" size="5"></a> 
         <img name="do_next" src="/icons/do_next.png" alt="nächster Datensatz"  
	            onClick="alert('. "'Springt zum nächsten Datensatz'" .')" 
	            onMouseOver="act('."'do_next')".'" onMouseOut="inact(' ."'do_next')". '">
         <img name="do_last" src="/icons/do_last.png" alt="letzter Datensatz"  
	            onClick="alert('. "'Springt zum letzten Datensatz'" .')" 
	            onMouseOver="act('."'do_last')".'" onMouseOut="inact(' ."'do_last')". '">
         <img name="do_new" src="/icons/do_new.png" alt="neuer Datensatz"  
	            onClick="alert('. "'Springt zum neuen Datensatz'" .')" 
	            onMouseOver="act('."'do_new')".'" onMouseOut="inact(' ."'do_new')". '"> von 0
      </td>
      </TR></table>';
   return $table;
}				

##############################################################################
1;
