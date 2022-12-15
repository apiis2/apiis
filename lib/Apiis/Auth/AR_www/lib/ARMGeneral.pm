package ARM::ARMGeneral;
##############################################################################
# $Id: ARMGeneral.pm,v 1.13 2006/08/08 14:35:15 marek Exp $
##############################################################################
use Apiis::Init;
use open ':utf8';
use open ':std';

=head1 NAME

ARMGeneral.pm

=head1 DESCRIPTION
 

=cut

=head1 SUBROUTINES
  
=cut

=head2 session_lang 

	Subroutine to get list of interface languages in current database and prepare drop-down
	list for the TMPL_LOOP from HTML::Template module. If input parameter lang_type is 
	undefined than loop for content_lang is returned

	input: lang_type (optional)	
	  
	output: reference to array of hashes with definition of languages	
	
=cut

sub session_lang {

    my @session_lang;
    my $filename = $apiis->APIIS_HOME.'/lib/Apiis/Auth/AR_www/lib/languages.dat';
    open (INFILE , "<:utf8","$filename") or die __("Problems with [_1]!",$filename), "\n";
    while ( <INFILE> ) {
     chomp;
     next if (length == 0);
     @rec = split /\|/ , $_;
        my %tmp_hash;
        $tmp_hash{'lang_iso'}  = $rec[0];
        $tmp_hash{'lang_name'} = $rec[1];
        if ( $rec[0] eq "en" ) {
            $tmp_hash{'selected'} = " selected=\"selected\" ";
        }
        push( @session_lang, \%tmp_hash );
    }
    return \@session_lang;
}

=head2 initTMPL 
	
 	return hash reference with initial template parameters	

   input: 1) gui_lang - language of interface 

   output:  hash reference 

=cut

sub initTMPL {
    my $gui_lang = shift;
    my %init_params;
    $init_params{'my_style'}    = style($gui_lang);
    $init_params{'print_style'} = print_style($gui_lang);
    my $some_js =
        "<script type=\"text/javascript\" src=\"../jscript/lang.js\" ></script>";
    $init_params{'java_script'} = $some_js;
    $init_params{'mid_header'}  = '* * * * * * * * * * * * * * * *';
    # meta data
    require ARMLabels;
    $init_params{'l_page_keywords'} =
        ARM::ARMLabels::get_arm_labels("index.cgi");
    $init_params{'l_page_description'} =
        ARM::ARMLabels::get_arm_labels("index.cgi");
    $init_params{'l_page_author'} =
        "- Marek Imialek - TZV FAL Germany vel. Mariensee  ";

    return \%init_params;
}

=head2 show_documantation 
	
	It show page with documentation

   input: 
   output: template content to fill in caller script

=cut

sub show_documentation {

    my $script_name = $apiis->programname();

    # open additional template with general information
    my $template_file =
        $apiis->APIIS_HOME . "/lib/Apiis/Auth/AR_www/arm_doc/developer_doc/index.html";
    my $doc_tmpl   = HTML::Template->new( filename => $template_file );
    my $mid_header = __("Documentation");

    return Encode::decode_utf8( $doc_tmpl->output ), $mid_header;
}

=head2 listFAQ 
	
	Print help and FAQ unformation

   input: 1) tmpl_dir - path to template directory 
			 2) sid - session identifier (optional)

   output: template content to fill in caller script

=cut

sub listFAQ {

    my $tmpl_dir    = shift;
    my $gui_lang    = shift || 'en';
    my $script_name = $apiis->programname();

    # open additional template with help and FAQ information
    my $template_file = $tmpl_dir . $gui_lang . "/helpfaq.tmpl";
    if ( !-e $template_file ) {
        $template_file = $tmpl_dir . "en/helpfaq.tmpl";
    }
    my $help_tmpl  = HTML::Template->new( filename => $template_file );
    my $mid_header = __("Frequently Asked Questions");

    return Encode::decode_utf8( $help_tmpl->output ), $mid_header;
}

=head2 style 
	
	return current css stylesheet file	

   input: 1) gui_lang - language of interface 

   output: path to current style sheet file 

=cut

sub style {
    my $gui_lang = shift;
    my $description = shift || undef;
    my $stylesheet;

    # style sheet for interface for specified GUI language
    if ( defined $description ) {
        $stylesheet = '../styles/' . $gui_lang . '/description.css';
        if ( !-e $stylesheet ) {
            $apiis->log( 'info', "File not found: " . $stylesheet );
            $stylesheet = '../styles/en/descriptios.css';
        }
    }
    else {
        $stylesheet = '../styles/' . $gui_lang . '/apiis.css';
        if ( !-e $stylesheet ) {
            $apiis->log( 'info', "File not found: " . $stylesheet );
            $stylesheet = '../styles/en/apiis.css';
        }
    }

    return $stylesheet;
}

=head2 print_style 
	
	return current css stylesheet file for printing	

   input: 1) gui_lang - language of interface 

   output: path to current style sheet file for print version

=cut

sub print_style {
    my $gui_lang = shift;

    # style sheet for interface for specified GUI language
    my $stylesheet = '../styles/' . $gui_lang . '/apiis_print.css';
    if ( !-e $stylesheet ) {
        $apiis->log( 'info', "File not found: " . $stylesheet );
        $stylesheet = '../styles/en/apiis_print.css';
    }

    return $stylesheet;
}

################################################################################
# additional java script functions
################################################################################

=head2 js_functions

   input: none
	  
   output: string with commonly used javascript
	
=cut

sub js_functions {
    return <<EOS;
 \n 
	<script type="text/javascript" src="../jscript/lang.js" ></script>
	<script type="text/javascript" src="../jscript/arm.js" ></script>
  \n
EOS
}

=head2 js_header 

   Prepare Java Script which is language dependent and is used later in other Java Script functions

   input: none 
	  
   output: formated string with proper javascript
	
=cut

sub js_header {
    my $form = shift;
    # Java Script function return string for provided ID

    my $my_function =
          "\nfunction msg(msg_id){\n"
        . "\tmsgs = new Array();\n"
        . "\tmsgs[1]=\""
        . __("Are you sure you want to ") . "\";\n"
        . "\tmsgs[2]=\" "
        . __("this data?") . "\";\n"
        . "\tmsgs[3]=\""
        . __("Nothing to update or insert")
        . "\";\n\n"
        . "\tmsgs[4]=\""
        . __("Sorry, passwords do not match")
        . "\";\n\n"
        . "\tmsgs[5]=\""
        . __("Are you sure you want to remove record from the database")
        . "\";\n\n"
        . "\tmsgs[6]=\""
        . __("Role name can not be NULL")
        . "\";\n\n"
        .

        " return msgs[msg_id];\n" . "}\n";

    my $my_function2 =
          "\nfunction translate_status(my_status){\n"
        . "\tswitch(my_status){\n"
        . "\tcase \"update\": \n"
        . "\t	my_status=\""
        . __("update") . "\";\n"
        . "\tbreak;\n"
        . "\tcase \"insert\": "
        . "\t	my_status=\""
        . __("insert") . "\";\n"
        . "\tbreak;\n" . "\t}\n"
        . " return my_status;\n" . "}\n";

    my $my_function3;

    if ( $form eq "tables" ) {
        $my_function3 =
              "\nfunction table_columns(table_name){\n"
            . "\ttables = new Array();";

        my @tables  = $apiis->Model->tables;
        my $counter = 1;
        foreach my $table_name (@tables) {
            my $tab_ref = $apiis->Model->table($table_name);
            my $columns = join( ',', @{ $tab_ref->cols } );
            $my_function3 = join( "\n",
                $my_function3, "\ttables['$counter']=\"$table_name\";" );
            $counter++;
            $my_function3 = join( "\n",
                $my_function3, "\ttables['$counter']=\"$columns\";" );
            $counter++;
        }

        my $my_function3a = "\nvar columns;
                            \tfor (i=1; i<tables.length; i=i+2){\n
			     \tif(tables[i] == table_name){\n
			       \tcolumns=tables[i+1];\n
			       \tbreak;\n
			     \t}\n
			    \t}
			";
        $my_function3 = join( "\n", $my_function3, $my_function3a );
        $my_function3 = join( "\n", $my_function3, "return columns;\n}\n" );
    }

    return $my_function . "\n" . $my_function2 . "\n" . $my_function3;
}

=head2 get_language_id 

   input:
	1) iso code for language
	  
   output:
	1) internal language ID 
	
=cut

sub get_language_id {
    my $iso_lang = shift;

    my $sql_statement_lang =
        sprintf("select lang_id from languages where iso_lang='$iso_lang'");
    my $sql_ref_lang = $apiis->DataBase->sys_sql($sql_statement_lang);
    my $lang_id;
    if ( $sql_ref_lang->status ) {
        $apiis->errors( $sql_ref_lang->errors );
        return undef;
    }
    else {
        while ( my @data = $sql_ref_lang->handle->fetchrow_array ) {
            $lang_id = $data[0];
        }
        return $lang_id;
    }
}

# check if not used
# =head2 js_table_columns
#
#    Prepare Java Script which is language dependent and is used later in other Java Script functions
#
#    input: none
#
#    output: formated string with proper javascript
#
# =cut
#
# sub js_table_columns {
#
#   my $my_function =
#           "\nfunction table_columns(table_name){\n"
#         . "\t tables = new Array();";
#   my @tables = $apiis->Model->tables;
#
#   foreach my $table_name (@tables){
#     my $tab_ref = $apiis->Model->table($table_name);
#     my $columns = join (',',@{$tab_ref->cols});
#     $my_function = join('\n',$my_function,"\ttabels[$table_name]=\"$columns\";");
#   }
#
#   $my_function = join ('\n',$my_function,"return tables[table_name];\n");
#   return $my_function;
# }

######################################################################

=head1 AUTHORS

Marek Imialek <marek@tzv.fal.de or imialekm@o2.pl>

=cut

1;
