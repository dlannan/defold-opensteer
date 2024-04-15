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
-- // An autonomous "pedestrian":
-- // follows paths, avoids collisions with obstacles and other pedestrians
-- //
-- // 10-29-01 cwr: created
-- //
-- //
-- // ----------------------------------------------------------------------------


-- #include "OpenSteer/PolylineSegmentedPathwaySingleRadius.h"
-- #include "OpenSteer/SimpleVehicle.h"
-- #include "OpenSteer/OpenSteerDemo.h"
-- #include "OpenSteer/Proximity.h"
-- #include "OpenSteer/Color.h"

-- Note: The following lua script is based on the above C++ code, 
--        however, a sizable amount of changes were needed to work properly.
--        Feel free to share and use though.
-- // ----------------------------------------------------------------------------

local tinsert = table.insert

require("opensteer.os-lq")
local veclib = require("opensteer.os-vec")
local osmath, osvec, Vec3 = veclib.osmath, veclib.osvec, veclib.vec3

SimpleVehicle = require("opensteer.os-simplevehicle")
pathwaylib = require("opensteer.os-pathway")
Pathway = pathwaylib.PolylinePathway
SphericalObstacle = require("opensteer.os-obstacle").SphericalObstacle
lqdblib = require("opensteer.os-proximity")
LQProximityDatabase = lqdblib.LQProximityDatabase

local debugdraw_modes = {}
debugdraw_modes[1] = require("debug-draw.debug-draw")
debugdraw_modes[2] = {
    ray = function(v1, v2, col) end,
    circle = function(x, z, r, col) end,
    COLORS = debugdraw_modes[1].COLORS,
    text = debugdraw_modes[1].text,
}

local debugdraw = debugdraw_modes[2]

local function debugEnable(enable)
    if(enable == 1) then 
        debugdraw = debugdraw_modes[1]
    else 
        debugdraw = debugdraw_modes[2]
    end 
end

-- // Test the OpenSteer pedestrian demo.
-- //    - start testing as soon as document loaded. Include this to test.

gTestPath = nil

gObstacle1 = SphericalObstacle()
gObstacle2 = SphericalObstacle()
gObstacles = {}

gEndpoint0 = Vec3()
gEndpoint1 = Vec3()
gUseDirectedPathFollowing = true

-- // this was added for debugging tool, but I might as well leave it in
gWanderSwitch = true

local function vmathVec3( v3 )
    return vmath.vector(v3.x, v3.y, v3.z)
end


function getTestPath() 
    if (gTestPath == nil) then

        local pathRadius = 2.0

        local pathPointCount = 7
        local size = 30.0
        local top = 2.0 * size
        local gap = 1.2 * size
        local out = 2.0 * size
        local h = 0.5
        local pathPoints = {
             osvec.Vec3Set (h+gap-out,     0,0,  h+top-out),  --// 0 a
             osvec.Vec3Set (h+gap,         0.0,  h+top),      --// 1 b
             osvec.Vec3Set (h+gap+(top/2), 0.0,  h+top/2),    --// 2 c
             osvec.Vec3Set (h+gap,         0.0,  h),          --// 3 d
             osvec.Vec3Set (h,             0.0,  h),          --// 4 e
             osvec.Vec3Set (h,             0.0,  h+top),      --// 5 f
             osvec.Vec3Set (h+gap,         0.0,  h+top/2)     --// 6 g
        }

        gObstacle1.center = osmath.interpolateV(0.2, pathPoints[1], pathPoints[2])
        gObstacle2.center = osmath.interpolateV(0.5, pathPoints[3], pathPoints[4])
        gObstacle1.radius = 3.0
        gObstacle2.radius = 5.0
        tinsert(gObstacles, gObstacle2)
        tinsert(gObstacles, gObstacle1)

        gEndpoint0 = pathPoints[1]
        gEndpoint1 = pathPoints[pathPointCount]

        gTestPath = pathwaylib.PolylinePathway1(pathPointCount, pathPoints, pathRadius, false)
    end
    return gTestPath
end

local Pedestrian = function( pd ) 

    local self = {}
    -- // allocate one and share amoung instances just to save memory usage
    -- // (change to per-instance allocation to be more MP-safe)
    self.neighbors = {}

    -- // path to be followed by this pedestrian
    -- // XXX Ideally this should be a generic Pathway, but we use the
    -- // XXX getTotalPathLength and radius methods (currently defined only
    -- // XXX on PolylinePathway) to set random initial positions.  Could
    -- // XXX there be a "random position inside path" method on Pathway?
    self.path = nil

    -- // direction for path following (upstream or downstream)
    self.pathDirection = 1

    -- // type for a group of Pedestrians
    -- //typedef std::vector<Pedestrian*> groupType;
    self.mover = SimpleVehicle()

    -- // a pointer to this boid's interface object for the proximity database
    self.proximityToken = nil

    -- // switch to new proximity database -- just for demo purposes
    self.newToken = function( newpd )

        -- // delete this boid's token in the old proximity database
        if(self.proximityToken) then self.proximityToken = nil end

        -- // allocate a token for this boid in the proximity database
        self.proximityToken = newpd.allocateToken(self)
    end

    -- // destructor
    self.delete = function()
        -- // delete this boid's token in the proximity database
        self.proximityToken = nil
    end

    -- // reset all instance state
    self.reset = function() 

        self.newToken( pd )

        -- // reset the vehicle 
        self.mover.reset()

        -- // max speed and max steering force (maneuverability) 
        self.mover.setMaxSpeed(2.0)
        self.mover.setMaxForce(8.0)

        -- // initially stopped
        self.mover.setSpeed(0.0)

        -- // size of bounding sphere, for obstacle avoidance, etc.
        self.mover.setRadius(0.5) -- // width = 0.7, add 0.3 margin, take half

        -- // set the path for this Pedestrian to follow
        self.path = getTestPath()

        -- // set initial position
        -- // (random point on path + random horizontal offset)
        local d = self.path.getTotalPathLength() * osmath.frandom01()
        local r = self.path.radius
        local randomOffset = osvec.randomVectorOnUnitRadiusXZDisk().mult( r )

        self.mover.setPosition(self.path.mapPathDistanceToPoint(d).add( randomOffset))
        
        -- // randomize 2D heading
        self.mover.randomizeHeadingOnXZPlane()

        -- // pick a random direction for path following (upstream or downstream)
        self.pathDirection = 1
        if(osmath.frandom01() > 0.5) then self.pathDirection = -1 end

        -- // notify proximity database that our position has changed
        self.proximityToken.updateForNewPosition( self.mover.position() )
    end

    -- // per frame simulation update
    self.update = function( currentTime, elapsedTime ) 
               
        local steer = self.determineCombinedSteering(elapsedTime)
        
        -- // apply steering force to our momentum
        self.mover.applySteeringForce(steer, elapsedTime)

        -- // reverse direction when we reach an endpoint
        if (gUseDirectedPathFollowing == true)  then

            if (osvec.Vec3_distance(self.mover.position(), gEndpoint0) < self.path.radius) then
                self.pathDirection = 1
            end
            if (osvec.Vec3_distance(self.mover.position(), gEndpoint1) < self.path.radius) then 
                self.pathDirection = -1
            end
        end
        -- // notify proximity database that our position has changed
        self.proximityToken.updateForNewPosition( self.mover.position() )
    end

    -- // compute combined steering force: move forward, avoid obstacles
    -- // or neighbors if needed, otherwise follow the path and wander
    self.determineCombinedSteering = function(elapsedTime) 
        
        -- // move forward
        local steeringForce = self.mover.forward();

        -- // probability that a lower priority behavior will be given a
        -- // chance to "drive" even if a higher priority behavior might
        -- // otherwise be triggered.
        local leakThrough = 0.1

        -- // determine if obstacle avoidance is required
        local obstacleAvoidance = osvec.Vec3_zero
        if (leakThrough < osmath.frandom01()) then 
            local oTime = 6.0; -- // minTimeToCollision = 6 seconds
            obstacleAvoidance = self.mover.steerToAvoidObstacles(oTime, gObstacles)
        end
        
        -- // if obstacle avoidance is needed, do it
        if (obstacleAvoidance.neq(osvec.Vec3_zero)) then
            steeringForce = steeringForce.add(obstacleAvoidance);
        end 
            -- // otherwise consider avoiding collisions with others
            local collisionAvoidance = osvec.Vec3Set(0.0, 0.0, 0.0)
            local caLeadTime = 4.0

            -- // find all neighbors within maxRadius using proximity database
            -- // (radius is largest distance between vehicles traveling head-on
            -- // where a collision is possible within caLeadTime seconds.)
            local maxRadius = caLeadTime * self.mover.maxSpeed() * 2.0

            self.neighbors = self.proximityToken.findNeighbors(self.mover.position(), maxRadius)
            
            --if (leakThrough < osmath.frandom01()) then
                collisionAvoidance = (self.mover.steerToAvoidNeighbors(caLeadTime, self.neighbors)).mult(10.0)
--                pprint("Avoiding.."..collisionAvoidance.x.."  "..collisionAvoidance.y.."  "..collisionAvoidance.z )
            --end

            -- // if collision avoidance is needed, do it
            if (collisionAvoidance.neq(osvec.Vec3_zero)) then
                steeringForce = steeringForce.add(collisionAvoidance)
                drawVector(self.mover.position(), steeringForce, 5.0)
            else 
                -- // add in wander component (according to user switch)
                if (gWanderSwitch == true) then 
                    steeringForce = steeringForce.add( self.mover.steerForWander(elapsedTime))
                end

                -- // do (interactively) selected type of path following
                local pfLeadTime = 3.0
                local pathFollow = Vec3()
                if(gUseDirectedPathFollowing == true) then 
                    pathFollow = self.mover.steerToFollowPath(self.pathDirection, pfLeadTime, self.path)
                else 
                    pathFollow = self.mover.steerToStayOnPath(pfLeadTime, self.path)
                end

                -- // add in to steeringForce
                steeringForce = steeringForce.add(pathFollow.mult(0.5))
            end
        --end

        -- // return steering constrained to global XZ "ground" plane
        steeringForce.setYtoZero()
        return steeringForce
    end


    -- // draw this pedestrian into scene
    self.draw = function()
    
    end

    self.reset()
    return self
end

function drawObstacle( ctx, x, z, scale, r) 

    debugdraw.circle(x, z, scale * r, debugdraw.COLORS.orange)
end

function drawPath(ctx, scale, xoff, yoff) 

    local ct = 0
    local lastpt = nil

    local x = gObstacle1.center.x * scale + scale * xoff
    local z = gObstacle1.center.z * scale + scale * yoff
    drawObstacle(ctx, x, z, scale, gObstacle1.radius)
    x = gObstacle2.center.x * scale + scale * xoff
    z = gObstacle2.center.z * scale + scale * yoff
    drawObstacle(ctx, x, z, scale, gObstacle2.radius)

    for idx = 1, #gTestPath.points -1 do
        local pt = gTestPath.points[idx]
        local pt2 = gTestPath.points[idx+1]
        local x = pt.x * scale + scale * xoff
        local z = pt.z * scale + scale * yoff
        local nx = pt2.x * scale + scale * xoff
        local nz = pt2.z * scale + scale * yoff
        
        debugdraw.ray(vmath.vector3(x, 0.0, z), vmath.vector3(nx, 0.0, nz), debugdraw.COLORS.green)
    end
end

local gPedestrians = {
    center = osvec.Vec3Set(0, 0, 0),
    div = 20.0,
    diameter = 200.0, -- //XXX need better way to get this

    population = 0,
    crowd = {},

    oldTime = 0,
    currentTime = 0,
    elapsedTime = 0,

    ctx = nil,
    scale = 7.0,
    xoff = 0.0,
    yoff = 0.0,
}

gPedestrians.divisions = osvec.Vec3Set(gPedestrians.div, 1.0, gPedestrians.div)
gPedestrians.dimensions = osvec.Vec3Set(gPedestrians.diameter, gPedestrians.diameter, gPedestrians.diameter)
gPedestrians.GPD = LQProximityDatabase( gPedestrians.center, gPedestrians.dimensions, gPedestrians.divisions)

function drawTarget( x, z, sz ) 
    
    local x = x * gPedestrians.scale + gPedestrians.scale * gPedestrians.xoff
    local z = z * gPedestrians.scale + gPedestrians.scale * gPedestrians.yoff

    debugdraw.ray(vmath.vector3(x-gPedestrians.scale*sz, 0.0, z), vmath.vector3(x+gPedestrians.scale*sz, 0.0, z), debugdraw.COLORS.white)
    debugdraw.ray(vmath.vector3(x, 0.0, z-gPedestrians.scale*sz), vmath.vector3(x, 0.0, z+gPedestrians.scale*sz), debugdraw.COLORS.white)
end

function drawVector( p, v, sz ) 
    
    local x = p.x * gPedestrians.scale + gPedestrians.scale * gPedestrians.xoff
    local z = p.z * gPedestrians.scale + gPedestrians.scale * gPedestrians.yoff
    local vx = (p.x + v.x * sz) * gPedestrians.scale + gPedestrians.scale * gPedestrians.xoff
    local vz = (p.z + v.z * sz) * gPedestrians.scale + gPedestrians.scale * gPedestrians.yoff

    debugdraw.ray(vmath.vector3(x, 0.0, z), vmath.vector3(vx, 0.0, vz), debugdraw.COLORS.yellow)
end

function addPedestrianToCrowd() 

    gPedestrians.population = gPedestrians.population + 1
    local pedestrian = Pedestrian( gPedestrians.GPD )
    tinsert(gPedestrians.crowd, pedestrian)
end

function pedestrianUpdater(dt) 

    dt = dt or 0
    
    gPedestrians.oldTime = gPedestrians.currentTime
    gPedestrians.elapsedTime = dt
    gPedestrians.currentTime = gPedestrians.currentTime + dt
    
    drawPath(gPedestrians.ctx, gPedestrians.scale, gPedestrians.xoff, gPedestrians.yoff)

    -- // update each Pedestrian
    for i, person in ipairs(gPedestrians.crowd) do
        person.update(gPedestrians.currentTime, gPedestrians.elapsedTime)
        local pos = person.mover.position()
        local fwd = person.mover.forward()

        local x = pos.x * gPedestrians.scale + gPedestrians.scale * gPedestrians.xoff
        local z = pos.z * gPedestrians.scale + gPedestrians.scale * gPedestrians.yoff
        debugdraw.circle(x, z, gPedestrians.scale, debugdraw.COLORS.red)
    end
end

function pedestrianSetup(max_pedestrians)

    debugdraw.circle(0, 0, 20.0, debugdraw.COLORS.orange)
    max_pedestrians = max_pedestrians or 100
    pprint("Testing OpenSteer Pedestrians: "..max_pedestrians)
    -- pprint("LQDB:", gPedestrians.GPD)

    local v1 = vmath.vector3(gPedestrians.center.x, gPedestrians.center.y, gPedestrians.center.z)
    local d = gPedestrians.diameter
    local color = debugdraw.COLORS.blue
    
    debugdraw.ray(v1 + vmath.vector3(-d, 0.0, -d), v1 + vmath.vector3(d, 0.0, -d), color)
    debugdraw.ray(v1 + vmath.vector3(-d, 0.0, d), v1 + vmath.vector3(d, 0.0, d), color)
    debugdraw.ray(v1 + vmath.vector3(d, 0.0, -d), v1 + vmath.vector3(d, 0.0, d), color)
    debugdraw.ray(v1 + vmath.vector3(-d, 0.0, -d), v1 + vmath.vector3(-d, 0.0, d), color)

    -- // create the specified number of Pedestrians
    gPedestrians.population = 0
    for i = 1, max_pedestrians do
        addPedestrianToCrowd()
    end

    gPedestrians.currentTime = 0.0
    pedestrianUpdater()
end

return {
    Pedestrian = Pedestrian,
    all = gPedestrians,
    updater = pedestrianUpdater,
    debugEnable = debugEnable,
    debugdraw_modes = debugdraw_modes,
}