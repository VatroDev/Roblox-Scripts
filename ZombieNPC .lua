

-- Services
local PathfindingService = game:GetService("PathfindingService") 
local RepStorage = game:GetService("ReplicatedStorage") 

-- ZOMBIE TYPE CONFIGURATION
-- ================================
-- We keep the current type in a single variable so this script can be reused for different zombie types.
local ZOMBIE_TYPE = "Heavy" -- Default set to 'Heavy' for testing tanky behavior. You can change this to "Light" or "Normal" to reuse the same script with different stats.

-- Define stats for each zombie type
local ZombieTypes = {
	Heavy = {
		Health = 150, -- Heavy gets a lot of health. Chosen to make it a threat that soaks damage.
		WalkSpeed = 5, -- Slow to move heavy/tanky feeling. Using a lower WalkSpeed emphasizes durability over mobility.
		Damage = 25, -- High damage to make encounters with this type meaningful.
		AttackCooldown = 1.5, -- Longer cooldown balances its high damage.
		DisplayName = "Heavy Zombie"
	},
	Light = {
		Health = 75, -- Low health so they feel fragile and die quickly to encourage hit-and-run gameplay.
		WalkSpeed = 16, -- Fast movement for swarm behavior; chosen to be clearly faster than player default speed.
		Damage = 6, -- Low single-hit damage to balance speed.
		AttackCooldown = 0.6, -- Fast attacks make them dangerous in groups.
		DisplayName = "Light Zombie"
	},
	Normal = {
		Health = 100, -- Balanced baseline values give a predictable test subject.
		WalkSpeed = 10,
		Damage = 10,
		AttackCooldown = 1.0,
		DisplayName = "Normal Zombie"
	}
}

-- Fetch stats for the chosen zombie type
local currentStats = ZombieTypes[ZOMBIE_TYPE]
if not currentStats then
	-- We warn and return rather than error to make debugging less disruptive during development.
	warn("Invalid zombie type: " .. tostring(ZOMBIE_TYPE))
	return
end

-- Get zombie template from ReplicatedStorage
-- ================================
local templateNames = {
	Heavy = "HeavyZombieTemplate",
	Normal = "NormalZombieTemplate",
	Light = "LightZombieTemplate"
}

local templateName = templateNames[ZOMBIE_TYPE]
local zombieTemplate = RepStorage:FindFirstChild(templateName)
if not zombieTemplate then
	-- If template missing, warn and return.
	warn("Zombie template not found: " .. tostring(templateName))
	return
end

-- Grab zombie parts
-- ================================
local zombie = script.Parent -- Expect this script to be a child of the zombie model instance.
-- We try multiple common torso names to support both R6 and R15 rigs and also HumanoidRootPart fallback.
local zombieTorso = zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("HumanoidRootPart")
local zombieHumanoid = zombie:FindFirstChild("Humanoid")

if not zombieTorso or not zombieHumanoid then
	-- We require these to run the AI; otherwise the model isn't set up correctly.
	warn("Zombie missing torso or humanoid, can't run AI.")
	return
end

-- Apply zombie stats
-- Using MaxHealth then Health ensures health bars and damage events behave as expected.
zombieHumanoid.MaxHealth = currentStats.Health
zombieHumanoid.Health = currentStats.Health
zombieHumanoid.WalkSpeed = currentStats.WalkSpeed -- Set walk speed on the humanoid so MoveTo and character animations use it.
zombie.Name = currentStats.DisplayName -- Name the model for debugging in workspace. Useful when multiple zombie types spawn.
zombieHumanoid.DisplayName = currentStats.DisplayName -- Shows a name above the humanoid (Roblox 2020+ feature).

-- Stats tracking with safe indexing
-- We use a metatable to return 0 for undefined stats so we don't need to initialize every stat explicitly.
local Stats = setmetatable({}, {
	__index = function(t, k) return 0 end -- If we read an undefined stat, treat it as 0 instead of nil (avoids errors when incrementing).
})

local spawnTime = tick() -- Record spawn time to calculate lifespan at death. Chosen because tick() is simple and sufficient.

-- 
-- AI helper functions
-- ================================
local function findTarget()
	-- Use a local agroDistance value that we reduce as we find closer players.
	-- This pattern finds the closest valid player within the initial range.
	local agroDistance = 100 -- 100 studs is a good default detection radius. You can tune this for balance.
	local target = nil
	-- Iterate all players; grabbing their character parts to compute distance.
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player.Character then
			local human = player.Character:FindFirstChild("Humanoid")
			-- Try multiple torso parts to support different rigs.
			local torso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("HumanoidRootPart")
			-- We only consider living players (health > 0)
			if human and torso and human.Health > 0 then
				local distance = (zombieTorso.Position - torso.Position).Magnitude
				-- We pick the closest player within the current agroDistance.
				if distance < agroDistance then
					agroDistance = distance
					target = torso -- Store the torso object for pathfinding.
				end
			end
		end
	end
	-- Returning the torso part keeps pathfinding code generic (works for both R6/R15).
	return target
end

-- Damage variables
local DAMAGE_AMOUNT = currentStats.Damage
local ATTACK_COOLDOWN = currentStats.AttackCooldown
local lastAttackTime = 0 -- We track last attack time to implement cooldown without using delay or coroutines.

-- onTouched handles melee-style damage when part is touched. This is a simple approach that works for close-range enemies.
local function onTouched(hit)
	local character = hit.Parent
	if not character then return end -- Defensive: hit.Parent might be nil in some edge cases.
	local humanoid = character:FindFirstChild("Humanoid")
	-- Only damage players, not NPCs: check if the touched character belongs to a player.
	if humanoid and game.Players:GetPlayerFromCharacter(character) then
		local currentTime = tick()
		if currentTime - lastAttackTime >= ATTACK_COOLDOWN then
			lastAttackTime = currentTime -- update last attack time immediately to prevent rapid multi-hits on overlap
			local healthBefore = humanoid.Health
			-- Using TakeDamage is preferred over directly setting Health because it triggers damage events and respects Roblox's damage pipeline.
			humanoid:TakeDamage(DAMAGE_AMOUNT)

			-- Update tracked stats. Using the metatable ensures these increments work even if keys were never set.
			Stats.HitsLanded = Stats.HitsLanded + 1
			Stats.DamageDealt = Stats.DamageDealt + DAMAGE_AMOUNT

			-- If this attack killed the player, increment Kills. healthBefore > 0 check ensures we only count actual kills from this hit.
			if humanoid.Health <= 0 and healthBefore > 0 then
				Stats.Kills = Stats.Kills + 1
				print(character.Name .. " got taken out by the zombie!") -- Simple feedback for development; remove or route to logging in production.
			end

			-- Debug print to monitor behavior during development. In production, consider replacing prints with proper logging or removing them.
			print("Zombie hit " .. character.Name .. ". Damage so far: " .. Stats.DamageDealt)
		end
	end
end

-- Connect the touch handler. We listen on the torso to approximate melee range.
zombieTorso.Touched:Connect(onTouched)


-- Death + Respawn
-- ================================
zombieHumanoid.Died:Connect(function()
	-- Increment death stat and record time alive
	Stats.Deaths = Stats.Deaths + 1
	Stats.TimeAlive = tick() - spawnTime

	-- Log stats for debugging — helpful during tuning.
	print("--- Zombie Stats ---")
	print("Time Alive: " .. string.format("%.2f", Stats.TimeAlive) .. "s")
	print("Kills: " .. Stats.Kills)
	print("Hits: " .. Stats.HitsLanded)
	print("Damage: " .. Stats.DamageDealt)
	print("Chases: " .. Stats.ChasesStarted)
	print("Wanders: " .. Stats.TimesWandered)
	print("--------------------")

	-- Delay before respawn; task.wait is preferred over wait() for more predictable behavior.
	task.wait(5) -- 5 second respawn delay: chosen to give players a breather. Alternative: dynamic cooldown based on difficulty or number of players.

	-- Clone a fresh zombie from the template and set it up similarly to the original.
	local newZombie = zombieTemplate:Clone()
	newZombie.Name = currentStats.DisplayName

	local hum = newZombie:FindFirstChild("Humanoid")
	if hum then
		hum.DisplayName = currentStats.DisplayName -- Keep the display name consistent on respawn.
	end

	local newTorso = newZombie:FindFirstChild("Torso") or newZombie:FindFirstChild("UpperTorso") or newZombie:FindFirstChild("HumanoidRootPart")
	if newTorso then
		-- Place the new zombie at the same location as the old one. This keeps spawns predictable.
		newTorso.CFrame = zombieTorso.CFrame
	end

	newZombie.Parent = workspace -- Insert into the world so it becomes active.
	local newScript = script:Clone() -- Clone this script into the new zombie so AI continues to run.
	newScript.Parent = newZombie

	zombie:Destroy() -- Remove the dead zombie model to avoid clutter.
end)

-- Movement (pathfinding + wandering)
-- ================================
local function pathfindTo(destination)
	-- Create a path and compute a route from current position to destination.
	local path = PathfindingService:CreatePath()
	-- ComputeAsync is asynchronous internally but returns a Path object synchronously.
	path:ComputeAsync(zombieTorso.Position, destination)

	-- If the path succeeded, use the waypoints. Using waypoints makes the NPC avoid obstacles.
	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		-- Move to the second waypoint rather than the first because the first waypoint is often the current position.
		if #waypoints > 1 then
			zombieHumanoid:MoveTo(waypoints[2].Position)
		else
			-- Fallback: if there are few waypoints, just MoveTo the destination directly.
			zombieHumanoid:MoveTo(destination)
		end
	else
		-- Pathfinding failed (maybe unreachable or blocked). Fallback to direct MoveTo which may go through obstacles.
		zombieHumanoid:MoveTo(destination)
	end
end

-- Main loop parameters
local WANDER_RADIUS = 50 -- Wander radius in studs. Tweak to control how far zombies roam from spawn.
local WANDER_INTERVAL = 3 -- Seconds between wander attempts while idle. Shorter intervals make movement feel jittery; longer intervals feel static.
local lastWanderTime = 0
local isChasing = false

-- Main AI loop. We use a short wait to keep movement smooth without making the server do too much work.
while task.wait(0.05) do -- 0.05s update gives ~20 updates/sec which balances responsiveness and CPU cost.
	-- Defensive checks: stop if model removed or dead.
	if not zombie.Parent or zombieHumanoid.Health <= 0 then
		break
	end

	local targetTorso = findTarget()
	if targetTorso then
		-- If we just started chasing, record that.
		if not isChasing then
			Stats.ChasesStarted = Stats.ChasesStarted + 1
			isChasing = true
		end
		-- Use pathfinding to the target's current position.
		pathfindTo(targetTorso.Position)
		-- Reset wander timer so the zombie doesn't interrupt chase to wander.
		lastWanderTime = tick()
	else
		-- No target -> wander behavior
		isChasing = false
		if tick() - lastWanderTime > WANDER_INTERVAL then
			lastWanderTime = tick()
			Stats.TimesWandered = Stats.TimesWandered + 1

			-- Generate a random point in a circle around the current position using polar coordinates.
			-- Polar coordinates produce an even distribution of points inside the circle.
			local angle = math.random() * 2 * math.pi
			local x = WANDER_RADIUS * math.cos(angle)
			local z = WANDER_RADIUS * math.sin(angle)
			local wanderPosition = zombieTorso.Position + Vector3.new(x, 0, z)
			zombieHumanoid:MoveTo(wanderPosition)
		end
	end
end

