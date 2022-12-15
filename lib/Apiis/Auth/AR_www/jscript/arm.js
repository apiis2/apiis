
// ACCESS RIGHTS MANAGER

  function check_status(my_form) {

	if (my_form == undefined) {//if no other form specified use default
	        my_form = document.forms[0];
	}

	var agree; 

	switch(my_form.form_status.value){
	case "insert":
	case "update":  
		agree=window.confirm(msg(1) + translate_status(my_form.form_status.value) + msg(2) );//confirm
	break;
        
        case "list":
		agree=false;
        break;
  
	case "edit": 
		var tmp_string="forms"+my_form.name;
		if(my_form.action.value!=tmp_string){agree=true;}	
		else{agree=false;}
	break; 
	default:
		agree=false;
		if(agree==false){
			window.alert(msg(3)); //no update
		}
	}

	return agree;
  }

function setstatus(my_form) {

	switch(my_form.form_status.value){
	case "new":
	case "insert":
		my_form.form_status.value="insert";
	break;
     
        case "list":
        break;

	case "edit":
	        my_form.form_status.value="update";
	break;

	default:
		my_form.form_status.value="update";
	}

	return true;
  }

// method to find element in array 
function grep (element){
	for (var i=0;i<this.length;i++) {
	   if(this[i]==element)	{return i;}
	   if(this.length==i)	{return -1;}
	}
}

// join grep method to Array object
Array.prototype.grep=grep;

function show_apply (id){
	where = document.forms[0].name
	form=document.getElementById(where);
        if (where == "users") {
           form.action.value="armuser";
        }
        else if (where == "st_roles" || where == "dbt_roles") {
           form.action.value="armrole";
        }
        else {
           form.action.value="arm"+where;
	}
	form.form_status.value="edit";
	form.show_apply.value=id;
	form.submit();
}

function remove (id){
        where = document.forms[0].name
        agree=window.confirm(msg(5));
        if (agree == true) {
           form=document.getElementById(where);
           form.action.value="arm"+where;
           form.form_status.value="edit";
           form.remove.value=id;
           form.submit();
        }
}

function select_columns_for_table(id){
        var table_name = document.getElementById("table_name_"+id);
        var ret_field = document.getElementById("table_columns_all"+id);
        var columns = table_columns(table_name.value);
        ret_field.value = columns;
}

function choose_descriptor (form_action, id, descriptor_id, session_id) {
        var table_name = document.getElementById("dbtpolicy_table_name_"+id);
        var aWin=window.open(form_action+"?sid="+session_id+"&action=armchoose_descriptor&descriptor_id="+descriptor_id+"&choosen_policy_id="+id+"&choosen_table_name="+table_name.value+"",
                     'popup','height=400,top=0,left=0,resizable=no,scrollbars=yes'); 
        aWin.focus();
}

function define_sql (form_action, descriptor_id, session_id) {
        var descriptor_name = document.getElementById("descriptor_name_"+descriptor_id);
        var aWin=window.open(form_action+"?sid="+session_id+"&action=armdescriptors_define_sql&descriptor_id="+descriptor_id+"&descriptor_name="+descriptor_name.value+"",
                     'popup','height=500,top=0,left=0,resizable=no,scrollbars=yes'); 
        aWin.focus();
}

function go_next_arm( where, form ){

	var error=0;

	if (form == undefined) {
	   form = document.forms[0];
	}

	if (where == undefined) {
	   where = form.name;
	   form.action.value="arm";
	}

	actions = new Array( "st_roles", "dbt_roles", "users", "user", "user_roles", "st_policies", "dbt_policies" );

	if (actions.grep(where)>=0) {

	switch (where) {

	case "users":
	        form.form_status.value='list'
		form.action.value="armusers";
	break;
	case "st_roles":
		form.form_status.value='list';
		form.action.value="armst_roles";
	 break;
	case "dbt_roles":
		form.form_status.value='list';
		form.action.value="armdbt_roles";
	 break;
	case "user":
		form.form_status.value='edit';
		form.action.value="armuser";
	 break;
	case "user_roles":
		form.form_status.value='edit';
		form.action.value="armuser_roles";
	 break;
	case "st_policies":
		form.form_status.value='edit';
		form.action.value="armst_policies";
	 break;
	case "dbt_policies":
		form.form_status.value='edit';
		form.action.value="armdbt_policies";
	 break;
	default:
	  	form.action.value="arm" + where;
	 }
	}

        if (error==0) {
	   if (form.onsubmit()) {
	      form.submit();

	   }
	   else{
	      form.form_status.value="edit";
	      form.submit();
	   }
	}
}

function check_password(my_form) {

        if (my_form == undefined) {
           my_form = document.forms[0];
        }
	var agree;
	if (my_form.ar_users__pass1.value == my_form.ar_users__pass2.value){
	   agree = check_status(my_form);
	} 
	else {
	   agree = false;
	   my_form.ar_users__pass1.value ="";
           my_form.ar_users__pass2.value ="";
	   window.alert(msg(4));  
	}
	return agree;
}

function check_role_name(my_form) {

        if (my_form == undefined){
           my_form = document.forms[0];
        }
	var agree;
	if (my_form.ar_roles__role_name.value != 0 ){
	   agree = check_status();
	} 
	else {
	   agree = false;
	   my_form.ar_roles__role_name.value ="new role name";
	   window.alert(msg(6));  
	}
	return agree;
}


function get_subroles(){

       var subroleslist = document.getElementById("ar_role__role_subset");
       var i;
       var error=false;

       if (subroleslist.options.selectedIndex < 0 && error == false) {
	  if (subroleslist.multiple) {
	     error=true;
	     for (i=0; i<subroleslist.length; i++) {
	        if (subroleslist.options[i].value != ""){
		   subroleslist.options[i].selected=true;
		   error=false;
		}
	     }
          }
          else {
             error=true;
	     if (subroleslist.length>0) {
	        if (subroleslist.options[0].value != "") {
	           subroleslist.options[0].selected=true;
		   error=false;
		}
	     }
	  }
       }

       return error;
}

function get_user_roles(){

var stroles  = document.getElementById("ar_role__st_roles");
var dbtroles = document.getElementById("ar_role__dbt_roles");
var i;
var error=false;

       if(stroles.options.selectedIndex < 0 && error == false){
		if(stroles.multiple){
			error=true;
			for (i=0; i<stroles.length; i++){
				if(stroles.options[i].value != ""){
					stroles.options[i].selected=true;
					error=false;
				}
			}
		}
		else{
			error=true;
			if(stroles.length>0){
				if(stroles.options[0].value != ""){
					stroles.options[0].selected=true;
					error=false;
				}
			}
		}
	}

	if(dbtroles.options.selectedIndex < 0 && error == false){
		if(dbtroles.multiple){
			error=true;
			for (i=0; i<dbtroles.length; i++){
				if(dbtroles.options[i].value != ""){
					dbtroles.options[i].selected=true;
					error=false;
				}
			}
		}
		else{
			error=true;
			if(dbtroles.length>0){
				if(dbtroles.options[0].value != ""){
					dbtroles.options[0].selected=true;
					error=false;
				}
			}
		}
	}

return error;
}

var checkflag = "false";
function check_role_policies(field) {
  if (checkflag == "false") {
    for (i = 0; i < field.length; i++) {
      field[i].checked = true;
    }
    checkflag = "true";
    return "Uncheck All"; 
  }
  else {
    for (i = 0; i < field.length; i++) {
      field[i].checked = false; 
    }
    checkflag = "false";
    return "Check All"; 
  }
}

function addRow_stpolicy() {
  var tbody = document.getElementById("policy_tab").getElementsByTagName("tbody")[0];
  var select_type = document.getElementById("policy_tab").getElementsByTagName("select")[0];
  var row = document.createElement("tr");
  var cell1 = document.createElement("td");
  var cell2 = document.createElement("td");
  var cell3 = document.createElement("td");
  var cell4 = document.createElement("td");
  var cell5 = document.createElement("td");
  var inp1 =  document.createElement("input");
  var inp3 =  document.createElement("input");
  var a1 =  document.createElement("a");
  var select1 =document.createElement("select");

  row.setAttribute("class","loop_row")
  
  inp1.setAttribute("size","40");
  inp1.name = "stpolicy_name_new";
  cell1.appendChild(inp1);

  select1.name="action_type_new";
  var soption = document.createElement("option");
  soption.value = "";
  soption.innerHTML = "";
  select1.appendChild(soption);
  for (i=0; i<select_type.length; i++) {
    var soptions = document.createElement("option");
    soptions.value = select_type.options[i].value;
    soptions.innerHTML = select_type.options[i].value;
    select1.appendChild(soptions);
  }
  cell2.appendChild(select1);

  inp3.setAttribute("size","60");
  inp3.name = "stpolicy_descr_new";
  cell3.appendChild(inp3);

  a1.href = "javascript:show_apply('new')";
  a1.innerHTML = "Add";
  cell4.appendChild(a1);

  row.appendChild(cell1);
  row.appendChild(cell2);
  row.appendChild(cell3);
  row.appendChild(cell4);
  row.appendChild(cell5);
  tbody.appendChild(row);
} 

function addRow_dbtpolicy() {
  var tbody = document.getElementById("policy_tab").getElementsByTagName("tbody")[0];
  var select_type = document.getElementById("policy_tab").getElementsByTagName("select")[0];
  var form_action = "ApiisWeb.cgi";
  var session = document.getElementById("sid");
  var row = document.createElement("tr");
  var cell1 = document.createElement("td");
  var cell2 = document.createElement("td");
  var cell3 = document.createElement("td");
  var cell4 = document.createElement("td");
  var cell5 = document.createElement("td");
  var cell6 = document.createElement("td");
  var cell7 = document.createElement("td");
  var cell8 = document.createElement("td");
  var inp1 =  document.createElement("input");
  var inp2 =  document.createElement("input");
  var inp3 =  document.createElement("input");
  var inp4 =  document.createElement("input");
  var inp5 =  document.createElement("input");
  var inp6 =  document.createElement("input");
  var inp7 =  document.createElement("input");
  var a1 =  document.createElement("a");
  var a2 =  document.createElement("a");
  var a3 =  document.createElement("a");
  var select1 =document.createElement("select");

  row.setAttribute("class","loop_row")

  select1.name="dbtpolicy_action_new";
  var soption = document.createElement("option");
  soption.value = "";
  soption.innerHTML = "";
  select1.appendChild(soption);
  for (i=0; i<select_type.length; i++) {
    var soptions = document.createElement("option");
    soptions.value = select_type.options[i].value;
    soptions.innerHTML = select_type.options[i].value;
    select1.appendChild(soptions);
  }
  cell1.appendChild(select1);  

  inp2.setAttribute("size","20");
  inp2.name = "dbtpolicy_table_name_new";
  inp2.id = "dbtpolicy_table_name_new";
  cell2.appendChild(inp2);

  inp3.setAttribute("size","50");
  inp3.name = "dbtpolicy_table_columns_new";
  cell3.appendChild(inp3);

  inp4.setAttribute("size","30");
  inp4.name = "dbtpolicy_descriptor_name_new";
  cell4.appendChild(inp4);

  inp5.setAttribute("size","30");
  inp5.name = "dbtpolicy_descriptor_value_new";
  cell5.appendChild(inp5);

  a1.href = "#bottom";
  a1.innerHTML = "Table";
  a1.setAttribute("onclick","var aWin=window.open('"+form_action+"?sid="+session.value+"&action=armchoose_table&table_id=new&choosen_policy_id=new','popup','height=400,top=0,left=0,resizable=no,scrollbars=yes'); aWin.focus();");
  cell6.appendChild(a1);
  
  inp6.name  = "table_id_new";
  inp6.value = "";
  inp6.type  = "hidden";
  cell6.appendChild(inp6);

  a2.href = "#bottom";
  a2.innerHTML = "Descriptor";
  a2.setAttribute("onclick","choose_descriptor('"+form_action+"','new','new','"+session.value+"');");
  cell7.appendChild(a2);

  inp7.name  = "descriptor_id_new";
  inp7.value = "";
  inp7.type  = "hidden";
  cell7.appendChild(inp7);

  a3.href = "javascript:show_apply('new')";
  a3.innerHTML = "Add";
  cell8.appendChild(a3);

  row.appendChild(cell1);
  row.appendChild(cell2);
  row.appendChild(cell3);
  row.appendChild(cell4);
  row.appendChild(cell5);
  row.appendChild(cell6);
  row.appendChild(cell7);
  row.appendChild(cell8);
  tbody.appendChild(row);
} 

function addRow_table() {
  var tbody = document.getElementById("policy_tab").getElementsByTagName("tbody")[0];
  var select_type = document.getElementById("policy_tab").getElementsByTagName("select")[0];
  var row = document.createElement("tr");
  var cell1 = document.createElement("td");
  var cell2 = document.createElement("td");
  var cell3 = document.createElement("td");
  var cell4 = document.createElement("td");
  var cell5 = document.createElement("td");
  var cell6 = document.createElement("td");
  var cell7 = document.createElement("td");
  var inp2 =  document.createElement("input");
  var inp3 =  document.createElement("input");
  var inp4 =  document.createElement("input");
  var a1 =  document.createElement("a");
  var select1 =document.createElement("select");
  var a0 =document.createElement("a");

  row.setAttribute("class","loop_row")

  select1.name="table_name_new";
  select1.id="table_name_new";
  var soption = document.createElement("option");
  soption.value = "";
  soption.innerHTML = "";
  select1.appendChild(soption);
  for (i=0; i<select_type.length; i++) {
    var soptions = document.createElement("option");
    soptions.value = select_type.options[i].value;
    soptions.innerHTML = select_type.options[i].value;
    select1.appendChild(soptions);
  }
  cell1.appendChild(select1);

  a0.href = "javascript:select_columns_for_table('new')";
  a0.innerHTML = "*";

  cell2.appendChild(a0);

  inp2.setAttribute("size","50");
  inp2.name = "table_columns_allnew";
  inp2.id = "table_columns_allnew";
  cell3.appendChild(inp2);

  inp3.setAttribute("size","50");
  inp3.name = "table_columns_new";
  cell4.appendChild(inp3);
  
  inp4.setAttribute("size","30");
  inp4.name = "table_desc_new";
  cell5.appendChild(inp4);

  a1.href = "javascript:show_apply('new')";
  a1.innerHTML = "Add";
  cell6.appendChild(a1);

  row.appendChild(cell1);
  row.appendChild(cell2);
  row.appendChild(cell3);
  row.appendChild(cell4);
  row.appendChild(cell5);
  row.appendChild(cell6);
  row.appendChild(cell7);
  tbody.appendChild(row);
} 

function addRow_descriptor() {
  var tbody = document.getElementById("policy_tab").getElementsByTagName("tbody")[0];
  var select_type = document.getElementById("policy_tab").getElementsByTagName("select")[0];
  var sid = document.getElementById("sid").value;
  var row = document.createElement("tr");
  var cell1 = document.createElement("td");
  var cell2 = document.createElement("td");
  var cell3 = document.createElement("td");
  var cell4 = document.createElement("td");
  var cell5 = document.createElement("td");
  var inp2 =  document.createElement("textarea");
  var inp3 =  document.createElement("textarea");
  var inp4 =  document.createElement("input");
  var a1 =  document.createElement("a");
  var a2 =  document.createElement("a");
  var select1 =document.createElement("select");

  row.setAttribute("class","loop_row")

  select1.name="descriptor_name_new";
  select1.id="descriptor_name_new";
  var soption = document.createElement("option");
  soption.value = "";
  soption.innerHTML = "";
  select1.appendChild(soption);
  for (i=0; i<select_type.length; i++) {
    var soptions = document.createElement("option");
    soptions.value = select_type.options[i].value;
    soptions.innerHTML = select_type.options[i].value;
    select1.appendChild(soptions);
  }
  cell1.appendChild(select1);

  inp2.setAttribute("cols","70");
  inp2.setAttribute("rows","1");
  inp2.name = "descriptor_value_new";
  cell2.appendChild(inp2);

  inp3.setAttribute("cols","35");
  inp3.setAttribute("rows","1");
  inp3.name = "descriptor_desc_new";
  cell3.appendChild(inp3);
  
  a1.href = "javascript:show_apply('new')";
  a1.innerHTML = "Add";
  cell4.appendChild(a1);
  
  a2.href = "javascript:define_sql('ApiisWeb.cgi','new','"+sid+"')";
  a2.innerHTML = "SQL";
  cell5.appendChild(a2);

  row.appendChild(cell1);
  row.appendChild(cell2);
  row.appendChild(cell3);
  row.appendChild(cell4);
  row.appendChild(cell5);
  tbody.appendChild(row);
} 


function execute_sql() {

  var sql = document.getElementById("sql").value;
  var sid = document.getElementById("sid").value;
  var form_action = document.getElementById("action").value;

  var url = "ApiisWeb.cgi?sid="+sid+"&action=ajax"+form_action+"&sql=";

  http.open("GET", url + escape(sql), true);

  http.onreadystatechange = handleHttpResponse;

  http.send(null);

}

function handleHttpResponse() {

  if (http.readyState == 4) {
    if (http.status == 200) {
       results = http.responseText;
       document.getElementById('sql_result').value = results;
    } 
    else {
       alert('There was a problem with the request.');
    }
  }
  else {
    document.getElementById('sql_result').value = "Please wait, processing ...";
  }

}


function getHTTPObject() { 
  var xmlhttp; 

  /*@cc_on 

  @if (@_jscript_version >= 5) 

     try { 

       xmlhttp = new ActiveXObject("Msxml2.XMLHTTP"); 

     } 

     catch (e) { 

       try { 

         xmlhttp = new ActiveXObject("Microsoft.XMLHTTP"); 

       } 

       catch (E) { 

         xmlhttp = false; 

       } 

     } 
  
  @else 

     xmlhttp = false; 

  @end @*/  
  
  if (!xmlhttp && typeof XMLHttpRequest != 'undefined') { 

    try { 

      xmlhttp = new XMLHttpRequest(); 

    } 

    catch (e) { 

      xmlhttp = false; 

    } 

  } 

  return xmlhttp; 
} 

var http = getHTTPObject(); // We create the HTTP Object 





/*
Author:
Marek Imialek marek at tzv dot fal dot de
*/
