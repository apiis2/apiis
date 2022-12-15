<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE html
	PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US"><head><title>Form with one textfield and an Exit button</title>
<link rel="stylesheet" type="text/css" href="etc/apiis.css" />
<style type="text/css">
<!--/* <![CDATA[ */
input.Field_1{color: blue;background-color: yellow}input.Field_0{color: red}

/* ]]> */-->
</style>
</head><body class="menu" onKeyUp="JumpFields(event)" onLoad="Refresh()" onSubmit="Refresh()" ><form method="get" action="/cgi-bin/GUI" enctype="application/x-www-form-urlencoded">
<table style="border:solid black 1px" bgcolor="lightgray" ><TR></TR><TR><td>Datum:</td><td class="Field_0">
<Input  class="Field_0" name="Field_0" onChange="CheckValue()" onFocus="CheckPosition('Field_0')" type="TextField" size="20" override ="no" ></td><td><Img style="vertical-align:bottom" src="/icons/unknown.png" onClick="alert('Datumsfeld mit automatischer Vervollständigung, bei Fehler OK mit Leertaste betätigen'); CheckPosition('Field_0')"></td></TR>
<TR><td>Zahl:</td><td class="Field_0" ><Input  class="Field_1" name="Field_1"  onFocus="CheckPosition('Field_1')" onChange="CheckValue()" type="TextField" size="20" override ="no" ></td><td><Img style="vertical-align:bottom" src="/icons/unknown.png" onClick="alert('Zahlenfeld mit Format ##.#. Focus springt automatisch weiter, wenn Nachkommastelle vollständig eingegeben wurde oder die gesamte Zahl vollständig ist. Zahlen ohne  ,  werden um die 0 vervollständigt, Kommas werden in Punkt umgewandelt.')"></td></TR>
<TR><td><u>K</u>ey:</td><td class="Field_0" ><Input  class="Field_2" name="Field_2" accesskey="k" onFocus="CheckPosition('Field_2');SetDefault('Field_2')" onChange="CheckValue()" type="TextField" size="20" override ="no" ></td><td><Img style="vertical-align:bottom" src="/icons/unknown.png" onClick="alert('Feld kann mit ALT+K angesprungen werden.'); CheckPosition('Field_0')"></td></TR>
<TR><td>Rasse:</td><td><SELECT NAME="Field_4" onFocus="CheckPosition('Field_4')" onChange="CheckValue()"   >
   <OPTION VALUE="a">DU</OPTION>
   <OPTION VALUE="b">PI</OPTION>
   <OPTION VALUE="c">DE</OPTION>
   <OPTION VALUE="d">DL</OPTION>
 </SELECT>
</td></TR>
<TR><td>Geschlecht:</td><td>
<SELECT NAME="Field_5" onFocus="CheckPosition('Field_5')" onChange="CheckValue()"  >
   <OPTION VALUE=1>M</OPTION>
   <OPTION VALUE=2>W</OPTION>
 </SELECT>
 </td></TR>
 <TR><td>
</td></TR>

<SCRIPT LANGUAGE="JavaScript">
  <!--

  var $_act_rec=0;
  var $data=[[5,'','','c','1'],['','1','','b','1'],['','2','','d','2'],['','14.3','','a','2']];
  var $stat=new Array('','','','','');
  var $stru=new Array('Field_0','Field_1','Field_2','Field_4','Field_5');
  var $frmt=new Array('','##.#','','','');
  var $type=new Array('d','n','t','t','t');
  var $default=new Array('','','l','','');
  var $_last_rec=4;
  var $_act_field=0;


var data= [['V8','DU','V1','W'],
           ['V7','PI','V2','W'], 
           ['V6','PI','V3','W'],
           ['V6','DL','V3','W'],
           ['V6','DE','V3','M'],
           ['V5','DU','V4','M']];
	  
var i,k,j;	  
var connect_selects=new Array ("V1","V2");
var pos=new Array();
for (i = 0; i < connect_selects.length;i++) {pos[connect_selects[i]]=i};

function FilterOnSelectedItem(sel_object) { 
  var i, j, k,  vpos;
  var looked_column;
  var looked_text;
  var looked_object;
  var data_red=new Array;

  

  
  if (sel_object!=null) {
    looked_column=sel_object.selectedIndex;
    looked_text=sel_object.options[looked_column].text;
    looked_object=sel_object.name;
    vpos=pos[looked_object]*2+1;
    if (document.images) document.images['disconnect'].src = eval("connect.src");
  } else {
    if (document.images) document.images['disconnect'].src = eval("disconnect.src");
  }
  
  /* null for all select fields which defined in array  */
  for (j=0;j < connect_selects.length;j++) {
    for (i=document.forms[0][connect_selects[j]].options.length; i>=0; i--) {
      document.forms[0][connect_selects[j]].options[i]=null;
    }  
  } 
  
  /* Select-Einträge reduzieren*/
  for (j=0;j < connect_selects.length;j++) {
    var n=0;
    for (i = 0; i < data.length;i++) { 
      if (data[i][ vpos ] == looked_text) {
        var ok=1;
        for (k=0;k<document.forms[0][connect_selects[j]].options.length;k++) {
	  if (document.forms[0][connect_selects[j]].options.length >0 )  {
	    if (document.forms[0][connect_selects[j]].options[k].text == data[i][j*2+1]) {
	      ok=0;
	    }
	  }  
	}
	if (ok==1) {
          document.forms[0][connect_selects[j]].options[n] = new Option(); 
          document.forms[0][connect_selects[j]].options[n].value = data[i][j*2];  
          document.forms[0][connect_selects[j]].options[n].text = data[i][j*2+1];  
 	  n++;
	}  
      }	
    }
  }  

  /*sel_object.options[0].selected = true;*/
}

  function SetDefault(field) {
    if (($default[$_act_field] !='') && ($data[$_act_rec][$_act_field] == '')) {
     if (($default[$_act_field]=='l') && ($_act_field>0)) {
        $data[$_act_rec][$_act_field]=$data[$_act_rec-1][$_act_field];
        document.forms[0][$stru[$_act_field]].value=$data[$_act_rec-1][$_act_field];
      }
    }
  }
  
  function CheckPosition(field) {
    for ($i=0;$i<=$stru.length;$i++) {
      if ($stru[$i]==field) {
        $_act_field=$i;
      }
    }  
  }

  function CheckValue() {
    if ($stat[$_act_field] == '') $stat[$_act_field]='u';
  }

  function NextField() {
    $_act_field++;
    if ($_act_field>$stru.length-1) {
      $_act_field=0;
      MoveNext();
    }	
    try { document.forms[0][$stru[$_act_field]].select()}
    catch(e) {
      document.forms[0][$stru[$_act_field]].focus();
    } 
  }

  function CheckDate(dat) {
    if ($dat == '') return; 
	var $msg='';
	var $dat=dat;
	var $vdate=new Date();
	$_j=$vdate.getFullYear();
	$_m=$vdate.getMonth()+1;
	if ($_m<10) $_m='0'+$_m;
	$_d=$vdate.getDay()+1;
	if ($_d<10) $_d='0'+$_d;
	
	new String($dat);
	$dat= $dat.replace(/,/g,'.');
        if ($dat.search(/^.{1,2}\..{1,2}\..{1,4}$/) > -1 ) {
	  $dat=$dat;
        } else if ($dat.search(/^.{1,2}\..{1,2}\.$/) > -1 ) {
	  $dat+=$_j;
	} else if ($dat.search(/^.{1,2}\..{1,2}$/) > -1 ) {
	  $dat+='.'+$_j;
	} else if ($dat.search(/^.{1,2}\.$/) > -1 ) {
	  $dat+=$_m+'.'+$_j;
	} else if ($dat.search(/^.{1,2}$/) > -1 ) {
	  $dat+='.'+$_m+'.'+$_j;
	} else {
	  return false;
	}  
        var $a=new Array();
	$a=$dat.match(/(.+?)\.(.+?)\.(.+)/);

        $t = $a[1];
	if ($t.search(/^.$/) > -1 ) $t='0'+$t;
	$m = $a[2];
	if ($m.search(/^.$/) > -1 ) $m='0'+$m;
        $j = $a[3];

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
          if($j%4!=0 && $t>28)  $msg='Falsches Datum';
        }
	
        $dat=$t+'.'+$m+'.'+$j;
        
	/* test Datum */
        reg1 = /[0-3][0-9]\.[01][0-9]\.[2][0][0-9][0-9]/;
        if (!reg1.test($dat)) $msg='Falsches Datum';
	if ($msg !='') {
          return false;
	} else {
	  return $dat;
	}
  }
  
  function JumpFields(event) {
    var $nxt='';
    var $dat=document.forms[0][$stru[$_act_field]].value;

    if (($frmt[$_act_field] !='') && ($dat != '')) {
      var $vfrmt=$frmt[$_act_field];
      if ($type[$_act_field] == 'n') {
	$dat=$dat.replace(/,/,'.');
	if ($dat.match(/[^0-9+-.,]/) != null) {
	  alert("Fehler");
	  document.forms[0][$stru[$_act_field]].select();
	  return;
	}  
        var $nkf=$vfrmt.match(/\.(.*)$/);
        var $nkd=$dat.match(/\.(.*)$/);
        if ($nkd == null) $nkd=[0,0];
        if ($nkf == null) $nkf=[0,0];
        if (($dat.length == $vfrmt.length) && ($dat.search(/\./) != -1)) $nxt='1';
        if (($nkf[1].length == $nkd[1].length) && ($nkd[1].length > 0))  $nxt='1';
      }	
    }
    if ((event.which==13) || ($nxt == '1')) {
      var $msg='';
    
      if (($type[$_act_field] == 'd') && ($dat != '')){
        $dat=CheckDate($dat);
	if (! $dat) {
	  $msg='Falsches Datum';
	}  
      }
      if ($type[$_act_field] == 'n') {
        $dat=$dat.replace(/,/,'.');
        if (($dat.search(/\./) == -1) && ($dat !='')){
          $dat+='.0';
        }
      }
      if ($msg == '') {
        document.forms[0][$stru[$_act_field]].value=$dat;
        $data[$_act_rec][$_act_field]=document.forms[0][$stru[$_act_field]].value;
        NextField();
      } else {
        alert($msg);
        document.forms[0][$stru[$_act_field]].select();
	return;
      }	
      if ($frmt[$_act_field] !='') {
      }
       
    }  
  }

  function Refresh() {
    for ($i=0;$i<$stru.length;$i++) {
      document.forms[0][$stru[$i]].value=$data[$_act_rec][$i];
    }  
    document.forms[0][$stru[0]].select();
    document.forms[0]["_nav_r"].value=$_act_rec+1;
    document.forms[0]["_nav_m"].value='von '+$_last_rec;
  }

  function MoveFirst() {
    $_act_rec=0;
    Refresh();
  }
  function MovePrev() {
    $_act_rec=$_act_rec-1;
    if ($_act_rec <0 ) $_act_rec=0;
    Refresh();
  }
  function MoveRec() {
    $_act_rec=document.forms[0]["_nav_r"].value - 1;
    if ($_act_rec <0 ) $_act_rec=0;
    if ($_act_rec >= $_last_rec) $_act_rec=$_last_rec-1; 
    Refresh();
  }
  function MoveNext() {
    $_act_rec=$_act_rec+1;
    if ($_act_rec >= $_last_rec) $_act_rec=$_last_rec-1;
    Refresh();
  }
  function MoveLast() {
    $_act_rec=$_last_rec-1;
    Refresh();
  }


  if (document.images) {
    var do_first = new Image();
    do_first.src = "/icons/do_first.png";
    var do_first2 = new Image();
    do_first2.src = "/icons/do_first2.png";
    
    var do_prev = new Image();
    do_prev.src = "/icons/do_prev.png";
    var do_prev2 = new Image();
    do_prev2.src = "/icons/do_prev2.png";
    
    var do_next = new Image();
    do_next.src = "/icons/do_next.png";
    var do_next2 = new Image();
    do_next2.src = "/icons/do_next2.png";
    
    var do_last = new Image();
    do_last.src = "/icons/do_last.png";
    var do_last2 = new Image();
    do_last2.src = "/icons/do_last2.png";
    
    var do_new   = new Image();
    do_new.src   = "/icons/do_new.png";
    var do_new2  = new Image();
    do_new2.src  = "/icons/do_new2.png";
    
    var disconnect   = new Image();
    disconnect.src   = "/icons/disconnect.png";
    var disconnect2  = new Image();
    disconnect2.src  = "/icons/disconnect2.png";
    
    var connect   = new Image();
    connect.src   = "/icons/connect.png";
    var connect2  = new Image();
    connect2.src  = "/icons/connect2.png";
}
function act(imgName) {
  if (document.images) document.images[imgName].src = eval(imgName + "2.src");
}
function inact(imgName) {
  if (document.images) document.images[imgName].src = eval(imgName + ".src");
}
// -->
</SCRIPT><TR>
      <td colspan="3" style="border-top:solid black 2px;padding:2px" >
         <img name="do_first" src="/icons/do_first.png" alt="erster Datensatz"  
	            onClick="MoveFirst()" 
	            onMouseOver="act('do_first')" onMouseOut="inact('do_first')">
         <img name="do_prev" src="/icons/do_prev.png" alt="vorheriger Datensatz" 
	            onClick="MovePrev()" 
	            onMouseOver="act('do_prev')" onMouseOut="inact('do_prev')">
         <input style="font-size:12px; vertical-align:top; text-align:right" 
	        id="_nav_r" name="_nav_r" onChange="MoveRec()" type"textfield" maxlength="5" size="5"></a> 
         <img name="do_next" src="/icons/do_next.png" alt="nächster Datensatz"  
	            onClick="MoveNext()" 
	            onMouseOver="act('do_next')" onMouseOut="inact('do_next')">
         <img name="do_last" src="/icons/do_last.png" alt="letzter Datensatz"  
	            onClick="MoveLast()" 
	            onMouseOver="act('do_last')" onMouseOut="inact('do_last')">
         <img name="do_new" src="/icons/do_new.png" alt="neuer Datensatz"  
	            onClick="alert('Springt zum neuen Datensatz')" 
	            onMouseOver="act('do_new')" onMouseOut="inact('do_new')">
         <input style="font-size:12px; vertical-align:top; text-align:left; border-style:none; background:lightgray"
	        id="_nav_m"  name="_nav_m" readonly value="0" size="10" >
      </td>
      </TR></table>

<p>
<table style="border:solid black 1px" bgcolor="lightblue">
<TR><td colspan="3"><H4>Beispiel für abhängige Listen</H4></td></TR><TR><td>Rasse:<SELECT NAME="V1" onFocus="CheckPosition('V1')"  onClick="FilterOnSelectedItem(this.form.V1)">
   <OPTION VALUE="a">DU</OPTION>
   <OPTION VALUE="b">PI</OPTION>
   <OPTION VALUE="c">DE</OPTION>
   <OPTION VALUE="d">DL</OPTION>
 </SELECT>
</td>
<td>Geschlecht:</td><td>
<SELECT NAME="V2" onFocus="CheckPosition('V2')" onClick="FilterOnSelectedItem(this.form.V2)">
   <OPTION VALUE=1>M</OPTION>
   <OPTION VALUE=2>W</OPTION>
 </SELECT>
 </td>
 <td>
<Img style="vertical-align:bottom" name="disconnect" src="/icons/disconnect.png" onClick="FilterOnSelectedItem()">&nbsp<Img style="vertical-align:bottom" src="/icons/unknown.png" onClick="alert('Beispiel zu voneinander abhängigen Scrollinglists. Nach einer Auswahl werden in der anderen Liste nur die Einträge angezeigt, für die die Auswahl zutreffen. Über die Kette kann die Verbindung gelöst und die Ausgangseinstellung eingestellt werden. Wenn man keine Auswahl treffen will, dann Kursor bei gedrückter Maustaste aus dem Listenfeld herausziehen.'); CheckPosition('Field_0')"></td>
</td></TR></table>
