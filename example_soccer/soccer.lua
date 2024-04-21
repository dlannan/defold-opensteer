

-- // Test the OpenSteer soccer demo.
-- //    - start testing as soon as document loaded. Include this to test.

-- // ----------------------------------------------------------------------------
-- //
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
-- // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
-- // THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- // FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- // DEALINGS IN THE SOFTWARE.
-- //
-- //
-- // ----------------------------------------------------------------------------
-- //
-- // Simple soccer game by Michael Holm, IO Interactive A/S
-- //
-- // I made this to learn opensteer, and it took me four hours. The players will
-- // hunt the ball with no team spirit, each player acts on his own accord.
-- //
-- // I challenge the reader to change the behavour of one of the teams, to beat my
-- // team. It should not be too hard. If you make a better team, please share the
-- // source code so others get the chance to create a team that'll beat yours :)
-- //
-- // You are free to use this code for whatever you please.
-- //
-- // (contributed on July 9, 2003)
-- //
-- // ----------------------------------------------------------------------------


-- Note: The following lua script is based on the above C++ code, 
--        however, a sizable amount of changes were needed to work properly.
--        Feel free to share and use though.
-- // ----------------------------------------------------------------------------

local tinsert = table.insert

local veclib = require("opensteer.os-vec")
local osmath, osvec, Vec3 = veclib.osmath, veclib.osvec, veclib.vec3

local SimpleVehicle = require("opensteer.os-simplevehicle")

-- // ----------------------------------------------------------------------------
-- Setup variables
local MAX_TEAM       = 8
local soccerGame     = {}

soccerGame.selectedVehicle = 0
soccerGame.oldTime         = 0
soccerGame.currentTime     = 0
soccerGame.elapsedTime     = 0

soccerGame.selectedVehicle = nil 
soccerGame.soccer          = nil
soccerGame.context         = nil

soccerGame.zscale          = 2.0
soccerGame.xscale          = 2.4
soccerGame.checkRadius     = 30.0

soccerGame.ballobj         = nil

soccerGame.m_PlayerCountA  = 8
soccerGame.m_PlayerCountB  = 8
soccerGame.TeamA           = {}
soccerGame.TeamB           = {}
soccerGame.m_AllPlayers    = {}

soccerGame.m_Ball          = nil
soccerGame.m_bbox          = nil 
soccerGame.m_TeamAGoal     = nil 
soccerGame.m_TeamBGoal     = nil
soccerGame.junk            = nil
soccerGame.m_redScore      = 0
soccerGame.m_blueScore     = 0

soccerGame.centerx         = 0
soccerGame.centery         = 0
soccerGame.scale           = 1.0

soccerGame.playerPosition = {
    osvec.Vec3Set(0,0,4),
    osvec.Vec3Set(-5,0,7),
    osvec.Vec3Set(5,0,7),
    osvec.Vec3Set(-3,0,10),
    osvec.Vec3Set(3,0,10),
    osvec.Vec3Set(-8,0, 15),
    osvec.Vec3Set(0,0,15),
    osvec.Vec3Set(8,0,15),

    osvec.Vec3Set(0,0,-4),
    osvec.Vec3Set(-5,0,-7),
    osvec.Vec3Set(5,0,-7),
    osvec.Vec3Set(-3,0,-10),
    osvec.Vec3Set(3,0,-10),
    osvec.Vec3Set(-8,0, -15),
    osvec.Vec3Set(0,0,-15),
    osvec.Vec3Set(8,0,-15),
}


-- // Get the initial position of the vehicles and set them here
soccerGame.playerPositionStore = {}
--local playerPosition = {}

local function ScaleVector( v ) 

    v.x = v.x * soccerGame.xscale
    v.z = v.z * soccerGame.zscale
    return v
end

-- // ----------------------------------------------------------------------------
-- // a box object for the field and the goals.
local AABBox = function(_min, _max) 

    local self = {}
    self.m_min = _min
    self.m_max = _max

    self.InsideX = function(p) if((p.x < self.m_min.x) or (p.x > self.m_max.x)) then return false else return true end end 
    self.InsideZ = function(p) if((p.z < self.m_min.z) or (p.z > self.m_max.z)) then return false else return true end end
    self.draw = function(ctx) 
        local b = osvec.Vec3Set(self.m_min.x, 0, self.m_max.z)
        local c = osvec.Vec3Set(self.m_max.x, 0, self.m_min.z)
    end
    return self
end

-- // ----------------------------------------------------------------------------
-- // The ball object
local Ball = function(bbox) 

    local self = {}
    self.spin = 0.0   
    self.distance = 0.0
    self.lastfwd = Vec3()
    self.lastpos = Vec3()

    self.m_bbox = bbox
    self.mover = SimpleVehicle()

    self.customData = {}

    -- // reset state
    self.reset = function() 

        self.mover.reset () -- // reset the vehicle 
        self.mover.setSpeed(0.0)         -- // speed along Forward direction.
        self.mover.setMaxForce(30.0)      -- // steering force is clipped to this magnitude
        self.mover.setMaxSpeed(70.0)         -- // velocity is clipped to this magnitude
        self.mover.setRadius(1.2)

        self.mover.setPosition(osvec.Vec3Set(0.0, 0.0, 0.0))
        -- //self.mover.clearTrailHistory ()    -- // prevent long streaks due to teleportation 
        -- //self.mover.setTrailParameters (100, 6000)
        self.lastpos = self.mover.position().clone()
    end

    -- // per frame simulation update
    self.update = function( currentTime, elapsedTime) 

        self.mover.applyBrakingForce(3.5, elapsedTime)
        self.mover.applySteeringForce(self.mover.velocity(), elapsedTime)
        -- // are we now outside the field?
        if(not soccerGame.m_bbox.InsideX(self.mover.position())) then
            local d = self.mover.velocity()
            self.mover.regenerateOrthonormalBasis(osvec.Vec3Set(-d.x, d.y, d.z))
            self.mover.applySteeringForce(self.mover.velocity(), elapsedTime)
        end
        if(not soccerGame.m_bbox.InsideZ(self.mover.position())) then
            local d = self.mover.velocity()
            self.mover.regenerateOrthonormalBasis(osvec.Vec3Set(d.x, d.y, -d.z))
            self.mover.applySteeringForce(self.mover.velocity(), elapsedTime)
        end


        if(soccerGame.m_TeamAGoal.InsideZ(soccerGame.m_Ball.mover.position()) and soccerGame.m_TeamAGoal.InsideX(soccerGame.m_Ball.mover.position())) then
            soccerGame.m_Ball.reset()	-- // Ball in blue teams goal, red scores
            soccerGame.m_blueScore = soccerGame.m_blueScore + 1
            msg.post("/hud", "score", { id = "blue", score = soccerGame.m_blueScore })
        end
        if(soccerGame.m_TeamBGoal.InsideZ(soccerGame.m_Ball.mover.position()) and soccerGame.m_TeamBGoal.InsideX(soccerGame.m_Ball.mover.position())) then
            soccerGame.m_Ball.reset()	-- // Ball in red teams goal, blue scores
            soccerGame.m_redScore = soccerGame.m_redScore + 1
            msg.post("/hud", "score", { id = "red", score = soccerGame.m_redScore })
        end

        self.distance = self.distance + osvec.Vec3_distance( self.lastpos, self.mover.position() )
        local pos = self.mover.position()
        self.mover.setPosition( osvec.Vec3Set(pos.x, 0.0, pos.z))
        self.lastpos = self.mover.position().clone()
    end

    self.kick = function( dir, elapsedTime )
        self.mover.setSpeed(dir.length())
        self.mover.regenerateOrthonormalBasis(dir)
    end

    self.reset()
    return self
end

-- // ----------------------------------------------------------------------------
-- // Player agent part of a team.
local Player = function( others, allplayers, ball, isTeamA, id) 

    local self = {}
    -- // constructor
    self.mover = SimpleVehicle()

    self.m_others = others
    self.m_AllPlayers = allplayers
    self.m_Ball = ball
    self.b_ImTeamA = isTeamA
    self.m_MyID = id

    -- // reset state
    self.reset = function() 
        self.mover.reset() -- // reset the vehicle 
        self.mover.setSpeed (0.0)         -- // speed along Forward direction.
        self.mover.setMaxForce (20.7)      -- // steering force is clipped to this magnitude
        self.mover.setMaxSpeed (10)         -- // velocity is clipped to this magnitude
        self.mover.setRadius(1.25)

        -- // Place me on my part of the field, looking at oponnents goal
        local Xpos = -osmath.frandom01()*20
        if (self.b_ImTeamA == true) then Xpos = osmath.frandom01()*20  end
        self.mover.setPosition( osvec.Vec3Set(Xpos, 0, (osmath.frandom01()-0.5)*20) )
        if(self.m_MyID <= 9) then 
            if(self.b_ImTeamA == true) then 
                self.mover.setPosition(soccerGame.playerPosition[self.m_MyID])
            else
                self.mover.setPosition(soccerGame.playerPosition[self.m_MyID+ MAX_TEAM])
            end
        end

        self.m_home = self.mover.position().clone()
    end

    -- // per frame simulation update
    -- // (parameter names commented out to prevent compiler warning from "-W")
    self.update = function( currentTime, elapsedTime) 

        -- // if I hit the ball, kick it.
        local distToBall = osvec.Vec3_distance (self.mover.position(), self.m_Ball.mover.position())
        local sumOfRadii = self.mover.radius() + self.m_Ball.mover.radius()
        if(distToBall < sumOfRadii) then
            self.m_Ball.kick((self.m_Ball.mover.position().sub(self.mover.position())).mult(10.0), elapsedTime)
        end

        -- // otherwise consider avoiding collisions with others
        local collisionAvoidance = self.mover.steerToAvoidNeighbors(1.0, self.m_AllPlayers)
        if(collisionAvoidance.neq(osvec.Vec3_zero)) then
            self.mover.applySteeringForce (collisionAvoidance, elapsedTime)
        else 
            local distHomeToBall = osvec.Vec3_distance (self.m_home, self.m_Ball.mover.position())
            if( distHomeToBall < soccerGame.checkRadius) then
                
                -- // go for ball if I'm on the 'right' side of the ball
                local testplayer = self.mover.position().z < self.m_Ball.mover.position().z
                if( self.b_ImTeamA ) then testplayer = self.mover.position().z > self.m_Ball.mover.position().z end

                if( testplayer == true ) then
                    local seekTarget = self.mover.xxxsteerForSeek(self.m_Ball.mover.position())
                    self.mover.applySteeringForce(seekTarget, elapsedTime)
                else
                    local Z = 1.0
                    if self.m_Ball.mover.position().x - self.mover.position().x > 0 then Z = -1.0 end
                    local Zset = osvec.Vec3Set(Z,0,-3)
                    if (self.b_ImTeamA) then Zset = osvec.Vec3Set(Z,0,3) end
                    local behindBall = self.m_Ball.mover.position().add( Zset )
                    local behindBallForce = self.mover.xxxsteerForSeek(behindBall)
                    -- //annotationLine (position(), behindBall , Vec3(0,1,0))
                    local evadeTarget = self.mover.xxxsteerForFlee(self.m_Ball.mover.position())
                    self.mover.applySteeringForce(behindBallForce.mult(5.0).add(evadeTarget), elapsedTime)
                end
            else -- // Go home
                local seekTarget = self.mover.xxxsteerForSeek(self.m_home)
                -- //local seekHome = self.mover.xxxsteerForSeek(self.m_home)
                self.mover.applySteeringForce (seekTarget.mult(2.0), elapsedTime)
            end
        end
    end

    -- // per-instance reference to its group
    -- //const std::vector<Player*>	m_others
    -- //const std::vector<Player*>	m_AllPlayers
    -- //Ball*	m_Ball
    -- //bool	b_ImTeamA
    -- //int		m_MyID
    -- //Vec3		m_home 

    self.reset()
    return self
end



-- // ----------------------------------------------------------------------------
-- // TODO: This should be a helper!!! Move it!!!

local function soccerScreen(gwidth, gheight)
    gwidth = gwidth or 640 
    gheight = gheight or 480 

    soccerGame.centerx     = gwidth * 0.5 
    soccerGame.centery     = gheight * 0.5 
    soccerGame.scale       = 2.9 * gheight / 100.0
--    print(gwidth, gheight)
end

-- // ----------------------------------------------------------------------------
-- // Setup Ball, Players and Teams.
local function soccerSetup() 

    -- // Make a field
    soccerGame.m_bbox      = AABBox(ScaleVector(osvec.Vec3Set(-10,0,-20)), ScaleVector(osvec.Vec3Set(10,0,20)))
    -- // Red goal
    soccerGame.m_TeamAGoal = AABBox(ScaleVector(osvec.Vec3Set(-2,0,-21)), ScaleVector(osvec.Vec3Set(2,0,-19)))
    -- // Blue Goal
    soccerGame.m_TeamBGoal = AABBox(ScaleVector(osvec.Vec3Set(-2,0,19)), ScaleVector(osvec.Vec3Set(2,0,21)))
    -- // Make a ball
    soccerGame.m_Ball      = Ball(soccerGame.m_bbox)

    -- // Build team A

    local s = vmath.vector3(0.4, 0.4, 1.0) 
    go.set_scale(s, "ball")
        
    for i = 1, soccerGame.m_PlayerCountA do
        local pMicTest = Player(soccerGame.TeamA, soccerGame.m_AllPlayers, soccerGame.m_Ball, true, i)
        soccerGame.selectedVehicle = pMicTest
        tinsert(soccerGame.TeamA, pMicTest)
        tinsert(soccerGame.m_AllPlayers, pMicTest)
        local s = vmath.vector3(0.8, 0.8, 4.0)
        go.set_scale(s, "player"..i)
    end
    -- // Build Team B
    for i=1, soccerGame.m_PlayerCountB do 
        local pMicTest = Player(soccerGame.TeamB, soccerGame.m_AllPlayers, soccerGame.m_Ball, false, i)
        soccerGame.selectedVehicle = pMicTest
        tinsert(soccerGame.TeamB,pMicTest)
        tinsert(soccerGame.m_AllPlayers,pMicTest)
        local s = vmath.vector3(0.8, 0.8, 4.0)
        go.set_scale(s, "player"..i+9)
    end
    -- // initialize camera
    soccerGame.m_redScore = 0
    soccerGame.m_blueScore = 0
end

-- // ----------------------------------------------------------------------------
-- // Cleanup game and data
local function soccerClose() 
    for k,v in pairs(soccerGame.TeamA) do
        v = nil
    end
    soccerGame.TeamA = {}
    for k,v in pairs(soccerGame.TeamB) do
        v = nil
    end
    soccerGame.TeamB = {}
    soccerGame.m_AllPlayers = {}
end

-- // ----------------------------------------------------------------------------
-- // Reset the soccer field
local function soccerReset() 

    -- // reset vehicle
    for k,v in pairs(soccerGame.TeamA) do
        v.reset ()
    end 
    for k,v in pairs(soccerGame.TeamB) do
        v.reset ()
    end
    m_Ball.reset()

    -- // initialize camera
    soccerGame.m_redScore = 0
    soccerGame.m_blueScore = 0

    soccerGame.oldTime = 0.0
    soccerGame.currentTime = 0.0
end

-- // ----------------------------------------------------------------------------
-- // Update Ball and Players
local function soccerUpdater( dt ) 

    soccerGame.oldTime = soccerGame.currentTime
    soccerGame.currentTime = soccerGame.currentTime + dt 
    soccerGame.elapsedTime = dt

    local pos = soccerGame.m_Ball.mover._lastPosition
    local soccrey = soccerGame.centery - pos.z * soccerGame.scale
    local offset     = vmath.vector3(soccerGame.centerx, soccrey, 0)
    
    -- // update simulation of test vehicle
    for k,v in pairs(soccerGame.TeamA) do
        v.update (soccerGame.currentTime, soccerGame.elapsedTime)
        local pos = v.mover._lastPosition
        go.set_position(vmath.vector3(pos.x, pos.z, pos.y) * soccerGame.scale + offset, "player"..k)

        local fwd =v.mover.forward()
        local angle = math.atan2(fwd.z, fwd.x)
        local rot = vmath.quat_rotation_z( angle )
        local newrot = vmath.slerp(dt * 5.0, go.get_rotation( "player"..k), rot )
        go.set_rotation( newrot,  "player"..k)          
    end 
    for k,v in pairs(soccerGame.TeamB) do 
        v.update (soccerGame.currentTime, soccerGame.elapsedTime)
        local pos = v.mover._lastPosition
        go.set_position(vmath.vector3(pos.x, pos.z, pos.y) * soccerGame.scale + offset, "player"..k+9)

        local fwd =v.mover.forward()
        local angle = math.atan2(fwd.z, fwd.x)
        local rot = vmath.quat_rotation_z( angle )
        local newrot = vmath.slerp(dt * 5.0, go.get_rotation( "player"..k+9), rot )
        go.set_rotation( newrot,  "player"..k+9)        
    end 
    if(soccerGame.m_Ball) then 
        soccerGame.m_Ball.update(soccerGame.currentTime, soccerGame.elapsedTime) 
        local pos = soccerGame.m_Ball.mover._lastPosition
        go.set_position(vmath.vector3(pos.x, pos.z, pos.y) * soccerGame.scale + offset, "ball")

        local campos = go.get_world_position("/camera")
        go.set_position(vmath.vector3(campos.x, pos.z * soccerGame.scale, campos.z), "/camera")
    end    
end

-- // ----------------------------------------------------------------------------

return {
    close     = soccerClose,
    reset     = soccerReset,
    setup     = soccerSetup,
    screen    = soccerScreen,
    update    = soccerUpdater,
    data      = soccerGame,
}

-- // ----------------------------------------------------------------------------
