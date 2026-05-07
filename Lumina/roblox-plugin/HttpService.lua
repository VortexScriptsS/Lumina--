-- HttpService wrapper for Lumina Plugin
-- Handles communication with the Python backend

local HttpService = game:GetService("HttpService")

local HttpWrapper = {}
HttpWrapper.__index = HttpWrapper

function HttpWrapper:new(config)
	local self = setmetatable({}, HttpWrapper)
	self.config = config or {
		base_url = "http://localhost:8000",
		plugin_key = "your-secret-key-here",
		timeout = 30
	}
	return self
end

function HttpWrapper:makeRequest(endpoint, method, data)
	local url = self.config.base_url .. endpoint
	
	local headers = {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. self.config.plugin_key,
		["User-Agent"] = "Lumina-Roblox-Plugin/1.0.0"
	}
	
	local requestOptions = {
		Url = url,
		Method = method,
		Headers = headers
	}
	
	if data and (method == "POST" or method == "PUT") then
		requestOptions.Body = HttpService:JSONEncode(data)
	end
	
	local success, result = pcall(function()
		return HttpService:RequestAsync(requestOptions)
	end)
	
	if not success then
		return false, {
			error = "Request failed: " .. tostring(result),
			status_code = 0
		}
	end
	
	if result.Success then
		local parseSuccess, parsedData = pcall(function()
			return HttpService:JSONDecode(result.Body)
		end)
		
		if parseSuccess then
			return true, parsedData
		else
			return true, { raw_response = result.Body }
		end
	else
		return false, {
			error = "HTTP Error: " .. (result.StatusMessage or "Unknown error"),
			status_code = result.StatusCode,
			response_body = result.Body
		}
	end
end

function HttpWrapper:sendChatMessage(message, context)
	local requestData = {
		message = message,
		source = "roblox",
		context = context or {}
	}
	
	return self:makeRequest("/api/chat", "POST", requestData)
end

function HttpWrapper:getModels()
	return self:makeRequest("/api/models", "GET")
end

function HttpWrapper:checkHealth()
	return self:makeRequest("/api/health", "GET")
end

function HttpWrapper:sendMCPRequest(action, parameters)
	local requestData = {
		action = action,
		parameters = parameters or {}
	}
	
	return self:makeRequest("/api/mcp/explorer", "POST", requestData)
end

function HttpWrapper:testConnection()
	local success, result = self:checkHealth()
	if success then
		return true, "Connection successful"
	else
		return false, "Connection failed: " .. (result.error or "Unknown error")
	end
end

function HttpWrapper:sendStartupHello()
	-- Send a hello message when plugin starts
	local helloMessage = "Hello from Lumina Roblox Plugin! I'm ready to assist with Lua scripting and animations."
	local context = {
		plugin_version = "1.0.0",
		roblox_studio = true,
		startup_time = tick()
	}
	
	local success, result = self:sendChatMessage(helloMessage, context)
	
	if success then
		print("Lumina: Successfully connected to backend!")
		print("Backend response:", result.response)
		return true, result
	else
		warn("Lumina: Failed to connect to backend:", result.error)
		return false, result
	end
end

return HttpWrapper
