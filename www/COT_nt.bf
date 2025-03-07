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
options ["1"] = "Global w/variation";
options ["2"] = "Beta-Gamma";
options ["3"] = "4";

ExecuteAFile 		("/var/www/html/HYPHY/TemplateBatchFiles/TemplateModels/GRM.mdl",options);

ExecuteAFile 		("/var/www/html/HYPHY/TemplateBatchFiles/queryTree.bf");

VERBOSITY_LEVEL 	   = -1;
LikelihoodFunction  lf = (filteredData, givenTree);
Optimize (res,lf);

treeString = Format (givenTree,1,1);
UseModel (USE_NO_MODEL);
Tree test = treeString;

cot_data = ComputeCOT ("test","");
fprintf (stdout, cot_data);

UseModel (GRMModel);
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

LikelihoodFunction cot_lf = (filteredData, cot_tree);
DataSet ds_a = ReconstructAncestors (cot_lf);
SetParameter (ds_a,0,"COT");
DataSetFilter dsf_a = CreateFilter (ds_a,1,"","0"); /* COT is at the root; first sequence in the
													   file */
											   
fprintf (stdout, dsf_a);