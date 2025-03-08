---# Services #---
local rs = game:GetService("RunService")
local rep = game:GetService("ReplicatedStorage")
local plrs = game:GetService("Players")

---# Modules #---
local combat = require(rep.CombatSystem)

---# Vectors #---
local offset_idle    = Vector3.new(0, 0.4, 0)
local offset_moving  = Vector3.new(0, 0.3, 0.35)
local offset_jumping = Vector3.new(0, -1.5, 0)
local offset_land    = Vector3.new(0, 2.5, 0)

---# Constants #---
local bobFreq = 10
local bobAmpli = 0.125
local tween_time = 0.1

---# Variables #---
local anim = Instance.new("Animation")
local offsetval = Instance.new("Vector3Value")
local camera = workspace.CurrentCamera
local player = plrs.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
offsetval.Value = humanoid.CameraOffset
anim.AnimationId = "rbxassetid://127529819850442"
local landanim = script.Parent.Humanoid:LoadAnimation(anim)

---# Main Code #---
local function getcamoffset()
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso then
		local rightOffset = torso.CFrame.RightVector * 0.2
		local upOffset = torso.CFrame.UpVector * 0.1
		local backwardOffset = torso.CFrame.LookVector * -1
		return rightOffset + upOffset + backwardOffset
	end
	return offset_idle
end

local function calculatetarget()
	local state = humanoid:GetState()
	local baseOffset = offset_idle

	if state == Enum.HumanoidStateType.Jumping then
		baseOffset = offset_jumping
	elseif state == Enum.HumanoidStateType.Landed then
		baseOffset = offset_land
		if not landanim.IsPlaying then
			landanim:Play()
			task.delay(1, function() landanim:Stop() end)
		end
	elseif humanoid.MoveDirection.Magnitude > 0 then
		baseOffset = offset_moving
		local bob = math.sin(tick() * bobFreq) * bobAmpli
		baseOffset = baseOffset + Vector3.new(0, bob, 0)
	end

	if combat.isAnimating(character) then
		return getcamoffset()
	end

	return baseOffset
end

rs.RenderStepped:Connect(function(delta)
	local target = calculatetarget()
	offsetval.Value = offsetval.Value:Lerp(target, delta / tween_time)
	humanoid.CameraOffset = offsetval.Value
end)
