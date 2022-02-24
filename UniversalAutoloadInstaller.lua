-- ============================================================= --
-- Universal Autoload MOD - MANAGER
-- ============================================================= --

-- manager
UniversalAutoloadManager = {}
addModEventListener(UniversalAutoloadManager)

-- specialisation
g_specializationManager:addSpecialization('universalAutoload', 'UniversalAutoload', Utils.getFilename('UniversalAutoload.lua', g_currentModDirectory), true)

for vehicleName, vehicleType in pairs(g_vehicleTypeManager.types) do
	if vehicleName == 'trailer' or vehicleName == 'dynamicMountAttacherTrailer' or vehicleName == 'carFillable' or vehicleName == 'car' then
		if SpecializationUtil.hasSpecialization(FillUnit, vehicleType.specializations) and
		   SpecializationUtil.hasSpecialization(TensionBelts, vehicleType.specializations) then
			g_vehicleTypeManager:addSpecialization(vehicleName, 'universalAutoload')
		end
	end
end

-- tables
UniversalAutoload.ACTIONS = {
	["TOGGLE_LOADING"]        = "UNIVERSALAUTOLOAD_TOGGLE_LOADING",
	["UNLOAD_ALL"]            = "UNIVERSALAUTOLOAD_UNLOAD_ALL",
	["TOGGLE_TIPSIDE"]        = "UNIVERSALAUTOLOAD_TOGGLE_TIPSIDE",
	["TOGGLE_FILTER"]         = "UNIVERSALAUTOLOAD_TOGGLE_FILTER",
	["CYCLE_MATERIAL_FW"]     = "UNIVERSALAUTOLOAD_CYCLE_MATERIAL_FW",
	["CYCLE_MATERIAL_BW"]     = "UNIVERSALAUTOLOAD_CYCLE_MATERIAL_BW",
	["SELECT_ALL_MATERIALS"]  = "UNIVERSALAUTOLOAD_SELECT_ALL_MATERIALS",
	["CYCLE_CONTAINER_FW"]    = "UNIVERSALAUTOLOAD_CYCLE_CONTAINER_FW",
	["CYCLE_CONTAINER_BW"]    = "UNIVERSALAUTOLOAD_CYCLE_CONTAINER_BW",
	["SELECT_ALL_CONTAINERS"] = "UNIVERSALAUTOLOAD_SELECT_ALL_CONTAINERS",
	["TOGGLE_BELTS"]	      = "UNIVERSALAUTOLOAD_TOGGLE_BELTS",
	["TOGGLE_DOOR"]           = "UNIVERSALAUTOLOAD_TOGGLE_DOOR",
	["TOGGLE_CURTAIN"]	      = "UNIVERSALAUTOLOAD_TOGGLE_CURTAIN"
}

UniversalAutoload.WARNINGS = {
	[1] = "warning_UNIVERSALAUTOLOAD_CLEAR_UNLOADING_AREA",
	[2] = "warning_UNIVERSALAUTOLOAD_NO_OBJECTS_FOUND"
}

UniversalAutoload.CONTAINERS = {
	[1] = "ALL",
	[2] = "EURO_PALLET",
	[3] = "BIGBAG_PALLET",
	[4] = "LIQUID_TANK",
	[5] = "BIGBAG",
	[6] = "BALE"
}

-- DEFINE DEFAULTS FOR CONTAINER TYPES
UniversalAutoload.ALL            = { sizeX = 1.250, sizeY = 0.850, sizeZ = 0.850 }
UniversalAutoload.EURO_PALLET    = { sizeX = 1.250, sizeY = 0.790, sizeZ = 0.850 }
UniversalAutoload.BIGBAG_PALLET  = { sizeX = 1.525, sizeY = 1.075, sizeZ = 1.200 }
UniversalAutoload.LIQUID_TANK    = { sizeX = 1.433, sizeY = 1.500, sizeZ = 1.415 }
UniversalAutoload.BIGBAG         = { sizeX = 1.050, sizeY = 2.000, sizeZ = 0.900 }
UniversalAutoload.BALE           = { isBale=true }

UniversalAutoload.VEHICLES = {}
UniversalAutoload.UNKNOWN_TYPES = {}

-- IMPORT VEHICLE CONFIGURATIONS
UniversalAutoload.VEHICLE_CONFIGURATIONS = {}
function UniversalAutoload.ImportVehicleConfigurations(xmlFilename)

	print("  IMPORT supported vehicle configurations")
	local xmlFile = XMLFile.load("configXml", xmlFilename, UniversalAutoload.xmlSchema)
	if xmlFile ~= 0 then
	
		local i = 0
		while true do
			local configKey = string.format("universalAutoload.vehicleConfigurations.vehicleConfiguration(%d)", i)

			if not xmlFile:hasProperty(configKey) then
				break
			end

			local configFileName = xmlFile:getValue(configKey.."#configFileName")
			
			UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName] = {}
			local config = UniversalAutoload.VEHICLE_CONFIGURATIONS[configFileName]
			config.selectedConfigs = xmlFile:getValue(configKey.."#selectedConfigs")
			config.width  = xmlFile:getValue(configKey..".loadingArea#width")
			config.length = xmlFile:getValue(configKey..".loadingArea#length")
			config.height = xmlFile:getValue(configKey..".loadingArea#height")
			config.offset = xmlFile:getValue(configKey..".loadingArea#offset", "0 0 0", true)
			config.isCurtainTrailer = xmlFile:getValue(configKey..".options#isCurtainTrailer", false)
			config.enableRearLoading = xmlFile:getValue(configKey..".options#enableRearLoading", false)
			config.noLoadingIfUnfolded = xmlFile:getValue(configKey..".options#noLoadingIfUnfolded", false)
			config.noLoadingIfFolded = xmlFile:getValue(configKey..".options#noLoadingIfFolded", false)
			config.showDebug = xmlFile:getValue(configKey..".options#showDebug", false)
			
			print("  >> "..configFileName)

			i = i + 1
		end

		xmlFile:delete()
	end
end

-- IMPORT CONTAINER TYPE DEFINITIONS
UniversalAutoload.LOADING_TYPE_CONFIGURATIONS = {}
function UniversalAutoload.ImportContainerTypeConfigurations(xmlFilename)

	print("  IMPORT container types")
	local xmlFile = XMLFile.load("configXml", xmlFilename, UniversalAutoload.xmlSchema)
	if xmlFile ~= 0 then

		local key = "universalAutoload.containerTypeConfigurations"
		local i = 0
		while true do
			local containerTypeKey = string.format("%s.containerTypeConfiguration(%d)", key, i)

			if not xmlFile:hasProperty(containerTypeKey) then
				break
			end

			local containerType = xmlFile:getValue(containerTypeKey.."#containerType")
			if tableContainsValue(UniversalAutoload.CONTAINERS, containerType) then
			
				local default = UniversalAutoload[containerType] or {}
				print("  "..containerType..":")
				
				local j = 0
				while true do
					local objectTypeKey = string.format("%s.objectType(%d)", containerTypeKey, j)
					
					if not xmlFile:hasProperty(objectTypeKey) then
						break
					end
				
					local name = xmlFile:getValue(objectTypeKey.."#name")
					UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] = {}
					newType = UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name]
					newType.name = name
					newType.type = containerType or "ALL"
					newType.containerIndex = UniversalAutoload.CONTAINERS_INDEX[containerType] or 1
					newType.sizeX = xmlFile:getValue(objectTypeKey.."#sizeX", default.sizeX or 1.5)
					newType.sizeY = xmlFile:getValue(objectTypeKey.."#sizeY", default.sizeY or 1.5)
					newType.sizeZ = xmlFile:getValue(objectTypeKey.."#sizeZ", default.sizeZ or 1.5)
					newType.isBale = xmlFile:getValue(objectTypeKey.."#isBale", default.isBale or false)
					newType.alwaysRotate = xmlFile:getValue(objectTypeKey.."#alwaysRotate", default.alwaysRotate or false)
					print(string.format("  >> %s [%.3f, %.3f, %.3f] %s", newType.name,
						newType.sizeX, newType.sizeY, newType.sizeZ, tostring(newType.alwaysRotate) ))
					
					j = j + 1
				end
				
			else
				print("  UNKNOWN CONTAINER TYPE: "..tostring(containerType))
			end

			i = i + 1
		end

		xmlFile:delete()
	end

	print("  ADDITIONAL container types:")
    for index, fillType in ipairs(g_fillTypeManager.fillTypes) do
        if fillType.palletFilename ~= nil then	
			local xmlFile = XMLFile.load("configXml", fillType.palletFilename, Vehicle.xmlSchema)
			if xmlFile ~= 0 then
				--print( "  >> " .. fillType.palletFilename )

				local i3d_path = xmlFile:getValue("vehicle.base.filename")
				local name = UniversalAutoload.getObjectNameFromPath(i3d_path)
				
				if UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] == nil then
				
					local category = xmlFile:getValue("vehicle.storeData.category")
					local width = xmlFile:getValue("vehicle.base.size#width", 1.5)
					local height = xmlFile:getValue("vehicle.base.size#height", 1.5)
					local length = xmlFile:getValue("vehicle.base.size#length", 1.5)
					
					local containerType
					if category == "bigbagPallets" then containerType = "BIGBAG_PALLET"
					elseif name == "liquidTank" then containerType = "LIQUID_TANK"
					elseif name == "bigBag" then containerType = "BIGBAG"
					--elseif string.find(i3d_path, "FS22_Seedpotato_Farm_Pack") then containerType = "POTATOBOX"
					else
						containerType = "ALL"
						print("UNKNOWN CONTAINER TYPE: "..name.." - "..category)
					end

					UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name] = {}
					newType = UniversalAutoload.LOADING_TYPE_CONFIGURATIONS[name]
					newType.name = name
					newType.type = containerType or "ALL"
					newType.containerIndex = UniversalAutoload.CONTAINERS_INDEX[containerType] or 1
					newType.sizeX = width
					newType.sizeY = height
					newType.sizeZ = length
					newType.isBale = false
					newType.alwaysRotate = false
					newType.width = math.min(newType.sizeX, newType.sizeZ)
					newType.length = math.max(newType.sizeX, newType.sizeZ)
						
					print(string.format("  >> %s [%.3f, %.3f, %.3f] - %s", newType.name,
						newType.sizeX, newType.sizeY, newType.sizeZ, containerType ))
						
				end
	
			end
			--DebugUtil.printTableRecursively(fillType, "--", 0, 1)
        end
    end


	
end

function UniversalAutoload.detectKeybindingConflicts()
	--DETECT 'T' KEYS CONFLICT
	if g_currentMission.missionDynamicInfo.isMultiplayer and not g_dedicatedServer then

		local chatKey = ""
		local containerKey = "KEY_t"
		local xmlFile = loadXMLFile('TempXML', g_gui.inputManager.settingsPath)	
		local actionBindingCounter = 0
		if xmlFile ~= 0 then
			while true do
				local key = string.format('inputBinding.actionBinding(%d)', actionBindingCounter)
				local actionString = getXMLString(xmlFile, key .. '#action')
				if actionString == nil then
					break
				end
				if actionString == 'CHAT' then
					local i = 0
					while true do
						local bindingKey = key .. string.format('.binding(%d)',i)
						local bindingInput = getXMLString(xmlFile, bindingKey .. '#input')
						if bindingInput == "KEY_t" then
							print("  Using 'KEY_t' for 'CHAT'")
							chatKey = bindingInput
						elseif bindingInput == nil then
							break
						end

						i = i + 1
					end
				end
				
				if actionString == 'UNIVERSALAUTOLOAD_CYCLE_CONTAINER_FW' then
					local i = 0
					while true do
						local bindingKey = key .. string.format('.binding(%d)',i)
						local bindingInput = getXMLString(xmlFile, bindingKey .. '#input')
						if bindingInput ~= nil then
							print("  Using '"..bindingInput.."' for 'CYCLE_CONTAINER'")
							containerKey = bindingInput
						elseif bindingInput == nil then
							break
						end

						i = i + 1
					end
				end
				
				actionBindingCounter = actionBindingCounter + 1
			end
		end
		delete(xmlFile)
		
		if chatKey == containerKey then
			print("**CHAT KEY CONFLICT DETECTED** - Disabling CYCLE_CONTAINER for Multiplayer")
			print("(Please reassign 'CHAT' or 'CYCLE_CONTAINER' to a different key and RESTART the game)")
			UniversalAutoload.chatKeyConflict = true
		end
		
	end
end

function UniversalAutoloadManager:loadMap(name)

	if g_modIsLoaded["FS22_Seedpotato_Farm_Pack"] then
		print("** Seedpotato Farm Pack is loaded **")
		table.insert(UniversalAutoload.CONTAINERS, "POTATOBOX")
		UniversalAutoload.POTATOBOX = { sizeX = 1.850, sizeY = 1.100, sizeZ = 1.200 }
	end

	UniversalAutoload.CONTAINERS_INDEX = {}
	for i, key in ipairs(UniversalAutoload.CONTAINERS) do
		UniversalAutoload.CONTAINERS_INDEX[key] = i
	end
	
	UniversalAutoload.MATERIALS = {}
	table.insert(UniversalAutoload.MATERIALS, "ALL" )
	UniversalAutoload.MATERIALS_FILLTYPE = {}
	table.insert( UniversalAutoload.MATERIALS_FILLTYPE, {["title"]= g_i18n:getText("universalAutoload_ALL")} )
	for index, fillType in ipairs(g_fillTypeManager.fillTypes) do
		if fillType.name ~= "UNKNOWN" then
			table.insert(UniversalAutoload.MATERIALS, fillType.name )
			table.insert(UniversalAutoload.MATERIALS_FILLTYPE, fillType )
		end
	end
	
	--print("  ALL MATERIALS:")
	UniversalAutoload.MATERIALS_INDEX = {}
	for i, key in ipairs(UniversalAutoload.MATERIALS) do
		-- print("  - "..i..": "..key.." = "..UniversalAutoload.MATERIALS_FILLTYPE[i].title)
		UniversalAutoload.MATERIALS_INDEX[key] = i
	end
		
	local vehicleSettingsFile = Utils.getFilename("config/SupportedVehicles.xml", UniversalAutoload.path)
	UniversalAutoload.ImportVehicleConfigurations(vehicleSettingsFile)
	local ContainerTypeSettingsFile = Utils.getFilename("config/ContainerTypes.xml", UniversalAutoload.path)
	UniversalAutoload.ImportContainerTypeConfigurations(ContainerTypeSettingsFile)
	
	UniversalAutoload.detectKeybindingConflicts()

end

function UniversalAutoloadManager:deleteMap()
end

function tableContainsValue(container, value)
	for k, v in pairs(container) do
		if v == value then
			return true
		end
	end
	return false
end
