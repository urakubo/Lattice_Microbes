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

#include "TestingHelper.h"
#define BOOST_TEST_MODULE LatticeMicrobe
#include <boost/test/unit_test.hpp>

void cu_CopyYWindowSitesPeriodic(unsigned int * inLattice, unsigned int * outLattice, unsigned int latticeXSize, unsigned int latticeYSize, unsigned int latticeZSize);
void cu_CopyYWindowApronsPeriodic(unsigned int * inLattice, unsigned int * outLattice, unsigned int latticeXSize, unsigned int latticeYSize, unsigned int latticeZSize);

BOOST_AUTO_TEST_SUITE(CopyYWindowPeriodic)

BOOST_AUTO_TEST_CASE(CopyYWindowSitesPeriodic)
{
    unsigned int latticeXSize=128, latticeYSize=96, latticeZSize=64;
    unsigned int latticeXYZSize=latticeXSize*latticeYSize*latticeZSize;
    unsigned int * inLattice = new unsigned int[latticeXSize*latticeYSize*latticeZSize*2];
    unsigned int * outLattice = new unsigned int[latticeXSize*latticeYSize*latticeZSize*2];

    // Test a simple lattice with ones in the first word.
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                inLattice[i] = 1;
                inLattice[i+latticeXYZSize] = 0;
            }
    cu_CopyYWindowSitesPeriodic(inLattice, outLattice, latticeXSize, latticeYSize, latticeZSize);
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                BOOST_REQUIRE_MESSAGE( outLattice[i] == inLattice[i], "Site " << x << "," << y << "," << z << " word 1 was " << outLattice[i] << " expecting " << inLattice[i] );
                BOOST_REQUIRE_MESSAGE( outLattice[i+latticeXYZSize] == inLattice[i+latticeXYZSize], "Site " << x << "," << y << "," << z << " word 2 was " << outLattice[i+latticeXYZSize] << " expecting " << inLattice[i+latticeXYZSize] );
            }

    // Test a simple lattice with ones in both words.
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                inLattice[i] = 1;
                inLattice[i+latticeXYZSize] = 1;
            }
    cu_CopyYWindowSitesPeriodic(inLattice, outLattice, latticeXSize, latticeYSize, latticeZSize);
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                BOOST_REQUIRE_EQUAL( outLattice[i], inLattice[i] );
                BOOST_REQUIRE_EQUAL( outLattice[i+latticeXYZSize], inLattice[i+latticeXYZSize] );
            }

    // Test a lattice with the x,y,z in the first word and z,x,y in the second.
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                inLattice[i] = x | (y<<8) | (z<<16);
                inLattice[i+latticeXYZSize] = z | (x<<8) | (y<<16);
            }
    cu_CopyYWindowSitesPeriodic(inLattice, outLattice, latticeXSize, latticeYSize, latticeZSize);
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                BOOST_REQUIRE_EQUAL( outLattice[i], inLattice[i] );
                BOOST_REQUIRE_EQUAL( outLattice[i+latticeXYZSize], inLattice[i+latticeXYZSize] );
            }

    delete[] outLattice;
    delete[] inLattice;
}

BOOST_AUTO_TEST_CASE(CopyYWindowApronsPeriodic)
{
    unsigned int latticeXSize=384, latticeYSize=96, latticeZSize=64;
    unsigned int latticeXYZSize=latticeXSize*latticeYSize*latticeZSize;
    unsigned int * inLattice = new unsigned int[latticeXSize*latticeYSize*latticeZSize*2];
    unsigned int * outLattice = new unsigned int[latticeXSize*latticeYSize*latticeZSize*2];

    // Test a lattice with the 0 in the first word and 0 in the second to make sure we get the lattice boundaries correct.
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                inLattice[i] = 0;
                inLattice[i+latticeXYZSize] = 0;
            }
    cu_CopyYWindowApronsPeriodic(inLattice, outLattice, latticeXSize, latticeYSize, latticeZSize);
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                BOOST_REQUIRE_MESSAGE( outLattice[i] == 0, "Site " << x << "," << y << "," << z << " word 1 was " << outLattice[i] << " expecting " << 0 );
                BOOST_REQUIRE_MESSAGE( outLattice[i+latticeXYZSize] == 0, "Site " << x << "," << y << "," << z << " word 2 was " << outLattice[i+latticeXYZSize] << " expecting " << 0 );
            }

    // Test a lattice with the x,y,z in the first word and z,x,y in the second.
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                inLattice[i] = x | (y<<10) | (z<<20);
                inLattice[i+latticeXYZSize] = z | (x<<10) | (y<<20);
            }
    cu_CopyYWindowApronsPeriodic(inLattice, outLattice, latticeXSize, latticeYSize, latticeZSize);
    int apronSize=3;
    for (unsigned int z=0; z<latticeZSize; z++)
        for (unsigned int y=0; y<latticeYSize; y++)
            for (unsigned int x=0; x<latticeXSize; x++)
            {
                unsigned int i = z*latticeXSize*latticeYSize + y*latticeXSize + x;
                if (y == 0 || y == 1 || y == 2)
                {
                    BOOST_REQUIRE_MESSAGE( outLattice[i] == ((x) | ((y+latticeYSize-apronSize)<<10) | (z<<20)), "Site " << x << "," << y << "," << z << " word 1 was " << outLattice[i] << " expecting " << ((x) | ((y+latticeYSize-apronSize)<<10) | (z<<20)) );
                    BOOST_REQUIRE_MESSAGE( outLattice[i+latticeXYZSize] == (z | ((x)<<10) | ((y+latticeYSize-apronSize)<<20)), "Site " << x << "," << y << "," << z << " word 2 was " << outLattice[i+latticeXYZSize] << " expecting " << (z | ((x)<<10) | ((y+latticeYSize-apronSize)<<20)) );
                }
                else if (y == (latticeYSize-3) || y == (latticeYSize-2) || y == (latticeYSize-1))
                {
                    BOOST_REQUIRE_MESSAGE( outLattice[i] == ((x) | ((y-latticeYSize+apronSize)<<10) | (z<<20)), "Site " << x << "," << y << "," << z << " word 1 was " << outLattice[i] << " expecting " << ((x) | ((y-latticeYSize+apronSize)<<10) | (z<<20)) );
                    BOOST_REQUIRE_MESSAGE( outLattice[i+latticeXYZSize] == (z | ((x)<<10) | ((y-latticeYSize+apronSize)<<20)), "Site " << x << "," << y << "," << z << " word 2 was " << outLattice[i+latticeXYZSize] << " expecting " << (z | ((x)<<10) | ((y-latticeYSize+apronSize)<<20)) );
                }
                else if (y%8 == 5 || y%8 == 6 || y%8 == 7)
                {
                    BOOST_CHECK_MESSAGE( outLattice[i] == ((x) | ((y+apronSize)<<10) | (z<<20)), "Site " << x << "," << y << "," << z << " word 1 was " << outLattice[i] << " expecting " << ((x) | ((y+apronSize)<<10) | (z<<20)) );
                    BOOST_REQUIRE_MESSAGE( outLattice[i+latticeXYZSize] == (z | ((x)<<10) | ((y+apronSize)<<20)), "Site " << x << "," << y << "," << z << " word 2 was " << outLattice[i+latticeXYZSize] << " expecting " << (z | ((x)<<10) | ((y+apronSize)<<20)) );
                }
                else if (y%8 == 0 || y%8 == 1 || y%8 == 2)
                {
                    BOOST_CHECK_MESSAGE( outLattice[i] == ((x) | ((y-apronSize)<<10) | (z<<20)), "Site " << x << "," << y << "," << z << " word 1 was " << outLattice[i] << " expecting " << ((x) | ((y-apronSize)<<10) | (z<<20)) );
                    BOOST_REQUIRE_MESSAGE( outLattice[i+latticeXYZSize] == (z | ((x)<<10) | ((y-apronSize)<<20)), "Site " << x << "," << y << "," << z << " word 2 was " << outLattice[i+latticeXYZSize] << " expecting " << (z | ((x)<<10) | ((y-apronSize)<<20)) );
                }
                else
                {
                    BOOST_REQUIRE_MESSAGE( outLattice[i] == 0, "Site " << x << "," << y << "," << z << " word 1 was " << outLattice[i] << " expecting " << 0 );
                    BOOST_REQUIRE_MESSAGE( outLattice[i+latticeXYZSize] == 0, "Site " << x << "," << y << "," << z << " word 2 was " << outLattice[i+latticeXYZSize] << " expecting " << 0 );
                }
            }
}
BOOST_AUTO_TEST_SUITE_END()
