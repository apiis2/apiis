###################################################################################
# $Id: Json2Html.pm,v 1.13 2009-08-14 07:56:25 ulm Exp $
###################################################################################
use Apiis::GUI;

###################################################################################
package Apiis::GUI::Json2Html;
use Apiis;
use Apiis::Init;
@Apiis::GUI::Json2Html::ISA=qw (Apiis::GUI);

sub GetStyle {
    my $self = shift;
    my $style= shift;

    my $ret='';

    if ($style and exists $style->{'style'}) {
    
        my @ar_style;

        #-- put key-value-pair as string into array
        map {
            push(@ar_style,(keys %{$_})[0].':'.(values %{$_})[0]);

        } @{ $style->{'style'} };
    
        $ret=join(';',@ar_style);
    }

    #-- return a valid style-string
    return $ret;
}

sub GetAttributes {
    my $self = shift;
    my $attr= shift;

    #-- return a valid style-string 
    my $vattr='';
    
    foreach my $va (@{ $attr }) {

        if ((keys %{$va})[0] eq 'style') {
            $vattr.=' '.(keys %{$va})[0].'="'.$self->GetStyle($va).'"';
        }
        else {
            $vattr.=' '.(keys %{$va})[0].'="'.(values %{$va})[0].'"';
        }
    }
    
    return $vattr;
}

sub CreateTag {
   my  $self = shift;
   my  $data = shift;

    my $attr='';
    my $vtag='';

    #-- loop over all records in data 
    foreach my $tag (@{ $data->{'data'}  }) {

        if (exists $tag->{'data'}) {
            
            $vtag.='<'.$tag->{'tag'}.' '.$self->GetAttributes($tag->{'attr'}).'>'.$self->CreateTag( $tag ).'</'.$tag->{'tag'}.'>';
        }    
        else {

            #-- if attributes for tag 
            $vtag.='<'.$tag->{'tag'}.' '.$self->GetAttributes($tag->{'attr'}).'>'.$tag->{'value'}.'</'.$tag->{'tag'}.'>';
        }    
    }

    return $vtag;
}

sub PrintGUI {
    my $self = shift;
    my $data = shift;


    return;
}

sub PrintHeader {
    my $self = shift;
    my $query=$self->Query;
    
    my $ph=''; my $enc; my $css='';my $title;

#    $enc=$self->GUIobj->general->charset;
#    $css=$self->GUIobj->general->stylesheet;
#    $title=$self->GUIobj->general->name;
    $enc='utf8';    
    print $query->header(-charset=>"$enc");

    print $query->start_html();
    
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

    return if ($apiis->status);

    $data=JSON::from_json($data);

    my $v='<'.$data->{'tag'}.'>'.$self->CreateTag($data).'</'.$data->{'tag'}.'>';

    print $v;
}  

sub GetAllSubGUIs {
    my $self = shift;
}
1;


