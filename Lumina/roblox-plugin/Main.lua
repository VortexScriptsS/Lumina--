-- Lumina Plugin - AI-powered platform for Roblox Studio
-- Main plugin entry point

local PluginManager = plugin:CreateToolbar("Lumina")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StudioService = game:GetService("StudioService")

-- Plugin configuration
local CONFIG = {
	BACKEND_URL = "http://localhost:8000",
	PLUGIN_KEY = "your-secret-key-here",
	PLUGIN_NAME = "Lumina AI Assistant",
	PLUGIN_VERSION = "1.0.0"
}

-- Create plugin UI (no icon to avoid loading issues)
local PluginUI = PluginManager:CreateButton(
	"Open Lumina",
	"Open Lumina AI Assistant"
)

-- Create main widget
local WidgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	false,
	200,
	300,
	150,
	150
)

local LuminaWidget = plugin:CreateDockWidgetPluginGui("LuminaWidget", WidgetInfo)
LuminaWidget.Title = CONFIG.PLUGIN_NAME

-- UI Elements
local MainFrame = Instance.new("ScrollingFrame")
MainFrame.Size = UDim2.new(1, -10, 1, -10)
MainFrame.Position = UDim2.new(0, 5, 0, 5)
MainFrame.BackgroundTransparency = 0
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = LuminaWidget

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = MainFrame

-- Title Label
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.BackgroundTransparency = 1
TitleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Text = CONFIG.PLUGIN_NAME
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextScaled = true
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.LayoutOrder = 1
TitleLabel.Parent = MainFrame

-- Input TextBox
local InputFrame = Instance.new("Frame")
InputFrame.Size = UDim2.new(1, 0, 0, 80)
InputFrame.BackgroundTransparency = 0
InputFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
InputFrame.BorderSizePixel = 0
InputFrame.LayoutOrder = 2
InputFrame.Parent = MainFrame

local InputLabel = Instance.new("TextLabel")
InputLabel.Size = UDim2.new(1, 0, 0, 20)
InputLabel.Position = UDim2.new(0, 0, 0, 5)
InputLabel.BackgroundTransparency = 1
InputLabel.Text = "Ask Lumina:"
InputLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
InputLabel.TextSize = 14
InputLabel.Font = Enum.Font.SourceSans
InputLabel.TextXAlignment = Enum.TextXAlignment.Left
InputLabel.Parent = InputFrame

local InputTextBox = Instance.new("TextBox")
InputTextBox.Size = UDim2.new(1, -10, 0, 50)
InputTextBox.Position = UDim2.new(0, 5, 0, 25)
InputTextBox.BackgroundTransparency = 0
InputTextBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
InputTextBox.BorderSizePixel = 1
InputTextBox.BorderColor3 = Color3.fromRGB(60, 60, 60)
InputTextBox.Text = ""
InputTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
InputTextBox.TextSize = 14
InputTextBox.Font = Enum.Font.SourceSans
InputTextBox.TextWrapped = true
InputTextBox.MultiLine = true
InputTextBox.PlaceholderText = "Enter your question about Lua scripting, animations, or math..."
InputTextBox.Parent = InputFrame

-- Send Button
local SendButton = Instance.new("TextButton")
SendButton.Size = UDim2.new(0, 80, 0, 30)
SendButton.Position = UDim2.new(1, -85, 1, -35)
SendButton.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
SendButton.BorderSizePixel = 0
SendButton.Text = "Send"
SendButton.TextColor3 = Color3.fromRGB(0, 0, 0)
SendButton.TextSize = 14
SendButton.Font = Enum.Font.SourceSansBold
SendButton.Parent = InputFrame

-- Response Display
local ResponseFrame = Instance.new("Frame")
ResponseFrame.Size = UDim2.new(1, 0, 0, 200)
ResponseFrame.BackgroundTransparency = 0
ResponseFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ResponseFrame.BorderSizePixel = 0
ResponseFrame.LayoutOrder = 3
ResponseFrame.Parent = MainFrame

local ResponseLabel = Instance.new("TextLabel")
ResponseLabel.Size = UDim2.new(1, 0, 0, 20)
ResponseLabel.Position = UDim2.new(0, 0, 0, 5)
ResponseLabel.BackgroundTransparency = 1
ResponseLabel.Text = "AI Response:"
ResponseLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ResponseLabel.TextSize = 14
ResponseLabel.Font = Enum.Font.SourceSans
ResponseLabel.TextXAlignment = Enum.TextXAlignment.Left
ResponseLabel.Parent = ResponseFrame

local ResponseTextBox = Instance.new("TextLabel")
ResponseTextBox.Size = UDim2.new(1, -10, 1, -30)
ResponseTextBox.Position = UDim2.new(0, 5, 0, 25)
ResponseTextBox.BackgroundTransparency = 0
ResponseTextBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ResponseTextBox.BorderSizePixel = 1
ResponseTextBox.BorderColor3 = Color3.fromRGB(60, 60, 60)
ResponseTextBox.Text = ""
ResponseTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
ResponseTextBox.TextSize = 12
ResponseTextBox.Font = Enum.Font.SourceSans
ResponseTextBox.TextWrapped = true
ResponseTextBox.TextXAlignment = Enum.TextXAlignment.Left
ResponseTextBox.TextYAlignment = Enum.TextYAlignment.Top
ResponseTextBox.Parent = ResponseFrame

-- Preview Button Frame
local PreviewFrame = Instance.new("Frame")
PreviewFrame.Size = UDim2.new(1, 0, 0, 40)
PreviewFrame.BackgroundTransparency = 0
PreviewFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
PreviewFrame.BorderSizePixel = 0
PreviewFrame.LayoutOrder = 4
PreviewFrame.Parent = MainFrame

local PreviewButton = Instance.new("TextButton")
PreviewButton.Size = UDim2.new(0, 120, 0, 30)
PreviewButton.Position = UDim2.new(0.5, -60, 0.5, -15)
PreviewButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
PreviewButton.BorderSizePixel = 0
PreviewButton.Text = "▶ Preview Animation"
PreviewButton.TextColor3 = Color3.fromRGB(255, 255, 255)
PreviewButton.TextSize = 12
PreviewButton.Font = Enum.Font.SourceSansBold
PreviewButton.Parent = PreviewFrame

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.SourceSans
StatusLabel.LayoutOrder = 5
StatusLabel.Parent = MainFrame

-- Load BackendClient wrapper
local HttpWrapper = require(script.Parent.BackendClient):new({
	base_url = CONFIG.BACKEND_URL,
	plugin_key = CONFIG.PLUGIN_KEY
})

-- Send message to backend
function sendMessage(message)
	StatusLabel.Text = "Thinking..."
	
	local context = {
		game_name = game.Name,
		place_id = game.PlaceId,
		studio_version = StudioService.StudioVersion
	}
	
	local success, response = HttpWrapper:sendChatMessage(message, context)
	
	if success then
		-- Check if this is a keyframe animation response
		if response.response and string.find(response.response, '{"keyframes"') then
			-- Try to parse as JSON keyframe data
			local parseSuccess, keyframeData = pcall(function()
				-- Clean up the response to extract only JSON
				local jsonStart = string.find(response.response, "{")
				local jsonEnd = string.find(response.response, "}", -1)
				if jsonStart and jsonEnd then
					local jsonStr = string.sub(response.response, jsonStart, jsonEnd)
					return game:GetService("HttpService"):JSONDecode(jsonStr)
				end
				return nil
			end)
			
			if parseSuccess and keyframeData.keyframes then
				-- Build KeyframeSequence object
				local animSuccess = buildKeyframeAnimation(keyframeData, message)
				if animSuccess then
					ResponseTextBox.Text = "✅ Keyframe animation created successfully!\n\n" .. response.response
					StatusLabel.Text = "Animation created 🎬"
				else
					ResponseTextBox.Text = "❌ Failed to create animation object\n\n" .. response.response
					StatusLabel.Text = "Animation error"
				end
			else
				-- Regular response display
				ResponseTextBox.Text = response.response or "No response received"
				local statusText = string.format("Model: %s (%.2fs)", 
					response.model_used or "unknown", 
					response.processing_time or 0)
				
				-- Add thinking indicator if DeepSeek model was used
				if response.thinking and response.thinking ~= "" then
					statusText = statusText .. " 🧠"
					-- Store thinking for potential display
					_G.LastThinking = response.thinking
				end
				
				StatusLabel.Text = statusText
			end
		else
			-- Regular response display
			ResponseTextBox.Text = response.response or "No response received"
			local statusText = string.format("Model: %s (%.2fs)", 
				response.model_used or "unknown", 
				response.processing_time or 0)
			
			-- Add thinking indicator if DeepSeek model was used
			if response.thinking and response.thinking ~= "" then
				statusText = statusText .. " 🧠"
				-- Store thinking for potential display
				_G.LastThinking = response.thinking
			end
			
			StatusLabel.Text = statusText
		end
	else
		ResponseTextBox.Text = "Error: " .. tostring(response.error or response)
		StatusLabel.Text = "Error occurred"
	end
end

-- Event handlers
SendButton.MouseButton1Click:Connect(function()
	local message = InputTextBox.Text
	if message and message ~= "" then
		sendMessage(message)
	end
end)

InputTextBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		local message = InputTextBox.Text
		if message and message ~= "" then
			sendMessage(message)
		end
	end
end)

PluginUI.Click:Connect(function()
	LuminaWidget.Enabled = not LuminaWidget.Enabled
end)

-- MCP Integration placeholder
local MCP = {}

function MCP:getExplorerTree()
	-- This will be implemented when MCP integration is complete
	local success, response = HttpWrapper:makeRequest(
		CONFIG.BACKEND_URL .. "/api/mcp/explorer",
		"POST",
		{
			action = "get_tree",
			parameters = {}
		}
	)
	
	if success then
		return response.data
	else
		return nil
	end
end

function MCP:getInstanceDetails(path)
	local success, response = HttpWrapper:makeRequest(
		CONFIG.BACKEND_URL .. "/api/mcp/explorer",
		"POST",
		{
			action = "get_instance",
			parameters = { path = path }
		}
	)
	
	if success then
		return response.data
	else
		return nil
	end
end

-- Send startup hello message and analytics
spawn(function()
	wait(2) -- Wait a moment for everything to load
	
	-- Send hello message
	local success, result = HttpWrapper:sendStartupHello()
	if not success then
		StatusLabel.Text = "Backend connection failed"
		warn("Lumina: Could not connect to backend. Make sure the backend is running.")
	else
		-- Send analytics after successful connection
		wait(1) -- Brief delay
		sendAnalyticsToBackend()
	end
end)

-- Build KeyframeSequence animation from JSON data
function buildKeyframeAnimation(keyframeData, originalRequest)
	local success, error = pcall(function()
		-- Create AnimSaves folder if it doesn't exist
		local animSaves = game:GetService("Workspace"):FindFirstChild("AnimSaves")
		if not animSaves then
			animSaves = Instance.new("Folder")
			animSaves.Name = "AnimSaves"
			animSaves.Parent = workspace
		end
		
		-- Generate animation name from request
		local animName = "LuminaAnimation_" .. tick()
		
		-- Create KeyframeSequence
		local keyframeSequence = Instance.new("KeyframeSequence")
		keyframeSequence.Name = animName
		keyframeSequence.Looped = keyframeData.looped or false
		keyframeSequence.Priority = keyframeData.priority or Enum.AnimationPriority.Action
		keyframeSequence.Parent = animSaves
		
		-- Create keyframes from data
		if keyframeData.keyframes then
			for i, keyframe in ipairs(keyframeData.keyframes) do
				local pose = Instance.new("Pose")
				pose.Name = "Keyframe" .. i
				
				-- Add pose for each bone/motor
				if keyframe.poses then
					for boneName, cframeData in pairs(keyframe.poses) do
						if type(cframeData) == "table" and cframeData.x and cframeData.y and cframeData.z then
							local cframe = CFrame.new(cframeData.x, cframeData.y, cframeData.z, 
								cframeData.lookX or 0, cframeData.lookY or 0, cframeData.lookZ or 0,
								cframeData.rightX or 1, cframeData.rightY or 0, cframeData.rightZ or 0,
								cframeData.upX or 0, cframeData.upY or 1, cframeData.upZ or 0)
							pose[boneName] = cframe
						end
					end
				end
				
				-- Add pose to keyframe sequence
				keyframeSequence:AddKeyframe(keyframe.time or 0, pose)
			end
		end
		
		print("Lumina: Created animation '" .. animName .. "' with " .. #keyframeData.keyframes .. " keyframes")
		return true
	end)
	
	if not success then
		warn("Lumina: Failed to build keyframe animation:", error)
		return false
	end
end

-- Preview the latest KeyframeSequence animation
function previewLatestAnimation()
	StatusLabel.Text = "Loading preview..."
	
	local success, error = pcall(function()
		-- Find the latest animation in AnimSaves
		local animSaves = workspace:FindFirstChild("AnimSaves")
		if not animSaves then
			StatusLabel.Text = "No AnimSaves folder found"
			warn("Lumina: AnimSaves folder not found. Create an animation first.")
			return false
		end
		
		-- Get all KeyframeSequences and find the latest one
		local animations = {}
		for _, child in ipairs(animSaves:GetChildren()) do
			if child:IsA("KeyframeSequence") then
				table.insert(animations, child)
			end
		end
		
		if #animations == 0 then
			StatusLabel.Text = "No animations found"
			warn("Lumina: No KeyframeSequences found in AnimSaves folder.")
			return false
		end
		
		-- Sort by creation time (assuming name contains timestamp or use last modified)
		table.sort(animations, function(a, b)
			return a.Name > b.Name -- Assumes timestamp naming makes newer names larger
		end)
		
		local latestAnimation = animations[1]
		print("Lumina: Previewing animation '" .. latestAnimation.Name .. "'")
		
		-- Find a rig with Humanoid to play the animation
		local targetRig = nil
		local targetHumanoid = nil
		
		-- Search for character models with Humanoid (more efficient)
		for _, instance in ipairs(workspace:GetChildren()) do
			if instance:IsA("Model") then
				local humanoid = instance:FindFirstChildOfClass("Humanoid")
				if humanoid then
					targetRig = instance
					targetHumanoid = humanoid
					break
				end
			end
		end
		
		print("Lumina: Target rig found:", targetRig.Name)
		
		-- Create Animator if needed
		local animator = targetHumanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = targetHumanoid
		end
		
		-- Load and play the animation
		local animationTrack = animator:LoadAnimation(latestAnimation)
		animationTrack:Play()
		
		StatusLabel.Text = "Playing animation ▶"
		print("Lumina: Animation playing on", targetRig.Name)
		
		-- Store reference for potential cleanup
		_G.LuminaPreviewAnimation = animationTrack
		_G.LuminaPreviewAnimationId = latestAnimation
		
		return true
	end)
	
	if not success then
		StatusLabel.Text = "Preview failed"
		warn("Lumina: Failed to preview animation:", error)
		return false
	end
end

-- Send analytics to backend
function sendAnalyticsToBackend()
	-- Load MCP Explorer
	local MCPExplorer = require(script.Parent.MCP.explorer):new({
		base_url = CONFIG.BACKEND_URL,
		plugin_key = CONFIG.PLUGIN_KEY
	})
	
	-- Get analytics
	local analytics = MCPExplorer:getAnalytics()
	
	-- Send to backend
	local success, result = HttpWrapper:sendMCPRequest("sync_analytics", {
		analytics = analytics
	})
	
	if success then
		print("Lumina: Analytics synced successfully!")
		print("Rigs found:", #result.data.rigs_found)
	else
		warn("Lumina: Failed to sync analytics:", result.error)
	end
end

-- Preview button click handler
PreviewButton.MouseButton1Click:Connect(function()
	previewLatestAnimation()
end)

-- Expose MCP functions to global scope for debugging
_G.LuminaMCP = MCP

print("Lumina Plugin loaded successfully!")
print("Version: " .. CONFIG.PLUGIN_VERSION)
print("Backend: " .. CONFIG.BACKEND_URL)

-- Debug: Check if UI components loaded successfully
wait(1)
if PreviewButton and PreviewButton.Parent then
	print("✅ Preview button created successfully")
else
	warn("⚠️ Preview button NOT found - UI may not have loaded")
end

if LuminaWidget then
	print("✅ Lumina widget created successfully")
else
	warn("⚠️ Lumina widget NOT created")
end
