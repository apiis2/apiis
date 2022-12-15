#############################################################################
# $Id: XML.pm,v 1.21 2016/06/15 12:11:59 ulm Exp $
##############################################################################

package Apiis::Init::XML;
$VERSION = '$Revision $';

use strict;
use Carp;
use warnings;
use XML::DTDParser qw(ParseDTD ParseDTDFile);
use XML::Simple;
use Apiis::Init;

@Apiis::Init::XML::ISA = qw( Apiis::Init );

sub new {
   my ( $invocant, %args ) = @_;
   
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);
   return $self;
}

##############################################################################
sub _init {

   #--- internal subroutine to reduce code     
   sub MergeAttributes {
     my ($dtd, $xml) = @_;
     #-- first all attributes
     #-- %attributes merges default from dtd and definition from xml
     my $attributes={};      
  
     #-- default values from dtd for each attribute of this element
     foreach my $attr (keys %{$dtd}) {
       $attributes->{$attr}=$dtd->{$attr}[2];
       
       #--- overwrite default values with definition from xml-file
       $attributes->{$attr}=$xml->{$attr} if (exists $xml->{$attr});
     }
    
     #-- overwrite with actual values
     foreach my $attr (keys %{$xml}) {
       $attributes->{$attr}=$xml->{$attr};
     }        
     return $attributes;
   }
   
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++;    # Conway p. 243

   #--- read dtd and init a hash with all entries
   my $dtd;
   eval {
     $dtd = ParseDTDFile( $args{'dtd'} );
   };
   if ( $@ ) {
      $apiis->errors(
         Apiis::Errors->new(
            type      => 'CODE',
            severity  => 'ERR',
            from      => 'Apiis::Init::XML',
            msg_short => __( "$@", 'gui', 'Apiis::Init::XML' ),
         )
      );
      $apiis->status(1);
   }        

   #--- basic initialisation -> $self->{"General"}=[]  and $self->{"GeneralObjects"}=[]
   #--- 
   map {$self->{$_}=[]; $self->{$_.'Objects'}=[] } @{$dtd->{$args{'gui'}}->{childrenARR}};

   $self->{"_MaxColumn"} = 1;
   $self->{"_ContentFields"} = ();
   $self->{"_GUI"}=$args{'gui'};
   $self->{"_CheckModul"} = undef;
   $self->{"_GetAllSubGUIs"} = undef;
   $self->{"_GetAllBlocks"} = undef;
   $self->{"_GetAllDataSources"} = undef;
   $self->{"_Children"} = undef;

   no strict 'refs';
   my $a1 = Apiis::CheckFile->new( file => $args{'xml'} );
   if ( $a1->status ) {
     foreach ( $a1->errors ) {
       push @{$self->{"_errors"}},$a1->errors;
     }
     $apiis->status(1);
   } else {
       $self->{"_fullname"} = $a1->base . $a1->ext;
       $self->{"_basename"} = $a1->base;
       $self->{"_ext"}      = $a1->ext;
       $self->{"_path"}     = $a1->path;
   }

   my %hs_name;
   my %hs_position;
   unless ( $apiis->status ) {
 
    if ($self->{_GUI} eq 'Form') {
            
      #--- read all attributes and elements from a xml-configuration-file
      my $hs_xml = XMLin($args{'xml'});

      sub CreateObjects {
        my ($self,$dtd,$vhsxml,$xml_element,$parent)=@_;

        my $hs_xml={}; my $attributes;
        
        #-- creates a key as anonymous array for each possible element
        #-- this array contain all names of all elements with the same type
        #-- $self->Block{$name}->Field => ('Field_1', 'Field_2')
        #--
        foreach my $element (@{$dtd->{$xml_element}->{childrenARR}}) {
          next if (! exists $dtd->{$element}->{'Name'});     
          $hs_xml->{$element.'s'}=[];
        }  
        $hs_xml->{'Parent'}=$parent;
        $hs_xml->{'Children'}=[];
        $hs_xml->{'ElementType'}=$xml_element;
        $hs_xml->{'OrderByRow'}=[];
        
        #--- loop over all possible childelements in a dtd from an element
        foreach my $key (@{$dtd->{$xml_element}->{childrenARR}}) {
          next if (! exists $vhsxml->{$key});      
          if (ref $vhsxml->{$key} eq 'HASH') {
            push (@{$hs_xml->{Children}},$vhsxml->{$key}->{Name}) if (exists $vhsxml->{$key}->{Name});
            push (@{$hs_xml->{$key.'s'}},$vhsxml->{$key}->{Name}) if (exists $vhsxml->{$key}->{Name});
          } elsif (ref $vhsxml->{$key} eq 'ARRAY') {
            foreach my $el (@{$vhsxml->{$key}}) {
              push (@{$hs_xml->{Children}},$el->{Name}) if (exists $el->{Name});
              push (@{$hs_xml->{$key.'s'}},$el->{Name}) if (exists $el->{Name});
            }
          }  
        }

        #-- merge attributs of elements which have no name-attribut
        #-- into the parent element as attributs
        foreach my $attribute (@{$dtd->{$xml_element}->{childrenARR}}) {                
          next if (exists $dtd->{$attribute}->{attributes}->{Name});
        
          foreach my $element (keys %{$dtd->{$attribute}->{attributes}}) {
            $hs_xml->{$element}=$dtd->{$attribute}->{attributes}->{$element}[2] if (! exists $hs_xml->{$element});
            if (exists $vhsxml->{$attribute}->{$element}) {
              $hs_xml->{$element}=$vhsxml->{$attribute}->{$element};
            }  
          }  
        } 
               
        #-- merge attributes of the given element from dtd and frm|rpt
        foreach my $attribute (keys %{$dtd->{$xml_element}->{'attributes'}}) {                
          $hs_xml->{$attribute}=$dtd->{$xml_element}->{'attributes'}->{$attribute}[2];      
          
          #-- save attributes, if $sub_element a attribute and not an element
          if (exists $vhsxml->{$attribute}) {
            $hs_xml->{$attribute}=$vhsxml->{$attribute};      
          }        
        }  
        
        $hs_xml->{'Type'}='Sql'      if (($xml_element eq 'DataSource') and ($hs_xml->{'Statement'}));
        $hs_xml->{'Type'}='Bash'     if (($xml_element eq 'DataSource') and ($hs_xml->{'Command'}));
        $hs_xml->{'Type'}='Function' if (($xml_element eq 'DataSource') and ($hs_xml->{'FunctionName'}));
        $hs_xml->{'Type'}='Record'   if (($xml_element eq 'DataSource') and ($hs_xml->{'TableName'}));
        
        push(@{$self->{General}},$hs_xml->{'Name'})           if ($xml_element eq 'General');
        push(@{$self->{_GetAllBlocks}},$hs_xml->{'Name'})      if ($xml_element eq 'Block');
        push(@{$self->{_GetAllDataSources}},$hs_xml->{'Name'}) if ($xml_element eq 'DataSource');
        if (($xml_element ne 'DataSource') and ($xml_element ne 'General')) {
          push(@{$self->{_AllStyleObjects}},$hs_xml->{'Name'});
        } 
  	
        #-- Create object for main-element
        no strict 'subs';
        $self->{$hs_xml->{'Name'}}=Apiis::GUI::ElementObj->new($hs_xml);
	*{$hs_xml->{'Name'}} = sub { return $self->{$hs_xml->{'Name'}};};
        
        foreach my $elements (keys %{$vhsxml}) {
             
          #-- do not create a object for keys which are hashs, but no elements like dtd
          next if (! exists $dtd->{$elements});
          
          if (ref $vhsxml->{$elements} eq 'HASH') {
            #-- do not create a object for elements without a Name attribute
            next if (! exists $vhsxml->{$elements}->{'Name'});
           
            CreateObjects($self,$dtd,$vhsxml->{$elements},$elements,$hs_xml->{'Name'});
          } elsif (ref $vhsxml->{$elements} eq 'ARRAY') {
            foreach my $el (@{$vhsxml->{$elements}}) {
              #-- do not create a object for elements without a Name attribute
              next if (! exists $el->{'Name'});
             
              CreateObjects($self,$dtd,$el,$elements,$hs_xml->{'Name'});
            }
          }  
        }  
      }
      
      #-- starts rexursively over all root-elements and creates objects with the keys of hash as Methods
      my $i;
      map { if (! exists $hs_xml->{$_}->{'Name'}) {$hs_xml->{$_}->{'Name'}='NN_'.$i++};
            CreateObjects($self,$dtd,$hs_xml->{$_},$_,'Form') 
          }  @{$dtd->{$args{'gui'}}->{childrenARR}};
      map { push(@{$self->{_Children}}, $hs_xml->{$_}->{Name}) if (exists
                      $hs_xml->{$_}->{Name}) }  @{$dtd->{$args{'gui'}}->{childrenARR}};

    } else {  
      map {$self->{$_}=[]; $self->{$_.'Objects'}=[] } @{$dtd->{$args{'gui'}}->{childrenARR}};

      #--- read all attributes and elements from a xml-configuration-file
      my $hs_xml = XMLin($args{'xml'});
      
      #--- loop over all Elements
      my $key; my $value;
      foreach my $xml_element (sort keys %{$hs_xml}) {

        #-- these are no elements 
        next if (ref $hs_xml->{$xml_element} ne 'HASH');
        
        #-- if Group then initialize GroupObjects
        if ($xml_element eq 'GroupHeader' ) {
          $hs_xml->{$xml_element}->{'GroupHeaderObjects'}=[];
          foreach my $elements (keys %{$hs_xml->{$xml_element}}) {
            #-- do not create a object for keys which are hashs, but no elements like dtd
            next if ($elements!~/(Data|Lines|Text|PageBreak|SubGUI|Images)/);
          
            if (ref $hs_xml->{$xml_element}->{$elements} eq 'HASH') {
              push(@{$hs_xml->{$xml_element}->{'GroupHeaderObjects'}},
                              $hs_xml->{$xml_element}->{$elements}->{'Name'});
            } elsif (ref $hs_xml->{$xml_element}->{$elements} eq 'ARRAY') {
              foreach my $el (@{$hs_xml->{$xml_element}->{$elements}}) {
                push(@{$hs_xml->{$xml_element}->{'GroupHeaderObjects'}},$el->{'Name'});
              }
            } 
          }  
        }  

        $hs_xml->{$xml_element}->{'GroupFooterObjects'}=[] if ($xml_element eq 'GroupFooter' );
        $hs_xml->{$xml_element}->{'ElementType'}=$xml_element;
       
        
        #--- fill attributes
        my $attributes=MergeAttributes($dtd->{$xml_element}->{'attributes'},$hs_xml->{$xml_element});
        $attributes->{'OrderByRow'}=[];
        $attributes->{'CallFrom'}='';

        #--- Create a new element-object, sub-elements for the parent-element removed
	no strict 'subs';
        $self->{$hs_xml->{$xml_element}->{'Name'}}=Apiis::GUI::ElementObj->new($attributes);
	*{$hs_xml->{$xml_element}->{'Name'}} = sub { return $self->{$hs_xml->{$xml_element}->{'Name'}};};
        
        $self->{$xml_element}=[]  if (undef $self->{xml_element});
        push(@{$self->{$xml_element}},$hs_xml->{$xml_element}->{'Name'});
        push(@{$self->{_XMLElement}},$hs_xml->{$xml_element}->{'Name'});
       
                
        #--- save position of fields and datas in select
        if (exists $hs_xml->{$xml_element}->{'DataSource'}) {
	  if ($hs_xml->{$xml_element}->{'DataSource'}) {
            if ($hs_xml->{$xml_element}->{'DataSource'}=~/^select\s/i) {      
	      my $st=$1; my $i=0; #offen: genaues parsen jetzt is 'as' zwingend
	      while ($st=~/.*?as\s+(.*?)[,\s]/mg) {
	        $hs_name{$1}=$i++;
	      } 
            }  
                   
            #-- collect {}-parameter
            while ( $hs_xml->{$xml_element}->{'DataSource'} =~ m{ (\{([_a-zA-Z]?[_a-zA-Z0-9\s\.\,\:]*)\}) }xg) {
              $self->{'_Parameter'}->{$1}=[$1,$2] ;
            }
	  }
        }      
        
        #--- Sortieren der Childelemente nach Zeilen
        #--- miserable Programmierung
        my @vsort;my %hs_sort=();my $v2sort=[]; 
        foreach my $childelement (keys %{$hs_xml->{$xml_element}}) {

          #--- next, if $childelement an attributdefinition in dtd and not an element
          next if (! exists $dtd->{$xml_element}->{children}->{$childelement});
          
          #--- copy fix-address to ref-address to use the same code, if element
          #--- is a hash and not hashs in an array
          if (ref $hs_xml->{$xml_element}->{$childelement} eq 'HASH') {
             $hs_xml->{$xml_element}->{$childelement}=[$hs_xml->{$xml_element}->{$childelement}];
          }   
        
          my $row;
          foreach my $child (@{$hs_xml->{$xml_element}->{$childelement}}) {
            $child->{'ElementType'}=$childelement;
         
            if (exists $child->{'Row'}) {
              ($row)=($child->{'Row'}=~/^(\d*)/);      
            } else {
              $row=$row++;      
            }        
            push(@$v2sort,[$row,$child->{'Name'}]);
            $hs_sort{$row}=[] if (! exists $hs_sort{$row});
            push(@{$hs_sort{$row}},$child); 
          }  
        }
        foreach my $key (sort keys %hs_sort) {
          foreach (@{$hs_sort{$key}}) {      
            push(@vsort,$_);      
          }  
        }        
        map { push(@{$self->{$hs_xml->{$xml_element}->{'Name'}}->{'OrderByRow'}},$_->[1])} sort {$a->[0] <=> $b->[0]} @$v2sort;
          
        #--- now loop over all children-elements 
        foreach my $child (@vsort) {
            #--- save all subguis/forms 
            if (exists $child->{'GUISource'}) {
              $self->{'_GetAllSubGUIs'}->{$child->{'GUISource'}}='';
            }
                  
            my $attributes=MergeAttributes($dtd->{$child->{'ElementType'}}->{'attributes'},$child);
            $attributes->{'PositionSQL'}=undef;
            $attributes->{'QuestionChangeValue'}=undef;
            $attributes->{'ElementType'}=$child->{'ElementType'};
            $attributes->{'Functions'}=[];
            map {if ($child->{$_}=~/^([_a-zA-Z0-9_]*)\((.*)\)$/)
                    {push(@{$attributes->{'Functions'}},$_) } }  keys %{$child};
            #--- set parent group 
            $attributes->{'CallFrom'}=$xml_element;
            #--- additional methods, which are not implemented in a dtd        
            for my $item (qw/ _n _sum _sum2 _min _max _last _first/) {
              $self->{$item}=0;
            }
            for my $item (qw/ _value/) {
              $self->{$item}=undef;
            }
            
            #--- Create a new element-object, sub-elements for the parent-element removed
	    no strict 'subs';
            $self->{$child->{'Name'}}=Apiis::GUI::ElementObj->new($attributes);
	    *{$child->{'Name'}} = sub { return $self->{$child->{'Name'}};};
            
            #--- get max columns
            if ((exists $child->{'Column'}) and ($child->{'Column'}!~/-/) and
	       ($child->{'Column'} > $self->{'_MaxColumn'})) {
                 $self->{'_MaxColumn'}=$child->{'Column'}
	    }
	    
	    if ((exists $child->{'Content'}) and ($child->{'Content'}=~/\[(.*)\]/)) {
              $hs_position{$1}=$child->{'Name'};
	    }
            
            #--- save name and object-reference into arrays
            push(@{$self->{$xml_element.'Objects'}},$child->{'Name'});
            push(@{$self->{'_AllStyleObjects'}},$child->{'Name'});

            #--- collect Data fields 
            if (($self->{$child->{'Name'}}->{'ElementType'} eq 'Data') or 
                ($self->{$child->{'Name'}}->{'ElementType'} eq 'Hidden') or
                ($self->{$child->{'Name'}}->{'ElementType'} eq 'TextField') 
                ){
              push(@{$self->{_ContentFields}},$child->{'Name'}) 
            };
          }
        }               
      }
     foreach my $key (keys %hs_name) {
       my $a=$hs_position{$key};     
       $self->$a->PositionSQL($hs_name{$key});      
     }
   }  
}

sub fullname { return $_[0]->{"_fullname"} };
sub basename { return $_[0]->{"_basename"} };
sub ext { return $_[0]->{"_ext"} };
sub path { return $_[0]->{"_path"} };
sub gui_file { return $_[0]->{"_gui_file"} };
sub MaxColumn { return $_[0]->{"_MaxColumn"} };
sub ContentFields { return $_[0]->{"_ContentFields"} };
#sub Query { return $_[0]->{"_Query"} };
#sub Apiis { return $_[0]->{"_Apiis"} };
sub GUI { return $_[0]->{"_GUI"} };
sub XMLElements { return $_[0]->{"_XMLElements"} };
sub Parameter { return $_[0]->{"_Parameter"} };
sub CheckModul { return $_[0]->{"_CheckModul"} };
sub GetAllSubGUIs { return $_[0]->{"_GetAllSubGUIs"} };
sub GetAllBlocks { return $_[0]->{"_GetAllBlocks"} };
sub GetAllDataSources { return $_[0]->{"_GetAllDataSources"} };
sub Children { return $_[0]->{"_Children"} };
sub AllStyleObjects { return $_[0]->{"_AllStyleObjects"} };

sub GUIHeaderObjects { return $_[0]->{"GUIHeaderObjects"} };
sub GUIFooterObjects { return $_[0]->{"GUIFooterObjects"} };
sub PageHeaderObjects { return $_[0]->{"PageHeaderObjects"} };
sub PageFooterObjects { return $_[0]->{"PageFooterObjects"} };
sub GroupHeaderObjects { return $_[0]->{"GroupHeaderObjects"} };
sub GroupFooterObjects { return $_[0]->{"GroupFooterObjects"} };
sub DetailObjects { return $_[0]->{"DetailObjects"} };
sub GUIHeader { return $_[0]->{"GUIHeader"} };
sub GUIFooter { return $_[0]->{"GUIFooter"} };
sub PageHeader { return $_[0]->{"PageHeader"} };
sub PageFooter { return $_[0]->{"PageFooter"} };
sub GroupHeader { return $_[0]->{"GroupHeader"} };
sub GroupFooter { return $_[0]->{"GroupFooter"} };
sub Detail { return $_[0]->{"Detail"} };
sub General { return $_[0]->{"General"} };

sub SetColumnBusy {
    my ( $self, $newval ) = @_;
    if ( $#_ == 1 ) {
       if ($newval == -1) {
         $self->{'SetColumnBusy'}=[];
       } else {
         $self->{'SetColumnBusy'}->[$newval-1]=1;
       }
    } else {
       return $self->{'SetColumnBusy' };
    }
}

###############################################################################
package Apiis::GUI::ElementObj;
$Apiis::GUI::ElementObj::VERSION = '$Revision: 1.21 $';

use Carp;
no strict 'refs';
use Data::Dumper;


sub new {
   my ( $invocant, $args ) = @_;
   
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init($args);

   no warnings ;
   foreach my $item (keys %{$args}) {
     no strict "refs";
     *{$item} = sub {
       my ( $self, $newval ) = @_;

       if ( $#_ == 1 ) {
         $newval='' if (! $newval);
         if (($item eq 'Content') and ($args->{'ElementType'} eq 'Data' )) {
	   $self->{'_n'}=$self->{'_n'} + 1;

	   if (($newval=~/^[+-]?[\.0-9]*$/) and ($newval ne "")) {
	     $self->{'_sum'}=$self->{'_sum'} + $newval;
	     $self->{'_sum2'}=$self->{'_sum2'} + ($newval * $newval);
	     $self->{'_min'}=$newval if ($self->{'_min'} > $newval);
	     $self->{'_max'}=$newval if ($self->{'_max'} < $newval);
	     $self->{'_first'}=$newval if (undef $self->{'_first'});
	     $self->{'_last'}=$newval;
	   }

	   #-- first call
	   if (! $self->{'_value'} ) {
	     $self->{'_QuestionChangeValue'}=2;
	   #-- new group  
	   } elsif ($self->{'_value'} ne $newval) {
	     $self->{'_QuestionChangeValue'}=1;
	   #-- no change  
	   } else {  
	     undef $self->{'_QuestionChangeValue'};
	   }

  	   $self->{'_value'}=$newval;
	 } else {  
           $self->{$item} = $newval;
	 }  
       } else {
          return undef unless exists $self->{$item };
	  if (($item eq 'Content') and ($args->{'ElementType'} eq 'Data' )) {
	    if ($self->{ $item } =~/^std\(/) {
	      if ($self->{'_n'}>1) {
                return (sqrt($self->{'_sum2'} - ($self->{'_sum'} * $self->{'_sum'}) )) / ($self->{'_n'} - 1);
              } else {
	        return 0;
	      }	
	    }
	    if ($self->{ $item } =~/^avg\(/) {
	      if ( $self->{'_n'} > 0 ) {
                return $self->{'_sum'} / $self->{'_n'};
              } else {
	        return 0;
	      }	
	    }
	    return $self->{'_n'}     if ($self->{ $item }=~/^cnt\(/i);
	    return $self->{'_min'}   if ($self->{ $item }=~/^min\(/i);
	    return $self->{'_max'}   if ($self->{ $item }=~/^max\(/i);
	    return $self->{'_first'} if ($self->{ $item }=~/^first\(/i);
	    return $self->{'_last'}  if ($self->{ $item }=~/^last\(/i);
#	    return $apiis->today()   if ($self->{ $item }=~/^date\(/i);
	    return $self->{'_value'};
	  } else {
            return $self->{ $item };
	  }  
       }
     }  
   }
   use warnings;
   return $self;
}

sub _init {
  my ( $self, $args ) = @_;
  my $pack = __PACKAGE__;
  return if $self->{"_init"}{$pack}++;    # Conway p. 243

  #--- initialize object with data
  foreach my $item (keys %{$args}) {
    $self->{$item}=$args->{$item};    
  }
  
}   
1;
__END__

=head1 SYNOPSIS

   $xml_obj = Apiis::Init::XML->new(%args);
   $xml_obj = Apiis::Init::XML->new(
         dtd=>$dtd_file,
         xml=>$xml_file,
         gui=>$what_type_of_gui
   );

=head1 DESCRIPTION

XML.pm init a file of configuration written in xml. XML.pm merge definitions
from the configuration file and the default values from the dtd-scheme. 

Suppositions:

Each xml-element need a unique name over all configuration and subconfiguration
files, which will be defined in "Name". Access to each attribute take place with
a method in combination with the name of the element:

   xml:
    <PageHeader Name="PageHeader_10">
      <Lines Name="Line_1" Column="1-4" Row="1" LineType="solid"/>
    </PageHeader>             
    ---------

   code: 
    $c=$xml_obj->Line_1->LineType
    $c is "solid"

    $c=$xml_obj->Line_1->Name
    $c is "Line_1"

Independent of the xml-definition a complete set of methods will be initiate
depend on the definition in the dtd-scheme. The default settings come from the
dtd-scheme and will overwritten if a the same attribute is defined in the
xml-scheme. E.g.

   dtd: 
   <!ATTLIST Text  
           Name       ID                          #REQUIRED
           Content    CDATA                       #REQUIRED
           Position   (static|absolute|relative)  "relative"
   >

  xml:
  <PageHeader Name="PageHeader_10">
     <Text Position="relative" Name="Text_1" Content="test"/>
  </PageHeader>

  code: 
   $c=$xml_obj->Text_1->Position
   $c is "relative"


Each xml-file has a hierachical structure. XML makes a flat structure.  

=cut


=head1 METHODS 

=head2 $apiis->GUI->[fullname | basename | ext | path | gui_file ] (all public, readonly)

fullname, basename, ext, path provide the fullname (basename.extension),
basename (without extension), extension, and path of the gui file.

=cut

# vim:tw=80:cindent:aw:expandtab
