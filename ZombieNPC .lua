-- Services
local PathfindingService = game:GetService("PathfindingService") -- Grabs Roblox's PathfindingService to handle AI navigation.
local RepStorage = game:GetService("ReplicatedStorage") -- Gets ReplicatedStorage to access shared assets like zombie templates.

-- ================================
-- ZOMBIE TYPE CONFIGURATION
-- ================================
-- Change this to "Heavy", "Light", or "Normal"
local ZOMBIE_TYPE = "Heavy" -- Defines the type of zombie to spawn. I chose "Heavy" as a default for testing its tank-like behavior.

-- Zombie type definitions
local ZombieTypes = {
	Heavy = {
		Health = 150, -- High health for a tanky zombie that can take a beating.
		WalkSpeed = 5, -- Slow speed to emphasize its bulkiness; fast zombies would feel less "heavy."
		Damage = 25, -- High damage to make it threatening, matching its tough nature.
		AttackCooldown = 1.5, -- Longer cooldown for balance, since high damage could be OP otherwise.
		DisplayName = "Heavy Zombie" -- Clear name for players to identify this zombie type.
	},
	Light = {
		Health = 75, -- Low health since it’s a fast, fragile zombie.
		WalkSpeed = 16, -- High speed to make it agile and hard to hit, fitting the "light" theme.
		Damage = 6, -- Low damage to balance its speed; it’s more about overwhelming than raw power.
		AttackCooldown = 0.6, -- Fast attacks to match its speedy nature, creating a swarm-like feel.
		DisplayName = "Light Zombie" -- Descriptive name for clarity in-game.
	},
	Normal = {
		Health = 100, -- Balanced health for a standard zombie, a middle ground between Heavy and Light.
		WalkSpeed = 10, -- Moderate speed to feel like a typical zombie, not too fast or slow.
		Damage = 10, -- Moderate damage for a balanced threat level.
		AttackCooldown = 1.0, -- Standard cooldown for a predictable attack pattern.
		DisplayName = "Normal Zombie" -- Simple name to reflect its standard role.
	}
}

-- Get the current zombie's stats
local currentStats = ZombieTypes[ZOMBIE_TYPE] -- Fetches the stats for the selected zombie type.
if not currentStats then
	warn("Invalid zombie type: " .. tostring(ZOMBIE_TYPE)) -- Warns if the ZOMBIE_TYPE is invalid (e.g., typo). Using warn() for debugging instead of error() to avoid stopping the script.
	return -- Stops the script to prevent errors from missing stats.
end

-- ================================
-- Get zombie template from ReplicatedStorage
-- ================================
local templateNames = {
	Heavy = "HeavyZombieTemplate", -- Maps zombie types to their template names in ReplicatedStorage.
	Normal = "NormalZombieTemplate",
	Light = "LightZombieTemplate"
}

local templateName = templateNames[ZOMBIE_TYPE] -- Gets the template name for the current zombie type.
local zombieTemplate = RepStorage:FindFirstChild(templateName) -- Looks for the template in ReplicatedStorage.

if not zombieTemplate then
	warn("Zombie template not found in ReplicatedStorage: " .. tostring(templateName)) -- Warns if the template is missing, likely a setup error in ReplicatedStorage.
	return -- Exits to avoid proceeding without a valid template.
end

-- ================================
-- Grab zombie parts
-- ================================
local zombie = script.Parent -- Gets the zombie instance this script is attached to.
local zombieTorso = zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("HumanoidRootPart") -- Checks for different torso names to support R6 and R15 rigs, with HumanoidRootPart as a fallback.
local zombieHumanoid = zombie:FindFirstChild("Humanoid") -- Gets the zombie’s Humanoid for health, movement, and animations.

if not zombieTorso or not zombieHumanoid then
	warn("Zombie is missing parts (torso/humanoid), can't run AI.") -- Warns if critical parts are missing, which would break pathfinding or AI logic.
	return -- Stops the script to prevent errors from missing components.
end

-- Apply zombie type stats
zombieHumanoid.MaxHealth = currentStats.Health -- Sets the zombie’s max health based on its type.
zombieHumanoid.Health = currentStats.Health -- Initializes health to max to ensure the zombie starts at full strength.
zombieHumanoid.WalkSpeed = currentStats.WalkSpeed -- Sets movement speed to match the zombie type’s stats.
zombie.Name = currentStats.DisplayName -- Names the zombie instance for clarity in the game world.
zombieHumanoid.DisplayName = currentStats.DisplayName -- Sets the in-game display name above the zombie’s head.

-- Default stats (with safe indexing)
local Stats = setmetatable({}, {
	__index = function(t, k) return 0 end -- Uses a metatable to return 0 for any undefined stat, preventing nil errors when tracking stats.
})

-- Track time alive
local spawnTime = tick() -- Records the time the zombie spawns to calculate its lifespan later.

-- ================================
-- AI helper functions
-- ================================
local function findTarget()
	local agroDistance = 100 -- Sets the max distance to detect players; 100 studs feels like a good range for zombies to "notice" players.
	local target = nil -- Initializes target as nil; we’ll update it if a valid player is found.
	for _, player in ipairs(game.Players:GetPlayers()) do -- Loops through all players in the game.
		if player.Character then -- Ensures the player has a character (they might be in a menu or disconnected).
			local human = player.Character:FindFirstChild("Humanoid") -- Gets the player’s Humanoid to check health.
			local torso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("HumanoidRootPart") -- Supports R6/R15 rigs for player torso.
			if human and torso and human.Health > 0 then -- Checks if the player is alive and has necessary parts.
				local distance = (zombieTorso.Position - torso.Position).Magnitude -- Calculates distance between zombie and player.
				if distance < agroDistance then -- If the player is closer than the current closest target...
					agroDistance = distance -- Update the closest distance.
					target = torso -- Set this player’s torso as the target for pathfinding.
				end
			end
		end
	end
	return target -- Returns the closest player’s torso or nil if no valid target is found.
end

-- Damage variables
local DAMAGE_AMOUNT = currentStats.Damage -- Stores the zombie’s damage value for quick access.
local ATTACK_COOLDOWN = currentStats.AttackCooldown -- Stores the attack cooldown to control attack frequency.
local lastAttackTime = 0 -- Tracks the last time the zombie attacked to enforce the cooldown.

-- Damage handler
local function onTouched(hit)
	local character = hit.Parent -- Gets the character that the zombie’s torso touched.
	local humanoid = character:FindFirstChild("Humanoid") -- Checks if the touched object has a Humanoid (i.e., it’s a player or NPC).
	if humanoid and game.Players:GetPlayerFromCharacter(character) then -- Ensures it’s a player, not an NPC or other object.
		local currentTime = tick() -- Gets the current time to check if the attack cooldown has passed.
		if currentTime - lastAttackTime >= ATTACK_COOLDOWN then -- Only attack if enough time has passed since the last attack.
			lastAttackTime = currentTime -- Updates the last attack time.

			local healthBefore = humanoid.Health -- Stores the player’s health before damage for kill detection.
			humanoid:TakeDamage(DAMAGE_AMOUNT) -- Deals damage to the player based on zombie type.

			Stats.HitsLanded = Stats.HitsLanded + 1 -- Increments the hit counter for stat tracking.
			Stats.DamageDealt = Stats.DamageDealt + DAMAGE_AMOUNT -- Adds to the total damage dealt by this zombie.

			if humanoid.Health <= 0 and healthBefore > 0 then -- Checks if the player died from this hit.
				Stats.Kills = Stats.Kills + 1 -- Increments kill count if the player was killed.
				print(character.Name .. " got taken out by the zombie!") -- Logs the kill for debugging or feedback.
			end

			print("Zombie hit " .. character.Name .. ". Damage so far: " .. Stats.DamageDealt) -- Logs the hit and total damage for debugging.
		end
	end
end

zombieTorso.Touched:Connect(onTouched) -- Connects the onTouched function to the zombie’s torso to detect collisions with players.

-- ================================
-- Death + Respawn
-- ================================
zombieHumanoid.Died:Connect(function()
	Stats.Deaths = Stats.Deaths + 1 -- Increments the death counter for this zombie.
	Stats.TimeAlive = tick() - spawnTime -- Calculates how long the zombie was alive.

	-- Prints a summary of the zombie’s performance for debugging and analysis.
	print("--- Zombie Stats ---")
	print("Time Alive: " .. string.format("%.2f", Stats.TimeAlive) .. "s") -- Formats time to 2 decimal places for readability.
	print("Kills: " .. Stats.Kills) -- Shows total kills.
	print("Hits: " .. Stats.HitsLanded) -- Shows total hits landed.
	print("Damage: " .. Stats.DamageDealt) -- Shows total damage dealt.
	print("Chases: " .. Stats.ChasesStarted) -- Shows how many times the zombie chased a player.
	print("Wanders: " .. Stats.TimesWandered) -- Shows how many times the zombie wandered randomly.
	print("--------------------")

	task.wait(5) -- Waits 5 seconds before respawning to give players a brief break and avoid instant respawns.
	local newZombie = zombieTemplate:Clone() -- Clones the zombie template from ReplicatedStorage to create a new instance.
	newZombie.Name = currentStats.DisplayName -- Sets the new zombie’s name to match its type.

	local hum = newZombie:FindFirstChild("Humanoid") -- Gets the new zombie’s Humanoid.
	if hum then
		hum.DisplayName = currentStats.DisplayName -- Sets the display name for the new zombie.
	end

	local newTorso = newZombie:FindFirstChild("Torso") or newZombie:FindFirstChild("UpperTorso") or newZombie:FindFirstChild("HumanoidRootPart") -- Finds the new zombie’s torso, supporting R6/R15.
	if newTorso then
		newTorso.CFrame = zombieTorso.CFrame -- Spawns the new zombie at the same position as the old one.
	end

	newZombie.Parent = workspace -- Places the new zombie in the game world.
	local newScript = script:Clone() -- Clones this script to attach it to the new zombie.
	newScript.Parent = newZombie -- Attaches the cloned script to the new zombie to run its AI.

	zombie:Destroy() -- Removes the old zombie from the game to clean up.
end)

-- ================================
-- Movement (pathfinding + wandering)
-- ================================
local function pathfindTo(destination)
	local path = PathfindingService:CreatePath() -- Creates a new path for the zombie to follow.
	path:ComputeAsync(zombieTorso.Position, destination) -- Computes a path from the zombie’s position to the destination.

	if path.Status == Enum.PathStatus.Success then -- Checks if a valid path was found.
		local waypoints = path:GetWaypoints() -- Gets the waypoints of the path.
		if #waypoints > 1 then -- Ensures there’s at least one waypoint to move to.
			zombieHumanoid:MoveTo(waypoints[2].Position) -- Moves to the second waypoint (first is usually the starting point).
		else
			zombieHumanoid:MoveTo(destination) -- Falls back to moving directly to the destination if waypoints are limited.
		end
	else
		zombieHumanoid:MoveTo(destination) -- If pathfinding fails, move directly toward the destination as a fallback.
	end
end

-- Main loop
local WANDER_RADIUS = 50 -- Sets the radius for random wandering; 50 studs gives a good spread without straying too far.
local WANDER_INTERVAL = 3 -- Sets the interval between wander movements; 3 seconds feels natural for idle behavior.
local lastWanderTime = 0 -- Tracks the last time the zombie wandered.
local isChasing = false -- Tracks whether the zombie is chasing a player to toggle between chase and wander modes.

while task.wait(0.05) do -- Runs every 0.05 seconds for smooth updates without overloading the server.
	if not zombie.Parent or zombieHumanoid.Health <= 0 then -- Checks if the zombie still exists or is dead.
		break -- Exits the loop if the zombie is invalid or dead.
	end

	local targetTorso = findTarget() -- Looks for a player to chase.

	if targetTorso then -- If a player is found within range...
		if not isChasing then -- If the zombie wasn’t already chasing...
			Stats.ChasesStarted = Stats.ChasesStarted + 1 -- Increments chase counter for stats.
			isChasing = true -- Switches to chase mode.
		end
		pathfindTo(targetTorso.Position) -- Uses pathfinding to chase the player.
		lastWanderTime = tick() -- Resets wander timer to prevent wandering while chasing.
	else
		isChasing = false -- Switches back to idle mode if no player is found.
		if tick() - lastWanderTime > WANDER_INTERVAL then -- Checks if it’s time to wander again.
			lastWanderTime = tick() -- Updates the last wander time.
			Stats.TimesWandered = Stats.TimesWandered + 1 -- Increments wander counter for stats.

			local angle = math.random() * 2 * math.pi -- Generates a random angle for circular wandering.
			local x = WANDER_RADIUS * math.cos(angle) -- Calculates X offset for a random point within the radius.
			local z = WANDER_RADIUS * math.sin(angle) -- Calculates Z offset for a random point.
			
			local wanderPosition = zombieTorso.Position + Vector3.new(x, 0, z) -- Creates a wander destination relative to the zombie’s position.
			zombieHumanoid:MoveTo(wanderPosition) -- Moves the zombie to the random position.
		end
	end
end
