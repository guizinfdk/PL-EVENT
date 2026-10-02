--[[
    PL EVENT - Painel Cyberpunk
    - Aba 🌀 : SmartPrompt Egg + Humanoid Bypass
    - Aba ⚡ : Speed (BodyVelocity)
    - Aba 🌌 : CarryEgg Auto TP
    - Aba 🌪️ : TP Areas (GuardAreas)
    - Aba 🔍 : Lista de Ovos + Steal Top (nova versão)
    - Tab bar arrastável lateralmente
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local playerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== CLEANUP ====================
local ENV = (getgenv and getgenv()) or _G
if ENV.PLEVENT_GUI then
	pcall(function() ENV.PLEVENT_GUI:Destroy() end)
end

-- ==================== PALETA CYBERPUNK ====================
local BG_COLOR    = Color3.fromRGB(12, 12, 22)
local TITLE_COLOR = Color3.fromRGB(18, 18, 32)
local ACCENT      = Color3.fromRGB(0, 255, 220)
local ACCENT_2    = Color3.fromRGB(255, 0, 140)
local TAB_IDLE    = Color3.fromRGB(22, 22, 38)
local TAB_ACTIVE  = Color3.fromRGB(40, 40, 65)
local TEXT_DIM    = Color3.fromRGB(180, 200, 210)
local BTN_IDLE    = Color3.fromRGB(28, 28, 44)
local BTN_HOVER   = Color3.fromRGB(45, 45, 70)
local BTN_ON      = Color3.fromRGB(0, 130, 110)

-- ==================== CONFIG EGG ====================
local RISE_HEIGHT      = 150
local TWEEN_DURATION   = 0.6
local WANDER_RANGE     = 8
local WANDER_MIN_TIME  = 0.08
local WANDER_MAX_TIME  = 0.22
local WANDER_SPEED     = 90
local SPAWN_NEAR_DIST  = 60
local CHANCE_GO_SPAWN  = 0.4

-- ==================== CONFIG CARRY EGG TP ====================
local VelocidadeRun    = 1e15
local DistanciaChegada = 4
local IgnorarY         = true
local WalkSpeedTemp    = 500
local JumpPowerTemp    = 120
local NomePart         = "SmartPromptPart"
local NomePrompt       = "CarryAreaEgg"
local HoldMinima       = 1.0

-- ==================== BYPASS ====================
local Bypass = {
	Enabled = false, InProgress = false, LastChar = nil,
	OriginalHumanoid = nil, CloneHumanoid = nil, _conn = nil, _autoApply = true,
}

local PROPS_TO_COPY = {
	"WalkSpeed","JumpPower","JumpHeight","UseJumpPower",
	"MaxHealth","Health","AutoRotate","AutoJumpEnabled","BreakJointsOnDeath",
	"CameraOffset","DisplayDistanceType","HealthDisplayDistance","HealthDisplayType",
	"NameDisplayDistance","NameOcclusion","RequiresNeck","WalkJumpPower","HipHeight",
	"RigType","WalkSpeedCheck","EvaluateStateMachine","MaxSlopeAngle","AutomaticScalingEnabled",
}

local STATE_ENUMS = {
	Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.Landed,
	Enum.HumanoidStateType.Flying, Enum.HumanoidStateType.Freefall,
	Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.PlatformStanding,
	Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Physics,
	Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Running, Enum.HumanoidStateType.RunningNoPhysics,
	Enum.HumanoidStateType.StrafingNoPhysics, Enum.HumanoidStateType.Jumping,
}

local function blog(msg) warn("[BYPASS] " .. msg) end

local function copyProperties(orig, clone)
	for _, prop in ipairs(PROPS_TO_COPY) do
		pcall(function()
			local ok, value = pcall(function() return orig[prop] end)
			if ok and value ~= nil then pcall(function() clone[prop] = value end) end
		end)
	end
	pcall(function()
		for k, v in pairs(orig:GetAttributes()) do
			pcall(function() clone:SetAttribute(k, v) end)
		end
	end)
	pcall(function()
		local desc = orig:FindFirstChildOfClass("HumanoidDescription")
		if desc then desc:Clone().Parent = clone end
	end)
end

local function captureStates(hum)
	local states = {}
	for _, s in ipairs(STATE_ENUMS) do
		local ok, enabled = pcall(function() return hum:GetStateEnabled(s) end)
		if ok then states[s] = enabled end
	end
	local curState
	pcall(function() curState = hum:GetState() end)
	return states, curState
end

local function reapplyStates(hum, states, curState)
	for s, enabled in pairs(states or {}) do
		pcall(function() hum:SetStateEnabled(s, enabled) end)
	end
	if curState then pcall(function() hum:ChangeState(curState) end) end
end

function Bypass.Apply(character)
	if Bypass.InProgress then blog("Já em andamento."); return false end
	Bypass.InProgress = true
	character = character or LocalPlayer.Character
	if not character then Bypass.InProgress = false; blog("Personagem não encontrado."); return false end
	local origHum = character:FindFirstChildOfClass("Humanoid")
	if not origHum then
		local ok = pcall(function() origHum = character:WaitForChild("Humanoid", 10) end)
		if not ok or not origHum then Bypass.InProgress = false; blog("Humanoid não encontrado."); return false end
	end
	local cloneHum
	local okClone = pcall(function() cloneHum = origHum:Clone() end)
	if not okClone or not cloneHum then Bypass.InProgress = false; blog("Falha ao clonar."); return false end
	local animatorMoved = false
	local animator = origHum:FindFirstChildOfClass("Animator")
	if animator then
		local ok = pcall(function() animator.Parent = cloneHum end)
		animatorMoved = ok
	end
	copyProperties(origHum, cloneHum)
	local states, curState = captureStates(origHum)
	pcall(function() cloneHum.Name = "Humanoid" end)
	local okParent = pcall(function() cloneHum.Parent = character end)
	if not okParent then
		if animatorMoved and animator and animator.Parent ~= origHum then
			pcall(function() animator.Parent = origHum end)
		end
		Bypass.InProgress = false; blog("Falha ao parentear clone."); return false
	end
	task.wait(0.05)
	if not pcall(function() origHum:Destroy() end) then
		pcall(function() cloneHum:Destroy() end)
		Bypass.InProgress = false; blog("Falha ao destruir original."); return false
	end
	task.wait(0.05)
	pcall(function()
		if Workspace.CurrentCamera then Workspace.CurrentCamera.CameraSubject = cloneHum end
	end)
	reapplyStates(cloneHum, states, curState)
	pcall(function()
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Parent = character end
	end)
	Bypass.LastChar, Bypass.OriginalHumanoid, Bypass.CloneHumanoid = character, origHum, cloneHum
	Bypass.InProgress = false
	blog("Aplicado com sucesso.")
	return true
end

-- ==================== SPEED ====================
local Speed = {
	Active = false, Conn = nil, BV = nil, Attachment = nil,
	LastChar = nil, Value = 50,
}

local function getRootAndHumanoid()
	local char = LocalPlayer.Character
	if not char or not char.Parent then return nil, nil end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return nil, nil end
	if hum.Health <= 0 then return nil, nil end
	return root, hum
end

function Speed:Cleanup()
	if self.Conn then pcall(function() self.Conn:Disconnect() end); self.Conn = nil end
	if self.BV then pcall(function() self.BV:Destroy() end); self.BV = nil end
	if self.Attachment then pcall(function() self.Attachment:Destroy() end); self.Attachment = nil end
	self.LastChar = nil
end

function Speed:Attach()
	local root = getRootAndHumanoid()
	if not root then return false end
	if self.BV then pcall(function() self.BV:Destroy() end) end
	if self.Attachment then pcall(function() self.Attachment:Destroy() end) end
	local att = Instance.new("Attachment")
	att.Name = "SpeedAttachment"
	att.Parent = root
	local bv = Instance.new("BodyVelocity")
	bv.Name = "SpeedBodyVelocity"
	bv.MaxForce = Vector3.new(1e5, 0, 1e5)
	bv.Velocity = Vector3.zero
	bv.P = 1250
	bv.Parent = root
	self.Attachment = att
	self.BV = bv
	self.LastChar = LocalPlayer.Character
	return true
end

function Speed:HeartbeatStep()
	if LocalPlayer.Character ~= self.LastChar then self:Attach() end
	local root, hum = getRootAndHumanoid()
	if not root or not hum then
		if self.BV and self.BV.Parent then self.BV.Velocity = Vector3.zero end
		return
	end
	if not self.BV or not self.BV.Parent then
		if not self:Attach() then return end
		root, hum = getRootAndHumanoid()
		if not root then return end
	end
	if ENV.FlyActive then self.BV.Velocity = Vector3.zero; return end
	local dir = hum.MoveDirection
	if dir.Magnitude > 0.01 then
		self.BV.Velocity = dir * self.Value
	else
		self.BV.Velocity = Vector3.zero
	end
end

function Speed:Start()
	if self.Active then return end
	if not self:Attach() then return end
	self.Active = true
	self.Conn = RunService.Heartbeat:Connect(function()
		local ok, err = pcall(function() self:HeartbeatStep() end)
		if not ok then warn("[Speed] Heartbeat error:", err) end
	end)
end

function Speed:Stop()
	self.Active = false
	self:Cleanup()
end

function Speed:SetValue(v)
	self.Value = math.clamp(tonumber(v) or 50, 1, 500)
end

-- ==================== SCREEN GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PLEVENT"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui
ENV.PLEVENT_GUI = screenGui

-- ==================== JANELA ====================
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 200, 0, 220)
main.Position = UDim2.new(0.5, -100, 0.5, -110)
main.BackgroundColor3 = BG_COLOR
main.BorderSizePixel = 0
main.Active = true
main.Parent = screenGui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = ACCENT; mainStroke.Thickness = 1.5; mainStroke.Transparency = 0.25
mainStroke.Parent = main

-- ==================== TITLE BAR ====================
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = TITLE_COLOR
titleBar.BorderSizePixel = 0
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

local tbFix = Instance.new("Frame")
tbFix.Size = UDim2.new(1, 0, 0, 6)
tbFix.Position = UDim2.new(0, 0, 1, -6)
tbFix.BackgroundColor3 = TITLE_COLOR
tbFix.BorderSizePixel = 0
tbFix.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "PL EVENT"
titleLabel.TextColor3 = ACCENT
titleLabel.Font = Enum.Font.Code
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local titleGlow = Instance.new("UIStroke")
titleGlow.Color = ACCENT; titleGlow.Thickness = 1; titleGlow.Transparency = 0.65
titleGlow.Parent = titleLabel

-- ==================== BOTÕES JANELA ====================
local function criarBotaoJanela(texto, offsetX, cor)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 20, 0, 20)
	btn.Position = UDim2.new(1, offsetX, 0, 5)
	btn.BackgroundColor3 = BTN_IDLE
	btn.Text = texto; btn.TextColor3 = cor
	btn.Font = Enum.Font.Code; btn.TextSize = 14
	btn.BorderSizePixel = 0; btn.AutoButtonColor = false
	btn.Parent = titleBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
	btn.MouseEnter:Connect(function() btn.BackgroundColor3 = BTN_HOVER end)
	btn.MouseLeave:Connect(function() btn.BackgroundColor3 = BTN_IDLE end)
	return btn
end

local btnMin   = criarBotaoJanela("—", -50, ACCENT)
local btnClose = criarBotaoJanela("✕", -25, ACCENT_2)

-- ==================== TAB BAR ====================
local TAB_W = 60
local TAB_GAP = 2
local abasDef = {
	{ emoji = "🌀", nome = "Event"    },
	{ emoji = "⚡", nome = "Speed"    },
	{ emoji = "🌌", nome = "CarryEgg" },
	{ emoji = "🌪️", nome = "Areas"    },
	{ emoji = "🔍", nome = "Eggs"     },
}
local totalTabsWidth = (#abasDef) * (TAB_W + TAB_GAP) + TAB_GAP

local tabBar = Instance.new("ScrollingFrame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -10, 0, 26)
tabBar.Position = UDim2.new(0, 5, 0, 36)
tabBar.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
tabBar.BorderSizePixel = 0
tabBar.ScrollBarThickness = 0
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.ScrollingEnabled = true
tabBar.ElasticBehavior = Enum.ElasticBehavior.Never
tabBar.CanvasSize = UDim2.new(0, totalTabsWidth, 0, 26)
tabBar.Parent = main
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 4)

-- ==================== PAGE HOLDER ====================
local pageHolder = Instance.new("Frame")
pageHolder.Size = UDim2.new(1, -10, 1, -78)
pageHolder.Position = UDim2.new(0, 5, 0, 68)
pageHolder.BackgroundTransparency = 1
pageHolder.Parent = main

-- ==================== ABAS ====================
local abas, pages = {}, {}

for i, data in ipairs(abasDef) do
	local tab = Instance.new("TextButton")
	tab.Size = UDim2.new(0, TAB_W, 1, 0)
	tab.Position = UDim2.new(0, TAB_GAP + (i - 1) * (TAB_W + TAB_GAP), 0, 0)
	tab.BackgroundColor3 = TAB_IDLE
	tab.Text = data.emoji
	tab.TextColor3 = TEXT_DIM
	tab.Font = Enum.Font.Code
	tab.TextSize = 16
	tab.BorderSizePixel = 0
	tab.AutoButtonColor = false
	tab.Parent = tabBar
	Instance.new("UICorner", tab).CornerRadius = UDim.new(0, 4)

	local page = Instance.new("Frame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
	page.BorderSizePixel = 0
	page.Visible = (i == 1)
	page.Parent = pageHolder
	Instance.new("UICorner", page).CornerRadius = UDim.new(0, 6)

	local ps = Instance.new("UIStroke")
	ps.Color = ACCENT; ps.Thickness = 1; ps.Transparency = 0.75
	ps.Parent = page

	abas[i], pages[i] = tab, page
end

local tbDragMoved = false
for i = 1, #abas do
	abas[i].MouseButton1Click:Connect(function()
		if tbDragMoved then return end
		for j = 1, #abas do
			pages[j].Visible = (j == i)
			abas[j].BackgroundColor3 = (j == i) and TAB_ACTIVE or TAB_IDLE
			abas[j].TextColor3 = (j == i) and ACCENT or TEXT_DIM
		end
	end)
end
abas[1].BackgroundColor3 = TAB_ACTIVE
abas[1].TextColor3 = ACCENT

-- Drag horizontal da tabBar
local tbDragActive, tbDragStartX, tbScrollStartX = false, 0, 0
local DRAG_THRESHOLD = 5

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local barPos, barSize = tabBar.AbsolutePosition, tabBar.AbsoluteSize
		if pos.X >= barPos.X and pos.X <= barPos.X + barSize.X
		and pos.Y >= barPos.Y and pos.Y <= barPos.Y + barSize.Y then
			tbDragActive = true
			tbDragStartX = input.Position.X
			tbScrollStartX = tabBar.CanvasPosition.X
			tbDragMoved = false
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not tbDragActive then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position.X - tbDragStartX
		if math.abs(delta) > DRAG_THRESHOLD then tbDragMoved = true end
		local maxScroll = math.max(0, tabBar.AbsoluteCanvasSize.X - tabBar.AbsoluteSize.X)
		local newX = math.clamp(tbScrollStartX - delta, 0, maxScroll)
		tabBar.CanvasPosition = Vector2.new(newX, 0)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		tbDragActive = false
		task.defer(function()
			task.wait()
			tbDragMoved = false
		end)
	end
end)

-- ============================================================
-- PÁGINA 1 — SMART PROMPT EGG + BYPASS
-- ============================================================
local page1 = pages[1]

local BypassBtn = Instance.new("TextButton")
BypassBtn.Size = UDim2.new(1, -16, 0, 30)
BypassBtn.Position = UDim2.new(0, 8, 0, 8)
BypassBtn.BackgroundColor3 = BTN_IDLE
BypassBtn.Text = "⚡ Ativar Bypass"
BypassBtn.TextColor3 = TEXT_DIM
BypassBtn.Font = Enum.Font.Code
BypassBtn.TextSize = 13
BypassBtn.BorderSizePixel = 0
BypassBtn.AutoButtonColor = false
BypassBtn.Parent = page1
Instance.new("UICorner", BypassBtn).CornerRadius = UDim.new(0, 4)
local bbs = Instance.new("UIStroke")
bbs.Color = ACCENT; bbs.Thickness = 1; bbs.Transparency = 0.5
bbs.Parent = BypassBtn

BypassBtn.MouseEnter:Connect(function()
	if not Bypass.Enabled then BypassBtn.BackgroundColor3 = BTN_HOVER end
end)
BypassBtn.MouseLeave:Connect(function()
	if not Bypass.Enabled then BypassBtn.BackgroundColor3 = BTN_IDLE end
end)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -16, 0, 30)
ToggleBtn.Position = UDim2.new(0, 8, 0, 44)
ToggleBtn.BackgroundColor3 = BTN_IDLE
ToggleBtn.Text = "🌀 Ativar Egg"
ToggleBtn.TextColor3 = TEXT_DIM
ToggleBtn.Font = Enum.Font.Code
ToggleBtn.TextSize = 13
ToggleBtn.BorderSizePixel = 0
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = page1
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 4)
local tbs = Instance.new("UIStroke")
tbs.Color = ACCENT; tbs.Thickness = 1; tbs.Transparency = 0.5
tbs.Parent = ToggleBtn

local eggStateRef = nil
ToggleBtn.MouseEnter:Connect(function()
	if not eggStateRef or not eggStateRef.active then ToggleBtn.BackgroundColor3 = BTN_HOVER end
end)
ToggleBtn.MouseLeave:Connect(function()
	if not eggStateRef or not eggStateRef.active then ToggleBtn.BackgroundColor3 = BTN_IDLE end
end)

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, -16, 1, -84)
Info.Position = UDim2.new(0, 8, 0, 80)
Info.BackgroundTransparency = 1
Info.Text = "Status: Aguardando..."
Info.TextColor3 = TEXT_DIM
Info.Font = Enum.Font.Code
Info.TextSize = 11
Info.TextWrapped = true
Info.TextXAlignment = Enum.TextXAlignment.Left
Info.TextYAlignment = Enum.TextYAlignment.Top
Info.Parent = page1

-- ============================================================
-- PÁGINA 2 — SPEED
-- ============================================================
local page2 = pages[2]

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(1, -16, 0, 30)
SpeedToggle.Position = UDim2.new(0, 8, 0, 8)
SpeedToggle.BackgroundColor3 = BTN_IDLE
SpeedToggle.Text = "⚡ Speed: OFF"
SpeedToggle.TextColor3 = TEXT_DIM
SpeedToggle.Font = Enum.Font.Code
SpeedToggle.TextSize = 13
SpeedToggle.BorderSizePixel = 0
SpeedToggle.AutoButtonColor = false
SpeedToggle.Parent = page2
Instance.new("UICorner", SpeedToggle).CornerRadius = UDim.new(0, 4)
local sts = Instance.new("UIStroke")
sts.Color = ACCENT; sts.Thickness = 1; sts.Transparency = 0.5
sts.Parent = SpeedToggle

SpeedToggle.MouseEnter:Connect(function()
	if not Speed.Active then SpeedToggle.BackgroundColor3 = BTN_HOVER end
end)
SpeedToggle.MouseLeave:Connect(function()
	if not Speed.Active then SpeedToggle.BackgroundColor3 = BTN_IDLE end
end)

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(1, -16, 0, 26)
SpeedBox.Position = UDim2.new(0, 8, 0, 44)
SpeedBox.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
SpeedBox.BorderSizePixel = 0
SpeedBox.Text = tostring(Speed.Value)
SpeedBox.TextColor3 = ACCENT
SpeedBox.PlaceholderText = "studs/s"
SpeedBox.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
SpeedBox.Font = Enum.Font.Code
SpeedBox.TextSize = 12
SpeedBox.ClearTextOnFocus = false
SpeedBox.Parent = page2
Instance.new("UICorner", SpeedBox).CornerRadius = UDim.new(0, 4)
local sbs = Instance.new("UIStroke")
sbs.Color = ACCENT; sbs.Thickness = 1; sbs.Transparency = 0.6
sbs.Parent = SpeedBox

local SpeedStatus = Instance.new("TextLabel")
SpeedStatus.Size = UDim2.new(1, -16, 1, -84)
SpeedStatus.Position = UDim2.new(0, 8, 0, 80)
SpeedStatus.BackgroundTransparency = 1
SpeedStatus.Text = "Status: Desligado"
SpeedStatus.TextColor3 = TEXT_DIM
SpeedStatus.Font = Enum.Font.Code
SpeedStatus.TextSize = 11
SpeedStatus.TextWrapped = true
SpeedStatus.TextXAlignment = Enum.TextXAlignment.Left
SpeedStatus.TextYAlignment = Enum.TextYAlignment.Top
SpeedStatus.Parent = page2

-- ============================================================
-- PÁGINA 3 — CARRY EGG AUTO TP
-- ============================================================
local page3 = pages[3]

local CarryBtn = Instance.new("TextButton")
CarryBtn.Size = UDim2.new(1, -16, 0, 30)
CarryBtn.Position = UDim2.new(0, 8, 0, 8)
CarryBtn.BackgroundColor3 = BTN_IDLE
CarryBtn.Text = "🌌 CarryEgg: OFF"
CarryBtn.TextColor3 = TEXT_DIM
CarryBtn.Font = Enum.Font.Code
CarryBtn.TextSize = 12
CarryBtn.BorderSizePixel = 0
CarryBtn.AutoButtonColor = false
CarryBtn.Parent = page3
Instance.new("UICorner", CarryBtn).CornerRadius = UDim.new(0, 4)
local cbs = Instance.new("UIStroke")
cbs.Color = ACCENT; cbs.Thickness = 1; cbs.Transparency = 0.5
cbs.Parent = CarryBtn

CarryBtn.MouseEnter:Connect(function()
	if not ENV._CarryAtivo then CarryBtn.BackgroundColor3 = BTN_HOVER end
end)
CarryBtn.MouseLeave:Connect(function()
	if not ENV._CarryAtivo then CarryBtn.BackgroundColor3 = BTN_IDLE end
end)

local CarryStatus = Instance.new("TextLabel")
CarryStatus.Size = UDim2.new(1, -16, 1, -50)
CarryStatus.Position = UDim2.new(0, 8, 0, 44)
CarryStatus.BackgroundTransparency = 1
CarryStatus.Text = "Status: Desligado\nTP disfarçado p/ spawn"
CarryStatus.TextColor3 = TEXT_DIM
CarryStatus.Font = Enum.Font.Code
CarryStatus.TextSize = 11
CarryStatus.TextWrapped = true
CarryStatus.TextXAlignment = Enum.TextXAlignment.Left
CarryStatus.TextYAlignment = Enum.TextYAlignment.Top
CarryStatus.Parent = page3

-- ============================================================
-- PÁGINA 4 — TP AREAS (GuardAreas)
-- ============================================================
local page4 = pages[4]

local GuardStatus = Instance.new("TextLabel")
GuardStatus.Size = UDim2.new(1, -16, 0, 14)
GuardStatus.Position = UDim2.new(0, 8, 0, 2)
GuardStatus.BackgroundTransparency = 1
GuardStatus.Text = "Selecione uma área..."
GuardStatus.TextColor3 = TEXT_DIM
GuardStatus.Font = Enum.Font.Code
GuardStatus.TextSize = 10
GuardStatus.TextXAlignment = Enum.TextXAlignment.Left
GuardStatus.Parent = page4

local GuardScroll = Instance.new("ScrollingFrame")
GuardScroll.Size = UDim2.new(1, -16, 0, 92)
GuardScroll.Position = UDim2.new(0, 8, 0, 18)
GuardScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 36)
GuardScroll.BorderSizePixel = 0
GuardScroll.ScrollBarThickness = 4
GuardScroll.ScrollBarImageColor3 = ACCENT
GuardScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
GuardScroll.Parent = page4
Instance.new("UICorner", GuardScroll).CornerRadius = UDim.new(0, 4)
local GuardScrollStroke = Instance.new("UIStroke")
GuardScrollStroke.Color = ACCENT; GuardScrollStroke.Thickness = 1; GuardScrollStroke.Transparency = 0.7
GuardScrollStroke.Parent = GuardScroll

local GuardList = Instance.new("UIListLayout")
GuardList.Parent = GuardScroll
GuardList.SortOrder = Enum.SortOrder.LayoutOrder
GuardList.Padding = UDim.new(0, 3)

local GuardPad = Instance.new("UIPadding")
GuardPad.PaddingTop = UDim.new(0, 4)
GuardPad.PaddingLeft = UDim.new(0, 4)
GuardPad.PaddingRight = UDim.new(0, 4)
GuardPad.PaddingBottom = UDim.new(0, 4)
GuardPad.Parent = GuardScroll

local GuardTPBtn = Instance.new("TextButton")
GuardTPBtn.Size = UDim2.new(1, -16, 0, 26)
GuardTPBtn.Position = UDim2.new(0, 8, 1, -30)
GuardTPBtn.BackgroundColor3 = BTN_IDLE
GuardTPBtn.Text = "🌪️ TP-AREA"
GuardTPBtn.TextColor3 = TEXT_DIM
GuardTPBtn.Font = Enum.Font.Code
GuardTPBtn.TextSize = 12
GuardTPBtn.BorderSizePixel = 0
GuardTPBtn.AutoButtonColor = false
GuardTPBtn.Parent = page4
Instance.new("UICorner", GuardTPBtn).CornerRadius = UDim.new(0, 4)
local gtbs = Instance.new("UIStroke")
gtbs.Color = ACCENT; gtbs.Thickness = 1; gtbs.Transparency = 0.5
gtbs.Parent = GuardTPBtn

GuardTPBtn.MouseEnter:Connect(function() GuardTPBtn.BackgroundColor3 = BTN_HOVER end)
GuardTPBtn.MouseLeave:Connect(function() GuardTPBtn.BackgroundColor3 = BTN_IDLE end)

-- ============================================================
-- PÁGINA 5 — LISTA DE OVOS + STEAL TOP
-- ============================================================
local page5 = pages[5]

local EggList_MaxDist = 1000
local EggList_TargetRarity = "Todos"
local EggList_FiltroNiveis = { "Todos","Common","Uncommon","Rare","Epic","Legendary","Mythic","Cosmic","Secret","Eternal","Divine" }
local EggList_FiltroIdx = 1

local EggList_RARITY_SCORE_MAP = {
	["Light & Dark"]=1300, ["Titan"]=1100, ["Divine"]=1000,
	["Transcendent"]=1000, ["Superior"]=1000, ["Eternal"]=900,
	["Limited"]=900, ["Secret"]=800, ["Exotic"]=800,
	["Cosmic"]=700, ["Exclusive"]=700, ["Admin"]=700,
	["Mythic"]=600, ["Mythical"]=600, ["Prismatic"]=600,
	["Rainbow"]=600, ["Squishy God"]=600, ["BrainrotGod"]=600,
	["Legendary"]=500, ["Epic"]=400, ["Rare"]=300,
	["SuperRare"]=200, ["Celestial"]=200, ["Uncommon"]=200,
	["Basic"]=100, ["Common"]=100,
}

local EggState, AreasData, RarityData, AssetsData, PetsData
pcall(function() EggState   = require(ReplicatedStorage.Client.EggState) end)
pcall(function() AreasData  = require(ReplicatedStorage.Data.Areas) end)
pcall(function() RarityData = require(ReplicatedStorage.Data.Rarity) end)
pcall(function() AssetsData = require(ReplicatedStorage.Data.Assets) end)
pcall(function() PetsData   = require(ReplicatedStorage.Data.Pets) end)

local EggList_iconCache   = {}
local EggList_rarityCache = {}

local function GetEggRarityInfo(egg)
	if not egg then return "Common", 100 end
	if egg.Rarity then
		local r = egg.Rarity
		local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
		return name, EggList_RARITY_SCORE_MAP[name] or 100
	end
	local cat = egg.AssetCategory or egg.Category or egg.Name
	if cat and AssetsData then
		local aInfo = (AssetsData.Directory or AssetsData)[cat]
		if aInfo and aInfo.Rarity then
			local r = aInfo.Rarity
			local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
			return name, EggList_RARITY_SCORE_MAP[name] or 100
		end
	end
	local areaData = AreasData and (AreasData.Directory or AreasData) and (AreasData.Directory or AreasData)[egg.AreaId]
	local rarity = areaData and areaData.Rarity
	local rarityId = (type(rarity) == "table" and (rarity._id or rarity.DisplayName or rarity.Name)) or (type(rarity) == "string" and rarity) or "Common"
	local rInfo = (RarityData and (RarityData.Rarities or RarityData) or {})[rarityId] or {}
	local rarityDisplayName = (type(rInfo) == "table" and (rInfo.DisplayName or rInfo._id)) or (type(rarity) == "table" and rarity.DisplayName) or rarityId or "Common"
	return rarityDisplayName, EggList_RARITY_SCORE_MAP[rarityDisplayName] or 100
end

local function GetPetIcon(record)
	if not record then return nil end
	local targetName = record.Pet or record.PetId or record.PetName or record.AssetCategory or record.Category
	if targetName then
		local c = EggList_iconCache[targetName]
		if c ~= nil then return c end
	end
	local rawIcon = record.Icon or record.PetIcon or record.ImageAsset or record.TextureId
	local result
	if rawIcon then
		result = (type(rawIcon) == "number" or not string.match(tostring(rawIcon), "://"))
			and ("rbxassetid://" .. tostring(rawIcon)) or tostring(rawIcon)
	elseif targetName then
		if PetsData then
			local pInfo = (PetsData.Directory or PetsData)[targetName]
			if pInfo and (pInfo.Icon or pInfo.Image or pInfo.AssetId) then
				local img = pInfo.Icon or pInfo.Image or pInfo.AssetId
				result = (type(img) == "number" or not string.match(tostring(img), "://"))
					and ("rbxassetid://" .. tostring(img)) or tostring(img)
			end
		end
		if not result and AssetsData then
			local aInfo = (AssetsData.Directory or AssetsData)[targetName]
			if aInfo and (aInfo.Icon or aInfo.Image or aInfo.AssetId) then
				local img = aInfo.Icon or aInfo.Image or aInfo.AssetId
				result = (type(img) == "number" or not string.match(tostring(img), "://"))
					and ("rbxassetid://" .. tostring(img)) or tostring(img)
			end
		end
	end
	if targetName then EggList_iconCache[targetName] = result end
	return result
end

-- UI da aba 5 ---------------------------------------------------
local EggFilterBtn = Instance.new("TextButton")
EggFilterBtn.Size = UDim2.new(0, 100, 0, 20)
EggFilterBtn.Position = UDim2.new(0, 0, 0, 0)
EggFilterBtn.BackgroundColor3 = BTN_IDLE
EggFilterBtn.Text = "Filtro: Todos"
EggFilterBtn.TextColor3 = TEXT_DIM
EggFilterBtn.Font = Enum.Font.Code
EggFilterBtn.TextSize = 10
EggFilterBtn.BorderSizePixel = 0
EggFilterBtn.AutoButtonColor = false
EggFilterBtn.Parent = page5
Instance.new("UICorner", EggFilterBtn).CornerRadius = UDim.new(0, 4)
local efbStroke = Instance.new("UIStroke")
efbStroke.Color = ACCENT; efbStroke.Thickness = 1; efbStroke.Transparency = 0.5
efbStroke.Parent = EggFilterBtn

EggFilterBtn.MouseEnter:Connect(function() EggFilterBtn.BackgroundColor3 = BTN_HOVER end)
EggFilterBtn.MouseLeave:Connect(function() EggFilterBtn.BackgroundColor3 = BTN_IDLE end)

local EggDistInput = Instance.new("TextBox")
EggDistInput.Size = UDim2.new(0, 82, 0, 20)
EggDistInput.Position = UDim2.new(1, -82, 0, 0)
EggDistInput.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
EggDistInput.BorderSizePixel = 0
EggDistInput.Text = tostring(EggList_MaxDist)
EggDistInput.TextColor3 = ACCENT
EggDistInput.PlaceholderText = "dist"
EggDistInput.PlaceholderColor3 = Color3.fromRGB(120, 130, 150)
EggDistInput.Font = Enum.Font.Code
EggDistInput.TextSize = 10
EggDistInput.ClearTextOnFocus = false
EggDistInput.Parent = page5
Instance.new("UICorner", EggDistInput).CornerRadius = UDim.new(0, 4)
local ediStroke = Instance.new("UIStroke")
ediStroke.Color = ACCENT; ediStroke.Thickness = 1; ediStroke.Transparency = 0.6
ediStroke.Parent = EggDistInput

local EggListFrame = Instance.new("ScrollingFrame")
EggListFrame.Size = UDim2.new(1, 0, 1, -48)
EggListFrame.Position = UDim2.new(0, 0, 0, 24)
EggListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 36)
EggListFrame.BorderSizePixel = 0
EggListFrame.ScrollBarThickness = 3
EggListFrame.ScrollBarImageColor3 = ACCENT
EggListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
EggListFrame.Parent = page5
Instance.new("UICorner", EggListFrame).CornerRadius = UDim.new(0, 4)
local elfStroke = Instance.new("UIStroke")
elfStroke.Color = ACCENT; elfStroke.Thickness = 1; elfStroke.Transparency = 0.8
elfStroke.Parent = EggListFrame

local EggListLayout = Instance.new("UIListLayout")
EggListLayout.SortOrder = Enum.SortOrder.LayoutOrder
EggListLayout.Padding = UDim.new(0, 3)
EggListLayout.Parent = EggListFrame

local EggListPad = Instance.new("UIPadding")
EggListPad.PaddingTop = UDim.new(0, 4)
EggListPad.PaddingLeft = UDim.new(0, 4)
EggListPad.PaddingRight = UDim.new(0, 4)
EggListPad.PaddingBottom = UDim.new(0, 4)
EggListPad.Parent = EggListFrame

local EggStealBtn = Instance.new("TextButton")
EggStealBtn.Size = UDim2.new(1, 0, 0, 22)
EggStealBtn.Position = UDim2.new(0, 0, 1, -22)
EggStealBtn.BackgroundColor3 = BTN_IDLE
EggStealBtn.Text = "STEAL TOP"
EggStealBtn.TextColor3 = TEXT_DIM
EggStealBtn.Font = Enum.Font.Code
EggStealBtn.TextSize = 11
EggStealBtn.BorderSizePixel = 0
EggStealBtn.AutoButtonColor = false
EggStealBtn.Parent = page5
Instance.new("UICorner", EggStealBtn).CornerRadius = UDim.new(0, 4)
local esbStroke = Instance.new("UIStroke")
esbStroke.Color = ACCENT; esbStroke.Thickness = 1; esbStroke.Transparency = 0.5
esbStroke.Parent = EggStealBtn

EggStealBtn.MouseEnter:Connect(function()
	if not ENV._EggStealActive then EggStealBtn.BackgroundColor3 = BTN_HOVER end
end)
EggStealBtn.MouseLeave:Connect(function()
	if not ENV._EggStealActive then EggStealBtn.BackgroundColor3 = BTN_IDLE end
end)

-- Pool de frames ----------------------------------------------------
local EggList_framePool = {}
local EggList_activeItems = {}
local EggList_frameTemplate = nil

local function criarTemplate()
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -4, 0, 26)
	frame.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
	frame.BorderSizePixel = 0
	frame.Visible = false
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 20, 0, 20)
	icon.Position = UDim2.new(0, 3, 0.5, -10)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = ""
	icon.Parent = frame

	local labelNome = Instance.new("TextLabel")
	labelNome.Size = UDim2.new(1, -66, 0, 12)
	labelNome.Position = UDim2.new(0, 26, 0, 1)
	labelNome.BackgroundTransparency = 1
	labelNome.TextColor3 = TEXT_DIM
	labelNome.Font = Enum.Font.Code
	labelNome.TextSize = 9
	labelNome.TextXAlignment = Enum.TextXAlignment.Left
	labelNome.TextTruncate = Enum.TextTruncate.AtEnd
	labelNome.Parent = frame

	local labelRarity = Instance.new("TextLabel")
	labelRarity.Size = UDim2.new(1, -66, 0, 11)
	labelRarity.Position = UDim2.new(0, 26, 0, 13)
	labelRarity.BackgroundTransparency = 1
	labelRarity.TextColor3 = ACCENT
	labelRarity.Font = Enum.Font.Code
	labelRarity.TextSize = 8
	labelRarity.TextXAlignment = Enum.TextXAlignment.Left
	labelRarity.TextTruncate = Enum.TextTruncate.AtEnd
	labelRarity.Parent = frame

	local labelDist = Instance.new("TextLabel")
	labelDist.Size = UDim2.new(0, 38, 1, 0)
	labelDist.Position = UDim2.new(1, -40, 0, 0)
	labelDist.BackgroundTransparency = 1
	labelDist.TextColor3 = TEXT_DIM
	labelDist.Font = Enum.Font.Code
	labelDist.TextSize = 9
	labelDist.TextXAlignment = Enum.TextXAlignment.Right
	labelDist.Parent = frame

	EggList_frameTemplate = {
		frame = frame, icon = icon,
		labelNome = labelNome, labelRarity = labelRarity, labelDist = labelDist,
	}
end
criarTemplate()

local function obterFrame()
	local item = table.remove(EggList_framePool)
	if not item then
		item = { frame = EggList_frameTemplate.frame:Clone() }
		item.icon = item.frame:FindFirstChildOfClass("ImageLabel")
		local labels = {}
		for _, c in ipairs(item.frame:GetChildren()) do
			if c:IsA("TextLabel") then table.insert(labels, c) end
		end
		item.labelNome = labels[1]
		item.labelRarity = labels[2]
		item.labelDist = labels[3]
	end
	item._lastDist = -1; item._lastRarity = ""; item._lastIcon = ""
	item._lastName = ""; item._lastOrder = -1
	item.frame.Visible = true
	item.frame.Parent = EggListFrame
	return item
end

local function devolverFrame(item)
	item.frame.Visible = false
	item.frame.Parent = nil
	table.insert(EggList_framePool, item)
end

local EggList_ovosBuffer = {}
local EggList_bufferCount = 0
local EggList_currentUids = {}
local EggList_topTarget = nil
local EggStealActive = false
local EggStealBodyVel = nil

local function atualizarLista()
	if not page5.Visible then return end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local myPos = hrp.Position

	if not EggState or not EggState.ReadFieldEggs then return end
	local ok, snapshot = pcall(EggState.ReadFieldEggs)
	if not ok or not snapshot or not snapshot.Records then return end

	for i = 1, EggList_bufferCount do EggList_ovosBuffer[i] = nil end
	EggList_bufferCount = 0
	for k in pairs(EggList_currentUids) do EggList_currentUids[k] = nil end

	for _, record in ipairs(snapshot.Records) do
		if record.State == "Slot" and record.BoundsCFrame then
			local eggPos = record.BoundsCFrame.Position
			local dx, dy, dz = eggPos.X - myPos.X, eggPos.Y - myPos.Y, eggPos.Z - myPos.Z
			local distSq = dx*dx + dy*dy + dz*dz
			if distSq <= EggList_MaxDist * EggList_MaxDist then
				local uid = record.Uid or tostring(record.BoundsCFrame)
				local rarityName, score
				local cached = EggList_rarityCache[uid]
				if cached then
					rarityName, score = cached.name, cached.score
				else
					rarityName, score = GetEggRarityInfo(record)
					EggList_rarityCache[uid] = { name = rarityName, score = score }
				end
				if EggList_TargetRarity == "Todos" or (rarityName:lower() == EggList_TargetRarity:lower()) then
					EggList_currentUids[uid] = true
					EggList_bufferCount = EggList_bufferCount + 1
					local entry = EggList_ovosBuffer[EggList_bufferCount]
					if not entry then
						entry = {}
						EggList_ovosBuffer[EggList_bufferCount] = entry
					end
					entry.uid = uid
					entry.record = record
					entry.rarityName = rarityName
					entry.dist = math.floor(math.sqrt(distSq) + 0.5)
					entry.score = score
				end
			end
		end
	end

	table.sort(EggList_ovosBuffer, function(a, b)
		if not a then return false end
		if not b then return true end
		return a.score > b.score
	end)
	for i = #EggList_ovosBuffer, 1, -1 do
		if EggList_ovosBuffer[i] == nil then table.remove(EggList_ovosBuffer, i) else break end
	end

	local top = EggList_ovosBuffer[1]
	EggList_topTarget = top and { uid = top.uid, record = top.record } or nil

	for uid, item in pairs(EggList_activeItems) do
		if not EggList_currentUids[uid] then
			devolverFrame(item)
			EggList_activeItems[uid] = nil
		end
	end

	for i = 1, EggList_bufferCount do
		local ovo = EggList_ovosBuffer[i]
		if not ovo then break end
		local uid = ovo.uid
		local item = EggList_activeItems[uid]
		if not item then
			item = obterFrame()
			EggList_activeItems[uid] = item
		end

		if item._lastOrder ~= i then
			item.frame.LayoutOrder = i
			item._lastOrder = i
		end

		local nome = ovo.record.AssetCategory or ovo.record.Category or ovo.record.Name or "Ovo"
		nome = tostring(nome)
		if item._lastName ~= nome then
			item.labelNome.Text = nome
			item._lastName = nome
		end
		if item._lastRarity ~= ovo.rarityName then
			item.labelRarity.Text = ovo.rarityName
			item._lastRarity = ovo.rarityName
		end
		if item._lastDist ~= ovo.dist then
			item.labelDist.Text = ovo.dist .. "m"
			item._lastDist = ovo.dist
		end

		local iconAsset = GetPetIcon(ovo.record)
		if iconAsset then
			if item._lastIcon ~= iconAsset then
				item.icon.Image = iconAsset
				item._lastIcon = iconAsset
			end
			if not item.icon.Visible then item.icon.Visible = true end
		else
			if item.icon.Visible then item.icon.Visible = false end
		end
	end

	local canvasY = EggList_bufferCount * 29
	if EggListFrame.CanvasSize.Y.Offset ~= canvasY then
		EggListFrame.CanvasSize = UDim2.new(0, 0, 0, canvasY)
	end
end

local function atualizarSeguro()
	local ok, err = pcall(atualizarLista)
	if not ok then warn("[EggList] " .. tostring(err)) end
end

EggFilterBtn.MouseButton1Click:Connect(function()
	EggList_FiltroIdx = EggList_FiltroIdx + 1
	if EggList_FiltroIdx > #EggList_FiltroNiveis then EggList_FiltroIdx = 1 end
	EggList_TargetRarity = EggList_FiltroNiveis[EggList_FiltroIdx]
	EggFilterBtn.Text = "Filtro: " .. EggList_TargetRarity
	for uid, item in pairs(EggList_activeItems) do devolverFrame(item) end
	EggList_activeItems = {}
	atualizarSeguro()
end)

EggDistInput.FocusLost:Connect(function()
	local valor = tonumber(EggDistInput.Text)
	if valor and valor > 0 then
		EggList_MaxDist = valor
	else
		EggDistInput.Text = tostring(EggList_MaxDist)
	end
	for uid, item in pairs(EggList_activeItems) do devolverFrame(item) end
	EggList_activeItems = {}
	atualizarSeguro()
end)

-- ============================================================
-- STEAL TOP (nova versão)
-- ============================================================
local function pararEggSteal()
	EggStealActive = false
	ENV._EggStealActive = false
	if EggStealBodyVel then
		EggStealBodyVel:Destroy()
		EggStealBodyVel = nil
	end
	local c = LocalPlayer.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h then h.Velocity = Vector3.zero end
end

local function acharPromptMaisProximo(refPos)
	if not refPos then return nil end
	local best, bestD = nil, math.huge
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt")
			and obj.Name == "CarryAreaEgg"
			and obj.Parent
			and obj.Parent.Name == "SmartPromptPart"
		then
			local d = (obj.Parent.Position - refPos).Magnitude
			if d < bestD then
				best, bestD = obj, d
			end
		end
	end
	return best
end

local function acharSpawnLocation()
	local s = workspace:FindFirstChild("SpawnLocation")
	if s and s:IsA("SpawnLocation") then return s end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then return obj end
	end
	return nil
end

EggStealBtn.MouseButton1Click:Connect(function()
	if EggStealActive then
		pararEggSteal()
		EggStealBtn.Text = "STEAL TOP"
		EggStealBtn.BackgroundColor3 = BTN_IDLE
		EggStealBtn.TextColor3 = TEXT_DIM
		return
	end

	local alvo = EggList_topTarget
	if not alvo then
		EggStealBtn.Text = "SEM ALVO"
		task.wait(1)
		EggStealBtn.Text = "STEAL TOP"
		return
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	EggStealActive = true
	ENV._EggStealActive = true
	EggStealBtn.Text = "PARAR (0m)"
	EggStealBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 60)
	EggStealBtn.TextColor3 = ACCENT_2

	EggStealBodyVel = Instance.new("BodyVelocity")
	EggStealBodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	EggStealBodyVel.P = 1250
	EggStealBodyVel.Velocity = Vector3.zero
	EggStealBodyVel.Parent = hrp

	local targetUid = alvo.uid
	local targetPos = alvo.record.BoundsCFrame and alvo.record.BoundsCFrame.Position or nil
	if not targetPos then
		pararEggSteal()
		EggStealBtn.Text = "STEAL TOP"
		EggStealBtn.BackgroundColor3 = BTN_IDLE
		EggStealBtn.TextColor3 = TEXT_DIM
		return
	end

	while EggStealActive do
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChild("HumanoidRootPart")
		if not h or not EggStealBodyVel or not EggStealBodyVel.Parent then break end

		local found = false
		local ok, snap = pcall(EggState.ReadFieldEggs)
		if ok and snap and snap.Records then
			for _, rec in ipairs(snap.Records) do
				if rec.Uid == targetUid and rec.BoundsCFrame then
					targetPos = rec.BoundsCFrame.Position
					found = true
					break
				end
			end
		end
		if not found then break end

		local myPos = h.Position
		local diff = targetPos - myPos
		local horiz = Vector3.new(diff.X, 0, diff.Z)
		local dist = horiz.Magnitude

		EggStealBtn.Text = string.format("PARAR (%dm)", math.floor(dist))
		if dist < 1 then break end

		local dir = horiz.Unit
		local speed = dist < 6 and math.max(30, dist * 30) or 250
		EggStealBodyVel.Velocity = Vector3.new(dir.X * speed, 0, dir.Z * speed)
		RunService.Heartbeat:Wait()
	end

	if EggStealBodyVel then
		EggStealBodyVel:Destroy()
		EggStealBodyVel = nil
	end
	local h2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if h2 then h2.Velocity = Vector3.zero end

	if not EggStealActive then
		EggStealBtn.Text = "STEAL TOP"
		EggStealBtn.BackgroundColor3 = BTN_IDLE
		EggStealBtn.TextColor3 = TEXT_DIM
		return
	end

	EggStealBtn.Text = "SEGURANDO..."
	local prompt = acharPromptMaisProximo(targetPos)
	if prompt then
		local done = false
		local conn
		conn = prompt.Triggered:Connect(function(plr)
			if plr == LocalPlayer then done = true end
		end)

		pcall(function() prompt:InputHoldBegin() end)

		local holdTime = prompt.HoldDuration or 1.2
		local t0 = tick()
		while not done and (tick() - t0) < (holdTime + 1.5) do
			RunService.Heartbeat:Wait()
		end

		pcall(function() prompt:InputHoldEnd() end)
		if conn then conn:Disconnect() end
	end

	task.wait(0.5)

	EggStealBtn.Text = "VOLTANDO..."
	local spawn = acharSpawnLocation()
	if spawn then
		local h3 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if h3 then
			h3.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0))
		end
	end

	EggStealActive = false
	ENV._EggStealActive = false
	EggStealBtn.Text = "STEAL TOP"
	EggStealBtn.BackgroundColor3 = BTN_IDLE
	EggStealBtn.TextColor3 = TEXT_DIM
end)

task.spawn(function()
	while screenGui and screenGui.Parent do
		if page5.Visible then atualizarSeguro() end
		task.wait(0.15)
	end
end)

-- ============================================================
-- ESTADO EGG (aba 1)
-- ============================================================
local eggState = {
	active = false, currentPrompt = nil, moveConnection = nil,
	promptConnections = {}, savedPlatformStand = false, savedState = nil,
	attachment = nil, alignPos = nil, alignOri = nil,
}
eggStateRef = eggState

local function setInfo(text) Info.Text = "Status: " .. text end

local function removeConstraints()
	if eggState.alignPos then pcall(function() eggState.alignPos:Destroy() end) eggState.alignPos = nil end
	if eggState.alignOri then pcall(function() eggState.alignOri:Destroy() end) eggState.alignOri = nil end
	if eggState.attachment then pcall(function() eggState.attachment:Destroy() end) eggState.attachment = nil end
end

local function restorePhysics()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = eggState.savedPlatformStand or false
		if eggState.savedState then
			pcall(function() hum:ChangeState(eggState.savedState) end)
		end
	end
	removeConstraints()
	eggState.savedState = nil
end

local function stopMovement()
	if eggState.moveConnection then
		eggState.moveConnection:Disconnect()
		eggState.moveConnection = nil
	end
	restorePhysics()
	eggState.currentPrompt = nil
end

local function onPromptTriggered(prompt)
	if not eggState.active then return end
	if not prompt or not prompt.Parent then return end
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	stopMovement()
	eggState.savedPlatformStand = hum.PlatformStand
	eggState.savedState = hum:GetState()
	hum.PlatformStand = true
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	pcall(function() hum:Move(Vector3.zero, false) end)

	local attachment = Instance.new("Attachment"); attachment.Parent = hrp
	eggState.attachment = attachment

	local alignPos = Instance.new("AlignPosition")
	alignPos.Attachment0 = attachment
	alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPos.Position = hrp.Position
	alignPos.MaxForce = math.huge
	alignPos.Responsiveness = 200
	alignPos.ApplyAtCenterOfMass = true
	alignPos.Parent = hrp
	eggState.alignPos = alignPos

	local alignOri = Instance.new("AlignOrientation")
	alignOri.Attachment0 = attachment
	alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOri.CFrame = hrp.CFrame
	alignOri.MaxTorque = math.huge
	alignOri.Responsiveness = 200
	alignOri.Parent = hrp
	eggState.alignOri = alignOri

	eggState.currentPrompt = prompt
	setInfo("Egg subindo " .. RISE_HEIGHT .. " studs...")

	local spawnPos = hrp.Position
	local targetPos = spawnPos + Vector3.new(0, RISE_HEIGHT, 0)
	local startPos = hrp.Position
	local tweenDuration = TWEEN_DURATION
	local elapsed = 0
	local phase = "tween"
	local currentGoal = targetPos
	local timeUntilNewGoal = 0

	local function pickNewGoal()
		local goToSpawn = math.random() < CHANCE_GO_SPAWN
		local base = goToSpawn and Vector3.new(spawnPos.X, spawnPos.Y + 5, spawnPos.Z) or targetPos
		currentGoal = base + Vector3.new(
			(math.random() * 2 - 1) * WANDER_RANGE,
			(math.random() * 2 - 1) * (WANDER_RANGE * 0.5),
			(math.random() * 2 - 1) * WANDER_RANGE
		)
		timeUntilNewGoal = WANDER_MIN_TIME + math.random() * (WANDER_MAX_TIME - WANDER_MIN_TIME)
	end

	eggState.moveConnection = RunService.Heartbeat:Connect(function(dt)
		local char = LocalPlayer.Character
		if not char or not char.Parent then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		local h = char:FindFirstChildOfClass("Humanoid")
		if not root or not h then return end
		if not eggState.alignPos or not eggState.alignPos.Parent then return end
		if not h.PlatformStand then
			h.PlatformStand = true
			h:ChangeState(Enum.HumanoidStateType.Physics)
		end
		if phase == "tween" then
			elapsed = elapsed + dt
			local alpha = math.min(elapsed / tweenDuration, 1)
			local eased = 1 - (1 - alpha) ^ 2
			local pos = startPos:Lerp(targetPos, eased)
			eggState.alignPos.Position = pos
			eggState.alignOri.CFrame = CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
			if alpha >= 1 then
				phase = "move"
				pickNewGoal()
				setInfo("Egg vagando...")
			end
		else
			local distToSpawn = (root.Position - spawnPos).Magnitude
			if distToSpawn < SPAWN_NEAR_DIST then
				currentGoal = targetPos + Vector3.new(
					(math.random() * 2 - 1) * WANDER_RANGE,
					(math.random() * 2 - 1) * (WANDER_RANGE * 0.5),
					(math.random() * 2 - 1) * WANDER_RANGE
				)
				timeUntilNewGoal = 0.6
				setInfo("Perto do spawn, voltando...")
			else
				timeUntilNewGoal = timeUntilNewGoal - dt
			end
			local currentPos = root.Position
			local dir = currentGoal - currentPos
			local dist = dir.Magnitude
			if timeUntilNewGoal <= 0 or dist < 0.8 then
				pickNewGoal()
			else
				local step = math.min(WANDER_SPEED * dt, dist)
				eggState.alignPos.Position = currentPos + dir.Unit * step
			end
		end
	end)
end

local function connectPrompt(prompt)
	if not prompt or not prompt.Parent then return end
	local conn = prompt.Triggered:Connect(function() onPromptTriggered(prompt) end)
	table.insert(eggState.promptConnections, conn)
end

local function disconnectAllPrompts()
	for _, conn in ipairs(eggState.promptConnections) do
		pcall(function() conn:Disconnect() end)
	end
	eggState.promptConnections = {}
end

local function scanPrompts()
	disconnectAllPrompts()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Name == "CarryAreaEgg" then
			local parent = obj.Parent
			if parent and parent.Name == "SmartPromptPart" then
				connectPrompt(obj)
			end
		end
	end
	setInfo("Egg: " .. #eggState.promptConnections .. " prompts conectados")
end

-- ============================================================
-- ESTADO CARRY EGG TP (aba 3)
-- ============================================================
local CarryCharacter  = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local CarryHumanoid   = CarryCharacter:WaitForChild("Humanoid")
local CarryRootPart   = CarryCharacter:WaitForChild("HumanoidRootPart")

local CarryAtivo        = false
local CarryEscaneando   = false
local CarryTeleportando = false
local CarryConnRun      = nil
local CarryWalkOrig     = nil
local CarryJumpOrig     = nil
local CarryConexoes     = {}

local function setCarryStatus(txt) CarryStatus.Text = "Status: " .. txt end

local function getSpawnPosition()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			return obj.Position + Vector3.new(0, 5, 0)
		end
	end
	return Vector3.new(0, 50, 0)
end

local function pararCarryTeleporte()
	if CarryConnRun then CarryConnRun:Disconnect(); CarryConnRun = nil end
	if CarryHumanoid and CarryHumanoid.Parent then
		if CarryWalkOrig then CarryHumanoid.WalkSpeed = CarryWalkOrig end
		if CarryJumpOrig then CarryHumanoid.JumpPower = CarryJumpOrig end
	end
	CarryTeleportando = false
end

local function teleportarDisfarcado(alvo)
	if CarryTeleportando then return end
	if not CarryCharacter or not CarryCharacter.Parent then return end
	if not CarryHumanoid  or not CarryHumanoid.Parent  then return end
	if not CarryRootPart  or not CarryRootPart.Parent  then return end
	CarryTeleportando = true
	CarryWalkOrig = CarryHumanoid.WalkSpeed
	CarryJumpOrig = CarryHumanoid.JumpPower
	CarryHumanoid.WalkSpeed = WalkSpeedTemp
	CarryHumanoid.JumpPower = JumpPowerTemp
	CarryConnRun = RunService.Heartbeat:Connect(function(dt)
		if not CarryRootPart or not CarryRootPart.Parent then pararCarryTeleporte(); return end
		local origem = CarryRootPart.Position
		local delta  = alvo - origem
		if IgnorarY then delta = Vector3.new(delta.X, 0, delta.Z) end
		local dist = delta.Magnitude
		if dist <= DistanciaChegada or dist < 1e-3 then
			CarryRootPart.CFrame = CFrame.new(alvo) * (CarryRootPart.CFrame - CarryRootPart.Position)
			pararCarryTeleporte(); return
		end
		local passo   = math.min(VelocidadeRun * dt, dist)
		local direcao = delta.Unit
		local novaPos = origem + direcao * passo
		CarryRootPart.CFrame = CFrame.lookAt(novaPos, novaPos + direcao)
	end)
end

local function conectarCarryPrompt(prompt)
	if CarryConexoes[prompt] then return end
	local conn = prompt.Triggered:Connect(function()
		if not CarryAtivo then return end
		if prompt.HoldDuration < HoldMinima then return end
		teleportarDisfarcado(getSpawnPosition())
	end)
	CarryConexoes[prompt] = conn
end

local function escanearCarry()
	for prompt, conn in pairs(CarryConexoes) do
		if not prompt or not prompt.Parent then
			conn:Disconnect(); CarryConexoes[prompt] = nil
		end
	end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == NomePart then
			for _, filho in ipairs(obj:GetChildren()) do
				if filho:IsA("ProximityPrompt") and filho.Name == NomePrompt then
					conectarCarryPrompt(filho)
				end
			end
		end
	end
end

local function ativarCarry()
	CarryAtivo = true
	ENV._CarryAtivo = true
	CarryBtn.Text = "🌌 CarryEgg: ON"
	CarryBtn.BackgroundColor3 = BTN_ON
	CarryBtn.TextColor3 = ACCENT
	setCarryStatus("Ativado — aguardando prompt")
	escanearCarry()
	if not CarryEscaneando then
		CarryEscaneando = true
		task.spawn(function()
			while CarryAtivo do
				task.wait(2)
				if not CarryAtivo then break end
				escanearCarry()
			end
			CarryEscaneando = false
		end)
	end
end

local function desativarCarry()
	CarryAtivo = false
	ENV._CarryAtivo = false
	CarryBtn.Text = "🌌 CarryEgg: OFF"
	CarryBtn.BackgroundColor3 = BTN_IDLE
	CarryBtn.TextColor3 = TEXT_DIM
	setCarryStatus("Desligado\nTP disfarçado p/ spawn")
	pararCarryTeleporte()
	for prompt, conn in pairs(CarryConexoes) do conn:Disconnect() end
	CarryConexoes = {}
end

-- ============================================================
-- ESTADO TP AREAS (aba 4)
-- ============================================================
local GuardSelected = nil
local GuardAreaButtons = {}

local function FindGuardAreas(parent)
	parent = parent or Workspace
	for _, child in pairs(parent:GetChildren()) do
		if child.Name == "GuardAreas" then return child end
		local found = FindGuardAreas(child)
		if found then return found end
	end
	return nil
end

local function GetNestsModel(areaName)
	local guardAreas = FindGuardAreas()
	if not guardAreas then return nil end
	local areaFolder = guardAreas:FindFirstChild(areaName)
	if not areaFolder then return nil end
	local nests = areaFolder:FindFirstChild("Nests")
	if not nests then
		for _, v in pairs(areaFolder:GetDescendants()) do
			if v.Name == "Nests" then nests = v; break end
		end
	end
	return nests
end

local function TeleportAndFireClosestPrompt(nestsModel)
	if not nestsModel then return false end
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
	local hrp = char.HumanoidRootPart
	local targetPart = nestsModel.PrimaryPart or nestsModel:FindFirstChildWhichIsA("BasePart")
	if targetPart then
		hrp.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
	else
		local cf, size = nestsModel:GetBoundingBox()
		hrp.CFrame = cf + Vector3.new(0, size.Y/2 + 3, 0)
	end
	task.wait(0.5)
	local closestPrompt, shortestDist = nil, math.huge
	local MAX_DISTANCE = 200
	for _, desc in pairs(Workspace:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and desc.Parent:IsA("BasePart") then
			local dist = (hrp.Position - desc.Parent.Position).Magnitude
			if dist < shortestDist and dist <= MAX_DISTANCE then
				shortestDist = dist; closestPrompt = desc
			end
		end
	end
	if closestPrompt then
		hrp.CFrame = closestPrompt.Parent.CFrame + Vector3.new(0, 3, 0)
		task.wait(0.3)
		if fireproximityprompt then
			fireproximityprompt(closestPrompt)
		else
			closestPrompt:InputHoldBegin()
			task.wait(closestPrompt.HoldDuration > 0 and closestPrompt.HoldDuration or 0.1)
			closestPrompt:InputHoldEnd()
		end
		return true
	end
	return false
end

local function updateGuardSelection()
	for name, btn in pairs(GuardAreaButtons) do
		if name == GuardSelected then
			btn.BackgroundColor3 = BTN_ON
			btn.TextColor3 = ACCENT
		else
			btn.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
			btn.TextColor3 = TEXT_DIM
		end
	end
end

local function populateGuardList()
	local guardAreas = FindGuardAreas()
	if not guardAreas then
		GuardStatus.Text = "Erro: GuardAreas não encontrado."
		GuardStatus.TextColor3 = ACCENT_2
		return
	end
	GuardStatus.Text = "Áreas carregadas!"
	GuardStatus.TextColor3 = ACCENT
	for _, area in pairs(guardAreas:GetChildren()) do
		if area:IsA("Folder") or area:IsA("Model") then
			if not GuardAreaButtons[area.Name] then
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 22)
				btn.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
				btn.Text = area.Name
				btn.TextColor3 = TEXT_DIM
				btn.Font = Enum.Font.Code
				btn.TextSize = 11
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = false
				btn.Parent = GuardScroll
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
				GuardAreaButtons[area.Name] = btn
				btn.MouseButton1Click:Connect(function()
					GuardSelected = area.Name
					updateGuardSelection()
					GuardStatus.Text = "→ " .. area.Name
					GuardStatus.TextColor3 = ACCENT
				end)
			end
		end
	end
	local count = 0
	for _ in pairs(GuardAreaButtons) do count = count + 1 end
	GuardScroll.CanvasSize = UDim2.new(0, 0, 0, count * 25 + 8)
end

-- ==================== DRAG PANEL ====================
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				if conn then conn:Disconnect() end
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

-- ============================================================
-- AÇÕES DOS BOTÕES
-- ============================================================
BypassBtn.MouseButton1Click:Connect(function()
	Bypass.Enabled = not Bypass.Enabled
	if Bypass.Enabled then
		BypassBtn.BackgroundColor3 = BTN_ON
		BypassBtn.TextColor3 = ACCENT
		BypassBtn.Text = "⚡ Bypass Ativo"
		Bypass.Apply(LocalPlayer.Character)
		setInfo("Bypass ativado")
	else
		BypassBtn.BackgroundColor3 = BTN_IDLE
		BypassBtn.TextColor3 = TEXT_DIM
		BypassBtn.Text = "⚡ Ativar Bypass"
		setInfo("Bypass desativado")
	end
end)

ToggleBtn.MouseButton1Click:Connect(function()
	eggState.active = not eggState.active
	if eggState.active then
		ToggleBtn.BackgroundColor3 = BTN_ON
		ToggleBtn.TextColor3 = ACCENT
		ToggleBtn.Text = "🌀 Egg Ativo"
		scanPrompts()
	else
		ToggleBtn.BackgroundColor3 = BTN_IDLE
		ToggleBtn.TextColor3 = TEXT_DIM
		ToggleBtn.Text = "🌀 Ativar Egg"
		stopMovement()
		disconnectAllPrompts()
		setInfo("Egg desativado")
	end
end)

SpeedToggle.MouseButton1Click:Connect(function()
	if Speed.Active then
		Speed:Stop()
		SpeedToggle.Text = "⚡ Speed: OFF"
		SpeedToggle.BackgroundColor3 = BTN_IDLE
		SpeedToggle.TextColor3 = TEXT_DIM
		SpeedStatus.Text = "Status: Desligado"
	else
		Speed:Start()
		SpeedToggle.Text = "⚡ Speed: ON"
		SpeedToggle.BackgroundColor3 = BTN_ON
		SpeedToggle.TextColor3 = ACCENT
		SpeedStatus.Text = string.format("Status: Ligado — %d studs/s", Speed.Value)
	end
end)

SpeedBox.FocusLost:Connect(function()
	Speed:SetValue(SpeedBox.Text)
	SpeedBox.Text = tostring(Speed.Value)
	if Speed.Active then
		SpeedStatus.Text = string.format("Status: Ligado — %d studs/s", Speed.Value)
	end
end)

task.spawn(function()
	while screenGui and screenGui.Parent do
		if Speed.Active then
			SpeedStatus.Text = string.format("Status: Ligado — %d studs/s", Speed.Value)
		end
		task.wait(0.3)
	end
end)

CarryBtn.MouseButton1Click:Connect(function()
	if CarryAtivo then desativarCarry() else ativarCarry() end
end)

populateGuardList()

GuardTPBtn.MouseButton1Click:Connect(function()
	if not GuardSelected then
		GuardStatus.Text = "Selecione uma área primeiro!"
		GuardStatus.TextColor3 = ACCENT_2
		return
	end
	GuardTPBtn.Text = "Teleportando..."
	GuardTPBtn.BackgroundColor3 = BTN_ON
	GuardStatus.Text = "Indo para Forest..."
	GuardStatus.TextColor3 = ACCENT
	local forestNests = GetNestsModel("Forest")
	if forestNests then TeleportAndFireClosestPrompt(forestNests) end
	GuardStatus.Text = "Aguardando 3s..."
	task.wait(3)
	if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
		GuardStatus.Text = "Personagem morreu."
		GuardStatus.TextColor3 = ACCENT_2
		GuardTPBtn.Text = "🌪️ TP-AREA"
		GuardTPBtn.BackgroundColor3 = BTN_IDLE
		return
	end
	GuardStatus.Text = "Indo para " .. GuardSelected .. "..."
	local targetNests = GetNestsModel(GuardSelected)
	if targetNests then
		TeleportAndFireClosestPrompt(targetNests)
		GuardStatus.Text = "Feito: " .. GuardSelected
		GuardStatus.TextColor3 = ACCENT
	else
		GuardStatus.Text = "Erro: Nests em " .. GuardSelected
		GuardStatus.TextColor3 = ACCENT_2
	end
	GuardTPBtn.Text = "🌪️ TP-AREA"
	GuardTPBtn.BackgroundColor3 = BTN_IDLE
end)

-- Minimizar
local minimizado = false
btnMin.MouseButton1Click:Connect(function()
	minimizado = not minimizado
	if minimizado then
		main.Size = UDim2.new(0, 200, 0, 30)
		tabBar.Visible = false
		pageHolder.Visible = false
	else
		main.Size = UDim2.new(0, 200, 0, 220)
		tabBar.Visible = true
		pageHolder.Visible = true
	end
end)

-- Fechar
btnClose.MouseButton1Click:Connect(function()
	stopMovement()
	disconnectAllPrompts()
	Speed:Stop()
	desativarCarry()
	pcall(pararEggSteal)
	if Bypass._conn then Bypass._conn:Disconnect() end
	screenGui:Destroy()
	ENV.PLEVENT_GUI = nil
	print("[PL EVENT] Fechado.")
end)

-- ==================== EVENTOS GLOBAIS ====================
workspace.DescendantAdded:Connect(function(obj)
	if not eggState.active then return end
	if obj:IsA("ProximityPrompt") and obj.Name == "CarryAreaEgg" then
		task.defer(function()
			local parent = obj.Parent
			if parent and parent.Name == "SmartPromptPart" then
				connectPrompt(obj)
				setInfo("Egg: " .. #eggState.promptConnections .. " prompts")
			end
		end)
	end
end)

Bypass._conn = LocalPlayer.CharacterAdded:Connect(function(char)
	if eggState.active then stopMovement() end
	task.wait(0.3)
	if Bypass.Enabled and Bypass._autoApply then
		Bypass.Apply(char)
	end
end)

LocalPlayer.CharacterAdded:Connect(function(novoChar)
	pararCarryTeleporte()
	task.wait(1)
	CarryCharacter = novoChar
	CarryHumanoid  = CarryCharacter:WaitForChild("Humanoid")
	CarryRootPart  = CarryCharacter:WaitForChild("HumanoidRootPart")
	if CarryAtivo then
		task.wait(0.5)
		escanearCarry()
	end
end)

setInfo("Pronto.")
print("[PL EVENT] Carregado com 5 abas + novo Steal Top integrado!")
