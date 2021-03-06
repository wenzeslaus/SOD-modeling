#--------------------------------------------------------------------------------
# Name:         SOD_aniso.r
# Purpose:      Lattice-based simulation of the spread of pathogen P. ramorum over a heterogeneous landscape.
# Author:       Francesco Tonini
# Email:        ftonini84@gmail.com
# Created:      01/07/2015
# Copyright:    (c) 2015 by Francesco Tonini
# License:      GNU General Public License (GPL)
# Software:     Tested successfully using R version 3.0.2 (http://www.r-project.org/)
#-----------------------------------------------------------------------------------------------------------------------


set.seed(2000)

##Define the main working directory
##Make sure to specify the appropriate path using either / or \\ to specify the path 
#setwd("path_to_desired_folder")
setwd("D:/TangibleLandscape")

#Path to folders in which you want to save all your vector & raster files
fOutput <- 'output'

##Create a physical copy of the subdirectory folder(s) where you save your output
##If the directory already exists it gives a warning, BUT we can suppress it using showWarnings = FALSE
dir.create(fOutput, showWarnings = FALSE)

##Use an external source file w/ all modules (functions) used within this script. 
##Use FULL PATH if source file is not in the same folder w/ this script
source('./scripts/myfunctions_SOD.r')

##Load all required libraries
print('Loading required libraries...')
load.packages()


###Input simulation parameters:
start <- 2004
end <- 2006
months <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
months_msk <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep")
tstep <- sapply(months, FUN=function(x) paste(x,start:end,sep=''))
tstep <- c(t(s))

##read initial raster (host index) with counts of max available "Susceptible" trees per cell
##counts are integers [0, 100]
Nmax_rast <- raster('./layers/HI_100m.img')
Nmax <- Nmax_rast[]  #integer vector of Smax

#raster resolution
res_win <- res(Nmax_rast)[1]

#empty vector with counts of I (=infected trees)
I_lst <- rep(0, length(Nmax))  #integer

#clone Smax raster to I (=infected trees) raster and spores (=number of spores)
I_rast <- Nmax_rast 

#empty vector with counts of pathogen spores
spores_lst <- rep(0, length(Nmax))  #integer

########################################################
##SOURCES OF INFECTION:
#initial sources of infection (integer between 0 and length(Smax))
inf_src <- 2 #integer

#randomly sample the index of cells to be source of infections
#inf.index <- sample(which(HI.raster[] > 0), size = inf.sources)
inf_idx <- sample(which(Nmax > 0), size = inf_src)

#randomize the initial I (=infected trees) counts (this does NOT have to exceed Nmax)
I_lst[inf_idx] <- sapply(Nmax[inf_idx], FUN=function(x) sample(1:x, size=1)) 
###############################################################################

#Susceptibles = Nmax - Infected 
S_lst <- Nmax - I_lst   #integer vector

#integer matrix with susceptible and infected
susceptible <- matrix(S_lst, ncol=ncol(Nmax_rast), nrow=nrow(Nmax_rast), byrow=T)
infected <- matrix(I_lst, ncol=ncol(Nmax_rast), nrow=nrow(Nmax_rast), byrow=T)


##LOOP for each month (or whatever chosen time unit)
for (tt in tstep){
  
  if (!any(substr(tt,1,3) %in% months_msk)) next
  print(tt)
  
  if (tt == tstep[1]) {
    
    if(!any(S_lst > 0)) stop('Simulation ended. There are no more susceptible trees on the landscape!')
    
    ##CALCULATE OUTPUT TO PLOT:
    # 1) values as % infected
    I_rast[] <- ifelse(I_lst == 0, NA, round(I_lst/Nmax, 1))
    
    # 2) values as number of infected per cell
    #I_rast[] <- ifelse(I_lst == 0, NA, I_lst)    
    
    # 3) values as 0 (non infected) and 1 (infected) cell
    #I_rast[] <- ifelse(I_lst > 0, 1, 0) 
    #I_rast[] <- ifelse(I_lst > 0, 1, NA) 
    
    breakpoints <- c(0, 0.25, 0.5, 0.75, 1)
    colors <- c("yellow","gold","orange","red")
    plot(I_rast, breaks=breakpoints, col=colors, main=tt)
    
    #WRITE TO FILE:
    #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='FLT4S', overwrite=TRUE) # % infected as output
    #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='INT1U', overwrite=TRUE) # nbr. infected hosts as output
    #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='LOG1S', overwrite=TRUE)  # 0=non infected 1=infected output
    
  }else{
       
    #check if there are any susceptible trees left on the landscape (IF NOT continue LOOP till the end)
    if(!any(susceptible > 0)){
      breakpoints <- c(0, 0.25, 0.5, 0.75, 1)
      colors <- c("yellow","gold","orange","red")
      plot(I_rast, breaks=breakpoints, col=colors, main=tt)
      #WRITE TO FILE:
      #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='FLT4S', overwrite=TRUE) # % infected as output
      #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='INT1U', overwrite=TRUE) # nbr. infected hosts as output
      #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='LOG1S', overwrite=TRUE)  # 0=non infected 1=infected output
      next 
    }
    
    #Within each infected cell (I > 0) draw random number of infections ~Poisson(lambda=rate of spore production) for each infected host. 
    #Take SUM for total infections produced by each cell.
    
    #integer vector
    spores_lst[I_lst > 0] <- sapply(I_lst[I_lst > 0], FUN=new.infections.gen, rate=4.4*4)  #4.4 * 4 convert approximately to spores/month
    #integer matrix 
    spores_mat <- matrix(spores_lst, ncol=ncol(Nmax_rast), nrow=nrow(Nmax_rast), byrow=T)
    
    #SPORE DISPERSAL:
    #(SporeDisp2 seems faster in R alone!!)
    
    #out <- SporeDisp(spores_mat, S=susceptible, I=infected, rs=res_win, rtype='Cauchy', scale=20.57, wtype='Uniform')  #C++ functions to CONVERT
    #out <- SporeDisp(spores_mat, S=susceptible, I=infected, rs=res_win, rtype='Cauchy', scale=20.57, wtype='VM', wdir='N', kappa=2)  #C++ functions to CONVERT
    #out <- SporeDisp2(spores_mat, S=susceptible, I=infected, rs=res_win, rtype='Cauchy', scale=20.57, wtype='Uniform')  #C++ functions to CONVERT
    out <- SporeDisp2(spores_mat, S=susceptible, I=infected, rs=res_win, rtype='Cauchy', scale=20.57, wtype='VM', wdir='N', kappa=2)  #C++ functions to CONVERT
    
    susceptible <- out$S 
    infected <- out$I  
    
    I_rast[] <- infected
    I_lst <- I_rast[]
    
    #wipe out spores vector to use in following time steps
    spores_lst <- rep(0, length(Nmax))  #integer
    
    ##CALCULATE OUTPUT TO PLOT:
    # 1) values as % infected
    I_rast[] <- ifelse(I_lst == 0, NA, round(I_lst/Nmax, 1))
    
    # 2) values as number of infected per cell
    #I_rast[] <- ifelse(I_lst == 0, NA, I_lst)    
    
    # 3) values as 0 (non infected) and 1 (infected) cell
    #I_rast[] <- ifelse(I_lst > 0, 1, 0) 
    #I_rast[] <- ifelse(I_lst > 0, 1, NA) 
    
    breakpoints <- c(0, 0.25, 0.5, 0.75, 1)
    colors <- c("yellow","gold","orange","red")
    plot(I_rast, breaks=breakpoints, col=colors, main=tt)
    
    #WRITE TO FILE:
    #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='FLT4S', overwrite=TRUE) # % infected as output
    #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='INT1U', overwrite=TRUE) # nbr. infected hosts as output
    #writeRaster(I_rast, filename=paste('./',fOutput,'/Infected_', tt, '.img',sep=''), format='HFA', datatype='LOG1S', overwrite=TRUE)  # 0=non infected 1=infected output
  }
  
  
}






