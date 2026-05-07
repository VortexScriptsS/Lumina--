-- MCP (Model Context Protocol) Client for Lumina
-- Enables AI to see and interact with Roblox Studio Explorer

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local Teams = game:GetService("Teams")
local SoundService = game:GetService("SoundService")
local Chat = game:GetService("Chat")
local LocalizationService = game:GetService("LocalizationService")
local TestService = game:GetService("TestService")

local MCPClient = {}
MCPClient.__index = MCPClient

function MCPClient:new(config)
	local self = setmetatable({}, MCPClient)
	self.config = config or {
		base_url = "http://localhost:8000",
		plugin_key = "your-secret-key-here"
	}
	self.services = {
		Workspace = Workspace,
		Lighting = Lighting,
		ReplicatedFirst = ReplicatedFirst,
		ReplicatedStorage = ReplicatedStorage,
		ServerScriptService = ServerScriptService,
		ServerStorage = ServerStorage,
		StarterGui = StarterGui,
		StarterPack = StarterPack,
		StarterPlayer = StarterPlayer,
		Teams = Teams,
		SoundService = SoundService,
		Chat = Chat,
		LocalizationService = LocalizationService,
		TestService = TestService,
		game = game
	}
	return self
end

function MCPClient:getInstanceTree(instance, maxDepth, currentDepth)
	maxDepth = maxDepth or 3
	currentDepth = currentDepth or 0
	
	if currentDepth >= maxDepth then
		return {
			name = instance.Name,
			className = instance.ClassName,
			path = instance:GetFullName(),
			children_count = #instance:GetChildren(),
			deep_truncated = true
		}
	end
	
	local children = {}
	for _, child in ipairs(instance:GetChildren()) do
		table.insert(children, self:getInstanceTree(child, maxDepth, currentDepth + 1))
	end
	
	local instanceData = {
		name = instance.Name,
		className = instance.ClassName,
		path = instance:GetFullName(),
		children = children,
		properties = self:getImportantProperties(instance)
	}
	
	return instanceData
end

function MCPClient:getImportantProperties(instance)
	local importantProperties = {
		"Name", "ClassName", "Parent", "Anchored", "CanCollide", "Position", 
		"Size", "CFrame", "Rotation", "Transparency", "BrickColor", "Material",
		"Reflectance", "Enabled", "Visible", "Archivable"
	}
	
	local properties = {}
	
	for _, propName in ipairs(importantProperties) do
		local success, value = pcall(function()
			return instance[propName]
		end)
		
		if success and value ~= nil then
			local formattedValue = self:formatPropertyValue(value)
			if formattedValue then
				properties[propName] = formattedValue
			end
		end
	end
	
	return properties
end

function MCPClient:formatPropertyValue(value)
	if typeof(value) == "string" then
		return value
	elseif typeof(value) == "number" then
		return tostring(value)
	elseif typeof(value) == "boolean" then
		return tostring(value)
	elseif typeof(value) == "Vector3" then
		return string.format("Vector3.new(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
	elseif typeof(value) == "CFrame" then
		local pos, look = value.Position, value.LookVector
		return string.format("CFrame.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
	elseif typeof(value) == "Color3" then
		return string.format("Color3.new(%.3f, %.3f, %.3f)", value.R, value.G, value.B)
	elseif typeof(value) == "EnumItem" then
		return value.Name
	elseif typeof(value) == "Instance" then
		return value:GetFullName()
	else
		return "[" .. typeof(value) .. "]"
	end
end

function MCPClient:findInstance(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	
	local current = game
	for _, part in ipairs(parts) do
		if current then
			current = current:FindFirstChild(part)
		else
			break
		end
	end
	
	return current
end

function MCPClient:getServiceTree()
	local servicesTree = {}
	
	for serviceName, service in pairs(self.services) do
		servicesTree[serviceName] = {
			name = service.Name,
			className = service.ClassName,
			path = service:GetFullName(),
			children_count = #service:GetChildren(),
			sample_children = {}
		}
		
		-- Get first few children as sample
		for i, child in ipairs(service:GetChildren()) do
			if i <= 5 then -- Limit to first 5 children
				table.insert(servicesTree[serviceName].sample_children, {
					name = child.Name,
					className = child.ClassName,
					path = child:GetFullName()
				})
			end
		end
	end
	
	return servicesTree
end

function MCPClient:sendToBackend(data)
	local success, result = pcall(function()
		local headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. self.config.plugin_key
		}
		
		return HttpService:RequestAsync(self.config.base_url .. "/api/mcp/explorer", {
			Url = self.config.base_url .. "/api/mcp/explorer",
			Method = "POST",
			Headers = headers,
			Body = HttpService:JSONEncode(data)
		})
	end)
	
	if success and result.Success then
		local parseSuccess, parsedData = pcall(function()
			return HttpService:JSONDecode(result.Body)
		end)
		
		if parseSuccess then
			return true, parsedData
		else
			return false, { error = "Failed to parse response" }
		end
	else
		return false, { error = "Request failed: " .. tostring(result) }
	end
end

function MCPClient:syncExplorerTree()
	local treeData = {
		action = "sync_tree",
		data = {
			services = self:getServiceTree(),
			timestamp = tick()
		}
	}
	
	return self:sendToBackend(treeData)
end

function MCPClient:syncInstance(path)
	local instance = self:findInstance(path)
	
	if not instance then
		return false, { error = "Instance not found: " .. path }
	end
	
	local instanceData = {
		action = "sync_instance",
		data = {
			instance = self:getInstanceTree(instance, 2), -- 2 levels deep
			path = path,
			timestamp = tick()
		}
	}
	
	return self:sendToBackend(instanceData)
end

function MCPClient:handleRequest(request)
	if request.action == "get_tree" then
		return {
			success = true,
			data = self:getServiceTree()
		}
	elseif request.action == "get_instance" then
		local path = request.parameters.path
		if not path then
			return {
				success = false,
				error = "Path parameter required"
			}
		end
		
		local instance = self:findInstance(path)
		if not instance then
			return {
				success = false,
				error = "Instance not found: " .. path
			}
		end
		
		return {
			success = true,
			data = self:getInstanceTree(instance, request.parameters.depth or 3)
		}
	elseif request.action == "search" then
		local query = request.parameters.query
		if not query then
			return {
				success = false,
				error = "Query parameter required"
			}
		end
		
		return {
			success = true,
			data = self:searchInstances(query)
		}
	else
		return {
			success = false,
			error = "Unknown action: " .. request.action
		}
	end
end

function MCPClient:searchInstances(query)
	local results = {}
	local queryLower = string.lower(query)
	
	-- Search through all services
	for serviceName, service in pairs(self.services) do
		local serviceResults = self:searchInInstance(service, queryLower, serviceName)
		for _, result in ipairs(serviceResults) do
			table.insert(results, result)
		end
	end
	
	return results
end

function MCPClient:searchInInstance(instance, query, basePath)
	local results = {}
	local currentPath = basePath .. "." .. instance.Name
	
	-- Check if current instance matches
	if string.find(string.lower(instance.Name), query) or 
	   string.find(string.lower(instance.ClassName), query) then
		table.insert(results, {
			name = instance.Name,
			className = instance.ClassName,
			path = currentPath,
			match_type = "name_or_class"
		})
	end
	
	-- Search children
	for _, child in ipairs(instance:GetChildren()) do
		local childResults = self:searchInInstance(child, query, currentPath)
		for _, result in ipairs(childResults) do
			table.insert(results, result)
		end
	end
	
	return results
end

return MCPClient
