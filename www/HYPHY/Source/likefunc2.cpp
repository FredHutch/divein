/*

HyPhy - Hypothesis Testing Using Phylogenies.

Copyright (C) 1997-2008  
Primary Development:
  Sergei L Kosakovsky Pond (sergeilkp@mac.com)
Significant contributions from:
  Spencer V Muse (muse@stat.ncsu.edu)
  Simon DW Frost (sdfrost@ucsd.edu)
  Art FY Poon    (apoon@biomail.ucsd.edu)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

#include "likefunc.h"
#include <math.h>

#ifdef 	  __HYPHYDMALLOC__
#include "dmalloc.h"
#endif

#ifdef	_SLKP_LFENGINE_REWRITE_

_String _hyMarginalSupportMatrix ("marginal_support_matrix"); 

/*--------------------------------------------------------------------------------------------------*/

void	_LikelihoodFunction::DetermineLocalUpdatePolicy (void)
{
	for (long k = 0; k < theTrees.lLength; k ++)
	{
		long catCount = ((_TheTree*)LocateVar(theTrees(k)))->categoryCount;
		_List * lup = new _List,
			  * mte = new _List;
		
		computedLocalUpdatePolicy.AppendNewInstance (new _SimpleList (catCount,0,0));
		for (long l = 0; l < catCount; l++)
		{
			lup->AppendNewInstance (new _SimpleList);
			mte->AppendNewInstance (new _List);
		}
			
		localUpdatePolicy.AppendNewInstance		 (lup);
		matricesToExponentiate.AppendNewInstance (mte);
	}
}

/*--------------------------------------------------------------------------------------------------*/

void	_LikelihoodFunction::FlushLocalUpdatePolicy (void)
{
	computedLocalUpdatePolicy.Clear();
	localUpdatePolicy.Clear();
	matricesToExponentiate.Clear();
}

//_______________________________________________________________________________________
void			_LikelihoodFunction::PartitionCatVars	  (_SimpleList& storage, long partIndex)
{
	if (partIndex < blockDependancies.lLength)
	{
		for (long bit = 0; bit < 32; bit++)
			if (CheckNthBit(blockDependancies.lData[partIndex], bit))
				storage << indexCat.lData[bit];
	}
}

//_______________________________________________________________________________________
long			_LikelihoodFunction::TotalRateClassesForAPartition	  (long partIndex)
{
	if (partIndex >= 0 && partIndex < categoryTraversalTemplate.lLength)
	{
		_List* myList = (_List*)categoryTraversalTemplate(partIndex);
		if (myList->lLength)
			return ((_SimpleList*)((*myList)(1)))->Element(-1);
	}
	else
		if (partIndex < 0)
		{
			long catCount = 1;
			for (long k = 0; k < indexCat.lLength; k++)
				catCount *= ((_CategoryVariable*)LocateVar (indexCat.lData[k]))->GetNumberOfIntervals();
			return catCount;
		}
	return 1;
}

//_______________________________________________________________________________________
void			_LikelihoodFunction::SetupCategoryCaches	  (void)
{
	categoryTraversalTemplate.Clear();
	for (long partIndex = 0; partIndex < theDataFilters.lLength; partIndex++)
		if (blockDependancies.lData[partIndex] == 0)
		{
			_List * noCatVarList = new _List;
			noCatVarList->AppendNewInstance (new _List);
			noCatVarList->AppendNewInstance (new _SimpleList((long)1));
			noCatVarList->AppendNewInstance (new _SimpleList((long)1));
			categoryTraversalTemplate.AppendNewInstance (noCatVarList);
		}
		else
		{
			_SimpleList		  myCats;
			PartitionCatVars  (myCats, partIndex);
			_List*			  catVarReferences = new _List,
				 *			  container		   = new _List;
			
			_SimpleList*	  catVarCounts	   = new _SimpleList,
						*	  catVarOffsets	   = new _SimpleList (myCats.lLength,1,0);
			
			long			  totalCatCount	   = 1;
			for (long varIndex = 0; varIndex < myCats.lLength; varIndex++)
			{
				_CategoryVariable * aCV = (_CategoryVariable *)LocateVar (myCats.lData[varIndex]);
				(*catVarReferences) << aCV;
				long				intervalCount = aCV->GetNumberOfIntervals();
				(*catVarCounts)		<< intervalCount;
				totalCatCount		*= intervalCount;
			}
			(*catVarCounts) << totalCatCount;
			
			for (long varIndex = myCats.lLength-2; varIndex >= 0; varIndex--)
				catVarOffsets->lData[varIndex] *= catVarCounts->lData[varIndex+1];
			
			container->AppendNewInstance (catVarReferences);
			container->AppendNewInstance (catVarCounts);
			container->AppendNewInstance (catVarOffsets);

			((_TheTree*)LocateVar(theTrees(partIndex)))->SetupCategoryMapsForNodes(*catVarReferences,*catVarCounts,*catVarOffsets);
			
			categoryTraversalTemplate.AppendNewInstance(container);
		}
	
	if (indexCat.lLength)
	{
		if (siteResults)
			DeleteObject (siteResults);
		AllocateSiteResults();
	}
}

/*--------------------------------------------------------------------------------------------------*/

void	_LikelihoodFunction::RestoreScalingFactors (long index, long branchID, long patternCnt, long* scc, long *sccb)
{	
	if (branchID >= 0) // finished using an existing cache
	{
		overallScalingFactors[index] = overallScalingFactorsBackup[index];
		if (sccb)
			for (long recoverIndex = 0; recoverIndex < patternCnt; recoverIndex++)
				scc[recoverIndex] = sccb[recoverIndex];
	}	
}

/*--------------------------------------------------------------------------------------------------*/

bool	_LikelihoodFunction::ProcessPartitionList (_SimpleList& partsToDo, _Matrix* partitionList, _String caller)
{	
	long	partCount = CountObjects(0);
	partsToDo.Populate (partCount, 0, 1);
	if (partitionList)
	{
		partitionList->ConvertToSimpleList (partsToDo);
		DeleteObject (partitionList);
		partsToDo.Sort();
		partsToDo.FilterRange (-1, partCount);
		if (partsToDo.lLength == 0)
		{
			WarnError (_String("An invalid partition specification in call to ") & caller);
			return nil;
		}
	}

	return true;
}


//_______________________________________________________________________________________

void	_LikelihoodFunction::ReconstructAncestors (_DataSet &target,_SimpleList& doTheseOnes, _String& baseResultID,  bool sample, bool doMarginal)
/*
	Reconstruct ancestors for a likelihood function using 
 
-- target      :	the _DataSet object that will receive the results
-- doTheseOnes :	a _sorted_ array of partition indices to include in this operation; is assumed to contain valid indices (i.e. 0 -- number of partitions - 1)
-- baseResultID:	the HBL identifier of the dataset that will receive the result; used as a prefix for .marginal_support_matrix support matrix (when doMarginal = true)
-- sample	   :	if true, an ancestral sample (weighted by likelihood) is drawn, otherwise an ML (or maginal) reconstruction is carried out
-- doMarginal  :	if sample == false, doMarginal determines how the ancestors are reconstructed; if true, the reconstruction is marginal (maximizes
					the likelihood of each node while summing over the rest), otherwise it is joint.
 
*/
{
	_DataSetFilter *dsf				= (_DataSetFilter*)dataSetFilterList (theDataFilters(doTheseOnes.lData[0]));	
	_TheTree    	*firstTree		= (_TheTree*)LocateVar(theTrees(doTheseOnes.lData[0]));
	
	target.SetTranslationTable		(dsf->GetData());	
	target.ConvertRepresentations(); 
	
	computationalResults.ZeroUsed();
	PrepareToCompute();
		
	// check if we need to deal with rate variation
	_Matrix			*rateAssignments = nil;
	if  (!doMarginal && indexCat.lLength>0)
		rateAssignments = (_Matrix*)checkPointer(ConstructCategoryMatrix(doTheseOnes,_hyphyLFConstructCategoryMatrixConditionals,false));
	else
		Compute(); // need to do this to populate rate matrices
	
	long siteOffset			= 0,
		 patternOffset		= 0,
		 sequenceCount		;
	
	for (long i = 0; i<doTheseOnes.lLength; i++)
	{
		long	   partIndex    = doTheseOnes.lData[i];
		_TheTree   *tree		= (_TheTree*)LocateVar(theTrees(partIndex));
		dsf = (_DataSetFilter*)dataSetFilterList (theDataFilters(partIndex));
		
		long    catCounter = 0;
		
		if (rateAssignments)
		{
			_SimpleList				pcats;
			PartitionCatVars		(pcats,partIndex);
			catCounter			  = pcats.lLength;
		}
		
		if (i==0)
		{
			tree->AddNodeNamesToDS (&target,false,true,false); // store internal node names in the dataset
			sequenceCount = target.GetNames().lLength;
		}
		else
		{
			if (!tree->Equal(firstTree)) // incompatible likelihood function
			{
				ReportWarning ((_String("Ancestor reconstruction had to ignore partition ")&_String(partIndex+1)&" of the likelihood function since it has a different tree topology than the first part."));
				continue;
			}
			_TranslationTable * mtt = target.GetTT()->MergeTables(dsf->GetData()->GetTT());
			if (mtt)
			{
				target.SetTranslationTable		(mtt);	
				DeleteObject					(mtt);
			}
			else
			{
				ReportWarning ((_String("Ancestor reconstruction had to ignore partition ")&_String(partIndex+1)&" of the likelihood function since it has a character alphabet incompatible with the first part."));
				continue;
			}
		}
		
		_List		* expandedMap	= dsf->ComputePatternToSiteMap(),
					* thisSet;
		
		if (sample)
		{
			_AVLListX   * nodeMapper	= tree->ConstructNodeToIndexMap(true);
			thisSet						= new _List;
			_SimpleList* tcc			= (_SimpleList*)treeTraversalMasks(partIndex);
			if (tcc)
			{
				long shifter = dsf->GetDimension()*dsf->NumberDistinctSites()*tree->GetINodeCount();
				for (long cc = 0; cc <= catCounter; cc++)
					tree->FillInConditionals(dsf, conditionalInternalNodeLikelihoodCaches[partIndex] + cc*shifter, tcc);
			}
			tree->SampleAncestorsBySequence (dsf, *(_SimpleList*)optimalOrders.lData[partIndex], 
												 &tree->GetRoot(), 
											     nodeMapper, 
											     conditionalInternalNodeLikelihoodCaches[partIndex],
												 *thisSet, 
											     nil,
											     *expandedMap,  
											     catCounter?rateAssignments->theData+siteOffset:nil, 
											     catCounter);
			
			
			nodeMapper->DeleteAll(false);DeleteObject (nodeMapper);
			
		}
		else
		{
			if (doMarginal)
			{
				_Matrix  *marginals = new _Matrix;
				_String  supportMxID = baseResultID & '.' & _hyMarginalSupportMatrix;
				thisSet = RecoverAncestralSequencesMarginal (partIndex, *marginals, *expandedMap);
				CheckReceptacleAndStore(&supportMxID, "ReconstructAncestors", true, marginals, false);
				
			}
			else
				thisSet = tree->RecoverAncestralSequences (dsf, 
															*(_SimpleList*)optimalOrders.lData[partIndex],
															*expandedMap,
															conditionalInternalNodeLikelihoodCaches[partIndex],
															catCounter?rateAssignments->theData+siteOffset:nil, 
															catCounter,
															conditionalTerminalNodeStateFlag[partIndex],
															(_GrowingVector*)conditionalTerminalNodeLikelihoodCaches(partIndex)
															);
																												
		}
		
		
		_String * sampledString = (_String*)(*thisSet)(0);
		
		for (long siteIdx = 0; siteIdx<sampledString->sLength; siteIdx++)
			target.AddSite (sampledString->sData[siteIdx]);
		
		for (long seqIdx = 1;seqIdx < sequenceCount; seqIdx++)
		{
			sampledString = (_String*)(*thisSet)(seqIdx);
			for (long siteIdx = 0;siteIdx<sampledString->sLength; siteIdx++)
				target.Write2Site (siteOffset + siteIdx, sampledString->sData[siteIdx]);
		}
		DeleteObject (thisSet);
		DeleteObject (expandedMap);
		siteOffset	  += dsf->GetSiteCount();
		patternOffset += dsf->GetSiteCount();
	}
	
		
	target.Finalize();
	target.SetNoSpecies(target.GetNames().lLength);
	
	if (rateAssignments)
		DeleteObject (rateAssignments);
	
	DoneComputing ();
	
}

//_______________________________________________________________________________________________

void			_LikelihoodFunction::PopulateConditionalProbabilities	(long index, char runMode, _Parameter* buffer, _SimpleList& scalers, long branchIndex, _SimpleList* branchValues)
// this function computes site probabilties for each rate class (or something else that involves iterating over rate classes)
// see run options below

// run mode can be one of the following
// _hyphyLFConditionProbsRawMatrixMode : simply   populate an M (number of rate classes) x S (number of site patterns) matrix of conditional likelihoods
//   : expected minimum dimension of buffer is M*S
//	 : scalers will have M*S entries laid out as S for rate class 0, S for rate class 1, .... S for rate class M-1
// _hyphyLFConditionProbsScaledMatrixMode : simply   populate an M (number of rate classes) x S (number of site patterns) and scale to the lowest multiplier
//   : expected minimum dimension of buffer is M*S
//	 : scalers will have S entries
// _hyphyLFConditionProbsWeightedSum : compute  a sum for each site using weighted by the probability of a given category
//   : expected minimum dimension of buffer is 2*S
//	 : scalers will have S entries
// _hyphyLFConditionProbsMaxProbClass : compute the category index of maximum probability  
//   : expected minimum dimension of buffer is 3*S -- the result goes into offset 0
//	 : scalers will have S entries 
// _hyphyLFConditionProbsClassWeights : compute the weight of each rate class index 
//   : expected minimum dimension of buffer is M
//	 : scalers will have no entries
{
	_List				*traversalPattern		= (_List*)categoryTraversalTemplate(index),
						*variables			    = (_List*)((*traversalPattern)(0)),
						*catWeigths				= nil;

	_SimpleList			*categoryCounts			= (_SimpleList*)((*traversalPattern)(1)),
						*categoryOffsets		= (_SimpleList*)((*traversalPattern)(2)),
						categoryValues			(categoryCounts->lLength,0,0);
	
	long				totalSteps				= categoryOffsets->lData[0] * categoryCounts->lData[0],
						catCount				= variables->lLength-1,
						blockLength				= BlockLength(index),
						arrayDim				;
	
	bool				isTrivial				= variables->lLength == 0;
	
	_CategoryVariable   *catVariable;
	
	
	switch (runMode)
	{
		case _hyphyLFConditionProbsRawMatrixMode:
			arrayDim = catCount*blockLength;
			break;
		case _hyphyLFConditionProbsClassWeights:
			arrayDim = 0;
			break;
		default:
			arrayDim = blockLength;
	}
	
	
	if (runMode == _hyphyLFConditionProbsWeightedSum || runMode == _hyphyLFConditionProbsClassWeights)
	{
		if (runMode == _hyphyLFConditionProbsWeightedSum)
			for (long r = 0; r < blockLength; r++)
				buffer[r] = 0.;
	
		catWeigths = new _List;
	}
	else
		if (runMode == _hyphyLFConditionProbsMaxProbClass)
			for (long r = 0, r2 = 2*blockLength; r < blockLength; r++, r2++)
			{
				buffer[r] = 0.0; buffer[r2] = 0.0;
			}
	
	for					(long currentCat		= 0; currentCat <= catCount; currentCat++)
	{
		(catVariable = ((_CategoryVariable**)(variables->lData))[currentCat])->Refresh();
		catVariable->SetIntervalValue(0,true);
		if (runMode == _hyphyLFConditionProbsWeightedSum || runMode == _hyphyLFConditionProbsClassWeights)
			(*catWeigths) << catVariable->GetWeights();
	}
	
		
	scalers.Populate	(arrayDim,0,0);

	for					(long currentRateCombo  = 0; currentRateCombo < totalSteps; currentRateCombo++)
	{

		// the next clause takes care of advancing the class count and 
		// setting each category variable to its appropriate value 
		
		if (!isTrivial)
		{
			long remainder = currentRateCombo % categoryCounts->lData[catCount];
			if (currentRateCombo && remainder  == 0)
			{
				categoryValues.lData[catCount] = 0;
				(((_CategoryVariable**)(variables->lData))[catCount])->SetIntervalValue(0);
				for (long uptick = catCount-1; uptick >= 0; uptick --)
				{
					categoryValues.lData[uptick]++;
					if (categoryValues.lData[uptick] == categoryCounts->lData[uptick])
					{
						categoryValues.lData[uptick] = 0;
						(((_CategoryVariable**)(variables->lData))[uptick])->SetIntervalValue(0);
					}
					else
					{
						(((_CategoryVariable**)(variables->lData))[uptick])->SetIntervalValue(categoryValues.lData[uptick]);
						break;
					}
				}
			}
			else
			{
				if (currentRateCombo)
				{
					categoryValues.lData[catCount]++;
					(((_CategoryVariable**)(variables->lData))[catCount])->SetIntervalValue(remainder);
				}
			}
		}
		
		_Parameter		 currentRateWeight = 1.;
		if (runMode == _hyphyLFConditionProbsWeightedSum || runMode == _hyphyLFConditionProbsClassWeights)
		{
			for					(long currentCat		= 0; currentCat <= catCount; currentCat++)
				currentRateWeight *= ((_Matrix**)catWeigths->lData)[currentCat]->theData[categoryValues.lData[currentCat]];
			if (runMode == _hyphyLFConditionProbsClassWeights)
			{
				buffer [currentRateCombo] = currentRateWeight;
				continue;
			}
			else
				if (currentRateWeight == 0.0) // nothing to do, eh?
					continue;
		}
		
	
		// now that the categories are set we can proceed with the computing step
		long			 indexShifter					= blockLength * currentRateCombo;
		long			 *siteCorrectors				= ((_SimpleList**)siteCorrections.lData)[index]->lLength?
														 (((_SimpleList**)siteCorrections.lData)[index]->lData) + indexShifter
														 :nil;
		
		if (runMode == _hyphyLFConditionProbsRawMatrixMode || runMode == _hyphyLFConditionProbsScaledMatrixMode) 
			// populate the matrix of conditionals and scaling factors
		{
			_Parameter	_hprestrict_ *bufferForThisCategory = buffer + indexShifter;

			ComputeBlock	(index, bufferForThisCategory, currentRateCombo, branchIndex, branchValues);
			
			if (runMode == _hyphyLFConditionProbsRawMatrixMode)
				for (long p = 0; p < blockLength; p++)
					scalers.lData[p+indexShifter] = siteCorrectors[p];
			else
			{
				if (siteCorrectors)
				{
					for (long r1 = 0; r1 < blockLength; r1++)
					{
						long scv			  = *siteCorrectors,
							 scalerDifference = scv-scalers.lData[r1];
						
						if (scalerDifference > 0) 
						// this class has a _bigger_ scaling factor than at least one other class
						// hence it needs to be scaled down (unless it's the first class)
						{
							if (currentRateCombo==0) //(scalers.lData[r1] == -1)
								scalers.lData[r1] = scv;
							else
								bufferForThisCategory[r1] *= acquireScalerMultiplier (scalerDifference);
						}
						else
						{
							if (scalerDifference < 0) 
							// this class is a smaller scaling factor, i.e. its the biggest among all those
							// considered so far; all other classes need to be scaled down
							{							
								_Parameter scaled = acquireScalerMultiplier (-scalerDifference);
								for (long z = indexShifter+r1-blockLength; z >= 0; z-=blockLength)
									buffer[z] *= scaled;
								
								scalers.lData[r1] = scv;
							}
						}
						siteCorrectors++;
					}
				}
			}
		} 
		else
		{
			if (runMode == _hyphyLFConditionProbsWeightedSum || runMode == _hyphyLFConditionProbsMaxProbClass) 
			{
				//if (branchIndex>=0)
				//	((_TheTree*)LocateVar(theTrees.lData[index]))->AddBranchToForcedRecomputeList (branchIndex+((_TheTree*)LocateVar(theTrees.lData[index]))->GetLeafCount());
				ComputeBlock	(index, buffer + blockLength, currentRateCombo, branchIndex, branchValues);

				if (runMode == _hyphyLFConditionProbsWeightedSum)
					for (long r1 = 0, r2 = blockLength; r1 < blockLength; r1++,r2++)
					{
						if (siteCorrectors)
						{
							long scv = *siteCorrectors;
							
							if (scv < scalers.lData[r1]) // this class has a _smaller_ scaling factor
							{
								buffer[r1] = currentRateWeight * buffer[r2] + buffer[r1] * acquireScalerMultiplier (scalers.lData[r1] - scv);
								scalers.lData[r1] = scv;
							}
							else
							{
								if (scv > scalers.lData[r1]) // this is a _larger_ scaling factor
									buffer[r1] += currentRateWeight * buffer[r2] * acquireScalerMultiplier (scv - scalers.lData[r1]);							
								else // same scaling factors
									buffer[r1] += currentRateWeight * buffer[r2];
							}
							
							siteCorrectors++;
						}
						else
							buffer[r1] += currentRateWeight * buffer[r2];
						
					}				
				else // runMode = _hyphyLFConditionProbsMaxProbClass
				{
					for (long r1 = blockLength*2, r2 = blockLength, r3 = 0; r3 < blockLength; r1++,r2++,r3++)
					{
						bool doChange = false;
						if (siteCorrectors)
						{
							long scv  = *siteCorrectors,
								 diff = scv - scalers.lData[r3];
							
							if (diff<0) // this has a _smaller_ scaling factor
							{
								_Parameter scaled = buffer[r1]*acquireScalerMultiplier (diff);
								if (buffer[r2] > scaled)
									doChange = true;
								else
									buffer[r1] = scaled;
								scalers.lData[r3] = scv;
							}
							else
							{
								if (diff>0) // this is a _larger_ scaling factor
									buffer[r2] *= acquireScalerMultiplier (-diff);		
								doChange = buffer[r2] > buffer[r1] && ! CheckEqual (buffer[r2],buffer[r1]);
							}
							
							siteCorrectors++;
						}
						else
							doChange = buffer[r2] > buffer[r1] && ! CheckEqual (buffer[r2],buffer[r1]);
						
						if (doChange)
						{
							buffer[r1]		   = buffer[r2];
							buffer[r3]         = currentRateCombo;
						}
					}						
				}
			}
		}
	}
	DeleteObject (catWeigths);
}

//_______________________________________________________________________________________________

void			_LikelihoodFunction::ComputeSiteLikelihoodsForABlock	(long index, _Parameter* results, _SimpleList& scalers, long branchIndex, _SimpleList* branchValues)
// assumes that results is at least blockLength slots long
{
	if (blockDependancies.lData[index])
		PopulateConditionalProbabilities(index, _hyphyLFConditionProbsWeightedSum, results, scalers, branchIndex, branchValues);	
	else
	{
		ComputeBlock		(index, results, -1, branchIndex, branchValues);
		scalers.Clear		();
		scalers.Duplicate   (siteCorrections(index));
	}
}

//_______________________________________________________________________________________________

_List*	 _LikelihoodFunction::RecoverAncestralSequencesMarginal (long index, _Matrix & supportValues, _List& expandedSiteMap) 
// index:			which part to process
// supportValues:	for each internal node and site stores alphabetDimension values for the 
//				:	relative support of each residue at a given site
//				:   linearized 3D matrix
//				:   1st - node index (same order as flatTree)
//				:   2nd - site index (only unique patterns are stored)
//				:   3rd - the character

{	
	
	_DataSetFilter* dsf				= (_DataSetFilter*)dataSetFilterList (theDataFilters(index));
	_TheTree		*blockTree		= (_TheTree*)LocateVar(theTrees.lData[index]);
					 
	long			patternCount					= dsf->NumberDistinctSites	(),
					alphabetDimension				= dsf->GetDimension			(),
					unitLength						= dsf->GetUnitLength		(),
					iNodeCount						= blockTree->GetINodeCount	(),
					leafCount						= blockTree->GetLeafCount   (),
					siteCount						= dsf->GetSiteCount			(),
					shiftForTheNode					= patternCount * alphabetDimension;
	
	_Parameter		*siteLikelihoods				= new _Parameter [2*patternCount],
					*siteLikelihoodsSpecState		= new _Parameter [2*patternCount];
	
	_SimpleList		scalersBaseline, 
					scalersSpecState,
					branchValues,
					postToIn;
	
	blockTree->MapPostOrderToInOderTraversal (postToIn);
	supportValues.Clear				();
	CreateMatrix					(&supportValues,iNodeCount,shiftForTheNode,false,true,false);
	
	ComputeSiteLikelihoodsForABlock	   (index, siteLikelihoods, scalersBaseline); // establish a baseline likelihood for each site
		
	for								(long currentChar = 0; currentChar < alphabetDimension-1; currentChar++)
	// the prob for the last char is  (1 - sum (probs other chars))
	{
		branchValues.Populate			(patternCount,currentChar,0);
		for (long branchID = 0; branchID < iNodeCount; branchID ++)
		{
			long mappedBranchID = postToIn.lData[branchID];
			ComputeSiteLikelihoodsForABlock (index, siteLikelihoodsSpecState, scalersSpecState, branchID, &branchValues);
			for (long siteID = 0; siteID < patternCount; siteID++)
			{
				long scaleDiff = (scalersSpecState.lData[siteID]-scalersBaseline.lData[siteID]);
				_Parameter ratio = siteLikelihoodsSpecState[siteID]/siteLikelihoods[siteID];
				if (scaleDiff > 0)
					ratio *= acquireScalerMultiplier(scaleDiff);
				supportValues.theData[mappedBranchID*shiftForTheNode + siteID*alphabetDimension + currentChar] = ratio;
			}
			blockTree->AddBranchToForcedRecomputeList (branchID+leafCount);
		}			
	}
	
	_SimpleList  conversion;
	_AVLListXL	 conversionAVL (&conversion);
	_String		 codeBuffer    (unitLength, false);
	_List	     *result	   = new _List;
	
	for (long k = 0; k < iNodeCount; k++)
		result->AppendNewInstance (new _String(siteCount*unitLength,false));
	
	for (long siteID = 0; siteID < patternCount; siteID++)
	{
		_SimpleList*	patternMap = (_SimpleList*) expandedSiteMap (siteID);
				
		for  (long nodeID = 0; nodeID < iNodeCount ; nodeID++)
		{
			long			mappedNodeID = postToIn.lData[nodeID];
			_Parameter		max_lik     = 0.,	
							sum			= 0.,
							*scores		= supportValues.theData + shiftForTheNode*mappedNodeID +  siteID*alphabetDimension;
			long			max_idx     = 0;

			for (long charID = 0; charID < alphabetDimension-1; charID ++)
			{
				sum+=scores[charID];
				if (scores[charID] > max_lik)
				{
					max_idx = charID; max_lik = scores[charID];
				}
			}
			
				   
			//if (fabs(scores[alphabetDimension-1]+sum-1.) > 0.1)
			//	WarnError (_String("Bad monkey!") & scores[alphabetDimension-1] & ":" & (1.-sum) );
			
			scores[alphabetDimension-1] = 1. - sum;

			if (scores[alphabetDimension-1] > max_lik)
				max_idx = alphabetDimension-1; 
						
			dsf->ConvertCodeToLettersBuffered (dsf->CorrectCode(max_idx), unitLength, codeBuffer.sData, &conversionAVL);
			_String  *sequence   = (_String*) (*result)(mappedNodeID);
			
			for (long site = 0; site < patternMap->lLength; site++)
			{
				char* storeHere = sequence->sData + patternMap->lData[site]*unitLength;
				for (long charS = 0; charS < unitLength; charS ++)
					storeHere[charS] = codeBuffer.sData[charS];
			}
			
		}
	}
	delete siteLikelihoods; 
	delete siteLikelihoodsSpecState;
	return result;
}

//_______________________________________________________________________________________________

_Parameter _LikelihoodFunction::SumUpSiteLikelihoods (long index, const _Parameter * patternLikelihoods, const _SimpleList& patternScalers) 
/* 
 compute the likelihood of a partition (index), corrected for scaling, 
 by summing pattern likelihoods from patternLikelihoods, weighted by pattern frequencies
 and corrected for scaling factors from patternScalers
*/
{
	_SimpleList		* patternFrequencies = &((_DataSetFilter*)dataSetFilterList (theDataFilters(index)))->theFrequencies;
	
	_Parameter		 logL			  = 0.;
	long			 cumulativeScaler = 0;
	
	for				 (long patternID = 0; patternID < patternFrequencies->lLength; patternID++)
	{
		long patternFrequency = patternFrequencies->lData[patternID];
		if (patternFrequency > 1)
		{
			logL			 += myLog(patternLikelihoods[patternID])*patternFrequency;
			cumulativeScaler += patternScalers.lData[patternID]*patternFrequency;
		}
		else
		// all this to avoid a double*long multiplication
		{
			logL			 += myLog(patternLikelihoods[patternID]);
			cumulativeScaler += patternScalers.lData[patternID];			
		}
	}
	
	return logL - cumulativeScaler * _logLFScaler;
		
}

//_______________________________________________________________________________________________

void _LikelihoodFunction::UpdateBlockResult (long index, _Parameter new_value) 
{
	if (computationalResults.GetUsed()>index)
		computationalResults.theData[index] = new_value;
	else
		computationalResults.Store(new_value);
}

#endif