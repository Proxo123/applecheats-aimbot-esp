local Silent = {}

local Players = game:GetService("Players")
local ARSENAL_PLACE_ID = 286090429

local REMOTE_NAMES = {
	HitPart = true,
	Trail = true,
	CreateProjectile = true,
	Flames = true,
	Fire = true,
	ReplicateProjectile = true,
}

local state = {
	enabled = false,
	targetPart = nil,
	hooksInstalled = false,
	hookBusy = false,
}

local oldNamecall
local oldIndex

local function getConfig()
	return getgenv().AppleSilentConfig or {}
end

local function isActive()
	return state.enabled == true and state.targetPart ~= nil and state.targetPart.Parent ~= nil
end

local function fromExecutor()
	return checkcaller and checkcaller()
end

local function getHitbox()
	local part = state.targetPart
	if not part or not part.Parent then
		return nil
	end
	if part.Name == "Hitbox" then
		return part
	end
	if game.PlaceId == ARSENAL_PLACE_ID then
		local char = part:FindFirstAncestorOfClass("Model")
		if char then
			return char:FindFirstChild("Hitbox") or part
		end
	end
	return part
end

local function rayHitFor(part)
	local camera = workspace.CurrentCamera
	local pos = part.Position
	local origin = camera and camera.CFrame.Position or pos
	local diff = pos - origin
	local normal = diff.Magnitude > 0.01 and -diff.Unit or Vector3.new(0, 1, 0)
	return part, pos, normal
end

local function copyArgs(args)
	local out = {}
	for i = 1, #args do
		out[i] = args[i]
	end
	return out
end

local function patchRemoteArgs(name, args, hitbox)
	local pos = hitbox.Position
	if name == "HitPart" then
		args[1] = hitbox
		return true
	end
	if name == "Fire" then
		args[1] = pos
		return true
	end
	if name == "Flames" then
		args[1] = hitbox.CFrame
		args[2] = pos
		args[5] = pos
		return true
	end
	if name == "ReplicateProjectile" then
		if type(args[1]) == "table" then
			args[1][3] = pos
			args[1][4] = pos
			args[1][10] = pos
		end
		return true
	end
	if name == "CreateProjectile" then
		args[3] = pos
		args[4] = hitbox.CFrame
		args[10] = pos
		args[17] = pos
		args[18] = hitbox
		args[19] = pos
		return true
	end
	if name == "Trail" then
		if type(args[1]) == "table" and type(args[1][5]) == "string" then
			args[1][2] = pos
			args[1][6] = hitbox
		end
		return true
	end
	return false
end

local function installHooks()
	if state.hooksInstalled or not hookmetamethod then
		return
	end

	local mouse = Players.LocalPlayer:GetMouse()

	oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
		if state.hookBusy or fromExecutor() or not isActive() then
			return oldNamecall(self, ...)
		end

		local method = getnamecallmethod()
		local args = { ... }
		local hitbox = getHitbox()

		if method == "FireServer" and hitbox then
			local name = tostring(self)
			if REMOTE_NAMES[name] then
				local remoteArgs = copyArgs(args)
				if patchRemoteArgs(name, remoteArgs, hitbox) then
					state.hookBusy = true
					local ok, result = pcall(function()
						return self.FireServer(self, table.unpack(remoteArgs))
					end)
					state.hookBusy = false
					if ok then
						return result
					end
				end
			end
		end

		if hitbox and self == workspace then
			if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "findPartOnRay" then
				return rayHitFor(hitbox)
			end
			if method == "Raycast" then
				local origin = args[1]
				local direction = args[2]
				local params = args[3]
				if typeof(origin) ~= "Vector3" then
					origin = args[2]
					direction = args[3]
					params = args[4]
				end
				if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and direction.Magnitude > 0.01 then
					local newDir = (hitbox.Position - origin).Unit * direction.Magnitude
					state.hookBusy = true
					local ok, result = pcall(function()
						if typeof(args[1]) == "Vector3" then
							return oldNamecall(self, origin, newDir, params)
						end
						return oldNamecall(self, args[1], origin, newDir, params)
					end)
					state.hookBusy = false
					if ok then
						return result
					end
				end
			end
		end

		return oldNamecall(self, ...)
	end))

	if mouse then
		oldIndex = hookmetamethod(game, "__index", newcclosure(function(obj, index)
			if state.hookBusy or fromExecutor() or not isActive() or obj ~= mouse then
				return oldIndex(obj, index)
			end
			local target = getHitbox()
			if not target then
				return oldIndex(obj, index)
			end
			if index == "Target" or index == "target" then
				return target
			end
			if index == "Hit" or index == "hit" then
				return target.CFrame
			end
			return oldIndex(obj, index)
		end))
	end

	state.hooksInstalled = true
end

function Silent.UpdateConfig(patch)
	getgenv().AppleSilentConfig = getgenv().AppleSilentConfig or {}
	for k, v in pairs(patch) do
		getgenv().AppleSilentConfig[k] = v
	end
	state.enabled = patch.Enabled == true
end

function Silent.SetTarget(part)
	state.targetPart = part
end

function Silent.IsSupported()
	return hookmetamethod ~= nil and newcclosure ~= nil
end

function Silent.SetEnabled(stateOn)
	installHooks()
	state.enabled = stateOn == true
	return state.hooksInstalled
end

function Silent.Unload()
	state.enabled = false
	state.targetPart = nil
	getgenv().AppleSilentConfig = getgenv().AppleSilentConfig or {}
	getgenv().AppleSilentConfig.Enabled = false
end

installHooks()

return Silent
