//UTF8
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

  
  function CheckValue() {
    var $msg='';
    for ($j=0;$j<$_order_elements.length;$j++) {
      $_act_field=$_order_elements[$j];
      var $dat=document.getElementById($_act_field.Id[0]).value;
      /*document.getElementById($_order_elements[$i].Id[0]).value=$_order_elements[$i]._data_ref[$_act_rec];*/
      for ($i=0;$i<$_act_field._check.length;$i++) {
        if (($_act_field._check[$i] == 'IsANumber') && ($dat !='')) {
          $dat=$dat.replace(/,/,'.');
          /*if (($dat.search(/\./) == -1) && ($dat !='')){
            $dat+='.0';
          }*/
	  if (! CheckNumber($dat)) {
	    $msg='Keine Zahl';
	  };
	} else if (($_act_field._check[$i] == 'NotNull')  && ($dat =='')) {
	  $msg='Feld muß Wert enthalten';
	} else if ((($_act_field._check[$i] == 'IsADate') || ($_act_field.InputType[0] == 'date')) && ($dat !='')){
	  $dat=CheckDate($dat);
	  if (! $dat) {
	    $msg='Falsches Datum';
	  }  
	} else if (($_act_field._check[$i].search(/^range/i) > -1 ) && ($dat !='')) {
	  var result=$_act_field._check[$i].match(/\d+/g);
	  var $min=new Number(result[0]);
	  var $max=new Number(result[1]);
	  if (($dat <$min) || ($dat >$max)) {
	    $msg=$dat + ' außerhalb des Definitionsbereiches: '+$min+' - '+$max;
	  }
	} else if  ($_act_field.InputType[0] == 'number') { 
	  $dat=$dat.replace(/,/,'.');
          /*if (($dat.search(/\./) == -1) && ($dat !='')){
            $dat+='.0';
          }*/
	  if (! CheckNumber($dat)) {
	    $msg='Keine Zahl';
	  };
	}  
        if (($_act_field._error[$i] !='') &&
	    ($_act_field._error[$i] != null)) {
	    $msg=$_act_field._error[$i];
	}
      }
      if ($msg != '') {
        alert($msg);
//        if (document.getElementById($_act_field.Id[0]).type == 'Input') {
          document.getElementById($_act_field.Id[0]).focus();
          document.getElementById($_act_field.Id[0]).select();
//	}  
        return false;
      }	
    }
    
    for ($j=0;$j<$_order_elements.length;$j++) {
      if (($_order_elements[$j]._data_ref_bak[$_act_rec] != null) && 
          ($_order_elements[$j]._data_ref[$_act_rec] != $_order_elements[$j]._data_ref_bak[$_act_rec])) {
	$t=$_order_elements[$j]._parentblock[0];
        $t._updated[$_act_rec]='u';
      }
/*      document.getElementById($_order_elements[$j].Id[0]).value=$dat;*/
      if ((document.getElementById($_order_elements[$j].Id[0]).type == 'checkbox') && 
          (document.getElementById($_order_elements[$j].Id[0]).checked==true)) {
        $_order_elements[$j]._data_ref[$_act_rec]='t';
      } else {
        $_order_elements[$j]._data_ref[$_act_rec]=document.getElementById($_order_elements[$j].Id[0]).value;
      }
    } 
    return true;
  }
 
  function ShowMessages() {
    if (xf._messages != null) {
      for ($j=0;$j<xf._messages.length;$j++) {
        if ((xf._messages[$j] != null) && (xf._messages[$j] != '')) {
          alert(PrepareMessage(xf._messages[$j]));
        }
      }	
    }
  }

  function ErrorHandling(field) {
    $_act_field=field;
    
    // Change Color, if an input and input not equal the old value
    // delete error message
    if (document.getElementById($_act_field.Id[0]).value != $_act_field._data_ref_bak[$_act_rec]) {
      document.getElementById($_act_field.Id[0]).style.backgroundColor=$_act_field._color;
      $_act_field._error[$_act_rec]='';
      $_act_field._data_ref[$_act_rec]=document.getElementById($_act_field.Id[0]).value;
    }  
  }
  
  function NextField() {
    var $act_element_counter=$_act_field.NextElement[0];
    if ($_order_elements[$act_element_counter] == null) {
      $act_element_counter=0;
    }
    $_act_field=$_order_elements[$act_element_counter];
    document.getElementById($_order_elements[$act_element_counter].Id[0]).focus();
    if (document.getElementById($_order_elements[$act_element_counter].Id[0]).type == 'text') {
      var $a=document.getElementById($_order_elements[$act_element_counter].Id[0]);
      $a.select();
    }
  }

  function CheckNumber(dat) {
    if (dat.search(/^[+-]?\d*\.?\d*$/) > -1 ) {
      return true;
    } else {
      return false;
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
        reg1 = /[0-3][0-9]\.[01][0-9]\.[12][90][0-9][0-9]/;
        if (!reg1.test($dat)) $msg='Falsches Datum';
	if ($msg !='') {
          return false;
	} else {
	  return $dat;
	}
  }
  
  function JumpFields(event) {
    var $nxt='';
  }

  function PrepareMessage($message) {
    var $st=$message;
    $st=$st.replace(/;/g,"\n");
    $st=$st.replace(/"/g,"\"");
    return $st;
  }
  
  function Refresh() {
    if ($_blockname._messages[$_act_rec] != null) {
      for ($j=0;$j<$_blockname._messages[$_act_rec].length;$j++) {
        if (($_blockname._messages[$j] != null) && ($_blockname._messages[$j] != '')) {
	  alert(PrepareMessage($_blockname._messages[$j]));
        }
      }
    }
    for ($i=0;$i<$_order_elements.length;$i++) {
      if (document.getElementById($_order_elements[$i].Id[0]).type == 'checkbox') {
        document.getElementById($_order_elements[$i].Id[0]).value=$_order_elements[$i]._data_ref[$_act_rec];
	if (($_order_elements[$i]._data_ref[$_act_rec] == '1') ||
	    ($_order_elements[$i]._data_ref[$_act_rec] == 'true') ||
	    ($_order_elements[$i]._data_ref[$_act_rec] == 'on')) {
          document.getElementById($_order_elements[$i].Id[0]).checked=true;
	} else {
          document.getElementById($_order_elements[$i].Id[0]).checked=false;
	}
      } else {
        document.getElementById($_order_elements[$i].Id[0]).value=$_order_elements[$i]._data_ref[$_act_rec];
      }	
      if ($_order_elements[$i]._color == undefined) {
       // var $_order_elements[$i]._color=new String;
	$_order_elements[$i]._color=document.getElementById($_order_elements[$i].Id[0]).style.backgroundColor;
      }	
      if (($_order_elements[$i]._error[$_act_rec] != '') && 
          ($_order_elements[$i]._error[$_act_rec] != null)) {
        document.getElementById($_order_elements[$i].Id[0]).style.backgroundColor="red";
      } else {
        document.getElementById($_order_elements[$i].Id[0]).style.backgroundColor=$_order_elements[$i]._color;
      } 
    }  
    if ($_order_elements[0] != null) {
      document.getElementById($_order_elements[0].Id[0]).focus();
      if (document.getElementById($_order_elements[0].Id[0]).type == 'text') {
        var $a=document.getElementById($_order_elements[0].Id[0]);
        $a.select();
      }  
    }
    if (document.forms[0]["_nav_r"] != null) {
      document.forms[0]["_nav_r"].value=$_act_rec+1+'/'+$_last_rec;
    }  
  }

  function MoveFirst() {
    if (CheckValue()) {
      $_act_rec=0;
      Refresh();
    }  
  }
  function MovePrev() {
    if (CheckValue()) {
      $_act_rec=$_act_rec-1;
      if ($_act_rec <0 ) $_act_rec=0;
      Refresh();
    }  
  }
  function MoveRec() {
    if (CheckValue()) {
      $_act_rec=document.forms[0]["_nav_r"].value - 1;
      if ($_act_rec <0 ) $_act_rec=0;
      if ($_act_rec >= $_last_rec) $_act_rec=$_last_rec-1; 
      Refresh();
    }  
  }
  function MoveNext() {
    if (CheckValue()) {
      $_act_rec=$_act_rec+1;
      if ($_act_rec >= $_last_rec) $_act_rec=$_last_rec-1;
      Refresh();
    }  
  }
  function MoveLast() {
    if (CheckValue()) {
      $_act_rec=$_last_rec-1;
      Refresh();
    }  
  }
  function MoveNew() {
    if (CheckValue()) {
      $_last_rec++;
      var $_old_rec=$_act_rec;
      $_act_rec=$_last_rec-1;
    
      for ($i=0;$i<$_order_elements.length;$i++) {
        if ($_order_elements[$i].Default[0] != null)  {
          if (($_order_elements[$i].Default[0]=='_lastrecord') && ($_last_rec>1)) {
            $_order_elements[$i]._data_ref.push($_order_elements[$i]._data_ref[$_old_rec]);
          } else {
	    if ($_order_elements[$i].Default[0]!='_lastrecord') {
              $_order_elements[$i]._data_ref.push($_order_elements[$i].Default[0]);
	    }  
  	  }
        } else {
          $_order_elements[$i]._data_ref.push('');
        }
	$_order_elements[$i]._parentblock[0]._updated[$_act_rec]='i';
      }
      Refresh();
    }
  }
  function Clear() {
    if (confirm("Alle Daten im Formular löschen?")) {
      $_act_rec=0;
      $_last_rec=1;
      for ($i=0;$i<$_order_elements.length;$i++) {
        $_order_elements[$i]._data_ref=[''];
      }
      Refresh();
    }  
  }
    function OpenForm(_id,_formcounter) {
        if ((_id != null ) && (document.getElementById(_id).alt != null)) {
            document.getElementById('__form').value=document.getElementById(_id).alt;
        }
        
        document.forms[_formcounter].elements["g"].value=document.getElementById(_id).alt; 
        
        document.getElementById('__command').value='do_open_form';
        document.getElementById('__records').value=1;
        document.forms[_formcounter].action='/cgi-bin/GUI';
        document.forms[_formcounter].submit();
    }
  
  function OpenReport(_id,_formcounter) {
    if ((_id != null ) && (document.getElementById(_id).alt != null)) {
      document.getElementById('__form').value=document.getElementById(_id).alt;
    }
    document.forms[_formcounter].elements["g"].value=document.getElementById(_id).alt; 
    document.getElementById('__command').value='do_open_report';
    document.getElementById('__records').value=1;
    document.forms[_formcounter].action='/cgi-bin/GUI';
    document.forms[_formcounter].submit();
  }

  function Query(_id) {
    if ((_id != null ) && (document.getElementById(_id).alt != null)) {
      document.getElementById('__form').value=document.getElementById(_id).alt;
      if (document.getElementById(_id).alt.search(/frm/) != -1 ) {
         document.forms[4].action='/cgi-bin/GUI';
      }
    }
  
    document.getElementById('__command').value='do_query_block';
    document.getElementById('__commandfield').value=_id;
    document.getElementById('__records').value=1;
    document.forms[4].submit();
  }
  function Reset() {
    for ($j=0;$j<$_order_elements.length;$j++) {
      if (! $_order_elements[$j]._data_ref_bak[$_act_rec]) {
        $_order_elements[$j]._data_ref_bak[$_act_rec]='';
      }	
      document.getElementById($_order_elements[$j].Id[0]).value=$_order_elements[$j]._data_ref_bak[$_act_rec];
      $_order_elements[$j]._data_ref[$_act_rec]=document.getElementById($_order_elements[$j].Id[0]).value;
    } 
    document.getElementById($_order_elements[0].Id[0]).focus();
    if (document.getElementById($_order_elements[0].Id[0]).type == 'text') {
      document.getElementById($_order_elements[0].Id[0]).select();
    }  
  }
  function Delete() {
    if ($_act_rec > $_last_rec_bak-1) {
      if (confirm("Datensatz löschen?")) {
        for ($j=0;$j<$_order_elements.length;$j++) {
          $_order_elements[$j]._data_ref.splice($_act_rec,1);
        } 
        $_act_rec=$_act_rec-1;
        $_last_rec=$_last_rec-1;
        Refresh();
      }	
    }
  }
  function Submit(_id,Steuerung) {
    //alert(_id);
    if (CheckValue()) {
      if (confirm("Daten abschicken?")) {
        for ($j=0;$j<$_order_elements.length;$j++) {
	  //alert($_order_elements[$j]._data_ref[0]);
	  var $t=new Array;
	  var $r=new Array;
          for ($k=0;$k<$_last_rec;$k++) {
	    if (($k==0) || ($_order_elements[$j]._parentblock[0]._updated[$k] == 'u') || ($_order_elements[$j]._parentblock[0]._updated[$k] == 'i')) {
	      $t.push($_order_elements[$j]._data_ref[$k]);
	      //$r.push($_blockname._rowid[$k]);
	    }
	  }
          document.getElementById($_order_elements[$j].Id[0]).value=$t.join('+++');
        }
	if (document.getElementById(_id).alt != null) {
          document.getElementById('__form').value=document.getElementById(_id).alt;
        }
        document.getElementById('__command').value=document.getElementsByName('do_save')[0].id;
        document.getElementById('__commandfield').value=document.getElementsByName('do_save')[0].id;
        document.getElementById('__records').value=$t.length;
        //document.getElementById('__rowid').value=$r.join('+++');;
        document.forms[0].submit();
      } 
    }  
  }


function act(imgName) {
}
function inact(imgName) {
}
