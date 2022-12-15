/*hierFrames.js (Cross-browser/Frames)
* By Peter Belesis. v1.0 980408
* Copyright (c) 2001 Peter Belesis. All Rights Reserved.
* Originally published and documented at http://www.dhtmlab.com/
* Available solely from INT Media Group. Incorporated under exclusive license.
* Contact licensing@internet.com for more information.
*/

if (NS4) parent.onload = startIt;
if (IE4) parent.document.body.onload = startIt;

if (perCentOver != null) {
	childOverlap = (perCentOver/100) * menuWidth
}
mSecsVis = secondsVisible*1000;

imgStr = "<IMG SRC=" + imgSrc + " WIDTH=" + imgSiz + " HEIGHT=" + imgSiz +" BORDER=0 VSPACE=2 ALIGN=RIGHT>"

function initVars() {

	topCount = 1;
	areCreated = false;
	isOverMenu = false;
	currentMenu = null;
	allTimer = null;

}

initVars();

function startIt() {
	
	main = parent.frames.main;
	
	if (NS4) main.onunload = initVars;
	if (IE4) main.document.body.onunload = initVars;

	if (NS4) makeClass();
	makeTop();

}

function makeClass() {
	styLayer = new Layer(400);
	styleStr = "<STYLE TYPE='text/javascript'>"
	+ "with (parent.frames.main.document.classes.items.SPAN) {"
	+ "width=\"" + menuWidth + "\";"
	+ "color=\""+ fntCol + "\";"
	+ "fontSize=\""+ fntSiz + "\";"
	+ "fontWeight=\""+ fntWgh + "\";"
	+ "fontStyle=\""+ fntSty + "\";"
	+ "fontFamily=\""+ fntFam + "\";"
	+ "borderWidth=\"" + borWid + "\";"
	+ "borderColor=\"" + borCol + "\";"
	+ "borderStyle=\"" + borSty + "\";"
	+ "lineHeight=\"" + linHgt + "\";"
	+ "}"
	+ "</STYLE>";
 
	styLayer.document.write(styleStr);
	styLayer.document.close();

}

function menuSetup(hasParent,lastItem,openCont,openItem) {

	this.menuOver = menuOver;
	this.menuOut = menuOut;

	this.onmouseover = this.menuOver;
	this.onmouseout = this.menuOut;

	this.showIt = showIt;
	this.keepInWindow = keepInWindow;

	this.hideTree = hideTree
	this.hideParents = hideParents;
	this.hideChildren = hideChildren;
	this.hideTop = hideTop;
	
	this.hasChildVisible = false;
	this.isOn = false;
	
	this.hideTimer = null;

	if (hasParent) {
		this.hasParent = true;
		this.parentMenu = openCont;
		this.parentItem = openItem;
		this.parentItem.child = this;
	}
	else {
		this.hasParent = false;
		this.hideSelf = hideSelf;
	}

	if (NS4) {
		this.fullHeight = lastItem.top + lastItem.document.height;
		this.clip.bottom = this.fullHeight;
	}
	else {
	    this.fullHeight = lastItem.style.pixelTop + lastItem.offsetHeight;
		this.showIt(false);
		this.onselectstart = cancelSelect;
		this.moveTo = moveTo;
		this.moveTo(0,0);
	}
}

function itemSetup(arrayPointer,whichArray) {
	this.itemOver = itemOver;
	this.itemOut = itemOut;
	this.onmouseover = this.itemOver;
	this.onmouseout = this.itemOut;

	this.dispText = whichArray[arrayPointer];
	this.linkText = whichArray[arrayPointer + 1];
	this.hasMore = whichArray[arrayPointer + 2];

	if (this.linkText.length > 0) {
		this.linkIt = linkIt;
		if (NS4) {
			this.onfocus = this.linkIt;
		}
		else {
			this.onclick = this.linkIt;
			this.style.cursor = "hand";
		}
	}
      
	if (this.hasMore) {
		htmStr = imgStr + this.dispText;
	}
	else {
		htmStr = this.dispText;
	}

	if (NS4) {
		layStr = "<SPAN CLASS=items>" + htmStr+ "</SPAN>";

		this.document.write(layStr);
		this.document.close();

		this.bgColor = backCol;
		this.clip.right = menuWidth;
		this.visibility = "inherit";
		this.container = this.parentLayer;

		if (arrayPointer == 0) {
			this.top = 0;
		}
		else {
			this.top = this.prevItem.top + this.prevItem.document.height - borWid;
		}
		this.left = 0;
	}
	else {
		with (this.style) {
			padding = 3;
			width = menuWidth;
			color = fntCol;
			fontSize = fntSiz
			fontWeight = fntWgh;
			fontStyle = fntSty;
			fontFamily = fntFam;
			borderWidth = borWid;
			borderColor = borCol;
			borderStyle = borSty;
			backgroundColor = backCol;
			lineHeight = linHgt;
	}

		this.innerHTML = htmStr;

		this.container = this.offsetParent;

		if (arrayPointer == 0) {
			this.style.pixelTop = 0;
		}
		else {
			this.style.pixelTop = this.prevItem.style.pixelTop + this.prevItem.offsetHeight - borWid;
		}
		this.style.pixelLeft = 0;
	}
}

function makeElement(whichEl,whichContainer) {
	if (arguments.length==1)
		whichContainer = (NS4) ? main : main.document.body;

	if (NS4) {
		eval(whichEl + "= new Layer(menuWidth,whichContainer)");
	}
	else {
		elStr = "<DIV ID=" + whichEl + " STYLE='position:absolute'></DIV>";
		whichContainer.insertAdjacentHTML("BeforeEnd",elStr);
		eval(whichEl + "= main." + whichEl);
	}
	
	return eval(whichEl);
}

function makeTop() {

	while(eval("window.arMenu" + topCount)) {
		topArray = eval("arMenu" + topCount);

		topName = "elMenu" + topCount;

		topMenu = makeElement(topName);
    	topMenu.setup = menuSetup;

		topItemCount = 0;
		for (i=0; i<topArray.length; i+=3) {
			topItemCount++;
			status = "Creating Hierarchical Menus: " + topCount + " / " + topItemCount;
			topItemName = "item" + topCount + "_" + topItemCount;
			topItem = makeElement(topItemName,topMenu);

			if (topItemCount >1)
				topItem.prevItem = eval("item" + topCount + "_" + (topItemCount-1));

			topItem.setup = itemSetup;
			topItem.setup(i,topArray);

			if (topItem.hasMore) makeSecond();
		}
		
		topMenu.setup(false,topItem);
		topCount++
	}

	status = (topCount-1) + " Heirarchical Menu Trees Created"
	areCreated = true;
}

function makeSecond() {

	secondCount = topCount + "_" + topItemCount;
	
	secondArray = eval("arMenu" + secondCount);
	secondName = "elChild" + secondCount;
	
	secondMenu = makeElement(secondName);
	secondMenu.setup = menuSetup;

	secondItemCount=0;
	for (j=0; j<secondArray.length; j+=3) {
		secondItemCount++;
		secondItemName = "item" + secondCount +"_" + secondItemCount;

		secondItem = makeElement(secondItemName,secondMenu)		
		
		if (secondItemCount >1)
			secondItem.prevItem = eval("item" + secondCount  + "_" + (secondItemCount-1));

		secondItem.setup = itemSetup;
		secondItem.setup(j,secondArray);

		if (secondItem.hasMore) makeThird();
	}

	secondMenu.setup(true,secondItem,topMenu,topItem);
}

function makeThird() {
	thirdCounter = secondCount + "_" + secondItemCount 
	
	thirdArray = eval("arMenu" + thirdCounter);
	thirdName = "elGrandChild" + thirdCounter;
	thirdMenu = makeElement(thirdName)
	
	thirdMenu.setup = menuSetup;

	thirdItemCount=0;
	for (k=0; k<thirdArray.length; k+=3) {
		thirdItemCount++;
		thirdItemName = "item" + thirdCounter + "_" + thirdItemCount;
		thirdItem = makeElement(thirdItemName,thirdMenu);

		if (thirdItemCount >1)
			thirdItem.prevItem = eval("item" + thirdCounter + "_" +(thirdItemCount-1));

		thirdItem.setup = itemSetup;
		thirdItem.setup(k,thirdArray);

	}

	thirdMenu.setup(true,thirdItem,secondMenu,secondItem);
}

function linkIt() {
	main.location.href = this.linkText;
}

function showIt(on) {
	if (NS4) {this.visibility = (on) ? "show" : "hide"}
		else {this.style.visibility = (on) ? "visible" : "hidden"}
}

function keepInWindow() {
	scrBars = 20;

	if (NS4) {

		winRight = (main.pageXOffset + main.innerWidth) - scrBars;
		rightPos = this.left + menuWidth;
   
		if (rightPos > winRight) {
			if (this.hasParent) {
				parentLeft = this.parentMenu.left;
				newLeft = ((parentLeft-menuWidth) + childOverlap);
				this.left = newLeft;
			}
			else {
				dif = rightPos - winRight;
				this.left -= dif;
			}
		}

		winBot = (main.pageYOffset + main.innerHeight) - scrBars;
		botPos = this.top + this.fullHeight;

		if (botPos > winBot) {
			dif = botPos - winBot;
			this.top -= dif;
		}
	}
	else {

	   	winRight = (main.document.body.scrollLeft + main.document.body.clientWidth) - scrBars;

		rightPos = this.style.pixelLeft + menuWidth;
	
		if (rightPos > winRight) {
			if (this.hasParent) {
				parentLeft = this.parentMenu.style.pixelLeft;
				newLeft = ((parentLeft - menuWidth) + childOverlap);
				this.style.pixelLeft = newLeft;
			}
			else {
				dif = rightPos - winRight;
				this.style.pixelLeft -= dif;
			}
		}
		winBot = (main.document.body.scrollTop + main.document.body.clientHeight) - scrBars;
		botPos = this.style.pixelTop + this.fullHeight;

		if (botPos > winBot) {
			dif = botPos - winBot;
			this.style.pixelTop -= dif;
		}
	}
}

function popUp(menuName,e){
	if (!areCreated) return;

	hideAll();
	currentMenu = eval(menuName);

	if (isLeftNav) {	
		xPos = (NS4) ? main.pageXOffset : main.document.body.scrollLeft;
		yPos = (NS4) ? (e.pageY-pageYOffset)+main.pageYOffset : event.clientY + main.document.body.scrollTop;
	}
	else {
		xPos = (NS4) ? (e.pageX-pageXOffset)+main.pageXOffset : event.clientX + main.document.body.scrollLeft;
		yPos = (NS4) ? main.pageYOffset : main.document.body.scrollTop;
	}
	currentMenu.moveTo(xPos,yPos);

	currentMenu.keepInWindow()
	currentMenu.isOn = true;
	currentMenu.showIt(true);
}

function popDown(menuName){ 
	if (!areCreated) return;
	whichEl = eval(menuName);
	whichEl.isOn = false;
	whichEl.hideTop();
}

function menuOver() {
	this.isOn = true;
	isOverMenu = true;
	currentMenu = this;
	if (this.hideTimer) clearTimeout(this.hideTimer);
}

function menuOut() {
	if (IE4) theEvent = main.event;
	if (IE4 && theEvent.srcElement.contains(theEvent.toElement)) return;
	this.isOn = false;
	isOverMenu = false;
	if (IE4) allTimer = setTimeout("currentMenu.hideTree()",10); 
}

function itemOver(){ 
	if (IE4) theEvent = main.event;
	if (IE4 && theEvent.srcElement.tagName == "IMG") return;

	if (NS4) {
		this.bgColor = overCol;
	}
	else {
		this.style.backgroundColor = overCol;
		this.style.color = overFnt;
	}
	
	if (this.container.hasChildVisible) {
		this.container.hideChildren(this);
	}            

	if(this.hasMore) {
		if (NS4) {
			this.childX = this.container.left + (menuWidth - childOverlap);
			this.childY = this.pageY + childOffset;
		}
		else {
			this.childX = this.container.style.pixelLeft + (menuWidth - childOverlap);
			this.childY = this.style.pixelTop + this.container.style.pixelTop + childOffset;
		}

		this.child.moveTo(this.childX,this.childY);
		this.child.keepInWindow();
		this.container.hasChildVisible = true;
		this.container.visibleChild = this.child;
		this.child.showIt(true);
	}
}


function itemOut() {
	if (IE4) theEvent = main.event;
    if (IE4 && (theEvent.srcElement.contains(theEvent.toElement)
     || (theEvent.fromElement.tagName=="IMG" && theEvent.toElement.contains(theEvent.fromElement))))
        return;

	if (NS4) {
		this.bgColor = backCol;
		if (!isOverMenu) {
			allTimer = setTimeout("currentMenu.hideTree()",10);
		}
	}
	else {
		this.style.backgroundColor = backCol;
		this.style.color = fntCol;
	}
}

function hideAll() {
	for(i=1; i<topCount; i++) {
		temp = eval("elMenu" + i);
		temp.isOn = false;
		if (temp.hasChildVisible) temp.hideChildren();
		temp.showIt(false);
	}	
}
  	
function hideTree() { 
	allTimer = null;
	if (isOverMenu) return;
	if (this.hasChildVisible) {
		this.hideChildren();
	}
	this.hideParents();
}

function hideChildren(item) {
	if (this.visibleChild.hasChildVisible) {
		this.visibleChild.visibleChild.showIt(false);
		this.visibleChild.hasChildVisible = false;
	}

	if (!this.isOn || !item.hasMore || this.visibleChild != this.child) {
		this.visibleChild.showIt(false);
		this.hasChildVisible = false;
	}
}

function hideParents() {     

	if (this.hasParent) {
		this.showIt(false);
		if (this.parentMenu.hasParent) {
			this.parentMenu.isOn = false;		
			this.parentMenu.showIt(false);
			this.parentMenu.parentMenu.isOn = false;
			whichEl = this.parentMenu.parentMenu
		}
		else {
			this.parentMenu.isOn = false;
			whichEl = this.parentMenu;
		}
	}
	else {
		whichEl = this;
	}

	whichEl.hideTop();
}

function hideTop() {
	whichEl = this;
	this.hideTimer = setTimeout("whichEl.hideSelf()",mSecsVis);
}

function hideSelf() {
	this.hideTimer = null;
	if (!this.isOn && !isOverMenu) { 
		this.showIt(false);
	}
}

function cancelSelect(){return false}

function moveTo(xPos,yPos) {
	this.style.pixelLeft = xPos;
	this.style.pixelTop = yPos;
}

