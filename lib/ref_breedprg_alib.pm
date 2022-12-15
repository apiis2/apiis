   ###########################################################################
   # $Id: ref_breedprg_alib.pm,v 1.58 2013/09/17 06:20:10 heli Exp $
   # the specific lib for breeding programs
   # and single animal records (often fix structure)
   ###########################################################################
   use Apiis::Misc qw(:all);

   ###########################################################################
   # return a hash with ext_id and db_id WITHOUT unit
   # ( used in loading historic data, load_data_*.pl )
   # no input values.
   # return: %id_hash; ( ext_id => db_id )
   sub get_id_hash_unit {
      my ($ext_id, $db_id);
      if ( ! $dbh ) {
	$dbh=$apiis->DataBase->dbh;
      }
      local $dbh->{RaiseError} = 1 unless $dbh->{RaiseError};
      print "Fetching IDs from entry ...";
      my $sth = $dbh->prepare(q{
	 SELECT ext_animal, db_animal FROM transfer
	 }) or die $dbh->errstr;
      $sth->execute;                            # rffr should entry_transfer
      $sth->bind_columns( \$ext_id, \$db_id );  # bind columns to the vars

      my $k = 0;
      # creating hash (key = ext_id, value = db_id)
      while ($sth->fetch) {
         $id_hash{ $ext_id } = $db_id;
	 $k++;
      }
      $sth->finish;
      print " ($k IDs stored)\n";
      return \%id_hash;
   }
   ######################################################################
   # return value from datafile at specific position ( used in loading
   # historic data, load_data_*.pl ) usage: get_value( 'position cfix
   # position2', \@lineref ) @lineref is the line from datafile
   # return: value if position known as code (from collect_codes1.pl)
   # return db_code after check file codes.chg for possible changing this code
   # same for unit and table_id
=pod

=head1 usage

get_value( 'position cfix position2', \@lineref, format )

=head1 description

return value from datafile at specific position   @lineref is the line from datafile
return: value if position known as code (from collect_codes1.pl)
return db_code after check file codes.chg for possible changing this code
same for unit and table_id
MUST be used if fields can be empty: as a consequence the variable is not an
empty string but a NULL value!!!

=head1 configuration

=head2 position

describe the position on input line. could be more than once and also
fixed parts are possible (see the c-option).

=head2 format

define either an date format, a simple test if the return value is
an number or lower resp. upper case any character.

=head3 [dmyj] plus any character which split the date (.-/...)

date format use the function getdate(). this allow an specific format
like 'dd.mm.yyyy' or 'ddmmjj' or use the number of elements in the
data. for further details see function getdate().

=head3 n

test is a number else ignore the value. also change from ',' to '.' if exist.

=head3 cl

lower case characters.

=head3 cu

upper case characters.

=head1 used in

loading historic data (load_data.pl)


=cut

   sub get_value {
     #     use vars qw/$sgetvalstr $getvalstr/;
     my $getvalstr =  shift();
     my @line = @{ shift() };
     my $format = shift;

     my @getvalstr = split ( /\s+/, $getvalstr );
     my @vall = ();
     my $val = (); my $class = ();
     my @vall_orig = ();

     if ( $#getvalstr > 0 ) { 	  # more than one position
       foreach $pos ( @getvalstr ) {
	 if ( $pos =~ /\|/ ) {
	   my $ppos=$pos;
	   $ppos =~s/\|/ /g;
	   $ppos = get_string(\@line, $ppos);
	   $ppos=~s/\|/#/g;
	   $vall=$ppos;
	 } elsif ( $pos =~ /^c/ ) {
	   $pos =~ s/^.//g;
	   $vall = $oval = $pos;
	 } elsif ( $pos =~ /^o/ ) {
	   $oval = $pos;
	   $pos =~ s/^.//;
	   my @val = split ( ':', $pos );
	   $pos = $id_code{ $val[0] . '#' . $val[1] };
	   $vall  = $pos;
	 } else {
	   $val = $line[$pos];
	   $oval = $val;
	   if ( defined $val ) {
	     $vall = get_value( $pos, \@line );
	   } else {
	     $vall = NULL;
	   }
	 }
	 push ( @vall, $vall );
	 push ( @vall_orig, $oval );
       }
       $val = join( '|', @vall );
       $val_orig = join( '|', @vall_orig );

       if ( $testid2{ $getvalstr } )  { # if id defined
 	 my $ccount = $#getvalstr;
	 my @fields=split(/\s+/,lc($testid2{ $getvalstr }));
	 my $table=shift @fields;

	 if ( $format =~ /[yYjJ]/ ) {	# datum
	   for (my $i=0;$i<=$#fields;$i++) {
 	     if (($vall[$i]) and ($apiis->Model->table($table)->datatype($fields[$i]) eq 'DATE')) {
 	       ($vall[$i], $status, $obj) = getdate($vall[$i], $format);
 	     }
 	     if (! $vall[$i]) {
 	       $vall[$i]=NULL;
	     }
	   }
	 } elsif ( $format =~ /^n/ ) {
	   my $ret = $vall[$p];
	   $ret =~ s/,/./g; # use 'dot'
	 EXIT: {
	     last EXIT if ( not defined $ret );
	     last EXIT if ( $ret eq '' );
	     last EXIT if ( $ret + 0 eq $ret );
	     last EXIT if ( $ret =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ );
	     print __("\nvalue [_1] not numeric on position [_2] - would be ignored\n", $ret, $p);
	     $ret = NULL;
	   }
	   $vall[$p] = $ret;
	 } elsif ( $format =~ /^cu/ ) { # means character upper case
	   $vall[$p] = uc($vall[$p]);
	 } elsif ( $format =~ /^cl/ ) { # means character lower case
	   $vall[$p] = lc($vall[$p]);
	 }

	 @testid2_extr = split( / /, $testid2{ $getvalstr } );
	 my $id_name = 'db_'.$testid2_extr[0];
	 my $tab_name = shift @testid2_extr;
	 my $scount = 0;
	 my $clause = ();
	 my @where_cl = ();
	 foreach $s ( @testid2_extr ) {
	   $vall[ $scount ] = NULL if ( $vall[ $scount ] eq '' );
	   # next if ( $vall[ $scount ] == '' );
	   $clause = lc ( $s ) . ' = \'' . $vall[ $scount ] . '\'';
	   $clause =~ s/'NULL'/NULL/g;
	   $clause =~ s/=[ ]*NULL/isNULL/g; # '= NULL' not valid
	   push @where_cl, $clause;
	   $scount ++;
	 }
	 my $where_clause = join( ' and ', @where_cl );
	 my $sql = "SELECT $id_name from $tab_name WHERE $where_clause";
	 # print "+++>$sql<+++\n";
	 my $sth = $dbh->prepare(qq{ $sql }) or die $dbh->errstr;
	 $sth->execute;
         my $q = $sth->rows;
	 if ($q>1) {
	   print __("no unique key: [_1]\n", $sql);
	   exit;
	 } elsif ($q==0) {
	   print __("no key defined: [_1]\n", $sql);
	   # print "Kein Schlüssel definiert: $sql\n";
	   exit;
	 } else {
           $sth->bind_columns( \$table_id ); # bind columns to the vars
	   #	   $sth->bind_columns( \$table_id ); # bind columns to the vars
	   my @retline = ();
	   $val = NULL;
	   while ( my $ret = $sth->fetch ) {
	     my @retline = @$ret;
	     if ( $retline[0] ) {
	       $val = $retline[0];
	     } else {
	       $val = NULL;
	       print __("no proper id for given where clause: [_1]\n", @where_cl);
	     }
	   }
	   $sth->finish;
	 }
       }
     } else {			# main... also for use in recursive manner
       my $sgetvalstr = $getvalstr;

       #--- fix-value
       if ( $sgetvalstr =~ /^c/ ) {
         $sgetvalstr =~ s/^.//g;
         return $sgetvalstr;
       } elsif ( $sgetvalstr =~ /^o/ ) {
	 $sgetvalstr =~ s/^.//;
	 my @val = split ( ':', $sgetvalstr );
	 $sgetvalstr = $id_code{ $val[0] . '#' . $val[1] };
	 return $sgetvalstr;
       } else {
         $val = $line[$sgetvalstr];
         if ( defined $val and $val ne '') {

           #--- Test, ob code oder unit
           #--- wenn nicht, wert so belassen
	   $class=undef;
           $class = $test2{ $sgetvalstr } if ( $test2{ $sgetvalstr } );
           $class = $testjob2{ $sgetvalstr } if ( $testjob2{ $sgetvalstr } );
           if ($class) {

             #--- get valid values from modified *.chg files (normaly
             # by Ulf Müller *.ok, but this is not mandatory)
             if ( defined $test{ $sgetvalstr . '#' . $line[$sgetvalstr] } ) {
               $val = $test{ $sgetvalstr . '#' . $line[$sgetvalstr] };
             } elsif ( defined $testjob{  $sgetvalstr . '#' . $line[$sgetvalstr] } ) {
               $val = $testjob{ $sgetvalstr . '#' . $line[$sgetvalstr] };
             }

             #--- get internal Code
             if ( $id_code{ $class . '#' . $val } ) {
               $val = $id_code{ $class . '#' . $val };
             } elsif ( $id_unit{ lc ( $class ) . '#' . lc( $val ) } ) {
               $val = $id_unit{ lc ( $class ) . '#' . lc( $val ) };
             } else {
               $val=NULL;
	     }
           } elsif ($format =~ /[yYjJ]/ ) {
             #--- wenn Datum
             ($val,$status, $obj)=getdate($val, $format);
             if (! $val) {
               $val=NULL;
             } else {
               $val="'".$val."'";
             }
           } elsif ( $format =~ /^n/ ) { # numeric
	   my $ret = $val;
	   $ret =~ s/,/./g; # use 'dot'
	 EXIT: {
	     last EXIT if ( not defined $ret );
	     last EXIT if ( $ret eq '' );
	     last EXIT if ( $ret + 0 eq $ret );
	     last EXIT if ( $ret =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ );
	     print __("\nvalue [_1] not numeric on position [_2] - would be ignored\n", $ret, $sgetvalstr);
	     $ret = NULL;
	   }
	   $val = $ret;
	 } elsif ( $format =~ /^cu/ ) { # means character upper case
	   $val = uc($val);
	 } elsif ( $format =~ /^cl/ ) { # means character lower case
	   $val = lc($val);
	 }
         } else {
           $val = NULL;
         }
       }
     }
     return $val;
   }

#####################################################################################
# test, if value a code and gives back a db_unit or db_code
sub get_db_code_db_unit {
  my $ssstr = shift;
  my $val   = shift;
  if ( $val ) {
    #--- Test, if code or unit
    #--- if not, then return value without changes
    my $class=undef;
    $class = $test2{ $ssstr } if ( $test2{ $ssstr } );
    $class = $testjob2{ $ssstr } if ( $testjob2{ $ssstr } );
    if ($class) {
      #--- get internal code (db_*)
      if ( $id_code{ $class . '#' . $val } ) {
        $val = $id_code{ $class . '#' . $val };
      } elsif ( $id_unit{ lc ( $class ) . '#' . lc($val) } ) {
        $val = $id_unit{ lc ( $class ) . '#' . lc($val) };
      }
    }
  } else {
    $val = 'NULL';
  }
  return $val;
}




#    ######################################################################
#    # return value from datafile at specific position
#    # ( used in loading historic data, load_data_*.pl )
#    # usage: get_value( position, \@lineref ) @lineref is the line from datafile
#    # return: value
#    # if position known as code (from collect_codes1.pl) return db_code
#    # after check file codes.chg for possible changing this code
#    sub get_value {
#      my $ssstr =  shift();
#      my @line = @{ shift() };
#      $val = $line[$ssstr];
#      if ( $val ) {
#        if ( defined $test{  $ssstr . '#' . $line[$ssstr] } ) {
# 	 # if ( $test{ $ssstr . '#' . $line[$ssstr] } ) {
# 	 # society unknown return 0!!
# 	 $val = $test{ $ssstr . '#' . $line[$ssstr] };
#        }
#      }
#      else {
#        $val = NULL;
#      }

#      $class = $test2{ $ssstr };
#      if ( $class and defined $val ) {
#        if ( $id_code{ $class . '#' . $val } ) {
# 	 $val = $id_code{ $class . '#' . $val };
#        }
#      }
#      return $val;
#    }

   ######################################################################
   # return db_animal for the ext_animal
   # ( used in loading historic data, load_data_*.pl )
   # require id_hash without unit (see above)
   # usage: get_animal_id( concatenated ext_animal )
   # return: db_animal
   sub get_animal_id {
     my $sstr =  shift();
     my $iinfile =  shift();
     my @lline = @{shift()};
     my $lline = join( '|', @lline );
     if ( exists $dup{ $iinfile . ' -> ' . $lline }  and exists $dup2{ $sstr } ) {
       $sstr = $dup{ $iinfile . ' -> ' . $lline };
       if ( $dup2{ $sstr } > 1 ) {
	 $sstr = undef;
       }
       $dup2{ $sstr } ++ if ( $sstr );
       # if two times the same line in data (use only one time)
     }
     if ( ! %id_hash ) {
       #######  $id_hash{ $ext_id } = $db_id
       get_id_hash_unit( \%id_hash );
     }
     if ( defined $sstr and $id_hash{ $sstr } ) {
       $db_id = $id_hash{ $sstr };
     } else {
       $db_id = undef;
     }
     return $db_id;
   }
   ######################################################################
   # get db_code from table codes
   # ( used in loading historic data, add_codes.pl, load_data_*.pl )
   # without parameter
   # return: %id_code; (class . '#'. ext_code) => db_code
   sub get_code_id {
      my ($class, $ext_code, $db_code) = ();
      print "Fetching IDs from codes ...";
      my $sql = "SELECT class, ext_code, db_code FROM codes";
      my $sql_ref = $apiis->DataBase->sys_sql($sql);
      $apiis->check_status;
      my $k = 0;
      # creating hash (key = class . '#'. ext_code, value = db_code)
      while ( my $line_ref = $sql_ref->handle->fetch ) {
	my @line = @$line_ref;
	# $id_code{ $class . '#' . $ext_code } = $db_code;
	$id_code{ $line[0] . '#' . $line[1] } = $line[2];
	$k++;
      }
      $sql_ref->handle->finish;
      print " ($k IDs stored)\n";
      return \%id_code;
   }
   # #############################################################################
   # return two hash references with the duplicated animals from file $chg_file
   # change file get from collect_ext_id.pl -f
   # ( used in loading historic data, load_data_*.pl )
   # usage: get_dup_animal( $chg_file );
   # return: ( $dup_ref, $dup2_ref )
   # %dup:  datafile => whole line; %dup2: ext_animal => count of use
   sub get_dup_animal {
     my $chg_file = shift();
     my $coll_ext_id = shift();

     open ( IN, "<$chg_file" ) || die "$chg_file not found";
     my %dup = ();
     my %dup2 = ();
     my %temp = ();

     @data=<IN>;
     foreach $line (@data) {
       next if ( $line =~ /^#/ );
		 my $key = $line;
		 $key =~ s/=> .*$//;
		 map {s/^\s*//; s/\s*$//} $key;
		 $rest = $line;
		 $rest =~ s/^.*?=> //;
		 mychomp($rest);	##!!
		 @rest2 = split( '\|', $rest);
		 map {s/^\s*//; s/\s*$//} @rest2;
		 $rrest = join( '|', @rest2);
		 @temp = split( / /, $key );
		 $temp{ $temp[0] . '|' . $temp[2] . ' -> ' . $rrest } ++;
		 $dup{ $temp[0] . ' -> ' . $rrest } = $temp[2];
		 $dup2{ $temp[2] } ++;
	      }
	 close( IN );
         if ( $coll_ext_id ) {
	   foreach $temp_row ( keys %temp ) {
	     if ( $temp{ $temp_row } > 1 ) {
	       my $comp_temp_row = $temp_row;
	       $comp_temp_row =~ s/\|.+?->/ ->/g;
	       if ( $dup{ $comp_temp_row } ) {
		 $dup2{ $dup{ $comp_temp_row } } -= ( $temp{ $temp_row } -1 );
	       }
	     }
	   }
	 }
       return ( \%dup, \%dup2 );
     }
   #############################################################################
   # return two hash references with the codes to change
   #     from $chg_file and datafile ($infile)
   # change file get from collect_codes1.pl or collect_job1.pl or collect_keys1.pl
   # used to create the datafile specific new target code!
   # ( used in loading historic data, load_data_*.pl )
   # usage: create_repl_hash( $chg_file, $infile );
   # return: ( $test_ref, $test2_ref )
   # %test: (column . '#' . value) => new_value
   # %test2: column => category
   sub create_repl_hash {
     $file = shift();
     $infile = shift();
     return ( 0, 0 ) if ( ! $infile or ! $file );
     my %test = ();
     my %test2 = ();
     # caching...
     my $has_cache = ();
     $has_cache = 1 if $apiis->Cache->hasMemcached();
     my ( $mem_cache, $db_name );
   CACHE: {
       last CACHE if !$has_cache;
       $mem_cache = $apiis->Cache->memcache();
     }
     my $mydb_name   = $apiis->Model->db_name;
     my @memkeys = ( $mydb_name, $file, $infile );
     my $mem_key = join( ':::', @memkeys );
     if ( $has_cache and ! %test and ! %test2 ) {
       my $ret_link = $mem_cache->get( $mem_key );
       my $ret = @$ret_link[0];
       my $ret2 = @$ret_link[1];
       %test  = %$ret if ( $ret );
       %test2 = %$ret2 if ( $ret2 );
     }
     if ( ! %test and ! %test2 ) {
       open ( IN, "<$file" ) or die "$file: not known $!\n";;
       @data=<IN>;
       foreach $line (@data) {
	 next if $line =~ /^\s*$/;
	 next if $line =~ /^#/;
	 my @lline =  &quotewords('\s+', 0, $line);
	 my $nn = scalar @lline;
	 foreach $l (@lline) {
	   $l = '' if (not defined $l)
	 }
	 if ( $lline[1] and $lline[1] eq $infile ) {
	   #    if ( $lline[3] ne $lline[5] ) {
	   ##          column              value
	   $concat = "$lline[2]" . "#" . "$lline[3]";
	   ##              new_value
	   $test{$concat} = $lline[5];
	   ##       column     category
	   $test2{$lline[2]} = $lline[0];
	   #    }
	 }
       }
       close ( IN );
       $mem_cache->set( $mem_key, [\%test, \%test2], 7200 ) if ( $has_cache );
     }
     ### end caching
     return ( \%test, \%test2 );
   }

   # ###########################################################################
   # insert all db_animal from transfer into table animal
   # (without unknown 1 and 2) the next actions in animal are then updates!
   # all animals get for sire = '1' and dam = '2'
   # (because some animals never updated and then they have NULL there)
   # usage: transfer_to_animal(); without any parameter
   # ( used in loading historic data, load_data_herdbook.pl only once )
   # require %id_hash
   sub transfer_to_animal {
     my $today = $apiis->today;
     my $now = $apiis->now;
     my $user = $apiis->os_user;
#     if ( not defined %id_code ) {
     if ( ! %id_code ) {
       get_code_id( \%id_code );
     }
     if ( ! %id_hash ) {
       #######  $id_hash{ $ext_id } = $db_id
       get_id_hash_unit( \%id_hash );
     }
     my $s = 0;
     my $commit_counter = 0;
     my %id_hash_value = ();

   foreach $key (keys %id_hash) {
     $value = $id_hash{ $key };
     $id_hash_value{ $value } ++;
   }
     print "Inserting all db_animal in table animal ...\n";
     my $rowid = $apiis->DataBase->rowid;
     my $owner = $apiis->node_name;
     my $sth = $dbh->prepare(qq{
			       INSERT into animal ( db_animal, db_sire, db_dam, last_change_dt, last_change_user, $rowid, owner, version ) VALUES ( ?, '1', '2', '$now', '$user', ?, '$owner', '1' )
			      }) or die $dbh->errstr;
     foreach $ins ( keys %id_hash_value ) {
       if ( $ins > 2) {
	 my $guid  = $apiis->DataBase->seq_next_val('seq_database__guid');
	 $sth->execute( $ins, $guid );
	 $dbh->commit unless $commit_counter%1000; # commit every 1000 records
	 print '.' unless ++$s%100;
	 print " --> $s\n" unless $s%1000;
	 $commit_counter++;
       }
     }
   $dbh->commit;
   print "total $s db_animal in ANIMAL inserted\n";
   #open( LOG, ">>runall_long.log" );
   #print LOG "total $s db_animal in ANIMAL inserted\n";
   #close( LOG );
   }
   ###########################################################################
   # return two hash references whith 'create index statements'
   # infile modelname_DBL.sql (get from model_file)
   # ( used in loading historic data, load_data_*.pl )
   # usage: get_index( $model_file );
   # return: ( $idx_ref, $idx_ref2 )
   # %idx_ref: ( table . '|' . idx_name ) => whole create index line
   # %idx_ref2: table => count used
   # require $model_file
   sub get_index {
     my $model_file = shift();
     $model_file =~ s/\.model$//;
     my $sql_file = $model_file . '_Pg.sql';
     my $sql_in = $apiis->APIIS_LOCAL . '/var/' . $sql_file;
     my %idx = ();
     my %idx2 = ();
     open(MODEL, "<$sql_in") or die "$sql_file: $!\n";
     my $j = 1;
     while (<MODEL>) {
       my $line = $_;
       if ( $_ =~ 'INDEX' and $_ =~ 'CREATE') {
	 my $table = $line;
	 $table = $1 if  s/^.*?ON\s*(\w+)//;
	 my $index_name = $line;
	 $index_name =~ s/^.*?INDEX\s+?([\w_]+)\s+.*$/$1/;
	 $index_name =~ s/\s*$//;		##???
	 $idx{ $table . '|' . $index_name } = $line;
	 $idx2{ $table } ++;
       }
     }
     close(MODEL);
     return ( \%idx, \%idx2 );
   }
   #####################
   # get a specific external identifikation of an animal
   # in depence of additional informations
   # ## ## ##
   # mann muss die stellung im array entsprechend der modelldatei kennen!
   # parameter 1. stellung im array: [1..n]:splus|sminus|plus-xyz|minus-xyz|alpha,
   #           2. anzeigereihenfolge und was:     32,
   #           3. dbanimal:                       $animal
   # splus => längste wert; sminus => kürzeste wert
   # plus-xyz => soll xyz enthalten; minus-string => soll xyz nicht enthalten
   # alpha => alphanumeric
   # ex: get_ext_animal( '1:plus-bnr|jahr', 123, $animal )
   #                                           => 1. stelle (ext_unit) = bnr|jahr
   # ex: get_ext_animal( '2:sminus', $animal ) => 2. stelle kürzeste
   # ex: @tier = get_ext_animal( '1:plus-society|sex 3:minus-\|', 32, $ttier );
   #                                           => 400126 >=< 32|2
   # wenn kein tier gefunden wurde auf das die regeln passt, dann das erste
   # ext_animal from transfer because historic data or pedigree...
   # ( used in list_error.pl, show_ped.pl, print_pedigree_loops.pl )
   # # todo echte hirarchie
   sub get_ext_animal {
     my $para = shift;
     my $show = shift;
     my $dbanimal = shift;

     return 'unknown_sire' if ( $dbanimal == 1 );
     return 'unknown_dam'  if ( $dbanimal == 2 );
     my @retext = (); my %ret = (); my %totalret = ();
     #  tie %totalret, 'Tie::IxHash';
     my $sql ="select ext_animal from v_animal where db_animal = $dbanimal";
     my $sql_ref = $apiis->DataBase->sys_sql($sql);
     $apiis->check_status;
     while ( my $line_ref = $sql_ref->handle->fetch ) {
       my @line = @$line_ref;
       $ret{ $line[0] } ++;
     }
     foreach my $q ( keys %ret ) {
       push @retext, $q;
     }

     if ( $para ) {
       @para = split( / /, $para );
       foreach my $pp ( @para ) {
	 @ppp = split( ":", $pp );
	 $pos = $ppp[0];
	 $rule = $ppp[1];
	 my $character = $rule;
	 $character =~ s/plus-|minus-//g;

	 @animal = alpha( $pos, \@retext ) if ( $rule =~ /^alpha/ );
	 @animal = sminus( $pos, \@retext ) if ( $rule =~ /^sminus/ );
	 @animal = splus( $pos, \@retext ) if ( $rule =~ /^splus/ );
	 @animal = plusstr( $pos, $character, \@retext ) if ( $rule =~ /^plus-/ );
	 @animal = minusstr( $pos, $character, \@retext ) if ( $rule =~ /^minus-/ );

	 foreach $eachani ( @animal ) {
	   $totalret{ $eachani } ++;
	 }
	 $totalret{ $retext[0] } ++ if ( ! @animal );
       }
     } else { $totalret{ $retext[0] } ++; }
     @animal = ();

     # die mit der höchsten anzahl nehmen
     my $n = 1;
     foreach $ttr (sort { $totalret{$b} cmp $totalret{$a} } keys %totalret) {
       $ttr_old = $totalret{ $ttr } if ( $n == 1 );
       push @animal, $ttr if ( $totalret{ $ttr } == $ttr_old );
       $ttr_old = $totalret{ $ttr };
       $n++;
     }

     my @ani_return = ();
     foreach $red ( @animal ) {
       if ( $show ) {
	 @showcol = split( '', $show );
	 @str = split( /${ $apiis->reserved_strings }{v_concat}/, $red );
	 my @animal_ret = ();
	 foreach $s ( @showcol ) {
	   $s = $s-1;
	   push @animal_ret, $str[$s];
	 }
	 $ani_ret = join( ${ $apiis->reserved_strings }{v_concat}, @animal_ret );
       } else { $ani_ret = $red; }
       push @ani_return, $ani_ret;
     }
   #print ">-->@ani_return<--<\n";


      if ( ! @ani_return ) {
	$ani_return[0] = $retext[0];
      }
     return @ani_return; # auch mehrere möglich
   }
   ############
   # shortest string on position
   sub sminus {
     my $pos = shift;
     my $rettext = shift;
     $pos = $pos -1;
     my @rettext = @$rettext;
     my %ret = ();
     my @animal = ();
     foreach $val ( @rettext ) {
       @str = split( /${ $apiis->reserved_strings }{v_concat}/, $val );
       my $testlength = length( $str[ $pos ] );
       $ret{ $val } = $testlength;
     }
     my $n = 1;
     foreach $f (sort { $ret{$a} <=> $ret{$b} } keys %ret) {
       $f_old = $ret{ $f } if ( $n == 1 );
       push @animal, $f if ( $ret{ $f } == $f_old );
       $f_old = $ret{ $f };
       $n++;
     }
     return @animal;
   }
   ############
   # longest string on position
   sub splus {
     my $pos = shift;
     my $rettext = shift;
     $pos = $pos -1;
     my @rettext = @$rettext;
     my %ret = ();
     my @animal = ();
     foreach $val ( @rettext ) {
       @str = split( /${ $apiis->reserved_strings }{v_concat}/, $val );
       my $testlength = length( $str[ $pos ] );
       $ret{ $val } = $testlength;
     }
     my $n = 1;
     foreach $f (sort { $ret{$b} <=> $ret{$a} } keys %ret) {
       $f_old = $ret{ $f } if ( $n == 1 );
       push @animal, $f if ( $ret{ $f } == $f_old );
       $f_old = $ret{ $f };
       $n++;
     }
     return @animal;
   }
   ############
   # should 'str' match
   sub plusstr {
     my $pos = shift;
     my $string = shift;
     my $rettext = shift;
     $pos = $pos -1;
     my @rettext = @$rettext;
     my @animal = ();
     foreach $val ( @rettext ) {
       @str = split( /${ $apiis->reserved_strings }{v_concat}/, $val );
       if ( $str[$pos]=~$string ) {
	 push @animal, $val;
       }
     }
     return @animal;
   }
   ############
   # should 'str' not match
   sub minusstr {
     my $pos = shift;
     my $string = shift;
     my $rettext = shift;
     $pos = $pos -1;
     my @rettext = @$rettext;
     my @animal = ();
     foreach $val ( @rettext ) {
       @str = split( /${ $apiis->reserved_strings }{v_concat}/, $val );
       if ( $str[ $pos ]!~$string ) {
	 push @animal,  $val;
       }
     }
     return @animal;
   }
   ############
   # should be alphanumeric
   sub alpha {
     my $pos = shift;
     my $rettext = shift;
     $pos = $pos -1;
     my @rettext = @$rettext;
     my @animal = ();
     foreach $val ( @rettext ) {
       @str = split( /${ $apiis->reserved_strings }{v_concat}/, $val );
       if ( $str[ $pos ] =~ /[a-zA-Z_]/ ) { # define the rule for alpha
	 push @animal,  $val;
       }
     }
     return @animal;
   }
   # ##########################################################################
   # # code_ext_animal( ext_unit, ext_id, ext_animal )
   # # (used in LO_DS*, to make it clearer
   # # use ${ $apiis->reserved_strings }{v_concat} from apiisrc
   # # returnex: 'soc|sex >=< 32|2 >=< 400125'
   # sub code_ext_animal {
   #   my $ext_unit = shift;
   #   my $ext_id = shift;
   #   my $ext_animal = shift;
   #   my $ret = $ext_unit . ${ $apiis->reserved_strings }{v_concat} . $ext_id . ${ $apiis->reserved_strings }{v_concat} . $ext_animal;
   #   return $ret;
   # }
   # ##########################################################################
   # # code_ext_unit( ext_unit, ext_id )
   # # (used in LO_DS*, to make it clearer
   # # use ${ $apiis->reserved_strings }{v_concat} from apiisrc
   # # returnex: 'society32breeder >=< 57'
   # sub code_ext_unit {
   #   my $ext_unit = shift;
   #   my $ext_id = shift;
   #   my $ret = $ext_unit . ${ $apiis->reserved_strings }{v_concat} . $ext_id;
   #   return $ret;
   # }
   ##########################################################################
   # get_db_from_rowid
   # select element from table in depence of rowid
   # (used in list_error.pl)
   sub get_db_from_rowid {
     my $rowid = shift;
     my $tab = shift;
     my $rid = shift;
     my $sort = shift;
     $sqltext  = "SELECT $sort FROM $tab where $rid = $rowid";
     my $sql_ref = $apiis->DataBase->sys_sql($sqltext);
     $sql_ref->check_status;
     @erg = $sql_ref->handle->fetchrow_array;
     return (  $erg[0] );
   #  print "no key specified in table $tab\n";
   }
   #####################
   # get external value in depence of what type of value it is
   # animal, unit, name, code, address, record_seq, ds or something else
   # use views
   # not realy fine :-(
   # (used in list_error.pl)
   sub get_ext_val {
     my $db = shift;
     my $dd = shift;
     my $tab = shift;
     my $ext_dd = $dd;
     if ( $dd ne 'record_seq' and $dd ne 'ds' ) {
       $ext_dd =~ s/^db_/ext_/;
     }
     $ext_dd = 'ext_id' if ( $ext_dd eq 'ext_unit' );
     my $ext_tab;
     $ext_tab = 'v_animal' if $dd eq 'db_animal';
     $ext_tab = 'v_unit' if $dd eq 'db_unit';
     $ext_tab = 'v_naming' if $dd eq 'db_name';
     $ext_tab = 'v_codes' if $dd eq 'db_code';
     $ext_tab = 'v_address' if $dd eq 'db_address';
     $ext_tab = 'v_inspool' if $dd eq 'record_seq';
     $ext_tab = 'v_load_stat' if $dd eq 'ds';
     $ext_tab = $tab if !( $ext_tab );
     my @retext = ();
     my $sql = ();
     $sql = "select $ext_dd from $ext_tab where $dd = $db";
     my $sql_ref = $apiis->DataBase->sys_sql($sql);
     $sql_ref->check_status;
     while( my $line_ref = $sql_ref->handle->fetch ) {
       my @line = @$line_ref;
       push @retext, $line[0];
     }

     if ( $dd =~ /db_animal/ ) {
       @retext = get_ext_animal( '3:minus-\|', '', $db );
     }
       $ext_val = $retext[0];
     return $ext_val;
   }
   ##########################################################################
   # get the acurate db_unit for breeder, owner ...
   # get_db_unit( ext_id, ext_unit )
   # return db_unit
   # (used in load_data_*, dates_to_transfer.pl)
   sub get_db_unit {
     my $ext_id = lc shift;
     my $ext_unit = lc ( shift );
     my $db_unit = ();
     if ( !%id_unit ) {
      if ( ! $dbh ) {
	$dbh=$apiis->DataBase->dbh;
      }
       get_unit_id( \%id_unit );
     }
     $db_unit = $id_unit{ $ext_unit . '#' . $ext_id };
     if ( $db_unit ) {
       return $db_unit;
     } else {
       $db_unit = 'NULL';
       return $db_unit;
     }
   }
   ##########################################################################
   # without parameter
   # return \%id_unit;  (ext_unit . '#'. ext_id)  => db_unit
   # ( used in sub get_db_unit )
   sub get_unit_id {
      my ($ext_unit, $ext_id, $db_unit);
      print "Fetching IDs from unit ...";
      my $sth = $dbh->prepare(qq{
	 SELECT db_unit, ext_unit, ext_id FROM unit
	 }) or die $dbh->errstr;
      $sth->execute;
      $sth->bind_columns( \$db_unit, \$ext_unit, \$ext_id );  # bind columns to the vars
      my $k = 0;
      # creating hash (key = job . '#'. ext_code, value = db_code)
      while ($sth->fetch) {
	 $id_unit{ $ext_unit . '#' . $ext_id } = $db_unit;
	 $k++;
      }
      $sth->finish;
      print " ($k IDs stored)\n";
      return \%id_unit;
   }
   #####################
   # return the ext_code from codes
   # (used in list_error.pl )
   sub get_ext_code {
     my $code = shift;
     if ( $code ) {
      if ( ! $dbh ) {
	$dbh=$apiis->DataBase->dbh;
      }
       my $sql ="select ext_code from codes where db_code = $code";
       my ( $sthc, $status, $err_msg ) =  RunSQL( $sql );
       my $scode = $sthc->bind_columns( \$ext_code ) if ( ! $err_msg );
       return $ext_code;
     }
     else { return NULL; }
   }
   #############################################################################
   # get the last value of this sequence:
   # ( used in collect_ext_id.pl )
   # usage: get_last_val('sequencename');
   sub get_last_val {
     my $sequence = shift;
     my $newval;
      if ( ! $dbh ) {
	$dbh=$apiis->DataBase->dbh;
      }
     # print "Getting last value of sequence $sequence";
     my $sql = "select last_value from $sequence";
     my $sth = $dbh->prepare( $sql ) or die DBI->errstr, "\n";
     $sth->execute or die DBI->errstr, "\n";
     $sth->bind_columns( \$newval );
     $sth->fetch;
     $sth->finish;
     return $newval;
   }
   ###################################n########################################
   # get the next value of this sequence
   # ( used in collect_ext_id.pl, LO_DS* )
   sub get_next_val {
     my $sequence = shift;
      if ( ! $dbh ) {
	$dbh=$apiis->DataBase->dbh;
      }
     # print "Getting next value of sequence $sequence";
     my $sql = "select nextval ('$sequence')";
     my $sth = $dbh->prepare( $sql ) or die DBI->errstr, "\n";
     $sth->execute or die DBI->errstr, "\n";
     $sth->bind_columns( \$newval );
     $sth->fetch;
     $sth->finish;
     return $newval;
   }
   ######################################n########################################
   # set the new value of this sequence after inserting the records.
   # ( used in collect_ext_id.pl )
   # usage: set_next_val('sequencename');
   sub set_next_val {
     my $sequence = shift;
     my $newval = shift;
      if ( ! $dbh ) {
	$dbh=$apiis->DataBase->dbh;
      }
     # print "Setting next value of sequence $sequence";
     my $sql = "select setval('$sequence', $newval) from $sequence";
     my $sth = $dbh->prepare( $sql ) or die DBI->errstr, "\n";
     $sth->execute or die DBI->errstr, "\n";
     $sth->fetch;
     $sth->finish;
     return $newval;
   }
   ######################################n########################################

######################################################################
# sub inbreed
# get pedigree and return inbreeding coefficient      mostly subs [bf]
# used in info_ped.pl
######################################################################
#   usage: inbreed( $hash_ref, $unknown_animal ); or
#          inbreed( $hash_ref, $unknown_animal, 'st' );
#            's' = faster but much RAM needed
#              (for small populations with deep pedigree) see minipigs
#            't' = return also numerical sorted pedigree and translation ref
#   %inhash key = animal,
#           $hash{ animal }[0] = sire
#           $hash{ animal }[1] = dam
#           $hash{ animal }[2] = birth_dt
#           unknown parents 1 and 2 or "$unknown_animal"
#   return ( $hash_ref )
#   %outhash key = animal,
#            $hash{ animal }[0] = inbreeding coefficient (F)
#            $hash{ animal }[1] = birth_dt
#
#   if option t: return ( $hash_ref, $trans_ref, $trans_ref2 )
#            see $hash_ref
#
#            $trans{ new_animal }[0] = new_sire
#            $trans{ new_animal }[1] = new_dam
#
#            $trans2{ new_animal } = old_animal
#
# $d = 1; # debug
######################################################################
sub inbreed {
    my $href    = shift;
    my $unknown = shift;
    if (@_) {
        my $t = shift;
        if ( $t =~ /s/ ) {
            $s = 1;
            print "\nUse more ram to make the job faster (option -s)\n";
        }
        if ( $t =~ /t/ ) {
            $trans = 1;
        }
    }

    $us = "1";
    $ud = "2";
    if ($unknown) {
        $us = "$unknown";
        $ud = "$unknown";
    }

    %tree = ();
    my %in = %$href;
    foreach $ani ( keys %in ) {
        # if(@{$in{$ani}}<3){$in{$ani}[1]=$ud;}
        # if(@{$in{$ani}}<2){$in{$ani}[0]=$us;}
        $tree{$ani}[0] = 0;
        $tree{$ani}[1] = $in{$ani}[0];
        $tree{$ani}[2] = $in{$ani}[1];
        $tree{$ani}[3] = $in{$ani}[2] if ( $in{$ani}[2] );
    }

    # get possible sorting
    $tree{$us}[0] = 1;
    $tree{$us}[1] = $us;
    $tree{$us}[2] = $ud;
    $tree{$ud}[0] = 2;
    $tree{$ud}[1] = $us;
    $tree{$ud}[2] = $ud;
    complete();
    $num = 3;

    foreach $k ( keys %tree ) {
        align($k);
    }
    if ($d) {
        foreach $k ( keys %tree ) {
            print "$k -> $tree{$k}[0]\n";
        }
    }
    if ($trans) {
        tie %res_trans,  'Tie::IxHash';
        tie %res_trans2, 'Tie::IxHash';
        %res_trans  = ();
        %res_trans2 = ();
        # first write the relationships
        foreach $k ( sort { $tree{$a}[0] <=> $tree{$b}[0] } keys %tree ) {
            if ( $tree{$k}[1] ne $us || $tree{$k}[2] ne $ud ) {
                $res_trans{ $tree{$k}[0] }[0] = $tree{ $tree{$k}[1] }[0];
                $res_trans{ $tree{$k}[0] }[1] = $tree{ $tree{$k}[2] }[0];
            }
        }
        # now write the translation table (in numerical order)
        foreach $k ( sort { $tree{$a}[0] <=> $tree{$b}[0] } keys %tree ) {
            $res_trans2{ $tree{$k}[0] } = $k;
        }
    }
    delete $tree{$us};    # else deep recursion...
    delete $tree{$ud};

    %res = ();
    %ex  = ();            # giant hash to store some results #+#
    foreach $k ( keys %tree ) {
        $h = eintrag( $k, $k );
        #  if($h!=1.0) {
        $res{$k}[0] = $h - 1.0;
        $res{$k}[1] = $tree{$k}[3];
        #  }
    }

    if ($d) {
        foreach $k ( sort { $res{$a} <=> $res{$b} } keys %res ) {
            print "$k : $res{$k}\n";
        }
    }

    $tree_ref = \%res;
    #  use Data::Dumper; print "++++>" . Dumper(%in);

    if ($trans) {
        $ref2 = \%res_trans;
        $ref3 = \%res_trans2;
        return ( $tree_ref, $ref2, $ref3 );
    }
    else {
        return ($tree_ref);
    }
    # # # # # SUB-S U B S :-) # # # # # # # # # # # #
    sub align {    # using global %tree and $num
        my $key = shift;
        if ( $tree{$key}[0] == 0 ) {
            align( $tree{$key}[1] );
            align( $tree{$key}[2] );
            $tree{$key}[0] = $num++;
        }
    }

    sub eintrag {    # using global %tree
        my $i = shift;
        my $j = shift;
        # $i muss jünger sein
        if ( $tree{$i}[0] < $tree{$j}[0] ) {
            my $h = $i;
            $i = $j;
            $j = $h;
        }
        my $exk = $i . ',' . $j;    # key to save value in
        my $rr;
        if ( $s && defined $ex{$exk} ) {    # -s
            $rr = $ex{$exk};
            if ($d) { print "*$rr) "; }
            return ($rr);
        }

        if ($d) {
            print "($i,$j= ";
        }
        my $r;

        if ( $tree{$i}[1] eq $us ) {
            if ( $tree{$i}[2] eq $ud ) {    # beide Eltern unbekannt
                if ( $i eq $j ) {
                    $r = (1);
                }
                else {
                    $r = (0);
                }
            }
            else {                          # ein Elter unbekannt
                if ( $i eq $j ) {
                    $r = (1);
                }
                else {
                    $r = ( 0.5 * eintrag( $tree{$i}[2], $j ) );
                }
            }
        }
        else {                              # ein Elter unbekannt
            if ( $tree{$i}[2] eq $ud ) {
                if ( $i eq $j ) {
                    $r = (1);
                }
                else {
                    $r = ( 0.5 * eintrag( $tree{$i}[1], $j ) );
                }
            }
            else {                          # beide Eltern bekannt
                if ( $i eq $j ) {
                    $r = ( 1 + 0.5 * eintrag( $tree{$i}[1], $tree{$i}[2] ) );
                }
                else {
                    $r = (
                        0.5 * (
                                  eintrag( $tree{$i}[1], $j )
                                + eintrag( $tree{$i}[2], $j )
                        )
                    );
                }
            }
        }
        if ($d) {
            print "$r) ";
        }
        if ($s) { $ex{$exk} = $r; }    # save value
        return ($r);
    }

    sub complete {                     # completing %tree if necessary
        foreach $k ( keys %tree ) {
            if ( !exists $tree{ $tree{$k}[1] } ) {
                $tree{ $tree{$k}[1] }[0] = 0;
                $tree{ $tree{$k}[1] }[1] = $us;
                $tree{ $tree{$k}[1] }[2] = $ud;
                # print "unknown sire $k -> *$tree{$k}[1]*\n";
            }
            if ( !exists $tree{ $tree{$k}[2] } ) {
                $tree{ $tree{$k}[2] }[0] = 0;
                $tree{ $tree{$k}[2] }[1] = $us;
                $tree{ $tree{$k}[2] }[2] = $ud;
                # print "unknown dam $k -> *$tree{$k}[2]*\n";
            }
        }
    }
}    # inbreed

######################################################################
#   usage: completeness( $hash_ref, $unknown_animal, $level );
#          level means the deepness of pedigree (generations to check)
#   %inhash key = animal,
#           $hash{ animal }[0] = sire
#           $hash{ animal }[1] = dam
#           $hash{ animal }[2] = birth_dt
#           unknown parents 1 and 2 or "$unknown_animal"
#   return ( $hash_ref )
#   %outhash key = animal,
#            $hash{ animal }[0] = completeness in %
#            $hash{ animal }[1] = birth_dt
#            $hash{ animal }[2] = max. number of ancestors
#            $hash{ animal }[3] = number known ancestors
#
######################################################################
sub completeness {
    my $href    = shift;
    my $unknown = shift;
    my $level   = shift;

    $us = "1";
    $ud = "2";
    if ($unknown) {
        $us = "$unknown";
        $ud = "$unknown";
    }

    my %tree2 = ();
    my %in    = %$href;
    foreach $ani ( keys %in ) {
        # if(@{$in{$ani}}<3){$in{$ani}[1]=$ud;}
        # if(@{$in{$ani}}<2){$in{$ani}[0]=$us;}
        $tree2{$ani}[0] = 0;
        $tree2{$ani}[1] = $in{$ani}[0];
        $tree2{$ani}[2] = $in{$ani}[1];
        $tree2{$ani}[3] = $in{$ani}[2] if ( $in{$ani}[2] );
    }

    # get possible sorting
    $tree2{$us}[0] = 1;
    $tree2{$us}[1] = $us;
    $tree2{$us}[2] = $ud;
    $tree2{$ud}[0] = 2;
    $tree2{$ud}[1] = $us;
    $tree2{$ud}[2] = $ud;
    complete2();
    my $num = 3;

    foreach $k ( keys %tree2 ) {
        align2($k);
    }

    # # make sure '1' and '2' are not in the database
    if ( exists $tree2{'1'} ) { delete $tree2{'1'}; }
    if ( exists $tree2{'2'} ) { delete $tree2{'2'}; }

    my %res = ();

    $h = $level;
    $e = 2;
    while ( $h-- ) { $e *= 2; }
    $e -= 2;    # expected number of ancestors

    foreach $k ( keys %tree2 ) {
        $r = cntanc( $k, $level ) - 1;
        $res{$k}[0] = 100 * $r / $e;
        $res{$k}[1] = $tree2{$k}[3];
        $res{$k}[2] = $e;
        $res{$k}[3] = $r;
    }
    return \%res;

    ### subs ####
    sub align2 {    # using global %tree2 and $num
        my $key = shift;
        if ( $tree2{$key}[0] == 0 ) {
            align2( $tree2{$key}[1] );
            align2( $tree2{$key}[2] );
            $tree2{$key}[0] = $num++;
        }
    }

    sub complete2 {    # completing %tree2 if necessary
        foreach $k ( keys %tree2 ) {
            if ( !exists $tree2{ $tree2{$k}[1] } ) {
                $tree2{ $tree2{$k}[1] }[0] = 0;
                $tree2{ $tree2{$k}[1] }[1] = $us;
                $tree2{ $tree2{$k}[1] }[2] = $ud;
                print "unknown sire $k -> *$tree2{$k}[1]*\n";
            }
            if ( !exists $tree2{ $tree2{$k}[2] } ) {
                $tree2{ $tree2{$k}[2] }[0] = 0;
                $tree2{ $tree2{$k}[2] }[1] = $us;
                $tree2{ $tree2{$k}[2] }[2] = $ud;
                print "unknown dam $k -> *$tree2{$k}[2]*\n";
            }
        }
    }

    sub cntanc {
        my $a = shift;
        my $l = shift;
        if ( exists $tree2{$a} ) {
            if ( $l == 0 ) {
                return 1;
            }
            else {
                my $rr = 1 + cntanc( $tree2{$a}[1], $l - 1 )
                           + cntanc( $tree2{$a}[2], $l - 1 );
                return $rr;
            }
        }
    }
}    # completeness

sub genepart {
   ######################################################################
   #   usage: genepart( $hash_ref, $unknown_animal, $level, $initial );
   #          level means the deepness of pedigree (generations to check)
   #   %inhash key = animal,
   #           $hash{ animal }[0] = sire
   #           $hash{ animal }[1] = dam
   #           $hash{ animal }[2] = trait
   #           unknown parents 1 and 2 or "$unknown_animal"
   #   return ( $hash_ref )
   #   %outhash key = animal,
   #            $hash{ animal }{ 'max' }  = max. number of ancestors
   #            $hash{ animal }{ 'tot' }  = number known ancestors
   #            $hash{ animal }{ $trait } = number of ancestors for
   #                                        each given trait
   ######################################################################

    my $href = shift;
    my $unknown = shift;
    my $level = shift;
#     my $initial = shift;

    $us="1"; $ud="2";
    if ($unknown) {
	$us="$unknown"; $ud="$unknown";
    }

#     if ( $initial == 1 ) {
    %tree3=();
    %traits_in=();
    #my $num = 0;
#     }
    my %in = %$href;
    foreach $ani ( keys %in ) {
	# if(@{$in{$ani}}<3){$in{$ani}[1]=$ud;}
	# if(@{$in{$ani}}<2){$in{$ani}[0]=$us;}
	$tree3{$ani}[0]=0;
	$tree3{$ani}[1]=$in{$ani}[0];
	$tree3{$ani}[2]=$in{$ani}[1];
	$tree3{$ani}[3]=$in{$ani}[2] if ( $in{ $ani }[2] );
 	$traits_in{ $in{ $ani }[2] } += 1;
    }

    # get possible sorting
    $tree3{$us}[0]=1;
    $tree3{$us}[1]=$us;
    $tree3{$us}[2]=$ud;
    $tree3{$ud}[0]=2;
    $tree3{$ud}[1]=$us;
    $tree3{$ud}[2]=$ud;
    complete3();
    $num=3;
       foreach $k (keys %tree3) {
         align3($k);
       }

    # # make sure '1' and '2' are not in the database
    if(exists $tree3{'1'}){delete $tree3{'1'};}
    if(exists $tree3{'2'}){delete $tree3{'2'};}

    my %res=();

    $h=$level; $e=2; while($h--){$e*=2;} $e-=2; # expected number of ancestors

    foreach my $tr ( keys %traits_in ) {
	foreach $k ( keys %tree3 ) {
	    my $r = cntanct3( $k, $level, $tr );
	    $r = $r - 1 if ( $tree3{ $k }[3] eq $tr );
	    $r = 0 if ( $r == -1 );
	    $res{$k}{$tr}   = $r;
	    $res{$k}{'max'} = $e;
	    $res{$k}{'tot'} += $r;
	}
    }

    $tree3_ref = \%res;
    return ( $tree3_ref );

    ### subs ####
    sub align3 {			# using global %tree3 and $num
	my $key=shift;
	if ($tree3{$key}[0]==0) {
	    align3($tree3{$key}[1]);
	    align3($tree3{$key}[2]);
	    $tree3{$key}[0]=$num++;
	}
    }

    sub complete3 {		# completing %tree3 if necessary
	foreach $k (keys %tree3) {
	    if (!exists $tree3{$tree3{$k}[1]}) {
		$tree3{$tree3{$k}[1]}[0]=0;
		$tree3{$tree3{$k}[1]}[1]=$us;
		$tree3{$tree3{$k}[1]}[2]=$ud;
		print "unknown sire $k -> *$tree3{$k}[1]*\n";
	    }
	    if (!exists $tree3{$tree3{$k}[2]}) {
		$tree3{$tree3{$k}[2]}[0]=0;
		$tree3{$tree3{$k}[2]}[1]=$us;
		$tree3{$tree3{$k}[2]}[2]=$ud;
		print "unknown dam $k -> *$tree3{$k}[2]*\n";
	    }
	}
    }

    sub cntanct3 {
	my $a=shift;
	my $l=shift;
	my $t=shift;
 	if ( exists $tree3{$a} ) {
	    if ( $l == 0 ) {
		if ( $tree3{ $a }[3] eq $t ) {
		    return 1;
		} else {
		    return 0;
		}
	    } else {
		my $rr = 1 + cntanct3($tree3{$a}[1],$l-1,$t) + cntanct3($tree3{$a}[2],$l-1,$t);
		if ( $tree3{ $a }[3] ne $t ) {
		    $rr = $rr -1;
		}
		return $rr;
	    }
	}
	return 0;
    }
}				# genepart

sub same_gene {
    ######################################################################
    # compute the genetic influence from two given pedigrees to get an
    # idea about what comming if use the pops together (ex: for BLUPs)
    #
    #   eighter for an defined animal or the whole population
    #
    #   definition: common animal have 100%, the descendents than have
    #   .5 from this value.... recursively
    #   influence defined as avg( values ) for all animals in ped
    #
    #   usage: same_gene( $hash_ref_pop_a, $hash_ref_pop_b, '', $unknown_animal ) or
    #          same_gene( $hash_ref_pop_a, $hash_ref_pop_b, $animal, $unknown_animal )
    #            with animal get the information for an specific animal
    #
    #   two hash_references needed with the same structure
    #   %inhash key = animal,
    #           $hash{ animal }[0] = sire
    #           $hash{ animal }[1] = dam
    #           unknown parents 1 and 2 or "$unknown_animal"
    #   return ( @return )
    #            $return[0] = count animals in pop a
    #            $return[1] = count animals in pop b
    #            $return[2] = count animals in a and b
    #       if animal defined
    #            $return[3] = animal coming from pop a|b|common
    #            $return[4] = % common ancestors
    #       else for population
    #            $return[3] = % influence pop a by pop b
    #            $return[4] = % influence pop b by pop a
    #            $return[5] = % influence of merged pedigree
    #       allways
    #            $return[6] = \%hash_ref merged pedigree (popc)
    #
    # remarks: differences between the two pedigrees only given as
    # warning to STDERR and use the animal which is not unknown (if
    # both than from pop A)
    # small pop A total included in pop B than influence A by B 100%
    # but B by A is minimal; together same...
    #
    ######################################################################
    # if large number of only pedigree ancestors is filled in with no
    # traits, the real influence is overestimated but should not so
    # important for real pedigrees
    ######################################################################

    my $href_a = shift;
    my $href_b = shift;
    my $animal = shift;
    my $unknown = shift;

    my @ret = ();
    my %popa=(); my $cnta=0;
    my %popb=(); my $cntb=0;
    my %popc=(); my $cntcc=0;
    my %common=(); my $cntc=0;

    my $us="1"; my $ud="2";
    if ($unknown) {
	$us="$unknown"; $ud="$unknown";
    }

    my %in_a = %$href_a;
    foreach my $ani ( keys %in_a ) {
	$popa{$ani}[0]=-1;
	$popa{$ani}[1]=$in_a{$ani}[0];
	$popa{$ani}[2]=$in_a{$ani}[1];
	$popa{$ani}[3]=$in_a{$ani}[2] if ( $in{ $ani }[2] );
	$cnta++;
    }

    sanitize(\%popa,\$cnta);

    my %in = %$href_b;
    foreach my $ani ( keys %in ) {
	# if(@{$in{$ani}}<3){$in{$ani}[1]=$ud;}
	# if(@{$in{$ani}}<2){$in{$ani}[0]=$us;}
	$popb{$ani}[0]=-1;
	$popb{$ani}[1]=$in{$ani}[0];
	$popb{$ani}[2]=$in{$ani}[1];
	$popb{$ani}[3]=$in{$ani}[2] if ( $in{ $ani }[2] );
	$cntb++;
	# mark common animals in pedigree
	if (exists($popa{$ani})) {
	    $common{$ani} =1;
	    $popa{$ani}[0]=1;
	    $popb{$ani}[0]=1;
	    $cntc++;
	}
    }

    sanitize(\%popb,\$cntb);

    $ret[0] = $cnta;
    $ret[1] = $cntb;
    $ret[2] = $cntc;

    # reintroduce '1' and '2' as non common animals
    $popa{$us}[0]=0; $popa{$ud}[0]=0;
    $popb{$us}[0]=0; $popb{$ud}[0]=0;

    # create popc as merged pedigree for both
    my $total_differences = 0; #some statistics
    my $unk_sirea = 0;
    my $unk_sireb = 0;
    my $unk_dama = 0;
    my $unk_damb = 0;
    my $diff_sire_and_dam = 0;
    my $diff_sire = 0;
    my $diff_dam = 0;
    my %both_sire = ();
    my %both_dam = ();
    my %diff_a_b = ();

    foreach my $ani ( keys %popa ) {
	if (  $popb{ $ani } ) {
	    # different sire AND dam in both peds
	    if ( $popa{ $ani }[1] ne $popb{ $ani }[1] and $popa{ $ani }[2] ne $popb{ $ani }[2] ) {
		$total_differences += 1;
		$diff_sire_and_dam += 1;
		$unk_sirea += 1 if ( $popa{ $ani }[1] eq $us );
		$unk_sireb += 1 if ( $popb{ $ani }[1] eq $us );
		$unk_dama += 1 if ( $popa{ $ani }[2] eq $ud );
		$unk_damb += 1 if ( $popb{ $ani }[2] eq $ud );
                if ( $popa{ $ani }[1] ne $us and $popb{ $ani }[1] ne $us ) {
		    $both_sire{ $popa{ $ani }[1] } += 1;
		    $diff_a_b{ $popa{ $ani }[1] } = $popb{ $ani }[1];
		}
                if ( $popa{ $ani }[2] ne $ud and $popb{ $ani }[2] ne $ud ) {
		    $both_dam{ $popa{ $ani }[2] } += 1;
		    $diff_a_b{ $popa{ $ani }[2] } = $popb{ $ani }[2];
		}

		if ( $popa{ $ani }[1] ne $us ) {
		    print "different sire in pedigree for animal $ani ( $popa{ $ani }[1] <-> $popb{ $ani }[1] )! use value from pop A\n";
		    $popc{ $ani }[0] =  $popa{ $ani }[0];
		    $popc{ $ani }[1] =  $popa{ $ani }[1];
		} else {
		    print "different sire in pedigree for animal $ani ( $popa{ $ani }[1] <-> $popb{ $ani }[1] )! use value from pop B\n";
		    $popc{ $ani }[0] =  $popb{ $ani }[0];
		    $popc{ $ani }[1] =  $popb{ $ani }[1];
		}
		if ( $popa{ $ani }[2] ne $ud ) {
		    print "different dam in pedigree for animal $ani ( $popa{ $ani }[2] <-> $popb{ $ani }[2] )! use value from pop A\n";
		    $popc{ $ani }[2] =  $popa{ $ani }[2];
		} else {
		    print "different dam in pedigree for animal $ani ( $popa{ $ani }[2] <-> $popb{ $ani }[2] )! use value from pop B\n";
		    $popc{ $ani }[2] =  $popb{ $ani }[2];
		}
	    } # different sire (only)
	    elsif ( $popa{ $ani }[1] ne $popb{ $ani }[1] ) {
		$total_differences += 1;
		$diff_sire += 1;
		$unk_sirea += 1 if ( $popa{ $ani }[1] eq $us );
		$unk_sireb += 1 if ( $popb{ $ani }[1] eq $us );
                if ( $popa{ $ani }[1] ne $us and $popb{ $ani }[1] ne $us ) {
		    $both_sire{ $popa{ $ani }[1] } += 1;
		    $diff_a_b{ $popa{ $ani }[1] } = $popb{ $ani }[1];
		}

		if ( $popa{ $ani }[1] ne $us ) {
		    print "different sire in pedigree for animal $ani ( $popa{ $ani }[1] <-> $popb{ $ani }[1] )! use value from pop A\n";
		    $popc{ $ani }[0] =  $popa{ $ani }[0];
		    $popc{ $ani }[1] =  $popa{ $ani }[1];
		    $popc{ $ani }[2] =  $popa{ $ani }[2];
		} else {
		    print "different sire in pedigree for animal $ani ( $popa{ $ani }[1] <-> $popb{ $ani }[1] )! use value from pop B\n";
		    $popc{ $ani }[0] =  $popb{ $ani }[0];
		    $popc{ $ani }[1] =  $popb{ $ani }[1];
		    $popc{ $ani }[2] =  $popb{ $ani }[2];
		}
	    } # different dam (only)
	    elsif ( $popa{ $ani }[2] ne $popb{ $ani }[2] ) {
		$total_differences += 1;
		$unk_dama += 1 if ( $popa{ $ani }[2] eq $ud );
		$unk_damb += 1 if ( $popb{ $ani }[2] eq $ud );
                if ( $popa{ $ani }[2] ne $ud and $popb{ $ani }[2] ne $ud ) {
		    $both_dam{ $popa{ $ani }[2] } += 1;
		    $diff_a_b{ $popa{ $ani }[2] } = $popb{ $ani }[2];
		}

		if ( $popa{ $ani }[2] ne $ud ) {
		    print "different dam in pedigree for animal $ani ( $popa{ $ani }[2] <-> $popb{ $ani }[2] )! use value from pop A\n";
		    $popc{ $ani }[0] =  $popa{ $ani }[0];
		    $popc{ $ani }[1] =  $popa{ $ani }[1];
		    $popc{ $ani }[2] =  $popa{ $ani }[2];
		} else {
		    print "different dam in pedigree for animal $ani ( $popa{ $ani }[2] <-> $popb{ $ani }[2] )! use value from pop B\n";
		    $popc{ $ani }[0] =  $popb{ $ani }[0];
		    $popc{ $ani }[1] =  $popb{ $ani }[1];
		    $popc{ $ani }[2] =  $popb{ $ani }[2];
		}
	    } # no differences
	    else {
		$popc{ $ani }[0] =  $popa{ $ani }[0];
		$popc{ $ani }[1] =  $popa{ $ani }[1];
		$popc{ $ani }[2] =  $popa{ $ani }[2];

	    }
	} # not in pop B
	else {
	    $popc{ $ani }[0] =  $popa{ $ani }[0];
	    $popc{ $ani }[1] =  $popa{ $ani }[1];
	    $popc{ $ani }[2] =  $popa{ $ani }[2];
	}
    }

    # add missing from pop B
    foreach my $ani ( keys %popb ) {
	if ( ! $popc{ $ani } ) {
	    $popc{ $ani }[0] =  $popb{ $ani }[0];
	    $popc{ $ani }[1] =  $popb{ $ani }[1];
	    $popc{ $ani }[2] =  $popb{ $ani }[2];
	}
    }

    # statistics used ped
    print STDOUT "\nSTATISTIC for PEDIGREES\n";
    print STDOUT "total differences in pedigree: $total_differences\n";

    print STDOUT "differences sire and dam: $diff_sire_and_dam\n";
    print STDOUT "differences only sire: $diff_sire\n";
    print STDOUT "differences only dam: $diff_dam\n";

    print STDOUT "unknown sires pop a: $unk_sirea\n";
    print STDOUT "unknown sires pop b: $unk_sireb\n";
    print STDOUT "unknown dams pop a: $unk_dama\n";
    print STDOUT "unknown dams pop b: $unk_damb\n";

    print STDOUT "differences in both pops (sires): " .scalar ( keys %both_sire )."\n";
    print STDOUT "differences in both pops (dams): " .scalar ( keys %both_dam )."\n";
    print STDOUT "\t these are:\n";
    foreach my $ani ( keys %diff_a_b ) {
    print STDOUT "$ani <-> $diff_a_b{ $ani }\n";
    }

    $cntcc = scalar( keys %popc );
    # should not happen!
    sanitize(\%popc,\$cntcc);


    # check for loops
    my %testpopa = ();
    for my $ani ( keys %popa ) {
	$testpopa{ $ani }[0] = $popa{ $ani }[1];
	$testpopa{ $ani }[1] = $popa{ $ani }[2];
    }

    my $href_in = \%testpopa;
    my @erg = ();
    @erg = testloop( $href_in, '', '1' );
    if ( scalar @erg == 0 ) {
	print "\n Congratulation, your pedigree I looks fine!\n\n";
    } else {
	print "\n the following loops are inside (ped I):\n";

	foreach my $x (@erg) {
	    my @ergpart = split( '->', $x );
	    my $c       = 0;
	    my $first   = $ergpart[0];
	    foreach my $y (@ergpart) {
		$c++;
		if ( $y ne $first or $c == 1 ) {
		    print "$y -> ";
		} else {
		    print "$y\n\n";
		}
		if ( $c == 2 ) {
		    # fix pedigree
		    if ( $y == $popa{ $first }[1]  ) {
			$popa{ $first }[1] = '1';
		    }
		    if ( $y == $popa{ $first }[2]  ) {
			$popa{ $first }[2] = '2';
		    }
		}
	    }
	}
	print ".... and fixed\n";
    }

    my %testpopb = ();
    for my $ani ( keys %popb ) {
	$testpopb{ $ani }[0] = $popb{ $ani }[1];
	$testpopb{ $ani }[1] = $popb{ $ani }[2];
    }
    my $href_inb = \%testpopb;
    my @ergb = ();
    @ergb = testloop( $href_inb, '', '1' );
    if ( scalar @ergb == 0 ) {
	print "\n Congratulation, your pedigree II looks fine!\n\n";
    } else {
	print "\n the following loops are inside (ped II):\n";

	foreach my $x (@ergb) {
	    my @ergpart = split( '->', $x );
	    my $c       = 0;
	    my $first   = $ergpart[0];
	    foreach my $y (@ergpart) {
		$c++;
		if ( $y ne $first or $c == 1 ) {
		    print "$y -> ";
		} else {
		    print "$y\n\n";
		}
		if ( $c == 2 ) {
		    # fix pedigree
		    if ( $y == $popb{ $first }[1]  ) {
			$popb{ $first }[1] = '1';
		    }
		    if ( $y == $popb{ $first }[2]  ) {
			$popb{ $first }[2] = '2';
		    }
		}
	    }
	}
	print ".... and fixed\n";
    }

    my %testpopc = ();
    for my $ani ( keys %popc ) {
	$testpopc{ $ani }[0] = $popc{ $ani }[1];
	$testpopc{ $ani }[1] = $popc{ $ani }[2];
    }
    my $href_inc = \%testpopc;
    my @ergc = ();
    @ergc = testloop( $href_inc, '', '1' );
    if ( scalar @ergc == 0 ) {
	print "\n Congratulation, your total pedigree looks fine!\n\n";
    } else {
	print "\n the following loops are inside (ped total):\n";
	foreach my $x (@ergc) {
	    my @ergpart = split( '->', $x );
	    my $c       = 0;
	    my $first   = $ergpart[0];
	    foreach my $y (@ergpart) {
		$c++;
		if ( $y ne $first or $c == 1 ) {
		    print "$y -> ";
		} else {
		    print "$y\n\n";
		}
		if ( $c == 2 ) {
		    # fix pedigree
		    if ( $y == $popc{ $first }[1]  ) {
			$popc{ $first }[1] = '1';
		    }
		    if ( $y == $popc{ $first }[2]  ) {
			$popc{ $first }[2] = '2';
		    }
		}
	    }
	}
	print ".... and fixed\n";
    }
    # use Data::Dumper; print "++++".Dumper(%testpop)."<+++\n";

    ##################################################################
    # computations for one specific animal
    if ( $animal ) {
	if ( exists( $common{$animal} ) ) {
	    $ret[3] = 'common';
	    #print "animal $animal is a common animal\n";
	    # exit;
	} elsif ( exists( $popa{$animal} ) ) {
	    $ret[3] = 'pop A';
	    #print "animal $animal belongs to population A\n";
	    $popr=\%popa;
	} elsif (exists( $popb{$animal} ) ) {
	    $ret[3] = 'pop B';
	    #print "animal $animal belongs to population B\n";
	    $popr=\%popb;
	} else {
	    die "*E* animal $animal is unknown\n";
	}
	$r = commonpart( $animal, $popr );
	$r = 1 if ( $ret[3] eq 'common' );
	$ret[4] = $r*100;
	#printf "and has %.2f %% common ancestors\n", $r*100;
    }
    ##################################################################
    # computations for whole populations
    else {
	$ca=0;
	for my $a (keys %popa) {
	    my $cc = commonpart($a,\%popa);
	    $ca += $cc;
	    # hash mit allen werten sichern?
	    # print "++>$a..$cc....$ca......$cnta<++\n";
	}
	# sum genetic part of common ancestors / count animals
	$ca/=$cnta;
	$ret[3] = $ca*100;
	#printf "population A is %.2f %% influenced by population B\n",$ca*100;
	$cb=0;
	for my $a (keys %popb) {
	    $cb+=commonpart($a,\%popb);
	}
	$cb/=$cntb;
	$ret[4] = $cb*100;
	#printf "population B is %.2f %% influenced by population A\n",$cb*100;
	$cc=0;
	for my $a (keys %popc) {
	    $cc+=commonpart($a,\%popc);
	}
	$cc/=$cntcc;
	$ret[5] = $cc*100;
    }

    $ret[6] = \%popc;

    ##################################################################
    # sanitize a population tree
    # same as complete with hash as argument # rffr change this later!
    sub sanitize{
	my $href=shift;
	my $cref=shift;
	# make sure all mentioned animals appear as keys
	for my $i (keys %$href) {
	    if (!exists($$href{$$href{$i}[1]}) && $$href{$i}[1] ne '1') {
		#print STDERR "*W* comleting data for $$href{$i}[1]\n";
		$$href{$$href{$i}[1]}[0]=-1;
		$$href{$$href{$i}[1]}[1]=$us;
		$$href{$$href{$i}[1]}[2]=$ud;
		$$cref++;
	    }
	    if (!exists($$href{$$href{$i}[2]}) && $$href{$i}[2] ne '2') {
		#print STDERR "*W* comleting data for $$href{$i}[2]\n";
		$$href{$$href{$i}[2]}[0]=-1;
		$$href{$$href{$i}[2]}[1]=$us;
		$$href{$$href{$i}[2]}[2]=$ud;
		$$cref++;
	    }
	}
	# make sure $us ('1') and $ud ('2') do not belong to the
	# population
	if (exists $$href{$us}) {
	    delete $$href{$us}; $$cref--;
	}
	if (exists $$href{$ud}) {
	    delete $$href{$ud}; $$cref--;
	}
    }

    ##################################################################
    # compute (and remember) common influence                     [bf]
    # common animals have on pos 0->1 else -1 see hash building
    # value > 0 always computed
    # generally the sum of half of the values from the ancestors
    ##################################################################
    sub commonpart {
	my $a=shift;
	my $hr=shift;
	if ($$hr{$a}[0]<0) {	# we have to compute it
	    $$hr{$a}[0]=0.5*commonpart($$hr{$a}[1],$hr)
	      +0.5*commonpart($$hr{$a}[2],$hr);
	} # else allways computed
	# print STDERR "*x* $a: $$hr{$a}[0]\n";
	return $$hr{$a}[0];
    }
    return ( @ret );
}				# same gene

########################################################################
# testloop                                                     subs [bf]
# used in print_pedigree_loops.pl
########################################################################
#   usage: testloop( $hash_ref, $unknown_animal, initial );
#       initial = 1
#       means set the variables back (this is not always possible
#       because recursion...)
#   %inhash key = animal,
#           $hash{ animal }[0] = sire
#           $hash{ animal }[1] = dam
#           $hash{ animal }[2] = birth_dt ( optional )
#           unknown parents 1 and 2 or "$unknown_animal"
#   return ( @ret ) array with animals concatenated with '->'
#            ex:  @ret = ("a->b->c->a", "d->d")
########################################################################
sub testloop {
    my $href = shift;
    my $unknown = shift;
    my $initial = shift;

    if ( $initial == 1 ) {
	    %tree = ();
	    @ret_ges = ();
    }

    %tree = %$href;
    my @ret = ();
    my %rethash = ();
    my $k = (); my $l = ();

    if ($unknown) {
	    $tree{"$unknown"}[4]=2;
    } else {
	    $tree{"1"}[4]=2; 
        $tree{"2"}[4]=2;
    }

    foreach my $k (keys %tree) {
	    test($k);
    }
    
    sub test {	                # using global variables %tree and @path
	# $tree{$node}[4]= 0 - unknown
	#                  1 - under investigation
	#                  2 - clear
	my $node=shift;
	if (!exists($tree{$node}) || $tree{$node}[4]==2) {
	    return;
	}
	if ($tree{$node}[4]==1) { # now we have a problem
	    push @ret, $node;
	    # print "loop are: $node ";
	    my $l = @path-1;
	    while ($path[$l] ne $node) {
		push @ret, $path[$l];
		# print "-> $path[$l] ";
		$l--;
	    }
	    push @ret, $node;
	    my $str = join( '->', @ret );
	    push @ret_ges, $str;
	    @ret = ();
	    # print "-> $node\n";
	} else {		# $tree{$node}[0]==0
	    $tree{$node}[4]=1; 
        push(@path,$node);
	    test($tree{$node}[0]);
	    test($tree{$node}[1]);
	    $tree{$node}[4]=2; pop(@path);
	}
    }				#end test
    return ( @ret_ges );

}				# test_loop

########################################################################
# testloop                                                     subs [bf]
# used in print_pedigree_loops.pl
########################################################################
#   usage: testloop( $hash_ref, $unknown_animal, initial );
#       initial = 1
#       means set the variables back (this is not always possible
#       because recursion...)
#   %inhash key = animal,
#           $hash{ animal }[0] = sire
#           $hash{ animal }[1] = dam
#           $hash{ animal }[2] = birth_dt ( optional )
#           unknown parents 1 and 2 or "$unknown_animal"
#   return ( @ret ) array with animals concatenated with '->'
#            ex:  @ret = ("a->b->c->a", "d->d")
########################################################################
sub testloop_array {
    my $href = shift;
    my $unknown = shift;
    my $initial = shift;

    if ( $initial == 1 ) {
	    %tree = ();
	    @ret_ges = ();
    }

    my @ret = ();
    my %rethash = ();
    my $k = (); 
    my $l = ();

    if ($unknown) {
	    $href->[0]->[4]=2;
    } else {
	    $href->[1]->[4]=2; 
        $href->[2]->[4]=2;
    }

    for (my $j=3; $j<=$#{$href};$j++) {

        if ($href->[$j]) {

	       test( $j );
        }
    }
    
    sub test {	                # using global variables %tree and @path
	    # $tree{$node}[4]= 0 - unknown
	    #                  1 - under investigation
	    #                  2 - clear
	    my $node=shift;
        return if !defined $href->[$node];

        my @vped=split(';',$href->[$node]);

        #-- nicht existent oder in Ordnung 
        return if $vped[4]==2;

        # now we have a problem
	    if ($vped[4]==1) { 
    
            #-- save db_animal with problem 
	        push @ret, $node;

    	    # print "loop are: $node ";
	        my $l = @path-1;
	    
            while ($path[$l] ne $node) {
	    	    push @ret, $path[$l];
		        # print "-> $path[$l] ";
		        $l--;
    	    }
	    
            push @ret, $node;
	    
            my $str = join( '->', @ret );
	    
            push @ret_ges, $str;
	        @ret = ();
    	    # print "-> $node\n";
	    } 
        else {		# $tree{$node}[0]==0
	        $vped[4]=1; 
            $href->[$node]=join(';',@vped);
            
            push(@path,$node);
    	    test($vped[0]);
	        test($vped[1]);

	        $vped[4]=2;
            
            $href->[$node]=join(';',@vped);
            
            pop(@path);
	    }
    }	
    #end test
    
    return ( @ret_ges );
}				# test_loop


#######################################################################
# testbd                                                     subs [bf]
########################################################################
#   usage: testbd( $hash_ref, $unknown_animal );
#   %inhash key = animal,
#           $hash{ animal }[0] = sire
#           $hash{ animal }[1] = dam
#           $hash{ animal }[2] = birth_dt ( optional )
#           unknown parents 1 and 2 or "$unknown_animal"
#   return ( @bderr ) array with animals id with wrong birth_dt
########################################################################
sub testbd {
  my $href = shift;
  my $unknown = shift;
  my %tree = %$href;
  my %bderr = ();
  
  foreach $d (keys %tree) {
     $tree{$d}[4] = 0;
  }
       
  if ($unknown) {
  $tree{"$unknown"}[4]=2;
  } else {
  $tree{"1"}[4]=2; $tree{"2"}[4]=2;
  }
  foreach $k (keys %tree) {
   testbd2($k); 
  }
  
  sub testbd2{                       # using global variables %tree 
  # $tree{$node}[4]= 0 - unknown
  #                  1 - under investigation
  #                  2 - clear
  my $node=shift;
  if (!exists($tree{$node}) || $tree{$node}[4]==2) {
  return;
  }
# check for birth_dt of parents and the animal
  if ($tree{$node}[2]) {  #only if birth_dt is notnull
    if ($tree{$tree{$node}[0]}[2]) {
        if ( ($tree{$tree{$node}[0]}[2]) ge ($tree{$node}[2])) {
	$bderr{$node}[0] = "sire";  #error with birth_dt of sire
	}
	}
	if ($tree{$tree{$node}[1]}[2]) {
	if ( ($tree{$tree{$node}[1]}[2]) ge ($tree{$node}[2])) {
        $bderr{$node}[1] = "dam"; #error with birth_dt of dam
      }
      }
  }
}  #testbd2

return ( %bderr );
}   #  testbd

#######################################################################
#pedanalys - a modul for completeness of pedigree data 
#usage: pedanalys( $hash_ref, $unknown_animal );
#   %inhash key = animal,
#           $hash{ animal }[0] = sire
#           $hash{ animal }[1] = dam
#           $hash{ animal }[2] = birth_dt ( optional )
#           unknown parents 1 and 2 or "$unknown_animal"
#   return ( @compl ) with animals id, coefficient of completeness
#######################################################################
sub pedanalys {
  my $href = shift;
  my $unknown = shift;
  %tree = %$href;
  @ret = ();
  %rethash = ();
  
  if ($unknown) {
   $tree{"$unknown"}[4]=2;
  } else {
   $tree{"1"}[4]=2; $tree{"2"}[4]=2;
  }
  foreach $k (keys %tree) {
   test($k);
  }
  sub testped{                       # using global variables %tree and @path

  # $tree{$node}[4]= 0 - unknown
  #                  1 - under investigation
  #                  2 - clear
  my $node=shift;
  if (!exists($tree{$node}) ||  $tree{$node}[4]==2) {
    return;
   }
  if ($tree{$node}[4]==1) {	# now we have a problem
    push @ret, $node;
    # print "loop are: $node ";
    $l=@path-1;
    while ($path[$l] ne $node) {
      push @ret, $path[$l];
      # print "-> $path[$l] ";
      $l--;
    }
    push @ret, $node;
    my $str = join( '->', @ret );
    push @ret_ges, $str;
    @ret = ();
    # print "-> $node\n";
  } else {			# $tree{$node}[0]==0
    $tree{$node}[4]=1; push(@path,$node);
    test($tree{$node}[0]);
    test($tree{$node}[1]);
    $tree{$node}[4]=2; pop(@path);
  }
}  #end test

return ( @ret_ges );

} # pedanalys  is nor ready, just copied from testloop:)

#######################################################################
#sub generations 
#calculating generation for all animals starting with youngest 
#   input file: animal, sire, dam
#   ouput file: input + added number of generation
# remark : it is fast for a real small data set else it is slow :(
#######################################################################
sub generations {
  my $href = shift;
  %tree = %$href;
  
  $tree{"1"}[4]=2; 
  $tree{"2"}[4]=2;
  $gensire=0;
  $gendam=0;
#foreach $k ( keys %tree) { 
#print "$k\n";
#print "$tree{$k}[0]\n";
#print "$tree{$k}[1]\n";
#print "$tree{$k}[2]\n";
#}

  foreach $k (keys %tree) {
  print "!!!!!k:$k\n"; 
   $anc = 0;
   $numdam=0;
   $numsire=0;
#   $depth=0;
   $a=0;
   $side='';
   testgen($k);
   $ancestors{$k}[0] = $anc-1; #if an ancestor is founder $anc=0
   print "generation:$tree{$k}[3]\n" if  defined $tree{$k}[3];
   print "founder->number of ancestors in pedigree: $anc-1\n";
   print "sire:ancestors $numsire\n";
   print "dam:ancestors $numdam\n";
}

  sub testgen{    # using global variables %tree 
  my $node=shift;
  print "***node:$node\n";
  if (!exists($tree{$node}) || ($node==1) || ( $node==2) ) {
    return;
   }
  
  if ( $tree{$node}[3]==0 ) {
    $tree{$node}[3]=1;
    }
    if ( $tree{$node}[1] ne 2 ) {  #dam generation
    $gendam=$tree{$node}[3]+1;
    $numdam=$numdam+1;
    if ( $gendam gt $tree{$tree{$node}[1]}[3] ) {
    $tree{$tree{$node}[1]}[3]=$gendam;
    }
    }
  if ( $tree{$node}[0] ne 1 ) {  #sire generation
    $gensire=$tree{$node}[3]+1;
    $numsire=$numsire+1;
    if ( $gensire gt $tree{$tree{$node}[0]}[3] ) {
    $tree{$tree{$node}[0]}[3]=$gensire;
    }
    }
    $anc++; # number of nodes invoked with node $k,known ancestors of $k
    testgen($tree{$node}[0]); # test of the sire
    testgen($tree{$node}[1]); # test of the dam
    #$tree{$node}[4]=2; 
  }
 #end test for generations

return ( %tree );

} # generations

##################################################################
#sub meuw , using meuwisen algorithme for calcualting inbreediing
##################################################################
sub meuw {
 my $href = shift;
   %tree = %$href;

#$nma=max db_animal, animals number is $c
#$nmi=min danimal
my @ped; # size [1 .. 2, 1 .. $c] ped[1][i] -sire , and ped[2][i] dam
my @point; # size [1 .. $c] point[i] the next oldest ancestor, =0 is the last 

my @f; #[ 0 .. $c] inbreeding coefficients, f[0]=-1
my @l; #[ 1 .. $c] elem. lij of matrix L
my @d; #[ 1 .. $c]

#replace db_sire=1 and db_dam=2 with 0
foreach $k ( keys %tree ) {
   if ( $tree{$k}[0] == 1 ) {
   $tree{$k}[0] = 0;
   }
   if ( $tree{$k}[1] == 2 ) {
      $tree{$k}[1] = 0;
   }   
  }

#foreach $k ( sort keys %tree) {
#      if ( $tree{$k}[0] == 1 ) {
#      print "$k \n"; }
#      if ( $tree{$k}[1] == 2 ) {
#      print "$k \n"; 
#      }
#}

$k = 0; #counter of new animal id

#loop for renumbering animals, each animal takes new id after his parents
#new id goes in $tree{$i}[3]

until ( $k eq $c ) {

   for $i ( $nmi .. $nma ) {
#   print "i=$i,  $tree{$i}[3] ";
    if ( $tree{$i}[3] eq 0) {
      if ( ($tree{$i}[0] eq 0) or ($tree{$tree{$i}[0]}[3] ne 0 ) ) {
      if ( ($tree{$i}[1] eq 0) or ($tree{$tree{$i}[1]}[3] ne 0 ) ) {
	$k ++;
	$tree{$i}[3] = $k;
#	print "db_animal ($i), nowa $tree{$i}[3], $k \n";
      } 
      }
    }
   }
} 

$kk = $k;
#$kk, $c keep the max new id!
# sire and dam new ids in ped file
foreach $i ( keys %tree) {
if ( $tree{$i}[0] == 0 ) { 
     $ped[1][$tree{$i}[3]] = 0;  #unknown sire
   } else {  
   $ped[1][$tree{$i}[3]] = $tree{$tree{$i}[0]}[3]; # sire to @ped
}
if ( $tree{$i}[1] == 0 ) {
     $ped[2][$tree{$i}[3]]=0;  #unknown dam
     } else {
   $ped[2][$tree{$i}[3]]=$tree{$tree{$i}[1]}[3]; # dam to @ped	
}
#if ( ( $tree{$i}[3] <= $ped[1][$tree{$i}[3]] ) || ( $tree{$i}[3] <= $ped[2][$tree{$i}[3]] )) {
#print "a: $tree{$i}[3], $ped[1][$tree{$i}[3]], $ped[2][$tree{$i}[3]] \n";
#}
}

#check if there are animals with wrong new ids
foreach $i ( sort {$tree{$a}[3] <=> $tree{$b}[3]} keys %tree ) {
   if ( $tree{$i}[3] <= $ped[1][$tree{$i}[3]] or $tree{$i}[3] <= $ped[2][$tree{$i}[3]] ) {
   print "Problems with pedigree: \n";
   print "animal:$i, $tree{$i}[3] , sire: $ped[1][$tree{$i}[3]], dam: ped[2][$tree{$i}[3]]\n";
   }
$point[$i] = 0; 
}


$f[0]=-1; #
$ninbr = 0;

for $i ( 1 .. $c ) {
    $is = $ped[1][$i];
    $id = $ped[2][$i];
    if ( $id gt $is ) {   # $ped[1][$i] must be > $ped[2][$i]
    $ped[1][$i] = $id;
    $ped[2][$i] = $is;
    }
#    print"i: $i\n";
#    print "si: $is\n";
#    print "di: $id\n";
#    print "1: $f[$is]\n";
#    print "2: $f[$id]\n";
    $d[$i] = 0.5-0.25*($f[$is]+$f[$id]); #within family variance
#    print "d:$d[$i]\n";
    if ( ( $is == 0 ) or ( $id == 0 ) ) { # the animal with unknown parents
    $f[$i] = 0.0;
    } else {
       if ( ($ped[1][$i-1] eq $ped[1][$i]) and ($ped[2][$i-1] eq $ped[2][$i]) ) {
           $f[$i] = $f[$i-1];    # the animal $i has sibs $i-1 
       } else {
          $np = 0;
          $fi = -1.0;           # start with diagional of matrix A 
          $l[$i] = 1.0;         # inicialise row of L 
          $j = $i;              # $j - oldest ansestors of $i 
          while ( $j != 0 ) {   # stop when list of ancestors is empty
             $k = $j;           # $k temp variable
             $r = 0.5*$l[$k];   # conribution to parents
             $ks = $ped[1][$k]; # take sire of ancestors
             $kd = $ped[2][$k]; # take dam of ancestors
             if ( $ks > 0 ) {   # find slot in link list for sire
	       while ( $point[$k] > $ks ) { # stop=next is older or sire
                 $k = $point[$k];
               }
               $l[$ks] += +$r; # add contribution to sire
               if ( $ks != $point[$k] ) { # include sire in link list
                  $point[$ks] = $point[$k];# point[$ks]=next ancestor in list
                  $point[$k] = $ks;  # point[previous ancestor]=sire
               }
             if ( $kd > 0 ){  # the same for the dam
               while ( $point[$k] > $kd) {
                 $k=$point[$k];
                }
               $l[$kd] += +$r;
               if ( $kd != $point[$k] ) {
                $point[$kd] = $point[$k];
                $point[$k] = $kd;
               }
             }
	  }
#         print "fi: $fi ";
#	  print "lj: $l[$j] ";
#	  print "dj: $d[$j] \n";
	  
	  $fi=$fi+$l[$j]*$l[$j]*$d[$j]; # add L*D*L value of animal j
          $l[$j] = 0.0;   # clear l for next F
          $k = $j;        # old j in k
          $j = $point[$j];# new j=next oldest animal in list
          $point[$k] = 0; # cleat point[old j] for next F
          $np = $np+1;
       }
     $f[$i]=$fi;          # F in array f
#    if ($fi gt 0.000001 ) { $ninbr = $ninbr+1; }
#    if ( $np gt 200) { $np = 200; }
    }

  }
}
foreach $k ( keys %tree) {
     $tree{$k}[4]= $f[$tree{$k}[3]];
     print "an: $k, inbr: $tree{$k}[4]\n";
       }
			
return ( %tree ); # the [4] element is inbreeding 
} # end of meuw 

########################################################################
# sub getdate( external date )
# return ( formated date, status, err_msg )
# only the following dates are possible:
#     3 799  -> 3-Juli-1999
#     12 799 -> 12-Juli-1999; 121299 -> 12-Dezember-1999
#     [12.07.99|12-07-99|12:07:99] -> 12-Juli-1999
# or using a format as second parameter like 'dd.mm.jjjj or 'yyy.tt.mm' or 'ttmmjj' and so on )
#    getdate('19984/02','yyyymm/tt') => 2-April-1998
########################################################################
=pod

=head1 usage

getdate(date) or getdate(date, format)

=head1 return

 formated date, status, err_msg

=head1 description

getdate should be simplify the handling of dates in incomming
datastreams.

only the following dates are possible:

=over

=item 3 799 ->3-Juli-1999

=item 12 799 -> 12-Juli-1999

=item 121299 -> 12-Dezember-1999

=item [12.07.99|12-07-99|12:07:99] -> 12-Juli-1999

=back

or using a format as second parameter like 'dd.mm.jjjj or 'yyy.tt.mm'
or 'ttmmjj' and so on

getdate('19984/02','yyyymm/tt') => 2-April-1998

=cut
########################################################################
  sub getdate {
    my $date = shift; # date_format from apiisrc
    my $format= shift;
    my $status = 1;
    my $err_msg;
    my @all_errors;
    return ( undef, 0, \@all_errors ) if ( ! $date or $date eq '' );

    #um--- when user gives a format
    my ($d,$m,$y);
    if ($format) {
      my $i=-1;
      my @date=split('|',$date);
      foreach my $dd (split /|/,lc($format)) {
        $i++;
	next if ($i > $#date);
        next if ($dd=~/[\.\/]/);
        #--- wenn datum nicht exakt dem Format entspricht 1.1.1999 = dd.mm.yyyy
        if ($date[$i]=~/[\.\/]/) {
          $i--;
          next;
        }
        $d.=$date[$i] if ($dd=~/[dt]/);
        $m.=$date[$i] if ($dd=~/[m]/);
        $y.=$date[$i] if ($dd=~/[yj]/);
      }
      #---mu
    } else {
      $date =~ s/(..).(..).(..)/$1$2$3/ if length( $date ) == 8;
      $date =~ s/(..)(..)(..)/$1$2$3/ if length( $date ) == 6;
      $date =~ s/(.)(..)(..)/$1$2$3/ if length( $date ) == 5;
      if ( length( $date ) < 5 or length( $date ) > 8 or length( $date ) == 7 ) {
         $err_msg = "unknown format for function 'getdate'";
        my $err_obj = Apiis::Errors->new( type     => 'PARAM',
  				 action   => 'UNKNOWN',
 				 severity => 'CRIT',
  				 from     => 'getdate',
  				 msg_short => $err_msg,
  				 msg_long => $err_msg,
  				 data     => $date,
  			       );
        $status = 1;
        return ( undef, $status, [$err_obj] )
      }
      $d = $1;
      $m = $2;
      $y = $3;
  #    $y = 19 . $y if $y != /^0/;
  #    $y = 20 . $y if $y =~ /^0/;
      $d =~ s/^ // if ( $d );
      $m =~ s/^ // if ( $m );
    }

    $date = $d . '-' . $m . '-' . $y if ( $d and $m and $y );
    my $date_format = $apiis->date_format;
    ( $date, $status, $err_msg ) = LocalToRawDate( $date_format, $date );
    if ( $status ) {
      my $err_obj = Apiis::Errors->new( type     => 'PARAM',
				 action   => 'UNKNOWN',
				 severity => 'CRIT',
				 msg_long => $err_msg,
				 msg_short => $err_msg,
				 data     => $date,
			       );
      push @all_errors, $err_obj;
    }
    return ( $date, $status, \@all_errors );
  }
#######################################################################
# sub insert_code_if_new ()
# parameter: class, ext_value, column_name='value', column_name2=...
#
# ex:
# $err = insert_code_if_new( 'POP', $pop, 'short_name='.$pop, 'long_name='$lname );
#######################################################################
sub insert_code_if_new {
  my $class   = shift; # class
  my $ext_val = shift; # external value

  my @m_cols = ();
  my @m_vals = ();

  #######  $id_codes{ $cat . '#' . $ext_code } = $db_code
  get_code_id( \%id_code ) if ( ! %id_code );

  if ( @_ ) {
    foreach ( @_ ) {
      @col = split ( /=/, $_ );
      push @m_cols, $col[0] ;
      push @m_vals, '\'' . $col[1] . '\'';
    }
    $more_cols = join( ",", @m_cols );
    $more_vals = join( ",", @m_vals );
    $more_cols = ',' . $more_cols if ( @_ );
    $more_vals = ',' . $more_vals if ( @_ );

    if ( ! $id_code{ $class . '#' . $ext_val } ) {
      my $now   = $apiis->now if ( ! $now );
      my $user  = $apiis->os_user if ( ! $user );
      my $next_seq = get_next_val(seq_codes__db_code);
      my $rowid = $apiis->DataBase->rowid;
      my $owner = $apiis->node_name;
      my $guid  = $apiis->DataBase->seq_next_val('seq_database__guid');
      my $insert = "INSERT INTO codes ( $rowid, last_change_user, last_change_dt, owner, version, db_code, ext_code, class " .
                     $more_cols .
                           " ) VALUES ( $guid, '$user', '$now', '$owner', '1', $next_seq, '$ext_val', '$class' " .
                     $more_vals . " )";
      print "WARNING! new code: $class => $ext_val \n";
      my $sql_ref = $apiis->DataBase->sys_sql($insert);
      $apiis->check_status;
      $id_code{ $class . '#' . $ext_val } = $next_seq;
    }
  }
return ( 0 ); # errorhandlin have to be added soon!
} ## sub insert_code_if_new

  ##############################################################################
  # get the defined positions from dataline
  # allow also undef and '' values to check invalid ids (only here)
  # usage: my $str = get_string( \@line, \@sstring );
  # return: concatenated strings with '|'
  sub get_string {
    my @line = @{ shift() };
    my $pattern=shift;
    my @pattern;
    if (ref($pattern) eq 'ARRAY') {
      @pattern = @{ $pattern };
    } else {
      @pattern=split('\s+', $pattern);
    }
    my @strings;

    map {s/^\s*//; s/\s*$//} @line; # delete leading and trailing whitespace
    for my $thiscol ( @pattern ){
      if ( $thiscol =~ /\D/ ){
	$thiscol =~ s/^c//i;
	return undef if $thiscol eq ''; # should not happen
	push @strings, $thiscol;
    } else {
#      return undef if ( not defined $line[$thiscol]) or $line[$thiscol] eq '';
#      undefined and NULL values possible to check wrong external id
      $line[$thiscol] = '' if ( not defined  $line[$thiscol] );
      $val = NULL;
	if ( $line[$thiscol] ) {
	  if ( defined $test{  $thiscol . '#' . $line[$thiscol] } ) {
	    # if ( $test{ $thiscol . '#' . $line[$thiscol] } ) {
	    # society unknown return 0!!
	    $val = $test{ $thiscol . '#' . $line[$thiscol] };
	  } elsif ( defined $testjob{  $thiscol . '#' . $line[$thiscol] } ) {
	    $val = $testjob{ $thiscol . '#' . $line[$thiscol] };
	  } else {
	    $val = $line[$thiscol];
	  }

	}
	else {
	  $val = NULL;
	}
#   if ( $codes_file ) {
# 	  $class = $test2{ $thiscol };
# 	  if ( $class and defined $val ) {
# 	   if ( $id_code{ $class . '#' . $val } ) {
# 	     $val = $id_code{ $class . '#' . $val };
# 	   }
# 	  }
#   }
  $val = '' if ( $val eq 'NULL' );
  push @strings, $val;
  }
  }
  return join('|', @strings);
}


### librarys from old pdbl !!!!!!!!

#############################################################################
# get the first name *.model in $APIIS_LOCAL/etc; require $APIIS_LOCAL
# should only one file with this specification here
# usage: GetModelName();
sub GetModelName {
  eval {
    warn "This subroutine is obsolete and have to disappear soon";
    my $APIIS_LOCAL=$apiis->APIIS_LOCAL;
    my $name=$apiis->project;
    $name.='.model';
  };
  if (@_) {
    print "no modelfile and no xmlfile found\n"; die;
  } else {
    return $name;
  }
  opendir(DIR, "$APIIS_LOCAL/etc/") or die "can't opendir $APIIS_LOCAL/etc: $!";
  my @files; my @name; my @name2;
  while (defined($file = readdir(DIR))) {
    next if $file =~ /^\.\.?$/;     # skip . and ..
    push @files, $file;
  }
  closedir(DIR);
  @name = grep { /.*?\.model$/ } @files;
  @name2 = grep { /.*?\.xml$/ } @files;
  if ( ! @name ) {
    if ( @name2 ) {
      my $model_basename = $name2[0];
      $model_basename =~ s/\.xml$//;
      system( "xml2model.pl $model_basename" );
      $name[0] = $model_basename . '.model';
    } else {
      print "no modelfile and no xmlfile found\n"; die;
    }
  }
  return $name[0];
}

##
1;
