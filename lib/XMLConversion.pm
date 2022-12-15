=head1 NAME

XMLConversion

=head1 DESCRIPTION

Keeps the subroutines for converting the xml file of the project into old model format and vice-versa. The name convention for the xml_file and model_file is project_name.xml and project_name.model respectively.

=cut


=head2 xml2model

- converts .xml into .model format. Usage: xml2model(xml_file, model_file)

=cut

sub xml2model {
  use XML::Parser;
  use IO::File;
  my ( $xp, $currentTag, $parser, $name, %attr, $attrkey, $value, @pk, @el, $elem, $el2, $e, %el2, $indent );
  
  my $infile = shift; 
  my $model_file = shift;
  
  #initialize parser with style ParseParamEnt - to use DTD file for parsing 
  $xp = new XML::Parser( ParseParamEnt => 1);
  
  #set callback funstions for start, end tags  and cdata
  $xp->setHandlers(Start => \&start, Char  => \&cdata,  End   => \&end);
  
  #the tag that is currently being processed
  $currentTag = "";
  
  my $output = new IO::File(">$model_file"); 
  $xp->parsefile($infile);

=head2 start

- internal subroutine for xml2model - extracts elements from xml document and their attributes

=cut

  sub start()  {
    my($parser, $name, %attr) = @_;
    $currentTag = $name;
    if ($currentTag eq "general")
      {
	print $output "################# $currentTag ########### \n";
	foreach $attrkey ( keys %attr ){
	  # dbport and dbuser are not quated
	  $attr{$attrkey} =~ s/^\s*//; # remove leading whitespace
	  $attr{$attrkey} =~ s/\s*$//; # remove end whitespace
	  if ( $attr{$attrkey} !~ /^\$/ ) {
	    #       if ( ($attrkey ne "dbport") and ($attrkey ne "dbuser") ) {
	    $value = "'" . $attr{$attrkey} . "'";
	  } else {
	    $value = $attr{$attrkey};
	  } 
	  # for all names 'db' is replaced by '$db_' because of model structure		
	  $attrkey =~ s/db/\$db_/;
	  print $output $attrkey . " = " . $value , ";\n";
	}
      }
    elsif ($currentTag eq "table")
      {  
	$c = 0;
	# $c is the  counter for columns in a table
	foreach $attrkey ( keys %attr ){
	  print $output "#################### \%" . $attr{$attrkey}," ########## \n";
	  print $output "\%" . $attr{$attrkey}," = (\n"; 
	}
      }
    elsif ($currentTag eq "column")
      {
	$c++;
	$indent = 4;
	# $undent is for indents of elements, subelements and etc 
	# print $output " " x $indent ."col" . $c . " => {\n";	
	# a way to have leading zeros in name of the columns	      
	print $output " " x $indent ."col" . "0" x (3-length($c)) .  $c  . " => {\n";
	$indent += 4;
	foreach $attrkey ( keys %attr ){
	  # If ERROR, MODIFY, CHECK the value must be quated, arounded by [] and split by "," 
	  $attr{$attrkey} =~ s/^\s*//; # remove leading whitespace
	  $attr{$attrkey} =~ s/\s*$//; # remove end whitespace
	  if ( ($attrkey eq "ERROR" ) or ($attrkey eq "MODIFY" ) or ($attrkey =~ /^CHECK\d?$/) ) {
	    if ( $attr{$attrkey} ) {
	      $value = "['" . $attr{$attrkey} . "']";
	      $value =~ s/,/','/g;
	    } else {
	      #if it is empty is arounded by []			  
	      $value = "[]";
	    }
	  } else {
	    #for others fields it is only quated                 	
	    $value = "'" . $attr{$attrkey} . "'"; 
	  }		 
	  # attribute "name" is replaced by DB_COLUMN                 
	  if ( $attrkey eq "name" ) {
	    $attrkey = "DB_COLUMN";
	  }
	  print $output " " x $indent . $attrkey. " => " . $value . ",\n" unless (($attrkey =~ /^CHECK\d?$/) and ($value eq "[]"));
	};
	$indent -= 4;  
      }
    elsif ($currentTag eq "TABLE")
      {
	print $output " " x $indent . "$currentTag => {\n";
      }
    elsif ($currentTag eq "TRIGGER")
      {
	$indent += 4;
	# TABLE is on the level of column but it is not an element in xml document 
	print $output " " x $indent . "$currentTag => {\n";
	$indent += 4;
	foreach $attrkey ( keys %attr ){  
	  # triger's values arounded by []	               
	  $value = "[" . $attr{$attrkey} . "]";
	  print $output " " x $indent . $attrkey. " => " . $value . ",\n"; 
	};		  
	$indent -= 4;
      }
    elsif ($currentTag eq "CONSTRAINTS")
      {
	print $output " " x $indent . "$currentTag => {\n";
	$indent += 4;
	foreach $attrkey ( sort keys %attr ){
	  # if values are empty
	  $attr{$attrkey} =~ s/^\s*//; # remove leading whitespace
	  $attr{$attrkey} =~ s/\s*$//; # remove end whitespace   
	  if ( !$attr{$attrkey} ) {
	    $value = "[]"; 
	    print $output " " x $indent . "$attrkey  => " . $value .  ",\n"; 
	  } else {
	    #if values are available
	    if ( ( $attrkey eq "SEQUENCE") or ( $attrkey eq "INDEX") )  {
	      $value = "['" . $attr{$attrkey} . "']";
	      $value =~ s/,/','/g; 
	      print $output " " x $indent . "$attrkey  => " . $value . ",\n"; 
	    }
	    if ( $attrkey eq "PRIMARYKEY" ){
	      print $output " " x $indent . "$attrkey => [" ;
	      # values as arrays from hashes with deliminator '#'		   
	      @pk = split("#", $attr{$attrkey});
	      $indent += 4;
	      foreach $elem ( @pk ) {
		@el = split(";", $elem );
		foreach $elem2 ( @el ) {
		  # split(":", $elem2 )to take keys like CONCAT, WHERE ...  and values;
		  ($key, $valueh) = split /:/, $elem2;
		  # %$el2 is a hash filled by PK conditional VIEW containt 
		  $el2{$key} = $valueh; 
		}
		print $output " " x $indent . "{ \n";
		foreach $e ( keys %el2 ) {  
		  # keys of %$el2 and quoted values are printed 
		  if ( ( $e eq "CONCAT" ) or ( $e eq "ADD_COLS") ) {
		    $el2{$e} =~ s/,/ /g;
		    print $output " " x $indent . "$e => [ qw/$el2{$e}/ ], \n";
		  } else {
		    print $output " " x $indent . "$e =>  '$el2{$e}', \n";
		  }
		  delete $el2{$e};	
		}
		print $output " " x $indent . "},\n";
	      }
	      print $output " " x $indent . "],\n"; 
	      $indent -= 4;
	    }
	  } 
	};
      }
  }
  
=head2 cdata

- internal subroutine for xml2model - it is called when CDATA is found. Not in use now

=cut
  
  sub cdata()    {
    my ($parser, $data) = @_;
  }
  
=head2 cdata

- internal subroutine for xml2model - it is called when the end tag is found

=cut

  sub end()   {
    my ($parser, $name) = @_;
    
    $currentTag = ($name);
    
    if ($currentTag eq "general")
    {
      print $output "##################### end $currentTag ######### \n";
    }
    elsif ($currentTag eq "table")
      {
      print $output ");\n";
    }
  elsif ( ($currentTag eq "column") or ($currentTag eq "TRIGGER") or ($currentTag eq "TABLE") or ($currentTag eq "CONSTRAINTS"))
    {
	  print $output "},\n";
	}
	     
    # clear value of current tag
    $currentTag = "";
  }
  
  $output->close();
  print "Successfully converted xml into model format.\n";
}



=head2 model2xml

- converts .model into .xml format. Usage: model2xml(model_file_path, xml_file_path, model_name )

=cut

sub model2xml {
  use IO::File;
  use myWriter;
  my ( $model_file, $xml_file, $model_short_name, $otput, $db_host, $db_name, $db_driver, $db_user, $db_password, $db_port);
  $model_file=shift;
  $xml_file=shift;
  $model_short_name=shift;
  $output = new IO::File(">$xml_file");
my $writer = new XML::Writer(OUTPUT => $output, NEWLINES => 1, DATA_MODE => 1, DATA_INDENT => 2);

  #initialize xml file - xml declaration, doctype and root element
  $writer->xmlDecl("UTF-8","1.0");
  $writer->doctype("model","","model.dtd");
  $writer->comment("This is a model file reversed to xml");
  $writer->startTag("model");
  $writer->setDataIndent(3);
  
  #take the tables hash form the model
  open(MODEL, "<$model_file") or die __("Cannot open file [_1]",$model_file);
  while (<MODEL>) { push @tables, $1 if /^\s*%(\w+)/ }
  close MODEL;
  require $model_short_name;

  $writer->startTag("general", "dbdriver" => $apiis->Model->db_driver, 
		    "dbname" => $apiis->Model->db_name,
		    "dbhost" => $apiis->Model->db_host,
		    "dbport" => $apiis->Model->db_port,
		    "dbuser" => $apiis->Model->db_user,
		    "dbpassword" => $apiis->Model->db_password);
  $writer->endTag();
  
  foreach $table (@tables) {
    $writer->startTag("table", name => $table); 	
    #reverse sort
    foreach $col ( sort keys %{$table}) {
      if ($col ne 'TABLE') {
	my %arg_hash=();
	foreach $key (sort keys %{$$table{$col}}) {
	  if ($key eq "DB_COLUMN") {
	    $arg_hash{name}= $$table{$col}{$key};
	  } elsif (($key eq "MODIFY") or ($key eq "ERROR") or ($key=~/^CHECK\d?$/) ) {
	    $arg_hash{$key}= join(",",@{$$table{$col}{$key}});
	  } else {
	    $arg_hash{$key}= $$table{$col}{$key};
	  }
	}
	
	$writer->startTag("column", %arg_hash);
	$writer->endTag("column");
      } 
    }
    # TABLE must be the end subelement of a table
    $col = "TABLE";  
    $writer->startTag("TABLE");
    $writer->startTag("TRIGGER", PREINSERT => join(",",@{$$table{$col}{TRIGGER}{PREINSERT}}),
		      POSTINSERT => join(",",@{$$table{$col}{TRIGGER}{POSTINSERT}}),
		      PREUPDATE => join(",",@{$$table{$col}{TRIGGER}{PREUPDATE}}),
		      POSTUPDATE => join(",",@{$$table{$col}{TRIGGER}{POSTUPDATE}}),
		      PREDELETE => join(",",@{$$table{$col}{TRIGGER}{PREDELETE}}),
		      POSTDELETE => join(",",@{$$table{$col}{TRIGGER}{POSTDELETE}}));
    $writer->endTag("TRIGGER");
    my @p = @{$$table{$col}{CONSTRAINTS}{PRIMARYKEY}};	
    # $pk - an element of PRIMARYKEY array @p
    # %{$pk} - a hash of defined Views, $s - key of $pk like CONCAT, PK_COL ...
    # $$pk{$s} - value of the key $s (CONCAT => value)
    # @{$$pk{$s}} - array of values of key $s if $s is not a scalar
    # $expr - concat of elements:values sequence for a PK key $s
    # @expr - an array  
    $n = 0;
    foreach $pk ( @p ) {
      for $s ( keys % { $pk })  {
	if ($#{$$pk{$s}} gt 0 ) {
	  $con = join(",",@{$$pk{$s}});
	  $subcon = join(":",$s,$con); 
	} else {
	  if ( ref($$pk{$s}) eq "ARRAY") {
	    $subcon = $s;
	    print "#### $s\n";
	  } else {
	    $subcon = join(":",$s,$$pk{$s});
	  }
	}
	#$con - values of the key separated via ','
	# $subcon - key with value and deliminator ':'; 
	$expr = $expr.$subcon.";";
      }
      # todo : eliminate last "," and ";"?
      $expr[$n] = $expr;
      $expr = "";
      # $n - number of subelement concatenated values,  $expr[$n] contains conc.expresion
      $n++;
    }
    $n = $n-1 if ( $n != 0 );
    # all values are joined with deliminator '#';
    if ( $expr[$n]){
      $value = join("#",@expr);
    } else {
      $value = "";
    }
    $writer->startTag("CONSTRAINTS", PRIMARYKEY => $value,
		      SEQUENCE => join(",",@{$$table{$col}{CONSTRAINTS}{SEQUENCE}}),
		      INDEX => join(",",@{$$table{$col}{CONSTRAINTS}{INDEX}}));
    $writer->endTag("CONSTRAINTS");
    $writer->endTag("TABLE");	    
    #cancel the values in @expr   
    for $el ( 0..$n ) {
      $expr[$el] = "";
    }
    
    
    
    $writer->endTag();
  }
  
  #	 $writer->setOutput($output);
  $writer->endTag("model");
  $writer->end();
  $output->close();
  
  print "Successfully converted model to xml format.\n";
}

1;


=head1 AUTHORS

Zhivko Duchev <duchev@tzv.fal.de>

Lina Jordanova <lina@tzv.fal.de>

=cut

__END__
