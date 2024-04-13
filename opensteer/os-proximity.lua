

-- // called by LQ for each clientObject in the specified neighborhood:
-- // push that clientObject onto the ContentType vector in void*
-- // clientQueryState
-- // (parameter names commented out to prevent compiler warning from "-W")
local perNeighborCallBackFunction = function(clientObject, distanceSquared, clientQueryState) 
    
    -- //console.log("adding results:", clientObject)
    table.insert(clientQueryState.results, clientObject)
end


-- // (parameter names commented out to prevent compiler warning from "-W")
local counterCallBackFunction = function( clientObject, distanceSquared, clientQueryState ) 

    clientQueryState.count = clientQueryState.count + 1
end


-- // ----------------------------------------------------------------------------
-- // A AbstractProximityDatabase-style wrapper for the LQ bin lattice system

-- // constructor
local LQProximityDatabase = function(center, dimensions, divisions) 

    local self = {}
    self.halfsize = dimensions.mult(0.5)
    self.origin = center.sub(self.halfsize)

    self.lq = lqCreateDatabase(self.origin.x, self.origin.y, self.origin.z, dimensions.x, dimensions.y, dimensions.z,  (divisions.x or 0), (divisions.y or 0), (divisions.z or 0))

    -- // destructor
    self.delLQProximityDatabase = function() 
        lqDeleteDatabase (self.lq)
        self.lq = nil
    end

    -- // constructor
    self.tokenType = function(parentObject, lqpd) 
        
        local token = {}
        token.proxy = lqInitClientProxy(parentObject)
        token.lq = lqpd.lq

        -- // destructor
        token.deltokenType = function() 
            lqRemoveFromBin (token.proxy)
        end

        -- // the client object calls this each time its position changes
        token.updateForNewPosition = function( p ) 
            lqUpdateForNewLocation(token.lq, token.proxy, p.x, p.y, p.z)
        end

        -- // find all neighbors within the given sphere (as center and radius)
        token.findNeighbors = function( center, radius ) 
            
            local state = { results= {} }
            lqMapOverAllObjectsInLocality(token.lq, center.x, center.y, center.z, radius, perNeighborCallBackFunction, state)
            return state.results
        end

        -- // Get statistics about bin populations: min, max and
        -- // average of non-empty bins.
        token.getBinPopulationStats = function( min, max, average ) 
            lqGetBinPopulationStats (token.lq, min, max, average)
        end

        return token
    end

    -- // allocate a token to represent a given client object in this database
    self.allocateToken = function(parentObject) 
        return self.tokenType(parentObject, self)
    end

    -- // count the number of tokens currently in the database
    self.getPopulation = function() 
        local state = { count = 0 }
        lqMapOverAllObjects(self.lq, counterCallBackFunction, state)
        return state.count
    end

    return self 
end


return LQProximityDatabase

