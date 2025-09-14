-- Services
local PathfindingService = game:GetService("PathfindingService")
local RepStorage = game:GetService("ReplicatedStorage")

-- ================================
-- ZOMBIE TYPE CONFIGURATION
-- ================================
-- Change this to "Heavy", "Light", or "Normal"
local ZOMBIE_TYPE = "Heavy"

-- Zombie type definitions
local ZombieTypes = {
	Heavy = {
		Health = 150,
		WalkSpeed = 5,
		Damage = 25,
		AttackCooldown = 1.5,
		DisplayName = "Heavy Zombie"
	},
	Light = {
		Health = 75,
		WalkSpeed = 16,
		Damage = 6,
		AttackCooldown = 0.6,
		DisplayName = "Light Zombie"
	},
	Normal = {
		Health = 100,
		WalkSpeed = 10,
		Damage = 10,
		AttackCooldown = 1.0,
		DisplayName = "Normal Zombie"
	}
}

-- Get the current zombie's stats
local currentStats = ZombieTypes[ZOMBIE_TYPE]
if not currentStats then
	warn("Invalid zombie type: " .. tostring(ZOMBIE_TYPE))
	return
end

-- ================================
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
	warn("Zombie template not found in ReplicatedStorage: " .. tostring(templateName))
	return
end

-- ================================
-- Grab zombie parts
-- ================================
local zombie = script.Parent
local zombieTorso = zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("HumanoidRootPart")
local zombieHumanoid = zombie:FindFirstChild("Humanoid")

if not zombieTorso or not zombieHumanoid then
	warn("Zombie is missing parts (torso/humanoid), can't run AI.")
	return
end

-- Apply zombie type stats
zombieHumanoid.MaxHealth = currentStats.Health
zombieHumanoid.Health = currentStats.Health
zombieHumanoid.WalkSpeed = currentStats.WalkSpeed
zombie.Name = currentStats.DisplayName
zombieHumanoid.DisplayName = currentStats.DisplayName

-- Default stats (with safe indexing)
local Stats = setmetatable({}, {
	__index = function(t, k) return 0 end
})

-- Track time alive
local spawnTime = tick()

-- ================================
-- AI helper functions
-- ================================
local function findTarget()
	local agroDistance = 100
	local target = nil
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player.Character then
			local human = player.Character:FindFirstChild("Humanoid")
			local torso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("HumanoidRootPart")
			if human and torso and human.Health > 0 then
				local distance = (zombieTorso.Position - torso.Position).Magnitude
				if distance < agroDistance then
					agroDistance = distance
					target = torso
				end
			end
		end
	end
	return target
end

-- Damage variables
local DAMAGE_AMOUNT = currentStats.Damage
local ATTACK_COOLDOWN = currentStats.AttackCooldown
local lastAttackTime = 0

-- Damage handler
local function onTouched(hit)
	local character = hit.Parent
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and game.Players:GetPlayerFromCharacter(character) then
		local currentTime = tick()
		if currentTime - lastAttackTime >= ATTACK_COOLDOWN then
			lastAttackTime = currentTime

			local healthBefore = humanoid.Health
			humanoid:TakeDamage(DAMAGE_AMOUNT)

			Stats.HitsLanded = Stats.HitsLanded + 1
			Stats.DamageDealt = Stats.DamageDealt + DAMAGE_AMOUNT

			if humanoid.Health <= 0 and healthBefore > 0 then
				Stats.Kills = Stats.Kills + 1
				print(character.Name .. " got taken out by the zombie!")
			end

			print("Zombie hit " .. character.Name .. ". Damage so far: " .. Stats.DamageDealt)
		end
	end
end

zombieTorso.Touched:Connect(onTouched)

-- ================================
-- Death + Respawn
-- ================================
zombieHumanoid.Died:Connect(function()
	Stats.Deaths = Stats.Deaths + 1
	Stats.TimeAlive = tick() - spawnTime

	print("--- Zombie Stats ---")
	print("Time Alive: " .. string.format("%.2f", Stats.TimeAlive) .. "s")
	print("Kills: " .. Stats.Kills)
	print("Hits: " .. Stats.HitsLanded)
	print("Damage: " .. Stats.DamageDealt)
	print("Chases: " .. Stats.ChasesStarted)
	print("Wanders: " .. Stats.TimesWandered)
	print("--------------------")

	task.wait(5)
	local newZombie = zombieTemplate:Clone()
	newZombie.Name = currentStats.DisplayName

	local hum = newZombie:FindFirstChild("Humanoid")
	if hum then
		hum.DisplayName = currentStats.DisplayName
	end

	local newTorso = newZombie:FindFirstChild("Torso") or newZombie:FindFirstChild("UpperTorso") or newZombie:FindFirstChild("HumanoidRootPart")
	if newTorso then
		newTorso.CFrame = zombieTorso.CFrame
	end

	newZombie.Parent = workspace
	local newScript = script:Clone()
	newScript.Parent = newZombie

	zombie:Destroy()
end)

-- ================================
-- Movement (pathfinding + wandering)
-- ================================
local function pathfindTo(destination)
	local path = PathfindingService:CreatePath()
	path:ComputeAsync(zombieTorso.Position, destination)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints > 1 then
			zombieHumanoid:MoveTo(waypoints[2].Position)
		else
			zombieHumanoid:MoveTo(destination)
		end
	else
		zombieHumanoid:MoveTo(destination)
	end
end

-- Main loop
local WANDER_RADIUS = 50
local WANDER_INTERVAL = 3
local lastWanderTime = 0
local isChasing = false

while task.wait(0.05) do
	if not zombie.Parent or zombieHumanoid.Health <= 0 then
		break
	end

	local targetTorso = findTarget()

	if targetTorso then
		if not isChasing then
			Stats.ChasesStarted = Stats.ChasesStarted + 1
			isChasing = true
		end
		pathfindTo(targetTorso.Position)
		lastWanderTime = tick()
	else
		isChasing = false
		if tick() - lastWanderTime > WANDER_INTERVAL then
			lastWanderTime = tick()
			Stats.TimesWandered = Stats.TimesWandered + 1

			local angle = math.random() * 2 * math.pi
			local x = WANDER_RADIUS * math.cos(angle)
			local z = WANDER_RADIUS * math.sin(angle)
			
			local wanderPosition = zombieTorso.Position + Vector3.new(x, 0, z)
			zombieHumanoid:MoveTo(wanderPosition)
		end
	end
end
