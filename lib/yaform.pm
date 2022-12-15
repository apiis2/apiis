##############################################################################
# $Id: yaform.pm,v 1.136 2005/10/11 08:59:24 haboe Exp $
# Yet Another Form
##############################################################################
#use diagnostics;

$^W = 0; 

##############################################################################
# usage: TkYAF(formfile,[value1, value2, ...]
#                  values will be written into the field-variables 
sub TkYAF {

   my $form_file = shift;
   my @param = @_;

   # debug level for DBIx::Recordset
   $_debug_level = $opt_D if($opt_D);

   print "FORMFILE:$form_file\n" if($opt_d);
   return "cannot open $form_file" if(!form_file and ! -f $form_file and ! %yaffd);

   use Data::Dumper;
   use Tk;
   use Tk::Dialog;
   use Tk::BrowseEntry;
   use Tk::DateEntry;
   use Tk::Pane;
   use File::Basename;
   use encoding 'utf8';

   $| = 1; # unbuffer output

   # requirements
   Tk->require_version('800.015');
#   Tk::Pane->require_version('3.002');
   Tk::DateEntry->require_version('1.3');
   Tk::BrowseEntry->require_version('3.022');

   my ($model,$form,$title,$tfont,$sfont,$lfont,$height,$width,$Ftype);
   my ($formbg, $formfg, $var);
   my $maske if(! %yaffd);
   
   if(! %yaffd) {
      $form = initFORM($form_file, \$model);
   } else { 
      $maske->destroy if(Exists($maske));
      $form = \%yaffd;
      return if(!$$form{GENERAL}{HEIGHT} or !$$form{GENERAL}{WIDTH});
   }

   ##################  defined FONTS  ########################################
   $title  = $$form{GENERAL}{TITLE}?$$form{GENERAL}{TITLE}:undef;
   $tfont  = $$form{GENERAL}{TITLEFONT};
   $sfont  = $$form{GENERAL}{NORMALFONT};
   if ($$form{GENERAL}{LABELFONT}) {
      $lfont  = $$form{GENERAL}{LABELFONT};
   } else {
      $lfont  = $$form{GENERAL}{NORMALFONT};
   }   

   $height = $$form{GENERAL}{HEIGHT};
   $width  = $$form{GENERAL}{WIDTH};
   
   $formfg = $$form{GENERAL}{FGCOLOR} if($$form{GENERAL}{FGCOLOR});
   $formbg = $$form{GENERAL}{BGCOLOR} if($$form{GENERAL}{BGCOLOR});

   # Form type
   $Ftype = 1 if(defined $$form{GENERAL}{FORMTYPE});

   # ACTION 
   foreach $var (sort keys %$form) {
      next if $var eq 'GENERAL';
      my @array = split(/,/, $$form{$var}{ACTION});
      $$form{$var}{ACTION} = \@array if(! %yaffd);
   }

   ###############################################
   $maske = MainWindow->new(-relief => 'groove',
			    -borderwidth => '2');
   $maske -> configure(-title=>$title?$title:
                               ($form_file?basename($form_file):$programname)) if(!$opt_x);
   $maske -> configure(-height=>$height, -width=>$width);
   $maske -> configure(-bg=>$formbg) if($formbg);

   ### icon on the title bar
   # my $image = "$APIIS_HOME/lib/einBild.gif";  # 32x32 GIF or BMP
   # my $icon = $maske->Photo(-file => $image);
   # $maske->iconimage($icon);

   # The toplevel should be not resizeable?
   # $maske->resizable(0,0);

   $$form{GENERAL}{TOPLEVEL} = $maske; # so, we have always access to the toplevel

   # screen dimension
   $screenheight = $maske->screenheight();
   $screenwidth = $maske->screenwidth();
   print "screen width x height:$screenwidth x $screenheight\n" if($opt_d);

   #### where to place the Form
   # value of -P parameter
   #   .-------.
   #   |1  2  3|
   #   |   0   |
   #   |4  5  6|
   #   '-------'
   #
   # without -P : Form is placed on position 0
   #
   # geometry
   my ($dx,$dy); # Verschiebung
   my ($cx,$cy); # Korrektur wg. Fensterdekoration
   if($$form{GENERAL}{STARTUP} =~ /overrideredirect\(1\)/) {
      $cx = 4;
      $cy = 130;
   } else {
      $cx = 10;
      $cy = 104;
   }
   if(!$opt_P) {            # center the toplevel window (Hi Lina!)
      $dx = int(($screenwidth - $width) / 2) - $cx;
      $dy = int( ($screenheight - $height - $cy) / 2);
   } elsif($opt_P == 1) {   # top left
      $dx = 0;
      $dy = 0;
   } elsif($opt_P == 2) {   # top center
      $dx = int(($screenwidth - $width - $cx) / 2);
      $dy = 0;
   } elsif($opt_P == 3) {   # top right
      $dx = int($screenwidth - $width - $cx);
      $dy = 0;
   } elsif($opt_P == 4) {   # bottom left
      $dx = 0;
      $dy = int($screenwidth - $height - 2*$cy);
   } elsif($opt_P == 5) {   # bottom center
      $dx = int(($screenwidth - $width) / 2) - $cx;
      $dy = int($screenwidth - $height - 2*$cy);
   } elsif($opt_P == 6) {   # bottom right
      $dx = int($screenwidth - $width - $cx);
      $dy = int($screenwidth - $height - 2*$cy);
   }
   $maske->geometry("+$dx+$dy");
   print "dx:$dx  dy:$dy\n" if($opt_d);  

   ######################### FONTS ##########################################
   ## either we can use system fonts or create new font with the
   ## fontCreate method.
   ##
   ## system fonts:
   ## X Windows System: you can get a list of all fonts by running
   ##                   the command:  xlsfonts
   ##
   ## MS Windows 9x   : all installed fonts in Control Panel->Fonts
   ##                   i.e. Arial 12 normal
   ##                        Verdana 24 bold
   ##
   ## create new font:
   ## family,size,weight,slant,underline,overstrike
   ##
   ## family:     courier, times or helvetica
   ##
   ## size  :     positiv value : the font will be sized in points
   ##             negative value: the font will be sized in pixel
   ##
   ## weight:     normal | bold
   ##
   ## slant :     roman  | italic
   ##
   ## underline:  0 | 1
   ##
   ## overstrike: 0 | 1
   ##
   ## examples:
   ##   NORMALFONT=helvetica,10,normal,roman,0,0
   ##   LABELFONT=helvetica,12,bold,roman,0,0
   ##

   # split $tfont if it's in 'create new font' format
   if(!$tfont or index($tfont,',') ne -1) {
      my($fam,$size,$weight,$slant,$un,$ov) = split(',',$tfont);
      $fam = 'helvetica' if(!$fam);
      $size = 16 if(!$size);
      $weight = 'bold' if(!$weight);
      $slant = 'roman' if(!$slant);
      $un = 0 if(!$un);
      $ov = 0 if(!$ov);
      print "$fam,$size,$weight,$slant,$un,$ov\n" if($opt_d);
      $tfont = $maske->fontCreate(-family=>$fam,
                                -size=>$size,
				-weight=>$weight,
				-slant=>$slant,
			        -underline=>$un,
				-overstrike=>$ov);
   }

   # split $sfont if it's in 'create new font' format
   if(!$sfont or index($sfont,',') ne -1) {
      my($fam,$size,$weight,$slant,$un,$ov) = split(',',$sfont);
      $fam = 'helvetica' if(!$fam);
      $size = 10 if(!$size);
      $weight = 'normal' if(!$weight);
      $slant = 'roman' if(!$slant);
      $un = 0 if(!$un);
      $ov = 0 if(!$ov);
      print "$fam,$size,$weight,$slant,$un,$ov\n" if($opt_d);
      $sfont = $maske->fontCreate(-family=>$fam,
                                -size=>$size,
				-weight=>$weight,
				-slant=>$slant,
			        -underline=>$un,
				-overstrike=>$ov);
   }

   # split $lfont if it's in 'create new font' format
   if(!$lfont or index($lfont,',') ne -1) {
      my($fam,$size,$weight,$slant,$un,$ov) = split(',',$lfont);
      $fam = 'helvetica' if(!$fam);
      $size = 10 if(!$size);
      $weight = 'bold' if(!$weight);
      $slant = 'roman' if(!$slant);
      $un = 0 if(!$un);
      $ov = 0 if(!$ov);
      print "$fam,$size,$weight,$slant,$un,$ov\n" if($opt_d);
      $lfont = $maske->fontCreate(-family=>$fam,
                                -size=>$size,
				-weight=>$weight,
				-slant=>$slant,
			        -underline=>$un,
				-overstrike=>$ov);
   }

   print "TITLEFONT:$tfont\n" if($opt_d);
   print "NORMALFONT:$sfont\n" if($opt_d);
   print "LABELFONT:$lfont\n" if($opt_d);

   #default font for Entry widgets
   if ($sfont) {
      $maske -> optionAdd('*font'=>$sfont); 
   } else {
      $maske -> optionAdd('*font'=>$lfont);
   }

   # title optional: no title - no title-frame
   my $tframe;
   if($title) {
      my $tframe = $maske->Frame(-relief=>'groove',-borderwidth=>4,
			)->pack(-anchor=>'n',-fill => 'x',-expand=>1);
      $tframe->configure(-foreground=>$formfg) if($formfg);
      $tframe->configure(-background=>$formbg) if($formbg);

      my $titlelabel = $tframe-> Label(-text=>$title,
				       -font=>$tfont
			              )->pack(-anchor=>'center');
      $titlelabel->configure(-background=>$formbg) if($formbg);
      $titlelabel->configure(-foreground=>$formfg) if($formfg);
      
      $$form{'GENERAL'}{WIDGET} = $tframe; # for balloon and other
   }

   ############ Frame mit allen Datenfeldern ######

   # height and width of the frame depends on 
   #      defined HEIGHT and WIDTH value in the form file,
   #      and screen resolution
   my $h = ($height < $screenheight-165) ? $height : $screenheight-165;
   my $w = ($width < $screenwidth-40) ? $width : $screenwidth-40;


   my $pane = $maske->Scrolled(Pane, Name => 'form',
			  -scrollbars => 'osoe',
			  -sticky => 'nswe',
			  -height=>$h,
			  -width=>$w,
			  )->pack(-fill=>'both',-expand=>1);
   my $frame = $pane -> Frame(-relief=>'sunken',-borderwidth=>2,
			      -height=>$height,
			      #-height=>$height-20,
			      -width=>$width-8
		     ) ->pack(-side=>'top',-fill=>'both',-expand=>1);
   $frame->configure(-foreground=>$formfg) if($formfg);
   $frame->configure(-background=>$formbg) if($formbg);
   
   $$form{GENERAL}{FRAME} = $frame;
   ${$frame}{SECTION} = 'GENERAL';  # needed in sub motion
   ${$frame}{FORM} = $form;  # needed in sub motion
   $frame->Tk::bind("<Shift-Control-Button-1>",\&move);
   $frame->Tk::bind("<Shift-Control-Button1-Motion>",\&motion);
   $frame->Tk::bind("<Shift-Control-ButtonRelease>",\&recurs);
   $frame->Tk::bind("<Visibility>",[\&startup,$form,$frame]);

   my $focus = 1;
   my $vfFocus = 1;
   my $i = 0;
   my $curX = 0;
   my $curY = 0;
   my $maxRecord = 100; # test
   my $field;
   my $date_format = $apiis->date_format;

   foreach $var (sort keys %$form) {

      next if $var eq 'GENERAL';
      my $type = $$form{$var}{TYPE};

      if($type =~ /^[EDBLCAITMPNUROH]/) { 
	 
	 $$form{$var}{XLOCATION}=$$form{$var}{XLOCATION}?
	          $$form{$var}{XLOCATION}:0;
	 $$form{$var}{YLOCATION}=$$form{$var}{YLOCATION}?
	          $$form{$var}{YLOCATION}:0;

	 # coordinates depends on absolute or relative indicated values
         $curX = xcoord($form,$var,$curX);# set x-coordinate current field
         $curY = ycoord($form,$var,$curY);# set y-coordinate current field

         my $bg; # field background color
         my $fg; # field foreground color
 
         if(! defined $$form{$var}{BGCOLOR}) {
              $bg = ($$form{$var}{TYPE} =~ /^[EBLCNH]/) ? 'gray95' : '#c0c0ca';
         } else {
              $bg = $$form{$var}{BGCOLOR};
         }
         if(! defined $$form{$var}{FGCOLOR}) {
              $fg = 'black';
         } else {
              $fg = $$form{$var}{FGCOLOR};
         }
	 
	 ### Canvas-widget with a Background Image TYPE=I
	 # or a frame with border
         if($$form{$var}{TYPE} =~ /^I/) {

	    my $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:0;
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'flat';
	    my $height = $$form{$var}{HEIGHT}?$$form{$var}{HEIGHT}:50;
	    my $width = $$form{$var}{WIDTH}?$$form{$var}{WIDTH}:50;
	    my $file = eval qq{qq{$$form{$var}{FILE}}};

	    $file = $apiis->APIIS_LOCAL ."/".$file if($file and ! -r $file); 
	    
	    my $picture = $frame->Photo(-file=>$file,
		                        -height=>0,-width=>0);
	    my $canvas = $frame->Canvas(-background=>$bg,
		                        -highlightbackground=>$bg,
		                        -borderwidth=>$border,
		                        -relief=>$relief,
		                        -height=>$height,
					-width=>$width
					)->place('-x'=>$curX-9,'-y'=>$curY+8);
	    my $bw = $canvas->createImage(0,0,-image=>$picture,
		                              -anchor=>"nw");
            $field = $canvas;

            # add the key of this field to the widget hash
            ${$canvas}{FIELD} = $$form{$var};  # needed in sub motion
            ${$canvas}{SECTION} = $var;  # needed in sub motion
            ${$canvas}{FORM} = $form;  # needed in sub motion
	    $$form{$var}{WIDGET} = $field;

            $canvas->Tk::bind("<Shift-Control-Button-1>",\&move);
            $canvas->Tk::bind("<Shift-Control-Button1-Motion>",\&motion);
            $canvas->Tk::bind("<Shift-Control-ButtonRelease>",\&recurs);
            $canvas->Tk::bind("<FocusIn>", [\&focusIn,$form,$field]);
            $canvas->Tk::bind("<FocusOut>", [\&focusOut,$form,$field]);

         }

	 ### Label widget
	 if($$form{$var}{LABEL}) {

	    # each Label-widget can have his own font
	    #  this is hidden for the normal user
	    my $mylfont = $$form{$var}{FONT}?$$form{$var}{FONT}:$lfont;

	    my $label = $frame->Label(-textvariable=>\$$form{$var}{LABEL},
					-font=>$mylfont, -justify=>'left')
			       ->place("-x"=>$curX,
				       "-y"=>$curY)
			       if($$form{$var}{LABEL});
	    $label->configure(-foreground=>$formfg) if($formfg);
	    $label->configure(-foreground=>$fg) if($$form{$var}{TYPE} =~ /^[AI]/);
	    $label->configure(-background=>$formbg) if($formbg);

	    # add key of this field to the widget hash
	    ${$label}{FIELD} = $$form{$var};
	    ${$label}{SECTION} = $var;
	    ${$label}{FORM} = $form;
	    $$form{$var}{LABELWIDGET} = $label;

	    $label->bind("<Shift-Control-Button-1>",\&move);
	    $label->bind("<Shift-Control-Button1-Motion>",\&motion);
            $label->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $label->bind("<FocusIn>", [\&focusIn,$form,$field]);
            $label->bind("<FocusOut>", [\&focusOut,$form,$field]);

            $field = $label;  # will be overwritten except for TYPE=A

	 }

	 my $state = ($$form{$var}{TYPE} =~ /^E/) ? 'normal' : 'disabled';

         ###  Entry widget
         if($$form{$var}{TYPE} =~ /^[ED]/) {

	    $$form{$var}{FIELDLENGTH} = $$form{$var}{FIELDLENGTH}?
	          $$form{$var}{FIELDLENGTH}:20;

            $field = $frame->Entry(-textvariable=>\$$form{$var}{DATA},
                                     -width=>$$form{$var}{FIELDLENGTH},
                                     -background => $bg,
				      -foreground => $fg,
				     # -show=>'*',
                                     -state => $state)
                            ->place("-x"=>$curX,
                                    "-y"=>$curY+20);

	    # password field?
	    # PASSWD=* or any ASCII character that is displayed
            #          instead of the typed character 
	    my $passwd = $$form{$var}{PASSWD}?$$form{$var}{PASSWD}:undef;
            $field->configure(-show=>$passwd) if($passwd);

            # add key of this field to the widget hash
            ${$field}{FIELD} = $$form{$var};
            ${$field}{SECTION} = $var;
            ${$field}{FORM} = $form;

            $field->bind("<Shift-Control-Button-1>",\&move);
            $field->bind("<Shift-Control-Button1-Motion>",\&motion);
            $field->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $field->bind("<FocusIn>", [\&focusIn,$form,$field]);
            $field->bind("<FocusOut>", [\&focusOut,$form,$field]);

         }

         ### BrowseEntry widget
	 ###  TYPE B: browseable entry field  (data comes from database)
	 ###       N: same like B but no query  
	 ###       L  List field  (data comes from 'List'-checkrule)
         elsif($$form{$var}{TYPE} =~ /^[BNL]/) {
           my (@choises, @bfld, @en, @cn);

           $bframe[$i] = $frame->Frame(-relief=>'groove', -borderwidth=>0)
                            ->place("-x"=>$curX-1,
                                  "-y"=>$curY+20);

           my $lscmd =($$form{$var}{TYPE} =~ /^[BN]/)?\&browseDB:\&browseList;
           $bfld[$i] = $bframe[$i]->BrowseEntry(-variable=>\$$form{$var}{DATA},
                              -width=>$$form{$var}{FIELDLENGTH},
                              -choices=>\@choises,
                              -listcmd=>$lscmd,
                              -colorstate=>'normal',
              ) # -bg=>$bg) # die Farbe geht über das Eingabefeld hinaus :-(
                              ->pack();
           $bfld[$i]->configure(-background=>$formbg) if($formbg);

	   $field = $bfld[$i];

           # add key of this field to the widget hash
           $bframe[$i]{FIELD} = $$form{$var};  # needed in sub motion
           $bframe[$i]{SECTION} = $var;  # needed in sub motion
           $bframe[$i]{FORM} = $form;  # needed in sub motion
           $bfld[$i]{FIELD} = $$form{$var};

           # set background color -- only for the Entry!
           my $labentry = $bfld[$i]->Subwidget('entry'); # LabEntry(BrowseEntry)
           $en[$i] = $labentry->Subwidget('entry'); # Entry(LabEntry)
           $en[$i]->configure(-bg=>$bg,-fg=>$fg); # set back/foreground
           $cn[$i] = $bfld[$i]->Subwidget('slistbox'); # 
           $cn[$i]->configure(-bg=>$bg); # set background for pop up list

	   #$$form{$var}{WIDGET} = $bframe[$i];

           my $en = $cn[$i]->Subwidget('xscrollbar');
           $en->configure(-bg=>$bg,
                          -troughcolor=>$bg,
                          -activebackground=>$bg) if($en);
           $en = $cn[$i]->Subwidget('yscrollbar');
           $en->configure(-bg=>$bg,
                          -troughcolor=>$bg,
                          -activebackground=>$bg) if($en);
           $en = $cn[$i]->Subwidget('corner');
           $en->configure(-bg=>$bg) if($en);

	   ## LabEntry's label background makes urgly Fields
	   ## we don't need a LabEntry label - so destroy it ##
           $en = $labentry->Subwidget('label');
	   $en->destroy() if($en);
	   ####


           $bfld[$i]->bind("<Shift-Control-Button-1>",\&move);
           $bfld[$i]->bind("<Shift-Control-Button1-Motion>",\&motion);
           $bfld[$i]->bind("<Shift-Control-ButtonRelease>",\&recurs);
           $bfld[$i]->bind("<FocusIn>", [\&focusIn,$form,$field]);
           $bfld[$i]->bind("<FocusOut>", [\&focusOut,$form,$field]);
         }

         ### DateEntry widget
         elsif($$form{$var}{TYPE} =~ /^C/) {
            my (@cframe, @cfld);
            my $calIcon=$maske->Pixmap(-file=>"$APIIS_HOME/lib/images/calendar.xpm");

            $cframe[$i] = $frame->Frame(-relief=>'groove', -borderwidth=>0)
                            ->place("-x"=>$curX,
                                  "-y"=>$curY+19);

	    $^W = 0; # switch off DateEntry´s warnings 
            $cfld[$i]=$cframe[$i]->DateEntry(-weekstart=>1,
                            -textvariable=>\$$form{$var}{DATA},
                            -arrowimage=>$calIcon,
			    )->pack;
            $cfld[$i]->configure(-background=>$formbg) if($formbg);
	    
	    # Date Format specified in $APIIS_HOME/apiisrc
	    #if($date_format eq 'US') {
	    #   print "# debug use DATE FORMAT MM-DD-YYYY (US) for $var\n"
	    #                                                        if($opt_d);
	    #   $cfld[$i]->configure(-parsecmd=>
	    #                 sub {  # dateformat: MM-DD-YYYY
            #                    my ($m,$d,$y) = ($_[0] =~ /(\d*)-(\d*)-(\d*)/);
            #                    return ($y,$m,$d);
	#	             });
        #       $cfld[$i]->configure(-formatcmd=>
	#                     sub { # dateformat: MM-DD-YYYY
        #                        sprintf ("%02d-%02d-%4d",$_[1],$_[2],$_[0]);
	#		     });
	#    } 
	    if($apiis->date_order) {
	       print "date_order for $var: ",$apiis->date_order,"\n" if($opt_d);
	       $cfld[$i]->configure(-parsecmd=>
	                     sub {  # dateformat: DD-MM-YYYY
			        my $de = shift;
                                # my ($d,$m,$y) = ($_[0] =~ /(\d*)-(\d*)-(\d*)/);
			        # print "parsecmd:$de\n";
                                my ($y,$m,$d) = $apiis->extdate2iso($de);
                                return ($y,$m,$d);
			     });
               $cfld[$i]->configure(-formatcmd=>
	                     sub { # dateformat: MM-DD-YYYY
                                # sprintf ("%02d-%02d-%4d",$_[2],$_[1],$_[0]);
                                my $s = sprintf ("%04d-%02d-%02d",$_[0],$_[1],$_[2]);
				# print "formatcmd:$s";
				my $e = $apiis->iso2extdate($s);
				# print " => $e\n";
				return $e;
			     });
	    } else {
	       print "# debug use default DATE FORMAT MM/DD/YYYY for $var\n"
	                                                            if($opt_d);
	    }
	    
	    # Width of the Entry subwidget, default is 10
            $cfld[$i]->configure(-width=>$$form{$var}{FIELDLENGTH})
	                              if($$form{$var}{FIELDLENGTH});

	    # colors for the drop down calendar
            $cfld[$i]->configure(-boxbackground=>$bg) if($bg);
            $cfld[$i]->configure(-buttonbackground=>$bg) if($bg);
            $cfld[$i]->configure(-todaybackground=>$formbg) if($formbg);

	    # the locale's abbreviated weekday name
	    use POSIX qw/strftime/;
	    my @daynames=();
            foreach (0..6) {
               push @daynames,strftime("%a",0,0,0,1,1,1,$_);
            }
            $cfld[$i]->configure(-daynames=>\@daynames) if(@daynames);

	    $^W = 1; # switch on warnings again

	    $field = $cfld[$i];

            # add the key of this field to the widget hash
            $cframe[$i]{FIELD} = $$form{$var};  # needed in sub motion
            $cframe[$i]{SECTION} = $var;  # needed in sub motion
            $cframe[$i]{FORM} = $form;  # needed in sub motion
            $cfld[$i]{FIELD} = $$form{$var};
	    $$form{$var}{WIDGET} = $cframe[$i];

            # set background color -- only for the Entry!
            $en[$i] = $cfld[$i]->Subwidget('entry'); # Entry(DateEntry)
            $en[$i]->configure(-bg=>$bg,-fg=>$fg); # set back/foreground
 
            $cfld[$i]->bind("<Shift-Control-Button-1>",\&move);
            $cfld[$i]->bind("<Shift-Control-Button1-Motion>",\&motion);
            $cfld[$i]->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $cfld[$i]->bind("<FocusIn>", [\&focusIn,$form,$field]);
            $cfld[$i]->bind("<FocusOut>", [\&focusOut,$form,$field]);

         }

	 ### Text-widget TYPE=T
         if($$form{$var}{TYPE} =~ /^T/) {
	    
	    my $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:2;
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'sunken';
	    my $wrap = $$form{$var}{WRAP}?$$form{$var}{WRAP}:'none';
	    my $height = $$form{$var}{HEIGHT}?$$form{$var}{HEIGHT}:2;
	    my $width = $$form{$var}{WIDTH}?$$form{$var}{WIDTH}:20;
	    my $scroll = $$form{$var}{SCROLLBAR}?$$form{$var}{SCROLLBAR}:'oe';
	    
	    my $text = $frame->Scrolled(Text,
		                    -height=>$height,
		                    -width=>$width,
				    -wrap=>$wrap,
				    -background=>$bg,
				    -foreground=>$fg,
				    -border=>$border,
				    -relief=>$relief,
				    -scrollbars=>$scroll,
				    -font=>$sfont
				    )
			          ->place("-x"=>$curX,
				          "-y"=>$curY+20);
	                   
	    if( $$form{$var}{DATA}) {
	       $text->insert('1.0',$$form{$var}{DATA});
	    }

	    $field = $text;

            # set background color for the scollbars and corner
            if($formbg) {
               my $en = $text->Subwidget('xscrollbar');
               $en->configure(-bg=>$formbg,
                              -troughcolor=>$formbg,
                              -activebackground=>$formbg) if($en);
               $en = $text->Subwidget('yscrollbar');
               $en->configure(-bg=>$formbg,
                              -troughcolor=>$formbg,
                              -activebackground=>$formbg) if($en);
               $en = $text->Subwidget('corner');
               $en->configure(-bg=>$formbg) if($en);
            }

            # add the key of this field to the widget hash
            ${$text}{FIELD} = $$form{$var};  # needed in sub motion
            ${$text}{SECTION} = $var;  # needed in sub motion
            ${$text}{FORM} = $form;  # needed in sub motion
            ${$text}{FIELD} = $$form{$var};
	    $$form{$var}{WIDGET} = $field;

            $text->bind("<Shift-Control-Button-1>",\&move);
            $text->bind("<Shift-Control-Button1-Motion>",\&motion);
            $text->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $text->bind("<FocusIn>", [\&focusIn,$form,$text]);
            $text->bind("<FocusOut>", [\&focusOut,$form,$text]);
            $text->bind("<Control-Return>", 'focusNext');
            $text->bind("<KP_Enter>",'focusNext');

	 }

	 ### Listbox-widget TYPE=M
         if($$form{$var}{TYPE} =~ /^M/) {
	    
	    my $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:2;
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'sunken';
	    my $height = $$form{$var}{HEIGHT}?$$form{$var}{HEIGHT}:2;
	    my $width = $$form{$var}{WIDTH}?$$form{$var}{WIDTH}:20;
	    my $scroll = $$form{$var}{SCROLLBAR}?$$form{$var}{SCROLLBAR}:'oe';
	    my $mode = $$form{$var}{MODE}?$$form{$var}{MODE}:'extended';
	    
	    my $listbox = $frame->Scrolled(Listbox,
				    -takefocus=>1,
				    -exportselection=>0,
		                    -height=>$height,
		                    -width=>$width,
				    -background=>$bg,
				    -foreground=>$fg,
				    -borderwidth=>$border,
				    -relief=>$relief,
				    -scrollbars=>$scroll,
				    -font=>$sfont,
				    -selectmode=>$mode
				    )
			          ->place("-x"=>$curX,
				          "-y"=>$curY+20);
	                   
	    if( $$form{$var}{DATA}) {
	       $listbox->insert('end',split(' ',$$form{$var}{DATA}));
               $$form{$var}{DATA}=undef;
	    }


	    $field = $listbox;

            # set background color for the scollbars and corner
            if($formbg) {
               my $en = $field->Subwidget('xscrollbar');
               $en->configure(-bg=>$formbg,
                              -troughcolor=>$formbg,
                              -activebackground=>$formbg) if($en);
               $en = $field->Subwidget('yscrollbar');
               $en->configure(-bg=>$formbg,
                              -troughcolor=>$formbg,
                              -activebackground=>$formbg) if($en);
               $en = $field->Subwidget('corner');
               $en->configure(-bg=>$formbg) if($en);
            }

            # add the key of this field to the widget hash
            ${$listbox}{FIELD} = $$form{$var};  # needed in sub motion
            ${$listbox}{SECTION} = $var;  # needed in sub motion
            ${$listbox}{FORM} = $form;  # needed in sub motion
	    $$form{$var}{WIDGET} = $field;

            $listbox->bind("<Shift-Control-Button-1>",\&move);
            $listbox->bind("<Shift-Control-Button1-Motion>",\&motion);
            $listbox->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $listbox->bind("<FocusIn>", [\&focusIn,$form,$listbox]);
            $listbox->bind("<FocusOut>", [\&focusOut,$form,$listbox]);

            $listbox->bind("<Leave>", 'focusNext');
            $listbox->bind("<Button-1>", 'focus');
            $listbox->bind("<Tab>", 'focusNext');
            $listbox->bind("<KP_Enter>",'focusNext');


	    &browseDB($listbox);
	 }


	 ### pushButton-widget TYPE=P
         if($$form{$var}{TYPE} =~ /^P/) {
	    
	    my $text = $$form{$var}{TEXT}?$$form{$var}{TEXT}:$var;
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'raised';
	    my $height = $$form{$var}{HEIGHT}?$$form{$var}{HEIGHT}:1;
	    my $width = $$form{$var}{WIDTH}?$$form{$var}{WIDTH}:5;
	    my $fg = $$form{$var}{FGCOLOR}?$$form{$var}{FGCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
	    my $bg = $$form{$var}{BGCOLOR}?$$form{$var}{BGCOLOR}:
	                                   $$form{GENERAL}{BGCOLOR};
	    my $mylfont = $$form{$var}{FONT}?$$form{$var}{FONT}:$lfont;
            my $border;
            if($$form{$var}{BORDER} eq '0') {
	       $border = 0;
            } else {
	       $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:4;
            }
	    
	    my $pushButton = $frame->Button(-text=>$text,
		                    #-height=>$height,
		                    #-width=>$width,
				    -borderwidth=>$border,
				    -relief=>$relief,
				    -font=>$mylfont,
				    -padx=>0,-pady=>0,
				    -command=>sub {
                                              eval $$form{$var}{COMMAND};
                                              my $b = warnwin($maske,__('Warning'),'error',$@,
                                                     [__('Ok'),__('Exit')]) if($@);
                                              exit if($b and $b eq __('Exit'));
                                              },
				    )->place("-x"=>$curX,
				             "-y"=>$curY+20);

            $pushButton->configure(-foreground=>$fg) if($fg);
            $pushButton->configure(-background=>$bg) if($bg);
            $pushButton->configure(-activebackground=>$bg) if($bg);
            $pushButton->configure(-activeforeground=>$fg) if($fg);

            # if $$form{$var}{TEXT} an Image or Text
            my $file = eval qq{qq{$$form{$var}{TEXT}}};
            if(-e $file) {
               $pushButton->configure(-image=>
                                      $frame->Photo(-file=>$file));
            } else {
               $pushButton->configure(-height=>$height,-width=>$width);
            }
	                   
	    $field = $pushButton;

            # add the key of this field to the widget hash
            ${$pushButton}{FIELD} = $$form{$var};  # needed in sub motion
            ${$pushButton}{SECTION} = $var;  # needed in sub motion
            ${$pushButton}{FORM} = $form;  # needed in sub motion
            ${$pushButton}{FIELD} = $$form{$var};
	    $$form{$var}{WIDGET} = $field;

            $pushButton->bind("<Shift-Control-Button-1>",\&move);
            $pushButton->bind("<Shift-Control-Button1-Motion>",\&motion);
            $pushButton->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $pushButton->bind("<FocusIn>", [\&focusIn,$form,$pushButton]);
            $pushButton->bind("<FocusOut>", [\&focusOut,$form,$pushButton]);

	 }

	 ### RadioButton-widget TYPE=R
         if($$form{$var}{TYPE} =~ /^R/) {
	    
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'raised';
	    my @text = split('\|',$$form{$var}{TEXT});
	    
	    my $height = $$form{$var}{HEIGHT}?$$form{$var}{HEIGHT}:1;
	    my $fg = $$form{$var}{FGCOLOR}?$$form{$var}{FGCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
	    my $bg = $$form{$var}{BGCOLOR}?$$form{$var}{BGCOLOR}:
	                                   $$form{GENERAL}{BGCOLOR};
	    my $selcolor = $$form{$var}{SELECTCOLOR};
	    my $selected = ($$form{$var}{SELECTED} or 
		            $$form{$var}{SELECTED} == 0) ? $$form{$var}{SELECTED}:'nothing';
	    my $mylfont = $$form{$var}{FONT}?$$form{$var}{FONT}:$lfont;
            my $border;
            if($$form{$var}{BORDER} eq '0') {
	       $border = 0;
            } else {
	       $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:2;
            }
	    
	    my $ib = 0;
	    my $radioButton;

	    # Frame als Container für alle Radiobuttons
	    my $radioframe = $frame->Frame(-borderwidth=>$border,
                                           -relief=>$relief,
		                           -background=>$bg,
		                          )->place("-x"=>$curX,"-y"=>$curY+20);

	    foreach my $item (@text) { 
               $radioButton = $radioframe->Radiobutton(-text=>$item,
                                                       -height=>$height,
                                                       -highlightthickness=>0,
                                                       -borderwidth=>2,
						       -indicatoron=>1,
                                                       -font=>$mylfont,
                                                       -variable=>\$selected,
                                                       -value=>$ib,
                                                       -command=>
                              sub {
				   print "# debug Radiobutton: Section $var: $item: $selected\n" if($opt_d);
                                   $$form{$var}{SELECTED} = $selected;
                                   $$form{$var}{DATA} = $item;
                                   eval $$form{$var}{COMMAND};
                                   my $b = warnwin($maske,__('Warning'),'error',$@,
                                          [__('Ok'),__('Exit')]) if($@);
                                   exit if($b and $b eq __('Exit'));
                                   },
                                                      )->pack(-side=>'top',-anchor=>'w');

               $radioButton->configure(-foreground=>$fg) if($fg);
               $radioButton->configure(-background=>$bg) if($bg);
               $radioButton->configure(-activebackground=>$bg) if($bg);
               $radioButton->configure(-activeforeground=>$fg) if($fg);
               $radioButton->configure(-selectcolor=>$selcolor) if($selcolor);

	       $ib++;

            } 
	                   
	    $field = $radioframe;

            # add the key of this field to the widget hash
            ${$radioframe}{FIELD} = $$form{$var};  # needed in sub motion
            ${$radioframe}{SECTION} = $var;  # needed in sub motion
            ${$radioframe}{FORM} = $form;  # needed in sub motion
            ${$radioframe}{FIELD} = $$form{$var};
	    $$form{$var}{WIDGET} = $field;

            $radioframe->bind("<Shift-Control-Button-1>",\&move);
            $radioframe->bind("<Shift-Control-Button1-Motion>",\&motion);
            $radioframe->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $radioframe->bind("<FocusIn>", [\&focusIn,$form,$radioframe]);
            $radioframe->bind("<FocusOut>", [\&focusOut,$form,$radioframe]);

	 }


#####################################################################################
#   NOT READY YET
	 ### CheckButton-widget TYPE=
         if($$form{$var}{TYPE} =~ /^X/) {
	    
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'raised';
	    my @text = split('\|',$$form{$var}{TEXT});
	    
	    my $height = $$form{$var}{HEIGHT}?$$form{$var}{HEIGHT}:1;
	    my $fg = $$form{$var}{FGCOLOR}?$$form{$var}{FGCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
	    my $bg = $$form{$var}{BGCOLOR}?$$form{$var}{BGCOLOR}:
	                                   $$form{GENERAL}{BGCOLOR};
	    my $selcolor = $$form{$var}{SELECTCOLOR};
	    my $selected = $$form{$var}{SELECTED}?$$form{$var}{SELECTED}:0;
	    my $mylfont = $$form{$var}{FONT}?$$form{$var}{FONT}:$lfont;
            my $border;
            if($$form{$var}{BORDER} eq '0') {
	       $border = 0;
            } else {
	       $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:2;
            }
	    
	    my $ib = 0;
	    my $checkButton;

	    # Frame als Container für alle Checkbuttons
	    my $checkframe = $frame->Frame(-borderwidth=>$border,
                                           -relief=>$relief,
		                           -background=>$bg,
		                          )->place("-x"=>$curX,"-y"=>$curY+20);

	    foreach my $item (@text) { 
               $checkButton = $checkframe->Checkbutton(-text=>$item,
                                                       -height=>$height,
                                                       -highlightthickness=>0,
                                                       -borderwidth=>2,
						       -indicatoron=>1,
                                                       -font=>$mylfont,
                                                       -variable=>\$selected,
                                                       -value=>$ib,
                                                       -command=>
                              sub {
				   print "# debug Checkbutton: Section $var: $item: $selected\n" if($opt_d);
                                   $$form{$var}{SELECTED} = $selected;
                                   $$form{$var}{DATA} = $item;
                                   eval $$form{$var}{COMMAND};
                                   my $b = warnwin($maske,__('Warning'),'error',$@,
                                          [__('Ok'),__('Exit')]) if($@);
                                   exit if($b and $b eq __('Exit'));
                                   },
                                                      )->pack(-side=>'top',-anchor=>'w');

               $checkButton->configure(-foreground=>$fg) if($fg);
               $checkButton->configure(-background=>$bg) if($bg);
               $checkButton->configure(-activebackground=>$bg) if($bg);
               $checkButton->configure(-activeforeground=>$fg) if($fg);
               $checkButton->configure(-selectcolor=>$selcolor) if($selcolor);

	       $ib++;

            } 
	                   
	    $field = $checkframe;

            # add the key of this field to the widget hash
            ${$checkframe}{FIELD} = $$form{$var};  # needed in sub motion
            ${$checkframe}{SECTION} = $var;  # needed in sub motion
            ${$checkframe}{FORM} = $form;  # needed in sub motion
            ${$checkframe}{FIELD} = $$form{$var};
	    $$form{$var}{WIDGET} = $field;

            $checkframe->bind("<Shift-Control-Button-1>",\&move);
            $checkframe->bind("<Shift-Control-Button1-Motion>",\&motion);
            $checkframe->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $checkframe->bind("<FocusIn>", [\&focusIn,$form,$checkframe]);
            $checkframe->bind("<FocusOut>", [\&focusOut,$form,$checkframe]);

	 }
#####################################################################################


	 ### Uhr-widget TYPE=U
         if($$form{$var}{TYPE} =~ /^U/) {
	   
	    require Tk::Clock;
            Tk::Clock->require_version('0.06');

	    my $analog = 0;
            my $digital = 0;
	    $digital = 1 if($$form{$var}{TYPE} =~ /digital/);
	    $analog = 1 if($$form{$var}{TYPE} =~ /analog/);
	    

	    my $bg = $$form{$var}{BGCOLOR}?$$form{$var}{BGCOLOR}:
	                                   $$form{GENERAL}{BGCOLOR};
	    # Zeiger
	    my $handColor = $$form{$var}{FGCOLOR}?$$form{$var}{FGCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
	    # ticks
	    my $tickColor = $$form{$var}{tickCOLOR}?$$form{$var}{tickCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
	    #sec-Zeiger
	    my $secsColor = $$form{$var}{secsCOLOR}?$$form{$var}{secsCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
	    # time
	    my $timeColor = $$form{$var}{timeCOLOR}?$$form{$var}{timeCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
	    # date
	    my $dateColor = $$form{$var}{dateCOLOR}?$$form{$var}{dateCOLOR}:
	                                   $$form{GENERAL}{FGCOLOR};
            # AnalogScale
	    my $aScale = $$form{$var}{ANALOGSCALE}?$$form{$var}{ANALOGSCALE}:
	                                   100;
	    # tickfreq
	    my $tickfreq = $$form{$var}{TICKFREQ}?$$form{$var}{TICKFREQ}:1;
	    # timeformat
	    my $timeformat = $$form{$var}{TIMEFORMAT}?$$form{$var}{TIMEFORMAT}:
	                                   "HH.MM:SS";
	    # dateformat apiisrc!
	    my $dateformat = $$form{$var}{DATEFORMAT}?$$form{$var}{DATEFORMAT}:
	                                   "dd-mm-yy";
	    #  timeFont
	    my $timefont = $$form{$var}{TIMEFONT}?$$form{$var}{TIMEFONT}:
	                                   $sfont;
	    #  dateFont
	    my $datefont = $$form{$var}{DATEFONT}?$$form{$var}{DATEFONT}:
	                                   $sfont;

	    my $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:0;
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'flat';

	    my $uhr = $frame->Clock(-background=>$bg,
                                    -bd=>$border,
                                    -relief=>$relief);
            $uhr->config(useDigital => $digital,
	                 useAnalog  => $analog,
			 anaScale   => $aScale,
			 handColor  => $handColor,
			 secsColor  => $secsColor,
			 tickColor  => $tickColor,
			 tickFreq   => $tickfreq,
                         timeFont   => $timefont,
                         timeColor  => $timeColor,
                         timeFormat => $timeformat,
                         dateFont   => $datefont,
                         dateColor  => $dateColor,
                         dateFormat => $dateformat
			 );
            $uhr->place("-x"=>$curX,"-y"=>$curY);

	    $field = $uhr;

            # add the key of this field to the widget hash
            ${$uhr}{FIELD} = $$form{$var};  # needed in sub motion
            ${$uhr}{SECTION} = $var;  # needed in sub motion
            ${$uhr}{FORM} = $form;  # needed in sub motion
            ${$uhr}{FIELD} = $$form{$var};
	    $$form{$var}{WIDGET} = $field;

            $uhr->Tk::bind("<Shift-Control-Button-1>",\&move);
            $uhr->Tk::bind("<Shift-Control-Button1-Motion>",\&motion);
            $uhr->Tk::bind("<Shift-Control-ButtonRelease>",\&recurs);
	 
         }
	    

	 ### MListbox-widget TYPE=O
         if($$form{$var}{TYPE} =~ /^O/) {

	    require Tk::MListbox;
	    Tk::MListbox->require_version('1.11');
	    
	    my $border = $$form{$var}{BORDER}?$$form{$var}{BORDER}:2;
	    my $relief = $$form{$var}{RELIEF}?$$form{$var}{RELIEF}:'groove';
	    my $height = $$form{$var}{HEIGHT}?$$form{$var}{HEIGHT}:5;
	    my $width = $$form{$var}{WIDTH}?$$form{$var}{WIDTH}:100;
	    my $scroll = $$form{$var}{SCROLLBAR}?$$form{$var}{SCROLLBAR}:'osoe';
	    my $mode = $$form{$var}{MODE}?$$form{$var}{MODE}:'browse';
	    my $move = $$form{$var}{MOVEABLE}?$$form{$var}{MOVEABLE}:0;
	    my $separatorcolor = $$form{$var}{SEPARATORCOLOR}?$$form{$var}{SEPARATORCOLOR}:'black';
	    my $separatorwidth = $$form{$var}{SEPARATORWIDTH}?$$form{$var}{SEPARATORWIDTH}:1;
	    my $headerfont = $$form{$var}{FONT}?$$form{$var}{FONT}:$lfont;
	    my $bg = $$form{$var}{BGCOLOR}?$$form{$var}{BGCOLOR}:$$form{GENERAL}{BGCOLOR};
	    my $fg = $$form{$var}{FGCOLOR}?$$form{$var}{FGCOLOR}:$$form{GENERAL}{FGCOLOR};
	    my $frbg = $$form{$var}{FRAMECOLOR}?$$form{$var}{FRAMECOLOR}:$bg;
	    my $mylfont = $$form{$var}{FONT}?$$form{$var}{FONT}:$lfont;
	    my $listfont = $$form{$var}{LISTBOXFONT}?$$form{$var}{LISTBOXFONT}:$sfont;


	    my @text = split('\|',$$form{$var}{TEXT});
	    my @fieldl = split('\|',$$form{$var}{FIELDLENGTH}?$$form{$var}{FIELDLENGTH}:10);
	    my @sort = split('\|',$$form{$var}{SORTABLE}?$$form{$var}{SORTABLE}:1);
	    my @sortmode = split('\|',$$form{$var}{SORTMODE}?$$form{$var}{SORTMODE}:'a');
	    my @rsiz = split('\|',$$form{$var}{RESIZEABLE}?$$form{$var}{RESIZEABLE}:1);
	    my @hfgcolor = split('\|',$$form{$var}{HEADERFGCOLOR}?$$form{$var}{HEADERFGCOLOR}:$fg);
	    my @hbgcolor = split('\|',$$form{$var}{HEADERBGCOLOR}?$$form{$var}{HEADERBGCOLOR}:$bg);
	    my @lfgcolor = split('\|',$$form{$var}{LISTBOXFGCOLOR}?$$form{$var}{LISTBOXFGCOLOR}:$fg);
	    my @lbgcolor = split('\|',$$form{$var}{LISTBOXBGCOLOR}?$$form{$var}{LISTBOXBGCOLOR}:$bg);
	    my @selfgcolor = split('\|',$$form{$var}{SELECTFGCOLOR}?$$form{$var}{SELECTFGCOLOR}:$bg);
	    my @selbgcolor = split('\|',$$form{$var}{SELECTBGCOLOR}?$$form{$var}{SELECTBGCOLOR}:$fg);
	    
	    # Frame als Container für MListbox
	    my $mlframe = $frame->Frame(-borderwidth=>$border,
                                           -relief=>$relief,
		                           # -background=>$frbg,
		                          )->place("-x"=>$curX,"-y"=>$curY+20);
            $mlframe->configure(-background=>$frbg) if($frbg);

	    my $mlistbox = $mlframe->Scrolled(MListbox,
				    -takefocus=>1,
		                    -height=>$height,
		                    -width=>$width,
				    # -background=>$bg,
				    # -foreground=>$fg,
				    -separatorcolor=>$separatorcolor,
				    -separatorwidth=>$separatorwidth,
			            -moveable=>$move,
				    -resizeable=>0,
				    # -borderwidth=>$border,
				    # -relief=>$relief,
				    -scrollbars=>$scroll,
				    -font=>$sfont,
				    -selectmode=>$mode
				    )
			          ->pack(-padx=>3,-pady=>3,);
	                   
	    $mlistbox->configure(-foreground=>$fg) if($fg);
	    $mlistbox->configure(-background=>$bg) if($bg);

            # create columns with columnInsert
	    my $i = 0;
	    foreach $col (@text) {
	       #  sortmode either numerically or alphbetically 
	       if($sortmode[$i] eq 'n') {
	          $mlistbox->columnInsert('end',-text=>$col,
			   -textwidth=>$fieldl[$i]?$fieldl[$i]:$fieldl[0],
		           -sortable=>$sort[$i]?$sort[$i]:$sort[0],
			   -resizeable=>$rsiz[$i]?$rsiz[$i]:$rsiz[0],
			   -comparecmd=>sub{$_[0] <=> $_[1]},  # sortmode
			   );
	       }else {
	          $mlistbox->columnInsert('end',-text=>$col,
			   -textwidth=>$fieldl[$i]?$fieldl[$i]:$fieldl[0],
		           -sortable=>$sort[$i]?$sort[$i]:$sort[0],
			   -resizeable=>$rsiz[$i]?$rsiz[$i]:$rsiz[0],
			   -comparecmd=>sub{$_[0] cmp $_[1]},  # sortmode
			   );
               }
	       $mlistbox->columnGet($i)->Subwidget("heading")->configure(
		     -background=>$hbgcolor[$i]?$hbgcolor[$i]:$hbgcolor[0]) if($hbgcolor[0]);
	       $mlistbox->columnGet($i)->Subwidget("heading")->configure(
		     -foreground=>$hfgcolor[$i]?$hfgcolor[$i]:$hfgcolor[0]) if($hfgcolor[0]);
	       $mlistbox->columnGet($i)->Subwidget("heading")->configure(
		     -font=>$mylfont) if($mylfont);

	       $mlistbox->columnGet($i)->Subwidget("listbox")->configure(
		  -background=>$lbgcolor[$i]?$lbgcolor[$i]:$lbgcolor[0]) if($lbgcolor[0]);
	       $mlistbox->columnGet($i)->Subwidget("listbox")->configure(
		  -foreground=>$lfgcolor[$i]?$lfgcolor[$i]:$lfgcolor[0]) if($lfgcolor[0]);
	       $mlistbox->columnGet($i)->Subwidget("listbox")->configure(
	          -selectforeground=>$selfgcolor[$i]?$selfgcolor[$i]:$selfgcolor[0]) if($selfgcolor[0]);
	       $mlistbox->columnGet($i)->Subwidget("listbox")->configure(
                  -selectbackground=>$selbgcolor[$i]?$selbgcolor[$i]:$selbgcolor[0]) if($selbgcolor[0]);
	       $mlistbox->columnGet($i)->Subwidget("listbox")->configure(
		     -font=>$listfont) if($listfont);
	       $i++;
	    }


	    # Are there some DATAs in the formfile?
	    if( $$form{$var}{DATA}) {
	       my @ar = split('\n',$$form{$var}{DATA});
	       foreach (@ar) {
	          $mlistbox->insert('end',[ split(' ',$_)]);
	       }
               $$form{$var}{DATA}=undef;
	    }


	    $field = $mlistbox;

            # set background color for the scollbars and corner
            if($bg) {
               my $en = $field->Subwidget('xscrollbar');
               $en->configure(-bg=>$bg,
                              -troughcolor=>$bg,
                              -activebackground=>$bg) if($en);
               $en = $field->Subwidget('yscrollbar');
               $en->configure(-bg=>$bg,
                              -troughcolor=>$bg,
                              -activebackground=>$bg) if($en);
               $en = $field->Subwidget('corner');
               $en->configure(-bg=>$bg) if($en);
            }

            # add the key of this field to the widget hash
            ${$mlistbox}{FIELD} = $$form{$var};  # needed in sub motion
            ${$mlistbox}{SECTION} = $var;  # needed in sub motion
            ${$mlistbox}{FORM} = $form;  # needed in sub motion
            ${$mlframe}{FIELD} = $$form{$var};  # needed in sub motion
            ${$mlframe}{SECTION} = $var;  # needed in sub motion
            ${$mlframe}{FORM} = $form;  # needed in sub motion
	    # mlframe oder mlistbox?
	    $$form{$var}{WIDGET} = $field;
	    # $$form{$var}{WIDGET} = $mlframe;

            $mlistbox->bindRows("<Shift-Control-Button-1>",\&move);
            $mlistbox->bindRows("<Shift-Control-Button1-Motion>",\&motion);
            $mlistbox->bindRows("<Shift-Control-ButtonRelease>",\&recurs);
            $mlframe->bind("<Shift-Control-Button-1>",\&move);
            $mlframe->bind("<Shift-Control-Button1-Motion>",\&motion);
            $mlframe->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $mlistbox->bind("<FocusIn>", [\&focusIn,$form,$mlistbox]);
            $mlistbox->bind("<FocusOut>", [\&focusOut,$form,$mlistbox]);

            $mlistbox->bind("<Leave>", 'focusNext');
            $mlistbox->bind("<Button-1>", 'focus');
            $mlistbox->bind("<Tab>", 'focusNext');
            $mlistbox->bind("<KP_Enter>",'focusNext');


	    &browseDB($mlistbox);
	 }


	  
	 ### MatchEntry-widget TYPE=H
	 #   Entry widget with advanced auto-completion capability
         elsif($$form{$var}{TYPE} =~ /^H/) {
	    require Tk::MatchEntry;

	    my (@choises, @hfld, @en, @cn, $field, $ipopp);

            $bframe[$i] = $frame->Frame(-relief=>'groove', -borderwidth=>0)
                            ->place("-x"=>$curX-1,
                                  "-y"=>$curY+20);

            my $lscmd =($$form{$var}{TYPE} =~ /^[H]/)?\&browseDB:\&browseList;
            $hfld[$i] = $bframe[$i]->MatchEntry(-variable=>\$$form{$var}{DATA},
                              -width=>$$form{$var}{FIELDLENGTH},
			      -fixedwidth     => 1,
			      ignorecase     => 1,
			      -maxheight      => 5,
                              -choices=>\@choises,
                              -listcmd=>$lscmd,
                              -colorstate=>'normal',
              ) # -bg=>$bg) # die Farbe geht <FC>ber das Eingabefeld hinaus :-(
                              ->pack(-side => 'left');
            $hfld[$i]->configure(-background=>$formbg) if($formbg);

            $field = $hfld[$i];

            $ipopp = $frame->Pixmap(-file=>"$APIIS_HOME/lib/images/popup.xpm");
	    my $b=$bframe[$i]->Button(-image => $ipopp,
	                  -relief=>'raised',
			  -border=>2,
			  -height=>0,-width=>0,
			  -padx=>0,-pady=>0,
                          -command => sub{$lscmd;$field->popup}
                         )->pack(-side => 'left');
            $b->configure(-background=>$formbg) if($formbg);
            $b->configure(-foreground=>$formfg) if($formfg);
            $b->configure(-activeforeground=>$formbg) if($formbg);
            $b->configure(-activebackground=>$formfg) if($formfg);


            # add key of this field to the widget hash
            $bframe[$i]{FIELD} = $$form{$var};  # needed in sub motion
            $bframe[$i]{SECTION} = $var;  # needed in sub motion
            $bframe[$i]{FORM} = $form;  # needed in sub motion
            $hfld[$i]{FIELD} = $$form{$var};

            # set background color -- only for the Entry!
            my $labentry = $hfld[$i]->Subwidget('entry'); # LabEntry(BrowseEntry)
            $en[$i] = $labentry->Subwidget('entry'); # Entry(LabEntry)
            $en[$i]->configure(-bg=>$bg,-fg=>$fg); # set back/foreground
            $cn[$i] = $hfld[$i]->Subwidget('slistbox'); #
            $cn[$i]->configure(-bg=>$bg); # set background for pop up list

            my $en = $cn[$i]->Subwidget('xscrollbar');
            $en->configure(-bg=>$bg,
                          -troughcolor=>$bg,
                          -activebackground=>$bg) if($en);
            $en = $cn[$i]->Subwidget('yscrollbar');
            $en->configure(-bg=>$bg,
                          -troughcolor=>$bg,
                          -activebackground=>$bg) if($en);
            $en = $cn[$i]->Subwidget('corner');
            $en->configure(-bg=>$bg) if($en);

            ## LabEntry's label background makes urgly Fields
            ## we don't need a LabEntry label - so destroy it ##
            $en = $labentry->Subwidget('label');
            $en->destroy() if($en);
            ####


            $hfld[$i]->bind("<Shift-Control-Button-1>",\&move);
            $hfld[$i]->bind("<Shift-Control-Button1-Motion>",\&motion);
            $hfld[$i]->bind("<Shift-Control-ButtonRelease>",\&recurs);
            $hfld[$i]->bind("<FocusIn>", [\&focusIn,$form,$field]);
            $hfld[$i]->bind("<FocusOut>", [\&focusOut,$form,$field]);

	 } # MatchEntry


	 $$form{$var}{WIDGET} = $field if(!$$form{$var}{WIDGET}); # Zugriff auf widgets über form-hash

         # set focus
	 my ($veryfirstFocus, $firstfocus);
         if ($focus and $$form{$var}{TYPE} =~ /^[EBLCTMOPNUH]/) {
	    if($vfFocus) {
	       $veryfirstFocus = $field;
	       $vfFocus = undef;
               $field->focus();
	       $$form{GENERAL}{VFF} = $field; # to make $veryfirstFocus local
	    }
	    if($$form{$var}{CLEAR} =~ /Y/) {
               $focus = undef;
               $firstfocus = $field;
	       $$form{GENERAL}{FF} = $field; # to make firstFocus local
	    }
         }
	 $firstfocus = $veryfirstFocus if(!$firstfocus);

         $i++;

      } # Widget types

      $frame->bind(Tk::Entry, "<Tab>", sub {&function($form,'F')});
      $frame->bind('all', "<KP_Enter>",'focusNext');
      $frame->bind(Tk::Entry, "<KP_Enter>", sub {&function($form,'F')});

      # Restart form
      $frame->bind('all', "<Shift-Control-Button-3>",
                                   sub {
                                          my @p;
					  foreach my $var (sort keys %$form) {
					     next if $var eq 'GENERAL';
					     push(@p, $$form{$var}{DATA});
					  }
                                          $maske->destroy;
					  &TkYAF($form_file, @p)
                                       });

      # end 
      $frame->bind('all', "<Shift-Control-Double-Button-2>",
                                   sub {
                                          $maske->destroy;
                                       });

#      $frame->bind(Tk::Entry, "<FocusIn>", [\&focusIn,$formd]);
#      $frame->bind(Tk::Entry, "<FocusOut>", [\&focusOut,$form]);


      # balloon status window?
      $balloon_status = $field if($var eq 'BalloonStatusField');


   }
  
   #### Button bar
   my $buttonFrame = buttonBar(\$maske, $form);
   $$form{GENERAL}{BUTTONBAR} = $buttonFrame; # access to the buttonbar


   # set default values (done by clearForm)
   $firstClear = 1; # makes it possible to display DATA
   clearForm($form);


   # TkYAF-parameters are going into the fields
   foreach my $var (sort keys %$form) {
      next if $var eq 'GENERAL';
      my $p = shift(@param);
      if($$form{$var}{TYPE} =~ /^T/) {
         $$form{$var}{WIDGET}->insert('1.0',$p);
      } elsif($$form{$var}{TYPE} =~ /^[M]/) {
         $$form{$var}{WIDGET}->insert('0',$p);
      } else {
         $$form{$var}{DATA} = $p if($p);
      }
   }



   ####   BALLOON help system
   my $balloon = $$form{GENERAL}{BALLOON}?$$form{GENERAL}{BALLOON}:undef;
   my $bcolor = $$form{GENERAL}{BALLOONBG}?$$form{GENERAL}{BALLOONBG}:'yellow';
   my $wait = $$form{GENERAL}{BALLOONWAIT}?$$form{GENERAL}{BALLOONWAIT}:350;
   my $border = 2;

   my $balloon_widget;      # balloon-widget itself
   if($balloon and $balloon eq 'both') { # help msgs on status-line and as balloon
      use Tk::Balloon;
      $balloon_widget = $maske->Balloon(-statusbar => $balloon_status,  
                                        -background => $bcolor,
                                        -borderwidth => $border,
                                        -relief => 'groove',
                                        -initwait => $wait,
                                        );
      foreach my $var (sort keys %$form) {
            $balloon_widget->attach($$form{$var}{WIDGET},
                            -balloonposition => 'mouse',
                            -msg => $$form{$var}{BALLOONMSG},
                             )if($$form{$var}{BALLOONMSG} and $balloon_widget); 
      }
   } elsif($balloon and $balloon eq 'balloon' ) { # only  balloons
      use Tk::Balloon;
      $balloon_widget = $maske->Balloon(-background => $bcolor,
                                        -borderwidth => $border,
                                        -relief => 'groove',
                                        -initwait => $wait,
                                       );
      foreach my $var (sort keys %$form) {
            $balloon_widget->attach($$form{$var}{WIDGET},
                            -balloonposition => 'mouse',
                            -msg => $$form{$var}{BALLOONMSG},
                             )if($$form{$var}{BALLOONMSG} and $balloon_widget); 
      }
   } elsif($balloon and $balloon eq 'status' ) { # only on the status-widget($balloon_status)
      use Tk::Balloon;
      $balloon_widget = $maske->Balloon(-statusbar => $balloon_status,  
                                        -background => $bcolor,
                                        -borderwidth => $border,
                                        -relief => 'groove',
                                        -initwait => $wait,
                                       );
      foreach my $var (sort keys %$form) {
            $balloon_widget->attach($$form{$var}{WIDGET},
                            -balloonposition => 'mouse',
                            -statusmsg => $$form{$var}{BALLOONMSG},
                             )if($$form{$var}{BALLOONMSG} and $balloon_widget);
      }
   }

   $$form{GENERAL}{BALLOONWIDGET} = $balloon_widget; # general access to the balloon-system
   
   MainLoop;

   ###  return all field values as a hash
   #    $ret_data{section} = value
   my %ret_data;
   foreach $var (sort keys %$form) {
      next if($var eq 'GENERAL');
      $ret_data{$var} = $$form{$var}{DATA}
                        if($$form{$var}{TYPE} =~ /^[EDLBCTMN]/
			      and defined $$form{$var}{DATA});
   }
   return %ret_data;
   
   

} # TkYAF


##################### evaluate STARTUP ######################################
sub startup {

   my $field = pop(@_);  # field
   my $form = pop(@_);   # form hash
   my ($we) = @_;        # widget

   $we->bind("<Visibility>",'');

   # for older usage of $buttonFrame and $maske
   my $buttonFrame = $$form{GENERAL}{BUTTONBAR};
   my $maske = $$form{GENERAL}{TOPLEVEL};

   my $b = '';
   ####   if   STARTUP   defined?
   eval $$form{GENERAL}{STARTUP} if($$form{GENERAL}{STARTUP});
   $b = warnwin($maske,'Error in [GENERAL] STARTUP-Command','error',
                   "$@\nSTARTUP=$$form{GENERAL}{STARTUP}\n",
                   [__('Ok'),__('Exit')]) if($@);
   exit if($b eq __('Exit'));

} #startup

##############################################################################
sub allesklar {
   
   use Tk::Dialog;
   use Apiis::Misc;                # standard lib for apiis

   my $form = shift;
   my $top_ref = shift;
   my $top = ${$top_ref};

   my ($i, $u, $c, $f, $z) = (0, 0, 0, 0, 0); 
   my ($status, $tab) = '';
   my $msg10 = __('Error in Data');               #  en => "Error in Data:"
   my $csv_string = '' if $opt_c;

   # get DATA from some special fields
   foreach $var (sort keys %$form) {
      next if $var eq 'GENERAL';

      # get text from Text-widgets
      $$form{$var}{DATA} = $$form{$var}{WIDGET}->get('1.0','end')
                                  if($$form{$var}{TYPE} =~ /^[T]/);

      # get selected items from Listbox-widget
      if($$form{$var}{TYPE} =~ /^[M]/) {
	 my $we = $$form{$var}{WIDGET};
         my @choices;
         my @sel = $we->curselection();
         foreach (@sel) {
            my $a = $we->get($_);
	    push(@choices,$a);
         }
      print # debug Listbox:@choices\n"; if($opt_d); 
      $$form{$var}{DATA} = join(' ',@choices);
      }
      
   }

   # execute all defined functions 
   &function($form,'fF');

   foreach $var (sort keys %$form) {
      next if $var eq 'GENERAL';
      if($opt_c) {
	 $csv_string .= ($$form{$var}{DATA})?"$$form{$var}{DATA},":",";
         next
      }
	                 
      foreach $action ( @{$$form{$var}{ACTION}} ) {
	 @{$action_args} = split /\s+/, $action;
	 push @{$action_args}, $$form{$var}{DATA};
	 push @{$action_args}, $var;
	 # inserts ?
	 if(@{$action_args}[0] eq 'I') {
	    @{$insert_args[$i]} = @{$action_args};
	    print "# debug insert:$i $var :: @$action_args\n" if($opt_d); 
	    $i++;
	 }
	 # updates ?
	 if(@{$action_args}[0] eq 'U') {
	    @{$update_args[$u]} = @{$action_args};
	    print "# debug update:$u $var :: @$action_args\n" if($opt_d); 
	    $u++;
	 }
	 # where conditions ?
	 if(@{$action_args}[0] eq 'C') {
	    @{$where_args[$c]} = @{$action_args};
	    print "# debug where clause:$c $var :: @$action_args\n" if($opt_d); 
	    $c++;
	 }
      }
   }
   chop $csv_string if $csv_string;
   print $csv_string ."\n" if $opt_c;

   my $regcommit = 0;
   my ($color,$rep,$srep);

   # field background color red or $$form{GENERAL}{ERRCOLOR}
   my $blink = $$form{GENERAL}{ERRCOLOR}?$$form{GENERAL}{ERRCOLOR}:'red';




# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

#### INSERTs
   if(@insert_args) {
      for(@insert_args) {   # put the data into the tablehash of the modelfile
         my $col = getKey($$_[1],$$_[2], 'DB_COLUMN');
	 if($col ne -1) {
            ${$$_[1]}{$col}{DATA}=$$_[3];
            ${$$_[1]}{$col}{FORM_SEC}=$$_[4];  # from which field
	 } else {
	    warnwin($top,"Fatal Error",'error',
	                 "can not find hash-key for column $$_[2] in table $$_[1]");
	    return;
	 }
      }

      # set default values
      my $tab = $$_[1];
      foreach my $col ( sort keys %{$tab} ) {
	 next if $col eq 'TABLE';
	 $$tab{$col}{DATA} = $$tab{$col}{DEFAULT}
			   if($$tab{$col}{DEFAULT} and
			      $$tab{$col}{DATA} eq '');
      }
      
      # run CheckRule for all involved tables
      my %inshash = ();
      for (@insert_args) {
	 $tab = $$_[1];
	 if(not $inshash{$tab}) {
	    $inshash{$tab} = 1;
	    my $status = CheckRules(\%{$tab});
	    print "# debug Check table $tab\n" if($opt_d); 
	    print "# debug Check STATUS:$status\n" if($opt_d); 
	    #  error if ($status =~ /$msg10/);
	    if($status) {
	       print "# debug CheckRule: table $tab:",__('Rule violated'),"\n" if($opt_d); 
	       foreach my $col (sort keys %{$tab}) {
	          next if($col eq 'TABLE');
		  if(scalar(@{$$tab{$col}{ERROR}})) {

		     print "INSERT_ERROR:$col in section:$$tab{$col}{FORM_SEC}\n" if($opt_d);

		     # widget; a little bit shorter
		     my $we = $$form{$$tab{$col}{FORM_SEC}}{WIDGET}
		                            if(exists $$form{$$tab{$col}{FORM_SEC}});
		     
		     # only fields on the form can be changed
		     if(Exists($we)) {
		        # get current background color
		        $color = getwidgetoption($we,'background');

	                # flashing field indicates an error; background color $blink
		        $rep=$we->repeat(500, 
			    sub{ setwidgetoption($we,'background',$blink);
		                 $we->after(250,sub{setwidgetoption($we,'background',$color)});
			       });
		     }

                     # dialog window only if isn't an ErrorStatusField defined
		     my $delay;
		     my $swe;
		     if(exists $$form{ErrorStatusField}) {
		        # add table and coloumn to the err_msg
		        my $err_msg = "ERROR: ".$tab.".".$$tab{$col}{DB_COLUMN}.": ".
		                      join(" ; ",@{$$tab{$col}{ERROR}});
		        $$form{ErrorStatusField}{DATA} = $err_msg;
			$delay = 4000;
			# ErrorStatusField flashes one time
			$swe = $$form{ErrorStatusField}{WIDGET};
			my $scolor=getwidgetoption($swe,'background');
			setwidgetoption($swe,'background',$blink);
			$srep=$swe->after(1500,sub{setwidgetoption($swe,'background',$scolor)});
		        $srep=$swe->after(2500,sub{$srep=undef;});
		     } else {
		        # add table and coloumn to the err_msg
		        my $err_msg = $tab.".".$$tab{$col}{DB_COLUMN}."\n".
		                      join(" ; ",@{$$tab{$col}{ERROR}});
		        warnwin($top,__('Error in Data'),'error',$err_msg);
			$delay = 1000;
                     }
                     
		     if(Exists($we)) {
		        # Let it still 2 seconds flash.
			$we->after($delay,sub{ $we->afterCancel($rep); # stop flashing
		                             # restore background color
		                             setwidgetoption($we,'background',$color);
					     $rep = undef;
					   });
		     }

		     # wait until the widget stops flashing
		     $we->waitVariable(\$rep) if($rep);
		     $swe->waitVariable(\$srep) if($srep);
		    
		  }
	       }

	       $status = __('Error in Data');
	       status($status,\$top) if($regcommit == 1); # for rollback
	       return;
	    }
	    
	    print "# debug CheckRule: table $tab:",__('records successfully checked against rules'),"\n" if($opt_d); 

	    commitData(\%{$tab}, $tab, \$status);
            $regcommit = 1;
	    print "# debug INSERT table $tab\n" if($opt_d); 
	    # last if ($status =~ /$msg10/);
	    
	 }
      }

      undef %inshash;

   }

#   return if(status($status,\$top));

#   return if($UpIn eq 'Insert');

#### UPDATEs
### 1. assemble SQL statement for selecting update-record 
   my (%updatehash, %wherehash);  # flags for each table
   for(@update_args) {
      my $sqltext = '';     # SQL statement for each table
      $tab = $$_[1];
      next if($updatehash{$tab});
      $updatehash{$tab} = 1;
      $sqltext = "SELECT oid,* FROM $tab WHERE ";

      for(@where_args) {
         my $wtab = $$_[1];
         next if($wtab ne $tab);
         if(! $wherehash{$wtab}) {
            $wherehash{$wtab} = 1;
            $sqltext .= "$$_[2] = '$$_[3]'";
         } else { $sqltext .= " AND $$_[2] = '$$_[3]'"; }
      }
      if(! $wherehash{$tab}) {
         error($top, "ERROR: Field Section",
	             "Parameter: ACTION\nC-Type missing for table ". uc $tab);
	 next;
      }
      undef %wherehash;

      print "# debug selected update record (SQL):\n" if($opt_d); 
      print "#           $sqltext\n" if($opt_d); 
    
###  2. fetch record 
      my $sth = ExecuteSQL($sqltext);
      print "SQL:$sqltext\n" if($opt_s);
      my @array = $sth->fetchrow_array;
      $sth->finish;
      next if (not @array); # if no record retrieved -> next @update_args

###  3. put all datas into the tablehash of the model
      my @columns;
      foreach(sort keys(%$tab)){
         push(@columns, $_) if($_ ne 'TABLE');
      }
      my $rowid = shift(@array);

      print "# debug ROWID:$rowid\n" if($opt_d);

      my $ncols = 0;
      foreach (@array) {
         if($$tab{$columns[$ncols]}{DATATYPE} eq 'DATE') {
            my($y,$m,$d) = Decode_Date_NativeRDBMS($_);
	    if($d and $m and $y) {
	       $$tab{$columns[$ncols]}{DATA}="$d-$m-$y"if($apiis->date_format eq 'EU');
	       $$tab{$columns[$ncols]}{DATA}="$m-$d-$y"if($apiis->date_format eq 'US');
	    }
	 } else { $$tab{$columns[$ncols]}{DATA}=$_;}
	$ncols++;
      }

###  4. put new values into tablehash of the model
      for(@update_args) {
	 next if($tab ne $$_[1]); 
         my $col = getKey($$_[1],$$_[2], 'DB_COLUMN');
	 if($col ne -1) {
            $$tab{$col}{DATA}=$$_[3];
	    $$tab{$col}{FORM_SEC}=$$_[4]; # from which field
	 } else {
	    warnwin($top,"Fatal Error",'error',
	                 "can not find hash-key for column $$_[2] in table $$_[1]");
	    return;
	 }
      }

###  5. finally call subroutine Update
      $regcommit = 0;
      print "# debug UPDATE table $tab\n" if($opt_d); 
      my ($err_status,$err_msg) = Update($tab, $rowid, \%$tab, \$status);
      print "# debug UPDATE STATUS:$err_status\n" if($opt_d); 
      
      if($err_status) {
         print "# debug UPDATE ERROR:$err_msg\n" if($opt_d); 
	 foreach my $col (sort keys %{$tab}) {
	    next if($col eq 'TABLE');
	    if(scalar(@{$$tab{$col}{ERROR}})) {
	       
	       print "UPDATE_ERROR:$col in form-section:$$tab{$col}{FORM_SEC}\n" if($opt_d);

	       # widget: little bit shorter
	       my $we = $$form{$$tab{$col}{FORM_SEC}}{WIDGET}
		                            if(exists $$form{$$tab{$col}{FORM_SEC}});

               # only fields on the form can be changed (widget must exist)
               if(Exists($we)) {
	          # get current background color
	          $color = getwidgetoption($we,'background');
	       
	          # field background color red or $$form{GENERAL}{ERRCOLOR}
                  my $blink = $$form{GENERAL}{ERRCOLOR}?$$form{GENERAL}{ERRCOLOR}:'red';

	          # flashing field indicates an error; background color $blink
		  $rep=$we->repeat(500,
		             sub{ setwidgetoption($we,'background',$blink);
		                  $we->after(250,sub{setwidgetoption($we,'background',$color)})
			        });
	       }

	       # dialog window only if isn't an ErrorStatusField defined
	       my $delay;
	       my $swe;
	       if(exists $$form{ErrorStatusField}) {
		  # add table and coloumn to the err_msg
		  my $err_msg = "ERROR: ".$tab.".".$$tab{$col}{DB_COLUMN}.": ".
				join(" ; ",@{$$tab{$col}{ERROR}});
		  $$form{ErrorStatusField}{DATA} = $err_msg;
		  $delay = 4000;
		  # ErrorStatusField flashes one time
		  $swe = $$form{ErrorStatusField}{WIDGET};
		  my $scolor=getwidgetoption($swe,'background');
		  setwidgetoption($swe,'background',$blink);
		  $srep=$swe->after(1500,sub{setwidgetoption($swe,'background',$scolor)});
		  $srep=$swe->after(2500,sub{$srep=undef;});
	       } else {
		  # add table and coloumn to the err_msg
		  my $err_msg = $tab.".".$$tab{$col}{DB_COLUMN}."\n".
				join(" ; ",@{$$tab{$col}{ERROR}});
		  warnwin($top,__('Error in Data'),'error',$err_msg);
		  $delay = 1000;
	       }

               if(Exists($we)) {
		  # Let it still 2 seconds flash.
		  $we->after($delay,sub{ $we->afterCancel($rep); # stop flashing
	                               # restore background color
	                               setwidgetoption($we,'background',$color);
                                       $rep = undef;
		                     });
	       }

               # wait until the widget stops flashing
               $we->waitVariable(\$rep) if($rep);
               $swe->waitVariable(\$srep) if($srep);

	    }
	 }

         $status = __('Error in Data');
	 status($status,\$top) if($regcommit == 1); # for rollback 
	 return;
      }

      print "# debug Update: table:$tab:",__('records successfully checked against the rules'),"\n" if($opt_d);
      $regcommit = 1;
#      last if(Update($tab, $rowid, \%$tab, \$status)); # last, if error
   }

# YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY

   undef %updatehash;
   status($status,\$top,$form);
   
} # allesklar


##############################################################################
sub exitForm {

   $form = shift;

   readWidget($form) if($opt_p); # special Widgets like T,M and O are readout

   $$form{GENERAL}{TOPLEVEL}->destroy;

} # exitForm


##############################################################################
sub status {

   my $status = shift;
   my $top_ref = shift;
   my $form = shift;
   my $top = ${$top_ref};
   
   my $stat = __('Error in Data');

   print "STATUS:$status\n" if($opt_d);
   
   if ($status =~ /$stat/) {
      my $rc = $dbh->rollback || die $dbh->errstr;
      print "# debug ROLLBACK executed\n" if($opt_d);
      return 1;
   }
   else {
      # reset the form
      my $rc = $dbh->commit if($dbh);   
      print '# debug final commit $dbh->commit',"\n" if($opt_d);  
      clearForm($form,'sub');
      return 0;
   }

} # status


##############################################################################
# call all user functions
sub function {

   my $form = shift;
   my $type = shift;
   my $f = 0;

   foreach $var (sort keys %$form) {
      next if $var eq 'GENERAL';
      foreach $action ( @{$$form{$var}{ACTION}} ) {
         @{$action_args} = split /\s+/, $action;
         push @{$action_args}, $$form{$var}{DATA};
         # functions ?
         if($type =~ /@{$action_args}[0]/ ) {
            @{$func_args[$f]} = $var;
            push @{$func_args[$f]}, @{$action_args};
	    print "# debug function:$f $var :: @{$action_args}\n" if($opt_d); 
            $f++;
         }
      }
      print "# debug DATA used by functions:$$form{$var}{DATA}\n" if($opt_d);
   }
   # function
   if(@func_args) {
      for($z=0; $z<$f;$z++) {
         $$form{$func_args[$z][0]}{DATA} = &{$func_args[$z][2]}(@{$func_args[$z]},$form);
      }
   }

} # function


##############################################################################
# error - DialogBox
# usage: error(toplevel window, title, error)
sub error {
   
   my $top = shift;
   my $title = shift;
   my $status = shift;

   $wop=$top->parent()?$top->parent():$top; # the parent from top may be the
                                            # toplevel window from apiish
   
   my $dialog = $wop->Dialog(-title=>$title,
                             -bitmap=>"error",
                             -text=>$status)
		        ->Show;
} # error
 

##############################################################################
# usage: warnwin (toplevel-window, title, bitmap, text, [buttons])
sub warnwin {

   my ($fdtop, $title, ,$bitmap, $text, $buttons) = @_;

   $buttons = ['OK'] if(!$buttons);

   use Tk::Dialog;

   my $d = $fdtop->Dialog(-title=>$title,
                        -bitmap=>$bitmap,
                        -font=>'variable',
                        -text=>$text,
                        -buttons=>$buttons);
   return $d->Show;

} # warnwin


##############################################################################
# Return from the given hash the key where the value of
# the subkey is equal to string
sub getKey {

   my ($hash, $string, $subkey) = @_;

   foreach $key (sort keys %$hash) {
      next if ($key eq 'TABLE' or $key eq 'GENERAL');
      if($$hash{$key}{$subkey} eq $string) {
         return $key;
      }
   }
   return -1;

} # getKey


##############################################################################
# execute a command, defined in $form{GENERAL}{key}
# usage:  exeUserCommand (key,section,form)
sub exeUserCommand {

   my $key = shift;
   my $section = shift;
   my $form = shift;

   my $top = $$form{GENERAL}{TOPLEVEL};
   
##### Hinweis und Abfrage ob subroutine gestartet werden soll
#
#   my $yesbutton = 'Ja';
#   my $nobutton = 'Nein';
   
#   my @buttons = $yesbutton;
#   push(@buttons,$nobutton);
   
#   my $text = "Daten zu diesem Schlüssel existieren\nnoch nicht in der Datenbank!\n";
#   $text .= "\nHinweis:\nWenn der Datensatz, auf den der Schlüssel\nweist nicht existiert, kann der aktuelle\nDatensatz nicht gespeichert werden.\n";
#   $text .= "\nWollen Sie diese Daten jetzt eingeben?\n";
#
#   my $dialog = $maske->Dialog(-title=>"Frage",
#                             -bitmap=>'question',
#                             -text=>$text,
#			     -buttons => \@buttons,
#			     -default_button => $yesbutton)
#   		        ->Show;
##################

#   if($dialog eq $yesbutton) {

      my $b = '';
      # execute user defined command
      eval $$form{GENERAL}{$key} if($$form{GENERAL}{$key});
      $b = warnwin($top,"Error in [GENERAL] $key-Command",'error',
                   "$@\n$key=$$form{GENERAL}{$key}\n",
                   [__('Ok'),__('Exit')]) if($@);
      exit if($b eq __('Exit'));

      eval $$form{$section}{$key} if($$form{$section}{$key});
      $b = warnwin($top,"Error in [$section] $key-Command",'error',
                   "$@\n$key=$$form{$section}{$key}\n",
                   [__('Ok'),__('Exit')]) if($@);
      exit if($b eq __('Exit'));

#   }

} # exeUserCommand


##############################################################################
# execute a command, defined in ACTION
# usage:  ACTION=F exeCommand section key

# example: 
#     [XY]
#     ACTION=F exeCommand col008 DOIT
#	   
#     [col008]
#     DOIT=system("xmessage second")
# or/and
#     [GENERAL]
#     DOIT=system("xmessage first")
#          
sub exeCommand {

   my $form = pop(@_);
   
   my $section = $_[3];
   my $key = $_[4];
   

   my $top = $$form{GENERAL}{TOPLEVEL};

   my $b = '';
   # execute defined command
   eval $$form{GENERAL}{$key} if($$form{GENERAL}{$key});
   $b = warnwin($top,"Error in [GENERAL] $key-Command",'error',
                "$@\n$key=$$form{GENERAL}{$key}\n",
                [__('Ok'),__('Exit')]) if($@);
   exit if($b eq __('Exit'));

   eval $$form{$section}{$key} if($$form{$section}{$key});
   $b = warnwin($top,"Error in [$section] $key-Command",'error',
                "$@\n$key=$$form{$section}{$key}\n",
                [__('Ok'),__('Exit')]) if($@);
   exit if($b eq __('Exit'));


   return $_[5];

} # exeCommand


###########################################################################
# commitData
# usage : commitData(table_reference, tablename, statusmessage_reference )
#
sub commitData {
   my $tabref = shift;
   my $tablename = shift;
   my $status_msg_ref = shift;    # reference to the status message

####   use Rules;
####   use CheckRules;
   #### use DataBase;
####   use Modify;

   my $data_error;
#   $data_error = CheckRules( $tabref );

   if ( $data_error ) {
      $$status_msg_ref = __('Error in Data'); # Error in Data
      # error messages
      foreach $col ( sort keys %$tabref ) {
         next if $col eq 'TABLE';
         if  ( scalar @{$tabref->{$col}{ERROR}} ) {
            $$status_msg_ref .= "\n" .
                                ucfirst $tabref->{$col}{DB_COLUMN} .
                                ': ' .
                                join(',', @{$tabref->{$col}{ERROR}});
         }
      }
   } else { # data ok
      # prepare hash for subroutine Insert
      my (%data_hash);
      foreach $col ( sort keys %$tabref ) {
         next if $col eq 'TABLE';
         if ($tabref->{$col}{DATA} and $tabref->{$col}{DATA} ne '') {
            $data_hash{ $tabref->{$col}{DB_COLUMN} } = $tabref->{$col}{DATA};
         }
      }
      # Insert data into Database:
      if ( OldInsert($tablename, \%data_hash) ) {
         $$status_msg_ref = __('Record committed');  # Record committed
      }
   }
} # commitData


##############################################################################
# retrieves data from the database and puts it into  
# the Browse-Entry or [M]Listbox-widget as selectable items 
sub browseDB {

   my ($e) = @_;  # widget

   #### use DataBase;

   my $sql = 'SELECT DISTINCT ';
   my @choices;
   my $p;

   # no modelfile - no database -> no list items
   if($$e{FIELD}{TYPE} =~ /^[BNH]/) {
      $p = $e->parent;
      return if(! $apiis->exists_model);
   }
   if($$e{FIELD}{TYPE} =~ /^MO/) {
      return if(! $apiis->exists_model);
   }

   my $dbhy=$apiis->DataBase->sys_dbh;

   if ( defined $$e{FIELD}) {
      if($$e{FIELD}{TYPE} =~ /^\w\s+(.*)/) {
         my $select = $1;
	 return if(! $select);
	 my @ar = split(' ', $select);
	 $ar[0] =~ s/\|/,/g;          # substitute '|' with ','
	 $sql .= "$ar[0] ";
	 if($$e{FIELD}{TYPE} =~ /^B/) {   #  only TYPE=B for queries
	    $sql .= "FROM $ar[1] WHERE $ar[0] LIKE '%".$$e{FIELD}{DATA}."%'";
	 } else {
	    $ar[1] =~ s/\|/,/g;          # substitute '|' with ','
	    $sql .= "FROM $ar[1]";
	 }
	 if($#ar > 1) {
	    ($ar[0]) = $ar[0] =~ /^(\w+|\w+\.+\w+),.+/ if($$e{FIELD}{TYPE} =~ /^O/); 
	    $sql .= " WHERE $ar[0] LIKE '%%'" if($$e{FIELD}{TYPE} =~ /^[NMOH]/);
	    for(my $i=2;$i<=$#ar;$i++) {
	       if($ar[$i] =~ /(\$.*\$)/) {
                  $ar[$i] =~ s/\$//g;
                  (my $ope) = $ar[$i] =~ /^\w+\.*\w+([=<>!~]+)\w+/;
		  my @arr = split(/[=<>!~]+/,$ar[$i]);
		  if($$e{FIELD}{TYPE} =~ /^[BNH]/ and $$p{FORM}{$arr[1]}{DATA}){
                     $sql .= " AND $arr[0] $ope ".
		                        $dbhy->quote($$p{FORM}{$arr[1]}{DATA});
		  }
		  if($$e{FIELD}{TYPE} =~ /^[MO]/ and $$e{FORM}{$arr[1]}{DATA}){
                     $sql .= " AND $arr[0] $ope ".
		                        $dbhy->quote($$e{FORM}{$arr[1]}{DATA});
		  }
               } else {
	          $sql .= " and $ar[$i]";
	       }
	    }
	 }
      } else {return;}
   }

####   ConnectDB() unless defined $dbh;
####   my $sth = ExecuteSQL( $sql );

   print "SQL:$sql\n" if($opt_s);

   my $sql_ref = $apiis->DataBase->user_sql($sql);
   $apiis->check_status;
   #$apiis->error->print if($apiis->error and $opt_d);


   my @MO_choices; 
   @choices = ('');
####   while( my @ary = $sth->fetchrow_array) {
   while( my $ary_ref = $sql_ref->handle->fetch) {
      push @choices, join(', ',@{$ary_ref});
      push @MO_choices, [@{$ary_ref}]; # O-type needs array of arrays. 
   }
####   $sth->finish;
   
   # DATATYPE DATE must convert to the users dateformat
   my $ta = $$e{FIELD}{TABLE};
   my $co = $$e{FIELD}{COLUMN};
   my $kk = getKey($ta,$$e{FIELD}{COLUMN},'DB_COLUMN');
   if(${$ta}{$kk}{DATATYPE} and ${$ta}{$kk}{DATATYPE} eq 'DATE') { # convert
      print "CONVERT\n";
      foreach (@choices) {
         my($y,$m,$d) = Decode_Date_NativeRDBMS($_);
         if($d and $m and $y) {
            $_="$d-$m-$y"if($apiis->date_format eq 'EU');
	    $_="$m-$d-$y"if($apiis->date_format eq 'US');
	 }
      }
   }

   $e->configure(-choices=>\@choices) if($$e{FIELD}{TYPE} =~ /^[BNH]/);

   if($$e{FIELD}{TYPE} =~ /^[MO]/) {
      $e->delete(0,'end');
      foreach (@MO_choices) {
	 print "# debug browseDB:[$$e{FIELD}{TYPE}]:CHOICES:@$_\n" if($opt_d);
         $e->insert('end',@$_) if($$e{FIELD}{TYPE} =~ /^M/);
         $e->insert('end',$_) if($$e{FIELD}{TYPE} =~ /^O/);
      }
   }


   if($$e{FIELD}{TYPE} =~ /^[BN]/) {
      my $cn = $e->Subwidget('slistbox')->Subwidget('listbox'); # popup listbox subwidget
      # set height of the popup listbox
      # Problem: listbox height is set by the first time of use and
      # than no more adjustable :-(
      my $nchoices = scalar(@choices);
      if($nchoices > 3 and $nchoices < 10) {
         $cn->configure(-height=>$nchoices);
      } elsif( $nchoices >= 10) {
         $cn->configure(-height=>10);
      } else {
         $cn->configure(-height=>3);
      }

      # set width of the popup listbox
      my $w = 0;
      foreach (@choices) {
         $w = length $_>$w?length $_:$w;
      }
      $cn->configure(-width=>$w+1);
      $cn->update();
   }
   
   # $e->configure(-choices=>\@choices) if($$e{FIELD}{TYPE} =~ /^[BN]/);


} # browseDB


##############################################################################
# extract values from the 'List'-checkrule which were defined in the modelfile
#
# if TABLE and COLUMN are defined in the field section we use this to extract
#                     the values from the CHECK-rule 'List'.
# otherwise we use the indicated table and column values in the parameter ACTION
#                     for 'U'pdates or 'I'nserts
#
sub browseList {

   my ($e) = @_;  # widget
   my @choices;

   if(defined $$e{FIELD}{TABLE} and defined $$e{FIELD}{COLUMN}) {
      $col = getKey($$e{FIELD}{TABLE},$$e{FIELD}{COLUMN} , 'DB_COLUMN');
      if (scalar @{$$e{FIELD}{TABLE}{$col}{CHECK}}) {
	 foreach $method ( @{$$e{FIELD}{TABLE}{$col}{CHECK}} ) {
	    my @args = split /\s+/, $method;
	    push (@choices, @args) if(shift @args eq 'List');
	 }
      }
   }
   elsif ( defined $$e{FIELD}{ACTION}) {
      foreach $act (@{$$e{FIELD}{ACTION}}) {
	 my @list = split /\s+/, $act;
	 if ('IU' =~ /$list[0]/) {
	    $col = getKey($list[1], $list[2], 'DB_COLUMN');
	    if (scalar @{$list[1]{$col}{CHECK}}) {
               foreach $method ( @{$list[1]{$col}{CHECK}} ) {
                  my @args = split /\s+/, $method;
                  push (@choices, @args) if(shift @args eq 'List');
	       }
	    }
	 }
      }
   }

   $e->configure(-choices=>\@choices);

   my $cn = $e->Subwidget('slistbox'); # popup listbox subwidget

   # set height of the popup listbox
   if(scalar @choices < 10) {
      $cn->configure(-height=>scalar @choices);
      $cn->update();
   }

   # set width of the popup listbox
   my $w = 0;
   foreach (@choices) {
      $w = length $_>$w?length $_:$w;
   }
   $cn->configure(-width=>$w+1);
   $cn->update();
 

} # browseList


##############################################################################
# coordinates depends on absolute or relative indicated values
#   relative coordinates have a plus/minus sign 
#   absolute coordinates do not have a sign
sub coordinate {
   
   my ($coord, $xy, $curXY) = @_;

   
   if($coord =~ /^[+-]/) {
      return ($curXY += $coord) if($xy eq 'x');
      return ($curXY += $coord) if($xy eq 'y');
   }

   return ($curXY = $coord) if($xy eq 'x');
   return ($curXY = $coord) if($xy eq 'y');

} # coordinate


##############################################################################
sub xcoord {

   my ($form_ref, $col, $curX) = @_; 
   my $coord = $$form_ref{$col}{XLOCATION};
   return(coordinate($coord,'x', $curX));
   
} # xcoord


##############################################################################
sub ycoord {

   my ($form_ref, $col, $curY) = @_; 
   my $coord = $$form_ref{$col}{YLOCATION};
   return(coordinate($coord,'y', $curY));

} # ycoord

##############################################################################
#
sub motion {

   my ($we) = @_;

   my $widget;

   my $xmouse = $we->pointerx();
   my $ymouse = $we->pointery();
   my $xn = $we->pointerx() - $deltaX;
   my $yn = $we->pointery() - $deltaY;
   my $corx = 0;
   my $cory = 0;

   # Grid for easier alignment in FormDesigner.
   use vars qw / $xgrid $ygrid /;
   if($xgrid and $xn%$xgrid != 0 and %yaffd) {
      $xn -= $xn%$xgrid;
   }
   if($ygrid and $yn%$ygrid != 0 and %yaffd) {
      $yn -= $yn%$ygrid;
   }

   # special behavier for the Compound widgets
   # BrowseEntry and DateEntry

   #BrowseEntry's parent is labentry
   if($we->parent()->name() =~ /labentry/){
      my $browseentryframe = $we->parent()->parent()->parent();
      $widget = $browseentryframe;
      $_xentry = $xn + 1;
      $_yentry = $yn - 20;
      $corx = $xgrid-1;
   }
   
   # DateEntry's parent is dateentry
   elsif($we->parent()->name() =~ /dateentry/){
      my $entryframe = $we->parent()->parent();
      $widget = $entryframe;
      $_xentry = $xn;
      $_yentry = $yn - 19;
      $cory = -1;
   }
   
   # Scrolled's parent is text
   elsif($we->name() =~ /text/){
      my $textframe = $we->parent();
      $widget = $textframe;
      $_xentry = $xn;
      $_yentry = $yn - 20;
   }
   
   # or Scrolled's parent is listbox
   elsif($we->name() =~ /listbox/){
      my $listframe = $we->parent();
      $widget = $listframe;
      $_xentry = $xn;
      $_yentry = $yn - 20;
   }
   
   # button
   elsif($we->name() =~ /button/){
      $widget = $we;
      $_xentry = $xn;
      $_yentry = $yn - 20;
   }
   
   # other widgets Entry / Label / Canvas
   else {
      if($we->name() =~ /entry/){
         $_xentry = $xn;
         $_yentry = $yn - 20;
      }
      elsif($we->name() =~ /canvas/){
         $_xentry = $xn + 9;
         $_yentry = $yn - 8;
      }
      elsif($we->name() =~ /clock/){
         $_xentry = $xn + 0;
         $_yentry = $yn - 0;
      } else {
         $_xentry = $xn;
         $_yentry = $yn;
      }
      $widget = $we;
   }
   
   # put x/y coordinates into the Entry-field, except for FormDesigner
   $$widget{FIELD}{DATA}="$_xentry:$_yentry" if(!%yaffd);

   if(%yaffd) {
   # put x/y coordinates into hash of FormDesigner
      $yaffd{$$widget{SECTION}}{XLOCATION} = $_xentry + $corx; 
      $yaffd{$$widget{SECTION}}{YLOCATION} = $_yentry + $cory; 
      $widget->place('-x'=>$xn + $corx, '-y'=>$yn + $cory);
   } else {
      $widget->place('-x'=>$xn, '-y'=>$yn);
   }

} # motion

##############################################################################
#
sub move {
   
   my ($we) = @_;
   my $widget;
   my @info;


   # change mouse cursor
   #  store current cursor for later restore ( sub recurs )
   $_cursor=$we->cget(-cursor);

   # set cursor to fleur
   $we->configure(-cursor=>'fleur');
   $_cursorFlag = 1;     # mark as changed


   # special behavier for the Compound widgets
   # BrowseEntry, DateEntry and Scrolled widgets
   # BrowseEntry's parent is labentry
   if($we->parent()->name() =~ /labentry/){
      my $browseentryframe = $we->parent()->parent()->parent();
      $widget = $browseentryframe;
      $widgetname = $we->parent()->parent()->parent()->name();
   }
   
   #DateEntry's parent is dateentry
   elsif($we->parent()->name() =~ /dateentry/){
      my $entryframe = $we->parent()->parent();
      $widget = $entryframe;
      $widgetname = $we->parent()->name();
   }

   #Scrolled's parent is text
   elsif($we->name() =~ /text/){
      my $textframe = $we->parent();
      $widget = $textframe;
      $widgetname = $we->name();
   }

   #or Scrolled's parent is listbox
   elsif($we->name() =~ /listbox/){
      my $listframe = $we->parent();
      $widget = $listframe;
      $widgetname = $we->name();
   }

   # other widgets
   else {
      $widget = $we;
      $widgetname = $we->name();
   }
      
   @info = $widget->placeInfo();
   if(@info) { # not for frames
      $deltaX = $widget->pointerx() - $info[1];
      $deltaY = $widget->pointery() - $info[5];
   } else {
      $deltaX = $widget->pointerx();
      $deltaY = $widget->pointery();
   }


   # which field
   ## $_widgetSection = $$widget{SECTION};

   # print "Widget field:$_widgetSection\n" if($opt_d); 
   print "Widget name:$widgetname\n" if($opt_d); 
   print "Widget info:@info\n" if($opt_d); 


   # calculate x,y for the first time
   motion($we); 

   # Field status window
   fieldStatusWin($widget);

} # move


##############################################################################
# after move/motion this subroutine restores the cursor
sub recurs {

   my ($we) = @_;
   if($_cursorFlag == 1) {
      $we->configure(-cursor=>$_cursor);
      $_cursorFlag = 0;
   }

} # recurs


##############################################################################
#
sub fieldStatusWin {
   
   use Tk::LabEntry;
   Tk::LabEntry->require_version('3.009');

   # for the FormDesigner we don't need this window
   return if(%yaffd);

   my $widget = shift;

   my $top = $$widget{FORM}{GENERAL}{TOPLEVEL};
   my $form = $$widget{FORM};
   $_widgetSection = $$widget{SECTION};

   my $font = $top->fontCreate(-family=>'helvetica',-size=>'10');

   # toplevel status-window incl. frame
   if(! Exists($_statwin)) {
      $_statwin=$top->Toplevel(-title=>'Status');
      $statusFrame = $_statwin->Frame(-relief=>'groove',-borderwidth=>4,
			)->pack(-anchor=>'n',-fill => 'x',-expand=>1);

   }

  
   # Section 
   if(! Exists($sectionField)) {
      $sectionField = $statusFrame->LabEntry(-textvariable=>\$_widgetSection,
                       -label=>' Section',
       		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
       		       ##-labelPack=>[-side=>'left'] with some LabEntry-versions
		       #                            this doesn't work :-(
		       #                            we use configure instead
       		       )->pack(-anchor=>'e');
      $sectionField->configure(-labelPack=>[-side=>'left']);
   }
  
   # TITLE
   if($_widgetSection eq 'GENERAL') {
   $_widgetTitle = $$form{$_widgetSection}{TITLE};
      if(! Exists($titleField)) {
	 $titleField = $statusFrame->LabEntry(-textvariable=>\$_widgetTitle,
			  -label=>'TITLE',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $titleField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($titleField)) {
      $titleField->destroy();
   }

   # MODEL
   if($_widgetSection eq 'GENERAL') {
   $_widgetModel = $$form{$_widgetSection}{MODEL};
      if(! Exists($modelField)) {
	 $modelField = $statusFrame->LabEntry(-textvariable=>\$_widgetModel,
			  -label=>'MODEL',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $modelField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($modelField)) {
      $modelField->destroy();
   }

   # TITLEFONT
   if($_widgetSection eq 'GENERAL') {
   $_widgetTF = $$form{$_widgetSection}{TITLEFONT};
      if(! Exists($tfontField)) {
	 $tfontField = $statusFrame->LabEntry(-textvariable=>\$_widgetTF,
			  -label=>'TITLEFONT',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $tfontField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($tfontField)) {
      $tfontField->destroy();
   }  
   
   # NORMALFONT
   if($_widgetSection eq 'GENERAL') {
   $_widgetNF = $$form{$_widgetSection}{NORMALFONT};
      if(! Exists($nfontField)) {
	 $nfontField = $statusFrame->LabEntry(-textvariable=>\$_widgetNF,
			  -label=>'NORMALFONT',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $nfontField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($nfontField)) {
      $nfontField->destroy();
   }  
   
   # LABELFONT
   if($_widgetSection eq 'GENERAL') {
   $_widgetLF = $$form{$_widgetSection}{LABELFONT};
      if(! Exists($lfontField)) {
	 $lfontField = $statusFrame->LabEntry(-textvariable=>\$_widgetLF,
			  -label=>'LABELFONT',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $lfontField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($lfontField)) {
      $lfontField->destroy();
   }  
   
   # BUTTONFONT
   if($_widgetSection eq 'GENERAL') {
   $_widgetBF = $$form{$_widgetSection}{BUTTONFONT};
      if(! Exists($bfontField)) {
	 $bfontField = $statusFrame->LabEntry(-textvariable=>\$_widgetBF,
			  -label=>'BUTTONFONT',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $bfontField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($bfontField)) {
      $bfontField->destroy();
   }  
   
   # CONJUNCTION
   if($_widgetSection eq 'GENERAL') {
   $_widgetCon = $$form{$_widgetSection}{CONJUNCTION};
      if(! Exists($conField)) {
	 $conField = $statusFrame->LabEntry(-textvariable=>\$_widgetCon,
			  -label=>'CONJUNCTION',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $conField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($conField)) {
      $conField->destroy();
   }

   # ORDER
   if($_widgetSection eq 'GENERAL') {
   $_widgetOrder = $$form{$_widgetSection}{ORDER};
      if(! Exists($orderField)) {
	 $orderField = $statusFrame->LabEntry(-textvariable=>\$_widgetOrder,
			  -label=>'ORDER',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $orderField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($orderField)) {
      $orderField->destroy();
   }

   # ERRCOLOR
   if($_widgetSection eq 'GENERAL') {
   $_widgetErrC = $$form{$_widgetSection}{ERRCOLOR};
      if(! Exists($errcoField)) {
	 $errcoField = $statusFrame->LabEntry(-textvariable=>\$_widgetErrC,
			  -label=>'ERRCOLOR',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $errcoField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($errcoField)) {
      $errcoField->destroy();
   }

   # STARTUP
   if($_widgetSection eq 'GENERAL') {
   $_widgetStart = $$form{$_widgetSection}{STARTUP};
      if(! Exists($startField)) {
	 $startField = $statusFrame->LabEntry(-textvariable=>\$_widgetStart,
			  -label=>'STARTUP',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $startField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($startField)) {
      $startField->destroy();
   }   

   # BALLOON 
   if($_widgetSection eq 'GENERAL') {
   $_widgetBalloon = $$form{$_widgetSection}{BALLOON};
      if(! Exists($balloonField)) {
         $balloonField = $statusFrame->LabEntry(-textvariable=>\$_widgetBalloon,
                          -label=>'BALLOON',
                          -state=>'disabled',
                          -width=>20,
                          -font=>$font,
                          ##-labelPack=>[-side=>'left']
                          )->pack(-anchor=>'e');
         $balloonField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($balloonField)) {
      $balloonField->destroy();
   }
 
   # BALLOONBG
   if($_widgetSection eq 'GENERAL') {
   $_widgetBalloonbg = $$form{$_widgetSection}{BALLOONBG};
      if(! Exists($balloonbgField)) {
         $balloonbgField = $statusFrame->LabEntry(-textvariable=>\$_widgetBalloonbg,
                          -label=>'BALLOONBG',
                          -state=>'disabled',
                          -width=>20,
                          -font=>$font,
                          ##-labelPack=>[-side=>'left']
                          )->pack(-anchor=>'e');
         $balloonbgField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($balloonbgField)) {
      $balloonbgField->destroy();
   }
 

   # BALLOONWAIT
   if($_widgetSection eq 'GENERAL') {
   $_widgetBalloonWAIT = $$form{$_widgetSection}{BALLOONWAIT};
      if(! Exists($balloonWaitField)) {
         $balloonWaitField = $statusFrame->LabEntry(-textvariable=>\$_widgetBalloonWAIT,
                          -label=>'BALLOONWAIT',
                          -state=>'disabled',
                          -width=>20,
                          -font=>$font,
                          ##-labelPack=>[-side=>'left']
                          )->pack(-anchor=>'e');
         $balloonWaitField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($balloonWaitField)) {
      $balloonWaitField->destroy();
   }
 
   # TYPE
   $_widgetType = $$form{$_widgetSection}{TYPE} ?
                              $$form{$_widgetSection}{TYPE} : '';
   if($_widgetType =~ /^[EDLBCAITMOPNUR]/) {
      if(! Exists($typeField)) {
	 $typeField = $statusFrame->LabEntry(-textvariable=>\$_widgetType,
			  -label=>'TYPE',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $typeField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($typeField)) {
      $typeField->destroy();
   }

   # LABEL
   $_widgetLabel = $$form{$_widgetSection}{LABEL};
   if($_widgetType =~ /^[EDLBCAITMOPNR]/) {
      if(! Exists($labelField)) {
	 $labelField = $statusFrame->LabEntry(-textvariable=>\$_widgetLabel,
			  -label=>'LABEL',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  #-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $labelField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($labelField)) {
      $labelField->destroy();
   }

  
   # XLOCATION
   $_widgetX = $$form{$_widgetSection}{XLOCATION};
   if($_widgetType =~ /^[EDLBCAITMOPNUR]/) {
      if(! Exists($xlocField)) {
	 $xlocField = $statusFrame->Frame()
				->pack(-anchor=>'n',-fill => 'x',-expand=>1);
	 $xlocField->LabEntry(-textvariable=>\$_xentry,
			  -label=>' cur-X',
			  -state=>'disabled',
			  -width=>5,
			  -font=>$font,
			  #-labelPack=>[-side=>'left']
			  )->pack(-side=>'right')
			     ->configure(-labelPack=>[-side=>'left']);
	 $xlocField->LabEntry(-textvariable=>\$_widgetX,
			  -label=>'XLOCATION',
			  -state=>'disabled',
			  -width=>6,
			  -font=>$font,
			  #-labelPack=>[-side=>'left']
			  )->pack(-side=>'right')
			     ->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($xlocField)) {
      $xlocField->destroy();
   }

   # YLOCATION
   $_widgetY = $$form{$_widgetSection}{YLOCATION};
   if($_widgetType =~ /^[EDLBCAITMOPNUR]/) {
      if(! Exists($ylocField)) {
	 $ylocField = $statusFrame->Frame()
				->pack(-anchor=>'n',-fill => 'x',-expand=>1);
	 $ylocField->LabEntry(-textvariable=>\$_yentry,
			  -label=>' cur-Y',
			  -state=>'disabled',
			  -width=>5,
			  -font=>$font,
			  #-labelPack=>[-side=>'left']
			  )->pack(-side=>'right')
			     ->configure(-labelPack=>[-side=>'left']);
	 $ylocField->LabEntry(-textvariable=>\$_widgetY,
			  -label=>'YLOCATION',
			  -state=>'disabled',
			  -width=>6,
			  -font=>$font,
			  #-labelPack=>[-side=>'left']
			  )->pack(-side=>'right')
			     ->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($ylocField)) {
      $ylocField->destroy();
   }

   # FIELDLENGTH
   $_widgetFieldLength = $$form{$_widgetSection}{FIELDLENGTH};
   if($_widgetType =~ /^[EDLBCNO]/) {
      if(! Exists($fldField)) {
         $fldField = $statusFrame->LabEntry(-textvariable=>\$_widgetFieldLength,
	               -label=>'FIELDLENGTH',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $fldField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($fldField)) {
      $fldField->destroy();
   }
 
   # HEIGHT 
   $_widgetheight = $$form{$_widgetSection}{HEIGHT} ?
                             $$form{$_widgetSection}{HEIGHT} : undef;
   if($_widgetType =~ /^[ITMOPR]/ or $_widgetSection eq 'GENERAL') {
      if(! Exists($heightfield)) {
         $heightfield = $statusFrame->LabEntry(-textvariable=>\$_widgetheight,
	               -label=>'HEIGHT',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $heightfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($heightfield)) {
      $heightfield->destroy();
   }

   # WIDTH
   $_widgetwidth = $$form{$_widgetSection}{WIDTH} ?
                             $$form{$_widgetSection}{WIDTH} : undef;
   if($_widgetType =~ /^[ITMOP]/ or $_widgetSection eq 'GENERAL') {
      if(! Exists($widthfield)) {
         $widthfield = $statusFrame->LabEntry(-textvariable=>\$_widgetwidth,
	               -label=>'WIDTH',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $widthfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($widthfield)) {
      $widthfield->destroy();
   }

   # TABLE
   $_widgetTable = $$form{$_widgetSection}{TABLE} ?
                             $$form{$_widgetSection}{TABLE} : undef;
   if($_widgetType =~ /^[EDLBCTNM]/) {
      if(! Exists($tableField)) {
         $tableField = $statusFrame->LabEntry(-textvariable=>\$_widgetTable,
	               -label=>'TABLE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $tableField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($tableField)) {
      $tableField->destroy();
   }

   # COLUMN
   $_widgetColumn = $$form{$_widgetSection}{COLUMN} ?
                             $$form{$_widgetSection}{COLUMN} : undef;
   if($_widgetType =~ /^[EDLBCTNM]/) {
      if(! Exists($columnField)) {
         $columnField = $statusFrame->LabEntry(-textvariable=>\$_widgetColumn,
	               -label=>'COLUMN',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $columnField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($columnField)) {
      $columnField->destroy();
   }

   # RELATION
   $_widgetRel = $$form{$_widgetSection}{RELATION} ?
                             $$form{$_widgetSection}{RELATION} : undef;
   if($_widgetType =~ /^[EDLBCTNM]/) {
      if(! Exists($relationField)) {
         $relationField = $statusFrame->LabEntry(-textvariable=>\$_widgetRel,
	               -label=>'RELATION',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $relationField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($relationField)) {
      $relationField->destroy();
   }
  
   # CLEAR
   $_widgetClear = $$form{$_widgetSection}{CLEAR} ?
                             $$form{$_widgetSection}{CLEAR} : undef;
   if($_widgetType =~ /^[EDLBCTMNO]/) {
      if(! Exists($clearField)) {
         $clearField = $statusFrame->LabEntry(-textvariable=>\$_widgetClear,
	               -label=>'CLEAR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $clearField ->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($clearField)) {
      $clearField->destroy();
   }

   # OPERATOR
   $_widgetOperator = $$form{$_widgetSection}{OPERATOR} ?
                             $$form{$_widgetSection}{OPERATOR} : undef;
   if($_widgetType =~ /^[EDLBCTMN]/) {
      if(! Exists($opField)) {
         $opField = $statusFrame->LabEntry(-textvariable=>\$_widgetOperator,
	               -label=>'OPERATOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $opField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($opField)) {
      $opField->destroy();
   } 
   
   # UPDATE
   $_widgetUpdate = $$form{$_widgetSection}{UPDATE} ?
                             $$form{$_widgetSection}{UPDATE} : undef;
   if($_widgetType =~ /^[EDLBCTMN]/) {
      if(! Exists($updateField)) {
         $updateField = $statusFrame->LabEntry(-textvariable=>\$_widgetUpdate,
	               -label=>'UPDATE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $updateField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($updateField)) {
      $updateField->destroy();
   }

  # ACTION
   $_widgetAction = $$form{$_widgetSection}{ACTION} ?
                             join(',',@{$$form{$_widgetSection}{ACTION}}):undef;
   if($_widgetType =~ /^[EDLBCTMNOR]/) {
      if(! Exists($actionField)) {
         $actionField = $statusFrame->LabEntry(-textvariable=>\$_widgetAction,
	               -label=>'ACTION',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $actionField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($actionField)) {
      $actionField->destroy();
   }
   
   # BGCOLOR
   $_widgetBGColor = $$form{$_widgetSection}{BGCOLOR} ? 
                             $$form{$_widgetSection}{BGCOLOR} : undef;
   if($_widgetType =~ /^[EDLBCITMOPNUR]/ or $_widgetSection eq 'GENERAL') {
      if(! Exists($bgcolorField)) {
         $bgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetBGColor,
	               -label=>'BGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $bgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($bgcolorField)) {
      $bgcolorField->destroy();
   }

   # FGCOLOR
   $_widgetFGColor = $$form{$_widgetSection}{FGCOLOR} ?
                             $$form{$_widgetSection}{FGCOLOR} : undef;
   if($_widgetType =~ /^[EDLBCAITMOPNUR]/ or $_widgetSection eq 'GENERAL') {
      if(! Exists($fgcolorField)) {
         $fgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetFGColor,
	               -label=>'FGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $fgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($fgcolorField)) {
      $fgcolorField->destroy();
   }

   # BALLOONMSG
   $_widgetBALLOONMSG = $$form{$_widgetSection}{BALLOONMSG} ?
                             $$form{$_widgetSection}{BALLOONMSG} : undef;
   if($_widgetType =~ /^[EDLBCAITMOPNUR]/ or $_widgetSection eq 'GENERAL') {
      if(! Exists($balloonmsgField)) {
         $balloonmsgField = $statusFrame->LabEntry(
                       -textvariable=>\$_widgetBALLOONMSG,
	               -label=>'BALLOONMSG',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $balloonmsgField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($balloonmsgField)) {
      $balloonmsgField->destroy();
   }

   # ENTER  (focusIn)
   $_widgetfocusIn = $$form{$_widgetSection}{ENTER} ?
                             $$form{$_widgetSection}{ENTER} : undef;
   if($_widgetType =~ /^[ELBCTMNO]/) {
      if(! Exists($focusInfield)) {
         $focusInfield = $statusFrame->LabEntry(-textvariable=>\$_widgetfocusIn,
	               -label=>'ENTER',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $focusInfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($focusInfield)) {
      $focusInfield->destroy();
   }

   # LEAVE  (focusOut)
   $_widgetfocusOut = $$form{$_widgetSection}{LEAVE} ?
                             $$form{$_widgetSection}{LEAVE} : undef;
   if($_widgetType =~ /^[ELBCTMNO]/) {
      if(! Exists($focusOutfield)) {
         $focusOutfield=$statusFrame->LabEntry(-textvariable=>\$_widgetfocusOut,
	               -label=>'LEAVE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $focusOutfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($focusOutfield)) {
      $focusOutfield->destroy();
   }

   # PASSWD   
   $_widgetpwd = $$form{$_widgetSection}{PASSWD} ?
                             $$form{$_widgetSection}{PASSWD} : undef;
   if($_widgetType =~ /^[E]/) {
      if(! Exists($pwdfield)) {
         $pwdfield = $statusFrame->LabEntry(-textvariable=>\$_widgetpwd,
	               -label=>'PASSWD',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $pwdfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($pwdfield)) {
      $pwdfield->destroy();
   }


   # FILE (image file name)  
   $_widgetfile = $$form{$_widgetSection}{FILE} ?
                             $$form{$_widgetSection}{FILE} : undef;
   if($_widgetType =~ /^[I]/) {
      if(! Exists($filefield)) {
         $filefield = $statusFrame->LabEntry(-textvariable=>\$_widgetfile,
	               -label=>'FILE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $filefield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($filefield)) {
      $filefield->destroy();
   }

   # BORDER
   $_widgetbord = $$form{$_widgetSection}{BORDER} ?
                             $$form{$_widgetSection}{BORDER} : undef;
   if($_widgetType =~ /^[ITMOPUR]/) {
      if(! Exists($borderfield)) {
         $borderfield = $statusFrame->LabEntry(-textvariable=>\$_widgetbord,
	               -label=>'BORDER',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $borderfield ->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($borderfield)) {
      $borderfield->destroy();
   }

   # RELIEF
   $_widgetrelief = $$form{$_widgetSection}{RELIEF} ?
                             $$form{$_widgetSection}{RELIEF} : undef;
   if($_widgetType =~ /^[ITMOPUR]/) {
      if(! Exists($relieffield)) {
         $relieffield = $statusFrame->LabEntry(-textvariable=>\$_widgetrelief,
	               -label=>'RELIEF',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $relieffield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($relieffield)) {
      $relieffield->destroy();
   }

   # SCROLLBAR
   $_widgetscroll = $$form{$_widgetSection}{SCROLLBAR} ?
                             $$form{$_widgetSection}{SCROLLBAR} : undef;
   if($_widgetType =~ /^[TMO]/) {
      if(! Exists($scrollfield)) {
         $scrollfield = $statusFrame->LabEntry(-textvariable=>\$_widgetscroll,
	               -label=>'SCROLLBAR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $scrollfield ->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($scrollfield)) {
      $scrollfield->destroy();
   }

   # WRAP  textwidget
   $_widgetwrap = $$form{$_widgetSection}{WRAP} ?
                             $$form{$_widgetSection}{WRAP} : undef;
   if($_widgetType =~ /^[T]/) {
      if(! Exists($wrapfield)) {
         $wrapfield = $statusFrame->LabEntry(-textvariable=>\$_widgetwrap,
	               -label=>'WRAP',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $wrapfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($wrapfield)) {
      $wrapfield->destroy();
   }

   # MODE (selection mode)
   $_widgetmode = $$form{$_widgetSection}{MODE} ?
                             $$form{$_widgetSection}{MODE} : undef;
   if($_widgetType =~ /^[MO]/) {
      if(! Exists($modefield)) {
         $modefield = $statusFrame->LabEntry(-textvariable=>\$_widgetmode,
	               -label=>'MODE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $modefield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($modefield)) {
      $modefield->destroy();
   }

   # COMMAND (push-button)
   $_widgetpushb = $$form{$_widgetSection}{COMMAND} ?
                             $$form{$_widgetSection}{COMMAND} : undef;
   if($_widgetType =~ /^[PR]/) {
      if(! Exists($pushbfield)) {
         $pushbfield = $statusFrame->LabEntry(-textvariable=>\$_widgetpushb,
	               -label=>'COMMAND',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $pushbfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($pushbfield)) {
      $pushbfield->destroy();
   }

   # TEXT (push-button)
   $_widgettext = $$form{$_widgetSection}{TEXT} ?
                             $$form{$_widgetSection}{TEXT} : undef;
   if($_widgetType =~ /^[OPR]/) {
      if(! Exists($textbfield)) {
         $textbfield = $statusFrame->LabEntry(-textvariable=>\$_widgettext,
	               -label=>'TEXT',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $textbfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($textbfield)) {
      $textbfield->destroy();
   }

   # SORTMODE
   $_widgetsortmode = $$form{$_widgetSection}{SORTMODE} ?
                             $$form{$_widgetSection}{SORTMODE} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($sortmodeField)) {
         $sortmodeField = $statusFrame->LabEntry(-textvariable=>\$_widgetsortmode,
	               -label=>'SORTMODE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $sortmodeField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($sortmodeField)) {
      $sortmodeField->destroy();
   }

   # SORTABLE
   $_widgetsortable = $$form{$_widgetSection}{SORTABLE} ?
                             $$form{$_widgetSection}{SORTABLE} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($sortableField)) {
         $sortableField = $statusFrame->LabEntry(-textvariable=>\$_widgetsortable,
	               -label=>'SORTABLE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $sortableField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($sortableField)) {
      $sortableField->destroy();
   }

   # RESIZEABLE
   $_widgetresizeable = $$form{$_widgetSection}{RESIZEABLE} ?
                             $$form{$_widgetSection}{RESIZEABLE} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($resizeableField)) {
         $resizeableField = $statusFrame->LabEntry(-textvariable=>\$_widgetresizeable,
	               -label=>'RESIZEABLE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $resizeableField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($resizeableField)) {
      $resizeableField->destroy();
   }

   # MOVEABLE
   $_widgetmoveable = $$form{$_widgetSection}{MOVEABLE} ?
                             $$form{$_widgetSection}{MOVEABLE} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($moveableField)) {
         $moveableField = $statusFrame->LabEntry(-textvariable=>\$_widgetmoveable,
	               -label=>'MOVEABLE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $moveableField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($moveableField)) {
      $moveableField->destroy();
   }

   # HEADERFGCOLOR
   $_widgetheaderFGColor = $$form{$_widgetSection}{HEADERFGCOLOR} ?
                             $$form{$_widgetSection}{HEADERFGCOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($headerfgcolorField)) {
         $headerfgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetheaderFGColor,
	               -label=>'HEADERFGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $headerfgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($headerfgcolorField)) {
      $headerfgcolorField->destroy();
   }

   # HEADERBGCOLOR
   $_widgetheaderBGColor = $$form{$_widgetSection}{HEADERBGCOLOR} ?
                             $$form{$_widgetSection}{HEADERBGCOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($headerbgcolorField)) {
         $headerbgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetheaderBGColor,
	               -label=>'HEADERBGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $headerbgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($headerbgcolorField)) {
      $headerbgcolorField->destroy();
   }

   # LISTBOXFGCOLOR
   $_widgetlistboxFGColor = $$form{$_widgetSection}{LISTBOXFGCOLOR} ?
                             $$form{$_widgetSection}{LISTBOXFGCOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($listboxfgcolorField)) {
         $listboxfgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetlistboxFGColor,
	               -label=>'LISTBOXFGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $listboxfgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($listboxfgcolorField)) {
      $listboxfgcolorField->destroy();
   }

   # LISTBOXBGCOLOR
   $_widgetlistboxBGColor = $$form{$_widgetSection}{LISTBOXBGCOLOR} ?
                             $$form{$_widgetSection}{LISTBOXBGCOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($listboxbgcolorField)) {
         $listboxbgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetlistboxBGColor,
	               -label=>'LISTBOXBGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $listboxbgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($listboxbgcolorField)) {
      $listboxbgcolorField->destroy();
   }

   # SELECTFGCOLOR
   $_widgetselectFGColor = $$form{$_widgetSection}{SELECTFGCOLOR} ?
                             $$form{$_widgetSection}{SELECTFGCOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($selectfgcolorField)) {
         $selectfgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetselectFGColor,
	               -label=>'SELECTFGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $selectfgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($selectfgcolorField)) {
      $selectfgcolorField->destroy();
   }

   # FRAMECOLOR
   $_widgetframeColor = $$form{$_widgetSection}{FRAMECOLOR} ?
                             $$form{$_widgetSection}{FRAMECOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($framecolorField)) {
         $framecolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetframeColor,
	               -label=>'FRAMECOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $framecolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($framecolorField)) {
      $framecolorField->destroy();
   }
   
   # SELECTBGCOLOR
   $_widgetselectBGColor = $$form{$_widgetSection}{SELECTBGCOLOR} ?
                             $$form{$_widgetSection}{SELECTBGCOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($selectbgcolorField)) {
         $selectbgcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetselectBGColor,
	               -label=>'SELECTBGCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $selectbgcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($selectbgcolorField)) {
      $selectbgcolorField->destroy();
   }

   # SEPARATORCOLOR
   $_widgetseparatorColor = $$form{$_widgetSection}{SEPARATORCOLOR} ?
                             $$form{$_widgetSection}{SEPARATORCOLOR} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($separatorcolorField)) {
         $separatorcolorField = $statusFrame->LabEntry(-textvariable=>\$_widgetseparatorColor,
	               -label=>'SEPARATORCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $separatorcolorField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($separatorcolorField)) {
      $separatorcolorField->destroy();
   }

   # SEPARATORWIDTH
   $_widgetseparatorWidth = $$form{$_widgetSection}{SEPARATORWIDTH} ?
                             $$form{$_widgetSection}{SEPARATORWIDTH} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($separatorwidthField)) {
         $separatorwidthField = $statusFrame->LabEntry(-textvariable=>\$_widgetseparatorWidth,
	               -label=>'SEPARATORWIDTH',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $separatorwidthField->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($separatorwidthField)) {
      $separatorwidthField->destroy();
   }
   # some specials for TYPE=U
   # tickCOLOR
   $_widgettickcol = $$form{$_widgetSection}{tickCOLOR} ?
                             $$form{$_widgetSection}{tickCOLOR} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($tickcfield)) {
         $tickcfield = $statusFrame->LabEntry(-textvariable=>\$_widgettickcol,
	               -label=>'tickCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $tickcfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($tickcfield)) {
      $tickcfield->destroy();
   }

   # secsCOLOR
   $_widgetsecscol = $$form{$_widgetSection}{secsCOLOR} ?
                             $$form{$_widgetSection}{secsCOLOR} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($secscfield)) {
         $secscfield = $statusFrame->LabEntry(-textvariable=>\$_widgetsecscol,
	               -label=>'secsCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $secscfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($secscfield)) {
      $secscfield->destroy();
   }

   # timeCOLOR
   $_widgettimecol = $$form{$_widgetSection}{timeCOLOR} ?
                             $$form{$_widgetSection}{timeCOLOR} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($timecfield)) {
         $timecfield = $statusFrame->LabEntry(-textvariable=>\$_widgettimecol,
	               -label=>'timeCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $timecfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($timecfield)) {
      $timecfield->destroy();
   }

   # dateCOLOR
   $_widgetdatecol = $$form{$_widgetSection}{dateCOLOR} ?
                             $$form{$_widgetSection}{dateCOLOR} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($datecfield)) {
         $datecfield = $statusFrame->LabEntry(-textvariable=>\$_widgetdatecol,
	               -label=>'dateCOLOR',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $datecfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($datecfield)) {
      $datecfield->destroy();
   }

   # ANALOGSCALE
   $_widgetanascale = $$form{$_widgetSection}{ANALOGSCALE} ?
                             $$form{$_widgetSection}{ANALOGSCALE} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($anascfield)) {
         $anascfield = $statusFrame->LabEntry(-textvariable=>\$_widgetanascale,
	               -label=>'ANALOGSCALE',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $anascfield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($anascfield)) {
      $anascfield->destroy();
   }

   # TICKFREQ
   $_widgettickf = $$form{$_widgetSection}{TICKFREQ} ?
                             $$form{$_widgetSection}{TICKFREQ} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($tickffield)) {
         $tickffield = $statusFrame->LabEntry(-textvariable=>\$_widgettickf,
	               -label=>'TICKFREQ',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $tickffield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($tickffield)) {
      $tickffield->destroy();
   }

   # TIMEFORMAT
   $_widgettimef = $$form{$_widgetSection}{TIMEFORMAT} ?
                             $$form{$_widgetSection}{TIMEFORMAT} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($timeffield)) {
         $timeffield = $statusFrame->LabEntry(-textvariable=>\$_widgettimef,
	               -label=>'TIMEFORMAT',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $timeffield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($timeffield)) {
      $timeffield->destroy();
   }

   # DATEFORMAT
   $_widgetdatef = $$form{$_widgetSection}{DATEFORMAT} ?
                             $$form{$_widgetSection}{DATEFORMAT} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($dateffield)) {
         $dateffield = $statusFrame->LabEntry(-textvariable=>\$_widgetdatef,
	               -label=>'DATEFORMAT',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $dateffield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($dateffield)) {
      $dateffield->destroy();
   }

   # TIMEFONT
   $_widgettimefo = $$form{$_widgetSection}{TIMEFONT} ?
                             $$form{$_widgetSection}{TIMEFONT} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($timefofield)) {
         $timefofield = $statusFrame->LabEntry(-textvariable=>\$_widgettimefo,
	               -label=>'TIMEFONT',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $timefofield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($timefofield)) {
      $timefofield->destroy();
   }

   # DATEFONT
   $_widgetdatefo = $$form{$_widgetSection}{DATEFONT} ?
                             $$form{$_widgetSection}{DATEFONT} : undef;
   if($_widgetType =~ /^[U]/) {
      if(! Exists($datefofield)) {
         $datefofield = $statusFrame->LabEntry(-textvariable=>\$_widgetdatefo,
	               -label=>'DATEFONT',
		       -state=>'disabled',
		       -width=>20,
                       -font=>$font,
		       #-labelPack=>[-side=>'left']
		       )->pack(-anchor=>'e');
         $datefofield->configure(-labelPack=>[-side=>'left']);
      }
   } elsif(Exists($datefofield)) {
      $datefofield->destroy();
   }

   # FONT
   $_widgetfo = $$form{$_widgetSection}{FONT} ?
                             $$form{$_widgetSection}{FONT} : undef;
   if($_widgetType =~ /^[AOR]/) {
      if(! Exists($fontField)) {
	 $fontField = $statusFrame->LabEntry(-textvariable=>\$_widgetfo,
			  -label=>'FONT',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $fontField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($fontField)) {
      $fontField->destroy();
   }

   # LISTBOXFONT
   $_widgetlifo = $$form{$_widgetSection}{LISTBOXFONT} ?
                             $$form{$_widgetSection}{LISTBOXFONT} : undef;
   if($_widgetType =~ /^[O]/) {
      if(! Exists($lifontField)) {
	 $lifontField = $statusFrame->LabEntry(-textvariable=>\$_widgetlifo,
			  -label=>'LISTBOXFONT',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $lifontField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($lifontField)) {
      $lifontField->destroy();
   }
   
   # SELECTCOLOR
   $_widgetsc = $$form{$_widgetSection}{SELECTCOLOR} ?
                             $$form{$_widgetSection}{SELECTCOLOR} : undef;
   if($_widgetType =~ /^[R]/) {
      if(! Exists($selcField)) {
	 $selcField = $statusFrame->LabEntry(-textvariable=>\$_widgetsc,
			  -label=>'SELECTCOLOR',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $selcField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($selcField)) {
      $selcField->destroy();
   }
   
   # SELECTED
   $_widgetsd = $$form{$_widgetSection}{SELECTED} ?
                             $$form{$_widgetSection}{SELECTED} : undef;
   if($_widgetType =~ /^[R]/) {
      if(! Exists($seldField)) {
	 $seldField = $statusFrame->LabEntry(-textvariable=>\$_widgetsd,
			  -label=>'SELECTED',
			  -state=>'disabled',
			  -width=>20,
			  -font=>$font,
			  ##-labelPack=>[-side=>'left']
			  )->pack(-anchor=>'e');
	 $seldField->configure(-labelPack=>[-side=>'left']);
      }

   } elsif(Exists($seldField)) {
      $seldField->destroy();
   }

#   my @sklaven = $statusFrame->packSlaves();
#   foreach(sort @sklaven) {
#      print "Sklave:",$_, $_->name,"\n";
#      print "cget:",$_->cget(-label),"\n";
#      push(@la,$_->cget(-label));
#      $_->pack();
#   }
#   print "labels:", sort(@la),"\n";

   # Revision
   if(! Exists($revfrm) and $$form{GENERAL}{ID}) {
      $revfrm = $_statwin->Frame(-relief=>'groove',-borderwidth=>2,
			)->pack(-anchor=>'n',-fill => 'x',-expand=>1);
      $revf = $revfrm->Entry(-textvariable=>\$$form{GENERAL}{ID},
                                     #-width=>30,
                                     -state => 'disabled')
                            ->pack(-expand=>1,-fill=>'x');
   }

   # Close-button
   if(! Exists($frameb)) {
      $frameb = $_statwin->Frame(-relief=>'groove',-borderwidth=>2,
			)->pack(-anchor=>'n',-fill => 'x',-expand=>1);
      $frameb->Button(-text=>'Close',      # i18n
                      -font=>$font,
                      -command=>sub{$_statwin->toplevel->destroy;
		                    $_statwin=undef}
		       )->pack();
   }
	           

} # fieldStatusWin


##############################################################################
# Ini2ModelHash converts a ini-style configuration file 
#               to a apropriate form or model hash
# usage: Ini2ModelHash ( configfile, hash-reference, [form | model] )
#
#   
#           form  - for ini-style form files
#           model - for database model file
#      initializes the hash     
#      prevents "Use of uninitialized value" warning message
#
sub Ini2ModelHash {

   my ($inifile, $hash_ref, $init) = @_;

   if( ! -f $inifile) {
      $hash_ref->{ERROR} = "error: cannot open $inifile";
      return;
   }

   # use IniConf; # not longer in use
   use Config::IniFiles;


   # my $cfg = IniConf->new( -file => $inifile );
   my $cfg = new Config::IniFiles( -file => $inifile );
   # my $cfg = Config::IniFiles->new( -file => $inifile );

   my @sections = $cfg->Sections;
   foreach $s (@sections) {
      initFormHash($s,$hash_ref) if($init eq 'form');
      initModelHash($s,$hash_ref) if($init eq 'model');
      my @par = $cfg->Parameters($s);
      foreach $p (@par) {
         my $value = $cfg->val($s,$p);
	 $hash_ref->{$s}{$p} = $value;
      }
   }

   return;
} # Ini2ModelHash

sub initFormHash {

   my ($key, $hash_ref) = @_;

   if($key eq 'GENERAL') {
      $hash_ref->{$key}{TITLE}       = '';
      $hash_ref->{$key}{TITLEFONT}   = '';
      $hash_ref->{$key}{LABELFONT}   = '';
      $hash_ref->{$key}{NORMALFONT}  = '';
      $hash_ref->{$key}{HEIGHT}      = '';
      $hash_ref->{$key}{WIDTH}       = '';
      $hash_ref->{$key}{BUTTONFONT}     = '';
      $hash_ref->{$key}{MODEL}       = '';
      $hash_ref->{$key}{ORDER}       = '';
      $hash_ref->{$key}{CONJUNCTION} = '';
      $hash_ref->{$key}{STARTUP}     = '';
      $hash_ref->{$key}{FGCOLOR}     = '';
      $hash_ref->{$key}{BGCOLOR}     = '';
      $hash_ref->{$key}{BALLOON}     = '';
      $hash_ref->{$key}{BALLOONBG}   = '';
      $hash_ref->{$key}{BALLOONWAIT} = '';
      $hash_ref->{$key}{BALLOONMSG}  = '';
   }
   else {
      $hash_ref->{$key}{DATA}        = '';
      $hash_ref->{$key}{ERROR}       = '';
      $hash_ref->{$key}{TYPE}        = '';
      $hash_ref->{$key}{XLOCATION}   = '';
      $hash_ref->{$key}{YLOCATION}   = '';
      $hash_ref->{$key}{FIELDLENGTH} = '';
      $hash_ref->{$key}{LABEL}       = '';
      $hash_ref->{$key}{ACTION}      = '';
      $hash_ref->{$key}{CLEAR}       = '';
      $hash_ref->{$key}{UPDATE}      = '';
      $hash_ref->{$key}{COLUMN}      = '';
      $hash_ref->{$key}{OPERATOR}    = '';
      $hash_ref->{$key}{BORDER}      = '';
      $hash_ref->{$key}{RELIEF}      = '';
      $hash_ref->{$key}{WRAP}        = '';
      $hash_ref->{$key}{HEIGHT}      = '';
      $hash_ref->{$key}{WIDTH}       = '';
      $hash_ref->{$key}{SCROLLBAR}   = '';
      $hash_ref->{$key}{BALLOONMSG}  = '';
      $hash_ref->{$key}{COMMAND}     = '';
      $hash_ref->{$key}{MODE}        = '';
      $hash_ref->{$key}{FILE}        = '';
      $hash_ref->{$key}{TEXT}        = '';
      $hash_ref->{$key}{ENTER}       = '';
      $hash_ref->{$key}{LEAVE}       = '';
   }
} # initFormHash

sub initModelHash {

   my ($key, $hash_ref) = @_;

   if($key ne 'TABLE') {
      $hash_ref->{$key}{DB_COLUMN}       = '';
      # u.s.w
   }
} # initModelHash


##############################################################################
# usage: my $form_ref = initFORM ($formfile, $model_ref)
# return the reference to the form hash
sub initFORM {

   my $form_file = shift;
   my $model_ref = shift;


   #BEGIN {                              # execute before compilation
   #   use Env qw( APIIS_HOME APIIS_LOCAL HOME );     # get environment variable
   #   die "APIIS_HOME is not set!\n" unless $APIIS_HOME;
   #}

   #require "$APIIS_HOME/apiisrc";                   # system defaults
   #require "$HOME/.apiisrc" if -r "$HOME/.apiisrc"; # user settings

   #### use DataBase;

   # use i18n_apiis;
   use Apiis::Misc;
   use form_ulib;               # lib for user defined functions
      
   use Apiis::Model;
   use Apiis::DataBase::Record;
   use Apiis::DataBase::User;

   my %hash;
   my $form = \%hash;
   Ini2ModelHash($form_file, $form, 'form');

   #${$model_ref}  = eval qq{qq{$$form{GENERAL}{MODEL}}};
   #print "MODEL:",${$model_ref},"\n";
   my $project = $$form{GENERAL}{PROJECT}?$$form{GENERAL}{PROJECT}:'';
   print "PROJECT from formfile: $project\n" if($opt_d);
   my $form_user = $$form{GENERAL}{USER}?$$form{GENERAL}{USER}:'';
   print "USER from formfile: $form_user\n" if($opt_d);
   my $passwd = $$form{GENERAL}{PASSWORD}?$$form{GENERAL}{PASSWORD}:'';

#   if( -f ${$model_ref}) { 
   #   print "MODELFILE: ${$model_ref}\n" if($opt_d);

      # authentication
      if(! $apiis->exists_user) {
	 if(! $form_user or ! $passwd) {
	    login(\$project, \$form_user, \$passwd);
	 }
	 
	 my $user_obj = Apiis::DataBase::User->new(
			id => $form_user, password => $passwd);
	 
	 $apiis->join_model($project, userobj=>$user_obj);
	 $apiis->check_status;
	 print $apiis->User->sprint if($opt_d);
	 print "Authenticated: ",$apiis->User->authenticated,"\n" if($opt_d);
      }

   #} else {
   #   print "\n  *** NO DATABASE MODEL GIVEN! ***\n    Please check form file\n"; # i18n 
   #}

   return($form);

} # initFORM



##############################################################################
# usage: buttonBar($top_ref, $form) 
# 
sub buttonBar {

   my ($top_ref, $form) = @_;
   my $top = ${$top_ref};

   my $formfg = $$form{GENERAL}{FGCOLOR} if($$form{GENERAL}{FGCOLOR});
   my $formbg = $$form{GENERAL}{BGCOLOR} if($$form{GENERAL}{BGCOLOR});

   
   $maxRec = 0 if(! defined $maxRec);    # maximal record number
   $curRec = 0 if(! defined $curRec);    # current record number
   $minRec = 0 if(! defined $minRec);    # minimal record number 
   $vonmaxRec = __('von')." $maxRec";            #  "von" : i18n !
   $UpIn = __('Insert');                      # i18n
   

   # BUTTONS=  in general section obsolet now 
   # my $button = lc substr($$form{GENERAL}{BUTTONS},0,1);

   # Fonts
   my $font;
   if($$form{GENERAL}{BUTTONFONT}) {
      $font = $$form{GENERAL}{BUTTONFONT};
   } else {
      if(!$font or index($font,',') ne -1) {
         my($fam,$size,$weight,$slant,$un,$ov) = split(',',$tfont) if($tfont);
         $fam = 'helvetica' if(!$fam);
         $size = 8 if(!$size);
         $weight = 'normal' if(!$weight);
         $slant = 'roman' if(!$slant);
         $un = 0 if(!$un);
         $ov = 0 if(!$ov);
         print "$fam,$size,$weight,$slant,$un,$ov\n" if($opt_d);
         $font = $top->fontCreate(-family=>$fam,
                                     -size=>$size,
                                     -weight=>$weight,
				     -slant=>$slant,
			             -underline=>$un,
				     -overstrike=>$ov);
      }
   }

   # Pixmaps
   my $iconf = $top->Pixmap(-file=>"$APIIS_HOME/lib/images/arrowfirst.xpm");
   my $iconl = $top->Pixmap(-file=>"$APIIS_HOME/lib/images/arrowleft.xpm");
   my $iconr = $top->Pixmap(-file=>"$APIIS_HOME/lib/images/arrowright.xpm");
   my $iconm = $top->Pixmap(-file=>"$APIIS_HOME/lib/images/arrowmax.xpm");
   my $iconn = $top->Pixmap(-file=>"$APIIS_HOME/lib/images/arrownew.xpm");

   ## frame
   my $frame = $top->Frame(-relief=>'sunken',-borderwidth=>4)
		     ->pack(-anchor=>'s',-fill=>'x',-expand=>1);
   $frame->configure(-foreground=>$formfg) if($formfg);
   $frame->configure(-background=>$formbg) if($formbg);

   # Widgets
   my $lab1 = $frame->Label(-text=>__('Record').": ",-font=>$font)  # i18n
		     ->pack(-side=>'left');
   $lab1->configure(-foreground=>$formfg) if($formfg);
   $lab1->configure(-background=>$formbg) if($formbg);

   my $bf = $frame->Button( -image=>$iconf,
	                    -command=>sub{setFirstButton($form)})
		    ->pack(-side=>'left');
   $bf->configure(-background=>$formbg) if($formbg);
   $bf->configure(-foreground=>$formfg) if($formfg);
   $bf->configure(-activeforeground=>$formbg) if($formbg);
   $bf->configure(-activebackground=>$formfg) if($formfg);

   my $bl = $frame->Button( -image=>$iconl,
	                    -command=>sub{setLeftButton($form)})
		    ->pack(-side=>'left');
   $bl->configure(-background=>$formbg) if($formbg);
   $bl->configure(-foreground=>$formfg) if($formfg);
   $bl->configure(-activeforeground=>$formbg) if($formbg);
   $bl->configure(-activebackground=>$formfg) if($formfg);

   my $e = $frame->Entry(-textvariable=>\$curRec,
			 -width=>6,
			 -font=>$font,
		     #   -state=>'disabled',
			 -background => 'gray95')
		       ->pack(-side=>'left');
   $e->configure(-background=>$formbg) if($formbg);
   $e->configure(-foreground=>$formfg) if($formfg);
   $e->bind("<Return>", sub{setform($form)});


   my $br = $frame->Button(-image=>$iconr,
	                    -command=>sub{setRightButton($form)})
		    ->pack(-side=>'left');
   $br->configure(-background=>$formbg) if($formbg);
   $br->configure(-foreground=>$formfg) if($formfg);
   $br->configure(-activeforeground=>$formbg) if($formbg);
   $br->configure(-activebackground=>$formfg) if($formfg);

   my $be = $frame->Button( -image=>$iconm,
	                    -command=>sub{setMaxButton($form)})
		    ->pack(-side=>'left');
   $be->configure(-background=>$formbg) if($formbg);
   $be->configure(-foreground=>$formfg) if($formfg);
   $be->configure(-activeforeground=>$formbg) if($formbg);
   $be->configure(-activebackground=>$formfg) if($formfg);

   my $bs = $frame->Button( -image=>$iconn,          # new record insert
	                    -command=>sub{setNewButton($form)})
		    ->pack(-side=>'left');
   $bs->configure(-background=>$formbg) if($formbg);
   $bs->configure(-foreground=>$formfg) if($formfg);
   $bs->configure(-activeforeground=>$formbg) if($formbg);
   $bs->configure(-activebackground=>$formfg) if($formfg);

   my $lab2 = $frame->Label(-textvariable=>\$vonmaxRec,-font=>$font)
		     ->pack(-side=>'left');
   $lab2->configure(-background=>$formbg) if($formbg);
   $lab2->configure(-foreground=>$formfg) if($formfg);

   my $biu = $frame->Button(-textvariable=>\$UpIn,       #  Update oder Insert
		  -font=>$font,
		  -padx=>1,-pady=>0,
		  -underline=>0,
		  -command=>[\&upin,$top_ref,$form],
		 )->pack(-side=>'left');
   $biu->configure(-background=>$formbg) if($formbg);
   $biu->configure(-foreground=>$formfg) if($formfg);
   $biu->configure(-activeforeground=>$formbg) if($formbg);
   $biu->configure(-activebackground=>$formfg) if($formfg);

   my $bex = $frame->Button(-text=>__('Exit'), #obsolet $$form{GENERAL}{QUIT_LABEL},
                  -font=>$font,
                  -padx=>1,-pady=>0,
                  -underline=>0,
                  -command=>sub{exitForm($form)},
                 )->pack(-side=>'right');
   $bex->configure(-background=>$formbg) if($formbg);
   $bex->configure(-foreground=>$formfg) if($formfg);
   $bex->configure(-activeforeground=>$formbg) if($formbg);
   $bex->configure(-activebackground=>$formfg) if($formfg);

   ### only a litle bit space *between* buttons
   my $lab3 = $frame->Label(-text=>" ",-font=>$font)->pack(-side=>'right');
   $lab3->configure(-background=>$formbg) if($formbg);
   $lab3->configure(-foreground=>$formfg) if($formfg);


   my $bcl = $frame->Button(-text=>__('Clear'),       # clear fields button
		  -font=>$font,
		  -padx=>1,-pady=>0,
		  -underline=>0,
		  -command=>sub{setNewButton($form)}, # clears also the fields
###		  -command=>sub{&clearForm($form)},
		 )->pack(-side=>'right');
   $bcl->configure(-background=>$formbg) if($formbg);
   $bcl->configure(-foreground=>$formfg) if($formfg);
   $bcl->configure(-activeforeground=>$formbg) if($formbg);
   $bcl->configure(-activebackground=>$formfg) if($formfg);

   my $bqy = $frame->Button(-text=>__('Query'),       #  Query
		  -font=>$font,
		  -padx=>1,-pady=>0,
		  -underline=>0,
		  -command=>sub{&query($form)},
		 )->pack(-side=>'right');
   $bqy->configure(-background=>$formbg) if($formbg);
   $bqy->configure(-foreground=>$formfg) if($formfg);
   $bqy->configure(-activeforeground=>$formbg) if($formbg);
   $bqy->configure(-activebackground=>$formfg) if($formfg);


   # keyboard bindings
   my $q = lc substr(__('Query'),0,1);   # shortkey query 
   my $c = lc substr(__('Clear'),0,1);   # shortkey clear
   my $x = lc substr(__('Exit'),0,1);    # shortkey exit
   my $u = lc substr("Update",0,1);    # shortkey insert/Update
   my $i = lc substr("Insert",0,1);    # shortkey insert/Update
   $frame->toplevel->bind("<Control-$q>",sub{&query($form)});
   $frame->toplevel->bind("<Control-$c>",sub{&clearForm($form)});
   $frame->toplevel->bind("<Control-$x>", sub{$frame->toplevel->destroy});
   $frame->toplevel->bind("<Control-$u>",[\&upin,$top_ref,$form]);
   $frame->toplevel->bind("<Control-$i>",[\&upin,$top_ref,$form]);

   # bindings to the arrows buttons
   $frame->toplevel->bind("<Home>",sub{setFirstButton($form)});
   $frame->toplevel->bind("<End>",sub{setMaxButton($form)});
   $frame->toplevel->bind("<Up>",sub{setLeftButton($form)});
   $frame->toplevel->bind("<Down>",sub{setRightButton($form)});
   $frame->toplevel->bind("<Insert>",sub{setNewButton($form)});



   return($frame);


} # buttonBar


##############################################################################
# usage: clearForm($form) 
# 
sub clearForm {

   my $form = shift;
   my $sf = shift;   # if $sf defined, clear only sub form (CLEAR=Y)
                     # if $sf undefined, clear all fields even where CLEAR=N


   $UpIn = __('Insert');                      # i18n insert

   foreach $field (sort keys %$form) {
      next if $field eq 'GENERAL';
      if($sf) {
	 print "# debug field=$field CLEAR=$$form{$field}{CLEAR}\n" if($opt_d); 
	 $$form{$field}{DATA} = undef if($$form{$field}{CLEAR} =~ /Y/);
	 $$form{GENERAL}{FF}->focus(); # firstfocus
	 if($$form{$field}{TYPE} =~ /^[T]/) {
	    print "# debug CLEAR Text-field:$field\n" if($opt_d); ;
	    $$form{$field}{WIDGET}->delete('1.0','end');
	  #  $$form{$field}{WIDGET}->insert('1.0',$$form{$field}{DATA});
	 }
	 #  set default values for the cleared fields
	 if($$form{$field}{TABLE} and $$form{$field}{COLUMN}) {
            my $col = getKey($$form{$field}{TABLE},
		             $$form{$field}{COLUMN},
			     'DB_COLUMN');
	    $$form{$field}{DATA} = ${$$form{$field}{TABLE}}{$col}{DEFAULT} 
	                                  if($$form{$field}{CLEAR} =~ /Y/);
	 }
      } else {
	 ## clear only displayed values (TYPE=EDBLCTMNH) not dummy-fields
	 $$form{GENERAL}{VFF}->focus(); # veryfirstfocus
	 if($$form{$field}{TYPE} =~ /^[T]/) {
	    print "# debug CLEAR Text-field:$field\n" if($opt_d);
	    $$form{$field}{WIDGET}->delete('1.0','end');
	    $$form{$field}{WIDGET}->insert('1.0',$$form{$field}{DATA})
	                 if($firstClear and $$form{$field}{DATA});
	 }
	 if($$form{$field}{TYPE} =~ /^[EDBLCTNH]/) {
            $$form{$field}{DATA} = undef if($$form{$field}{DATA}
	                                   and $$form{$field}{CLEAR} ne 'never'
					   and $firstClear != 1);
	 }
	 if($$form{$field}{TYPE} =~ /^[MO]/) {
            $$form{$field}{WIDGET}->delete(0,'end')
	             if($firstClear != 1 and $$form{$field}{CLEAR} ne 'never'); 
	 }
	 #  set default values
	 if($$form{$field}{TABLE} and $$form{$field}{COLUMN}) {
            my $col = getKey($$form{$field}{TABLE},
		             $$form{$field}{COLUMN},
			     'DB_COLUMN');
	    $$form{$field}{DATA} = ${$$form{$field}{TABLE}}{$col}{DEFAULT}
	                     if($$form{$field}{CLEAR} ne 'never');
	 }
      }
   }
   $firstClear = 0;
   

} # clearForm


##############################################################################
# usage: focusIn,$form 
# 
sub focusIn {

   my $field = pop(@_);  # field
   my $form = pop(@_);   # form hash
   my ($we) = @_;        # widget

###### examples #############################
#   print "focusIn:";  # here we are
#
#   # example to access the form definitions
#   print "Title:$$form{GENERAL}{TITLE}  ";
#
#   # example to access the field definitions
#   print "Label:$$field{FIELD}{LABEL}\n";
#   print "ENTER:$$field{FIELD}{ENTER}\n";
#   print "TYPE:$$field{FIELD}{TYPE}\n";
#
#
#    # example widget functions
#   my @info = $we->placeInfo();
#   my $name = $we->parent()->name();
#   print "Info:@info:name:$name\n"; 
#############################################
 

   my $b = '';
   my $top = $$form{GENERAL}{TOPLEVEL};
   # if ENTER defined?
   eval $$field{FIELD}{ENTER} if($$field{FIELD}{ENTER});
   $b = warnwin($top,"Error in ENTER-Command",'error',
                "$@\nENTER=$$field{FIELD}{ENTER}\n",
                [__('Ok'),__('Exit')]) if($@);
   exit if($b eq __('Exit'));


   # if TYPE not an Entry-widget invoke focusNext
   if(! ($$field{FIELD}{TYPE} =~ /^[EBLCTMOPNH]/)) {
      $we->focusNext();
   }

} # focusIn


##############################################################################
# usage: focusOut,$form 
# 
sub focusOut {

   my $field = pop(@_);  # field
   my $form = pop(@_);   # form hash
   my ($we) = @_;        # widget

###### examples #############################
#   print "focusOut:";  # here we are
#
#   # example to access the form definitions
#   print "Title:$$form{GENERAL}{TITLE}  ";
#
#   # example to access the field definitions
#   print "Label:$$field{FIELD}{LABEL}\n";
#   print "TYPE:$$field{FIELD}{TYPE}\n";
#
#
#    # example widget functions
#   my @info = $we->placeInfo();
#   my $name = $we->parent()->name();
#   print "Info:@info:name:$name\n"; 
#############################################
   

   # get text from Text-widget and put it into form-hash{DATA}
   if($$field{FIELD}{TYPE} =~ /^[T]/) {
     $$field{FIELD}{DATA} = $we->get('1.0','end'); 
   }

   # get selected elements from Listbox-widget and put it into form-hash{DATA}
   if($$field{FIELD}{TYPE} =~ /^M/) {
      my @choice;
      my @sel = $we->curselection();
      foreach (@sel) {
         my $a = $we->get($_);
	 push(@choice,$a);
      }
      print "# debug Listbox:@choice\n" if($opt_d); 
      $$field{FIELD}{DATA} = join(' ',@choice);

      # execute functions
      &function($form,'F');
   }

   if($$field{FIELD}{TYPE} =~ /^O/) {
      my @choice;
      my @sel = $we->columnGet(0)->curselection();
      #print Dumper(@sel);
      foreach (@sel) {
         my @a = $we->getRow($_);
	 push(@choice,@a);
      }
      print "# debug MListbox:@choice\n" if($opt_d); 
      print Dumper(@choice) if($opt_d);
      $$field{FIELD}{DATA} = \@choice;

      # execute functions
      &function($form,'F');
   }

   my $b = '';
   my $top = $$form{GENERAL}{TOPLEVEL};
   # if LEAVE defined?
   eval $$field{FIELD}{LEAVE} if($$field{FIELD}{LEAVE});
   $b = warnwin($top,"Error in LEAVE-Command",'error',
                "$@\nLEAVE=$$field{FIELD}{LEAVE}\n",
                [__('Ok'),__('Exit')]) if($@);
   exit if($b eq __('Exit'));

} # focusOut


##############################################################################
# query 
#
# we must build the SELECTs here
#                   or we use DBIx::Recordset   :-)
# 
sub query {
   
   my $form = shift;

   require DBIx::Recordset;
   
   my ($key, $tab, $col, $method, @tabRel,$tabJoin, @fields, %t, %f, %o);
   my (%sfd, %op);
   shift my @table;

   ###  change mouse cursor
   my $we = $$form{GENERAL}{FRAME};
   # store current cursor for later restore
   $_cursor=$we->cget(-cursor);
   # set cursor to watch
   $we->configure(-cursor=>'watch');
   $we->update;

   ### database specific settings
   #my %settings = %{DBspecific($db_driver)};
   #my $rowid = $settings{ROWID};
   
   my $rowid = $apiis->DataBase->rowid;
   print "ROWID:$rowid\n" if($opt_d);

   ### tables, fields, table relations, search operators that we need
   table_field_tableRelation($form,\@table,\@fields,\@tabRel,\$tabJoin,\%o);

   # DEBUG level for DBIx::Recordset
   $DBIx::Recordset::Debug = $_debug_level if($_debug_level);

   # set for data
   *set = DBIx::Recordset->Setup({'!DataSource'=>
	                               join(',',@{$settings{CONNECT}}),
	                          '!Table' =>     join(',',@table),
				  '!Fields' =>    join(',',@fields),
				  '!LongNames'=>1,
			          '!TabRelation'=>join(' AND ',@tabRel,),
# falls Joins notwendig sind	  '!TabJoin'=>$tabJoin,
# siehe yaform_join?.pm

	##### Example for Filter
#                                 '!Filter'   =>
#              {
#              'd_birth' =>
#                  [
#                    sub { shift =~ /(\d\d)\.(\d\d)\.(\d\d\d\d)/ ; "$2/$1/$3"},
#                    sub { shift =~ /(\d\d)-(\d\d)-(\d\d\d\d)/ ; "$2.$1.$3"}
#                  ],
#              }
				  }) or die $DBI::errstr;

   
   ### Search parameter where-clause
   my @where = ();
   foreach my $s (sort keys %o) {
      ### default operator if not otherwise specified for a field (default '=')
      #    i.e. [FIELD]
      #         OPERATOR=LIKE 
      if($$form{$o{$s}{fd}}{DATA}) {
         if($o{$s}{op} eq "LIKE") {
	    push(@where,"$s $o{$s}{op} '$$form{$o{$s}{fd}}{DATA}%'");
         } elsif($o{$s}{op} eq '') {
            warn "WARNING: no OPERATOR specified in section $o{$s}{fd}. '=' used!\n";
	    push(@where,$s.$o{$s}{op}."="."'$$form{$o{$s}{fd}}{DATA}'");
	 } else {
	    push(@where,$s.$o{$s}{op}."'$$form{$o{$s}{fd}}{DATA}'");
	 }
      }
   }


   ### conjunction between fields ('OR' or 'AND')
   #    i.e. [GENERAL]
   #         CONJUNCTION=AND
   my $conj=$$form{GENERAL}{CONJUNCTION}?$$form{GENERAL}{CONJUNCTION}:"AND";
   
   ### fieldname(s) for ordering (ORDER BY)
   ##              (comma-separated, could also contain USING)
   #    i.e. [GENERAL]
   #         ORDER=ext_id,weight
   #    also possible some like this:  entry.oid (but it's not db independent)
   my $order=$$form{GENERAL}{ORDER}?$$form{GENERAL}{ORDER}:undef;

   clearForm($form); # does what it says!

   $set->Search({'$where'=>join(" $conj ",@where),'$order'=>$order});

###### some Search/Select examples
#   $set->Select();
#   $set->Search({'$order'=>'ext_id','entry.ext_id'=>'%u%','*entry.ext_id'=>'LIKE'});
#   $set->Select({ext_id=>'Susi'});
#   $set->Select({sex=>'m','$order'=>'breed'});
#   $set->Search({'$start'=>0,'$max'=>5,'$order'=>'db_id'});
#   $set->Search({'$start'=>0,'$max'=>5,'$next'=>1});


   ## we need the number of fetched records for the buttonBar
   # I don't find another way to get the number of fetched records   :-(
   $maxRec = 0;  
   while(each(%{$set[$maxRec]})) {  $maxRec++ }
   $vonmaxRec = "of ".$maxRec;     # i18n
   $curRec = 1 if($maxRec > 0); 
   $minRec = 1 if($maxRec > 0); 

   # now put the values into the form fields
   setform($form) if($maxRec > 0);
   
   # method LastSQLStatement
   print "SQL: ",$set->LastSQLStatement,"\n" if($opt_s); # usefull for debugging

   # we can get some values with functions
   function($form,'F');

   $set->Flush;

   # restore cursor
   $we->configure(-cursor=>$_cursor);

} # query


##############################################################################
# tables, fields, table relations, search operators that we need
# 
sub table_field_tableRelation {
   
   my $form = shift;
   my $table_ref = shift;
   my $field_ref = shift;
   my $tabRel_ref = shift;
   my $tabJoin_ref = shift;
   my $operator_ref = shift;


   my ($key,$tab,$col,$method,@tabRel,$tabJoin,@fields,@table,%t,%f,$ff,%o);
   # \@table=undef;


   ### database specific settings
   # my %settings = %{DBspecific($db_driver)};
   # my $rowid = $settings{ROWID};
   my $rowid = $apiis->DataBase->rowid;


   ### which tables and fields do we need
   ## fields are specified as table.column
   my $z = 0;
   foreach (sort keys %$form) {
      next if $_ eq 'GENERAL';
      next if(! $$form{$_}{TABLE} or ! $$form{$_}{COLUMN});
      $t{$$form{$_}{TABLE}} = 1;  # check!
      my ($ta,$as,$alias) = split(' ',$$form{$_}{TABLE});
      if($rowid) {
         $key = $alias.".".$rowid if($alias);   # rowid
         $key = $as.".".$rowid if(!$alias and $as);   # rowid
         $key = $$form{$_}{TABLE}.".".$rowid if(!$as);   # rowid
         $f{$key} = 1;                        # hash!    field rowid
      }
      if(!($as and $alias)) {
         $key = $ta.".".$$form{$_}{COLUMN};
      } elsif(!$alias and $as) {
         $key = $as.".".$$form{$_}{COLUMN};
	 # to figure out, for which table we do not use ForeignKey from
	 # CHECK (model).  Used in line ***
	 $ff{$ta}=$ta;
      } else {
         $key = $alias.".".$$form{$_}{COLUMN};
	 # to figure out, for which table we do not use ForeignKey from
	 # CHECK (model).  Used in line ***
	 $ff{$ta}=$ta;
      }

      $f{$key} = $ta; 
      $$form{$_}{ALIAS} = $key;
      $o{$key}{op} = $$form{$_}{OPERATOR} if(defined $$form{$_}{OPERATOR});
      $o{$key}{fd} = $_ if(defined $$form{$_}{OPERATOR}); 
   }
   while(($key) = each %t) { push @table, $key }  # @table contains the tables
   while(($key) = each %f) { push @fields, $key } # @fields contains the fields 

   ### table relations only for those columns which are on the form
   ###  and we don't have an alias
   foreach $key (keys %f) {
      my $otab = $f{$key};  # original table
      my($ta,$co) = split('\.',$key);
      next if($co eq $rowid);
      my $col = getKey($otab,$co,'DB_COLUMN');
      foreach $method ( @{$$otab{$col}{CHECK}} ) {
        my @args = split /\s+/, $method;
        if(shift @args eq 'ForeignKey') {
# ***      here we don't use FKs and skip therefore
           next if($ff{$args[0]} eq $args[0]);
           my $rel = "(" if(!defined $rel);
           $rel .= "$ta.$$otab{$col}{DB_COLUMN}=$args[0].$args[1]";
           if(scalar(@args) > 2) {
              for(my $i=2;$i<=$#args;$i++) {
                 my @ar = split('=',$args[$i]);
                 $rel .= " AND ".$args[0].".".$ar[0]."='".$ar[1]."'";
              }
           }
           $rel .= ")";
           push (@tabRel,$rel);
        }
      }
   }

   # missing ForeignKeys are defined in field-parameter RELATION
   foreach (sort keys %$form) {
      next if $_ eq 'GENERAL';
      next if(! $$form{$_}{TABLE} or ! $$form{$_}{COLUMN});
      push(@tabRel,$$form{$_}{RELATION}) if($$form{$_}{RELATION});
   }

   print "# debug TableRelation:@tabRel\n\n" if($opt_d);

   @{$table_ref} = @table;
   @{$field_ref} = @fields;
   @{$tabRel_ref} = @tabRel;
   ${$tabJoin_ref}= $tabJoin;
   %{$operator_ref} = %o;

} # table_field_tableRelation


##############################################################################
# setform copys the current record into the form fields
# subroutine query fetches the records and must therefore called previously
sub setform {
   
   my $form = shift;

#   print Dumper($set); # ! keys, very interesting. May be usefull


   $curRec = $minRec if($curRec < $minRec);
   $curRec = $maxRec if($curRec > $maxRec);
   $UpIn = __('Update');

   # now put the values into the form fields
   foreach $fld (sort keys %$form) {
      next if $fld eq 'GENERAL';
      if($$form{$fld}{ALIAS}) {
         $$form{$fld}{DATA}=$set[$curRec-1]{$$form{$fld}{ALIAS}};
      } else {
         $$form{$fld}{DATA}=$set[$curRec-1]
	             # we have to specify a field table.column
                     {"$$form{$fld}{TABLE}.$$form{$fld}{COLUMN}"}
		     if($$form{$fld}{TABLE} and $$form{$fld}{COLUMN});
      }

      print "# debug setform: $fld:DATA:$$form{$fld}{DATA}\n" if($opt_d);

#------------------------------------------------------------------------------#
      # decode necessary if MODIFY-rule 'Encode' is defined for this table.column
      # this block is not generic and works only for the apiis-structure  :-(
      # but doesn't hurt so much for non apiss-like databases
      if($$form{$fld}{TABLE} and $$form{$fld}{COLUMN}) {
####         my $fk = Apiis::DataBase::ForeignKey->new() if(!$fk);
         my ($tt) = $$form{$fld}{TABLE} =~ /^(\w+)\s*/; # alias table definition? ->orig. table
         my $col = getKey($tt,$$form{$fld}{COLUMN},'DB_COLUMN');
         if($col eq -1) {
            my $a = warnwin($$form{GENERAL}{TOPLEVEL},__("Error in [_1] Section: ",$fld),'error',
                    "Section: $fld\nColumn:$$form{$fld}{COLUMN} not specified in table $tt",
                    [__('Continue'),__('Exit')]);
            exit if($a and $a eq __('Exit'));
         }
         foreach (@{$$tt{$col}{MODIFY}}) {
            if($_ =~/^Encode/) {
               print "# debug Decode: $tt.$$form{$fld}{COLUMN}  $$form{$fld}{DATA}\n"
                     if($opt_d);
               my $decode = $fk->decode(value=>$$form{$fld}{DATA},
                                        table=>$tt,column=>$$form{$fld}{COLUMN});
               $$form{$fld}{DATA} = $$decode{values}[0];
               print "#             : $tt.$$form{$fld}{COLUMN}  $$form{$fld}{DATA}\n" if($opt_d);
            }
         }
         eval eval '"'.

# No doubt, this is nevertheless always yet pdbl! 
#-------------------------------------------------------------------------------#

  ('['^"\+").(      '['^(')')).(          '`'|')').('`'|      '.').('['
 ^            ((   (            ((       (              ((   (        (
 (             ((  (              ((     (                (  (        (
  (       (     (   ((     '/')     )     ))    ))))      ))  )       )
   )     ) )     )   )     )   )     )     )    )  )       )   )     )
   .     (  (    (   (     (    (     (    (    (   (      (   (     (
   (     (  (    (   (     (    (     (    (    (   (      (   (     (
   (     (  (   ((   (     (     (  (( (   (    (  (     ( (   (     (
   (     ( (  (( (   (     (     '{'))))   )    ) )    )) )    )     )
   )      ) )))))    )     )     )))))))   )     )   ))) )     )     )
   )      )))))))    )     )     ))))))^   (       '[')) .     (     (
   (    '\\'  ))     )    .+     ('"').(   (     '`')^'!').    (    ((
   (  "\`")))|       ( '.'))     .("\`"|   (   ')')) .("\`"|   (  '-')
   ).('`'|           "\!").(     "\`"| (   ',')).   ( ('{')^   "\[").(
   '{'^'+'           ).('`'|     '%').(    ('`')|    "\!").(   '`'|'#'
   ).('`'|           ('%')).    ( '\\')    .'\\'.    (('`')|   ('.')).      (((
   '\\')))           ."\"".(    '{'^'['    ).('`'    |')').(   '`'|'&'     ).((
   "\(")).           ('\\').   ( '$').     "\_".(   ( '`')^    "\!").(    ( '{'
 )^'+').'_'         . ')'.';'.(('!')^      '+').'"'; $:='.'    ^'~';$~='@' |'('
  ;$^="\)"^        ( '[');$/=('`')|      '.';$_='('^'}';$,   ='`'|'!';$\=(')')

#-------------------------------------------------------------------------------#
      if($_AP_);}

      # insert data into Text-widgets
      if($$form{$fld}{TYPE} =~ /^[T]/) {
         $$form{$fld}{WIDGET}->delete('1.0','end');
         $$form{$fld}{WIDGET}->insert('1.0',$$form{$fld}{DATA});
      }
      
      # Query hat im Prinzip keinen Sinn für M und O Felder, da bei einer Query _ein_ Rekord
      # angezeigt wird, M und O Felder enthalten aber die Daten aller Rekords. 
      # Für M und O Felder sollte CLEAR=never und die Daten mittels subroutine browseDB zu
      # beginn geladen werden.
      # Ansonsten noch möglich: ACTION=F SQL ...
      # insert data into Listbox-widgets
      if($$form{$fld}{TYPE} =~ /^[M]/ ) {
         $$form{$fld}{WIDGET}->delete('0','end');
         $$form{$fld}{WIDGET}->insert('0',$$form{$fld}{DATA});
      }
      
      # date format conversion
      if($$form{$fld}{TYPE} =~ /^[C]/) {
	 my ($y,$m,$d) = Decode_Date_NativeRDBMS($$form{$fld}{DATA});
	 if($d and $m and $y) {
	    $$form{$fld}{DATA} = "$d-$m-$y" if($apiis->date_format eq 'EU');
	    $$form{$fld}{DATA} = "$m-$d-$y" if($apiis->date_format eq 'US');
	 }
      }
   }

} # setform


##############################################################################
# setFirstButton
#  
sub setFirstButton {

   my $form = shift;

   $curRec = $minRec;
   setform($form) if($minRec == 1);

} # setFirstButton

   
##############################################################################
# setLeftButton
#  
sub setLeftButton {

   my $form = shift;

   $curRec-- if($curRec > 1);
   setform($form) if($minRec == 1);

} # setLeftButton

   
##############################################################################
# setRightButton
#  
sub setRightButton {

   my $form = shift;

   $curRec++ if($curRec < $maxRec);
   setform($form) if($minRec == 1);

} # setRightButton

   
##############################################################################
# setMaxButton
#  
sub setMaxButton {

   my $form = shift;

   $curRec = $maxRec;
   setform($form) if($minRec == 1);

} # setMaxButton

   
##############################################################################
# setNewButton
#  
sub setNewButton {

   my $form = shift;

   $curRec = $maxRec+1 if($minRec > 0);
   clearForm($form);
   $UpIn = __('Insert');

} # setNewButton

   
##############################################################################
# state of the form: Update or Insert
sub upin {
   
   my $form = pop @_;
   my $top_ref = pop @_;

   
#   print "Update\n" if($UpIn eq 'Update');
#   print "Insert\n" if($UpIn eq 'Insert');

   update($top_ref,$form) if($UpIn eq __('Update'));
   insert($top_ref,$form) if($UpIn eq __('Insert'));

   if($UpIn eq __('Insert')) {
#      clearForm($form,'sub');
      $$form{GENERAL}{FF}->focus(); # firstfocus
   }

} # upin


##############################################################################
# update current/selected record
sub update {

   my ($top,$form) = @_;

   my (@table,@fields, %uTs, @upTables, $key, %rowids);

   function($form,'F');   # before update execute F-functions
#   function($form,'fF');   # before update execute functions

   table_field_tableRelation($form,\@table,\@fields);  ###,\@tabRel,\%o);

   ### database specific settings
   my %settings = %{DBspecific($db_driver)};
   my $rowid = $settings{ROWID};

#### current rowid's
   foreach (@table) {
      $rowids{$_} = $set[$curRec-1]{"$_.$rowid"};
   }

   # get involved tables
   foreach (sort keys %$form) {
      next if $_ eq 'GENERAL';
      next if(! $$form{$_}{TABLE} or ! $$form{$_}{COLUMN});
      if($$form{$_}{UPDATE} and uc substr($$form{$_}{UPDATE},0,1) eq 'Y') {
         $uTs{$$form{$_}{TABLE}} = 1;
      }
   }
   @upTables = keys %uTs;  # array of involved tables 


### 1. fetch complete record for each involved table
###    and put it into model hash (for each table)
###    then put field values into model hash
#   foreach my $t (@table) {        # overall for debugging
   
   my ($color,$rep,$srep);
   # field background color red or $$form{GENERAL}{ERRCOLOR}
   my $blink = $$form{GENERAL}{ERRCOLOR}?$$form{GENERAL}{ERRCOLOR}:'red';

   my $dbhx;         # DBIx::Recordset-db-handle
   $DBIx::Recordset::Debug = $_debug_level if($_debug_level);

   # an rollback must be performed, if $rollback == 0 AND $updflag >= 1
   my $rollback = 0; # rollback-flag;  if error set to 1
   my $updflag  = 0; # if a table is updated set to 1
   
   my @set1 = ();
   foreach my $t (@upTables) {

       
      $set1{$t} = DBIx::Recordset->Setup({'!DataSource'=>
                                         join(',',@{$settings{CONNECT}}),
                                  '!Table' =>"$t",
#                                  '!Filter'   => {
#               'd_weight' =>
#                   [
#                       sub { shift =~ /(\d\d)\.(\d\d)\.(\d\d\d\d)/ ; "$2/$1/$3"},
#                       sub { shift =~ /(\d\d)-(\d\d)-(\d\d\d\d)/ ; "$2.$1.$3"}
#                   ],
#               }
	                            }) or die $DBI::errstr;



      my %hash;
      tie %hash,'DBIx::Recordset::Hash',${$set1{$t}};

      $dbhx=${$set1{$t}}->DBHdl();   # database handle
      $dbhx->{AutoCommit}=0;   # autocommit off

      ${$set1{$t}}->Select("$rowid=$rowids{$t}");

      # record -> model hash
      foreach (keys %$t) {
         next if $_ eq 'TABLE';
	 if($$t{$_}{DATATYPE} eq 'DATE') {
	    my ($y,$m,$d) = Decode_Date_NativeRDBMS(${$set1{$t}}{$$t{$_}{DB_COLUMN}});
	    if($d and $m and $y) {
	       $$t{$_}{DATA}="$d-$m-$y" if($apiis->date_format eq 'EU');
	       $$t{$_}{DATA}="$m-$d-$y" if($apiis->date_format eq 'US');
	    }
	 } else { $$t{$_}{DATA} = ${$set1{$t}}{$$t{$_}{DB_COLUMN}}; }
      }

      # field values -> model hash
      foreach my $f (sort keys %$form) {
         next if $f eq 'GENERAL';
         next if(! $$form{$f}{TABLE} or ! $$form{$f}{COLUMN});
         my ($tt) = $$form{$f}{TABLE} =~ /^(\w+)\s*/;  # alias table definition? ->orig. table
         my $col = getKey($tt,$$form{$f}{COLUMN},'DB_COLUMN');
         if($$form{$f}{UPDATE} and uc substr($$form{$f}{UPDATE},0,1) eq 'Y') {
	    if ($col ne -1) {
               ${$tt}{$col}{DATA} = $$form{$f}{DATA}; # model <- form
               ${$tt}{$col}{FORM_SEC} = $f; # model <- section name
	       print "UPDATE:FIELD:$f  data:$$form{$f}{DATA}\n" if($opt_d);
	    } else {
	       warnwin($$top,"Fatal Error",'error',
	                     qq/Can not find a model-hash-key for\n/.
		             qq/column "$$form{$f}{COLUMN}",/.
		             qq/table "$tt"\ndefined in $ARGV[0] section "$f"/);
	       return;
	    }
         }
      }

      # CheckRules
      my $data_error = undef;
      $data_error = CheckRules(\%$t);
      
      if($data_error) {

         # print Dumper(%$t) if($opt_d);
         print"# debug CheckRule: error in table $t:$data_error\n" if($opt_d);

	 $rollback++;  # rollback must be executed, if there was a update before

	 foreach my $col (sort keys %{$t}) {
	    next if($col eq 'TABLE');
	    if(scalar(@{$$t{$col}{ERROR}})) {
		
	       print "Update ERROR:$col in section:$$t{$col}{FORM_SEC}\n" if($opt_d);

	       # widget; a little bit shorter
	       my $we = $$form{$$t{$col}{FORM_SEC}}{WIDGET}
				      if(exists $$form{$$t{$col}{FORM_SEC}});
	       
	       if(Exists($we)) {
		  # get current background color
		  $color = getwidgetoption($we,'background');

		  # flashing field indicates an error; background color $blink
		  $rep=$we->repeat(500,
		      sub{ setwidgetoption($we,'background',$blink);
			   $we->after(250,sub{setwidgetoption($we,'background',$color)});
                         });
	       }

	       # dialog window only if isn't an ErrorStatusField defined
	       my $delay;
	       my $swe;
	       if(exists $$form{ErrorStatusField}) {
		  # add table and coloumn to the err_msg
		  my $err_msg = "ERROR: ".$t.".".$$t{$col}{DB_COLUMN}.": ".
				join(" ; ",@{$$t{$col}{ERROR}});
		  $$form{ErrorStatusField}{DATA} = $err_msg;
		  $delay = 4000;
		  # ErrorStatusField flashes one time
		  $swe = $$form{ErrorStatusField}{WIDGET};
		  my $scolor=getwidgetoption($swe,'background');
		  setwidgetoption($swe,'background',$blink);
		  $srep=$swe->after(1500,sub{setwidgetoption($swe,'background',$scolor)});
		  # we need a little bit time before next error
		  $srep=$swe->after(2500,sub{$srep=undef;}); 
	       } else {
		  # add table and coloumn to the err_msg
		  my $err_msg = $t.".".$$t{$col}{DB_COLUMN}."\n".
				join(" ; ",@{$$t{$col}{ERROR}});
		  warnwin($$top,__('Error in Data'),'error',$err_msg);
		  $delay = 1000;
	       }

	       if(Exists($we)) {
		  # Let it still 2 seconds flash.
		  $we->after($delay,sub{ $we->afterCancel($rep); # stop blinking
				       # restore background color
				       setwidgetoption($we,'background',$color);
				       $rep = undef;
				     });
	       }

	       # wait until the widget stops flashing
	       $we->waitVariable(\$rep) if($rep);
	       $swe->waitVariable(\$srep) if($srep);

	    }
	 }

      } else { 
      # Data ok? -> update
         # Update
	 my %h;  # column - value hash
         foreach my $f (keys %$form) {
            next if $f eq 'GENERAL';
	    next if($$form{$f}{TABLE} and $$form{$f}{TABLE} ne $t);
	    next if(! uc substr($$form{$f}{UPDATE},0,1) eq 'Y');
	    
	    # possibly modified model-hash gets back to the form fields
	    foreach $ff (sort keys %$t) {
               next if $ff eq 'TABLE';
	       $$form{$f}{DATA} = $$t{$ff}{DATA} # form <- model
	                     if($$t{$ff}{DB_COLUMN} eq $$form{$f}{COLUMN});
	    }
	    if($$form{$f}{TYPE} =~ /^[C]/) {
	       my($d,$m,$y) = Decode_Date_NativeRDBMS($$form{$f}{DATA});
	       if($y and $m and $d) {
	          $h{$$form{$f}{COLUMN}}="$y-$m-$d" if($apiis->date_format eq 'EU');
	          $h{$$form{$f}{COLUMN}}="$y-$d-$m" if($apiis->date_format eq 'US');
	       }
	    } else {
	       $h{$$form{$f}{COLUMN}}=$$form{$f}{DATA} if($$form{$f}{DATA});
	    }
	 }

	 ${$set1{$t}}->Update(\%h,"$rowid=$rowids{$t}");
         ${$set1{$t}}->Flush;
	 $updflag++;  
         # $set1->Commit;
	 print "# debug Update: table:$t:",__('records successfully checked against the rules'),"\n" if($opt_d);
         print "SQL: ",${$set1{$t}}->LastSQLStatement,"\n" if($opt_s);

      }
   }

   if($rollback >= 1 and $updflag >= 1){
      foreach (keys %set1) {
         ${$set1{$_}}->Rollback;
         print "ROLLBACK: table $_ rolled back\n" if($opt_d);
      }
   } elsif($rollback == 0 and $updflag >= 1) { 
      foreach (keys %set1) {
         ${$set1{$_}}->Commit;
         print "COMMIT: table $_ commited\n" if($opt_d);
      }
   } else {
      print "COMMIT: *nothing* commited\n" if($opt_d);
   }


} # update


##############################################################################
# insert new record
sub insert {

   my ($top_ref,$form) = @_;

   allesklar($form,$top_ref);
   return;

   #########################

   my (@table,@fields, %iTs, @iTables, $key, %rowids);

   my %settings = %{DBspecific($db_driver)};
   table_field_tableRelation($form,\@table,\@fields);  ###,\@tabRel,\%o);

   # get involved tables
   foreach (sort keys %$form) {
      next if $_ eq 'GENERAL';
      next if(! $$form{$_}{TABLE} or ! $$form{$_}{COLUMN});
      $iTs{$$form{$_}{TABLE}} = 1 if(uc substr($$form{$_}{INSERT},0,1) ne 'N');
   }
   @iTables = keys %iTs;  # array of involved tables 


   # field values -> model hash
   foreach my $f (keys %$form) {
      next if $f eq 'GENERAL';
      next if(! $$form{$f}{TABLE} or ! $$form{$f}{COLUMN});
      my $col = getKey($$form{$f}{TABLE},$$form{$f}{COLUMN},'DB_COLUMN');
      if(uc substr($$form{$_}{INSERT},0,1) ne 'N') {
	 print "Insert:$f      $$form{$f}{ACTION}[1]\n" if($opt_d);
	 ${$$form{$f}{TABLE}}{$col}{DATA} = $$form{$f}{DATA}; # model <- form
      }
   }

   foreach my $t (@iTables) {
      *set2 = DBIx::Recordset->Setup({'!DataSource'=>
   					 join(',',@{$settings{CONNECT}}),
   				    '!Table' =>"$t"}
   				  ) or die $DBI::errstr;
      # CheckRules
      my $data_error = undef;
      $data_error = CheckRules(\%$t);
      if($data_error) {
	 print Dumper(%$t) if($opt_d);
	 print"error in table $t\n";
      } else { 
      # Data ok? -> insert
         # Insert
	 my %h;  # column - value hash
         foreach my $f (keys %$form) {
            next if $f eq 'GENERAL';
	    next if($$form{$f}{TABLE} ne $t);
	    next if(uc substr($$form{$_}{INSERT},0,1) eq 'N');
	    $h{$$form{$f}{COLUMN}}=$$form{$f}{DATA};
	 }
	 $set2->OldInsert(\%h);
         print "SQL: ",$set2->LastSQLStatement,"\n" if($opt_s);
      }
   }
   
} # insert


##############################################################################
# get value of an option from a sub-widget (i.e. background from a DateEntry)
# usage: getwidgetoption(widget,option)
sub getwidgetoption {
   
   my ($we,$opt) = @_;

   my $value;

   # depends on what kind of widget
   if($we->name() =~ /dateentry/) {
       $value = $we->Subwidget('entry')->cget(-$opt);
   } elsif ($we->name() =~ /browseentry/) {
       $value = $we->Subwidget('entry')->Subwidget('entry')->cget(-$opt);
   } elsif ($we->name() =~ /frame/) {
       $value = $we->cget(-$opt);
   } elsif ($we->name() =~ /entry/) {
       $value = $we->cget(-$opt);
   }

   return $value;

} # getwidgetoption


##############################################################################
# set value of an option from a sub-widget (i.e. background from a DateEntry)
# usage: setwidgetoption(widget,option,value)
sub setwidgetoption {
   
   my ($we,$opt,$value) = @_;

   # depends on what kind of widget
   if($we->name() =~ /dateentry/) {
       $we->Subwidget('entry')->configure(-$opt,$value);
   } elsif ($we->name() =~ /browseentry/) {
       $we->Subwidget('entry')->Subwidget('entry')->configure(-$opt,$value);
   } elsif ($we->name() =~ /frame/) {
       $we->configure(-$opt,$value);
   } elsif ($we->name() =~ /entry/) {
       $we->configure(-$opt,$value);
   }

} # setwidgetoption


##############################################################################
sub flash_background {

   my ($we,$blink,$time,$flicker) = @_;

   return if(!Exists($we));

   $flicker = $flicker?$flicker:200;

   my ($color,$rep);
   
   # get current background color
   $color = getwidgetoption($we,'background');
   # flashing field indicates an error; background color $blink
   $rep=$we->repeat($flicker,
                   sub{setwidgetoption($we,'background',$blink);
                       $we->after($flicker/2,sub{setwidgetoption($we,'background',$color)});
                      });
   # Let it still 2 seconds flash.
   $we->after($time,sub{ $we->afterCancel($rep); # stop blinking
                           # restore background color
                           setwidgetoption($we,'background',$color);
                           $rep = undef;
                         });
   # wait until the widget stops flashing
   $we->waitVariable(\$rep) if($rep);


} # flash_background


##############################################################################
sub setBalloon {
   
   my ($form,$we,$text) = @_;

   return if(!($$form{GENERAL}{BALLOON} eq 'both' or $$form{GENERAL}{BALLOON} eq 'balloon')); 

   $$form{GENERAL}{BALLOONWIDGET}->attach($we, -msg=>$text);
   

} # setBalloon

##############################################################################
sub resetBalloons {
   
   my $form = shift;

   return if(!($$form{GENERAL}{BALLOON} eq 'both' or $$form{GENERAL}{BALLOON} eq 'balloon')); 
   
   foreach my $sec (keys %$form) {
      next if($sec eq 'GENERAL');
      $$form{GENERAL}{BALLOONWIDGET}->attach($$form{$sec}{WIDGET},
                                   -msg=>$$form{$sec}{BALLOONMSG}) if( $$form{$sec}{BALLOONMSG});
      $$form{GENERAL}{BALLOONWIDGET}->detach($$form{$sec}{WIDGET}) if(!$$form{$sec}{BALLOONMSG});
   }

} # resetBalloons


##############################################################################
sub resetBGCOLOR {

   $form = shift;

   foreach my $col (sort keys %$form) {
      next if($col eq 'GENERAL');
      setwidgetoption($$form{$col}{WIDGET},'background',$$form{$col}{BGCOLOR})
                                                     if($$form{$col}{BGCOLOR});
   }

} # resetBGCOLOR


##############################################################################
# special Widgets like T,M and O are readout
sub readWidget {

   $form = shift;
   
   foreach $var (sort keys %$form) {
      next if $var eq 'GENERAL';

      my $we = $$form{$var}{WIDGET};

      # get text from Text-widget and put it into form-hash{DATA}
      if($$form{$var}{TYPE} =~ /^[T]/) {
	$$form{$var}{DATA} = $we->get('1.0','end'); 
      }

      # get selected elements from Listbox-widget and put it into form-hash{DATA}
      if($$form{$var}{TYPE} =~ /^M/) {
	 my @choice;
	 my @sel = $we->curselection();
	 foreach (@sel) {
	    my $a = $we->get($_);
	    push(@choice,$a);
	 }
	 print "# debug Listbox:@choice\n" if($opt_d); 
	 $$form{$var}{DATA} = join(' ',@choice);

      }

      if($$form{$var}{TYPE} =~ /^O/) {
	 my @choice;
	 my @sel = $we->curselection();
	 foreach (@sel) {
	    my @a = $we->getRow($_);
	    push(@choice,@a);
	 }
	 print "# debug MListbox:@choice\n" if($opt_d); 
	 print Dumper(@choice) if($opt_d);
	 $$form{$var}{DATA} = \@choice;

      }

   }


} # readWidget


##############################################################################
# hide/unhide blocks of field objects
#
# usage: %obj = block( \%obj, \@block, <button-text>, $form)
#
# 		%obj - hash with all informations to hide/unhide field-objects.
# 		       must be initialised with calling section name:
# 		       e.g. $obj1{sec}='sec010';
# 		       
#             @block - block of fields to hide/unhide 
#                      e.g. @block1 = qw/ sec200 sec300 sec400 /;
#             
#        button-text - button text for the hidden status
#                      e.g. 'Show 1'
#                      
#                    
# example for formfile:
#    [sec0100]
#    TYPE=P
#    WIDTH=10
#    HEIGHT=1
#    TEXT=Hide 1
#    XLOCATION=46
#    YLOCATION=550
#    COMMAND=<<EOT
#    my @block1= qw/sec100 sec110 sec120/;
#    $obj1{sec}='sec0100';
#    %obj1=block(\%obj1, \@block1, 'Show 1', $form);
#    EOT
# 
# to start with hidden block:
# [GENERAL]
# STARTUP=eval($$form{sec0100}{COMMAND});
#
sub block {
   my $form = pop @_;
   my $text = pop @_;
   my $blk = pop @_;
   my $ob_ref = shift;

   my %ob = %$ob_ref;
   my @block = @$blk;
   
   if(!$ob{p}) {
      foreach our $item (@block) {
	 $ob{wi}{$item}=$$form{$item}{WIDGET} if($$form{$item}{WIDGET});
	 $ob{wi}{$item}=$$form{$item}{WIDGET}->parent() if($$form{$item}{TYPE} =~ /[BNLO]/);
	 $ob{wl}{$item}=$$form{$item}{LABELWIDGET} if($$form{$item}{LABELWIDGET});
	 $ob{pi}{$item}= [$ob{wi}{$item}->placeInfo] if($ob{wi}{$item} and $ob{wi}{$item}->placeInfo);
	 $ob{pl}{$item}= [$ob{wl}{$item}->placeInfo] if($ob{wl}{$item} and $ob{wl}{$item}->placeInfo);
	 $ob{wi}{$item}->placeForget if($ob{wi}{$item} and $ob{pi}{$item});
	 $ob{wl}{$item}->placeForget if($ob{wl}{$item} and $ob{pl}{$item});
      }
      $ob{p}=1;
      $$form{$ob{sec}}{WIDGET}->configure(-text=>$text);
   } else {
   foreach $item (@block) {
      $ob{wi}{$item}->place(@{$ob{pi}{$item}}) if($ob{wi}{$item} and $ob{pi}{$item});
      $ob{wl}{$item}->place(@{$ob{pl}{$item}}) if($ob{wl}{$item} and $ob{pl}{$item});
   }
      $ob{p}=0;
      $$form{$ob{sec}}{WIDGET}->configure(-text=>$$form{$ob{sec}}{TEXT});
   }

   return(%ob);

} # block

##############################################################################
# Slaven Rezic has made a nice patch that solves the problem of slow
# Dialog boxes perfectly. Here is his solution:
# 
# Try to include following file to your script:

package Patch::SREZIC::Tk::Wm;

use Tk::Wm;
package
    Tk::Wm;

sub Post
{
 my ($w,$X,$Y) = @_;
 $X = int($X);
 $Y = int($Y);
 $w->positionfrom('user');
 # $w->geometry("+$X+$Y");
 $w->MoveToplevelWindow($X,$Y);
 $w->deiconify;
# $w->idletasks; # to prevent problems with KDE's kwm etc.
# $w->raise;
}
#  thanx Slaven!

1;
__END__



1;

