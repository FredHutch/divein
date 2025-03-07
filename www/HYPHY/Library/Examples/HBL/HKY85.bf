DataSet 					nucleotideSequences = ReadDataFile ("data/hiv.nuc");DataSetFilter				filteredData = CreateFilter (nucleotideSequences,1);HarvestFrequencies 			(observedFreqs, filteredData, 1, 1, 1);global R = 1;HKY85RateMatrix = 		{{*,trvs,R*trvs,trvs}		 {trvs,*,trvs,R*trvs}		 {R*trvs,trvs,*,trvs}		 {trvs,R*trvs,trvs,*}};Model 	HKY85 = (HKY85RateMatrix, observedFreqs);Tree	givenTree = DATAFILE_TREE;LikelihoodFunction  theLnLik = (filteredData, givenTree);Optimize (paramValues, theLnLik);function _THyPhyAskFor (key){	if (key == "LogL")	{		return paramValues[1][0];	}	if (key == "kappa")	{		return R;	}	if (key == "Tree")	{		return Format(givenTree,1,1);	}	if (key == "Branch lengths")	{		return BranchLength (givenTree,-1);	}	return "_THyPhy_NOT_HANDLED_";}