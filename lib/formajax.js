//UTF8(ö)
var $form={};
var $current_record;
var $max_record;
var $current_field;
var $resetcolor={};
var $verror=false;

//-------------- Ajax Functions for query and save
function ExecuteAjax($mm) {
  var $m= encodeURIComponent($mm);
  $verror=false;
  var myAjax       = new Ajax();
  myAjax.method    = "POST";
  myAjax.url       = "/cgi-bin/GUI";
  myAjax.params    = "json=" + $m;

  myAjax.onSuccess = function(txt) {
    if (frmHasError(txt)) { 
      myAjax.onError(frmGetError(txt));
      return null;
    } else {
      try {
        //JSON auswerten
	$form = eval( '(' + txt + ')' );
	$data=$form.data;
	document.getElementById("statusbar").innerHTML = $form.info;
	initFormElements();
      } catch(e) {
        //Fehler JSON auswerten
        myAjax.onError(e.name+": "+e.message)
        return null;
      }
    }  
  }
  myAjax.onError = function(msg) {
    document.getElementById("statusbar").innerHTML = msg;
  }
  myAjax.doRequest();
}



function doQuery() {
      
  resetColor();
  getFormElements("no"); 
  var $aktrec=$form.data[0];
  for ( $t in $aktrec) {
      if ( $t == 'toJSONString' ) {
         continue;
      }
      //alert($aktrec[$t][0] +',' + $aktrec[$t][1]);
      if (($aktrec[$t][0] == false ) && ($aktrec[$t][1] == '')) $aktrec[$t][0]='';
  }
  
  $form.info="";
  $form.command="do_query_block";
  $form.formtype="apiisajax";
  var $mm=$form.toJSONString();

  document.getElementById("statusbar").innerHTML = "Laden ...";
  ExecuteAjax($mm);
}

function doRunEvents($field) {
  
  resetColor();
  getFormElements("no"); 
  var $aktrec=$form.data[0];
  for ( $t in $aktrec) {
      if ( $t == 'toJSONString' ) {
         continue;
      }
      //alert($aktrec[$t][0] +',' + $aktrec[$t][1]);
      if (($aktrec[$t][0] == false ) && ($aktrec[$t][1] == '')) $aktrec[$t][0]='';
  }
  
  $form.info="";
  $form.command="do_runevents";
  $form.formtype="apiisajax";
  $form.event=new Object();
  $form.event=$field;
  var $mm= $form.toJSONString();

  document.getElementById("statusbar").innerHTML = "Öffnen  ...";
  ExecuteAjax($mm);
}


function Navigation(event, field) {
  var $n=$config.general.floworder[field][1];
  var $v=$config.general.floworder[field][0];
  document.getElementById(field).setAttribute('autocomplete','off');
  document.getElementById($n).setAttribute('autocomplete','off');
  document.getElementById($v).setAttribute('autocomplete','off');
  if (event == 13) {
    // || (event == 40))  {
    resetColor();
    document.getElementById($n).style.backgroundColor="lightgreen";
    document.getElementById($n).focus();
  }  
//  if (event == 38) {
//    document.getElementById($v).focus();
//  }  
}

function SetElement(field) {
    resetColor();
    document.getElementById(field).style.backgroundColor="lightgreen";
}


function JumpFields(event) {
  return;
}

/*-----------------------------------------------------------------------*/
// reset reduced select-elements 
//
function ResetSelectElements() {
  
    //Select-elements in forms suchen with loop over all elements
    for (i=0;i<document.forms[0].elements.length;i++) {
    
        // is a select element?
        if ((document.forms[0].elements[i].type == 'select-one') || 
            (document.forms[0].elements[i].type == 'select-multiple')) {
      
            // select element has reduced entries
            if ((document.forms[0][i].bak != null) && (document.forms[0][i].bak.length>0)) {

                // write bak all entries which are removed in one step
                var $tt=document.forms[0][i].bak.length;
	            for (j=0;j<$tt;j++) {
                    var $t=document.forms[0][i].bak.pop();
                    for (k=0;k<$t.length;k++) {

	                    // append entries in options
                        document.forms[0][i].options[document.forms[0][i].options.length]=new Option( $t[k][1], $t[k][0]); 
                    }
	            }  
            }
        }

        // string for comparsion set to ''
        document.forms[0][i].searchstring='';
    }
}
/*------------------------------------------------------------------*/

function ReduceEntries(e,field,pos_suchen) {

   if (e == 13) {
      document.getElementById("statusbar").innerHTML = " Ok";
      Navigation(e, field);
      return;
   } 
   if (e == 9) {
     document.getElementById("statusbar").innerHTML = " Ok";
     return;
   }
   if ((e == 0) || ((e == 8) && (document.forms[0][field].bak.length<1))) {
     document.forms[0][field].searchstring=null;
     document.getElementById("statusbar").innerHTML = " Ok";
     return;
   }  
   
   if (e == 32) {$dd=' '};
   
   if (( e < 48 )  && (e != 8)) {return};

   var $dd=String.fromCharCode(e);
   if (e == 96) {$dd='0'};
   if (e == 97) {$dd='1'};
   if (e == 98) {$dd='2'};
   if (e == 99) {$dd='3'};
   if (e == 100) {$dd='4'};
   if (e == 101) {$dd='5'};
   if (e == 102) {$dd='6'};
   if (e == 103) {$dd='7'};
   if (e == 104) {$dd='8'};
   if (e == 105) {$dd='9'};
   if (e == 106) {$dd='*'};
   if (e == 107) {$dd='+'};
   if (e == 108) {$dd='0'};
   if (e == 109) {$dd='-'};
   if (e == 110) {$dd='.'};
   if (e == 111) {$dd='/'};

   if (pos_suchen == null) pos_suchen='left';
   //if (document.forms[0][field].searchstring == null) document.forms[0][field].searchstring=new String('');
   if (document.forms[0][field].searchstring == null) { 
     document.forms[0][field].searchstring  = $dd;
     document.forms[0][field].newoption     = 0;
   } else {
       if (e != 8) {
     document.forms[0][field].searchstring =document.forms[0][field].searchstring+$dd;
       }
   }
   
   // Initialisierung mit leerem Array
   if (document.forms[0][field].bak == null) {
       document.forms[0][field].bak=[];
   }
   
   // Schleife über alle Einträge
   var $a=[];
   
    // 0=Tab/Esc; 8=Back; 13=Enter;
    if (e == 8) {

        // wenn etwas in bak steht 
        if (document.forms[0][field].bak.length>0) {

            // Suchstring um eins reduzieren
            document.forms[0][field].searchstring=document.forms[0][field].searchstring.slice(0,document.forms[0][field].searchstring.length-1);

            var $t;
                // letzten Block zurückholen
                $t=document.forms[0][field].bak.pop();

            // wenn $t undef, dann reduzierten String zurückschreiben
            if (( $t.length == 0 ) && ( document.forms[0][field].newoption == 1 )) {
	            document.forms[0][field].options[0].value=document.forms[0][field].searchstring;
	            document.forms[0][field].options[0].text =document.forms[0][field].searchstring;
            }

            // newoption zurücksetzen
            if (($t.length > 0) && ( document.forms[0][field].newoption > 0 )) {

                document.forms[0][field].options[0]=null;
                document.forms[0][field].newoption--;
            }

            // Schleife über alle Einträge
            for (k=0;k<$t.length;k++) {
                document.forms[0][field].options[document.forms[0][field].options.length]=new Option( $t[k][1], $t[k][0]); 
            }

            // Suchstring in der Statusbar anzeigen
            if (document.forms[0][field].searchstring.length>0) {
                document.getElementById("statusbar").innerHTML = "Suchstring: " + document.forms[0][field].searchstring ;
            }
            else { 
                document.getElementById("statusbar").innerHTML = " Ok";
            }	 
        }
    } 
    // wenn  
    else {
     
        // neue Methode anlegen, wenn Sicherung der Optionen noch nicht existiert
        var $bak=[];
        var $dds;

        if ((document.forms[0][field].options.length > 0) || (document.forms[0][field].newoption == 1)) {
       
            // Suchstring auf andere Variable kopieren
            $dds=document.forms[0][field].searchstring;

            //Suchstring anzeigen in Statuszeile 
            document.getElementById("statusbar").innerHTML = "Suchstring: " + $dds ;

            var $tt=0;
      
            // Regex definieren, Suche des Suchstrings in den Values 
            var reg = new RegExp ($dds,"i");

            // Schleife über alle Listfeld-Einträge 
            for (k=0;k<document.forms[0][field].options.length;k++) {

                // Regex ausführen 
                var $erg=document.forms[0][field].options[k].text.search(reg);

                // Wenn nicht gefunden, dann Wert aus Liste löschen und kopieren nach bak 
                if ($erg == -1) {

                    // Flag, bak wurde gefüllt 
	                $tt=1;

                    // Array mit Herausgelöschten Listeneinträgen
                    $a.push(k);

                    // Aufbau eines neuen Optionsobjekts
	                var $t=new Array();
	                $t[0]=document.forms[0][field].options[k].value;
	                $t[1]=document.forms[0][field].options[k].text;

                    // speichern in bak, wenn es kein neuer Wert ist
                    $bak.push($t);
                }
            } 

            // Suchstring sichern
            if ($tt == 1) { 
                document.forms[0][field].searchstring=$dds;
            }
        }

        // nur ausführen, wenn tatsächlich etwas reduziert wurde
        if ($a.length>0) {
  
            //save deleted entries from Scrollinglist
            document.forms[0][field].bak.push($bak);

            for (k=$a.length-1;k>=0;k--) {
                document.forms[0][field].options[$a[k]]=null;
            }    
       
       // Eintrag entsprechend der Eingabefolge suchen
       //for (k=0;k<document.forms[0][field].options.length;k++) {
       //  //von vorn beginnende
       //	 if (pos_suchen == "left") {
       //    var reg = new RegExp (document.forms[0][field].searchstring,"i");
       //    var $erg=document.forms[0][field].options[k].text.search(reg);
       //    if ($erg != -1) {
       //	   }  
       //	 // von hinten beginnend
  	// } else {
          // var reg = new RegExp (document.forms[0][field].searchstring,"i");
          // var $erg=document.forms[0][field].options[k].text.search(reg);
	 //}

       //}
        }
        else {
            //save deleted entries from Scrollinglist
            document.forms[0][field].bak.push($bak);

        }


        // es wurde kein Muster gefunden => Falsch oder Neueingabe
        if ( document.forms[0][field].options.length < 1 )   {

            // Wenn Neueingabe OnlyListEntries="yes" muss gesetzt sein
            if (document.forms[0][field].getAttribute('onlylistentries') == 'no') {
                // Aufbau eines neuen Optionsobjekts
                //document.forms[0][field].searchstring=document.forms[0][field].searchstring + $dd
	            var $t=new Array();
	            $t[0]=document.forms[0][field].searchstring;
	            $t[1]=document.forms[0][field].searchstring;

                // speichern in bak
                document.forms[0][field].options[document.forms[0][field].options.length]=new Option( $t[1], $t[0]);

                // newoption setzen
                document.forms[0][field].newoption++;
            }
        }
    }
   
    // Focus setzen: yellow, neuer Wert
    if ((document.forms[0][field].options.length==1) && ( document.forms[0][field].newoption > 0 )) {
         document.forms[0][field].style.background="yellow";
    }
    // Focus setzen: lightblue, wenn nur noch ein Eintrag => eindeutig
    else if (document.forms[0][field].length==1) {
        document.forms[0][field].style.background="lightblue";
    } 
    // es sind noch mehrere Einträge im Listfeld
    else {
        document.forms[0][field].style.background="lightgreen";
    }
}


function doSaveForm() {
 
    if (! confirm("Daten abschicken?")) {
        return;
    }

    // save last input into $form.data
    resetColor();
    getFormElements(); 
    if ($verror) {
        $verror=false;
        return;
    }

    // first delete all records, which are not changed
    var $vneu=0;
    var $vchanged=0;
    var $delete=[];
    //alert($form.data.length);
    for ($i=0;$i<$form.data.length;$i++) {
        var $aktrec=$form.data[$i];
        var $changed=false;
        var $notnew=false;
        for ( $t in $aktrec) {
            if ( $t == 'toJSONString' ) {
                continue;
            }
            //alert($aktrec[$t][0] +',' + $aktrec[$t][1]);
            //if (($aktrec[$t][0] == false ) && ($aktrec[$t][1] == '')) $aktrec[$t][0]='';

            if ($aktrec[$t][0] != $aktrec[$t][1]) $changed=true;
            if (($aktrec[$t][1] != '') && ($aktrec[$t][1] != null))            $notnew=true;
        }
        if (($notnew == true) && ($changed == true)) {
            $vchanged++;
        } else if ($notnew == false) {
            $vneu++;
        }
        else {
            $delete.push($i);
        }
    }

    //for($i=$delete.length-1;$i>=0;$i--) {
    //  $form.data.splice($delete[$i],1);
    //  //doDeleteRecord($delete[$i]);
    //}

    if (($vneu+$vchanged) == 0) {
        alert("Keine Änderungen oder neue Daten zum Senden.");
        return;
    } else {
        document.getElementById("statusbar").innerHTML = "Speichern ... (neu: "+$vneu+", geändert: "+$vchanged+") ";
    }
    $form.info="";
    $form.command="do_save_block";
    $form.formtype="apiisajax";
    var $mm= $form.toJSONString();
    ExecuteAjax($mm);
}


//-------------------------------------- Navigation 
function doNextRecord() {
  getFormElements();
  currentRecord($current_record+1);
}
function doLastRecord() {
  getFormElements();
  currentRecord($max_record-1);
}
function doFirstRecord() {
  getFormElements();
  currentRecord(0);
}
function doPrevRecord() {
  getFormElements();
  currentRecord($current_record-1);
}
function doRecord() {
  getFormElements();
  var $a=document.getElementById("__nav_r").value;
  currentRecord($a-1);
}
function doNewRecord() {
  getFormElements();
  newFormElements();
  $max_record++;
  currentRecord($max_record-1);
}

function currentRecord(rec) {
  // new current record
  $current_record=rec;

  // set min/max if overflow
  if ($current_record >= $max_record-1) $current_record=$max_record-1;
  if ($current_record <= 0) $current_record=0;

  // fill form elements with data
  setFormElements();

  if (rec == 0) {
    document.getElementById($config.general["tab_first"]).style.backgroundColor="lightgreen"; 
    document.getElementById($config.general["tab_first"]).focus(); 
  } else {
    document.getElementById($config.general["tab_0"]).style.backgroundColor="lightgreen"; 
    document.getElementById($config.general["tab_0"]).focus(); 
  }

  // update record in navigationbar
  if (document.forms[0]["__nav_r"] != null) {  
    document.forms[0]["__nav_r"].value=($current_record+1)+'/'+$max_record;
  }  
}
//------------------------------------ End Navigation


function initFormElements () {

  // if a new form via callform
  if ($form.newform != null) {
    var $options;

    // prepare options for opening window
    $options="menubar=no,toolbar=no,titlebar=no,"+"status=no"+$form.newform[0].options;
    $options="";

    // open a new form
    var $fenster=window.open("",$form.newform[0].name,$options);
    $fenster.document.open();

    // write html-code and close initialization
    $fenster.document.write($form.newform[0].data);
    $fenster.document.close();
    $form.newform=null;
  }

  $max_record=$form.data.length;
  // all 
  for ($i=0;$i<$form.data.length;$i++) {
    var $aktrec=$form.data[$i];
    for ( $t in $aktrec) {
      if ( $t == 'toJSONString' ) continue;
      // init 
      if ($aktrec[$t][0] == null) $aktrec[$t][0]='';
      if (($aktrec[$t][1] == null) || ($aktrec[$t][1] == '')) $aktrec[$t][1]=$aktrec[$t][0];
      $resetcolor[$t]=document.getElementById($t).style.backgroundColor;
    }
  }
  currentRecord(0);
}

// Reset Color after error to original color
function resetColor() {
    for ( $t in $resetcolor) {
      if (( $t == 'toJSONString' ) || ($t == '')) continue;
      document.getElementById($t).style.backgroundColor=$resetcolor[$t];
    }
}

function newFormElements() {
  // record duplizieren
  $form.data[$max_record]=new Object();
  var $aktrec=$form.data[$max_record-1];
  var $currec=$form.data[$current_record];
  var $aktrecn=$form.data[$max_record];
  for ( $t in $aktrec) {
    if ( $t == 'toJSONString' ) {
       continue;
    }
    $aktrecn[$t]=new Array();
    $aktrecn[$t][0]=$config.fields[$t]["default"];
    $aktrecn[$t][1]=$config.fields[$t]["default"];
    if (($config.fields[$t]["defaultfunction"] == "lastrecord") ||
        ($config.fields[$t]["defaultfunction"] == "today"))    {
      $aktrecn[$t][0]=$aktrec[$t][0];
      $aktrecn[$t][1]=$aktrec[$t][0];
    }
    if ($config.fields[$t]["defaultfunction"] == "activerecord") {
      $aktrecn[$t][0]=$currec[$t][0];
      $aktrecn[$t][1]=$currec[$t][0];
    }
  }
}


// delete a record from $form.data and refresh form with values from next record 
//
function doDeleteRecord(record) {
  if (! confirm("Datensatz löschen?")) {
    return;
  }

  if (($current_record == 0) && ($max_record-1 == 0)) {
     doClearForm();
  } else {
    if (record == null) {
      $form.data.splice($current_record,1);
    } else {
      $form.data.splice(record,1);
    }

    $max_record=$form.data.length;
    if ($current_record >= $max_record-1) $current_record=$max_record-1;
    document.forms[0]["__nav_r"].value=($current_record+1)+'/'+$max_record;

    setFormElements();
  } 
  ResetSelectElements();
}

function setFormElements() {
  
  document.getElementById("statusbar").innerHTML = 'Ok.';
  resetColor();

  var $aktrec=$form.data[$current_record];

  if ($form.errors != null) {
    var $akterr=$form.errors[$current_record];
    for ($k in $akterr) {
      
      if ( $k == 'toJSONString' ) {
         continue;
      }
      $akterr[$k]= $akterr[$k].replace(/;/g,'\n');
      alert($akterr[$k]);
    }
    
    // Fehlermeldung löschen
    $form.errors[$current_record]=null;
  }

  for ( $t in $aktrec) {
    if ( $t == 'toJSONString' ) {
       continue;
    }
    if (( document.getElementById($t).type == 'text' ) || ( document.getElementById($t).type == 'select-one')) {
       document.getElementById($t).value = $aktrec[$t][0];
    } else if (( document.getElementById($t).type == 'checkbox' )) {

       // bei checkbox false oder 0 "false" oder "0" ist falsch 
       document.getElementById($t).checked = $aktrec[$t][0];
    }
    if (($aktrec[$t][2] != '') && ($aktrec[$t][2] != null)) {
       document.getElementById($t).style.backgroundColor = "red";
       alert ($aktrec[$t][2]);
    }

  }

}

function getFormElements(check) {
  
  document.getElementById("statusbar").innerHTML = 'Ok.';
  var $aktrec=$form.data[$current_record];
  for ( $t in $aktrec) {

    if ( $t == 'toJSONString' ) continue;
    if (check != 'no') checkField($t);

    if ( (document.getElementById($t).type == 'text' ) || (document.getElementById($t).type == 'select-one' )) {
       // save original value
       if (document.getElementById($t).value != $aktrec[$t][0]) $aktrec[$t][1]=$aktrec[$t][0];
       $aktrec[$t][0]=document.getElementById($t).value;

    } else if (( document.getElementById($t).type == 'checkbox' )) {
       // bei checkbox false oder 0 "false" oder "0" ist falsch 
       if (document.getElementById($t).checked != $aktrec[$t][0]) $aktrec[$t][1]=$aktrec[$t][0];
       $aktrec[$t][0]=document.getElementById($t).checked;
    
    }

    // clear errormessages if value changed
    if ($aktrec[$t][0] != $aktrec[$t][1]) $aktrec[$t][2]='';

  }
  
  // write back removed entries in a select element
  ResetSelectElements();

}

function doClearForm() {
    if (confirm("Alle Daten im Formular löschen?")) {
        $max_record=1;
        var $aktrec=$form.data[0];
        for ( $t in $aktrec) {
            if ( $t == 'toJSONString' ) {
                continue;
            }
    
            if ( (document.getElementById($t).type == 'text' ) || 
                 (document.getElementById($t).type == 'select-one')) {
                $aktrec[$t][0]='';
                $aktrec[$t][2]='';
            } 
            else if (( document.getElementById($t).type == 'checkbox' )) {
                // bei checkbox false oder 0 "false" oder "0" ist falsch 
                $aktrec[$t][0]=false;
                $aktrec[$t][2]=false;
            }
        }
        $form.data=[$aktrec];
        currentRecord(0);
        ResetSelectElements();
    }  
}

function doResetForm() {
  var $aktrec=$form.data[$current_record];
  for ( $t in $aktrec) {
    if ( $t == 'toJSONString' ) continue;

    if ((document.getElementById($t).type == 'text' ) || (document.getElementById($t).type == 'select-one')) {
       if ($aktrec[$t][1] != $aktrec[$t][0]) document.getElementById($t).value = $aktrec[$t][1] ;
    } else if (( document.getElementById($t).type == 'checkbox' )) {
       if ($aktrec[$t][1] != $aktrec[$t][0])  document.getElementById($t).checked = $aktrec[$t][1];
    }
  }
  ResetSelectElements();
}

function checkField(field) {
  var $value=document.getElementById(field).value;
  new String($value);
  var $type=$config.fields[field]["type"];
  var $check=$config.fields[field]["check"];
  var $msg="Ok";
  for($i=0;$i<$check.length;$i++) {
    $check[$i]=$check[$i].toLowerCase();
    if (($check[$i] == 'notnull')  && ($value =='')) {
      $msg='Feld muß Wert enthalten';
    } else if ($value == '') {
      return;
    } else if ($check[$i] == 'isanumber')  {
      $value=$value.replace(/,/,'.');
      if ($value.search(/^[+-]?\d*\.?\d*$/) == -1 ) {
        $msg='Keine Zahl';
      }
/*    } else if ($check[$i].search(/^range/i) > -1 )  {
      var result=$check[$i].match(/\d*\.?\d/g);
      var $min=new Number(result[0]);
      var $max=new Number(result[1]);
      if (($value <$min) || ($value >$max)) {
        $msg=$value + ' außerhalb des Definitionsbereiches: '+$min+' - '+$max;
      }*/
    } else if (($check[$i] == 'isadate') || ($check[$i] == 'date'))  {
      var $vdate=new Date();
      $_j=$vdate.getFullYear();
      $_m=$vdate.getMonth()+1;
      if ($_m<10) $_m='0'+$_m;
      $_d=$vdate.getDay()+1;
      if ($_d<10) $_d='0'+$_d;
 
      $value= $value.replace(/,/g,'.');
      if (($config.general["date_format"] == 'ge' ) || ($config.general["date_format"] == 'eu')) {
	if ($value.search(/\./) == -1) {
	  if (($value.length == 1) || ($value.length == 3) || ($value.length == 5) || ($value.length == 7)) {
	    $value='0'+$value;
	  }
	  if ($value.length == 2) {
	    $value+='.'+$_m+'.'+$_j;
	  } else if ($value.length == 4) {
	    $value=$value.substr(0,2)+'.'+$value.substr(2,2)+'.'+$_j;
	  } else if ($value.length == 6) {
	    $value=$value.substr(0,2)+'.'+$value.substr(2,2)+'.20'+$value.substr(4,2);
	  } else if ($value.length == 8) {
	    $value=$value.substr(0,2)+'.'+$value.substr(2,2)+'.'+$value.substr(4,4);
          }
	} else {
          if ($value.search(/^.{1,2}\..{1,2}\..{1,4}$/) > -1 ) {
	    $value=$value;
          } else if ($value.search(/^.{1,2}\..{1,2}\.$/) > -1 ) {
	    $value+=$_j;
	  } else if ($value.search(/^.{1,2}\..{1,2}$/) > -1 ) {
	    $value+='.'+$_j;
	  } else if ($value.search(/^.{1,2}\.$/) > -1 ) {
	    $value+=$_m+'.'+$_j;
	  } else if ($value.search(/^.{1,2}$/) > -1 ) {
	    $value+='.'+$_m+'.'+$_j;
	  }  
          var $a=new Array();
	  $a=$value.match(/(.+?)\.(.+?)\.(.+)/);

          var $t = $a[1];
	  if ($t.search(/^.$/) > -1 ) $t='0'+$t;
	  var $m = $a[2];
	  if ($m.search(/^.$/) > -1 ) $m='0'+$m;
          var $j = $a[3];

          if ($m >12) $msg='Falsches Datum';
	  if ($m < 1) $msg='Falsches Datum';
	  if ($t < 1) $msg='Falsches Datum';
        
	  reg2 = /04|06|09|11/;
          if (reg2.test($m)) {
            if ($t >30){
	      $msg='Falsches Datum';
	    }
          } 
          if ($t>31) $msg='Falsches Datum';
          if ($m==2) {
            if ($j%4==0 && $t>29) $msg='Falsches Datum';
            if ($j%4!=0 && $t>28)  $msg='Falsches Datum';
          }
	
          $value=$t+'.'+$m+'.'+$j;
        
	  /* test Datum */
          reg1 = /[0-3][0-9]\.[01][0-9]\.[12][90][0-9][0-9]/;
          if (!reg1.test($value)) $msg='Falsches Datum';
        }
      }

    } else if ($type == 'text') {
    }
  }
  if ($msg != "Ok") {
    document.getElementById(field).style.backgroundColor = "red";
    $verror=true;
    alert($msg);
    document.getElementById(field).focus();
  } else {
    document.getElementById(field).value=$value;
  }
}

function errorHandler(msg) {
    document.getElementById("statusbar").innerHTML = msg;
}

function loadText() {
/* $form={"form":"test.pl",
           "sid":"1234",
	   "model":"ovicap_sn",
	   "user":"b08mueul",
	   "data":[{"t1":["abb",,],"t2":[0,,],"t3":["K",,],"t4":[1,,]},
	           {"t1":["a",,]  ,"t2":[1,,],"t3":["D",,],"t4":[3,,]},
	           {"t1":["a",,]  ,"t2":[1,,],"t3":["E",,],"t4":[5,,]},
	           {"t1":["c",,]  ,"t2":[0,,],"t3":["T",,],"t4":[7,,]}
		   ]};
  $config={"general":{"date_order":"dd.mm.yyyy", "date_sep":'.',"date_format":"ge"},
           "fields":{"t1":{"type":"date","default":"01.01.2006","defaultfunction":"lastrecord","check":["isadate"]},
                     "t2":{"type":"bool","default":true,"defaultfunction":"","check":[]},
                     "t3":{"type":"text","default":"","defaultfunction":"lastrecord","check":[]},
                     "t4":{"type":"number","default":3,"defaultfunction":"activerecord","check":["isanumber","notnull","range 3 40"]}}};
*/

  initFormElements($form.data);
}

function frmHasError(msg) {
  if (!msg)  return false;
  if (msg.indexOf("frmError:") == 0 ) {
    return true;
  } else {
    return false;
  }
}

window.onload = loadText;
