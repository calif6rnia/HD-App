---# Services #---
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---# Constants #---
local g = 9.8 -- gravity
local mass = 7.834 -- ball mass
local bounce_damp = 0.8
local max_bounces = 5 -- max bounce

---# Variables #---
local active_conn = nil

---# Module #---
local physics = {}

---# Helper Funcs #---

local function calc_trajectory(init_velo, cos_theta, sin_theta, time) -- used to help calculate the trajectory path for the ball
	local x = init_velo * cos_theta * time
	local y = (init_velo * sin_theta * time) - (0.5 * g * time^2)
	return x, y
end


---# Physics #---

-- this is the main physics code

local function calculate_path(init_velo, angle, look_vec, base_mult, length_mult, speed, start_time, origin, ground_lvl)
	local path = {}
	local theta = math.rad(angle)
	local cos_theta, sin_theta = math.cos(theta), math.sin(theta)
	local vert_velo = init_velo * sin_theta
	local bounce_count = 0
	local max_bounces = 5
	local bounce_damp = 0.8
	local elapsed_time = 0

	while bounce_count <= max_bounces do
		elapsed_time = (tick() - start_time) * speed
		local z, y = calc_trajectory(init_velo, cos_theta, sin_theta, elapsed_time)
		local forward_vec = look_vec.Unit * z * (length_mult or 1) * base_mult
		local target_pos = origin + forward_vec + Vector3.new(0, y, 0)

		if target_pos.Y <= ground_lvl then
			bounce_count = bounce_count + 1
			if bounce_count > max_bounces then break end

			angle = 16
			sin_theta = math.sin(math.rad(angle))
			vert_velo = -vert_velo * bounce_damp
			start_time = tick()
			origin = Vector3.new(target_pos.X, ground_lvl, target_pos.Z)
		end

		table.insert(path, target_pos)
	end

	return path
end

function physics:animate(ball, init_velo, angle, force, distance, base_mult, look_vec, length_mult, speed, dont_adjust) -- this is the function used the most. It pretty much just moves the ball in an arc most of the time but is easy modifable and adjustable for all times of movement
	self:stop(ball) 
	self._stop_anim = false
	local start_time = tick()
	local origin = ball.Position
	local theta = math.rad(angle)
	local cos_theta, sin_theta = math.cos(theta), math.sin(theta)
	local vert_velo = init_velo * sin_theta
	local ground_lvl = workspace:WaitForChild("Detection").Position.Y + 35.3
	local bounce_count = 0
	local net_debounce = false
	local debounce_time = 0.2
	speed = speed or 1

	active_conn = RunService.Heartbeat:Connect(function(delta_time)
		if self._stop_anim then
			active_conn:Disconnect()
			active_conn = nil
			return
		end

		local elapsed_time = (tick() - start_time) * speed
		local z, y = calc_trajectory(init_velo, cos_theta, sin_theta, elapsed_time)
		local forward_vec = look_vec.Unit * z * (length_mult or 1) * base_mult
		local target_pos = origin + forward_vec + Vector3.new(0, y, 0)

		if target_pos.Y <= ground_lvl then
			bounce_count = bounce_count + 1
			if bounce_count > max_bounces then
				self:stop(ball)
				return
			end

			angle = 16
			sin_theta = math.sin(math.rad(angle))
			vert_velo = -vert_velo * bounce_damp
			start_time = tick()
			origin = Vector3.new(target_pos.X, ground_lvl, target_pos.Z)
		end

		ball.Position = target_pos
	end)
end

function physics:drop(ball, spawn_pos, fastfall, fastfall_mult) -- drops the ball from a set position
	self:stop(ball)
	self._stop_anim = false
	local ground_lvl = workspace:WaitForChild("Detection").Position.Y + 35.3
	local start_time = tick()
	local start_height = spawn_pos.Y
	fastfall_mult = fastfall and (fastfall_mult or 3) or 1
	ball.Position = spawn_pos

	active_conn = RunService.Heartbeat:Connect(function(delta_time)
		if self._stop_anim then
			active_conn:Disconnect()
			active_conn = nil
			return
		end

		local elapsed_time = tick() - start_time
		local new_y = start_height - (0.5 * g * fastfall_mult * elapsed_time^2)

		if new_y <= ground_lvl then
			ball.Position = Vector3.new(spawn_pos.X, ground_lvl, spawn_pos.Z)
			self:stop(ball)
		else
			ball.Position = Vector3.new(spawn_pos.X, new_y, spawn_pos.Z)
		end
	end)
end

function physics:sendup(ball, height_offset, init_velo) -- sends the ball up from the current position
	self:stop(ball)
	self._stop_anim = false
	local ground_lvl = workspace:WaitForChild("Detection").Position.Y + 35.3
	local start_time = tick()
	local start_pos = ball.Position
	local target_height = start_pos.Y + height_offset

	active_conn = RunService.Heartbeat:Connect(function(delta_time)
		if self._stop_anim then
			active_conn:Disconnect()
			active_conn = nil
			return
		end

		local elapsed_time = tick() - start_time
		local current_height = start_pos.Y + (init_velo * elapsed_time) - (0.5 * g * elapsed_time^2)

		if current_height >= target_height then
			ball.Position = Vector3.new(start_pos.X, target_height, start_pos.Z)
			self:drop(ball, ball.Position, true)
		elseif current_height <= ground_lvl then
			ball.Position = Vector3.new(start_pos.X, ground_lvl, start_pos.Z)
			self:stop(ball)
		else
			ball.Position = Vector3.new(start_pos.X, current_height, start_pos.Z)
		end
	end)
end

function physics:arcwithfixedxdistance(ball, fixed_dist, peak_height, init_velo) -- sends the ball with a fixed distance and an always an arc, rarely used
	self:stop(ball)
	self._stop_anim = false
	local start_time = tick()
	local origin = ball.Position
	local ground_lvl = workspace:WaitForChild("Detection").Position.Y + 35.3
	local theta = math.asin((2 * peak_height * g) / (init_velo^2)) / 2
	local cos_theta, sin_theta = math.cos(theta), math.sin(theta)
	local total_time = (2 * init_velo * sin_theta) / g
	local horiz_speed = fixed_dist / total_time

	active_conn = RunService.Heartbeat:Connect(function(delta_time)
		if self._stop_anim then
			active_conn:Disconnect()
			active_conn = nil
			return
		end

		local elapsed_time = tick() - start_time
		if elapsed_time > total_time then
			ball.Position = Vector3.new(origin.X + fixed_dist, ground_lvl, origin.Z)
			self:stop(ball)
			return
		end

		local x = horiz_speed * elapsed_time
		local y = (init_velo * sin_theta * elapsed_time) - (0.5 * g * elapsed_time^2)
		local target_pos = Vector3.new(origin.X + x, origin.Y + y, origin.Z)

		if target_pos.Y <= ground_lvl then
			ball.Position = Vector3.new(origin.X + x, ground_lvl, origin.Z)
			self:stop(ball)
		else
			ball.Position = target_pos
		end
	end)
end

---# Stop Animation #---
function physics:stop(ball) -- stops the ball ofc
	self._stop_anim = true
	if active_conn then
		active_conn:Disconnect()
		active_conn = nil
	end
end

return physics
