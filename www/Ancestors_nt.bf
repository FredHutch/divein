/* define the models you want to implement */
modelChoices = {{"JC69","Jukes Cantor 1969"}
			    {"HKY85","Hasegawa Kishino Yano 1985"}
			    {"GTR","General Time Reversible"}
			    {"F81",""}
			    {"K80",""}
			    {"TN93",""}};
			    
/* define the constraints needed to implement each respective model 
   from GTR */
  
modelConstraints = 	{{"AC:=1;AT:=1;CG:=1;CT:=1;GT:=1;freqs={{0.25}{0.25}{0.25}{0.25}};", /* JC69 */
					  "CT:=1;AT:=AC;CG:=AC;GT:=AC", /* HKY85 */
					  "", /* GTR */
					  "AC:=1;AT:=1;CG:=1;CT:=1;GT:=1", /* F81 */
					  "CT:=1;AT:=AC;CG:=AC;GT:=AC;freqs={{0.25}{0.25}{0.25}{0.25}};", /* K80 */
					  "AT:=AC;CG:=AC;GT:=AC" /* TN93 */
					}};
			   

fscanf 					  (stdin,"String",nexusInFile);
DataSet 			ds 	= ReadDataFile (nexusInFile);
DataSetFilter 		dsf	= CreateFilter (ds,1);


sd = Log(dsf.unique_sites)/Log(10)$1+1;

if (ds.species < 5)
{
	msd = 3;
}
else
{
	if (ds.species < 10)
	{
		msd = 4;
	}
	else
	{
		if (ds.species < 50)
		{
			msd = 5;
		}
		else
		{
			msd = 6;
		}
	}
}

resp = Max(2,Min (msd, sd));

global betaP = 1;
global betaQ = 1;
betaP:>0.05;betaP:<85;
betaQ:>0.05;betaQ:<85;

category pc = (resp-1, EQUAL, MEAN, 
				_x_^(betaP-1)*(1-_x_)^(betaQ-1)/Beta(betaP,betaQ), /* density */
				IBeta(_x_,betaP,betaQ), /*CDF*/
				0, 				   /*left bound*/
				1, 			   /*right bound*/
				IBeta(_x_,betaP+1,betaQ)*betaP/(betaP+betaQ)
			   );


global alpha = .5;
alpha:>0.01;alpha:<100;
category c = (resp, pc, MEAN, 
				GammaDist(_x_,alpha,alpha), 
				CGammaDist(_x_,alpha,alpha), 
				0 , 
		  	    1e25,
		  	    CGammaDist(_x_,alpha+1,alpha)
		  	 );

global 		AC = 1;
global 		AT = 1;
global 		CG = 1;
global 		CT = 1;
global 		GT = 1;

REV_Q = {{*,AC*mu,mu,AT*mu}{AC*mu,*,CG*mu,CT*mu}{mu,CG*mu,*,GT*mu}{AT*mu,CT*mu,GT*mu,*}};

HarvestFrequencies (freqs,dsf,1,1,1);

ChoiceList (whichModel,"Which model?",1,SKIP_NONE, modelChoices);

fprintf (stdout, whichModel+1, "\n\n");

if (whichModel < 0)
{
	return 0;
}

if (Abs (modelConstraints[whichModel]) > 0)
{
	ExecuteCommands (modelConstraints[whichModel]);
}

Model REV = (REV_Q, freqs,1);

Tree theTree 		  = DATAFILE_TREE;
LikelihoodFunction lf = (dsf, theTree);
Optimize (res,lf);

DataSet ancDS 		    = ReconstructAncestors(lf);
DATA_FILE_PRINT_FORMAT  = 0;
DATA_FILE_DEFAULT_WIDTH = 100000;
DataSetFilter 		  ancF = CreateFilter (ancDS,1);

DATAFILE_TREE		   = Format (theTree,1,1);
fprintf (stdout, ancF);



