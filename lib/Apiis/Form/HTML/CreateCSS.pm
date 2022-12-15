package Apiis::Form::JS::CreateCSS;

use strict;
use warnings;
use Data::Dumper;
use Apiis;

=head2

CreateCSS($blockname) - internal

=cut



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
    'ListStylePosition',  'list-style-position', 'ListStyle',            'list-style',
    'ButtonImage',        'background-image',    
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
	    if ($key eq 'ButtonImage')  {
	      push( @properties, 'background-image:url('.$t.')' );
	    } else {
              push( @properties, $css{$key} . ":$t" );
	    }  
        }
    }
    return @properties;
}


sub MakeStyle {
    my $self = shift;
    $self->{'_style'} = shift;

    my $hs_style = {};
    my @ar_style;
    my @a=('',':hover',':active');
    my $form_name = $self->{_form_list}->[0];
    foreach my $blockname ( $self->blocknames ) {
        foreach my $name_list ( '_misc_blockelement_list', '_field_list' ) {
            my $names_ref = $self->GetValue( $blockname, $name_list );
	    my $p;
            foreach my $fieldname (@$names_ref) {

                my @properties = ();
                my $vtype = $self->GetValue( $fieldname, 'Type' );
                next if ( $vtype eq '' );

	        next if (exists $self->{'_disable_targetfield'}->{$fieldname});
            
	        # Pseudoclasses in css like hover|active
                if ($self->GetValue( $fieldname, 'ButtonImageOver' )) {
		  my $save=$self->GetValue( $fieldname, 'ButtonImage' );
		  for (my $k=0;$k<=2;$k++) {
                    my @properties = ();
                    if ($k==1) {
 		       $self->SetValue( $fieldname, 'ButtonImage',$self->GetValue( $fieldname, 'ButtonImageOver' ));
		    } elsif ($k==2) {
		       if ($self->GetValue( $fieldname, 'ButtonImageActive') ) {
  		         $self->SetValue( $fieldname, 'ButtonImage',$self->GetValue( $fieldname, 'ButtonImageActive' ));
		       } else {	 
		          $self->SetValue( $fieldname, 'ButtonImage',$save) ;
		       }
		    } 
		    push( @properties, $self->Apiis::Form::JS::CreateCSS::CreateCSSProperties( $self->GetValue( $fieldname, 'Name' ) ) );
                    if ( $#properties > -1 ) {
                       push( @ar_style, [ join( ';', @properties ), undef, $vtype, $fieldname.$a[$k],[] ] );
                    }
                  }
		  $self->SetValue( $fieldname, 'ButtonImage',$save);
                } else {
		  push( @properties, $self->Apiis::Form::JS::CreateCSS::CreateCSSProperties( $self->GetValue( $fieldname, 'Name' ) ) );

                  if ( $#properties > -1 ) {
                      push( @ar_style, [ join( ';', @properties ), undef, $vtype, $fieldname,[] ] );
                  }
		}
            }
        }
    }

    #-- Test auf doppelte Styles mit sich selbst
    for ( my $i = 0 ; $i <= $#ar_style ; $i++ ) {
        next if $ar_style[$i]->[1];
        for ( my $j = $i + 1 ; $j <= $#ar_style ; $j++ ) {
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
    for ( my $i = 0 ; $i <= $#ar_keys ; $i++ ) {
        for ( my $j = 0 ; $j <= $#ar_style ; $j++ ) {
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
    for ( my $j = 0 ; $j <= $#ar_style ; $j++ ) {
        $self->{_style}->{ $ar_style[$j]->[3] } = $ar_style[$j];
    }

    my $style;
    foreach my $key ( keys %{ $self->{'_style'} } ) {
        if ( $self->{'_style'}->{$key}->[1] ) {
	   push(@{$self->{'_style'}->{$self->{'_style'}->{$key}->[1]}[4]},$self->{'_style'}->{$key}->[3]);
	}
    }

    foreach my $key ( keys %{ $self->{'_style'} } ) {
        next if ( $self->{'_style'}->{$key}->[1]);
	push(@{$self->{'_style'}->{$key}->[4]},$key);
        $style .= '#'.join(', #',@{$self->{'_style'}->{$key}->[4]}).'{'.$self->{'_style'}->{$key}->[0].'}';
    }

    return ($self->{'_style'},$style);
}

1;

