-- // ----------------------------------------------------------------------------
-- //
-- //
-- // OpenSteer -- Steering Behaviors for Autonomous Characters
-- //
-- // Copyright (c) 2002-2005, Sony Computer Entertainment America
-- // Original author: Craig Reynolds <craig_reynolds@playstation.sony.com>
-- //
-- // Permission is hereby granted, free of charge, to any person obtaining a
-- // copy of this software and associated documentation files (the "Software"),
-- // to deal in the Software without restriction, including without limitation
-- // the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- // and/or sell copies of the Software, and to permit persons to whom the
-- // Software is furnished to do so, subject to the following conditions:
-- //
-- // The above copyright notice and this permission notice shall be included in
-- // all copies or substantial portions of the Software.
-- //
-- // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
-- // THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- // FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- // DEALINGS IN THE SOFTWARE.
-- //
-- //
-- // ----------------------------------------------------------------------------
-- //
-- //
-- // Color class and predefined colors.
-- //
-- // May 05, 2005 bk:  created 
-- //
-- //
-- // ----------------------------------------------------------------------------

-- // Forward declaration. Full declaration in Vec3.h

local veclib = require("opensteer.os-vec")
local osmath, osvec, Vec3 = veclib.osmath, veclib.osvec, veclib.vec3

local oscolor = {}
    
local Color = function( rValue, gValue, bValue, aValue )
    
    aValue = aValue or 1.0

    local self = {}

    self.greyValue = rValue 

    self.r_ = rValue
    self.g_ = gValue
    self.b_ = bValue
    self.a_ = aValue
    
    self.r = function() return self.r_ end
    self.g = function() return self.g_ end
    self.b = function() return self.b_ end
    self.a = function() return self.a_ end
        
    self.setR = function( value ) self.r_ = value end
    self.setG = function( value ) self.g_ = value end
    self.setB = function( value ) self.b_ = value end
	self.setA = function( value ) self.a_ = value or 1.0 end
    
    self.set = function( r, g, b, a )
        self.r_ = r 
        self.g_ = g
        self.b_ = b 
        self.a_ = a or 1.0
    end 

    self.convertToVec3 = function() 
        return osvec.Vec3Set(self.r_, self.g_, self.b_)
    end 
    
-- // this is necessary so that graphics API's such as DirectX
-- // requiring a pointer to colors can do their conversion
-- // without a lot of copying.
	self.colorFloatArray = function() return {self.r_, self.g_, self.b_, self.a_} end

    self.add = function( other ) 
        self.r_ = self.r_ + other.r_
        self.g_ = self.g_ + other.g_
        self.b_ = self.b_ + other.b_
        self.a_ = self.a_ + other.a_
    end 

-- /**
-- * @todo What happens if color components become negative?
-- */
    self.sub = function( other )
        self.r_ = self.r_ - other.r_
        self.g_ = self.g_ - other.g_
        self.b_ = self.b_ - other.b_
        self.a_ = self.a_ - other.a_
    end
        
-- /**
-- * @todo What happens if color components become negative?
-- */
    self.mult = function( factor )
        self.r_ = self.r_ * factor
        self.g_ = self.g_ * factor
        self.b_ = self.b_ * factor
        self.a_ = self.a_ * factor
    end 
        
-- /**
-- * @todo What happens if color components become negative?
-- */
    self.div = function( factor )
        self.r_ = self.r_ / factor
        self.g_ = self.g_ / factor
        self.b_ = self.b_ / factor
        self.a_ = self.a_ / factor
    end 
        
        
	-- // provided for API's which require four components        
    return self
end    
    
oscolor.Add = function( lhs, rhs )
    local newcol = Color(lhs.r_, lhs.g_, lhs.b_, lhs.a_)
    newcol.add( rhs )
    return newcol
end

oscolor.Sub = function( lhs, rhs )
    local newcol = Color(lhs.r_, lhs.g_, lhs.b_, lhs.a_)
    newcol.sub( rhs )
    return newcol 
end     

oscolor.Mult = function( lhs, factor )
    local newcol = Color(lhs.r_, lhs.g_, lhs.b_, lhs.a_)
    newcol.mult( factor )
    return newcol 
end     

oscolor.MultColor = function( lhs, rhs )
    local newcol = Color(lhs.r_ * rhs.r_, lhs.g_ * rhs.g_, lhs.b_ * rhs.b_, lhs.a_ * rhs.a_)
    return newcol 
end     

oscolor.Div = function( lhs, factor )
    local newcol = Color(lhs.r_, lhs.g_, lhs.b_, lhs.a_)
    newcol.div( factor )
    return newcol 
end     

oscolor.grayColor = function(value )
    return Color( value, value, value )
end

oscolor.Set = function( rValue, gValue, bValue, aValue) 
    return Color(rValue, gValue, bValue, aValue)
end 
    

oscolor.gBlack = Color(0.0, 0.0, 0.0)
oscolor.gWhite = Color(1.0, 1.0, 1.0)

oscolor.gRed = Color(1.0, 0.0, 0.0) 
oscolor.gGreen = Color(0.0, 1.0, 0.0)
oscolor.gBlue = Color(0.0, 0.0, 1.0)
oscolor.gYellow = Color(1.0, 1.0, 0.0)
oscolor.gCyan = Color(0.0, 1.0, 1.0)
oscolor.gMagenta = Color(1.0, 0.0, 1.0)
oscolor.gOrange = Color(1.0, 0.5, 0.0)

oscolor.gDarkRed = Color(0.5, 0.0, 0.0)
oscolor.gDarkGreen = Color(0.0, 0.5, 0.0)
oscolor.gDarkBlue = Color(0.0, 0.0, 0.5)
oscolor.gDarkYellow = Color(0.5, 0.5, 0.0)
oscolor.gDarkCyan = Color(0.0, 0.5, 0.5)
oscolor.gDarkMagenta = Color(0.5, 0.0, 0.5)
oscolor.gDarkOrange = Color(0.5, 0.25, 0.0)

oscolor.gGray10 = oscolor.grayColor(0.1)
oscolor.gGray20 = oscolor.grayColor(0.2)
oscolor.gGray30 = oscolor.grayColor(0.3)
oscolor.gGray40 = oscolor.grayColor(0.4)
oscolor.gGray50 = oscolor.grayColor(0.5)
oscolor.gGray60 = oscolor.grayColor(0.6)
oscolor.gGray70 = oscolor.grayColor(0.7)
oscolor.gGray80 = oscolor.grayColor(0.8)
oscolor.gGray90 = oscolor.grayColor(0.9)

return {
    oscolor = oscolor,
    Color = Color, 
}