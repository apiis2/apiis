#############################################################################
# $Id: Init.pm,v 1.10 2004/11/26 13:56:35 ulm Exp $
##############################################################################
# This Init package provides common methods for either Tk or Web:
#
# method    invocation              description
# fullname  $apiis->Report->fullname   gives back the full name of the reports file
# basename  $apiis->Report->basename   gives back the base name of the reports file
# path      $apiis->Report->path       gives back the path of the reports file
# ext       $apiis->Report->ext        gives back the extension of the reports file
# uncomplete list, have a look into test.Report
##############################################################################

package Apiis::Report::Init;
$VERSION = '$Revision $';

use strict;
use Carp;
use warnings;
use Apiis::Errors;
use Apiis::CheckFile;
use Data::Dumper;

#@Apiis::Report::Init::ISA = qw( Apiis::Init );
#our $apiis;

sub new {
   my ( $invocant, %args ) = @_;
 #  croak _("Missing initialisation in main file ([_1]).", __PACKAGE__ ) . "\n"
 #    unless defined $apiis;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init(%args);
   return $self;
}

##############################################################################
sub _init {
   my ( $self, %args ) = @_;
   my $pack = __PACKAGE__;
   return if $self->{"_init"}{$pack}++;    # Conway p. 243

   $self->{"_MaxColumn"} = 1;
   $self->{"_Errors"} = [];
   $self->{"_ContentFields"} = ();
   $self->{"General"} = [];
   $self->{"ReportHeader"} = [];
   $self->{"ReportFooter"} = [];
   $self->{"PageHeader"} = [];
   $self->{"PageFooter"} = [];
   $self->{"GroupHeader"} = [];
   $self->{"GroupFooter"} = [];
   $self->{"Detail"} = [];

   $self->{"ReportHeaderObjects"} = [];
   $self->{"ReportFooterObjects"} = [];
   $self->{"PageHeaderObjects"} = [];
   $self->{"PageFooterObjects"} = [];
   $self->{"GroupHeaderObjects"} = [];
   $self->{"GroupFooterObjects"} = [];
   $self->{"DetailObjects"} = [];

   $self->{"_Report"}=$args{'report'};
   $self->{"_Status"} = undef;
   $self->{"_Errors"}=[];

   if ( exists $args{'report'} ) {
      no strict 'refs';
      my $a = Apiis::CheckFile->new( file => $args{'report'} );
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

      unless ( $self->{"_Status"} ) {
         my %hs_name;
         $self->{'_XMLElements'}=GetElementsXML($args{'report'});
         my @ar_xml_elements=@{$self->{'_XMLElements'}};
	 #-- save all objectname which have a content field
	 map { if (exists $_->[1]{'Content'}) { push(@{$self->{_ContentFields}}, $_->[1]{'Name'}) } } @ar_xml_elements;
	 use strict;

	 #--- Init each Element als Object and save it in self-hash
	 #--- and create a method
	 my $element_obj;my @a; my $vclass; my $vgroup;
         foreach my $s (@ar_xml_elements) {
	    next if ($s->[0] eq 'Report');

	    $vclass=$s->[0] if ($s->[0] eq 'ReportHeader');
            $vclass=$s->[0] if ($s->[0] eq 'ReportFooter');
            $vclass=$s->[0] if ($s->[0] eq 'PageHeader');
            $vclass=$s->[0] if ($s->[0] eq 'PageFooter');
            $vclass=$s->[0] if ($s->[0] eq 'GroupHeader');
            $vclass=$s->[0] if ($s->[0] eq 'GroupFooter');
            $vgroup=$s->[1]{'Name'} if ($s->[0] eq 'GroupHeader');
            $vgroup=$s->[1]{'Name'} if ($s->[0] eq 'GroupFooter');
            $vclass=$s->[0] if ($s->[0] eq 'Detail');

           if ($s->[0]=~/(General|ReportHeader|ReportFooter|PageHeader|PageFooter|GroupHeader|GroupFooter|Detail)/ ) {
	      push (@{$self->{$s->[0]}},$s->[1]{'Name'});
	    }

	    if (($s->[0] eq 'Text') or ($s->[0] eq 'Data') or ($s->[0] eq 'Images') or
	        ($s->[0] eq 'Lines') or ($s->[0] eq 'PageBreak' ) or ($s->[0] eq 'SubReport')) {
              push (@{$self->{'ReportHeaderObjects'}},$s->[1]{'Name'}) if ($vclass eq 'ReportHeader');
              push (@{$self->{'ReportFooterObjects'}},$s->[1]{'Name'}) if ($vclass eq 'ReportFooter');
              push (@{$self->{'PageHeaderObjects'}},  $s->[1]{'Name'}) if ($vclass eq 'PageHeader');
              push (@{$self->{'PageFooterObjects'}},  $s->[1]{'Name'}) if ($vclass eq 'PageFooter');
              push (@{$self->$vgroup->{'GroupHeaderObjects'}}, $s->[1]{'Name'}) if ($vclass eq 'GroupHeader');
              push (@{$self->$vgroup->{'GroupFooterObjects'}}, $s->[1]{'Name'}) if ($vclass eq 'GroupFooter');
              push (@{$self->{'DetailObjects'}},      $s->[1]{'Name'}) if ($vclass eq 'Detail');
            }

            if ((exists $s->[1]{'Column'}) and ($s->[1]{'Column'}!~/-/) and
	      ($s->[1]{'Column'} > $self->{'_MaxColumn'})) {
              $self->{'_MaxColumn'}=$s->[1]{'Column'}
	    }
            no strict 'subs';
            my $b="Apiis::Report::".$s->[0];
	    $self->{$s->[1]{'Name'}}=$b->new( $s->[0], $s->[1]);
	    no strict 'refs';
	    *{$s->[1]{'Name'}} = sub {
                                  return $self->{$s->[1]{'Name'}};
	                       };
			       
            #--- set parent group 
	    $self->{$s->[1]{'Name'}}->{'CallFrom'}=$vclass;
            
	    #--- save position of fields and datas in select
            if (exists $s->[1]{'DataSource'}) {
	       if ($s->[1]{'DataSource'}=~/select (.*)from/i) {
	         my $st=$1; my $i=0; #offen: genaues parsen jetzt is 'as' zwingend
	         while ($st=~/.*?as\s+(.*?)[,\s]/mg) {
		   $hs_name{$1}=$i++;
		 }  
	         #my @a=split(',',$1);
	         #my $i=0;
	         ##-- take alias or correct name without blank from select and save position in %hs_name
	         #map{if ($_=~/.*\s+as\s+.*\,/) {($_)=($_=~/as (.*)/)} ;$_=~s/\s//g;$hs_name{$_}=$i;$i++} @a;
	       } else {
	       }
  	    }
	    if ((exists $s->[1]{'Content'}) and ($s->[1]{'Content'}=~/\[(.*)\]/)) {
              $self->{$s->[1]{'Name'}}->{'PositionSQL'}=$hs_name{$1} 	if (exists $hs_name{$1});
	    }
         }

#	 no strict 'refs';
#         for my $item (qw/ ReportHeaderObjects ReportFooterObjects PageHeaderObjects PageFooterObjects
#	                   GroupHeaderObjects GroupFooterObjects DetailObjects ReportHeader
#			   ReportFooter PageHeader PageFooter GroupHeader GroupFooter Detail General/) {
#           *{$item} = sub {
#              my ( $self ) = @_;
#              return undef unless exists $self->{$item };
#              return $self->{ $item };
#            };
#         }

      }

   } else {
      push @{ $self->{"_Errors"} },
        Apiis::Errors->new(
         type      => 'CODE',
         severity  => 'ERR',
         from      => 'Apiis::Report::Init',
         msg_short => __("No key [_1] passed to [_2]", 'report', 'Apiis::Report::Init'),
      );
   }
   if ( $self->{"_Status"} ) {
#      $apiis->status(1);
#      $apiis->errors( $self->{"_errors"} );
   }

#offen: herausgenommen, da sonst Funktionen redefined wurden. 
# foreach my $thiskey (qw/ Query Apiis Report Status Errors XMLElements/) {
#     no strict "refs";
#     *{$thiskey} = sub { return $_[0]->{"_$thiskey"} };
#  }

#  #-- dummy functions
#  foreach my $thiskey (qw/ PrintObjects PrintCell/) {
#     no strict "refs";
#     *{$thiskey} = sub { return undef };
#  }

}

###############################################################################
sub GetAllElementsXML {
###############################################################################
  #my $self=shift;
  use XML::Parser;
  my $report=shift;
  my %hs_name; 
  our $ar_elements=[]; #offen: Kunstgriff, by my kommt "not stay shared"
  no strict;
  my $xp = new XML::Parser( ParseParamEnt => 1);
  $xp->setHandlers(Start => \&start);
  $xp->parsefile($report);
  sub start {
    my($parser, $name, %attr) = @_;
    push(@{$ar_elements},[$name, \%attr]);
    if ((exists $attr{'ReportSource'}) and ($attr{'ReportSource'}=~/(.*\.rpt)$/)) {
      push(@{$ar_elements},GetAllElementsXML($1)); #offen: Verweis
      									#test lesen der rpt
    }
  }
  return $ar_elements;
}

###############################################################################
sub GetElementsXML {
###############################################################################
  #my $self=shift;
  use XML::Parser;
  my $report=shift;
  my %hs_name;
  our $ar_elements=[];  #offen: Kunstgriff, by my kommt "not stay shared"
  no strict;
  my $xp = new XML::Parser( ParseParamEnt => 1);
  $xp->setHandlers(Start => \&start);
  $xp->parsefile($report);
  sub start {
    my($parser, $name, %attr) = @_;
    push(@{$ar_elements},[$name, \%attr]);
  }
  return $ar_elements;
}

###############################################################################
sub GetAllParameter {
###############################################################################
  my $self=shift;
  my $xml=shift;
  my $parameter={};
  foreach my $element (@{$xml}) {
    if ($element->[1]{'DataSource'}) {
      $parameter->{$1}=[$1,$2] while $element->[1]{'DataSource'} =~ m{ (\{([_a-zA-Z]?[_a-zA-Z0-9\s\.\,\:]*)\}) }xg;
    }
  }
  return $parameter;
}

###############################################################################
sub GetAllSubReports {
###############################################################################
  my $self=shift;
  my $xml=shift;
  my $parameter={};
  foreach my $element (@{$xml}) {
    if ($element->[1]{'ReportSource'}) {
      $parameter->{$element->[1]{'ReportSource'}}='';
    }
  }
  return $parameter;
}


##############################################################################
# access methods for report file attributes:
##############################################################################
# return the according hash entry for the public methods:

=head2 $apiis->Report->[fullname | basename | ext | path | report_file ] (all public, readonly)

fullname, basename, ext, path provide the fullname (basename.extension),
basename (without extension), extension, and path of the report file.

=cut

foreach my $thiskey (qw/ fullname basename ext path report_file MaxColumn ContentFields Errors
                       /) {
   no strict "refs";
   *$thiskey = sub { return $_[0]->{"_$thiskey"} };
}

	 no strict 'refs';
         for my $item (qw/ ReportHeaderObjects ReportFooterObjects PageHeaderObjects PageFooterObjects
	                   GroupHeaderObjects GroupFooterObjects DetailObjects ReportHeader
			   ReportFooter PageHeader PageFooter GroupHeader GroupFooter Detail General/) {
           *{$item} = sub {
              my ( $self ) = @_;
              return undef unless exists $self->{$item };
              return $self->{ $item };
            };
         }
 foreach my $thiskey (qw/ Query Apiis Report Status Errors XMLElements/) {
     no strict "refs";
     *{$thiskey} = sub { return $_[0]->{"_$thiskey"} };
  }

##############################################################################
# access methods for report file attributes:
##############################################################################
foreach my $item (qw/ SetColumnBusy
                       /) {
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

#-------------------------------------------------------------------------------
###############################################################################
package Apiis::Report::ElementObj;
$Apiis::Report::ElementObj::VERSION = '$Revision: 1.10 $';

=head1 NAME

Apiis::Report::ElementObj -- internal package to provide an element object with
methods to access a single elements and its properties

=head1 SYNOPSIS

  $element_obj = Apiis::Report::ElementObj->new( $elementname, \%{$element});

=head1 DESCRIPTION

In XML different elements can be defined by user. Valid elements in Report are
General, ReportHeader, ReportFooter, PageHeader, PageFooter, GroupHeader, 
GroupFooter, Details, Data, Text, Images, Lines PageBreak. Each of this elements
has a unique name and properties. This package creates an object for one 
element with methods to access properties. Syntax to invoke this
package, e.g.: $elementref = $apiis->Report->element('Data_0');

=head1 METHODS

=cut

##############################################################################
use Carp;
no strict 'refs';
use Data::Dumper;
use Tie::IxHash;
###############################################################################

=head2 new (mostly internal)

To create the element object, new() needs as input the element name and a 
hashreferenz with all properties

   $element_obj = Apiis::Report::ElementObj->new( $elementname, \%{$element});

It is made shure, that the internal structure can only be accessed from
within Apiis::Report::ElementObj. Only the public methods provide access to it
from the outside world.

=cut
  
sub new {
   my ( $invocant, $elementname, $elementhash_ref ) = @_;
#   croak _("Missing initialisation in main file ([_1]).", __PACKAGE__ ) . "\n"
#   unless defined $apiis;
   my $class = ref($invocant) || $invocant;
   my $self = bless {}, $class;
   $self->_init($elementname, $elementhash_ref);
   return $self;
}


#############################################################################
# access methods for report file attributes:
##############################################################################
# return the according hash entry for the public methods:

=head2 $apiis->Report->[ ElementType | DataSource | PageHeader | PageFooter |
 Name | Height | Width | BackgroundColor | ForegroundColor | KeepTogether | Group | PositionSQL
 GroupOn | Sort | Value | Content | Visible | Left | Top | Column | Row | Color | GroupFooterName
 FontFamily | FontVariant | FontSize | FontStyle | FontWeight | TextDecoration | TextAlign | Format |
 DecimalPlaces | RunningSums | LineType | LineWidth | ImageSource | WordSpacing | VerticalAlign | Middle |
 TextTransform | Border | ReportSource | CallFrom] (all public, read/write)


=cut


sub _init {
  my ( $self, $elementname, $args ) = @_;
  my $pack = __PACKAGE__;
  return if $self->{"_init"}{$pack}++;    # Conway p. 243
  
  my %args=%$args;
  $args{'ElementType'}=$elementname;
  #--- initialize object with data
  for my $item (qw/ ElementType DataSource PageHeader PageFooter
                  Name Height Width ForegroundColor KeepTogether Group GroupOn Sort
                  Value Content Visible Left Top Column Row Color CharSet 
                  
                  FontFamily FontSize FontStyle FontWeight FontVariant Font
                  
                  BackgroundColor Color BackgroundImage BackgroundRepeat
                  BackgroundAttachment BackgroundPosition Background
                  
                  WordSpacing LetterSpacing TextDecoration VerticalAlign
                  TextTransform TextAlign TextIndent LineHeight 
                  
                  MarginTop MarginRight MarginBottom MarginLeft Margin
                  
                  PaddingTop PaddingRight PaddingBottom PaddingLeft Padding
                  
                  BorderTopWidth BorderRightWidth BorderBottomWidth
                  BorderLeftWidth BorderWidth
                  
                  BorderStyle BorderColor 
                  BorderTop BorderRight BorderBottom BorderLeft Border
                 
                  BlockWidth BlockHeight BlockFloat Clear Display WhiteSpace 

                  ListStyleType ListStyleImage ListStylePosition ListStyle 
                  
                  Format DecimalPlaces RunningSums LineType ImageSource 
		  QuestionChangeValue GroupFooterName ReportSource CallFrom
		  PositionSQL LineWidth 
                /) {
    if ($args{$item}) {		
      $self->{$item}=$args{$item};
    } else {
      $self->{$item}='';
    }
  }
  for my $item (qw/ _n _sum _sum2 _min _max _last _first/) {
    $self->{$item}=0;
  }
  for my $item (qw/ _QuestionChangeValue _value/) {
    $self->{$item}=undef;
  }


}   

### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (qw/ ElementType DataSource PageHeader PageFooter
                  Name Height Width ForegroundColor KeepTogether Group GroupOn Sort
                  Value Content Visible Left Top Column Row Color CharSet
                  
                  FontFamily FontSize FontStyle FontWeight FontVariant Font
                  
                  BackgroundColor Color BackgroundImage BackgroundRepeat
                  BackgroundAttachment BackgroundPosition Background
                  
                  WordSpacing LetterSpacing TextDecoration VerticalAlign
                  TextTransform TextAlign TextIndent LineHeight 
                  
                  MarginTop MarginRight MarginBottom MarginLeft Margin
                  
                  PaddingTop PaddingRight PaddingBottom PaddingLeft Padding
                  
                  BorderTopWidth BorderRightWidth BorderBottomWidth
                  BorderLeftWidth BorderWidth
                  
                  BorderStyle BorderColor 
                  BorderTop BorderRight BorderBottom BorderLeft Border
                 
                  BlockWidth BlockHeight BlockFloat Clear Display WhiteSpace 

                  ListStyleType ListStyleImage ListStylePosition ListStyle 
                  
                  Format DecimalPlaces RunningSums LineType ImageSource 
		  QuestionChangeValue GroupFooterName ReportSource CallFrom
		  PositionSQL LineWidth 
               /) {
   *{$item} = sub {
       my ( $self, $newval ) = @_;
       return '';
   };
}


###############################################################################
package Apiis::Report::ReportHeader;
@Apiis::Report::ReportHeader::ISA = qw( Apiis::Report::ElementObj );
my @a=(qw /ElementType  Name  Height  BackgroundColor/);

### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@a) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@a};

###############################################################################
package Apiis::Report::ReportFooter;
@Apiis::Report::ReportFooter::ISA = qw( Apiis::Report::ElementObj );

my @e=(qw /ElementType  Name  Height  BackgroundColor/);
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@e) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@e};

###############################################################################
package Apiis::Report::PageHeader;
@Apiis::Report::PageHeader::ISA = qw( Apiis::Report::ElementObj );

my @f=(qw /ElementType  Name  Height  BackgroundColor/);
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@f) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@f};

###############################################################################
package Apiis::Report::PageFooter;
@Apiis::Report::Page::ISA = qw( Apiis::Report::ElementObj );

my @g=(qw /ElementType  Name  Height  BackgroundColor/);
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@g) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@g};

###############################################################################
package Apiis::Report::Detail;
@Apiis::Report::Detail::ISA = qw( Apiis::Report::ElementObj );

my @h=(qw /ElementType  Name  Height  BackgroundColor/);
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@h) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@h};


###############################################################################
package Apiis::Report::GroupHeader;
@Apiis::Report::GroupHeader::ISA = qw( Apiis::Report::ElementObj );

my @i=(qw/ ElementType GroupHeaderObjects Value Content Name Height BackgroundColor KeepTogether Group GroupOn Sort GroupFooterName/);
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@i) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

foreach my $thiskey (qw/ QuestionChangeValue/) {
   no strict "refs";
   *$thiskey = sub { return $_[0]->{"_$thiskey"} };
}
sub Methods { my $self = shift; return \@i};

###############################################################################
package Apiis::Report::GroupFooter;
@Apiis::Report::GroupFooter::ISA = qw( Apiis::Report::ElementObj );
my @j=(qw/ ElementType GroupFooterObjects Value Content Name Height BackgroundColor/);

### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@j) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;

       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@j};


###############################################################################
package Apiis::Report::Text;
@Apiis::Report::Text::ISA = qw( Apiis::Report::ElementObj );

my @k=(qw/ ElementType Name Value Content 
           Position Left Top Height Width Clip Column Row Visibility 
           BackgroundColor Color BackgroundImage BackgroundRepeat
           BackgroundAttachment BackgroundPosition Background
           FontFamily FontVariant FontSize FontStyle FontWeight Font 
           TextDecoration TextAlign WordSpacing LetterSpacing VerticalAlign TextTransform 
           TextIndent LineHeight 
           MarginTop MarginRight MarginLeft MarginBottom Margin
           PaddingTop PaddingRight PaddingLeft PaddingBottom Padding 
           BorderTopWidth BorderRightWidth BorderLeftWidth BorderBottomWidth BorderWidth
           BorderColor BorderStyle
           BorderTop BorderRight BorderLeft BorderBottom Border 
           BlockFloat BlockWidth BlockHeight Clear Display WhiteSpace 
           ListStyleType ListStyleImage ListStylePosition ListStyle
           
           CallFrom/);

### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@k) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@k};

###############################################################################
package Apiis::Report::Data;
@Apiis::Report::Data::ISA = qw( Apiis::Report::ElementObj );

my @l=(qw/ ElementType Name Value Content 
           Position Left Top Height Width Clip Column Row Visibility 
           BackgroundColor Color BackgroundImage BackgroundRepeat
           BackgroundAttachment BackgroundPosition Background
           FontFamily FontVariant FontSize FontStyle FontWeight Font 
           TextDecoration TextAlign WordSpacing LetterSpacing VerticalAlign TextTransform 
           TextIndent LineHeight 
           MarginTop MarginRight MarginLeft MarginBottom Margin
           PaddingTop PaddingRight PaddingLeft PaddingBottom Padding 
           BorderTopWidth BorderRightWidth BorderLeftWidth BorderBottomWidth BorderWidth
           BorderColor BorderStyle
           BorderTop BorderRight BorderLeft BorderBottom Border 
           BlockFloat BlockWidth BlockHeight Clear Display WhiteSpace 
           ListStyleType ListStyleImage ListStylePosition ListStyle
           Format DecimalPlaces RunningSums TextTransform PositionSQL
	   CallFrom
          /);
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@l) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;

       if ( $#_ == 1 ) {
         $newval='' if (! $newval);
         if ($item eq 'Content') {
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
	  if ($item eq 'Content') {
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
   };
}
foreach my $thiskey (qw/ QuestionChangeValue/) {
   no strict "refs";
   *$thiskey = sub { return $_[0]->{"_$thiskey"} };
}

sub Methods { my $self = shift; return \@l};

###############################################################################
package Apiis::Report::Lines;
@Apiis::Report::Lines::ISA = qw( Apiis::Report::ElementObj );

my $a=[qw/ ElementType Name Left Top Row ForegroundColor LineType Column LineWidth CallFrom
           MarginTop MarginRight MarginLeft MarginBottom Margin
           PaddingTop PaddingRight PaddingLeft PaddingBottom Padding
           BorderTopWidth BorderRightWidth BorderLeftWidth
           BorderBottomWidth BorderWidth
           BorderTop BorderRight BorderLeft
           BorderBottom Border
                /];
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@{$a}) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return $a};

###############################################################################
package Apiis::Report::PageBreak;
@Apiis::Report::PageBreak::ISA = qw( Apiis::Report::ElementObj );

my $b=[qw/ ElementType Name Left Top CallFrom/];
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@{$b}) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return $b};

###############################################################################
package Apiis::Report::SubReport;
@Apiis::Report::SubReport::ISA = qw( Apiis::Report::ElementObj );

### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item ( qw/ ElementType Name ReportSource Visible Height Width Column Row CallFrom/ ) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return [qw/ ElementType Name ReportSource Visible Height Width Column Row CallFrom/]};

###############################################################################
package Apiis::Report::Images;
@Apiis::Report::Images::ISA = qw( Apiis::Report::ElementObj );

my @c=(qw/ ElementType Name ImageSource Visible Height Width Column Row CallFrom
           MarginTop MarginRight MarginLeft MarginBottom Margin
           PaddingTop PaddingRight PaddingLeft PaddingBottom Padding
           BorderTopWidth BorderRightWidth BorderLeftWidth
           BorderBottomWidth BorderWidth
           BorderTop BorderRight BorderLeft
           BorderBottom Border
                /);
### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@c) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return \@c};

###############################################################################
package Apiis::Report::General;
@Apiis::Report::General::ISA = qw( Apiis::Report::ElementObj );

my @d=(qw/ ElementType Name DataSource PageHeader PageFooter Width Border CallFrom 
           CharSet/);

### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@d) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return [@d]};

###############################################################################
package Apiis::Report::Hidden;
@Apiis::Report::Hidden::ISA = qw( Apiis::Report::ElementObj );

my @d=(qw/ ElementType Name DataSource PageHeader PageFooter Width Border CallFrom 
           CharSet/);

### create the access methods (subs) for each key of the sections:
# first create the read/write methods:
for my $item (@d) {

   *{$item} = sub {
       my ( $self, $newval ) = @_;
       
       if ( $#_ == 1 ) {
          $self->{$item} = $newval;
       } else {
          return undef unless exists $self->{$item };
          return $self->{ $item };
       }
   };
}

sub Methods { my $self = shift; return [@d]};
1;

# vim:tw=80:cindent:aw:expandtab
