

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

local tinsert = table.insert

local Vec3 = require("opensteer.os-vec")
local SimpleVehicle = require("opensteer.os-simplevehicle")

local selectedVehicle
local soccer
local context

local zscale = 1.76
local xscale = 2.17
local checkRadius = 30.0
local MAX_TEAM     = 8

local     ballobj

local     m_PlayerCountA = 0
local     m_PlayerCountB = 0
local     TeamA = {}
local     TeamB = {}
local     m_AllPlayers = {}

local     m_Ball        = nil
local     m_bbox        = nil 
local     m_TeamAGoal   = nil 
local     m_TeamBGoal   = nil
local    junk
local     m_redScore    = 0
local     m_blueScore   = 0

local centerx     = 0
local centery     = 0
local scale       = 1

local playerPosition = {
    Vec3Set(0,0,4),
    Vec3Set(-5,0,7),
    Vec3Set(5,0,7),
    Vec3Set(-3,0,10),
    Vec3Set(3,0,10),
    Vec3Set(-8,0, 15),
    Vec3Set(0,0,15),
    Vec3Set(8,0,15),

    Vec3Set(0,0,-4),
    Vec3Set(-5,0,-7),
    Vec3Set(5,0,-7),
    Vec3Set(-3,0,-10),
    Vec3Set(3,0,-10),
    Vec3Set(-8,0, -15),
    Vec3Set(0,0,-15),
    Vec3Set(8,0,-15),
}


-- // Get the initial position of the vehicles and set them here
local playerPositionStore = {}
--local playerPosition = {}

function ScaleVector( v ) 

    v.x = v.x * xscale
    v.z = v.z * zscale
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
        local b = Vec3Set(self.m_min.x, 0, self.m_max.z)
        local c = Vec3Set(self.m_max.x, 0, self.m_min.z)
    end
    return self
end

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

        self.mover.setPosition(Vec3Set(0.0, 0.0, 0.0))
        -- //self.mover.clearTrailHistory ()    -- // prevent long streaks due to teleportation 
        -- //self.mover.setTrailParameters (100, 6000)
        self.lastpos = self.mover.position().clone()
    end

    -- // per frame simulation update
    self.update = function( currentTime, elapsedTime) 

        self.mover.applyBrakingForce(3.5, elapsedTime)
        self.mover.applySteeringForce(self.mover.velocity(), elapsedTime)
        -- // are we now outside the field?
        if(not m_bbox.InsideX(self.mover.position())) then
            local d = self.mover.velocity()
            self.mover.regenerateOrthonormalBasis(Vec3Set(-d.x, d.y, d.z))
            self.mover.applySteeringForce(self.mover.velocity(), elapsedTime)
        end
        if(not m_bbox.InsideZ(self.mover.position())) then
            local d = self.mover.velocity()
            self.mover.regenerateOrthonormalBasis(Vec3Set(d.x, d.y, -d.z))
            self.mover.applySteeringForce(self.mover.velocity(), elapsedTime)
        end


        if(m_TeamAGoal.InsideZ(m_Ball.mover.position()) and m_TeamAGoal.InsideX(m_Ball.mover.position())) then
            m_Ball.reset()	-- // Ball in blue teams goal, red scores
            m_blueScore = m_blueScore + 1
            label.set_text("#sc_wild", "WILD: "..m_blueScore)
        end
        if(m_TeamBGoal.InsideZ(m_Ball.mover.position()) and m_TeamBGoal.InsideX(m_Ball.mover.position())) then
            m_Ball.reset()	-- // Ball in red teams goal, blue scores
            m_redScore = m_redScore + 1
            label.set_text("#sc_farm", "FARM: "..m_redScore)
        end

        self.distance = self.distance + Vec3_distance( self.lastpos, self.mover.position() )
        local pos = self.mover.position()
        self.mover.setPosition( Vec3Set(pos.x, 0.0, pos.z))
        self.lastpos = self.mover.position().clone()
    end

    self.kick = function( dir, elapsedTime )
        self.mover.setSpeed(dir.length())
        self.mover.regenerateOrthonormalBasis(dir)
    end

    self.reset()
    return self
end

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
        local Xpos = -frandom01()*20
        if (self.b_ImTeamA == true) then Xpos = frandom01()*20  end
        self.mover.setPosition( Vec3Set(Xpos, 0, (frandom01()-0.5)*20) )
        if(self.m_MyID <= 9) then 
            if(self.b_ImTeamA == true) then 
                self.mover.setPosition(playerPosition[self.m_MyID])
            else
                self.mover.setPosition(playerPosition[self.m_MyID+ MAX_TEAM])
            end
        end

        self.m_home = self.mover.position().clone()
    end

    -- // per frame simulation update
    -- // (parameter names commented out to prevent compiler warning from "-W")
    self.update = function( currentTime, elapsedTime) 

        -- // if I hit the ball, kick it.
        local distToBall = Vec3_distance (self.mover.position(), self.m_Ball.mover.position())
        local sumOfRadii = self.mover.radius() + self.m_Ball.mover.radius()
        if(distToBall < sumOfRadii) then
            self.m_Ball.kick((self.m_Ball.mover.position().sub(self.mover.position())).mult(10.0), elapsedTime)
        end

        -- // otherwise consider avoiding collisions with others
        local collisionAvoidance = self.mover.steerToAvoidNeighbors(1.0, self.m_AllPlayers)
        if(collisionAvoidance.neq(Vec3_zero)) then
            self.mover.applySteeringForce (collisionAvoidance, elapsedTime)
        else 
            local distHomeToBall = Vec3_distance (self.m_home, self.m_Ball.mover.position())
            if( distHomeToBall < checkRadius) then
                
                -- // go for ball if I'm on the 'right' side of the ball
                local testplayer = self.mover.position().z < self.m_Ball.mover.position().z
                if( self.b_ImTeamA ) then testplayer = self.mover.position().z > self.m_Ball.mover.position().z end

                if( testplayer == true ) then
                    local seekTarget = self.mover.xxxsteerForSeek(self.m_Ball.mover.position())
                    self.mover.applySteeringForce(seekTarget, elapsedTime)
                else
                    local Z = 1.0
                    if self.m_Ball.mover.position().x - self.mover.position().x > 0 then Z = -1.0 end
                    local Zset = Vec3Set(Z,0,-3)
                    if (self.b_ImTeamA) then Zset = Vec3Set(Z,0,3) end
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
function setBodyMaterial( obj, newmaterial )    
end

function soccerSetup(gwidth, gheight) 

    centerx     = gwidth * 0.5 
    centery     = gheight * 0.5 
    scale       = gheight / 100.0  
    
    -- // Make a field
    m_bbox = AABBox(ScaleVector(Vec3Set(-10,0,-20)), ScaleVector(Vec3Set(10,0,20)))
    -- // Red goal
    m_TeamAGoal = AABBox(ScaleVector(Vec3Set(-2,0,-21)), ScaleVector(Vec3Set(2,0,-19)))
    -- // Blue Goal
    m_TeamBGoal = AABBox(ScaleVector(Vec3Set(-2,0,19)), ScaleVector(Vec3Set(2,0,21)))
    -- // Make a ball
    m_Ball = Ball(m_bbox)
    m_Ball['node'] = ballobj

    -- // Build team A
    m_PlayerCountA = 8

    local s = vmath.vector3(0.4, 0.4, 1.0)
    go.set_scale(s, "ball")
        
    for i = 1, m_PlayerCountA do
        local pMicTest = Player(TeamA, m_AllPlayers, m_Ball, true, i)
        selectedVehicle = pMicTest
        tinsert(TeamA, pMicTest)
        tinsert(m_AllPlayers,pMicTest)
        local s = vmath.vector3(0.2, 0.2, 1.0)
        go.set_scale(s, "player"..i)
    end
    -- // Build Team B
    m_PlayerCountB = 8
    for i=1, m_PlayerCountB do 
        local pMicTest = Player(TeamB, m_AllPlayers, m_Ball, false, i)
        selectedVehicle = pMicTest
        tinsert(TeamB,pMicTest)
        tinsert(m_AllPlayers,pMicTest)
        local s = vmath.vector3(0.2, 0.2, 1.0)
        go.set_scale(s, "player"..i+9)
    end
    -- // initialize camera
    m_redScore = 0
    m_blueScore = 0
end

function soccerClose() 
    for k,v in pairs(TeamA) do
        v = nil
    end
    TeamA = {}
    for k,v in pairs(TeamB) do
        v = nil
    end
    TeamB = {}
    m_AllPlayers = {}
end

function soccerReset() 

    -- // reset vehicle
    for k,v in pairs(TeamA) do
        v.reset ()
    end 
    for k,v in pairs(TeamB) do
        v.reset ()
    end
    m_Ball.reset()

    -- // initialize camera
    m_redScore = 0
    m_blueScore = 0

    oldTime = 0.0
    currentTime = 0.0
end

-- // ----------------------------------------------------------------------------

local selectedVehicle = 0
local oldTime = 0
local currentTime = 0
local elapsedTime = 0

function soccerUpdater( dt ) 

    oldTime = currentTime
    currentTime = currentTime + dt 
    elapsedTime = dt

    local offset     = vmath.vector3(centerx, centery, 0)

    -- // update simulation of test vehicle
    for k,v in pairs(TeamA) do
        v.update (currentTime, elapsedTime)
        local pos = v.mover._lastPosition
        go.set_position(vmath.vector3(pos.x, pos.z, pos.y) * scale + offset, "player"..k)
    end 
    for k,v in pairs(TeamB) do 
        v.update (currentTime, elapsedTime)
        local pos = v.mover._lastPosition
        go.set_position(vmath.vector3(pos.x, pos.z, pos.y) * scale + offset, "player"..k+9)
    end 
    m_Ball.update(currentTime, elapsedTime)

    local pos = m_Ball.mover._lastPosition
    go.set_position(vmath.vector3(pos.x, pos.z, pos.y) * scale + offset, "ball")
end
