RequireVersion ("2.0");
/*ExecuteAFile ("/data/home/wdeng/HYPHY/hyphy/HYPHY/TemplateBatchFiles/TreeTools.ibf");*/
ExecuteAFile ("/var/www/html/HYPHY/TemplateBatchFiles/TreeTools.ibf");

/*-----------------------------------------------------------------------------	
	MAIN FUNCTION
------------------------------------------------------------------------------*/

function ComputeCOT (_treeID, _filePath)
/* IN 	: the identifier of an existing tree variable (String)
		  _filePath : if not an empty string, write a PostScript image with this tree
		  			  to the given path
		  			  
   OUT	: an associative array with four entries
   		  "Branch" 		- the branch where the COT resides
   		  				  branch ENDS at the node whose value is returned 
   		  				  
   		  "Split"  		- how far up the branch the COT is, measured in the same units as branch lengths
   		  				  from the END of the branch (i.e node) 
   		  				  
   		  "COTTree"		- tree rerooted at the COT
   		  
   		  "Distances"	- mean squared distance from the COT to all leaves		  
*/ 
{
	_power = 2;
					 /* '2' is the power of the distance function to 
						   minimize - i.e. least squares in this case */
	ExecuteCommands (
	"_cot = Min (`_treeID`,_power);");
	
	_returnList = {};
	_returnList ["Branch"] = _cot["COT_NODE"];
	_returnList ["Split"]  = _cot["COT_SPLIT"];
	_meanD = 0;
	_keys  = Rows(_cot["COT_TO_NODE"]); 
		/* _cot["COT_TO_NODE"] is an associative array
		   mapping tree nodes to the total distance from COT (linear distance)
		*/ 

	for (_k = 0; _k < Columns(_keys); _k=_k+1)
	{
		_meanD = _meanD + (_cot["COT_TO_NODE"])[_keys[_k]]^_power;
	}

	_returnList     ["Distances"]  = _meanD/Columns(_keys);
	/* reroot the tree at the COT branch */
	ExecuteCommands ("_rerootedTree = RerootTree (`_treeID`, \""+_returnList ["Branch"]+"\");");
	/* hackish lines below split the root branch into appropriate bits */
	
	ACCEPT_ROOTED_TREES = 1;
	UseModel (USE_NO_MODEL);
	Tree _temp = _rerootedTree;
	_tempA = _temp^0; /* this converts the tree into a post-order list of nodes as an associative array; 
						print it to see the structure */					       
	_rootID	   = (_tempA[0])["Root"];
	_dist	   = {};
	for (_k = 1; _k < Abs (_tempA); _k = _k + 1)
	{
		if ((_tempA[_k])["Parent"] == _rootID)
		{
			if (_k == _rootID - 1)
			{
				_dist [(_tempA[_k])["Name"]] = _cot["COT_SPLIT"];
			}
			else
			{
				_dist [(_tempA[_k])["Name"]] = _cot["COT_BRANCH_LENGTH"]-_cot["COT_SPLIT"];			
			}
		}
		else
		{
			_dist [(_tempA[_k])["Name"]] = (_tempA[_k])["Length"];
		}
	}
	
	_returnList["COTTree"] = PostOrderAVL2StringDistances (_tempA,_dist);
	
	/* make a postscript file if needed */
	if (Abs(_filePath))
	{
		TREE_OUTPUT_OPTIONS = {};
		nodeSpec = {};
		nodeSpec ["TREE_OUTPUT_BRANCH_SPLIT"]		= _cot["COT_SPLIT"]/_cot["COT_BRANCH_LENGTH"];	
		TREE_OUTPUT_OPTIONS [_cot["COT_NODE"]] 		= nodeSpec;
		ExecuteCommands 							("psString = PSTreeString (`_treeID`,\"STRING_SUPPLIED_LENGTHS\",{{-1,-1}});");
		fprintf 									(_filePath, CLEAR_FILE, psString);
	}

	return _returnList;
	
}

/*--------------------------------
	EXAMPLE OF USE
---------------------------------*/

/*
UseModel (USE_NO_MODEL);
Tree test = "((a:0.1,b:0.2):0.3, (c:0.05,(d:0.02,f:0.2):0.2): 0.5, e:0.5)";
cot_data = ComputeCOT ("test","tree.ps");
fprintf (stdout, cot_data);*/

/*--------------------------------
	EXAMPLE OF USE WITH DATA FIT TO GET THE SEQUENCE 
---------------------------------*/

DataSet 			ds 	= ReadDataFile (PROMPT_FOR_FILE);

DataSetFilter		filteredData	 = CreateFilter (ds,1);

/* use the rev model with beta-gamma rate variation (4 bins) via a standard file include with piped option */
options = {};
options ["1"] = "/var/www/html/HYPHY/TemplateBatchFiles/TemplateModels/EmpiricalAA/LG";
options ["2"] = "Estimated";
options ["3"] = "Rate variation";
options ["4"] = "General Discrete";
options ["5"] = "3";

ExecuteAFile 		("/var/www/html/HYPHY/TemplateBatchFiles/TemplateModels/Custom_AA_empirical.mdl",options);
ExecuteAFile 		("/var/www/html/HYPHY/TemplateBatchFiles/queryTree.bf");

VERBOSITY_LEVEL 	   = -1;
LikelihoodFunction  lf = (filteredData, givenTree);
Optimize (res,lf);

treeString = Format (givenTree,1,1);
UseModel (USE_NO_MODEL);
Tree test = treeString;

cot_data = ComputeCOT ("test","");
fprintf (stdout, cot_data);

UseModel (_customAAModel);
treeString = cot_data["COTTree"];
Tree cot_tree  = treeString;

/* need to rescale branch length parameters for 
the rerooted tree*/

/* ratios of the total lengths of each tree */

L1 = BranchLength (givenTree,-1);
L2 = BranchLength (cot_tree,-1);
L2 = (L1 * Transpose(L1)["1"])[0]/(L2 * Transpose(L2)["1"])[0];

bn = BranchName (cot_tree,-1);

for (k=0; k<Columns (bn); k=k+1)
{
	ExecuteCommands ("cot_tree."+bn[k]+".mu = cot_tree."+bn[k]+".mu * L2");
}

LikelihoodFunction _lf_ID = (filteredData, cot_tree);
											   
DataSet	 				mlAncestors = ReconstructAncestors (_lf_ID);
DataSetFilter			_AncestalFilter	= CreateFilter (mlAncestors,1);
GetDataInfo				(_AncestalFilterChars,_AncestalFilter,"CHARACTERS");

_samplingIterates		= 100;

_characterDimension 	= Columns (_AncestalFilterChars);

/* indexed linearly by seq*_AncestalFilter.sites + site -> (seq,site)*/
_mlInformation			= {};
/* [(i,j)] -> integer - most likely ancestor or (-1) for gap */

_sampledInformation		= {};
/* [(i,j)] -> {chars,1} - the frequency of each sampled character */

_marginalInformation	= {};
/* [(i,j)] -> {chars,1} - marginal support for each character */

GetString   (_AncestralNodeNames, _AncestalFilter, -1);
GetDataInfo (_AncestalFilterSiteToPatternMap, _AncestalFilter);

_idx_3 = 0;
_utility_Vector1 = {1,_characterDimension}["1"];
_utility_Vector2 = {1,_characterDimension}["_MATRIX_ELEMENT_COLUMN_"];

for (_idx_1 = 0; _idx_1 < _AncestalFilter.species; _idx_1 = _idx_1 + 1)
{
	for (_idx_2 = 0; _idx_2 < _AncestalFilter.sites; _idx_2 = _idx_2 + 1)
	{
		GetDataInfo (_charInfo, _AncestalFilter, _idx_1, _AncestalFilterSiteToPatternMap[_idx_2]);
		_whichChar = (_utility_Vector1*_charInfo)[0];
		if (_whichChar > 1)
		{
			_mlInformation[_idx_3] = -1;
		}
		else
		{
			_mlInformation[_idx_3] = (_utility_Vector2*_charInfo)[0];
		}
		_sampledInformation[_idx_3] = {_characterDimension,1};
		_idx_3 = _idx_3+1;
	}

}


for (k = 0; k < _samplingIterates; k = k + 1)
{
	DataSet	 			_sampledSequences = SampleAncestors (_lf_ID);
	DataSetFilter		_sampledFilter	  = CreateFilter (_sampledSequences,1);
	_idx_3 								  = 0;
	
	GetDataInfo (_sampledFilterSiteToPatternMap, _sampledFilter);
	for (_idx_1 = 0; _idx_1 < _sampledFilter.species; _idx_1 = _idx_1 + 1)
	{
		for (_idx_2 = 0; _idx_2 < _sampledFilter.sites; _idx_2 = _idx_2 + 1)
		{
			GetDataInfo 			 	  (_charInfo, _sampledFilter, _idx_1, _sampledFilterSiteToPatternMap[_idx_2]);
			_sampledInformation[_idx_3] = _sampledInformation[_idx_3]+_charInfo;
			_idx_3 = _idx_3+1;
		}
	}
}

DataSet	 		_marginalAncestors 			= ReconstructAncestors (_lf_ID,MARGINAL);
DataSetFilter	_marginalAncestorsFilter	= CreateFilter 		   (_marginalAncestors, 1);
GetDataInfo 	(_marginalFilterSiteToPatternMap, filteredData);

_idx_3 = 0;
for (_idx_1 = 0; _idx_1 < _marginalAncestorsFilter.species; _idx_1 = _idx_1 + 1)
{
	for (_idx_2 = 0; _idx_2 < _marginalAncestorsFilter.sites; _idx_2 = _idx_2 + 1)
	{
		_patternIndex 				 = _marginalFilterSiteToPatternMap[_idx_2];
		_marginalInformation[_idx_3] = _marginalAncestors.marginal_support_matrix[{{_idx_1,_patternIndex*_characterDimension}}][{{_idx_1,(1+_patternIndex)*_characterDimension-1}}];
		_idx_3 						 = _idx_3+1;
	}

}

_outputCSV = ""; _outputCSV * 2048; 
_outputCSV * "Sequence,Site,ML Joint";
for (_idx_1 = 0; _idx_1 < _characterDimension; _idx_1 = _idx_1 + 1)
{
	_outputCSV * (",Sampled "+ _AncestalFilterChars[_idx_1]);
}
for (_idx_1 = 0; _idx_1 < _characterDimension; _idx_1 = _idx_1 + 1)
{
	_outputCSV * (",Marginal "+ _AncestalFilterChars[_idx_1]);
}

_idx_3 = 0;
for (_idx_1 = 0; _idx_1 < 1; _idx_1 = _idx_1 + 1)
{
	for (_idx_2 = 0; _idx_2 < _marginalAncestorsFilter.sites; _idx_2 = _idx_2 + 1)
	{
		_outputCSV * ("\n" + _AncestralNodeNames[_idx_1] + "," + (1+_idx_2) + "," + _AncestalFilterChars[_mlInformation[_idx_3]]);
		
		_maxValue = 0;
		_maxIndex = 0;
		
		for (_idx_4 = 0; _idx_4 < _characterDimension; _idx_4 = _idx_4 + 1)
		{
			_thisCharacter = (_sampledInformation[_idx_3])[_idx_4]/_samplingIterates;
			_outputCSV * ("," + _thisCharacter);
			if (_thisCharacter > _maxValue)
			{
				_maxValue = _thisCharacter;
				_maxIndex = _idx_4;
			}
		}
		_maxIndexSampled = _maxIndex;

		_maxValue = 0;
		_maxIndex = 0;

		for (_idx_4 = 0; _idx_4 < _characterDimension; _idx_4 = _idx_4 + 1)
		{
			_thisCharacter = (_marginalInformation[_idx_3])[_idx_4];
			_outputCSV * ("," + _thisCharacter);
			if (_thisCharacter > _maxValue)
			{
				_maxValue = _thisCharacter;
				_maxIndex = _idx_4;
			}
		}
		_maxIndexMarginal = _maxIndex;
		/*if (_mlInformation[_idx_3] != _maxIndexMarginal || _maxIndexMarginal != _maxIndexSampled || _maxIndexSampled != _mlInformation[_idx_3])
		{
			fprintf (stdout, _idx_1, ":", _idx_2+1, " is discrepant\n");
		}*/
		_idx_3 = _idx_3 + 1;
		
	}
}

_outputCSV * 0;
fprintf (stdout, _outputCSV);