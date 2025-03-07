# Purpose: test differences between pairwise genetic distances from two different samples.
# The program compares two samples at the time, but it has the capacity of doing "batches of pairs,"
# as for example when one wishes to test two different regions from a set of patients to see whether
# or not they evolved at different evolutionary rates.
# Written by: EEGiorgi, egiorgi@lanl.gov -- Latest update: 2/23/2011
# Authors: EE Giorgi and T Bhattacharya
# LA-CC-11-024 (2/24/2011)

# INPUT: First, save the present code in a working directory. Create two folders, one labeled "Set1" and
# the second one labeled "Set2." Each set will contain one of the pairs to be compared. Each pair has to
# have the same ID name. So, for example, suppose we wish to test the diversity in env and gag sampled
# from patients CH1, CH2, and CH3. Then we would prepare 6 input files named: CH1-env.dat, CH2-env.dat,
# and CH3-env.dat will be saved in the folder "Set1" and CH1-gag.dat, CH2-gag.dat,and CH3-gag.dat will 
# be saved in the folder "Set2". The program will then match whatever string comes before the "-" character
# between the two sets as the pairs to be compared.

# Each input file should be prepared as follows (no header!):

# column 1: An integer indicating the sequence number [Takes values 1 to the number of sequences for that subject minus 1].
# column 2: An integer indicating the sequence number being compared to the sequence in column 1;
# column 3: Pairwise distance between the two sequences that are indicated in columns 1 and 2. 
# column 4: Sequence length (this is particularly important if the two patients have different sequence lengths).

# if the first sequence is the consensus, then the sequence numbering should start at 0 (0 being the consensus);
# the program will ignore the consensus; 

# See the provided examples for appropriate input files.

# OUTPUT: the program will print the T-statistic and both the Z-test and T-test p-values on the console.


OurVarEst <- function(s11,s12,s21,s22,n1,n2){
	
	temp1 <- 4*((n1*(n1-1)*(n1-2)*(n1-3))^(-1))
	temp2 <- 4*((n2*(n2-1)*(n2-2)*(n2-3))^(-1))
	
	ourv <- temp1*(2*s11+s12)+temp2*(2*s21+s22)
	return(ourv)
	
	}
	
myvarmu <- function(n1, sigm1, sigm2){
	
	temp1 <- 4*((n1*(n1-1)*(n1-2)*(n1-3))^(-1))
	return(temp1*(2*sigm1+sigm2))
	
	}
	
 mynu <- function(ns, sigm1, sigm2){
	
	num <- ((2/((ns-2)*(ns-3)))*(sigm2+2*sigm1))^2
	den1 <- (4*(ns-1)/((ns-2)^2))*((2/((ns-1)*(ns-2)))^2)*((sigm2+sigm1)^2)
	den2 <- ((2*ns)/((ns-3)*(ns-2)^2))*((2/(ns*(ns-2)*(ns-3)))*((ns-4)*sigm2-2*sigm1))^2
	return(num/(den1+den2))
	
	}

#### set-up

args <- commandArgs(trailingOnly = F)
uploadDir <- args[length(args)]
uploadDir <- sub("-","",uploadDir)
print(uploadDir)
set1 <- paste(uploadDir,"/Set1/",sep="")
set2 <- paste(uploadDir,"/Set2/",sep="")
print(set1)
print(set2)
# q(save="no")

infiles <- list.files(pattern=".dat", path=set1) 
pat <- strsplit(infiles, split="-")
npat <- length(infiles)

patients <- vector("character", length=npat)
for(g in 1:npat){ patients[g] <- pat[[g]][1] }


for(k in 1:npat){

print(paste("Patient", patients[k], sep=" ")) 

nbases <- rep(0,2)
nseq <- rep(0,2)
mult <- rep(0,2)
dvec <- vector("list", length=2)
vecone <- vector("list", length=2)
vectwo <- vector("list", length=2)

patinfiles <- rep("", 2)
patinfiles[1] <- paste(set1,list.files(pattern=patients[k], path=set1),sep="")
patinfiles[2] <- paste(set2,list.files(pattern=patients[k], path=set2),sep="")

for(i in 1:2){	
	
   	infile <- patinfiles[i]
	dlist <- scan(infile, what = list("","","",""), flush = TRUE)
	vecone[[i]] <- as.numeric(dlist[[1]])
	vectwo[[i]] <- as.numeric(dlist[[2]])
	nbases[i] <- as.numeric(dlist[[4]])[1]
	dvec[[i]] <- as.numeric(as.vector(dlist[[3]]))
	if(dlist[[1]][1]=="0"){
		only <- which(dlist[[1]]!="0")
		dvec[[i]] <- dvec[[i]][only]
		vecone[[i]] <- vecone[[i]][only]
		vectwo[[i]] <- vectwo[[i]][only]
		}
	nseq[i] <- 1+max(as.numeric(dlist[[1]]))
	mult[i] <- nseq[i]*(nseq[i]-1)*(0.5)
		
}

if(nbases[1] != nbases[2]){ 
	dvec[[1]] <- dvec[[1]]/nbases[1]
	dvec[[2]] <- dvec[[2]]/nbases[2]
	 }

sample1 <- dvec[[1]]
sample2 <- dvec[[2]] ## sample2 is the larger (for computational convenience)

N1 <- nseq[1]
N2 <- nseq[2]

mu1 <- sum(sample1)/length(sample1)
mu2 <- sum(sample2)/length(sample2)

sigma12 <- sum((sample1-mu1)^2)
sigma22 <- sum((sample2-mu2)^2)

#### calculate the two means and the two statistics and then store the p-value
#### need to compute the pairwise distances

sigma11 <-  0 #sample1
sigma21 <-  0 #sample2

for(i in 1:(N1-2)){
	for(j in (i+1):(N1-1)){
		
			d1ij <- sample1[which((vecone[[1]]==i)&(vectwo[[1]]==j))]
			
				for(l in (j+1):N1){
					d1il <- sample1[which((vecone[[1]]==i)&(vectwo[[1]]==l))]
					d1jl <- sample1[which((vecone[[1]]==j)&(vectwo[[1]]==l))]
					sigma11 <- sigma11+(d1ij-mu1)*(d1il-mu1)+(d1ij-mu1)*(d1jl-mu1)+(d1il-mu1)*(d1jl-mu1)
					}
				}
			}

for(i in 1:(N2-2)){
	for(j in (i+1):(N2-1)){
			
			d2ij <- sample2[which((vecone[[2]]==i)&(vectwo[[2]]==j))]
		
				for(l in (j+1):N2){
					d2il <- sample2[which((vecone[[2]]==i)&(vectwo[[2]]==l))]
					d2jl <- sample2[which((vecone[[2]]==j)&(vectwo[[2]]==l))]
					sigma21 <- sigma21+(d2ij-mu2)*(d2il-mu2)+(d2ij-mu2)*(d2jl-mu2)+(d2il-mu2)*(d2jl-mu2)
					}
				}
				
		}

#### T-stats

OurT <- (mu1-mu2)/sqrt(OurVarEst(sigma11,sigma12,sigma21,sigma22,N1,N2))

npooled <- (1/N1 + 1/N2)^(-1)
varmu1 <- myvarmu(N1, sigma11, sigma12)
varmu2 <- myvarmu(N2, sigma21, sigma22)
coeff1 <- varmu1/(varmu1+varmu2)
coeff2 <- varmu2/(varmu1+varmu2)
nu1 <- mynu(N1, sigma11, sigma12)
nu2 <- mynu(N2, sigma21, sigma22)
nu <- ((coeff1^2)*nu1^(-1) + (coeff1^2)*nu2^(-1))^(-1)

OurPval_norm <- 2*(1-pnorm(abs(OurT)))
OurPval <- 2*(1-pt(abs(OurT), df=nu, lower.tail = TRUE))

print(paste("T=", OurT, "df=", nu, sep=" "))
print(paste("Z-test P=", OurPval_norm, sep=" "))
print(paste("T-test P=", OurPval, sep=" "))


}