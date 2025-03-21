#include <stdio.h>
#include "likefunc.h"



#ifndef __HYPHY_NO_CURL__
	#define	__HYPHYCURL__
#endif

#ifdef  __HYPHYCURL__
	#include <curl/curl.h>
#endif	

#ifdef			__HYPHYMPI__
_String			preserveSlaveNodeState ("PRESERVE_SLAVE_NODE_STATE"),
				MPI_NEXUS_FILE_RETURN  ("MPI_NEXUS_FILE_RETURN");

bool 			mpiParallelOptimizer 	= false,
   				mpiPartitionOptimizer 	= false;
int  			_hy_mpi_node_rank;

void 			mpiNormalLoop    (int, int, _String &);
void			mpiOptimizerLoop (int, int);

void			mpiBgmLoop (int, int);

#endif


//_________________________________________________________________________

size_t url2File   (void *ptr, size_t size, size_t nmemb, void *stream)
{
	return fwrite (ptr, size, nmemb, (FILE*)stream);	
}

//_________________________________________________________________________

size_t url2String (void *ptr, size_t size, size_t nmemb, void *stream)
{
	_String * s = (_String*)stream;
	char	* p = (char*)ptr;
	
	for (long k=0; k<size*nmemb; k++)
		(*s) << p[k];

	return size*nmemb;
}

//_________________________________________________________________________

bool	Get_a_URL (_String& urls, _String* fileName)
{
	#ifdef __HYPHYCURL__
		CURL *curl;
		CURLcode res ;
		curl = curl_easy_init (); 
		FILE   * f = nil;
		_String* s = nil;
		char cErr [CURL_ERROR_SIZE+1];
		if(curl) 
		{ 
			if (fileName)
			{
				f = fopen (fileName->sData,"wb");
				if (!f)
				{
					urls = _String ("Failed to open ") & *fileName & " for writing";
					return false;
				}
			}
			else
			{
				s = new _String (8192, true);
				checkPointer (s);
			}
			
			curl_easy_setopt (curl, CURLOPT_URL, urls.sData ); 
			curl_easy_setopt (curl, CURLOPT_ERRORBUFFER, cErr);
			if (f)
				curl_easy_setopt (curl, CURLOPT_FILE, (void*)f);
			else
				curl_easy_setopt (curl, CURLOPT_FILE, (void*)s);
				
			_String ver (GetVersionString());
			curl_easy_setopt (curl, CURLOPT_USERAGENT, ver.sData);
			//curl_easy_setopt (curl, CURLOPT_VERBOSE, 1);
			curl_easy_setopt (curl, CURLOPT_WRITEFUNCTION, (void*)(f?url2File:url2String));
			_Parameter vbl = 0.0;
			checkParameter (VerbosityLevelString,vbl,0.0);
			if (vbl<0.5)
			{
				curl_easy_setopt (curl,CURLOPT_NOPROGRESS,1);
			}
			res = curl_easy_perform (curl);
			curl_easy_cleanup (curl);
			
			if (f)
				fclose (f);
			else
			{
				s->Finalize();
				urls = *s;
				DeleteObject (s);
			}
			if (!res)
				return true;
		}
		else
		{
			urls = "Failed to initialize CURL object";
			return false;
		}
		urls = _String ("CURL error:") & (long)res & "." & cErr;
		return false;
	#else
		urls = "This feature requires libcurl";
		return false;
	#endif
}

#ifndef __HYPHY_GTK__

//____________________________________________________________________________________	

_String*	StringFromConsole	(bool)
{
	_String * returnme = new _String (32L, true);
	#ifndef __HEADLESS__
		int		  readAChar;
		while 	 ((readAChar = getc(stdin)) != '\n')
		{
			if (readAChar == EOF)
			{
				if (returnme->sLength == 0)
					WarnError ("Ran out of standard input\n");
				break;
			}
			*returnme << readAChar;
		}
	#else
		WarnError ("Unhandled standard input interaction in StringFromConsolel for headless HyPhy");
		return;
	#endif
	returnme->Finalize ();
	return returnme;
}

//__________________________________________________________________________________

void	StringToConsole (_String & s)
{
#ifdef __HYPHYMPI__
	if (_hy_mpi_node_rank == 0)
#endif
	{
	#ifdef __HEADLESS__
		if (globalInterfaceInstance)
			globalInterfaceInstance->PushOutString(&s);
	#else
		printf ("%s",s.getStr());
	#endif
	}
}

//__________________________________________________________________________________

void	BufferToConsole (const char* s)
{
#ifdef __HYPHYMPI__
	if (_hy_mpi_node_rank == 0)
#endif
	#ifdef __HEADLESS__
		if (globalInterfaceInstance)
		{
			_String st (s);
			globalInterfaceInstance->PushOutString(&st);
		}
	#else
		printf ("%s",s);
	#endif
}

//__________________________________________________________________________________

void	NLToConsole (void)
{
	BufferToConsole ("\n");
}

#endif

#ifdef __HYPHYMPI__

//__________________________________________________________________________________
void mpiNormalLoop    (int rank, int size, _String & baseDir)
{
	long		 senderID = 0;
	
	ReportWarning ("Entered mpiNormalLoop");

	_String* theMessage = MPIRecvString (-1,senderID),	// listen for messages from any node
			* resStr	= nil,
			_bgmSwitch ("_BGM_SWITCH_"),
			css("_CONTEXT_SWITCH_MPIPARTITIONS_");
				
	while (theMessage->sLength)
	{
		setParameter    (mpiNodeID, (_Parameter)rank);
		setParameter	(mpiNodeCount, (_Parameter)size);
		//ReportWarning (*theMessage);
		DeleteObject (resStr);
		resStr = nil;
		if (theMessage->Equal (&css) )
		{
			mpiPartitionOptimizer = true;
			ReportWarning ("Switched to mpiOptimizer loop");
			MPISendString(css,senderID);
			mpiOptimizerLoop (rank,size);
			ReportWarning ("Returned from mpiOptimizer loop");
			mpiPartitionOptimizer = false;
			pathNames && & baseDir;
		}
		else if ( theMessage->Equal (&_bgmSwitch) )
		{
			ReportWarning ("Received signal to switch to mpiBgmLoop");
			MPISendString (_bgmSwitch, senderID);	// feedback to source to confirm receipt of message
			mpiBgmLoop (rank, size);
			ReportWarning ("Returned from mpiBgmLoop");
		}
		else
		{
			if (theMessage->beginswith ("#NEXUS"))
			{
				_String		msgCopy (*theMessage);
				ReportWarning ("Received a function to optimize");
				ReadDataSetFile (nil,true,theMessage);
				ReportWarning ("Done with the optimization");
				_Variable*  lfName = FetchVar(LocateVarByName(MPI_NEXUS_FILE_RETURN));
				
				if (lfName)
				{
					resStr = (_String*)(lfName->Compute()->toStr());
				}
				else
				{
					long		f = LocateVarByName (lf2SendBack);
					if (f>=0)
						lfName = FetchVar(f);
											
					if (!(lfName&&(lfName->ObjectClass()==STRING)))
					{
						_String errMsg ("Malformed MPI likelihood function optimization request - missing LF name to return.\n\n\n");
						errMsg = errMsg & msgCopy;
						FlagError (errMsg);
						break;
					}
					
					f = likeFuncNamesList.Find (((_FString*)lfName->Compute())->theString);
					if (f<0)
					{
						_String errMsg ("Malformed MPI likelihood function optimization request - invalid LF name to return.\n\n\n");
						errMsg = errMsg & msgCopy;
						FlagError (errMsg);
						break;				
					}
					_Parameter pv;
					checkParameter (shortMPIReturn, pv ,0);
					resStr = new _String (1024L,true);
					checkPointer (resStr);
					((_LikelihoodFunction*)likeFuncList (f))->SerializeLF(*resStr,pv>0.5?5:2);
					resStr->Finalize();
				}
			}
			else
			{
				_ExecutionList exL (*theMessage);
				/*printf ("Received:\n %s\n", ((_String*)exL.toStr())->sData);*/
				_PMathObj res = exL.Execute();
				resStr = res?(_String*)res->toStr():new _String ("0");
			}
				
			checkPointer (resStr);
			DeleteObject (theMessage);
			MPISendString(*resStr,senderID);

			_Parameter 	   	keepState = 0.0;
			checkParameter  (preserveSlaveNodeState, keepState, 0.0);
			
			if (keepState < 0.5)
			{
				PurgeAll (true);
				pathNames && & baseDir;		
			}
		}
		theMessage = MPIRecvString (-1,senderID);		
	}
	/*MPISendString(empty,senderID);*/
	DeleteObject (resStr);
	DeleteObject (theMessage);	
}

//__________________________________________________________________________________
void mpiOptimizerLoop (int rank, int size)
{
	long		 senderID = 0;
			
	ReportWarning (_String ("MPI Node:") & (long)rank & " is ready for MPIParallelOptimizer tasks");
				
	if (mpiPartitionOptimizer)
		ReportWarning (_String("MPI Partitions mode"));
	
	//printf ("Node %d waiting for a string\n", rank);
	_String* theMessage = MPIRecvString (-1,senderID);
	while (theMessage->sLength)
	{
		if (theMessage->beginswith ("#NEXUS"))
		{
			ReadDataSetFile (nil,true,theMessage);
			if (likeFuncNamesList.lLength!=1)
			{
				_String errMsg ("Malformed MPI likelihood function paraller optimizer startup command. No valid LF has been defined.n\n\n");
				FlagError (errMsg);
				break;						
			}
			
			// send back the list of independent variables
			
			_LikelihoodFunction * theLF = (_LikelihoodFunction*)likeFuncList (0);
			
			if (mpiParallelOptimizer && theLF->GetCategoryVars().lLength)
			{
				_String errMsg ("Likelihood functions spawned off to slave MPI nodes can't have category variables.n\n\n");
				FlagError (errMsg);
				break;						
			}
			
			_SimpleList* ivl = & theLF->GetIndependentVars();
			
			_String		 variableSpec (128L, true);
			
			(variableSpec) << LocateVar(ivl->lData[0])->GetName();

			for (long kk = 1; kk < ivl->lLength; kk++)
			{
				(variableSpec) << ';';
				(variableSpec) << LocateVar(ivl->lData[kk])->GetName();	
			}
			
			ReportWarning 		  (variableSpec);
			MPISendString		  (variableSpec,senderID);
			theLF->PrepareToCompute();
			theLF->MPI_LF_Compute (senderID, mpiPartitionOptimizer);
			theLF->DoneComputing();
			PurgeAll (true);
		}
		DeleteObject (theMessage);
		theMessage = MPIRecvString (-1,senderID);
	}	
	DeleteObject (theMessage);		
}


//__________________________________________________________________________________
void mpiBgmLoop (int rank, int size)
{
	long		senderID	= 0;
	_String	*	resStr		= nil;
	
	ReportWarning (_String ("MPI Node:") & (long)rank & " is ready for MPIBgmCacheNodeScores tasks");
	
	// receive serialized Bgm
	_String* theMessage = MPIRecvString (-1, senderID);
	
	while (theMessage->sLength)
	{
		_ExecutionList	exL (*theMessage);
		_PMathObj		res = exL.Execute();	// should send this process into CacheNodeScores()
		
		resStr = res ? (_String*)res->toStr() : new _String ("0");
		ReportWarning (_String ("MPI Node: ") & (long)rank & " executed HBL with result:\n" & resStr);
		
		if (bgmNamesList.lLength < 1)
		{
			_String errMsg ("Malformed HBL. No valid BGM has been defined.\n");
			FlagError (errMsg);
			break;
		}
	}
	
	DeleteObject (theMessage);		
}
#endif

