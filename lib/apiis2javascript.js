// Defitionen
// apiis-Notation:JavaScript-Notation
css={"BackGround":"backgroundColor",
     "Top"            :"top",
     "Left"           :"left",
     "BackgroundColor":"backgroundColor",
     "Position"       :"position",	  	           
     "FontSize"       :"fontSize",
     "TextAlign"      :"textAlign",
     "TextTransform":"textTransform",
     "TextIndent":"textIndent",
     "LineHeight":"lineHeight",
     "Middle":"middle",
     "WordSpacing":"wordSpacing",
     "LetterSpacing":"letterSpacing",
     "TextDecoration":"textDecoration",
     "VerticalAlign":"verticalAlign",
     "FontFamily":"fontFamily",
     "FontStyle":"fontStyle",
     "FontVariant":"fontVariant",
     "FontWeight":"fontWeight",
     "Font":"font",
     "BackgroundImage":"backgroundImage",
     "BackgroundRepeat":"backgroundRepeat",
     "BackgroundAttachment":"backgroundAttachment",
     "BackgroundPosition":"backgroundPosition",
     "ForeGround":"color",

     "MarginTop":"marginTop",
     "MarginLeft":"marginLeft",
     "MarginBottom":"marginBottom",
     "MarginRight":"marginRight",
     "Margin":"margin",
     "PaddingTop":"paddingTop",
     "PaddingRight":"paddingRight",
     "PaddingBottom":"paddingBottom",
     "PaddingLeft":"paddingLeft",
     "Padding":"padding",

     "BorderTopWidth":"borderTopWidth",
     "BorderRightWidth":"borderRigthWidth",
     "BorderBottomWidth":"borderBottomWidth",
     "BorderLeftWidth":"borderLeftWidth",
     "BorderWidth":"borderWidth",
     "BorderColor":"borderColor",

     "BorderStyle":"borderStyle",
     "BlockWidth":"width",
     "":"",
};

tags={
     "Block"         :"div",
     "Name"          :"id",
     "Size"          :"size",
     "MaxLength"     :"maxlength",
     "Columns"       :"cols",
     "Image"         :"img",
     "ButtonLabel"   :"value",
     "ButtonImage"   :"src",
     "Form"          :"form",
}

apiisfields={
     "Link"          :"a",
     "Label"         :"div",
     "Form"          :"form",
     "Block"         :"div",
     "Image"         :"img",
     "ScrollingList" :"select",
     "BrowseEntry"   :"select",
     "PopupMenue"    :"select",
     "TextBlock"     :"textarea",
     "Calendar"      :"calendar",
     "Message"       :"textarea",
}

field={
     "TextField"     :"text",
     "Button"        :"button",
     "FileField"     :"file",
     "RadioGroup"    :"radio",
     "CheckBox"      :"checkbox",
     "CheckBoxGroup" :"check",
     "ScrollingList" :"select",
     "BrowseEntry"   :"select",
     "PopupMenue"    :"select",
     "TextBlock"     :"textarea",
     "Calendar"      :"calendar",
     "Message"       :"textarea",
}

input={
     "TextField"     :"text",
     "Button"        :"button",
     "FileField"     :"file",
     "RadioGroup"    :"radio",
     "CheckBox"      :"checkbox",
     "CheckBoxGroup" :"check",
};

img={
     "ButtonImage"   :"a",
};

function SetImage(vid,vimage) {
    document.getElementById(vid).setAttribute("src",vimage);
}

// richtigen Inputtype zurückgeben
function CheckInputType(apiiselement) {
    
    // gibt es einen direkten taag
    if (apiisfields[ apiiselement.nodeName ]) {
        return apiisfields[ apiiselement.nodeName ];
    }

    //schleife über alle Tags
    for (var tag in apiiselement.childNodes) {

        // wenn tag in apiisfields ist, Wert sichern 
        if ( field[ apiiselement.childNodes[tag].nodeName ] ) {

            // wenn inputfield return input
            if (input[apiiselement.childNodes[tag].nodeName] ) {
         
                // wenn ButtonImage vorkommt, dann ist Button ein a-Anker 
                if ((apiiselement.childNodes[tag].nodeName.toLowerCase() == "button" ) &&
                    (apiiselement.childNodes[tag].hasAttribute("ButtonImage") )) { 
                    return "button";
                }
                else {
                    return "input";
                }
            }
            else {
                return field[ apiiselement.childNodes[tag].nodeName ];
            }
        }
    }
}

function CreateJSElement(apiiselement) {         

    //APIIS-Element zu HTML-Tag ermitteln
    var vtag=CheckInputType(apiiselement);

    // wenn nicht gefunden (undef), dannbeinhaltet APIIS-Element ein Attribute
    if (!vtag) {
        return;
    }
 
    // neues JS-Element erzeugen
    return document.createElement( vtag );
}



function SetElementAttributs(currentelement, apiiselement) {

    //XML-Kommentare (type=8) überspringen
    if (apiiselement.nodeType == 8 ) {
        return;
    }
 
    var currentelement;

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
            vattribute=document.createAttribute( tags[vname]);
        }

        // wenn es in ID-Tag ist, dann mit FORM-ID ergänzen, damit es im DOM eindeutig ist
        if (( vattribute.nodeName == "id") && ( document.apiis.currentformid )) {
            vattribute.nodeValue=document.apiis.currentformid + '_' + apiiselement.getAttribute( vname );
        }
        else {
            vattribute.nodeValue=apiiselement.getAttribute( vname );
        }

        // Attribute dem Element zuordnen, außer ID-Tag
        if ( (vattribute.nodeName == "id" ) && (currentelement.hasAttribute("id")) ) {
            continue;
        }
        else {
            currentelement.setAttributeNode(vattribute);
        }
    }

    //Scheife über apiis-Elemente, und JS-Attribute herauspicken
    for (var i=0; i < apiiselement.childNodes.length; i++) {

         //XML-Kommentare (type=8) überspringen
         if (apiiselement.childNodes[i].nodeType == 8 ) {
             continue;
         }
 
         // Schreibweise über alias vereinfachen
         var telement=apiiselement.childNodes[i];
 
         // alle Elemente,die abgefragt werden müssen
         var ar_elemente=['Position','Color','TextField','Text','Format','Button'];

         // Schleife über alle Attribut-Elemente
         for (var k=0; k < ar_elemente.length; k++) {

             //Variablen zurücksetzen 
             var vpos=['null'];
             var vcsspos=['null'];

             // wenn es Tag TextField im  Element gibt
             if ((telement.nodeName.toLowerCase() == 'text') && ( ar_elemente[k] == telement.nodeName )) {
                 // andere Attribute
                 vcsspos=['FontSize','TextAlign','FontFamily','FontSize','FontStyle','FontWeight',
                          'FontStretch'];    
             }

             // wenn es Tag Format im  Element gibt
             if ((telement.nodeName.toLowerCase() == 'format') && ( ar_elemente[k] == telement.nodeName )) {
                 // andere Attribute
                 vcsspos=['MarginTop','MarginRight','MarginBottom','MarginLeft','Margin',
                          'PaddingTop','PaddingRight','PaddingBottom','PaddingLeft','Padding',
                          'BorderTopWidth','BorderRightWidth','BorderLeftWidth','BorderBottomWidth',
                          'BorderWidth','BorderColor','BorderStyle', 'BlockWidth',
                          ];    
             }

             // wenn es Tag TextField im  Element gibt
             if ((telement.nodeName.toLowerCase() == 'textfield') && ( ar_elemente[k] == telement.nodeName )) {
                 // andere Attribute
                 vpos=['Size','MaxLength','Override','Password','Default','InputType'];    
             }

             // wenn es Tag Button im  Element gibt
             if ((telement.nodeName.toLowerCase() == 'button') && ( ar_elemente[k] == telement.nodeName )) {
                 // andere Attribute
                 vpos=['Command','URL','Src','ButtonImage','ButtonImageOver','ButtonImageActive',
                       'ButtonLabel','Navigationbar'];    
             }

             // wenn es Tag Position im  Element gibt
             if ((telement.nodeName.toLowerCase() == 'position') && ( ar_elemente[k] == telement.nodeName )) {
                 // css-style attribute
                 vcsspos=['Top','Left','Position' ];    
                 // andere Attribute
                 vpos=['Column','Row','Width','Height','Columnspan','Rowspan','Anchor','Sticky','Clip','Repeat'];    
             }

             // wenn es Tag Position im apiis-Element gibt
             if ((telement.nodeName.toLowerCase() == 'color') && ( ar_elemente[k] == telement.nodeName )) {
                 // css-style attribute
                 vcsspos=['BackGround','ForeGround','BackgroundImage','BackgroundRepeat',
                          'BackgroundAttachment','BackgroundPosition' ];    
             }

             // style-Attribute aus apiis-tag in js-tag übernehmen
             for (j in vcsspos) {
                 if (telement.getAttribute( vcsspos[j] )) {
                    currentelement.style[ css[ vcsspos[j] ] ]=telement.getAttribute( vcsspos[j] );
                 }
             }
  
             // alle anderen Attribute übernehmen
             for (j in vpos) {
                 if (telement.getAttribute( vpos[j] )) {
                     if (!tags[ vpos[j] ]) {
                         currentelement.setAttribute(vpos[j], telement.getAttribute( vpos[j]) );
                     }
                     else {
                         currentelement.setAttribute(tags[ vpos[j] ], telement.getAttribute( vpos[j]) );
                     }

                 }
             }
         }
    }

    // Jedes Element bekommt die Attribute  datasetcol, datasetrow und blockid
    currentelement.setAttribute("datasetrow",0);
    currentelement.setAttribute("datasetcol",0);

    currentelement.setAttribute("viewrow",0);
    currentelement.setAttribute("viewcol",0);

    currentelement.setAttribute("formid", document.apiis.currentformid);
    currentelement.setAttribute("blockid",document.apiis.currentblockid);
    currentelement.setAttribute("formindex",document.apiis.currentformcount);
    currentelement.setAttribute("idxml",currentelement.getAttribute("id"));
}


function SetMaxRows() {
   max_data_rows=form.datasource.data.length-1;
}
function SetMaxCols() {
   max_data_columns=form.datasource.data[0].length-1;
}
 
// an den Record eine neue Zeile anfügen
function InsertNewRecordset(recordset) {
    var row=new Array();
    for (var column=0; column<recordset.length;column++) {
        row.push('');
    } 
    recordset.push(row);
    SetMaxRows();
} 




// Erstellt ein Formular
function CreateForm( formelements, parenttag ) {

    //Neues javascript-Element erzeugen
    var newtag=CreateJSElement( formelements );

    // leeres Element
    if (formelements.nodeName=="none") {
        return;
    }

    //wenn velement undef ist, dann Attribute dem Elternelement zuordnen
    if (!newtag) {
        SetElementAttributs(parenttag,formelements);

        //einige Elemente in apiis sind attribute in html, umsetzung über input[]
        if (input[ formelements.nodeName]) {
            parenttag.setAttribute("type",input[formelements.nodeName] );
        }

        // wenn Tabular, dann Flag in Block (div) setzen 
        if (formelements.nodeName.toLowerCase() == "tabular" ) {
            parenttag.setAttribute("viewtype","spreatsheet");
        }

        // Rücksprung, wenn datasource
        if (formelements.nodeName.toLowerCase() != "tabular") {
            return newtag;
        }
    }
    else {
      SetElementAttributs(newtag,formelements);
 
     // form-ID sichern
     if (formelements.nodeName.toLowerCase() == "form") {
         document.apiis.currentformcount++;
         document.apiis.currentformid=newtag.getAttribute("id");
         document.apiis.currentform=formelements;
     }

     // block-ID sichern
     if (formelements.nodeName.toLowerCase() == "block") {
         document.apiis.currentblockid=newtag.getAttribute("id");
         document.apiis.currentblock=formelements;
        
         // Anzahl der anzuzeigenden Zeilen im From
         if (!newtag.hasAttribute("viewstep")) {
             newtag.setAttribute("viewstep",1);
         }
         newtag.setAttribute("isblock",true);

         // flag zurücksetzen 
         document.apiis.printtable=null;
         
         newtag.elements=new Array();


         // zusätzliche Steuerattribute für den View des Blocks
         newtag.setAttribute("viewstart",0);
         newtag.setAttribute("viewmaxcol",0);
         newtag.setAttribute("viewmaxrow",newtag.getAttribute("viewstep") );

         //zusätzliche Steuerattribute für den Datensatz des Block
         newtag.setAttribute("datasetmaxrow",0);
         newtag.setAttribute("datasetmaxcol",0);
     }

     if ( newtag.nodeName.toLowerCase() == "button") {
         var v=document.createElement("img");
         v.setAttribute("id","img_"+newtag.getAttribute("id") );
         v.setAttribute("src",newtag.getAttribute("src"));

         if (newtag.hasAttribute("buttonimageover") ) {
             newtag.setAttribute("onMouseOver",'SetImage("' + v.id+ '","' + newtag.getAttribute("buttonimageover") + '")' );
             newtag.setAttribute("onMouseOut" ,'SetImage("' + v.id+ '","' + newtag.getAttribute("src") + '")' );
         }
         newtag.appendChild(v); 
         newtag.setAttribute("onClick",'SetElement("' + newtag.getAttribute("id") +'")');
     }

     // Labels=text wird anders behandelt als Elemente
     if ( formelements.nodeName.toLowerCase() == "label" ) {

         // neues Text-Element erzeugen + Text
         var v=document.createTextNode( formelements.getAttribute("Content") );

         // Textknoten in Div einfügen 
         newtag.appendChild( v );
     }
    }

    // Positionsarray initialisieren, wird später eine Tabelle
    var ar_position=new Array();
    var velement;
    var vmatrix;

    // Schleife über alle Elemente des Form-Tags
    for (var i=0; i < formelements.childNodes.length; i++) {

        var velement;     

        if (newtag) {
          //Neues javascript-Element erzeugen
          velement=CreateForm(formelements.childNodes[i], newtag);
        }
        else {
          //Neues javascript-Element erzeugen
          velement=CreateForm(formelements.childNodes[i], parenttag);
        }

        // Schleifenabbruch, wenn undef, da kein Tag zum einfügen
        if (!velement) {
            continue;
        }          
     
        // mit erstem Element viewtype setzen für Block-Elemente
        // Blockelemente sollen in eine Tabelle, Blockelemente sammeln
        if ( parenttag && ( parenttag.hasAttribute("isblock")) ) { 

            if ((! parenttag.hasAttribute("viewtype")) && 
                ( velement.hasAttribute( "Column" ) || velement.hasAttribute( "Row" ) )) {
                parenttag.setAttribute("viewtype","table");
            }

            // Blockelemente sollen per css gesetzt werden
            if ((! parenttag.hasAttribute("viewtype")) && 
                velement.hasAttribute( "Position" ) ) {
                parenttag.setAttribute("viewtype","css");
            }

            if ( parenttag.getAttribute("viewtype") == "css" ) {
                newtag.appendChild(velement);
            } 
            else {
                // Variablen instantiieren
                var vx;
                var vy;

                // Spaltenwert initialisieren, falls attribute column nicht exisitert
                if (!velement.hasAttribute( "Column" ))  {
                     vx=0;
                } 
                else {
                     vx=velement.getAttribute( "Column" );
                }

                // zeilenwert initialisieren, falls attribute row nicht exisitert
                if (!velement.hasAttribute( "Row" ) || ( parenttag.getAttribute("viewtype") == "spreatsheet") )  {
                     vy=0;
                } 
                else {
                     vy=velement.getAttribute( "Row" );
                }
                  
                // Zeile initialisieren
                if (!parenttag.elements[vy]) {
                    parenttag.elements[vy]=new Array();
                }

                // Element in Matrix schreiben
                parenttag.elements[vy][vx]=velement;
                var k=0;
            }
        }
        else {
            // 
            newtag.appendChild(velement);
        }
    }
 
    // Leerzeilen beseitigen
    if (( formelements.nodeName == 'Tabular') || 
        ((formelements.nodeName == 'Block')  && (!document.apiis.printtable) ) ) {
        ar_position=parenttag.elements;
   
        var tarray=new Array();
        for (var i=0; i < ar_position.length; i++) {
            if (ar_position[i]) {
                tarray.push(ar_position[i]);
            }	  
        }
        ar_position=tarray;

        // Tabelle erzeugen
        var table=document.createElement("table");
        table.setAttribute("cellSpacing","0px");
        table.setAttribute("cellPadding","0px");
        table.setAttribute("class","table");
        table.onmouseout=function() {ChangeViewStyle( null ,'onmouseout')};
        var start=0;

        //bei Spreatsheet kommt noch eine InfoSpalte vor die Zeile
        if ( parenttag.getAttribute("viewtype") == "spreatsheet") {
            start=-1
            
            var tarray=new Array();
            for (var j=0; j < ar_position[0].length; j++) {
                if (ar_position[0][j]) {
                    tarray.push(ar_position[0][j]);
                }	  
            }
            ar_position[0]=tarray;

            // Felder in den Block sichern
            document.apiis.currentblock.fields=new Array();
            for (var i=0;i<ar_position[0].length;i++) {
                document.apiis.currentblock.fields.push(ar_position[0][i]);
            }

            var row=table.insertRow(0);

            // Tabellenkopf initialisiern
            var ende=ar_position[0].length;
            for (var spalte=start;spalte<ende;spalte++) {

                var td=document.createElement("td");
                var a=document.createElement('img'); 
                a.setAttribute("src",'/home/b08mueul/apiis/lib/images/blank25s.gif');
 
                if ((spalte == start )) { td.setAttribute("class","tdaa");};
                if ((spalte >  start )) { td.setAttribute("class","tdab");};

                td.appendChild(a);
                row.appendChild(td);
            } 
        }


        // Erzeuge so viel Zeilen, wie im Datensatz stehen
        // maximal aber nur soviel, wie im Fenster angezeigt
        // werden sollen
        var nview=form.datasource.data.length;
        var nwin=0;
        if ( nwin > 0 ) {
            nview=nwin ;
        }
 
        // Schleife über alle Datensätze des Fensters
        for (var i=0; i < nview; i++) {
 
            // neue Zeile in Tabelle einfügen
            row=table.insertRow(i+1);
            
            // Spreatsheet und tabelle werden unterschiedlich behandelt
            vrow=i;
            if ( parenttag.getAttribute("viewtype") == "spreatsheet") {
               vrow=0;
            }   
            
            
            // Schleife über alle Spalten
            for (var j=start; j < ar_position[vrow].length; j++) {

                // neues Zelle erstellen
                var td=document.createElement("td"); 
                var vpointer;

                if (j > -1) {

                    td.setAttribute("class","blank");

                    // 
                    vpointer=ar_position[vrow][j].cloneNode(true);
                    vpointer.setAttribute("value",form.datasource.data[i][j]);
                    vpointer.setAttribute("id",vpointer.getAttribute("id") + '_' + i + '_' + j);
                    vpointer.setAttribute("datasetrow",i);
                    vpointer.setAttribute("datasetcol",j);
                    vpointer.setAttribute("viewrow",i);
                    vpointer.setAttribute("viewcol",j);

                    vpointer.onclick    =function() {SetElement(this.id)};
                    vpointer.onkeyup    = KeyPress;
                    
                    if ( parenttag.getAttribute("viewtype") == "spreatsheet") {
                        if ((i == 0) && (j == 0)) { vclass="aa" };
                        if ((i == 0) && (j >  0)) { vclass="ab" };
                    
                        if ((i > 0 ) && (j == 0 )) { vclass="ba" };
                        if ((i > 0 ) && (j >  0 )) { vclass="bb" };
                        
                        vpointer.setAttribute("class",vclass);
                        vpointer.onfocus    =function() {ChangeViewStyle(this.id,'activ', vclass)};
                        vpointer.onmouseover=function() {ChangeViewStyle(this.id,'over',  vclass)};
       
                    }
                    
                    // erstes Element auf aktiv setzen
                    if ( (i==0) && ( j==0) )  {
                        document.apiis.currentfield=vpointer;
                        document.apiis.currentactivfield=vpointer;
                        document.apiis.currentactivfield.style.backgroundColor="lightgreen";
                    }
                }
                else {
                    vpointer=document.createElement('img'); 
                    vpointer.setAttribute("id","i0");
                    vpointer.setAttribute("src",'/home/b08mueul/apiis/lib/images/blank30.gif');
                    if (i == 0 ) { td.setAttribute("class","tdba") };
                    if (i > 0  ) { td.setAttribute("class","tdbb") };
                }

                // Element in Tabelle einhängen
                td.appendChild(vpointer);

                // Zellenattribute setzen 
                if ( vpointer.hasAttribute("Columnspan" )) {
                    td.setAttribute("colspan",vpointer.getAttribute("Columnspan"));
                }
                if ( vpointer.hasAttribute("Width" )) {
                   td.setAttribute("width",vpointer.getAttribute("Width"));
                }

                // Tabellenzelle in Zeile einfügen
                row.appendChild(td);
             }
          }
          
          // Tabelle einbinden 
          parenttag.appendChild(table);
          document.apiis.printtable=1;
    } 

    return newtag;
}
