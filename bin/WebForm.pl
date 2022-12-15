#!/usr/local/bin/perl -w

BEGIN { # execute some initialization before compilation
   use Env qw( APIIS_HOME APIIS_LOCAL HOME);
   die "APIIS_HOME is not set!\n" unless $APIIS_HOME;
   use lib "$APIIS_HOME/lib";
   require apiis_init;
   initialize_apiis( VERSION => '$Revision: 1.9 $' );
}

use DBI;
use apiis_lib;
use apiis_alib;
use Data::Dumper;
use ref_breedprg_alib;
use CGI qw/:standard :html3/;
use Apiis::Form::HTML;
use CheckRules;
use DataBase;
use MenuFiles;
use MenuForms;
use Modify;
use form_ulib;
my $zw;
our $apiis;

# use CGI qw/:standard :html3/;
# my $query=new CGI;
# print $query->header();
#   print $query->start_form(-action=>"/cgi-bin/WebForm.pl?form=address.frm&sub=Clear",
#                            -method=>"GET",
#                            -target=>"aktiv");
#  print $query->hidden(-name=>'offset',-default=>9);
#   print $query->submit;
#
# print $query->end_form;
# print "p".$query->param('offset');
# __END__



sub browseList {

#    my ($e) = @_;  # widget
#    my @choices;
#
#    if(defined $$e{FIELD}{TABLE} and defined $$e{FIELD}{COLUMN}) {
#       $col = getKey($$e{FIELD}{TABLE},$$e{FIELD}{COLUMN} , 'DB_COLUMN');
#       if (scalar @{$$e{FIELD}{TABLE}{$col}{CHECK}}) {
# 	 foreach $method ( @{$$e{FIELD}{TABLE}{$col}{CHECK}} ) {
# 	    my @args = split /\s+/, $method;
# 	    push (@choices, @args) if(shift @args eq 'List');
# 	 }
#       }
#    }
#    elsif ( defined $$e{FIELD}{ACTION}) {
#       foreach $act (@{$$e{FIELD}{ACTION}}) {
# 	 my @list = split /\s+/, $act;
# 	 if ('IU' =~ /$list[0]/) {
# 	    $col = getKey($list[1], $list[2], 'DB_COLUMN');
# 	    if (scalar @{$list[1]{$col}{CHECK}}) {
#                foreach $method ( @{$list[1]{$col}{CHECK}} ) {
#                   my @args = split /\s+/, $method;
#                   push (@choices, @args) if(shift @args eq 'List');
# 	       }
# 	    }
# 	 }
#       }
#    }
#
#    $e->configure(-choices=>\@choices);
#
#    my $cn = $e->Subwidget('slistbox'); # popup listbox subwidget
#
#    # set height of the popup listbox
#    if(scalar @choices < 10) {
#       $cn->configure(-height=>scalar @choices);
#       $cn->update();
#    }
#
#    # set width of the popup listbox
#    my $w = 0;
#    foreach (@choices) {
#       $w = length $_>$w?length $_:$w;
#    }
#    $cn->configure(-width=>$w+1);
#    $cn->update();


} # browseList


###########################################################################
# commitData
# usage : commitData(table_reference, tablename, statusmessage_reference )
#
sub commitData {
   my $tabref = shift;
   my $tablename = shift;
   my $status_msg_ref = shift;    # reference to the status message

   use Rules;
   use CheckRules;
   use DataBase;
   use Modify;

   my $data_error;
#   $data_error = CheckRules( $tabref );

   if ( $data_error ) {
      $$status_msg_ref = msg(10); # Error in Data
      # error messages
      foreach $col ( sort keys %$tabref ) {
         next if $col eq 'TABLE';
         if  ( scalar @{$tabref->{$col}{ERROR}} ) {
            $$status_msg_ref .= "\n" .
                                ucfirst $tabref->{$col}{DB_COLUMN} .
                                ': ' .
                                join(',', @{$tabref->{$col}{ERROR}});
         }
      }
   } else { # data ok
      # prepare hash for subroutine Insert
      my (%data_hash);
      foreach $col ( sort keys %$tabref ) {
         next if $col eq 'TABLE';
         if ($tabref->{$col}{DATA} and $tabref->{$col}{DATA} ne '') {
            $data_hash{ $tabref->{$col}{DB_COLUMN} } = $tabref->{$col}{DATA};
         }
      }
      # Insert data into Database:
      if ( OldInsert($tablename, \%data_hash) ) {
         $$status_msg_ref = msg(11);  # Record committed
      }
      if (defined $@ and $@ ne '') {
        my ($m1,$m2)=($@=~/(.*):\sERROR: (.*)/);
              $e = Errors->new(
               type      => 'DB',
               severity  => 'FATAL',
               from      => 'Form ',
               msg_short => $m1,
               msg_long  => $m2
         );

        $apiis->Form->{$apiis->{'_aktivform'}}->error('GENERAL',$e);
        $status=1;
      }
   }
} # commitData

##############################################################################
# execute a command, defined in $form{GENERAL}{key}
# usage:  exeUserCommand (key)
sub exeUserCommand {
#  my $key = shift;
#    #---um
#  if ($apiis->{Form}) {
#       $key=~s/[+-]//;
#       #--- Test, ob es diese Funktion als key gibt
#       foreach my $k ($apiis->Form->{$apiis->{_aktivform}}->sectionskeys('GENERAL')) {
#         if ($key eq $k) {
#           eval $apiis->Form->{$apiis->{_aktivform}}->$key('GENERAL');
#           if ($@ and ($@ ne '' )) {
#               $e = Errors->new(
#                type      => 'DB',
#                severity  => 'FATAL',
#                from      => $k,
#                msg_short => "$@",
#                msg_long  => ""
#               );
#
#               $apiis->Form->{$apiis->{'_aktivform'}}->error('GENERAL',$e);
#               $status=1;
#
#           }
#         }
#       }
#
#    } else {
# #      my $yesbutton = 'Ja';
# #      my $nobutton = 'Nein';
# #
# #      my @buttons = $yesbutton;
# #      push(@buttons,$nobutton);
# #
# #
# #      my $text = "Daten zu diesem Schlüssel existieren\nnoch nicht in der Datenbank!\n";
# #      $text .= "\nHinweis:\nWenn der Datensatz, auf den der Schlüssel\nweist nicht existiert, kann der aktuelle\nDatensatz nicht gespeichert werden.\n";
# #      $text .= "\nWollen Sie diese Daten jetzt eingeben?\n";
# #
# #      my $dialog = $maske->Dialog(-title=>"Frage",
# #                                -bitmap=>'question',
# #                                -text=>$text,
# #   			     -buttons => \@buttons,
# #   			     -default_button => $yesbutton)
# #      		        ->Show;
# #
# #      if($dialog eq $yesbutton) {
# #         # execute user defined command
# #         eval $$form{GENERAL}{$key} if($$form{GENERAL}{$key});
# #      }
#  }
}

##############################################################################
# Return from the given hash the key where the value of
# the subkey is equal to string
sub getKey {
   my ($hash, $string, $subkey) = @_;

   foreach $key (sort keys %$hash) {
      next if ($key eq 'TABLE' or $key eq 'GENERAL');
      if($$hash{$key}{$subkey} eq $string) {
         return $key;
      }
   }
   return -1;

} # getKey




##############################################################################
sub status {

   my $status = shift;
   my $top_ref = shift;
   my $form = shift;
   my $top = ${$top_ref};

   my $stat = msg(10);

   print "STATUS:$status\n" if($opt_d);

   if ($status =~ /$stat/) {
      my $rc = $dbh->rollback || die $dbh->errstr;
      print "# debug ROLLBACK executed\n" if($opt_d);
      return 1;
   }
   else {
      # reset the form
      my $rc = $dbh->commit if($dbh);
      print '# debug final commit $dbh->commit',"\n" if($opt_d);
#       clearForm($form,'sub');
      return 0;
   }

} # status


my $query=new CGI;
# $query->param('ext_animal'=>'1');
# $query->param('ext_unit'=>'Prüfstation');
# $query->param('ext_id'=>'Köllitsch');
# $query->param('ext_animal_sire'=>'555');
# $query->param('ext_unit_sire'=>'Herdbuch-Sachsen');
# $query->param('ext_id_sire'=>'14130004');
# $query->param('ext_animal_dam'=>'666');
# $query->param('ext_unit_dam'=>'Herdbuch-Sachsen');
# $query->param('ext_id_dam'=>'14440004');
# $query->param('parity'=>'1');
# $query->param('db_breed'=>'00');
# $query->param('db_zb_abt'=>'A1');
# $query->param('birth_dt'=>'01-01-2003');
# $query->param('name'=>'test');
# $query->param('db_gebtyp'=>'D');
# $query->param('mz'=>'1');
# $query->param('db_sex'=>'M');
# $query->param('comments'=>'test');
# $query->param('command'=>'speichern');
# $query->param('s'=>'Command');
# $query->param('oid'=>'');
# $query->param('currec'=>'0');
# $query->param('maxrec'=>'0');
# $query->param('qry'=>'__qry__ext_id_dam||__qry__name||__qry__birth_dt||__qry__parity||__qry__ext_animal_sire||__qry__ext_unit_sire||__qry__db_breed||__qry__db_sex||__qry__ext_id_sire||__qry__ext_unit||__qry__ext_id||__qry__mz||__qry__ext_animal||__qry__ext_unit_dam||__qry__comments||__qry__ext_animal_dam||__qry__db_gebtyp||');__qry__db_origin|
# $query->param('form'=>'/home/b08guest/devel/apiis/scrapie/model/forms/Tierdaten');

# $query->param('oid'=>'unit|5248174|codes|3589368');
# $query->param('ext_unit'=>'Prüfstation');
# $query->param('ext_id'=>'Köllitsch');
# $query->param('opening_dt'=>'01-01-2003');
# $query->param('ext_name'=>'LPA-Uhlig');
# $query->param('ext_address'=>'Köll');
# $query->param('short_name'=>'society');
# $query->param('s.x'=>'31');
# $query->param('s.y'=>'8');
# $query->param('s'=>'Update');
# $query->param('currec'=>'0');
# $query->param('maxrec'=>'0');
# $query->param('qry'=>'__qry__db_address||__qry__town||__qry__zip||__qry__db_country||__qry__street||__qry__ext_address||__qry__long_name|');
# $query->param('form'=>'/home/b08guest/devel/apiis/scrapie/model/forms/Unit_Kl.frm');


# #Codes
# $query->param('ext_code'=>'Prüfstation');
# $query->param('class'=>'UNIT');
# $query->param('opening_dt'=>'01-01-2003');
# $query->param('s.x'=>'31');
# $query->param('s.y'=>'8');
# $query->param('s'=>'Insert');
# $query->param('oid'=>'');
# $query->param('currec'=>'0');
# $query->param('maxrec'=>'0');
# $query->param('qry'=>'__qry__db_address||__qry__town||__qry__zip||__qry__db_country||__qry__street||__qry__ext_address||__qry__long_name|');
# $query->param('form'=>'/home/b08guest/devel/apiis/scrapie/model/forms/Schlüssel_Kl.frm');




#Address
# $query->param('ext_address'=>'asdf');
# $query->param('street'=>'asdf');
# $query->param('zip'=>'asdf');
# $query->param('town'=>'asdf');
# $query->param('long_name'=>'Schweizerische Eidgenossenschaft');

# $query->param('ext_name'=UM);
# $query->param('short_name'=deutsch);
# $query->param('s'=Update);
# $query->param('oid'=naming|4404353|codes|3589389);
# $query->param('currec'=0);
# $query->param('maxrec'=3);
# $query->param('qry'=__qry__second_name||__qry__short_name||__qry__salutation||__qry__db_name||__qry__opening_dt||__qry__closing_dt||__qry__db_language||__qry__birth_dt||__qry__title||__qry__third_name||__qry__ext_name|UM|__qry__formatted_name||__qry__first_name|);
# $query->param('form'=/home/b08guest/devel/apiis/scrapie/model/forms/Adressverwaltung/Personen);


# $query->param('birth_dt'=>'adsf');
# $query->param('s.x'=>'31');
# $query->param('s.y'=>'8');
# $query->param('s'=>'Insert');
# $query->param('oid'=>'');
# $query->param('currec'=>'0');
# $query->param('maxrec'=>'0');
# $query->param('qry'=>'__qry__db_address||__qry__town||__qry__zip||__qry__db_country||__qry__street||__qry__ext_address||__qry__long_name|');
# $query->param('form'=>'/home/zwisss/devel/apiis/scrapie/model/forms/Adressen');
#
#
# $query->param('animal_nr'=>'21079');
# $query->param('gewicht'=>'20');
# $query->param('dat'=>'13-10-2003');
# $query->param('leaving_areason'=>'1');
# $query->param('todbemerk'=>'asdf');
# $query->param('command'=>'speichern');
# $query->param('s'=>'Command');
# $query->param('oid'=>'');
# $query->param('form'=>'/home/b08guest/devel/apiis/minipigs_goe/model/forms/Ladeobjekte/LO_Abgang_tod');
#
#   print $query->header;
#   foreach ($query->param) {
#     print "&$_=".$query->param($_);
#   }  ;

if ((defined $query->param('form')) and ($query->param('s') ne 'Exit')) {
  my ($key,$value,$tablecontent,$rowcontent, @val,%hs_param, $hs_oid);
  my $abs='f';
  $zw=Apiis::Form::HTML::ApiisR0->new($query,$apiis);
  $zw->PrintHeader();
#   print $query->br().br().br().br().br().br().br().br().br().br().br().br().br().br().br();
#   foreach ($query->param) {
#     print "$_:".$query->param($_).br();
#   }
  goto ERROR if ($apiis->status);
  $maxrec=$query->param('maxrec');
  $currec=$query->param('currec');
  $zw->{_currec}=$currec;
  $sub= $query->param('s');
  $hs_oid={};

  %{$hs_oid}=split('\|',$query->param('oid')) if ($query->param('oid'));
  if ($query->param('qry')) {
    %hs_param=split('\|',$query->param('qry'));
  } else {
    foreach $value ($apiis->Form->{$zw->{_formname}}->sections) {
      if ($apiis->Form->{$zw->{_formname}}->column($value)) {
        $hs_param{"__qry__".$apiis->Form->{$zw->{_formname}}->column($value)}='';
      }
    }
  }

  #--- Wenn Command
  my $command;
  if ($query->param('command')) {
    #--- Werte aus param in Form-Hash übertragen
    foreach $value ($apiis->Form->{$zw->{_formname}}->sections) {
      if ($query->param($apiis->Form->{$zw->{_formname}}->column($value))) {
        $apiis->Form->{$zw->{_formname}}->data($value, $query->param($apiis->Form->{$zw->{_formname}}->column($value)));
      }
    }

    foreach my $thissection ( $apiis->Form->{$zw->{_formname}}->sections ) {
      if ($apiis->Form->{$zw->{_formname}}->text($thissection) and ($apiis->Form->{$zw->{_formname}}->text($thissection) eq $query->param('command'))) {
        $command=$apiis->Form->{$zw->{_formname}}->command($thissection);
        if ($command=~/call_LO\(\'(.*?)\'/) {
          $zw->call_LO("$1",undef);
        }
      }
    }
  }

  if ((! defined $query->param('s') or ($query->param('s') eq 'Clear') or
                ($query->param('s') eq 'Insert')) or ($query->param('s') eq "setNewButton")){
    $maxrec=0;
    $currec=0;
    $UpIn='Insert';
    #--- Wenn clear|insert, dann löschen der archivierten Abfrageparameter bzw. initialisieren
    foreach (keys %hs_param) {
      $hs_param{$_}='';
    }
  } else {
    $maxrec=$query->param('maxrec');
    $currec=$query->param('currec');
#     if ($query->param('s') eq "setNewButton") {
#       $UpIn='Insert';
#     } else {
    $UpIn='Update';
#    }
  }

  #--- Ankommende Daten werden auf die Felder verteilt, unabhängig, was damit gemacht werden soll
  foreach $value ($apiis->Form->{$zw->{_formname}}->sections) {
    #--- wenn Clear, neuer Datensatz oder Navigation, sind alte Daten uninteressant
    if (($query->param('s') eq 'Clear')         or ($query->param('s') eq "setFirstButton") or
        ($query->param('s') eq "setLeftButton") or ($query->param('s') eq "setRightButton") or
        ($query->param('s') eq "setMaxButton")  or ($query->param('s') eq "setNewButton")) {
      $apiis->Form->{$zw->{_formname}}->data($value, '');
    } else {
      if ($query->param($apiis->Form->{$zw->{_formname}}->column($value))) {
        $apiis->Form->{$zw->{_formname}}->data($value, $query->param($apiis->Form->{$zw->{_formname}}->column($value)));
      }
    }
  }

  #--- Sind die Daten Grundlage einer neuen Query Anfrage
  if ((defined $query->param('s')) and ($query->param('s') eq 'Query')) {
    #--- Abfrageparameter sichern
    foreach $value ($apiis->Form->{$zw->{_formname}}->sections) {
      if (defined $query->param($apiis->Form->{$zw->{_formname}}->column($value))) {
        $hs_param{"__qry__".$apiis->Form->{$zw->{_formname}}->column($value)}=$query->param($apiis->Form->{$zw->{_formname}}->column($value));
      }
    }
    #---Abfragen und Daten in form-Hash schreiben
    ($maxrec,$hs_oid)=$zw->query(undef,0,0);
    $currec=0;
  }

  #--- Sind die Daten Grundlage eines Updates
  if ((defined $query->param('s')) and ($query->param('s') eq 'Update')) {
    $zw->update();
  }

  #--- Sind die Daten Grundlage einer neuen Insert Abfrage
  if ((defined $query->param('s')) and ($query->param('s') eq 'Insert')) {
    my $status=$zw->insert(undef,$form);
    $UpIn='Insert';
    if ($status eq "0") {
      foreach $value ($apiis->Form->{$zw->{_formname}}->sections) {
        $apiis->Form->{$zw->{_formname}}->data($value, '');
      }
    }
  }

  #--- Wenn Navigation, dann Navigationsparameter aus ursprünglicher Query rücksichern
  if (($query->param('s') eq "setFirstButton") or ($query->param('s') eq "setMaxButton") or
      ($query->param('s') eq "setLeftButton")  or ($query->param('s') eq "setRightButton")) {
       #or ($query->param('s') eq "Update")) {

    foreach $value ($apiis->Form->{$zw->{_formname}}->sections) {
      #--- wenn Clear, neuer Datensatz oder Navigation, sind alte Daten uninteressant
      if (defined  $apiis->Form->{$zw->{_formname}}->column($value)) {
        if (exists $hs_param{"__qry__".$apiis->Form->{$zw->{_formname}}->column($value)}) {
          $apiis->Form->{$zw->{_formname}}->data($value,$hs_param{"__qry__".$apiis->Form->{$zw->{_formname}}->column($value)});
        }
      }
    }
    my $x;
    ($x,$hs_oid)=$zw->query(undef,$currec,0);

  }
  $query->delete_all();
  my $curX; my $curY; my $offset; $cy;
  #--- kopf drucken
  print $query->start_form(-action=>"/cgi-bin/WebForm.pl",
                           -method=>"GET",
                           -target=>"aktiv");
  my $title; my $bgcolor; my $fgcolor;my $width;
  if ( $apiis->Form->{$zw->{_formname}}->title('GENERAL')) {
    $title=$apiis->Form->{$zw->{_formname}}->title('GENERAL')
  } else {
    $title=$apiis->Form->{$zw->{_formname}}->basename;
  }
  $fgcolor=$apiis->Form->{$zw->{_formname}}->fgcolor('GENERAL');
  $bgcolor=$apiis->Form->{$zw->{_formname}}->bgcolor('GENERAL');
  $width=$apiis->Form->{$zw->{_formname}}->width('GENERAL');
  $fgcolor="#000000" if ($apiis->Form->{$zw->{_formname}}->fgcolor('GENERAL')!~/^\#\d{6}/);
  $bgcolor="#dedade" if ($apiis->Form->{$zw->{_formname}}->bgcolor('GENERAL')!~/^\#\d{6}/);
  #nok $width="300" if ($apiis->Form->{$zw->{_formname}}->width('GENERAL') < 100);

  if (defined $apiis->Form->{$zw->{_formname}}->error('GENERAL')) {
    $err=$zw->SetFormErrorForLink($apiis->Form->{$zw->{_formname}}->error('GENERAL'));
    $err=$query->a({-href=>"/cgi-bin/WebForm.pl?error=$err",-target=>"error"},img({-border=>0,-src=>"/icons/error.gif",-alt=>$apiis->Form->{$zw->{_formname}}->error('GENERAL')}));
    $style='txferr';
    $fgcolor='red';
  }
  print $query->div({-style=>"position:absolute; border:ridge;
                              padding-left:36px;font-weight:bold; font-size: 24px; font-family:arial;
                              color:".$fgcolor.";
                              background-color:".$bgcolor.";
                              top: 0px;
                              width:". $width."px;
                              height:30px", -align=>'center'},$title,$err);
  my $offset=30;
  my $xoffset=10;
  $cy=$offset;
  print $query->div({-style=>"position:absolute; border:ridge;
                              padding-left:36px;font-weight:bold; font-size: 26px; font-family:arial;
                              color:".$fgcolor.";
                              background-color:".$bgcolor.";
                              width:".$width."px;
                              top:". $cy ."px;
                              height:".$apiis->Form->{$zw->{_formname}}->height('GENERAL')."px"},'');
  my @ar_sections=$apiis->Form->{$zw->{_formname}}->sections;
  foreach $value (@ar_sections) {
    next if ((! defined $apiis->Form->{$zw->{_formname}}->type($value)) or
                       ($apiis->Form->{$zw->{_formname}}->type($value) eq ''));

      $curX=$zw->xcoord(undef,$apiis->Form->{$zw->{_formname}}->xlocation($value),$curX) + $xoffset;
      $curY=$zw->ycoord(undef,$apiis->Form->{$zw->{_formname}}->ylocation($value),$curY);
      $cy=$curY+$offset;
      my $t='';my $err='';my $style='txf';
      $t=$query->img({-src=>"/icons/help.gif",-alt=>$apiis->Form->{$zw->{_formname}}->balloonmsg($value)}) if (defined $apiis->Form->{$zw->{_formname}}->balloonmsg($value));
      if (defined $apiis->Form->{$zw->{_formname}}->error($value)) {
        $err=$zw->SetFormErrorForLink($apiis->Form->{$zw->{_formname}}->error($value));
        $err=$query->a({-href=>"/cgi-bin/WebForm.pl?error=$err",-target=>"error"},img({-border=>0,-src=>"/icons/error.gif",-alt=>$err}));
        $style='txferr';
      }
      if ($apiis->Form->{$zw->{_formname}}->type($value)=~/^[A]/) {
        print $query->div({-class=>'txf',-style=>"position:absolute;
                            top:".$cy."px;
                            left:".$curX."px"},
              b($apiis->Form->{$zw->{_formname}}->label($value)));
      }
      if ($apiis->Form->{$zw->{_formname}}->type($value)=~/^[ED]/) {
       if ($apiis->Form->{$zw->{_formname}}->type($value)=~/^[E]/) {
         print $query->div({-class=>'txf',-style=>"position:absolute;
                             top:".$cy."px;
                             left:".$curX."px"},
              b($apiis->Form->{$zw->{_formname}}->label($value)).br().
              $query->textfield(-class=>$style,
                                -style=>"background-color:".$apiis->Form->{$zw->{_formname}}->bgcolor($value),
                                -name=>$apiis->Form->{$zw->{_formname}}->column($value),
                                -size=>$apiis->Form->{$zw->{_formname}}->fieldlength($value),
                                -default=>$apiis->Form->{$zw->{_formname}}->data($value)),$t,$err);
       } else {
         print $query->div({-class=>'menu',-style=>"position:absolute;
                              top:".$cy."px;
                              left:".$curX."px"},
             b($apiis->Form->{$zw->{_formname}}->label($value)).br().strong($apiis->Form->{$zw->{_formname}}->data($value)));
       }
      }

      #--- PushButton
      if ($apiis->Form->{$zw->{_formname}}->type($value)=~/^P/ ) {
        my $label=$apiis->Form->{$zw->{_formname}}->text($value);
        print $query->div({-class=>'menu',-style=>"position:absolute;
                             top:".$cy."px;
                             left:".$curX."px"},
              b($query->submit("command",$label)),
              "$t","$err"
              );
      }

      #--- Datum
      if ($apiis->Form->{$zw->{_formname}}->type($value)=~/^C/ ) {
        print $query->div({-class=>'menu',-style=>"position:absolute;
                             top:".$cy."px;
                             left:".$curX."px"},
              b($apiis->Form->{$zw->{_formname}}->label($value)).br().
              $query->textfield(-class=>$style,
                                -style=>"background-color:".$apiis->Form->{$zw->{_formname}}->bgcolor($value),
                                -default=>$apiis->Form->{$zw->{_formname}}->data($value),
                                -name=>$apiis->Form->{$zw->{_formname}}->column($value),
                                -size=>$apiis->Form->{$zw->{_formname}}->fieldlength($value)),
              "$t","$err");
      }
      #--- Text
      if (($apiis->Form->{$zw->{_formname}}->type($value)=~/^T/ ) or
          ($apiis->Form->{$zw->{_formname}}->type($value) eq "Text")) {
        print $query->div({-class=>'menu',-style=>"position:absolute;
                             top:".$cy."px;
                             left:".$curX."px"},
              b($apiis->Form->{$zw->{_formname}}->label($value)).br().
              $query->textarea(-class=>"txf",
                               -default=>$apiis->Form->{$zw->{_formname}}->data($value),
                               -name=>$apiis->Form->{$zw->{_formname}}->column($value),
                               -cols=>$apiis->Form->{$zw->{_formname}}->width($value),
                               -rows=>$apiis->Form->{$zw->{_formname}}->height($value),
                               -size=>$apiis->Form->{$zw->{_formname}}->fieldlength($value)),$t,$err);
      }

      #--- Radiobutton
      if ($apiis->Form->{$zw->{_formname}}->type($value)=~/^R/ ) {
        print $query->div({-class=>'menu',-style=>"position:absolute;
                             top:".$cy."px;
                             left:".$curX."px"},
              b($apiis->Form->{$zw->{_formname}}->label($value)).br().
              $query->radio_group(-class=>"txf",
                               -style=>"background-color:".$apiis->Form->{$zw->{_formname}}->bgcolor($value),
                               -default=>$apiis->Form->{$zw->{_formname}}->data($value),
                               -name=>$apiis->Form->{$zw->{_formname}}->column($value),
                               -linebreak=>'true',
                               -values=>[split('\|',$apiis->Form->{$zw->{_formname}}->text($value))]),$t,$err);
      }

      if ($apiis->Form->{$zw->{_formname}}->type($value)=~/^[BNL]\s*/) {
        if ($apiis->Form->{$zw->{_formname}}->type($value) =~ /^[BN]/) {
          @val=$zw->browseDB($value);
        } else {
          @val=browseList;
        }
         if ($apiis->Form->{$zw->{_formname}}->clear($value) eq 'Y') {
           unshift(@val,'');
         }
        print $query->div({-class=>'menu',-style=>"position:absolute;
                            top:".$cy."px;
                            left:".$curX."px"},
               b($apiis->Form->{$zw->{_formname}}->label($value)).br().$query->popup_menu(-class=>'pop',
                                                         -style=>"background-color:".$apiis->Form->{$zw->{_formname}}->bgcolor($value),
                                                         -name=>$apiis->Form->{$zw->{_formname}}->column($value),
                                                         -values=>[@val],
                                                         -default=>$apiis->Form->{$zw->{_formname}}->data($value),
                                                        ),$t,$err);
      }
  }


  #---Abfrageparameter sichern und als Parameter übergeben
  my $qry="qry=".join('|',%hs_param);

  #--- Wenn kein LO-Objekt Buttonbar einfügen
  my $LO;
  foreach my $thissection ( $apiis->Form->{$zw->{_formname}}->sections ) {
    if ($apiis->Form->{$zw->{_formname}}->command($thissection)) {
      $command=$apiis->Form->{$zw->{_formname}}->command($thissection);
      if ($command=~/call_LO\(\'(.*?)\'/) {
        $LO=$1;
      }
    }
  }
  if (-f "$APIIS_LOCAL/lib/".$LO.".pm") {
    print $query->hidden(-name=>'s',-default=>"Command");
  } else {
    #--- Steuerleiste
    $offset=30;
    $cy=$apiis->Form->{$zw->{_formname}}->height('GENERAL')+ $offset;
    print $query->div({-style=>"position:absolute; border:ridge;
                                padding-left:36px;font-weight:bold; font-size: 26px; font-family:arial;
                                color:".$fgcolor.";
                                background-color:".$bgcolor.";
                                width:".$width."px;
                                top:". $cy ."px;
                                height: 30px"},'');

    $zw->buttonBarStyle($query,$form,$currec,$maxrec,$UpIn,$abs,$qry,$cy);
  }

  print $query->table({-class=>'menu'},$tablecontent);
  print $query->hidden(-name=>'oid',-default=>join('|',%{$hs_oid}));
  print $query->hidden(-name=>'currec',-default=>$currec);
  print $query->hidden(-name=>'maxrec',-default=>$maxrec);
  print $query->hidden(-name=>'qry',-default=>join('|',%hs_param));
  print $query->hidden(-name=>'form',-default=>$zw->{_formname});
  print $query->end_form;
ERROR:

  foreach my $thiserror ( @{$apiis->errors} ) {
    $err=$zw->SetFormErrorForLink($thiserror);
    my $tablecontent='';
    my @e=split('<l>',$err);
    foreach $e (@e) {
      my @err=split(':',$e);
      $tablecontent.=TR(td(strong($err[0])),td($err[1]));
    }
    print $query->table($tablecontent);
  }

} elsif ($query->param('version'))  {
  $zw=Apiis::Form::HTML::ApiisModel->new($query,$apiis);
  $zw->PrintHeader();
  $zw->Body() if ($apiis->status == 0);
} elsif (($query->param('login'))  or ($query->param('s') eq 'Exit')){
  $zw=Apiis::Form::HTML::ApiisLogin->new($query,$apiis);
  $zw->PrintHeader();
  $zw->Body() if ($apiis->status == 0);
} elsif ($query->param('error')) {
  $zw=Apiis::Form::HTML::ApiisError->new($query,$apiis);
  $zw->PrintHeader();
  $zw->Body() if ($apiis->status == 0);
} else {
  $zw=Apiis::Form::HTML::ApiisM0->new($query,$apiis,$query->param('dir'));
  $zw->PrintHeader();
  $zw->Body($query->param('dir'));
}



#if ($query->param('logon') eq 'Anmelden') {
#  $zw->SetUser();
#}
#$zw->ControlUser;

$zw->PrintHtmlEnde();

__END__

=pod

=head1 NAME

WebForm.pl

=head1 ABSTRACT

WebForm.pl is a Web-Frontend on basis of yaform.pm. It reads *.frm-Files
and create a Browser-Form for the input of datas.

=head1 PROGRAMMING STYLE

WebForm.pl is written in OO-Stile.

=head1 Notice

The communication of a browser with a database via HTML is very different
to the communication via TK. That's why, not all features of Form.pl are implemented
in WebForm.pl. For example getting information from the database by pushing
the TAB-button.

=head1 Configuration

1.: apache runs under the user-id "wwwrun" (suse) , "www-data" (debian) or something like that.
    This user-id needs read-rights (group or other) for apiis/index and the project-directory and
    execute-rights for apiis/bin/WebForm.pl

2.: httpd.conf ("/etc/apache/" (debian) or "/etc/httpd/" (suse) needs this entry in
    "Section 3: Virtual Hosts":
    For using Internet each project needs a subdomain.
    There will be defined directories or variables.
    Do define subdomains a entry in /etc/httpd/httpd.conf for each subdomain is necessary.

    #you must replace  /home/... with your current pfad.
    ################
    <VirtualHost ref_breedprg.apiis.org>
      ServerName ref_breedprg.apiis.org
      ServerAlias ref_breedprg.apiis.org

      DocumentRoot /home/zwisss/devel/apiis/ref_breedprg
      ScriptAlias /cgi-bin/ /home/zwisss/devel/apiis/bin/
      Alias images /home/zwisss/devel/apiis/lib/images

      SetEnv APIIS_HOME /home/zwisss/devel/apiis
      SetEnv APIIS_LOCAL /home/zwisss/devel/apiis/ref_breedprg
      SetEnv HOME /home/zwisss

      ServerAdmin webmaster@www.apiis-sachsen.de>
    </VirtualHost>
    ################

3.: Add in "/etc/hosts"

    127.0.0.2       ref_breedprg.localhost                         ref_breedprg

    If you define a ServerAlias in section VirtualHost, this entry
    isn't necessary.

4.: user-id "wwwrun" or "www-data" must exists in postgres

    su root
    su postgres
    createuser wwwrun



=head1 Comment

Please note, all functions in LO_*.pm Objects and all global-variables
must be expand to main::. For example $main::dbh->rollback or main::CheckLO, because,
WebForm.pl is programmed in OO-Stile.

=head1 AUTHOR INFORMATION

 Ulf Müller.

=head1 BUGS

Normally, the most features of Form.pl should be work, but not all posibilities
were tested at time.

=head1 SEE ALSO

L<Apiis::Form::Base.pm>, L<Apiis::Form::HTML.pm>,L<Apiis::Form::Tk.pm>

=cut


