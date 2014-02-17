class "wVehicles"

function wVehicles:__init( )
	self.vehicles = {}
	self.messageColor = Color(255, 255, 255)
	-- Define steam ids here that should be able to use all commands
	self.admins = Set { "STEAM_0:1:65621451", "STEAM_0:0:1337" }
--	self.admins = Set { "STEAM_0:0:26639056", "STEAM_0:0:1337" }

	-- Which commands should be accessible to non-admins?
	self.allowPlayerUsage = Set { "gc", "list" }
	-- Uncomment the following line if you dont want any of the commands available to public.
	-- self.allowPlayerUsage = Set { }

	Events:Subscribe("PlayerChat", self, self.parseVehicleCommands)
	Events:Subscribe("ModuleLoad", self, self.moduleLoaded)
	Events:Subscribe("ModuleUnload", self, self.moduleUnLoaded)

	Network:Subscribe("wVehicles.requestVehicleList", self, self.requestVehicleList)
	Network:Subscribe("wVehicles.putInVehicle", self, self.putInVehicle)
end

-- Only the server can put players into vehicles..
function wVehicles:putInVehicle(arg, sender)
	sender:EnterVehicle(Vehicle.GetById(arg), 0)
end

-- Network response to the client for /v list
function wVehicles:requestVehicleList(arg, sender)
	local vehData = {}

	for k,v in pairs(self.vehicles) do
		if(self.vehicles[ v:GetId() ] ~= nil) then
			vehData[ v.sqlId ] = {
				[ "model" ] = v:GetName(),
				[ "id" ] = v:GetId(),
				[ "x" ] = v:GetPosition().x,
				[ "y" ] = v:GetPosition().y,
				[ "z" ] = v:GetPosition().z
			}
		end
	end

	Network:Send(sender, "wVehicles.receiveVehicleList", vehData)
end

function wVehicles:moduleLoaded()
	-- Uncomment this line below if you want to delete all vehicles;
	-- SQL:Execute("DROP TABLE IF EXISTS vehicles")
	SQL:Execute("create table if not exists vehicles (vehicleid INTEGER PRIMARY KEY AUTOINCREMENT, modelid INTEGER, x FLOAT, y FLOAT, z FLOAT, a_pitch FLOAT, a_roll FLOAT, a_yaw FLOAT, col1 VARCHAR, col2 VARCHAR, owner VARCHAR)" )

    local 
    	result, newVehicle = SQL:Query( "select * from vehicles" ):Execute(), nil

    if #result > 0 then
        for i, v in ipairs(result) do
        	print("[Vehicle] Spawning ID " .. v.vehicleid)
            newVehicle = self:CreateVehicle(tonumber(v.modelid), Vector3(tonumber(v.x),tonumber(v.y),tonumber(v.z)), Angle(tonumber(v.a_yaw), tonumber(v.a_pitch), tonumber(v.a_roll)))
			newVehicle.sqlId = tonumber(v.vehicleid)

			if(v.col1 == nil) then v.col1 = "000000" end
			if(v.col2 == nil) then v.col2 = "000000" end

			newVehicle:SetColors( Color( hex2rgb( v.col1 ) ),  Color( hex2rgb( v.col2 ) ) )
			self.vehicles[ newVehicle:GetId() ] = newVehicle;

        end
    end
end



function wVehicles:moduleUnLoaded()	
	for k,v in pairs(self.vehicles) do
		v:Remove()
	end
	self.vehicles = {}
end

function wVehicles:getBySqlId( _sqlid )	
	for k,v in pairs(self.vehicles) do
		if(v.sqlId == _sqlid) then
			return v
		end
	end
	return nil
end


function wVehicles:parseVehicleCommands(args)
	local 
		msg = args.text:lower();


	if msg:sub(1, 2) == "/v" then
		-- handle the command if it starts with /v
		msg = msg:sub(2);
		local params = msg:split(" ")
		local validActions = Set { "create", "park", "delete", "color", "enter", "respawn", "gc", "list" }

		local action = #params >= 2 and params[ 2 ]:lower() or nil

		if (action == nil or validActions[ action ] == nil) then
			return self:SendClientMessage(args.player, "Syntax: /v <create/gc/enter/list/park/respawn/color/delete>")
		end

		local isAdmin = self.admins[ tostring(args.player:GetSteamId()) ] ~= nil and true or false
		if isAdmin == false and self.allowPlayerUsage[ action ] == nil then
			return self:SendClientMessage(args.player, "You're not allowed to use this command!")
		end

		-- Syntax: /v gc
		-- gc as in "goclosest" - warps you into the closest vehicle from you as driver
		if(action == "gc") then
			local currentDistance, currentVehicle = -1, nil

			for k,v in pairs(self.vehicles) do
				thisDistance = getDistanceFromTo(args.player:GetPosition().x, args.player:GetPosition().y, v:GetPosition().x, v:GetPosition().y)
				if(thisDistance < currentDistance or currentDistance == -1) then
					currentDistance = thisDistance
					currentVehicle = v;
				end
			end

			if(currentVehicle ~= nil) then
				args.player:EnterVehicle(currentVehicle, 0)
			end
		end


		-- Syntax: /v list
		-- displays a list of the current vehicle in the database
		if(action == "list") then
			Network:Send(args.player, "wVehicles.ShowList")
		end

		-- Syntax: /v enter <id>
		-- warps you into the vehicle witht the given sql id as driver
		if(action == "enter") then
			-- create
			local vehicleId = #params >= 3 and tonumber( params[ 3 ] ) or nil
			local vehicleFound = vehicleId ~= nil and self:getBySqlId( vehicleId ) or nil
			if(vehicleFound == nil or vehicleId == nil) then
				self:SendClientMessage(args.player, "There is no vehicle with the id " .. vehicleId.. "!")
			end

			if(vehicleFound ~= nil) then
				args.player:EnterVehicle(vehicleFound, 0)
			end
		end

		-- Syntax: /v create <modelid>
		-- spawns a vehicle with the given model id and stores it in the database
		if(action == "create") then
			-- create
			local modelId = #params >= 3 and tonumber( params[ 3 ] ) or nil

			if modelId == nil or modelId < 1 or modelId > 91 then
				return self:SendClientMessage(args.player, "Syntax: /v <" .. action .. "> <modelid (1 - 91)>")
			end


			local newVehicle = self:CreateVehicle(modelId, args.player:GetPosition() + Vector3(0, 3, 0), args.player:GetAngle())

			args.player:EnterVehicle(newVehicle, 0)

			local 
				cmd = SQL:Query("insert into vehicles (modelid,x,y,z,a_pitch,a_roll,a_yaw,owner) values (?,?,?,?,?,?,?,?)")
				cmd:Bind( 1, modelId )
				cmd:Bind( 2, args.player:GetPosition().x )
				cmd:Bind( 3, args.player:GetPosition().y )
				cmd:Bind( 4, args.player:GetPosition().z )
				cmd:Bind( 5, newVehicle:GetAngle().pitch )
				cmd:Bind( 6, newVehicle:GetAngle().roll )
				cmd:Bind( 7, newVehicle:GetAngle().yaw )
				cmd:Bind( 8, args.player:GetSteamId().id )
				cmd:Execute()

			-- fetch the last inserted auto incremented id..
			cmd = SQL:Query("SELECT last_insert_rowid() as insert_id FROM vehicles")
			local result = cmd:Execute()

			if #result > 0 then
				newVehicle.sqlId = tonumber(result[1].insert_id);
			end

			if(newVehicle.sqlId == nil) then
				newVehicle:Remove()
				print("Something went horribly wrong..")
				return false
			end

			print("<Vehicle> Added to database:" .. newVehicle.sqlId)

			self.vehicles[ newVehicle:GetId() ] = newVehicle;

			self:SendClientMessage(args.player, newVehicle:GetName() .. " (SQLID: " .. newVehicle.sqlId ..") has been spawned.")


		-- Syntax: /v respawn
		-- respawns the vehicle you're currently in
		elseif (action == "respawn") then
			local myVehicle = args.player:GetVehicle()
			if(myVehicle == nil) then
				return self:SendClientMessage(args.player, "Enter a vehicle first.")
			end

			myVehicle:Respawn()
			args.player:EnterVehicle(myVehicle, 0)

		-- Syntax: /v color <col1> <col2>
		-- see colors.lua for a list of colors
		-- changes the color in which the vehicle should spawn
		-- note: vehicle colors only change after a vehicle respawns
		elseif (action == "color") then
			local myVehicle = args.player:GetVehicle()
			if(myVehicle == nil) then
				return self:SendClientMessage(args.player, "Enter a vehicle first.")
			end


			local col1 = #params >= 4 and params[ 3 ] or nil
			local col2 = #params >= 4 and params[ 4 ] or nil

			if col1 == nil or col2 == nil then
				return self:SendClientMessage(args.player, "Syntax: /v <" .. action .. "> <col1> <col2>")
			end

			if colors[ col1 ] == nil then
				return self:SendClientMessage(args.player, "Error: Color \"" .. col1 .. "\" is not defined.")
			end		

			if colors[ col2 ] == nil then
				return self:SendClientMessage(args.player, "Error: Color \"" .. col2 .. "\" is not defined.")
			end				

			myVehicle:SetColors( colors[ col1 ], colors[ col2 ] )
			myVehicle:Respawn()
			args.player:EnterVehicle(myVehicle, 0)


			local 
				cmd = SQL:Command("update vehicles set col1 = ?, col2 = ? WHERE vehicleid = ?")
				cmd:Bind( 1, rgbToHex( colors[ col1 ].r, colors[ col1 ].g, colors[ col1 ].b ) )
				cmd:Bind( 2, rgbToHex( colors[ col2 ].r, colors[ col2 ].g, colors[ col2 ].b ) )
				cmd:Bind( 3, self.vehicles[ myVehicle:GetId() ].sqlId )
				cmd:Execute()

			self:SendClientMessage(args.player, "This " .. myVehicle:GetName().. " will now spawn in " .. col1 .. " and " .. col2)

		-- Syntax: /v park
		-- will make the vehicle you're currently in spawn always at your current position
		elseif (action == "park") then
			-- park current vehicle
			local myVehicle = args.player:GetVehicle()
			if(myVehicle == nil) then
				return self:SendClientMessage(args.player, "Enter a vehicle first.")
			end


			local 
				cmd = SQL:Command("update vehicles set x = ?, y = ?, z = ?, a_pitch = ?, a_roll = ?, a_yaw = ? WHERE vehicleid = ?")
				cmd:Bind( 1, myVehicle:GetPosition().x )
				cmd:Bind( 2, myVehicle:GetPosition().y )
				cmd:Bind( 3, myVehicle:GetPosition().z )
				cmd:Bind( 4, myVehicle:GetAngle().pitch )
				cmd:Bind( 5, myVehicle:GetAngle().roll )
				cmd:Bind( 6, myVehicle:GetAngle().yaw )
				cmd:Bind( 7, self.vehicles[ myVehicle:GetId() ].sqlId )
				cmd:Execute()


			self:SendClientMessage(args.player, "This" .. myVehicle:GetName() .. " (SQLID: " .. self.vehicles[ myVehicle:GetId() ].sqlId ..") will now spawn here!")

		-- Syntax: /v delete
		-- permanently deletes the vehicle from the server & database
		elseif(action == "delete") then
			-- delete it
			local myVehicle = args.player:GetVehicle()
			if(myVehicle == nil) then
				return self:SendClientMessage(args.player, "Enter a vehicle first.")
			end

			local 
				cmd = SQL:Command("delete from vehicles where vehicleid = ?")
				cmd:Bind( 1, self.vehicles[ myVehicle:GetId() ].sqlId )
				cmd:Execute()

			self:SendClientMessage(args.player, myVehicle:GetName() .. " (SQLID: " .. self.vehicles[ myVehicle:GetId() ].sqlId ..") has been removed.")

			self.vehicles[ myVehicle:GetId() ] = nil;
			print("deleted type = " .. type(self.vehicles[ myVehicle:GetId() ]))
			myVehicle:Remove()
		end
		return false
	end

	return true
end
 

--
function rgbToHex ( nR, nG, nB )
	local sColor = ""
	nR = string.format ( "%X", nR )
	sColor = sColor .. ( ( string.len ( nR ) == 1 ) and ( "0" .. nR ) or nR )
	nG = string.format ( "%X", nG )
	sColor = sColor .. ( ( string.len ( nG ) == 1 ) and ( "0" .. nG ) or nG )
	nB = string.format ( "%X", nB )
	sColor = sColor .. ( ( string.len ( nB ) == 1 ) and ( "0" .. nB ) or nB )
	return sColor
end
function hex2rgb(hex)
	return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
end
-- 

function wVehicles:CreateVehicle(model, xyz, angle) -- model = int, xyz = Vector3, angle = Angle
	local veh, vehSpawnPos = {}, xyz
	veh.model_id = model
	veh.position = vehSpawnPos
	veh.angle = angle
	veh.enabled = true
	return Vehicle.Create(veh)
end

-- :)
function wVehicles:SendClientMessage(player, text)
	player:SendChatMessage(text, self.messageColor);
	return false
end


-- from http://stackoverflow.com/questions/656199/search-for-an-item-in-a-lua-list
function Set (list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end


function getDistanceFromTo(x1,y1,x2,y2) 
return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) 
end

function SetTemplate(args)
	local splittedText = args.text:split ( " " )	
        if ( splittedText [ 1 ] == "/tmp" ) then
			if args.player:GetState() ~= PlayerState.InVehicle then return end
				v = args.player:GetVehicle()	
				vtm = tostring(splittedText [ 2 ])
				vcl = tostring(v:GetColors())		
				local vc1 , vc2 = v:GetColors()
				
				if splittedText [ 2 ] == nil then
					vtm = " "
				end
			
				local spawnArgs = {}
				spawnArgs.position = args.player:GetPosition()
				spawnArgs.angle = args.player:GetAngle()
				spawnArgs.model_id = v:GetModelId()
				spawnArgs.world = args.player:GetWorld()
				spawnArgs.decal = v:GetDecal()
				spawnArgs.linear_velocity = v:GetLinearVelocity()
				spawnArgs.tone1 = vc1
				spawnArgs.tone2 = vc2
				spawnArgs.template = vtm
				v:Remove()
				local v = Vehicle.Create( spawnArgs )
				args.player:EnterVehicle( v, VehicleSeat.Driver )
				args.player:SendChatMessage( "New Template " .. tostring(vtm), Color( 255, 255, 100 ) )
			--	args.player:SendChatMessage( "GetOccupants" .. tostring(passangers), Color( 255, 255, 100 ) )
				
				
		end
	end
Events:Subscribe("PlayerChat", SetTemplate)

function SetDecal(args)
	local splittedText = args.text:split ( " " )	
        if ( splittedText [ 1 ] == "/dec" ) then
			if args.player:GetState() ~= PlayerState.InVehicle then return end
				v = args.player:GetVehicle()	
				vde = tostring(splittedText [ 2 ])
				vcl = tostring(v:GetColors())		
				local vc1 , vc2 = v:GetColors()
				
				if splittedText [ 2 ] == nil then
					vde = " "
				end
			
				local spawnArgs = {}
				spawnArgs.position = args.player:GetPosition()
				spawnArgs.angle = args.player:GetAngle()
				spawnArgs.model_id = v:GetModelId()
				spawnArgs.world = args.player:GetWorld()
				spawnArgs.linear_velocity = v:GetLinearVelocity()
				spawnArgs.template = v:GetTemplate()
				spawnArgs.tone1 = vc1
				spawnArgs.tone2 = vc2
				spawnArgs.decal = vde
				v:Remove()
				local v = Vehicle.Create( spawnArgs )
				args.player:EnterVehicle( v, VehicleSeat.Driver )
				args.player:SendChatMessage( "New Decal " .. tostring(vde), Color( 255, 255, 100 ) )
			--	args.player:SendChatMessage( "GetOccupants" .. tostring(passangers), Color( 255, 255, 100 ) )
				
				
		end
	end
Events:Subscribe("PlayerChat", SetDecal)

-- init
vehicleManager = wVehicles()