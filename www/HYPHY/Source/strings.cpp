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

#include "hy_strings.h"

#ifndef __HYPHYXCODE__
	#include "gnuregex.h"
#else
	#include "regex.h"
#endif

#include "batchlan.h"

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <time.h>


_String	  __KERNEL__VERSION__ ("2.0020090803beta");

#ifdef	 __UNIX__
	#if !defined __MINGW32__
		#include <sys/utsname.h>
	#endif
	extern  bool dropIntoDebugMode;
#else	
	void 	SaveConsole (void);
#endif

#ifdef 	  __HYPHYDMALLOC__
	#include "dmalloc.h"
#endif

#if !defined __UNIX__ || defined __HEADLESS__
	#include "preferences.h"
#endif

#ifdef __MAC__
	#include <Dialogs.h>
	#include "HYUtils.h"
#endif

#ifdef __WINDOZE__
	void WinErrorBox(_String&, bool);
#endif

#ifdef __HYPHY_GTK__
	#include <gtk/gtk.h>
	#include "HYConsoleWindow.h"
#endif


_String 	empty(""),
			hyphyCiteString 
			("\nPlease cite S.L. Kosakovsky Pond, S. D. W. Frost and S.V. Muse. (2005) HyPhy: hypothesis testing using phylogenies. Bioinformatics 21: 676-679 if you use HyPhy in a publication\nIf you are a new HyPhy user, the tutorial located at http://www.hyphy.org/docs/HyphyDocs.pdf may be a good starting point.\n");

char		defaultReturn = 0;

unsigned 	long _String::storageIncrement = 32;

extern 		_Parameter messageLogFlag;

//_______________________________________________________________________

struct _hyValidIDCharsType
{
	bool valid_chars[255];
	_hyValidIDCharsType(void)
	{
		for (int c = 0; c < 256; c++)
			valid_chars[c] = false;
		{
		for (unsigned char c='a'; c<='z'; c++)
			valid_chars[c] = true;
        }
		{
		for (unsigned char c='A'; c<='Z'; c++)
			valid_chars[c] = true;
		}
		{
		for (unsigned char c='0'; c<='9'; c++)
			valid_chars[c] = true;
        }
		valid_chars['_'] = true;
	}
}
_hyValidIDChars;

//_______________________________________________________________________
//does nothing
_String::_String (void)
{
	sLength = 0;
	sData = nil;
}
//_______________________________________________________________________
//length constructor
_String::_String (unsigned long sL, bool flag) {

	if (flag)
	{
		sLength = 0;
		nInstances = sL>storageIncrement?sL:storageIncrement;
		sData = (char*)MemAllocate (nInstances*sizeof (char));
		//sData = (char*)MemAllocate (storageIncrement*sizeof (char));
		if (!sData)
		{
			nInstances = 1;
			warnError(-108);
		}
	}
	else
	{
		sLength = sL;
		sData = (char*)MemAllocate (sL+1);
	    if (sData)
			memset (sData,0,sL+1);
		else 
		{
			sLength = 0;
			warnError (-108);
		}
	}	
}


//_______________________________________________________________________

_String::_String (const _String& source, long from, long to) 
{
	if (source.sLength) 
	{
		if (from == -1) from = 0;
		
		if (to == -1) 	to   = ((long)source.sLength)-1;
		
		if (to>=from)
		{
			sLength = to-from+1;
			sData = (char*)MemAllocate (sLength+1);
			if (!sData)
				warnError( -108);
				
			if (sLength > 32)
				memcpy (sData,source.sData+from ,sLength);
			else
				for (long k=0; k<sLength; k++)
					sData[k] = source.sData[k+from];
					
			sData[sLength] = 0;
			return;
		}
	}
	
	sLength = 0;
	sData = (char*)MemAllocate (1);
	sData[0] = 0;
}

//_______________________________________________________________________
//length constructor
_String::_String (long sL) {
	
	char s [32];
	sprintf (s,"%ld", sL);
	
	for(sLength=0;s[sLength];sLength++) ;
	
	checkPointer (sData = (char*)MemAllocate(sLength+1));
	
	memcpy (sData, s, sLength+1);
}

//_______________________________________________________________________
void	_String::Initialize (void) {
	BaseObj::Initialize();
	sLength = 0;
	sData = 0;
}

//_______________________________________________________________________
void	_String::Duplicate (BaseRef ref) {
	_String * s = (_String*)ref;
	sLength = s->sLength;
	sData = s->sData;
	if (sData) 
	{
		checkPointer (sData = (char*)MemAllocate (sLength+1));
		memcpy (sData, s->sData, sLength+1);
	}

}


//_______________________________________________________________________
// stack copy contructor
_String::_String (const _String& s) {
	Duplicate ((BaseRef)&s);
}

//_______________________________________________________________________

_String::_String (_String* s) 
{
	CopyDynamicString (s, false);
}

//_______________________________________________________________________
void _String::CopyDynamicString (_String *s, bool flushMe)
{
	if (flushMe && sData) 
		free (sData);
	
	sLength 	= s->sLength;
	if (s->nInstances == 1)
	{
		sData   	= s->sData;
		s->sData 	= nil;
		DeleteObject (s);
	}
	else
	{
		checkPointer (sData = (char*)MemAllocate (sLength+1));
		if (s->sData)
			memcpy (sData, s->sData, sLength+1);
		else
			sData[0] = 0;
		s->nInstances --;
	}
}


//_______________________________________________________________________
// data constructor
_String::_String (const char* s) {
	for(sLength=0;s[sLength];sLength++) ;
	checkPointer (sData = (char*)MemAllocate (sLength+1));
	memcpy (sData, s, sLength+1);
}

//_______________________________________________________________________
// data constructor
_String::_String (const char s) {
	sLength = 1;
	checkPointer (sData = (char*)MemAllocate (sLength+1));
	sData[0]=s;
	sData[1]=0;
}

//_______________________________________________________________________
// data constructor
_String::_String (_Parameter val) {
	char s_val[128];
	sprintf (s_val,PRINTF_FORMAT_STRING,val);
	for(sLength=0;s_val[sLength];sLength++) ;
	checkPointer (sData = (char*)MemAllocate (sLength+1));
	for (long k=0; k<=sLength; k++)
		sData[k] = s_val[k];
}

//_______________________________________________________________________
//does nothing
_String::_String (FILE* F)
{
	sLength = 0;
	sData   = nil;
	if (F)
	{
		fseek (F,0,SEEK_END);
		sLength = (unsigned long)ftell(F);
		sData =	(char*)MemAllocate (sLength+1);
		rewind (F);
		fread (sData,1,sLength,F);
		sData[sLength] = 0;
	}
}


//_______________________________________________________________________
//destructor	
			
_String::~_String(void)
{
	if (isReleasing)
	{
		memReleased+=sizeof(_String);
		isReleasing--;
	}

	if (nInstances<=1){
		if (sData) 
		{
			free (sData);
			memReleased+=sLength+1;
			sData = nil;
		}
		sLength = 0;
	}
	else
		nInstances--;
}

//_______________________________________________________________________
// make dynamic copy
BaseRef _String::makeDynamic (void)
{
	_String * r = new _String;
	if (!r)
		checkPointer(r);
	//memAlloc += sizeof (_String);
	//memcpy ((char*)r, (char*)this, sizeof (_String));
	//r->nInstances = 1;
	r->Duplicate(this);
	return r;
}
	 				
 			
//_______________________________________________________________________
// element location functions 				
 			
char& _String::operator [] (long index)
{
	if (((unsigned long)index)<sLength)
		return sData[index];
	return defaultReturn;
}

//_______________________________________________________________________
// element location functions 				
 			
const char _String::getChar (long index)
{
	if (((unsigned long)index)<sLength)
		return sData[index];
	return defaultReturn;
}

//_______________________________________________________________________
// element location functions 				
 			
void _String::setChar (long index, char c)
{
	if (((unsigned long)index)<sLength)
		sData[index] = c;
}

//_______________________________________________________________________
// element location functions 				
 			
char _String::operator () (unsigned long index)
{
	if (index<sLength)
		return sData[index];
		
	return 0;
}

//_______________________________________________________________________
void	_String::DuplicateErasing (BaseRef ref) {
	if (sData) 
	{
		free (sData);
		memReleased += sLength+1;
	}	
	_String * s = (_String*)ref;
	sLength = s->sLength;
	sData = s->sData;
	if (sData) {
			checkPointer (sData = (char*)MemAllocate (sLength+1));
			memcpy (sData, s->sData, sLength+1);
	}

}
//_______________________________________________________________________
// assignment operator  

void _String::operator = (_String s)
{
	if (sData) 
	{
		free (sData);
		memReleased += sLength+1;
	}

	sLength = s.sLength;
	sData = s.sData;
	
	if (sData) {
		checkPointer (sData = (char*)MemAllocate (sLength+1));
		nInstances = 1;
		memcpy (sData, s.sData, sLength+1);
	}
}

//_______________________________________________________________________
// string length
 				
unsigned long _String::Length(void)
{
	return sLength;
}
//_______________________________________________________________________
// append operator
_String _String::operator & (_String s)
{
	if (sLength+s.sLength == 0) 
		return empty;
	
	_String res (sLength+s.sLength);
	
	if (sLength)
		memcpy((res.sData),sData,sLength);
	
	if (s.sLength)
		memcpy(res.sData+sLength,s.sData,s.sLength);
	
	res.sData[res.sLength]=0;
	return res;
}

//_______________________________________________________________________
// insert char operator
void _String::Insert (char c, long pos)
{
	if (pos<0) pos = sLength;
	
	sData = MemReallocate (sData,sizeof(char)*(sLength+2));
	
	if (pos<sLength)
	{
		memmove(sData+pos+1,sData+pos, sLength-pos);
	}
	sData[pos] = c;
	sLength++;
	sData[sLength] = 0;
}

//_______________________________________________________________________
// delete range char operator
void _String::Delete (long from, long to)
{
	if (from<0) from = 0;
	if (to<0) to = sLength-1;

	if (to<sLength-1)
		memmove (sData+from, sData+to+1, sLength-to-1);	
	sLength -= to-from+1;
	sData = MemReallocate (sData,sizeof(char)*(sLength+1));
	sData[sLength]=0;
}

//_______________________________________________________________________
// append operator
void _String::operator << (const _String* s)
{
	if ( s && s->sLength) 
	{
		/*unsigned long leftOver = storageIncrement-sLength%storageIncrement;
		
		if (sLength&&(leftOver==storageIncrement)) 
			leftOver = 0;
		
		if (leftOver<s->sLength) //readjust memory allocation
		{
			long times = (s->sLength-leftOver)/storageIncrement+1;

			if (!(sData = MemReallocate (sData, (sLength/storageIncrement+times+1)*storageIncrement)))
				warnError( -108);
		}*/
		
		if (nInstances < sLength + s->sLength)
		{
			unsigned long incBy = sLength + s->sLength - nInstances;
			
			if (incBy < storageIncrement)
				incBy = storageIncrement;
				
			if (incBy < sLength/8)
				incBy = sLength/8;
			
			nInstances+=incBy;

			sData = (char*)MemReallocate((char*)sData, nInstances*sizeof(char));
				
			if (!sData)
				checkPointer (sData);
		}

		memcpy(sData+sLength,s->sData,s->sLength);
		sLength+=s->sLength;
	}
}

//_______________________________________________________________________
// append operator
void _String::operator << (const char* str)
{
	_String conv (str);
	(*this)<<&conv;
}

//_______________________________________________________________________
// append operator
void _String::operator << (const char c)
{
	if (nInstances <= sLength)
	{
		nInstances	+= ((storageIncrement*8 > sLength)? storageIncrement: (sLength/8+1));
		checkPointer (sData = (char*)MemReallocate((char*)sData, nInstances*sizeof(char)));
	}
	
	sData[sLength++]=c;
}

//_______________________________________________________________________
// append operator
void _String::EscapeAndAppend (const char c, char mode)
{
	if (mode == 2)
	{
		(*this) << c;
		switch (c)
		{
			case '\'':
				(*this) << c; 
		}
		return;
	}
	else
	{
		if (mode == 1)
		{
			switch (c)
			{
				case '(':
				case ')':
				case '%':
					(*this) << '\\'; (*this) << c;
					return;
			}
		}
	}
	switch (c)
	{
		case '\n':
			(*this) << '\\';
			(*this) << 'n';
			break;
		case '\t':
			(*this) << '\\';
			(*this) << 't';
			break;
		case '"':
			(*this) << '\\';
			(*this) << '"';
			break;
		case '\\':
			(*this) << '\\';
			(*this) << '\\';
			break;
		default:
			(*this) << c;
	}
}

//_______________________________________________________________________
// append operator
void _String::EscapeAndAppend (const _String & s, char mode)
{
	for (long i=0; i<s.sLength;  i++)
		EscapeAndAppend (s.sData[i], mode);
}


//_______________________________________________________________________
// finalize buffer string
void _String::Finalize (void)
{
	if (!(sData = MemReallocate (sData, sLength+1)))
		warnError (-108);
	
	sData[sLength]  = 0;
	nInstances		= 1;
}



//_______________________________________________________________________
// return good ole char*
_String::operator const char* (void)
{
	return sData;
}

//_______________________________________________________________________
// return good ole char*
char * _String::getStr (void)
{
	return sData;
}
//_______________________________________________________________________
// return good ole char*
BaseRef _String::toStr (void)
{
	nInstances++;
	return this;
}
//_______________________________________________________________________

_String _String::Chop(long from, long to)
{
	if (!sLength) return empty;
	if (from == -1) from = 0;
	if (to == -1) to = ((long)sLength)-1;
	if (to<from) return empty;
	_String res ((unsigned long)(sLength+from-to+1));
	if (from)
		memcpy (res.sData,sData, from);
	if ((to<((long)sLength)-1)&&(to>from))
		memcpy (res.sData+from,sData+to+1, sLength-to-1);
	return res;
}

//_______________________________________________________________________
// cut string from, to (-1 for any means from beginning/to end)
_String _String::Cut(long from, long to)
{
	if (sLength==0) 
	{
		return empty;
	}
	if (from == -1) from = 0;
	if (to == -1 || to >= sLength) to = ((long)sLength)-1;
	if (to<from) return empty;
	_String res ((unsigned long)(to-from+1));
	if (to-from+1)
		memcpy (res.sData,sData+from,  to-from+1);
	return res;
}

//_______________________________________________________________________
// s[0]...s[sLength-1] => s[sLength-1]...s[0]
void _String::Flip(void)
{
	for (long i = 0; i < sLength/2; i++)
	{
		char c = sData[i];
		sData[i] = sData[sLength-1-i];
		sData[sLength-1-i] = c;
	}
}

//_______________________________________________________________________
// compute Adler-32 CRC for a string
// implementation shamelessly lifted from http://en.wikipedia.org/wiki/Adler-32

#define MOD_ADLER 65521

long _String::Adler32(void)
{
   unsigned char  *data = (unsigned char*)sData; 
   
   unsigned long len = sLength,
   				 a   = 1, 
   				 b 	 = 0;

   while (len) {
           unsigned tlen = len > 5550 ? 5550 : len;
           len -= tlen;
           do {
                   a += *data++;
                   b += a;
           } 
           while (--tlen);
           a = (a & 0xffff) + (a >> 16) * (65536-MOD_ADLER);
           b = (b & 0xffff) + (b >> 16) * (65536-MOD_ADLER);
   }

   if (a >= MOD_ADLER)
           a -= MOD_ADLER;
 
   b = (b & 0xffff) + (b >> 16) * (65536-MOD_ADLER);
 
   if (b >= MOD_ADLER)
        b -= MOD_ADLER;
  
   return b << 16 | a;
}

//_______________________________________________________________________
// cut string from, to (-1 for any means from beginning/to end)
void _String::Trim(long from, long to)
{
	if (!sLength) return;
	if (from < 0) from = 0;
	else
		if (from>=sLength)
			from = ((long)sLength)-1;
	if (to < 0) to = ((long)sLength)-1;
	else
		if (to>=sLength)
			to = ((long)sLength)-1;
	if (to-from+1>0)
	{
		memmove (sData,sData+from,  to-from+1);
		sLength = to-from+1;
		sData = MemReallocate (sData, to-from+2);
		sData[to-from+1]=0;
	}
	else
	{
		sLength = 0;
		sData = MemReallocate (sData, 1);
		sData[0]=0;
	}
}

//_______________________________________________________________________
// locate the first non-space charachter of the string
long _String::FirstNonSpaceIndex(long start, long end, char direction)
{
	if (start == -1) start = ((long)sLength)-1;
	if (end == -1)   end = ((long)sLength)-1;
	if (direction<0)
	{
		//long t = start;
		start = end;
		end = start;
	}	
	if (sLength&&(start<sLength)&&(!isspace (sData[start]))) return start; // first char is non-space
	char* str = sData+start;
	for (int i = start; i<=end; i+=direction, str+=direction)
		if (!(((*str>=9)&&(*str<=13))||(*str==' '))) return i;
		
	return -1;
}

//_______________________________________________________________________
// remove all spaces
void _String::KillSpaces (_String& result)
{
	_String temp (sLength+1,true);
	for (long k=0; k<sLength; k++)
		if (!isspace (sData[k]))
			temp << sData[k];
	temp.Finalize();
	result = temp;
}

//_______________________________________________________________________
// replace all space runs with a single space

void _String::CompressSpaces (void)
{
	_String temp (sLength+1,true);
	bool    skipping = false;
	
	for (long k=0; k<sLength; k++)
		if (isspace (sData[k]))
		{
			if (!skipping)
			{
				skipping = true;
				temp << ' ';
			}
		}
		else
		{
			temp << sData[k];
			skipping = false;
		}
	temp.Finalize();
	*this = temp;
}

//_______________________________________________________________________
// locate the first non-space charachter of the string
long _String::FirstSpaceIndex(long start, long end, char direction)
{
	if (start == -1) start = ((long)sLength)-1;
	if (end == -1)   end = ((long)sLength)-1;
	if (direction<0)
	{
		//long t = start;
		start = end;
		end = start;
	}	
	if (sLength&&(isspace (sData[start]))) return start; // first char is non-space
	char* str = sData+start;
	for (int i = start; i<=end; i+=direction, str+=direction)
		if ((((*str>=9)&&(*str<=13))||(*str==' '))) return i;
		
	return -1;
}

//_______________________________________________________________________
// locate the first non-space charachter of the string
char _String::FirstNonSpace(long start, long end, char direction)
{
	long r = FirstNonSpaceIndex(start,end,direction);
	return r==-1?0:sData[r];
}

//_______________________________________________________________________
// locate the first non-space charachter of the string
long _String::FindEndOfIdent(long start, long end, char wild)
{
	if (start == -1) 
		start = ((long)sLength)-1;
	if (end == -1)   
		end = ((long)sLength)-1;
		
	long i = start;
	
	for (; i<=end; i++)
		if (!(isalnum(sData[i])||sData[i]=='.'||sData[i]==wild||sData[i]=='_')) break;
		
	if (i>start+2 && sData[i-1] == '_' && sData[i-2] == '_')
		return i-3;
		
	return i-1;
}


//_______________________________________________________________________
// find first occurence of the string between from and to

long _String::Find(_String s, long from, long to)
// -1, indicates that search term has not been found
{
	if (!sLength) return -1;
	if (from == -1) from = 0;
	if (to == -1) to = ((long)sLength)-1;
	if (to<from) return -1;
	if (to-from+1<s.sLength) return -1;
	char *sP = sData+from, *ssP = s.sData;
	for (long i=from;i<=to-s.sLength+1;i++,sP++)
	{
		long j;
		for (j = 0;(sP[j]==ssP[j])&&(j<s.sLength);j++) ;
		if (j==s.sLength) return i;
	}
	return -1;
}

//_______________________________________________________________________
// find first occurence of the string between from and to 
// case insensitive

long _String::FindAnyCase (_String s, long from, long to)
// -1, indicates that search term has not been found
{
	if (!sLength) 
		return -1;
	if (from == -1) 
		from = 0;
	if (to == -1) 
		to = ((long)sLength)-1;
	if (to<from) 
		return -1;
	if (to-from+1<s.sLength) 
		return -1;
		
	s.UpCase();
	char *sP = sData+from, *ssP = s.sData;
	for (long i=from;i<=to-s.sLength+1;i++,sP++)
	{
		long j;
		for (j = 0;(toupper(sP[j])==ssP[j])&&(j<s.sLength);j++) ;
		if (j==s.sLength) return i;
	}
	return -1;
}

//_______________________________________________________________________
// find first occurence of the string between from and to

bool _String::ContainsSubstring(_String& s)
// -1, indicates that search term has not been found
{
	if (!sLength) return false;
	if (sLength<s.sLength) return -1;
	char *sP = sData, *ssP = s.sData;
	for (long i=0;i<sLength-s.sLength;i++,sP++)
	{
		long j = 0;
		for (;(sP[j]==ssP[j])&&(j<s.sLength);j++) ;
		if (j==s.sLength) 
			return true;
	}
	return false;
}

//_______________________________________________________________________
// find first occurence of the string between from and to

long _String::Find(char s, long from, long to)
{
	if (!sLength) return -1;
	if (from == -1) from = 0;
	if (to == -1) to = ((long)sLength)-1;
	if (to<from) return -1;
	//if (to-from<0) return -1;

	for (long i=from;i<=to;i++)
		if (sData[i]==s) return i;

	return -1;
}
			
//_______________________________________________________________________
// find first occurence of the string between from and to

long _String::FindBackwards(_String s, long from, long to)
// -1, indicates that search term has not been found
{
	if (!sLength) return -1;
	if (from == -1) from = 0;
	if (to == -1) to = ((long)sLength)-1;
	if (to<from) return -1;
	if (to-from+1<s.sLength) return -1;
	char *sP = sData, *ssP = (s.sData);
	for (long i=to-s.sLength+1;i>=(long)from;i--)
	{
		long j;
		for (j = 0;(sP[i+j]==ssP[j])&&(j<s.sLength);j++) ;
		if (j==s.sLength) return i;
	}
	return -1;
}



//_______________________________________________________________________
// find first occurence of the string 

long _String::FindBinary(char s)
// -1, indicates that search term has not been found
{
	long top=Length()-1, bottom=0, middle;
	
	if (top==-1) return top;
	while (top>bottom)
	{
		middle = (top+bottom)/2;
		if (s<sData[middle])
		{
			top = middle==top?top-1:middle;
		}
		else
			if (s<sData[middle])
			{
				bottom = middle==bottom?bottom+1:middle;
			}
			else
				return middle;
			
		
	}
	middle = top;
	if (s==sData[middle]) return middle;
	
	return -middle-2;
}

//_______________________________________________________________________
// lexicographic comparison
bool _String::operator == (_String s)
{
	return Equal(&s);
}

//_______________________________________________________________________
// lexicographic comparison
bool _String::Equal (_String* s)
{
	if  (sLength!=s->sLength)
		 return false;

	for (long i=0; i<sLength; i++)
	 	if (sData[i]!=s->sData[i]) 
	 		return false;
	
	return true;
}

//_______________________________________________________________________
// lexicographic comparison
char 	_String::Compare (_String* s)
{
	long upTo;
		 
	if  (sLength>s->sLength)
		upTo = s->sLength;
	else
		upTo = sLength;

	for (long i=0; i<upTo; i++)
	{
		int res = (sData[i]-s->sData[i]);
	 	if (res < 0)
	 		return -1;
	 	else
	 		if (res>0)
	 			return 1;
	}
	
	if (sLength == s->sLength)
		return 0;

	return 1-2*(sLength<s->sLength);
}

//_______________________________________________________________________
// lexicographic comparison
bool _String::EqualWithWildChar (_String* s, char wildchar)
// s may contain a wild char
{
	char *sP = sData, *ssP = (s->sData); // optimize
	// we start comparing the strings until we run into a wildchar.
	long matchLength, t, q, p, curPos = 0;
	while (*ssP)
	{
		if (*ssP!=wildchar)
		{
			if (*ssP==*sP)
			{
				ssP++;
				sP++;
				curPos++;
				continue;
			}
			else
			{
				return false;
			}
		}
		// wildchar found
		// skip the wildchar and scroll the 1st string until match is found
		matchLength = 0;
		ssP++;
		while (*ssP&&(*ssP!=wildchar))
		{
			ssP++;
			matchLength++;
		}
		if (!matchLength) // wildchar is the last symbol in expression
		{
			if (!*ssP)
			{
				return true; // expressions matched
			}
		}
		else // check sP for a possible match
		{
			t = matchLength-1;
			q = matchLength+curPos-1;
			ssP--;
			while (q<sLength)
			{
				if (sP[t]==*ssP)
				{
					p = 1;
					while (p<matchLength)
					{
						char c = *(ssP-p);
						if (sP[t-p]!=c) break;
						p++;
					}
					if (p==matchLength)
					{
						sP += t+1;
						curPos = q+1;
						ssP++;
						break;
//						ssP++;
					}
				}
				t++;
				q++;
			}
			if (q==sLength)
			{
				return false;
			}
		}
	}

	return (*sP==0);
}
//_______________________________________________________________________
// lexicographic comparison
bool _String::operator > (_String s)
{
	return Greater(&s);
}

//_______________________________________________________________________
// lexicographic comparison
bool _String::Greater (_String *s)
{
	unsigned long top = ((s->sLength>sLength)?sLength:s->sLength);
	
	for (long i=0; i<top; i++)
	{
	 	int j = sData[i]-s->sData[i];
		if (j>0) return true;
	 	if (j<0) return false;
	}  
	
	return (sLength>s->sLength);
}
		
//_______________________________________________________________________
// lexicographic comparison
bool _String::operator <= (_String s)
{
	return !((*this)>s);
}

//_______________________________________________________________________
// lexicographic comparison
bool _String::operator >= (_String s)
{
	return (((*this)>s)||(*this==s));
}
 			
//_______________________________________________________________________
// lexicographic comparison
bool _String::operator != (_String s)
{
	return !(*this==s);
}

//_______________________________________________________________________
// lexicographic comparison
bool _String::Less (_String *s)
{
	unsigned long top = ((s->sLength>sLength)?sLength:s->sLength);
	
	for (long i=0; i<top; i++)
	{
		 int j= sData[i]-s->sData[i];
		 if (j>0) return false;
		 if (j<0) return true;
	}  
	
	return (sLength<s->sLength);
	
}

//_______________________________________________________________________
// lexicographic comparison
bool _String::operator < (_String s)
{
	return Less(&s);
}

//_______________________________________________________________________
// lexicographic inclusion
bool _String::contains (_String s)
{
	return Find(s)!=-1;
}

//_______________________________________________________________________
// lexicographic inclusion
bool _String::contains (char c)
{
	return Find(c)!=-1;
}
 				
//_______________________________________________________________________
// begins with string
bool _String::beginswith (_String s, bool caseSensitive)
{
	if (sLength<s.sLength) return FALSE;
	char *sP = sData, *ssP = (s.sData);
	if (caseSensitive)
	{
		for (long i=0; i<s.sLength; i++)
			if (sP[i]!=ssP[i]) return FALSE;
	}
	else
		for (long i=0; i<s.sLength; i++)
			if (toupper(sP[i])!=toupper(ssP[i])) return FALSE;
		
	
	return TRUE;
}
 			
//_______________________________________________________________________
// begins with string
bool _String::startswith (_String& s)
{
	if (sLength<s.sLength) 
		return FALSE;
		
	char *sP  = sData, 
		 *ssP = s.sData;
		 
	for (;*ssP; sP++,ssP++)
	 if (*sP!=*ssP) return false;
	
	return true;
}
 			
//_______________________________________________________________________
// ends with string
bool _String::endswith (_String s, bool caseSensitive)
{
	if (sLength<s.sLength) return FALSE;
	char *sP = sData+sLength-s.sLength, 
		 *ssP = (s.sData),
		 *ssP2 = s.sData+s.sLength;
	
	if (caseSensitive)
	{
		for (; ssP!=ssP2; ssP++,sP++)
			if (*sP-*ssP) return FALSE;
	}
	else
		for (; ssP!=ssP2; ssP++,sP++)
			if (toupper(*sP)!=toupper(*ssP)) return FALSE;
	
	return TRUE;
}

//_______________________________________________________________________
// replace string 1 with string 2, all occurences true/false
void _String::FormatTimeString(long time_diff)
{
	long secs = time_diff, 
		 mins = secs/60, 
	     hrs  = mins/60;

	mins = mins%60;
	secs = secs%60;
	if (hrs<10)
		(*this) = _String('0')&hrs;
	else
		(*this) = _String(hrs);
	(*this) = (*this) &':';
	if (mins<10)
		(*this) = (*this)&_String('0')&mins;
	else
		(*this) = (*this)&_String(mins);
	(*this) = (*this) &':';
	if (secs<10)
		(*this) = (*this)&_String('0')&secs;
	else
		(*this) = (*this)&_String(secs);	
}

//_______________________________________________________________________
// replace string 1 with string 2, all occurences true/false
_String _String::Replace(_String s, _String d, bool flag)
{
	if (!sLength) 		
		return empty;
	if (sLength<s.sLength) 
		return *this;
	if (s.sLength == 0) 
		return (*this);
	
	if (flag) // replace all
	{
		// max possible number of replaces
		unsigned long t = sLength, cp=0;
		
		// allocate space for positions of substring s in this
		long *finds = (long *)MemAllocate(t*sizeof(long)), curSlot = 0;
		
		
		// find all substrings s in this
		finds[0]=Find(s);
		if (finds[0]!=-1)
		{
			curSlot++;
			while ((finds[curSlot]=Find(s,finds[curSlot-1]+s.sLength,-1))!=-1)
				curSlot++;
		}
		
		// calculate the length of resulting string
		
		_String Res(sLength-(s.sLength-d.sLength)*curSlot);
		
		if (!curSlot) // not found
		{
			free ((char*)finds);
			return *this;
		}
			
		char *rP = (Res.sData), *dsP =(d.sData), *sP=(sData);

		if (finds[0])
			memcpy(rP,sP,finds[0]); //head of the string;
		cp+=finds[0];
			
		for (t=0;t<curSlot-1;t++) // do the replacing
		{
			if (d.sLength)
				memcpy(rP+cp,dsP,d.sLength);
			cp+=d.sLength;
			if (finds[t+1]-finds[t]-s.sLength)
				memcpy(rP+cp,sP+finds[t]+s.sLength,finds[t+1]-finds[t]-s.sLength);
			cp+=finds[t+1]-finds[t]-s.sLength;
		}
		if (d.sLength)
			memcpy(rP+cp,dsP,d.sLength);
		cp+=d.sLength;
		if(sLength-finds[curSlot-1]-s.sLength)
			memcpy(rP+cp,sP+finds[curSlot-1]+s.sLength,sLength-finds[curSlot-1]-s.sLength);
		//tail
		free((char*)finds);
		return Res;
	}
	
	//first occurrence replace
	long t = Find(s),cp=0;
	if (t==-1) return *this;
	// substring not found
	
	_String Res(sLength-(s.sLength-d.sLength));

	char *rP = Res.sData, *dsP =d.sData, *sP=sData;
	if(t)
		memcpy(rP,sP,t); //head of the string;
	cp+=t;
	if (d.sLength)
		memcpy(rP+cp,dsP,d.sLength);
	cp+=d.sLength;
	if (sLength-t-s.sLength)
		memcpy(rP+cp,sP+t+s.sLength,sLength-t-s.sLength);
	//tail
	return Res;

}


//_______________________________________________________________________
_List* _String::Tokenize (_String s)
{
	_List *res = new _List;
	if (s.sLength!=0)
	{
		long cp=0,cpp;
		while ((cpp = Find(s,cp,-1))!=-1)
		{
			if (cpp>cp)
				res->AppendNewInstance (new _String (*this,cp,cpp-1));
			else
				(*res) && (&empty);

			cp=cpp+s.sLength;
		}
		
		res->AppendNewInstance (new _String (*this,cp,-1));
	}
	return res;
}


//_______________________________________________________________________
	
_Parameter		_String::toNum (void)
{
	if (!sLength) 	return 0;
	char * endP;
	return strtod(sData,&endP);
}


//_______________________________________________________________________
void 	_String::UpCase (void)
{
	char * TheText = sData;
	for (long i = 0; i<sLength; i++) 
	{
		//char c = TheText[i];
		//if ((c>='a')&&(c<='z')) 
			//TheText[i]-=32;
		TheText[i] = toupper (TheText[i]);
	}

}

//_______________________________________________________________________
void 	_String::LoCase (void)
{
	char * TheText = sData;
	for (long i = 0; i<sLength; i++) 
	{
		/*char c = TheText[i];
		if ((c>='A')&&(c<='Z')) 
			TheText[i]+=32;*/
			
		TheText[i] = tolower (TheText[i]);
	}
}

//_______________________________________________________________________
void	ReportWarning (_String st)
{
	checkParameter 			(MessageLogging, messageLogFlag, 1.0);
	
#ifdef  __HEADLESS__
	if (globalInterfaceInstance && messageLogFlag >= 0.1)
		globalInterfaceInstance->PushWarning (&st);
#else		
	if ( !globalMessageFile || messageLogFlag<.1 ) 
		return;
	
	char   str[] = "\n";
	fwrite (str, 1, 1, globalMessageFile);
	fwrite (st.getStr(), 1, st.Length(), globalMessageFile);
	fflush (globalMessageFile);
#endif
}


//_______________________________________________________________________
void	FlagError (_String st)
{
#ifdef  __HEADLESS__
	if (globalInterfaceInstance)
		globalInterfaceInstance->PushError (&st);
	
	terminateExecution = true;
#else		
	char  str[] = "\nError:";
	
		st = st & _String(ReturnCurrentCallStack());
		if (globalErrorFile) 
		{
			fwrite (str, 1, 7, globalErrorFile);
			fwrite (st.getStr(), 1, st.Length(), globalErrorFile);
			fflush(globalErrorFile);
		}
	#if !defined __MAC__ && !defined __WINDOZE__
		#ifdef __HYPHYMPI__
			int     rank;
			MPI_Comm_rank(MPI_COMM_WORLD, &rank);
			_String mpiErrorSend = _String("Received an error state from MPI node ") & (long)rank & '\n' & st;
			
			if (rank > 0)
				MPISendString (mpiErrorSend,0,true);
			else
				printf ("Master node received an error:%s\n", st.sData);
		#else
			printf("Error:");
		#endif
		printf("\n%s\n", st.getStr());
	#endif
	
	#ifdef __MAC__
		Str255 			  err;
		StringToStr255	 (st,err);
		ParamText 	   	 (err,NULL,NULL,NULL);
		Alert 			 (128, (ModalFilterUPP)NULL);
		WritePreferences ();
		SaveConsole		 ();
	#endif
	
	#ifdef __WINDOZE__
		if (st.sLength>255)
			st = st.Cut(0,255);
		WritePreferences();
		WinErrorBox(st,false);
	#endif
	
	#ifdef __HYPHYMPI__
		if (rank==0)
			MPI_Abort (MPI_COMM_WORLD,1);
	#endif
	
	#ifdef __UNIX__
		if (dropIntoDebugMode)
			while (ExpressionCalculator()) ;
	#endif
		GlobalShutdown();
		exit(1);
#endif
}


//_______________________________________________________________________
void	WarnError (_String st)
{
#ifdef  __HEADLESS__
	if (globalInterfaceInstance)
		globalInterfaceInstance->PushError (&st);
	terminateExecution = true;
#else		
	char  str[] = "\nError:";
#ifndef __HYPHY_GTK__
	st = st & _String(ReturnCurrentCallStack());
#endif

	if (globalErrorFile)
	{
		fwrite (str, 1, 7, globalErrorFile);
		fwrite (st.getStr(), 1, st.Length(), globalErrorFile);
		fflush(globalErrorFile);
	}
	
	if (globalMessageFile)
		fprintf (globalMessageFile, "%s\n", st.sData);
#ifndef __MAC__
#ifndef __WINDOZE__
#ifndef __HYPHY_GTK__
	#ifdef __HYPHYMPI__
		int     rank;
		MPI_Comm_rank(MPI_COMM_WORLD, &rank);
		_String mpiErrorSend = _String("Received an error state from MPI node ") & (long)rank & '\n' & st;
		if (rank > 0)
			MPISendString (mpiErrorSend,0,true);
		else
			printf ("Master node received an error:%s\n", st.sData);
	#else
		printf("Error:\n%s\n", st.getStr());
	#endif
#endif
#endif
#endif
#ifdef __MAC__
	if (!skipWarningMessages)
	{
		Str255 err;
		err[0] = st.sLength>255?255:st.sLength;
		memcpy (err+1,st.getStr(),st.sLength>255?255:st.sLength);
		ParamText (err,NULL,NULL,NULL);
		char alertCode;
		#ifndef __OLDMAC__
			#ifdef TARGET_API_MAC_CARBON
				alertCode = Alert (129, (ModalFilterUPP)NULL);
			#else
				alertCode = Alert (129, (RoutineDescriptor*)NULL);
			#endif
		#else
			alertCode = Alert (129, NULL);
		#endif
		terminateExecution = true;
		if (alertCode == 2)
			skipWarningMessages = true;
		else
			if (alertCode == 3)
			{
				WritePreferences();
				SaveConsole();
				//GlobalShutdown(); 
				// graceless exit; no need to clean stuff up
				exit(1);
			}
	}
	return;
		#endif
#ifdef __HYPHY_GTK__
	if (!skipWarningMessages)
	{
		GtkWidget *dialog = gtk_message_dialog_new (
							hyphyConsoleWindow?GTK_WINDOW(gtk_widget_get_ancestor(hyphyConsoleWindow->theWindow,GTK_TYPE_WINDOW)):NULL,
							GTK_DIALOG_MODAL,
							GTK_MESSAGE_WARNING,
							GTK_BUTTONS_NONE,
							"The following error occurred:\n %s",
							st.sData);
							
		gtk_dialog_add_button (GTK_DIALOG(dialog),"Skip Further Messages",2);
		gtk_dialog_add_button (GTK_DIALOG(dialog),"Quit",3);
		gtk_dialog_add_button (GTK_DIALOG(dialog),"OK",1);
		char alertCode = gtk_dialog_run (GTK_DIALOG (dialog));
		gtk_widget_destroy (dialog);

		terminateExecution = true;
		if (alertCode == 2)
			skipWarningMessages = true;
		else
			if (alertCode == 3)
			{
				WritePreferences();
				SaveConsole ();
				GlobalShutdown();
				exit(1);
			}
	}
	return;
#endif
#ifdef __WINDOZE__
	if (!skipWarningMessages)
	{
		if (st.sLength>255)
			st = st.Cut(0,255);
		WinErrorBox(st, true);
		terminateExecution = true;
	}
	return;
#endif
#ifdef __UNIX__
	if (dropIntoDebugMode)
		while (ExpressionCalculator()) ;
#endif
#ifdef __HYPHYMPI__
	if (rank==0)
		MPI_Abort (MPI_COMM_WORLD,1);
#endif
	GlobalShutdown();
	exit(1);
#endif
}
//_______________________________________________________________________

void	_String::StripQuotes (void) 
{	
	if (sLength&&(sData[sLength-1]=='"')&&(sData[0]=='"'))
		Trim(1,sLength-2);
	//if (sData[0]=='"')
	//	*this=Cut(1,-1);
}

//_______________________________________________________________________

bool	_String::IsValidIdentifier (bool strict) 
{	
	if (!sLength) 
		return false;
	
	if (strict)
	{
		if (!(isalpha(sData[0])||(sData[0]=='_')))
			 return false;
	}
	else
		if (!(isalnum (sData[0])||(sData[0]=='_')))
			 return false;
	
	
	for(long p = 1; p<sLength; p++)
	{
		char c = sData[p];
		if (!(isalnum(c)||(c=='_')||(strict&&(c=='.'))))
			return false;
	}
	return true;
}

//_______________________________________________________________________

bool	_String::IsValidRefIdentifier (void) 
{	
	if (sLength<2) return false;
	if (sData[sLength-1]=='&')
		return Cut(0,sLength-2).IsValidIdentifier();
	return false;
}

//_______________________________________________________________________

void	_String::ProcessParameter (void) 
{
	if (Equal(&getDString))
		*this = ReturnDialogInput();
}
		
//_______________________________________________________________________

void	_String::ProcessFileName (bool isWrite, bool acceptStringVars, Ptr theP) 
{
	if (Equal(&getFString)) // prompt user for file
	{
		if (!isWrite)
			*this = ReturnFileDialogInput();
		else
			*this = WriteFileDialogInput ();
			
		ProcessFileName(false,false,theP);
		
		_Variable* pathVar = CheckReceptacle(&useLastFString,empty,false);
		_FString   pathVal (*this);
		pathVar->SetValue (&pathVal);
		return; 
	}

	if (acceptStringVars)
		*this = ProcessLiteralArgument (this,(_VariableContainer*)theP);
	else
		StripQuotes();
	
	if (!sLength) return;


#if (defined __UNIX__ || defined __HYPHY_GTK__) && !defined __MINGW32__
//UNIX LINES HERE
	if (Find('\\')!=-1) // DOS (ASSUME RELATIVE) PATH
		*this = Replace ("\\","/",true);
	else
		if (Find(':')!=-1) // Mac (Assume Relative) PATH
		{
			*this = Replace ("::",":../", true);
			if (getChar(0)==':') 
				Trim(1,-1);
			*this = Replace (':','/',true);
		}
	
	if (getChar(0) != '/') // relative path
	{
		_String* 	lastPath = (_String*)pathNames(pathNames.lLength-1);
		long 		f = lastPath->sLength-2, 
					k = 0;
	
		// check the last stored absolute path and reprocess this relative path into an absolute.
		while (beginswith("../"))
		{
			if ( (f = lastPath->FindBackwards('/',0,f)-1) ==-1) 
				return;
			Trim(3,-1);
			k++;
		}
		if (k==0) 
			*this = *lastPath& (*this);
		else
			*this = lastPath->Cut(0,f+1)& (*this);
			
	}
#endif

#if defined	__WINDOZE__ || defined __MINGW32__ // WIN/DOS code
	if (Find('/')!=-1) // UNIX PATH
	{
		if (getChar(0)=='/')
			Trim(1,-1);
		*this = Replace ("/","\\",true);
	}
	else 
	{	
		if (Find('\\')==-1)
		{
			// check to see if this is a relative path
			*this = Replace ("::",":..\\", true);
			if ((sData[0]==':')) Trim(1,-1);
			*this = Replace (':','\\',true);
		}
	}		
	
	if (Find(':')==-1 && Find("\\\\",0,1)==-1) // relative path
	{
		_String* lastPath = (_String*)pathNames(pathNames.lLength-1);
		long f = lastPath->sLength-2, k = 0;
		// check the last stored absolute path and reprocess this relative path into an absolute.
		while (beginswith("..\\"))
		{
			f = lastPath->FindBackwards('\\',0,f)-1;
			if (f==-1) return;
			Trim(3,-1);
			k++;
		}
		if (k==0) 
		{
			if (lastPath->sData[lastPath->sLength-1]!='\\')
				*this = *lastPath&'\\'& (*this);
			else
				*this = *lastPath& (*this);
		}
		else
			*this = lastPath->Cut(0,f+1)& (*this);

	}
	
	_String escapedString (sLength, true);
	for (long stringIndex = 0; stringIndex < sLength; stringIndex ++)
	{
		char currentChar = getChar (stringIndex);
		switch (currentChar)
		{
			case '\t':
				escapedString << '\\';
				escapedString << 't';
				break;
			case '\n':
				escapedString << '\\';
				escapedString << 'n';
				break;
			default:
				escapedString << currentChar;
		}
	}
	escapedString.Finalize();
	(*this) = escapedString;
	//(*this)=Replace ('\n',"\\n",true);
	//(*this)=Replace ('\t',"\\t",true);
#endif

#ifdef __MAC__
	if (Find('/')!=-1) // UNIX PATH
	{
		bool rootPath = false;
		if (sData[0]=='/')
		{
			rootPath = true;
			*this = volumeName&Cut(1,-1);
		}
		
		if (beginswith("..")) 
			*this = _String('/')&Cut(2,-1);
		
		*this = Replace ("/",":",true);
		*this = Replace ("..","",true);
		
		if (sData[0]!=':' && !rootPath)
			*this = _String(':')&*this;
	}
	else 
	{
		if (Find('\\')!=-1) // DOS PATH (ASSUME PARTIAL)
		{
			if (beginswith("..")) *this = _String('\\')&Cut(2,-1);
			*this = Replace ("\\",":",true);
			*this = Replace ("..","",true);
			if (Find(':')!=-1)
				*this = _String(':')&*this;					
		}
		else // MAC PATH
		{
			if (Find(':')!=-1)
			{
				if (sData[0]!=':')
				{
					if (!beginswith(volumeName))
					{
						if (pathNames.lLength)
						{
							_String* lastPath = (_String*)pathNames(pathNames.lLength-1);
							if (!beginswith (lastPath->Cut (0,lastPath->Find(':'))))
								*this = _String(':')&*this;
						}
						else
							*this = _String(':')&*this;
					}
				}
			}
			else
				*this = _String(':')&*this;
		}
	}		
	
	if (sData[0]==':') // relative path
	{
		long f = -1, k = 0;
		if (pathNames.lLength)
		{
			_String* lastPath = (_String*)pathNames(pathNames.lLength-1);
			// check the last stored absolute path and reprocess this relative path into an absolute.
			while (sData[k]==':')
			{
				f = lastPath->FindBackwards(':',0,f)-1;
				if (f==-1) return;
				k++;
			}
			*this = lastPath->Cut(0,f+1)& Cut(k,-1);
		}
		else
			*this = empty;
	}
#endif
}

//_______________________________________________________________________

_String	_String::PathComposition (_String relPath) 
// compose two UNIX paths (abs+rel)
{

	if (relPath.sData[0]!='/') // relative path
	{
		long f = -1, k = 0;
		f = sLength-2;
		_String result = *this;
		while (relPath.beginswith("../"))
		{
			f = FindBackwards('/',0,f)-1;
			if (f==-1) return empty;
			k++;
		}
		if (k==0) 
		{
			result = result&relPath;
		}
		else
			*this = result&relPath.Cut(k*3,-1);
	}
	else 
	{
		return relPath;
	}
	return empty;
}

//_________________________________________________________________________

char	GetPlatformDirectoryChar (void)
{
	char c = '/';
	#ifdef __MAC__ 
		c = ':';
	#endif
	#if defined __WINDOZE__ || defined __MINGW32__
		c = '\\';
	#endif

	return c;
}

//_______________________________________________________________________

_String	_String::PathSubtraction (_String& p2, char) 
// mac only so far
{
	_String result;
	char separator = GetPlatformDirectoryChar();
		
	//if (pStyle == 0)
	//	  separator = ':';
	long k;
	for (k=0; (k<sLength)&&(k<p2.sLength)&&(sData[k]==p2.sData[k]); k++) ;
	if (k>0)
	{
		while (sData[k]!=separator) k--;
		if (k>0)
		{
			long m=k+1, levels = 0;
			for (;m<sLength;m++)
				if (sData[m]==separator) levels++;
			if (levels)
			{
				result = separator;
				while (levels)
				{
					result.Insert (separator,-1);
					levels--;
				}
			}
			result = result & p2.Cut(k+1,-1);	
			return result;
		}		
	}
	return empty;
}

//_______________________________________________________________________

void	_String::ConvertToAnIdent (bool strict) 
// convert a string to a valid ident
{
	_String * result = new _String ((unsigned long)sLength+1,true);
	if (!result)
		checkPointer (result);
	
	if (sLength)
	{
		if (strict)
		{
			if (((sData[0]>='a')&&(sData[0]<='z'))||((sData[0]>='A')&&(sData[0]<='Z'))||(sData[0]=='_'))
				(*result)<<sData[0];
			else
				(*result)<<'_';
		}
		else
		{
			if (((sData[0]>='a')&&(sData[0]<='z'))||((sData[0]>='A')&&(sData[0]<='Z'))||(sData[0]=='_')||((sData[0]>='0')&&(sData[0]<='9')))
				(*result)<<sData[0];
			else
				(*result)<<'_';		
		}
		
		long l = 0;
		for (long k=1; k<sLength; k++)
		{
			char c = sData[k];
			if (_hyValidIDChars.valid_chars[c])
			{
				(*result)<<c;
				l++;
			}
			else
				if (result->sData[l] != '_')
				{
					(*result)<<'_';
					l++;
				}
		}
	}
	result->Finalize();
	
	CopyDynamicString (result, true);
}

//_______________________________________________________________________

_String	_String::ShortenVarID (_String& containerID)
{
	long matched=-1,
		 upTo = sLength<containerID.sLength?sLength:containerID.sLength,
		 k;
		 
	for (k=0; k<upTo; k++)
	{
		if (sData[k]!=containerID.sData[k])
			break;
		else
			if (sData[k] == '.')
				matched = k;
	}
	
	if ((upTo==containerID.sLength)&&(upTo<sLength)&&(k==upTo)&&(sData[upTo]=='.'))
		matched = upTo;
	
	return Cut (matched+1,-1);
} 

//_______________________________________________________________________

_String		GetVersionString (void)
{
	_String theMessage = _String("HYPHY ")&__KERNEL__VERSION__;
	#ifdef __MP__
		theMessage = theMessage & "(MP)";
	#endif
	#ifdef __HYPHYMPI__
		theMessage = theMessage & "(MPI)";
	#endif
	theMessage = theMessage & " for ";
	#ifdef __MAC__
		theMessage = theMessage & "MacOS";
		#ifdef __HYPHYXCODE__
				theMessage = theMessage & "(Universal Binary)";			
		#else
			#ifdef TARGET_API_MAC_CARBON
				theMessage = theMessage & "(Carbon)";
			#endif
		#endif
	#endif
	#ifdef __WINDOZE__
		theMessage = theMessage & "Windows (Win32)";
	#endif
	#ifdef __UNIX__
		#if !defined __HEADLESS_WIN32__ && ! defined __MINGW32__
			struct		utsname 	 name;
			uname 		(&name);
			theMessage = theMessage & name.sysname & " on " & name.machine;
		#endif
		#if defined __MINGW32__
			theMessage = theMessage & "MinGW ";// " & __MINGW32_VERSION;
		#endif
	#endif
	return theMessage;
}

//_______________________________________________________________________

_String		GetTimeStamp (bool doGMT)
{
	time_t cTime;
	time (&cTime);
	
	if (doGMT)
	{
		tm* gmt = gmtime (&cTime);
		return _String ((long)1900+gmt->tm_year) & '/' & _String (1+(long)gmt->tm_mon) & '/'
			   & _String ((long)gmt->tm_mday) & ' ' & _String ((long)gmt->tm_hour) & ':' & _String ((long)gmt->tm_min);
	}
	
	tm*		localTime = localtime (&cTime);
	
	return	asctime (localTime);
	
}

//_______________________________________________________________________

void		_String::RegExpMatchOnce (_String* pattern, _SimpleList& matchedPairs, bool caseSensitive, bool handleErrors)
{
	if (sLength)
	{
		int errNo = 0;
		Ptr regex = PrepRegExp (pattern, errNo, caseSensitive);
		if (regex)
		{
			RegExpMatch (regex, matchedPairs);
			FlushRegExp (regex);
		}
		else
			if (handleErrors)
				WarnError (GetRegExpError (errNo));		
	}
}

//_______________________________________________________________________

void		_String::RegExpMatch (Ptr pattern, _SimpleList& matchedPairs)
{
	if (sLength)
	{
		regex_t*		regEx = (regex_t*)pattern;
		
		regmatch_t*		matches = new regmatch_t [regEx->re_nsub+1];
		int				errNo = regexec (regEx, sData,regEx->re_nsub+1, matches, 0);
		if (errNo == 0)
		{
			for (long k=0; k<=regEx->re_nsub; k++)
			{
				matchedPairs << matches[k].rm_so;
				matchedPairs << matches[k].rm_eo-1;
			}
		}
		delete			matches;		 		
	}
}

//_______________________________________________________________________

void		_String::RegExpMatchAll (Ptr pattern, _SimpleList& matchedPairs)
{
	if (sLength)
	{
		regex_t*		regEx = (regex_t*)pattern;
		
		regmatch_t*		matches = new regmatch_t [regEx->re_nsub+1];
		int				errNo =  regexec (regEx, sData,regEx->re_nsub+1, matches, 0);
		while (errNo == 0)
		{
			long		 offset = matchedPairs.lLength?matchedPairs.lData[matchedPairs.lLength-1]+1:0;
			
			matchedPairs << matches[0].rm_so+offset;
			matchedPairs << matches[0].rm_eo-1+offset;
			
			offset += matches[0].rm_eo;
			if (offset < sLength)
				errNo =  regexec (regEx, sData+offset ,regEx->re_nsub+1, matches, 0);
			else
				break;
		}
		delete			matches;		 
	}
}

//_______________________________________________________________________

Ptr		 	PrepRegExp			(_String* source, int& errCode, bool caseSensitive)
{
	regex_t  * res = new regex_t;
	checkPointer (res);
	
	errCode = regcomp (res, source->sData, REG_EXTENDED|(caseSensitive?0:REG_ICASE));
	
	if (errCode)
	{
		FlushRegExp ((Ptr)res);
		return nil;
	}
	return (Ptr)res;
}

//_______________________________________________________________________

_String GetRegExpError	 (int error)
{
	char buffer [512];
	buffer[regerror (error, nil, buffer, 511)] = 0;
	return _String("Regular Expression error:")&buffer;
}	

//_______________________________________________________________________

void		 FlushRegExp			(Ptr regExpP)
{
	regex_t*		regEx = (regex_t*)regExpP;
	regfree		   (regEx);
	delete 			regEx;
}	

//_______________________________________________________________________

long	_String::LempelZivProductionHistory (_SimpleList* rec)
{
	if (rec)
		rec->Clear();

	if (sLength == 0)
		return 0;
	
	if (rec)			 
		(*rec) << 0;
	
	long   cp = 1,
		   pH = 1;
	
	while (cp<sLength)
	{
		long maxExtension = 0;
				
		for (long ip = 0; ip < cp; ip++)
		{
			long sp = ip,
				 mp = cp;
				 
			while ((mp<sLength) && (sData[mp] == sData[sp]))
			{
				mp++;
				sp++;
			}
			
			if (mp==sLength)
			{
				maxExtension = sLength-cp;
				break; 
			}
			else
			{
				if ((mp = mp-cp+1)>maxExtension)
				 	maxExtension = mp;
			}
		}
					
		cp = cp+maxExtension;
		if (rec)			 
			(*rec) << cp-1;
		else
			pH ++;
	}		 
	
	if (rec)
		return rec->lLength;
	
	return pH;
}

//_______________________________________________________________________

_String*	_String::Sort (_SimpleList* index)
{
	if (index)
		index->Clear();
	
	if (sLength)
	{
		_SimpleList charList (sLength);
		if (index)
		{
			for (unsigned long i=0; i<sLength; i++)
			{
				charList << sData[i];
				(*index) << i;
			}
			SortLists (&charList, index);
		}
		else
		{
			for (unsigned long i=0; i<sLength; i++)
				charList << sData[i];
			
			charList.Sort();
		}			
		_String * sorted = new _String (sLength);
		checkPointer (sorted);
		for (unsigned long i=0; i<sLength; i++)
			sorted->sData[i] = charList.lData[i];
			
		return sorted;
	}
	
	return new _String;
}

//_______________________________________________________________________

long		_String::ExtractEnclosedExpression (long& from, char open, char close, bool respectQuote, bool respectEscape)
{
	long   currentPosition = from,
		   currentLevel	   = 0;
	
	bool   isQuote = false,
		   doEscape = false;

	while (currentPosition < sLength)
	{
		char thisChar = sData[currentPosition];
		if (!doEscape)
		{
			if (thisChar == '"' && respectQuote && !doEscape)
				isQuote = !isQuote;
			else
				if (thisChar == open && !isQuote)
				{
					currentLevel++;
					if (currentLevel == 1)
						from = currentPosition;
				}
				else
					if (thisChar == close && !isQuote)
					{
						currentLevel--;
						if (currentLevel == 0 && from < currentPosition)
							return currentPosition;
						if (currentLevel < 0)
							return -1;
					}
					else
						if (thisChar == '\\' && respectEscape && isQuote && !doEscape)
							doEscape = true;
		}
		else
			doEscape = false;
		
		currentPosition++;
	}
	
	return -1;
}

//_______________________________________________________________________

long		_String::FindTerminator (long from, _String& terminators)
{
	long   currentPosition  = from,
		   currentCurly     = 0,
		   currentSquare    = 0,
			currentParen	= 0;
	
	bool   isQuote = false,
		  doEscape = false;
		
	while (currentPosition < sLength)
	{
		char thisChar = sData[currentPosition];
		if (!doEscape)
		{
			if (thisChar == '"' && !doEscape)
				isQuote = !isQuote;
			else
			{
				if (!isQuote)
				{
					if (thisChar == '{')
						currentCurly ++;
					else
					if (thisChar == '[')
						currentSquare ++;
					else
					if (thisChar == '(')
						currentParen ++;
					if (currentCurly > 0 && thisChar == '}')
						currentCurly --;
					else
					if (currentSquare > 0 && thisChar == ']')
						currentSquare --;
					else
					if (currentParen > 0 && thisChar == ')')
						currentParen --;
					else
					if (currentParen == 0 && currentSquare == 0 && currentCurly == 0)
						for (long s = 0; s < terminators.sLength; s++)
							if (thisChar == terminators.sData[s])
								return currentPosition;
				}
				else
				{
					if (thisChar == '\\' && isQuote && !doEscape)
						doEscape = true;
				}
			}
		}
		else
			doEscape = false;
		
		currentPosition++;
	}
	
	return -1;
}


//EOF
		
