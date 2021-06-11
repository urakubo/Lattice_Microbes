/*
 * University of Illinois Open Source License
 * Copyright 2008-2018 Luthey-Schulten Group,
 * All rights reserved.
 * 
 * Developed by: Luthey-Schulten Group
 * 			     University of Illinois at Urbana-Champaign
 * 			     http://www.scs.uiuc.edu/~schulten
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the Software), to deal with 
 * the Software without restriction, including without limitation the rights to 
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
 * of the Software, and to permit persons to whom the Software is furnished to 
 * do so, subject to the following conditions:
 * 
 * - Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimers.
 * 
 * - Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimers in the documentation 
 * and/or other materials provided with the distribution.
 * 
 * - Neither the names of the Luthey-Schulten Group, University of Illinois at
 * Urbana-Champaign, nor the names of its contributors may be used to endorse or
 * promote products derived from this Software without specific prior written
 * permission.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL 
 * THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
 * OTHER DEALINGS WITH THE SOFTWARE.
 *
 * Author(s): Elijah Roberts
 */

#include "config.h"
#include "core/Types.h"
#include "core/Exceptions.h"
#include "rdme/ByteLattice.h"
#include "rdme/CudaByteLattice.h"
#include "rdme/Lattice.h"

namespace lm {
namespace rdme {

CudaByteLattice::CudaByteLattice(lattice_coord_t size, si_dist_t latticeSpacing, uint particlesPerSite)
:ByteLattice(size,latticeSpacing,particlesPerSite),cudaParticlesCurrent(0),cudaParticlesSize(0),cudaSiteTypesSize(0),cudaSiteTypes(NULL),isGPUMemorySynched(false)
{
    // Initialize the pointers.
    cudaParticles[0] = NULL;
    cudaParticles[1] = NULL;

    allocateCudaMemory();
}

CudaByteLattice::CudaByteLattice(lattice_size_t xSize, lattice_size_t ySize, lattice_size_t zSize, si_dist_t latticeSpacing, uint particlesPerSite)
:ByteLattice(xSize,ySize,zSize,latticeSpacing,particlesPerSite),cudaParticlesCurrent(0),cudaParticlesSize(0),cudaSiteTypesSize(0),cudaSiteTypes(NULL),isGPUMemorySynched(false)
{
    // Initialize the pointers.
    cudaParticles[0] = NULL;
    cudaParticles[1] = NULL;

    allocateCudaMemory();
}

CudaByteLattice::~CudaByteLattice()
{
    deallocateCudaMemory();
}

void CudaByteLattice::allocateCudaMemory()
{
    size_t free=0, total=0;

    // Allocate memory on the CUDA device.
    cudaParticlesSize=numberSites*wordsPerSite*sizeof(uint32_t);
	try
	{
		CUDA_EXCEPTION_CHECK(cudaMalloc(&cudaParticles[0], cudaParticlesSize)); //TODO: track memory usage.
		CUDA_EXCEPTION_CHECK(cudaMalloc(&cudaParticles[1], cudaParticlesSize)); //TODO: track memory usage.
	}
	catch(CUDAException e)
	{
		CUDA_EXCEPTION_CHECK(cudaMemGetInfo(&free, &total));
		printf("Failed to allocate %zu bytes for particle lattice, %zu available out of %zu\n", cudaParticlesSize*2U, free, total);
		throw e;
	}
    cudaSiteTypesSize=numberSites*sizeof(uint8_t);
	try
	{
		CUDA_EXCEPTION_CHECK(cudaMalloc(&cudaSiteTypes, cudaSiteTypesSize)); //TODO: track memory usage.
	}
	catch(CUDAException e)
	{
		CUDA_EXCEPTION_CHECK(cudaMemGetInfo(&free, &total));
		printf("Failed to allocate %zu bytes for site lattice, %zu available out of %zu\n", cudaSiteTypesSize, free, total);
		throw e;
	}
	
}

void CudaByteLattice::deallocateCudaMemory()
{
    // If we have any allocated device memory, free it.
    if (cudaParticles[0] != NULL)
    {
        CUDA_EXCEPTION_CHECK(cudaFree(cudaParticles[0])); //TODO: track memory usage.
        cudaParticles[0] = NULL;
    }
    if (cudaParticles[1] != NULL)
    {
        CUDA_EXCEPTION_CHECK(cudaFree(cudaParticles[1])); //TODO: track memory usage.
        cudaParticles[1] = NULL;
    }
    cudaParticlesSize = 0;
    if (cudaSiteTypes != NULL)
    {
        CUDA_EXCEPTION_CHECK(cudaFree(cudaSiteTypes)); //TODO: track memory usage.
        cudaSiteTypes = NULL;
        cudaSiteTypesSize = 0;
    }
}

void CudaByteLattice::copyToGPU()
{
    CUDA_EXCEPTION_CHECK(cudaMemcpy(cudaParticles[cudaParticlesCurrent], particles, cudaParticlesSize, cudaMemcpyHostToDevice));
    CUDA_EXCEPTION_CHECK(cudaMemcpy(cudaSiteTypes, siteTypes, cudaSiteTypesSize, cudaMemcpyHostToDevice));
    isGPUMemorySynched = true;
}

void CudaByteLattice::copyFromGPU()
{
	CUDA_EXCEPTION_CHECK(cudaMemcpy(particles, cudaParticles[cudaParticlesCurrent], cudaParticlesSize, cudaMemcpyDeviceToHost));
    CUDA_EXCEPTION_CHECK(cudaMemcpy(siteTypes, cudaSiteTypes, cudaSiteTypesSize, cudaMemcpyDeviceToHost));
	isGPUMemorySynched = true;
}


void CudaByteLattice::getSiteLatticeView(uint8_t **siteLattice, int *Nz, int *Ny, int *Nx) {
    ByteLattice::getSiteLatticeView(siteLattice, Nz, Ny, Nx);
    // isGPUMemorySynched = false;
}

void CudaByteLattice::getParticleLatticeView(uint8_t **particleLattice, int *Nw, int *Nz, int *Ny, int *Nx, int *Np) {
    ByteLattice::getParticleLatticeView(particleLattice, Nw,  Nz, Ny, Nx, Np);
    // isGPUMemorySynched = false;
}


void * CudaByteLattice::getGPUMemorySrc()
{
    return cudaParticles[cudaParticlesCurrent];
}

void * CudaByteLattice::getGPUMemoryDest()
{
    return cudaParticles[cudaParticlesCurrent==0?1:0];
}

void CudaByteLattice::swapSrcDest()
{
    cudaParticlesCurrent = cudaParticlesCurrent==0?1:0;
}

void * CudaByteLattice::getGPUMemorySiteTypes()
{
    return cudaSiteTypes;
}

void CudaByteLattice::setSiteType(lattice_size_t x, lattice_size_t y, lattice_size_t z, site_t site)
{
    ByteLattice::setSiteType(x,y,z,site);
    isGPUMemorySynched = false;
}

void CudaByteLattice::addParticle(lattice_size_t x, lattice_size_t y, lattice_size_t z, particle_t particle)
{
    ByteLattice::addParticle(x,y,z,particle);
	isGPUMemorySynched = false;
}

void CudaByteLattice::removeParticles(lattice_size_t x,lattice_size_t y,lattice_size_t z)
{
    ByteLattice::removeParticles(x,y,z);
    isGPUMemorySynched = false;
}

void CudaByteLattice::setSiteType(lattice_size_t index, site_t site)
{
    ByteLattice::setSiteType(index,site);
    isGPUMemorySynched = false;
}

void CudaByteLattice::addParticle(lattice_size_t index, particle_t particle)
{
    ByteLattice::addParticle(index,particle);
	isGPUMemorySynched = false;
}

void CudaByteLattice::removeParticles(lattice_size_t index)
{
    ByteLattice::removeParticles(index);
    isGPUMemorySynched = false;
}

void CudaByteLattice::removeAllParticles()
{
    ByteLattice::removeAllParticles();
	isGPUMemorySynched = false;
}

void CudaByteLattice::setFromRowMajorByteData(void * buffer, size_t bufferSize)
{
    ByteLattice::setFromRowMajorByteData(buffer, bufferSize);
    isGPUMemorySynched = false;
}

}
}
