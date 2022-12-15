function SetElement ( vfield, vcommand ) {

    var velement=document.getElementById( vfield );
    var vform=document.forms[ velement.getAttribute("formindex") ];
    
    var vhidden;   

    // wenn es ein Command-Attribute gibt = button
    if ( velement.hasAttribute("command")) {
       vcommand=velement.getAttribute("command") ;
    }


    //Block für das neue, aktive Feld holen
    var vblock=document.getElementById( velement.getAttribute("datasetblockid") );
    
    // für den aktuellen Block, Zeiger auf dem View
    var current_viewcol   =velement.viewcol;
    var current_viewrow   =velement.viewrow;
    
    if (vcommand) {
       switch (vcommand) {
         case "do_open_report":
            vform.action='http://ovicap.localhost/cgi-bin/GUI';
            vform.target="_blank";
            break;
         case "do_open_form":
            vform.action='http://ovicap.localhost/cgi-bin/GUI';
            break;
         case "do_query_block":
            vform.action='http://ovicap.localhost/cgi-bin/GUI';
            break;
         case 'do_next_field':
           current_viewrow++;
           break
         case 'do_prev_field':
           current_viewrow--;
           break;
         case 'do_first_block':
           current_viewrow=0;
           break;
         case 'do_last_block':
           current_viewrow=vblock.datasetmaxrow;
           break;
         case 'do_new_block':
           // Datensatz hinzufügen
           InsertNewRecord(vblock);
           current_viewrow=vblock.datasetmaxrow;
           break;
       }
 
       if ( (vcommand == "do_open_report") || (vcommand == "do_open_form") ||
            (vcommand == "do_query_block") ) {  
           // Hidden-Elemente setzen
           var velemente=['g','user','sid','m','o'];

           // Schleife über alle hidden-Elemente
           for (var i=0; i<velemente.length;i++) { 

               //Element erzeugen
               vhidden=document.createElement("input");

               //Attribute setzen 
               vhidden.setAttribute("type","hidden");
               vhidden.setAttribute("name", velemente[ i ] );

               // Herkunft der Attribute ist unterschiedlich
   	       switch ( velemente[ i ] ) {
      	           case 'g':
                       vhidden.setAttribute("value", velement.getAttribute("url") );
                       break;
      	           case 'm':
                       vhidden.setAttribute("value", document.apiis.m);
                       break;
      	           case 'o':
                       vhidden.setAttribute("value", document.apiis.o);
                       break;

                   // aus Anmeldung
      	           case 'user':
                       vhidden.setAttribute("value", document.apiis.user);
                       break;
 
                   // aus Anmeldung
      	           case 'sid':
                      vhidden.setAttribute("value", document.apiis.sid);
                      break;
               }

               // Anfügen des Hidden-Elements in das Formelement
               vform.appendChild(vhidden);
           }

           // Formulardaten absenden
           vform.submit();
       } 
       else {

           var current_field=document.apiis.currentfieldid;

           // aktives Feld rücksetzen, Ursprungslage herstellen
           if (current_field) {      
               document.getElementById(current_field).style.backgroundColor=null; 
               document.getElementById('i'+current_row).setAttribute("src",'/home/b08mueul/apiis/lib/images/blank30.gif');
           }

           // Sichtfenster bereits am Anfang des DataSets
           if (current_viewrow < 0) {
               current_viewrow = 0;
           }
       
           // Sichtfenster am Ende des DataSets  
           else if (current_viewrow > vblock.datasetmaxrow)  {
               current_viewrow = vblock.datasetmaxrow;
           }

           // Sichtfenster muss verschoben werden
           else {
               RefreshView(vblock,current_viewrow);
           }

           // neues Feld aktivieren
           vfield=current_field.getAttribute("idxml") + current_viewrow;

           // aktuelles Feld kennzeichnen + focus  
           document.getElementById('i'+current_row).setAttribute("src",'/home/b08mueul/apiis/lib/images/erster.png');
           document.getElementById(vfield).style.backgroundColor="lightgreen";
           document.getElementById(vfield).focus();
       }
    }         
    else {
       current_row=velement.row;
       current_column=velement.column;

    }

    // aktives Feld speichern
    document.apiis.currentfieldid=vfield;
      
}
 
function KeyPress(event) {
    var key=event.which;
    var current_field=document.apiis.currentfieldid;
    
    switch (key) {
      case 8:
         SetElement(current_field, 'do_next_field');
         break;
      case 13:
         SetElement(current_field, 'do_next_field');
         break;
      case 37:
         SetElement(current_field, 'do_prev_field');
         break;
      case 38:
         SetElement(current_field, 'do_prev_block');
         break;
      case 39:
         SetElement(current_field, 'do_next_field');
         break;
      case 40:
         SetElement(current_field, 'do_next_block');
         break;
   }
}

function RefreshView () {
    //für aktuellen Block: Zeiger auf dem Dataset 
    var current_datasetcol=vblock.datasetcol;
    var current_datasetrow=vblock.datasetrow;

  alert("Refresh");
}

function InsertNewRecord(vblock) {
  alert("InsertNewRecord");
  vblock.datasetmaxrow++;
}

