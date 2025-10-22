-- creating a variable for pathfinding servicess
local PathfindingService = game :GetService( "PathfindingService")

--created a variable for replicated storage
local RepStorage=game:GetService("ReplicatedStorage")

-- Random Number Generator
local rng = Random.new()

-- zombie type selection
local ZOMBIE_TYPE ="Heavy"

-- each zombie type stats definition
local ZombieTypes ={

    -- heavy zombie stats
	Heavy = {
        -- zombies health
		Health =150,
        -- zombies walk speed
		WalkSpeed = 5,
        -- zombie's damage
		Damage = 25,
        -- zombie's attack cooldown
		AttackCooldown =1.5,
        -- zombie's displayed name
		DisplayName = "Heavy Zombie",
        --zombie animations
		AttackAnimId = "rbxassetid://AttackAnimation",
		AttackSoundId = "rbxassetid://AttackSoundAnimation",
		GroanSoundId = "rbxassetid://GroanSound",
        -- zombie raged state 
		RageThreshold =0.4 -- 40% health
	},
    -- light zombie stats
	Light = {
        -- zombies health
		Health = 75,
        -- zombie's walk speed
		WalkSpeed = 16,
        -- zombie's damage
		Damage = 6,
        -- zombie attack cooldown
		AttackCooldown = 0.6,
        -- zombie displayed name
		DisplayName = "Light Zombie",
        -- zombie animations
		AttackAnimId = "rbxassetid://YOUR_ATTACK_ANIM_ID_HERE",
		AttackSoundId = "rbxassetid://YOUR_ATTACK_SOUND_ID_HERE",
		GroanSoundId = "rbxassetid://YOUR_GROAN_SOUND_ID_HERE",
        -- zombie raged state
		RageThreshold = 0.5 -- when reaching 50% health 
	},
    -- normal zombie stats
	Normal = {
        -- zombie health
		Health = 100,
        -- zombie walk speed
		WalkSpeed = 10,
        -- zombie damage
		Damage = 10,
        -- zombie attack cooldown
		AttackCooldown = 1.0,
        -- zombie displayed name
		DisplayName = "Normal Zombie",
        -- zombie animations
		AttackAnimId = "rbxassetid://YOUR_ATTACK_ANIM_ID_HERE",
		AttackSoundId = "rbxassetid://YOUR_ATTACK_SOUND_ID_HERE",
		GroanSoundId = "rbxassetid://YOUR_GROAN_SOUND_ID_HERE",
        -- zombie raged state
		RageThreshold = 0.3 -- when reaching 30% health
	}
}

--  3 spawn locations for zombies to spawn in (can be modified)
local SPAWN_LOCATIONS ={
    -- first  location
	Vector3.new(102.75, 2.5, 11.85),
    -- second location
	Vector3.new(116.1, 2.5, -18.95),
    -- Third location
	Vector3.new(88.55, 2.5, -24.1)
}

-- getting the stats for the selected zombie type
local currentStats = ZombieTypes[ZOMBIE_TYPE]
-- checking if the zombie type is valid first
if not currentStats then
    -- warning message if zombie type not valid
	warn("Invalid zombie type: " .. tostring(ZOMBIE_TYPE))
	return
end

--created a table that maps zombie types to their template names in ReplicatedStorage
local templateNames = {
    -- the heavy zombie uses the "HeavyZombieTemplate" model from replicated storage
	Heavy = "HeavyZombieTemplate",
    -- the normal zombie uses the "NormalZombieTemplate" model from replicated storage
	Normal = "NormalZombieTemplate",
    -- THe Light zombie uses the "LightZombieTemplate" model from replicated storage
	Light = "LightZombieTemplate"
}

-- varible to get the correct zombie template based on the selected zombie type
local templateName = templateNames[ZOMBIE_TYPE]
-- this gets the zombie template from replicated storage
local zombieTemplate = RepStorage:FindFirstChild(templateName)

-- checking if the zombie template exists
if not zombieTemplate then
    -- warning message if the template is not found
	warn("Zombie template not found in ReplicatedStorage: " .. tostring(templateName))
	return
end

-- main zombie script starts here!!
-- getts the zombie model
local zombie = script.Parent
-- gets the zombie torso or humanoid root part
local zombieTorso = zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("HumanoidRootPart")
-- gets the zombie humanoid
local zombieHumanoid = zombie:FindFirstChild("Humanoid")

-- checking if the zombie has the necessary parts
if not zombieTorso or not zombieHumanoid then
    -- if not then warning message
	warn("Zombie is missing parts (torso/humanoid), can't run AI.")
	return
end

-- setting the zombie stats based on its selected Zombietype
zombieHumanoid.MaxHealth = currentStats.Health
-- Setting zombie's  health
zombieHumanoid.Health = currentStats.Health
-- setting the zombie speed
zombieHumanoid.WalkSpeed = currentStats.WalkSpeed
--setting the zombie name 
zombie.Name = currentStats.DisplayName
-- setting the zombie's displayed name
zombieHumanoid.DisplayName = currentStats.DisplayName


-- loading the attack animation and sounds
-- creates variables for attack animation
local attackTrack
-- creates variable for attack Sound
local attackSound
-- loads the animator from the humanoid
local animator =zombieHumanoid:FindFirstChildOfClass("Animator")
-- checking if the animator exists
if animator then
    -- creates the attack animation instance
	local attackAnim =Instance.new("Animation")
    -- sets the animation id to the current zombie type attack animation id
	attackAnim.AnimationId =currentStats.AttackAnimId
    -- loads the attack animation into the attack track
	attackTrack = animator : LoadAnimation(attackAnim)

    -- creates the attack sound instance
	attackSound = Instance .new("Sound", zombieTorso)
    -- sets the sound id to the current zombie type attack sound id
	attackSound.SoundId =  currentStats.AttackSoundId

    -- creates the groan sound instance
	local groanSound = Instance.new("Sound", zombieTorso)
    -- sets the sound id to the current zombie type groan sound id
	groanSound.SoundId = currentStats.GroanSoundId
        -- sets the groan sound to loop and volume
	groanSound.Looped = true
    -- sets the groan sound volume
	groanSound.Volume = 0.5
    -- plays the groan sound
	groanSound:Play()
end

-- stats tracking table
local Stats = setmetatable({}, {
    -- initializes all stats to zero
	__index = function(t, k) return 0 end
})

-- records the spawn time of the zombie
local spawnTime = tick()

-- function to find the nearest target player within a certain Distnce
local function findTarget()
    -- creates variable for agro distance (minimum distance before zombie starts chasing player)
	local agroDistance = 100
    -- creates variable for target 
	local target = nil
    -- creates raycast parameters to ignore the zombie itself
	local rayParams = RaycastParams.new()
    -- sets the filter type to blacklist
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    -- adds the zombie to the filter list
	rayParams.FilterDescendantsInstances = {zombie}

    -- loops through all players in the game
	for _, player in ipairs(game.Players:GetPlayers()) do
        -- checks if the player has a character
		if player.Character then
            -- gets the humanoid and torso of this Player
			local human = player.Character:FindFirstChild("Humanoid")
            -- gets the torso or upper torso or humanoid root part of this player
			local torso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("HumanoidRootPart")
			-- checks if the humanoid and torso exist and if the player is alive
            if human and torso and human.Health > 0 then
                -- calculates the distance between the zombie and the player
				local distance = (zombieTorso.Position - torso.Position).Magnitude
                -- checks if the distance is less than the current agro distance
				if distance < agroDistance then
                    -- performs a raycast to check for line of sight
					local origin = zombieTorso.Position
                    -- calculates the direction for the raycast
					local direction = (torso.Position - origin).Unit * distance
                    -- performs the raycast
					local result = workspace:Raycast(origin, direction, rayParams)
                    -- checks if there is no obstruction or if the obstruction is part of the player's character model
					if not result or result.Instance:IsDescendantOf(player.Character) then
                        -- updates the agro distance and target to this player
						agroDistance = distance
                        -- sets the target to this player's torso
						target = torso
					end
				end
			end
		end
	end
    --  returns the target found which is the closest player (or nil if none found)
	return target
end


-- set the zombie's damage from the current stats
local DAMAGE_AMOUNT = currentStats.Damage
-- same thing for attack cooldown
local ATTACK_COOLDOWN = currentStats.AttackCooldown
-- variable to track last attack time
local lastAttackTime = 0

-- function that handles when the zombie touches a player to deal damage 
local function onTouched(hit)
    -- gets the character from the hit part
	local character = hit.Parent
    -- gets the humanoid from the character
	local humanoid = character:FindFirstChild("Humanoid")
    -- checks if the humanoid exists and if the character belongs to a player
	if humanoid and game.Players:GetPlayerFromCharacter(character) then
        -- gets the current time
		local currentTime = tick()
        -- checks if enough time has passed since the last attack
		if currentTime - lastAttackTime >= ATTACK_COOLDOWN then
            -- updates the last attack time
			lastAttackTime = currentTime
            -- plays the attack animation and sound if they exist
			if attackTrack and attackSound then
				attackTrack:Play()
				attackSound:Play()
			end
            -- creates a variable for health before taking damage
			local healthBefore = humanoid.Health
            -- deals damage to the humanoid
			humanoid:TakeDamage(DAMAGE_AMOUNT)
            -- updates the stats for hits landed and damage dealt by incrementing 1
			Stats.HitsLanded = Stats.HitsLanded + 1
            -- updates the damage dealt stat by adding the damage of this attack on total damage dealt
			Stats.DamageDealt = Stats.DamageDealt + DAMAGE_AMOUNT
            -- checks if the attack killed the player
			if humanoid.Health <= 0 and healthBefore > 0 then
                -- Increments the kills stat by 1
				Stats.Kills = Stats.Kills + 1
			end
		end
	end
end

-- connects the onTouched function to the zombie torso's Touched event
zombieTorso.Touched:Connect(onTouched)


-- handles the zombie's death event
zombieHumanoid.Died:Connect(function()
	-- increments the deaths stat by 1
	Stats.Deaths = Stats.Deaths + 1
	-- calculates the time the zombie was alive
	Stats.TimeAlive = tick() - spawnTime
	-- prints the zombie's stats to the output
	print("--- Zombie Stats ---")
	-- formats the time alive to 2 decimal places
	print("Time Alive: " .. string.format("%.2f", Stats.TimeAlive) .. "s")
	-- prints the number of deaths
	print("Kills: " .. Stats.Kills)
	-- prints the number of hits landed
	print("Hits: " .. Stats.HitsLanded)
	-- prints the total damage dealt
	print("Damage: " .. Stats.DamageDealt)
	-- prints the number of chases started
	print("Chases: " .. Stats.ChasesStarted)
	-- prints the number of times wandered
	print("Wanders: " .. Stats.TimesWandered)
	print("--------------------")
	-- waits for 5 seconds before respawning
	task.wait(5)
	-- creates a new zombie by cloning the template
	local newZombie = zombieTemplate:Clone()
	-- positions the new zombie at a random spawn location
	local newTorso = newZombie:FindFirstChild("Torso") or newZombie:FindFirstChild("UpperTorso") or newZombie:FindFirstChild("HumanoidRootPart")
	-- checks if the new torso exists
	if newTorso then
		-- selects a random spawn location from the predefined list
		local randomIndex = rng:NextInteger(1, #SPAWN_LOCATIONS)
		-- sets the new zombieies position to the random spawn loc
		local randomSpawnPosition = SPAWN_LOCATIONS[randomIndex]
		-- sets the CFrame of the new zombie torso to the random spawn position
		newTorso.CFrame = CFrame.new(randomSpawnPosition)
	end
	-- parents the new zombie to the workspace and to make it appear in the game 
	newZombie.Parent = workspace
	-- destroys the old zombie dead body
	zombie:Destroy()
end)

-- function to handle pathfinding to a destination
local function pathfindTo(destination)
	-- creates a path object using the PathfindingService
	local path = PathfindingService:CreatePath()
	-- computes the path from the zombie positions to the destination
	path:ComputeAsync(zombieTorso.Position, destination)
	-- checks if the path status is successful
	if path.Status == Enum.PathStatus.Success then
		-- gets the waypoints from the path
		local waypoints = path:GetWaypoints()
		-- moves to the second waypoint to avoid getting stuck on the first one
		if #waypoints > 1 then
			zombieHumanoid:MoveTo(waypoints[2].Position)
		else
			zombieHumanoid:MoveTo(destination)
		end
	else
		zombieHumanoid:MoveTo(destination)
	end
end

-- variables for zombie wandering behavior
local WANDER_RADIUS = 50 -- radius
local WANDER_INTERVAL = 3 -- time  between wanders
local lastWanderTime = 0 -- last wander time tracker
local isChasing = false -- chasing statetracker
local isEnraged = false -- enraged state tracker

-- main AI loop
while task.wait(0.05) do
	-- checks if the zombie is still alive
	if not zombie.Parent or zombieHumanoid.Health <= 0 then
		break
	end
	-- checks if the zombie should enter enraged state
	if not isEnraged and zombieHumanoid.Health / zombieHumanoid.MaxHealth <= currentStats.RageThreshold then
		-- sets the enraged state to true
		isEnraged = true
		-- increases walk speed and damage in enraged state
		zombieHumanoid.WalkSpeed = zombieHumanoid.WalkSpeed * 1.5
		DAMAGE_AMOUNT = DAMAGE_AMOUNT * 1.2
		-- adds a visual effect to indicate enraged state
		local rageEffect = Instance.new("PointLight", zombieTorso)
		-- sets the color brightness and range of the raged effect
		rageEffect.Color = Color3.fromRGB(255, 25, 25)
		rageEffect.Brightness = 2
		rageEffect.Range = 12
	end
	-- finds the nearest target player
	local targetTorso = findTarget()
	-- if a target is found, pathfind towards them
	if targetTorso then
		-- checks if the zombie was not already chasing
		if not isChasing then
			-- increments the chases started stat by 1
			Stats.ChasesStarted = Stats.ChasesStarted + 1
			-- sets the chasing state to true
			isChasing = true
		end
		-- pathfinds to player's torso position.
		pathfindTo(targetTorso.Position)
		-- updates the last wander time to prevent immediate wandering after chasing
		lastWanderTime = tick()
	else
		-- if no target found sets is chasing state to false
		isChasing = false
		-- checks if it's time to wander
		if tick() - lastWanderTime > WANDER_INTERVAL then
			-- updates the last wander time
			lastWanderTime = tick()
			-- increments the times wandered stat by 1
			Stats.TimesWandered = Stats.TimesWandered + 1
			-- generate a random position within the wander radius
			local angle = rng:NextNumber() * 2 * math.pi
			-- calculates the x and z offsets using cosine and sine functions
			local x = WANDER_RADIUS * math.cos(angle)
			local z = WANDER_RADIUS * math.sin(angle)
			-- calculates the wander position relative to the zombie's current position
			local wanderPosition = zombieTorso.Position + Vector3.new(x, 0, z)
			-- pathfinds to the wander position
			zombieHumanoid:MoveTo(wanderPosition)
		end
	end
end
