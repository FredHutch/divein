DataSet 			ds 	= ReadDataFile (PROMPT_FOR_FILE);

DataSetFilter		filteredData	 = CreateFilter (ds,1);

/* use the rev model with beta-gamma rate variation (4 bins) via a standard file include with piped option */
options = {};
options ["1"] = "/var/www/html/HYPHY/TemplateBatchFiles/TemplateModels/EmpiricalAA/LG";
options ["2"] = "Estimated";
options ["3"] = "Rate variation";
options ["4"] = "General Discrete";
options ["5"] = "4";

/*ExecuteAFile 		("/data/home/wdeng/HYPHY/hyphy/HYPHY/TemplateBatchFiles/TemplateModels/Custom_AA_empirical.mdl", options);*/
ExecuteAFile 		("/var/www/html/HYPHY/TemplateBatchFiles/TemplateModels/Custom_AA_empirical.mdl", options);
Tree theTree 		  = DATAFILE_TREE;
LikelihoodFunction lf = (filteredData, theTree);
Optimize (res,lf);

DataSet ancDS 		    = ReconstructAncestors(lf);
DATA_FILE_PRINT_FORMAT  = 0;
DATA_FILE_DEFAULT_WIDTH = 100000;
DataSetFilter 		  ancF = CreateFilter (ancDS,1);

DATAFILE_TREE		   = Format (theTree,1,1);
fprintf (stdout, "\n\n", ancF);