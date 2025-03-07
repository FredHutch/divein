function removeChildNodes(parentNode) {
	var kids = parentNode.childNodes;    // Get the list of children
    var numkids = kids.length;  // Figure out how many children there are
    for(var i = numkids-1; i >= 0; i--) {  // Loop backward through the children
        var c = parentNode.removeChild(kids[i]);    // Remove a child
    }
}

function reset_all(form) {
	form.reset();
	form.seqFile.disabled = false;
	form.datatype.disabled = false;
	form.freq.disabled = false;
	form.ttText.disabled = true;
	disable_grpRadio(form.ttRadio);
	form.propText.disabled = true;
	form.gammaText.disabled = true;
	form.treeImprovType.disabled = false;
	form.aLRT.disabled = true;
	form.bsText.disabled = true;
	form.divergence.disabled = false;
	form.seqText.disabled = true;
	form.divermeasure.disabled = false;
	form.outgrpFile.disabled = false;
	enable_grpRadio(form.outgrpRadio);
	form.grpFile.disabled = false;
	enable_grpRadio(form.grpRadio);
}

function enable_field(field, value) {
	if (value) {
		field.value = value;
	}
	field.disabled = false;
//	field.value = value;
}

function disable_field(field) {
	field.value = "";
	field.disabled = true;
}

function enable_text(field) {
	field.disabled = false;
}

function disable_text(field) {
	field.disabled = true;
}

function enable_select(field) {
	field.disabled = false;
}

function disable_select(field) {
	field.disabled = true;
}

function select_multiple(multiselect, idx) {
	if (idx == 'all') {
		for (var i = 0; i < multiselect.length; i++) {
			multiselect.options[i].selected = true;
		}
	}else {
		for (var i = 0; i < multiselect.length; i++) {
			if (i == idx) {
				multiselect.options[i].selected = true;
			}else {
				multiselect.options[i].selected = false;
			}			
		}
	}	
}

function handle_treeImprovType(value, treeImprovType) {
	if (value == 'tlr') {
		treeImprovType.disabled = false;
	}else {
		treeImprovType.disabled = true;
	}
}

function changeOptions (datatype, id, program) {
	var modelSelectNode = document.getElementById(id);
	removeChildNodes(modelSelectNode);
	var modelOptions = Array ();
	if (program == "phyml") {
		if (datatype == "nt") {	// nt
			modelOptions[0] = "F81";
			modelOptions[1] = "GTR";
			modelOptions[2] = "HKY85";
			modelOptions[3] = "JC69";
			modelOptions[4] = "K80";
			modelOptions[5] = "TN93";
		
			for (var i = 0; i < 6; i++) {
				var modelOption = document.createElement("option");
				modelOption.value = modelOptions[i];
				if (modelOptions[i] == "GTR") {
					modelOption.selected = true;
				}
				modelOption.appendChild(document.createTextNode(modelOptions[i]));
				modelSelectNode.appendChild(modelOption);
			}
		}else {	// aa
			modelOptions[0] = "Blosum62";
			modelOptions[1] = "CpREV";
			modelOptions[2] = "Dayhoff";
			modelOptions[3] = "DCMut";
			modelOptions[4] = "HIVb";
			modelOptions[5] = "HIVw";
			modelOptions[6] = "JTT";
			modelOptions[7] = "LG";
			modelOptions[8] = "MtArt";
			modelOptions[9] = "MtMam";
			modelOptions[10] = "MtREV";
			modelOptions[11] = "RtREV";
			modelOptions[12] = "VT";
			modelOptions[13] = "WAG";
			for (var i = 0; i < 14; i++) {
				var modelOption = document.createElement("option");
				modelOption.value = modelOptions[i];
				if (modelOptions[i] == "LG") {
					modelOption.selected = true;
				}
				modelOption.appendChild(document.createTextNode(modelOptions[i]));
				modelSelectNode.appendChild(modelOption);
			}
		}
		var freq = document.getElementById('freq');
		handleFreq('GTR', freq);
	}else if (program == "fasttree") {
		if (datatype == "nt") {	// nt
			modelOptions[0] = "GTR";
			modelOptions[1] = "JC69";
		
			for (var i = 0; i < 2; i++) {
				var modelOption = document.createElement("option");
				modelOption.value = modelOptions[i];
				if (modelOptions[i] == "GTR") {
					modelOption.selected = true;
				}
				modelOption.appendChild(document.createTextNode(modelOptions[i]));
				modelSelectNode.appendChild(modelOption);
			}
		}else {	// aa
			modelOptions[0] = "LG";
			modelOptions[1] = "WAG";
			modelOptions[2] = "JTT";
			for (var i = 0; i < 3; i++) {
				var modelOption = document.createElement("option");
				modelOption.value = modelOptions[i];
				if (modelOptions[i] == "LG") {
					modelOption.selected = true;
				}
				modelOption.appendChild(document.createTextNode(modelOptions[i]));
				modelSelectNode.appendChild(modelOption);
			}
		}
	}else if (program == "raxml") {
		if (datatype == "nt") {	// nt
			modelOptions[0] = "GTR";
			modelOptions[1] = "HKY85";
			modelOptions[2] = "JC69";
			modelOptions[3] = "K80";
		
			for (var i = 0; i < 4; i++) {
				var modelOption = document.createElement("option");
				modelOption.value = modelOptions[i];
				if (modelOptions[i] == "GTR") {
					modelOption.selected = true;
				}
				modelOption.appendChild(document.createTextNode(modelOptions[i]));
				modelSelectNode.appendChild(modelOption);
			}
		}else {	// aa
			modelOptions[0] = "BLOSUM62";
			modelOptions[1] = "CPREV";
			modelOptions[2] = "DAYHOFF";
			modelOptions[3] = "DCMUT";
			modelOptions[4] = "HIVB";
			modelOptions[5] = "HIVW";
			modelOptions[6] = "JTT";
			modelOptions[7] = "LG";
			modelOptions[8] = "MTART";
			modelOptions[9] = "MTMAM";
			modelOptions[10] = "MTREV";
			modelOptions[11] = "RTREV";
			modelOptions[12] = "VT";
			modelOptions[13] = "WAG";
			for (var i = 0; i < 14; i++) {
				var modelOption = document.createElement("option");
				modelOption.value = modelOptions[i];
				if (modelOptions[i] == "LG") {
					modelOption.selected = true;
				}
				modelOption.appendChild(document.createTextNode(modelOptions[i]));
				modelSelectNode.appendChild(modelOption);
			}
		}
	}
	
}

function handleFreq(value, freq) {
	if (value == "JC69" || value == "K80") {
		freq.disabled = true;
	}else {
		freq.disabled = false;
	}
}

function handleTT (value, ttText, ttFixRadio, ttEstRadio) {
	if (value == "HKY85" || value == "K80" || value == "TN93") {
		ttText.value = 4;
		ttText.disabled = false;
		ttFixRadio.disabled = false;
		ttFixRadio.checked = true;
		ttEstRadio.disabled = false;
	}else {
		ttText.value = "";
		ttText.disabled = true;
		ttFixRadio.disabled = true;
		ttEstRadio.checked = true;
		ttEstRadio.disabled = true;
	}
}

function disableGamma(value, gammaText, gammaFixRadio, gammaEstRadio) {
	if (value <= 1 || value.match(/^\s*$/)) {
		gammaText.value = "";
		gammaText.disabled = true;
		gammaFixRadio.disabled = true;
		gammaEstRadio.checked = true;
		gammaEstRadio.disabled = true;
	}else {
		gammaText.value = "";
		gammaText.disabled = true;
		gammaFixRadio.disabled = false;
		gammaEstRadio.checked = true;
		gammaEstRadio.disabled = false;
	}
}

function enable_diver(help_source) {
	var diver = document.getElementById("diver");
	removeChildNodes(diver);
	var span1 = document.createElement("span");
	span1.className = "label";
	var ddLink = document.createElement("a");
	ddLink.setAttribute("href", help_source+"#diver");
	ddLink.appendChild(document.createTextNode("Calculate diversity and/or divergence based on"));
	span1.appendChild(ddLink);
	
	var span2 = document.createElement("span");
	span2.className = "formw";
	
	var innerHTML = "<input type='checkbox' name='diverFormat' value='tree'>";
	var checkbox1;
	try {
		checkbox1 = document.createElement(innerHTML);
	}catch (err) {
		checkbox1 = document.createElement("input");
		checkbox1.type = "checkbox";
		checkbox1.name = "diverFormat";
		checkbox1.value = "tree";
	}		

	innerHTML = "<input type='checkbox' name='diverFormat' value='pairwise' checked=true>";
	var checkbox2;
	try {
		checkbox2 = document.createElement(innerHTML);
	}catch (err) {
		checkbox2 = document.createElement("input");
		checkbox2.type = "checkbox";
		checkbox2.name = "diverFormat";
		checkbox2.value = "pairwise";
		checkbox2.checked = true;
	}

	span2.appendChild(checkbox1);			
	span2.appendChild(document.createTextNode("Tree"));
	span2.appendChild(checkbox2);
	span2.appendChild(document.createTextNode("Pairwise distances"));
	
	diver.appendChild(span1);
	diver.appendChild(span2);
}

function disable_diver() {
	var diver = document.getElementById("diver");
	removeChildNodes(diver);
}

function check_radio(radioId) {
	radioId.checked = true;
}

function uncheck (id) {
	id.checked = false;
}

function disable_radio (radioId) {
	radioId.disabled = true;
}

function enable_radio (radioId) {
	radioId.disabled = false;
}

function disable_grpRadio (grpRadio) {
	for (var i = 0; i < grpRadio.length; i++) {
		grpRadio[i].disabled = true;
	}
}

function enable_grpRadio (grpRadio) {
	for (var i = 0; i < grpRadio.length; i++) {
		grpRadio[i].disabled = false;
	}
}

function handleRadios(value, radios) {
//	alert ("value: "+value);
	if (value) {
		radios[0].checked = true;
	}else {
		radios[1].checked = true;
	}
}

function remove_value(field) {	
	try {
		field.parentNode.innerHTML = field.parentNode.innerHTML;
	}catch (err) {		
		field.value = '';	
	}	
}

function popitup(url) {
	newwindow=window.open(url,'name','height=50%,width=50%');
	if (window.focus) {newwindow.focus()}
	return false;
}

function isEmail (field) {
	if (field.value.indexOf("@") == -1 || field.value.indexOf(".") == -1) {
		return false;
	}else {
		return true;
	}
}

function set_fields (cb) {
	var othercb;
	var distFile1 = document.getElementById("distFile1");
	var distFile2 = document.getElementById("distFile2");
	if (cb.name == "cb1") {
		othercb =  document.getElementById("cb2");
	}else {
		othercb =  document.getElementById("cb1");
	}
	if (cb.checked) {
		othercb.checked = true;
		disable_field(distFile1);
		disable_field(distFile2);
	}else {
		othercb.checked = false;
		enable_field(distFile1);
		enable_field(distFile2);
	}
	
}

function CheckInsitesForm (form) {
	if (!form.seqRadio[2].checked && form.seqFile.value.match(/^\s*$/)) {
		alert ("Please upload sequence file");
		form.seqFile.focus();
		return false;
	}else if (!form.seqRadio[2].checked && !form.datatype.value) {
		alert ("Please select a sequence data type");
		form.datatype.focus();
		return false;
	}
	return true;
}

function CheckCotForm(form) {
	if (!isEmail(form.email)) {
		alert ("Please enter your email address");
		form.email.focus();
		return false;
	}
	
	if (!form.seqRadio[2].checked) {
		if (form.seqFile.value.match(/^\s*$/)) {
			alert ("Please upload sequence file");
			form.seqFile.focus();
			return false;
		}else if (!form.datatype.value) {
			alert ("Please select a sequence data type");
			form.datatype.focus();
			return false;
		}else if (form.treeRadio[0].checked && form.treeFile.value.match(/^\s*$/)) {
			alert ("You select to upload newick tree file, please upload one");
			form.treeFile.focus();
			return false;
		}
	}
	return true;
}

function CheckTstForm(form) {
	if (!isEmail(form.email)) {
		alert ("Please enter your email address");
		form.email.focus();
		return false;
	}else if (form.projectId.value) {
		if (!form.projectId.value.match(/^\s*\d+\s*$/)) {
			alert ("Please enter correct project Id that should be comprised of digits");
			form.projectId.focus();
			return false;
		}
	}else if (form.diveinFile.value.match(/^\s*$/) && form.userFile.value.match(/^\s*$/) && !form.diveinExampleCb.checked && !form.userExampleCb.checked) {
		alert ("Please upload pairwise distance file");
		return false;
	}else if (form.seqFile.value.match(/^\s*$/) && !form.seqExampleCb.checked) {
		alert ("Please upload sequence fasta file");
		form.seqFile.focus();
		return false;
	}
	
	return true;
}

function CheckDiverForm(form) {
	//alert("CheckDiverForm");
	form.action = "/cgi-bin/diver/diver_grp.cgi";
	if (form.aLRTRadio[0].checked) {
		//alert("yes!");
		form.action = "/cgi-bin/diver/diver.cgi";			
	}
	if (!isEmail(form.email)) {
		alert ("Please enter your email address");
		form.email.focus();
		return false;
	}else if (!form.seqRadio[2].checked && form.seqFile.value.match(/^\s*$/)) {
		alert ("Please upload sequence file");
		form.seqFile.focus();
		return false;
	}else if (!form.seqRadio[2].checked && !form.datatype.value) {
		alert ("Please select a sequence data type");
		form.datatype.focus();
		return false;	
	}else if (form.seedRadio[0].checked) {
		if (!form.seedText.value.match(/^\d+$/)) {
			alert ("Please enter only the intiger number for the seed");
			form.seedText.focus();
			return false;
		}
	}else if (form.bsRadio[0].checked) {
		if (!form.bsText.value.match(/^\d+$/)) {
			alert ("Please enter only the number for bootstrap replications");
			form.bsText.focus();
			return false;
		}
		if (form.bsText.value > 100) {
			alert ("The number for bootstrap replications is limited to 100.");
			form.bsText.focus();
			return false;
		}				
	}else if (form.ttRadio[0].checked && !form.ttText.value.match(/^\d+$/)) {
		alert ("Please enter only the number for transition/transversion ratio");
		form.ttText.focus();
		return false;			
	}else if (form.propRadio[0].checked && !form.propText.value.match(/^\d+(\.\d+){0,1}$/)) {
		alert ("Please enter only numerical number for proportion of invariable sites");
		form.propText.focus();
		return false;				
	}else if (!form.catText.value.match(/^\d+$/)) {
		alert ("Please enter only the number for substitution rate categories");
		form.catText.focus();
		return false;
	}else if (form.gammaRadio[0].checked && !form.gammaText.value.match(/^\d+(\.\d+){0,1}$/)) {
		alert ("Please enter only numerical number for gamma distribution parameter");
		form.gammaText.focus();
		return false;
	}else if (form.bsRadio[1].checked && form.aLRTRadio[1].checked  && !form.divermeasure[0].selected && !form.divermeasure[1].selected) {
		alert ("Please check one or both methods for calculating divergence and diversity");
		form.divermeasure.focus();
		return false;
	}else if (form.divergence.options[0].selected && form.outgrpRadio[1].checked) {
		alert ("Need an outgroup file containing the name of outgroup sequence(s) to calculate MRCA");
//		form.outgrpFile.focus();
		return false;
	}else if (form.divergence.options[3].selected && form.seqText.value.match(/^\s*$/)) {
		alert ("Please enter a sequence name for calculating divergence from the specific sequence in alignment");
//		form.seqText.focus();
		return false;
	}
	return true;
}

function CheckFastTreeForm(form) {
	//alert("CheckFastTreeForm");
	form.action = "/cgi-bin/diver/fasttree_grp.cgi";
	if (form.aLRTRadio[0].checked) {
		//alert("yes");
		if (!form.sh.value.match(/^\d+$/)) {
			alert ("Please enter only the number for bootstrap replications");
			form.sh.focus();
			return false;
		}
		form.action = "/cgi-bin/diver/fasttree.cgi";			
	}
	if (!isEmail(form.email)) {
		alert ("Please enter your email address");
		form.email.focus();
		return false;
	}else if (!form.seqRadio[2].checked && form.seqFile.value.match(/^\s*$/)) {
		alert ("Please upload sequence file");
		form.seqFile.focus();
		return false;
	}else if (!form.seqRadio[2].checked && !form.datatype.value) {
		alert ("Please select a sequence data type");
		form.datatype.focus();
		return false;	
	}else if (form.ttRadio[0].checked && !form.ttText.value.match(/^\d+$/)) {
		alert ("Please enter only the number for transition/transversion ratio");
		form.ttText.focus();
		return false;			
	}else if (form.propRadio[0].checked && !form.propText.value.match(/^\d+(\.\d+){0,1}$/)) {
		alert ("Please enter only numerical number for proportion of invariable sites");
		form.propText.focus();
		return false;				
	}else if (!form.catText.value.match(/^\d+$/)) {
		alert ("Please enter only the number for substitution rate categories");
		form.catText.focus();
		return false;
	}else if (form.gammaRadio[0].checked && !form.gammaText.value.match(/^\d+(\.\d+){0,1}$/)) {
		alert ("Please enter only numerical number for gamma distribution parameter");
		form.gammaText.focus();
		return false;
	}	
	return true;
}

function CheckRaxmlForm(form) {
	//alert("CheckRaxmlForm");
	form.action = "/cgi-bin/diver/raxml_grp.cgi";
	if (form.bsRadio[0].checked) {
		//alert("yes");
		if (!form.bsText.value.match(/^\d+$/)) {
			alert ("Please enter only the number for bootstrap replications");
			form.bsText.focus();
			return false;
		}
		form.action = "/cgi-bin/diver/raxml.cgi";			
	}
	if (!isEmail(form.email)) {
		alert ("Please enter your email address");
		form.email.focus();
		return false;
	}else if (!form.seqRadio[2].checked && form.seqFile.value.match(/^\s*$/)) {
		alert ("Please upload sequence file");
		form.seqFile.focus();
		return false;
	}else if (!form.seqRadio[2].checked && !form.datatype.value) {
		alert ("Please select a sequence data type");
		form.datatype.focus();
		return false;	
	}	
	return true;
}


function CheckClusterForm(form) {
	if (!isEmail(form.email)) {
		alert ("Please enter your email address");
		form.email.focus();
		return false;
	}else if (form.seqFile.value.match(/^\s*$/) && form.alignFile.value.match(/^\s*$/) && form.treeFile.value.match(/^\s*$/) && !form.seqExampleCb.checked && !form.alignExampleCb.checked && !form.treeExampleCb.checked) {
		alert ("Please upload input data file");
		return false;
	}else if (!form.minclustersize.value.match(/^\d+$/)) {
		alert ("Please enter only numerical number for minimal cluster size");
		form.minclustersize.focus();
		return false;
	}else if (!form.distcutoff.value.match(/^\d+(\.\d+){1}$/)) {
		alert ("Please enter only decimal number for distance threshold");
		form.distcutoff.focus();
		return false;
	}
	return true;
}

function CheckRetrieveForm (form) {	
	if (!form.projectId.value.match(/^\s*\d+\s*$/)) {
		alert ("Please enter the digital number of your project ID.");
		form.projectId.focus();
		return false;
	}
	return true;
}

function checkform(form, id) {
	if (!isEmail(form.email)) {
		alert ("Please enter your email address");
		form.email.focus();
		return false;
	}
	
	if (id == 'DtMRCADD') {	
		if (!form.fileRadio[3].checked && form.seqFile.value.match(/^\s*$/)) {
			alert ("Please upload sequence file");
			form.seqFile.focus();
			return false;
		}else {
			if ( form.outgrpfileRadio[0].checked && form.outgrpFile.value.match(/^\s*$/)) {
				alert ("Please upload outgroup file");
				form.outgrpFile.focus();
				return false;
			}else if (form.grpfileRadio[0].checked && form.grpFile.value.match(/^\s*$/)) {
				alert ("Please upload group file");
				form.grpFile.focus();
				return false;
			}else if (form.bsRadio[0].checked) {
				if (!form.bsText.value.match(/^\d+$/)) {
					alert ("Please enter only the number for bootstrap replications");
					form.bsText.focus();
					return false;
				}
				if (form.bsText.value > 100) {
					alert ("The number for bootstrap replications is limited to 100");
					form.bsText.focus();
					return false;
				}				
			}else if (form.ttRadio[0].checked && !form.ttText.value.match(/^\d+$/)) {
				alert ("Please enter only the number for transition/transversion ratio");
				form.ttText.focus();
				return false;			
			}else if (form.propRadio[0].checked && !form.propText.value.match(/^\d+(\.\d+){0,1}$/)) {
				alert ("Please enter only numerical number for proportion of invariable sites");
				form.propText.focus();
				return false;				
			}else if (!form.catText.value.match(/^\d+$/)) {
				alert ("Please enter only the number for substitution rate categories");
				form.catText.focus();
				return false;
			}else if (form.gammaRadio[0].checked && !form.gammaText.value.match(/^\d+(\.\d+){0,1}$/)) {
				alert ("Please enter only numerical number for gamma distribution parameter");
				form.gammaText.focus();
				return false;				
			}else if (form.treeFileRadio[0].checked && form.treeFile.value.match(/^\s*$/)) {
				alert ("Please upload start tree file");
				form.treeFile.focus();
				return false;				
			}else if (form.bsRadio[1].checked && !form.diverFormat[0].checked && !form.diverFormat[1].checked) {
				alert ("Please check one or both methods for calculating divergence and diversity");
				return false;
			}
		}	
	}else {
		if (!form.distRadio[2].checked && form.distFile.value.match(/^\s*$/)) {
			alert ("Please upload distant file");
			form.distFile.focus();
			return false;
		}else if (form.grpfileRadio[0].checked && form.distGrpFile.value.match(/^\s*$/)) {
			alert ("Please upload defined group file");
			form.distGrpFile.focus();
			return false;
		}
	}	
	return true;
}

function handleDivergence(multiselect) {
	var seqText = document.getElementById("seqText");
	if (multiselect.options[3].selected) {
		seqText.disabled = false;
		seqText.focus();
	}else {
		seqText.value = '';
		seqText.disabled = true;
	}

/*	var seqRow = document.getElementById("seqRow");
	var outgrpFile = document.getElementById('outgrpFile');
	var outgrpRadios = document.getElementsByName('outgrpRadio');
	if (multiselect.options[3].selected) {
		if (!document.getElementById("seqText")) {
			removeChildNodes(seqRow);
			var rowdiv = document.createElement("div");
			rowdiv.className = "row";
			var span1 = document.createElement("span");
			span1.className = "label";
			span1.appendChild(document.createTextNode("Input sequence name:"));
			
			var span2 = document.createElement("span");
			span2.className = "formw";
			var seqText = document.createElement("input");
			seqText.type = "text";
			seqText.name = "seqText";
			seqText.id = "seqText";
			seqText.size = 25;
			span2.appendChild(seqText);
			
			rowdiv.appendChild(span1);
			rowdiv.appendChild(span2);
			seqRow.appendChild(rowdiv);
		}		
	}else {
		removeChildNodes(seqRow);
	}
	if (multiselect.options[0].selected) {		
		outgrpFile.disabled = false;
		outgrpRadios[0].checked = true;
	}else {
		outgrpFile.disabled = true;
		outgrpRadios[1].checked = true;
	}
*/
}

function checkHistForm (form) {
	if (form.radio[1].checked == true) {
		var minDist = form.mindist.value;
		var maxDist = form.maxdist.value;
		if (!minDist.match(/^\s*\d*\.?\d+\s*$/) || !maxDist.match(/^\s*\d*\.?\d+\s*$/)) {
			alert ("Please enter the float number for minumal and maximal distances");
			return false;
		}else {
			minDist = parseFloat(minDist);
			maxDist = parseFloat(maxDist);
			if (minDist >= maxDist) {
				alert ("Maximal distance value must be greater than minimal distance");
				return false;
			}
		}
	}
	
	if (form.binBox.value.match(/^\s*\d+\s*$/) && form.binBox.value > 0) {
		return true;
	}else {
		alert ("Please enter only the integer number for Bins");
		return false;				
	}	
}

function DistText(flag, form) {		
	if (flag == 'enable') {
		form.mindist.disabled = false;
		form.maxdist.disabled = false;
	}else {
		form.mindist.value = "";
		form.maxdist.value = "";
		form.mindist.disabled = true;
		form.maxdist.disabled = true;
	}
}

var NS4 = (navigator.appName == "Netscape" && parseInt(navigator.appVersion) < 5);

function addOption(theSel, theText, theValue)
{
  var newOpt = new Option(theText, theValue);
  var selLength = theSel.length;
  theSel.options[selLength] = newOpt;
}

function deleteOption(theSel, theIndex)
{ 
  var selLength = theSel.length;
  if(selLength>0)
  {
    theSel.options[theIndex] = null;
  }
}

function moveOptions(theSelFrom, theSelTo)
{
  
  var selLength = theSelFrom.length;
  var selectedText = new Array();
  var selectedValues = new Array();
  var selectedCount = 0;
  
  var i;
  
  // Find the selected Options in reverse order
  // and delete them from the 'from' Select.
  for(i=selLength-1; i>=0; i--)
  {
    if(theSelFrom.options[i].selected)
    {
      selectedText[selectedCount] = theSelFrom.options[i].text;
      selectedValues[selectedCount] = theSelFrom.options[i].value;
      deleteOption(theSelFrom, i);
      selectedCount++;
    }
  }
  
  // Add the selected text/values in reverse order.
  // This will add the Options to the 'to' Select
  // in the same order as they were in the 'from' Select.
  for(i=selectedCount-1; i>=0; i--)
  {
    addOption(theSelTo, selectedText[i], selectedValues[i]);
  }
  
  if(NS4) history.go(0);
}

function handle_seqExampleCb(cb, seqExampleCb) {
	if (cb.checked) {
		seqExampleCb.checked = true;
	}else {
		seqExampleCb.checked = false;
	}
}

function handle_distExampleCb(cb, diveinExampleCb, userExampleCb) {
	if (!cb.checked) {
		diveinExampleCb.checked = false;
		userExampleCb.checked = false;
	}	
}

function CheckSampleList(className) {
	var sample1group = 0;
	var sample2group = 0;
	var mulselects = document.getElementsByClassName(className);
	for (var i=0; i<mulselects.length; i++) {
		var select = mulselects[i];
		if (select.name != 'allSeqName') {					
			if (select.length < 4) {
				alert ("At least 4 sequences in each sample group");
				return false;
			}
			if (select.name.match(/sample1group/)) {
				sample1group = 1;
			}else if (select.name.match(/sample2group/)) {
				sample2group = 1;
			}
		}				
	}
	if (!sample1group || !sample2group) {
		alert ("Please define sequences in both sample 1 and sample 2");
		return false;
	}
	return true;
}

function CheckOutgroup (DiverSeqName, OutgrpSeqName, className) {
	for (var i=0; i<DiverSeqName.length; i++) {
		if (DiverSeqName[i].value == "MRCA") {
			if (OutgrpSeqName.length < 1) {
				alert ("Please define outgroup sequence(s) in order to calculate divergence from MRCA");
				return false;
			}
		}		
	}
	var mulselects = document.getElementsByClassName(className);
	for (var i=0; i<mulselects.length; i++) {
		var select = mulselects[i];
		if (select.name.match(/^ingrp/) && select.length == 0) {
			alert ("Please define group sequences in ingroup field");
			return false;
		}
	}
	return true;
}

function CheckGroups (className) {
	var mulselects = document.getElementsByClassName(className);
	for (var i=0; i<mulselects.length; i++) {
		var select = mulselects[i];
		if (select.name == "reference" && select.length > 1) {
			alert ("Please define only one reference sequence at a time");
			return false;
		}
		if (select.name.match(/^ingrp/) && select.length == 0) {
			alert ("Please define group sequences in group field");
			return false;
		}
	}
	return true;
}

function setAllTrue (className) {
	var mulselects = document.getElementsByClassName(className);
	for (var i=0; i<mulselects.length; i++) {
//		alert ("select "+i+": "+mulselects[i].name);
		var select = mulselects[i];
		if (select.name != 'allSeqName') {
			for (var j=0; j<select.length; j++) {
				select[j].selected = true;
			}	
		}			
	}
}

function setMeasurement (multiselect, idx) {
	for (var i = 0; i < multiselect.length; i++) {
		if (i == idx) {
			multiselect.options[i].selected = true;
		}else {
			multiselect.options[i].selected = false;
		}			
	}
}

function setSelectedTrue (grpId) {
	var select = document.getElementById(grpId);
	for (var i=0; i<select.length; i++) {
		select[i].selected = true;		
	}
}

function rmGrp (gid, selFrom) {
	var grp = document.getElementById(gid);
	var trNode = grp.parentNode.parentNode;
	setSelectedTrue(gid);
	moveOptions(grp, selFrom);
	removeChildNodes(trNode);
}

function addIngrp(tid, selFrom) {
	var table = document.getElementById(tid);
	var children = table.childNodes;
	var tr = document.createElement("tr");
	var td1 = document.createElement("td");
	var td2 = document.createElement("td");
	var td3 = document.createElement("td");
	var grpIdx = children.length;
	var grpName = "group "+grpIdx;
//	td1.vAlign = "middle";
	var rmButton = document.createElement("input");
	rmButton.setAttribute("type", "button");
	rmButton.setAttribute("value", "-");
	var rmgid = "ingrp"+grpIdx;
	rmButton.onclick = function () {rmGrp(rmgid, selFrom)};
	var grpName = document.createElement("input");
	grpName.className = "ingrpName";
	grpName.type = "text";
	grpName.id = "ingrpName"+grpIdx;
	grpName.name = "ingrpName"+grpIdx;
	grpName.size = 10;
	grpName.setAttribute("value", "group "+grpIdx);
	grpName.onfocus = function () {inputFocus(grpName)};
	grpName.onblur = function () {inputBlur(grpName)};
	td1.appendChild(grpName);
	td1.appendChild(document.createTextNode(" "));
	td1.appendChild(rmButton);
			
	var select = document.createElement("select");
	select.className = "mulselect";	
	select.name = "ingrp"+grpIdx;
	select.id = "ingrp"+grpIdx;
	select.multiple = "multiple";
	select.size = 5;
	td2.valign = "top";
	td2.appendChild(select);
	
	var leftArraw = document.createElement("input");
	leftArraw.type = "button";
	leftArraw.value = "<--";	
	leftArraw.onclick = function () {moveOptions(select, selFrom)};
	var rightArraw = document.createElement("input");
	rightArraw.type = "button";
	rightArraw.value = "-->";	
	rightArraw.onclick = function () {moveOptions(selFrom, select)};
		
	var spacer = document.createElement("div");
	spacer.className = "spacer";
		
	td3.appendChild(rightArraw);
	td3.appendChild(spacer);
	td3.appendChild(leftArraw);
	tr.appendChild(td3);
	tr.appendChild(td2);
	tr.appendChild(td1);
			
	table.insertBefore(tr, children[0]);
}

function addGrp(tid, gid, selFrom) {
	var table = document.getElementById(tid);
	var g1 = document.getElementById(gid);
	if (g1) {
		g1.size = 5;
	}
	var children = table.childNodes;
	var tr = document.createElement("tr");
	var td1 = document.createElement("td");
	var td2 = document.createElement("td");
	var td3 = document.createElement("td");
	var grpIdx = children.length;
	var grpName = " group "+grpIdx+" ";
//	td1.vAlign = "middle";
	var rmButton = document.createElement("input");
	rmButton.setAttribute("type", "button");
	rmButton.setAttribute("value", "-");
	var rmgid = '';
	if (gid == "sample1group1") {
		rmgid = "sample1group"+grpIdx;
	}else {
		rmgid = "sample2group"+grpIdx
	}
	rmButton.onclick = function () {rmGrp(rmgid, selFrom)};
	if (gid == "sample1group1") {
		td1.appendChild(rmButton);
		td1.appendChild(document.createTextNode(grpName));
	}else {
		td1.appendChild(document.createTextNode(grpName));
		td1.appendChild(rmButton);
	}	
	
	
	var select = document.createElement("select");
	select.className = "mulselect";
	if (gid == "sample1group1") {
		select.name = "sample1group"+grpIdx;
		select.id = "sample1group"+grpIdx;
	}else {
		select.name = "sample2group"+grpIdx;
		select.id = "sample2group"+grpIdx;
	}	
	select.multiple = "multiple";
	select.size = 5;
	
	td2.appendChild(select);
	
	var leftArraw = document.createElement("input");
	leftArraw.type = "button";
	leftArraw.value = "<--";
	if (gid == "sample1group1") {
		leftArraw.onclick = function () {moveOptions(selFrom, select)};
	}else {
		leftArraw.onclick = function () {moveOptions(select, selFrom)};
	}
	var rightArraw = document.createElement("input");
	rightArraw.type = "button";
	rightArraw.value = "-->";
	if (gid == "sample1group1") {
		rightArraw.onclick = function () {moveOptions(select, selFrom)};
	}else {
		rightArraw.onclick = function () {moveOptions(selFrom, select)};
	}
		
	var spacer = document.createElement("div");
	spacer.className = "spacer";
	
	if (gid == "sample1group1") {
		td3.appendChild(leftArraw);
		td3.appendChild(spacer);
		td3.appendChild(rightArraw);
		tr.appendChild(td1);
		tr.appendChild(td2);
		tr.appendChild(td3);
	}else {
		td3.appendChild(rightArraw);
		td3.appendChild(spacer);
		td3.appendChild(leftArraw);
		tr.appendChild(td3);
		tr.appendChild(td2);
		tr.appendChild(td1);
	}
			
	table.insertBefore(tr, children[0]);
}

function inputFocus(i){
//	alert ("value: "+i+", "+i.value);
//	alert ("default value: "+i.defaultValue);
    if(i.value==i.defaultValue){ i.value=""; i.style.color="#000"; }
}
function inputBlur(i){
//	alert ("value: "+i+", "+i.value);
//	alert ("default value: "+i.defaultValue);
    if(i.value==""){ i.value=i.defaultValue; i.style.color="#888"; }
}





