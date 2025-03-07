/*
 
 HyPhy - Hypothesis Testing Using Phylogenies.
 
 Copyright (C) 1997-2006  
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

#if defined __AFYP_REWRITE_BGM__

#include "hy_lists.h"
#include "classes.h"
#include "likefunc.h"
#include "parser.h"
#include <math.h>
#include "matrix.h"
#include "baseobj.h"
#include "batchlan.h"
// #include "HYUtils.h"


/*SLKP 20070926; include progress report updates */
#if !defined __UNIX__ && !defined __HEADLESS__
	#include "HYConsoleWindow.h"
#endif
/*SLKP*/


#if defined __AFYP_DEVELOPMENT__ && defined __HYPHYMPI__
	#include "mpi.h"
#endif




#define		DIRICHLET_FLATTENING_CONST	0.5


class _BayesianGraphicalModel : public _LikelihoodFunction
	{
	public:
		/* constructors */
		_BayesianGraphicalModel () { }
		_BayesianGraphicalModel (_AssociativeList *);
		
		/* destructor */
		virtual ~_BayesianGraphicalModel (void);
		
		
		/* network initialization */
		bool			SetDataMatrix	(_Matrix *),	// via SetParameter HBL
						SetConstraints	(_Matrix *),	//	"		"
						SetStructure	(_Matrix *),
						SetParameters	(_AssociativeList *),
						SetNodeOrder	(_SimpleList *);
		
		
		/* computation */
		virtual	_Parameter		Compute (void);
				_Parameter		Compute (_Matrix &),
								Compute (_SimpleList &, _List *);
		
		virtual _Matrix *		Optimize ();
		
		void			GraphMetropolis (bool, long, long, long, _Parameter, _Matrix *),
						OrderMetropolis (bool, long, long, _Parameter, _Matrix *),
						K2Search (bool, long, long, _Matrix *);
		
		
		void			CacheNodeScores (void);
		void			MPIReceiveScores (_Matrix *, bool, long);
		void			ReleaseCache (void);
		
		_Parameter		ComputeDiscreteScore (long node_id),	
						ComputeDiscreteScore (long, _Matrix &),
						ComputeDiscreteScore (long, _SimpleList &),
						
						ComputeContinuousScore (long node_id),		
						ComputeContinuousScore (long, _Matrix &),
						ComputeContinuousScore (long, _SimpleList &);
		
		
		_Parameter		ImputeNodeScore (long, _SimpleList &);
		
		void			ComputeParameters (void),
						ComputeParameters (_Matrix *);
		
		
		
		
		/* input/output */
		void				SerializeBGM (_String &);
		bool				ImportModel (_AssociativeList *),
		
							ExportCache (_AssociativeList *),
							ImportCache (_AssociativeList *);
		
		
		/* utility */
		void			InitMarginalVectors (_List *);
		void			DumpMarginalVectors (_List *);
		
		void			SerializeBGMtoMPI (_String &);
		
		void			RandomizeGraph (_Matrix *, _SimpleList *, _Parameter, long, long, bool);
		_SimpleList *	GetOrderFromGraph (_Matrix &);
		bool			GraphObeysOrder (_Matrix &, _SimpleList &);
		
		void			UpdateDirichletHyperparameters (long , _SimpleList &, _Matrix * , _Matrix * );
		
		_Parameter		K2Score (long, _Matrix &, _Matrix &),
						BDeScore (long,	_Matrix &, _Matrix &),
						BottcherScore (_Matrix &, _Matrix &, _Matrix &, _Matrix &, _Parameter, _Matrix &, long);
		
		long			GetNumNodes (void)	{ return num_nodes; }
		long			GetNumCases (void)	{ return theData->GetVDim(); }
		
	protected:
		
		long			num_nodes;
		
		/* ------------------------------------------- */
		
		_Matrix	*		theData;
		
		_SimpleList		data_type,		// boolean, 0 = discrete, 1 = continuous
						num_levels,		// integer, if discrete, number of levels
						max_parents,	// integer, maximum number of parents
						has_missing;	// boolean, 0 = complete data, 1 = missing, (2 = latent, i.e., all missing)
		
		_Matrix			prior_sample_size,
						prior_mean,			// for continuous (Gaussian) nodes
						prior_precision,
						prior_scale;
		
		_Parameter		continuous_missing_value;		// some arbitrary value set in HBL to indicate just that
		
		/* ------------------------------------------- */
		
		_Matrix			theStructure;
		
		_Matrix			constraint_graph;	// integer, 0 = no constraint, -1 = banned edge, 1 = enforced edge
		
		_List			node_score_cache;
		bool			scores_cached;
		
		_SimpleList		node_order_arg;		// provides access to node ordering functionality as HBL argument
		
		/* ------------------------------------------- */
		
		_AssociativeList	theParameters;	// container for _Matrix objects holding formulas for posterior distribution on parameters
		
	};



//______________________________________________________________________________________________
#ifdef __NEVER_DEFINED__
class _DynamicBayesGraph : public _BayesianGraphicalModel
{
public:
	
protected:
	
};
#endif

#endif
