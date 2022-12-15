  // Navigationbar aufbauen
  navigationbuttons=['do_first', 'do_prev', 'do_next', 'do_last', 'do_new'];
  command          =['do_first_block', 'do_prev_block', 'do_next_block', 'do_last_block', 'do_new_block'];
  buttonlabel      =['First','Vorher','Next','Last','New'];
  buttonimage      =['do_first', 'do_prev', 'do_next', 'do_last', 'do_new'];
  buttonimageover  =['do_first2', 'do_prev2', 'do_next2', 'do_last2', 'do_new2'];
  buttonimageaktiv =['do_first3', 'do_prev3', 'do_next3', 'do_last3', 'do_new3'];
  navigationbar    =['yes','yes','yes','yes','yes'];
  column           =[0,1,2,3,4];
  row              =[0,0,0,0,0];
  for (var i=0; i<navigationbuttons.length; i++) {
    var img=document.createElement("img");
    img.setAttribute("name",navigationbuttons[i]);
    img.setAttribute("id",navigationbuttons[i]);
    img.setAttribute("src",vpath +navigationbuttons[i]+".png");
    img.buttonlabel=buttonlabel[i];
    img.buttonimage=buttonimage[i];
    img.buttonimageover=buttonimageover[i];
    img.buttonimageaktiv=buttonimageaktiv[i];
    img.column=column[i];
    img.row=row[i];
    img.command=command[i];
    img.onmouseover=function() { if (document.images) document.images[this.id].src = eval(this.id + "2.src");};
    img.onmouseout =function() { if (document.images) document.images[this.id].src = eval(this.id + ".src");};
    img.onclick    =function() { SetElement(this.id, this.command) };
    document.body.appendChild(img);
  }



  if (document.images) {
    var do_first = new Image();
    do_first.src = vpath + "do_first.png";
    var do_first2 = new Image();
    do_first2.src = vpath + "/do_first2.png";
    
    var do_prev = new Image();
    do_prev.src = vpath + "/do_prev.png";
    var do_prev2 = new Image();
    do_prev2.src = vpath + "/do_prev2.png";
    
    var do_next = new Image();
    do_next.src = vpath + "/do_next.png";
    var do_next2 = new Image();
    do_next2.src = vpath + "/do_next2.png";
    
    var do_last = new Image();
    do_last.src = vpath + "/do_last.png";
    var do_last2 = new Image();
    do_last2.src = vpath + "/do_last2.png";
    
    var do_new   = new Image();
    do_new.src   = vpath + "/do_new.png";
    var do_new2  = new Image();
    do_new2.src  = vpath + "/do_new2.png";
  }


