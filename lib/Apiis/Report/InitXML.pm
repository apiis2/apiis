#############################################################################
# $Id: InitXML.pm,v 1.3 2004/11/26 13:55:59 ulm Exp $
##############################################################################

package Apiis::Report::InitXML;
$VERSION = '$Revision $';

use strict;
use Carp;
use warnings;
use Apiis::Errors;
use Apiis::CheckFile;
use Data::Dumper;
use XML::DTDParser qw(ParseDTD ParseDTDFile);
use XML::Simple;
use Apiis::Init;
use Tie::IxHash;

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
     return $attributes;
   }
   
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++;    # Conway p. 243

   #--
   if ( ! exists $args{'xml'} ) {
      push @{ $self->{"_Errors"} },
        Apiis::Errors->new(
         type      => 'CODE',
         severity  => 'ERR',
         from      => 'Apiis::Report::Init',
         msg_short => __("No key [_1] passed to [_2]", 'report', 'Apiis::Report::Init'),
      );
   }        
   
   #--- read dtd and init a hash with all entries
   my $dtd = ParseDTDFile( $args{'dtd'} );

   #--- basic initialisation -> $self->{"General"}=[]  and $self->{"GeneralObjects"}=[]
   #--- 
   map {$self->{$_}=[]; $self->{$_.'Objects'}=[] } @{$dtd->{$args{'gui'}}->{childrenARR}};

   $self->{"_MaxColumn"} = 1;
   $self->{"_Errors"} = [];
   $self->{"_ContentFields"} = ();
   $self->{"_Report"}=$args{'report'};
   $self->{"_Status"} = undef;
   $self->{"_CheckModul"} = undef;
   $self->{"_GetAllSubReports"} = undef;

   no strict 'refs';
   my $a = Apiis::CheckFile->new( file => $args{'xml'} );
   if ( $a->status ) {
     foreach ( @{ $a->errors } ) {
       push(@{$self->{"_Errors"}},$a->errors);
     }
     $self->{'_Status'}=1;
   } else {
       $self->{"_fullname"} = $a->base . $a->ext;
       $self->{"_basename"} = $a->base;
       $self->{"_ext"}      = $a->ext;
       $self->{"_path"}     = $a->path;
   }

   my %hs_name;
   my %hs_position;
   unless ( $self->{"_Status"} ) {

      #--- read all attributes and elements from a xml-configuration-file
      my $hs_xml = XMLin($args{'xml'});

      #--- loop over all Elements
      my $key; my $value;
      foreach my $xml_element (keys %{$hs_xml}) {
        
        #--- fill attributes
        my $attributes=MergeAttributes($dtd->{$xml_element}->{'attributes'},$hs_xml->{$xml_element});
        $attributes->{'ElementType'}=$xml_element;
       
        #--- Create a new element-object, sub-elements for the parent-element removed
	no strict 'subs';
        $self->{$hs_xml->{$xml_element}->{'Name'}}=Apiis::Report::ElementObj->new($attributes);
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
        my @vsort;my %hs_sort=();
        foreach my $childelement (keys %{$hs_xml->{$xml_element}}) {

          #--- next, if $childelement an attributdefinition in dtd and not an element
          next if (! exists $dtd->{$xml_element}->{children}->{$childelement});
          
          #--- copy fix-address to ref-address to use the same code, if element
          #--- is a hash and not hashs in an array
          if (ref $hs_xml->{$xml_element}->{$childelement} eq 'HASH') {
             $hs_xml->{$xml_element}->{$childelement}=[$hs_xml->{$xml_element}->{$childelement}];
          }   
        
          foreach my $child (@{$hs_xml->{$xml_element}->{$childelement}}) {
            $child->{'ElementType'}=$childelement;
                  
            my ($row)=($child->{'Row'}=~/^(\d*)/);      
            $hs_sort{$row}=[] if (! exists $hs_sort{$row});
            push(@{$hs_sort{$row}},$child); 
          }  
        }
        foreach my $key (sort keys %hs_sort) {
          foreach (@{$hs_sort{$key}}) {      
            push(@vsort,$_);      
          }  
        }        
          
        #--- now loop over all children-elements 
        foreach my $child (@vsort) {
            #--- save all subreports/forms 
            if (exists $child->{'ReportSource'}) {
              $self->{'_GetAllSubReports'}->{$child->{'ReportSource'}}='';
            }
                  
            my $attributes=MergeAttributes($dtd->{$child->{'ElementType'}}->{'attributes'},$child);
            $attributes->{'PositionSQL'}=undef;
            $attributes->{'QuestionChangeValue'}=undef;
            $attributes->{'ElementType'}=$child->{'ElementType'};
            
            #--- set parent group 
            $attributes->{'CallFrom'}=$xml_element;
            
            #--- Create a new element-object, sub-elements for the parent-element removed
	    no strict 'subs';
            $self->{$child->{'Name'}}=Apiis::Report::ElementObj->new($attributes);
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

            #--- collect Data fields 
            if (($self->{$child->{'Name'}}->{'ElementType'} eq 'Data') or 
                ($self->{$child->{'Name'}}->{'ElementType'} eq 'Hidden') ){
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

no strict 'refs';
foreach my $thiskey (qw/ fullname basename ext path report_file MaxColumn ContentFields Errors
                         Query Apiis Report Status Errors XMLElements Parameter
                         CheckModul GetAllSubReports
                         /) {
   *$thiskey = sub { return $_[0]->{"_$thiskey"} };
}

for my $item (qw/ ReportHeaderObjects ReportFooterObjects PageHeaderObjects PageFooterObjects
                  GroupHeaderObjects GroupFooterObjects DetailObjects ReportHeader
                  ReportFooter PageHeader PageFooter GroupHeader GroupFooter Detail General/) {
           *{$item} = sub {
              my ( $self ) = @_;
              return undef unless exists $self->{$item };
              return $self->{ $item };
            };
}

foreach my $item (qw/ SetColumnBusy /) {
  no strict "refs";
  *{$item} = sub {
    my ( $self, $newval ) = @_;
    if ( $#_ == 1 ) {
       if ($newval == -1) {
         $self->{$item}=[];
       } else {
         $self->{$item}->[$newval-1]=1;
       }
    } else {
       return $self->{ $item };
    }
  };
}

###############################################################################
package Apiis::Report::ElementObj;
$Apiis::Report::ElementObj::VERSION = '$Revision: 1.3 $';

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
         if ($item eq 'Data') {
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
	  if ($item eq 'Data') {
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
  
  #--- additional methods, which are not implemented in a dtd        
  for my $item (qw/ _n _sum _sum2 _min _max _last _first/) {
    $self->{$item}=0;
  }
  for my $item (qw/ _value/) {
    $self->{$item}=undef;
  }
  
  #--- initialize object with data
  foreach my $item (keys %{$args}) {
    $self->{$item}=$args->{$item};    
  }
  
}   
1;
__END__

=head1 SYNOPSIS

$xml_obj = Apiis::Report::InitXML->new(%args);

=head1 DESCRIPTION

InitXML init a file of configuration written in xml. InitXML merge definitions
from the configuration file and the default values from the dtd-scheme. 

Suppositions:

Each xml-element need a unique name over all configuration and subconfiguration
files, which will be defined in "Name". Access to each attribute take place with a method in combination with the
name of the element:

==============================================================
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
===============================================================

Independent of the xml-definition a complete set of methods will be initiate
depend on the definition in the dtd-scheme. The default settings come from the
dtd-scheme and will overwritten if a the same attribute is defined in the
xml-scheme. E.g.

dtd: 
 <!ATTLIST Text  
           Name            ID              #REQUIRED
           Data            CDATA           #REQUIRED
           Position        (static|absolute|relative)  "relative"
 >

xml:
 <PageHeader Name="PageHeader_10">
    <Text Position="relative" Name="Text_1" Data="test"/>
 </PageHeader>

code: 
  $c=$xml_obj->Text_1->Position
  $c is "relative"


Each xml-file has a hierachical structure. InitXML makes a flat structure.  
=cut


=head1 METHODS 

=head2 $apiis->Report->[fullname | basename | ext | path | report_file ] (all public, readonly)

fullname, basename, ext, path provide the fullname (basename.extension),
basename (without extension), extension, and path of the report file.

=cut
# vim:tw=80:cindent:aw:expandtab
