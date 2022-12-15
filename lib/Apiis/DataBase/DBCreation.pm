##############################################################################
# $Id: DBCreation.pm,v 1.17 2013/01/03 09:34:59 ulm Exp $
##############################################################################

=head1 NAME

DBCreation.pm

=cut

=head1 DESCRIPTION

This module is used in runall process to create initial database structure. The structure of the database 
is taken from the model file. New database is created in the system user schema (system user name is 
taken from the modelfile) and the public schema is removed. Then the languages are loaded from 
defined file and information about node is inserted (from apissrc settings). At the end sequences are
corectly set.

=cut

=head1 SUBROUTINES

=cut

use Apiis::DataBase::SQL::MakeSQL;
#use Apiis::Auth::Role;
use Digest::MD5 qw(md5_base64);
use Term::ReadKey;
use DBI;
use Apiis::Misc qw(mychomp);

=head2 CreateDatabase
 
This subroutine call all subroutines which are written in this file. The parameters are defined as:
- $db_encoding  -  character encoding which will be used in the database 
- $db_name - databse name
- $user_creator - user name which creates database
- $lang_file -  file name where the initila languages are written (language.dat in the reference database) 
- $lang_dir - directory for the language file 

=cut

sub CreateDatabase { 
 my ($db_encoding,$db_name,$user_creator,$lang_file,$lang_dir) = @_;

 MakeSQL();
 InitDB($db_encoding,$db_name);
 $apiis->DataBase->connect; 
 LoadLang($user_creator,$lang_file,$lang_dir);
 LoadNodeData($user_creator);
 SetSequences();
}

#########################################################################
#########################################################################

=head2 InitDB

This subroutine creates initial database structure. PUBLIC schema is removed and the database 
is placed in the system user schema. System user schema name is taken from the user name
defined in the modelfile. 

=cut

sub InitDB{
 my ($db_encoding,$db_name) = @_;
 my $system_user = $apiis->Model->db_user;
 my $sqlfile = $apiis->APIIS_LOCAL.'/var/'.$apiis->Model->basename . '_' . $apiis->Model->db_driver . '.sql';
 my $host = $apiis->Model->db_host;
 system("dropdb -U $system_user -h $host $db_name");
 system("createdb -E $db_encoding -h $host -U $system_user  $db_name") == 0 or die "createdb -E $db_encoding  -h $host -U $system_user  $db_name failed: $?\n";
 system("psql -U $system_user -c \"drop schema public CASCADE\" -h $host -d $db_name");
 system("psql -U $system_user -c \"create schema $system_user\" -h $host -d $db_name");
 system("psql  -f $sqlfile -U $system_user -h $host -d $db_name") == 0
 or die "psql  -f $sqlfile -U $system_user -h $host -d $db_name failed: $?\n";
}

=head2 LoadLang

This subroutine load initial languages to the languages table.

=cut

sub LoadLang {
  
    my ($user,$file,$directory)=@_;
    
    $directory=$apiis->APIIS_LOCAL."/load" if (!$directory);
    
    my $load_status=1;
    my @data;

    eval {

        if ( -f "$directory/$file") {
            my $msg1= __("Problems opening directory");
            opendir(SPOOL, $directory) or die "$msg1 $directory\n";
     
            my $msg2= __("Loading data from the file"); 
            print "\n$msg2: $file\n";
        
            my $msg3= __("Problems opening file");
            open (INA, "<$directory/$file") or die $msg3, $file, ": $!\n";
            @data=<INA>;
    
            close INA;
        }
        else {

            #-- default for locations
            @data=('aa|Afar', 'ab|Abkhazian', 'af|Afrikanns', 'am|Amharic', 'ar|Arabic', 'as|Assamese', 'ay|Aymara', 'az|Azwerbaijani', 'ba|Bashkir', 'be|Byelorussian', 'bg|Bulgarian', 'bh|Bihari', 'bi|Bislama', 'bn|Bengali', 'bo|Tibetan', 'br|Breton', 'ca|Catalan', 'co|Corsican', 'cs|Czech', 'cy|Welch', 'da|Danish', 'de|German', 'dz|Bhutani', 'el|Greek', 'en|English', 'eo|Esperanto', 'es|Spanish', 'et|Estonian', 'eu|Basque', 'fa|Persian', 'fi|Finnish', 'fj|Fiji', 'fo|Faeroese', 'fr|French', 'fy|Frisian', 'ga|Irish', 'gd|Scots Gaelic', 'gl|Galician', 'gn|Guarani', 'gu|Gujarati', 'ha|Hausa', 'he|Hebrew', 'hi|Hindi', 'hr|Croatian', 'hu|Hungarian', 'hy|Armenian', 'ia|Interlingua', 'id|Indonesian', 'ie|Interlingue', 'ik|Inupiak', 'in|former Indonesian', 'is|Icelandic', 'it|Italian', 'iu|Inuktitut (eskimo)', 'iw|former Hebrew', 'ja|Japanese', 'ji|former Yiddish', 'jw|Javanese', 'ka|Georgian', 'kk|Kazakh', 'kl|Greenlandic', 'km|Cambodian', 'kn|Kannada', 'ko|Korean', 'ks|Kashmiri', 'ku|Kurdish', 'ky|Kirghiz', 'la|Latin', 'ln|Lingala', 'lo|Laothian', 'lt|Lithuanian', 'lv|Latvian', ' Lettish', 'mg|Malagasy', 'mi|Maori', 'mk|Macedonian', 'ml|Malayalam', 'mn|Mongolian', 'mo|Moldavian', 'mr|Marathi', 'ms|Malayalam', 'mt|Maltese', 'my|Burmese', 'na|Nauru', 'ne|Nepali', 'nl|Dutch', 'no|Norwegian', 'oc|Occitan', 'om|(Afan) Oromo', 'or|Oriya', 'pa|Punjabi', 'pl|Polish', 'ps|Pashto', 'Pushto', 'pt|Portuguese', 'qu|Quechua', 'rm|Rhaeto-Romance', 'rn|Kirundi', 'ro|Romanian', 'ru|Russian', 'rw|Kinyarwanda', 'sa|Sanskrit', 'sd|Sindhi', 'sg|Sangro', 'sh|Serbo-Croatian', 'si|Singhalese', 'sk|Slovak', 'sl|Slovenian', 'sm|Samoan', 'sn|Shona', 'so|Somali', 'sq|Albanien', 'sr|Serbian', 'ss|Siswati', 'st|Sesotho', 'su|Sudanese', 'sv|Swedish', 'sw|Swahili', 'ta|Tamil', 'te|Tegulu', 'tg|Tajik', 'th|Thai', 'ti|Tigrinya', 'tk|Turkmen', 'tl|Tagalog', 'tn|Setswana', 'to|Tonga', 'tr|Turkish', 'ts|Tsongo', 'tt|Tatar', 'tw|Twi', 'ug|Uigur', 'uk|Ukrainian', 'ur|Urdu', 'uz|Uzbek', 'vi|Vietnamese', 'vo|Volapuk', 'wo|Wolof', 'xh|Xhosa', 'yi|Yiddish', 'yo|Yoruba', 'za|Zhuang', 'zh|Chinese', 'zu|Zulu');
        }

        my $k = 0;
        my $msg4= __("Inserting into database");
        print "$msg4...\n";
    
        foreach (@data) {
        
            mychomp($_);		# remove End-Of-Line
            next if //;		# skip End-Of-File marker from DOS files
            next if /^\s*$/;		# skip empty lines;
            my $row=$_;
            my @line = split(/\|/,$row);      

            my $now=$apiis->extdate2iso($apiis->now);
            my $owner=$apiis->node_name; 
            my $lang_id = $apiis->DataBase->seq_next_val('seq_languages__lang_id');
            my $guid = $apiis->DataBase->seq_next_val('seq_database__guid');
      
            my $sql="INSERT INTO languages (lang_id, iso_lang, lang,last_change_dt,
                        last_change_user,creation_dt, creation_user,
                        guid, version, owner,synch)  
                     VALUES ($lang_id, '@line[0]', '@line[1]','$now', '$user','$now', '$user',
		             $guid, 1, '$owner','y')";

            my $sql_ref = $apiis->DataBase->sys_sql($sql);
      
            if ($sql_ref->status or $apiis->status) {
	
                $apiis->log('err',$apiis->errors(0)->sprintf);
	            die;
            }
      
            ++$k;
        }
    
        $apiis->DataBase->sys_dbh->commit;
    
        my $msg5= __("languages from the file inserted in to the database");
        print "$k $msg5 \n";
    
        $apiis->log ("info","$k $msg5 \n");
        if (not $k==0) {$load_status=0};   
    };
 
    if ($load_status){
        my $msg6 =  __("Languages not loaded in the database");
        $apiis->status(1);
	    $apiis->errors(
		       Apiis::Errors->new(
				      type      => 'PARAM',
				      severity  => 'CRIT',
				      from      => 'Apiis::DataBase::DBCreation::LoadLang',
				      msg_short =>$msg6,
				     )
		      );
	    print "\n"; 	
	    die $msg6;
    }
 
    if ( $@ ) {
        $apiis->DataBase->sys_dbh->rollback;
        print "$@\n";
        return -1;
    } else {
        $apiis->DataBase->sys_dbh->commit;
        return 0;
    }
}

=head2 LoadNodeData 

This subroutine load initial information about node. These information are inserted in the nodes table.

=cut

sub LoadNodeData {
  my $user=shift;
  my $now=$apiis->extdate2iso($apiis->now);
  my $node=$apiis->node_name; 
  my $address=$apiis->node_ip;
  my $guid = $apiis->DataBase->seq_next_val('seq_database__guid');  
  my $sql="INSERT INTO nodes (guid, nodename, address, last_change_dt, last_change_user, owner,version) VALUES ($guid,'$node','$address','$now','$user','$node',1)";
  my $sql_ref= $apiis->DataBase->sys_sql($sql);
  if ($sql_ref->status or $apiis->status) {
    $apiis->DataBase->sys_dbh->rollback;
    $sql_ref->check_status;
    $apiis->check_status;
  } else {
    $apiis->DataBase->sys_dbh->commit;
  };
}

=head2 SetSequences

This subroutine sets initial sequences.

=cut

sub SetSequences {
  my ($tab,$seq,$local_status);
  my ($seq_min,$seq_max)=split(':',$apiis->sequence_interval);
  my @tables = $apiis->Model->tables;
  $local_status=0;
 TABLE:
  foreach $tab (@tables) {
    my $table = $apiis->Model->table($tab);
    my @tab_sequences = $table->sequences if $table->sequences;
    foreach $seq (@tab_sequences) {
      my $sql_drop_sequence="DROP SEQUENCE $seq";
      my $sql_create_sequence="CREATE SEQUENCE $seq MINVALUE $seq_min MAXVALUE $seq_max";
      my $sql_ref_drop= $apiis->DataBase->sys_sql($sql_drop_sequence);
      my $sql_ref_create= $apiis->DataBase->sys_sql($sql_create_sequence);
      if ($sql_ref_drop->status or $sql_ref_create->status or $apiis->status) {
	$local_status=1;
	last TABLE;
      };
    }
  }
  if ($local_status) {
   my $msg7 =__( "Resetting the sequences with min and max values failed");
    $apiis->DataBase->sys_dbh->rollback;
    $apiis->log( 'err',$msg7
	     );
  } else {
    my $msg7 = __("Database sequences reset to start with $seq_min and have maximal value $seq_max");
    $apiis->DataBase->sys_dbh->commit;
    $apiis->log( 'notice',$msg7);
  };
}

######################################################################################
1;


=head1 AUTHORS

 Marek Imialek <marek@tzv.fal.de>

=cut

__END__
