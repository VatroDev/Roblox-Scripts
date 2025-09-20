-- Services
-- Getting the PathfindingService to enable zombies to navigate around obstacles.
local PathfindingService = game:GetService("PathfindingService") -- PathfindingService is used for AI navigation; chosen because it’s Roblox’s built-in solution for pathfinding, avoiding custom pathfinding logic which would be more complex.

-- Getting ReplicatedStorage to access shared assets like zombie templates.
local RepStorage = game:GetService("ReplicatedStorage") -- ReplicatedStorage is used to store templates accessible to both client and server; it’s the standard Roblox practice for storing such assets.

-- A reliable way to generate random numbers
-- Creating a Random object for consistent random number generation.
local rng = Random.new() -- Random.new() is used for thread-safe random numbers; preferred over math.random() because it allows reproducible sequences with a seed if needed.

-- ================================
-- ZOMBIE TYPE CONFIGURATION
-- ================================
-- Change this to "Heavy", "Light", or "Normal"
-- Defining the zombie type to configure behavior and stats.
local ZOMBIE_TYPE = "Heavy" -- Set to "Heavy" to select the heavy zombie configuration; a string-based type system is used for simplicity and readability over numerical enums.

-- Zombie type definitions
-- Creating a table to store stats for different zombie types.
local ZombieTypes = { -- A table is used to organize stats for each zombie type; this structure allows easy access and modification without hardcoding values.
	-- Heavy zombie configuration.
	Heavy = { -- "Heavy" type is defined first for prominence; grouped logically with stats for clarity.
		-- Setting high health for a tank-like zombie.
		Health = 150, -- High health (150) makes the zombie durable; chosen to make heavy zombies harder to kill compared to others.
		-- Slow speed to balance high health and damage.
		WalkSpeed = 5, -- Low speed (5) reflects a heavy, lumbering zombie; slower speed balances its high health and damage.
		-- High damage to make it a significant threat.
		Damage = 25, -- High damage (25) suits the heavy zombie’s role as a dangerous foe; chosen to reward players for avoiding it.
		-- Longer cooldown to balance high damage.
		AttackCooldown = 1.5, -- Longer cooldown (1.5s) prevents rapid attacks; balances the high damage to give players reaction time.
		-- Display name for identification in-game.
		DisplayName = "Heavy Zombie", -- Descriptive name for clarity in UI; chosen to match the zombie’s role and appearance.
		-- Placeholder for attack animation asset.
		AttackAnimId = "rbxassetid://YOUR_ATTACK_ANIM_ID_HERE", -- Placeholder for animation ID; allows flexibility to swap animations without code changes.
		-- Placeholder for attack sound asset.
		AttackSoundId = "rbxassetid://YOUR_ATTACK_SOUND_ID_HERE", -- Placeholder for sound ID; keeps sound assets modular and reusable.
		-- Placeholder for groan sound asset.
		GroanSoundId = "rbxassetid://YOUR_GROAN_SOUND_ID_HERE", -- Placeholder for ambient sound; enhances atmosphere without hardcoding.
		-- Threshold for entering enraged state.
		RageThreshold = 0.4 -- 40% health triggers rage; chosen to make rage a mid-fight event, balancing difficulty.
	},
	-- Light zombie configuration.
	Light = { -- "Light" type for faster, weaker zombies; grouped similarly for consistency.
		-- Lower health for a less durable zombie.
		Health = 75, -- Lower health (75) makes it easier to kill; fits the fast, fragile archetype.
		-- High speed for quick movement.
		WalkSpeed = 16, -- High speed (16) makes it agile; chosen to challenge players with fast pursuit.
		-- Low damage to balance high speed.
		Damage = 6, -- Low damage (6) balances speed; ensures it’s less lethal than heavier types.
		-- Short cooldown for frequent attacks.
		AttackCooldown = 0.6, -- Short cooldown (0.6s) suits fast attacks; aligns with the light zombie’s agile nature.
		-- Display name for clarity.
		DisplayName = "Light Zombie", -- Clear name for UI; matches the zombie’s role.
		-- Placeholder for attack animation.
		AttackAnimId = "rbxassetid://YOUR_ATTACK_ANIM_ID_HERE", -- Same placeholder system for modularity.
		-- Placeholder for attack sound.
		AttackSoundId = "rbxassetid://YOUR_ATTACK_SOUND_ID_HERE", -- Consistent sound placeholder.
		-- Placeholder for groan sound.
		GroanSoundId = "rbxassetid://YOUR_GROAN_SOUND_ID_HERE", -- Consistent for ambient audio.
		-- Higher rage threshold for later rage.
		RageThreshold = 0.5 -- 50% health for rage; higher than heavy to delay rage due to lower health.
	},
	-- Normal zombie configuration.
	Normal = { -- "Normal" type as a balanced option; follows same structure for consistency.
		-- Moderate health for balance.
		Health = 100, -- Balanced health (100) as a middle ground; fits a standard enemy role.
		-- Moderate speed for balanced movement.
		WalkSpeed = 10, -- Moderate speed (10) for a standard zombie; balances pursuit and avoidance.
		-- Moderate damage for balanced threat.
		Damage = 10, -- Moderate damage (10) for a standard threat; avoids being too weak or strong.
		-- Moderate cooldown for balanced attacks.
		AttackCooldown = 1.0, -- 1s cooldown as a middle ground; allows consistent but not overwhelming attacks.
		-- Display name for identification.
		DisplayName = "Normal Zombie", -- Clear name for UI; reflects balanced role.
		-- Placeholder for attack animation.
		AttackAnimId = "rbxassetid://YOUR_ATTACK_ANIM_ID_HERE", -- Consistent placeholder system.
		-- Placeholder for attack sound.
		AttackSoundId = "rbxassetid://YOUR_ATTACK_SOUND_ID_HERE", -- Consistent sound modularity.
		-- Placeholder for groan sound.
		GroanSoundId = "rbxassetid://YOUR_GROAN_SOUND_ID_HERE", -- Consistent for audio.
		-- Lower rage threshold for earlier rage.
		RageThreshold = 0.3 -- 30% health for rage; lower to make rage more frequent, fitting balanced role.
	}
}

-- Your exact spawn locations
-- Defining specific spawn points for zombies.
local SPAWN_LOCATIONS = { -- Table of spawn points; using Vector3 for precise 3D coordinates.
	-- First spawn point coordinates.
	Vector3.new(102.75, 2.5, 11.85), -- Specific spawn point; chosen for map layout to spread zombies evenly.
	-- Second spawn point coordinates.
	Vector3.new(116.1, 2.5, -18.95), -- Another spawn point; placed to avoid clustering with others.
	-- Third spawn point coordinates.
	Vector3.new(88.55, 2.5, -24.1) -- Final spawn point; ensures variety in spawn locations.
}

-- Get the current zombie's stats
-- Retrieving stats for the selected zombie type.
local currentStats = ZombieTypes[ZOMBIE_TYPE] -- Access stats using ZOMBIE_TYPE; table lookup is efficient and avoids conditionals.
-- Validating the zombie type to prevent errors.
if not currentStats then -- Check if type exists; prevents runtime errors from invalid types.
	-- Warn if the type is invalid and stop execution.
	warn("Invalid zombie type: " .. tostring(ZOMBIE_TYPE)) -- Warn logs error for debugging; tostring ensures type safety.
	return -- Exit script to avoid errors; safer than continuing with invalid stats.
end

-- ================================
-- Get zombie template from ReplicatedStorage
-- ================================
-- Mapping zombie types to their template names.
local templateNames = { -- Table maps types to template names; avoids hardcoding strings multiple times.
	-- Template name for heavy zombie.
	Heavy = "HeavyZombieTemplate", -- Specific name for heavy zombie model; clear naming for organization.
	-- Template name for normal zombie.
	Normal = "NormalZombieTemplate", -- Name for normal zombie model; consistent naming convention.
	-- Template name for light zombie.
	Light = "LightZombieTemplate" -- Name for light zombie model; keeps templates distinct.
}

-- Getting the template name for the current zombie type.
local templateName = templateNames[ZOMBIE_TYPE] -- Lookup template name; efficient and matches type system.
-- Finding the template in ReplicatedStorage.
local zombieTemplate = RepStorage:FindFirstChild(templateName) -- Find template by name; ReplicatedStorage is standard for shared assets.

-- Validating that the template exists.
if not zombieTemplate then -- Check to ensure template exists; prevents errors if asset is missing.
	-- Warn if template is not found and stop execution.
	warn("Zombie template not found in ReplicatedStorage: " .. tostring(templateName)) -- Warn for debugging; tostring for type safety.
	return -- Exit to avoid errors; ensures script doesn’t proceed without a valid template.
end

-- ================================
-- Grab zombie parts
-- ================================
-- Getting the zombie instance (parent of this script).
local zombie = script.Parent -- Script is inside zombie model; Parent gives direct access to the zombie.
-- Finding the zombie’s torso or equivalent part.
local zombieTorso = zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("HumanoidRootPart") -- Check multiple part names; supports both R6 and R15 rigs for flexibility.
-- Finding the zombie’s Humanoid for health and movement.
local zombieHumanoid = zombie:FindFirstChild("Humanoid") -- Humanoid controls health and movement; standard for Roblox characters.

-- Validating that required parts exist.
if not zombieTorso or not zombieHumanoid then -- Ensure both parts exist; prevents errors if model is incomplete.
	-- Warn if parts are missing and stop execution.
	warn("Zombie is missing parts (torso/humanoid), can't run AI.") -- Warn for debugging; clear message for developers.
	return -- Exit to avoid errors; ensures AI doesn’t run without critical components.
end

-- Apply zombie type stats
-- Setting maximum health based on zombie type.
zombieHumanoid.MaxHealth = currentStats.Health -- Set max health; ensures health scales with type.
-- Setting current health to maximum.
zombieHumanoid.Health = currentStats.Health -- Initialize health to max; ensures zombie starts at full health.
-- Setting walk speed based on type.
zombieHumanoid.WalkSpeed = currentStats.WalkSpeed -- Set speed; reflects type-specific movement behavior.
-- Setting zombie model name for identification.
zombie.Name = currentStats.DisplayName -- Name model for clarity; used for in-game identification.
-- Setting humanoid display name for UI.
zombieHumanoid.DisplayName = currentStats.DisplayName -- Display name for UI; consistent with model name for clarity.

-- Load animations and sounds
-- Declaring variables for animation and sound objects.
local attackTrack -- Variable for attack animation track; declared here for scope.
local attackSound -- Variable for attack sound; declared for scope.
-- Finding the Animator for playing animations.
local animator = zombieHumanoid:FindFirstChildOfClass("Animator") -- Animator handles animations; standard for Roblox humanoids.
-- Checking if Animator exists before loading animations.
if animator then -- Ensure Animator exists; avoids errors if humanoid is misconfigured.
	-- Creating a new Animation instance.
	local attackAnim = Instance.new("Animation") -- Animation object for attack; created dynamically for flexibility.
	-- Setting the animation ID from zombie stats.
	attackAnim.AnimationId = currentStats.AttackAnimId -- Use type-specific animation; allows unique animations per type.
	-- Loading the animation into the Animator.
	attackTrack = animator:LoadAnimation(attackAnim) -- Load animation; prepares it for playback.

	-- Creating a sound for the attack.
	attackSound = Instance.new("Sound", zombieTorso) -- Sound attached to torso; ensures spatial audio from zombie’s position.
	-- Setting the attack sound ID.
	attackSound.SoundId = currentStats.AttackSoundId -- Type-specific sound; enhances immersion with unique audio.

	-- Creating a looping groan sound for ambiance.
	local groanSound = Instance.new("Sound", zombieTorso) -- Sound for groans; attached to torso for spatial effect.
	-- Setting the groan sound ID.
	groanSound.SoundId = currentStats.GroanSoundId -- Type-specific groan; adds variety to zombie types.
	-- Enabling looping for continuous groans.
	groanSound.Looped = true -- Looped for constant ambiance; typical for zombie groans.
	-- Setting volume for subtle effect.
	groanSound.Volume = 0.5 -- Moderate volume; loud enough to hear but not overpowering.
	-- Playing the groan sound immediately.
	groanSound:Play() -- Start playing; creates immediate atmosphere.
end

-- Default stats (with safe indexing)
-- Creating a Stats table to track zombie metrics.
local Stats = setmetatable({}, { -- Table with metatable for stats; allows tracking without predefined keys.
	-- Metatable to return 0 for undefined stats.
	__index = function(t, k) return 0 end -- Return 0 for missing keys; prevents nil errors when accessing stats.
})

-- Track time alive
-- Recording the spawn time for tracking lifetime.
local spawnTime = tick() -- Store spawn time; used to calculate time alive when zombie dies.

-- ================================
-- AI helper functions
-- ================================
-- Function to find a target player within range.
local function findTarget() -- FindTarget locates players; encapsulates logic for reusability.
	-- Maximum distance for detecting players.
	local agroDistance = 100 -- 100 studs as detection range; large enough to make zombies threatening but not infinite.
	-- Variable to store the closest target.
	local target = nil -- Initialize to nil; will store closest player’s torso.
	-- Setting up raycast parameters for line-of-sight checks.
	local rayParams = RaycastParams.new() -- RaycastParams for efficient raycasting; reusable for multiple checks.
	-- Setting filter to ignore the zombie itself.
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist -- Blacklist to ignore zombie; prevents self-detection.
	-- Adding zombie to the blacklist.
	rayParams.FilterDescendantsInstances = {zombie} -- Ignore zombie’s parts; ensures accurate raycasts.

	-- Looping through all players to find a target.
	for _, player in ipairs(game.Players:GetPlayers()) do -- Iterate players; standard way to check all players in Roblox.
		-- Checking if player has a character.
		if player.Character then -- Ensure character exists; avoids errors for players not in game.
			-- Finding the player’s humanoid.
			local human = player.Character:FindFirstChild("Humanoid") -- Get humanoid; needed to check health.
			-- Finding the player’s torso or equivalent part.
			local torso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("HumanoidRootPart") -- Support R6/R15; ensures compatibility.
			-- Checking if player is valid and alive.
			if human and torso and human.Health > 0 then -- Valid target requires humanoid, torso, and positive health.
				-- Calculating distance to player.
				local distance = (zombieTorso.Position - torso.Position).Magnitude -- Distance via Magnitude; standard for 3D distance.
				-- Checking if player is within agro range.
				if distance < agroDistance then -- Closer than current agroDistance; candidate for target.
					-- Setting up raycast origin for line-of-sight check.
					local origin = zombieTorso.Position -- Start at zombie’s torso; logical for line-of-sight.
					-- Calculating direction to player.
					local direction = (torso.Position - origin).Unit * distance -- Normalized direction scaled by distance; ensures accurate raycast.
					-- Performing raycast to check for obstacles.
					local result = workspace:Raycast(origin, direction, rayParams) -- Raycast to detect obstacles; ensures zombie can “see” player.
					-- Checking if raycast hits player or nothing (line of sight clear).
					if not result or result.Instance:IsDescendantOf(player.Character) then -- No obstacle or hit player; valid target.
						-- Updating closest target distance.
						agroDistance = distance -- Update agroDistance; ensures closest player is chosen.
						-- Setting target to player’s torso.
						target = torso -- Store torso; used for pathfinding.
					end
				end
			end
		end
	end
	-- Returning the closest valid target or nil.
	return target -- Return target; nil if no valid target found.
end

-- Damage variables
-- Setting initial damage based on zombie type.
local DAMAGE_AMOUNT = currentStats.Damage -- Initialize damage; allows dynamic updates (e.g., in rage mode).
-- Setting attack cooldown based on type.
local ATTACK_COOLDOWN = currentStats.AttackCooldown -- Type-specific cooldown; ensures consistent attack timing.
-- Tracking last attack time for cooldown.
local lastAttackTime = 0 -- Initialize to 0; used to enforce attack cooldown.

-- Damage handler
-- Function to handle damage when zombie touches a player.
local function onTouched(hit) -- OnTouched handles collisions; triggered when zombie touches something.
	-- Getting the character from the hit part.
	local character = hit.Parent -- Parent of hit part; typically the character model.
	-- Finding the humanoid of the hit character.
	local humanoid = character:FindFirstChild("Humanoid") -- Get humanoid; needed to apply damage.
	-- Checking if hit is a valid player character.
	if humanoid and game.Players:GetPlayerFromCharacter(character) then -- Ensure it’s a player with a humanoid; avoids damaging non-players.
		-- Getting current time for cooldown check.
		local currentTime = tick() -- Current time; used to enforce attack cooldown.
		-- Checking if enough time has passed since last attack.
		if currentTime - lastAttackTime >= ATTACK_COOLDOWN then -- Cooldown elapsed; zombie can attack.
			-- Updating last attack time.
			lastAttackTime = currentTime -- Update time; prevents rapid attacks.
			-- Playing attack animation and sound if available.
			if attackTrack and attackSound then -- Check if assets exist; avoids errors if not loaded.
				-- Playing attack animation.
				attackTrack:Play() -- Play animation; enhances visual feedback.
				-- Playing attack sound.
				attackSound:Play() -- Play sound; adds audio feedback.
			end
			-- Storing health before damage for kill tracking.
			local healthBefore = humanoid.Health -- Store health; used to detect kills.
			-- Applying damage to the player.
			humanoid:TakeDamage(DAMAGE_AMOUNT) -- Deal damage; uses type-specific damage value.
			-- Incrementing hit counter.
			Stats.HitsLanded = Stats.HitsLanded + 1 -- Track hits; useful for debugging and stats.
			-- Incrementing damage dealt counter.
			Stats.DamageDealt = Stats.DamageDealt + DAMAGE_AMOUNT -- Track total damage; accumulates for stats.
			-- Checking if player was killed.
			if humanoid.Health <= 0 and healthBefore > 0 then -- Player died this hit; healthBefore ensures accurate kill detection.
				-- Incrementing kill counter.
				Stats.Kills = Stats.Kills + 1 -- Track kills; rewards zombie effectiveness.
			end
		end
	end
end

-- Connecting touch event to damage handler.
zombieTorso.Touched:Connect(onTouched) -- Connect Touched event; triggers damage on contact with players.

-- ================================
-- Death + Respawn
-- ================================
-- Handling zombie death and respawn.
zombieHumanoid.Died:Connect(function() -- Died event; triggered when zombie’s health reaches 0.
	-- Incrementing death counter.
	Stats.Deaths = Stats.Deaths + 1 -- Track deaths; useful for stats and debugging.
	-- Calculating time alive.
	Stats.TimeAlive = tick() - spawnTime -- Calculate lifetime; tracks how long zombie survived.
	-- Printing stats for debugging.
	print("--- Zombie Stats ---") -- Header for stats; clear separator for readability.
	-- Printing time alive.
	print("Time Alive: " .. string.format("%.2f", Stats.TimeAlive) .. "s") -- Formatted time; %.2f for readable output.
	-- Printing kill count.
	print("Kills: " .. Stats.Kills) -- Show kills; tracks zombie effectiveness.
	-- Printing hit count.
	print("Hits: " .. Stats.HitsLanded) -- Show hits; tracks combat activity.
	-- Printing damage dealt.
	print("Damage: " .. Stats.DamageDealt) -- Show total damage; summarizes impact.
	-- Printing chase count.
	print("Chases: " .. Stats.ChasesStarted) -- Show chases; tracks AI aggression.
	-- Printing wander count.
	print("Wanders: " .. Stats.TimesWandered) -- Show wanders; tracks idle behavior.
	-- Printing stats footer.
	print("--------------------") -- Footer for clarity; separates stats output.
	-- Waiting before respawning.
	task.wait(5) -- 5-second delay; gives players a break before zombie respawns.
	-- Cloning a new zombie from the template.
	local newZombie = zombieTemplate:Clone() -- Clone template; reuses original model for consistency.
	-- Finding the new zombie’s torso.
	local newTorso = newZombie:FindFirstChild("Torso") or newZombie:FindFirstChild("UpperTorso") or newZombie:FindFirstChild("HumanoidRootPart") -- Support R6/R15; ensures compatibility.
	-- Setting random spawn position if torso exists.
	if newTorso then -- Check torso exists; avoids errors if model is incomplete.
		-- Generating random index for spawn location.
		local randomIndex = rng:NextInteger(1, #SPAWN_LOCATIONS) -- Random index; ensures varied spawn points.
		-- Getting random spawn position.
		local randomSpawnPosition = SPAWN_LOCATIONS[randomIndex] -- Select spawn point; uses predefined locations for control.
		-- Setting new zombie’s position.
		newTorso.CFrame = CFrame.new(randomSpawnPosition) -- Set position; CFrame for precise placement.
	end
	-- Spawning the new zombie in the workspace.
	newZombie.Parent = workspace -- Place in workspace; makes zombie active in game.
	-- Destroying the old zombie.
	zombie:Destroy() -- Remove old zombie; prevents duplicates and frees resources.
end)

-- ================================
-- Movement (pathfinding + wandering)
-- ================================
-- Function to move zombie to a destination using pathfinding.
local function pathfindTo(destination) -- PathfindTo handles navigation; encapsulates pathfinding logic.
	-- Creating a new path object.
	local path = PathfindingService:CreatePath() -- Create path; uses Roblox’s pathfinding for reliable navigation.
	-- Computing path from zombie to destination.
	path:ComputeAsync(zombieTorso.Position, destination) -- Async computation; efficient and non-blocking.
	-- Checking if pathfinding was successful.
	if path.Status == Enum.PathStatus.Success then -- Success means a valid path was found; handles pathfinding failures gracefully.
		-- Getting waypoints from the path.
		local waypoints = path:GetWaypoints() -- Get waypoints; provides steps for zombie to follow.
		-- Checking if there are enough waypoints.
		if #waypoints > 1 then -- More than one waypoint; use second waypoint for smoother movement.
			-- Moving to the second waypoint.
			zombieHumanoid:MoveTo(waypoints[2].Position) -- Second waypoint; avoids standing still at start and ensures progress.
		else
			-- Moving directly to destination if too few waypoints.
			zombieHumanoid:MoveTo(destination) -- Fallback to destination; handles edge cases like single waypoint.
		end
	else
		-- Moving directly to destination if pathfinding fails.
		zombieHumanoid:MoveTo(destination) -- Direct movement; fallback to ensure zombie doesn’t freeze.
	end
end

-- Main loop
-- Defining constants for wandering behavior.
local WANDER_RADIUS = 50 -- 50 studs for wandering; large enough for exploration but keeps zombie in area.
local WANDER_INTERVAL = 3 -- 3 seconds between wanders; balances idle movement with performance.
local lastWanderTime = 0 -- Track last wander; ensures wandering happens at intervals.
local isChasing = false -- Track chasing state; prevents wandering during pursuit.
local isEnraged = false -- Track enraged state; controls speed and damage boosts.

-- Main AI loop running every 0.05 seconds.
while task.wait(0.05) do -- 0.05s interval; fast enough for smooth AI but avoids excessive CPU use.
	-- Checking if zombie or humanoid is invalid.
	if not zombie.Parent or zombieHumanoid.Health <= 0 then -- Exit if zombie is gone or dead; prevents errors.
		break -- Break loop; stops AI for invalid zombie.
	end
	-- Enraged State Check
	-- Checking if zombie should enter enraged state.
	if not isEnraged and zombieHumanoid.Health / zombieHumanoid.MaxHealth <= currentStats.RageThreshold then -- Below rage threshold; triggers enraged mode.
		-- Setting enraged state.
		isEnraged = true -- Mark as enraged; prevents repeated checks.
		-- Increasing walk speed for enraged state.
		zombieHumanoid.WalkSpeed = zombieHumanoid.WalkSpeed * 1.5 -- 1.5x speed; makes zombie more threatening.
		-- Increasing damage for enraged state.
		DAMAGE_AMOUNT = DAMAGE_AMOUNT * 1.2 -- 1.2x damage; increases danger without being overwhelming.
		-- Creating a visual effect for rage.
		local rageEffect = Instance.new("PointLight", zombieTorso) -- PointLight for visual cue; attached to torso for visibility.
		-- Setting red color for rage effect.
		rageEffect.Color = Color3.fromRGB(255, 25, 25) -- Red color; conveys danger and rage.
		-- Setting brightness for visibility.
		rageEffect.Brightness = 2 -- Bright enough to be noticeable; balances visibility and performance.
		-- Setting range for light effect.
		rageEffect.Range = 12 -- 12 studs; visible but not excessive.
	end
	-- Finding a target to chase.
	local targetTorso = findTarget() -- Call findTarget; checks for nearby players.
	-- Handling chase behavior.
	if targetTorso then -- Target found; initiate chase.
		-- Checking if not already chasing.
		if not isChasing then -- First detection of target; start chase.
			-- Incrementing chase counter.
			Stats.ChasesStarted = Stats.ChasesStarted + 1 -- Track chases; monitors AI aggression.
			-- Setting chasing state.
			isChasing = true -- Mark as chasing; prevents wandering.
		end
		-- Moving toward the target.
		pathfindTo(targetTorso.Position) -- Use pathfinding; ensures intelligent navigation to player.
		-- Updating last wander time to prevent wandering.
		lastWanderTime = tick() -- Reset wander timer; keeps zombie focused on target.
	else
		-- No target; enter idle/wander mode.
		isChasing = false -- Clear chasing state; allows wandering.
		-- Checking if it’s time to wander.
		if tick() - lastWanderTime > WANDER_INTERVAL then -- Wander interval elapsed; time to move randomly.
			-- Updating last wander time.
			lastWanderTime = tick() -- Reset timer; ensures consistent wandering intervals.
			-- Incrementing wander counter.
			Stats.TimesWandered = Stats.TimesWandered + 1 -- Track wanders; monitors idle behavior.
			-- Generating random angle for wandering.
			local angle = rng:NextNumber() * 2 * math.pi -- Random angle; creates circular wandering pattern.
			-- Calculating x-coordinate for wander position.
			local x = WANDER_RADIUS * math.cos(angle) -- Cosine for x; part of polar coordinate system for random movement.
			-- Calculating z-coordinate for wander position.
			local z = WANDER_RADIUS * math.sin(angle) -- Sine for z; completes polar coordinates for even distribution.
			-- Creating wander position relative to current position.
			local wanderPosition = zombieTorso.Position + Vector3.new(x, 0, z) -- New position; keeps y constant to stay on ground.
			-- Moving to wander position.
			zombieHumanoid:MoveTo(wanderPosition) -- Direct movement; simple wandering without pathfinding for performance.
		end
	end
end
