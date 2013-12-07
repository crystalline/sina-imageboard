
function insert(text)
{
	//var textarea=document.forms.postform.field4;
	var textarea = document.getElementById('msg_text')
	if(textarea)
	{
		if(textarea.createTextRange && textarea.caretPos) // IE
		{
			var caretPos=textarea.caretPos;
			caretPos.text=caretPos.text.charAt(caretPos.text.length-1)==" "?text+" ":text;
		}
		else if(textarea.setSelectionRange) // Firefox
		{
			var start=textarea.selectionStart;
			var end=textarea.selectionEnd;
			textarea.value=textarea.value.substr(0,start)+text+textarea.value.substr(end);
			textarea.setSelectionRange(start+text.length,start+text.length);
		}
		else
		{
			textarea.value+=text+" ";
		}
		textarea.focus();
	}
}

function highlight(post)
{
	var cells=document.getElementsByTagName("div");
	for(var i=0;i<cells.length;i++) {
	    if(cells[i].className=="post" && cells[i].id==String(post)) {
            cells[i].className="post_highlight";
	        insert(">>"+String(post))
	    }
	    
	}
	
	return true;
}

window.onload=function(e)
{
	var match;

	if(match=/#([0-9]+)/.exec(document.location.toString()))
        insert(">>"+match[1]);
}
