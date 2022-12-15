##############################################################################
# $Id: xfig_lib.pm,v 1.6 2004/02/24 14:31:24 haboe Exp $
# common variables and subroutines for model2fig
##############################################################################
 
=pod

=head1 NAME

xfig_lib.pm - library for model2xfig

=head1 DESCRIPTION

xfig_lib initialized basic variables, sets default values and defines subroutines
for creating the FIG-header, for compounding objects, drawing lines, arrowlines,
boxes and text.

=cut

#### Variables ###############################################################

#### File Header ####
#                        default values
$firstLineComment =       '#FIG 3.2 by model2fig';
$orientation =            'Landscape';
$justification =          'Center';
$units =                  'Metric';
$papersize =              'A4';
$magnification =          100.00;
$multiplePage =           'Single';
$transparentColor =       -2;
$resolution_coordSystem = '1200 2';
$header = getFileHeader();

#### attributes #####
$sizeH = 12;    # fontsize for the head line
$sizeT = 10;    # fontsize for tablenames
$sizeC = 8;     # fontsize for columnnames
$fontH = 18;    # fonttype for head line 18 - Helvetica-Bold
$fontT = 18;    # fonttype for tablenames  18 - Helvetica-Bold
$fontC = 16;    # fonttype for columnnames 16 - Helvetica
$colorH = 0;    # color for head line
$colorT = 1;    # color for tablenames
$colorC = 0;    # color for columnnames
$colorL = 0;    # line color (box type)
$thick = 1;     # line thickness (box type)
$fillc = 7;     # fill-color for box type
$fill = -1;     # -1 = no fill    20 = filled
$depthT = 900;  # depth text
$depthB = 900;  # depth box
$depthL = 899;  # depth line
$depthA = 910;  # depth arrowlines

#### coordinates ####
$x0 = 200;            # position of the first table
$y0 = 500;
$xc = $x0;            # position of the current table
$yc = $y0;
$xi = $sizeC*220;     # table interval
$yi = $sizeC*22;      # column interval
$xw = $sizeC*190;     # box width
$xoffset = 100;       # x-coordinate offset for the line starting point 
$yoffset = $yi/4; # y-coordinate offset for the line starting point

#### Objects ########
%objectClass = (
   circle => 1,
   polyline => 2,
   spline => 3,
   text => 4,
   arc => 5,
   compound => 6
);

#### Subroutines #############################################################
=pod

=head1 SUBROUTINES

=cut

#### getFileHeader #####
=pod

=head2 getFileHeader

getFileHeader creates the FIG-file header.

usage: $header = getFileHeader( [comment] )

   comment: comment to print into the header

   returnvalue: string with header

=cut
sub getFileHeader {
   my $comment = shift;
   if ($comment) {
      $firstLineComment = $comment;
   }
   return ("$firstLineComment\n$orientation\n$justification\n".
           "$units\n$papersize\n$magnification\n$multiplePage\n".
           "$transparentColor\n$resolution_coordSystem\n");
}

#### texttype ##########
=pod

=head2 texttype

creates a F<text> object.

usage: $textobj = texttype( $text, $type,
                            $xpos, $ypos, $depthT )

    text: string
    type: t = title;  c = columnname ; h = head line
    xpos: x-position
    ypos: y-position
  depthT: depth (layer)

 returnvalue: string with text object

=cut
sub texttype {
   my ($text, $type, $xpos, $ypos, $depthT) = @_;

   my $line = '4 0 ';
   $line = $line."$colorT $depthT 0 $fontT $sizeT 0.0000 4 0 0 " if ( $type eq 't');
   $line = $line."$colorC $depthT 0 $fontC $sizeC 0.0000 4 0 0 " if ( $type eq 'c');
   $line = $line."$colorH $depthT 0 $fontH $sizeH 0.0000 4 0 0 " if ( $type eq 'h');
   $line = $line."$xpos $ypos $text\\001\n";

   return $line;
}

#### boxtype ##########
=pod

=head2 boxtype

creates a F<box> object.

usage: $boxobj = boxtype( $x1, $y1 ,$x2 ,$y2 )

   x1,y1: first corner point
   x2,y2: final corner point
   
 returnvalue: string with box object

=cut
sub boxtype {
   my ($x1, $y1, $x2, $y2, $depthB) = @_;

   my $line = "2 2 0 $thick $colorL $fillc $depthB 0 $fill 0.000 0 0 -1 0 0 5\n\t ";
   $line = $line."$x1 $y1 $x2 $y1 $x2 $y2 $x1 $y2 $x1 $y1\n";

   return $line;
}

#### linetype #########
=pod

=head2 linetype

creates a F<line> object.

usage: $lineobj = linetype( $x1, $y1 ,$x2 ,$y2 )

   x1,y1: first point
   x2,y2: final point
   
 returnvalue: string with line object

=cut
sub linetype {
   my ($x1, $y1, $x2, $y2, $depthL) = @_;

   my $line = "2 1 0 $thick $colorL $fillc $depthL 0 $fill 0.000 0 0 -1 0 0 2\n\t ";
   $line .= "$x1 $y1 $x2 $y2\n";

   return $line;
}

#### arrowlinetype #########
=pod

=head2 arrowlinetype

creates a F<arrowline> object with a B<backward> arrow.

usage: $arrowlineobj = arrowlinetype( $x1, $y1 ,$x2 ,$y2 )

   x1,y1: first point
   x2,y2: final point
   
 returnvalue: string with arrowline object

=cut
sub arrowlinetype {
   my ($x1, $y1, $x2, $y2, $depthA) = @_;

   my $line = "2 1 0 $thick $colorL $fillc $depthA 0 $fill 0.000 0 0 -1 0 1 2\n\t ";
   $line .= "1 1 1.00 60.00 120.00\n\t";
   $line .= "$x1 $y1 $x2 $y2\n";

   return $line;
}

#### compoundtype #####
=pod

=head2 compoundtype

creates a F<compound> object.

usage: $compoundobj = compoundtype( $objects,
                                   $upperight_corner_x,
                                   $upperight_corner_y,
                                   $lowerleft_corner_x,
                                   $lowerleft_corner_y )

         objects:  string with xfig objects. Created with
                   texttype,boxtype,linetype and
                   arrowlinetype

         upperight_corner_x, upperight_corner_y,
         lowerleft_corner_x, lowerleft_corner_y
         defines a rectangle so that all objects are
         inside of this region. 

 returnvalue: string with compound object

=cut
sub compoundtype {
   my ($objects, $x0, $y0, $x1, $y1) = @_;

   $x0 -= 10;
   $y0 -= 35;
   $x1 += 10;
   $y1 += 15;

   my $line = "6 $x0 $y0 $x1 $y1\n".$objects."-6\n";

   return $line;
}
1;

__END__

=pod

=head1 SEE ALSO

model2xfig, xfig (www.xfig.org)

=head1 AUTHOR

Hartmut Börner (haboe@tzv.fal.de)

=cut
