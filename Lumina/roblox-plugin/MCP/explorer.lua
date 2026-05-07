-- MCP Explorer Integration for Lumina
-- Provides detailed exploration capabilities for Roblox Studio

local MCPClient = require(script.Parent.client)

local MCPExplorer = {}
MCPExplorer.__index = MCPExplorer

function MCPExplorer:new(config)
	local self = setmetatable({}, MCPExplorer)
	self.client = MCPClient:new(config)
	self.isSyncing = false
	self.lastSyncTime = 0
	self.syncInterval = 5 -- seconds
	return self
end

function MCPExplorer:startAutoSync()
	if self.isSyncing then
		return
	end
	
	self.isSyncing = true
	
	-- Create a connection to game changes
	game.DescendantAdded:Connect(function(descendant)
		self:queueSync("descendant_added", descendant:GetFullName())
	end)
	
	game.DescendantRemoving:Connect(function(descendant)
		self:queueSync("descendant_removing", descendant:GetFullName())
	end)
	
	game.DescendantChanged:Connect(function(descendant)
		self:queueSync("descendant_changed", descendant:GetFullName())
	end)
	
	print("MCP Explorer auto-sync started")
end

function MCPExplorer:stopAutoSync()
	self.isSyncing = false
	print("MCP Explorer auto-sync stopped")
end

function MCPExplorer:queueSync(changeType, path)
	local currentTime = tick()
	
	-- Throttle sync requests
	if currentTime - self.lastSyncTime < self.syncInterval then
		return
	end
	
	self.lastSyncTime = currentTime
	
	-- Schedule sync for next heartbeat
	game:GetService("RunService").Heartbeat:Wait()
	
	if changeType == "descendant_added" or changeType == "descendant_removing" then
		self.client:syncExplorerTree()
	elseif changeType == "descendant_changed" then
		self.client:syncInstance(path)
	end
end

function MCPExplorer:getFullTree()
	return self.client:getServiceTree()
end

function MCPExplorer:getInstanceDetails(path, depth)
	depth = depth or 3
	
	local instance = self.client:findInstance(path)
	if not instance then
		return {
			success = false,
			error = "Instance not found: " .. path
		}
	end
	
	return {
		success = true,
		data = self.client:getInstanceTree(instance, depth)
	}
end

function MCPExplorer:searchInstances(query)
	return self.client:searchInstances(query)
end

function MCPExplorer:getInstanceProperties(path)
	local instance = self.client:findInstance(path)
	if not instance then
		return {
			success = false,
			error = "Instance not found: " .. path
		}
	end
	
	local properties = {}
	local allProperties = {}
	
	-- Get all properties using reflection
	local success, propertyList = pcall(function()
		return instance:GetChildren()
	end)
	
	if success then
		for _, property in pairs(propertyList) do
			-- This is a simplified approach - in a real implementation,
			-- you'd want to use reflection to get all actual properties
			local propSuccess, propValue = pcall(function()
				return instance[property.Name]
			end)
			
			if propSuccess and propValue ~= nil then
				local formattedValue = self.client:formatPropertyValue(propValue)
				if formattedValue then
					properties[property.Name] = formattedValue
				end
			end
		end
	end
	
	-- Get important properties
	local importantProps = self.client:getImportantProperties(instance)
	
	return {
		success = true,
		data = {
			all_properties = properties,
			important_properties = importantProps,
			instance_info = {
				name = instance.Name,
				className = instance.ClassName,
				path = instance:GetFullName(),
				parent = instance.Parent and instance.Parent:GetFullName() or nil,
				children_count = #instance:GetChildren()
			}
		}
	}
end

function MCPExplorer:createInstance(parentPath, className, instanceName)
	local parent = self.client:findInstance(parentPath)
	if not parent then
		return {
			success = false,
			error = "Parent not found: " .. parentPath
		}
	end
	
	local success, newInstance = pcall(function()
		local instance = Instance.new(className)
		instance.Name = instanceName or className
		instance.Parent = parent
		return instance
	end)
	
	if success then
		-- Sync the change
		self:queueSync("instance_created", newInstance:GetFullName())
		
		return {
			success = true,
			data = {
				instance_path = newInstance:GetFullName(),
				name = newInstance.Name,
				className = newInstance.ClassName
			}
		}
	else
		return {
			success = false,
			error = "Failed to create instance: " .. tostring(newInstance)
		}
	end
end

function MCPExplorer:modifyInstanceProperty(path, propertyName, value)
	local instance = self.client:findInstance(path)
	if not instance then
		return {
			success = false,
			error = "Instance not found: " .. path
		}
	end
	
	local success, error_msg = pcall(function()
		instance[propertyName] = value
	end)
	
	if success then
		-- Sync the change
		self:queueSync("property_changed", path)
		
		return {
			success = true,
			data = {
				path = path,
				property = propertyName,
				new_value = self.client:formatPropertyValue(value)
			}
		}
	else
		return {
			success = false,
			error = "Failed to modify property: " .. tostring(error_msg)
		}
	end
end

function MCPExplorer:deleteInstance(path)
	local instance = self.client:findInstance(path)
	if not instance then
		return {
			success = false,
			error = "Instance not found: " .. path
		}
	end
	
	local instanceInfo = {
		name = instance.Name,
		className = instance.ClassName,
		path = instance:GetFullName()
	}
	
	local success, error_msg = pcall(function()
		instance:Destroy()
	end)
	
	if success then
		-- Sync the change
		self:queueSync("instance_deleted", path)
		
		return {
			success = true,
			data = instanceInfo
		}
	else
		return {
			success = false,
			error = "Failed to delete instance: " .. tostring(error_msg)
		}
	end
end

function MCPExplorer:executeScript(scriptCode, environment)
	local success, result = pcall(function()
		-- Create a sandboxed environment for script execution
		local env = environment or {}
		env.game = game
		env.workspace = workspace
		env.print = print
		env.warn = warn
		
		-- Create the function
		local func, loadError = load(scriptCode, "MCP_Script", "t", env)
		
		if not func then
			error("Script compilation error: " .. tostring(loadError))
		end
		
		-- Execute the function
		return func()
	end)
	
	if success then
		return {
			success = true,
			data = {
				result = result,
				type = typeof(result)
			}
		}
	else
		return {
			success = false,
			error = "Script execution error: " .. tostring(result)
		}
	end
end

function MCPExplorer:getAnalytics()
	local analytics = {
		total_instances = 0,
		instance_types = {},
		services = {},
		largest_trees = {}
	}
	
	-- Count instances by type
	for _, instance in ipairs(game:GetDescendants()) do
		analytics.total_instances = analytics.total_instances + 1
		
		local className = instance.ClassName
		analytics.instance_types[className] = (analytics.instance_types[className] or 0) + 1
	end
	
	-- Service information
	for serviceName, service in pairs(self.client.services) do
		analytics.services[serviceName] = {
			name = service.Name,
			className = service.ClassName,
			children_count = #service:GetChildren()
		}
	end
	
	-- Find largest trees (services with most children)
	local serviceList = {}
	for serviceName, serviceData in pairs(analytics.services) do
		table.insert(serviceList, {
			name = serviceName,
			count = serviceData.children_count
		})
	end
	
	table.sort(serviceList, function(a, b) return a.count > b.count end)
	analytics.largest_trees = table.move(serviceList, 1, 5, 1, {})
	
	return analytics
end

return MCPExplorer
