// Defitionen
// apiis-Notation:JavaScript-Notation
css={"BackGround":"backgroundColor",
     "Top":"top",
     "Left":"left",
     "BackgroundColor":"backgroundColor",
     "Position":"position",	  	           
};

tags={
     "Block"         :["div"],
     "Name"          :["id"],
     "Size"          :["size"],
}

apiisfields={
     "TextField"     :["input", "text"],
     "Button"        :["input", "button"],
     "FileField"     :["input", "file"],
     "RadioGroup"    :["input", "radio"],
     "CheckBox"      :["input", "checkbox"],
     "Link"          :["a"],
     "ScrollingList" :["select"],
     "BrowseEntry"   :["select"],
     "PopupMenue"    :["select"],
     "TextBlock"     :["textarea"],
     "Calendar"      :["calendar"],
     "Message"       :["textarea"],
     "CheckBoxGroup" :["input", "check"],
}

// richtigen Inputtype zurückgeben
function CheckInputType(apiiselement) {
    
    var vtag;

    //schleife über alle Tags
    for (var tag in apiiselement.childNodes) {

        // wenn tag in apiisfields ist, Wert sichern 
        if (apiisfields[ apiiselement.childNodes[tag].nodeName ] ) {
            return apiisfields[ apiiselement.childNodes[tag].nodeName ];
        }
    }
}

function CreateJSElement(apiiselement) {         

    var velement;

    // Labels=text wird anders behandelt als Elemente
    if ( apiiselement.nodeName == "Label" ) {

        // neues Text-Element erzeugen + Text
        var v=document.createTextNode( apiiselement.getAttribute("Content") );

        // neues div-Element erzeugen
        velement=document.createElement( "div" );

        // Textknoten in Div einfügen
        velement.appendChild( v );

    }
    else { if ( apiiselement.nodeName == "Field" ) {

        //Feldtyp ermitteln
        var vtag=CheckInputType(apiiselement);

            // neues JS-Element erzeugen
            velement=document.createElement( vtag[0] );
        
            // wenn es ein input-field ist, dann muss type als attribut untersetzt werden
            if (( vtag == "input") && ( vtag[1] )) {
                velement.setAttributes("type",vtag[1]);
            }
        }
        else {
            // neues JS-Element erzeugen
            velement=document.createElement( tags[apiiselement.nodeName] );
        }
    }

    // APIIS-Elemente, die css-Attribute sind, einklinken
    SetElementAttributs(velement,apiiselement);

    return velement;
}



function SetElementAttributs(velement, apiiselement) {

    // Schleife über alle Attribute des Elements
    for (var i=0; i < apiiselement.attributes.length; i++) {

        // Schreibweise über alias vereinfachen
        var telement=apiiselement.attributes[i];

        // Attributename in Apiis    
        var vname=telement.nodeName;

        // apiis aus javascript umwidmen
        var vattribute;

        // wenn es keine Umsetzung gibt, dann original verwenden
        if (!tags[vname]) {
            vattribute=document.createAttribute( vname );
        }
        else {
            vattribute=document.createAttribute( tags[vname][0]);
        }
        vattribute.nodeValue=apiiselement.getAttribute( vname );

        // Attribute dem Element zuordnen
        velement.setAttributeNode(vattribute);
    }

    //Scheife über apiis-Elemente, und JS-Attribute herauspicken
    for (var i=0; i < apiiselement.childNodes.length; i++) {

         // Schreibweise über alias vereinfachen
         var telement=apiiselement.childNodes[i];
 
         // alle Elemente,die abgefragt werden müssen
         var ar_elemente=['Position','Color','TextField'];

         // Schleife über alle Attribut-Elemente
         for (var k=0; k < ar_elemente.length; k++) {

             //Variablen zurücksetzen 
             var vpos=['null'];
             var vcsspos=['null'];

             // wenn es Tag Position im  Element gibt
             if ((telement.nodeName == 'TextField') && ( ar_elemente[k] == telement.nodeName )) {
                 // andere Attribute
                 vpos=['Size'];    
             }

             // wenn es Tag Position im  Element gibt
             if ((telement.nodeName == 'Position') && ( ar_elemente[k] == telement.nodeName )) {
                 // css-style attribute
                 vcsspos=['Top','Left','Height','Width','Position' ];    
                 // andere Attribute
                 vpos=['Column','Row','Position','Columnspan','Rowspan','Anchor','Sticky','Clip','Repeat'];    
             }

             // wenn es Tag Position im apiis-Element gibt
             if ((telement.nodeName == 'Color') && ( ar_elemente[k] == telement.nodeName )) {
                 // css-style attribute
                 vcsspos=['BackGround' ];    
             }

             // style-Attribute aus apiis-tag in js-tag übernehmen
             for (j in vcsspos) {
                 if (telement.getAttribute( vcsspos[j] )) {
                    velement.style[ css[ vcsspos[j] ] ]=telement.getAttribute( vcsspos[j] );
                 }
             }
  
             // alle anderen Attribute übernehmen
             for (j in vpos) {
                 if (telement.getAttribute( vpos[j] )) {
                     var vattribute=document.createAttribute( vpos[j] );
                     vattribute.nodeValue=telement.getAttribute( vpos[j]) ;
                     velement.setAttributeNode(vattribute);
                 }
             }
         }
    }
}


