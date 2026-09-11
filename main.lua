local LIBRARY_ID = "rbxassetid://7657867786"
local SILENT_URL = "https://raw.githubusercontent.com/Proxo123/applecheats-aimbot-esp/main/silent.lua"

local library = loadstring(game:GetObjects(LIBRARY_ID)[1].Source)("Pepsi's UI Library")
library.WorkspaceName = "AppleCheatsHub"

local Silent = loadstring(game:HttpGet(SILENT_URL))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Drawings = {}
local Connections = {}
local EspCache = {}
local Unloaded = false

local function AddConnection(signal, fn)
	table.insert(Connections, signal:Connect(fn))
end

local function flagRaw(name)
	local v = library.flags[name]
	if type(v) == "table" then
		if v.Options and v.Options.Value ~= nil then
			return v.Options.Value
		end
		if v.Value ~= nil then
			return v.Value
		end
	end
	return v
end

local function flagOn(name, default)
	local v = flagRaw(name)
	if v == nil then
		return default == true
	end
	return v == true
end

local function flagVal(name, default)
	local v = flagRaw(name)
	if v == nil then
		return default
	end
	return v
end

local function SyncSilent()
	Silent.UpdateConfig({
		Enabled = flagOn("SilentAim"),
		TeamCheck = flagOn("SilentTeamCheck", true),
		VisibleCheck = flagOn("SilentVisibleCheck", true),
		Fov = tonumber(flagVal("SilentFOV", 200)) or 200,
	})
	if flagOn("SilentAim") then
		if not Silent.SetEnabled(true) then
			library:Notify("silent needs getactors/run_on_actor", 4)
		end
	else
		Silent.SetEnabled(false)
	end
end

local function IsTeammate(player, useEspTeam)
	local check = useEspTeam and flagOn("ESPTeamCheck", true) or flagOn("AimTeamCheck", true)
	if not check then
		return false
	end
	local lt, tt = LocalPlayer.Team, player.Team
	if not lt or not tt then
		return false
	end
	return lt == tt
end

local function GetRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function GetAimPart(character)
	local partName = flagVal("AimPart", "Head")
	return character and (character:FindFirstChild(partName) or character:FindFirstChild("Head") or GetRoot(character))
end

local function IsVisible(origin, targetPart)
	if not targetPart then
		return false
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character or LocalPlayer, Camera }
	local dist = (targetPart.Position - origin).Magnitude
	local result = Workspace:Raycast(origin, (targetPart.Position - origin).Unit * dist, rayParams)
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
	Radius = 120,
})

local SilentFovCircle = CreateDrawing("Circle", {
	Visible = false,
	Thickness = 1,
	Color = Color3.fromRGB(255, 80, 80),
	Filled = false,
	NumSides = 64,
	Radius = 200,
})

local function GetEsp(player)
	if not EspCache[player] then
		EspCache[player] = {
			Box = CreateDrawing("Square", { Visible = false, Thickness = 1, Color = Color3.fromRGB(255, 255, 255), Filled = false }),
			Name = CreateDrawing("Text", { Visible = false, Size = 14, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), Font = Drawing.Fonts.UI }),
			Distance = CreateDrawing("Text", { Visible = false, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(200, 200, 200), Font = Drawing.Fonts.UI }),
			Line = CreateDrawing("Line", { Visible = false, Thickness = 1, Color = Color3.fromRGB(255, 255, 255) }),
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
	local fov = tonumber(flagVal("AimFOV", 120)) or 120
	local closest
	local closestDist = fov
	local center = Camera.ViewportSize * 0.5

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then
			continue
		end
		if IsTeammate(player, false) then
			continue
		end
		local character = player.Character
		local aimPart = GetAimPart(character)
		local root = GetRoot(character)
		if not aimPart or not root then
			continue
		end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			continue
		end
		local pos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
		if not onScreen or pos.Z <= 0 then
			continue
		end
		if flagOn("AimWallCheck") and not IsVisible(Camera.CFrame.Position, aimPart) then
			continue
		end
		local dist2d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
		if dist2d < closestDist then
			closestDist = dist2d
			closest = aimPart
		end
	end
	return closest
end

local function UpdateEsp()
	if not flagOn("ESPEnabled") then
		for _, player in ipairs(Players:GetPlayers()) do
			local esp = EspCache[player]
			if esp then
				HideEsp(esp)
			end
		end
		return
	end

	local localRoot = GetRoot(LocalPlayer.Character)
	if not localRoot then
		return
	end

	local maxDist = tonumber(flagVal("ESPMaxDistance", 500)) or 500

	for _, player in ipairs(Players:GetPlayers()) do
		local esp = GetEsp(player)
		if player == LocalPlayer or IsTeammate(player, true) then
			HideEsp(esp)
			continue
		end

		local character = player.Character
		local root = GetRoot(character)
		local head = character and character:FindFirstChild("Head")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not root or not head or not hum or hum.Health <= 0 then
			HideEsp(esp)
			continue
		end

		local dist = (localRoot.Position - root.Position).Magnitude
		if dist > maxDist then
			HideEsp(esp)
			continue
		end

		local headPos, headOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
		local footPos, footOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
		if not headOn or not footOn then
			HideEsp(esp)
			continue
		end

		local height = math.abs(footPos.Y - headPos.Y)
		local width = height * 0.55
		local x = headPos.X - width / 2
		local y = headPos.Y

		esp.Box.Visible = flagOn("ESPBox", true)
		esp.Box.Size = Vector2.new(width, height)
		esp.Box.Position = Vector2.new(x, y)

		esp.Name.Visible = flagOn("ESPName", true)
		esp.Name.Text = player.DisplayName
		esp.Name.Position = Vector2.new(headPos.X, y - 16)

		esp.Distance.Visible = flagOn("ESPDistance", true)
		esp.Distance.Text = string.format("[%dm]", math.floor(dist))
		esp.Distance.Position = Vector2.new(headPos.X, footPos.Y + 4)

		esp.Line.Visible = flagOn("ESPSnaplines")
		esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
		local linePos = Camera:WorldToViewportPoint(root.Position)
		esp.Line.To = Vector2.new(linePos.X, linePos.Y)
	end
end

local function UpdateAimbot()
	local aimFov = tonumber(flagVal("AimFOV", 120)) or 120
	local silentFov = tonumber(flagVal("SilentFOV", 200)) or 200

	FovCircle.Visible = flagOn("AimShowFOV") and flagOn("AimEnabled")
	FovCircle.Radius = aimFov
	FovCircle.Position = Camera.ViewportSize * 0.5

	SilentFovCircle.Visible = flagOn("SilentAim")
	SilentFovCircle.Radius = silentFov
	SilentFovCircle.Position = Camera.ViewportSize * 0.5

	if not flagOn("AimEnabled") then
		return
	end

	local mode = flagVal("AimMode", "Mouse2 Held")
	local holding = true
	if mode == "Mouse2 Held" then
		holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	elseif mode == "Mouse1 Held" then
		holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	end
	if not holding then
		return
	end

	local target = GetClosestTarget()
	if not target then
		return
	end

	local smooth = tonumber(flagVal("AimSmoothness", 8)) or 8
	local current = Camera.CFrame
	local goal = CFrame.new(current.Position, target.Position)
	local alpha = math.clamp(1 / math.max(smooth, 1), 0.05, 1)
	Camera.CFrame = current:Lerp(goal, alpha)
end

local window = library:CreateWindow({
	Name = "Apple Cheats",
	Themeable = { Info = "Pepsi UI", Credit = true },
})

local aimTab = window:CreateTab({ Name = "Aimbot" })
local espTab = window:CreateTab({ Name = "ESP" })
local miscTab = window:CreateTab({ Name = "Misc" })

local aimMain = aimTab:CreateSection({ Name = "Aimbot", Side = "Left" })
local aimTune = aimTab:CreateSection({ Name = "Tuning", Side = "Right" })
local silentSec = aimTab:CreateSection({ Name = "Silent", Side = "Left" })
local espMain = espTab:CreateSection({ Name = "ESP", Side = "Left" })
local espTune = espTab:CreateSection({ Name = "Display", Side = "Right" })
local miscSec = miscTab:CreateSection({ Name = "Script", Side = "Left" })

aimMain:AddToggle({ Name = "Enabled", Flag = "AimEnabled", Value = false })
aimMain:AddToggle({ Name = "Team Check", Flag = "AimTeamCheck", Value = true })
aimMain:AddToggle({ Name = "Wall Check", Flag = "AimWallCheck", Value = false })
aimMain:AddToggle({ Name = "Show FOV", Flag = "AimShowFOV", Value = true })
aimMain:AddDropdown({
	Name = "Activation",
	Flag = "AimMode",
	Value = "Mouse2 Held",
	List = { "Mouse2 Held", "Mouse1 Held", "Always" },
})
aimMain:AddDropdown({
	Name = "Target Part",
	Flag = "AimPart",
	Value = "Head",
	List = { "Head", "HumanoidRootPart", "UpperTorso" },
})

aimTune:AddSlider({ Name = "FOV", Flag = "AimFOV", Value = 120, Min = 20, Max = 400, Textbox = true })
aimTune:AddSlider({ Name = "Smoothness", Flag = "AimSmoothness", Value = 8, Min = 1, Max = 20, Textbox = true })

silentSec:AddToggle({ Name = "Silent Aim", Flag = "SilentAim", Value = false })
silentSec:AddToggle({ Name = "Team Check", Flag = "SilentTeamCheck", Value = true })
silentSec:AddToggle({ Name = "Visible Check", Flag = "SilentVisibleCheck", Value = true })
silentSec:AddSlider({ Name = "Silent FOV", Flag = "SilentFOV", Value = 200, Min = 50, Max = 500, Textbox = true })

espMain:AddToggle({ Name = "Enabled", Flag = "ESPEnabled", Value = false })
espMain:AddToggle({ Name = "Box", Flag = "ESPBox", Value = true })
espMain:AddToggle({ Name = "Name", Flag = "ESPName", Value = true })
espMain:AddToggle({ Name = "Distance", Flag = "ESPDistance", Value = true })
espMain:AddToggle({ Name = "Snaplines", Flag = "ESPSnaplines", Value = false })
espMain:AddToggle({ Name = "Team Check", Flag = "ESPTeamCheck", Value = true })

espTune:AddSlider({ Name = "Max Distance", Flag = "ESPMaxDistance", Value = 500, Min = 50, Max = 2000, Textbox = true })

miscSec:AddButton({
	Name = "Unload",
	Callback = function()
		if Unloaded then
			return
		end
		Unloaded = true
		Silent.Unload()
		for _, conn in ipairs(Connections) do
			conn:Disconnect()
		end
		for _, drawing in ipairs(Drawings) do
			drawing:Remove()
		end
		for _, esp in pairs(EspCache) do
			HideEsp(esp)
		end
		pcall(function()
			window:Destroy()
		end)
		library:Notify({ Text = "unloaded", Time = 3 })
	end,
})

AddConnection(RunService.RenderStepped, function()
	if Unloaded then
		return
	end
	Camera = Workspace.CurrentCamera
	SyncSilent()
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

if Silent.IsSupported() then
	library:Notify({ Text = "loaded - pepsi ui + silent ready", Time = 4 })
else
	library:Notify({ Text = "loaded - silent needs actor apis", Time = 4 })
end
