/*
 * University of Illinois Open Source License
 * Copyright 2010 Luthey-Schulten Group,
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
#include <cstdlib>
#include <cstdio>
#include <iostream>
#include <stdint.h>
#include <cuda.h>
#include "lptf/Profile.h"
#include "lm/Cuda.h"
#include "lm/Math.h"
#include "TimingConstants.h"

#define LS_WORDS_PER_SITE               2
#define LS_APRON_SIZE                   1
#define LS_XYZ_WINDOW_X_SIZE            16
#define LS_XYZ_WINDOW_Y_SIZE            6
#define LS_XYZ_WINDOW_Z_SIZE            6
#define LS_XYZ_Z_THREADS                3

#define MPD_MAX_PARTICLE_OVERFLOWS      512
#define MPD_OVERFLOW_LIST_ENTRIES       1+2*MPD_MAX_PARTICLE_OVERFLOWS


#include "lm/rdme/dev/xor_random_dev.cu"
#include "lm/rdme/dev/lattice_sim_3dw_dev.cu"
#include "lm/rdme/dev/byte_diffusion_3dw_dev.cu"

// Allocate the profile space.
PROF_ALLOC;

#define X_SIZE          140
#define Y_SIZE          128
#define Z_SIZE          64
#define PARTICLE_COUNT  216720      //   1 mM

void runTimestep(cudaStream_t stream, void* inLattice, void* outLattice, void* siteOverflowList, uint64_t seed) throw(lm::CUDAException);
__global__ void xyz_kernel(const unsigned int* inLattice, unsigned int* outLattice, const unsigned int gridXSize, const unsigned int latticeXSize, const unsigned int latticeYSize, const unsigned int latticeZSize, const unsigned int latticeXYSize, const unsigned int latticeXYZSize, const unsigned long long timestepHash, unsigned int* siteOverflowList);

int main(int argc, char **argv)
{
    try
    {
        PROF_INIT;
        PROF_BEGIN(PROF_MAIN_RUN);

        // Allocate the cuda resources.
        cudaStream_t stream;
        unsigned int* startLattice;
        unsigned int* startLatticeCounts;
        void* inLattice;
        void* outLattice;
        void* overflowList;
        startLattice = new unsigned int[X_SIZE*Y_SIZE*Z_SIZE*LS_WORDS_PER_SITE];
        startLatticeCounts = new unsigned int[X_SIZE*Y_SIZE*Z_SIZE];
        memset(startLattice, 0, X_SIZE*Y_SIZE*Z_SIZE*LS_WORDS_PER_SITE*sizeof(unsigned int));
        memset(startLatticeCounts, 0, X_SIZE*Y_SIZE*Z_SIZE*sizeof(unsigned int));
        CUDA_EXCEPTION_CHECK(cudaStreamCreate(&stream));
        CUDA_EXCEPTION_CHECK(cudaMalloc(&inLattice, X_SIZE*Y_SIZE*Z_SIZE*LS_WORDS_PER_SITE*sizeof(unsigned int)));
        CUDA_EXCEPTION_CHECK(cudaMalloc(&outLattice, X_SIZE*Y_SIZE*Z_SIZE*LS_WORDS_PER_SITE*sizeof(unsigned int)));
        CUDA_EXCEPTION_CHECK(cudaMalloc(&overflowList, MPD_OVERFLOW_LIST_ENTRIES*sizeof(unsigned int)));

        // Fill in some random particles.
        srand(2010);
        for (unsigned int i=0; i<PARTICLE_COUNT; i++)
        {
            unsigned int r = (unsigned int)((((double)rand())/((double)RAND_MAX))*((double)X_SIZE)*((double)Y_SIZE)*((double)Z_SIZE));
            if (startLatticeCounts[r] < 4)
            {
                ((unsigned char*)&startLattice[r])[startLatticeCounts[r]] = (rand()%255)+1;
                startLatticeCounts[r]++;
            }
            else if (LS_WORDS_PER_SITE >= 2 && startLatticeCounts[r] < 8)
            {
                ((unsigned char*)&startLattice[r+(X_SIZE*Y_SIZE*Z_SIZE)])[startLatticeCounts[r]] = (rand()%255)+1;
                startLatticeCounts[r]++;
            }
            else
            {
                printf("Warning: skipped adding particle to fully occupied site.\n");
            }
        }

        // Start timings the kernels.
        PROF_BEGIN(PROF_SUBMIT_KERNELS);
        PROF_CUDA_START(stream);

        // Launch the kernels.
        int NUM_LAUNCHES=100;
        for (int i=0; i<NUM_LAUNCHES; i++)
        {
            // Reset the memory.
            CUDA_EXCEPTION_CHECK(cudaMemcpy(inLattice, startLattice, X_SIZE*Y_SIZE*Z_SIZE*LS_WORDS_PER_SITE*sizeof(unsigned int), cudaMemcpyHostToDevice));
            CUDA_EXCEPTION_CHECK(cudaMemset(outLattice, 0, X_SIZE*Y_SIZE*Z_SIZE*LS_WORDS_PER_SITE*sizeof(unsigned int)));
            CUDA_EXCEPTION_CHECK(cudaMemset(overflowList, 0, MPD_OVERFLOW_LIST_ENTRIES*sizeof(unsigned int)));

            // Run the timestep.
            PROF_CUDA_BEGIN(PROF_TIMESTEP_RUNNING,stream);
            runTimestep(stream, inLattice, outLattice, overflowList, 1);
            PROF_CUDA_END(PROF_TIMESTEP_RUNNING,stream);
        }

        // Wait for all of the kernels to finish.
        CUDA_EXCEPTION_CHECK(cudaStreamSynchronize(stream));

        // Record the timings.
        PROF_CUDA_FINISH(stream);
        CUDA_EXCEPTION_CHECK(cudaFree(overflowList));
        CUDA_EXCEPTION_CHECK(cudaFree(outLattice));
        CUDA_EXCEPTION_CHECK(cudaFree(inLattice));
        delete[] startLatticeCounts;
        delete[] startLattice;
        CUDA_EXCEPTION_CHECK(cudaStreamDestroy(stream));
        PROF_END(PROF_SUBMIT_KERNELS);

        printf("Profile file saved as: %s\n",PROF_MAKE_STR(PROF_OUT_FILE));
        PROF_END(PROF_MAIN_RUN);
        PROF_WRITE;
        return 0;
    }
    catch (lm::CUDAException& e)
    {
        std::cerr << "CUDA Exception during execution: " << e.what() << std::endl;
    }
    catch (std::exception& e)
    {
        std::cerr << "Exception during execution: " << e.what() << std::endl;
    }
    catch (...)
    {
        std::cerr << "Unknown Exception during execution." << std::endl;
    }
    PROF_END(PROF_MAIN_RUN);
    PROF_WRITE;
    return -1;
}

void runTimestep(cudaStream_t stream, void* inLattice, void* outLattice, void* siteOverflowList, uint64_t seed)
throw(lm::CUDAException)
{
    // Calculate some properties of the lattice.
    const unsigned int latticeXSize = X_SIZE;
    const unsigned int latticeYSize = Y_SIZE;
    const unsigned int latticeZSize = Z_SIZE;
    const unsigned int latticeXYSize = X_SIZE*Y_SIZE;
    const unsigned int latticeXYZSize = X_SIZE*Y_SIZE*Z_SIZE;

    // Execute the kernel for the x direction.
    PROF_CUDA_BEGIN(PROF_XYZ_DIFFUSION,stream);
    unsigned int gridXSize;
    dim3 gridSize, threadBlockSize;
    if (!calculateLaunchParameters(&gridXSize, &gridSize, &threadBlockSize, LS_XYZ_BLOCK_X_SIZE, LS_XYZ_BLOCK_Y_SIZE, LS_XYZ_BLOCK_Z_SIZE, latticeXSize, latticeYSize, latticeZSize, LS_XYZ_X_THREADS, LS_XYZ_Y_THREADS, LS_XYZ_Z_THREADS))
        throw lm::InvalidArgException("Unable to calculate correct launch parameters, the lattice, block, and thread sizes are incompatible.");
    CUDA_EXCEPTION_EXECUTE((xyz_kernel<<<gridSize,threadBlockSize,0,stream>>>((unsigned int*)inLattice, (unsigned int*)outLattice, gridXSize, latticeXSize, latticeYSize, latticeZSize, latticeXYSize, latticeXYZSize, seed, (unsigned int*)siteOverflowList)));
    PROF_CUDA_END(PROF_XYZ_DIFFUSION,stream);
}

__global__ void __launch_bounds__(LS_XYZ_X_THREADS*LS_XYZ_Y_THREADS*LS_XYZ_Z_THREADS,5) xyz_kernel(const unsigned int* inLattice, unsigned int* outLattice, const unsigned int gridXSize, const unsigned int latticeXSize, const unsigned int latticeYSize, const unsigned int latticeZSize, const unsigned int latticeXYSize, const unsigned int latticeXYZSize, const unsigned long long timestepHash, unsigned int* siteOverflowList)
{
    __shared__ unsigned int bx, by, bz;
    calculateBlockIndices(&bx, &by, &bz, gridXSize);

    // Figure out the indices of this thread.
    int blockXIndex, blockYIndex, blockZIndex;
    int latticeXIndex, latticeYIndex, latticeZIndex, latticeIndex;
    unsigned int windowIndex;
    calculateThreadIndices(bx, by, bz, latticeXSize, latticeXYSize, &blockXIndex, &blockYIndex, &blockZIndex, &latticeXIndex, &latticeYIndex, &latticeZIndex, &latticeIndex, &windowIndex);

    ///////////////////////////////////////////
    // Load the lattice into shared memory. //
    ///////////////////////////////////////////

    // Shared memory to store the lattice segment. Each lattice site has four particles, eight bits for each particle.
    __shared__ unsigned int window[LS_XYZ_WINDOW_SIZE*LS_WORDS_PER_SITE];

    // Copy the x window from device memory into shared memory.
    copyXYZWindowFromLattice(inLattice, window, latticeIndex, latticeXIndex, latticeYIndex, latticeZIndex, latticeXSize, latticeYSize, latticeZSize, latticeXYSize, latticeXYZSize, windowIndex);
    __syncthreads();

    ////////////////////////////////////////
    // Make the choice for each particle. //
    ////////////////////////////////////////

    __shared__ unsigned int choices[LS_XYZ_WINDOW_SIZE*LS_WORDS_PER_SITE];

    // Make the choices.
    // Loop through the z planes.
    for (int i=0; i<LS_XYZ_Z_LOOPS; i++)
    {
        // Figure out the new indices for this z loop.
        int loopLatticeIndex = LS_Z_LOOP_LATTICE_INDEX(latticeIndex,i,latticeXYSize);
        unsigned int loopWindowIndex = LS_Z_LOOP_WINDOW_INDEX(windowIndex,i);

        makeDiffusionChoices(window, choices, loopLatticeIndex, loopWindowIndex, timestepHash);
    }
    __syncthreads();

    //////////////////////////////////////////////////////////
    // Create version of the lattice at the next time step. //
    //////////////////////////////////////////////////////////

    // Loop through the z planes.
    for (int i=0; i<LS_XYZ_Z_LOOPS; i++)
    {
        // Figure out the new indices for this z loop.
        int loopBlockZIndex = LS_Z_LOOP_Z_INDEX(blockZIndex,i);
        int loopLatticeIndex = LS_Z_LOOP_LATTICE_INDEX(latticeIndex,i,latticeXYSize);
        unsigned int loopWindowIndex = LS_Z_LOOP_WINDOW_INDEX(windowIndex,i);

        // Construct the new state of each site in the block and save to the lattice.
        if (blockXIndex >= 0 && blockXIndex < LS_XYZ_BLOCK_X_SIZE && blockYIndex >= 0 && blockYIndex < LS_XYZ_BLOCK_Y_SIZE && loopBlockZIndex >= 0 && loopBlockZIndex < LS_XYZ_BLOCK_Z_SIZE)
        {
            performPropagation(outLattice, window, choices, loopLatticeIndex, latticeXYSize, latticeXYZSize, loopWindowIndex, siteOverflowList);
        }
    }
}
