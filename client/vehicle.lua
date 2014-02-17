class 'vehicleListGUI'


function vehicleListGUI:__init() 
	self.render = false
	self.GUI_vehiclelist = {}

	self.mainWindow = Window.Create()
	self.mainWindow:SetSize(Vector2(640, 400))
	self.mainWindow:SetPositionRel(Vector2(0.5, 0.5) - self.mainWindow:GetSizeRel()/2)
	self.mainWindow:SetTitle("Vehicles")
	self.mainWindow:SetVisible(self.render)

	local curWidth = 0;
	self.vehicleList = SortedList.Create(self.mainWindow)
	self.vehicleList:SetPosition(Vector2(1, 1))
	self.vehicleList:SetSize(Vector2(640, 400))
	self.vehicleList:AddColumn("localid", curWidth + 60)
	self.vehicleList:AddColumn("sqlid", curWidth + 60)
	self.vehicleList:AddColumn("model", curWidth + 170)
	self.vehicleList:AddColumn("x", curWidth + 110)
	self.vehicleList:AddColumn("y", curWidth + 110)
	self.vehicleList:AddColumn("z", curWidth + 110)
	self.vehicleList:SetButtonsVisible(true)


	Mouse:SetVisible(self.render)

	Network:Subscribe("wVehicles.ShowList", self, self.toggleVehicleList)
	Network:Subscribe("wVehicles.receiveVehicleList", self, self.fillVehicleList)

	Events:Subscribe("LocalPlayerInput", self, self.LocalPlayerInput )
	Events:Subscribe("Render", self, self.Render )
end

function vehicleListGUI:fillVehicleList(receivedList)

	self:clearList()
	for k,v in pairs(receivedList) do
		tmprow = self.vehicleList:AddItem("")
		tmprow:SetCellText(0, tostring(v.id))
		tmprow:SetCellText(1, tostring(k))
		tmprow:SetCellText(2, v.model)
		tmprow:SetCellText(3, tostring(v.x))
		tmprow:SetCellText(4, tostring(v.y))
		tmprow:SetCellText(5, tostring(v.z))


		-- k = local veh id
		self.GUI_vehiclelist[ k ] = tmprow;

	end
end


function vehicleListGUI:toggleVehicleList() 
	if self.render == true then
		self.render = false
	else
		self.render = true
	end


	Network:Send("wVehicles.requestVehicleList")

	self.mainWindow:SetVisible(self.render)
	Mouse:SetVisible(self.render)
end


function vehicleListGUI:clearList()
	-- clear the sortedlist of old entries first
	for k,v in pairs(self.GUI_vehiclelist) do
		self.vehicleList:RemoveItem(v)
	end
	self.GUI_vehiclelist = {}
end

function vehicleListGUI:LocalPlayerInput( args )
    if self.render == true and Game:GetState() == GUIState.Game then
        return false
    end
end


function vehicleListGUI:Render( args )
	if self.render == true and Game:GetState() == GUIState.Game and self.mainWindow:GetVisible() == true then
		-- is visible, handle selected row
		local selRow = self.vehicleList:GetSelectedRow()
		if selRow ~= nil then
			self.vehicleList:UnselectAll()
	    	self.render = false
			self.mainWindow:SetVisible(self.render)
			Mouse:SetVisible(self.render)
			Network:Send("wVehicles.putInVehicle", tonumber( selRow:GetCellText(0) ))
		end
	end
    if self.render == true and Game:GetState() == GUIState.Game and self.mainWindow:GetVisible() ~= true then
    	self.render = false
		self.mainWindow:SetVisible(self.render)
		Mouse:SetVisible(self.render)
    end
end

vehList = vehicleListGUI()