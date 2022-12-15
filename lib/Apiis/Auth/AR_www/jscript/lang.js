/*
	$Id: lang.js,v 1.2 2006/08/08 14:35:15 marek Exp $


*/

function set_languages(){
	var my_lang_form = document.getElementById('set_lang');
	var my_login_form = document.getElementById('login');
	my_login_form.gui_lang.value = my_lang_form.gui_lang.value;
	if (my_login_form.selected_project.value == 0){
	  alert("Please, choose the project name");
	  return false;
	}
	else {
	  return true;
	}  
}


