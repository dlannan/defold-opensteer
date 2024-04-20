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
-- // Multiple pursuit (for testing pursuit)
-- //
-- // 08-22-02 cwr: created 
-- //
-- //
-- // ----------------------------------------------------------------------------

local tinsert = table.insert

local osdebug = require("opensteer.os-debug")

require("opensteer.os-lq")
local veclib = require("opensteer.os-vec")
local osmath, osvec, Vec3 = veclib.osmath, veclib.osvec, veclib.vec3
local colorlib = require("opensteer.os-color")
local oscolor, Color = colorlib.oscolor, colorlib.Color

local SteerLibrary = require("opensteer.os-library")
local LocalSpace = require("opensteer.os-localspace")
local SimpleVehicle = require("opensteer.os-simplevehicle")

-- // ----------------------------------------------------------------------------
-- // This PlugIn uses two vehicle types: MpWanderer and MpPursuer.  They have
-- // a common base class, MpBase, which is a specialization of SimpleVehicle.

local MpBase = function()

    local self = {}
    -- // type for a group of Pedestrians
    -- //typedef std::vector<Pedestrian*> groupType;
    self.mover = SimpleVehicle()
    -- // for draw method
    self.bodyColor = osdebug.debugdraw.COLORS.blue

    self.trail = osdebug.TrailTrace(10, osdebug.debugdraw.COLORS.blue)

    -- // reset state
    self.reset = function()
        self.mover.reset ()          -- // reset the vehicle 
        self.mover.setSpeed (0)      -- // speed along Forward direction.
        self.mover.setMaxForce (5.0) -- // steering force is clipped to this magnitude
        self.mover.setMaxSpeed (3.0) -- // velocity is clipped to this magnitude
        self.trail.clearTrailHistory()    -- // prevent long streaks due to teleportation 
    end

    -- // draw into the scene
    self.draw = function()
        osdebug.drawBasic2dCircularVehicle (self.mover, self.bodyColor)
        self.trail.draw()
    end

    self.reset()
    return self
end


local MpWanderer = function() 

    local self = {} 

    self.mpbase = MpBase()
    self.mover = self.mpbase.mover

    -- // reset state
    self.reset = function()

        self.mpbase.reset()
        self.mpbase.bodyColor = vmath.vector4(0.4, 1.0, 0.4, 1.0) -- // greenish
    end

    -- // one simulation step
    self.update = function(currentTime,  elapsedTime)
    
        local wander2d = self.mover.steerForWander(elapsedTime)
        wander2d.setYtoZero()
        local steer = self.mover.forward().add(wander2d.mult(3))
        self.mover.applySteeringForce (steer, elapsedTime)

        -- // for annotation
        self.mpbase.trail.recordTrailVertex (currentTime, self.mover.position())
    end

    self.draw = function() self.mpbase.draw() end

    self.reset()
    return self
end 


local MpPursuer = function( pd, w_ ) 

    local self = {} 

    self.mpbase = MpBase()
    self.mover = self.mpbase.mover
    self.mpbase.trail.color = osdebug.debugdraw.COLORS.orange
    -- // constructor

    self.wanderer = w_ 

    -- // allocate one and share amoung instances just to save memory usage
    -- // (change to per-instance allocation to be more MP-safe)
    self.neighbors = {}

    -- // a pointer to this boid's interface object for the proximity database
    self.proximityToken = nil

    -- // switch to new proximity database -- just for demo purposes
    self.newToken = function( newpd )

        -- // delete this boid's token in the old proximity database
        if(self.proximityToken) then self.proximityToken = nil end

        -- // allocate a token for this boid in the proximity database
        self.proximityToken = newpd.allocateToken(self)
    end

    -- // one simulation step
    self.update = function (currentTime, elapsedTime)

        -- // notify proximity database that our position has changed
        self.proximityToken.updateForNewPosition( self.mover.position() )

        -- // when pursuer touches quarry ("wanderer"), reset its position
        local d = osvec.Vec3_distance (self.mover.position(), self.wanderer.mover.position())
        local r = self.mover.radius() + self.wanderer.mover.radius()
        if (d < r) then self.reset(); return end

        local maxTime = 20 -- // xxx hard-to-justify value
        local force = self.mover.steerForPursuit(self.wanderer.mover, maxTime)
        local steer = self.determineCombinedSteering( force, elapsedTime) 
        self.mover.applySteeringForce( steer, elapsedTime )
        
        -- // for annotation
        self.mpbase.trail.recordTrailVertex (currentTime, self.mover.position())
    end

    -- // compute combined steering force: move forward, avoid obstacles
    -- // or neighbors if needed, otherwise follow the path and wander
    self.determineCombinedSteering = function(steeringForce, elapsedTime) 

        -- // otherwise consider avoiding collisions with others
        local collisionAvoidance = osvec.Vec3Set(0.0, 0.0, 0.0)
        local caLeadTime = 5.0
        local maxRadius = 2.0 * self.mover.maxSpeed()

        self.neighbors = self.proximityToken.findNeighbors(self.mover.position(), maxRadius)
        
        collisionAvoidance = (self.mover.steerToAvoidNeighbors(caLeadTime, self.neighbors)).mult(5.0)
--                pprint("Avoiding.."..collisionAvoidance.x.."  "..collisionAvoidance.y.."  "..collisionAvoidance.z )

        -- // if collision avoidance is needed, do it
        if (collisionAvoidance.neq(osvec.Vec3_zero)) then
            steeringForce = steeringForce.add(collisionAvoidance)
            osdebug.drawVector(self.mover.position(), steeringForce, 3.0)
        else 
            steeringForce = steeringForce.add( self.mover.steerForWander(elapsedTime))
        end
        --end

        -- // return steering constrained to global XZ "ground" plane
        steeringForce.setYtoZero()
        return steeringForce
    end    

    self.draw = function() self.mpbase.draw() end

    -- // reset position
    self.randomizeStartingPositionAndHeading = function()
    
        -- // randomize position on a ring between inner and outer radii
        -- // centered around the home base
        local inner = 20
        local outer = 30
        local radius = osmath.frandom2(inner, outer)
        local randomOnRing = osvec.RandomUnitVectorOnXZPlane().mult(radius)
        self.mover.setPosition(self.wanderer.mover.position().add(randomOnRing))

        -- // randomize 2D heading
        self.mover.randomizeHeadingOnXZPlane()
    end

    -- // reset state
    self.reset = function()
        
        self.newToken( pd )

        self.mpbase.reset()
        self.mpbase.bodyColor = vmath.vector4(1.0, 0.4, 0.4, 1.0) -- // redish
        self.randomizeStartingPositionAndHeading()

        -- // notify proximity database that our position has changed
        self.proximityToken.updateForNewPosition( self.mover.position() )
    end

    self.reset() 
    return self
end


return 
{
    MpBase      = MpBase,
    MpWanderer  = MpWanderer,
    MpPursuer   = MpPursuer,
}
