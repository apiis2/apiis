############################################################################
# $Id: HTML.pm,v 1.30 2022/02/25 22:11:42 ulf Exp $
###################################################################################
use Apiis::GUI;

###################################################################################
package Apiis::GUI::HTML;
use Apiis;
use Apiis::Init;
#use Apiis::Init::DataSource;
@Apiis::GUI::HTML::ISA=qw (Apiis::GUI);

my %css=(  'Width','width','FontFamily','font-family','FontSize','font-size','FontStyle','font-style','FontWeight',
           'font-weight','FontVariant','font-variant','Font','font','BackgroundColor','background-color',
	   'BackGround','background-color','ForeGround','color','Color','color','BackgroundImage','background-image',
	   'BackgroundRepeat','background-repeat','BackgroundAttachment','background-attachment','BackgroundPosition',
	   'background-position','Background','background','WordSpacing','word-spacing','LetterSpacing','letter-spacing',
	   'TextDecoration','text-decoration','VerticalAlign','vertical-align','TextTransform','text-transform',
	   'TextAlign','text-align','TextIndent','text-indent','LineHeight','text-height','MarginTop','margin-top',
	   'MarginRight','margin-right','MarginBottom','margin-bottom','MarginLeft','margin-left','Margin','margin',
	   'PaddingTop','padding-top','PaddingRight','padding-right','PaddingBottom','padding-bottom','PaddingLeft',
	   'padding-left','Padding','padding','BorderTopWidth','border-top-width','BorderRightWidth','border-right-width',
	   'BorderBottomWidth','border-bottom-width','BorderLeftWidth','border-left-width','BorderWidth','border-width',
	   'BorderStyle','border-style','BorderColor','border-color','BorderTop','border-top','BorderRight','border-right',
	   'BorderBottom','border-bottom','BorderLeft','border-left','Border','border','BlockWidth','width','BlockHeight',
	   'height','BlockFloat','float','Clear','clear','Display','display','WhiteSpace','white-space','ListStyleType',
	   'list-style-type','ListStyleImage','list-style-image','ListStylePosition','list-style-position','ListStyle',
	   'list-style');
	   
=head2 CreateCSSProperties

This function has an object name as argument. It fetchs the object about getobject($name) and make a loop over the css-children-objects. After test whether the children-objects (color, format, position, miscellaneous, text) are valid each methodes of the objects were ask if it has an entry. About hash %css the correct css-name will fetched. After loop all properties were collect and return as STYLE-element

=cut

sub CreateCSSProperties {
  my $self = shift;
  my $obj_name=shift;
  my $obj=$self->GUIobj->getobject($obj_name);
  @properties=();
  foreach $typ ('color', 'format', 'position', 'miscellaneous', 'text') {
    next if (! $obj->can($typ));
    next if (! $obj->$typ);
    foreach my $key (keys %{$obj->$typ}) {
      if (exists $css{$key}) {
        my $key1=lc($key);
        my $t=$obj->$typ->$key1;
	next if (($t eq '') or ($t eq 'none'));
        push(@properties,$css{$key}.": $t");
      }	
    }
  }
  return @properties;
}

sub MakeStyle {
  my $self = shift;
  my $guio = shift;
  my $style='';
  my @d;
  if ($self->GUI eq 'Form' ) { 
    @d=@{$guio->allstyleobjects};
  } else {
    @d=@{$guio->AllStyleObjects};
  }
  foreach my $key (@d) {
    my @properties=();
   
    my %hs_styleobjects;
    if ($self->GUI eq 'Form' ) { 
       push(@properties,$self->CreateCSSProperties($self->GUIobj->getobject($key)->name));
    } else {
      %hs_styleobjects=%{$guio->$key};
      foreach $item (keys %hs_styleobjects) {
        my $t=$hs_styleobjects{$item};
        next if ((ref ($t) eq 'ARRAY') or (ref ($t) eq 'HASH'));
        next if (($t eq '') or ($t eq 'none'));
        push(@properties,$css{$item}.": $t");
      }
    }
    if ($#properties > -1) {
      $guio->{'_Style'}->{$key}=join(';',@properties);
    }  
  }
  
  #-- reduce classes with identical properties to one class
  my @ar_keys=sort keys %{$guio->{'_Style'}};
  for (my $i=0; $i<=$#ar_keys;$i++) {
    for (my $j=$i+1; $j<=$#ar_keys;$j++) {
      if ($guio->{'_Style'}->{$ar_keys[$i]} eq $guio->{'_Style'}->{$ar_keys[$j]}) {
        $guio->{'_Style'}->{$ar_keys[$j]}=$ar_keys[$i] if ($guio->{'_Style'}->{$ar_keys[$i]}=~/:/);
      }
    }
  }   

  #-- write style for each class
  foreach $key (keys %{$guio->{'_Style'}}) {
    next if (exists $guio->{'_Style'}->{$guio->{'_Style'}->{$key}});
    my $t='td';
    if ($self->GUI eq 'Form') {
      $t='table' if ($self->GUIobj->getobject($key)->objecttype eq 'Block');
    }
    if ($t eq 'table') {
      $style.='table.'.$key.'{'.$guio->{'_Style'}->{$key}.'}';
    } else {
      $style.='td.'.$key.'{'.$guio->{'_Style'}->{$key}.'}';
    }  
  }

  return $style;
}

sub PrintHeader {
  my $self = shift;
  my $query=$self->Query;
  my $ph='';
  my $enc; my $css='';my $title;
  
  no strict 'refs';
  
  if ($self->GUI ne 'Form' ) { 
    $enc=$self->GUIobj->{$self->GUIobj->General->[0]}->CharSet;
    $ph=$self->GUIobj->{$self->GUIobj->General->[0]}->PrintHeader;
    $css=$self->GUIobj->{$self->GUIobj->General->[0]}->StyleSheet;
    $title=$self->GUIobj->{$self->GUIobj->General->[0]}->Name;
  } else {
    $enc=$self->GUIobj->general->charset;
    $css=$self->GUIobj->general->stylesheet;
    $title=$self->GUIobj->general->name;
  }  
  
  print $query->header(-charset=>"$enc");
  
  my $t=$self->MakeStyle($self->GUIobj);
  
  print $query->start_html(-encoding=>$enc,-style=>{src=>$css,-code=>$t}, -class=>"menu", -title=>$title);
  
  return if (lc($ph) eq "no");
  
  my $opt_p=$query->param('sid');
  my $opt_u=$query->param('user');
  my $opt_m=$query->param('m');
  my $opt_o=$query->param('o');
  my $logo=$apiis->{'_logo'};
  my $t=$apiis->APIIS_HOME;
  
  if ($self->GUI eq 'Form' ) {
    print $query->start_form(-action=>"/cgi-bin/GUI", -method=>"POST");
    print $query->hidden(-name=>'m',-default=>"$opt_m");
    print $query->hidden(-name=>'user',-default=>"$opt_u");
    print $query->hidden(-name=>'sid',-default=>$opt_p);
    print $query->hidden(-name=>'o',-default=>$opt_o);
  }  
  
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
                $query->td()
    );

    print $query->table($vtable);

    return;
}

sub PrintBlock {
  my $self = shift;
  my $obj = shift;
  my $parent=shift;
  my @position=();
  my @position_sort;

  #-- aktuellen Block setzen
  $self->GUIobj->unshiftcurrentblock($obj->name);
  
  #-- Sortieren noch einfügen
  foreach my $ch (@{$obj->children}) {
    my $o=$self->GUIobj->getobject($ch);
    next if ($o->objecttype ne 'Field' and $o->objecttype ne 'Block' and $o->objecttype ne 'Label' and $o->objecttype ne 'Image' and $o->objecttype ne 'Line');
    $position[$o->position->row][$o->position->column]=$o->name;
  }
  foreach my $row (@position) {
    next if (! $row);
    foreach my $col (@{$row}) {
      next if (! $col);
      push(@position_sort,$col);
    }  
  }
  #-- Daten holen
  my $daten=[1];
  
  #-- Schleife über alle Daten
  foreach my $ds (@{$daten}) {
    #-- loop over all fields and all blocks
    foreach my $fld (@position_sort) {
      my $o=$self->GUIobj->getobject($fld);
      next if ($o->objecttype eq 'Hidden');

      #-- if object a new row, then init new else collect
      #no strict 'refs';
      if ($row and ($o->position->row ne $row)) {
        $self->PrintRowForm(\@cell);
        @cell=();
      }
      $row=$o->position->row;
      $column=$o->position->column;
      if ($row) { 
        $cell[$column-1]=$self->PrintCellForm($o);
      } else {
        if ($o->objecttype eq 'Block') {
          $self->PrintBlock($o->children,$o->name);
	  $cell[$column-1]=$o->table;
        }
	
      }
    }
  
    $self->PrintRowForm(\@cell);
  }
  $self->PrintTableForm($obj);
  
  #-- aktuellen Block entfernen
  $self->GUIobj->shiftcurrentblock();
}

sub PrintCellForm {
  my $self = shift;
  my $object = shift;
  my $cell=''; my @properties=(); my $cell1='';
  my $query=$self->Query;
  no strict 'refs';
  my $controled;
  my $replace;
  
  my $n=$object->name;
 
  $column=$object->position->column;
  if ($column=~/.+\-.+/) {
    my ($min, $max)=($column=~/(.+)\-(.+)/);
    for (my $i=$min; $i<=$max; $i++) {
      $self->GUIobj->setcolumnbusy($i);
    };
  } else {
    $self->GUIobj->setcolumnbusy($column) if ($column=~/^\d+/);
  }

  if ($object->objecttype eq 'Field') {
    my $type=lc($object->type);
    if ($type eq 'link') {
      my $v=$object->$type->label;
      $opt_o=$query->param('o');
      $opt_m=$query->param('m');
      $opt_p=$query->param('sid');
      $opt_u=$query->param('user');
      my $opt_g=$object->$type->src;
      my $t=$apiis->APIIS_LOCAL;
      $opt_g=~s/\$APIIS_HOME/$t/g;
      my $u="/cgi-bin/GUI?sid=$opt_p&g=$opt_g";
      $cell=$query->a({-href=>$u},$v);
    }  
    if ($type eq 'popupmenue') {
      my $sql=$object->datasource->sql->statement;
      my $sth = $apiis->DataBase->sys_sql( $sql );
      $sth->check_status; # debug
      $self->errors( $sth->errors ) if $sth->status;
      my $data_ref = $sth->handle->fetchall_arrayref;
      my @d=();
      push @d, $_->[$order_index] for @$data_ref;
      
      #my %l=split(';',$self->GUIobj->$object->labels);
      my $e=$object->$type->default;
      $cell=$query->popup_menu(-values=>\@d, -default=>$e, -labels=>\%l, -name=>$n);
    }  
    if ($type eq 'button') {
      $query->delete('g');
      print $query->hidden(-name=>'g',-default=>$object->$type->src);
      my $v=$object->$type->buttonlabel;
      if ($object->$type->command eq 'Submit') {
        $cell=$query->submit($n,$v);
      }
    }  
    if ($type eq 'textfield') {
      my $m=$object->$type->maxlength;
      my $p=$object->$type->password;
      my $d=$object->$type->default;
      my $o=$object->$type->override;
      if (lc($o) eq 'no') {$o=0} else {$o=1};
      if ($p eq "yes") {
        $cell=$query->password_field(-name=>$n,-size=>$t, -maxlength=>$m);
      } else {
        $cell=$query->textfield(-name=>$n,-size=>$t, -default=>$d, -override=>$o);
      }
    }  
  }
  
  if ($object->objecttype eq 'Image') {
    my $s=$object->src;
    my $a=$object->alt;
    $cell=$query->img({-src=>$s, -alt=>$a});
  }
  
  if ($object->objecttype eq 'Label') {
    $cell=$object->content;
  }
  
  #if ($object->type eq 'TextField') {
  #  my $m=$object->textfield->maxlength;
  #  my $p=$object->textfield->password;
  #  my $d=$object->textfield->default;
  #  my $o=$object->textfield->override;
  #  my $s=$object->textfield->size;
  #  if (lc($o) eq 'no') {$o=0} else {$o=1};
  #  if ($p eq "yes") {
  #    $cell=$query->password_field(-name=>$n,-size=>$s, -maxlength=>$m);
  #  } else {
  #    $cell=$query->textfield(-name=>$n,-size=>$s, -default=>$d, -override=>$o, -maxlength=>$m);
  #  }  
  #}
 
  my $column=$object->position->column;
  my $a; my $properties2='';
  if ($column=~/^(.+)\-(.+)/) {
    $a=$2 - $1 + 1;
    $properties2=' colspan="'.$a.'"';
  } 
  if ($object->position->row=~/^(.+)\-(.+)/) {
    $a=$2 - $1 + 1;
    $properties2.=' rowspan="'.$a.'"';
  } 

  my $properties=' STYLE="'.join(';',@properties).'"' if ($#properties > -1);

  #-- search the right class name, if objects has the same properties only one object name is a class
  #-- the other one has a link to the right class
  my $vclass='';
  if (! exists $self->GUIobj->{_Style}->{$object->name}) {
    $vclass='';
  } elsif ($self->GUIobj->{_Style}->{$object->name}=~/:/) {
    $vclass=$object->name;
  } else {
    $vclass=$self->GUIobj->{_Style}->{$object->name};
  }
  if ($vclass eq '') {
    return '<td'.$properties . $properties2.'>'.$cell.'</td>';
  } else {
    return '<td class="'.$vclass.'"'.$properties . $properties2.'>'.$cell.'</td>';
  }  
}

sub PrintRowForm {
  my $self = shift;
  my $vcell = shift;
  my @cell=@{$vcell};
  my $cell=''; my $properites='';
  my $query=$self->Query;

  #--
  for (my $i=0; $i<$self->GUIobj->maxcolumn ;$i++) {
    if (! $self->GUIobj->setcolumnbusy->[$i]) {
      $cell.=$query->td({},"");
    } else {
      $cell.=$cell[$i];
    }
  }
  $self->GUIobj->getobject($self->GUIobj->currentblock)->table($query->TR({$properties},$cell));
  $self->GUIobj->setcolumnbusy(-1);
}

=head2 PrintTableForm

This function prints the table-tag. The Style-class will be detecting and combine with the html-code. The html-code for each block is saved in $block->{_table} and can read with the method $block->table or set with $block->table($newvalue, $mode). $newvalue is the new html-code. Is $mode "undef" $newvalue will append, is $mode 'o', the internal value _table will overwrite with $newvalue. 

=cut

sub PrintTableForm {
  my $self = shift;
  my $o=shift;
  my $query=$self->Query;

  #-- search the right class name, if objects has the same properties only one object name is a class
  #-- the other one has a link to the right class
  my $vclass='';
  if (! exists $self->GUIobj->{_Style}->{$o->name}) {
    $vclass='';
  } elsif ($self->GUIobj->{_Style}->{$o->name}=~/:/) {
    $vclass=$o->name;
  } else {
    $vclass=$self->GUIobj->{_Style}->{$o->name};
  }
  
  my $x=$self->GUIobj->getobject($self->GUIobj->currentblock)->table;
  $self->GUIobj->getobject($self->GUIobj->currentblock)->table($query->table({class=>"$vclass"},$x),'o');
}




######################################################################################################

sub PrintObjects {
  my $self = shift;
  my $objects = shift;
  my $parent=shift;
  my $cell; my $row; my @cell; my $column;

  return if ($#{$objects} eq -1);
  if ($self->GUI eq "Report") {
    if (! $parent) {
      $parent=$self->GUIobj->{$objects->[0]}->CallFrom;
      $parent=$self->GUIobj->$parent->[0];
    }  

    if ($#{$self->GUIobj->$parent->OrderByRow} eq -1) {
      my @s=();
      foreach (@{$self->GUIobj->$parent->Children}) {
        push(@s,[$self->GUIobj->$_->Row, $_]);
      }
      map {push(@{$self->GUIobj->$parent->OrderByRow},$_->[1])} sort {$a->[0] <=> $b->[0]} @s;
    }
  
    foreach my $o (@{$self->GUIobj->$parent->OrderByRow}) {
      next if ($self->GUIobj->$o->ElementType eq 'Hidden');
      #-- if object a new row, then init new else collect
      no strict 'refs';
      if ($row and ($self->GUIobj->$o->Row ne $row)) {
        $self->PrintRow(\@cell);
        @cell=();
      }
      $row=$self->GUIobj->$o->Row;
      $column=$self->GUIobj->$o->Column;

      if ($row) { 
        $cell[$column-1]=$self->PrintCell($o);
      } else {
        if ($self->GUIobj->$o->ElementType eq 'Block') {
          $self->PrintObjects($self->GUIobj->$o->Children,$self->GUIobj->$o->Name);
        }
      }
    }
  } else { 
    my $obj=$self->GUIobj->getobject($objects->[0]);
    my $pa_obj;
    if (! $parent) {
      $pa_obj=$self->GUIobj->getobject($obj->parent);
    }  

    if ($#{$pa_obj->orderbyrow} eq -1) {
      my @s=();
      foreach (@{$pa_obj->children}) {
        push(@s,[$self->GUIobj->getobject($_)->row, $_]);
      }
      map {push(@{$pa_obj->orderbyrow},$_->[1])} sort {$a->[0] <=> $b->[0]} @s;
    }
  
    foreach my $o (@{$pa_obj->orderbyrow}) {
      next if ($self->GUIobj->getobject($o)->type eq 'Hidden');
      #-- if object a new row, then init new else collect
      no strict 'refs';
      if ($row and ($self->GUIobj->getobject($o)->row ne $row)) {
        $self->PrintRow(\@cell);
        @cell=();
      }
      $row=$self->GUIobj->getobject($o)->row;
      $column=$self->GUIobj->getobject($o)->column;

      if ($row) { 
        $cell[$column-1]=$self->PrintCell($o);
      } else {
        if ($self->GUIobj->getobject($o)->objecttype eq 'Block') {
          $self->PrintObjects($self->GUIobj->getobject($o)->children,$self->GUIobj->getobject($o)->name);
        }
      }
    }
  }
  
  $self->PrintRow(\@cell);
}

sub PrintCell {
  my $self = shift;
  my $object = shift;
  my $cell=''; my @properties=(); my $cell1='';
  my $query=$self->Query;
  no strict 'refs';
  my $controled;
  my $replace;

  #-- Datenbehandlung
  my $et=$self->GUIobj->$object->ElementType;
  my $column=$self->GUIobj->$object->Column;
  
  no strict 'refs';
  #-- Belegte Zellen finden und kennzeichnen
  if ($column=~/.+\-.+/) {
    my ($min, $max)=($column=~/(.+)\-(.+)/);
    for (my $i=$min; $i<=$max; $i++) {
      $self->GUIobj->SetColumnBusy($i);
    };
  } else {
    $self->GUIobj->SetColumnBusy($column) if ($column=~/^\d+/);
  }
  
  #-- Spaltenbelegung ermitteln
  #if ($column=~/(.+)\-/) {$column=$1};

  if ($self->GUI eq 'Form') {
    if ($et eq 'Page') {
      $cell=$self->MakeGUI($self->GUIobj->$object->Children);
    }
  }  
  if ($et eq 'SubGUI') {
    my $vsr=$self->GUIobj->$object->GUISource;
    my $sr=$self->{$apiis->APIIS_LOCAL.$vsr};
    my $name=${$sr->GUIobj->General}[0];
    #--- Parameter auflösen
    my @a; my @b; my @c; 
    my ($d)=($sr->GUIobj->$name->DataSource=~/\((.*)\)/);
    @a=split(',',$d);
    foreach my $a (@a) {
      @b=($a=~/\[(.*?)\]/g);
      next if ($#b==-1);
      if ($b[1] and (! exists $self->{$b[0]}) and ($self->GUIobj->fullname ne $b[0])) {
        $self->Apiis->errors(
            Apiis::Errors->new(
               type      => 'CODE',
               severity  => 'ERR',
               from      => 'Apiis::GUI::HTML',
               msg_short => __("GUI [_1] isn't aktiv", $b[0] )
	    ));
	$self->Apiis->status(1);
	return;
      }
      $name=$b[1];
      if ( $self->GUIobj->$name->can('Content')) {
        $sr->{'_Parameter'}->{$a}=[$a,$b[0],$b[0],$self->GUIobj->$name->Content];
      }	
    }
    $cell=$sr->MakeGUI;
    $sr->{_tablecontent}='';

   # $cell=$self->{$self->GUIobj->$object->GUISource};
  } elsif (($et eq 'Text') or ($et eq 'Data') or ($et eq 'Label') or ($et eq 'Field') ) {
    if ($self->GUI eq 'Form') {
      my $n=$object;
      if ($self->GUIobj->$object->type eq 'TextField') {
	my $m=$self->GUIobj->$object->maxlength;
	my $t=$self->GUIobj->$object->size;
        my $p=$self->GUIobj->$object->password;
        my $d=$self->GUIobj->$object->default;
        my $o=$self->GUIobj->$object->override;
	if (lc($o) eq 'no') {$o=0} else {$o=1};
	if ($p eq "yes") {
          $cell=$query->password_field(-name=>$n,-size=>$t, -maxlength=>$m);
	} else {
          $cell=$query->textfield(-name=>$n,-size=>$t, -default=>$d, -override=>$o);
	}  
      }
      if ($self->GUIobj->$object->type eq 'TextArea') {
	my $m=$self->GUIobj->$object->maxlength;
        my $p=$self->GUIobj->$object->password;
        my $r=$self->GUIobj->$object->rows;
        my $c=$self->GUIobj->$object->columns;
        my $d=$self->GUIobj->$object->default;
        my $o=$self->GUIobj->$object->override;
	if (lc($o) eq 'no') {$o=0} else {$o=1};
	if ($c or $r) {
          $cell=$query->textarea(-name=>'t', -rows=>$r, -columns=>$c, -default=>$d, -override=>$o);
	} else {
          $cell=$query->textfield(-name=>'t',-size=>$t, -default=>$d, -override=>$o);
	}  
      }
      if ($self->GUIobj->$object->Type eq 'ScrollingList') {
	#my ($data)=($self->GUIobj->Field_1->dscolumn=~/\[(.*)\]/);
	my $d=[split(';',$self->GUIobj->$data->content)];
        my $s=$self->GUIobj->$object->size;
        my $m=$self->GUIobj->$object->multiple;
	if (lc($m) eq 'false') {$m=0} else {$m=1};
        my %l=split(';',$self->GUIobj->$object->labels);
        my $e=$self->GUIobj->$object->default;
        $cell=$query->scrolling_list(-size=>$s, -values=>$d, -default=>$e, -labels=>\%l, -multiple=>$m, -name=>$n);
      }
      if ($self->GUIobj->$object->type eq 'PopupMenue') {
        
	my $data=$self->GUIobj->$object->dscolumn;
	my $dso=Apiis::Init::DataSource->new(interface=>'form', 
	                                     ds_object=>$self->GUIobj->{$self->GUIobj->$data->parent},
				             xml_object => $self->GUIobj);
        my $list_ref=$dso->get_listfield(returntype=>'arrayref', column_obj=>$self->GUIobj->$data);
	$self->GUIobj->$data->content($list_ref);  
	my $d=$self->GUIobj->$data->content;
        #my %l=split(';',$self->GUIobj->$object->labels);
        my $e=$self->GUIobj->$object->default;
        $cell=$query->popup_menu(-values=>$d, -default=>$e, -labels=>\%l, -name=>$n);
      }
      if ($self->GUIobj->$object->type eq 'Submit') {
        $query->delete('g');
        print $query->hidden(-name=>'g',-default=>$self->GUIobj->$object->Src);
	my $v=$self->GUIobj->$object->buttonlabel;
        $cell=$query->submit($n,$v);
      }
      if ($self->GUIobj->$object->type eq 'Link') {
	my $v=$self->GUIobj->$object->labels;
	$opt_o=$query->param('o');
	$opt_m=$query->param('m');
	$opt_p=$query->param('sid');
	$opt_u=$query->param('user');
	my $u="/cgi-bin/GUI?sid=$opt_p&g=".$self->GUIobj->$object->url;
        $cell=$query->a({-href=>$u},$v);
      }
      if ($self->GUIobj->$object->type eq 'Reset') {
	my $v=$self->GUIobj->$object->labels;
        $cell=$query->reset($v);
      }
      if ($self->GUIobj->$object->type eq 'ImageButton') {
	my $v=$self->GUIobj->$object->src;
        $cell=$query->image_button($n,$v);
      }
      if ($self->GUIobj->$object->type eq 'FileField') {
        my $s=$self->GUIobj->$object->size;
        my $e=$self->GUIobj->$object->default;
        my $l=$self->GUIobj->$object->maxlength;
        my $o=$self->GUIobj->$object->override;
	if (lc($o) eq 'Yes') {$o=0} else {$o=1};
        $cell=$query->filefield(-name=>$n,-default=>$e,-size=>$s,-maxlength=>$l,-override=>$o);
      }
      if ($self->GUIobj->$object->type eq 'CheckBoxGroup') {
	my $d=[split(';',$self->GUIobj->$data->content)];
        my $e=$self->GUIobj->$object->default;
        my $m=$self->GUIobj->$object->linebreak;
        my $c=$self->GUIobj->$object->columns;
        my $ch=$self->GUIobj->$object->columnheader;
        my $r=$self->GUIobj->$object->rows;
        my $rh=$self->GUIobj->$object->rowheader;
        my %l=split(';',$self->GUIobj->$object->labels);
        $cell=$query->checkbox_group(-name=>$n, -values=>$d, -default=>$e, -labels=>\%l, -linebreak=>$m,
	                             -columns=>$c, -columnheaders=>$ch, -rows=>$r, -rowheaders=>$rc);
      }
      if ($self->GUIobj->$object->type eq 'RadioGroup') {
	my $d=[split(';',$self->GUIobj->$data->content)];
        my $e=$self->GUIobj->$object->default;
        my $c=$self->GUIobj->$object->columns;
        my $ch=$self->GUIobj->$object->columnheader;
        my $r=$self->GUIobj->$object->rows;
        my $rh=$self->GUIobj->$object->rowheader;
        my %l=split(';',$self->GUIobj->$object->labels);
        $cell=$query->radio_group(-name=>$n, -values=>$d, -default=>$e, -labels=>\%l,
	                             -columns=>$c, -columnheaders=>$ch, -rows=>$r, -rowheaders=>$rc);
      }
      if ($self->GUIobj->$object->type eq 'CheckBox') {
        my $e=$self->GUIobj->$object->checked;
	if (lc($e) eq 'no') {$e=0} else {$e=1};
        my $l=$self->GUIobj->$object->labels;
        $cell=$query->checkbox(-name=>$n, -checked=>$e, -label=>$l);
      }
      if ($self->GUIobj->$object->type eq 'Label') {
        $cell=$self->GUIobj->$object->content;
      }
      
    } else {
      if ($et eq 'Text') {
        $cell=$self->GUIobj->$object->Content;
        $cell=~s/[\[\]]//g;
        $cell=__($cell);
      } else {
        $cell=$self->GUIobj->$object->Content;
      }	
    }
    if ($et eq 'Data') { 
      if (($self->GUIobj->$object->DecimalPlaces ne '') and
          ($self->GUIobj->$object->DecimalPlaces ne 'Automatic') and 
  	  ($self->GUIobj->$object->DecimalPlaces ne 'none')) {
        $cell=sprintf('%.'.$self->GUIobj->$object->DecimalPlaces.'f', $cell);
      }	
    }
  }
  if (($et eq 'Lines') or ($self->GUIobj->$object->FieldType eq 'Line') or ($self->GUIobj->$object->FieldType eq 'Lines')) {
    if (exists $self->GUIobj->{'ExportFile'}) {
      $cell=$query->img({-src=>"$APIIS_HOME/lib/images/blank1.gif"},);
    } else {
      $cell=$query->img({-src=>"/icons/blank1.gif"},);
    }
    my $r;my $t;my $w;
    if ($self->GUI eq 'Report' ) {
      $r=$self->GUIobj->$object->ForegroundColor;
      $t=$self->GUIobj->$object->LineType ;
      $w=$self->GUIobj->$object->LineWidth;
    } else {
      $r=$self->GUIobj->$object->ForeGround;
      $t=$self->GUIobj->$object->LineType ;
      $w=$self->GUIobj->$object->LineWidth.$self->GUIobj->$object->Unit;
    }   
    push(@properties,"border-top: $t $r $w");
  }

  if ($cell=~/^date\(/) {
    $cell=localtime();
  }
  #--- loop over all elements
  if ($self->GUI eq 'Report') {
   foreach  my $item (@{$self->GUIobj->$object->Functions}) {
    #--- initialize
    $replace='';
    $t='';

    #--- if content a function, then solve function and save return value
    if ($self->GUIobj->$object->$item=~/^([_a-zA-Z0-9_]*)\((.*)\)$/) {
      my @vparam=split(',',$2); 
      my $vfunction="Apiis::GUI::$1";
      
      #--- test if module exists
      if (! $self->GUIobj->CheckModul) {
        $self->LinkModul($self->GUIobj->path.'/'.$self->GUIobj->basename.".pm");
	return if ($self->Apiis->status==1);
      }
      
      #--- set parameters and auflösen
      my @vvparam=();
      foreach my $v (@vparam) {
        if ($v=~/\[(.*?)\]/) {
	  push(@vvparam,$self->GUIobj->$1->Content);
	} else {
	  push(@vvparam,$v);
	}
      }
      
      #--- execute function
      eval {
        $replace = &$vfunction($self, @vvparam);
      };  
      if ($@) {
        $self->Apiis->errors(
         Apiis::Errors->new(
         type      => 'CODE',
         severity  => 'ERR',
         from      => 'Apiis::GUI',
         msg_short => "Can't execute function $vfunction in module: $module",
         msg_long =>  "$@"
        ));
        $self->Apiis->status(1);
	return;
      }
      
      my $t=$replace;
      
      #--- 
      push(@properties,"width: $t")   if ($item eq 'Width');
      
      #--- Font 
      push(@properties,"font-family: $t")   if ($item eq 'FontFamily');
      push(@properties,"font-size: $t")     if ($item eq 'FontSize');;
      push(@properties,"font-style: $t")    if ($item eq 'FontStyle');;
      push(@properties,"font-weight: $t")   if ($item eq 'FontWeight');;
      push(@properties,"font-variant: $t")  if ($item eq 'FontVariant');;
      push(@properties,"font: $t")          if ($item eq 'Font');;
  
      #--- Color
      push(@properties,"background-color: $t") if ($item eq 'BackgroundColor');
      push(@properties,"color: $t")            if ($item eq 'Color');
      push(@properties,"background-image: $t") if ($item eq 'BackgroundImage');
      push(@properties,"background-repeat: $t") if ($item eq 'BackgroundRepeat');
      push(@properties,"background-attachment: $t") if ($item eq 'BackgroundAttachment');
      push(@properties,"background-position: $t")   if ($item eq 'BackgroundPosition');
      push(@properties,"background: $t")            if ($item eq 'Background');
  
      #--- Text
      push(@properties,"word-spacing: $t")        if ($item eq 'WordSpacing');
      push(@properties,"letter-spacing: $t")      if ($item eq 'LetterSpacing');
      push(@properties,"text-decoration: $t")     if ($item eq 'TextDecoration');
      push(@properties,"vertical-align: $t")      if ($item eq 'VerticalAlign');
      push(@properties,"text-transform: $t")      if ($item eq 'TextTransform');
      push(@properties,"text-align: $t")          if ($item eq 'TextAlign');
      push(@properties,"text-indent: $t")         if ($item eq 'TextIndent');
      push(@properties,"text-height: $t")         if ($item eq 'LineHeight');
  
      #--- Block
      push(@properties,"margin-top: $t")    if ($item eq 'MarginTop');
      push(@properties,"margin-right: $t")  if ($item eq 'MarginRight');
      push(@properties,"margin-bottom: $t") if ($item eq 'MarginBottom');
      push(@properties,"margin-left: $t")   if ($item eq 'MarginLeft');
      push(@properties,"margin: $t")        if ($item eq 'Margin');
      
      push(@properties,"padding-top: $t")    if ($item eq 'PaddingTop');
      push(@properties,"padding-right: $t")  if ($item eq 'PaddingRight');
      push(@properties,"padding-bottom: $t") if ($item eq 'PaddingBottom');
      push(@properties,"padding-left: $t")   if ($item eq 'PaddingLeft');
      push(@properties,"padding: $t")        if ($item eq 'Padding');
      
      push(@properties,"border-top-width: $t")    if ($item eq 'BorderTopWidth');
      push(@properties,"border-right-width: $t")  if ($item eq 'BorderRightWidth');
      push(@properties,"border-bottom-width: $t") if ($item eq 'BorderBottomWidth');
      push(@properties,"border-left-width: $t")   if ($item eq 'BorderLeftWidth');
      push(@properties,"border-width: $t")        if ($item eq 'BorderWidth');
      
      push(@properties,"border-style: $t")   if ($item eq 'BorderStyle');
      push(@properties,"border-color: $t")   if ($item eq 'BorderColor');
      
      push(@properties,"border-top: $t")    if ($item eq 'BorderTop');
      push(@properties,"border-right: $t")  if ($item eq 'BorderRight');
      push(@properties,"border-bottom: $t") if ($item eq 'BorderBottom');
      push(@properties,"border-left: $t")   if ($item eq 'BorderLeft');
      push(@properties,"border: $t")        if ($item eq 'Border');
  
      push(@properties,"width: $t")       if ($item eq 'BlockWidth');
      push(@properties,"height: $t")      if ($item eq 'BlockHeight');
      push(@properties,"float: $t")       if ($item eq 'BlockFloat');
      push(@properties,"clear: $t")       if ($item eq 'Clear');
      push(@properties,"display: $t")     if ($item eq 'Display');
      push(@properties,"white-space: $t") if ($item eq 'WhiteSpace');

      #--- List
      push(@properties,"list-style-type: $t")     if ($item eq 'ListStyleType');
      push(@properties,"list-style-image: $t")    if ($item eq 'ListStyleImage');
      push(@properties,"list-style-position: $t") if ($item eq 'ListStylePosition');
      push(@properties,"list-style: $t")          if ($item eq 'ListStyle');
    }
   }
  }
  my $a; my $properties2='';
  if ($column=~/^(.+)\-(.+)/) {
    $a=$2 - $1 + 1;
    $properties2=' colspan="'.$a.'"';
  } 
  if ($self->GUIobj->$object->Row=~/^(.+)\-(.+)/) {
    $a=$2 - $1 + 1;
    $properties2.=' rowspan="'.$a.'"';
  } 

  my $properties=' STYLE="'.join(';',@properties).'"' if ($#properties > -1);

  #-- search the right class name, if objects has the same properties only one object name is a class
  #-- the other one has a link to the right class
  my $vclass='';
  if (! exists $self->GUIobj->{_Style}->{$self->GUIobj->$object->Name}) {
    $vclass='';
  } elsif ($self->GUIobj->{_Style}->{$self->GUIobj->$object->Name}=~/:/) {
    $vclass=$self->GUIobj->$object->Name;
  } else {
    $vclass=$self->GUIobj->{_Style}->{$self->GUIobj->$object->Name};
  }
  if ($vclass eq '') {
    return '<td'.$properties . $properties2.'>'.$cell.'</td>';
  } else {
    return '<td class="'.$vclass.'"'.$properties . $properties2.'>'.$cell.'</td>';
  }  
}

sub PrintRow {
  my $self = shift;
  my $vcell = shift;
  my @cell=@{$vcell};
  my $cell=''; my $properites='';
  my $query=$self->Query;

  #--
  for (my $i=0; $i<$self->GUIobj->MaxColumn ;$i++) {
    if (!$self->GUIobj->SetColumnBusy->[$i]) {
      $cell.=$query->td({},"");
    } else {
      $cell.=$cell[$i];
    }
  }
  $self->{'_tablecontent'}.=$query->TR({$properties},$cell);
  $self->GUIobj->SetColumnBusy(-1);
}

sub PrintTable {
  my $self = shift;
  my $query=$self->Query;

#  if ($self->$object->Border ne '') {
#    my $t=$self->GUIobj->$object->Border ;
#    push(@properties,"border: $t");
#  }

#  my $t=$self->{'_tablecontent'};
#  $self->{'_tablecontent'}='';
  return $query->table({border=>"0", cellspacing=>"0", cellpadding=>"0"},$self->{'_tablecontent'});
}

###################################################################################
package Apiis::GUI::HTML::ApiisModel;
@Apiis::GUI::HTML::ApiisModel::ISA=qw (Apiis::GUI::HTML);
use CGI qw/:standard :html3/;
use Apiis::Init;
###################################################################################
                                                      
sub new {
  my ($class,%args) = @_;
  my $self={};

  bless $self, $class;
  $self->{'apiis'}=$args{'apiis'};
  $self->{'query'}=$args{'query'};
  $self->{'m'}=$args{'model'};
  return $self;
}

sub PrintHeader {
  my $self = shift;
  print $self->{'query'}->header;
  my $css="../etc/apiis.css";
  #if (! exists $ENV{'DOCUMENT_ROOT'}) {
  #  if (exists $ENV{'APIIS_HOME'}) {
  #    $css='file://'.$ENV{'APIIS_HOME'}.'/etc/apiis.css';
  #  } else {
  #    $css='apiis.css';
  #  }
  #}
  print $self->{'query'}->start_html(-style=>{-src=>$css},-class=>"menu");
}

sub Body {
  my $self=shift;
  my $query=$self->{'query'};
  print $query->h3({-class=>'menu'},$self->{'m'});
}

###################################################################################
package Apiis::GUI::HTML::ApiisAktiv;
@Apiis::GUI::HTML::ApiisAktiv::ISA=qw (Apiis::GUI::HTML);
use CGI qw/:standard :html3/;
use Apiis::Init;
###################################################################################
                                                      
sub new {
  my ($class,%args) = @_;
  my $self={};

  bless $self, $class;
  $self->{'apiis'}=$args{'apiis'};
  $self->{'query'}=$args{'query'};
  $self->{'m'}=$args{'model'};
  return $self;
}

sub PrintHeader {
  my $self = shift;
  print $self->{'query'}->header;
  my $css="../etc/apiis.css";
  #if (! exists $ENV{'DOCUMENT_ROOT'}) {
  #  if (exists $ENV{'APIIS_HOME'}) {
  #    $css='file://'.$ENV{'APIIS_HOME'}.'/etc/apiis.css';
  #  } else {
  #    $css='apiis.css';
  #  }
  #}
  print $self->{'query'}->start_html(-style=>{-src=>$css},-class=>"menu");
}

sub Body {
  my $self=shift;
}

###################################################################################
package Apiis::GUI::HTML::ApiisMenu;
@Apiis::GUI::HTML::ApiisMenu::ISA=qw (Apiis::GUI::HTML);
use CGI qw/:standard :html3/;
use Apiis::Init;
###################################################################################

###################################################################################
sub new {
###################################################################################
  my ($class,%args )=@_;
  my $self={};
  $self->{'query'}=$args{'query'};
  $self->{'apiis'}=$args{'apiis'};
  $self->{'dir'}=$args{'dir'};
  $self->{'p'}=$args{'session'};
  $self->{'u'}=$args{'user'};
  $self->{'m'}=$args{'model'};
  $self->{'o'}=$args{'output'};

  bless $self, $class;
  return $self;
}

sub PrintHeader {
  my $self = shift;
  my $query=$self->{'query'};
  my $apiis=$self->{'apiis'};
  print $query->header();
  $css='../etc/apiis.css';
  print $query->start_html({-style=>{-src=>$css},-class=>"menu"});
}

sub Body {
  my ($self)=@_;
  my $query=$self->{'query'};
  my $apiis=$self->{'apiis'};
  my $dir=$self->{'dir'};
  my $dirf=$self->{'dir'};
  my $opt_p=$self->{'p'};
  my $opt_u=$self->{'u'};
  my $opt_m=$self->{'m'};
  my $opt_o=$self->{'o'};
  
  my (@tables,@sforms,@forms,@allg,$i, $j);

  print $query->h1({-align=>'center'},uc("APIIS"));

  $dirf=$apiis->APIIS_LOCAL."/etc/menus";
   print div({style=>"border-style: groove; border-width: 2px; padding-left: 5px; background-color: rgb(255, 204, 0)"},a({-href=>"/cgi-bin/GUI?menu=$dirf&sid=$opt_p&dir=$dir", -target=>'menue'},__('Menüs') ));
   if ($dir=~/etc\/menus/) {
     ($dir)=($dir=~/(.*)\/.*?\//)  if $dir=~/\.\.$/;
     $dir=$apiis->APIIS_LOCAL."/etc/menus" if $dir!~/etc\/menus/;
     eval {
       opendir (DIR,"$dir") || die $self->PushErrGeneral($@);
       my @dird=(); my @dirf=();my @dir=();
       foreach (readdir(DIR)) {
         if ( -d $dir.'/'.$_ ) {
	   push(@dird,$_);
	 } else {
	   push(@dirf,$_);
	 }
       }
       closedir (DIR);
       push(@dir,sort @dird);
       push(@dir,sort @dirf);
       foreach (@dir) {
         next if ($_=~/CVS/);
         next if ($_=~/^\.$/);
         if ( -d $dir.'/'.$_) {
           my $dir1=$dir."/".$_;
           print a({-href=>"/cgi-bin/GUI?menu=$dir1&sid=$opt_p", -target=>'menue'},
                 img({-border=>0,-src=>"/icons/dir_kl.gif"})).$_.br();
         } else {
           ($vfrm)=($_=~/(.*)\.frm/);
           if ($vfrm) {
 	    my $f=$dir.'/'.$_;
             print a({-href=>"/cgi-bin/GUI?sid=$opt_p&g=$f"},
                 img({-border=>0,-src=>"/icons/text_kl.gif"}).$vfrm).br();
           }
         }
       }
     };
   }

if ($self->{'apiis'}->APIIS_LOCAL) {
   $dirf=$apiis->APIIS_LOCAL."/etc/forms";
   print div({style=>"border-style: groove; border-width: 2px; padding-left: 5px; background-color: rgb(255, 204, 0)"},a({-href=>"/cgi-bin/GUI?menu=$dirf&sid=$opt_p&dir=$dir", -target=>'menue'},__('Masken') ));
   if ($dir=~/\/forms/) {
     print b();
     my $vfrm;
     if ($dir=~/etc\/forms/) {
       ($dir)=($dir=~/(.*)\/.*?\//)  if $dir=~/\.\.$/;
       $dir=$apiis->APIIS_LOCAL."/etc/forms" if $dir!~/etc\/forms/;
       eval {
         opendir (DIR,"$dir") || die $self->PushErrGeneral($@);
         my @dird=(); my @dirf=();my @dir=();
         foreach (readdir(DIR)) {
           if ( -d $dir.'/'.$_ ) {
  	     push(@dird,$_);
	   } else {
	     push(@dirf,$_);
	   } 
         }
         closedir (DIR);
         push(@dir,sort @dird);
         push(@dir,sort @dirf);
         foreach (@dir) {
           next if ($_=~/CVS/);
           next if ($_=~/^\.$/);
           if ( -d $dir.'/'.$_) {
             my $dir1=$dir."/".$_;
             print a({-href=>"/cgi-bin/GUI?menu=$dir1&sid=$opt_p", -target=>'menue'},
                 img({-border=>0,-src=>"/icons/dir_kl.gif"})).$_.br();
           } else {
             ($vfrm)=($_=~/(.*)\.frm/);
             if ($vfrm) {
               my $dir1=$dir.'/'.$_;
               print a({-href=>"/cgi-bin/GUI?g=$dir1&sid=$opt_p"},
                   img({-border=>0,-src=>"/icons/text_kl.gif"}). $vfrm).br();
             }
           }
         }
       };
     }
   }
   
   $dirf=$apiis->APIIS_LOCAL."/etc/reports";
   print div({style=>"border-style: groove; border-width: 2px; padding-left: 5px; background-color: rgb(255, 204, 0)"},a({-href=>"/cgi-bin/GUI?menu=$dirf&sid=$opt_p", -target=>'menue'},__('Berichte') ));
   if ($dir=~/etc\/reports/) {
     ($dir)=($dir=~/(.*)\/.*?\//)  if $dir=~/\.\.$/;
     $dir=$apiis->APIIS_LOCAL."/etc/reports" if $dir!~/etc\/reports/;
     eval {
       opendir (DIR,"$dir") || die $self->PushErrGeneral($@);
       my @dird=(); my @dirf=();my @dir=();
       foreach (readdir(DIR)) {
         if ( -d $dir.'/'.$_ ) {
	   push(@dird,$_);
	 } else {
	   push(@dirf,$_);
	 }
       }
       closedir (DIR);
       push(@dir,sort @dird);
       push(@dir,sort @dirf);
       foreach (@dir) {
         next if ($_=~/CVS/);
         next if ($_=~/^\.$/);
         if ( -d $dir.'/'.$_) {
           my $dir1=$dir."/".$_;
           print a({-href=>"/cgi-bin/GUI?menu=$dir1&sid=$opt_p", -target=>'menue'},
                 img({-border=>0,-src=>"/icons/dir_kl.gif"})).$_.br();
         } else {
           ($vfrm)=($_=~/(.*)\.rpt/);
           if ($vfrm) {
 	    my $f=$dir.'/'.$_;
             print a({-href=>"/cgi-bin/GUI?sid=$opt_p&g=$f" -target=>'aktiv'},
                 img({-border=>0,-src=>"/icons/text_kl.gif"}).$vfrm).br();
           }
         }
       }
     };
   }
 
 }
  
}  

1;

