##############################################################################
# $Id: form_ulib.pm,v 1.77 2005/07/04 13:10:10 haboe Exp $
# user defined functions
##############################################################################

#########  include local form lib  ###########################################
if($APIIS_LOCAL and -r "$APIIS_LOCAL/lib/form_lib.pm") {
   require "$APIIS_LOCAL/lib/form_lib.pm";
}

 
##############################################################################
# syntax in ini-style form file:
#    ACTION => ['F selfromDB table col1 col2 section']
# -> select col1 from table where col2 = hash{section}{DATA} 
sub selFromDB {

   my @arg = @_;
 
   
}


##############################################################################
# syntax in form file:
#    ACTION=F fromDB table col1 col2 section [optional WHERE-clauses]
# -> select col1 from table where col2 = hash{section}{DATA} 
#   or
#    ACTION=F fromDB table col1
# -> select col1 from table 
#   or
#    ACTION=F fromDB table col1 col2 section codes.class=classname
sub fromDB {

   my $form = pop(@_);   # last element
   my @arg = @_;
   my $table   = $arg[3];
   my $col1    = $arg[4];
   my $col2    = $arg[5];
   my $section = $arg[6];
   my $optl    = $arg[7];

   my $sqltext;

   print "# debug fromDB:::arg:@arg\n" if($opt_d);

   return if( ! $$form{$section}{DATA});


   if($section and $col2) {
      $sqltext="SELECT $col1 FROM $table WHERE $col2='$$form{$section}{DATA}'";
      for(my $i=7;$i<$#arg;$i++) {
	 $sqltext.=" AND $arg[$i]";
      }
   } else {
      $sqltext = "SELECT $col1 FROM $table";
   }

   print "# debug SQL:$sqltext\n" if($opt_d);

####   ConnectDB() unless defined $dbh;
####   my $sth = ExecuteSQL($sqltext);
####   my @data_array = $sth->fetchrow_array;
####   $sth->finish;

   my $sql_ref = $apiis->DataBase->user_sql($sqltext);
   $apiis->check_status;
####   my @data_array = $sth->fetchrow_array;
   my $data_array = $sql_ref->handle->fetch;  # reference!

   if(@{$data_array}[0]) {
      # positive!
      if($$form{$arg[0]}{TYPE} =~ /^[C]/) { # date format conversion 
	 my ($y,$m,$d) = Decode_Date_NativeRDBMS(@{$data_array}[0]);
         if($d and $m and $y) {
            $$form{$arg[0]}{DATA} = "$d-$m-$y" if($date_format eq 'EU');
            $$form{$arg[0]}{DATA} = "$m-$d-$y" if($date_format eq 'US');
	 }

      } else {
         $$form{$arg[0]}{DATA} = @{$data_array}[0]; 
      }
      exeUserCommand("+fromDB",$arg[0],$form);# positive user defined command
	 print "# debug fromDB:returnvalue:@{$data_array}[0]\n" if($opt_d);
      return @{$data_array}[0] 
   }

   if($$form{GENERAL}{fromDB} or $$form{$arg[0]}{fromDB}) {
      # negative!
      exeUserCommand(fromDB,$arg[0],$form);  # execute user defined command
      return;
   } else {
      # if no user command defined, return value of the DATA-field
      return $$form{$arg[0]}{DATA} 
   }   
   
} # fromDB


##############################################################################
#  get the database id or return a new one
# getNextDBID ( form, label1, label2 )
# example: ['f getNextDBID MyForm external-id unit']
# f getNextDBID MyForm id_col form_var1 db_dest_col1 form_var2 db_dest_col2 ...
sub getNextDBID {
   
   my $dbid = &getDB_ID(@_);
   
   return &GetNextDBID if($dbid eq 'cannot find'); # increment database table 'db_id'
   return $dbid;

}


##############################################################################
#  get the database id or return a new one
# getNextDBID ( form, label1, label2 )
# example:
# f Next_seq_DBID MyForm id_col form_var1 db_dest_col1 form_var2 db_dest_col2 ...
sub Next_seq_DBID {
   
   my $dbid = &getDB_ID(@_);

   print "# debug Next_seq_DBID: $dbid\n" if($opt_d); 
   
   return &getNextDB_ID($_[3]) if($dbid eq 'cannot find'); # sequence seq_db_id
   return $dbid;

}

##############################################################################
#  get the database id 
#      if id not exists,  call a user defined error handling
# getDBID ( form, label1, label2 )
# example:
# F getDBID MyForm id_col form_var1 db_dest_col1 form_var2 db_dest_col2 ...
sub getDBID {
   
   my @args = @_;
   my $form = $args[$#args];

   print "# debug sub(getDBID):@args\n" if($opt_d); 

   my $dbid = &getDB_ID(@_);
   if($dbid eq 'cannot find') {
      # negative!
      exeUserCommand(getDBID,$args[0],$form);   # execute user defined command
      $dbid = &getDB_ID(@_);
   } elsif($dbid ne '') {
      # positive!
      $$form{$args[0]}{DATA} = $dbid; # with this, you can use the value
	                              # for the user-command
      exeUserCommand("+getDBID",$args[0],$form); # execute user defined command
   }

   return  if($dbid eq 'cannot find');
   return $dbid;

}

##############################################################################
#  exists the database id ? return id : return 
# example:
# F existsDBID MyForm id_col form_var1 db_dest_col1 form_var2 db_dest_col2 ...
sub existDBID {
   
   my @args = @_;
   my $form = $args[$#args];

   my $dbid = &getDB_ID(@args);

   return $$form{$_[0]}{DATA} if(! $dbid);
   return  if($dbid eq 'cannot find');
   return $dbid;
}

##############################################################################
#  get the database id  (used by 'getNextDBID' and 'getDBID')
#    only for ini-style form file now!
sub getDB_ID {

   my $form = pop(@_);
   my ($tab, $id, $sqltext);

   $tab = $_[3];
   $id  = $_[4];
   if($_[5] and $_[6]) {
      $sqltext = "SELECT $id FROM $tab WHERE ";
   } else {
      $sqltext = "SELECT $id FROM $tab";
   }



   my $zpar = scalar(@_);

   for(my $z = 5; $z < $zpar-2; $z+=2) {
      my $source = $$form{$_[$z]}{DATA};  # field variable
      return '' unless ($source); # not meaningfully if field is blank
      $source = $dbh->quote($source) if(! ($source eq 'NULL'
                                            or $source eq 'NOTNULL'));
      my $dest   = $_[$z+1];              # col of the primary key
      $sqltext .= "$dest = $source ";
      $sqltext .= "AND " if($z < ($zpar-4));
   }

   print "# debug getDBID SQL:$sqltext\n" if($opt_d);

####   ConnectDB() unless defined $dbh;
####   my $sth = ExecuteSQL( $sqltext );
####   my $ary_ref = $sth->fetchall_arrayref;
####   $sth->finish;

   my $sql_ref = $apiis->DataBase->user_sql($sqltext);
   $apiis->check_status;
   my $ary_ref = $sql_ref->handle->fetch;  # reference!

   if(!defined $$ary_ref[0][0] or $$ary_ref[0][0] eq '') { 
      # new db_id for a new object
      # we can do it here --
      # or we define it in the MODIFY-section in the model file
      # return '';
      return "cannot find"; 

   } elsif(scalar @{$ary_ref} == 1) {    # object exist -> return db_id
      return $$ary_ref[0][0]; 

   } elsif($$ary_ref[0][0] > 1) {        # more then one record -> FATAL ERROR
      $$form{GENERAL}{TOPLEVEL}->Dialog(-title=>"Fatal Error",
                          -bitmap=>"error",
                          -text=>"Fatal Error\n\n".
			         "'db_id' must contain\n". 
			         " *one* and *only one*\n".
				 "        record!")
   			  ->Show;
      return '';      # Fatal Error
   }

} # getDB_ID


##############################################################################
#  get next database id
# Syntax: $new_max_id = getNextDB_ID(table);
sub getNextDB_ID {

   my $seq = shift;

   my $s = $$seq{TABLE}{CONSTRAINTS}{SEQUENCE}[0]; # sequence name

   my $sequence = $s?$s:"seq_".$seq."_db_id";

   $sequence = $dbh->quote($sequence);
   my $sqltext = "SELECT nextval($sequence)";

   print "# debug nextval:$sequence:\n" if($opt_d); 
   print "# debug         $sqltext\n" if($opt_d);

####   ConnectDB() unless defined $dbh;
####   my $sth = ExecuteSQL($sqltext);
####   my @row_ary = $sth->fetchrow_array;
####   $sth->finish;
   my $row_ary = $sql_ref->handle->fetch; # reference!

   print "# debug db_id:@{$row_ary}[0]\n" if($opt_d); 
   return @{$row_ary}[0];

} # getNextDB_ID


##############################################################################
# Get the highest DB_ID, which is stored in the database table 'db_id' and
# increment it by one. Write the new value into 'db_id'.
sub GetNextDBID {

   print "GetNextDBID no more useable!\n";
   return;

   # retrieve the old max_db_id:
   my $sqltext = 'SELECT max_db_id FROM db_id';
   my $sth = ExecuteSQL( $sqltext );
   my $table_array_ref = $sth->fetchall_arrayref;
   $sth->finish;

   die "Fatal Error: table 'db_id' must contain *one* and *only one* record!\n"
      if scalar @{$table_array_ref} != 1;

   my $db_id = $$table_array_ref[0][0];
   $db_id++;

   # write it to table db_id:
   $sqltext = "UPDATE db_id SET max_db_id = $db_id";
   ExecuteSQL( $sqltext ) && return $db_id;
   
} # GetNextDBID


##############################################################################
# returns the sum of two fields
# returnvalue = col001 + col002
# usage: ACTION=F sum col001 c0l002 [FIX=2]
sub sum {
   
   my $form = pop(@_);   # last element
   my $fix if($#{@_} == 6);

   if($#{@_} == 6) {
      ($fix = $_[5]) =~ s/FIX=//g;
   }

   return(sprintf("%.".$fix."f",($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : 0) +
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : 0))) if($fix);
   return(($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : 0) +
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : 0)) if(!$fix);

}


##############################################################################
# returns the subtraction of two fields
# returnvalue = col001 - col002
# usage: ACTION=F sub col001 c0l002 [FIX=2]
sub sub {
   
   my $form = pop(@_);   # last element
   my $fix if($#{@_} == 6);
   
   if($#{@_} == 6) {
      ($fix = $_[5]) =~ s/FIX=//g;
   }
   return(sprintf("%.".$fix."f",($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : 0) -
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : 0))) if($fix);
   return(($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : 0) -
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : 0)) if(!$fix);

}


##############################################################################
# returns the multiplication of two fields
# returnvalue = col001 * col002
# usage: ACTION=F multi col001 c0l002 [FIX=n]
sub multi {
   
   my $form = pop(@_);   # last element
   my $fix if($#{@_} == 6);

   if($#{@_} == 6) {
      ($fix = $_[5]) =~ s/FIX=//g;
   }

   return(sprintf("%.".$fix."f",($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : 0) *
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : 0))) if($fix);
   return(($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : 0) *
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : 0)) if(!$fix);

}

##############################################################################
# returns the division of two fields
# returnvalue = col001 / col002
# usage: ACTION=F div col001 c0l002 [FIX=n]
sub div {
   
   my $form = pop(@_);   # last element
   my $fix if($#{@_} == 6);

   print "# debug function div:$#{@_}  @_\n" if($opt_d);

   if($#{@_} == 6) {
      ($fix = $_[5]) =~ s/FIX=//g;
   }

   return(sprintf("%.".$fix."f",($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : return undef) /
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : return undef))) if($fix);
   return(($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : return undef) /
	  ($$form{$_[4]}{DATA} ? $$form{$_[4]}{DATA} : return undef)) if(!$fix);

}

##############################################################################
# returns concatenated strings with optional character or string between them
# returnvalue = col001<char|string>col002
# usage: ACTION=F concat col001 col002 ... [delim=<char|string>]
# example ACTION=F concat section_ext_id section_unit delim=|
sub concat {
   
   my $form = pop(@_);   # last element
   pop(@_);
   my $str = '';
   my $delim = '';
   
   if($_[$#{@_}] =~ /delim/) {   # last parameter
      ($delim = $_[$#{@_}]) =~ s/delim=//;
      pop(@_);
   }

   for(my $i=3; $i<=$#{@_}-1; $i++) {
      return undef if(! $$form{$_[$i]}{DATA});
      $str .= $$form{$_[$i]}{DATA}.$delim;
   }
   return undef if(! $$form{$_[$#{@_}]}{DATA});
   $str .= $$form{$_[$#{@_}]}{DATA}; # last section

   return $str;

} # concat

############################################################################## 
# the same functionality as concat 
# plus: use reserved strings from apiisrc ( with ' ' ) and use fix parameter 
# returns concatenated strings 
# require apiisrc (see reserved_string) 
# returnvalue = col001$reserved_string->{V_CONCAT}col002 
# usage: ACTION=F concat2 col001 col002 ... 
# example ACTION=F concat2 section_ext_id 'unit' section_unit 
sub concat2 { 

  my $form = pop(@_);   # last element 
  pop(@_); 
  my $str = ''; 
  my $delim = $reserved_strings{V_CONCAT}; 

   for(my $i=3; $i<=$#{@_}-1; $i++) { 
     if ( $_[$i] =~ /\'.+?\'/ ) { 
        ( $ret = $_[$i] ) =~ s/\'//g; 
        $str .= $ret.$delim; 
      } else { 
         next if(! $$form{$_[$i]}{DATA}); 
        #return undef if(! $$form{$_[$i]}{DATA}); 
        $str .= $$form{$_[$i]}{DATA}.$delim; 
      } 
   } 

   return undef if(! $$form{$_[$#{@_}]}{DATA}); 
   $str .= $$form{$_[$#{@_}]}{DATA}; # last section 

   return $str; 

} # concat2


##############################################################################
# split a string into several substrings and put this pieces into different fields
# returnvalue = sourcefield
# usage: ACTION=F split destfield1 [destfield2 ...] delim=<char|string>
sub split {

   my $form = pop(@_);   # last element is the form-hash
   my $string = pop(@_);
   return undef if(! $string); # no string no split  - that's the life
   (my $delim = pop(@_)) =~ s/delim=//;
   $delim =~ s/([\+\?\.\*\^\$\(\)\[\]\{\}\|\\])/\\$1/g; # special characters

   my @s = split(/$delim/,$string,$#{@_}-2);

   for(my $i=3; $i<=$#{@_}; $i++) {
      $$form{$_[$i]}{DATA} = $s[$i-3];
   }
   
   return $string;

} # split


##############################################################################
# 
# 
# usage: ACTION=F fromField col
sub fromField {

   my $form = pop(@_);   # last element

   return($$form{$_[3]}{DATA} ? $$form{$_[3]}{DATA} : undef);

} # fromField


##############################################################################
# fetch one or more than one record and put the values into a listbox (type M)
#       or entry field (type E,D,B or N).
#       Entry fields can display one record only
#
# usage:
# ACTION=F fetchlist Table db_col1 section db_col2 [delimiter] [order=db_col] 
#
#        Table:  database table
#      db_col1:  column of the table TABLE to be fetched
#                for more than one column: db_col1a|db_col1b|db_col1c...
#      section:  section name of another form field
#      db_col2:  column of table TABLE to compare with the value of section
#    delimiter:  delimiter of the displayed columns. default: b|b (blank|blank) 
# order=db_col:  sortlist by column db_col
#
#
# resulting SQL-statement:
#      SELECT db_col1a,db_col1b FROM Table WHERE db_col2=<section>
#
# Example: 
#   # multiselectable listbox
#   TYPE=M
#   LABEL=ID |  Date            | weight[kg]
#   ACTION=F fetchlist  WEIGHT d_weight|weight col002 db_id bb:bb order=weight
#
#   # not editable text field
#   TYPE=D
#   LABEL=n  |  average weight [kg]
#   ACTION=F fetchlist WEIGHT count(*)|avg(weight) INT_ID db_id 
#
#
sub fetchlist {

   my $form = pop(@_);   # last element

   print "# debug ** function fetchlist **\n" if($opt_d);
   print "# debug field1:$_[3]:$$form{$_[3]}{DATA}\n" if($opt_d); 
   print "# debug field2:$_[4]:$$form{$_[4]}{DATA}\n" if($opt_d); 
   print "# debug field3:$_[5]:$$form{$_[5]}{DATA}\n" if($opt_d); 
   print "# debug field4:$_[6]:$$form{$_[6]}{DATA}\n" if($opt_d); 
   print "# debug field5:$_[7]:$$form{$_[7]}{DATA}\n" if($opt_d); 
   print "# debug field6:$_[8]:$$form{$_[8]}{DATA}\n" if($opt_d); 


   my $section = $_[0];
   my $tab = $_[3];
   my $col = $_[4];
   my $cr  = $_[5];
   my $cl  = $_[6];
   my $delim = $_[7];
   my $order = $_[8];

   if($order =~ /order=/) {
      $order =~ s/order=//;
      $delim =~ s/b/ /g;
   } else {
      if($delim =~ /order=/) {
	 $delim =~ s/order=//;
	 $order = $delim;
	 $delim = ' | ';
      } else {
         $delim =~ s/b/ /g if($delim);
         $delim = ' | ' if(! $delim);
	 $order = undef;
      }
   }

   return if(! ($tab and $col));
   return if($cl and $cr and (! $$form{$cr}{DATA}));

   $tab =~ s/\|/,/g;
   $col =~ s/\|/,/g;

   
   my $sqltext = 'SELECT '.$col.' FROM '.$tab;
   
   if($$form{$cr}{TYPE} =~ /^C/) {
      my($d,$m,$y) = Decode_Date_NativeRDBMS($$form{$cr}{DATA});
      if($y and $m and $d) {
         my $tmp ="$y-$m-$d" if($date_format eq 'EU');
            $tmp ="$y-$d-$m" if($date_format eq 'US');
         $sqltext .= ' WHERE '.$cl.'='.$dbh->quote($tmp) if($cl and $cr);
      }
   } else {
      $sqltext .= ' WHERE '.$cl.'='.$dbh->quote($$form{$cr}{DATA}) if($cl and $cr);
   }
   
   $sqltext .= ' ORDER BY '.$order if($order);

   print "fetchlist:SQL:$sqltext\n" if($opt_d);

   print "SQL:$sqltext\n" if($opt_s);

####   ConnectDB() unless defined $dbh;
####   my $sth = ExecuteSQL($sqltext);
   my $sql_ref = $apiis->DataBase->user_sql($sql);
   $apiis->check_status;

   my @choices;
   my @MO_choices;
####   while( my @ary = $sth->fetchrow_array) {
   while( my @ary_ref = $sth->fetchrow_array) {
      push @choices, join(', ',@{$ary_ref});
      push @MO_choices, [@{$ary_ref}]; # O-type needs array of arrays.
   }
   $sth->finish;
 
   if($$form{$section}{TYPE} =~ /^[MO]/) {
      $$form{$section}{WIDGET}->delete(0,'end');
      foreach (@MO_choices) {
         print "# debug [M]Listbox-CHOICES:fetchlist:@$_\n" if($opt_d);
	 if($$form{$section}{TYPE} =~ /^M/) {
	    $_ =~ s/,/$delim/g; 
	    $$form{$section}{WIDGET}->insert('end',@$_);
	 }
	 if($$form{$section}{TYPE} =~ /^O/) {
	    $$form{$section}{WIDGET}->insert('end',$_);
	 }
      }
   } else {
      $choices[0] =~ s/,/$delim/g;
      $$form{$section}{DATA} = $choices[0];
   }

} # fetchlist


##############################################################################
# execute an SQL statement without checking
#  Syntax: F SQL <sql-statement>[;<sql-statement> ...]    
#  no ',' allowed  use '|' instead
#
# The fetched values of a SELECT statement can be putted into
# a listbox TYPE=M field
# Example: TYPE=M
#          ACTION=F SQL SELECT username FROM users; 
#         
sub SQL {

   my $form = pop(@_);   # last element
   my @para = @_;

   my $section = $_[0];
   my $sql = '';

   # debug messages
   print "# debug ** function SQL **\n" if($opt_d);
   foreach (@para){print "#debug parameter:$_\n" if($opt_d)};

   for (my $i=3;$i<$#para;$i++) {
      # print "$i: $para[$i]\n";
      if($para[$i] =~ /^.*\$.*\$/) {
	 my ($l,$c,$r) = $para[$i] =~ /^(.*)\$(.*)\$(.*)$/;
	 return if(!$$form{$c}{DATA});
         $sql .= $l.$$form{$c}{DATA}.$r." ";
      } else {
         $sql .= "$para[$i] ";
      }
   }

   $sql =~ s/\|/,/g;          # substitute '|' with ','
   $sql =~ s/(\$\w+)/$1/gee;  # substitute variables names with its values
   print "SECTION:$section:SQL:$sql\n" if($opt_d or $opt_s);

   my $sql_ref = $apiis->DataBase->user_sql($sql);
   $apiis->check_status;

   # error?
   if($status) {
      error($$form{GENERAL}{TOPLEVEL},
            "Error on SQL statement in Section: $section",
	    $err_msg);
      my $rc = $dbh->rollback if($dbh);
      return;
   }

   # if SELECT-statement -> fetch
   if($sql =~ /^select/i) {
      my @choices;
      my @MO_choices;
      while( my $ary_ref = $sql_ref->handle->fetch) {
	 push @choices, join(', ',@{$ary_ref});
	 push @MO_choices, [@{$ary_ref}]; # O-type needs array of arrays.
      }
    
      if($$form{$section}{TYPE} =~ /^[MO]/) {
	 $$form{$section}{WIDGET}->delete(0,'end');
	 foreach (@MO_choices) {
	    print "# debug [M]Listbox-CHOICES:SQL::@$_\n" if($opt_d);
	    $$form{$section}{WIDGET}->insert('end',@$_)
	                   if($$form{$section}{TYPE} =~ /^M/);
	    $$form{$section}{WIDGET}->insert('end',$_)
	                   if($$form{$section}{TYPE} =~ /^O/);
	 }
      } else {
         if($$form{$section}{TYPE} =~ /^[T]/) {
	    print "# debug T-CHOICES:SQL::@$_\n" if($opt_d);
	    $$form{$section}{WIDGET}->delete('1.0','end'); 
	    $$form{$section}{WIDGET}->insert('1.0',$choices[0]);
	 } else { return $choices[0] };
      }
   } else {
      # $sth->finish;
      my $rc = $dbh->commit if($dbh);
   }

} # SQL


##############################################################################
# like SQL but  instead of using method user_sql here we use sys_sql!
sub sysSQL {

   my $form = pop(@_);   # last element
   my @para = @_;

   my $section = $_[0];
   my $sql = '';

   # debug messages
   print "# debug ** function SQL **\n" if($opt_d);
   foreach (@para){print "#debug parameter:$_\n" if($opt_d)};

   for (my $i=3;$i<$#para;$i++) {
      # print "$i: $para[$i]\n";
      if($para[$i] =~ /^.*\$.*\$/) {
	 my ($l,$c,$r) = $para[$i] =~ /^(.*)\$(.*)\$(.*)$/;
	 return if(!$$form{$c}{DATA});
         $sql .= $l.$$form{$c}{DATA}.$r." ";
      } else {
         $sql .= "$para[$i] ";
      }
   }

   $sql =~ s/\|/,/g;          # substitute '|' with ','
   $sql =~ s/(\$\w+)/$1/gee;  # substitute variables names with its values
   print "SECTION:$section:SQL:$sql\n" if($opt_d or $opt_s);

   my $sql_ref = $apiis->DataBase->sys_sql($sql);
   $apiis->check_status;

   # error?
   if($status) {
      error($$form{GENERAL}{TOPLEVEL},
            "Error on SQL statement in Section: $section",
	    $err_msg);
      my $rc = $dbh->rollback if($dbh);
      return;
   }

   # if SELECT-statement -> fetch
   if($sql =~ /^select/i) {
      my @choices;
      my @MO_choices;
      while( my $ary_ref = $sql_ref->handle->fetch) {
	 push @choices, join(', ',@{$ary_ref});
	 push @MO_choices, [@{$ary_ref}]; # O-type needs array of arrays.
      }
      #$sth->finish;
    
      if($$form{$section}{TYPE} =~ /^[MO]/) {
	 $$form{$section}{WIDGET}->delete(0,'end');
	 foreach (@MO_choices) {
	    print "# debug [M]Listbox-CHOICES:SQL::@$_\n" if($opt_d);
	    $$form{$section}{WIDGET}->insert('end',@$_)
	                   if($$form{$section}{TYPE} =~ /^M/);
	    $$form{$section}{WIDGET}->insert('end',$_)
	                   if($$form{$section}{TYPE} =~ /^O/);
	 }
      } else {
         if($$form{$section}{TYPE} =~ /^[T]/) {
	    print "# debug T-CHOICES:SQL::@$_\n" if($opt_d);
	    $$form{$section}{WIDGET}->delete('1.0','end'); 
	    $$form{$section}{WIDGET}->insert('1.0',$choices[0]);
	 } else { return $choices[0] };
      }
   } else {
      my $rc = $dbh->commit if($dbh);
   }

} # sysSQL

##############################################################################
# To use the GUI with a load object call_LO builds the data_hash and 
# passes the hash to the load object and executes it.
# 
# The load object LO_xx must be reside in $APIIS_LOCAL/lib directory with
# name LO_xx.pm
# 
# usage: TYPE=P
#        COMMAND=&call_LO('LO_xx',$form);
sub call_LO {

   my $form = pop(@_);
   my ($obj, $dlf) = @_;  # object, data log flag

   return if(! $obj);

   if($$form{BalloonStatusField}) {
      my $delay = 2500;
      $$form{BalloonStatusField}{DATA} = __('Inserting data');
      $$form{BalloonStatusField}{WIDGET}->after($delay,
			       sub{$$form{BalloonStatusField}{DATA} =''});
   }

   # change cursor 
   my $cursor=$$form{GENERAL}{FRAME}->cget(-cursor);     # store cursor
   $$form{GENERAL}{FRAME}->configure(-cursor=>'watch');  # change cursor to 'watch'
   $$form{GENERAL}{FRAME}->idletasks;       # to make new cursor visible before sub is called

   my %data_h = ();

   # get DATA from some special fields
   foreach $var (sort keys %$form) {
      next if $var eq 'GENERAL';

      # get text from Text-widgets
      if($$form{$var}{TYPE} =~ /^[T]/) {
	 $$form{$var}{DATA} = $$form{$var}{WIDGET}->get('1.0','end');
	 chomp($$form{$var}{DATA});
      }

      # get selected items from Listbox-widget
      if($$form{$var}{TYPE} =~ /^[M]/) {
	 my $we = $$form{$var}{WIDGET};
         my @choices;
         my @sel = $we->curselection();
         foreach (@sel) {
            my $a = $we->get($_);
	    push(@choices,$a);
         }
      print "# debug Listbox:@choices\n" if($opt_d); 
      $$form{$var}{DATA} = join(' ',@choices);
      }
   }



   # open Data log file
   my $dlfile = $apiis->APIIS_LOCAL."/var/data_$obj.log";
   my $head = 1 if(! -e $dlfile);
   open( DLF, ">>$dlfile") or
                  die __("Problems opening file [_1]", $dlfile),": $!\n" if($dlf);

   # header for the data-log
   if($dlf and $head) {
      foreach my $d (sort keys %$form) {
	 if($$form{$d}{COLUMN}) {
	    print DLF "$$form{$d}{COLUMN}|";
	 }
      }
      print DLF "\n";
   }

   # $apiis->join_model( $model_file ) unless $apiis->exists_model;;
   # $apiis->join_database unless $apiis->exists_database;

   # build data hash.
   # all fields with a value for parameter COLUMN are used as keys
   foreach my $d (sort keys %$form) {
      if($$form{$d}{COLUMN}) {
         $data_h{$$form{$d}{COLUMN}} = $$form{$d}{DATA};
	 print DLF $$form{$d}{DATA}."|" if($dlf);
         print "debug: $d used for LO_key: \'$$form{$d}{COLUMN}\':$$form{$d}{DATA} \n" if($opt_d);
      }
   }
   print DLF "\n" if($dlf);
   close DLF  if($dlf);

   # include the loadobject
   my $local = $apiis->APIIS_LOCAL;
   my $lo = "$local/lib/$obj.pm";
   require $lo;


   # execute loadobject
   my ($err_status, $err_ref) = &$obj({%data_h});

   print "# debug: $obj: Status: $err_status\n" if($opt_d);
   
   # Balloons available? If not errors are shown in an dialog window
   my $tt = 1 if($$form{GENERAL}{BALLOON} eq 'both' or $$form{GENERAL}{BALLOON} eq 'balloon');

   if($err_status) { # ERROR!
      
      ### set Balloon messages to the original 
      resetBalloons($form) if($tt);
      
      ### next line only necessary if bg-color is changed permanetly
      ###    if you use 'flash_background comment out the next line 
      resetBGCOLOR($form);

      foreach my $e (@$err_ref) {

         print "# debug: $obj: short error message: ",$e->msg_short,"\n",
               "# debug: $obj: long error message: ",$e->msg_long,"\n" if($opt_d);
         
         if(! $e->ext_fields) { # no array ext_fields in Errorobject
            my $b = warnwin($$form{GENERAL}{TOPLEVEL},__('Error'),'error',$e->msg_short,
                            [__('Ok'),__('Exit'),__('Detailed Error Message')]);
            if($b and $b eq __('Detailed Error Message')) {
                warnwin($$form{GENERAL}{TOPLEVEL},__('Error'),'error',$e->sprint);
            } elsif($b and $b eq __('Exit')) {
               exit;
            }
            next;
         }
         
	 if ( scalar @{ $e->ext_fields } ) {
	   @exc = @{ $e->ext_fields };
	 } else {
	   @exc = split ( ' ',  $e->ext_fields );
	 }
	 foreach my $excol (@exc) {
            my $col = getKey($form,$excol,'COLUMN');
            if($col ne -1) {
               my $we = $$form{$col}{WIDGET}; # current widget in shorter notation
               if(Exists($we)) {

                  ### with which color should the error field marked? 
                  my $blink = $$form{GENERAL}{ERRCOLOR}?$$form{GENERAL}{ERRCOLOR}:'red';

                  ### set background color to indicate an error,
                  ###     it is necessary to reset to the original color.
                  ### first store original background color
                  $$form{$col}{BGCOLOR} = getwidgetoption($we,'background');
                  setwidgetoption($we,'background',$blink);

                  ### set error message to the balloon or
                  ###     if not available popup a dialog window
                  if($tt) {
                     $balloonmsg = $e->msg_short . "\n" . $e->msg_long;
                     setBalloon($form,$we,$balloonmsg);
                  } else {
                     my $b = warnwin($$form{GENERAL}{TOPLEVEL},__('Error in Data'),'error',
                                     $e->msg_short,[__('Ok'),__('Exit'),__('Detailed Error Message')]);
                     if($b and $b eq __('Detailed Error Message')) {
                        warnwin($$form{GENERAL}{TOPLEVEL},__('Error'),'error',$e->sprint);
                     } elsif($b and $b eq __('Exit')) {
                        exit;
                     }
                  }
               
               }
            } else { # no column => popup a dialog window
               my $b = warnwin($$form{GENERAL}{TOPLEVEL},__('Error in Data'),'error',
                               $e->msg_short,[__('Ok'),__('Exit'),__('Detailed Error Message')]);
               if($b and $b eq __('Detailed Error Message')) {
                   warnwin($$form{GENERAL}{TOPLEVEL},__('Error'),'error',$e->sprint);
               } elsif($b and $b eq __('Exit')) {
                  exit;
               }
            }
         }

      }

   } else {  # No ERROR!

      ### clear fields 
      clearForm($form,'sub');

      if($$form{BalloonStatusField}) {
	 my $delay = 2500;
	 $$form{BalloonStatusField}{DATA} = __('Data successfully inserted');
	 $$form{BalloonStatusField}{WIDGET}->after($delay,
	                          sub{$$form{BalloonStatusField}{DATA} =''});
      }

      ### set Balloon messages to the original 
      resetBalloons($form) if($tt);

      ### next line only necessary if bg-color is changed permanetly
      ###    if you use 'flash_background comment out the next line 
      resetBGCOLOR($form);

   }

   # restore cursor
   $$form{GENERAL}{FRAME}->configure(-cursor=>$cursor);


} # call_LO


##############################################################################
# usage: ACTION=F invoke parameter
#
# example:   ACTION=F invoke XXX,f invoke EXECUTE
#            EXECUTE=&call_LO('LO_ware',$form);
#            XXX=print " --- actual state: $UpIn ---\n" # Insert or Update 
sub invoke {

   my $form = pop(@_);   # last element

   eval $$form{$_[0]}{$_[3]};
   my $b = warnwin($$form{GENERAL}{TOPLEVEL},__('Error'),'error',$@,
           [__('Ok'),__('Exit')]) if($@);
   exit if($b and $b eq __('Exit'));

} # invoke


##############################################################################
# Authentication
# 
sub login {

   my ($project, $user, $password) = @_;

   my $ltop = MainWindow->new;
   $ltop->title("Login");
   
   # Project
   my $l1 = $ltop->Label(-text=>"Project:");
   my $proj_e= $ltop->Entry(-textvariable=>$project,-width=>15);
   $l1->grid($proj_e);

   # User name
   my $l2 = $ltop->Label(-text=>"User Name:",-justify=>'right');
   my $user_e = $ltop->Entry(-textvariable=>$user,-width=>15);
   $l2->grid($user_e);

   # Password
   my $l3 = $ltop->Label(-text=>"Password:",-justify=>'right');
   my $pass_e = $ltop->Entry(-show=>'*',-textvariable=>$password,-width=>15);
   $l3->grid($pass_e);

   # Button
   my $button = $ltop->Button(-text=>'Login',
	 -command=>sub{$ltop->destroy;return});
   $button->grid("-",-sticky=>"nsew");
   
   MainLoop;

} # login


##############################################################################
# getfile
# 
# 
# 
sub getfile {

   my $form = pop(@_);   # last element
   my $file_ref = shift;
   my $types = shift;
   my $title = shift;

   $types = [["Image File", [qw/.gif .GIF .JPG .jpg/]],
             ["All files", '*']] if(!$types);

   $title = 'Load File' if(! $title);

   my $path=$$form{GENERAL}{INIPATH}?
            $$form{GENERAL}{INIPATH}:
	    $apiis->APIIS_LOCAL;

   my $top = $$form{GENERAL}{TOPLEVEL};
   $$file_ref = $$form{GENERAL}{TOPLEVEL}->getOpenFile(
                                -filetypes => $types,
   				-initialdir=>$path,
   				# -initialdir=>$apiis->APIIS_LOCAL,
   				-title=>$title);

   $path=dirname($$file_ref) if($$file_ref);
   $$form{GENERAL}{INIPATH}=$path;
   return $file_ref;

} # getfile

1;
