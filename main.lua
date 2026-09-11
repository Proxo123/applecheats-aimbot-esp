local AppleCheats = loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/applecheats-lib/4cd32cc/AppleCheats.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Config = {
	Aimbot = false,
	AimbotFov = 120,
	AimbotSmooth = 8,
	AimbotTeamCheck = true,
	AimbotVisibleOnly = false,
	AimbotPart = "Head",
	AimbotKey = Enum.UserInputType.MouseButton2,
	BoxEsp = true,
	NameEsp = true,
	DistanceEsp = true,
	Snaplines = false,
	MaxDistance = 500,
	TeamCheck = true,
	ShowFov = true,
}

local Drawings = {}
local Connections = {}
local Unloaded = false

local function AddConnection(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(Connections, conn)
	return conn
end

local function IsTeammate(player)
	if not Config.TeamCheck and not Config.AimbotTeamCheck then
		return false
	end
	local localTeam = LocalPlayer.Team
	local targetTeam = player.Team
	if not localTeam or not targetTeam then
		return false
	end
	return localTeam == targetTeam
end

local function GetCharacter(player)
	return player.Character
end

local function GetRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetAimPart(character)
	return character and (character:FindFirstChild(Config.AimbotPart) or character:FindFirstChild("Head") or GetRoot(character))
end

local function WorldToViewport(point)
	return Camera:WorldToViewportPoint(point)
end

local function GetDistance(fromPos, toPos)
	return (fromPos - toPos).Magnitude
end

local function IsOnScreen(pos, screenPos)
	return screenPos.Z > 0 and pos.X > 0 and pos.X < Camera.ViewportSize.X and pos.Y > 0 and pos.Y < Camera.ViewportSize.Y
end

local function IsVisible(origin, targetPart)
	if not targetPart then
		return false
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character or LocalPlayer, Camera}
	local result = Workspace:Raycast(origin, (targetPart.Position - origin).Unit * GetDistance(origin, targetPart.Position), rayParams)
	if not result then
		return true
	end
	return result.Instance:IsDescendantOf(targetPart.Parent)
end

local function CreateDrawing(class, props)
	local drawing = Drawing.new(class)
	for k, v in pairs(props) do
		drawing[k] = v
	end
	table.insert(Drawings, drawing)
	return drawing
end

local FovCircle = CreateDrawing("Circle", {
	Visible = false,
	Thickness = 1,
	Color = Color3.fromRGB(255, 255, 255),
	Filled = false,
	NumSides = 64,
	Radius = Config.AimbotFov,
	Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2),
})

local EspCache = {}

local function GetEsp(player)
	if not EspCache[player] then
		EspCache[player] = {
			Box = CreateDrawing("Square", {
				Visible = false,
				Thickness = 1,
				Color = Color3.fromRGB(255, 255, 255),
				Filled = false,
			}),
			Name = CreateDrawing("Text", {
				Visible = false,
				Size = 14,
				Center = true,
				Outline = true,
				Color = Color3.fromRGB(255, 255, 255),
				Font = Drawing.Fonts.UI,
			}),
			Distance = CreateDrawing("Text", {
				Visible = false,
				Size = 13,
				Center = true,
				Outline = true,
				Color = Color3.fromRGB(200, 200, 200),
				Font = Drawing.Fonts.UI,
			}),
			Line = CreateDrawing("Line", {
				Visible = false,
				Thickness = 1,
				Color = Color3.fromRGB(255, 255, 255),
			}),
		}
	end
	return EspCache[player]
end

local function HideEsp(esp)
	esp.Box.Visible = false
	esp.Name.Visible = false
	esp.Distance.Visible = false
	esp.Line.Visible = false
end

local function GetClosestTarget()
	local closest
	local closestDist = Config.AimbotFov
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then
			continue
		end
		if IsTeammate(player) and Config.AimbotTeamCheck then
			continue
		end
		local character = GetCharacter(player)
		local aimPart = GetAimPart(character)
		local root = GetRoot(character)
		if not aimPart or not root then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			continue
		end
		local screenPos, onScreen = WorldToViewport(aimPart.Position)
		if not onScreen then
			continue
		end
		if Config.AimbotVisibleOnly and not IsVisible(Camera.CFrame.Position, aimPart) then
			continue
		end
		local dist2d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
		if dist2d < closestDist then
			closestDist = dist2d
			closest = aimPart
		end
	end

	return closest
end

local function UpdateEsp()
	local localRoot = GetRoot(GetCharacter(LocalPlayer))
	if not localRoot then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local esp = GetEsp(player)
		if player == LocalPlayer or (IsTeammate(player) and Config.TeamCheck) then
			HideEsp(esp)
			continue
		end

		local character = GetCharacter(player)
		local root = GetRoot(character)
		local head = character and character:FindFirstChild("Head")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not character or not root or not head or not humanoid or humanoid.Health <= 0 then
			HideEsp(esp)
			continue
		end

		local dist = GetDistance(localRoot.Position, root.Position)
		if dist > Config.MaxDistance then
			HideEsp(esp)
			continue
		end

		local headPos, headOn = WorldToViewport(head.Position + Vector3.new(0, 0.5, 0))
		local footPos, footOn = WorldToViewport(root.Position - Vector3.new(0, 3, 0))
		if not headOn or not footOn then
			HideEsp(esp)
			continue
		end

		local height = math.abs(footPos.Y - headPos.Y)
		local width = height * 0.55
		local x = headPos.X - width / 2
		local y = headPos.Y

		esp.Box.Visible = Config.BoxEsp
		esp.Box.Size = Vector2.new(width, height)
		esp.Box.Position = Vector2.new(x, y)

		esp.Name.Visible = Config.NameEsp
		esp.Name.Text = player.DisplayName
		esp.Name.Position = Vector2.new(headPos.X, y - 16)

		esp.Distance.Visible = Config.DistanceEsp
		esp.Distance.Text = string.format("[%dm]", math.floor(dist))
		esp.Distance.Position = Vector2.new(headPos.X, footPos.Y + 4)

		esp.Line.Visible = Config.Snaplines
		esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
		local linePos = WorldToViewport(root.Position)
		esp.Line.To = Vector2.new(linePos.X, linePos.Y)
	end
end

local function UpdateAimbot()
	FovCircle.Visible = Config.ShowFov and Config.Aimbot
	FovCircle.Radius = Config.AimbotFov
	FovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

	if not Config.Aimbot then
		return
	end

	local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	if Config.AimbotKey == Enum.UserInputType.MouseButton2 and not holding then
		return
	end

	local target = GetClosestTarget()
	if not target then
		return
	end

	local current = Camera.CFrame
	local goal = CFrame.new(current.Position, target.Position)
	local alpha = math.clamp(1 / math.max(Config.AimbotSmooth, 1), 0.05, 1)
	Camera.CFrame = current:Lerp(goal, alpha)
end

local Window = AppleCheats:CreateWindow({
	Title = "APPLE CHEATS",
	Subtitle = "menu is only usable in game",
	Keybind = Enum.KeyCode.Insert,
})

local AimbotTab = Window:AddTab("Aimbot")
local VisualsTab = Window:AddTab("Visuals")
local MiscTab = Window:AddTab("Misc")

local AimCol = AimbotTab:AddColumn("Aimbot:")
AimCol:AddCheckbox("Enabled", false, function(v)
	Config.Aimbot = v
end)
AimCol:AddCheckbox("Team check", true, function(v)
	Config.AimbotTeamCheck = v
end)
AimCol:AddCheckbox("Visible only", false, function(v)
	Config.AimbotVisibleOnly = v
end)
AimCol:AddCheckbox("Show FOV circle", true, function(v)
	Config.ShowFov = v
end)
AimCol:AddSlider("FOV radius", 20, 400, 120, function(v)
	Config.AimbotFov = v
end)
AimCol:AddSlider("Smoothness", 1, 20, 8, function(v)
	Config.AimbotSmooth = v
end)

local AimCol2 = AimbotTab:AddColumn("Target:")
AimCol2:AddLabel("Hold RMB to aim")
local PartToggles = {}
local function SetAimPart(part, toggles)
	Config.AimbotPart = part
	for name, toggle in pairs(toggles) do
		toggle:Set(name == part)
	end
end
PartToggles.Head = AimCol2:AddCheckbox("Head", true, function(v)
	if v then
		SetAimPart("Head", PartToggles)
	end
end)
PartToggles.HumanoidRootPart = AimCol2:AddCheckbox("HumanoidRootPart", false, function(v)
	if v then
		SetAimPart("HumanoidRootPart", PartToggles)
	end
end)
PartToggles.UpperTorso = AimCol2:AddCheckbox("UpperTorso", false, function(v)
	if v then
		SetAimPart("UpperTorso", PartToggles)
	end
end)

local EnvCol = VisualsTab:AddColumn("Player:")
EnvCol:AddCheckbox("Box", true, function(v)
	Config.BoxEsp = v
end)
EnvCol:AddCheckbox("Name", true, function(v)
	Config.NameEsp = v
end)
EnvCol:AddCheckbox("Distance", true, function(v)
	Config.DistanceEsp = v
end)
EnvCol:AddCheckbox("Snaplines", false, function(v)
	Config.Snaplines = v
end)
EnvCol:AddSlider("Max distance", 50, 2000, 500, function(v)
	Config.MaxDistance = v
end)

local VisMisc = VisualsTab:AddColumn("Misc:")
VisMisc:AddCheckbox("Team check", true, function(v)
	Config.TeamCheck = v
end)

local MiscCol = MiscTab:AddColumn(nil)
MiscCol:AddButton("Unload", function()
	if Unloaded then
		return
	end
	Unloaded = true
	for _, conn in ipairs(Connections) do
		conn:Disconnect()
	end
	for _, drawing in ipairs(Drawings) do
		drawing:Remove()
	end
	for _, esp in pairs(EspCache) do
		HideEsp(esp)
	end
	Window:Destroy()
	AppleCheats:Notify("unloaded", 3)
end)

AddConnection(RunService.RenderStepped, function()
	if Unloaded then
		return
	end
	Camera = Workspace.CurrentCamera
	UpdateEsp()
	UpdateAimbot()
end)

AddConnection(Players.PlayerRemoving, function(player)
	local esp = EspCache[player]
	if esp then
		HideEsp(esp)
		esp.Box:Remove()
		esp.Name:Remove()
		esp.Distance:Remove()
		esp.Line:Remove()
		EspCache[player] = nil
	end
end)

AppleCheats:Notify("applecheats aimbot + esp loaded", 4)
