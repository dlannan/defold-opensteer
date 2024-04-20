
local tinsert = table.insert
local tremove = table.remove

local veclib = require("opensteer.os-vec")
local osmath, osvec, Vec3 = veclib.osmath, veclib.osvec, veclib.vec3

local osdebug = {
    scale   = 7.0,      -- Default pedestrian scaling (seems to match)
    xoff    = 0.0,
    yoff    = 0.0,
    debugdraw_modes = {},
}

osdebug.debugdraw_modes[1] = require("debug-draw.debug-draw")
osdebug.debugdraw_modes[2] = {
    ray = function(v1, v2, col) end,
    circle = function(x, z, r, col) end,
    COLORS = osdebug.debugdraw_modes[1].COLORS,
    text = osdebug.debugdraw_modes[1].text,
}

osdebug.debugdraw = osdebug.debugdraw_modes[2]

osdebug.debugEnable = function(enable)
    if(enable == 1) then 
        osdebug.debugdraw = osdebug.debugdraw_modes[1]
    else 
        osdebug.debugdraw = osdebug.debugdraw_modes[2]
    end 
end

osdebug.init    = function( scale_, xoff_, yoff_)
    osdebug.scale = scale_ 
    osdebug.xoff = xoff_ 
    osdebug.yoff = yoff_
end 

osdebug.drawTarget = function( x, z, sz ) 
    
    local x = x * osdebug.scale + osdebug.scale * osdebug.xoff
    local z = z * osdebug.scale + osdebug.scale * osdebug.yoff

    osdebug.debugdraw.ray(vmath.vector3(x-osdebug.scale*sz, 0.0, z), vmath.vector3(x+osdebug.scale*sz, 0.0, z), osdebug.debugdraw.COLORS.white)
    osdebug.debugdraw.ray(vmath.vector3(x, 0.0, z-osdebug.scale*sz), vmath.vector3(x, 0.0, z+osdebug.scale*sz), osdebug.debugdraw.COLORS.white)
end
    
osdebug.drawVector = function ( p, v, sz ) 
        
    local x = p.x * osdebug.scale + osdebug.scale * osdebug.xoff
    local z = p.z * osdebug.scale + osdebug.scale * osdebug.yoff
    local vx = (p.x + v.x * sz) * osdebug.scale + osdebug.scale * osdebug.xoff
    local vz = (p.z + v.z * sz) * osdebug.scale + osdebug.scale * osdebug.yoff

    osdebug.debugdraw.ray(vmath.vector3(x, 0.0, z), vmath.vector3(vx, 0.0, vz), osdebug.debugdraw.COLORS.yellow)
end

osdebug.drawObstacle = function( ctx, x, z, scale, r) 

    osdebug.debugdraw.circle(x, z, scale * r, osdebug.debugdraw.COLORS.orange)
end

osdebug.drawPath = function(ctx, path, scale, xoff, yoff) 

    for k, obj in ipairs(path.obstacles) do
        local x = obj.center.x * scale + scale * xoff
        local z = obj.center.z * scale + scale * yoff
        osdebug.drawObstacle(ctx, x, z, scale, obj.radius)
    end

    for idx = 1, #path.pathway.points -1 do
        local pt = path.pathway.points[idx]
        local pt2 = path.pathway.points[idx+1]
        local x = pt.x * scale + scale * xoff
        local z = pt.z * scale + scale * yoff
        local nx = pt2.x * scale + scale * xoff
        local nz = pt2.z * scale + scale * yoff
        
        osdebug.debugdraw.ray(vmath.vector3(x, 0.0, z), vmath.vector3(nx, 0.0, nz), osdebug.debugdraw.COLORS.green)
    end
end

osdebug.drawCircle = function(x, y, r, color)
    local x = x * osdebug.scale + osdebug.scale * osdebug.xoff
    local y = y * osdebug.scale + osdebug.scale * osdebug.yoff
    r = r * osdebug.scale
    osdebug.debugdraw.circle(x, y, r, color )
end

osdebug.drawLine = function( pt, pt2, color)
    local x = pt.x * osdebug.scale + osdebug.scale * osdebug.xoff
    local y = pt.y * osdebug.scale
    local z = pt.z * osdebug.scale + osdebug.scale * osdebug.yoff
    local nx = pt2.x * osdebug.scale + osdebug.scale * osdebug.xoff
    local ny = pt2.y * osdebug.scale
    local nz = pt2.z * osdebug.scale + osdebug.scale * osdebug.yoff
    
    osdebug.debugdraw.ray(vmath.vector3(x, y, z), vmath.vector3(nx, ny, nz), color)
end 

osdebug.drawTriangle = function( p1, p2, p3, color)

    osdebug.drawLine(vmath.vector3(p1.x, 0.0, p1.z), vmath.vector3(p2.x, 0.0, p2.z), color)
    osdebug.drawLine(vmath.vector3(p2.x, 0.0, p2.z), vmath.vector3(p3.x, 0.0, p3.z), color)
    osdebug.drawLine(vmath.vector3(p3.x, 0.0, p3.z), vmath.vector3(p1.x, 0.0, p1.z), color)
end

osdebug.drawBasic2dCircularVehicle = function(vehicle, color)

    -- // "aspect ratio" of body (as seen from above)
    local x = 0.5
    local y = math.sqrt(1 - (x * x))

    -- // radius and position of vehicle
    local r = vehicle.radius()
    local p = vehicle.position()

    -- // shape of triangular body
    local u = osvec.Vec3Set(0, 1, 0).mult(0.05).mult(r) -- // slightly up
    local f = vehicle.forward().mult(r)
    local s = vehicle.side().mult(x).mult(r)
    local b = vehicle.forward().mult(-y).mult(r)

    -- // draw double-sided triangle (that is: no (back) face culling)
    local p1 = p.add(f).add(u) 
    local p2 = p.add(b).sub(s).add(u)
    local p3 = p.add(b).add(s).add(u)
    osdebug.drawTriangle (p1, p2, p3, color)

    -- // draw the circular collision boundary
    local center = p.add(u)
    osdebug.drawCircle(center.x, center.z, r, osdebug.debugdraw.COLORS.white)
end

osdebug.TrailTrace = function( maxCount, color, timestep ) 
    
    maxCount = maxCount or 10 
    timestep = timestep or 0.25

    local self = {}
    self.trailcount = 0 
    self.lasttick = 0.0
    self.maxcount = maxCount
    self.timestep = timestep
    self.color = color
    self.trail = {}

    self.recordTrailVertex = function( tm, pos )

        if(tm - self.lasttick < self.timestep ) then return end 
        self.lasttick = self.lasttick + self.timestep
        local traildata = { tm = tm, pos = osvec.Vec3Set(pos.x, pos.y, pos.z) }
        -- Always insert at front
        tinsert( self.trail, 1, traildata )
        if(self.trailcount + 1 > self.maxcount) then 
            tremove(self.trail)
        else
            self.trailcount = self.trailcount + 1
        end
    end 

    self.clearTrailHistory = function()
        self.trail = {}
        self.trailcount = 0
    end

    self.draw = function() 
        if(self.trailcount < 2) then return end
        local alphaend = 0
        if(self.trailcount > 5) then alphaend = 3 end
        local col = vmath.vector4(self.color)
        for ti = 2, self.trailcount do 
            local p1 = self.trail[ti-1].pos
            local p2 = self.trail[ti].pos
            if(alphaend > 0 and ti > self.maxcount - alphaend) then 
                col.w = (self.maxcount - ti) * 0.33
            end 
            --print(ti..": "..p1.x.."   "..p1.z.."      "..p2.x.. "  ".. p2.z)
            osdebug.drawLine(vmath.vector3(p1.x, p1.y, p1.z), vmath.vector3(p2.x, p2.y, p2.z), col)
        end
    end

    return self
end

return osdebug