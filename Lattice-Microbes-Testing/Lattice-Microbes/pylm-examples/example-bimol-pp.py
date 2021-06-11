# pyLM Imports
from pyLM import *
from pyLM.units import *
from pySTDLM import *
# Custom Post-processing Imports
import matplotlib.pyplot as plt
import numpy as np
import scipy
import scipy.optimize

import argparse
ap = argparse.ArgumentParser()
ap.add_argument('-o', '--outputFile', required=True)
args = ap.parse_args()


# Set up logging for pyLM
import logging
LMLogger.setLMLoggerLevel(logging.INFO)

# Create our CME simulation object
sim=CME.CMESimulation()

# define our chemical species
species = ['A', 'B', 'C']
sim.defineSpecies(species)

# Add reactions to the simulation
sim.addReaction(reactant=('A','B'), product='C', rate=1.78e-4)
sim.addReaction(reactant='C', product=('A','B'), rate=3.51e-1)

# Set our initial species counts
sim.addParticles(species='A', count=1000)
sim.addParticles(species='B', count=1000)
sim.addParticles(species='C', count=0)

# Define simulation parameters: run for 10 seconds, saving data every ms
sim.setWriteInterval(ms(1))
sim.setSimulationTime(10)
sim.save(args.outputFile)

# Plot a graph file with the reaction network
NetworkVisualization.plotCMEReactionNetwork(sim, "BimolGraph.gml")

# Run some replicates using the Gillespie solver
numberReplicates=50
sim.run(filename=args.outputFile, method="lm::cme::GillespieDSolver", replicates=numberReplicates)

# Post-Processing commands #
# The following command will compute and plot the average and variance over
#  all replicates for the species specified in the list passed as the second argument.
#  It will create an image as named by the final argument.
PostProcessing.plotAvgVarFromFile(args.outputFile, ['A','B','C'], 'BimolSpeciesTrace.png')


##########################
# Custom Post Processing #
##########################
# Custom post-processing generally begins by getting a handle
#  to the file.  This is accomplished by passing the filename
#  to the function "openLMFile" which is supplied by "PostProcessing".
#  This function does some error checking to make sure the file is
#  generated by LM.
fileHandle=PostProcessing.openLMFile(args.outputFile) # Clean way to open a file for post-processing

# Most often you will need a list of the timesteps.  The following
#  function will extract the timesteps from the first replicate (rep 1)
#  and return it as a list.
timesteps=PostProcessing.getTimesteps(fileHandle)

# The following commands demonstrate how to extract the species
#  trace for the specified molecular species and replicate number
#  These traces will be the same length as the timesteps array.
#  Only one species can be extracted from a single replicate
#  for each call to the function.
speciesTraceA=PostProcessing.getSpecieTrace(fileHandle, 'A', 1)
speciesTraceC=PostProcessing.getSpecieTrace(fileHandle, 'C', 1)
for i in range(1,numberReplicates):
	stA=PostProcessing.getSpecieTrace(fileHandle, 'A', i)
	stC=PostProcessing.getSpecieTrace(fileHandle, 'C', i)
	# The bad way to do it
	for j in range(len(stA)):
		speciesTraceA[j] += stA[j]
		speciesTraceC[j] += stC[j]

# Get averages
#  This is just Python...
for i in range(0,len(speciesTraceA)):
	speciesTraceA[i]/=numberReplicates
	speciesTraceC[i]/=numberReplicates

afinal=speciesTraceA[len(speciesTraceA)-1]

# Fit some curves
#  Fitting some curves using SciPy Curvefit
def f_A(x, a, k1):
	return a*np.exp(-k1*x)+afinal
def f_C(x, a, k1):
	return a*(1.0-np.exp(-k1*x))

popA, popconvA = scipy.optimize.curve_fit(f_A, timesteps, speciesTraceA)
popC, popconvC = scipy.optimize.curve_fit(f_C, timesteps, speciesTraceC)
fitA=[0]*len(timesteps)
fitC=[0]*len(timesteps)
for i in range(len(timesteps)):
	fitA[i]=f_A(timesteps[i],popA[0],popA[1])
	fitC[i]=f_C(timesteps[i],popC[0],popC[1])

# Plot traces
#  Some custom plotting
plt.clf()
plt.plot(timesteps,speciesTraceA, label='Avg. A')
plt.plot(timesteps,speciesTraceC, label='Avg. C')
plt.plot(timesteps,fitA, label='k1=%f'%(popA[1]))
plt.plot(timesteps,fitC, label='k2=%f'%(popC[1]))
plt.legend()
plt.xlabel('Time (s)')
plt.ylabel('Species Count')
plt.savefig('BimolSpeciesFit.png')

# Close the LM File
#  It is very important that if you open an LM file with
#  the function "openLMFile" that it be closed at the
#  end of your post-processing with "closeLMFile".  
#  The function takes the filehandle that is returned 
#  by "openLMFile" as an argument. Also, not that 
#  once this function is called, any function that
#  takes the filehandle as an argument will fail to work
#  as the handle is now stale.  This is a common mistake
#  and if you get crashing, check that you haven't prematurely
#  closed the file.  This function is usually called 
#  last.
PostProcessing.closeLMFile(fileHandle) # Clean up after ourselves

