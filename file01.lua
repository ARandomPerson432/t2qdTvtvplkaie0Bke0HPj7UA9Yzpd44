--// Cache
--!nocheck
local game, workspace = game, workspace
local getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick = getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick
local Vector2new, Vector3zero, CFramenew, Color3fromRGB, Color3fromHSV, Drawingnew, TweenInfonew = Vector2.new, Vector3.zero, CFrame.new, Color3.fromRGB, Color3.fromHSV, Drawing.new, TweenInfo.new
local getupvalue, mousemoverel, tablefind, tableremove, stringlower, stringsub, mathclamp = debug.getupvalue, mousemoverel or (Input and Input.MouseMove), table.find, table.remove, string.lower, string.sub, math.clamp

local GameMetatable = getrawmetatable and getrawmetatable(game) or { -- Auxillary functions - if the executor doesn't support "getrawmetatable".
	__index = function(self, Index) return self[Index] end,
	__newindex = function(self, Index, Value) self[Index] = Value end
}
local __index = GameMetatable.__index
local __newindex = GameMetatable.__newindex
local getrenderproperty, setrenderproperty = getrenderproperty or __index, setrenderproperty or __newindex
local GetService = setmetatable({}, {
	__index = function(self, name)
		local success, cache = pcall(function()
			return cloneref(game:GetService(name))
		end)
		if success then
			rawset(self, name, cache)
			return cache
		else
			-- error("Invalid Roblox Service: " .. tostring(name))
		end
	end
})

--// Services

local Services = {
	RunService = GetService.RunService,
	UserInputService = GetService.UserInputService,
	TweenService = GetService.TweenService,
	Players = GetService.Players,
	CoreGui = GetService.CoreGui,
	ReplicatedStorage = GetService.ReplicatedStorage,
	Teams = GetService.Teams,
	Lighting = GetService.Lighting
}

--// Service Methods
local LocalPlayer = __index(Services.Players, "LocalPlayer")
local Camera = __index(workspace, "CurrentCamera")
local FindFirstChild, FindFirstChildOfClass = __index(game, "FindFirstChild"), __index(game, "FindFirstChildOfClass")
local GetDescendants = __index(game, "GetDescendants")
local WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
local GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
local GetMouseLocation = __index(Services.UserInputService, "GetMouseLocation")
local GetPlayers = __index(Services.Players, "GetPlayers")

--// Variables
local state = {
	ReqDist = 2000, Typing = false, Running = false, SrvConns = {}, Anim = nil, OrigSens = nil,
	LastPart = nil, LastPos = nil, Connect = __index(game, "DescendantAdded").Connect, Disconnect = nil,
	UserWL = {}, scriptUnloaded = false, namesHidden = false, autoLPEnabled = false,
	autoLPThread = nil, invEnabled = false, camFOVEnabled = false, camFOVVal = 70, origCamFOV = nil,
	fullbrightEnabled = false, origLighting = {}, rainbowESPEnabled = false, camFOVConn = nil, 
	wssCamConn = nil, isOnMobile = false, FluentMenu = nil, dealerConn = nil,
	localBL = {}, targetBL = {}, visBL = {}, lastVisCheck = 0, VIS_INT = 0.25, combBL = {},
}


local Map = workspace:WaitForChild("Map")
local Filter = workspace:WaitForChild("Filter")
local world = {
	BM = Map:WaitForChild("BredMakurz"), Doors = Map:WaitForChild("Doors"), ATMz = Map:WaitForChild("ATMz"),
	SPiles = Filter:WaitForChild("SpawnedPiles"), Shopz = Map:WaitForChild("Shopz"),
	Evts = Services.ReplicatedStorage:WaitForChild("Events"), Evts2 = Services.ReplicatedStorage:WaitForChild("Events2"),
	Vals = Services.ReplicatedStorage:WaitForChild("Values"), GM = Services.ReplicatedStorage:WaitForChild("Values"):WaitForChild("GameMode"),
	StamEv = Services.ReplicatedStorage:WaitForChild("Events2"):WaitForChild("StaminaChange")
}

local ui = {
	PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
}
ui.MainGui = ui.PlayerGui and ui.PlayerGui:FindFirstChild("CoreGUI")
ui.MobileGui = ui.PlayerGui and ui.PlayerGui:FindFirstChild("MobileButtonGUI")

local function buildBlacklist(char)
	local list = {}
	if char then
		for _, part in ipairs(char:GetChildren()) do
			if part:IsA("BasePart") then
				table.insert(list, part)
			end
		end
	end
	return list
end

-- Cache once per target character
local function getTargetBlacklist(targetChar)
	if not targetChar then return {} end
	if state.targetBL[targetChar] then return state.targetBL[targetChar] end
	local list = buildBlacklist(targetChar)
	state.targetBL[targetChar] = list
	return list
end

local function isVisible(targetPos, targetChar)
	if (Camera.CFrame.Position - targetPos).Magnitude < 10 then return true end
	local combined = {}
	for i = 1, #state.localBL do combined[#combined+1] = state.localBL[i] end
	local targetList = getTargetBlacklist(targetChar)
	for i = 1, #targetList do combined[#combined+1] = targetList[i] end
	return #Camera:GetPartsObscuringTarget({targetPos}, combined) == 0
end

--[[]]
xpcall(function() state.isOnMobile = table.find({Enum.Platform.Android, Enum.Platform.IOS}, Services.UserInputService:GetPlatform()) end, function() state.isOnMobile = Services.UserInputService.TouchEnabled and not Services.UserInputService.KeyboardEnabled end)
--]]

if getgenv().ExunysDeveloperAimbot and getgenv().ExunysDeveloperAimbot.Exit then getgenv().ExunysDeveloperAimbot:Exit() end

--// Environment
getgenv().ExunysDeveloperAimbot = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1 -- Bigger = Slower
	},
	Settings = {
		Enabled = true, -- This will be controlled by the UI
		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,
		DepthTarget = false,
		OffsetToMoveDirection = false,
		OffsetIncrement = 15,
		Sensitivity = 0, -- Animation length (in seconds) before fully locking onto target
		Sensitivity2 = 3.5, -- mousemoverel Sensitivity
		LockMode = 1, -- 1 = CFrame; 2 = mousemoverel
		LockPart = "Head", -- Body part to lock on
		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false,
		BulletPrediction = false, -- New: Enable bullet prediction
		PrioritizeDistance = true -- New: Prioritize closer targets
	},

	FOVSettings = {
		Enabled = true, -- This will be controlled by the UI
		Visible = true,
		Radius = 90,
		NumSides = 60,
		Thickness = 1,
		Transparency = 1,
		Filled = false,
		RainbowColor = false,
		Color = Color3fromRGB(255, 255, 255),
		LockedColor = Color3fromRGB(255, 150, 150)
	},
	Blacklisted = {},
	FOVCircle = Drawingnew("Circle")
}

local Environment = getgenv().ExunysDeveloperAimbot
setrenderproperty(Environment.FOVCircle, "Visible", false)

--// Core Functions
local FixUsername = function(String)
	local Result
	for _, Value in next, GetPlayers(Services.Players) do
		local Name = __index(Value, "Name")
		if stringsub(stringlower(Name), 1, #String) == stringlower(String) then
			Result = Name
		end
	end
	return Result
end

local GetRainbowColor = function()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed
	return Color3fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end

local function refreshCamera()
	Camera = __index(workspace, "CurrentCamera")
	if Camera and Camera:IsA("Camera") then
		if not state.origCamFOV or not state.camFOVEnabled then
			state.origCamFOV= Camera.FieldOfView
		end
		if state.camFOVEnabled then
			pcall(function()
				__newindex(Camera, "FieldOfView", state.camFOVVal)
			end)
		end
	end

	if state.CamFOVConn then
		state.CamFOVConn:Disconnect()
		state.CamFOVConn = nil
	end

	if Camera then
		local signal = __index(Camera, "GetPropertyChangedSignal")(Camera, "FieldOfView")
		state.CamFOVConn = state.Connect(signal, function()
			if state.camFOVEnabled and Camera and Camera:IsA("Camera") then
				pcall(function()
					__newindex(Camera, "FieldOfView", state.camFOVVal)
				end)
			end
		end)
	end

	if state.wssCamConn then
		state.wssCamConn:Disconnect()
		state.wssCamConn = nil
	end
	state.wssCamConn = state.Connect(__index(workspace, "GetPropertyChangedSignal")(workspace, "CurrentCamera"), function()
		refreshCamera()
	end)
end

local function restoreCameraFOV()
	if Camera and Camera:IsA("Camera") and state.origCamFOV then
		pcall(function()
			__newindex(Camera, "FieldOfView", state.origCamFOV)
		end)
	end
end

local function ToggleCameraFOV(enabled)
	state.camFOVEnabled = enabled
	refreshCamera()
	if not state.camFOVEnabled then
		restoreCameraFOV()
	end
end

local function updateCameraFOV()
	if state.camFOVEnabled and Camera and Camera:IsA("Camera") then
		pcall(function()
			__newindex(Camera, "FieldOfView", state.camFOVVal)
		end)
	end
end

local function restoreLighting()
	if not state.origLighting or not next(state.origLighting) then
		return
	end
	pcall(function()
		for key, value in pairs(state.origLighting) do
			if Services.Lighting[key] ~= nil then
				Services.Lighting[key] = value
			end
		end
	end)
end

local function ToggleFullbright(enabled)
	state.fullbrightEnabled  = enabled
	if state.fullbrightEnabled  then
		if not next(state.origLighting) then
			state.origLighting = {
				Ambient = Services.Lighting.Ambient,
				Brightness = Services.Lighting.Brightness,
				FogEnd = Services.Lighting.FogEnd,
				FogStart = Services.Lighting.FogStart,
				GlobalShadows = Services.Lighting.GlobalShadows,
				OutdoorAmbient = Services.Lighting.OutdoorAmbient,
				ColorShift_Bottom = Services.Lighting.ColorShift_Bottom,
				ColorShift_Top = Services.Lighting.ColorShift_Top,
			}
		end
		pcall(function()
			Services.Lighting.Ambient = Color3fromRGB(255, 255, 255)
			Services.Lighting.Brightness = 2
			Services.Lighting.FogEnd = 100000
			Services.Lighting.FogStart = 0
			Services.Lighting.GlobalShadows = false
			Services.Lighting.OutdoorAmbient = Color3fromRGB(255, 255, 255)
			Services.Lighting.ColorShift_Bottom = Color3fromRGB(255, 255, 255)
			Services.Lighting.ColorShift_Top = Color3fromRGB(255, 255, 255)
		end)
	else
		restoreLighting()
	end
end

local ConvertVector = function(Vector)
	return Vector2new(Vector.X, Vector.Y)
end

local CancelLock = function()
	Environment.Locked = nil
	Environment.LockedPart = nil
	state.LastPart = nil
	state.LastPos = nil
	local FOVCircle = Environment.FOVCircle
	setrenderproperty(FOVCircle, "Color", Environment.FOVSettings.Color)
	__newindex(Services.UserInputService, "MouseDeltaSensitivity", state.OrigSens)
	if state.Anim then state.Anim:Cancel() state.Anim = nil end
end

local function getClosestCharacterPart(Character, Pointer)
	local partNames = {
		"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso",
		"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
		"LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg",
		"LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot",
		"Left Arm", "Right Arm", "Left Leg", "Right Leg"
	}

	local bestPart, bestDistance
	for _, partName in ipairs(partNames) do
		local part = FindFirstChild(Character, partName)
		if part and part:IsA("BasePart") then
			local vector, onScreen = WorldToViewportPoint(Camera, part.Position)
			if onScreen then
				local screenPoint = ConvertVector(vector)
				local dist = (Pointer - screenPoint).Magnitude
				if not bestDistance or dist < bestDistance then
					bestDistance = dist
					bestPart = part
				end
			end
		end
	end

	return bestPart, bestDistance
end

-- Bullet prediction function
local function calculateBulletPrediction(targetPosition, targetVelocity, bulletSpeed, bulletAcceleration)
	if not bulletSpeed or bulletSpeed <= 0 then
		return targetPosition
	end

	local distance = (Camera.CFrame.Position - targetPosition).Magnitude
	if distance <= 0 then
		return targetPosition
	end

	local timeToTarget = distance / bulletSpeed

	-- Predict position based on velocity
	local predictedPosition = targetPosition + (targetVelocity * timeToTarget)

	if bulletAcceleration then
		predictedPosition = predictedPosition - (0.5 * bulletAcceleration * (timeToTarget ^ 2))
	end

	return predictedPosition
end

-- Get target velocity (for bullet prediction)
local function getTargetVelocity(character)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Velocity
	end
	return Vector3.zero
end

local getCurrentWeaponBulletStats

local GetClosestPlayer = function()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart
	local Pointer = state.isOnMobile and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) or GetMouseLocation(Services.UserInputService)

	if not Environment.Locked then
		state.ReqDist = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000

		local bestTarget = nil
		local bestScore = math.huge
		local bestPart = nil
		local bestDistance = math.huge

		for _, Value in next, GetPlayers(Services.Players) do
			local Character = __index(Value, "Character")
			local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")

			if Value ~= LocalPlayer 
				and not tablefind(Environment.Blacklisted, __index(Value, "Name")) 
				and Character 
				and FindFirstChild(Character, LockPart) 
				and Humanoid then

				local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption

				if Settings.TeamCheck and __index(Value, TeamCheckOption) == __index(LocalPlayer, TeamCheckOption) then
					continue
				end

				if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
					continue
				end

				-- Determine which part to target. If DepthTarget is enabled, find the part
				-- closest to the pointer using getClosestCharacterPart; otherwise use the
				-- configured LockPart on the character.
				local targetPartInstance
				if Settings.DepthTarget then
					local bestPartInfo = getClosestCharacterPart(Character, Pointer)
					if type(bestPartInfo) == "table" then
						-- in case getClosestCharacterPart returns both part and distance
						targetPartInstance = bestPartInfo[1]
					else
						targetPartInstance = bestPartInfo
					end
				end
				if not targetPartInstance then
					targetPartInstance = FindFirstChild(Character, LockPart)
				end

				if not targetPartInstance then
					continue
				end

				local PartPosition = __index(targetPartInstance, "Position")
				local Vector, OnScreen = WorldToViewportPoint(Camera, PartPosition)
				Vector = ConvertVector(Vector)
				local ScreenDistance = (Pointer - Vector).Magnitude

				-- Calculate 3D distance for prioritization
				local WorldDistance = (Camera.CFrame.Position - PartPosition).Magnitude

				if OnScreen and ScreenDistance < state.ReqDist then
					if Settings.WallCheck then
						local now = tick()
						state.visBL[Character] = state.visBL[Character] or {last = 0, visible = false}
						if now - state.visBL[Character].last > state.VIS_INT then
							state.visBL[Character].last = now
							-- run occlusion check only here
							local params = RaycastParams.new()
							params.FilterType = Enum.RaycastFilterType.Exclude
							params.FilterDescendantsInstances = {LocalPlayer.Character}
							local dir = PartPosition - Camera.CFrame.Position
							local result = workspace:Raycast(Camera.CFrame.Position, dir, params)
							state.visBL[Character].visible = (not result) or result.Instance:IsDescendantOf(Character)
						end
						if not state.visBL[Character].visible then
							continue
						end
					end

					-- Calculate score: prioritize closer targets (WorldDistance) within FOV (ScreenDistance)
					-- Lower score is better
					local score = WorldDistance * 0.7 + ScreenDistance * 0.3

					if score < bestScore then
						bestScore = score
						bestTarget = Value
						bestPart = targetPartInstance
						bestDistance = ScreenDistance
					end
				end
			end
		end

		if bestTarget then
			Environment.Locked = bestTarget
			Environment.LockedPart = __index(bestPart, "Name")
			state.ReqDist = bestDistance
		end
	else
		local LockedChar = __index(Environment.Locked, "Character")
		if LockedChar then
			local pos = __index(__index(LockedChar, LockPart), "Position")
			if (Pointer - ConvertVector(WorldToViewportPoint(Camera, pos))).Magnitude > state.ReqDist then
				CancelLock()
			end
		else
			CancelLock()
		end
	end
end

local Load = function()
	state.OrigSens = __index(Services.UserInputService, "MouseDeltaSensitivity")
	local Settings, FOVCircle, FOVSettings = Environment.Settings, Environment.FOVCircle, Environment.FOVSettings
	local Offset
	local AimbotButton 

	--// HYBRID CONTROL SETUP: Create controls based on platform

	if state.IsOnMobile then
		-- MOBILE: Create the toggle button
		AimbotButton = ui.MobileGui:WaitForChild("TouchControlFrame",math.huge):WaitForChild("Gun"):WaitForChild("AimButton")

		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 8)
		Corner.Parent = AimbotButton

		state.SrvConns.AimbotButtonConnection = state.Connect(AimbotButton.MouseButton1Click, function()
			state.Running = not state.Running
			if not state.Running then CancelLock() end
			AimbotButton.Text = "Aimbot: " .. (state.Running and "ON" or "OFF")
			AimbotButton.BackgroundColor3 = state.Running and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(40, 40, 40)
		end)
	else
		state.SrvConns.InputBeganConnection = state.Connect(__index(Services.UserInputService, "InputBegan"), function(Input)
			local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
			if state.Typing then return end
			if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
				if Toggle then
					state.Running = not state.Running
					if not state.Running then
						CancelLock()
					end
				else
					state.Running = true
				end
			end
		end)
		state.SrvConns.InputEndedConnection = state.Connect(__index(Services.UserInputService, "InputEnded"), function(Input)
			local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
			if Toggle or state.Typing then return end
			if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
				state.Running = false
				CancelLock()
			end
		end)
	end
	--// END HYBRID CONTROL SETUP

	state.SrvConns.RenderSteppedConnection = state.Connect(__index(Services.RunService, Environment.DeveloperSettings.UpdateMode), function()
		local OffsetToMoveDirection, LockPart = Settings.OffsetToMoveDirection, Settings.LockPart
		if Settings.Enabled and FOVSettings.Enabled then
			-- Apply only numeric properties safely
			local numericProps = { "Radius", "NumSides", "Thickness", "Transparency" }
			for _, prop in ipairs(numericProps) do
				local val = FOVSettings[prop]
				if val and type(val) == "number" then
					if pcall(getrenderproperty, FOVCircle, prop) then
						setrenderproperty(FOVCircle, prop, val)
					end
				end
			end

			-- Color logic
			local circleColor = Environment.Locked and FOVSettings.LockedColor
				or (FOVSettings.RainbowColor and GetRainbowColor())
				or FOVSettings.Color
			setrenderproperty(FOVCircle, "Color", circleColor)

			-- Position logic: mobile centers, desktop follows mouse
			local CameraViewport = Camera.ViewportSize
			if state.IsOnMobile then
				setrenderproperty(FOVCircle, "Position", Vector2new(CameraViewport.X / 2, CameraViewport.Y / 2))
			else
				setrenderproperty(FOVCircle, "Position", GetMouseLocation(Services.UserInputService))
			end

			-- Ensure visible when enabled
			setrenderproperty(FOVCircle, "Visible", FOVSettings.Visible)
		else
			setrenderproperty(FOVCircle, "Visible", false)
		end

		if state.Running and Settings.Enabled then
			GetClosestPlayer()
			if Environment.Locked then
				local LockedPlayer = Environment.Locked
				local Character = __index(LockedPlayer, "Character")
				local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")
				local PartToLock = Character and FindFirstChild(Character, LockPart)
				if not LockedPlayer or not Character or not Humanoid or not PartToLock or Humanoid.Health <= 0 then
					CancelLock()
				else
					Offset = OffsetToMoveDirection and __index(Humanoid, "MoveDirection") * (mathclamp(Settings.OffsetIncrement, 1, 30) / 10) or Vector3zero
					local LockedPosition_Vector3 = __index(PartToLock, "Position")

					-- Apply bullet prediction if enabled
					if Settings.BulletPrediction then
						local targetVelocity = getTargetVelocity(Character)
						local speed, accel = getCurrentWeaponBulletStats()
						LockedPosition_Vector3 = calculateBulletPrediction(LockedPosition_Vector3, targetVelocity, speed, accel)
					end

					local LockedPosition = WorldToViewportPoint(Camera, LockedPosition_Vector3 + Offset)
					if Environment.Settings.LockMode == 2 then
						mousemoverel((LockedPosition.X - GetMouseLocation(Services.UserInputService).X) / Settings.Sensitivity2, (LockedPosition.Y - GetMouseLocation(Services.UserInputService).Y) / Settings.Sensitivity2)
					else
						if Settings.Sensitivity >= 0 then
							state.Anim = Services.TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, LockedPosition_Vector3)})
							state.Anim:Play()
						else
							__newindex(Camera, "CFrame", CFramenew(Camera.CFrame.Position, LockedPosition_Vector3 + Offset))
						end
						__newindex(Services.UserInputService, "MouseDeltaSensitivity", 0)
					end
					setrenderproperty(FOVCircle, "Color", FOVSettings.LockedColor)
				end
			end
		end
	end)
end

--// Typing Check
state.SrvConns.TypingStartedConnection = state.Connect(__index(Services.UserInputService, "TextBoxFocused"), function()
	state.Typing = true
end)
state.SrvConns.TypingEndedConnection = state.Connect(__index(Services.UserInputService, "TextBoxFocusReleased"), function()
	state.Typing = false
end)

--// Functions

function Environment.Exit(self) -- METHOD | ExunysDeveloperAimbot:Exit(<void>)
	cleanupScript()
end

function Environment.Restart()
	for Index, conn in next, state.SrvConns do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	Load()
end

function Environment.Blacklist(self, Username) -- METHOD | ExunysDeveloperAimbot:Blacklist(<string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #2 \"Username\" <string>.")
	Username = FixUsername(Username)
	assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: User "..Username.." couldn't be found.")
	self.Blacklisted[#self.Blacklisted + 1] = Username
end

function Environment.Whitelist(self, Username) -- METHOD | ExunysDeveloperAimbot:Whitelist(<string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #2 \"Username\" <string>.")
	Username = FixUsername(Username)
	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." couldn't be found.")
	local Index = tablefind(self.Blacklisted, Username)
	assert(Index, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." is not blacklisted.")
	tableremove(self.Blacklisted, Index)
end

-- User whitelist management functions
local function AddToWhitelist(username)
	local player = Services.Players:FindFirstChild(username)
	if player then
		state.UserWL[username] = true
		return true
	end
	return false
end

local function RemoveFromWhitelist(username)
	state.UserWL[username] = nil
	return true
end

local function ClearWhitelist()
	state.UserWL = {}
	return true
end

local function ToggleWhitelist(boolean)
	-- Whitelist toggle removed; whitelist is always honored via `state.UserWL`.
	-- Keep function as a no-op for compatibility.
	return true
end

function Environment.GetClosestPlayer() -- ExunysDeveloperAimbot.GetClosestPlayer(<void>)
	GetClosestPlayer()
	local Value = Environment.Locked
	CancelLock()
	return Value
end

Environment.Load = Load -- ExunysDeveloperAimbot.Load()
setmetatable(Environment, {__call = Load})

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--// UI Integration
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Aimbot = getgenv().ExunysDeveloperAimbot -- Use the local environment we just created
local Options = Fluent.Options
--// Exunys Aimbot Settings
Aimbot:Load()
local AimFOV = Aimbot.FOVSettings
local AimSettings = Aimbot.Settings

--// Aimbot initial Settings (Set to false, UI will control them)
AimSettings.Enabled = false


local PlaceIds = {
	MainMenu = 4588604953,
	Casual = 8343259840,
	MCasual = 15169316384,
	Brawl = 15169306359,
	Standard = 15169303036,
	Infection = 15169310267,
}

local staffPlayers = {
	groups = {
		[4165692] = {
			["Tester"] = true, ["Contributor"] = true, ["Tester+"] = true, ["Developer"] = true,
			["Developer+"] = true, ["Community Manager"] = true, ["Manager"] = true, ["Owner"] = true
		},
		[32406137] = {
			["Junior"] = true, ["Moderator"] = true, ["Senior"] = true, ["Administrator"] = true,
			["Manager"] = true, ["Holder"] = true
		},
		[8024440] = {
			["R3SHAPE"] = true, ["reshape enjoyer"] = true, ["i heart reshape"] = true, ["reshape superfan"] = true
		},
		[14927228] = {
			["THE WAR ROOM"] = true
		}

	},
	users = { 
		3294804378, 93676120, 54087314, 81275825, 140837601, 1229486091, 46567801, 418086275, 29706395,
		3717066084, 1424338327, 5046662686, 5046661126, 5046659439, 418199326, 1024216621, 1810535041,
		63238912, 111250044, 63315426, 730176906, 141193516, 194512073, 193945439, 412741116, 195538733,
		102045519, 955294, 957835150, 25689921, 366613818, 281593651, 455275714, 208929505, 96783330,
		156152502, 93281166, 959606619, 142821118, 632886139, 175931803, 122209625, 278097946, 142989311,
		1517131734, 446849296, 87189764, 67180844, 9212846, 47352513, 48058122, 155413858, 10497435,
		513615792, 55893752, 55476024, 151691292, 136584758, 16983447, 3111449, 94693025, 271400893,
		5005262660, 295331237, 64489098, 244844600, 114332275, 25048901, 69262878, 50801509, 92504899,
		42066711, 50585425, 31365111, 166406495, 2457253857, 29761878, 21831137, 948293345, 439942262,
		38578487, 1163048, 7713309208, 3659305297, 15598614, 34616594, 626833004, 198610386, 153835477,
		3923114296, 3937697838, 102146039, 119861460, 371665775, 1206543842, 93428604, 1863173316, 90814576,
		374665997, 423005063, 140172831, 42662179, 9066859, 438805620, 14855669, 727189337, 1871290386,
		608073286
	} 
} 

local MAX_ESP_DISTANCE = 300
local UPDATE_INTERVAL = 0.5 
local lastUpdateTime = 0

local function CheckMode()
	for modeName, id in pairs(PlaceIds) do
		if game.PlaceId == id then
			return modeName
		end
	end
	return nil
end

local function RandomString(length)
	local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789~!@#$%^&*()_+{}}|:<>?-=[]\\;:,./"
	local result = ""
	for i = 1, length do
		local randIndex = math.random(1, #charset)
		result = result .. charset:sub(randIndex, randIndex)
	end
	return result
end

local currentMode = CheckMode()

if currentMode ==  "MainMenu" then
	Fluent:Notify({
		Title = "Federation Project CICADA-02",
		Content = "You are in Main Menu, please select a game mode to use the script.",
		Duration = 5,
	})
end
--// Connections
local safeConn, registerConn, atmConn, crateConn, playerAddedConn, StaffCheckConn
local charAddedConns = {}
local billboardConnections = {}

local ActiveBillboards = {}
local ActiveHighlights = {}

local function getHighlight(target, color, prefix)
	if not target then return nil end
	local name = prefix .. "_" .. target.Name .. "_ESPHighlight"

	-- reuse if exists
	local existing = ActiveHighlights[name]
	if existing then
		if existing.Parent then
			existing.FillColor = color
			existing.Adornee = target
			return existing
		else
			ActiveHighlights[name] = nil
		end
	end

	-- create once
	local highlight = Instance.new("Highlight")
	highlight.Name = name
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.8 -- lighter, cheaper
	highlight.OutlineTransparency = 0.7
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = target
	highlight.Parent = Services.CoreGui

	ActiveHighlights[name] = highlight
	return highlight
end

local function getAdorneePart(target, timeout)
	timeout = timeout or 5
	local deadline = os.clock() + timeout

	local function resolve()
		if target:IsA("BasePart") then
			return target
		elseif target:IsA("Model") then
			return target:FindFirstChild("HumanoidRootPart")
				or target:FindFirstChild("Head")
				or target:FindFirstChildWhichIsA("BasePart")
		end
	end

	local part = resolve()
	while not part and os.clock() < deadline do
		task.wait(0.1)
		part = resolve()
	end
	return part
end

local espCounters = {}

local function getUniqueName(prefix, target, kind)
	local safeName = target and target.Name or "Unknown"
	espCounters[safeName] = (espCounters[safeName] or 0) + 1
	return prefix .. "_" .. safeName .. "_" .. espCounters[safeName] .. kind
end

do -- create assist node
	local folder = Instance.new("Folder")
	folder.Name = "FedNodeAssist"
	folder.Parent = workspace  -- bug 4 fix

	local function CreateNode(name, pos, number)
		local node = Instance.new("Part")
		node.Name = "Assist_" .. name .. "_N" .. number  -- bug 1 + 3 fix
		node.Size = Vector3.new(1, 1, 1)
		node.Position = pos.Position  -- bug 2 fix (CFrame → Vector3)
		node.Anchored = true
		node.CanCollide = false
		node.Transparency = 0.5
		node.Material = Enum.Material.Neon
		node.Color = Color3.fromRGB(255, 255, 0)
		node:SetAttribute("CanIgnore", false)
		node:SetAttribute("BypassCollision", false)
		node.Parent = folder
		return node
	end

	-- begin create nodes
	CreateNode("MediumSafe_TS_20", CFrame.new(-4595.591, 3.949, -152.515), 1)
	CreateNode("MediumSafe_TS_20", CFrame.new(-4613.393, 3.949, -152.515), 2)
end

--ADVANCED PATHFINDER
-- Wrap the pathfinder in an IIFE to keep its locals scoped.
local Pathfinder = (function()

	-- ─────────────────────────────────────────────────────────────────
	-- SERVICES
	-- ─────────────────────────────────────────────────────────────────
	local PathfindingService = cloneref(game:GetService("PathfindingService"))

	-- ─────────────────────────────────────────────────────────────────
	-- CONSTANTS  (unchanged)
	-- ─────────────────────────────────────────────────────────────────
	local ZERO_V3     = Vector3.zero
	local ALMOST_ZERO = 0.000001

	local CHECKPOINT_DIST  = 28
	local AGENT_RADIUS     = 1.8
	local AGENT_HEIGHT     = 5.0
	local WAYPOINT_SPACING = 2

	local WAYPOINT_TIMEOUT  = 10
	local SEGMENT_TIMEOUT   = 20
	local JUMP_COOLDOWN     = 0.5
	local JUMP_MAX_HEIGHT   = 7
	local JUMP_FWD_DIST     = 3.5
	local JUMP_NEAR_DEST    = 5
	local JUMP_STREAK_MAX   = 3
	local STEP_JUMP_MIN     = 1.8

	local MAX_BISECT_DEPTH  = 7
	local MIN_BISECT_DIST   = 4

	local ARRIVAL_DIST      = 5
	local MAX_CP_RETRIES    = 1
	local RETRY_FAR_DIST    = 15
	local MAX_INJECT_DEPTH  = 3

	local TELEPORT_Y_THRESHOLD    = 5
	local TELEPORT_FAIL_THRESHOLD = 2

	local OSCILLATION_SAMPLES = 16
	local OSCILLATION_RATE    = 0.4
	local OSCILLATION_RADIUS  = 4.0
	local ESCAPE_COOLDOWN     = 6

	local PASSTHROUGH_RANGE   = 10
	local PASSTHROUGH_RESTORE = 14

	-- NodeAssist snap: how close start/goal must be to any node to activate the graph
	local NODE_SNAP_DIST = 80

	-- ─────────────────────────────────────────────────────────────────
	-- PLAYER / CHARACTER  (unchanged)
	-- ─────────────────────────────────────────────────────────────────
	local player    = Services.Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid  = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart  = character:WaitForChild("HumanoidRootPart") :: BasePart

	player.CharacterAdded:Connect(function(c)
		character = c
		humanoid  = c:WaitForChild("Humanoid")
		rootPart  = c:WaitForChild("HumanoidRootPart")
	end)

	local function getHumanoid()
		local c = player.Character
		return c and c:FindFirstChildOfClass("Humanoid")
	end

	-- ─────────────────────────────────────────────────────────────────
	-- RAYCAST PARAMS  (unchanged)
	-- ─────────────────────────────────────────────────────────────────
	local RAY_PARAMS      = RaycastParams.new()
	RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
	RAY_PARAMS.FilterDescendantsInstances = {character}

	player.CharacterAdded:Connect(function(c)
		RAY_PARAMS.FilterDescendantsInstances = {c}
	end)

	-- ─────────────────────────────────────────────────────────────────
	-- PATHFIND IGNORE LIST  (unchanged)
	-- ─────────────────────────────────────────────────────────────────
	local PathfindIgnore     = {}
	local ignoreParts        = {}
	local originalCanCollide = {}
	local noclipActive       = {}

	local function collectIgnoreParts()
		local parts = {}
		for _, obj in ipairs(PathfindIgnore) do
			if obj:IsA("BasePart") then
				table.insert(parts, obj)
			else
				for _, desc in ipairs(obj:GetDescendants()) do
					if desc:IsA("BasePart") then
						table.insert(parts, desc)
					end
				end
			end
		end
		return parts
	end

	local function refreshIgnore()
		ignoreParts = collectIgnoreParts()
		local filter = {character}
		for _, p in ipairs(ignoreParts) do table.insert(filter, p) end
		RAY_PARAMS.FilterDescendantsInstances = filter
		for _, p in ipairs(ignoreParts) do
			if originalCanCollide[p] == nil then
				originalCanCollide[p] = p.CanCollide
			end
		end
	end

	refreshIgnore()

	player.CharacterAdded:Connect(function(c)
		character = c
		refreshIgnore()
	end)

	local function updatePassthrough()
		if #ignoreParts == 0 then return end
		local pos = rootPart and rootPart.Position
		if not pos then return end
		for _, p in ipairs(ignoreParts) do
			local dist = (p.Position - pos).Magnitude
			if dist <= PASSTHROUGH_RANGE then
				if not noclipActive[p] then
					noclipActive[p] = true
					p.CanCollide    = false
				end
			elseif dist > PASSTHROUGH_RESTORE then
				if noclipActive[p] then
					noclipActive[p] = nil
					p.CanCollide    = originalCanCollide[p] ~= nil and originalCanCollide[p] or true
				end
			end
		end
	end

	-- ─────────────────────────────────────────────────────────────────
	-- GROUND / SAFETY HELPERS  (unchanged)
	-- ─────────────────────────────────────────────────────────────────
	local function snapToGround(pt)
		for _, up in ipairs({10, 30, 60, 100}) do
			local hit = workspace:Raycast(
				pt + Vector3.new(0, up, 0),
				Vector3.new(0, -(up + 50), 0),
				RAY_PARAMS
			)
			if hit then return hit.Position, true end
		end
		return pt, false
	end

	local function isPointSafe(pos)
		local snapped, ok = snapToGround(pos)
		if not ok then return false end
		local checkY = snapped.Y + AGENT_HEIGHT * 0.5
		local dirs = {
			Vector3.new( 1,0,0), Vector3.new(-1,0,0),
			Vector3.new( 0,0,1), Vector3.new( 0,0,-1),
		}
		for _, d in ipairs(dirs) do
			if workspace:Raycast(Vector3.new(pos.X, checkY, pos.Z), d * AGENT_RADIUS, RAY_PARAMS) then
				return false
			end
		end
		return true
	end

	local NUDGE_DIRS = {
		Vector3.new( 1,0,0), Vector3.new(-1,0,0),
		Vector3.new( 0,0,1), Vector3.new( 0,0,-1),
		Vector3.new( 1,0, 1).Unit, Vector3.new(-1,0, 1).Unit,
		Vector3.new( 1,0,-1).Unit, Vector3.new(-1,0,-1).Unit,
	}

	local function safestNearby(pos, awayFrom)
		local bias = pos - awayFrom
		local biasFlat = Vector3.new(bias.X, 0, bias.Z)
		if biasFlat.Magnitude > ALMOST_ZERO then biasFlat = biasFlat.Unit end
		for _, step in ipairs({2, 4, 6, 8, 10, 14, 18}) do
			local c, ok = snapToGround(pos + biasFlat * step)
			if ok and isPointSafe(c) then return c end
			for _, d in ipairs(NUDGE_DIRS) do
				c, ok = snapToGround(pos + d * step)
				if ok and isPointSafe(c) then return c end
			end
		end
		return nil
	end

	-- ─────────────────────────────────────────────────────────────────
	-- NODE ASSIST  ← NEW BLOCK
	-- Reads workspace.FedNodeAssist at navigation start.
	-- Part naming: Assist_<DestName>_N<index>
	--   CanIgnore   (bool attr, default false) — if true, skip this node
	--   BypassCollision (bool attr, default false) — if true, auto-add to PathfindIgnore
	-- ─────────────────────────────────────────────────────────────────
	local NodeAssist = {}
	do
		-- Internal graph: groups[destName] = { [index] = {part, pos, bypass} }
		local groups = {}

		local function parseNodeName(name)
			-- Must start with "Assist_"
			if not name:sub(1, 7) == "Assist_" then return nil, nil end
			local body = name:sub(8)   -- strip "Assist_"
			-- Find last "_N<digits>" segment
			local destName, idxStr = body:match("^(.+)_N(%d+)$")
			if not destName or not idxStr then return nil, nil end
			return destName, tonumber(idxStr)
		end

		-- Load (or reload) all nodes from workspace.FedNodeAssist
		function NodeAssist.Load()
			groups = {}
			local folder = workspace:FindFirstChild("FedNodeAssist")
			if not folder then
				warn("[NodeAssist] workspace.FedNodeAssist not found — node routing disabled")
				return
			end

			local bypassParts = {}

			for _, part in ipairs(folder:GetChildren()) do
				if not part:IsA("BasePart") then continue end

				local canIgnore = part:GetAttribute("CanIgnore")
				if canIgnore == true then continue end   -- skip opted-out nodes

				local destName, idx = parseNodeName(part.Name)
				if not destName then
					warn(string.format("[NodeAssist] Skipping '%s' — name doesn't match Assist_<Dest>_N<#>", part.Name))
					continue
				end

				local bypass = part:GetAttribute("BypassCollision") == true

				if not groups[destName] then groups[destName] = {} end
				groups[destName][idx] = {
					part   = part,
					pos    = part.Position,
					bypass = bypass,
				}

				if bypass then
					table.insert(bypassParts, part)
				end
			end

			-- Register bypass parts into PathfindIgnore so noclip handles them
			for _, p in ipairs(bypassParts) do
				local alreadyIn = false
				for _, v in ipairs(PathfindIgnore) do
					if v == p then alreadyIn = true; break end
				end
				if not alreadyIn then
					table.insert(PathfindIgnore, p)
				end
			end
			refreshIgnore()

			local groupCount, nodeCount = 0, 0
			for _, g in pairs(groups) do
				groupCount = groupCount + 1
				for _ in pairs(g) do nodeCount = nodeCount + 1 end
			end
			print(string.format("[NodeAssist] Loaded %d nodes across %d groups", nodeCount, groupCount))
		end

		-- Return ordered Vector3 list for a named group, or nil
		local function getGroupChain(destName)
			local g = groups[destName]
			if not g then return nil end
			-- Collect and sort by index
			local sorted = {}
			for idx, data in pairs(g) do
				table.insert(sorted, {idx = idx, pos = data.pos})
			end
			if #sorted == 0 then return nil end
			table.sort(sorted, function(a, b) return a.idx < b.idx end)
			local chain = {}
			for _, entry in ipairs(sorted) do
				table.insert(chain, entry.pos)
			end
			return chain
		end

		-- Find the nearest node position across ALL groups, returns (pos, distSq) or nil
		local function nearestNodePos(pos)
			local best, bestDist = nil, math.huge
			for _, g in pairs(groups) do
				for _, data in pairs(g) do
					local d = (data.pos - pos).Magnitude
					if d < bestDist then
						bestDist = d
						best     = data.pos
					end
				end
			end
			return best, bestDist
		end

		-- A* over the sequential group chains.
		-- Build a flat node list with sequential edges, then A*.
		local function buildFlatGraph()
			local nodes = {}   -- list of {pos, neighbors:[index]}
			local posToIdx = {}

			local function addNode(pos)
				local key = string.format("%.2f_%.2f_%.2f", pos.X, pos.Y, pos.Z)
				if posToIdx[key] then return posToIdx[key] end
				table.insert(nodes, {pos = pos, neighbors = {}})
				local i = #nodes
				posToIdx[key] = i
				return i
			end

			for _, g in pairs(groups) do
				local sorted = {}
				for idx, data in pairs(g) do
					table.insert(sorted, {idx = idx, pos = data.pos})
				end
				table.sort(sorted, function(a, b) return a.idx < b.idx end)

				local prevIdx = nil
				for _, entry in ipairs(sorted) do
					local ni = addNode(entry.pos)
					if prevIdx then
						table.insert(nodes[prevIdx].neighbors, ni)
						table.insert(nodes[ni].neighbors, prevIdx)   -- bidirectional
					end
					prevIdx = ni
				end
			end

			return nodes
		end

		local function astar(nodes, startI, goalI)
			if startI == goalI then return {nodes[startI].pos} end

			local open     = {startI}
			local cameFrom = {}
			local gScore   = {[startI] = 0}
			local fScore   = {[startI] = (nodes[startI].pos - nodes[goalI].pos).Magnitude}

			local function lowestF()
				local best, bestF = nil, math.huge
				for _, n in ipairs(open) do
					local f = fScore[n] or math.huge
					if f < bestF then best = n; bestF = f end
				end
				return best
			end
			local function inOpen(n)
				for _, v in ipairs(open) do if v == n then return true end end
				return false
			end

			while #open > 0 do
				local cur = lowestF()
				if cur == goalI then
					local path = {}
					local c = cur
					while c do
						table.insert(path, 1, nodes[c].pos)
						c = cameFrom[c]
					end
					return path
				end
				for i, v in ipairs(open) do
					if v == cur then table.remove(open, i); break end
				end
				for _, nb in ipairs(nodes[cur].neighbors) do
					local tg = (gScore[cur] or math.huge) + (nodes[cur].pos - nodes[nb].pos).Magnitude
					if tg < (gScore[nb] or math.huge) then
						cameFrom[nb] = cur
						gScore[nb]   = tg
						fScore[nb]   = tg + (nodes[nb].pos - nodes[goalI].pos).Magnitude
						if not inOpen(nb) then table.insert(open, nb) end
					end
				end
			end
			return nil
		end

		-- High-level route: given two world positions, return ordered Vector3 list or nil.
		-- Returns nil when nodes are too far from either endpoint (falls back to navmesh).
		function NodeAssist.Route(fromPos, toPos)
			local flatNodes = buildFlatGraph()
			if #flatNodes == 0 then return nil end

			-- Find nearest node to start and goal
			local startI, startDist = nil, math.huge
			local goalI,  goalDist  = nil, math.huge

			for i, node in ipairs(flatNodes) do
				local ds = (node.pos - fromPos).Magnitude
				local dg = (node.pos - toPos).Magnitude
				if ds < startDist then startDist = ds; startI = i end
				if dg < goalDist  then goalDist  = dg; goalI  = i end
			end

			-- Both endpoints must be reasonably close to the graph
			if startDist > NODE_SNAP_DIST or goalDist > NODE_SNAP_DIST then
				return nil
			end
			if startI == goalI then return nil end

			local path = astar(flatNodes, startI, goalI)
			if not path or #path == 0 then return nil end
			return path
		end

		-- Optional: reload nodes on-the-fly (call after adding parts at runtime)
		function NodeAssist.Reload()
			NodeAssist.Load()
		end
	end

	-- Load nodes immediately at startup
	NodeAssist.Load()

	-- ─────────────────────────────────────────────────────────────────
	-- DEBUG  (unchanged)
	-- ─────────────────────────────────────────────────────────────────
	local DEBUG     = true
	local dbgFolder = Instance.new("Folder")
	dbgFolder.Name   = "FedPF_Debug"
	dbgFolder.Parent = workspace

	local function clearDebug() dbgFolder:ClearAllChildren() end

	local segDbgFolder = Instance.new("Folder")
	segDbgFolder.Name   = "FedPF_Segment"
	segDbgFolder.Parent = workspace

	local function clearSegDebug() segDbgFolder:ClearAllChildren() end

	local function drawSegment(pointList)
		clearSegDebug()
		if not DEBUG or not pointList then return end
		for i, wp in ipairs(pointList) do
			local col = i == 1 and Color3.fromRGB(50,180,255) or Color3.fromRGB(255,210,0)
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(0.5,0.5,0.5)
			p.Position = wp.Position; p.Anchored = true; p.CanCollide = false
			p.CastShadow = false; p.Material = Enum.Material.Neon
			p.Color = col; p.Transparency = 0.2; p.Parent = segDbgFolder
			if i > 1 then
				local a = pointList[i-1].Position; local b = wp.Position
				local mid = (a+b)/2; local dist = (b-a).Magnitude
				if dist > 0.05 then
					local ln = Instance.new("Part")
					ln.Size = Vector3.new(0.06,0.06,dist)
					ln.CFrame = CFrame.lookAt(mid, b)
					ln.Anchored = true; ln.CanCollide = false; ln.CastShadow = false
					ln.Material = Enum.Material.Neon; ln.Color = Color3.fromRGB(255,110,0)
					ln.Transparency = 0.2; ln.Parent = segDbgFolder
				end
			end
		end
	end

	-- ─────────────────────────────────────────────────────────────────
	-- DESTINATION MARKER  (unchanged)
	-- ─────────────────────────────────────────────────────────────────
	local destFolder = Instance.new("Folder")
	destFolder.Name   = "FedDest"
	destFolder.Parent = workspace

	local destBase = Instance.new("Part")
	destBase.Size        = Vector3.new(3,0.3,3)
	destBase.Shape       = Enum.PartType.Cylinder
	destBase.Anchored    = true; destBase.CanCollide = false; destBase.CastShadow = false
	destBase.Material    = Enum.Material.Neon
	destBase.Color       = Color3.fromRGB(0,220,110)
	destBase.Transparency = 1
	destBase.Parent      = destFolder

	local destRing = Instance.new("SelectionBox")
	destRing.Adornee       = destBase
	destRing.Color3        = Color3.fromRGB(0,255,120)
	destRing.LineThickness = 0.05
	destRing.Parent        = destBase

	local destBeam = Instance.new("Part")
	destBeam.Size        = Vector3.new(0.12,40,0.12)
	destBeam.Anchored    = true; destBeam.CanCollide = false; destBeam.CastShadow = false
	destBeam.Material    = Enum.Material.Neon
	destBeam.Color       = Color3.fromRGB(0,255,120)
	destBeam.Transparency = 1
	destBeam.Parent      = destFolder

	local bb = Instance.new("BillboardGui")
	bb.Size          = UDim2.new(0,140,0,40)
	bb.StudsOffset   = Vector3.new(0,3.5,0)
	bb.AlwaysOnTop   = true
	bb.ResetOnSpawn  = false
	bb.Parent        = destBase

	local bbLabel = Instance.new("TextLabel")
	bbLabel.Size                 = UDim2.new(1,0,1,0)
	bbLabel.BackgroundTransparency = 1
	bbLabel.Text                 = "📍 DESTINATION"
	bbLabel.TextColor3           = Color3.fromRGB(0,255,120)
	bbLabel.TextScaled           = true
	bbLabel.Font                 = Enum.Font.GothamBold
	bbLabel.Parent               = bb

	local cpFolder = Instance.new("Folder")
	cpFolder.Name   = "FedCheckpoints"
	cpFolder.Parent = workspace

	local function clearCheckpointMarkers() cpFolder:ClearAllChildren() end

	local function drawCheckpoints(cps)
		clearCheckpointMarkers()
		if not DEBUG then return end
		for _, cp in ipairs(cps) do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(1.2,1.2,1.2)
			p.Position = cp; p.Anchored = true; p.CanCollide = false
			p.CastShadow = false; p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(0,200,255); p.Transparency = 0.1
			p.Parent = cpFolder
		end
	end

	local function showDest(pos)
		destBase.Transparency = 0.25; destBeam.Transparency = 0.6
		destBase.CFrame = CFrame.new(pos + Vector3.new(0,0.15,0)) * CFrame.Angles(0,0,math.pi/2)
		destBeam.Position = pos + Vector3.new(0,20,0)
	end

	local function hideDest()
		destBase.Transparency = 1; destBeam.Transparency = 1
	end

	-- ─────────────────────────────────────────────────────────────────
	-- CHECKPOINT GENERATOR  ← PATCHED: NodeAssist consulted first
	-- ─────────────────────────────────────────────────────────────────
	local function buildCheckpoints(startPos, endPos)

		-- ── 1. Try NodeAssist graph ───────────────────────────────────
		local graphRoute = NodeAssist.Route(startPos, endPos)
		if graphRoute and #graphRoute >= 1 then
			print(string.format("[PF] NodeAssist route: %d hops", #graphRoute))
			local checkpoints = {}
			for _, wp in ipairs(graphRoute) do
				table.insert(checkpoints, wp)
			end
			-- Append true destination if the last node is far from it
			local lastPt = checkpoints[#checkpoints]
			if (lastPt - endPos).Magnitude > 8 then
				table.insert(checkpoints, endPos)
			end
			drawCheckpoints(checkpoints)
			return checkpoints
		end

		-- ── 2. Fallback: navmesh rough-path  (original logic) ─────────
		local roughWps = nil

		for _, radius in ipairs({AGENT_RADIUS, 1.0, 0.5}) do
			local roughPath = PathfindingService:CreatePath({
				AgentRadius     = radius,
				AgentHeight     = AGENT_HEIGHT,
				AgentCanJump    = true,
				AgentCanClimb   = true,
				WaypointSpacing = CHECKPOINT_DIST,
				Costs           = { Water = 20 },
			})
			local ok = pcall(function() roughPath:ComputeAsync(startPos, endPos) end)
			if ok and roughPath.Status == Enum.PathStatus.Success then
				roughWps = roughPath:GetWaypoints()
				print(string.format("[PF] Rough path OK (radius=%.1f): %d waypoints", radius, #roughWps))
				break
			end
		end

		local checkpoints = {}
		if roughWps and #roughWps >= 2 then
			for i = 2, #roughWps do
				table.insert(checkpoints, roughWps[i].Position)
			end
		else
			warn("[PF] Rough path failed — single destination checkpoint")
			local snappedEnd, snapOk = snapToGround(endPos)
			table.insert(checkpoints, snapOk and snappedEnd or endPos)
		end

		return checkpoints
	end

-- ─────────────────────────────────────────────────────────────────
	-- SEGMENT COMPUTE
	-- ─────────────────────────────────────────────────────────────────
	local MIN_WP_DIST = 1.8

	local function deduplicateWps(wps)
		if not wps or #wps <= 1 then return wps end
		local out = { wps[1] }
		for i = 2, #wps do
			local prev   = out[#out].Position
			local curr   = wps[i].Position
			local isJump = wps[i].Action == Enum.PathWaypointAction.Jump
			if isJump or (curr - prev).Magnitude >= MIN_WP_DIST then
				table.insert(out, wps[i])
			end
		end
		return out
	end

	local function rawCompute(fromPos, toPos, radius)
		local path = PathfindingService:CreatePath({
			AgentRadius     = radius,
			AgentHeight     = AGENT_HEIGHT,
			AgentCanJump    = true,
			AgentCanClimb   = true,
			WaypointSpacing = WAYPOINT_SPACING,
			Costs           = { Water = 20 },
		})
		local ok = pcall(function() path:ComputeAsync(fromPos, toPos) end)
		if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
		local wps = path:GetWaypoints()
		if not wps or #wps == 0 then return nil end
		return deduplicateWps(wps)
	end

	local function computeFirstValid(fromPos, toPos)
		for _, radius in ipairs({AGENT_RADIUS, 1.2, 0.8, 0.5}) do
			local wps = rawCompute(fromPos, toPos, radius)
			if wps then return wps end
		end
		return nil
	end

	local function findMidpoint(fromPos, toPos)
		local mid   = (fromPos + toPos) * 0.5
		local rPath = PathfindingService:CreatePath({
			AgentRadius     = 1.0,
			AgentHeight     = AGENT_HEIGHT,
			AgentCanJump    = true,
			AgentCanClimb   = true,
			WaypointSpacing = math.max((toPos - fromPos).Magnitude * 0.4, 8),
		})
		local ok = pcall(function() rPath:ComputeAsync(fromPos, toPos) end)
		if ok and rPath.Status == Enum.PathStatus.Success then
			local wps = rPath:GetWaypoints()
			if #wps >= 2 then
				return wps[math.max(1, math.round(#wps / 2))].Position
			end
		end
		local snapped, snapOk = snapToGround(mid)
		return snapOk and snapped or mid
	end

	local function mergeWps(a, b)
		if not a then return b end
		if not b then return a end
		local merged = {}
		for _, wp in ipairs(a) do table.insert(merged, wp) end
		for i = 2, #b     do table.insert(merged, b[i]) end
		return merged
	end

	local function bisectSolve(fromPos, toPos, depth)
		local xzDist = Vector2.new(toPos.X - fromPos.X, toPos.Z - fromPos.Z).Magnitude
		if xzDist < MIN_BISECT_DIST or depth >= MAX_BISECT_DEPTH then
			return nil, nil
		end

		local mid = findMidpoint(fromPos, toPos)

		local wpsA = computeFirstValid(fromPos, mid)
		local reachA = mid
		if not wpsA then
			wpsA, reachA = bisectSolve(fromPos, mid, depth + 1)
		end

		if not wpsA then return nil, nil end

		local wpsB = computeFirstValid(reachA, toPos)
		local reachB = toPos
		if not wpsB then
			wpsB, reachB = bisectSolve(reachA, toPos, depth + 1)
		end

		if wpsB then
			return mergeWps(wpsA, wpsB), reachB
		else
			print(string.format("[PF] Partial bisect: reached (%.1f,%.1f,%.1f), %.0f studs short of target",
				reachA.X, reachA.Y, reachA.Z,
				Vector2.new(reachA.X - toPos.X, reachA.Z - toPos.Z).Magnitude))
			return wpsA, reachA
		end
	end

	local function computeSegment(fromPos, toPos)
		local wps = computeFirstValid(fromPos, toPos)
		if wps then return wps, toPos end

		local xzDist = Vector2.new(toPos.X - fromPos.X, toPos.Z - fromPos.Z).Magnitude
		if xzDist >= MIN_BISECT_DIST then
			local partial, reached = bisectSolve(fromPos, toPos, 0)
			if partial then
				local full = reached and
					Vector2.new(reached.X - toPos.X, reached.Z - toPos.Z).Magnitude < 2
				if full then
					print(string.format("[PF] Bisect solved full segment (%.0f studs)", xzDist))
				else
					print(string.format("[PF] Bisect partial: %.0f of %.0f studs reachable",
						Vector2.new(fromPos.X - reached.X, fromPos.Z - reached.Z).Magnitude, xzDist))
				end
				return partial, reached
			end
		end

		return nil, nil
	end

	-- ─────────────────────────────────────────────────────────────────
	-- PATHER
	-- ─────────────────────────────────────────────────────────────────
	local function makePather(pointList)
		local self = {}

		self.PointList  = pointList
		self.Started    = false
		self.Cancelled  = false

		self.Finished   = Instance.new("BindableEvent")
		self.PathFailed = Instance.new("BindableEvent")

		self.CurrentPoint        = 0
		self.Timeout             = 0
		self.SegmentTimer        = 0
		self.WaypointPos         = nil
		self.WaypointPlaneNormal = ZERO_V3
		self.WaypointPlaneDist   = 0
		self.WaypointNeedsJump   = false
		self.HumanoidPos         = ZERO_V3
		self.HumanoidVel         = ZERO_V3
		self.MoveDir             = ZERO_V3
		self.DoJump              = false
		self.DiedConn            = nil
		self.SeatedConn          = nil

		function self:SetPlane(fromWP, toWP)
			local n = Vector3.new(
				fromWP.Position.X - toWP.Position.X,
				0,
				fromWP.Position.Z - toWP.Position.Z
			)
			if n.Magnitude > ALMOST_ZERO then
				n = n.Unit
				self.WaypointPlaneNormal = n
				self.WaypointPlaneDist   = n:Dot(toWP.Position)
			else
				self.WaypointPlaneNormal = ZERO_V3
				self.WaypointPlaneDist   = 0
			end
			self.WaypointPos       = toWP.Position
			self.WaypointNeedsJump = toWP.Action == Enum.PathWaypointAction.Jump
		end

		function self:IsWaypointReached()
			if self.WaypointPlaneNormal == ZERO_V3 then return true end

			local dist      = self.WaypointPlaneNormal:Dot(self.HumanoidPos) - self.WaypointPlaneDist
			local speed     = -self.WaypointPlaneNormal:Dot(self.HumanoidVel)
			local threshold = math.max(1.0, 0.0625 * speed)
			local reached   = dist < threshold

			if not reached and self.WaypointPos then
				reached = Vector2.new(
					self.HumanoidPos.X - self.WaypointPos.X,
					self.HumanoidPos.Z - self.WaypointPos.Z
				).Magnitude < 2.5
			end

			if reached then
				self.WaypointPos         = nil
				self.WaypointPlaneNormal = ZERO_V3
				self.WaypointPlaneDist   = 0
			end
			return reached
		end

		function self:OnPointReached(reached)
			if not reached or self.Cancelled then
				if self.PathFailed then self.PathFailed:Fire() end
				self:Cleanup()
				return
			end

			local nextIdx = self.CurrentPoint + 1
			if nextIdx > #self.PointList then
				if self.Finished then self.Finished:Fire() end
				self:Cleanup()
				return
			end

			local curWP  = self.PointList[self.CurrentPoint]
			local nextWP = self.PointList[nextIdx]

			self:SetPlane(curWP, nextWP)
			self.CurrentPoint = nextIdx
			self.Timeout      = 0
		end

		function self:Tick(dt)
			if not self.Started or self.Cancelled then return end

			self.SegmentTimer = self.SegmentTimer + dt
			if self.SegmentTimer > SEGMENT_TIMEOUT then
				warn("[PF] Segment timed out — advancing")
				if self.Finished then self.Finished:Fire() end
				self:Cleanup()
				return
			end

			self.Timeout = self.Timeout + dt
			if self.Timeout > WAYPOINT_TIMEOUT then
				warn("[PF] Waypoint #" .. self.CurrentPoint .. " timed out — skipping")
				self:OnPointReached(true)
				return
			end

			local rp = getHumanoid() and getHumanoid().RootPart
			if not rp then return end

			self.HumanoidPos = rp.Position
			self.HumanoidVel = rp.AssemblyLinearVelocity

			while self.Started and self:IsWaypointReached() do
				self:OnPointReached(true)
			end
			if not self.Started then return end

			if self.WaypointPos then
				local dir = self.WaypointPos - self.HumanoidPos
				self.MoveDir = dir.Magnitude > ALMOST_ZERO and dir.Unit or ZERO_V3
			else
				self.MoveDir = ZERO_V3
			end

			self.DoJump = self.WaypointNeedsJump
			if self.WaypointNeedsJump then self.WaypointNeedsJump = false end
		end

		function self:Cleanup()
			if self.DiedConn   then self.DiedConn:Disconnect();   self.DiedConn   = nil end
			if self.SeatedConn then self.SeatedConn:Disconnect(); self.SeatedConn = nil end
			self.Started = false
			if self.Finished   then self.Finished:Destroy();   self.Finished   = nil end
			if self.PathFailed then self.PathFailed:Destroy(); self.PathFailed = nil end
		end

		function self:Cancel()
			self.Cancelled = true; self:Cleanup()
		end

		function self:IsActive()
			return self.Started and not self.Cancelled
		end

		function self:Start()
			if self.Started or not self.PointList or #self.PointList == 0 then
				if self.PathFailed then self.PathFailed:Fire() end
				return
			end
			local hum = getHumanoid()
			if not hum or not hum.RootPart then
				if self.PathFailed then self.PathFailed:Fire() end
				return
			end

			self.Started     = true
			self.HumanoidPos = hum.RootPart.Position
			self.HumanoidVel = hum.RootPart.AssemblyLinearVelocity

			self.DiedConn   = hum.Died:Connect(function()   self.Cancelled = true; self:Cleanup() end)
			self.SeatedConn = hum.Seated:Connect(function() self.Cancelled = true; self:Cleanup() end)

			self.CurrentPoint = 1
			self:OnPointReached(true)
		end

		return self
	end

	-- ─────────────────────────────────────────────────────────────────
	-- NAVIGATION STATE
	-- ─────────────────────────────────────────────────────────────────
	local Nav = {
		active        = false,
		checkpoints   = {},
		cpIndex       = 1,
		cpRetries     = {},
		cpFailCounts  = {},
		finalDest     = nil,
		pather        = nil,
		onFinished    = nil,
		onFailed      = nil,
		computing     = false,
		precomp       = {},
	}

	local oscBuffer     = {}
	local lastOscSample = 0
	local lastEscapeT   = 0

	local function cleanupPather()
		if Nav.pather then Nav.pather:Cancel(); Nav.pather = nil end
		if Nav.onFinished then Nav.onFinished:Disconnect(); Nav.onFinished = nil end
		if Nav.onFailed   then Nav.onFailed:Disconnect();   Nav.onFailed   = nil end
		clearSegDebug()
	end

	local function precomputeNext()
		local nextIdx = Nav.cpIndex + 1
		if nextIdx > #Nav.checkpoints then return end
		if Nav.precomp[nextIdx] ~= nil then return end

		Nav.precomp[nextIdx] = "pending"

		local fromPos = Nav.checkpoints[Nav.cpIndex] or rootPart.Position
		local toPos   = Nav.checkpoints[nextIdx]

		task.spawn(function()
			local wps, reached = computeSegment(fromPos, toPos)
			if wps then
				Nav.precomp[nextIdx] = {wps = wps, reached = reached}
				print(string.format("[PF] Pre-computed segment %d ✓", nextIdx))
			else
				Nav.precomp[nextIdx] = false
				print(string.format("[PF] Pre-computed segment %d ✗", nextIdx))
			end
		end)
	end

	local stopNav

	-- ─────────────────────────────────────────────────────────────────
	-- TELEPORT FALLBACK
	-- ─────────────────────────────────────────────────────────────────
	local function teleportToCheckpoint(target)
		local dest, ok = snapToGround(target)
		if not ok then dest = target end
		if rootPart then
			rootPart.CFrame = CFrame.new(dest + Vector3.new(0, 3.5, 0))
		end
		warn(string.format("[PF] ⚡ Teleport → (%.1f, %.1f, %.1f)", dest.X, dest.Y, dest.Z))
		task.wait(0.15)
	end

	local function shouldTeleport(fromPos, target)
		local yDiff    = math.abs(target.Y - fromPos.Y)
		local failures = Nav.cpFailCounts[Nav.cpIndex] or 0
		return yDiff >= TELEPORT_Y_THRESHOLD or failures >= TELEPORT_FAIL_THRESHOLD
	end

	-- ─────────────────────────────────────────────────────────────────
	-- MIDPOINT INJECTION
	-- ─────────────────────────────────────────────────────────────────
	local function tryInjectMidpoint(cpIdx, fromPos, toPos)
		local injectKey = "inject_" .. cpIdx
		local depth     = Nav.cpRetries[injectKey] or 0
		if depth >= MAX_INJECT_DEPTH then
			Nav.cpRetries[injectKey] = nil
			return false
		end

		local dist = Vector2.new(fromPos.X - toPos.X, fromPos.Z - toPos.Z).Magnitude
		if dist < MIN_BISECT_DIST then return false end

		local mid  = findMidpoint(fromPos, toPos)
		if not mid then return false end

		local dMid = Vector2.new(fromPos.X - mid.X, fromPos.Z - mid.Z).Magnitude
		if dMid < 3 or dMid > dist * 0.9 then return false end

		table.insert(Nav.checkpoints, cpIdx, mid)
		Nav.cpIndex = cpIdx - 1
		Nav.cpRetries[injectKey] = depth + 1
		drawCheckpoints(Nav.checkpoints)

		warn(string.format("[PF] Midpoint injected before cp%d (depth %d): (%.1f, %.1f, %.1f)",
			cpIdx, depth + 1, mid.X, mid.Y, mid.Z))
		return true
	end

	-- ─────────────────────────────────────────────────────────────────
	-- CHECKPOINT SEQUENCER
	-- ─────────────────────────────────────────────────────────────────
	local function advanceToNextCheckpoint()
		if not Nav.active then return end

		Nav.cpIndex = Nav.cpIndex + 1

		if Nav.cpIndex > #Nav.checkpoints then
			local pos    = rootPart.Position
			local xzDist = Vector2.new(pos.X - Nav.finalDest.X, pos.Z - Nav.finalDest.Z).Magnitude
			if xzDist <= ARRIVAL_DIST then
				stopNav("Destination reached ✓")
			else
				warn(string.format("[PF] Checkpoints exhausted %.1f studs from dest — recomputing", xzDist))
				task.spawn(function()
					if not Nav.active then return end
					Nav.checkpoints  = buildCheckpoints(rootPart.Position, Nav.finalDest)
					Nav.cpIndex      = 0
					Nav.cpRetries    = {}
					Nav.cpFailCounts = {}
					Nav.precomp      = {}
					if not Nav.active then return end
					drawCheckpoints(Nav.checkpoints)
					advanceToNextCheckpoint()
				end)
			end
			return
		end

		local target  = Nav.checkpoints[Nav.cpIndex]
		local fromPos = rootPart.Position

		if Vector2.new(fromPos.X - target.X, fromPos.Z - target.Z).Magnitude < 3 then
			advanceToNextCheckpoint()
			return
		end

		print(string.format("[PF] Segment %d/%d → (%.1f,%.1f,%.1f)  XZ=%.0f  ΔY=%.1f",
			Nav.cpIndex, #Nav.checkpoints,
			target.X, target.Y, target.Z,
			Vector2.new(fromPos.X - target.X, fromPos.Z - target.Z).Magnitude,
			target.Y - fromPos.Y))

		Nav.computing = true

		local cached = Nav.precomp[Nav.cpIndex]

		if cached == "pending" then
			task.spawn(function()
				local waited = 0
				while Nav.precomp[Nav.cpIndex] == "pending" and waited < 8 do
					task.wait(0.1)
					waited = waited + 0.1
				end
				Nav.computing = false
				if not Nav.active then return end
				Nav.cpIndex = Nav.cpIndex - 1
				advanceToNextCheckpoint()
			end)
			return
		end

		Nav.precomp[Nav.cpIndex] = nil

		local function onSegmentResult(wps, reached)
			Nav.computing = false
			if not Nav.active then return end

			if not wps then
				Nav.cpFailCounts[Nav.cpIndex] = (Nav.cpFailCounts[Nav.cpIndex] or 0) + 1

				if shouldTeleport(fromPos, target) then
					local reason = math.abs(target.Y - fromPos.Y) >= TELEPORT_Y_THRESHOLD
						and "floor gap" or "repeated failure"
					warn(string.format("[PF] ⚡ Teleporting to cp%d (%s)", Nav.cpIndex, reason))
					teleportToCheckpoint(target)
					Nav.cpFailCounts[Nav.cpIndex] = nil
					advanceToNextCheckpoint()
					return
				end

				if tryInjectMidpoint(Nav.cpIndex, fromPos, target) then
					advanceToNextCheckpoint()
					return
				end

				if Nav.cpIndex == #Nav.checkpoints then
					warn("[PF] Final segment unreachable — teleporting")
					teleportToCheckpoint(target)
					stopNav("Destination reached ✓")
				else
					warn(string.format("[PF] cp%d unreachable — skipping", Nav.cpIndex))
					advanceToNextCheckpoint()
				end
				return
			end

			local isPartial = reached and
				Vector2.new(reached.X - target.X, reached.Z - target.Z).Magnitude > 2

			if isPartial then
				table.insert(Nav.checkpoints, Nav.cpIndex + 1, target)
				drawCheckpoints(Nav.checkpoints)
				warn(string.format("[PF] Partial path injected: will resume to full target from (%.1f,%.1f,%.1f)",
					reached.X, reached.Y, reached.Z))
			end

			Nav.cpFailCounts[Nav.cpIndex] = nil

			drawSegment(wps)
			local pather = makePather(wps)
			Nav.pather   = pather

			precomputeNext()

			Nav.onFinished = pather.Finished.Event:Connect(function()
				cleanupPather()
				local pos     = rootPart.Position
				local arrived = Vector2.new(pos.X - target.X, pos.Z - target.Z).Magnitude
				local retries = Nav.cpRetries[Nav.cpIndex] or 0

				if not isPartial and arrived > RETRY_FAR_DIST and retries < MAX_CP_RETRIES then
					warn(string.format("[PF] Ended %.1f studs from cp — retry %d/%d",
						arrived, retries + 1, MAX_CP_RETRIES))
					Nav.cpRetries[Nav.cpIndex] = retries + 1
					Nav.cpIndex = Nav.cpIndex - 1
				else
					Nav.cpRetries[Nav.cpIndex] = nil
				end
				advanceToNextCheckpoint()
			end)

			Nav.onFailed = pather.PathFailed.Event:Connect(function()
				cleanupPather()
				Nav.cpFailCounts[Nav.cpIndex] = (Nav.cpFailCounts[Nav.cpIndex] or 0) + 1
				local retries = Nav.cpRetries[Nav.cpIndex] or 0

				if retries < MAX_CP_RETRIES then
					Nav.cpRetries[Nav.cpIndex] = retries + 1
					Nav.cpIndex = Nav.cpIndex - 1
					advanceToNextCheckpoint()
					return
				end

				Nav.cpRetries[Nav.cpIndex] = nil
				if shouldTeleport(rootPart.Position, target) then
					warn(string.format("[PF] ⚡ Pather failed cp%d — teleporting", Nav.cpIndex))
					teleportToCheckpoint(target)
					Nav.cpFailCounts[Nav.cpIndex] = nil
				elseif not tryInjectMidpoint(Nav.cpIndex, rootPart.Position, target) then
					warn(string.format("[PF] cp%d failed — skipping", Nav.cpIndex))
				end
				advanceToNextCheckpoint()
			end)

			pather:Start()
		end

		if cached and cached ~= false then
			print(string.format("[PF] Using pre-computed segment %d", Nav.cpIndex))
			onSegmentResult(cached.wps, cached.reached)
		elseif cached == false then
			onSegmentResult(nil, nil)
		else
			task.spawn(function()
				local wps, reached = computeSegment(fromPos, target)
				onSegmentResult(wps, reached)
			end)
		end
	end

	-- ─────────────────────────────────────────────────────────────────
	-- START NAVIGATION
	-- ─────────────────────────────────────────────────────────────────
	local function startNav(destination)
		stopNav(nil)

		local startPos        = rootPart.Position
		local snappedDest, ok = snapToGround(destination)
		if not ok then snappedDest = destination end

		Nav.active       = true
		Nav.finalDest    = snappedDest
		Nav.cpIndex      = 0
		Nav.cpRetries    = {}
		Nav.cpFailCounts = {}
		Nav.computing    = true

		showDest(snappedDest)
		print(string.format("[PF] ── New navigation → (%.1f, %.1f, %.1f)",
			snappedDest.X, snappedDest.Y, snappedDest.Z))

		task.spawn(function()
			Nav.checkpoints = buildCheckpoints(startPos, snappedDest)
			Nav.computing   = false
			Nav.precomp     = {}
			if not Nav.active then return end

			if #Nav.checkpoints == 0 then
				stopNav("No path found")
				return
			end

			drawCheckpoints(Nav.checkpoints)
			print(string.format("[PF] %d checkpoints", #Nav.checkpoints))
			advanceToNextCheckpoint()
		end)
	end

	-- ─────────────────────────────────────────────────────────────────
	-- STOP NAVIGATION
	-- ─────────────────────────────────────────────────────────────────
	stopNav = function(reason)
		Nav.active       = false
		Nav.computing    = false
		Nav.cpRetries    = {}
		Nav.cpFailCounts = {}
		oscBuffer        = {}
		Nav.precomp      = {}
		cleanupPather()
		hideDest()
		clearDebug()
		clearCheckpointMarkers()
		clearSegDebug()
		local hum = getHumanoid()
		if hum then hum:Move(ZERO_V3, false) end
		if reason then print("[PF] " .. reason) end
	end

	-- ─────────────────────────────────────────────────────────────────
	-- REACTIVE JUMP
	-- ─────────────────────────────────────────────────────────────────
	local lastJump   = 0
	local lastJumpY  = 0
	local jumpStreak = 0

	local function reactiveJump(moveDir, nearFinal)
		if nearFinal then return false end
		if jumpStreak >= JUMP_STREAK_MAX then return false end
		if rootPart.AssemblyLinearVelocity.Y > 2 then return false end

		if Nav.pather and Nav.pather.WaypointPos then
			local gNext = workspace:Raycast(Nav.pather.WaypointPos + Vector3.new(0,4,0), Vector3.new(0,-10,0), RAY_PARAMS)
			local gSelf = workspace:Raycast(rootPart.Position,                             Vector3.new(0,-10,0), RAY_PARAMS)
			local nextY = gNext and gNext.Position.Y or Nav.pather.WaypointPos.Y
			local selfY = gSelf and gSelf.Position.Y or rootPart.Position.Y
			if nextY - selfY < STEP_JUMP_MIN then return false end
		end

		local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
		if flat.Magnitude < 0.01 then return false end
		flat = flat.Unit

		local pos     = rootPart.Position
		local gHit    = workspace:Raycast(pos, Vector3.new(0,-15,0), RAY_PARAMS)
		local groundY = gHit and gHit.Position.Y or pos.Y

		for _, h in ipairs({2.0, 4.2}) do
			local origin = Vector3.new(pos.X, groundY + h, pos.Z)
			local hit    = workspace:Raycast(origin, flat * JUMP_FWD_DIST, RAY_PARAMS)
			if hit and math.abs(hit.Normal.Y) < 0.65 then
				local topFrom = hit.Position + Vector3.new(0, JUMP_MAX_HEIGHT + 2, 0)
				local topHit  = workspace:Raycast(topFrom, Vector3.new(0, -(JUMP_MAX_HEIGHT + 3), 0), RAY_PARAMS)
				local obstH   = topHit and (topHit.Position.Y - groundY) or (JUMP_MAX_HEIGHT + 1)
				if obstH >= STEP_JUMP_MIN and obstH <= JUMP_MAX_HEIGHT then
					return true
				end
			end
		end
		return false
	end

	-- ─────────────────────────────────────────────────────────────────
	-- OSCILLATION DETECTOR + ESCAPE ROUTE
	-- ─────────────────────────────────────────────────────────────────
	local function sampleOscillation()
		local now = tick()
		if now - lastOscSample < OSCILLATION_RATE then return end
		lastOscSample = now
		local pos = rootPart.Position
		table.insert(oscBuffer, {x = pos.X, z = pos.Z})
		if #oscBuffer > OSCILLATION_SAMPLES then table.remove(oscBuffer, 1) end
	end

	local function isOscillating()
		if #oscBuffer < OSCILLATION_SAMPLES then return false end
		local cx, cz = 0, 0
		for _, p in ipairs(oscBuffer) do cx = cx + p.x; cz = cz + p.z end
		cx = cx / #oscBuffer; cz = cz / #oscBuffer
		local maxDev = 0
		for _, p in ipairs(oscBuffer) do
			local d = math.sqrt((p.x-cx)^2 + (p.z-cz)^2)
			if d > maxDev then maxDev = d end
		end
		return maxDev < OSCILLATION_RADIUS
	end

	local function triggerEscapeRoute()
		if not Nav.active or not Nav.finalDest then return end
		local now = tick()
		if now - lastEscapeT < ESCAPE_COOLDOWN then return end
		lastEscapeT = now

		warn("[PF] Oscillation detected — injecting escape waypoint")
		oscBuffer = {}

		local pos    = rootPart.Position
		local toGoal = Vector3.new(Nav.finalDest.X - pos.X, 0, Nav.finalDest.Z - pos.Z)
		if toGoal.Magnitude < ALMOST_ZERO then return end
		toGoal = toGoal.Unit

		local perpR = Vector3.new( toGoal.Z, 0, -toGoal.X)
		local perpL = Vector3.new(-toGoal.Z, 0,  toGoal.X)

		cleanupPather()
		Nav.computing = true

		task.spawn(function()
			local escaped = false
			for _, dist in ipairs({6, 10, 14}) do
				for _, perp in ipairs({perpR, perpL}) do
					local escapePos, snapOk = snapToGround(pos + perp * dist)
					if not snapOk then continue end

					local escWps = rawCompute(pos, escapePos, AGENT_RADIUS)
						or rawCompute(pos, escapePos, 1.0)
					if escWps then
						drawSegment(escWps)
						local esc = makePather(escWps)
						Nav.pather = esc

						Nav.onFinished = esc.Finished.Event:Connect(function()
							cleanupPather()
							if not Nav.active then return end
							Nav.checkpoints  = buildCheckpoints(rootPart.Position, Nav.finalDest)
							Nav.cpIndex      = 0
							Nav.cpRetries    = {}
							Nav.cpFailCounts = {}
							Nav.precomp      = {}
							drawCheckpoints(Nav.checkpoints)
							advanceToNextCheckpoint()
						end)
						Nav.onFailed = esc.PathFailed.Event:Connect(function()
							cleanupPather()
							if Nav.active then advanceToNextCheckpoint() end
						end)

						esc:Start()
						escaped = true
						break
					end
				end
				if escaped then break end
			end

			Nav.computing = false
			if not escaped then
				warn("[PF] Escape route failed — forcing checkpoint rebuild")
				if not Nav.active then return end
				Nav.checkpoints  = buildCheckpoints(rootPart.Position, Nav.finalDest)
				Nav.cpIndex      = 0
				Nav.cpRetries    = {}
				Nav.cpFailCounts = {}
				Nav.precomp      = {}
				drawCheckpoints(Nav.checkpoints)
				advanceToNextCheckpoint()
			end
		end)
	end

	-- ─────────────────────────────────────────────────────────────────
	-- RENDER LOOP
	-- ─────────────────────────────────────────────────────────────────
	Services.RunService.RenderStepped:Connect(function(dt)
		if destBase.Transparency < 1 then
			destBase.CFrame = destBase.CFrame * CFrame.Angles(0, dt * 1.8, 0)
		end

		updatePassthrough()

		if not Nav.active or not Nav.pather or not Nav.pather:IsActive() then return end

		sampleOscillation()
		if not Nav.computing and isOscillating() then
			triggerEscapeRoute()
			return
		end

		local hum = getHumanoid()
		if not hum then return end

		Nav.pather:Tick(dt)
		if not Nav.pather or not Nav.pather:IsActive() then return end

		local moveDir = Nav.pather.MoveDir
		if moveDir.Magnitude > ALMOST_ZERO then
			hum:Move(moveDir, false)
		end

		local pos       = rootPart.Position
		local finalCP   = Nav.checkpoints[#Nav.checkpoints]
		local nearFinal = finalCP and
			(Vector3.new(pos.X,0,pos.Z) - Vector3.new(finalCP.X,0,finalCP.Z)).Magnitude < JUMP_NEAR_DEST

		local wantsJump = Nav.pather.DoJump
		if not wantsJump and not nearFinal then
			local state = hum:GetState()
			if state == Enum.HumanoidStateType.Running
				or state == Enum.HumanoidStateType.RunningNoPhysics then
				wantsJump = reactiveJump(moveDir, nearFinal)
			end
		end

		if wantsJump then
			local now = tick()
			if now - lastJump >= JUMP_COOLDOWN then
				local dy = pos.Y - lastJumpY
				jumpStreak = (dy < 0.3 and lastJumpY ~= 0) and jumpStreak + 1 or 0
				lastJump  = now
				lastJumpY = pos.Y
				if jumpStreak < JUMP_STREAK_MAX then hum.Jump = true end
			end
		elseif tick() - lastJump > 1.5 then
			jumpStreak = 0
			lastJumpY  = 0
		end
	end)

	-- ─────────────────────────────────────────────────────────────────
	-- PUBLIC API
	-- ─────────────────────────────────────────────────────────────────
	local API = {}

	API.OnReached   = nil
	API.OnFailed    = nil
	API.OnSegment   = nil
	API.OnComputing = nil

	local _baseStopNav = stopNav
	stopNav = function(reason)
		_baseStopNav(reason)
		if not reason then return end
		if reason:find("reached") then
			if API.OnReached   then task.spawn(API.OnReached)        end
		else
			if API.OnFailed    then task.spawn(API.OnFailed, reason) end
		end
		if API.OnComputing then task.spawn(API.OnComputing, false) end
	end

	function API.SetDestination(position)
		assert(typeof(position) == "Vector3", "SetDestination: expected Vector3")
		startNav(position)
		if API.OnComputing then task.spawn(API.OnComputing, true) end
	end

	function API.CancelDestination()
		stopNav("Cancelled")
	end

	function API.IsNavigating()
		return Nav.active
	end

	function API.IsComputing()
		return Nav.computing
	end

	function API.GetDestination()
		return Nav.finalDest
	end

	function API.GetProgress()
		return Nav.cpIndex, #Nav.checkpoints
	end

	function API.SetIgnoreList(list)
		assert(type(list) == "table", "SetIgnoreList: expected table")
		PathfindIgnore = list
		refreshIgnore()
	end

	function API.AddToIgnoreList(instance)
		table.insert(PathfindIgnore, instance)
		refreshIgnore()
	end

	function API.RemoveFromIgnoreList(instance)
		for i, v in ipairs(PathfindIgnore) do
			if v == instance then table.remove(PathfindIgnore, i); break end
		end
		refreshIgnore()
	end

	function API.SetTeleportYThreshold(studs)
		TELEPORT_Y_THRESHOLD = studs
	end

	function API.SetTeleportFailThreshold(count)
		TELEPORT_FAIL_THRESHOLD = count
	end

	function API.SetDebug(enabled)
		DEBUG = enabled
		if not DEBUG then clearDebug(); clearSegDebug(); clearCheckpointMarkers() end
	end

	function API.ToggleDebug()
		API.SetDebug(not DEBUG)
	end

	-- NodeAssist controls
	function API.ReloadNodes()
		NodeAssist.Reload()
	end

	function API.SetNodeSnapDistance(studs)
		NODE_SNAP_DIST = studs
	end

	return API
end)()

local NoRecoil_Enabled=false
local NoRecoil_Connections={}
local GlobalOriginalValues={}
local WeaponCache={}
local WeaponSpeedCache = {}          -- map [ToolInstance] = velocity
local WeaponSpeedCacheByName = {}    -- map [toolName] = velocity
local WeaponModuleNameMap = {}       -- map [moduleName] = moduleTable
local WeaponModuleHandleMap = {}     -- map [handleName] = moduleTable
local lastWeaponCacheTime = 0
local weaponCacheCooldown = 1.5 -- seconds (throttle expensive cache rebuilds)
local isCachingInProgress = false
local Settings={GunMods={
	NoRecoil=true,
	Spread=true,
	SpreadAmount=0,
	MagSizeOverride=nil,
	StoredAmmoOverride=nil
}}
local Player_nr=LocalPlayer
local GunMods_Connections = {}
local CharacterAddedConn = nil

local function cacheWeapons(force)
	force = force or false
	if not getgc and not getgenv and not getgenv().getgc then Fluent:Notify({Title = "Failed to cache weapons", Content = "Missing: getgc and/or getgenv", Duration = 5}) return end
	local now = tick()
	if not force and (now - lastWeaponCacheTime) < weaponCacheCooldown and #WeaponCache > 0 then return end
	if isCachingInProgress then return end
	isCachingInProgress = true
	lastWeaponCacheTime = now
	WeaponCache = {}
	WeaponModuleNameMap = {}
	WeaponModuleHandleMap = {}
	for _, v in pairs(getgc(true)) do
		if type(v)=='table' and rawget(v,'EquipTime') then
			table.insert(WeaponCache, v);
			if type(v.Name) == "string" then
				WeaponModuleNameMap[v.Name] = v
			end
			if type(v.HandleName) == "string" then
				WeaponModuleHandleMap[v.HandleName] = v
			end
			if not GlobalOriginalValues[v] then
				GlobalOriginalValues[v]={
					Recoil=v.Recoil,CameraRecoilingEnabled=v.CameraRecoilingEnabled,
					AngleX_Min=v.AngleX_Min,AngleX_Max=v.AngleX_Max,
					AngleY_Min=v.AngleY_Min,AngleY_Max=v.AngleY_Max,
					AngleZ_Min=v.AngleZ_Min,AngleZ_Max=v.AngleZ_Max,
					Spread=v.Spread,
					FireRate=v.FireRate,
					MagSize=v.MagSize,
					StoredAmmo=v.StoredAmmo,
					LimitedAmmoEnabled=v.LimitedAmmoEnabled,
					StartFull=v.StartFull
				}
			end
		end
	end
	isCachingInProgress = false
	lastWeaponCacheTime = tick()
end

getCurrentWeaponBulletStats = function()
	local char = LocalPlayer and LocalPlayer.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then
		return 0, nil, 0.1
	end

	-- Check per-tool cache first
	local cached = WeaponSpeedCache[tool]
	if type(cached) == "table" and cached.speed > 0 then
		return cached.speed, cached.accel, cached.fireRate
	end
	local cachedByName = WeaponSpeedCacheByName[tool.Name]
	if type(cachedByName) == "table" and cachedByName.speed > 0 then
		return cachedByName.speed, cachedByName.accel, cachedByName.fireRate
	end

	local function findBulletStats()
		if #WeaponCache == 0 then
			cacheWeapons()
		end

		local toolName = tool and tool.Name or ""
		for _, v in ipairs(WeaponCache) do
			if type(v) == "table" then
				local matchesTool = false
				if v.Name == toolName then
					matchesTool = true
				elseif v.HandleName == toolName then
					matchesTool = true
				elseif type(v.HandleName) == "string" and tool:FindFirstChild(v.HandleName) then
					matchesTool = true
				end
				if matchesTool then
					local bulletSettings = v.BulletSettings
					local speed = 0
					local accel = nil
					local fr = type(v.FireRate) == "number" and v.FireRate or 0.1
					if type(bulletSettings) == "table" then
						if type(bulletSettings.Velocity) == "number" and bulletSettings.Velocity > 0 then
							speed = bulletSettings.Velocity
						end
						if typeof(bulletSettings.Acceleration) == "Vector3" then
							accel = bulletSettings.Acceleration
						end
					end
					if speed > 0 then
						return {speed = speed, accel = accel, fireRate = fr}
					end
				end
			end
		end
		return nil
	end

	local stats = findBulletStats()
	if stats then
		WeaponSpeedCache[tool] = stats
		WeaponSpeedCacheByName[tool.Name] = stats
		return stats.speed, stats.accel, stats.fireRate
	end

	-- Poll briefly for weapon modules to appear after quick swaps (total ~250ms)
	local deadline = tick() + 0.25
	while tick() < deadline do
		cacheWeapons()
		stats = findBulletStats()
		if stats then
			WeaponSpeedCache[tool] = stats
			WeaponSpeedCacheByName[tool.Name] = stats
			return stats.speed, stats.accel, stats.fireRate
		end
		task.wait(0.05)
	end

	return 0, nil, 0.1
end

local function applyNoRecoilMods()
	for _, weapon in ipairs(WeaponCache) do
		weapon.Recoil = 0
		weapon.CameraRecoilingEnabled = false
		weapon.AngleX_Min = 0; weapon.AngleX_Max = 0
		weapon.AngleY_Min = 0; weapon.AngleY_Max = 0
		weapon.AngleZ_Min = 0; weapon.AngleZ_Max = 0
	end
end

local function resetNoRecoilMods()
	for weapon, values in pairs(GlobalOriginalValues) do
		if values.Recoil ~= nil then weapon.Recoil = values.Recoil end
		if values.CameraRecoilingEnabled ~= nil then weapon.CameraRecoilingEnabled = values.CameraRecoilingEnabled end
		if values.AngleX_Min ~= nil then weapon.AngleX_Min = values.AngleX_Min end
		if values.AngleX_Max ~= nil then weapon.AngleX_Max = values.AngleX_Max end
		if values.AngleY_Min ~= nil then weapon.AngleY_Min = values.AngleY_Min end
		if values.AngleY_Max ~= nil then weapon.AngleY_Max = values.AngleY_Max end
		if values.AngleZ_Min ~= nil then weapon.AngleZ_Min = values.AngleZ_Min end
		if values.AngleZ_Max ~= nil then weapon.AngleZ_Max = values.AngleZ_Max end
	end
end

local function applyGunMods()
	for _, weapon in ipairs(WeaponCache) do
		if Settings.GunMods.Spread then
			weapon.Spread = Settings.GunMods.SpreadAmount
		end

	end
end

local function resetGunMods()
	for weapon, values in pairs(GlobalOriginalValues) do
		weapon.Spread = values.Spread
		if values.MagSize ~= nil then weapon.MagSize = values.MagSize end
		if values.StoredAmmo ~= nil then weapon.StoredAmmo = values.StoredAmmo end
		if values.LimitedAmmoEnabled ~= nil then weapon.LimitedAmmoEnabled = values.LimitedAmmoEnabled end
		if values.StartFull ~= nil then weapon.StartFull = values.StartFull end
	end
end

local function ClearWeaponCaches()
	-- Restore original values first
	pcall(function() resetNoRecoilMods() end)
	pcall(function() resetGunMods() end)

	-- Disconnect stored connections
	for _, conn in ipairs(NoRecoil_Connections) do pcall(function() conn:Disconnect() end) end
	NoRecoil_Connections = {}
	for _, conn in ipairs(GunMods_Connections) do pcall(function() conn:Disconnect() end) end
	GunMods_Connections = {}

	-- Clear caches and maps
	WeaponCache = {}
	WeaponSpeedCache = {}
	WeaponSpeedCacheByName = {}
	WeaponModuleNameMap = {}
	WeaponModuleHandleMap = {}
	GlobalOriginalValues = {}
	lastWeaponCacheTime = 0
	isCachingInProgress = false

	pcall(function() Fluent:Notify({Title = "Cache", Content = "Weapon cache cleared", Duration = 2}) end)
end

local function handleWeapon(weapon)
	local wantsReapply = NoRecoil_Enabled or Settings.GunMods.Spread
	if not wantsReapply then return end

	task.wait(0.1)
	cacheWeapons()
	if NoRecoil_Enabled then applyNoRecoilMods() end
	if Settings.GunMods.Spread then applyGunMods() end

	-- Ensure mods re-apply when player equips the tool (handles quick swaps)
	if weapon and weapon:IsA("Tool") then
		local function updateToolBulletSpeed(toolInst)
			if not toolInst then return end
			local found = nil
			local tName = toolInst.Name
			-- try fast maps first
			found = WeaponModuleNameMap[tName] or WeaponModuleHandleMap[tName]
			if not found then
				for _, v in ipairs(WeaponCache) do
					if type(v) == "table" then
						if v.Name == tName then found = v; break end
						if v.HandleName == tName then found = v; break end
						if type(v.HandleName) == "string" and toolInst:FindFirstChild(v.HandleName) then found = v; break end
					end
				end
			end
			if found and found.BulletSettings and type(found.BulletSettings.Velocity) == "number" and found.BulletSettings.Velocity > 0 then
				local stats = {
					speed = found.BulletSettings.Velocity,
					accel = typeof(found.BulletSettings.Acceleration) == "Vector3" and found.BulletSettings.Acceleration or nil,
					fireRate = type(found.FireRate) == "number" and found.FireRate or 0.1
				}
				WeaponSpeedCache[toolInst] = stats
				WeaponSpeedCacheByName[toolInst.Name] = stats
			end
		end

		-- initial populate
		pcall(updateToolBulletSpeed, weapon)

		local ok, conn = pcall(function()
			return weapon.Equipped:Connect(function()
				task.wait(0.05)
				cacheWeapons()
				if NoRecoil_Enabled then applyNoRecoilMods() end
				if Settings.GunMods.Spread then applyGunMods() end
				pcall(updateToolBulletSpeed, weapon)
			end)
		end)
		if ok and conn then
			if NoRecoil_Enabled then table.insert(NoRecoil_Connections, conn) end
			if Settings.GunMods.Spread then table.insert(GunMods_Connections, conn) end
		end
	end
end

local function onCharacterAdded_nr(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			handleWeapon(child)
		end
	end

	-- Watch for tools added to the character so mods re-apply on weapon swap
	if NoRecoil_Enabled or Settings.GunMods.Spread then
		local childConn = character.ChildAdded:Connect(function(child)
			if child and child:IsA("Tool") then
				handleWeapon(child)
			end
		end)
		if NoRecoil_Enabled then table.insert(NoRecoil_Connections, childConn) end
		if Settings.GunMods.Spread then table.insert(GunMods_Connections, childConn) end
	end

	local humanoid = character:WaitForChild("Humanoid", 2)
	if humanoid then
		table.insert(NoRecoil_Connections, humanoid.Died:Connect(function()
			if NoRecoil_Enabled then
				task.wait(1.5)
				cacheWeapons()
				applyNoRecoilMods()
			elseif Settings.GunMods.Spread then
				task.wait(1.5)
				cacheWeapons()
				applyGunMods()
			end
		end))
	end
end

function ToggleNoRecoil(boolean)
	if boolean then
		if not NoRecoil_Enabled then
			NoRecoil_Enabled = true
			cacheWeapons()
			applyNoRecoilMods()
			if not CharacterAddedConn then
				CharacterAddedConn = Player_nr.CharacterAdded:Connect(onCharacterAdded_nr)
			end
		end
	else
		if NoRecoil_Enabled then
			NoRecoil_Enabled = false
			resetNoRecoilMods()
			for _, conn in ipairs(NoRecoil_Connections) do conn:Disconnect() end
			NoRecoil_Connections = {}
			if CharacterAddedConn and not (Settings.GunMods.Spread) then
				CharacterAddedConn:Disconnect()
				CharacterAddedConn = nil
			end
			-- If no mods remain enabled, clear caches to free memory and avoid getgc spam
			if not (NoRecoil_Enabled or Settings.GunMods.Spread) then
				ClearWeaponCaches()
			end
		end
	end
	if Player_nr.Character then onCharacterAdded_nr(Player_nr.Character) end
end

do -- combat extra features

end
-- SilentAim system wrapped in local scope
do
	local silentAim_Enabled = false
	local silentAim_Target = nil
	local silentAim_Coroutine = nil
	local friendlyCheck_Enabled = true
	local wallCheck_Enabled = false
	local debugTrail_Enabled = true

	local function drawDebugTrail(startPos, endPos)
		if not debugTrail_Enabled then return end
		task.spawn(function()
			local distance = (startPos - endPos).Magnitude
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.Neon
			part.Color = Color3.new(1, 0, 0)
			part.Size = Vector3.new(0.1, 0.1, distance)
			part.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
			part.Parent = workspace

			local tweenService = game:GetService("TweenService")
			local tween = tweenService:Create(part, TweenInfo.new(1.5), {Transparency = 1})
			tween:Play()

			task.wait(1.5)
			part:Destroy()
		end)
	end

	local GNX_S_Remote = world.Evts:WaitForChild("GNX_S", 5)
	local ZFKLF_H_Remote = world.Evts:WaitForChild("ZFKLF__H", 5)

	-- Whitelist / Roblox friends check
	function friendlyCheck(player)
		local isWL = state.UserWL[player.Name]
		local isSocialFriend = false
		pcall(function()
			if player and player:IsA("Player") then
				isSocialFriend = player:IsFriendsWith(LocalPlayer.UserId)
			end
		end)
		return (isWL or isSocialFriend)
	end

	local silentAim_EnemyDistance = 200

	function ToggleSilentAimEnemyDistance(dist)
		if type(dist) == "number" and dist > 0 then
			silentAim_EnemyDistance = dist
		else
			silentAim_EnemyDistance = 200
		end
	end

	local function wallcheck(startPos, endPos)
		local direction = (endPos - startPos).Unit
		local distance = (endPos - startPos).Magnitude
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
		local raycastResult = workspace:Raycast(startPos, direction * distance, raycastParams)
		return raycastResult ~= nil
	end

	local function GetSilentAimClosestEnemy()
		local closestEnemy = nil
		local shortestDistance = silentAim_EnemyDistance
		local myChar = LocalPlayer.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if not myHRP then return nil end

		for _, player in ipairs(Services.Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local enemyChar = player.Character
				local enemyHRP = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
				local enemyHum = enemyChar and enemyChar:FindFirstChildOfClass("Humanoid")

				if enemyHRP and enemyHum and enemyHum.Health > 15 and not enemyChar:FindFirstChildOfClass("ForceField") then
					-- skip friendlies if enabled
					if friendlyCheck_Enabled and friendlyCheck(player) then
						continue
					end
					local distance = (myHRP.Position - enemyHRP.Position).Magnitude
					if distance < shortestDistance then
						shortestDistance = distance
						closestEnemy = player
					end
				end
			end
		end
		return closestEnemy
	end

	local function ShootRage(VictimPlayer, speed, accel)
		if not VictimPlayer or not VictimPlayer.Character then return end
		local targetPart = VictimPlayer.Character:FindFirstChild("Head")
			or VictimPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not targetPart then return end

		local char = LocalPlayer.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if not tool then return end

		local currentcamera = workspace.CurrentCamera
		local targetVelocity = getTargetVelocity(VictimPlayer.Character)
		local hitPos = calculateBulletPrediction(targetPart.Position, targetVelocity, speed, accel)
		local hitDir = (hitPos - currentcamera.CFrame.Position).Unit
		local randomKey = RandomString(30).."0"

		if not GNX_S_Remote or not ZFKLF_H_Remote then
			warn("SilentAim Error: Required remotes not found.")
			return
		end

		pcall(function()
			GNX_S_Remote:FireServer(
				tick(),
				randomKey,
				tool,
				"FDS9I83",
				currentcamera.CFrame.Position,
				{hitDir},
				false
			)

			-- Draw debug trail from weapon to hit position
			if tool and tool:FindFirstChild("Handle") then
				drawDebugTrail(tool.Handle.Position, hitPos)
			else
				drawDebugTrail(currentcamera.CFrame.Position, hitPos)
			end
		end)

		pcall(function()
			ZFKLF_H_Remote:FireServer(
				"🧈",
				tool,
				randomKey,
				1,
				targetPart,
				hitPos,
				hitDir,
				nil,
				nil
			)
		end)
	end

	local function silentAimLoop()
		while silentAim_Enabled do
			local target = GetSilentAimClosestEnemy()
			if wallCheck_Enabled and target then
				local myChar = LocalPlayer.Character
				local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
				local targetChar = target.Character
				local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				if myHRP and targetHRP then
					if wallcheck(myHRP.Position, targetHRP.Position) then
						target = nil -- block target if wall is in the way
					end
				end
			end
			silentAim_Target = target
			if target and Services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				local speed, accel, fireRate = getCurrentWeaponBulletStats()
				ShootRage(target, speed, accel)
				task.wait(fireRate > 0 and (1 / fireRate) or 0.1)
			else
				task.wait(0.1)
			end
		end
		silentAim_Target = nil
		silentAim_Coroutine = nil
	end

	function ToggleSilentAim(state)
		silentAim_Enabled = state
		if silentAim_Enabled then
			if not GNX_S_Remote or not ZFKLF_H_Remote then
				ToggleSilentAim(false)
				warn("SilentAim Error: Required remotes not found.")
				return
			end
			if not silentAim_Coroutine then
				silentAim_Coroutine = task.spawn(silentAimLoop)
			end
		end
	end

	function ToggleSilentAimFriendlyCheck(state)
		friendlyCheck_Enabled = state
	end

	function ToggleSilentAimWallCheck(state)
		wallCheck_Enabled = state
	end

	function ToggleSilentAimDebugTrail(state)
		debugTrail_Enabled = state
	end
end

-- that one specific epic skin changer

do
	local SKINS = {
		["AKM"]={
			{name="akm_gildedfury",display="Gilded Fury",rarity="limited",textureID="15282807876",skinClass="Guns",sa={color="rbxassetid://15282807876",normal="rbxassetid://15282804930",roughness="rbxassetid://15282805071",metalness="rbxassetid://15282804808",customColor={145,127,175}}},
			{name="akm_gildedfury",display="Gilded Fury AKM",rarity="limited",textureID="15282807876",skinClass="Guns",sa={color="rbxassetid://15282807876",normal="rbxassetid://15282804930",roughness="rbxassetid://15282805071",metalness="rbxassetid://15282804808",customColor={145,127,175}}},
		},
		["AKS-74U"]={
			{name="aks_battleworncamo",display="Battleworn Camo",rarity="common",textureID="13842105937",skinClass="Guns",sa={color="rbxassetid://13842104374",normal="rbxassetid://13841838347",roughness="rbxassetid://13841839392",metalness="rbxassetid://13841837380"}},
			{name="aks_decay",display="DECAY-74U",rarity="common",textureID="138901102926673",skinClass="Guns",sa={color="rbxassetid://138901102926673",normal="",roughness="",metalness=""}},
			{name="aks_draco",display="Draco",rarity="common",textureID="13388089214",skinClass="Guns",sa={color="rbxassetid://13388090322",normal="rbxassetid://13388091442",roughness="rbxassetid://13388092218",metalness="rbxassetid://13388090867"}},
			{name="aks_crimcola",display="Crim Cola!",rarity="uncommon",textureID="13387566361",skinClass="Guns",sa={color="rbxassetid://13387556541",normal="rbxassetid://13387558142",roughness="rbxassetid://13387559359",metalness="rbxassetid://13387557277"}},
			{name="aks_formula",display="Formula",rarity="rare",textureID="16010501274",skinClass="Guns",sa={color="rbxassetid://16010501274",normal="rbxassetid://16010501274",roughness="rbxassetid://16010501274",metalness="rbxassetid://16010501274"}},
			{name="aks_gravebound",display="Gravebound",rarity="rare",textureID="107225184415547",skinClass="Guns",sa={color="rbxassetid://107225184415547",normal="rbxassetid://107225184415547",roughness="rbxassetid://107225184415547",metalness="rbxassetid://107225184415547"}},
			{name="aks_sharkbite",display="Sharkbite",rarity="rare",textureID="11684759812",skinClass="Guns",sa={color="rbxassetid://11684759812",normal="rbxassetid://11684763552",roughness="rbxassetid://11684764559",metalness="rbxassetid://11684761413"}},
			{name="aks_cherish",display="Cherish",rarity="legendary",textureID="16355375052",skinClass="Guns",sa={color="rbxassetid://16355375052",normal="rbxassetid://16355375052",roughness="rbxassetid://16355375052",metalness="rbxassetid://16355375052"}},
			{name="aks_frostbite",display="Frostbite",rarity="legendary",textureID="86574930426293",skinClass="Guns",sa={color="rbxassetid://82590391241285",normal="rbxassetid://92519255518461",roughness="rbxassetid://131453922856800",metalness="rbxassetid://107561609026444"}},
			{name="aks_jadestone",display="Jadestone",rarity="legendary",textureID="13712930979",skinClass="Guns",sa={color="rbxassetid://13712920992",normal="rbxassetid://13712922823",roughness="rbxassetid://13712861089",metalness="rbxassetid://13712921779"}},
			{name="aks_mire",display="Mire",rarity="legendary",textureID="15177307123",skinClass="Guns",sa={color="rbxassetid://15177307123",normal="rbxassetid://15177307123",roughness="rbxassetid://15177307123",metalness="rbxassetid://15177307123"}},
			{name="aks_pluto",display="PLUTO",rarity="limited",textureID="119124175056081",skinClass="Guns",sa={color="rbxassetid://119124175056081",normal="rbxassetid://8969901925",roughness="rbxassetid://8969903071",metalness="rbxassetid://8969900202",customColor={141,0,127}}},
		},
		["AWM"]={
			{name="awm_bob",display="Bob",rarity="limited",textureID="97069820896111",skinClass="Guns",sa={color="rbxassetid://97069820896111",normal="rbxassetid://16272297797",roughness="rbxassetid://16272298674",metalness="rbxassetid://16272296814"}},
		},
		["BBaton"]={
			{name="baton_magicwand",display="Magic Wand",rarity="common",textureID="15447733301",skinClass="Melees",sa={color="rbxassetid://15447733301",normal="rbxassetid://15447733301",roughness="rbxassetid://15447733301",metalness="rbxassetid://15447733301"}},
			{name="baton_silverbanded",display="Silverbanded",rarity="common",textureID="16688298201",skinClass="Melees",sa=nil},
			{name="baton_marbleized",display="Marbleized",rarity="rare",textureID="16688079257",skinClass="Melees",sa=nil},
		},
		["BFG-1"]={
			{name="bfg_federal",display="Federal",rarity="uncommon",textureID="13948530321",skinClass="Guns",sa={color="rbxassetid://13948416273",normal="rbxassetid://13948408785",roughness="rbxassetid://13948409253",metalness="rbxassetid://13948408225"}},
			{name="bfg_savior",display=".50 Savior",rarity="rare",textureID="18316883517",skinClass="Guns",sa={color="rbxassetid://18316883517",normal="rbxassetid://18316883517",roughness="rbxassetid://18316883517",metalness="rbxassetid://18316883517"}},
			{name="bfg_cupid",display="Cupid",rarity="limited",textureID="16355412948",skinClass="Guns",sa={color="rbxassetid://16355412948",normal="rbxassetid://16355412388",roughness="rbxassetid://16355412639",metalness="rbxassetid://16355411427"}},
		},
		["Balisong"]={
			{name="balisong_tan",display="Tan",rarity="common",textureID="15445188373",skinClass="Melees",sa=nil},
			{name="balisong_viper",display="Viper",rarity="uncommon",textureID="14983742104",skinClass="Melees",sa={color="rbxassetid://14983742104",normal="rbxassetid://14983728828",roughness="rbxassetid://14983729641",metalness="rbxassetid://14983727617"}},
			{name="balisong_fade",display="Fade",rarity="rare",textureID="16688046816",skinClass="Melees",sa={color="rbxassetid://16688046451",normal="rbxassetid://16688048275",roughness="rbxassetid://16688047264",metalness="rbxassetid://16688048586"}},
			{name="balisong_vampiric",display="Vampiric SKIBIDI OPIUM",rarity="rare",textureID="15177238158",skinClass="Melees",sa={color="rbxassetid://15177238158",normal="rbxassetid://14983728828",roughness="rbxassetid://14983729641",metalness="rbxassetid://14983727617"}},
			{name="balisong_stiletto_blackpearl",display="Stiletto: Blackpearl",rarity="exotic",textureID="16259029052",skinClass="Melees",sa={color="rbxassetid://16259029052",normal="rbxassetid://16259029052",roughness="rbxassetid://16259029052",metalness="rbxassetid://16259029052"}},
			{name="balisong_stiletto_bluegem",display="Stiletto: Bluegem",rarity="exotic",textureID="16259042388",skinClass="Melees",sa={color="rbxassetid://16259042388",normal="rbxassetid://16259042388",roughness="rbxassetid://16259042388",metalness="rbxassetid://16259042388"}},
			{name="balisong_stiletto_damascus",display="Stiletto: Damascus",rarity="exotic",textureID="16259055593",skinClass="Melees",sa={color="rbxassetid://16259055593",normal="rbxassetid://16259055593",roughness="rbxassetid://16259055593",metalness="rbxassetid://16259055593"}},
			{name="balisong_stiletto_emerald",display="Stiletto: Emerald",rarity="exotic",textureID="16302919829",skinClass="Melees",sa={color="rbxassetid://16302919829",normal="rbxassetid://16302919829",roughness="rbxassetid://16302919829",metalness="rbxassetid://16302919829"}},
			{name="balisong_stiletto_forest",display="Stiletto: Forest",rarity="exotic",textureID="16259072166",skinClass="Melees",sa={color="rbxassetid://16259072166",normal="rbxassetid://16259072166",roughness="rbxassetid://16259072166",metalness="rbxassetid://16259072166"}},
			{name="balisong_stiletto_olivedrift",display="Stiletto: Olivedrift",rarity="exotic",textureID="16259085913",skinClass="Melees",sa={color="rbxassetid://16259085913",normal="rbxassetid://16259085913",roughness="rbxassetid://16259085913",metalness="rbxassetid://16259085913"}},
			{name="balisong_stiletto_rustic",display="Stiletto: Rustic",rarity="exotic",textureID="16259093221",skinClass="Melees",sa={color="rbxassetid://16259093221",normal="rbxassetid://16259093221",roughness="rbxassetid://16259093221",metalness="rbxassetid://16259093221"}},
			{name="balisong_stiletto_vanilla",display="Stiletto: Vanilla",rarity="exotic",textureID="16259021346",skinClass="Melees",sa={color="rbxassetid://16259021346",normal="rbxassetid://16259021346",roughness="rbxassetid://16259021346",metalness="rbxassetid://16259021346"}},
		},
		["Bat"]={
			{name="bat_bats",display="Bats",rarity="common",textureID="110102460531915",skinClass="Melees",sa={color="rbxassetid://110102460531915",normal="rbxassetid://110102460531915",roughness="rbxassetid://110102460531915",metalness="rbxassetid://110102460531915"}},
			{name="bat_neapolitan",display="Neapolitan",rarity="common",textureID="16688469496",skinClass="Melees",sa={color="rbxassetid://16688469496",normal="rbxassetid://16688469496",roughness="rbxassetid://15028975758",metalness="rbxassetid://16688469496"}},
			{name="bat_testtube",display="Test Tube",rarity="common",textureID="96434260024281",skinClass="Melees",sa={color="rbxassetid://96434260024281",normal="",roughness="",metalness=""}},
			{name="bat_laminate",display="Laminate",rarity="uncommon",textureID="14983660185",skinClass="Melees",sa={color="rbxassetid://14983660185",normal="rbxassetid://14983660185",roughness="rbxassetid://14983660185",metalness="rbxassetid://14983660185"}},
			{name="bat_cosmic",display="Cosmic",rarity="rare",textureID="15445293206",skinClass="Melees",sa={color="rbxassetid://15445293206",normal="rbxassetid://15445293206",roughness="rbxassetid://15445293206",metalness="rbxassetid://15445293206"}},
			{name="bat_blackjack",display="Blackjack",rarity="legendary",textureID="16687987095",skinClass="Melees",sa={color="rbxassetid://16687987095",normal="rbxassetid://16687987095",roughness="rbxassetid://16687987095",metalness="rbxassetid://16687987095"}},
			{name="bat_cricket_blackpearl",display="Cricket: Blackpearl",rarity="exotic",textureID="15449155266",skinClass="Melees",sa={color="rbxassetid://15449155266",normal="rbxassetid://15449155266",roughness="rbxassetid://15449155266",metalness="rbxassetid://15449155266"}},
			{name="bat_cricket_bluegem",display="Cricket: Bluegem",rarity="exotic",textureID="15449171966",skinClass="Melees",sa={color="rbxassetid://15449171966",normal="rbxassetid://15449171966",roughness="rbxassetid://15449171966",metalness="rbxassetid://15449171966"}},
			{name="bat_cricket_damascus",display="Cricket: Damascus",rarity="exotic",textureID="15449190167",skinClass="Melees",sa={color="rbxassetid://15449190167",normal="rbxassetid://15449190167",roughness="rbxassetid://15449190167",metalness="rbxassetid://15449190167"}},
			{name="bat_cricket_emerald",display="Cricket: Emerald",rarity="exotic",textureID="15449096192",skinClass="Melees",sa={color="rbxassetid://15449096192",normal="rbxassetid://15449096192",roughness="rbxassetid://15449096192",metalness="rbxassetid://15449096192"}},
			{name="bat_cricket_forest",display="Cricket: Forest",rarity="exotic",textureID="15449106139",skinClass="Melees",sa={color="rbxassetid://15449106139",normal="rbxassetid://15449106139",roughness="rbxassetid://15449106139",metalness="rbxassetid://15449106139"}},
			{name="bat_cricket_olivedrift",display="Cricket: Olivedrift",rarity="exotic",textureID="15449137460",skinClass="Melees",sa={color="rbxassetid://15449137460",normal="rbxassetid://15449137460",roughness="rbxassetid://15449137460",metalness="rbxassetid://15449137460"}},
			{name="bat_cricket_rustic",display="Cricket: Rustic",rarity="exotic",textureID="15449148208",skinClass="Melees",sa={color="rbxassetid://15449148208",normal="rbxassetid://15449148208",roughness="rbxassetid://15449148208",metalness="rbxassetid://15449148208"}},
			{name="bat_cricket_vanilla",display="Cricket: Vanilla",rarity="exotic",textureID="15449203020",skinClass="Melees",sa={color="rbxassetid://15449203020",normal="rbxassetid://15449203020",roughness="rbxassetid://15449203020",metalness="rbxassetid://15449203020"}},
			{name="bat_cashcane",display="Cash Cane",rarity="limited",textureID="15998559023",skinClass="Guns",sa={color="rbxassetid://16300595972",normal="rbxassetid://16299761577",roughness="rbxassetid://16300595459",metalness="rbxassetid://16299760247"}},
		},
		["Bayonet"]={
			{name="bayonet_stonecut",display="Stonecit",rarity="subcommon",textureID="95862205225241",skinClass="Melees",sa={color="rbxassetid://95862205225241",normal="",roughness="",metalness=""}},
			{name="bayonet_paintsplatter",display="Paint Splatter",rarity="common",textureID="15710701683",skinClass="Melees",sa={color="rbxassetid://15710701683",normal="rbxassetid://15710701683",roughness="rbxassetid://15710701683",metalness="rbxassetid://15710701683"}},
			{name="bayonet_redtopo",display="Red Topo",rarity="common",textureID="14982984551",skinClass="Melees",sa={color="rbxassetid://14982984551",normal="rbxassetid://14982987123",roughness="rbxassetid://14982988058",metalness="rbxassetid://14982986074"}},
			{name="bayonet_fangs",display="Fangs",rarity="uncommon",textureID="14983866000",skinClass="Melees",sa={color="rbxassetid://14983866000",normal="rbxassetid://14982987123",roughness="rbxassetid://14982988058",metalness="rbxassetid://14982986074"}},
			{name="bayonet_hydrographed",display="Hydrographed",rarity="uncommon",textureID="16688339293",skinClass="Melees",sa={color="rbxassetid://16688338006",normal="rbxassetid://16688340298",roughness="rbxassetid://16688341008",metalness="rbxassetid://16688338406"}},
			{name="bayonet_violet",display="Violet",rarity="uncommon",textureID="15448020909",skinClass="Melees",sa={color="rbxassetid://15448020909",normal="rbxassetid://15448020909",roughness="rbxassetid://15448020909",metalness="rbxassetid://15448020909"}},
			{name="bayonet_icicle",display="Bayonet Icicle",rarity="limited",textureID="17778081372",skinClass="Melees",sa=nil},
		},
		["Beretta"]={
			{name="beretta_faded",display="Faded Orchid",rarity="subcommon",textureID="118073188574202",skinClass="Guns",sa={color="rbxassetid://118073188574202",normal="",roughness="",metalness=""}},
			{name="beretta_moss",display="Moss",rarity="common",textureID="13443011965",skinClass="Guns",sa={color="rbxassetid://13443011965",normal="rbxassetid://13388061241",roughness="rbxassetid://13388062020",metalness="rbxassetid://13388060473"}},
			{name="beretta_silvered",display="Silvered",rarity="common",textureID="15998401350",skinClass="Guns",sa={color="rbxassetid://15998401350",normal="rbxassetid://15998401350",roughness="rbxassetid://15998401350",metalness="rbxassetid://15998401350"}},
			{name="beretta_urbanred",display="Urban Red",rarity="common",textureID="13841598427",skinClass="Guns",sa={color="rbxassetid://13841595045",normal="rbxassetid://13841596345",roughness="rbxassetid://13841597360",metalness="rbxassetid://13841595733"}},
			{name="beretta_vampire",display="Vampire Hunter",rarity="common",textureID="110118886587312",skinClass="Guns",sa={color="rbxassetid://110118886587312",normal="rbxassetid://110118886587312",roughness="rbxassetid://110118886587312",metalness="rbxassetid://110118886587312"}},
			{name="beretta_wooden",display="Wooden Blaster",rarity="common",textureID="15695415641",skinClass="Guns",sa={color="rbxassetid://15695411633",normal="rbxassetid://15695410939",roughness="rbxassetid://15695410486",metalness="rbxassetid://15695411201"}},
			{name="beretta_clef",display="Clef",rarity="uncommon",textureID="13387793497",skinClass="Guns",sa={color="rbxassetid://13387587315",normal="rbxassetid://13387589539",roughness="rbxassetid://13387590166",metalness="rbxassetid://13387588930"}},
			{name="beretta_tiger",display="Tiger",rarity="uncommon",textureID="13704090301",skinClass="Guns",sa={color="rbxassetid://13704088639",normal="rbxassetid://13387589539",roughness="rbxassetid://13387590166",metalness="rbxassetid://13387588930"}},
			{name="beretta_walker",display="Walker",rarity="uncommon",textureID="15177179442",skinClass="Guns",sa={color="rbxassetid://15177179442",normal="rbxassetid://15177179442",roughness="rbxassetid://15177179442",metalness="rbxassetid://15177179442"}},
			{name="beretta_gold",display="Golden Beretta",rarity="limited",textureID="15039167103",skinClass="Guns",sa={color="rbxassetid://15071881699",normal="rbxassetid://15071881251",roughness="rbxassetid://15071880826",metalness="rbxassetid://15071881490",customColor={145,127,175}}},
			{name="beretta_gold",display="Golden Beretta",rarity="limited",textureID="15039167103",skinClass="Guns",sa={color="rbxassetid://15071881699",normal="rbxassetid://15071881251",roughness="rbxassetid://15071880826",metalness="rbxassetid://15071881490",customColor={145,127,175}}},
		},
		["Chainsaw"]={
			{name="chainsaw_flesh",display="Flesh Grinder",rarity="common",textureID="84720894767609",skinClass="Melees",sa={color="rbxassetid://84720894767609",normal="",roughness="",metalness=""}},
			{name="chainsaw_tealcoat",display="Teal Coat",rarity="common",textureID="14983382088",skinClass="Melees",sa={color="rbxassetid://14983382088",normal="rbxassetid://14983382088",roughness="rbxassetid://14983382088",metalness="rbxassetid://14983382088"}},
			{name="chainsaw_skullforged",display="Skull Forged",rarity="uncommon",textureID="15445199244",skinClass="Melees",sa={color="rbxassetid://15445199244",normal="rbxassetid://15445199244",roughness="rbxassetid://15445199244",metalness="rbxassetid://15445199244"}},
			{name="chainsaw_chromatic",display="Chromatic",rarity="rare",textureID="16688110086",skinClass="Melees",sa={color="rbxassetid://16688109289",normal="rbxassetid://16688110436",roughness="rbxassetid://16688110086",metalness="rbxassetid://16688109691"}},
			{name="chainsaw_frostysrevenge",display="Frosty's Revenge",rarity="rare",textureID="108135882535629",skinClass="Melees",sa={color="rbxassetid://108135882535629",normal="",roughness="",metalness=""}},
			{name="chainsaw_runic",display="Runic",rarity="legendary",textureID="124391413731378",skinClass="Melees",sa={color="rbxassetid://124391413731378",normal="rbxassetid://80321921079422",roughness="rbxassetid://129961044112883",metalness="rbxassetid://124391413731378"}},
			{name="chainsaw_rip",display="RIPPER",rarity="limited",textureID="15177796575",skinClass="Melees",sa={color="rbxassetid://15177794155",normal="rbxassetid://15177357891",roughness="rbxassetid://15177358508",metalness="rbxassetid://15177357345"}},
		},
		["Crowbar"]={
			{name="crowbar_cobalt",display="Cobalt",rarity="common",textureID="14982777465",skinClass="Melees",sa={color="rbxassetid://14982777465",normal="rbxassetid://8999009362",roughness="rbxassetid://8999009938",metalness="rbxassetid://8999008742"}},
			{name="crowbar_cobalt",display="Cobalt Pry",rarity="common",textureID="14982777465",skinClass="Melees",sa={color="rbxassetid://14982777465",normal="rbxassetid://8999009362",roughness="rbxassetid://8999009938",metalness="rbxassetid://8999008742"}},
			{name="crowbar_hazardous",display="Hazardous",rarity="uncommon",textureID="16688168392",skinClass="Melees",sa={color="rbxassetid://16688167039",normal="rbxassetid://16688167807",roughness="rbxassetid://16688168882",metalness="rbxassetid://16688166309"}},
		},
		["Deagle"]={
			{name="deagle_acrylic",display="Acrylic",rarity="common",textureID="13714051745",skinClass="Guns",sa={color="rbxassetid://13714048705",normal="rbxassetid://13567912487",roughness="rbxassetid://13567913639",metalness="rbxassetid://13567909944"}},
			{name="deagle_gingerbread",display="Gingerbread",rarity="uncommon",textureID="15695335671",skinClass="Guns",sa={color="rbxassetid://15695335671",normal="rbxassetid://15695335671",roughness="rbxassetid://15695335671",metalness="rbxassetid://15695335671"}},
			{name="deagle_aurora",display="Aurora",rarity="rare",textureID="113122788396408",skinClass="Guns",sa={color="rbxassetid://113122788396408",normal="",roughness="",metalness=""}},
			{name="deagle_eagleeye",display="Eagle Eye",rarity="rare",textureID="13937649183",skinClass="Guns",sa={color="rbxassetid://13937646988",normal="rbxassetid://13935410021",roughness="rbxassetid://13935410676",metalness="rbxassetid://13937635046"}},
			{name="deagle_ember",display="Ember",rarity="rare",textureID="16041800350",skinClass="Guns",sa={color="rbxassetid://16041800350",normal="rbxassetid://16041800350",roughness="rbxassetid://16041800350",metalness="rbxassetid://16041800350"}},
			{name="deagle_plasma",display="Plasma",rarity="rare",textureID="13567917232",skinClass="Guns",sa={color="rbxassetid://13567908266",normal="rbxassetid://13567912487",roughness="rbxassetid://13567913639",metalness="rbxassetid://13567909944"}},
			{name="deagle_presidential",display="Presidential",rarity="rare",textureID="18198670122",skinClass="Guns",sa={color="rbxassetid://18198670122",normal="rbxassetid://18198670122",roughness="rbxassetid://18198670122",metalness="rbxassetid://18198670122"}},
			{name="deagle_federation",display="Federation",rarity="legendary",textureID="13841715646",skinClass="Guns",sa={color="rbxassetid://13841710519",normal="rbxassetid://13841679919",roughness="rbxassetid://13841712407",metalness="rbxassetid://13841679235"}},
			{name="deagle_nacho",display="Nacho",rarity="legendary",textureID="16942393059",skinClass="Guns",sa={color="rbxassetid://16942392011",normal="rbxassetid://16942393650",roughness="rbxassetid://16942394043",metalness="rbxassetid://16942392549"}},
			{name="deagle_reaper",display="Reaper",rarity="legendary",textureID="72301183330195",skinClass="Guns",sa={color="rbxassetid://72301183330195",normal="rbxassetid://8969351301",roughness="rbxassetid://8969352384",metalness="rbxassetid://8969349955"}},
			{name="deagle_gold",display="Golden Deagle",rarity="limited",textureID="9422471620",skinClass="Guns",sa={color="rbxassetid://9422465914",normal="rbxassetid://9368506864",roughness="rbxassetid://9422469052",metalness="rbxassetid://9422467019",customColor={145,127,175}}},
			{name="deagle_modern",display="Modern",rarity="limited",textureID="11934375653",skinClass="Guns",sa={color="rbxassetid://11934375653",normal="rbxassetid://11934385269",roughness="rbxassetid://11934387175",metalness="rbxassetid://11934381207"}},
			{name="deagle_omori",display="OMORI",rarity="limited",textureID="136460482192003",skinClass="Guns",sa={color="rbxassetid://136460482192003",normal="rbxassetid://136460482192003",roughness="rbxassetid://136460482192003",metalness="rbxassetid://136460482192003",customColor={145,127,175}}},
		},
		["FN-FAL"]={
			{name="fal_merlot",display="Merlot",rarity="common",textureID="13566086660",skinClass="Guns",sa={color="rbxassetid://13566072355",normal="rbxassetid://13566075780",roughness="rbxassetid://13566082947",metalness="rbxassetid://13566073596"}},
			{name="fal_wintermaroon",display="Winter Maroon",rarity="common",textureID="15710689660",skinClass="Guns",sa={color="rbxassetid://15710689660",normal="rbxassetid://15710689660",roughness="rbxassetid://15710689660",metalness="rbxassetid://15710689660"}},
			{name="fal_purpleheart",display="Purpleheart",rarity="uncommon",textureID="16040566709",skinClass="Guns",sa={color="rbxassetid://16040566709",normal="rbxassetid://16040566709",roughness="rbxassetid://16040566709",metalness="rbxassetid://16040566709"}},
			{name="fal_majesty",display="Majesty",rarity="rare",textureID="13343296728",skinClass="Guns",sa={color="rbxassetid://12268008265",normal="rbxassetid://12267979962",roughness="rbxassetid://12267980974",metalness="rbxassetid://12267979022"}},
		},
		["FNP-45"]={
			{name="fnp_tan",display="Tan",rarity="common",textureID="15998535930",skinClass="Guns",sa={color="rbxassetid://15998535930",normal="rbxassetid://15998535930",roughness="rbxassetid://15998535930",metalness="rbxassetid://15998535930"}},
			{name="fnp_bloodshot",display="Bloodshot",rarity="uncommon",textureID="13566144332",skinClass="Guns",sa={color="rbxassetid://13566118019",normal="rbxassetid://13566120150",roughness="rbxassetid://13566128289",metalness="rbxassetid://13566119175"}},
			{name="fnp_pulse",display="Pulse",rarity="uncommon",textureID="16355357985",skinClass="Guns",sa={color="rbxassetid://9170832779",normal="rbxassetid://9170834197",roughness="rbxassetid://9170835896",metalness="rbxassetid://9170833562"}},
		},
		["Fire-Axe"]={
			{name="fireaxe_07gift",display="07 Gift",rarity="common",textureID="15695434311",skinClass="Melees",sa={color="rbxassetid://15695429682",normal="rbxassetid://15695429360",roughness="rbxassetid://15695428821",metalness="rbxassetid://15695429036"}},
			{name="fireaxe_oak",display="Oak",rarity="common",textureID="14983489673",skinClass="Melees",sa={color="rbxassetid://14983489673",normal="rbxassetid://14983489673",roughness="rbxassetid://14983489673",metalness="rbxassetid://14983489673"}},
			{name="fireaxe_axon",display="Axon",rarity="uncommon",textureID="16688204992",skinClass="Melees",sa={color="rbxassetid://16688204062",normal="rbxassetid://16688205447",roughness="rbxassetid://16688206001",metalness="rbxassetid://16688204499"}},
			{name="fireaxe_candied",display="Candied Axe",rarity="uncommon",textureID="130251013763185",skinClass="Melees",sa={color="rbxassetid://130251013763185",normal="rbxassetid://130251013763185",roughness="rbxassetid://130251013763185",metalness="rbxassetid://130251013763185"}},
			{name="fireaxe_jaws",display="Jaws",rarity="uncommon",textureID="15450295670",skinClass="Melees",sa={color="rbxassetid://15450295670",normal="rbxassetid://15450295670",roughness="rbxassetid://15450295670",metalness="rbxassetid://15450295670"}},
			{name="fireaxe_bio",display="Bio-Tool",rarity="rare",textureID="122222905147597",skinClass="Melees",sa={color="rbxassetid://122222905147597",normal="",roughness="",metalness=""}},
			{name="fireaxe_diesel",display="Diesel",rarity="rare",textureID="15014648272",skinClass="Melees",sa={color="rbxassetid://15014648272",normal="rbxassetid://15014647691",roughness="rbxassetid://15014647556",metalness="rbxassetid://15014640798"}},
			{name="fireaxe_xo",display="XO",rarity="rare",textureID="16357722686",skinClass="Melees",sa={color="rbxassetid://16357722686",normal="rbxassetid://16357722686",roughness="rbxassetid://16357722686",metalness="rbxassetid://16357722686"}},
			{name="fireaxe_tactical_blackpearl",display="Tactical: Blackpearl",rarity="exotic",textureID="15448222326",skinClass="Melees",sa={color="rbxassetid://15448222326",normal="rbxassetid://15448222326",roughness="rbxassetid://15448222326",metalness="rbxassetid://15448222326"}},
			{name="fireaxe_tactical_bluegem",display="Tactical: Bluegem",rarity="exotic",textureID="15039861739",skinClass="Melees",sa={color="rbxassetid://15039861739",normal="rbxassetid://15039861739",roughness="rbxassetid://15039861739",metalness="rbxassetid://15039861739"}},
			{name="fireaxe_tactical_damascus",display="Tactical: Damascus",rarity="exotic",textureID="15039856279",skinClass="Melees",sa={color="rbxassetid://15039856279",normal="rbxassetid://15039856279",roughness="rbxassetid://15039856279",metalness="rbxassetid://15039856279"}},
			{name="fireaxe_tactical_emerald",display="Tactical: Emerald",rarity="exotic",textureID="15448202220",skinClass="Melees",sa={color="rbxassetid://15448202220",normal="rbxassetid://15448202220",roughness="rbxassetid://15448202220",metalness="rbxassetid://15448202220"}},
			{name="fireaxe_tactical_forest",display="Tactical: Forest",rarity="exotic",textureID="15039850470",skinClass="Melees",sa={color="rbxassetid://15039850470",normal="rbxassetid://15039850470",roughness="rbxassetid://15039850470",metalness="rbxassetid://15039850470"}},
			{name="fireaxe_tactical_kintsugi",display="Tactical: Kintsugi",rarity="exotic",textureID="15039866167",skinClass="Melees",sa={color="rbxassetid://15039866167",normal="rbxassetid://15039866167",roughness="rbxassetid://15039866167",metalness="rbxassetid://15039866167"}},
			{name="fireaxe_tactical_olivedrift",display="Tactical: Olivedrift",rarity="exotic",textureID="15070266784",skinClass="Melees",sa={color="rbxassetid://15070266784",normal="rbxassetid://15070266784",roughness="rbxassetid://15070266784",metalness="rbxassetid://15070266784"}},
			{name="fireaxe_tactical_rustic",display="Tactical: Rustic",rarity="exotic",textureID="15039869342",skinClass="Melees",sa={color="rbxassetid://15039869342",normal="rbxassetid://15039869342",roughness="rbxassetid://15039869342",metalness="rbxassetid://15039869342"}},
			{name="fireaxe_tactical_vanilla",display="Tactical: Vanilla",rarity="exotic",textureID="14984257142",skinClass="Melees",sa={color="rbxassetid://14984257142",normal="rbxassetid://14984257142",roughness="rbxassetid://14984257142",metalness="rbxassetid://14984257142"}},
		},
		["G-17"]={
			{name="g17_benjamin",display="Benjamin",rarity="common",textureID="18198687338",skinClass="Guns",sa={color="rbxassetid://18198687338",normal="rbxassetid://18198687338",roughness="rbxassetid://18198687338",metalness="rbxassetid://18198687338"}},
			{name="g17_gleagle",display="Gleagle",rarity="common",textureID="16911006388",skinClass="Guns",sa={color="rbxassetid://16911005097",normal="rbxassetid://16911007007",roughness="rbxassetid://16911007567",metalness="rbxassetid://16911005667"}},
			{name="g17_night",display="Night",rarity="common",textureID="10899181873",skinClass="Guns",sa={color="rbxassetid://10899178487",normal="rbxassetid://10899190543",roughness="rbxassetid://10899191886",metalness="rbxassetid://10899187519",customColor={104,117,121},customParts={"FrontSightColorPart","RearSightColorPart"}}},
			{name="g17_sage",display="Sage",rarity="common",textureID="10898774042",skinClass="Guns",sa={color="rbxassetid://10898771076",normal="rbxassetid://10898799572",roughness="rbxassetid://10898801144",metalness="rbxassetid://10898797751",customColor={116,121,98},customParts={"FrontSightColorPart","RearSightColorPart"}}},
			{name="g17_tan",display="Tan",rarity="common",textureID="13841573907",skinClass="Guns",sa={color="rbxassetid://13841571102",normal="rbxassetid://13841572406",roughness="rbxassetid://13841572919",metalness="rbxassetid://13841571957",customColor={121,108,98},customParts={"FrontSightColorPart","RearSightColorPart"}}},
			{name="g17_photon",display="Photon",rarity="uncommon",textureID="94317587382863",skinClass="Guns",sa={color="rbxassetid://94317587382863",normal="",roughness="",metalness=""}},
			{name="g17_warhawk",display="Spitfire",rarity="uncommon",textureID="10898479150",skinClass="Guns",sa={color="rbxassetid://10898489161",normal="rbxassetid://10898493545",roughness="rbxassetid://10898494181",metalness="rbxassetid://10898492739",customColor={197,189,106},customParts={"FrontSightColorPart","RearSightColorPart"}}},
			{name="g17_crunch",display="CRUNCH",rarity="rare",textureID="136064273359037",skinClass="Guns",sa={color="rbxassetid://136064273359037",normal="rbxassetid://136064273359037",roughness="rbxassetid://136064273359037",metalness="rbxassetid://136064273359037"}},
			{name="g17_oxide",display="Oxide",rarity="rare",textureID="13556396197",skinClass="Guns",sa={color="rbxassetid://13556385916",normal="rbxassetid://13556387454",roughness="rbxassetid://13556388249",metalness="rbxassetid://13556386783",customColor={145,190,197},customParts={"FrontSightColorPart","RearSightColorPart"}}},
			{name="g17_yosei",display="Yōsei",rarity="rare",textureID="15707661222",skinClass="Guns",sa={color="rbxassetid://15707661222",normal="rbxassetid://15707661222",roughness="rbxassetid://15707661222",metalness="rbxassetid://15707661222"}},
			{name="g17_amethyst",display="Amethyst",rarity="legendary",textureID="9344560860",skinClass="Guns",sa={color="rbxassetid://9344554991",normal="rbxassetid://9344557259",roughness="rbxassetid://9344558040",metalness="rbxassetid://9344556621",customColor={121,113,163},customParts={"FrontSightColorPart","RearSightColorPart"}}},
			{name="g17_hotpink",display="Hot Pink",rarity="legendary",textureID="15998559023",skinClass="Guns",sa={color="rbxassetid://15998559023",normal="rbxassetid://15998559023",roughness="rbxassetid://15998559023",metalness="rbxassetid://15998559023"}},
			{name="g17_eliminated",display="ELIMINATION",rarity="limited",textureID="94164067871562",skinClass="Guns",sa={color="rbxassetid://94164067871562",normal="rbxassetid://75074216652378",roughness="rbxassetid://112379003610843",metalness="rbxassetid://133337669834230",customColor={17,17,17}}},
			{name="g17_sigma",display="Sigma",rarity="custom",textureID="17861230617",skinClass="Guns",sa={color="rbxassetid://17861230617",normal="rbxassetid://17861230617",roughness="rbxassetid://17861230617",metalness="rbxassetid://17861230617",customColor={229,134,255},customParts={"FrontSightColorPart","RearSightColorPart"}}},
		},
		["Golfclub"]={
			{name="golfclub_mocha",display="Mocha",rarity="common",textureID="15445223443",skinClass="Melees",sa={color="rbxassetid://15445223443",normal="rbxassetid://15445223443",roughness="rbxassetid://15445223443",metalness="rbxassetid://15445223443"}},
			{name="golfclub_orangeshift",display="Orange Shift",rarity="uncommon",textureID="14983545106",skinClass="Melees",sa={color="rbxassetid://14983545106",normal="rbxassetid://14983550867",roughness="rbxassetid://14983551891",metalness="rbxassetid://14983549891"}},
		},
		["Ithaca-37"]={
			{name="ithaca_lined",display="Lined Legacy",rarity="subcommon",textureID="13388406520",skinClass="Guns",sa={color="rbxassetid://13388406520",normal="",roughness="",metalness=""}},
			{name="ithaca_homedefense",display="Home Defense",rarity="common",textureID="13935300358",skinClass="Guns",sa={color="rbxassetid://13935302367",normal="rbxassetid://13935306192",roughness="rbxassetid://13935303200",metalness="rbxassetid://13935310687"}},
			{name="ithaca_ithcuh",display="Ithcuh",rarity="common",textureID="16910987164",skinClass="Guns",sa={color="rbxassetid://16910986091",normal="rbxassetid://16910987518",roughness="rbxassetid://16910987829",metalness="rbxassetid://16910986411"}},
			{name="ithaca_peppershot",display="Peppershot",rarity="uncommon",textureID="109757276465431",skinClass="Guns",sa={color="rbxassetid://109757276465431",normal="",roughness="",metalness=""}},
			{name="ithaca_reserve",display="Reserve",rarity="uncommon",textureID="13841786305",skinClass="Guns",sa={color="rbxassetid://13841781874",normal="rbxassetid://13565563166",roughness="rbxassetid://13565564605",metalness="rbxassetid://13565561573"}},
			{name="ithaca_sightings",display="Sightings",rarity="uncommon",textureID="15183702458",skinClass="Guns",sa=nil},
			{name="ithaca_blaze",display="Blaze",rarity="rare",textureID="13715287969",skinClass="Guns",sa={color="rbxassetid://13703922904",normal="rbxassetid://13703924503",roughness="rbxassetid://13703925013",metalness="rbxassetid://13703923500"}},
			{name="ithaca_darkmatter",display="Darkmatter",rarity="rare",textureID="15998588320",skinClass="Guns",sa={color="rbxassetid://15998588320",normal="rbxassetid://15998588320",roughness="rbxassetid://15998588320",metalness="rbxassetid://15998588320"}},
			{name="ithaca_hellfire",display="HELLFIRE",rarity="limited",textureID="88337624827127",skinClass="Guns",sa={color="rbxassetid://120094510362818",normal="rbxassetid://89491017367979",roughness="rbxassetid://131860023245181",metalness="rbxassetid://113748442311389",customColor={0,0,0}}},
		},
		["Katana"]={
			{name="katana_modest",display="Modest",rarity="common",textureID="15445242510",skinClass="Melees",sa={color="rbxassetid://15445242510",normal="rbxassetid://15445242510",roughness="rbxassetid://15445242510",metalness="rbxassetid://15445242510"}},
			{name="katana_acacia",display="Acacia",rarity="uncommon",textureID="16688145580",skinClass="Melees",sa={color="rbxassetid://16688144837",normal="rbxassetid://16688145997",roughness="rbxassetid://16688146261",metalness="rbxassetid://16688145249"}},
			{name="katana_arctx",display="ARCTX",rarity="rare",textureID="15695443919",skinClass="Melees",sa={color="rbxassetid://15695443919",normal="rbxassetid://15695443919",roughness="rbxassetid://15695443919",metalness="rbxassetid://15695443919"}},
			{name="katana_alchemist",display="Alchemist",rarity="rare",textureID="109290882173174",skinClass="Melees",sa={color="rbxassetid://109290882173174",normal="rbxassetid://109290882173174",roughness="rbxassetid://109290882173174",metalness="rbxassetid://109290882173174"}},
			{name="katana_saphira",display="Saphira",rarity="rare",textureID="14983772470",skinClass="Melees",sa={color="rbxassetid://14983772470",normal="rbxassetid://14983772470",roughness="rbxassetid://14983772470",metalness="rbxassetid://14983772470"}},
			{name="katana_hallowsblade",display="Hallows Blade",rarity="legendary",textureID="15177264050",skinClass="Melees",sa={color="rbxassetid://15177264050",normal="rbxassetid://15177264050",roughness="rbxassetid://15177264050",metalness="rbxassetid://15177264050"}},
			{name="katana_yuletide",display="Yuletide",rarity="legendary",textureID="78387945331940",skinClass="Melees",sa={color="rbxassetid://78387945331940",normal="",roughness="",metalness=""}},
			{name="katana_dragon",display="Dragon",rarity="limited",textureID="17519365000",skinClass="Melees",sa=nil},
			{name="katana_gold",display="Golden Katana",rarity="limited",textureID="15012855048",skinClass="Melees",sa={color="rbxassetid://15012855048",normal="rbxassetid://15012854439",roughness="rbxassetid://15012854262",metalness="rbxassetid://15012854848"}},
			{name="katana_gold",display="Golden Katana",rarity="limited",textureID="15012855048",skinClass="Melees",sa={color="rbxassetid://15012855048",normal="rbxassetid://15012854439",roughness="rbxassetid://15012854262",metalness="rbxassetid://15012854848"}},
			{name="katana_voidedge",display="Voidedge",rarity="limited",textureID="15653919187",skinClass="Melees",sa={color="rbxassetid://15012855048",normal="rbxassetid://15012854439",roughness="rbxassetid://15012854262",metalness="rbxassetid://15012854848"}},
			{name="katana_voidedge",display="Voidedge",rarity="limited",textureID="15653919187",skinClass="Melees",sa={color="rbxassetid://15012855048",normal="rbxassetid://15012854439",roughness="rbxassetid://15012854262",metalness="rbxassetid://15012854848"}},
		},
		["M1911"]={
			{name="1911_ironsight",display="Ironsight",rarity="common",textureID="13388235569",skinClass="Guns",sa={color="rbxassetid://13388236414",normal="rbxassetid://13388219329",roughness="rbxassetid://13388219893",metalness="rbxassetid://13388218612"}},
			{name="1911_sandwaves",display="Sandwaves",rarity="common",textureID="15998637813",skinClass="Guns",sa={color="rbxassetid://15998637813",normal="rbxassetid://15998637813",roughness="rbxassetid://15998637813",metalness="rbxassetid://15998637813"}},
			{name="1911_stainless",display="Stainless",rarity="uncommon",textureID="13842570127",skinClass="Guns",sa={color="rbxassetid://13842569053",normal="rbxassetid://13841646259",roughness="rbxassetid://13841646833",metalness="rbxassetid://13841645564"}},
			{name="1911_lunar",display="Lunar",rarity="rare",textureID="128273297919691",skinClass="Guns",sa={color="rbxassetid://128273297919691",normal="",roughness="",metalness=""}},
			{name="1911_rebel",display="Rebel",rarity="rare",textureID="13410200181",skinClass="Guns",sa={color="rbxassetid://13410196884",normal="rbxassetid://13410197562",roughness="rbxassetid://13410199143",metalness="rbxassetid://13410198420"}},
			{name="1911_darkheart",display="Darkheart",rarity="legendary",textureID="13556210238",skinClass="Guns",sa={color="rbxassetid://13564716720",normal="rbxassetid://13564718375",roughness="rbxassetid://13564719235",metalness="rbxassetid://13564717513"}},
			{name="1911_unity",display="Unity",rarity="legendary",textureID="18149758418",skinClass="Guns",sa={color="rbxassetid://18149758418",normal="rbxassetid://18149758418",roughness="rbxassetid://18149758418",metalness="rbxassetid://18149758418"}},
			{name="1911_oldglory",display="Old Glory",rarity="limited",textureID="13948809897",skinClass="Guns",sa={color="rbxassetid://13948805827",normal="rbxassetid://13948291596",roughness="rbxassetid://13948321939",metalness="rbxassetid://13948290980",customColor={145,127,175}}},
			{name="1911_oldglory",display="Old Glory",rarity="limited",textureID="13948809897",skinClass="Guns",sa={color="rbxassetid://13948805827",normal="rbxassetid://13948291596",roughness="rbxassetid://13948321939",metalness="rbxassetid://13948290980",customColor={145,127,175}}},
		},
		["M320-1"]={
			{name="m320_paintball",display="Paintball",rarity="uncommon",textureID="13842616391",skinClass="Guns",sa={color="rbxassetid://13842613980",normal="rbxassetid://13841618026",roughness="rbxassetid://13841618889",metalness="rbxassetid://13841616724"}},
		},
		["M4A1-1"]={
			{name="m4a1_monochrome",display="Monochrome",rarity="common",textureID="13388680352",skinClass="Guns",sa={color="rbxassetid://13388682540",normal="rbxassetid://13388684117",roughness="rbxassetid://13388684783",metalness="rbxassetid://13388683605"}},
			{name="m4a1_colacamo",display="Cola-Camo",rarity="uncommon",textureID="16910928732",skinClass="Guns",sa={color="rbxassetid://16910927803",normal="rbxassetid://16910929076",roughness="rbxassetid://16910929618",metalness="rbxassetid://16910928172"}},
			{name="m4a1_tiles",display="Tiles",rarity="uncommon",textureID="13387863271",skinClass="Guns",sa={color="rbxassetid://13387870685",normal="rbxassetid://13387874528",roughness="rbxassetid://13387875337",metalness="rbxassetid://13387873917"}},
			{name="m4a1_yellowstone",display="Yellowstone",rarity="uncommon",textureID="15998612264",skinClass="Guns",sa={color="rbxassetid://15998612264",normal="rbxassetid://15998612264",roughness="rbxassetid://15998612264",metalness="rbxassetid://15998612264"}},
			{name="m4a1_circuit",display="Circuit",rarity="rare",textureID="13841653101",skinClass="Guns",sa={color="rbxassetid://13841654362",normal="rbxassetid://13841656305",roughness="rbxassetid://13841657147",metalness="rbxassetid://13841655173"}},
			{name="m4a1_aureus",display="Aureus",rarity="legendary",textureID="13714597872",skinClass="Guns",sa={color="rbxassetid://13714578814",normal="rbxassetid://13714331534",roughness="rbxassetid://13714329843",metalness="rbxassetid://13714330861"}},
			{name="m4a1_frostbite",display="Frostbite",rarity="legendary",textureID="15695458963",skinClass="Guns",sa={color="rbxassetid://15695458963",normal="rbxassetid://15695458963",roughness="rbxassetid://15695458963",metalness="rbxassetid://15695458963"}},
			{name="m4a1_meltdown",display="Meltdown",rarity="legendary",textureID="105367863967017",skinClass="Guns",sa={color="rbxassetid://105367863967017",normal="",roughness="",metalness=""}},
			{name="m4a1_patriot",display="Patriot",rarity="legendary",textureID="13945992974",skinClass="Guns",sa={color="rbxassetid://13945985275",normal="rbxassetid://13945989865",roughness="rbxassetid://13945990897",metalness="rbxassetid://13945986111"}},
			{name="m4a1_heritage",display="Heritage",rarity="limited",textureID="18312055711",skinClass="Guns",sa={color="rbxassetid://18312055711",normal="rbxassetid://18312051579",roughness="rbxassetid://18312059297",metalness="rbxassetid://18312051579"}},
			{name="m4a1_modern",display="Modern",rarity="limited",textureID="8371778205",skinClass="Guns",sa={color="rbxassetid://8371778205",normal="rbxassetid://8371775875",roughness="",metalness=""}},
			{name="m4a1_opm",display="OPM",rarity="limited",textureID="16932839206",skinClass="Guns",sa={color="rbxassetid://16932838705",normal="rbxassetid://16932839768",roughness="rbxassetid://16932840076",metalness="rbxassetid://16932838927",customColor={8,2,27}}},
			{name="m4a1_subzero",display="Subzero",rarity="limited",textureID="109664302456309",skinClass="Guns",sa={color="rbxassetid://74488290583882",normal="rbxassetid://135293141470993",roughness="rbxassetid://132524427491436",metalness="rbxassetid://118937932788409",customColor={165,235,255}}},
		},
		["M60"]={
			{name="m60_woodsplitter",display="Woodsplitter",rarity="subcommon",textureID="108644929135165",skinClass="Guns",sa={color="rbxassetid://108644929135165",normal="",roughness="",metalness=""}},
		},
		["MAC-10"]={
			{name="mac10_freedom",display="Freedom",rarity="common",textureID="13935277958",skinClass="Guns",sa={color="rbxassetid://13935272075",normal="rbxassetid://13935274344",roughness="rbxassetid://13935275139",metalness="rbxassetid://13935273127"}},
			{name="mac10_lostnfound",display="Lost & Found",rarity="common",textureID="13841550040",skinClass="Guns",sa={color="rbxassetid://13841544929",normal="rbxassetid://13841547584",roughness="rbxassetid://13841548498",metalness="rbxassetid://13841546059"}},
			{name="mac10_lovelycamo",display="Lovely Camo",rarity="common",textureID="16357659168",skinClass="Guns",sa={color="rbxassetid://16357659168",normal="rbxassetid://16357659168",roughness="rbxassetid://16357659168",metalness="rbxassetid://16357659168"}},
			{name="mac10_urbandispatch",display="Urban Dispatch",rarity="common",textureID="15998655169",skinClass="Guns",sa={color="rbxassetid://15998655169",normal="rbxassetid://15998655169",roughness="rbxassetid://15998655169",metalness="rbxassetid://15998655169"}},
			{name="mac10_cheese",display="& Cheese",rarity="uncommon",textureID="13556186332",skinClass="Guns",sa={color="rbxassetid://13556188816",normal="rbxassetid://13556191703",roughness="rbxassetid://13556192448",metalness="rbxassetid://13556190532"}},
			{name="mac10_digital",display="Digital",rarity="uncommon",textureID="13388146611",skinClass="Guns",sa={color="rbxassetid://13388148081",normal="rbxassetid://13387827028",roughness="rbxassetid://13387824789",metalness="rbxassetid://13387826008"}},
			{name="mac10_eaglespride",display="Eagle's Pride",rarity="uncommon",textureID="18213167058",skinClass="Guns",sa={color="rbxassetid://18213167058",normal="rbxassetid://18213167058",roughness="rbxassetid://18213167058",metalness="rbxassetid://18213167058"}},
			{name="mac10_harvest",display="Harvest",rarity="uncommon",textureID="123346816049088",skinClass="Guns",sa={color="rbxassetid://123346816049088",normal="rbxassetid://8969383524",roughness="rbxassetid://8969384715",metalness="rbxassetid://8969382198"}},
			{name="mac10_hazmac",display="Hazmac",rarity="uncommon",textureID="70974550171047",skinClass="Guns",sa={color="rbxassetid://70974550171047",normal="",roughness="",metalness=""}},
			{name="mac10_cryofox",display="CryoFox",rarity="rare",textureID="133449450385008",skinClass="Guns",sa={color="rbxassetid://133449450385008",normal="",roughness="",metalness=""}},
			{name="mac10_tropical",display="Tropical",rarity="rare",textureID="13712974251",skinClass="Guns",sa={color="rbxassetid://13712964810",normal="rbxassetid://13556191703",roughness="rbxassetid://13712967534",metalness="rbxassetid://13712966361"}},
		},
		["MP7"]={
			{name="mp7_digital",display="Digital",rarity="common",textureID="13703243112",skinClass="Guns",sa={color="rbxassetid://13703243112",normal="rbxassetid://13703243112",roughness="rbxassetid://13703243112",metalness="rbxassetid://13703243112"}},
			{name="mp7_navy",display="Navy",rarity="common",textureID="13714361744",skinClass="Guns",sa={color="rbxassetid://13714362770",normal="rbxassetid://13404160425",roughness="rbxassetid://13404161300",metalness="rbxassetid://13404142924"}},
			{name="mp7_olive",display="Olive",rarity="common",textureID="13404171867",skinClass="Guns",sa={color="rbxassetid://13404159306",normal="rbxassetid://13404160425",roughness="rbxassetid://13404161300",metalness="rbxassetid://13404142924"}},
			{name="mp7_zombified",display="Zombified",rarity="rare",textureID="15334894800",skinClass="Guns",sa=nil},
			{name="mp7_hellrazor",display="Hellrazor",rarity="legendary",textureID="13842806014",skinClass="Guns",sa={color="rbxassetid://13842812065",normal="rbxassetid://13841893577",roughness="rbxassetid://13841894868",metalness="rbxassetid://13841892618"}},
		},
		["Machete"]={
			{name="machete_slasher",display="Slasher",rarity="common",textureID="136864966436069",skinClass="Melees",sa={color="rbxassetid://136864966436069",normal="rbxassetid://136864966436069",roughness="rbxassetid://136864966436069",metalness="rbxassetid://136864966436069"}},
			{name="machete_wallwriter",display="Wallwriter",rarity="common",textureID="16688358515",skinClass="Melees",sa={color="rbxassetid://16688357511",normal="rbxassetid://16688359032",roughness="rbxassetid://16688359499",metalness="rbxassetid://16688357868"}},
			{name="machete_giftededge",display="Gifted Edge",rarity="uncommon",textureID="135651933018967",skinClass="Melees",sa={color="rbxassetid://135651933018967",normal="",roughness="",metalness=""}},
			{name="machete_rainbow",display="Rainbow",rarity="uncommon",textureID="16952073758",skinClass="Melees",sa={color="rbxassetid://16952073307",normal="rbxassetid://16910957239",roughness="rbxassetid://16910956716",metalness="rbxassetid://16910957712"}},
			{name="machete_tix",display="Tix",rarity="rare",textureID="15445249285",skinClass="Melees",sa={color="rbxassetid://15445249285",normal="rbxassetid://15445249285",roughness="rbxassetid://15445249285",metalness="rbxassetid://15445249285"}},
			{name="machete_scepter",display="Scepter",rarity="legendary",textureID="14984201334",skinClass="Melees",sa={color="rbxassetid://14984201334",normal="rbxassetid://14984201334",roughness="rbxassetid://14984201334",metalness="rbxassetid://14984201334"}},
			{name="machete_zk_blackpearl",display="Black Pearl",rarity="exotic",textureID="15448244904",skinClass="Melees",sa={color="rbxassetid://15448244904",normal="rbxassetid://15448244904",roughness="rbxassetid://15448244904",metalness="rbxassetid://15448244904"}},
			{name="machete_zk_blackpearl",display="Black Pearl [ZK]",rarity="exotic",textureID="15448244904",skinClass="Melees",sa={color="rbxassetid://15448244904",normal="rbxassetid://15448244904",roughness="rbxassetid://15448244904",metalness="rbxassetid://15448244904"}},
			{name="machete_zk_bluegem",display="Bluegem [ZK]",rarity="exotic",textureID="15039202907",skinClass="Melees",sa={color="rbxassetid://15039203215",normal="rbxassetid://15039202668",roughness="rbxassetid://15039203446",metalness="rbxassetid://15039203053"}},
			{name="machete_zk_damascus",display="Damascus [ZK]",rarity="exotic",textureID="15039195623",skinClass="Melees",sa={color="rbxassetid://15039195623",normal="rbxassetid://15039195623",roughness="rbxassetid://15039195623",metalness="rbxassetid://15039195623"}},
			{name="machete_zk_emerald",display="Emerald [ZK]",rarity="exotic",textureID="16303081728",skinClass="Melees",sa={color="rbxassetid://16303081728",normal="rbxassetid://16303081728",roughness="rbxassetid://16303081728",metalness="rbxassetid://16303081728"}},
			{name="machete_zk_forest",display="Forest [ZK]",rarity="exotic",textureID="15039175283",skinClass="Melees",sa={color="rbxassetid://15039175283",normal="rbxassetid://15039175283",roughness="rbxassetid://15039175283",metalness="rbxassetid://15039175283"}},
			{name="machete_zk_undead",display="Machete: ZK",rarity="exotic",textureID="15039210788",skinClass="Melees",sa={color="rbxassetid://15039210788",normal="rbxassetid://15039210788",roughness="rbxassetid://15039210788",metalness="rbxassetid://15039210788"}},
			{name="machete_zk_rustic",display="Rustic [ZK]",rarity="exotic",textureID="15039186771",skinClass="Melees",sa={color="rbxassetid://15039186771",normal="rbxassetid://15039186771",roughness="rbxassetid://15039186771",metalness="rbxassetid://15039186771"}},
			{name="machete_zk_vanilla",display="Vanilla [ZK]",rarity="exotic",textureID="15029004407",skinClass="Melees",sa={color="rbxassetid://15029004407",normal="rbxassetid://15029004407",roughness="rbxassetid://15029004407",metalness="rbxassetid://15029004407"}},
			{name="machete_zk_olivedrift",display="ZK: Olivedrift",rarity="exotic",textureID="15070276224",skinClass="Melees",sa={color="rbxassetid://15070276224",normal="rbxassetid://15070275513",roughness="rbxassetid://15070275156",metalness="rbxassetid://15070275774"}},
		},
		["Magnum"]={
			{name="magnum_bills",display="Bills",rarity="common",textureID="13935347512",skinClass="Guns",sa={color="rbxassetid://13935343468",normal="rbxassetid://13841632677",roughness="rbxassetid://13851639717",metalness="rbxassetid://13841628817"}},
			{name="magnum_bronze",display="Bronze",rarity="common",textureID="13402004314",skinClass="Guns",sa={color="rbxassetid://13388529824",normal="rbxassetid://13388534835",roughness="rbxassetid://13388535886",metalness="rbxassetid://13388533297"}},
			{name="magnum_rustborne",display="Rustborne",rarity="common",textureID="13395647452",skinClass="Guns",sa={color="rbxassetid://13395647452",normal="",roughness="",metalness=""}},
			{name="magnum_abstract",display="Abstract",rarity="uncommon",textureID="13851642216",skinClass="Guns",sa={color="rbxassetid://13851638932",normal="rbxassetid://13841632677",roughness="rbxassetid://13851639717",metalness="rbxassetid://13841628817"}},
			{name="magnum_arcticapex",display="Artic Apex",rarity="uncommon",textureID="15710939034",skinClass="Guns",sa={color="rbxassetid://15710939034",normal="rbxassetid://15710939034",roughness="rbxassetid://15710939034",metalness="rbxassetid://15710939034"}},
			{name="magnum_ironhammer",display="Iron Hammer",rarity="uncommon",textureID="18319380961",skinClass="Guns",sa={color="rbxassetid://18319380961",normal="rbxassetid://18319380961",roughness="rbxassetid://18319380961",metalness="rbxassetid://18319380961"}},
			{name="magnum_amour",display="Amour",rarity="rare",textureID="16355308299",skinClass="Guns",sa={color="rbxassetid://16355308299",normal="rbxassetid://16355308299",roughness="rbxassetid://16355308299",metalness="rbxassetid://16355308299"}},
			{name="magnum_inferno",display="Inferno",rarity="limited",textureID="13565659313",skinClass="Guns",sa={color="rbxassetid://13565647644",normal="rbxassetid://13565652460",roughness="rbxassetid://13565654437",metalness="rbxassetid://13565650923",customColor={145,127,175}}},
			{name="magnum_inferno",display="Inferno",rarity="limited",textureID="13565659313",skinClass="Guns",sa={color="rbxassetid://13565647644",normal="rbxassetid://13565652460",roughness="rbxassetid://13565654437",metalness="rbxassetid://13565650923",customColor={145,127,175}}},
			{name="firemagnum",display="dont use this.",rarity="limited",textureID="0",skinClass="Guns",sa=nil},
		},
		["Mare"]={
			{name="mare_frostecho",display="Frost Echo",rarity="common",textureID="15695474241",skinClass="Guns",sa={color="rbxassetid://15695474241",normal="rbxassetid://15695474241",roughness="rbxassetid://15695474241",metalness="rbxassetid://15695474241"}},
			{name="mare_burial",display="Burial",rarity="uncommon",textureID="124598507519706",skinClass="Guns",sa={color="rbxassetid://124598507519706",normal="rbxassetid://124598507519706",roughness="rbxassetid://124598507519706",metalness="rbxassetid://124598507519706"}},
			{name="mare_foamshot",display="Foamshot",rarity="uncommon",textureID="126702271620280",skinClass="Guns",sa={color="rbxassetid://126702271620280",normal="",roughness="",metalness=""}},
			{name="mare_maritime",display="Maritime",rarity="uncommon",textureID="15998688712",skinClass="Guns",sa={color="rbxassetid://15998688712",normal="rbxassetid://15998688712",roughness="rbxassetid://15998688712",metalness="rbxassetid://15998688712"}},
			{name="mare_stallion",display="Stallion",rarity="uncommon",textureID="13564997857",skinClass="Guns",sa={color="rbxassetid://13556460890",normal="rbxassetid://13556462708",roughness="rbxassetid://13556463568",metalness="rbxassetid://13556461661"}},
			{name="mare_trickshot",display="Trickshot",rarity="limited",textureID="16907786775",skinClass="Guns",sa={color="rbxassetid://16907785827",normal="rbxassetid://16907787618",roughness="rbxassetid://16907788208",metalness="rbxassetid://16907786165"}},
			{name="mare_trickshot",display="Trickshot",rarity="limited",textureID="16907786775",skinClass="Guns",sa={color="rbxassetid://16907785827",normal="rbxassetid://16907787618",roughness="rbxassetid://16907788208",metalness="rbxassetid://16907786165"}},
			{name="mare_trickshot",display="Trickshot",rarity="limited",textureID="16907785827",skinClass="Guns",sa={color="rbxassetid://16907785827",normal="rbxassetid://16907787618",roughness="rbxassetid://16907788208",metalness="rbxassetid://16907786165"}},
		},
		["Metal-Bat"]={
			{name="metalbat_battlescarred",display="Battlescarred",rarity="common",textureID="16688459862",skinClass="Melees",sa=nil},
			{name="metalbat_spiffle",display="Spiffle",rarity="common",textureID="15445297130",skinClass="Melees",sa={color="rbxassetid://15445297130",normal="rbxassetid://15445297130",roughness="rbxassetid://15445297130",metalness="rbxassetid://15445297130"}},
			{name="metalbat_urbanleather",display="Urban Leather",rarity="common",textureID="14982908326",skinClass="Melees",sa={color="rbxassetid://14982908326",normal="rbxassetid://14982908326",roughness="rbxassetid://14982908326",metalness="rbxassetid://14982908326"}},
			{name="metalbat_candycorn",display="Candycorn",rarity="uncommon",textureID="15184166771",skinClass="Melees",sa={color="rbxassetid://15184166771",normal="rbxassetid://15184166771",roughness="rbxassetid://15184166771",metalness="rbxassetid://15184166771"}},
			{name="metalbat_jinglebat",display="Jingle Bat",rarity="uncommon",textureID="84803493814625",skinClass="Melees",sa={color="rbxassetid://84803493814625",normal="",roughness="",metalness=""}},
			{name="metalbat_tesla",display="Tesla-Coil",rarity="uncommon",textureID="137524582120989",skinClass="Melees",sa={color="rbxassetid://137524582120989",normal="",roughness="",metalness=""}},
			{name="metalbat_vibecheck",display="Vibecheck`d",rarity="uncommon",textureID="15445259400",skinClass="Melees",sa={color="rbxassetid://15445259400",normal="rbxassetid://15445259400",roughness="rbxassetid://15445259400",metalness="rbxassetid://15445259400"}},
			{name="metalbat_northpole",display="North Pole",rarity="legendary",textureID="15695386895",skinClass="Melees",sa={color="rbxassetid://15695386895",normal="rbxassetid://15695386895",roughness="rbxassetid://15695386895",metalness="rbxassetid://15695386895"}},
			{name="metalbat_serpentine",display="Serpentine",rarity="legendary",textureID="15028975758",skinClass="Melees",sa={color="rbxassetid://15028975758",normal="rbxassetid://15028975758",roughness="rbxassetid://15028975758",metalness="rbxassetid://15028975758"}},
		},
		["RPG-7"]={
			{name="rpg7_twotone",display="Two-Tone",rarity="uncommon",textureID="13388376607",skinClass="Guns",sa={color="rbxassetid://13388377781",normal="rbxassetid://13388379378",roughness="rbxassetid://13388380305",metalness="rbxassetid://13388378532"}},
			{name="rpg7_boom",display="BOOM!",rarity="rare",textureID="10959329950",skinClass="Guns",sa={color="rbxassetid://10959333634",normal="rbxassetid://10959335179",roughness="rbxassetid://10959335703",metalness="rbxassetid://10959334502"}},
			{name="rpg7_gold",display="Golden RPG",rarity="limited",textureID="13715204837",skinClass="Guns",sa={color="rbxassetid://13715204837",normal="rbxassetid://13715207167",roughness="rbxassetid://13715207920",metalness="rbxassetid://13715205903",customColor={255,170,0}}},
			{name="rpg7_gold",display="Golden RPG",rarity="limited",textureID="13715204837",skinClass="Guns",sa={color="rbxassetid://13715204837",normal="rbxassetid://13715207167",roughness="rbxassetid://13715207920",metalness="rbxassetid://13715205903",customColor={255,170,0}}},
		},
		["Rambo"]={
			{name="rambo_cocoa",display="Cocoa",rarity="common",textureID="15449254329",skinClass="Melees",sa={color="rbxassetid://15449254329",normal="rbxassetid://15449254329",roughness="rbxassetid://15449254329",metalness="rbxassetid://15449254329"}},
			{name="rambo_rimecarver",display="Rimecarver",rarity="common",textureID="88056079326083",skinClass="Melees",sa={color="rbxassetid://88056079326083",normal="",roughness="",metalness=""}},
			{name="rambo_slasha",display="Slasha",rarity="rare",textureID="14983934299",skinClass="Melees",sa={color="rbxassetid://14983934299",normal="rbxassetid://14983934299",roughness="rbxassetid://14983934299",metalness="rbxassetid://14983934299"}},
			{name="rambo_scorched",display="Scorched",rarity="legendary",textureID="16688015251",skinClass="Melees",sa={color="rbxassetid://16688013963",normal="rbxassetid://16688015743",roughness="rbxassetid://16688016303",metalness="rbxassetid://16688014597"}},
			{name="rambo_blackpearl",display="Black Pearl",rarity="exotic",textureID="16268374444",skinClass="Melees",sa=nil},
			{name="rambo_bluegem",display="Blue gem",rarity="exotic",textureID="16268374887",skinClass="Melees",sa=nil},
			{name="rambo_damascus",display="Damascus",rarity="exotic",textureID="16268375476",skinClass="Melees",sa=nil},
			{name="rambo_emerald",display="Emerald",rarity="exotic",textureID="16268308309",skinClass="Melees",sa=nil},
			{name="rambo_forest",display="Forest",rarity="exotic",textureID="16268376292",skinClass="Melees",sa=nil},
			{name="rambo_olivedrift",display="Olive Drift",rarity="exotic",textureID="16268376667",skinClass="Melees",sa=nil},
			{name="rambo_rustic",display="Rustic",rarity="exotic",textureID="16268377036",skinClass="Melees",sa=nil},
			{name="rambo_vanilla",display="Vanilla",rarity="exotic",textureID="16268315355",skinClass="Melees",sa=nil},
		},
		["SCAR-H-1"]={
			{name="scarh_torchbearer",display="Torch Bearer",rarity="common",textureID="18167599401",skinClass="Guns",sa={color="rbxassetid://18167599401",normal="rbxassetid://18167599401",roughness="rbxassetid://18167599401",metalness="rbxassetid://18167599401"}},
			{name="scarh_gridlines",display="Gridlines",rarity="uncommon",textureID="16010528228",skinClass="Guns",sa={color="rbxassetid://16010528228",normal="rbxassetid://16010528228",roughness="rbxassetid://16010528228",metalness="rbxassetid://16010528228"}},
			{name="scarh_milspec",display="MIL-SPEC",rarity="uncommon",textureID="13703883944",skinClass="Guns",sa={color="rbxassetid://13703885359",normal="rbxassetid://12548441857",roughness="rbxassetid://13703886985",metalness="rbxassetid://13703886217"}},
		},
		["SKS"]={
			{name="sks_copper",display="Copper",rarity="common",textureID="13388317796",skinClass="Guns",sa={color="rbxassetid://13394135741",normal="rbxassetid://13388320318",roughness="rbxassetid://13388321173",metalness="rbxassetid://13388319734"}},
			{name="sks_modern",display="Modern",rarity="common",textureID="13388174747",skinClass="Guns",sa={color="rbxassetid://13388175991",normal="rbxassetid://9341965058",roughness="rbxassetid://9341941167",metalness="rbxassetid://9341938929"}},
			{name="sks_nevermore",display="Nevermore",rarity="common",textureID="99728168884950",skinClass="Guns",sa={color="rbxassetid://99728168884950",normal="rbxassetid://99728168884950",roughness="rbxassetid://99728168884950",metalness="rbxassetid://99728168884950"}},
			{name="sks_paragon",display="Paragon",rarity="common",textureID="15998710650",skinClass="Guns",sa={color="rbxassetid://15998710650",normal="rbxassetid://15998710650",roughness="rbxassetid://15998710650",metalness="rbxassetid://15998710650"}},
			{name="sks_snowcoat",display="Snow Coat",rarity="common",textureID="9276325654",skinClass="Guns",sa={color="rbxassetid://9276325654",normal="",roughness="",metalness=""}},
			{name="sks_umbrella",display="Umbrella",rarity="uncommon",textureID="13841609325",skinClass="Guns",sa={color="rbxassetid://13841605579",normal="rbxassetid://13841607333",roughness="rbxassetid://13388321173",metalness="rbxassetid://13841606562"}},
			{name="sks_jacko",display="Jack'O",rarity="rare",textureID="15177206758",skinClass="Guns",sa={color="rbxassetid://15177206758",normal="rbxassetid://15177206758",roughness="rbxassetid://15177206758",metalness="rbxassetid://15177206758"}},
			{name="sks_jester",display="Jester",rarity="legendary",textureID="13343195152",skinClass="Guns",sa={color="rbxassetid://13343167267",normal="rbxassetid://13343168956",roughness="rbxassetid://13343169804",metalness="rbxassetid://13343167958"}},
			{name="sks_gold",display="Golden SKS",rarity="limited",textureID="16300596462",skinClass="Guns",sa={color="rbxassetid://16300596462",normal="rbxassetid://16299700340",roughness="rbxassetid://16299699813",metalness="rbxassetid://16299699464",customColor={145,127,175}}},
			{name="sks_gold",display="Golden SKS",rarity="limited",textureID="16300596462",skinClass="Guns",sa={color="rbxassetid://16300596462",normal="rbxassetid://16299700340",roughness="rbxassetid://16299699813",metalness="rbxassetid://16299699464",customColor={145,127,175}}},
		},
		["SKS	"]={
			{name="sks_gold",display="Golden SKS",rarity="limited",textureID="15998559023",skinClass="Guns",sa={color="rbxassetid://16300596462",normal="rbxassetid://16299700340",roughness="rbxassetid://16299699813",metalness="rbxassetid://16299699464",customColor={145,127,175}}},
		},
		["Sawn-Off"]={
			{name="sawnoff_radium",display="Radium Scatter",rarity="subcommon",textureID="94748131117032",skinClass="Guns",sa={color="rbxassetid://94748131117032",normal="",roughness="",metalness=""}},
			{name="sawnoff_caution",display="Caution",rarity="common",textureID="10959354994",skinClass="Guns",sa={color="rbxassetid://10959371093",normal="rbxassetid://10959372567",roughness="",metalness="rbxassetid://10959371833"}},
			{name="sawnoff_ectoplasm",display="Ectoplasm",rarity="common",textureID="99467907178773",skinClass="Guns",sa={color="rbxassetid://99467907178773",normal="rbxassetid://99467907178773",roughness="rbxassetid://99467907178773",metalness="rbxassetid://99467907178773"}},
			{name="sawnoff_logs",display="Logs",rarity="common",textureID="13556265064",skinClass="Guns",sa={color="rbxassetid://13556252494",normal="rbxassetid://13556254217",roughness="rbxassetid://13556254787",metalness="rbxassetid://13556253379"}},
			{name="sawnoff_multicam",display="Multicam",rarity="common",textureID="15998421683",skinClass="Guns",sa={color="rbxassetid://15998421683",normal="rbxassetid://15998421683",roughness="rbxassetid://15998421683",metalness="rbxassetid://15998421683"}},
			{name="sawnoff_tarnished",display="Tarnished Holly",rarity="common",textureID="137388284721605",skinClass="Guns",sa={color="rbxassetid://137388284721605",normal="",roughness="",metalness=""}},
			{name="sawnoff_banana",display="Banana",rarity="uncommon",textureID="13387477962",skinClass="Guns",sa={color="rbxassetid://13387455222",normal="rbxassetid://13387461274",roughness="rbxassetid://13387462843",metalness="rbxassetid://13387458782"}},
			{name="sawnoff_webs",display="Webs",rarity="uncommon",textureID="15177076142",skinClass="Guns",sa={color="rbxassetid://15177076142",normal="rbxassetid://15177076142",roughness="rbxassetid://15177076142",metalness="rbxassetid://15177076142"}},
			{name="sawnoff_glacial",display="Glacial",rarity="rare",textureID="13343271197",skinClass="Guns",sa={color="rbxassetid://13030805318",normal="rbxassetid://13030811843",roughness="rbxassetid://13030812846",metalness="rbxassetid://13030809551"}},
			{name="sawnoff_grandprix",display="Grand Prix",rarity="rare",textureID="13842331455",skinClass="Guns",sa={color="rbxassetid://13841748041",normal="rbxassetid://13841750446",roughness="rbxassetid://13556254787",metalness="rbxassetid://13841749691"}},
			{name="sawnoff_eros",display="Eros",rarity="limited",textureID="124136583812651",skinClass="Guns",sa={color="rbxassetid://94543327437589",normal="rbxassetid://96893785031392",roughness="rbxassetid://96893785031392",metalness="rbxassetid://140685658953144",customColor={243,107,255}}},
			{name="sawnoff_gold",display="Golden Sawn-Off",rarity="limited",textureID="13714495559",skinClass="Guns",sa={color="rbxassetid://13714456145",normal="rbxassetid://13702871512",roughness="rbxassetid://13702872174",metalness="rbxassetid://13702869725",customColor={255,170,0}}},
			{name="sawnoff_gold",display="Golden Sawn-Off",rarity="limited",textureID="13714495559",skinClass="Guns",sa={color="rbxassetid://13714456145",normal="rbxassetid://13702871512",roughness="rbxassetid://13702872174",metalness="rbxassetid://13702869725",customColor={255,170,0}}},
		},
		["Scout"]={
			{name="scout_redwood",display="Redwood",rarity="uncommon",textureID="13713221958",skinClass="Guns",sa={color="rbxassetid://13713216013",normal="rbxassetid://13713217944",roughness="rbxassetid://13713218967",metalness="rbxassetid://13713216835"}},
		},
		["Shovel"]={
			{name="shovel_conspiracy",display="Conspiracy",rarity="common",textureID="16911045144",skinClass="Melees",sa={color="rbxassetid://16911044501",normal="rbxassetid://16911046381",roughness="rbxassetid://16911045496",metalness="rbxassetid://16911045794"}},
			{name="shovel_digital",display="Digital Digger",rarity="common",textureID="89332284546616",skinClass="Melees",sa={color="rbxassetid://89332284546616",normal="",roughness="",metalness=""}},
			{name="shovel_oliveworn",display="Oliveworn",rarity="common",textureID="16688313893",skinClass="Melees",sa=nil},
			{name="shovel_sightings",display="Sightings",rarity="common",textureID="15176959990",skinClass="Melees",sa={color="rbxassetid://15176959990",normal="rbxassetid://14983801496",roughness="rbxassetid://14984658723",metalness="rbxassetid://14984659961"}},
			{name="shovel_heartbreaker",display="Heartbreaker",rarity="uncommon",textureID="16355297408",skinClass="Melees",sa={color="rbxassetid://16355295686",normal="rbxassetid://16355296613",roughness="rbxassetid://16355296920",metalness="rbxassetid://16355296031"}},
			{name="shovel_smiley2",display="Smiley 2",rarity="uncommon",textureID="14984656389",skinClass="Melees",sa={color="rbxassetid://14984656389",normal="rbxassetid://14983801496",roughness="rbxassetid://14984658723",metalness="rbxassetid://14984659961"}},
			{name="shovel_xray",display="X-ray",rarity="uncommon",textureID="87336044400444",skinClass="Melees",sa={color="rbxassetid://87336044400444",normal="rbxassetid://87336044400444",roughness="rbxassetid://87336044400444",metalness="rbxassetid://87336044400444"}},
			{name="shovel_sovereign",display="Sovereign",rarity="legendary",textureID="15445272453",skinClass="Melees",sa={color="rbxassetid://15445272453",normal="rbxassetid://15445272453",roughness="rbxassetid://15445272453",metalness="rbxassetid://15445272453"}},
		},
		["Sledgehammer"]={
			{name="sledgehammer_holidaymaul",display="Holiday Maul",rarity="common",textureID="15695483502",skinClass="Melees",sa={color="rbxassetid://140141455097259",normal="",roughness="",metalness=""}},
			{name="sledgehammer_weightedbronze",display="Weightedbronze",rarity="common",textureID="16689250659",skinClass="Melees",sa=nil},
			{name="sledgehammer_boss",display="Boss",rarity="uncommon",textureID="15695404278",skinClass="Melees",sa={color="rbxassetid://15695404278",normal="rbxassetid://15695404278",roughness="rbxassetid://15695404278",metalness="rbxassetid://15695404278"}},
			{name="sledgehammer_porcelain",display="Porcelain",rarity="legendary",textureID="15447463984",skinClass="Melees",sa={color="rbxassetid://15447463984",normal="rbxassetid://15447463984",roughness="rbxassetid://15447463984",metalness="rbxassetid://15447463984"}},
		},
		["Super-Shorty"]={
			{name="sshorty_firecracker",display="Firecracker",rarity="common",textureID="18149800264",skinClass="Guns",sa={color="rbxassetid://18149800264",normal="rbxassetid://18149800264",roughness="rbxassetid://18149800264",metalness="rbxassetid://18149800264"}},
			{name="sshorty_loveletter",display="Love Letter",rarity="common",textureID="16355340290",skinClass="Guns",sa={color="rbxassetid://16355338517",normal="rbxassetid://16355339662",roughness="rbxassetid://16355340721",metalness="rbxassetid://16355338911"}},
			{name="sshorty_steel",display="Steel",rarity="common",textureID="13394160404",skinClass="Guns",sa={color="rbxassetid://13394161570",normal="rbxassetid://13388284123",roughness="rbxassetid://13388283285",metalness="rbxassetid://13388284878"}},
			{name="sshorty_checkmate",display="Checkmate",rarity="uncommon",textureID="13713148936",skinClass="Guns",sa={color="rbxassetid://13713146952",normal="rbxassetid://13713130525",roughness="rbxassetid://13713131369",metalness="rbxassetid://13713129636"}},
		},
		["TEC-9"]={
			{name="tec9_burgundypine",display="Burgundy Pine",rarity="common",textureID="134671657569127",skinClass="Guns",sa={color="rbxassetid://134671657569127",normal="",roughness="",metalness=""}},
			{name="tec9_import",display="Import",rarity="common",textureID="13556236652",skinClass="Guns",sa={color="rbxassetid://13556231753",normal="rbxassetid://13556233332",roughness="rbxassetid://13556234000",metalness="rbxassetid://13556232611"}},
			{name="tec9_lilac",display="Lilac",rarity="common",textureID="13841536261",skinClass="Guns",sa={color="rbxassetid://13841531857",normal="rbxassetid://13841534362",roughness="rbxassetid://13841535132",metalness="rbxassetid://13841533434"}},
			{name="tec9_snakeskin",display="Snakeskin",rarity="common",textureID="13566205064",skinClass="Guns",sa={color="rbxassetid://13566186022",normal="rbxassetid://13566188527",roughness="rbxassetid://13566189605",metalness="rbxassetid://13566187509"}},
			{name="tec9_cottoncloud",display="Cotton Cloud",rarity="uncommon",textureID="15998727136",skinClass="Guns",sa={color="rbxassetid://15998727136",normal="rbxassetid://15998727136",roughness="rbxassetid://15998727136",metalness="rbxassetid://15998727136"}},
			{name="tec9_liberty",display="Liberty",rarity="uncommon",textureID="13935391655",skinClass="Guns",sa={color="rbxassetid://13935385791",normal="rbxassetid://13935388242",roughness="rbxassetid://13935389032",metalness="rbxassetid://13935387111"}},
			{name="tec9_star9",display="Star-9",rarity="uncommon",textureID="13387517349",skinClass="Guns",sa={color="rbxassetid://13387502788",normal="rbxassetid://13387508121",roughness="rbxassetid://13387509249",metalness="rbxassetid://13387506611"}},
			{name="tec9_diner",display="Diner",rarity="rare",textureID="13713002732",skinClass="Guns",sa={color="rbxassetid://13712979305",normal="rbxassetid://13703915693",roughness="rbxassetid://13712990125",metalness="rbxassetid://13712980107"}},
		},
		["Taiga"]={
			{name="taiga_current",display="Current Crash",rarity="subcommon",textureID="90247337759446",skinClass="Melees",sa={color="rbxassetid://90247337759446",normal="",roughness="",metalness=""}},
			{name="taiga_conductor",display="Conductor",rarity="common",textureID="14982945679",skinClass="Melees",sa={color="rbxassetid://14982945679",normal="rbxassetid://14982945679",roughness="rbxassetid://14982945679",metalness="rbxassetid://14982945679"}},
			{name="taiga_scalemail",display="Scalemail",rarity="common",textureID="16688381364",skinClass="Melees",sa=nil},
			{name="taiga_scuffed",display="Scuffed",rarity="common",textureID="15449276653",skinClass="Melees",sa={color="rbxassetid://15449276653",normal="rbxassetid://15449276653",roughness="rbxassetid://15449276653",metalness="rbxassetid://15449276653"}},
			{name="taiga_thornslash",display="Thorn Slash",rarity="common",textureID="16355282883",skinClass="Melees",sa={color="rbxassetid://16355282883",normal="rbxassetid://16355282883",roughness="rbxassetid://16355282883",metalness="rbxassetid://16355282883"}},
			{name="taiga_bubblegum",display="Bubblegum",rarity="uncommon",textureID="14983876632",skinClass="Melees",sa={color="rbxassetid://14983876632",normal="rbxassetid://14983878474",roughness="rbxassetid://14983879458",metalness="rbxassetid://14983877458"}},
			{name="taiga_icicle",display="Icicle",rarity="uncommon",textureID="15711030856",skinClass="Melees",sa={color="rbxassetid://15711030856",normal="rbxassetid://15711030856",roughness="rbxassetid://15711030856",metalness="rbxassetid://15711030856"}},
			{name="taiga_404",display="404",rarity="rare",textureID="15448951687",skinClass="Melees",sa={color="rbxassetid://15448951687",normal="rbxassetid://15448951687",roughness="rbxassetid://15448951687",metalness="rbxassetid://15448951687"}},
		},
		["Tommy"]={
			{name="tommy_currant",display="Currant",rarity="common",textureID="13841589575",skinClass="Guns",sa={color="rbxassetid://13841583772",normal="rbxassetid://13841586063",roughness="rbxassetid://13841586825",metalness="rbxassetid://13841584989"}},
			{name="tommy_headstone",display="Headstone",rarity="common",textureID="15177096261",skinClass="Guns",sa={color="rbxassetid://15177096261",normal="rbxassetid://15177096261",roughness="rbxassetid://15177096261",metalness="rbxassetid://15177096261"}},
			{name="tommy_plum",display="Plum",rarity="common",textureID="13388353769",skinClass="Guns",sa={color="rbxassetid://13388349585",normal="rbxassetid://13388350802",roughness="rbxassetid://13388351567",metalness="rbxassetid://13388350104"}},
			{name="tommy_huntinglodge",display="Hunting Lodge",rarity="uncommon",textureID="105449250306908",skinClass="Guns",sa={color="rbxassetid://105449250306908",normal="",roughness="",metalness=""}},
			{name="tommy_unclesam",display="Uncle Sam",rarity="rare",textureID="13936668999",skinClass="Guns",sa={color="rbxassetid://13936670325",normal="rbxassetid://13936671749",roughness="rbxassetid://13936672741",metalness="rbxassetid://13936670921"}},
			{name="tommy_leatherworks",display="Leatherworks",rarity="legendary",textureID="13565052794",skinClass="Guns",sa={color="rbxassetid://13556313114",normal="rbxassetid://13556315610",roughness="rbxassetid://13556316435",metalness="rbxassetid://13556314814"}},
			{name="tommy_gold",display="Golden Tommy",rarity="limited",textureID="15039147598",skinClass="Guns",sa={color="rbxassetid://15039147920",normal="rbxassetid://15039147363",roughness="rbxassetid://15039147120",metalness="rbxassetid://15039147721",customColor={145,127,175}}},
			{name="tommy_gold",display="Golden Tommy",rarity="limited",textureID="15039147598",skinClass="Guns",sa={color="rbxassetid://15039147920",normal="rbxassetid://15039147363",roughness="rbxassetid://15039147120",metalness="rbxassetid://15039147721",customColor={145,127,175}}},
		},
		["UMP-45"]={
			{name="ump_burntumber",display="Burnt Umber",rarity="common",textureID="13842577137",skinClass="Guns",sa={color="rbxassetid://13842574571",normal="rbxassetid://13841561295",roughness="rbxassetid://13713092610",metalness="rbxassetid://13841560451"}},
			{name="ump_honeycomb",display="Honeycomb",rarity="uncommon",textureID="13713093970",skinClass="Guns",sa={color="rbxassetid://13713087658",normal="rbxassetid://13713089856",roughness="rbxassetid://13713092610",metalness="rbxassetid://13713088970"}},
			{name="ump_lesion",display="Lesion",rarity="rare",textureID="15177224638",skinClass="Guns",sa={color="rbxassetid://15177224638",normal="rbxassetid://15177224638",roughness="rbxassetid://15177224638",metalness="rbxassetid://15177224638"}},
		},
		["Uzi"]={
			{name="uzi_coldshell",display="Cold Shell",rarity="common",textureID="73784413219495",skinClass="Guns",sa={color="rbxassetid://73784413219495",normal="",roughness="",metalness=""}},
			{name="uzi_grape",display="Grape",rarity="common",textureID="13387916321",skinClass="Guns",sa={color="rbxassetid://13387917991",normal="rbxassetid://13343337433",roughness="rbxassetid://13343338573",metalness="rbxassetid://13343336766"}},
			{name="uzi_pumpkinspice",display="Pumpkin Spice",rarity="common",textureID="15177118472",skinClass="Guns",sa={color="rbxassetid://15177118472",normal="rbxassetid://15177118472",roughness="rbxassetid://15177118472",metalness="rbxassetid://15177118472"}},
			{name="uzi_rust",display="Rust",rarity="common",textureID="13715501813",skinClass="Guns",sa={color="rbxassetid://13715502850",normal="rbxassetid://13715505019",roughness="rbxassetid://13715505740",metalness="rbxassetid://13715504263"}},
			{name="uzi_crimsonjaw",display="Crimson Jaw",rarity="rare",textureID="13343333197",skinClass="Guns",sa={color="rbxassetid://13343335417",normal="rbxassetid://13343337433",roughness="rbxassetid://13343338573",metalness="rbxassetid://13343336766"}},
			{name="uzi_grape2",display="Grapes II",rarity="rare",textureID="16952083915",skinClass="Guns",sa={color="rbxassetid://16952083501",normal="rbxassetid://16952084326",roughness="rbxassetid://16952084530",metalness="rbxassetid://16952083672"}},
			{name="uzi_smiley",display="Smiley",rarity="rare",textureID="13841671610",skinClass="Guns",sa={color="rbxassetid://13841666943",normal="rbxassetid://13841669834",roughness="rbxassetid://13715505740",metalness="rbxassetid://13841669024"}},
			{name="uzi_guilded",display="Guilded",rarity="legendary",textureID="15998742287",skinClass="Guns",sa={color="rbxassetid://15998742287",normal="rbxassetid://15998742287",roughness="rbxassetid://15998742287",metalness="rbxassetid://15998742287"}},
		},
		["Wrench"]={
			{name="wrench_schematic",display="Schematic",rarity="subcommon",textureID="85334381763123",skinClass="Melees",sa={color="rbxassetid://85334381763123",normal="",roughness="",metalness=""}},
			{name="wrench_aerospace",display="Aerospace",rarity="common",textureID="15695483502",skinClass="Melees",sa={color="rbxassetid://15695483502",normal="rbxassetid://15695483502",roughness="rbxassetid://15695483502",metalness="rbxassetid://15695483502"}},
			{name="wrench_contractor",display="Contractor",rarity="common",textureID="14982816807",skinClass="Melees",sa={color="rbxassetid://14982816807",normal="rbxassetid://14982826845",roughness="rbxassetid://14982824116",metalness="rbxassetid://14982829131"}},
			{name="wrench_mrwrench",display="Mr-Wrench",rarity="common",textureID="16688443083",skinClass="Melees",sa={color="rbxassetid://16688441788",normal="rbxassetid://16688443867",roughness="rbxassetid://16688444803",metalness="rbxassetid://16688442409"}},
			{name="wrench_tendencies",display="Tendencies",rarity="common",textureID="15177056272",skinClass="Melees",sa={color="rbxassetid://15177056272",normal="rbxassetid://14982826845",roughness="rbxassetid://14982824116",metalness="rbxassetid://14982829131"}},
			{name="wrench_greenmask",display="Green Mask",rarity="uncommon",textureID="15451673831",skinClass="Melees",sa={color="rbxassetid://15451673831",normal="rbxassetid://15451673831",roughness="rbxassetid://15451673831",metalness="rbxassetid://15451673831"}},
			{name="wrench_hammer_blackpearl",display="Hammer: Blackpearl",rarity="exotic",textureID="15448181005",skinClass="Melees",sa={color="rbxassetid://15448181005",normal="rbxassetid://15448181005",roughness="rbxassetid://15448181005",metalness="rbxassetid://15448181005"}},
			{name="wrench_hammer_bluegem",display="Hammer: Bluegem",rarity="exotic",textureID="15039886621",skinClass="Melees",sa={color="rbxassetid://15039886621",normal="rbxassetid://15039886621",roughness="rbxassetid://15039886621",metalness="rbxassetid://15039886621"}},
			{name="wrench_hammer_corrosion",display="Hammer: Corrosion",rarity="exotic",textureID="15039908965",skinClass="Melees",sa={color="rbxassetid://15039908965",normal="rbxassetid://15039908965",roughness="rbxassetid://15039908965",metalness="rbxassetid://15039908965"}},
			{name="wrench_hammer_damascus",display="Hammer: Damascus",rarity="exotic",textureID="15039883793",skinClass="Melees",sa={color="rbxassetid://15039883793",normal="rbxassetid://15039883793",roughness="rbxassetid://15039883793",metalness="rbxassetid://15039883793"}},
			{name="wrench_hammer_emerald",display="Hammer: Emerald",rarity="exotic",textureID="15448075670",skinClass="Melees",sa={color="rbxassetid://15448075670",normal="rbxassetid://15448075670",roughness="rbxassetid://15448075670",metalness="rbxassetid://15448075670"}},
			{name="wrench_hammer_olivedrift",display="Hammer: Olivedrift",rarity="exotic",textureID="15070249049",skinClass="Melees",sa={color="rbxassetid://15070249049",normal="rbxassetid://15070249049",roughness="rbxassetid://15070249049",metalness="rbxassetid://15070249049"}},
			{name="wrench_hammer_rustic",display="Hammer: Rustic",rarity="exotic",textureID="15039905170",skinClass="Melees",sa={color="rbxassetid://15039905170",normal="rbxassetid://15039905170",roughness="rbxassetid://15039905170",metalness="rbxassetid://15039905170"}},
			{name="wrench_hammer_vanilla",display="Hammer: Vanilla",rarity="exotic",textureID="14984302065",skinClass="Melees",sa={color="rbxassetid://14984302065",normal="rbxassetid://14984302065",roughness="rbxassetid://14984302065",metalness="rbxassetid://14984302065"}},
			{name="wrench_hammer_kintsugi",display="Kintsugi",rarity="exotic",textureID="15039897126",skinClass="Melees",sa={color="rbxassetid://15039897126",normal="rbxassetid://15039897126",roughness="rbxassetid://15039897126",metalness="rbxassetid://15039897126"}},
		},
	}
	local WEAPONS = {"AKM","AKS-74U","AWM","BBaton","BFG-1","Balisong","Bat","Bayonet","Beretta","Chainsaw","Crowbar","Deagle","FN-FAL","FNP-45","Fire-Axe","G-17","Golfclub","Ithaca-37","Katana","M1911","M320-1","M4A1-1","M60","MAC-10","MP7","Machete","Magnum","Mare","Metal-Bat","RPG-7","Rambo","SCAR-H-1","SKS","SKS	","Sawn-Off","Scout","Shovel","Sledgehammer","Super-Shorty","TEC-9","Taiga","Tommy","UMP-45","Uzi","Wrench"}

	-- === DEV SKIN CHANGER — standalone, zero server dependency ===

	local Players = game:GetService("Players")
	local UIS     = game:GetService("UserInputService")
	local lp      = Players.LocalPlayer

	local RARITY_COLORS = {
		common    = Color3.fromRGB(180,180,180),
		uncommon  = Color3.fromRGB(100,200,100),
		rare      = Color3.fromRGB(80,140,255),
		legendary = Color3.fromRGB(200,100,255),
		exotic    = Color3.fromRGB(255,180,50),
		limited   = Color3.fromRGB(255,80,80),
		custom    = Color3.fromRGB(255,220,0),
	}

	local currentTool    = nil
	local originalData   = {}
	local selectedWeapon = nil
	local weaponBtns     = {}
	local guiVisible     = true

	local function makeCorner(p, r)
		local c = Instance.new("UICorner", p)
		c.CornerRadius = UDim.new(0, r or 8)
	end
	local function makePad(p, l, r, t, b)
		local pad = Instance.new("UIPadding", p)
		pad.PaddingLeft   = UDim.new(0, l or 0)
		pad.PaddingRight  = UDim.new(0, r or 0)
		pad.PaddingTop    = UDim.new(0, t or 0)
		pad.PaddingBottom = UDim.new(0, b or 0)
	end

	-- GUI
	local sg = Instance.new("ScreenGui")
	sg.Name = "DevSkinChanger"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = lp.PlayerGui

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.new(0,400,0,540)
	main.Position = UDim2.new(0,20,0.5,-270)
	main.BackgroundColor3 = Color3.fromRGB(14,14,20)
	main.BorderSizePixel = 0
	main.Active = true
	main.Draggable = true
	main.Parent = sg
	makeCorner(main, 10)

	-- Title bar
	local titleBar = Instance.new("Frame", main)
	titleBar.Size = UDim2.new(1,0,0,40)
	titleBar.BackgroundColor3 = Color3.fromRGB(24,24,36)
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 2
	makeCorner(titleBar, 10)
	local tf = Instance.new("Frame", titleBar)
	tf.Size = UDim2.new(1,0,0,10)
	tf.Position = UDim2.new(0,0,1,-10)
	tf.BackgroundColor3 = Color3.fromRGB(24,24,36)
	tf.BorderSizePixel = 0
	tf.ZIndex = 2

	local dot = Instance.new("Frame", titleBar)
	dot.Size = UDim2.new(0,8,0,8)
	dot.Position = UDim2.new(0,12,0.5,-4)
	dot.BackgroundColor3 = Color3.fromRGB(80,200,120)
	dot.BorderSizePixel = 0
	dot.ZIndex = 3
	makeCorner(dot, 4)

	local titleLbl = Instance.new("TextLabel", titleBar)
	titleLbl.Size = UDim2.new(1,-90,1,0)
	titleLbl.Position = UDim2.new(0,28,0,0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "SKIN CHANGER | PRESS K TO TOGGLE ON/OFF"
	titleLbl.TextColor3 = Color3.fromRGB(220,220,230)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 3

	local hintLbl = Instance.new("TextLabel", titleBar)
	hintLbl.Size = UDim2.new(0,60,1,0)
	hintLbl.Position = UDim2.new(1,-100,0,0)
	hintLbl.BackgroundTransparency = 1
	hintLbl.Text = "[K] hide"
	hintLbl.TextColor3 = Color3.fromRGB(80,80,110)
	hintLbl.Font = Enum.Font.Gotham
	hintLbl.TextSize = 10
	hintLbl.ZIndex = 3

	-- Status
	local statusBar = Instance.new("Frame", main)
	statusBar.Size = UDim2.new(1,0,0,30)
	statusBar.Position = UDim2.new(0,0,0,40)
	statusBar.BackgroundColor3 = Color3.fromRGB(20,20,30)
	statusBar.BorderSizePixel = 0
	makePad(statusBar, 10, 10, 0, 0)

	local statusLbl = Instance.new("TextLabel", statusBar)
	statusLbl.Size = UDim2.new(1,0,1,0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "Equip a weapon, then pick a skin"
	statusLbl.TextColor3 = Color3.fromRGB(110,110,150)
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 11
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left

	-- Search
	local searchBox = Instance.new("TextBox", main)
	searchBox.Size = UDim2.new(1,-16,0,30)
	searchBox.Position = UDim2.new(0,8,0,74)
	searchBox.BackgroundColor3 = Color3.fromRGB(26,26,38)
	searchBox.BorderSizePixel = 0
	searchBox.PlaceholderText = "Search skins..."
	searchBox.PlaceholderColor3 = Color3.fromRGB(70,70,100)
	searchBox.Text = ""
	searchBox.TextColor3 = Color3.fromRGB(210,210,210)
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 12
	searchBox.ClearTextOnFocus = false
	makeCorner(searchBox, 6)
	makePad(searchBox, 10, 0, 0, 0)

	-- Column headers
	local function colHeader(text, xPos, w)
		local l = Instance.new("TextLabel", main)
		l.Size = UDim2.new(0,w,0,16)
		l.Position = UDim2.new(0,xPos,0,108)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = Color3.fromRGB(80,80,120)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 9
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	colHeader("WEAPON", 10, 118)
	colHeader("SKIN", 140, 240)

	-- Weapon scroll
	local weaponScroll = Instance.new("ScrollingFrame", main)
	weaponScroll.Size = UDim2.new(0,124,0,340)
	weaponScroll.Position = UDim2.new(0,8,0,126)
	weaponScroll.BackgroundColor3 = Color3.fromRGB(20,20,30)
	weaponScroll.BorderSizePixel = 0
	weaponScroll.ScrollBarThickness = 3
	weaponScroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,110)
	weaponScroll.CanvasSize = UDim2.new(0,0,0,0)
	weaponScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	makeCorner(weaponScroll, 6)
	Instance.new("UIListLayout", weaponScroll).Padding = UDim.new(0,2)

	-- Skin scroll
	local skinScroll = Instance.new("ScrollingFrame", main)
	skinScroll.Size = UDim2.new(1,-150,0,340)
	skinScroll.Position = UDim2.new(0,140,0,126)
	skinScroll.BackgroundColor3 = Color3.fromRGB(20,20,30)
	skinScroll.BorderSizePixel = 0
	skinScroll.ScrollBarThickness = 3
	skinScroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,110)
	skinScroll.CanvasSize = UDim2.new(0,0,0,0)
	skinScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	makeCorner(skinScroll, 6)
	Instance.new("UIListLayout", skinScroll).Padding = UDim.new(0,2)

	-- Reset button
	local resetBtn = Instance.new("TextButton", main)
	resetBtn.Size = UDim2.new(1,-16,0,32)
	resetBtn.Position = UDim2.new(0,8,0,474)
	resetBtn.BackgroundColor3 = Color3.fromRGB(36,36,56)
	resetBtn.Text = "↺   Reset to Default"
	resetBtn.TextColor3 = Color3.fromRGB(160,160,200)
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = 12
	resetBtn.BorderSizePixel = 0
	makeCorner(resetBtn, 6)
	resetBtn.MouseEnter:Connect(function() resetBtn.BackgroundColor3 = Color3.fromRGB(50,50,78) end)
	resetBtn.MouseLeave:Connect(function() resetBtn.BackgroundColor3 = Color3.fromRGB(36,36,56) end)

	-- Apply logic
	local function clearPreview(tool)
		for _, v in pairs(tool:GetDescendants()) do
			if v:IsA("SurfaceAppearance") and v:GetAttribute("DEV_PREVIEW") then v:Destroy() end
		end
	end

	local function captureOriginal(tool)
		originalData = {}
		for _, v in pairs(tool:GetDescendants()) do
			if v:IsA("MeshPart") then
				originalData[v] = {v.TextureID, v.Color, v.Transparency}
			end
		end
	end

	local function applySkin(tool, meta)
		clearPreview(tool)

		local sa = meta.sa
		if sa then
			for _, part in pairs(tool:GetDescendants()) do
				if part:IsA("MeshPart") then
					-- remove any existing preview SA on this part
					for _, ch in pairs(part:GetChildren()) do
						if ch:IsA("SurfaceAppearance") and ch:GetAttribute("DEV_PREVIEW") then ch:Destroy() end
					end
					local saInst = Instance.new("SurfaceAppearance")
					saInst.ColorMap     = sa.color
					saInst.NormalMap    = sa.normal ~= "" and sa.normal or sa.color
					saInst.RoughnessMap = sa.roughness ~= "" and sa.roughness or sa.color
					saInst.MetalnessMap = sa.metalness ~= "" and sa.metalness or sa.color
					saInst:SetAttribute("DEV_PREVIEW", true)
					saInst.Parent = part
				end
			end

			if sa.customColor and sa.customParts then
				local col = Color3.fromRGB(sa.customColor[1], sa.customColor[2], sa.customColor[3])
				for _, v in pairs(tool:GetDescendants()) do
					if v:IsA("MeshPart") then
						for _, pName in ipairs(sa.customParts) do
							if v.Name == pName then
								v.Color = col
								v.Transparency = 0
							end
						end
					end
				end
			end
		end

		if meta.textureID ~= "" then
			for _, v in pairs(tool:GetDescendants()) do
				if v:IsA("MeshPart") and v:GetAttribute("SATP") then
					v.TextureID = "rbxassetid://" .. meta.textureID
				end
			end
		end

		local col = RARITY_COLORS[meta.rarity] or Color3.fromRGB(200,200,200)
		statusLbl.Text = "✔  " .. meta.display .. "   |   " .. meta.rarity:upper()
		statusLbl.TextColor3 = col
	end

	local function resetSkin(tool)
		clearPreview(tool)
		for part, orig in pairs(originalData) do
			if part and part.Parent then
				part.TextureID    = orig[1]
				part.Color        = orig[2]
				part.Transparency = orig[3]
			end
		end
		statusLbl.Text = "Reset to default"
		statusLbl.TextColor3 = Color3.fromRGB(110,110,150)
	end

	-- Tool detection
	local function onChar(char)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				currentTool = child
				captureOriginal(child)
				statusLbl.Text = "Equipped: " .. child.Name .. " — pick a skin"
				statusLbl.TextColor3 = Color3.fromRGB(110,110,150)
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child == currentTool then
				currentTool = nil
				originalData = {}
				statusLbl.Text = "No tool equipped"
				statusLbl.TextColor3 = Color3.fromRGB(110,110,150)
			end
		end)
		for _, v in pairs(char:GetChildren()) do
			if v:IsA("Tool") then currentTool = v; captureOriginal(v) end
		end
	end
	if lp.Character then onChar(lp.Character) end
	lp.CharacterAdded:Connect(onChar)

	-- Skin list builder
	local function buildSkins(weapon, filter)
		for _, v in pairs(skinScroll:GetChildren()) do
			if not v:IsA("UIListLayout") then v:Destroy() end
		end
		local skins = SKINS[weapon]
		if not skins then return end
		filter = (filter or ""):lower()

		local order = 0
		for _, s in ipairs(skins) do
			if filter == "" or s.display:lower():find(filter,1,true) or s.rarity:lower():find(filter,1,true) then
				order += 1
				local btn = Instance.new("TextButton", skinScroll)
				btn.Size = UDim2.new(1,-4,0,38)
				btn.BackgroundColor3 = Color3.fromRGB(26,26,38)
				btn.BorderSizePixel = 0
				btn.LayoutOrder = order
				btn.Text = ""
				btn.AutoButtonColor = false
				makeCorner(btn, 4)

				local bar = Instance.new("Frame", btn)
				bar.Size = UDim2.new(0,3,0.7,0)
				bar.Position = UDim2.new(0,0,0.15,0)
				bar.BackgroundColor3 = RARITY_COLORS[s.rarity] or Color3.fromRGB(200,200,200)
				bar.BorderSizePixel = 0
				makeCorner(bar, 2)

				local nameLbl = Instance.new("TextLabel", btn)
				nameLbl.Size = UDim2.new(1,-14,0.55,0)
				nameLbl.Position = UDim2.new(0,10,0,3)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Text = s.display
				nameLbl.TextColor3 = Color3.fromRGB(215,215,225)
				nameLbl.Font = Enum.Font.GothamBold
				nameLbl.TextSize = 11
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

				local rarLbl = Instance.new("TextLabel", btn)
				rarLbl.Size = UDim2.new(1,-14,0.38,0)
				rarLbl.Position = UDim2.new(0,10,0.6,0)
				rarLbl.BackgroundTransparency = 1
				rarLbl.Text = s.rarity:upper()
				rarLbl.TextColor3 = RARITY_COLORS[s.rarity] or Color3.fromRGB(150,150,150)
				rarLbl.Font = Enum.Font.Gotham
				rarLbl.TextSize = 9
				rarLbl.TextXAlignment = Enum.TextXAlignment.Left

				btn.MouseButton1Click:Connect(function()
					if not currentTool then
						statusLbl.Text = "⚠  Equip a weapon first!"
						statusLbl.TextColor3 = Color3.fromRGB(255,100,60)
						return
					end
					applySkin(currentTool, s)
				end)
				btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(36,36,54) end)
				btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(26,26,38) end)
			end
		end
	end

	-- Weapon list builder
	local function selectWeapon(w)
		selectedWeapon = w
		for name, btn in pairs(weaponBtns) do
			btn.BackgroundColor3 = name == w and Color3.fromRGB(50,50,90) or Color3.fromRGB(24,24,36)
		end
		buildSkins(w, searchBox.Text)
	end

	for i, w in ipairs(WEAPONS) do
		if SKINS[w] then
			local btn = Instance.new("TextButton", weaponScroll)
			btn.Size = UDim2.new(1,-4,0,28)
			btn.BackgroundColor3 = Color3.fromRGB(24,24,36)
			btn.BorderSizePixel = 0
			btn.LayoutOrder = i
			btn.Text = ""
			btn.AutoButtonColor = false
			weaponBtns[w] = btn
			makeCorner(btn, 4)

			local lbl = Instance.new("TextLabel", btn)
			lbl.Size = UDim2.new(1,-8,1,0)
			lbl.Position = UDim2.new(0,6,0,0)
			lbl.BackgroundTransparency = 1
			lbl.Text = w
			lbl.TextColor3 = Color3.fromRGB(190,190,210)
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 11
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextTruncate = Enum.TextTruncate.AtEnd

			btn.MouseButton1Click:Connect(function() selectWeapon(w) end)
			btn.MouseEnter:Connect(function()
				if selectedWeapon ~= w then btn.BackgroundColor3 = Color3.fromRGB(34,34,50) end
			end)
			btn.MouseLeave:Connect(function()
				if selectedWeapon ~= w then btn.BackgroundColor3 = Color3.fromRGB(24,24,36) end
			end)
		end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if selectedWeapon then buildSkins(selectedWeapon, searchBox.Text) end
	end)

	resetBtn.MouseButton1Click:Connect(function()
		if currentTool then resetSkin(currentTool) end
	end)

	UIS.InputBegan:Connect(function(inp, busy)
		if busy then return end
		if inp.KeyCode == Enum.KeyCode.K then
			guiVisible = not guiVisible
			main.Visible = guiVisible
		end
	end)

	if WEAPONS[1] then selectWeapon(WEAPONS[1]) end
end

do
	local cashFolder = Filter:FindFirstChild("SpawnedBread")
	local Remote = world.Evts:WaitForChild("CZDPZUS")

	local autoPickupMoney_Enabled = false
	local autoPickupMoney_Conn = nil
	local autoPickupMoney_Coroutine = nil

	local function AutoPickupMoneyMainLogic()
		if not cashFolder then
			warn("AutoPickupMoney Error: Cannot find SpawnedBread folder in Workspace.")
			return
		end

		if not Remote or not Remote:IsA("RemoteEvent") then
			warn("AutoPickupMoney Error: Cannot find required RemoteEvent at: ReplicatedStorage.Evts.CZDPZUS or it's not a RemoteEvent.")
			return
		end


	end
end

-- Spinbot
local Spinbot_Enabled = false
local Spinbot_Conn = nil
local Spinbot_Speed = (360) * 3549882432239999

local function ToggleSpinbot(boolean)
	Spinbot_Enabled = boolean
	if boolean then
		if Spinbot_Conn then return end
		-- Connect to the chosen update mode (RenderStepped/Heartbeat)
		Spinbot_Conn = state.Connect(__index(Services.RunService, Environment.DeveloperSettings.UpdateMode), function(dt)
			local char = LocalPlayer and LocalPlayer.Character
			local hrp = char and FindFirstChild(char, "HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				local step = dt or (1/60)
				local angle = math.rad(Spinbot_Speed * step)
				pcall(function()
					hrp.CFrame = (hrp.CFrame * CFrame.Angles(0, angle, 0))
				end)
			end
		end)
	else
		if Spinbot_Conn then
			pcall(function() Spinbot_Conn:Disconnect() end)
			Spinbot_Conn = nil
		end
	end
end

-- MELEE AURA
local MeleeAura_Enabled = false
local MeleeAura_Connection

local runAttackLoop do

	local remoteFunctionPath = "XMHH.2"
	local remoteEventPath = "XMHH2.2"

	local remote1 = world.Evts:WaitForChild(remoteFunctionPath)
	local remote2 = world.Evts:WaitForChild(remoteEventPath)

	local maxdist = 5

	local function Attack(target)
		if not (target and target:FindFirstChild("Head")) then return end

		local char = LocalPlayer.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")

		if not remote1 or not remote1:IsA("RemoteFunction") then
			warn("MeleeAura Error: Cannot find required RemoteFunction at: ReplicatedStorage.Evts." .. remoteFunctionPath .. " or it's not a RemoteFunction.")
			if not MeleeAura_Enabled then return end
			MeleeAura_Enabled = false
			if MeleeAura_Connection and MeleeAura_Connection.Connected then
				MeleeAura_Connection:Disconnect()
				MeleeAura_Connection = nil
			end
			return
		end
		if not remote2 or not remote2:IsA("RemoteEvent") then
			warn("MeleeAura Error: Cannot find required RemoteEvent at: ReplicatedStorage.Evts." .. remoteEventPath .. " or it's not a RemoteEvent.")
			if not MeleeAura_Enabled then return end
			MeleeAura_Enabled = false
			if MeleeAura_Connection and MeleeAura_Connection.Connected then
				MeleeAura_Connection:Disconnect()
				MeleeAura_Connection = nil
			end
			return
		end

		local arg1 = {
			[1] = "🍞",
			[2] = tick(),
			[3] = tool,
			[4] = "43TRFWX",
			[5] = "Normal",
			[6] = tick(),
			[7] = true
		}
		local success1, result = pcall(function()
			return remote1:InvokeServer(unpack(arg1))
		end)

		if not success1 then
			warn("MeleeAura Error: InvokeServer on " .. remoteFunctionPath .. " failed:", result)
			return
		end

		task.wait(0.1)

		local Handle = tool and (tool:FindFirstChild("WeaponHandle") or tool:FindFirstChild("Handle")) or (char and char:FindFirstChild("Right Arm"))
		local head = target:FindFirstChild("Head")

		if Handle and head and hrp then
			local arg2 = {
				[1] = "🍞",
				[2] = tick(),
				[3] = tool,
				[4] = "2389ZFX34",
				[5] = result,
				[6] = false,
				[7] = Handle,
				[8] = head,
				[9] = target,
				[10] = hrp.Position,
				[11] = head.Position
			}
			local success2, errorMsg2 = pcall(function()
				remote2:FireServer(unpack(arg2))
			end)
			if not success2 then
				warn("MeleeAura Error: FireServer on " .. remoteEventPath .. " failed:", errorMsg2)
			end
		end
	end

	runAttackLoop = function()
		return Services.RunService.RenderStepped:Connect(function()
			if not MeleeAura_Enabled then return end
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				for _, plr in ipairs(Services.Players:GetPlayers()) do
					if plr ~= LocalPlayer then
						local c = plr.Character
						local hrp2 = c and c:FindFirstChild("HumanoidRootPart")
						local hum = c and c:FindFirstChildOfClass("Humanoid")
						if hrp2 and hum then
							local dist = (hrp.Position - hrp2.Position).Magnitude
							if dist < maxdist and hum.Health > 15 and not c:FindFirstChildOfClass("ForceField") then
								Attack(c)
							end
						end
					end
				end
			end
		end)
	end
end

local function ToggleMeleeAura(boolean)
	if boolean then
		if MeleeAura_Enabled then return end
		MeleeAura_Enabled = true
		if MeleeAura_Connection and MeleeAura_Connection.Connected then
			MeleeAura_Connection:Disconnect()
		end
		MeleeAura_Connection = runAttackLoop()
	else
		if not MeleeAura_Enabled then return end
		MeleeAura_Enabled = false
		if MeleeAura_Connection and MeleeAura_Connection.Connected then
			MeleeAura_Connection:Disconnect()
			MeleeAura_Connection = nil
		end
	end
end
-- Mobile Helper
local function Hidebuttons()
	-- List of target asset IDs
	local targetIds = {
		"rbxassetid://9886659276",
		"rbxassetid://9886659406"
	}

	-- Convert list into a lookup table for faster checks
	local idLookup = {}
	for _, id in ipairs(targetIds) do
		idLookup[id] = true
	end

	-- Function to scan a ScreenGui for ImageLabels with matching IDs
	local function scanScreenGui(screenGui)
		for _, descendant in ipairs(screenGui:GetDescendants()) do
			if descendant:IsA("ImageLabel") then
				if idLookup[descendant.Image] then
					local parent = descendant.Parent
					if parent and parent:IsA("GuiObject") then
						parent.Visible = false
						print("Disabled parent of:", descendant:GetFullName(), "Image:", descendant.Image)
					else
						print("Found ImageLabel but parent is not a GuiObject:", descendant:GetFullName())
					end
				end
			end
		end
	end

	-- Scan all ScreenGuis inside CoreGui
	for _, gui in ipairs(Services.CoreGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			scanScreenGui(gui)
		end
	end
end

-- Billboard creation (safe adornee binding)
local function ensureBillboard(target, prefix)
	local adorneePart
	repeat
		adorneePart = target:FindFirstChild("HumanoidRootPart")
			or target:FindFirstChild("Head")
			or target:FindFirstChildWhichIsA("BasePart")
		if not adorneePart then task.wait(0.2) end
	until adorneePart or state.scriptUnloaded

	if not adorneePart then return nil end

	local name = prefix .. "_" .. target.Name .. "_ESPBillboard"

	local existing = ActiveBillboards[name]
	if existing and existing.Parent then
		existing.Adornee = adorneePart
		return existing
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = adorneePart
	billboard.Parent = Services.CoreGui

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Info"
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextSize = 15
	textLabel.TextWrapped = true
	textLabel.Font = Enum.Font.GothamSemibold
	textLabel.Text = target.Name
	textLabel.Parent = billboard

	return billboard
end

local function updateBillboardScale(billboard)
	if not billboard or not billboard.Adornee then return end

	local cam = workspace.CurrentCamera
	if not cam then return end

	local dist = (cam.CFrame.Position - billboard.Adornee.Position).Magnitude

	if dist > MAX_ESP_DISTANCE then
		billboard.Enabled = false
		return
	else
		billboard.Enabled = true
	end

	local width, height = 500, 100

	local scaleFactor = math.clamp(50 / dist, 0.4, 1.0)
	billboard.Size = UDim2.new(0, width * scaleFactor, 0, height * scaleFactor)

	-- Dynamic text size
	local textLabel = billboard:FindFirstChild("Info")
	if textLabel then
		local dynamicSize = math.clamp(14 * scaleFactor, 10, 14)
		textLabel.TextSize = dynamicSize
		textLabel.TextWrapped = true
	end
end

--// ATM
local function highlightATM(model, baseColor)
	if state.scriptUnloaded then return end
	local highlight = getHighlight(model, baseColor, "ATM")
	local billboard = ensureBillboard(model, "ATM")

	local textLabel = billboard and billboard:FindFirstChild("Info")
	if textLabel then
		local modelName = (model and model.Name) or "Unknown"
		textLabel.Text = modelName --.. " | ATM"
		textLabel.TextColor3 = baseColor -- cyan text
	end

	highlight.FillColor = baseColor
	highlight.OutlineColor = baseColor
end

-- Safes / Registers
local function highlightModel(model, baseColor, prefix)
	if state.scriptUnloaded then return end
	local highlight = getHighlight(model, baseColor, prefix)
	local billboard = ensureBillboard(model, prefix)
	local values = model and model:FindFirstChild("Values")
	local broken = values and values:FindFirstChild("Broken")

	local function update()
		local textLabel = billboard and billboard:FindFirstChild("Info")
		if not textLabel then return end
		local modelName = (model and model.Name) or "Unknown"
		if broken and broken.Value == true then
			highlight.FillColor = Color3.fromRGB(255,0,0)
			highlight.OutlineColor = Color3.fromRGB(255,0,0)
			textLabel.Text = modelName-- .. " | Broken"
			textLabel.TextColor3 = Color3.fromRGB(255,0,0)
			highlight.OutlineColor = Color3.fromRGB(255,0,0)
		else

			highlight.FillColor = baseColor
			textLabel.Text = modelName-- .. " | Intact"
			textLabel.TextColor3 = baseColor
			highlight.OutlineColor = baseColor
		end
	end

	update()
	if broken then broken:GetPropertyChangedSignal("Value"):Connect(update) end
end

-- Crates
local function highlightCrate(model)
	if state.scriptUnloaded then return end
	if model.Name ~= "C1" then return end
	local mesh = model:FindFirstChildWhichIsA("MeshPart")
	if not mesh then return end

	local baseColor = Color3.fromRGB(255,128,0)
	local prefix = "Crate"
	if mesh.Material == Enum.Material.Fabric then
		baseColor = Color3.fromRGB(0,255,0); prefix = "C1Green"
	elseif mesh.Material == Enum.Material.Metal then
		baseColor = Color3.fromRGB(255,0,0); prefix = "C1Red"
	end

	local highlight = getHighlight(model, baseColor, prefix)
	local billboard = ensureBillboard(model, prefix)
	if not billboard then return end

	local textLabel = billboard:FindFirstChild("Info")
	if textLabel then
		local modelName = (model and model.Name) or "Unknown"
		textLabel.Text = modelName-- .. " | " .. (prefix == "C1Red" and "Red Crate" or "Green Crate")
		textLabel.TextColor3 = baseColor
	end
	highlight.FillColor = baseColor
	highlight.OutlineColor = baseColor
end

--// Players
local function destroyPlayerESP(player)
	local pname = player and player.Name or ""
	for _, obj in ipairs(Services.CoreGui:GetChildren()) do
		if obj:IsA("BillboardGui") and obj.Name:find("Player_" .. pname) then obj:Destroy() end
		if obj:IsA("Highlight")   and obj.Name:find("Player_" .. pname) then obj:Destroy() end
	end
end

local function highlightCharacter(character, player)
	if state.scriptUnloaded or not character or not player then return end

	local isFriend = friendlyCheck(player)

	-- Check if player is on same team
	local isTeammate = false
	if Services.Teams and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
		isTeammate = true
	end

	-- Determine visibility (whitelisted/social-friends bypass occlusion)
	local isVisible = true
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if isFriend then
		isVisible = true -- bypass wall occlusion for friends/whitelisted
	else
		if hrp and cam then
			local dist = (cam.CFrame.Position - hrp.Position).Magnitude
			if dist > MAX_ESP_DISTANCE then
				isVisible = false
			end
		end
	end

	-- Color logic: Green for friends/whitelist (bypass), Blue for teammates, Red if not visible, Orange otherwise
	local color
	if isFriend then
		color = Color3.fromRGB(0, 200, 0)
	elseif not isVisible then
		color = Color3.fromRGB(255, 0, 0)
	elseif isTeammate then
		color = Color3.fromRGB(0, 150, 255)
	else
		color = Color3.fromRGB(255, 165, 0)
	end

	local labelPrefix = "Player"
	if isFriend then
		labelPrefix = "Friend"
	elseif isTeammate then
		labelPrefix = "Teammate"
	end

	-- Create highlight and billboard once
	local highlight = getHighlight(character, color, labelPrefix)
	local billboard = ensureBillboard(character, labelPrefix)
	local textLabel = billboard and billboard:FindFirstChild("Info")

	if textLabel then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local health = humanoid and math.floor(humanoid.Health) or 0

		local equippedTool = character:FindFirstChildWhichIsA("Tool")
		local toolName = equippedTool and equippedTool.Name or "None"

		-- Add friend indicator
		local friendIndicator = ""
		if isFriend then
			friendIndicator = " [FRIEND]"
		elseif isTeammate then
			friendIndicator = " [TEAM]"
		end

		-- Show name, health, and tool
		textLabel.Text = string.format("%s%s | HP: %d | Tool: %s", player.Name, friendIndicator, health, toolName)
	end

	-- Store in ActiveBillboards for pooled updates
	if billboard then
		ActiveBillboards[#ActiveBillboards + 1] = {
			player = player,
			character = character,
			billboard = billboard,
			textLabel = textLabel,
			highlight = highlight,
			baseColor = color,
			isFriend = isFriend,
			isTeammate = isTeammate,
			lastVisibilityCheck = 0,
			isVisible = true
		}
	end
end

local function isDealer(model)
	return model:IsA("Model") and (
		model.Name == "Dealer" or
			model.Name == "ArmoryDealer" or
			model.Name == "RebelDealer"
	)
end

local function checkDealerStock(itemName)
	for _, dealer in ipairs(world.Shopz:GetChildren()) do
		if isDealer(dealer) then
			local CurrentStocksFolder = dealer:FindFirstChild("CurrentStocks")
			local Value
			-- check if it is a value and is it a IntConstrainedValue
			if CurrentStocksFolder and CurrentStocksFolder:FindFirstChild(itemName) and CurrentStocksFolder[itemName]:IsA("IntConstrainedValue") then
				Value = CurrentStocksFolder:FindFirstChild(itemName).Value
				print("[AutoFarm] Dealer:", dealer.Name, "has", Value, "of item:", itemName)
			end
		end
	end
	return Value
end

local blacklistedSafeNames = {
	"SmallSafe_SW_11", "SmallSafe_FA_34", "SmallSafe_FA_35", "SmallSafe_FA_36",
	"MediumSafe_VC_21", "MediumSafe_VC_30", "MediumSafe_VC_38",
	"MediumSafe_HO_24", "MediumSafe_SEW_2", "MediumSafe_SEW_8",
	"MediumSafe_T_46","MediumSafe_T_45"
}

local function findNearestATM()
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local nearest, nearestDist
	for _, model in ipairs(world.ATMz:GetChildren()) do
		if model:IsA("Model") and model.Name:find("ATM") == 1 then
			local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			if primary then
				local d = (hrp.Position - primary.Position).Magnitude
				if not nearestDist or d < nearestDist then
					nearest, nearestDist = model, d
				end
			end
		end
	end
	return nearest, nearestDist
end

local function findNearestDealer()
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local nearest, nearestDist
	for _, dealer in ipairs(world.Shopz:GetChildren()) do
		if isDealer(dealer) then
			local main = dealer:FindFirstChild("MainPart") or dealer.PrimaryPart or dealer:FindFirstChildWhichIsA("BasePart")
			if main then
				local d = (hrp.Position - main.Position).Magnitude
				if not nearestDist or d < nearestDist then
					nearest, nearestDist = dealer, d
				end
			end
		end
	end
	return nearest, nearestDist
end

local function findNearestSafe()
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local nearest, nearestDist
	for _, model in ipairs(world.BM:GetChildren()) do
		if model:IsA("Model") and (model.Name:find("SmallSafe") or model.Name:find("MediumSafe")) then
			if tablefind(blacklistedSafeNames, model.Name) then
				continue
			end
			local values = model:FindFirstChild("Values")
			local broken = values and values:FindFirstChild("Broken")
			if broken and broken.Value then
				continue
			end
			local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
			if primary then
				local d = (hrp.Position - primary.Position).Magnitude
				if not nearestDist or d < nearestDist then
					nearest, nearestDist = model, d
				end
			end
		end
	end
	return nearest, nearestDist
end

-- Helper: attempt to buy an item at a dealer model using the game's shop remote
local function buyItemAtDealer(dealer, itemName, category)
	if not dealer then return false end
	local main = dealer:FindFirstChild("MainPart")
	if not main then return false end

	local remote = world.Evts:FindFirstChild("SSHPRMTE1") or world.Evts:FindFirstChild("SSHPRMTE")
	if not remote then
		for _, obj in ipairs(world.Evts:GetChildren()) do
			if obj:IsA("RemoteFunction") then
				local n = string.lower(obj.Name)
				if n:find("shop") or n:find("store") or n:find("ssh") then
					remote = obj
					break
				end
			end
		end
	end

	if not remote then
		pcall(function()
			Fluent:Notify({Title = "AutoFarm", Content = "Purchase remote not found", Duration = 4})
		end)
		return false
	end

	local ok, res = pcall(function()
		-- match example call structure: (dealerType, category, item, dealerMainPart, nil, true)
		return remote:InvokeServer("IllegalStore", category or "Misc", itemName, main, nil, true)
	end)
	if not ok then warn("[AutoFarm] purchase failed:", res) end
	return ok
end

-- Door collision toggle map
local DoorCollisionMap = {}
local function ToggleDoorCollision(disable)
	local doorsFolder = Map and Map:FindFirstChild("Doors")
	if not doorsFolder then return end
	if disable then
		for _, obj in ipairs(doorsFolder:GetDescendants()) do
			if obj:IsA("BasePart") then
				if DoorCollisionMap[obj] == nil then
					DoorCollisionMap[obj] = obj.CanCollide
				end
				pcall(function() obj.CanCollide = false end)
			end
		end
	else
		for part, original in pairs(DoorCollisionMap) do
			if part and part.Parent then
				pcall(function() part.CanCollide = original end)
			end
			DoorCollisionMap[part] = nil
		end
	end
end

-- Teleport helpers (max step + cooldown)
local lastTeleportTime = 0
local TELEPORT_MAX = 200
local TELEPORT_COOLDOWN = 15
local function snapToGroundPoint(pos)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
	local from = pos + Vector3.new(0,50,0)
	local result = workspace:Raycast(from, Vector3.new(0,-200,0), rayParams)
	if result then
		return Vector3.new(pos.X, result.Position.Y + 2, pos.Z)
	else
		return pos
	end
end

local function TeleportTowards(destPos, maxStep)
	if tick() - lastTeleportTime < TELEPORT_COOLDOWN then return false end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local cur = hrp.Position
	local dir = destPos - cur
	local d = dir.Magnitude
	if d <= 1 then return false end
	local step = math.min(maxStep or TELEPORT_MAX, d)
	local target = cur + dir.Unit * step
	target = snapToGroundPoint(target)
	pcall(function() hrp.CFrame = CFrame.new(target + Vector3.new(0,2,0)) end)
	lastTeleportTime = tick()
	return true
end

local autoFarmThread
local function AutoFarm(enable)
	if state.scriptUnloaded then return end
	if enable then
		ToggleDoorCollision(true)
		if autoFarmThread then return end
		autoFarmThread = task.spawn(function()
			while enable and not state.scriptUnloaded do
				local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local backpack = LocalPlayer:FindFirstChild("Backpack")
				if not hrp then task.wait(1); continue end

				-- inventory check
				local hasLockpick, hasCrowbar = false, false
				if backpack then
					for _, obj in ipairs(backpack:GetChildren()) do
						if obj:IsA("Tool") then
							if obj.Name == "Lockpick" then hasLockpick = true end
							if obj.Name == "Crowbar" then hasCrowbar = true end
						end
					end
				end
				for _, obj in ipairs(char:GetChildren()) do
					if obj:IsA("Tool") then
						if obj.Name == "Lockpick" then hasLockpick = true end
						if obj.Name == "Crowbar" then hasCrowbar = true end
					end
				end

				-- buy missing items
				if not hasLockpick or not hasCrowbar then
					local lockpickStock = checkDealerStock("Lockpick") or 0
					local crowbarStock = checkDealerStock("Crowbar") or 0
					local EssentialItems = math.min(lockpickStock, crowbarStock)
					if dealer and EssentialItems > 1 then
						local main = dealer:FindFirstChild("MainPart") or dealer.PrimaryPart or dealer:FindFirstChildWhichIsA("BasePart")
						if main then
							Pathfinder.SetDestination(main.Position)
							local t0 = tick()
							while Pathfinder.IsNavigating() and (tick() - t0) < 60 do task.wait(0.2) end
							-- If pathfinder stopped but didn't reach destination, attempt teleport fallback (eat ban if teleport)
							if hrp and (hrp.Position - main.Position).Magnitude > 8 then
								--TeleportTowards(main.Position, TELEPORT_MAX)
								task.wait(0.6)
								-- retry navigation once after teleport
								Pathfinder.SetDestination(main.Position)
								local t1 = tick()
								while Pathfinder.IsNavigating() and (tick() - t1) < 60 do task.wait(0.2) end
							end
							if not hasLockpick then buyItemAtDealer(dealer, "Lockpick", "Misc") end
							if not hasCrowbar then buyItemAtDealer(dealer, "Crowbar", "Melee") end
							task.wait(0.8)
						end
					else
						pcall(function()
							Fluent:Notify({Title = "AutoFarm", Content = "No dealer found nearby", Duration = 4})
						end)
						task.wait(2)
					end
				end

				-- go to the nearest safe (skip blacklisted names)
				local safe = findNearestSafe()
				if safe then
					local primary = safe.PrimaryPart or safe:FindFirstChildWhichIsA("BasePart")
					if primary then
						Pathfinder.SetDestination(primary.Position)
						local t0 = tick()
						while Pathfinder.IsNavigating() and (tick() - t0) < 90 do task.wait(0.2) end
						-- teleport fallback if stuck far from safe
						if hrp and (hrp.Position - primary.Position).Magnitude > 8 then
							TeleportTowards(primary.Position, TELEPORT_MAX)
							task.wait(0.6)
							Pathfinder.SetDestination(primary.Position)
							local t2 = tick()
							while Pathfinder.IsNavigating() and (tick() - t2) < 90 do task.wait(0.2) end
						end
						task.wait(1)
					end
				else
					task.wait(2)
				end

				task.wait(0.5)
			end
			autoFarmThread = nil
		end)
	else
		if autoFarmThread then
			pcall(task.cancel, autoFarmThread)
			autoFarmThread = nil
		end
		pcall(function() Pathfinder.CancelDestination() end)
		ToggleDoorCollision(false)
	end
end



local function ToggleAutoFarm(boolean)
	AutoFarm(boolean)
end

local function createDealerESP(model)
	local baseColor
	if model.Name == "Dealer" then
		baseColor = Color3.fromRGB(0, 200, 0)      -- green
	elseif model.Name == "ArmoryDealer" then
		baseColor = Color3.fromRGB(0, 128, 255)    -- blue
	elseif model.Name == "RebelDealer" then
		baseColor = Color3.fromRGB(255, 0, 255)    -- magenta
	end

	local highlight = getHighlight(model, baseColor, model.Name)
	local billboard = ensureBillboard(model, model.Name)
	local textLabel = billboard and billboard:FindFirstChild("Info")
	if textLabel then
		textLabel.Text = model.Name
		textLabel.TextColor3 = baseColor
	end
end

local function hasTracker(player)
	if not player or not player:IsA("Player") then return false, nil end
	local children = player:GetChildren()
	for i = 1, #children do
		local child = children[i]
		if typeof(child.Name) == "string" and string.sub(child.Name, -8) == "Tracker$" then
			local trackedPlayerName = string.sub(child.Name, 1, -9)
			if Services.Players:FindFirstChild(trackedPlayerName) then
				return true, trackedPlayerName
			end
		end
	end
	return false, nil
end

local function isStaff(player)
	if not player or not player:IsA("Player") then return false end

	if staffPlayers.groups then
		for groupID, roles in pairs(staffPlayers.groups) do
			local successRank, rank = pcall(function() return player:GetRankInGroup(groupID) end)
			if successRank and rank and rank > 0 then
				local successRole, roleName = pcall(function() return player:GetRoleInGroup(groupID) end)
				if successRole and roleName and roles[roleName] then
					return true, roleName, groupID
				end
			end
		end
	end

	if staffPlayers.users then
		for i = 1, #staffPlayers.users do
			if player.UserId == staffPlayers.users[i] then
				return true, "UserID", player.UserId
			end
		end
	end

	return false
end

local function checkCurrentStaff()
	local staffFound = {}
	local currentPlayers = Services.Players:GetPlayers()
	for i = 1, #currentPlayers do
		local player = currentPlayers[i]
		if player ~= LocalPlayer then 
			local isPlayerStaff, role, groupID = isStaff(player)
			local hasTrackers, trackedPlayer = hasTracker(player)

			if isPlayerStaff or hasTrackers then
				table.insert(staffFound, {
					Name = player.Name,
					Role = hasTrackers and "Tracker User" or role,
					GroupId = groupID,
					TrackedPlayer = trackedPlayer
				})
			end
		end
	end

	if #staffFound > 0 then
		Fluent:Notify({
			Title = "Staff Detected",
			Content = "Returning to Menu",
			Duration = 10,
		})
		world.Evts.RCTNMEUN:InvokeServer()
		return true
	end
	return false
end

--// Toggles
--// Staff Check
local function ToggleStaffCheck(boolean)
	if state.scriptUnloaded then return end
	if boolean then
		if not StaffCheckConn then
			StaffCheckConn = Services.Players.PlayerAdded:Connect(function(player)
				task.defer(function()
					local isPlayerStaff, role, groupID = isStaff(player)
					local hasTrackers, trackedPlayer = hasTracker(player)

					if isPlayerStaff or hasTrackers then
						Fluent:Notify({
							Title = "Staff Detected",
							Content = "Returning to Menu",
							Duration = 10,
						})
					end
				end)
			end)
		end

		checkCurrentStaff()
	else
		if StaffCheckConn then StaffCheckConn:Disconnect(); StaffCheckConn = nil end
	end
end
--// Invisibility
local Invisibility_Active = false
local Invisibility_Usable = true

do
	repeat task.wait() until game:IsLoaded();

	local srv = setmetatable({}, {__index = function(_, k) return (cloneref or function(...) return ... end)(game:GetService(k)) end})
	local ply = LocalPlayer
	local ctx = {Char = ply.Character or ply.CharacterAdded:Wait(), HRP = nil, HMND = nil, AnimTrack = nil}

	local function RefreshRefs() 
		ctx.Char = ply.Character
		ctx.HRP = ctx.Char and ctx.Char:FindFirstChild("HumanoidRootPart")
		ctx.HMND = ctx.Char and ctx.Char:FindFirstChildOfClass("Humanoid")
	end
	RefreshRefs()

	local camo = Instance.new("Animation"); camo.AnimationId = "rbxassetid://215384594"
	local ui = {HUD = Instance.new("ScreenGui"); WarnFrame = Instance.new("Frame")}
	ui.HUD.Name = "IWHUD"; ui.HUD.Parent = srv.CoreGui; ui.HUD.ResetOnSpawn = false
	ui.WarnFrame.Name = "WarningFrame"; ui.WarnFrame.Size = UDim2.new(0.225,0,0.116,0); ui.WarnFrame.Position = UDim2.new(0.387,0,0.823,0)
	ui.WarnFrame.BackgroundColor3 = Color3.new(0,0,0); ui.WarnFrame.ClipsDescendants = true; ui.WarnFrame.Parent = ui.HUD

	local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(0.1,0); c1.Parent = ui.WarnFrame
	local st = Instance.new("UIStroke"); st.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize; st.Thickness = 0.03
	st.Color = Color3.fromRGB(127,0,0); st.LineJoinMode = Enum.LineJoinMode.Round; st.Parent = ui.WarnFrame

	local img = Instance.new("ImageLabel"); img.Size = UDim2.new(1,0,1,0); img.Image = "rbxassetid://10466023737"
	img.ImageTransparency = 0.36; img.BackgroundColor3 = Color3.new(0,0,0); img.ImageColor3 = Color3.fromRGB(124,0,0)
	img.ScaleType = Enum.ScaleType.Tile; img.TileSize = UDim2.new(0.2,0,0.7,0); img.Parent = ui.WarnFrame

	local txt = Instance.new("TextLabel"); txt.BackgroundColor3 = Color3.new(0,0,0); txt.Size = UDim2.new(0.905,0,0.663,0)
	txt.Position = UDim2.new(0.044,0,0.169,0); txt.Text = "You are visible while in the air!"
	txt.Font = Enum.Font.MontserratBold; txt.TextScaled = true; txt.Parent = ui.WarnFrame
	local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0.1,0); c2.Parent = txt

	if ctx.Char and not ctx.Char:FindFirstChild("Torso") then Invisibility_Usable = false end

	local function CheckGrounded()
		return ctx.HMND and ctx.HMND:IsDescendantOf(workspace) and ctx.HMND.FloorMaterial ~= Enum.Material.Air
	end

	local function CacheAnim()
		if ctx.AnimTrack then pcall(function() ctx.AnimTrack:Stop() end) ctx.AnimTrack = nil end
		if ctx.HMND then
			local ok, res = pcall(function() return ctx.HMND:LoadAnimation(camo) end)
			if ok then ctx.AnimTrack = res ctx.AnimTrack.Priority = Enum.AnimationPriority.Action4 else ctx.AnimTrack = nil end
		else ctx.AnimTrack = nil end
	end

	local function DeactivateInvisibility()
		if not Invisibility_Active then return end
		Invisibility_Active = false
		if ctx.AnimTrack then pcall(function() ctx.AnimTrack:Stop() end) end
		if ctx.HMND then workspace.CurrentCamera.CameraSubject = ctx.HMND end
		if ctx.Char then for _, v in pairs(ctx.Char:GetDescendants()) do
				if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end
			end end
		ui.WarnFrame.Visible = false
	end

	local function ActivateInvisibility()
		if Invisibility_Active or not Invisibility_Usable then return end
		RefreshRefs()
		if not ctx.Char or not ctx.HMND or not ctx.HRP or not ctx.Char:FindFirstChild("Torso") then return end
		Invisibility_Active = true
		workspace.CurrentCamera.CameraSubject = ctx.HRP
		CacheAnim()
	end

	local function InvisibilityStep(dt)
		-- Validate character state
		if not ctx.Char 
			or not ctx.HMND 
			or not ctx.HRP 
			or not ctx.HMND:IsDescendantOf(workspace) 
			or ctx.HMND.Health <= 0 
		then
			ui.WarnFrame.Visible = false
			return
		end

		-- Warning visibility based on grounded check
		ui.WarnFrame.Visible = not CheckGrounded()

		-- Manual movement update
		if ctx.HMND.MoveDirection.Magnitude > 0 then
			ctx.HRP.CFrame = ctx.HRP.CFrame + ctx.HMND.MoveDirection * 12 * dt
		end

		-- Save initial states
		local InitialCFrame = ctx.HRP.CFrame
		local InitialCamOffset = ctx.HMND.CameraOffset
		local _, yawAngle = workspace.CurrentCamera.CFrame:ToOrientation()

		-- Apply pose transformations
		ctx.HRP.CFrame = CFrame.new(ctx.HRP.CFrame.Position) 
			* CFrame.fromOrientation(0, yawAngle, 0) 
			* CFrame.Angles(math.rad(90), 0, 0)

		ctx.HMND.CameraOffset = Vector3.new(0, 1.44, 0)

		-- Animation logic
		if ctx.AnimTrack then
			local success = pcall(function()
				if not ctx.AnimTrack.IsPlaying then
					ctx.AnimTrack:Play()
				end
				ctx.AnimTrack:AdjustSpeed(0)
				ctx.AnimTrack.TimePosition = 0.3
			end)
			if not success then
				CacheAnim()
			end
		elseif ctx.HMND and ctx.HMND.Health > 0 then
			CacheAnim()
		end

		-- Wait for render frame
		srv.RunService.RenderStepped:Wait()

		-- Revert transformations
		if ctx.HMND and ctx.HMND:IsDescendantOf(workspace) then
			ctx.HMND.CameraOffset = InitialCamOffset
		end
		if ctx.HRP and ctx.HRP:IsDescendantOf(workspace) then
			ctx.HRP.CFrame = InitialCFrame
		end

		-- Stop animation track
		if ctx.AnimTrack then
			pcall(function() ctx.AnimTrack:Stop() end)
		end

		-- Re-orient character to camera
		if ctx.HRP and ctx.HRP:IsDescendantOf(workspace) then
			local LookVec = workspace.CurrentCamera.CFrame.LookVector
			local FlatLook = Vector3.new(LookVec.X, 0, LookVec.Z).Unit
			if FlatLook.Magnitude > 0.1 then
				ctx.HRP.CFrame = CFrame.new(ctx.HRP.Position, ctx.HRP.Position + FlatLook)
			end
		end

		-- Apply transparency
		if ctx.Char then
			for _, v in pairs(ctx.Char:GetDescendants()) do
				if v:IsA("BasePart") and v.Transparency ~= 1 then
					v.Transparency = 0.5
				end
			end
		end
	end

	srv.RunService.Heartbeat:Connect(function(dt)
		if not Invisibility_Active or not Invisibility_Usable then
			if not Invisibility_Active and ctx.Char then
				for _, v in pairs(ctx.Char:GetDescendants()) do if v:IsA("BasePart") and v.Transparency == 0.5 then v.Transparency = 0 end end
			end
			ui.WarnFrame.Visible = false return
		end
		InvisibilityStep(dt)
	end)

	ply.CharacterAdded:Connect(function()
		if Invisibility_Active then DeactivateInvisibility() end
		if ctx.AnimTrack then pcall(function() ctx.AnimTrack:Stop() end) ctx.AnimTrack = nil end
		task.wait(); RefreshRefs()
		if not ctx.HMND then task.wait(0.5) RefreshRefs()
			if not ctx.HMND then Invisibility_Usable = false; DeactivateInvisibility()
				Fluent:Notify({Title="Invisibility Mode Warning", Text="Humanoid not found. Disabled.", Duration=5}) return end
		end
		if ctx.HMND.RigType ~= Enum.HumanoidRigType.R6 then
			Invisibility_Usable = false; DeactivateInvisibility()
			Fluent:Notify({Title="Invisibility Mode Warning", Text="R6 rig only. Disabled.", Duration=5}) return
		else Invisibility_Usable = true end
		if Invisibility_Usable and not Invisibility_Active and state.invEnabled then ActivateInvisibility() end
	end)

	ply.CharacterRemoving:Connect(function()
		if ctx.AnimTrack then pcall(function() ctx.AnimTrack:Stop() end) ctx.AnimTrack = nil end
		ui.WarnFrame.Visible = false
	end)

	_G.ActivateInvisibility = ActivateInvisibility
	_G.DeactivateInvisibility = DeactivateInvisibility
	_G.IsInvisibilityActive = function() return Invisibility_Active end

end

do
	function ToggleInvisibility(boolean)
		if state.scriptUnloaded then return end
		state.invEnabled = boolean
		if boolean then
			_G.ActivateInvisibility()
		else
			_G.DeactivateInvisibility()
		end
	end

	--// Safe ESP
	function ToggleSafeESP(boolean)
		if state.scriptUnloaded then return end
		if boolean then
			for _, child in ipairs(world.BM:GetDescendants()) do
				if child:IsA("Model") and (child.Name:find("SmallSafe") or child.Name:find("MediumSafe")) then
					highlightModel(child, Color3.fromRGB(0, 255, 0), "Safe") -- pass "Safe"
				end
			end
			if not safeConn then
				safeConn = world.BM.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and (desc.Name:find("SmallSafe") or desc.Name:find("MediumSafe")) then
						highlightModel(desc, Color3.fromRGB(0, 255, 0), "Safe") -- pass "Safe"
					end
				end)
			end
		else
			if safeConn then safeConn:Disconnect(); safeConn = nil end
			for _, obj in ipairs(Services.CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and obj.Name:find("Safe_") and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and obj.Name:find("Safe_") and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	--// Register ESP
	function ToggleRegisterESP(boolean)
		if state.scriptUnloaded then return end
		if boolean then
			for _, child in ipairs(world.BM:GetDescendants()) do
				if child:IsA("Model") and child.Name:find("Register") == 1 then
					highlightModel(child, Color3.fromRGB(0, 255, 0), "Register") -- pass "Register"
				end
			end
			if not registerConn then
				registerConn = world.BM.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and desc.Name:find("Register") == 1 then
						highlightModel(desc, Color3.fromRGB(0, 255, 0), "Register") -- pass "Register"
					end
				end)
			end
		else
			if registerConn then registerConn:Disconnect(); registerConn = nil end
			for _, obj in ipairs(Services.CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and obj.Name:find("Register_") and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and obj.Name:find("Register_") and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	--// ATM ESP
	function ToggleATMESP(boolean)
		if state.scriptUnloaded then return end
		if boolean then
			for _, child in ipairs(world.ATMz:GetDescendants()) do
				if child:IsA("Model") and child.Name:find("ATM") == 1 then
					highlightATM(child, Color3.fromRGB(0, 200, 255)) -- highlightATM now passes "ATM" internally
				end
			end
			if not atmConn then
				atmConn = world.ATMz.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and desc.Name:find("ATM") == 1 then
						highlightATM(desc, Color3.fromRGB(0, 200, 255))
					end
				end)
			end
		else
			if atmConn then atmConn:Disconnect(); atmConn = nil end
			for _, obj in ipairs(Services.CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and obj.Name:find("ATM_") and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and obj.Name:find("ATM_") and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	--// Dealer ESP
	function ToggleDealerESP(boolean)
		if state.scriptUnloaded then return end
		if boolean then
			-- highlight all existing dealers
			for _, obj in ipairs(world.Shopz:GetChildren()) do
				if isDealer(obj) then
					createDealerESP(obj)
				end
			end
			-- listen for new dealers spawning
			if not dealerConn then
				dealerConn = world.Shopz.ChildAdded:Connect(function(obj)
					if isDealer(obj) then
						createDealerESP(obj)
					end
				end)
			end
		else
			if dealerConn then dealerConn:Disconnect(); dealerConn = nil end
			for _, obj in ipairs(Services.CoreGui:GetChildren()) do
				if obj:IsA("BillboardGui") and (
					obj.Name:find("Dealer_") or
						obj.Name:find("ArmoryDealer_") or
						obj.Name:find("RebelDealer_")
					) then obj:Destroy() end
				if obj:IsA("Highlight") and (
					obj.Name:find("Dealer_") or
						obj.Name:find("ArmoryDealer_") or
						obj.Name:find("RebelDealer_")
					) then obj:Destroy() end
			end
		end
	end

	--// Crate ESP
	function ToggleCrateESP(boolean)
		if state.scriptUnloaded then return end
		if boolean then
			for _, model in ipairs(world.SPiles:GetDescendants()) do
				if model:IsA("Model") and model.Name == "C1" then
					highlightCrate(model)
				end
			end
			if not crateConn then
				crateConn = world.SPiles.DescendantAdded:Connect(function(desc)
					if desc:IsA("Model") and desc.Name == "C1" then
						highlightCrate(desc)
					end
				end)
			end
		else
			if crateConn then crateConn:Disconnect(); crateConn = nil end
			for _, obj in ipairs(Services.CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and (obj.Name:find("C1Red_") or obj.Name:find("C1Green_")) and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and (obj.Name:find("C1Red_") or obj.Name:find("C1Green_")) and obj.Name:find("_ESPHighlight")) then
					obj:Destroy()
				end
			end
		end
	end

	--// Player ESP
	function TogglePlayerESP(boolean)
		if state.scriptUnloaded then return end
		if boolean then
			for _, player in ipairs(Services.Players:GetPlayers()) do
				if player ~= LocalPlayer then
					if player.Character then
						highlightCharacter(player.Character, player)
					end
					charAddedConns[player] = player.CharacterAdded:Connect(function(char)
						highlightCharacter(char, player)
					end)
				end
			end
			playerAddedConn = Services.Players.PlayerAdded:Connect(function(player)
				charAddedConns[player] = player.CharacterAdded:Connect(function(char)
					highlightCharacter(char, player)
				end)
			end)
		else
			if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end
			for player, conn in pairs(charAddedConns) do
				if conn then conn:Disconnect() end
				charAddedConns[player] = nil
			end
			for _, obj in ipairs(Services.CoreGui:GetChildren()) do
				if (obj:IsA("BillboardGui") and obj.Name:find("Player_"))
					or (obj:IsA("Highlight") and obj.Name:find("Player_")) then
					obj:Destroy()
				end
			end
		end
	end

	function ToggleAutoLockpick(boolean)
		if state.scriptUnloaded then return end

		state.autoLPEnabled = boolean
		local DISTANCE_THRESHOLD = 10
		local GLOBAL_COOLDOWN = 0.35
		local lastClickTime = 0

		if boolean then
			if not state.autoLPThread then  -- correct guard
				state.autoLPThread = task.spawn(function()
					while state.autoLPEnabled and not state.scriptUnloaded do
						local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
						local humanoid = character and character:FindFirstChild("Humanoid")
						local hrp = character and character:FindFirstChild("HumanoidRootPart")
						local backpack = LocalPlayer:FindFirstChild("Backpack")

						if not humanoid or not hrp or humanoid.Health <= 0 then
							task.wait(0.2)
							continue
						end

						----------------------------------------------------
						-- find nearest valid (unbroken) safe or door
						----------------------------------------------------
						local nearestTarget, nearestDist, targetType
						-- Safes
						for _, model in ipairs(world.BM:GetChildren()) do
							if model:IsA("Model") and model.Name:find("Safe") then
								local values = model:FindFirstChild("Values")
								local broken = values and values:FindFirstChild("Broken")
								if broken and broken:IsA("BoolValue") and broken.Value then
									continue
								end
								local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
								if primary then
									local dist = (hrp.Position - primary.Position).Magnitude
									if not nearestDist or dist < nearestDist then
										nearestTarget, nearestDist, targetType = model, dist, "Safe"
									end
								end
							end
						end
						-- Doors
						for _, model in ipairs(world.Doors:GetChildren()) do
							if model:IsA("Model") then
								local values = model:FindFirstChild("Values")
								local broken = values and values:FindFirstChild("Broken")
								local open = values and values:FindFirstChild("Open")
								local locked = values and values:FindFirstChild("Locked")
								if (broken and broken.Value) or (open and open.Value) then
									continue
								end
								if locked and locked.Value then
									local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
									if primary then
										local dist = (hrp.Position - primary.Position).Magnitude
										if not nearestDist or dist < nearestDist then
											nearestTarget, nearestDist, targetType = model, dist, "Door"
										end
									end
								end
							end
						end

						----------------------------------------------------
						-- act on nearest target
						----------------------------------------------------
						if nearestTarget and nearestDist and nearestDist <= DISTANCE_THRESHOLD then
							local lockpickTool, crowbar
							if backpack then
								for _, tool in ipairs(backpack:GetChildren()) do
									if tool:IsA("Tool") and tool.Name == "Lockpick" then
										lockpickTool = tool
									elseif tool:IsA("Tool") and tool.Name == "Crowbar" then
										crowbar = tool
									end
								end
							end
							crowbar = crowbar or (character and character:FindFirstChild("Crowbar"))

							if targetType == "Safe" then
								-- Safe logic: prioritize Lockpick, fallback Crowbar
								if lockpickTool then
									if character:FindFirstChildWhichIsA("Tool") ~= lockpickTool and humanoid then
										humanoid:EquipTool(lockpickTool)
									end
									local lockpickGUI = ui.PlayerGui:WaitForChild("LockpickGUI", math.huge)
									local BarContainer = lockpickGUI:WaitForChild("MF",math.huge):WaitForChild("LP_Frame",math.huge):WaitForChild("Frames",math.huge)
									while state.autoLPEnabled and not state.scriptUnloaded
										and lockpickGUI and lockpickGUI.Parent
										and lockpickGUI.Enabled do
										BarContainer.B1.Bar.Size = UDim2.new(0,900,0,900)
										BarContainer.B2.Bar.Size = UDim2.new(0,900,0,900)
										BarContainer.B3.Bar.Size = UDim2.new(0,900,0,900)
										local now = os.clock()
										if (now - lastClickTime) > GLOBAL_COOLDOWN then
											mouse1click()
											lastClickTime = now
										end
										task.wait(0.05)
									end
								elseif crowbar then
									if character:FindFirstChildWhichIsA("Tool") ~= crowbar and humanoid then
										humanoid:EquipTool(crowbar)
									end
									local now = os.clock()
									if (now - lastClickTime) > GLOBAL_COOLDOWN then
										keypress(0x46)
										task.wait(0.1)
										keyrelease(0x46)
										lastClickTime = now
									end
								end
							elseif targetType == "Door" then
								-- Door logic: prioritize Crowbar, fallback Lockpick
								if crowbar then
									if character:FindFirstChildWhichIsA("Tool") ~= crowbar and humanoid then
										humanoid:EquipTool(crowbar)
									end
									local now = os.clock()
									if (now - lastClickTime) > GLOBAL_COOLDOWN then
										if keytap then
											keytap(0x46)
										else
											keypress(0x46)
											task.wait(0.1)
											keyrelease(0x46)
										end
										lastClickTime = now
									end
								elseif lockpickTool then
									if character:FindFirstChildWhichIsA("Tool") ~= lockpickTool and humanoid then
										humanoid:EquipTool(lockpickTool)
									end
									local lockpickGUI = ui.PlayerGui:WaitForChild("LockpickGUI", math.huge)
									local BarContainer = lockpickGUI:WaitForChild("MF",math.huge):WaitForChild("LP_Frame",math.huge):WaitForChild("Frames",math.huge)
									while state.autoLPEnabled and not state.scriptUnloaded
										and lockpickGUI and lockpickGUI.Parent
										and lockpickGUI.Enabled do
										BarContainer.B1.Bar.Size = UDim2.new(0,900,0,900)
										BarContainer.B2.Bar.Size = UDim2.new(0,900,0,900)
										BarContainer.B3.Bar.Size = UDim2.new(0,900,0,900)
										local now = os.clock()
										if (now - lastClickTime) > GLOBAL_COOLDOWN then
											mouse1click()
											lastClickTime = now
										end
										task.wait(0.05)
									end
								end
							end
						end

						task.wait(0.2)
					end
					state.autoLPThread = nil  -- self-clear on exit
				end)
			end
		else
			state.autoLPEnabled = false
			if state.autoLPThread then
				task.cancel(state.autoLPThread)
				state.autoLPThread = nil
			end
		end
	end

	local autoBreakThread

	function ToggleAutoBreakRegister(boolean)
		if state.scriptUnloaded then return end

		local autoBreakEnabled = boolean
		local DISTANCE_THRESHOLD = 10
		local GLOBAL_COOLDOWN = 0.35
		local lastClickTime = 0

		if boolean then
			if not autoBreakThread then
				autoBreakThread = task.spawn(function()
					while autoBreakEnabled and not state.scriptUnloaded do
						local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
						local humanoid = character and character:FindFirstChild("Humanoid")
						local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
						local isDead = (not humanoid) or humanoid.Health <= 0

						if humanoidRootPart and not isDead then
							local nearestRegister, nearestDist
							for _, model in ipairs(world.BM:GetChildren()) do
								if model:IsA("Model") and model.Name:find("Register_") then
									local values = model:FindFirstChild("Values")
									local broken = values and values:FindFirstChild("Broken")
									if broken and broken:IsA("BoolValue") and broken.Value then
										continue
									end

									local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
									if primary then
										local dist = (humanoidRootPart.Position - primary.Position).Magnitude
										if not nearestDist or dist < nearestDist then
											nearestRegister, nearestDist = model, dist
										end
									end
								end
							end

							if nearestRegister and nearestDist and nearestDist <= DISTANCE_THRESHOLD then
								local backpack = LocalPlayer:FindFirstChild("Backpack")
								if backpack and character and not isDead then
									local currentTool = character and character:FindFirstChildWhichIsA("Tool")
									local crowbar = (backpack and backpack:FindFirstChild("Crowbar")) or (character and character:FindFirstChild("Crowbar"))
									local fists = (backpack and backpack:FindFirstChild("Fists")) or (character and character:FindFirstChild("Fists"))
									local toolToUse

									if crowbar then
										toolToUse = crowbar
									elseif fists then
										toolToUse = fists
									end

									if toolToUse then
										if currentTool ~= toolToUse then
											humanoid:EquipTool(toolToUse)
										end

										local now = os.clock()
										if (now - lastClickTime) > GLOBAL_COOLDOWN then
											if keytap then
												keytap(0x46)
											elseif keypress and keyrelease then
												keypress(0x46)
												task.wait(0.1)
												keyrelease(0x46)
											end
											lastClickTime = now
										end
									else
										Fluent:Notify({
											Title = "Auto Break Register",
											Content = "Fists or Crowbar not found",
											Duration = 5,
										})
										task.wait(1)
									end
								end
							end
						else
							local backpack = LocalPlayer:FindFirstChild("Backpack")
							if backpack and not isDead then
								local fists = backpack:FindFirstChild("Fists")
								if fists then
									humanoid:EquipTool(fists)
								else
									Fluent:Notify({
										Title = "Auto Break Register",
										Content = "Fists or Crowbar not found",
										Duration = 5,
									})
									task.wait(1)
								end
							end
						end

						task.wait(0.2)
					end
				end)
			end
		else
			if autoBreakThread then
				task.cancel(autoBreakThread)
				autoBreakThread = nil
			end
		end
	end
end

do
	local InfStamina = false
	local targetFunc
	local originalFunc
	local hooked = false

	task.spawn(function() -- no reason for you fuckers to argue that this shit blocks the rest
		if getgc and debug.getinfo then
			for _,v in pairs(getgc(true)) do
				if type(v) == "function" then
					local info = debug.getinfo(v)
					if info.name == "S_Get" then
						targetFunc = v
						break
					end
				end
			end
		end
	end)

	function ToggleInfiniteStamina(boolean)
		InfStamina = boolean

		if targetFunc and hookfunction then
			if boolean and not hooked then
				originalFunc = hookfunction(targetFunc, function()
					return 100,100
				end)

				hooked = true

			elseif not boolean and hooked then
				hookfunction(targetFunc, originalFunc)
				hooked = false
			end
		end

		if not hookfunction then
			local oldFunc = targetFunc
			targetFunc = function(...)
				if boolean then
					return 100, 100
				else
					return oldFunc(...)
				end
			end
		end
	end
end

do
	local AntiFallDamage = false
	local targetFunc
	local originalFunc
	local hooked = false

	task.spawn(function()
		if getgc and debug.getinfo then
			for _, v in pairs(getgc(true)) do
				if type(v) == "function" then
					local info = debug.getinfo(v)
					if info.name == "Fall" then
						targetFunc = v
						break
					end
				end
			end
		end
	end)

	function ToggleAntiFallDamage(boolean)
		AntiFallDamage = boolean

		if targetFunc and hookfunction then
			if boolean and not hooked then
				originalFunc = hookfunction(targetFunc, function(x)
					-- Let the original Fall() run to track position,
					-- but when it would fire "FlllD", intercept it
					-- by running our own version that sends safe values
					local character = game.Players.LocalPlayer.Character
					if character then
						local hrp = character:FindFirstChild("HumanoidRootPart")
						local humanoid = character:FindFirstChild("Humanoid")
						if hrp and humanoid then
							local pos = hrp.CFrame.Position.Y
							-- Fire with PosA = PosB so Mag = 0
							-- Server receives the event, processes it,
							-- calculates Mag = 0 < MinHeight(15), skips damage
							local event = game.ReplicatedStorage.Events:FindFirstChild("__DFfDD")
							if event then
								event:FireServer("FlllD", pos, pos, false)
							end
						end
					end
					-- Don't call originalFunc — we handled it ourselves
					return
				end)
				hooked = true

			elseif not boolean and hooked then
				hookfunction(targetFunc, originalFunc)
				hooked = false
			end
		end
	end
end

local fastWalkEnabled = false
local fastWalkThread

local function ToggleFastWalk(boolean)
	if state.scriptUnloaded then return end
	fastWalkEnabled = boolean
	if boolean then
		if not fastWalkThread then
			fastWalkThread = task.spawn(function()
				local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
				local Humanoid = Character:WaitForChild("Humanoid")
				while fastWalkEnabled and Character and Humanoid and Humanoid.Parent do
					local delta = Services.RunService.Heartbeat:Wait()
					if Humanoid.MoveDirection.Magnitude > 0 then
						Character:TranslateBy(Humanoid.MoveDirection * delta * 10)
					end
				end
				fastWalkThread = nil
			end)
		end
	else
	end
end

local Noclipping

local function ToggleNoclip(boolean)
	if boolean then
		-- disconnect old loop if any
		if Noclipping then
			Noclipping:Disconnect()
			Noclipping = nil
		end

		-- start loop
		Noclipping = Services.RunService.Stepped:Connect(function()
			if state.scriptUnloaded then
				if Noclipping then
					Noclipping:Disconnect()
					Noclipping = nil
				end
				return
			end
			local character = LocalPlayer.Character
			if character then
				for _, part in pairs(character:GetDescendants()) do
					if part:IsA("BasePart") and part.CanCollide then
						part.CanCollide = false
					end
				end
			end
		end)
	else
		-- stop loop
		if Noclipping then
			Noclipping:Disconnect()
			Noclipping = nil
		end

		-- restore HRP collision
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CanCollide = true
		end
	end
end

local function UnloadESPs()
	-- Disconnect all connections first
	if safeConn then safeConn:Disconnect(); safeConn = nil end
	if registerConn then registerConn:Disconnect(); registerConn = nil end
	if atmConn then atmConn:Disconnect(); atmConn = nil end
	if crateConn then crateConn:Disconnect(); crateConn = nil end
	if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end

	for bb, conn in pairs(billboardConnections) do
		if conn then
			conn:Disconnect()
		end
		billboardConnections[bb] = nil
	end

	for player, conn in pairs(charAddedConns) do
		if conn then conn:Disconnect() end
		charAddedConns[player] = nil
	end

	-- Safely destroy all ESP objects
	local success, err = pcall(function()
		for _, obj in ipairs(Services.CoreGui:GetChildren()) do
			-- Check if the object is valid before trying to check its properties or destroy it
			if obj and obj.Parent then
				if obj:IsA("BillboardGui") and obj.Name:find("_ESPBillboard") then
					obj:Destroy()
				elseif obj:IsA("Highlight") and obj.Name:find("_ESPHighlight") then
					obj:Destroy()
				end
			end
		end
	end)

	if not success then
		warn("Error during ESP cleanup: " .. tostring(err))
	end
end

local periodicCleanupCoroutine = nil

local function cacheOptions()
	local cachedOptions = {}
	for _, option in ipairs(Options) do
		cachedOptions[option.Name] = option.Value
	end
	return cachedOptions
end

do cacheOptions() end

local function startPeriodicCleanup()
	if periodicCleanupCoroutine then return end
	periodicCleanupCoroutine = task.spawn(function()
		while not state.scriptUnloaded do
			task.wait(150)
			if state.scriptUnloaded then break end

			pcall(function()
				-- 1. Clear weapon caches to prevent memory leak and optimization failure over time
				Options.No_Recoil:SetValue(false)
				Options.No_Recoil:SetValue(true)


--[[
								Options.Player_ESP:SetValue(false)
					Options.Safe_ESP:SetValue(false)				
					Options.Register_ESP:SetValue(false)
					Options.ATM_ESP:SetValue(false)
					Options.Crate_ESP:SetValue(false)
					Options.Dealer_ESP:SetValue(false)

				local cachedOptions = cacheOptions()
				for name, value in pairs(cachedOptions) do
					Options[name]:SetValue(value)
				end
]]

				-- 2. Clear orphaned ESP Highlights and Billboards
--[[
				if type(ActiveHighlights) == "table" then
					for name, highlight in pairs(ActiveHighlights) do
						if not highlight.Adornee or not highlight.Adornee.Parent then
							if highlight.Parent then highlight:Destroy() end
							ActiveHighlights[name] = nil
						end
					end
				end
				
				if type(ActiveBillboards) == "table" then
					for index = #ActiveBillboards, 1, -1 do
						local entry = ActiveBillboards[index]
						if not entry.target or not entry.target.Parent then
							if entry.billboard and entry.billboard.Parent then entry.billboard:Destroy() end
							table.remove(ActiveBillboards, index)
						end
					end
				end
]]

				-- 3. Clear blacklists that might hold destroyed part references
				state.localBL = {}
				state.targetBL = {}
				state.combBL = {}
				state.visBL = {}

				-- 4. Re-evaluate local player features gracefully
				local char = LocalPlayer and LocalPlayer.Character
				if char then
					local tool = char:FindFirstChildOfClass("Tool")
					if tool and type(handleWeapon) == "function" then
						handleWeapon(tool)
					end
				end

				-- 5. Force garbage collection to free unused memory
				collectgarbage("collect")
			end)
		end
	end)
end
startPeriodicCleanup()

local Window

local MobileConn = {}
function cleanupScript()
	if state.scriptUnloaded then return end

	-- Disable active toggles first so loops and ESP cleanup can stop gracefully.
	ToggleInfiniteStamina(false)
	ToggleAutoLockpick(false)
	ToggleAutoBreakRegister(false)
	ToggleFastWalk(false)
	ToggleNoclip(false)
	ToggleInvisibility(false)
	ToggleFullbright(false)
	ToggleCameraFOV(false)
	state.rainbowESPEnabled= false
	ToggleSafeESP(false)
	ToggleRegisterESP(false)
	ToggleATMESP(false)
	ToggleDealerESP(false)
	ToggleCrateESP(false)
	TogglePlayerESP(false)
	ToggleStaffCheck(false)

	-- Mark script as unloaded to prevent any further action.
	state.scriptUnloaded = true

	-- Disconnect all service connections.
	for _, Connection in next, state.SrvConns do
		if Connection and Connection.Disconnect then
			Connection:Disconnect()
		end
	end

	if periodicCleanupCoroutine then
		pcall(function() task.cancel(periodicCleanupCoroutine) end)
		periodicCleanupCoroutine = nil
	end

	if safeConn then safeConn:Disconnect(); safeConn = nil end
	if registerConn then registerConn:Disconnect(); registerConn = nil end
	if atmConn then atmConn:Disconnect(); atmConn = nil end
	if crateConn then crateConn:Disconnect(); crateConn = nil end
	if dealerConn then dealerConn:Disconnect(); dealerConn = nil end
	if playerAddedConn then playerAddedConn:Disconnect(); playerAddedConn = nil end

	for player, conn in pairs(charAddedConns) do
		if conn then conn:Disconnect() end
		charAddedConns[player] = nil
	end

	for bb, conn in pairs(billboardConnections) do
		if conn then conn:Disconnect() end
		billboardConnections[bb] = nil
	end

	for _, c in ipairs(MobileConn) do
		if c and c.Disconnect then
			c:Disconnect()
		end
	end

	if Noclipping and Noclipping.Disconnect then
		Noclipping:Disconnect()
		Noclipping = nil
	end

	if state.Anim and state.Anim.Cancel then
		state.Anim:Cancel()
	end

	if state.OrigSens then
		__newindex(Services.UserInputService, "MouseDeltaSensitivity", state.OrigSens)
	end

	if Environment and Environment.FOVCircle and Environment.FOVCircle.Remove then
		pcall(function()
			Environment.FOVCircle:Remove()
		end)
	end

	if Window and Window.Destroy then
		pcall(function() Window:Destroy() end)
		Window = nil
	end

	if state.FluentMenu and state.FluentMenu.Destroy then
		pcall(function() state.FluentMenu:Destroy() end)
		state.FluentMenu = nil
	end

	UnloadESPs()

	-- Destroy any auxiliary UI objects created by the script.
	pcall(function()
		for _, obj in ipairs(Services.CoreGui:GetChildren()) do
			if obj.Parent then
				if (obj:IsA("BillboardGui") and obj.Name:find("_ESPBillboard"))
					or (obj:IsA("Highlight") and obj.Name:find("_ESPHighlight"))
					or (obj:IsA("ScreenGui") and (obj.Name == "IWHUD" or obj.Name == "CrosshairGui" or obj.Name == "AimbotToggleButton" or obj.Name:find("Fluent"))) then
					obj:Destroy()
				end
			end
		end
	end)

	if _G then
		_G.ActivateInvisibility = nil
		_G.DeactivateInvisibility = nil
		_G.IsInvisibilityActive = nil
	end

	getgenv().ExunysDeveloperAimbot = nil
end

--// UI

if state.IsOnMobile then
	Window = Fluent:CreateWindow({
		Title = "Federation Project CICADA-02",
		SubTitle = "by Zawtro",
		TabWidth = 160,
		Size = UDim2.fromOffset(302,239),
		Acrylic = false,
		Theme = "Darker",
		MinimizeKey = Enum.KeyCode.RightControl,
	})
else
	Window = Fluent:CreateWindow({
		Title = "Federation Project CICADA-02",
		SubTitle = "by Zawtro",
		TabWidth = 160,
		Size = UDim2.fromOffset(580,460),
		Acrylic = false,
		Theme = "Darker",
		MinimizeKey = Enum.KeyCode.RightControl,
	})
end

for _, gui in ipairs(Services.CoreGui:GetChildren()) do
	if gui:IsA("ScreenGui") then
		if gui:IsA("Frame") and gui.AbsoluteSize == Vector2.new(580,460) or gui.AbsoluteSize == Vector2.new(302,239) then
			state.FluentMenu = gui
			break
		end
	end
end --// Find Menu

local Tabs = {
	Information = Window:AddTab({Title = "Information", Icon = "info"}),
	Combat = Window:AddTab({Title = "Combat", Icon = "crosshair"}),
	Visuals = Window:AddTab({Title = "Visuals", Icon = "eye"}),
	Character = Window:AddTab({Title = "character", Icon = "users"}),
	Misc = Window:AddTab({Title = "Misc", Icon = "circle-ellipsis"}),
	Settings = Window:AddTab({Title = "Settings", Icon = "settings"}),
}


--// Information Tab
do
	Tabs.Information:AddParagraph({
		Title = "Federation Project CICADA-02",
		Content = "Federation CICADA-02. Private cheat | CLASSIFICATION: FEDERATOR ACCESS",
	})
	local info = identifyexecutor()
	local executorIdentity = getidentity() or "Unknown"
	Tabs.Information:AddParagraph({ Title = "Executor Name",
		Content = type(info) == "table" and tostring(info.Name or "Unknown Executor") or tostring(info).."| Level: "..tostring(executorIdentity).." | All executors that is level 3+ or above are supported."
	})

	Tabs.Information:AddParagraph({ Title = "Game Version",
		Content = game.PlaceVersion and tostring(game.PlaceVersion) or "Unknown Version".. " | The place version of this game is calculated dynamically."
	})

	Tabs.Information:AddParagraph({ Title = "Update Notes",
		Content = [[
			- Initial Release
			]]
	})
end
--// Combat Tab
do
	local CombatTab = Tabs.Combat
	local CombatSection = CombatTab:AddSection("Aimbot")

	CombatSection:AddToggle("Aimbot_Toggle", {
		Title = "Enable Aimbot",
		Default = false,
		Callback = function(Value)
			AimSettings.Enabled = Value
		end
	})

	CombatSection:AddToggle("Aimbot_TeamCheck", {
		Title = "Team Check",
		Default = AimSettings.TeamCheck,
		Callback = function(Value)
			AimSettings.TeamCheck = Value
		end
	})

	CombatSection:AddToggle("Aimbot_WallCheck", {
		Title = "Wall Check",
		Default = AimSettings.WallCheck,
		Callback = function(Value)
			AimSettings.WallCheck = Value
		end
	})

	CombatSection:AddDropdown("Aimbot_LockPart", {
		Title = "Lock Part",
		Values = {"Head", "HumanoidRootPart", "Torso"},
		Default = AimSettings.LockPart,
		Callback = function(Value)
			AimSettings.LockPart = Value
		end
	})

	CombatSection:AddSlider("Aimbot_Sensitivity", {
		Title = "Sensitivity",
		Description = "Changes how fast the aimbot locks onto the target.",
		Min = 0,
		Max = 1,
		Default = AimSettings.Sensitivity,
		Rounding = 2,
		Callback = function(Value)
			AimSettings.Sensitivity = tonumber(Value)
		end
	})

	CombatSection:AddToggle("Aimbot_BulletPrediction", {
		Title = "Bullet Prediction",
		Default = AimSettings.BulletPrediction,
		Callback = function(Value)
			AimSettings.BulletPrediction = Value
		end
	})

	CombatSection:AddToggle("Aimbot_PrioritizeDistance", {
		Title = "Prioritize Close Targets",
		Default = AimSettings.PrioritizeDistance,
		Callback = function(Value)
			AimSettings.PrioritizeDistance = Value
		end
	})

	local FOVSection = CombatTab:AddSection("FOV Circle")

	FOVSection:AddToggle("FOV_Toggle", {
		Title = "Draw FOV",
		Default = AimFOV.Visible,
		Callback = function(Value)
			AimFOV.Visible = Value
		end
	})

	FOVSection:AddToggle("FOV_Rainbow", {
		Title = "Rainbow FOV",
		Default = AimFOV.RainbowColor,
		Callback = function(Value)
			AimFOV.RainbowColor = Value
		end
	})

	FOVSection:AddSlider("FOV_Radius", {
		Title = "FOV Radius",
		Description = "Changes the size of the FOV circle.",
		Min = 10,
		Max = 300,
		Default = AimFOV.Radius,
		Rounding = 0,
		Callback = function(Value)
			AimFOV.Radius = Value
		end
	})

	FOVSection:AddSlider("FOV_Thickness", {
		Title = "FOV Thickness",
		Description = "Changes the line thickness.",
		Min = 0.5,
		Max = 5,
		Default = AimFOV.Thickness,
		Rounding = 1,
		Callback = function(Value)
			AimFOV.Thickness = Value
		end
	})

	FOVSection:AddColorpicker("FOV_Color", {
		Title = "FOV Color",
		Default = AimFOV.Color,
		Callback = function(Value)
			AimFOV.Color = Value
		end
	})

	FOVSection:AddColorpicker("FOV_LockedColor", {
		Title = "Locked Target Color",
		Default = AimFOV.LockedColor,
		Callback = function(Value)
			AimFOV.LockedColor = Value
		end
	})

	local AimbotSilentAimSection = CombatTab:AddSection("Silent Aim")

	AimbotSilentAimSection:AddToggle("Silent_Aim",{
		Title = "Silent Aim",
		Default = false,
		Callback = function(Value)
			ToggleSilentAim(Value)
		end
	})

	AimbotSilentAimSection:AddToggle("Silent_Aim_Friendly_Check",{
		Title = "Friendly Check",
		Default = true,
		Callback = function(Value)
			ToggleSilentAimFriendlyCheck(Value)
		end
	})

	AimbotSilentAimSection:AddToggle("Silent_Aim_Wall_Check",{
		Title = "Wall Check",
		Default = true,
		Callback = function(Value)
			ToggleSilentAimWallCheck(Value)
		end
	})

	AimbotSilentAimSection:AddSlider("Silent_Aim_Enemy_Distance",{
		Title = "Enemy Distance",
		Description = "Maximum distance for silent aim to target enemies.",
		Min = 10,
		Max = 3000,
		Default = 200,
		Rounding = 0,
		Callback = function(Value)
			ToggleSilentAimEnemyDistance(tonumber(Value))
		end
	})

	AimbotSilentAimSection:AddToggle("Silent_Aim_Debug_Trail",{
		Title = "Debug Trail",
		Default = true,
		Callback = function(Value)
			ToggleSilentAimDebugTrail(Value)
		end
	})

	local AimbotOther = CombatTab:AddSection("Other")

	CombatTab:AddToggle("No_Recoil",{
		Title = "No Recoil",
		Default = false,
		Callback = function(Value)
			ToggleNoRecoil(Value)
		end
	})
end
--// Visuals Tab
do
	local VisualsTab = Tabs.Visuals
	local VisualsWorldSection = VisualsTab:AddSection("World")

	if currentMode == "Casual" or currentMode == "MCasual" or currentMode == "Standard" then
		-- Shared toggles
		VisualsWorldSection:AddToggle("Safe_ESP", {
			Title = "Safe ESP",
			Default = false,
			Callback = function(Value)
				ToggleSafeESP(Value)
			end
		})

		VisualsWorldSection:AddToggle("Register_ESP", {
			Title = "Register ESP",
			Default = false,
			Callback = function(Value)
				ToggleRegisterESP(Value)
			end
		})

		VisualsWorldSection:AddToggle("ATM_ESP", {
			Title = "ATM ESP",
			Default = false,
			Callback = function(Value)
				ToggleATMESP(Value)
			end
		})

		VisualsWorldSection:AddToggle("Dealer_ESP", {
			Title = "Dealer ESP",
			Default = false,
			Callback = function(Value)
				ToggleDealerESP(Value)
			end
		})

		VisualsWorldSection:AddSlider("ESP_Distance",{
			Title = "ESP Distance",
			Description = "Set max ESP render distance",
			Min = 1,
			Max = 2000,
			Default = 300,
			Rounding = 1,
			Callback = function(value)
				MAX_ESP_DISTANCE = tonumber(value)
			end
		})

		if currentMode == "Standard" then
			VisualsWorldSection:AddToggle("Crate_ESP", {
				Title = "Crate ESP",
				Default = false,
				Callback = function(Value)
					ToggleCrateESP(Value)
				end
			})
		elseif currentMode == "Casual"  or currentMode == "MCasual" then
			VisualsWorldSection:AddParagraph({
				Title = "Crate ESP Unavailable",
				Content = "Crate ESP is only available in Standard mode.",
			})
		elseif currentMode == "Infection" or currentMode == "Brawl" then
			VisualsWorldSection:AddParagraph({
				Title = "Safe ESP Unavailable",
				Content = "Safe ESP is only available in Standard or Casual mode.",
			})

			VisualsWorldSection:AddParagraph({
				Title = "Register ESP Unavailable",
				Content = "Register ESP is only available in Standard or Casual mode.",
			})

			VisualsWorldSection:AddParagraph({
				Title = "ATM ESP Unavailable",
				Content = "ATM ESP is only available in Standard or Casual mode.",
			})

			VisualsWorldSection:AddParagraph({
				Title = "Dealer ESP Unavailable",
				Content = "Dealer ESP is only available in Standard or Casual mode.",
			})
		end
	else
		VisualsWorldSection:AddParagraph({
			Title = "ESPs Unavailable",
			Content = "Safe, Register, Dealer, and ATM ESP are only available in Casual and Standard modes.",
		})
	end

	local VisualsRenderingSection = VisualsTab:AddSection("Rendering")

	VisualsRenderingSection:AddToggle("Rainbow_ESP", {
		Title = "Rainbow ESP",
		Description = "Use rainbow coloring for ESP highlights and labels.",
		Default = false,
		Callback = function(Value)
			state.rainbowESPEnabled= Value
		end
	})

	VisualsRenderingSection:AddToggle("Fullbright", {
		Title = "Fullbright",
		Description = "Set lighting to bright values for easier visibility.",
		Default = false,
		Callback = function(Value)
			ToggleFullbright(Value)
		end
	})

	VisualsRenderingSection:AddToggle("Camera_FOV_Enable", {
		Title = "Camera FOV Override",
		Description = "Apply a custom camera field of view separately from the aimbot FOV circle.",
		Default = false,
		Callback = function(Value)
			ToggleCameraFOV(Value)
		end
	})

	VisualsRenderingSection:AddSlider("Camera_FOV_Value", {
		Title = "Camera FOV",
		Description = "Adjust the camera field of view.",
		Min = 50,
		Max = 120,
		Default = state.camFOVVal,
		Rounding = 0,
		Callback = function(Value)
			state.camFOVVal = tonumber(Value)
			if state.camFOVEnabled then ToggleCameraFOV(true) end
		end
	})

	local VisualsPlayersSection = VisualsTab:AddSection("Players")

	VisualsWorldSection:AddToggle("Hide_Names", {
		Title = "Hide Billboard Text",
		Default = false,
		Callback = function(Value)
			state.namesHidden = Value
			for _, gui in ipairs(Services.CoreGui:GetChildren()) do
				if gui:IsA("BillboardGui") and gui.Name:find("_ESPBillboard") then
					local info = gui:FindFirstChild("Info")
					if info then
						info.Visible = not Value
					end
				end
			end
		end
	})
	VisualsPlayersSection:AddToggle("Player_ESP", {
		Title = "Player ESP",
		Default = false,
		Callback = function(Value)
			TogglePlayerESP(Value)
		end
	})

	-- Whitelist is always honored; toggle removed per user request


	-- Persistent AddInput on the Visuals tab for adding whitelist entries by name
	local WhitelistInput = Tabs.Visuals:AddInput("Whitelist_Input", {
		Title = "Add Whitelist",
		Default = "",
		Placeholder = "Player name or prefix",
		Numeric = false,
		Finished = true,
		Callback = function(Value)
			local txt = tostring(Value or ""):match("^%s*(.-)%s*$")
			if txt == "" then
				Fluent:Notify({Title = "Whitelist", Content = "Enter a player name", Duration = 2})
				return
			end
			local matched = FixUsername(txt) or txt
			local success = AddToWhitelist(matched)
			if success then
				Fluent:Notify({Title = "Whitelist", Content = "Added "..matched.." to whitelist", Duration = 3})
			else
				Fluent:Notify({Title = "Whitelist", Content = "Player not found: "..matched, Duration = 3})
			end
		end
	})

	VisualsPlayersSection:AddButton({
		Title = "Clear Whitelist",
		Description = "Removes all players from whitelist",
		Callback = function()
			ClearWhitelist()
			Fluent:Notify({
				Title = "Whitelist",
				Content = "Whitelist cleared",
				Duration = 3,
			})
		end
	})
end

do
	local CharTab = Tabs.Character
	local CharSection = CharTab:AddSection("Character")

	CharSection:AddToggle("Infinite Stamina",{
		Title = "Infinite Stamina",
		Default = false,
		Callback = function(Value)
			ToggleInfiniteStamina(Value)
		end
	})

	CharSection:AddToggle("Anti Fall Damage",{
		Title = "Anti Fall Damage",
		Default = false,
		Callback = function(Value)
			ToggleAntiFallDamage(Value)
		end
	})

	CharSection:AddToggle("Invisibility",{
		Title = "Invisibility",
		Default = false,
		Callback = function(Value)
			ToggleInvisibility(Value)
		end
	})

	CharSection:AddToggle("Spinbot",{
		Title = "Spinbot",
		Default = false,
		Callback = function(Value)
			ToggleSpinbot(Value)
		end
	})

	CharSection:AddSlider("Spinbot_Speed", {
		Title = "Spinbot Speed",
		Description = "Rotation speed in degrees per second.",
		Min = 30,
		Max = 1440,
		Default = Spinbot_Speed,
		Rounding = 0,
		Callback = function(Value)
			Spinbot_Speed = tonumber(Value) or Spinbot_Speed
		end
	})

	CharSection:AddToggle("Fast_Walk",{
		Title = "Fast Walk",
		Default = false,
		Callback = function(Value)
			ToggleFastWalk(Value)
		end
	})

	CharSection:AddToggle("Noclip",{
		Title = "Noclip",
		Default = false,
		Callback = function(Value)
			ToggleNoclip(Value)
		end
	})


	local AutofarmSection = CharTab:AddSection("Autofarm")

	AutofarmSection:AddToggle("Auto_farm",{
		Title = "Auto Farm",
		Default = false,
		Callback = function(Value)
			ToggleAutoFarm(Value)
		end
	})

end

--// Misc Tab
do
	local MiscTab = Tabs.Misc
	local MiscSection = MiscTab:AddSection("Script")
	if currentMode == "Casual"  or currentMode == "MCasual" or currentMode == "Standard" or currentMode == "Infection" or currentMode == "Brawl" then
		MiscSection:AddButton({
			Title = "Return to Menu",
			Description = "Returns you to the main menu.",
			Callback = function()
				if not world.Evts:WaitForChild("RCTNMEUN",100000) then
					Fluent:Notify({
						Title = "Cannot return to Menu",
						Content = "Event not found or the path has been changed. Please use in-game button.",
						Duration = 5,
					})
				else
					Fluent:Notify({
						Title = "Returning to Menu",
						Content = "Returning, please wait...",
						Duration = 3,
					})
					world.Evts.RCTNMEUN:InvokeServer()
				end
			end
		});

		MiscSection:AddToggle("Staff Check",{
			Title = "Staff Check",
			Description = "Checks for staff members and tracked players.",
			Default = false,
			Callback = function(Value)
				ToggleStaffCheck(Value)
			end
		})

	end
	local MiscWorld = MiscTab:AddSection("World")
	if currentMode == "Casual"  or currentMode == "MCasual" or currentMode == "Standard" then

		MiscWorld:AddToggle("Auto_Lockpick",{
			Title = "Auto Open Safe",
			Default = false,
			Callback = function(Value)
				ToggleAutoLockpick(Value)
			end
		})

		MiscWorld:AddToggle("Auto_BreakReg",{
			Title = "Auto Break Register",
			Default = false,
			Callback = function(Value)
				ToggleAutoBreakRegister(Value)
			end
		})
	end
end

if state.IsOnMobile then
	Hidebuttons()
	local QuickCapture = Instance.new("TextButton")
	local UICorner = Instance.new("UICorner")
	QuickCapture.Name = RandomString(30)
	QuickCapture.Parent = Services.CoreGui
	QuickCapture.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	QuickCapture.BackgroundTransparency = 0.14
	QuickCapture.Position = UDim2.new(0.489, -128,-0.003, 2)
	QuickCapture.Size = UDim2.new(0, 32, 0, 33)
	QuickCapture.Font = Enum.Font.SourceSansBold
	QuickCapture.Text = "TG"
	QuickCapture.TextColor3 = Color3.fromRGB(255, 255, 255)
	QuickCapture.TextSize = 20
	QuickCapture.TextWrapped = true
	QuickCapture.ZIndex = 10
	QuickCapture.Draggable = true
	UICorner.Name = RandomString(30)
	UICorner.CornerRadius = UDim.new(0.5, 0)
	UICorner.Parent = QuickCapture
	MobileConn[1] =	QuickCapture.MouseButton1Click:Connect(function()
		if state.FluentMenu then
			state.FluentMenu.Enabled = not state.FluentMenu.Enabled
		end
	end)

end

--// Loop
task.spawn(function()
	-- Unified loop
	while not state.scriptUnloaded do

		ui.MainGui:WaitForChild("MFrame"):WaitForChild("DisplayNameLabel").Text = "[PROTECTED BY SCRIPT]"

		local currentTime = tick()
		updateCameraFOV()

		-- Billboard and ESP update
		if currentTime - lastUpdateTime > UPDATE_INTERVAL then
			lastUpdateTime = currentTime

			-- Refresh player ESP stats and rainbow highlights
			for index = #ActiveBillboards, 1, -1 do
				local entry = ActiveBillboards[index]
				if not entry or not entry.billboard or not entry.billboard.Parent then
					table.remove(ActiveBillboards, index)
				else
					-- Update whitelist / social-friend / teammate status
					local isWL = state.UserWL[entry.player.Name]
					local isSocialFriend = false
					pcall(function()
						if entry.player and entry.player:IsA("Player") then
							isSocialFriend = entry.player:IsFriendsWith(LocalPlayer.UserId)
						end
					end)
					local isFriend = (isWL or isSocialFriend)
					local isTeammate = Services.Teams and entry.player.Team and LocalPlayer.Team and entry.player.Team == LocalPlayer.Team

					-- Check visibility (optimized - only check every 0.5 seconds)
					local isVisible = true
					if currentTime - (entry.lastVisibilityCheck or 0) > 0.5 then
						entry.lastVisibilityCheck = currentTime
						local hrp = entry.character and entry.character:FindFirstChild("HumanoidRootPart")
						local cam = workspace.CurrentCamera
						if hrp and cam then
							-- If whitelisted/social-friend, bypass occlusion and mark visible
							if isFriend then
								isVisible = true
							else
								-- Distance check
								local dist = (cam.CFrame.Position - hrp.Position).Magnitude
								if dist > MAX_ESP_DISTANCE then
									isVisible = false
								else
									-- Simple visibility check (optimized)
									local params = RaycastParams.new()
									params.FilterType = Enum.RaycastFilterType.Exclude
									params.FilterDescendantsInstances = {LocalPlayer.Character}
									local dir = hrp.Position - cam.CFrame.Position
									local result = workspace:Raycast(cam.CFrame.Position, dir, params)
									isVisible = (not result) or result.Instance:IsDescendantOf(entry.character)
								end
							end
						end
						entry.isVisible = isVisible
					else
						isVisible = entry.isVisible or true
					end

					-- Update color based on friend/whitelist/visibility status
					local color
					if isFriend then
						color = Color3.fromRGB(0, 200, 0) -- Green for whitelisted/social friends
					elseif not isVisible then
						color = Color3.fromRGB(255, 0, 0) -- Red when not visible
					elseif isTeammate then
						color = Color3.fromRGB(0, 150, 255) -- Blue for teammates
					else
						color = Color3.fromRGB(66, 19, 255) -- Orange for enemies
					end

					-- Update highlight color
					if entry.highlight and entry.highlight.Parent then
						if state.rainbowESPEnabled then
							entry.highlight.FillColor = GetRainbowColor()
						else
							entry.highlight.FillColor = color
						end
					end

					local humanoid = entry.character and entry.character:FindFirstChildOfClass("Humanoid")
					local health = humanoid and math.floor(humanoid.Health) or 0
					local equippedTool = entry.character and entry.character:FindFirstChildWhichIsA("Tool")
					local toolName = equippedTool and equippedTool.Name or "None"

					-- Add friend indicator
					local friendIndicator = ""
					if isWL then
						friendIndicator = " [WHITELIST]"
					elseif isSocialFriend then
						friendIndicator = " [FRIEND]"
					elseif isTeammate then
						friendIndicator = " [TEAM]"
					end

					if entry.textLabel then
						entry.textLabel.Text = string.format("%s%s | HP: %d | Tool: %s", entry.player.Name, friendIndicator, health, toolName)
						if state.rainbowESPEnabled then
							entry.textLabel.TextColor3 = GetRainbowColor()
						else
							entry.textLabel.TextColor3 = color
						end
					end
				end
			end

			if state.rainbowESPEnabled then
				for _, highlight in pairs(ActiveHighlights) do
					if highlight and highlight.Parent then
						highlight.FillColor = GetRainbowColor()
					end
				end
			end

			for _, gui in ipairs(Services.CoreGui:GetChildren()) do
				if gui:IsA("BillboardGui") and gui.Name:find("_ESPBillboard") then
					if not gui.Adornee or not gui.Adornee.Parent then
						local targetName = gui.Name:match("^(.-)_ESPBillboard")
						local cleanName = targetName:match("^(.-)_%d+") or targetName
						local target = workspace:FindFirstChild(cleanName, true)
						if target then
							local adorneePart = target:FindFirstChild("HumanoidRootPart")
								or target:FindFirstChild("Head")
								or target:FindFirstChildWhichIsA("BasePart")
							gui.Adornee = adorneePart or nil
							gui.Enabled = adorneePart ~= nil
						else
							gui.Enabled = false
						end
					end
					local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
					if hrp and gui.Adornee then
						local dist = (hrp.Position - gui.Adornee.Position).Magnitude
						gui.Enabled = dist <= MAX_ESP_DISTANCE
						if gui.Enabled then updateBillboardScale(gui) end
					end
					local info = gui:FindFirstChild("Info")
					if info then
						info.Visible = not state.namesHidden
						if state.rainbowESPEnabled then
							info.TextColor3 = GetRainbowColor()
						end
					end
				end
			end
		end

		-- Unload handling
		if Fluent.Unloaded then
			cleanupScript()
			return
		end

		task.wait() -- frame
	end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()

SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("ustink4040Scripts")
SaveManager:SetFolder("ustink4040Scripts/Criminality")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)


Window:SelectTab(1)

SaveManager:LoadAutoloadConfig()

