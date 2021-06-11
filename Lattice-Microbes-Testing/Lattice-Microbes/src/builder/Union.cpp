/*
 * University of Illinois Open Source License
 * Copyright 2014-2018 Luthey-Schulten Group,
 * All rights reserved.
 *
 * Developed by: Luthey-Schulten Group
 *               University of Illinois at Urbana-Champaign
 *               http://www.scs.uiuc.edu/~schulten
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
 * Author(s): Joseph R. Peterson
 */

#include "config.h"
#include "builder/Shape.h"
#include "builder/Union.h"
#include "rdme/Lattice.h"

namespace lm {
    namespace builder {
        
        Union::Union(Shape *s1, Shape *s2, site_t type)
        :Shape(UNION,
               s1->getBoundingBox().joinWith(s2->getBoundingBox()),
               type)
        {
            shape1 = s1;
            shape2 = s2;
        }
        
        Union::~Union()
        {
        }
        
        bool Union::intersects(Shape * query)
        {
            if (!boundingBoxesIntersect(query)) return false;
            
            // Check if either shape intersects
            if(shape1->intersects(query) || shape2->intersects(query))
                return true;
            
            return false;
        }
        
        bool Union::contains(point query)
        {
            if (shape1->contains(query) || shape2->contains(query))
                return true;
            
            return false;
        }
        
        bool Union::contains(Shape * query)
        {
            if (!boundingBoxesIntersect(query)) return false;
            
            if(shape1->contains(query) || shape2->contains(query))
                return true;
            
            return false;
            
        }
        
        double Union::getVolume(bool reintegrate)
        {
            // This uses a Monte-Carlo integrator provided by the Shape base class
            if(!hasBeenIntegrated && !reintegrate) {
                hasBeenIntegrated = true;
                return (storedVolume = this->integrateToPercentThreshold(1.0e-6));
            } else
                return storedVolume;
        }
        
    }
}
