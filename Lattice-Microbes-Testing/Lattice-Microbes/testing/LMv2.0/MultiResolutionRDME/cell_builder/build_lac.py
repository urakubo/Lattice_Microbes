import sys
import os

if len(sys.argv) != 3:
    quit("Usage: output_filename invivo_fraction")

outputFilename=sys.argv[1]
inVivoVolumeFraction=float(sys.argv[2])

xlen=1024e-9
ylen=1024e-9
zlen=2048e-9
cellRadius=4e-7
cellLength=2e-6
membraneThickness=32e-9
builder=LatticeBuilder(xlen,ylen,zlen,6.25e-9,1,0)
extraCellularType=0
extraCellular=Cuboid(point(0.0,0.0,0.0), point(xlen,ylen,zlen), extraCellularType)
builder.addRegion(extraCellular)
membraneType=2
membrane=CapsuleShell(point(xlen/2.0,ylen/2.0,((zlen-cellLength)/2)+cellRadius), point(xlen/2.0,ylen/2.0,((zlen-cellLength)/2)+cellLength-cellRadius), cellRadius-membraneThickness, cellRadius, membraneType)
builder.addRegion(membrane)
cytoplasmType=1
cytoplasm=Capsule(point(xlen/2.0,ylen/2.0,((zlen-cellLength)/2)+cellRadius), point(xlen/2.0,ylen/2.0,((zlen-cellLength)/2)+cellLength-cellRadius), cellRadius-membraneThickness, cytoplasmType)
builder.addRegion(cytoplasm)
obstacleType=3

# Build the cell.
if inVivoVolumeFraction > 0.0:
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.357510138,10.4e-9,21,cytoplasmType);
    '''builder.fillWithRandomSpheres(inVivoVolumeFraction*0.371384803, 5.2e-9,22,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.013434414, 4.3e-9,23,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.006199286, 4.1e-9,24,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.034785156, 4.0e-9,25,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.025040418, 3.8e-9,26,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.018438140, 3.5e-9,27,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.050035776, 3.4e-9,28,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.039932564, 3.0e-9,29,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.040452644, 2.7e-9,30,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.035473775, 2.3e-9,31,cytoplasmType);
    builder.fillWithRandomSpheres(inVivoVolumeFraction*0.007312886, 1.7e-9,32,cytoplasmType);'''

# Add the particles.
builder.addParticles(4, 1, 9);
builder.addParticles(8, 2, 30);
builder.addParticles(10, 1, 2408);
builder.addParticles(11, 0, 2408);

if not os.path.isfile(outputFilename):
    SimulationFile.create(outputFilename)

sim=SimulationFile(outputFilename)
spatialModel=SpatialModel()
builder.getSpatialModel(spatialModel)
sim.setSpatialModel(spatialModel)

# Discretize the lattice.
diffusionModel=DiffusionModel()
sim.getDiffusionModel(diffusionModel)
lattice = ByteLattice(diffusionModel.lattice_x_size(), diffusionModel.lattice_y_size(), diffusionModel.lattice_z_size(), diffusionModel.lattice_spacing(), diffusionModel.particles_per_site())
builder.discretizeTo(lattice, obstacleType, inVivoVolumeFraction*0.357510138)

# Add the operator site.
lattice.addParticle(32,32,64,1+1)

# Write out the model and lattice.
sim.setDiffusionModel(diffusionModel)
sim.setDiffusionModelLattice(diffusionModel, lattice)

sim.close()

