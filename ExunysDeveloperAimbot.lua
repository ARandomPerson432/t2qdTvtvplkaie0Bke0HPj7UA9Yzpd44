if getgenv().ExunysDeveloperAimbot and getgenv().ExunysDeveloperAimbot.Exit then
	getgenv().ExunysDeveloperAimbot:Exit()
end

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
		OffsetToMoveDirection = false,
		OffsetIncrement = 15,
		Sensitivity = 0, -- Animation length (in seconds) before fully locking onto target
		Sensitivity2 = 3.5, -- mousemoverel Sensitivity
		LockMode = 1, -- 1 = CFrame; 2 = mousemoverel
		LockPart = "Head", -- Body part to lock on
		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false
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
	for _, Value in next, GetPlayers(Players) do
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

local ConvertVector = function(Vector)
	return Vector2new(Vector.X, Vector.Y)
end

local CancelLock = function()
	Environment.Locked = nil
	local FOVCircle = Environment.FOVCircle
	setrenderproperty(FOVCircle, "Color", Environment.FOVSettings.Color)
	__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)
	if Animation then
		Animation:Cancel()
	end
end

local GetClosestPlayer = function()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart
	local Pointer = IsOnMobile and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) or GetMouseLocation(UserInputService)

	if not Environment.Locked then
		RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000

		for _, Value in next, GetPlayers(Players) do
			local Character = __index(Value, "Character")
			local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")

			if Value ~= LocalPlayer 
				and not tablefind(Environment.Blacklisted, __index(Value, "Name")) 
				and Character 
				and FindFirstChild(Character, LockPart) 
				and Humanoid then

				local PartPosition = __index(Character[LockPart], "Position")
				local TeamCheckOption = Environment.DeveloperSettings.TeamCheckOption

				if Settings.TeamCheck and __index(Value, TeamCheckOption) == __index(LocalPlayer, TeamCheckOption) then
					continue
				end

				if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
					continue
				end

				local Vector, OnScreen, Distance = WorldToViewportPoint(Camera, PartPosition)
				Vector = ConvertVector(Vector)
				Distance = (Pointer - Vector).Magnitude

				if OnScreen and Distance < RequiredDistance then
					if Settings.WallCheck then
						local now = tick()
						visibilityCache[Character] = visibilityCache[Character] or {last = 0, visible = false}
						if now - visibilityCache[Character].last > VIS_INTERVAL then
							visibilityCache[Character].last = now
							-- run occlusion check only here
							local params = RaycastParams.new()
							params.FilterType = Enum.RaycastFilterType.Exclude
							params.FilterDescendantsInstances = {LocalPlayer.Character}
							local dir = PartPosition - Camera.CFrame.Position
							local result = workspace:Raycast(Camera.CFrame.Position, dir, params)
							visibilityCache[Character].visible = (not result) or result.Instance:IsDescendantOf(Character)
						end
						if not visibilityCache[Character].visible then
							continue
						end
					end
					RequiredDistance, Environment.Locked = Distance, Value
				end
			end
		end
	else
		local LockedChar = __index(Environment.Locked, "Character")
		if LockedChar then
			local pos = __index(__index(LockedChar, LockPart), "Position")
			if (Pointer - ConvertVector(WorldToViewportPoint(Camera, pos))).Magnitude > RequiredDistance then
				CancelLock()
			end
		else
			CancelLock()
		end
	end
end

local Load = function()
	OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")
	local Settings, FOVCircle, FOVSettings = Environment.Settings, Environment.FOVCircle, Environment.FOVSettings
	local Offset
	local AimbotButton 

	--// HYBRID CONTROL SETUP: Create controls based on platform

	if IsOnMobile then
		-- MOBILE: Create the toggle button
		AimbotButton = MainMobileGui:WaitForChild("TouchControlFrame",math.huge):WaitForChild("Gun"):WaitForChild("AimButton")

		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 8)
		Corner.Parent = AimbotButton

		ServiceConnections.AimbotButtonConnection = Connect(AimbotButton.MouseButton1Click, function()
			Running = not Running
			if not Running then
				CancelLock()
			end
			AimbotButton.Text = "Aimbot: " .. (Running and "ON" or "OFF")
			AimbotButton.BackgroundColor3 = Running and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(40, 40, 40)
		end)
	else
		-- DESKTOP: Use the existing keybind system
		ServiceConnections.InputBeganConnection = Connect(__index(UserInputService, "InputBegan"), function(Input)
			local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
			if Typing then return end
			if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
				if Toggle then
					Running = not Running
					if not Running then
						CancelLock()
					end
				else
					Running = true
				end
			end
		end)
		ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), function(Input)
			local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle
			if Toggle or Typing then return end
			if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
				Running = false
				CancelLock()
			end
		end)
	end
	--// END HYBRID CONTROL SETUP

	ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, Environment.DeveloperSettings.UpdateMode), function()
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
			if IsOnMobile then
				setrenderproperty(FOVCircle, "Position", Vector2new(CameraViewport.X / 2, CameraViewport.Y / 2))
			else
				setrenderproperty(FOVCircle, "Position", GetMouseLocation(UserInputService))
			end

			-- Ensure visible when enabled
			setrenderproperty(FOVCircle, "Visible", FOVSettings.Visible)
		else
			setrenderproperty(FOVCircle, "Visible", false)
		end

		if Running and Settings.Enabled then
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
					local LockedPosition = WorldToViewportPoint(Camera, LockedPosition_Vector3 + Offset)
					if Environment.Settings.LockMode == 2 then
						mousemoverel((LockedPosition.X - GetMouseLocation(UserInputService).X) / Settings.Sensitivity2, (LockedPosition.Y - GetMouseLocation(UserInputService).Y) / Settings.Sensitivity2)
					else
						if Settings.Sensitivity >= 0 then
							Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, LockedPosition_Vector3)})
							Animation:Play()
						else
							__newindex(Camera, "CFrame", CFramenew(Camera.CFrame.Position, LockedPosition_Vector3 + Offset))
						end
						__newindex(UserInputService, "MouseDeltaSensitivity", 0)
					end
					setrenderproperty(FOVCircle, "Color", FOVSettings.LockedColor)
				end
			end
		end
	end)
end

--// Typing Check
ServiceConnections.TypingStartedConnection = Connect(__index(UserInputService, "TextBoxFocused"), function()
	Typing = true
end)
ServiceConnections.TypingEndedConnection = Connect(__index(UserInputService, "TextBoxFocusReleased"), function()
	Typing = false
end)

--// Functions

function Environment.Exit(self) -- METHOD | ExunysDeveloperAimbot:Exit(<void>)
	-- Safely disconnect all active service connections
	for _, Connection in next, ServiceConnections do
		if Connection and Connection.Disconnect then
			Connection:Disconnect()
		end
	end

	-- Cancel any active aimbot animation
	if Animation and Animation.Cancel then
		Animation:Cancel()
	end

	-- Restore original mouse sensitivity
	if OriginalSensitivity then
		__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)
	end

	-- Remove the FOV drawings from the screen
	if self.FOVCircle and self.FOVCircle.Remove then
		self.FOVCircle:Remove()
	end

	--// MOBILE COMPATIBILITY CLEANUP ADDITION
	-- Find and remove the mobile aimbot button from the screen if it exists
	local AimbotButton = CoreGui:FindFirstChild("AimbotToggleButton")
	if AimbotButton and AimbotButton.Destroy then
		AimbotButton:Destroy()
	end
	--// END MOBILE COMPATIBILITY CLEANUP ADDITION

	-- Clear the global environment to fully wipe the script
	getgenv().ExunysDeveloperAimbot = nil
end

function Environment.Restart() -- ExunysDeveloperAimbot.Restart(<void>)
	for Index, _ in next, ServiceConnections do
		if ServiceConnections[Index] and ServiceConnections[Index].Disconnect then
			Disconnect(ServiceConnections[Index])
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

function Environment.GetClosestPlayer() -- ExunysDeveloperAimbot.GetClosestPlayer(<void>)
	GetClosestPlayer()
	local Value = Environment.Locked
	CancelLock()
	return Value
end

Environment.Load = Load -- ExunysDeveloperAimbot.Load()
setmetatable(Environment, {__call = Load})
