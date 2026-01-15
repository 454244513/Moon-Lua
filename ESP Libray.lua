local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local camera = workspace.CurrentCamera

local ESP = {}

ESP.Enabled = true
ESP.TeamCheck = false

ESP.DefaultBoxColor = Color3.fromRGB(255, 255, 255)
ESP.DefaultNameColor = Color3.fromRGB(255, 255, 255)
ESP.DefaultHealthColor = Color3.fromRGB(0, 255, 0)
ESP.DefaultFlagColor = Color3.fromRGB(255, 255, 255)

local objects = {}
local renderConnection

local function newDrawing(class)
	local obj = Drawing.new(class)
	obj.Visible = false
	return obj
end

local function getCharacterParts(char)
	local parts = {}
	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("BasePart") then
			table.insert(parts, v)
		end
	end
	return parts
end

local function getBoundingBox(parts)
	local minX, minY, maxX, maxY
	local anyOnScreen = false
	for _, part in ipairs(parts) do
		local pos, onScreen = camera:WorldToViewportPoint(part.Position)
		if onScreen and pos.Z > 0 then
			anyOnScreen = true
			if not minX then
				minX, minY, maxX, maxY = pos.X, pos.Y, pos.X, pos.Y
			else
				if pos.X < minX then
					minX = pos.X
				end
				if pos.X > maxX then
					maxX = pos.X
				end
				if pos.Y < minY then
					minY = pos.Y
				end
				if pos.Y > maxY then
					maxY = pos.Y
				end
			end
		end
	end
	if not anyOnScreen or not minX then
		return nil
	end
	return minX, minY, maxX, maxY
end

local function createForPlayer(player, options)
	local boxOutline = newDrawing("Square")
	local box = newDrawing("Square")
	local nameText = newDrawing("Text")
	local healthBg = newDrawing("Square")
	local healthBar = newDrawing("Square")
	local flagText = newDrawing("Text")

	boxOutline.Thickness = 2
	boxOutline.Filled = false

	box.Thickness = 1
	box.Filled = false

	nameText.Size = 13
	nameText.Center = true
	nameText.Outline = true

	healthBg.Filled = true
	healthBg.Thickness = 0

	healthBar.Filled = true
	healthBar.Thickness = 0

	flagText.Size = 13
	flagText.Center = false
	flagText.Outline = true

	local entry = {
		Player = player,
		Options = options or {},
		Drawings = {
			BoxOutline = boxOutline,
			Box = box,
			Name = nameText,
			HealthBg = healthBg,
			HealthBar = healthBar,
			Flag = flagText,
		},
	}

	objects[player] = entry
end

local function removeForPlayer(player)
	local entry = objects[player]
	if not entry then
		return
	end
	for _, d in pairs(entry.Drawings) do
		d.Visible = false
		d:Remove()
	end
	objects[player] = nil
end

local function updateObject(entry, dt)
	if not ESP.Enabled then
		for _, d in pairs(entry.Drawings) do
			d.Visible = false
		end
		return
	end

	local player = entry.Player
	local options = entry.Options
	local char = player.Character
	if not char then
		for _, d in pairs(entry.Drawings) do
			d.Visible = false
		end
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		for _, d in pairs(entry.Drawings) do
			d.Visible = false
		end
		return
	end

	if ESP.TeamCheck and player.Team == LocalPlayer.Team then
		for _, d in pairs(entry.Drawings) do
			d.Visible = false
		end
		return
	end

	local parts = getCharacterParts(char)
	local minX, minY, maxX, maxY = getBoundingBox(parts)
	if not minX then
		for _, d in pairs(entry.Drawings) do
			d.Visible = false
		end
		return
	end

	local boxW = maxX - minX
	local boxH = maxY - minY

	local boxColor = options.BoxColor or ESP.DefaultBoxColor
	local nameColor = options.NameColor or ESP.DefaultNameColor
	local healthColor = options.HealthColor or ESP.DefaultHealthColor
	local flagColor = options.FlagColor or ESP.DefaultFlagColor

	local boxOutline = entry.Drawings.BoxOutline
	local box = entry.Drawings.Box
	local nameText = entry.Drawings.Name
	local healthBg = entry.Drawings.HealthBg
	local healthBar = entry.Drawings.HealthBar
	local flagText = entry.Drawings.Flag

	boxOutline.Color = Color3.new(0, 0, 0)
	boxOutline.Size = Vector2.new(boxW + 4, boxH + 4)
	boxOutline.Position = Vector2.new(minX - 2, minY - 2)
	boxOutline.Visible = true

	box.Color = boxColor
	box.Size = Vector2.new(boxW, boxH)
	box.Position = Vector2.new(minX, minY)
	box.Visible = true

	local name = player.Name
	if options.NameFormatter and type(options.NameFormatter) == "function" then
		name = options.NameFormatter(player, char, hum) or name
	end

	nameText.Text = name
	nameText.Color = nameColor
	nameText.Position = Vector2.new(minX + boxW / 2, minY - 14)
	nameText.Visible = true

	local maxHealth = hum.MaxHealth > 0 and hum.MaxHealth or 100
	local hp = math.clamp(hum.Health, 0, maxHealth)
	local hpFrac = hp / maxHealth

	local barHeight = boxH
	local barWidth = 4
	local barX = minX - 6 - barWidth
	local barY = minY

	healthBg.Color = Color3.fromRGB(40, 40, 40)
	healthBg.Size = Vector2.new(barWidth, barHeight)
	healthBg.Position = Vector2.new(barX, barY)
	healthBg.Visible = true

	local fillH = barHeight * hpFrac
	healthBar.Color = healthColor
	healthBar.Size = Vector2.new(barWidth, fillH)
	healthBar.Position = Vector2.new(barX, barY + (barHeight - fillH))
	healthBar.Visible = true

	local flagTextValue = ""
	if options.FlagFormatter and type(options.FlagFormatter) == "function" then
		flagTextValue = options.FlagFormatter(player, char, hum) or ""
	elseif type(options.FlagText) == "string" then
		flagTextValue = options.FlagText
	end

	flagText.Text = flagTextValue
	flagText.Color = flagColor
	flagText.Position = Vector2.new(maxX + 6, minY)
	flagText.Visible = flagTextValue ~= ""
end

local function onRenderStep(dt)
	if not camera then
		camera = workspace.CurrentCamera
	end
	for _, entry in pairs(objects) do
		updateObject(entry, dt)
	end
end

local function ensureConnection()
	if renderConnection then
		return
	end
	renderConnection = RunService.RenderStepped:Connect(onRenderStep)
end

function ESP.AddPlayer(player, options)
	removeForPlayer(player)
	createForPlayer(player, options)
	ensureConnection()
end

function ESP.RemovePlayer(player)
	removeForPlayer(player)
end

function ESP.Clear()
	for player in pairs(objects) do
		removeForPlayer(player)
	end
end

return ESP
