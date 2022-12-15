#############################################################################Yj
# This Init package provides specific methods for HTML:
##############################################################################
#-- UTF8 
package Apiis::Form::HTML;
$VERSION = '$Revision $';

use strict;
use warnings;
use base "Apiis::Form::Init";
our @ISA;
our $apiis;
use Apiis::Form::HTML::CreateCSS;
use Apiis;
use Apiis::Init;
use Data::Dumper;
use URI::Escape;
use JSON::XS;

my ( $opt_m, $opt_u, $opt_p, $opt_o, $text, $self );

my %css = (
    'Width',              'width',               'FontFamily',           'font-family',
    'FontSize',           'font-size',           'FontStyle',            'font-style',
    'FontWeight',         'font-weight',         'FontVariant',          'font-variant',
    'Font',               'font',                'BackgroundColor',      'background-color',
    'BackGround',         'background-color',    'ForeGround',           'color',
    'Color',              'color',               'BackgroundImage',      'background-image',
    'BackgroundRepeat',   'background-repeat',   'BackgroundAttachment', 'background-attachment',
    'BackgroundPosition', 'background-position', 'Background',           'background',
    'WordSpacing',        'word-spacing',        'LetterSpacing',        'letter-spacing',
    'TextDecoration',     'text-decoration',     'VerticalAlign',        'vertical-align',
    'TextTransform',      'text-transform',      'TextAlign',            'text-align',
    'TextIndent',         'text-indent',         'LineHeight',           'text-height',
    'MarginTop',          'margin-top',          'MarginRight',          'margin-right',
    'MarginBottom',       'margin-bottom',       'MarginLeft',           'margin-left',
    'Margin',             'margin',              'PaddingTop',           'padding-top',
    'PaddingRight',       'padding-right',       'PaddingBottom',        'padding-bottom',
    'PaddingLeft',        'padding-left',        'Padding',              'padding',
    'BorderTopWidth',     'border-top-width',    'BorderRightWidth',     'border-right-width',
    'BorderBottomWidth',  'border-bottom-width', 'BorderLeftWidth',      'border-left-width',
    'BorderWidth',        'border-width',        'BorderStyle',          'border-style',
    'BorderColor',        'border-color',        'BorderTop',            'border-top',
    'BorderRight',        'border-right',        'BorderBottom',         'border-bottom',
    'BorderLeft',         'border-left',         'Border',               'border',
    'BlockWidth',         'width',               'BlockHeight',          'height',
    'BlockFloat',         'float',               'Clear',                'clear',
    'Display',            'display',             'WhiteSpace',           'white-space',
    'ListStyleType',      'list-style-type',     'ListStyleImage',       'list-style-image',
    'ListStylePosition',  'list-style-position', 'ListStyle',            'list-style'
);

=head2 CreateCSSProperties

This function has an object name as argument. It fetchs the object about getobject($name) and make a loop over the css-children-objects. After test whether the children-objects (color, format, position, miscellaneous, text) are valid each methodes of the objects were ask if it has an entry. About hash %css the correct css-name will fetched. After loop all properties were collect and return as STYLE-element

=cut

sub CreateCSSProperties {
    my $self       = shift;
    my $obj_name   = shift;
    my @properties = ();
    foreach my $key ( keys %css ) {
        if ( $self->GetValue( $obj_name, $key ) ) {
            my $key1 = lc($key);
            my $t = $self->GetValue( $obj_name, $key );
            next if ( ( $t eq '' ) or ( $t eq 'none' ) or ( $t eq 'normal' ) );
            push( @properties, $css{$key} . ":$t" );
        }
    }
    return @properties;
}

sub MakeStyle {
    my $self = shift;
    $self->{'_style'} = shift;

    my $hs_style = {};
    my @ar_style;
    my $form_name = $self->{_form_list}->[0];
    foreach my $blockname ( $self->blocknames ) {
        foreach my $name_list ( '_misc_blockelement_list', '_field_list' ) {
            my $names_ref = $self->GetValue( $blockname, $name_list );
            foreach my $fieldname (@$names_ref) {

                next
                    if (
                    (       $self->GetValue( $fieldname, 'Visibility' )
                        and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                    )
                    );

                next if ( exists $self->{'_disable_targetfield'}->{$fieldname} );

                #if ($form_name.'_'.$fieldname eq 'Ablammung_Field_82c1') {
                #print "kk";
                #}
                my @properties = ();

                push( @properties, $self->CreateCSSProperties( $self->GetValue( $fieldname, 'Name' ) ) );
                my $vtype = $self->GetValue( $fieldname, 'Type' );
                $vtype = lc($vtype);
                my $t = 'td';
                $t = 'table'  if ( $vtype eq 'block' );
                $t = 'td'     if ( $vtype eq 'link' );
                $t = 'img'    if ( $vtype eq 'image' );
                $t = 'td'     if ( $vtype eq 'label' );
                $t = 'select' if ( $vtype eq 'scrollinglist' );
                $t = 'input'  if ( $vtype eq 'textfield' );
                $t = 'input'  if ( $vtype eq 'filefield' );
                $t = 'input'  if ( $vtype eq 'button' );
                next if ( $t eq '' );

                if ( $#properties > -1 ) {
                    push( @ar_style, [ join( ';', @properties ), undef, $t, $form_name . '_' . $fieldname ] );
                }
            }
        }
    }

    #-- Test auf doppelte Styles mit sich selbst
    for ( my $i = 0; $i <= $#ar_style; $i++ ) {
        next if $ar_style[$i]->[1];
        for ( my $j = $i + 1; $j <= $#ar_style; $j++ ) {
            if (    ( $ar_style[$i]->[0] eq $ar_style[$j]->[0] )
                and ( $ar_style[$i]->[2] eq $ar_style[$j]->[2] ) )
            {
                if ( !$ar_style[$i]->[1] ) {
                    $ar_style[$j]->[1] = $ar_style[$i]->[3];
                }
                else {
                    $ar_style[$j]->[1] = $ar_style[$i]->[1];
                }
            }
        }
    }

    #-- Test auf doppelte alte Styles
    my @ar_keys = sort keys %{ $self->{'_style'} };
    for ( my $i = 0; $i <= $#ar_keys; $i++ ) {
        for ( my $j = 0; $j <= $#ar_style; $j++ ) {
            if (    ( $ar_style[$j]->[0] eq $self->{'_style'}->{ $ar_keys[$i] }->[0] )
                and ( $ar_style[$j]->[2] eq $self->{'_style'}->{ $ar_keys[$i] }->[2] ) )
            {
                if ( !$self->{'_style'}->{ $ar_keys[$i] }->[1] ) {
                    $ar_style[$j]->[1] = $ar_keys[$i];
                }
                else {
                    $ar_style[$j]->[1] = $self->{'_style'}->{ $ar_keys[$i] }->[1];
                }
            }
        }
    }

    #anfügen an Style
    for ( my $j = 0; $j <= $#ar_style; $j++ ) {
        $self->{_style}->{ $ar_style[$j]->[3] } = $ar_style[$j];
    }

    return $self->{'_style'};
}

sub ReduceStyle {
    my $self = shift;
    $self->{'_style'} = shift;

    #my @ar_keys=sort keys %{$self->{'_style'}};
    #for (my $i=0; $i<=$#ar_keys;$i++) {
    #  next if ($self->{'_style'}->{$ar_keys[$i]}->[1]);
    #
    #  for (my $j=$i+1; $j<=$#ar_keys;$j++) {
    #    next if ($self->{'_style'}->{$ar_keys[$j]}->[1]);
    #    if (($self->{'_style'}->{$ar_keys[$i]}->[0] eq $self->{'_style'}->{$ar_keys[$j]}->[0]) and
    #        ($self->{'_style'}->{$ar_keys[$i]}->[2] eq $self->{'_style'}->{$ar_keys[$j]}->[2])) {
    #	next if ($ar_keys[$i] eq $ar_keys[$j]) ;
    #        $self->{'_style'}->{$ar_keys[$j]}->[1]=$ar_keys[$i];
    #
    #        #$self->{'_style'}->{$ar_keys[$j]}=$ar_keys[$i] if ($self->{'_style'}->{$ar_keys[$i]}=~/:/);
    #      }
    #    }
    #  }
    my $style = '';
    ##-- reduce classes with identical properties to one class
    #my $hs_style=$self->{'_style'};
    #my @ar_keys1=keys %{$hs_style};
    #my @ar_keys =keys %{$self->{_style}};
    #foreach my $key1 (@ar_keys1) {
    #  #$self->{_style}->{$key1}=$hs_style->{$key1};
    #  foreach my $key (@ar_keys) {
    #    if (($self->{'_style'}->{$key}->[0] eq $hs_style->{$key1}->[0]) and
    #        ($self->{'_style'}->{$key}->[2] eq $hs_style->{$key1}->[2])) {
    #	next if ($key eq $key1) ;
    #        if ($self->{'_style'}->{$key}->[1]) {
    #	  $self->{'_style'}->{$key1}->[1]=$self->{'_style'}->{$key}->[1];
    #        } else {
    #          $self->{'_style'}->{$key1}->[1]=$key;
    #  	}
    #      }
    #    }
    #  }

    #-- write style for each class
    foreach my $key ( keys %{ $self->{'_style'} } ) {
        next if ( $self->{'_style'}->{$key}->[1] );
        $style .= $self->{'_style'}->{$key}->[2] . '.' . $key . '{' . $self->{'_style'}->{$key}->[0] . '}';
    }

    #map {$self->{'_style'}->{$_}=$_ if ($self->{'_style'}->{$_}=~/\;/) } keys %{$self->{'_style'}};

    return $style;
}

sub _init {
    my ( $self, $args_refs ) = @_;
    return if $self->{"_init"}{ scalar __PACKAGE__ }++;    # Conway p. 243

    $self->set_fieldtypes(
        {   button        => 'Button',
            frame         => 'LabFrame',
            tabular       => 'Tabular',
            scrollinglist => 'ScrollingList',
            browseentry   => 'ScrollingList',
            popupmenue    => 'PopupMenue',
            textfield     => 'TextField',
            textarea      => 'TextArea',
            radiogroup    => 'RadioGroup',
            checkbox      => 'CheckBox',
            checkboxgroup => 'CheckBoxGroup',
            filefield     => 'FileField',
            label         => 'Label',
            link          => 'Link',
            image         => 'Image',
        }
    );
    $self->{_columnbusy} = [];
    $self->{_maxcolumn}  = 0;
    $self->{_menu}->{_formcounter}=0;
    $self->gui_type('HTML');

}

sub GetZIndexFile {
    my $self = shift;
    my $file = shift;
    my ( $i, $useform );
    eval { open( IN, $file ) };
    return if ($@);
    while (<IN>) {
        ($useform) = ( $_ =~ /useform.*?\"(.*?)\"/i );
        last if ($useform);
    }
    close(IN);
    if ($useform) {
        if ( exists $self->{_zindex_url}->{$useform} ) {
            $i = $self->{_zindex_url}->{$useform};
            $self->{_menu}->{_formcounter}++;
        }
        else {
            $i = $self->{_menu}->{_formcounter}++;
            $self->{_zindex_url}->{$useform} = $i;
        }
    }
    return ( $i, $useform );
}

sub GetZIndex {
    my $self = shift;
    my $obj  = shift;
    my $file = shift;
    my $i;
    my $useform;
    #-- Ersetzen der URL durch ZIndex
    foreach my $blockname ( $obj->blocknames ) {
        foreach my $name_list ( '_misc_blockelement_list', '_field_list' ) {
            my $names_ref = $obj->GetValue( $blockname, $name_list );
            foreach my $fieldname (@$names_ref) {
                my $url = $obj->GetValue( $fieldname, 'URL' );
                if ($url) {
                    if (   ( $url =~ /\.mfrm$/ )
                        or ( ( $url =~ /\.pfrm$/ ) and ( $obj->GetValue( $fieldname, 'Command' ) eq 'do_open_report' ) )
                        )
                    {
                        if ( exists $self->{_zindex_url}->{$url} ) {
                            $i = $self->{_zindex_url}->{$url};
                        }
                        else {
                            $i = $self->{_menu}->{_formcounter}++;
                            $self->{_zindex_url}->{$url} = $i;
                        }
                        $obj->SetValue( $fieldname, 'URL', "'set_visible(" . $i . ")'" );
                    }
                    if ( $url =~ /\.rpt$/ ) {
                        ( $i, $useform ) = GetZIndexFile($url);
                        $obj->SetValue( $fieldname, 'URL', "'set_visible(" . $i . ")'" );
                    }
                }

            }
        }
    }
    return ( $i, $useform );
}

sub myfind {
    my $self  = shift;
    my $dir   = shift;
    my $query = $self->{_query};
    my @files;
    my $ext;
    my $t;

    my $a = $apiis->APIIS_HOME;
    for my $file ( glob $dir . '*' ) {
        my ( $volume, $directories, $filepart ) = File::Spec->splitpath($file);
        ( $filepart, $ext ) = ( $filepart =~ /\d*_*(.*?)(\.rpt|\.frm|\.mfrm|\.pdf|\.html)*$/i );
        next if $filepart eq 'CVS';
        
        #-- Translation
        $filepart=__($filepart);

        if ( -d $file ) {
            ;    #recursion for directories
            $self->{_menu}->{_text} .= "['" . $filepart . " ... ',null,null,\n";
            push @files, $self->myfind( $file . '/' );
            $self->{_menu}->{_text} .= '],' . "\n";
        }
        next if ( !$ext );
        next if ( !( ( $ext eq '.rpt' ) or ( $ext eq '.mfrm' ) or ( $ext eq '.frm' ) or ( $ext eq '.pdf' ) or ($ext eq '.html') ) );

        if ( $ext =~ '.(pdf|html)' ) {
#mue org            my $b = '/'.$query->param('m'). "/etc/menu/$file";
            my $b = "/etc/menu/$file";
            $b =~ s/$a/\.\./g;
            $self->{_menu}->{_text} .= "['" . $filepart . "','$b'],\n";
        }
        else {
            my $b = "/etc/menu/$file";
            if ( ( $ext eq '.mfrm' ) ) {
                my $f_obj = Apiis::Form::HTML->new( xmlfile => $apiis->APIIS_LOCAL . "/etc/menu/$file" );
                my $opt_p = $query->param('sid');
                my $opt_u = $query->param('user');
                my $opt_m = $query->param('m');
                my $opt_o = $query->param('o');
                if ( !$f_obj->status ) {
                    my $i;
                    #my $i=$self->GetZIndex($f_obj);

                    $f_obj->{_query} = $query;
                    $i = $self->{_menu}->{_formcounter} if ( !$i );
                    $i = 0 if ( !$i );
                    $f_obj->{_formcounter} = $i;

                    my $jsdao = $f_obj->_create_js_dataobject( $self->{_menu} );
                    $self->{_menu}->{_forms}->{ $i . $f_obj->{'_form_list'}[0] } = $jsdao;

                    $f_obj->{_menu} = 1;
                    $self->{_style} = $f_obj->MakeStyle( $self->{_style} );
                    my $table = $f_obj->run;
                    $self->{_table} .= '<form id="F' . $i . '" method="POST" action="/cgi-bin/GUI" 
			                          enctype="multipart/form-data" target="_blank">
					    <input type="hidden" name="sid" value="' . $opt_p . '"  />
					    <input type="hidden" name="g" value="' . "/etc/menu/$file" . '"  />
					    <input type="hidden" name="formtype" value="apiisajax"  />
					    <div id="e' . $i . '" style="position:absolute;top:160px;visibility:hidden">
	                       ' . $table . '</div></form>';
                    #$self->{_table} .= '<div id="e' . $i . '" style="position:absolute;top:160px;visibility:hidden">
                    #       ' . $table . '</div>';
                    #push( @{ $self->{_menu}->{_div}->{_ids} }, "e$i" );
                    $self->{_menu}->{_div}->{_ids}->[$i] = "e$i";
                    $self->{_menu}->{_text} .= "['" . $filepart . "','set_visible(" . $i . ")'],\n";
                    $self->{_menu}->{_formcounter}++;
                }
            }
            elsif ( $ext eq '.rpt' ) {

                #menuefile aus rpt (UseForm) extrahieren

                my ( $i, $useform ) = $self->GetZIndexFile( $apiis->APIIS_LOCAL . "/etc/menu/$file" );
                if (defined $i) {
                    my $f_obj = Apiis::Form::HTML->new( xmlfile => $apiis->APIIS_LOCAL . $useform );
                    if ( !$f_obj->status ) {
                        $f_obj->{_query} = $query;
                        if ( !defined $i ) {
                            $i = $self->{_menu}->{_formcounter};
                            $i = 0 if ( !$i );
                            $self->{_menu}->{_formcounter}++;
                        }
                        $f_obj->{_formcounter} = $i;

                        my $jsdao = $f_obj->_create_js_dataobject( $self->{_menu} );
                        $self->{_menu}->{_forms}->{ $i . $f_obj->{'_form_list'}[0] } = $jsdao;

                        $f_obj->{_menu} = 1;
                        $self->{_style} = $f_obj->MakeStyle( $self->{_style} );
                        my $table = $f_obj->run;
                        $self->{_table} .= '<form id="F' . $i . '" method="POST" action="/cgi-bin/GUI" 
			                          enctype="multipart/form-data" target="_blank">
					    <input type="hidden" name="sid" value="' . $opt_p . '"  />
					    <input type="hidden" name="g" value="' . "/etc/menu/$file" . '"  />
					    <div id="e' . $i . '" style="position:absolute;top:160px;visibility:hidden">
	                       ' . $table . '</div></form>';
                        push( @{ $self->{_menu}->{_div}->{_ids} }, "e$i" );
                        $self->{_menu}->{_text} .= "['" . $filepart . "','set_visible(" . $i . ")'],\n";
                    }
                    else {
                        $self->status(1);
                        $apiis->errors( $f_obj->errors );
                        return;
                    }

                }
                else {
                    $self->{_menu}->{_text}
                        .= "['"
                        . $filepart
                        . "','/cgi-bin/GUI?sid=$opt_p&__form=$b','$file'],\n";

                }
            }
            else {
                $b = "/etc/menu/$file";
                $self->{_menu}->{_text}
                    .= "['"
                    . $filepart
                    . "','/cgi-bin/GUI?sid=$opt_p&formtype=apiisajax&g=$b','$file'],\n";
            }
        }
        push @files, $file;
    }
}

sub PrintMenue2 {
    $self = shift;
    my $query = $self->{_query};
    $opt_p                         = $query->param('sid');
    $opt_u                         = $query->param('user');
    $opt_m                         = $query->param('m');
    $opt_o                         = $query->param('o');
    $self->{_menu}->{_div}->{_ids} = [];

    my $enc = $self->GetValue( $self->generalnames->[0], 'CharSet' );
    my $css = $self->GetValue( $self->generalnames->[0], 'StyleSheet' );
    my $title = "OviCap-Menue";

    #Read all links from root directory for forms and reporst (is /etc/menu)
    use File::Spec;
    use File::Path;
    my @dirs     = ();
    my $startdir = $apiis->APIIS_LOCAL . "/etc/menu";
    eval { opendir( DIR, $startdir ) };
    if ($@) {
        $self->status(1);
        $self->errors(
            Apiis::Errors->new(
                type      => 'CODE',
                severity  => 'CRIT',
                from      => 'Apiis::Form::HTML::run',
                msg_short => sprintf( "$! '%s'", $startdir )
            )
        );
        return;
    }
    my @d = readdir(DIR);
    foreach (@d) {
        next if ( $_ =~ /^\./ );
        next if ( $_ =~ /CVS/ );
        next if -d;
        push( @dirs, $_ );
    }
    closedir(DIR);
    @dirs = sort @dirs;

    # create structure for javascriptmenu
    # loop over all subdirectories of /etc/menu

    my @files;
    $self->{_menu}->{_text} = 'var MENU_ITEMS = [' . "\n";

    # change to APIIS_HOME or APIIS_LOCAL:
    chdir $startdir or die __( "Cannot change to dir [_1]: [_2]", $startdir, $! ), "\n";
    foreach my $thisdir (@dirs) {
        push @files, $self->myfind($thisdir);
    }
    $self->{_menu}->{_text} .= ']' . "\n";

    my @ar_ids = @{ $self->{_menu}->{_div}->{_ids} };
    my $menu = 'var mfiles = ["' . join( '","', @ar_ids ) . '"];';
    $text = $self->{_menu}->{_text} . ';';

    #-- loop over all reduced datasources
    my $data = 'var js = new Object();';
    foreach my $key ( keys %{ $self->{_menu}->{_js} } ) {
        next if ( $key eq '_alias' );
        $data .= 'js.' . $key . '= new Object();';
        foreach my $key2 ( keys %{ $self->{_menu}->{_js}->{$key} } ) {
            $data .= 'js.' . $key . '.' . $key2 . '= new Object();';
            foreach my $key3 ( keys %{ $self->{_menu}->{_js}->{$key}->{$key2} } ) {
                $data
                    .= 'js.' 
                    . $key . '.' 
                    . $key2 . '.' 
                    . $key3 . '='
                    . $self->{_menu}->{_js}->{$key}->{$key2}->{$key3} . ';';
            }
        }
    }

    print $query->header(-charset=>"$enc");

    my $t = $self->ReduceStyle( $self->{_style} );
    my $target = $self->GetValue( $self->generalnames->[0], 'Target' );
    $title = $self->GetValue( $self->generalnames->[0], 'Description' );

    #-- if translation
    if ($title=~/^__\('(.*)'\)/) {
                
        #-- translate
        $title=main::__($1);
    }  

    $target = '' if ( !defined $target );
    print $query->start_html(
        -encoding => $enc,
        -style    => { src => $css, -code => $t },
        -script   => [ { -language => 'JavaScript', -src => '/lib/menu.js' } ],
        -class    => "menu",
        -title    => $title,
        -onKeyUp  => "JumpFields(event)",
        #        -onLoad   => "ShowMessages();Refresh()"
    );
    #print $query->start_form( -action => "/cgi-bin/GUI", -method => "POST", -target => "_blank" );
    #print $query->hidden( -name => 'user', -default => $query->param('user') );
    #print $query->hidden( -name => 'sid',  -default => $query->param('sid') );
    #print $query->hidden( -name => 'm',    -default => $query->param('m') );
    #print $query->hidden( -name => 'o',    -default => $query->param('o') );
    #print $query->hidden( -name => 'f',    -default => '1' );
    my $va = "<input type='hidden' id='__form' name='__form' value='" . $query->param('__form') . "'/>";
    $va .= '<input type="hidden" id="__formtype" name="formtype" default="apiisajax">';
    $va .= '<input type="hidden" id="__command" name="__command" default="none">';
    $va .= '<input type="hidden" id="__commandfield" name="__commandfield" default="none">';
    $va .= '<input type="hidden" id="__records" name="__records" default="none">';
    $va .= "<script language='JavaScript'>var xf=new Object();</script>";
    $va .= "<script language='JavaScript' src='/lib/form.js'></script>";

    my $logo = $apiis->{'_logo'};

    my $vtable;
    
    if ($logo) {
        $vtable=$query->TR(
                $query->td( { -width => 120, -height => 110 }, $query->img( { -src => "/$logo" }) ) 
            );
    } else {
        $vtable=$query->TR(
                $query->td( { -width => 120, -height => 110 }, $query->h1( $opt_m ) ) 
            )
    }
    
    $vtable.=$query->TR(
                $query->td( { -height => "50px" }, $query->img( { -src => "/icons/blank1.gif" } ) ),
                $query->td($va)
    );

    print $query->table($vtable);

    return if ( $self->GetValue( $self->generalnames->[0], 'Target' ) );

    print <<EOF

<!-- menu script itself. you should not modify this file -->
<script language="JavaScript" src="/lib/menu.js"></script>
<!-- items structure. you can see same structure is shared by 1-st and 2-nd menu -->
<!--script language="JavaScript" src="/lib/menuitems.js"></script> -->
<!-- files with geometry and styles structures for coresponding menus -->
<script language="JavaScript" src="/lib/menu_tpl1.js"></script>
<script language="JavaScript">
	<!--//
	// Note where menu initialization block is located in HTML document.
	// Don't try to position menu locating menu initialization block in
	// some table cell or other HTML element. Always put it before </body>

	// each menu gets two parameters (see demo files)
	// 1. items structure
	// 2. geometry structure

$text

$data

new menu (MENU_ITEMS, MENU_POS1);
//var connect_selects=new Array ("Field_0","Field_1");

//var pos=new Array();
//for (i = 0; i < connect_selects.length;i++) {pos[connect_selects[i]]=i};


$menu

	// make sure files containing definitions for these variables are linked to the document
	// if you got some javascript error like "MENU_POS1 is not defined", then you've made syntax
	// error in menu_tpl.js file or that file isn't linked properly.
	
	// also take a look at stylesheets loaded in header in order to set styles
	//-->
</script>
EOF
        ;
}

sub _create_js_dataobject {
    my $self     = shift;
    my $obj_menu = shift;
    my $src;

    foreach my $blockname ( $self->blocknames ) {
        my $ds = $self->GetValue( $blockname, '_datasource_list' );
        $ds = $ds->[0];

        #-- Datenquelle ermitteln
        my $ds_type = lc $self->GetValue( $ds, 'Type' );
        if ( $ds_type eq 'sql' ) {
            $src = $self->GetValue( $ds, 'Statement' );
        }
        elsif ( $ds_type eq 'none' ) {
            next;
        }

        #-- ignore space and letter to identify the same source
        $src = lc($src);
        $src =~ s/\s+//g;

        #-- test, if ds already exists
        if ( exists $obj_menu->{_js}->{_alias}->{$src} ) {
            $obj_menu->{_forms}->{ $obj_menu->{_formcounter} . $self->{'_form_list'}[0] } =
                $obj_menu->{_js}->{_alias}->{$src};
        }
        else {
            my @ar_d = ();
            my @ar_f = ();
            foreach my $fieldname ( @{ $self->GetValue( $blockname, '_field_list' ) } ) {
                if ( $self->GetValue( $fieldname, 'DSColumn' ) ) {
                    my $j = $self->GetValue( $self->GetValue( $fieldname, 'DSColumn' ), 'Order' );
                    $ar_d[$j] = $self->GetValue( $fieldname, '_data_ref' );
                }
            }
            my @t = ();
            #for ( my $i = 0 ; $i <= $#{ $ar_d[0] } ; $i++ ) {
            #    my @a = ();
            #    for ( my $j = 0 ; $j <= $#ar_d ; $j++ ) {
            #        $a[ $j * 2 ] = $ar_d[$j]->[$i];
            #        $a[ $j * 2 + 1 ] = $ar_d[$j]->[$i];
            #    }
            #    push( @t, "['" . join( "','", @a ) . "']" );
            #}

            #$obj_menu->{_js}->{_alias}->{'_ds_counter'}++;
            #my $counter=$obj_menu->{_js}->{_alias}->{'_ds_counter'};
            #$obj_menu->{_forms}->{$obj_menu->{_formcounter}.$self->{'_form_list'}[0]}=$counter;
            #$obj_menu->{_js}->{_alias}->{$src}=$counter;
            #$obj_menu->{_js}->{_dataobj}->{$counter}= "[". join("," ,@t). "]";

            $obj_menu->{_js}->{ $self->{_form_list}[0] }->{$ds}->{_formcounter} = $obj_menu->{_formcounter};
            $obj_menu->{_js}->{ $self->{_form_list}[0] }->{$ds}->{_data} = "[" . join( ",", @t ) . "]";
            $obj_menu->{_js}->{ $self->{_form_list}[0] }->{$ds}->{_fields} =
                "['" . join( "','", @{ $self->GetValue( $blockname, '_field_list' ) } ) . "']";
        }
    }
}

sub PrintHeaderAjax {
    my $self = shift;
    print "Content-type: text/html\n\n";
}

#################################################################
#  Init a HTML-Form using AJAX
#################################################################

sub PrintHeaderInit {
    my $self   = shift;
    my $opt_js = shift;
    my $query  = $self->{_query};
    my $header;
    my $enc    = $self->GetValue( $self->generalnames->[0], 'CharSet' );
    my $css    = $self->GetValue( $self->generalnames->[0], 'StyleSheet' );
    my $title  = $self->GetValue( $self->generalnames->[0], 'Description' );
    
    #-- if translation
    if ($title=~/^__\('(.*)'\)/) {
                
        #-- translate
        $title=main::__($1);
    }  

    my $width  = $self->GetValue( $self->formnames->[0],    'Width' );
    my $height = $self->GetValue( $self->formnames->[0],    'Height' );

    $self->{_formoptions} = '';
    $self->{_formoptions} .= ',width=' . $width   if ($width);
    $self->{_formoptions} .= ',height=' . $height if ($height);
    my $t;
    my $navigationbar;

    print $self->{_query}->header(-charset=>"$enc");

    # Create StyleSheet
    ( $self->{_style}, $t ) = $self->Apiis::Form::JS::CreateCSS::MakeStyle( $self->{_style} );

    # write code for <body>
    $header .= '<head>';
    $header .= '<title>' . $title . '</title>';
    $header .= '<link href="' . $css . '" rel="stylesheet" type="text/css"/>';
    $header .= '<script type="text/javascript" src="/lib/json.js"></script>';
    $header .= '<script type="text/javascript" src="/lib/ajax.js"></script>';
    $header .= '<script type="text/javascript" src="/lib/formajax.js"></script>';

    #if ($navigationbar) {
    #  $header .= '<script type="text/javascript" src="/lib/formnavigation.js"></script>';
    #}

    $header .= '<style>' . $t . '</style>';
    $header .= '</head>';
    $header .= '<body class="menu">';

    # write code for <form>
    $header .= $query->start_form( -action => "/cgi-bin/GUI", -method => "POST", -encoding => $enc );

    $self->{_table} = $header;
}
####################################################################

sub PrintHeader {
    my $self   = shift;
    my $opt_js = shift;
    my $query  = $self->{_query};

    my $enc    = $self->GetValue( $self->generalnames->[0], 'CharSet' );
    my $css    = $self->GetValue( $self->generalnames->[0], 'StyleSheet' );
    my $title  = $self->GetValue( $self->generalnames->[0], 'Description' );
    
    #-- if translation
    if ($title=~/^__\('(.*)'\)/) {
                
        #-- translate
        $title=main::__($1);
    }  

    my $width  = $self->GetValue( $self->formnames->[0],    'Width' );
    my $height = $self->GetValue( $self->formnames->[0],    'Height' );
    $opt_p = $query->param('sid');
    $opt_u = $query->param('user');
    $opt_m = $query->param('m');
    $opt_o = $query->param('o');

    print $query->header(-charset=>"$enc");
    my $t;
    ( $self->{_style}, $t ) = $self->Apiis::Form::JS::CreateCSS::MakeStyle( $self->{_style} );

    #$self->{_style}=$self->MakeStyle($self->{_style});
    #my $t=$self->ReduceStyle($self->{_style});
    my @a;

    #    $a[0]="<head><link rel='stylesheet' type='text/css' href='$css'/></head>";
    #    $a[1]="<body onKeyUp='JumpFields(event)' onLoad='ShowMessages();Refresh()' class='menu'>";
    #    $a[2]="<form action='/cgi-bin/GUI' method='POST'>";
    #    $a[4]="<input type='hidden' name='sid' default='".$query->param('sid')."'>";
    #    $a[7]="<input type='hidden' name='f' default='1'>";
    #    $a[8]="<script language='JavaScript' src='/lib/form.js'></".'+'."script>";
    #    print ' Content-type: text/html<script language="JavaScript" scr="/lib/form.js">
    #  	    var w = window.open("","KleinesFenster","width=200,height=200");
    #  	     w.document.write("'.$a[0].'");
    #  		     w.document.write("'.$a[8].'");
    #		     w.document.write("'.$a[1].'");
    #	     w.document.title="'.$title.'";
    #		     w.document.write("'.$a[2].'");
    #		     w.document.write("'.$a[3].'");
    #		     w.document.write("'.$a[4].'");
    #		     w.document.write("'.$a[5].'");
    #		     w.document.write("'.$a[6].'");
    #		     w.document.write("'.$a[7].'");
    #		     '
    print $query->start_html(
        -encoding => $enc,
        -style    => { src => $css, -code => $t },
        -script   => [ { -language => 'JavaScript', -src => '/lib/menu.js' } ],
        -class    => "menu",
        -title    => $title,
        -onKeyUp  => "JumpFields(event)",
        #        -onLoad   => "ShowMessages();Refresh()"
    );
    #print $query->start_form( -action => "/cgi-bin/GUI", -method => "GET" );
    #print $query->hidden( -name => 'user', -default => $query->param('user') );
    #print $query->hidden( -Id => 'sid', -name => 'sid', -default => $query->param('sid') );
    #print $query->hidden( -name => 'm', -default => $query->param('m') );
    #print $query->hidden( -name => 'o', -default => $query->param('o') );
    #print $query->hidden( -name => 'f', -default => '1' );
    my $va = "<input type='hidden' id='__form' name='__form' value='" . $query->param('__form') . "'/>";
    $va .= '<input type="hidden" id="__formtype" name="formtype" default="apiisajax">';
    $va .= '<input type="hidden" id="__command" name="__command" default="none">';
    $va .= '<input type="hidden" id="__commandfield" name="__commandfield" default="none">';
    $va .= '<input type="hidden" id="__records" name="__records" default="none">';
    $va .= "<script language='JavaScript'>var xf=new Object();</script>";
    $va .= "<script language='JavaScript' src='/lib/form.js'></script>";

    my $logo = $apiis->APIIS_LOCAL;
    $t = $apiis->APIIS_HOME;
    ($logo) = ( $logo =~ /$t(.*)?/ );
    print $query->table(
        $query->TR(
#            $query->td( { -width => 120, -height => 110 }, $query->img( { -src => "$logo/etc/logo.jpg" }, ) ),
#            $query->td( { -valign => "middle" }, $query->h1($opt_m) )
        ),
        $query->TR(
#            $query->td( { -height => "50px" }, $query->img( { -src => "/icons/blank1.gif" } ) ),
            $query->td($va)
        )
    );
}

sub PrintForm {
    my $self  = shift;
    my $query = $self->{_query};
    print $self->{_table};
}

sub PrintRowForm {
    my $self       = shift;
    my $vcell      = shift;
    my @cell       = @{$vcell};
    my $cell       = '';
    my $properties = '';
    my $query      = $self->{_query};

    #--
    for ( my $i = 0; $i < $self->{_maxcolumn}; $i++ ) {
        if ( !$self->{_setcolumnbusy}->[$i] ) {
            $cell .= $query->td( {}, "" );
        }
        else {
            $cell .= $cell[$i];
        }
    }
    $self->{_setcolumnbusy} = [];
    return $query->TR( {$properties}, $cell );
}

#-- mue wird wohl nirgends benötigt, auskommentiert 3.11.2020
#sub RunAjax {
#    my $self = shift;
#    my $cgi  = $self->{_cgi};
#
#    # Dataobject from json erstellen
#    my $js   = uri_unescape( $cgi->{'json'} );
#    my $json = JSON::XS->new->utf8->decode ( $js ) ;
#
#    # if Query
#    #
#    return 0;
#}

##########################################################################
# InitJSONData
##########################################################################
sub InitJSONData {
    my $self    = shift;
    my $value   = shift;
    my $newform = shift;

    my $hs_data = {};
    my $data    = {};
    $value = 'Ok.' if ( !$value );
    $hs_data = {
        'form'    => $self->xmlfile,
        'sid'     => $self->{_cgi}->{sid},
        'command' => '',
        'info'    => $value,
        'result'  => {'insert'=>'','update'=>'','error'=>''},
        'data'    => []
    };

    my $cgi_parameter = {};
    $cgi_parameter=$self->{'_query'}->Vars() if ($self->{'_query'});

    my $setparameter;

    # loop over each block in a form
    #
    BLOCK: foreach my $blockname ( $self->blocknames ) {

        #--- for forms with a parameter (subforms)
        #--- ask for events
        #
        if ( $self->GetValue( $blockname, '_event_list' ) ) {
            foreach my $event ( @{ $self->GetValue( $blockname, '_event_list' ) } ) {
                my $parameter_ref = $self->get_event_par_ref( { eventname => $event } );
                if ($parameter_ref) {
                    if ( ( $self->GetValue( $event, 'Action' ) eq 'SetQuery' ) ) {
                        my $from_master_ref = $parameter_ref->{'master_sourcefield'};
                        my $to_client_ref   = $parameter_ref->{'client_targetfield'};
                        if ($from_master_ref) {
                            $setparameter = 1;
                            for my $idx ( 0 .. @$from_master_ref - 1 ) {
                                if ( exists $cgi_parameter->{ $from_master_ref->[$idx] } ) {
                                    my $target_data_ref = $self->GetValue( $to_client_ref->[$idx], '_data_ref' );
                                    $$target_data_ref = $cgi_parameter->{ $from_master_ref->[$idx] };
                                    $idx++;
                                }
                            }
                        }
                    }
                }
            }
        }

        my $field_ref = $self->GetValue( $blockname, '_field_list' );
        my $ds        = $self->GetValue( $blockname, 'DataSource' );

        # loop over all fieldelements of the actual block
        # skip all fields of type label, button, image,link and the textfield __nav_r
        # because the have no data
        # create for all other elements an array with three entries ['','','']
        #   1. Value from database later to database
        #   2. backup of the value from database after changing the value in field 1
        #   3. error message

        for my $fieldname (@$field_ref) {

            my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
            next
                if ( ( $fieldtype eq 'label' )
                or ( $fieldtype eq 'button' )
                or ( $fieldtype eq 'image' )
                or ( $fieldname eq '__nav_r' )
                or ( $fieldtype eq 'link' ) );
            next
                if (
                (       $self->GetValue( $fieldname, 'Visibility' )
                    and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                )
                );

            next if ( exists $self->{'_disable_targetfield'}->{$fieldname} );

            #-- if parameter gets from another form
            my $field;
            
            #-- get Value of a referenced field
            if ( $self->GetValue( $fieldname, 'DefaultField' ) ) {
                
                #-- get name of field 
                my $vfield  = $self->GetValue( $fieldname, 'DefaultField' );

                #-- get value of the referenced field 
                $field      = ${ $self->GetValue( $vfield, '_data_ref' ) };
            } 
            elsif ( $self->GetValue( $fieldname, 'DefaultFunction' )
                and ( $self->GetValue( $fieldname, 'DefaultFunction' ) eq 'apiisrc' ) )
            {
                $field = $apiis->{ '_' . $self->GetValue( $fieldname, 'Default' ) };
                $field =~ s/\'//g;
            }
            elsif ( $self->GetValue( $fieldname, 'DefaultFunction' )
                and ( $self->GetValue( $fieldname, 'DefaultFunction' ) eq 'today' ) )
            {
                $field = $apiis->today;
            }
            elsif ( defined $self->GetValue( $fieldname, 'Default' )
                and ( $self->GetValue( $fieldname, 'Default' ) ne '' ) )
            {
                $field = $self->GetValue( $fieldname, 'Default' );
            }
            elsif ( ($setparameter) or ($newform) ) {
                $field = ${ $self->GetValue( $fieldname, '_data_ref' ) };

                if (  $self->GetValue( $fieldname, '_list_ref' ) ) { 

                    $field = $self->GetValue( $fieldname, '_list_ref' )->[0];
                }
            }
            $field = '' if ( !$field );
            $data->{$fieldname} = [ $field, '', '' ];

        }
    }

    #
    push( @{ $hs_data->{'data'} }, $data );

    #-- if a subform with parameter
    #-- fill datahash with parameter from CGI and execute QueryJSONData
    #
    if ($setparameter) {
        $self->{_cgi}->{json} = JSON::to_json( $hs_data) ;
#mue        $self->{_cgi}->{json} = JSON::XS->new->utf8->encode ( $hs_data );

        return $self->QueryJSONData();
    }
    else {
        return (JSON::to_json( $hs_data)) ;
#mue        return (JSON::XS->new->utf8->encode ( $hs_data ));
    }
}

##########################################################################
# CreateJSONData
##########################################################################

sub CreateJSONData {
    my $self  = shift;
    my $args  = shift;
    my $jsond = $self->InitJSONData( undef, $args );
    $self->{_table} .= '<script language="JavaScript">$form=' . $jsond . ';</script>';
}

##########################################################################
# SaveJSONData
##########################################################################

sub SaveJSONData {
    my $self = shift;

    my $jsond = JSON::from_json( $self->{_cgi}->{json}) ;

    #Commando rücksetzen
    $jsond->{'command'} = '';
    $jsond->{'info'}    = '';
    my $vguid = '';
    my %ext_fields;
    my $upok  = 0;
    my $inok  = 0;
    my $upnok = 0;
    my $innok = 0;
    my $data  = $jsond->{'data'};

    # alten Datensatz leeren
    $jsond->{'data'}   = [];
    $jsond->{'errors'} = [];

    BLOCK: foreach my $blockname ( $self->blocknames ) {
        my @fieldlist = @{ $self->GetValue( $blockname, '_field_list' ) };

        for my $fieldname (@fieldlist) {
            if (    ( $self->GetValue( $fieldname, 'DSColumn' ) )
                and ( $self->GetValue( $self->GetValue( $fieldname, 'DSColumn' ), 'DBName' ) ) )
            {
                if ( $self->GetValue( $self->GetValue( $fieldname, 'DSColumn' ), 'DBName' ) eq 'guid' ) {
                    $vguid = $fieldname;
                }
                $ext_fields{ $self->GetValue( $self->GetValue( $fieldname, 'DSColumn' ), 'DBName' ) } = $fieldname;
            }
        }

        my $ds = $self->GetValue( $blockname, 'DataSource' );
        my $LO;
        if ( ( $ds ne '' ) and $self->GetValue( $ds, '_parameter_list' ) ) {
            foreach ( @{ $self->GetValue( $ds, '_parameter_list' ) } ) {
                $LO = $self->GetValue( $_, 'Value' ) if ( uc( $self->GetValue( $_, 'Key' ) ) eq 'LO' );
            }
        }
        if ($LO) {

            no strict "refs";
            my $load_string = "use $LO";
            eval $load_string;
            if ($@) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => '_call_LO',
                        msg_short => 'Cannot find/load LoadObject $LO',
                        msg_long  => $@,
                    )
                );
                return;
            }
        }

        #-- loop over all records which come from client
        foreach my $record ( @{$data} ) {

            my $up_ins;
            #-- fill recordobject with data
            for my $fieldname (@fieldlist) {

                my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
                next
                    if ( ( $fieldtype eq 'label' )
                    or ( $fieldtype eq 'button' )
                    or ( $fieldtype eq 'image' )
                    or ( $fieldtype eq 'link' )
                    or ( $fieldname eq '__nav_r' ) );

                next
                    if (
                    (       $self->GetValue( $fieldname, 'Visibility' )
                        and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                    )
                    );

                if ( !exists $data->[0]->{$fieldname} ) {
                    next;
                }
                else {
                    $self->{'_activ_update_fields_from_cgi'}->{$fieldname}=$fieldname;
                }

                #-- replace _data_ref with content from client
				#$record->{$fieldname}->[0]=undef if ($record->{$fieldname}->[0] eq '');

                #delete old error-messages
                $record->{$fieldname}->[2] = '';

                #-- Zeiger der Spalte des Recordobjects auf Scalar
                my $a = $self->GetValue( $fieldname, '_data_ref' );

                #-- Zeiger (RObj) mit Datenwert füllen 
                $$a = $record->{$fieldname}->[0];

                #-- additional set data_refs if scrollinglist 
                if ($self->GetValue($fieldname,'Type') eq 'ScrollingList') {
                
                    #-- set first value of array 
                    my $b = $self->GetValue( $fieldname, '_data_refs' );
                    $b->[0] = $a;
                }

                #-- if InternalData and _translate_hash then translate internal value into external
                #-- necessary to encode data and to be compatible with TK
                if ( $self->GetValue( $fieldname, '_datasource_translate' )
                    and ( $self->GetValue( $fieldname, 'InternalData' ) eq "yes" ) )
                {
                    $$a =
                        $self->GetValue( $fieldname, '_datasource_translate' )
                        ->{ ${ $self->GetValue( $fieldname, '_data_ref' ) } }[0];
                }

                #-- if field a guid field and has a guid-number, than make an update otherwise an insert
                $up_ins = '1' if ( ( $fieldname eq $vguid ) and ( $record->{$fieldname}->[0] or ( $record->{$fieldname}->[0] ne '') ) );
            }

            if ($up_ins) {
                $self->update_block( { blockname => $blockname } );
            }
            else {
                if ($LO) {

                    #-- $record auf $datahash umwandeln
                    my $data_hash = {};
                    my $key, my $value;
                    while ( ( $key, $value ) = each %{$record} ) {
                        $data_hash->{$key} = $value->[0];
                    }
                    no strict "refs";
                    my ( $err_status, $err_ref ) = &$LO( $self, $data_hash );

                    $self->status($err_status);
                    $self->errors($err_ref);
                }
                else {
                    $self->insert_block( { blockname => $blockname } );
                }
            }

            if ( $self->status ) {
                my $error = {};
                if ($up_ins) {
                    $upnok++;
                }
                else {
                    $innok++;
                }
                for ( my $l = 0; $l <= $#{ $self->errors }; $l++ ) {
                    my $err = $self->errors->[$l];
                    next unless ( defined $err );
                    my @tmp = ();
                    if ( defined $err->ext_fields() ) {

                        my $notfound=1;

                        foreach my $db_col ( @{ $err->ext_fields() } ) {

                            if (exists $record->{$db_col}) {
                                $record->{$db_col}->[2] = $err->msg_long;
                                $record->{$db_col}->[2] = $err->msg_short if ( !$err->msg_long );

                                $notfound=undef;
                            }
                        }

                        #- if field not exists in hash 
                        if ($notfound) {
                            $error->{ $err->id } = $err->syslog_print;
                        }
                    }
                    else {
                        $err->backtrace('');
                        my $a = $err->msg_short;
                        $a =~ s/.*duplicate key.*/Schlüsselverletzung: Schlüssel existiert bereits in der Datenbank/g;
                        $a =~ s/.*voilate.*/Schlüsselverletzung: Schlüssel existiert noch nicht in der Datenbank/g;
                        $error->{ $err->id } = $err->syslog_print;
                    }
                    $self->errors->[$l] = undef;
                    $self->status(0);

                    #noch machen für related fields
                }
                push( @{ $jsond->{'data'} },   $record );
                push( @{ $jsond->{'errors'} }, $error );
            }
            else {
                if ($up_ins) {
                    $upok++;
                }
                else {
                    $inok++;
                }
            }

        }
    }

    my $ui = $upnok + $innok;
    if ( $jsond->{'data'}->[0] ) {
        $jsond->{'info'}   = "$upok update $inok insert $ui errors";
        $jsond->{'result'} = {'update'=>$upok,'insert'=>$inok, 'errors'=>$ui};
    }
    else {

        #letzter Datensatz;
        my $data_default = $data->[ $#{$data} ];
        BLOCK: foreach my $blockname ( $self->blocknames ) {

            my @fieldlist = @{ $self->GetValue( $blockname, '_field_list' ) };

            for my $fieldname (@fieldlist) {
                next if ( !exists $data->[0]->{$fieldname} );

                if ( !$self->GetValue( $fieldname, 'DefaultFunction' )
                    or ( $self->GetValue( $fieldname, 'DefaultFunction' ) ne "lastrecord" ) )
                {
                    $data_default->{$fieldname}->[0] = '';
                    $data_default->{$fieldname}->[1] = '';
                    $data_default->{$fieldname}->[2] = '';
                }
            }
        }
        $jsond->{'info'} = "$upok update $inok insert $ui errors";
        $jsond->{'result'} = {'update'=>$upok,'insert'=>$inok, 'errors'=>$ui};
        $jsond->{'data'} = [$data_default];
    }
   
    return JSON::to_json( $jsond) ;
#    print JSON::XS->new->utf8->encode ( $jsond );
}

##########################################################################
# RunJSONEvents
##########################################################################

sub RunJSONEvents {
    my $self = shift;

#    my $jsond = JSON::XS->new->utf8->decode ( $self->{'_cgi'}->{'json'} ) ;
    my $jsond = JSON::from_json( $self->{_cgi}->{json}) ;

    #Commando rücksetzen
    $jsond->{'command'} = '';

    BLOCK: foreach my $blockname ( $self->blocknames ) {

        my @fieldlist = @{ $self->GetValue( $blockname, '_field_list' ) };

        for my $fieldname (@fieldlist) {
            next if ( !exists $jsond->{data}->[0]->{$fieldname} );

            my $a = $self->GetValue( $fieldname, '_data_ref' );
            $$a = $jsond->{'data'}->[0]->{$fieldname}->[0];

            #-- if InternalData and _translate_hash then translate internal value into external
            #-- necessary to encode data and to be compatible with TK
            if ( $self->GetValue( $fieldname, '_datasource_translate' )
                and ( $self->GetValue( $fieldname, 'InternalData' ) eq "yes" ) )
            {
                $$a =
                    $self->GetValue( $fieldname, '_datasource_translate' )
                    ->{ ${ $self->GetValue( $fieldname, '_data_ref' ) } }[0];
            }

        }
    }
    $self->RunEvent( { elementname => $jsond->{'event'}, eventtype => 'CallForm', } );

    $jsond->{'info'} = "Ok.";
    $jsond->{'newform'} = [ $self->{'newform'} ] if ( exists $self->{'newform'} );
    return JSON::to_json( $jsond) ;
#mue    return JSON::XS->new->utf8->encode ( $jsond );
}

##########################################################################
# QueryJSONData
##########################################################################

sub QueryJSONData {
    my $self = shift;

    my $json = JSON::XS->new();  #mue  unmapping => 1 );
    my $jsond = $json->decode( $self->{_cgi}->{json} );

    #-- save command 
    my $command=$jsond->{'command'};
    if ($self->{'_cgi'}->{'command'}) {
        $command=$self->{'_cgi'}->{'command'};
    }

    #Commando rücksetzen
    $jsond->{'command'} = '';

    #-- Loop over all blocks in form
    BLOCK: foreach my $blockname ( $self->blocknames ) {
        
        #-- get blockname 
        my $ds = $self->GetValue( $blockname, 'DataSource' );

        #-- data string is empty and get a default setting
        if (( $command eq 'do_query_block_default') and $self->GetValue( $ds, 'DefaultFunction' )) {

            my $status_msg;
            my $LO=$self->GetValue( $ds, 'DefaultFunction' );

            no strict "refs";
            my $load_string = "use $LO";
            
            eval $load_string;
            
            #-- check for errors
            if ($@) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'ERR',
                        from      => '_call_LO',
                        msg_short => 'Cannot find/load LoadObject $LO',
                        msg_long  => $@,
                    )
                );
                return;
            }

            #-- execute LO
            my ( $err_status, $err_ref ) = &$LO( $self, $jsond );
        }
        
        my @fieldlist = @{ $self->GetValue( $blockname, '_field_list' ) };

        for my $fieldname (@fieldlist) {

                my $tab_col = $self->GetValue( $fieldname, 'DSColumn' );
                my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
                next
                    if ( ( $fieldtype eq 'label' )
                    or ( $fieldtype eq 'button' )
                    or ( $fieldtype eq 'image' )
                    or ( $fieldtype eq 'link' )
                    or ( $fieldname eq '__nav_r' ) );
                next
                    if (
                    (       $self->GetValue( $fieldname, 'Visibility' )
                        and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                    )
                    );

                next if ( exists $self->{'_disable_targetfield'}->{$fieldname} );



            my $a = $self->GetValue( $fieldname, '_data_ref' );
            $$a = $jsond->{'data'}->[0]->{$fieldname}->[0];

            #-- if InternalData and _translate_hash then translate internal value into external
            #-- necessary to encode data and to be compatible with TK
            if ( $self->GetValue( $fieldname, '_datasource_translate' )
                and ( $self->GetValue( $fieldname, 'InternalData' ) eq "yes" )
                and ($jsond->{'data'}->[0]->{ $fieldname }->[0] ) )
            {
                $$a =
                    $self->GetValue( $fieldname, '_datasource_translate' )
                    ->{ ${ $self->GetValue( $fieldname, '_data_ref' ) } }[0];
            }

        }

        $self->query_block( { blockname => $blockname } );

        if ($self->status) {
    
            $jsond->{'errors'} = [];

                my $error = {};
                
                for ( my $l = 0; $l <= $#{ $self->errors }; $l++ ) {
                    my $err = $self->errors->[$l];
                    next unless ( defined $err );
                    my @tmp = ();
                        $err->backtrace('');
                        my $a = $err->msg_short;
                        $a =~ s/.*duplicate key.*/Schlüsselverletzung: Schlüssel existiert bereits in der Datenbank/g;
                        $a =~ s/.*voilate.*/Schlüsselverletzung: Schlüssel existiert noch nicht in der Datenbank/g;
                        $error->{ $err->id } = $err->syslog_print;
                    $self->errors->[$l] = undef;
                    $self->status(0);

                    #noch machen für related fields
                }
                push( @{ $jsond->{'errors'} }, $error );

            last BLOCK;
        }

        my $q_records_ref = $self->GetValue( $ds, '__query_records' );

        #--- Interne Nummern auflösen, wenn Datensätze gefunden wurden
        #    if ($q_records_ref) {
        #          map { $_->decode_record } @{$q_records_ref};

        #-- wenn keine Datensätze gefunden wurden...
        #        } else {
        #          #mue noch schreiben
        #	}
        # alten Datensatz leeren
        $jsond->{'data'} = [];

        for my $record ( @{$q_records_ref} ) {
            my $data = {};
            for my $fieldname (@fieldlist) {
                my $tab_col = $self->GetValue( $fieldname, 'DSColumn' );
                my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
                next
                    if ( ( $fieldtype eq 'label' )
                    or ( $fieldtype eq 'button' )
                    or ( $fieldtype eq 'image' )
                    or ( $fieldtype eq 'link' )
                    or ( $fieldname eq '__nav_r' ) );
                next
                    if (
                    (       $self->GetValue( $fieldname, 'Visibility' )
                        and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                    )
                    );

                next if ( exists $self->{'_disable_targetfield'}->{$fieldname} );

                my $a = '';
                if ( $self->GetValue( $tab_col, 'Type' ) eq 'Related' ) {
                    my $o        = $self->GetValue( $tab_col, 'RelatedOrder' );
                    my $tab_col1 = $self->GetValue( $tab_col, 'RelatedColumn' );
                    if ( defined $record->column( $self->GetValue( $tab_col1, 'DBName' ) )->extdata ) {
                        $a = $record->column( $self->GetValue( $tab_col1, 'DBName' ) )->extdata->[$o];
                    }
                }
                else {
                    if ( $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata ) {
                        if ( $self->GetValue( $fieldname, 'InternalData' ) eq 'yes' ) {
                            $a = $record->column( $self->GetValue( $tab_col, 'DBName' ) )->intdata;
                        }
                        else {
                            if ( $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata->[1] ) {
                                $a =
                                    join( ':::',
                                    $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata );
                            }
                            else {
                                $a = $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata->[0];
                            }
                        }
                    }
                }

                $a='' if (!defined $a);

                $data->{$fieldname} = [ $a, '', '' ];

            }
            push( @{ $jsond->{'data'} }, $data );
        }
    }
    
    $jsond->{'info'} = "Ok.";
    if ( $jsond->{'data'}->[0] ) {
        return $json->encode($jsond);
    }
    else {
        return $self->InitJSONData();
    }
}

##############################################################################
# Print HTML for form if using AJAX
##############################################################################

sub PrintBody {
    my $self = shift;
    my %_done;
    my $cell;
    my $cell1;

    #--- make a loop over all blocks in xml-definition
    #--- and initialize variables
    my $tab0      = 100000;
    my $hs_config = {};
    $hs_config->{general} = {
        'date_order'  => $apiis->date_order,
        'date_sep'    => $apiis->date_sep,
        'date_format' => lc( $apiis->date_format ),
        'tab_0'       => undef,
        'tab_first'   => undef
    };

    # running OnOpenForm-Events:
    $self->RunEvent( { elementname => $self->formname, eventtype => 'OnOpenForm', } );

    BLOCK: foreach my $blockname ( $self->blocknames ) {

        my @navigationbar = ();
        my @statusbar     = ();
        my @ar_pos        = ();
        my $max_col       = 0;
        my $vtr           = '';
        my $vnavi         = '';
        my $vstatus       = '';
        my $vstyle;
        my $row           = '';
        my $column        = '';
        my $field_ref     = $self->GetValue( $blockname, '_field_list' );
        my $misc_list_ref = $self->GetValue( $blockname, '_misc_blockelement_list' );
        my $ds            = $self->GetValue( $blockname, 'DataSource' );
        my %hs_floworder;
        my @floworder;
        my %hs_order;

        FIELD:
        for my $fieldname ( @$field_ref, @$misc_list_ref ) {

            #-- skip if field = hidden
            next
                if (
                (       $self->GetValue( $fieldname, 'Visibility' )
                    and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                )
                );

            next if ( exists $self->{'_disable_targetfield'}->{$fieldname} );

            my $tab_col = $self->GetValue( $fieldname, 'DSColumn' );
            my $check;
            my @check;

            my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );

            #-- prepare FlowOrder for special fieldtypes
            #-- if FlowOrder not defined then floworder=''
            #--
            if ((   !$self->GetValue( $fieldname, 'Enabled' )
                    or (    ( $self->GetValue( $fieldname, 'Enabled' ) )
                        and ( $self->GetValue( $fieldname, 'Enabled' ) ne "no" ) )
                )
                and (  ( $fieldtype eq 'filefield' )
                    or ( $fieldtype eq 'textfield' )
                    or ( $fieldtype eq 'scrollinglist' )
                    or ( $fieldtype eq 'checkbox' ) )
                and ( $fieldname ne '__nav_r' )
                )
            {
                my $floworder = '999999';
                $floworder = $self->GetValue( $fieldname, 'FlowOrder' )
                    if ( $self->GetValue( $fieldname, 'FlowOrder' ) );
                if ( exists $hs_floworder{$floworder} ) {
                    push( @{ $hs_floworder{$floworder} }, $fieldname );
                }
                else {
                    $hs_floworder{$floworder} = [$fieldname];
                }
            }

            if ( $self->GetValue( $fieldname, 'FlowOrder' ) ) {
                $hs_config->{general}->{'tab_first'} = $fieldname if ( !$hs_config->{general}->{'tab_first'} );
                if ( $tab0 > $self->GetValue( $fieldname, 'FlowOrder' ) ) {
                    $hs_config->{general}->{'tab_0'} = $fieldname;
                    $tab0 = $self->GetValue( $fieldname, 'FlowOrder' );
                }
            }

            #next if (($fieldtype eq 'label') or ($fieldtype eq 'button') or ($fieldtype eq 'image') or
            #         ($fieldtype eq 'link'));

            #-- JSONConfig füllen
            $hs_config->{fields}->{$fieldname} =
                { 'type' => '', 'default' => '', 'defaultfunction' => '', 'check' => [] };
            if ($tab_col) {
                if ( $self->GetValue( $ds, 'Type' ) eq 'Record' ) {
                    my $col;
                    if ( $self->GetValue( $tab_col, 'Type' ) eq 'Related' ) {
                        $col = $self->GetValue( $self->GetValue( $tab_col, 'RelatedColumn' ), 'DBName' );
                    }
                    else {
                        $col = $self->GetValue( $tab_col, 'DBName' );
                    }

                    #-- error if field not exists
                    if (!$apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )) {
                        $self->status(1);
                        $self->errors(
                            Apiis::Errors->new(
                            type      => 'CODE',
                            severity  => 'CRIT',
                            from      => 'Apiis::Form::HTML::run',
                            msg_short => sprintf( "Table '%s' not defined in modelfile", $self->GetValue( $ds, 'TableName' ) ),
                            msg_long  => scalar $@,
                        )
                        );
                        return;
                    }
                    #-- error if field not exists
                    if ($apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col) eq '') {
                        $self->status(1);
                        $self->errors(
                            Apiis::Errors->new(
                            type      => 'CODE',
                            severity  => 'CRIT',
                            from      => 'Apiis::Form::HTML::run',
                            msg_short => sprintf( "Field '%s' not defined in modelfile", $col ),
                            msg_long  => scalar $@,
                        )
                        );
                        return;
                    }
                    my $type = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->datatype;
                    if ( lc($type) eq 'date' ) {
                        $check = 'isadate';
#                        $self->SetValue( $fieldname, 'InputType', 'date' );
                    }
                    elsif ( ( ( lc($type) eq 'float' ) or ( lc($type) eq 'real' ) or ( lc($type) eq 'bigint' ) )
                        and ( ( $col !~ /^db_/ ) and ( $col !~ /_id$/ ) and ( $col !~ /id_set$/ ) ) )
                    {
                        $check = 'isanumber';
                        $type  = 'number';
#                        $self->SetValue( $fieldname, 'InputType', 'number' );
                    }
                    if ( $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->check ) {
                        if ( ( $col ne 'guid' ) and ( $col !~ /^db_/ ) ) {
                            @check = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->check;
                        }
                    }
                    if ( $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->default ) {
                        my $v = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->default;
                        $v = $self->GetValue( $fieldname, 'Default' )
                            if ( defined $self->GetValue( $fieldname, 'Default' ) );
                        $hs_config->{fields}->{$fieldname}->{'default'} = $v;
                    }
                    else {
                        if ( defined $self->GetValue( $fieldname, 'Default' ) ) {
                            $hs_config->{fields}->{$fieldname}->{'default'} = $self->GetValue( $fieldname, 'Default' );
                        }
                    }
                    $hs_config->{fields}->{$fieldname}->{'type'} = $type;
                }
                push( @check, lc( $self->GetValue( $fieldname, 'Check' ) ) )
                    if ( $self->GetValue( $fieldname, 'Check' ) );
                push( @check, lc($check) ) if ($check);
                push( @{ $hs_config->{fields}->{$fieldname}->{'check'} }, @check );
            }
            else {
                push( @{ $hs_config->{fields}->{$fieldname}->{'check'} }, 'isadate' )
                    if (( $self->GetValue( $fieldname, 'InputType' ) )
                    and ( $self->GetValue( $fieldname, 'InputType' ) eq 'date' ) );
                $hs_config->{fields}->{$fieldname}->{'type'}    = $self->GetValue( $fieldname, 'InputType' );
                $hs_config->{fields}->{$fieldname}->{'default'} = $self->GetValue( $fieldname, 'Default' );
            }
            $hs_config->{fields}->{$fieldname}->{'defaultfunction'} = $self->GetValue( $fieldname, 'DefaultFunction' );

            my $html_fieldtype = $self->fieldtype( $fieldtype, $fieldname );
            my $module = 'Apiis::Form::HTML::' . $html_fieldtype;
            eval "require $module";
            if ($@) {
                $self->status(1);
                $self->errors(
                    Apiis::Errors->new(
                        type      => 'CODE',
                        severity  => 'CRIT',
                        from      => 'Apiis::Form::HTML::run',
                        msg_short => sprintf( "Error loading module '%s'", $fieldtype ),
                        msg_long  => scalar $@,
                    )
                );
            }
            push @ISA, $module;
            $_done{$module}++;
            unless ( $self->status ) {
                if (    defined $self->GetValue( $fieldname, 'Row' )
                    and defined $self->GetValue( $fieldname, 'Column' )
                    and ( $fieldname ne '__nav_r' )
                    and ( $fieldname ne '__statusbar' )
                    and ( !defined $self->GetValue( $fieldname, 'Navigationbar' )
                        or $self->GetValue( $fieldname, 'Navigationbar' ) eq 'no' )
                    )
                {
                    my ( $a, $a1, $b, $b1 );
                    $a = $self->GetValue( $fieldname, 'Row' );
                    if ( $self->GetValue( $fieldname, 'Rowspan' ) ) {
                        $a1 = $self->GetValue( $fieldname, 'Rowspan' );
                    }
                    $b = $self->GetValue( $fieldname, 'Column' );
                    if ( $self->GetValue( $fieldname, 'Columnspan' ) ) {
                        $b1 = $self->GetValue( $fieldname, 'Columnspan' );
                    }
                    if ( $ar_pos[$a][$b] ) {
                        push( @{ $ar_pos[$a][$b] }, $self->GetValue( $fieldname, 'Name' ) );
                    }
                    else {
                        $ar_pos[$a][$b] = [ $self->GetValue( $fieldname, 'Name' ) ];
                    }

                    #-- find max Column
                    $max_col = $b1 if ( ($b1) and ( $b1 > $max_col ) );
                    $max_col = $b  if ( ($b)  and ( $b > $max_col ) );
                }
                elsif ( $fieldname eq '__statusbar' ) {
                    push( @statusbar, $fieldname );
                }
                else {
                    push( @navigationbar, $fieldname );
                }
            }
            else {
                $apiis->errors( $self->errors );
            }

        }

        #-- makes a flat structure from hash into an array - change Floworder in an order
        #
        foreach my $key ( sort { $a <=> $b } keys %hs_floworder ) {
            map { push( @floworder, $_ ) } @{ $hs_floworder{$key} };
        }

        $hs_order{ $floworder[0] } = [ $floworder[$#floworder], $floworder[1] ];
        for ( my $i = 1; $i < $#floworder; $i++ ) {
            $hs_order{ $floworder[$i] } = [ $floworder[ $i - 1 ], $floworder[ $i + 1 ] ];
        }
        $hs_order{ $floworder[$#floworder] } = [ $floworder[ $#floworder - 1 ], $floworder[0] ];
        $hs_config->{general}->{floworder} = {%hs_order};

        #---
        #-- loop over all rows
        for ( my $i = 0; $i <= $#ar_pos; $i++ ) {
            my $td_filled;

            #-- loop over all columns
            for ( my $j = 0; $j <= $max_col; $j++ ) {
                my $cell1 = '';

                #-- loop over all cells
                for ( my $k = 0; $k <= $#{ $ar_pos[$i][$j] }; $k++ ) {
                    my $fieldname = $ar_pos[$i][$j]->[$k];
                    if ($fieldname) {

                        # the commands are named after the Fieldtype, e.g _textfield for
                        # type TextField:
                        my $command_function =
                            '_' . lc( $self->fieldtype( lc( $self->GetValue( $fieldname, 'Type' ) ), $fieldname ) );
                        my $properties2 = '';

                        if ((   $self->GetValue( $fieldname, 'Columnspan' )
                                and ( $self->GetValue( $fieldname, 'Columnspan' ) > 1 )
                            )
                            )
                        {
                            $properties2 .= ' colspan="' . $self->GetValue( $fieldname, 'Columnspan' ) . '"';
                        }
                        if ((   $self->GetValue( $fieldname, 'Rowspan' )
                                and ( $self->GetValue( $fieldname, 'Rowspan' ) > 1 )
                            )
                            )
                        {
                            $properties2 .= ' rowspan="' . $self->GetValue( $fieldname, 'Rowspan' ) . '"';
                        }

                        $vstyle .= $properties2;

                        $td_filled = 1;
                        $cell1 .= $self->$command_function( elementname => $fieldname );
                    }
                    else {
                        $cell1 .= '';
                    }
                    $column = $self->GetValue( $fieldname, 'Column' );
                    $row    = $self->GetValue( $fieldname, 'Row' );
                }
                if ( $cell1 ne '' ) {
                    $cell .= '<td ' . $vstyle . ' >' . $cell1 . '</td>';
                }
                else {
                    $cell .= '<td></td>';
                }
                $cell1  = '';
                $vstyle = '';
            }
            $vtr .= '<TR>' . $cell . '</TR>' if ($td_filled);
            $cell   = '';
            $cell1  = '';
            $column = '';
        }

        #-- create navigationbar
        foreach my $fieldname (@navigationbar) {
            my $command_function =
                '_' . lc( $self->fieldtype( lc( $self->GetValue( $fieldname, 'Type' ) ), $fieldname ) );
            $vnavi .= $self->$command_function( elementname => $fieldname );
        }
        #-- create statusbar
        foreach my $fieldname (@statusbar) {
            my $command_function =
                '_' . lc( $self->fieldtype( lc( $self->GetValue( $fieldname, 'Type' ) ), $fieldname ) );
            $vstatus .= $self->$command_function( elementname => $fieldname );
        }
        my $json = JSON::to_json( $hs_config) ;
#mue        my $json = JSON::XS->new->utf8->encode ( $hs_config );

        $self->{_table} .= '<script language="JavaScript">$config=' . $json . ';window.loadText</script>';
        $self->{_table} .= '<div id="' . $blockname . '"><table><tr><td>' . $vtr . '</td></tr></table></div>
	                    <div id="navigationbar">' . $vnavi . '</div>
			    <div id="statusbar">' . $vstatus . '</div>';
    }

    # running OnOpenForm-Events:
    $self->RunEvent( { elementname => $self->formname, eventtype => 'OnCloseForm', } );

    return $self->{_table};
}

##############################################################################
# run the configured form:
sub run {
    my $self = shift;

    #my $opt_js=shift;
    return if $self->status;
    my $query = $self->{_query};
    my %_done;
    my $js         = '';
    my $_akt_field = '';
    my @_order_elements;
    my $_last_rec = 0;
    my %hs_data   = ();
    my %hs_errors = ();
    my $cell;
    my $cell1;
    my $style1;
    my $vtr;
    my $module;
    my $max_col       = 0;
    my $status_msg    = '';
    my $cgi_parameter = $query->Vars();
    my $records       = 0;
    my $commandfield  = '';
    my $vguid;
    my $setparameter;
    my $mem_cache;
    $records      = $cgi_parameter->{__records}         if ( $cgi_parameter->{__records} );
    $commandfield = $cgi_parameter->{__commandfield}    if ( $cgi_parameter->{__commandfield} );
    my $command   = $cgi_parameter->{__command}         if ( $cgi_parameter->{__command} );
    $command      = ''                                  if ( !$command );
    my $formtype  = $cgi_parameter->{'formtype'}        if ( $cgi_parameter->{'formtype'} );
    my $form_name = $self->{_form_list}->[0];

    #-- switch command
    $command = 'do_query_block' if ( $command eq 'do_open_form' );
    $command = $self->GetValue( $commandfield, 'Command' ) if ( $commandfield ne '' );

    if ( $apiis->Cache->hasMemcached() and $apiis->Cache->hasMemcached() eq '1' ) {

        # collect memcached config data, also for storing at the end:
        $mem_cache = $apiis->Cache->memcache();
    }
    my $db_name = $apiis->Model->db_name;

    #my $form_name = $self->xmlfile;

    #--- block resolve with query-parameter
    #
    foreach my $blockname ( $self->blocknames ) {

        #--- ask for events
        if ( $self->GetValue( $blockname, '_event_list' ) ) {
            foreach my $event ( @{ $self->GetValue( $blockname, '_event_list' ) } ) {
                my $parameter_ref = $self->get_event_par_ref( { eventname => $event } );
                if ($parameter_ref) {
                    #mue if ( ( $self->GetValue( $event, 'Action' ) eq 'SetQuery' ) and ( $command eq 'do_query_block' ) ) {
                    if ( ( $self->GetValue( $event, 'Action' ) eq 'SetQuery' ) ) {
                        my $from_master_ref = $parameter_ref->{'master_sourcefield'};
                        my $to_client_ref   = $parameter_ref->{'client_targetfield'};
                        if ($from_master_ref) {
                            $setparameter = 1;
                            for my $idx ( 0 .. @$from_master_ref - 1 ) {
                                if ( exists $cgi_parameter->{ $from_master_ref->[$idx] } ) {
                                    my $target_data_ref = $self->GetValue( $to_client_ref->[$idx], '_data_ref' );
                                    $$target_data_ref = $cgi_parameter->{ $from_master_ref->[$idx] };
                                    $idx++;
                                }
                            }
                        }
                    }
                }
            }
        }

        #$hs_data{__rowid}=[split('\+\+\+',$cgi_parameter->{__rowid},100000000)] if ($cgi_parameter->{__rowid});
        my $ds = $self->GetValue( $blockname, 'DataSource' );
        my %ext_fields = ();
        %hs_errors = ();
        for ( my $i = 0; $i <= $records - 1; $i++ ) {

            my %data_hash = ();

            #--- Set Parameter (%data_hash)
            #--- if parameter from an other form
            if ( !$setparameter ) {
                for my $fieldname ( @{ $self->GetValue( $blockname, '_field_list' ) } ) {
                    if ( ( exists $cgi_parameter->{$fieldname} ) and ( !exists $hs_data{$fieldname} ) ) {
                        $hs_data{$fieldname} = [ split( '\+\+\+', $cgi_parameter->{$fieldname}, 100000000 ) ];
                        if ( $self->GetValue( $fieldname, 'DSColumn' ) ) {
                            if ( $self->GetValue( $self->GetValue( $fieldname, 'DSColumn' ), 'DBName' ) eq 'guid' ) {
                                $vguid = $fieldname;
                            }
                            $ext_fields{ $self->GetValue( $self->GetValue( $fieldname, 'DSColumn' ), 'DBName' ) } =
                                $fieldname;
                        }
                    }
                    my $a = $self->GetValue( $fieldname, '_data_ref' );
                    $$a = $hs_data{$fieldname}->[$i];
                    $data_hash{$fieldname} = $hs_data{$fieldname}->[$i];
                }
            }

            my $LO;
            if ( ( $commandfield ne '' ) and $self->GetValue( $commandfield, '_parameter_list' ) ) {
                foreach ( @{ $self->GetValue( $commandfield, '_parameter_list' ) } ) {
                    $LO = $self->GetValue( $_, 'Value' ) if ( uc( $self->GetValue( $_, 'Key' ) ) eq 'LO' );
                }
            }
            if ( $command eq 'do_query_block' ) {
                $self->query_block( { blockname => $blockname } );
                if ( $self->GetValue( $blockname, '_event_list' ) ) {
                    foreach my $event ( @{ $self->GetValue( $blockname, '_event_list' ) } ) {
                        my $parameter_ref = $self->get_event_par_ref( { eventname => $event } );
                        if ($parameter_ref) {
                            if (    ( $self->GetValue( $event, 'Action' ) eq 'SetQuery' )
                                and ( $command eq 'do_query_block' ) )
                            {
                                my $from_master_ref = $parameter_ref->{'master_sourcefield'};
                                my $to_client_ref   = $parameter_ref->{'client_targetfield'};
                                if ($from_master_ref) {
                                    $setparameter = 1;
                                    for my $idx ( 0 .. @$from_master_ref - 1 ) {
                                        if ( exists $cgi_parameter->{ $from_master_ref->[$idx] } ) {
                                            my $target_data_ref =
                                                $self->GetValue( $to_client_ref->[$idx], '_data_ref' );
                                            $$target_data_ref = $cgi_parameter->{ $from_master_ref->[$idx] };
                                            $idx++;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            }

            #old if (($self->GetValue($commandfield,'Command') eq 'do_save') and $vguid and
            if (    ( $command eq 'do_save' )
                and $vguid
                and ( $self->GetValue( $vguid, '_data_ref' ) )
                and ( ${ $self->GetValue( $vguid, '_data_ref' ) } ne '' ) )
            {
                $self->update_block( { blockname => $blockname } );
                if ( $self->status ) {
                    $status_msg = main::__("Update fehlgeschlagen");
                    for ( my $l = 0; $l <= $#{ $self->errors }; $l++ ) {
                        my $err = $self->errors->[$l];
                        next unless ( defined $err );
                        my @tmp = ();
                        if ( defined $err->ext_fields() ) {
                            foreach my $db_col ( @{ $err->ext_fields() } ) {
                                $hs_errors{$i}->{$db_col} = $err->syslog_print;
                            }
                        }
                        else {
                            $err->backtrace('');
                            my $t = quotemeta( $err->syslog_print );
                            $hs_errors{$i}->{'__record'} = $t;
                        }
                        $self->errors->[$l] = undef;
                        $self->status(0);

                        #noch machen für related fields
                    }
                }
                else {
                    $status_msg = main::__("Update Ok.");
                }
            }
            if (( $command eq 'do_save' )
                and (  !$vguid
                    or ( !$self->GetValue( $vguid, '_data_ref' ) )
                    or ( ${ $self->GetValue( $vguid, '_data_ref' ) } eq '' ) )
                )
            {
                if ($LO) {

                    no strict "refs";
                    my $load_string = "use $LO";
                    eval $load_string;
                    if ($@) {
                        $self->status(1);
                        $self->errors(
                            Apiis::Errors->new(
                                type      => 'CODE',
                                severity  => 'ERR',
                                from      => '_call_LO',
                                msg_short => 'Cannot find/load LoadObject $LO',
                                msg_long  => $@,
                            )
                        );
                        return;
                    }

                    my ( $err_status, $err_ref ) = &$LO( $self, \%data_hash );
                    if ($err_status) {
                        $status_msg = main::__("Aktion fehlgeschlagen");

                        for ( my $l = 0; $l <= $#{$err_ref}; $l++ ) {
                            my $err = $err_ref->[$l];
                            next unless ( defined $err );
                            my @tmp = ();
                            if ( defined $err->ext_fields() ) {
                                foreach my $db_col ( @{ $err->ext_fields() } ) {
                                    $hs_errors{$i}->{$db_col} = $err->syslog_print;
                                }
                            }
                            else {
                                $err->backtrace('');
                                my $t = quotemeta( $err->syslog_print );
                                $hs_errors{$i}->{'__record'} = $t;
                            }
                            $self->errors->[$l] = undef if ( $self->errors );
                            $self->status(0);

                            #noch machen für related fields
                            #foreach my $db_col (@{$err->ext_fields()}) {
                            #  push (@tmp,@{$ext_fields{$db_col}});
                            #}
                            #$err->ext_fields(\@tmp);
                            #$self->errors( $err );
                        }
                    }
                    else {
                        $status_msg = main::__("Aktion Ok.");
                    }
                }
                else {
                    $self->insert_block( { blockname => $blockname } );
                    if ( $self->status ) {
                        $status_msg = main::__("Aktion fehlgeschlagen");

                        for ( my $l = 0; $l <= $#{ $self->errors }; $l++ ) {
                            my $err = $self->errors->[$l];
                            next unless ( defined $err );
                            my @tmp = ();
                            if ( defined $err->ext_fields() ) {
                                foreach my $db_col ( @{ $err->ext_fields() } ) {
                                    $hs_errors{$i}->{$db_col} = $err->syslog_print;
                                }
                            }
                            else {
                                $err->backtrace('');
                                my $t = quotemeta( $err->syslog_print );
                                $hs_errors{$i}->{'__record'} = $t;
                            }
                            $self->errors->[$l] = undef;
                            $self->status(0);

                            #noch machen für related fields
                            #foreach my $db_col (@{$err->ext_fields()}) {
                            #  push (@tmp,@{$ext_fields{$db_col}});
                            #}
                            #$err->ext_fields(\@tmp);
                            #$self->errors( $err );
                        }
                    }
                    else {
                        $status_msg = main::__("Aktion Ok.");
                    }
                }
            }
        }

        #  $status_msg = main::__( "Data successfully inserted");
        # $self->form_status_msg( $status_msg );
    }

    #my @a;
    #$a[0]="<input type='hidden' id='__form' name='__form' value='".$query->param('__form')."'/>";

    #if ($opt_js) {
    #        print 'w.document.write("'.$a[0].'");';
    #        print 'w.document.write("'.$a[1].'");';
    #}

    $js = '<script language="JavaScript">' . "\n";

    #$js.='var xf=new Object();'."\n";
    #$js .= "xf._messages=['" . $status_msg . "'];\n";

    #-- reduce the same global-errors to one
    #my $i=0;
    #foreach ($self->errors) {
    #  if ($self->errors->[$i]->db_column) {
    #    $a=$self->errors->[$i]->syslog_print;
    #    $a=~s/(id=>)\d*?;/$1 1/g;
    #    $hs_errors{$a}=1;
    #  }
    #  $i++;
    #}

    my $mem_key_form = 'form::' . $db_name . ':::' . $form_name;
    my $mem_form;
    if ($mem_cache) {
        $mem_form = $mem_cache->get($mem_key_form);
    }

    #--- make a loop over all blocks in xml-definition
    #--- and initialize variables
    BLOCK: foreach my $blockname ( $self->blocknames ) {

        #$js .= 'xf.' . $blockname . '=new Object();' . "\n";
        my @errors_rec;
        my $errors_rec;

        my $row    = '';
        my $column = '';
        my $vtd    = '';
        my $vstyle = '';
        $vtr   = '';
        $cell  = '';
        $cell1 = '';
        my @ar_pos = ();
        my $field_ref = $self->GetValue( $blockname, '_field_list' );

        my $misc_list_ref = $self->GetValue( $blockname, '_misc_blockelement_list' );
        my $ds            = $self->GetValue( $blockname, 'DataSource' );

        my $q_records_ref = $self->GetValue( $ds, '__query_records' );
        @_order_elements = ();

        my %hs_tmp;
        my $n = 0;
        my @update;
        my $update;
        my @rowid;
        my $rowid;

        #-- has FlowOrder a wrong order then renumber
        #for my $fieldname ( @$field_ref ) {
        #  next if ($self->GetValue($fieldname,'Type')=~/(Button)/);
        #  next if ($self->GetValue($fieldname,'Name') eq '_nav_r');
        #  $hs_tmp{$fieldname}=[$self->GetValue($fieldname,'FlowOrder'),$fieldname];
        #}
        #foreach (sort {$a->[0] <=>$b->[0]} values %hs_tmp) {
        # push(@floworder$self->SetValue($_->[1],'FlowOrder',$n++);
        #}
        my $flowmax = $#{$field_ref} - 1;

        my %hs_fields;
        map { $hs_fields{$_} = 1 } @$field_ref;
        map { $_->decode_record } @{$q_records_ref};

        FIELD:
        for my $fieldname ( @$field_ref, @$misc_list_ref ) {

            #-- skip if field = hidden
            next
                if (
                (       $self->GetValue( $fieldname, 'Visibility' )
                    and $self->GetValue( $fieldname, 'Visibility' ) eq 'hidden'
                )
                );

            next if ( exists $self->{'_disable_targetfield'}->{$fieldname} );

            my $mem_key = 'js::' . $db_name . ':::' . $form_name . ':::' . $fieldname;
            my $mem_js;

            if (    ( exists $hs_fields{$fieldname} )
                and ( $self->GetValue( $fieldname, 'Type' ) !~ /(Button)/ )
                and ( $self->GetValue( $fieldname, 'Type' ) !~ /(Link)/ )
                and ( $self->GetValue( $fieldname, 'Type' ) !~ /(frame)/i )
                and ( $self->GetValue( $fieldname, 'Name' ) !~ /(_nav_r|nav_m)/ ) )
            {

                #--- make a loop over all elements within a block
                $js .= 'xf.' . $blockname . '.' . $fieldname . '=new Object();' . "\n";

                #--- save different properties of each element in js-object
                #--- only for elements which have connection to DataSource
                #

                #--- takeover data into js-object

                if ( ${ $self->GetValue( $fieldname, '_data_ref' ) }
                    and ( ${ $self->GetValue( $fieldname, '_data_ref' ) } eq '_lastrecord' ) )
                {
                    my $a = $self->GetValue( $fieldname, '_data_ref' );
                    $$a = '';
                }
                $_last_rec = 0;
                my @a;
                $_akt_field = "xf.$blockname.$fieldname" if ( !$_akt_field );
                $_order_elements[ $self->GetValue( $fieldname, "FlowOrder" ) ] = "xf.$blockname.$fieldname"
                    if ( $self->GetValue( $fieldname, "FlowOrder" ) );
                my $tab_col = $self->GetValue( $fieldname, 'DSColumn' );

                if (%hs_errors) {
                    my @errors;
                    for ( my $rec = 0; $rec <= $records - 1; $rec++ ) {
                        if ( $hs_errors{$rec} ) {
                            if ( $hs_errors{$rec}->{'__record'} ) {
                                $errors_rec[$rec] = "'" . $hs_errors{$rec}->{'__record'} . "'";
                            }
                            else {
                                $errors_rec[$rec] = "'" . $hs_errors{$rec}->{$fieldname} . "'";
                            }
                            push( @a,      $hs_data{$fieldname}->[$rec]   || '' );
                            push( @errors, $hs_errors{$rec}->{$fieldname} || '' );
                            push( @update, '' ) if ( !$update );
                        }
                        else {
                            $errors_rec[$rec] = "''";
                        }
                    }
                    $js .= 'xf.' . $blockname . '.' . $fieldname . "._error=['" . join( "','", @errors ) . "'];" . "\n";
                }
                elsif ( @{$q_records_ref} ) {
                    for my $record ( @{$q_records_ref} ) {
                        my $a = undef;
                        $_last_rec++;
                        if ( $self->GetValue( $tab_col, 'Type' ) eq 'Related' ) {
                            my $o        = $self->GetValue( $tab_col, 'RelatedOrder' );
                            my $tab_col1 = $self->GetValue( $tab_col, 'RelatedColumn' );
                            if ( defined $record->column( $self->GetValue( $tab_col1, 'DBName' ) )->extdata ) {
                                $a = $record->column( $self->GetValue( $tab_col1, 'DBName' ) )->extdata->[$o];
                            }
                        }
                        else {
                            if ( $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata ) {
                                if (ref( $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata ) eq
                                    'ARRAY' )
                                {
                                    $a =
                                        join( ':::',
                                        $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata );
                                }
                                else {
                                    $a = $record->column( $self->GetValue( $tab_col, 'DBName' ) )->extdata;
                                }
                            }
                        }
                        $a = '' if ( !defined $a );
                        push( @a,          $a );
                        push( @errors_rec, "''" ) if ( !$errors_rec );
                        push( @update,     '' ) if ( !$update );
                    }
                    $js .= 'xf.' . $blockname . '.' . $fieldname . "._error=[''];" . "\n";
                }
                else {
                    push( @a, ${ $self->GetValue( $fieldname, '_data_ref' ) } );
                    push( @errors_rec, "''" ) if ( !$errors_rec );
                    push( @update,     '' )   if ( !$update );
                    $js .= 'xf.' . $blockname . '.' . $fieldname . "._error=[''];" . "\n";
                }
                if ( !$update ) {
                    $js .= 'xf.' . $blockname . "._updated=['" . join( "','", @update ) . "'];" . "\n";
                    $update = 1;
                }
                map {
                    if ( !defined $_ ) { $_ = '' }
                } @a;
                $js .= 'xf.' . $blockname . '.' . $fieldname . '.' . "_data_ref=['" . join( "','", @a ) . "'];" . "\n";
                $js
                    .= 'xf.'
                    . $blockname . '.'
                    . $fieldname . '.'
                    . "_data_ref_bak=['"
                    . join( "','", @a ) . "'];" . "\n";

                $errors_rec = 1;
                if ($mem_cache) {
                    $mem_js = $mem_cache->get($mem_key);
                }
                if ( !$mem_js ) {
                    my $type;
                    my $check;
                    my @check;
                    my $default;
                    if ( $self->GetValue( $ds, 'Type' ) eq 'Record' ) {
                        my $col;
                        if ( $self->GetValue( $tab_col, 'Type' ) eq 'Related' ) {
                            $col = $self->GetValue( $self->GetValue( $tab_col, 'RelatedColumn' ), 'DBName' );
                        }
                        else {
                            $col = $self->GetValue( $tab_col, 'DBName' );
                        }

                        #-- check for undef
                        if (!$col) {
                            $self->status(1);
                            $self->errors(
                            Apiis::Errors->new(
                            type      => 'CODE',
                            severity  => 'CRIT',
                            from      => 'Apiis::Form::HTML::run',
                            msg_short => sprintf( " '%s' not defined in section DataSource", $tab_col ),
                            msg_long  => scalar $@,
                            )
                            );

                            return;
                        }
                        $type = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->datatype;
                        if ( $type =~ /date/i ) {
                            $check = 'IsADate';
#                            $self->SetValue( $fieldname, 'InputType', 'date' );
                        }
                        elsif ( $type =~ /(float|real)/i ) {
                            $check = 'IsANumber';
#                            $self->SetValue( $fieldname, 'InputType', 'number' );
                        }
                        if ( $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->check ) {
                            if ( ( $col ne 'guid' ) and ( $col !~ /^db_/ ) ) {
                                @check =
                                    $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->check;
                            }
                        }
                        if ( $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->default ) {
                            my $v = $apiis->Model->table( $self->GetValue( $ds, 'TableName' ) )->column($col)->default;
                            if ( !defined $self->GetValue( $fieldname, 'Default' ) ) {
                                $self->SetValue( $fieldname, 'Default', $v );
                            }
                        }
                    }
                    push( @check, $self->GetValue( $fieldname, 'Check' ) )
                        if ( $self->GetValue( $fieldname, 'Check' ) );
                    push( @check, $check ) if ($check);
                    @check = ('') if ( !@check );
                    $mem_js
                        .= 'xf.' . $blockname . '.' . $fieldname . "._check=['" . join( "','", @check ) . "'];" . "\n";
                    my $fieldname1 = 0;
					$flowmax=0 if (! $flowmax);

                    if ( $self->GetValue( $fieldname, "FlowOrder" ) and 
						($self->GetValue( $fieldname, "FlowOrder" ) ne '' ) ) {
					    $fieldname1 = $self->GetValue( $fieldname, 'FlowOrder' ) + 1;
                        $fieldname1 = 0 if ( ( $self->GetValue( $fieldname, 'FlowOrder' ) + 1 ) >= $flowmax );
                    }
                    $mem_js .= 'xf.' . $blockname . '.' . $fieldname . ".NextElement=[$fieldname1]" . "\n";

                    foreach my $property ( 'Name', 'InputType', 'DecimalPlaces', 'Default', 'Type', 'Format',
                        '_parentblock' )
                    {

                        if ( $self->GetValue( $fieldname, $property ) ) {
                            if ( $property eq 'Name' ) {
                                $mem_js
                                    .= 'xf.'
                                    . $blockname . '.'
                                    . $fieldname . '.Id' . "=['"
                                    . $self->GetValue( $fieldname, $property ) . "'];" . "\n";
                            }
                            else {
                                $mem_js
                                    .= 'xf.'
                                    . $blockname . '.'
                                    . $fieldname . '.'
                                    . $property . "=['"
                                    . $self->GetValue( $fieldname, $property ) . "'];" . "\n";
                            }
                        }
                        else {
                            if ( $property eq '_parentblock' ) {
                                $mem_js
                                    .= 'xf.'
                                    . $blockname . '.'
                                    . $fieldname . '.'
                                    . $property . "=[xf."
                                    . $blockname . "];" . "\n";
                            }
                            else {
                                $mem_js .= 'xf.' . $blockname . '.' . $fieldname . '.' . $property . '=[];' . "\n";
                            }
                        }
                    }
                    if ($mem_cache) {
                        $mem_cache->set( $mem_key, $mem_js, 3600 );
                    }
                }
                $js .= $mem_js;
            }

            if ( !$mem_form ) {
                my $fieldtype = lc $self->GetValue( $fieldname, 'Type' );
                my $html_fieldtype = $self->fieldtype( $fieldtype, $fieldname );
                my $module = 'Apiis::Form::HTML::' . $html_fieldtype;
                eval "require $module";
                if ($@) {
                    $self->status(1);
                    $self->errors(
                        Apiis::Errors->new(
                            type      => 'CODE',
                            severity  => 'CRIT',
                            from      => 'Apiis::Form::HTML::run',
                            msg_short => sprintf( "Error loading module '%s'", $fieldtype ),
                            msg_long  => scalar $@,
                        )
                    );
                }
                push @ISA, $module;
                $_done{$module}++;
                unless ( $self->status ) {
                    if (    defined $self->GetValue( $fieldname, 'Row' )
                        and defined $self->GetValue( $fieldname, 'Column' ) )
                    {
                        my ( $a, $a1, $b, $b1 );
                        if ( $self->GetValue( $fieldname, 'Rowspan' ) ) {
                            $a1 = $self->GetValue( $fieldname, 'Rowspan' );
                        }
                        if ( $self->GetValue( $fieldname, 'Row' ) =~ /\-/ ) {
                            ( $a, $a1 ) = ( $self->GetValue( $fieldname, 'Row' ) =~ /^(.+?)\-(.*)/ );
                        }
                        else {
                            $a = $self->GetValue( $fieldname, 'Row' );
                        }
                        if ( $self->GetValue( $fieldname, 'Columnspan' ) ) {
                            $b1 = $self->GetValue( $fieldname, 'Columnspan' );
                        }
                        if ( $self->GetValue( $fieldname, 'Column' ) =~ /\-/ ) {
                            ( $b, $b1 ) = ( $self->GetValue( $fieldname, 'Column' ) =~ /^(.+?)\-(.*)/ );
                        }
                        else {
                            $b = $self->GetValue( $fieldname, 'Column' );
                        }
                        if ( $ar_pos[$a][$b] ) {
                            push( @{ $ar_pos[$a][$b] }, $self->GetValue( $fieldname, 'Name' ) );
                        }
                        else {
                            $ar_pos[$a][$b] = [ $self->GetValue( $fieldname, 'Name' ) ];
                        }

                        #-- find max Column
                        $max_col = $b1 if ( ($b1) and ( $b1 > $max_col ) );
                        $max_col = $b  if ( ($b)  and ( $b > $max_col ) );
                    }
                }
            }
        }
        push( @errors_rec, "''" ) if ( !@errors_rec );
        #        $js .= 'xf.' . $blockname . '._messages= [' . join( ',', @errors_rec ) . '];' . "\n";

        if ( !$mem_form ) {

            #---
            #-- loop over all rows
            for ( my $i = 0; $i <= $#ar_pos; $i++ ) {
                my $td_filled;

                #-- loop over all columns
                for ( my $j = 0; $j <= $max_col; $j++ ) {
                    my $cell1 = '';

                    #-- loop over all cells
                    for ( my $k = 0; $k <= $#{ $ar_pos[$i][$j] }; $k++ ) {
                        my $fieldname = $ar_pos[$i][$j]->[$k];
                        if ($fieldname) {

                            # the commands are named after the Fieldtype, e.g _textfield for
                            # type TextField:
                            my $command_function =
                                '_' . lc( $self->fieldtype( lc( $self->GetValue( $fieldname, 'Type' ) ), $fieldname ) );
                            my $a;
                            my $properties2 = '';

                            if ((   $self->GetValue( $fieldname, 'Columnspan' )
                                    and ( $self->GetValue( $fieldname, 'Columnspan' ) > 1 )
                                )
                                )
                            {
                                $properties2 .= ' colspan="' . $self->GetValue( $fieldname, 'Columnspan' ) . '"';
                            }
                            if ( $self->GetValue( $fieldname, 'Column' ) =~ /^(.+?)\-(.*)/ ) {
                                $a           = $2 - $1 + 1;
                                $properties2 = ' colspan="' . $a . '"';
                                $j           = $a;
                                $k           = $j;
                            }
                            if ((   $self->GetValue( $fieldname, 'Rowspan' )
                                    and ( $self->GetValue( $fieldname, 'Rowspan' ) > 1 )
                                )
                                )
                            {
                                $properties2 .= ' rowspan="' . $self->GetValue( $fieldname, 'Rowspan' ) . '"';
                            }
                            if ( $self->GetValue( $fieldname, 'Row' ) =~ /^(.+?)\-(.*)/ ) {
                                $a = $2 - $1 + 1;
                                $properties2 .= ' rowspan="' . $a . '"';
                            }

                            my $vclass = '';
                            $vstyle = '';

                            #-- search the right class name, if objects has the same properties only one object name is a class
                            #-- the other one has a link to the right class

                            #if ($form_name.'_'.$fieldname eq 'FORM_1129548609_do_save') {
                            #print "kk";
                            #}
                            if ( !exists $self->{_style}->{ $form_name . '_' . $fieldname } ) {
                                $vclass = '';
                            }
                            elsif ( $self->{_style}->{ $form_name . '_' . $fieldname }->[1] ) {
                                $vclass = $self->{_style}->{ $form_name . '_' . $fieldname }->[1];
                            }
                            else {
                                $vclass = $form_name . '_' . $fieldname;
                            }

                            if ( $vclass eq '' ) {
                                $vstyle .= $properties2;
                            }
                            else {
                                $vstyle .= 'class="' . $vclass . '"' . $properties2;
                            }
                            $td_filled = 1;
                            $cell1 .= $self->$command_function( elementname => $fieldname );
                        }
                        else {
                            $cell1 .= '';
                        }
                        $column = $self->GetValue( $fieldname, 'Column' );
                        $row    = $self->GetValue( $fieldname, 'Row' );
                    }
                    if ( $cell1 ne '' ) {
                        $cell .= '<td ' . $vstyle . ' >' . $cell1 . '</td>';
                    }
                    else {
                        $cell .= '<td></td>';
                    }
                    $cell1 = '';
                }

                #$cell.='<td '.$style1.' >'.$cell1.'</td'  if ($vtd eq 0);
                #$cell.='<td '.$style.' >'.$cell1.'</td'  if ($vtd eq 0);
                $vtr .= '<TR>' . $cell . '</TR>' if ($td_filled);
                $cell   = '';
                $cell1  = '';
                $column = '';
            }

            $vstyle =
                ' STYLE="' . join( ';', $self->CreateCSSProperties( $self->GetValue( $blockname, 'Name' ) ) ) . '"';

            #            #--Navigation einbauen
            #            if ( $self->GetValue( $blockname, 'NavigationBar' )
            #                and ( $self->GetValue( $blockname, 'NavigationBar' ) eq 'full' ) )
            #            {
            #
            #                $vtr .= '<TR>
            #       <td colspan="' . $self->{_maxcolumn} . '" style="border-top:solid black 2px;padding:2px" >
            #         <img name="do_prev" src="/icons/do_prev.png" alt="vorheriger Datensatz"
            #	            onClick="MovePrev()"
            #	            onMouseOver="act(' . "'do_prev'" . ')" onMouseOut="inact(' . "'do_prev'" . ')">
            #         <input style="font-size:12px; vertical-align:top; text-align:right"
            #	        id="_nav_r" name="_nav_r" onChange="MoveRec()" type"textfield" maxlength="5" size="5"></a>
            #         <img name="do_next" src="/icons/do_next.png" alt="nächster Datensatz"
            #	            onClick="MoveNext()"
            #	            onMouseOver="act(' . "'do_next'" . ')" onMouseOut="inact(' . "'do_next'" . ')">
            #         <img name="do_last" src="/icons/do_last.png" alt="letzter Datensatz"
            #	            onClick="MoveLast()"
            #	            onMouseOver="act(' . "'do_last'" . ')" onMouseOut="inact(' . "'do_last'" . ')">
            #         <img name="do_new" src="/icons/do_new.png" alt="neuer Datensatz"
            #	            onClick="MoveNew()"
            #	            onMouseOver="act(' . "'do_new'" . ')" onMouseOut="inact(' . "'do_new'" . ')">
            #         <input style="font-size:12px; vertical-align:top; text-align:left; border-style:none; background:lightgray"
            #	        id="_nav_m"  name="_nav_m" readonly value="0" size="10" >
            #         <img name="do_clear" src="/icons/do_clear.png" alt="alles löschen"
            #	            onClick="Clear()"
            #	            onMouseOver="act(' . "'do_clear'" . ')" onMouseOut="inact(' . "'do_clear'" . ')">
            #         <img name="do_query" src="/icons/do_query.png" alt="Submit"
            #	            onClick="Query()"
            #	            onMouseOver="act(' . "'do_query'" . ')" onMouseOut="inact(' . "'do_query'" . ')">
            #         <img name="do_reset" src="/icons/do_reset.png" alt="Reset"
            #	            onClick="Reset()"
            #	            onMouseOver="act(' . "'do_reset'" . ')" onMouseOut="inact(' . "'do_reset'" . ')">
            #         <img name="do_delete" src="/icons/do_delete.png" alt="Delete"
            #	            onClick="Delete()"
            #	            onMouseOver="act(' . "'do_delete'" . ')" onMouseOut="inact(' . "'do_delete'" . ')">
            #         <img name="do_save" src="/icons/do_save.png" alt="Save"
            #	            onClick="Submit()"
            #	            onMouseOver="act(' . "'do_save'" . ')" onMouseOut="inact(' . "'do_save'" . ')">
            #        </td>
            #        </TR>';
            #            }

            $mem_form = '<table ' . $vstyle . '>' . $vtr . '</table>';
            if ($mem_cache) {
                $mem_cache->set( $mem_key_form, $mem_form, 3600 );
            }
        }
        $self->{_table} .= $mem_form;

        #$mem_form="<h1 style='color:red'>kk</h1>";
        #print $query->header ;
        #$self->{_table}='<script language="JavaScript">
        #     l=document.open("","","width=400");l.document.write("'.$mem_form.'");l.document.close();
        #     </script>';

        return $self->{_table};

    }
}
##############################################################################
1;
__END__

