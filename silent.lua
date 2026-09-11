local Silent = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local installed = false
local mainConn = nil

getgenv().AppleSilentConfig = getgenv().AppleSilentConfig or {
	Enabled = false,
	TeamCheck = true,
	VisibleCheck = true,
	Fov = 200,
}

local function getConfig()
	return getgenv().AppleSilentConfig
end

function Silent.UpdateConfig(patch)
	local cfg = getConfig()
	for k, v in pairs(patch) do
		cfg[k] = v
	end
end

function Silent.IsSupported()
	return getactors ~= nil and run_on_actor ~= nil and getgc ~= nil and hookfunction ~= nil
end

function Silent.Install()
	if installed then
		return true
	end
	if not Silent.IsSupported() then
		return false
	end
	local actors = getactors()
	if not actors or #actors < 1 then
		return false
	end
	local actor = actors[1]
	run_on_actor(actor, [=[
		local cfg = getgenv().AppleSilentConfig
		local Players = game:GetService("Players")
		local RunService = game:GetService("RunService")
		local target = nil

		local function isVisible(part)
			local camera = workspace.CurrentCamera
			if not camera or not part then
				return false
			end
			local origin = camera.CFrame.Position
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { Players.LocalPlayer.Character, camera }
			params.IgnoreWater = true
			local direction = part.Position - origin
			local result = workspace:Raycast(origin, direction, params)
			if not result then
				return true
			end
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			return model and Players:GetPlayerFromCharacter(model) ~= nil
		end

		local function getClosest()
			local lp = Players.LocalPlayer
			local camera = workspace.CurrentCamera
			if not lp or not camera then
				return nil
			end
			local closestDistance = cfg.Fov or 200
			local closest = nil
			local center = camera.ViewportSize * 0.5
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr == lp then
					continue
				end
				if cfg.TeamCheck and plr.Team and lp.Team and plr.Team == lp.Team then
					continue
				end
				local char = plr.Character
				if not char then
					continue
				end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				local hum = char:FindFirstChildOfClass("Humanoid")
				local head = char:FindFirstChild("Head")
				if not hrp or not hum or hum.Health <= 0 or not head then
					continue
				end
				local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
				if not onScreen then
					continue
				end
				local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
				if dist < closestDistance then
					if cfg.VisibleCheck and not isVisible(head) then
						continue
					end
					closestDistance = dist
					closest = head
				end
			end
			return closest
		end

		RunService.RenderStepped:Connect(function()
			if cfg.Enabled then
				target = getClosest()
			else
				target = nil
			end
		end)

		for _, fn in pairs(getgc(true)) do
			if type(fn) == "function" and islclosure(fn) then
				local ok, arity = pcall(function()
					return debug.info(fn, "a")
				end)
				if ok and arity == 2 then
					local upOk, upCount = pcall(function()
						return #debug.getupvalues(fn)
					end)
					local conOk, conCount = pcall(function()
						return #debug.getconstants(fn)
					end)
					local nameOk, name = pcall(function()
						return debug.info(fn, "n") or ""
					end)
					if upOk and upCount == 2 and conOk and conCount == 17 and nameOk and #name <= 10 then
						local old
						old = hookfunction(fn, function(p1, p2)
							if cfg.Enabled and target and target.Position then
								local mychar = Players.LocalPlayer.Character
								if mychar then
									local myHead = mychar:FindFirstChild("Head")
									if myHead then
										p1 = Ray.new(myHead.Position, target.Position - myHead.Position)
									end
								end
							end
							return old(p1, p2)
						end)
					end
				end
			end
		end
	]=])
	installed = true
	return true
end

function Silent.SetEnabled(state)
	local cfg = getConfig()
	cfg.Enabled = state == true
	if state and not installed then
		return Silent.Install()
	end
	return installed or not state
end

function Silent.Unload()
	getgenv().AppleSilentConfig.Enabled = false
	if mainConn then
		mainConn:Disconnect()
		mainConn = nil
	end
end

return Silent
