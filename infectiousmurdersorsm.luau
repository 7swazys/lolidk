local plrs = game:GetService("Players")
local run = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local http = game:GetService("HttpService")
local cam = workspace.CurrentCamera
local lp = plrs.LocalPlayer

local cfgPath = "infectedcfg.json"
local cfg = {
    aimbot = false,
    esp = true,
    tracers = true,
    fov = 150,
    smooth = 0.18,
    maxdist = 250,
    method = "MouseMoveRel",
}

local function saveCfg()
    pcall(function() writefile(cfgPath, http:JSONEncode(cfg)) end)
end

local function loadCfg()
    local ok, res = pcall(function() return http:JSONDecode(readfile(cfgPath)) end)
    if ok and type(res) == "table" then
        for k, v in pairs(cfg) do
            if res[k] ~= nil then cfg[k] = res[k] end
        end
    end
end
loadCfg()

local hrp
local myRole = "Unknown"

local function setupChar(char)
    hrp = char:WaitForChild("HumanoidRootPart")
end

lp.CharacterAdded:Connect(setupChar)
if lp.Character then setupChar(lp.Character) end

local roleColors = {
    Infected = Color3.fromRGB(255, 0, 0),
    Survivor = Color3.fromRGB(0, 255, 0),
    Unknown = Color3.fromRGB(128, 128, 128),
}

local function getRoleFromTool(tool)
    if not tool then return nil end
    for _, child in ipairs(tool:GetChildren()) do
        if child:IsA("Script") or child:IsA("LocalScript") then
            local name = string.lower(child.Name)
            if string.find(name, "knife") then
                return "Infected"
            elseif string.find(name, "gun") then
                return "Survivor"
            end
        end
    end
    return nil
end

local function getPlayerRole(p)
    if not p.Character then return "Unknown" end
    
    local character = p.Character
    
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        local equippedTool = humanoid:FindFirstChild("EquippedTool")
        if equippedTool then
            local role = getRoleFromTool(equippedTool)
            if role then return role end
        end
    end
    
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            local role = getRoleFromTool(child)
            if role then return role end
        end
    end
    
    local backpack = p:FindFirstChild("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") then
                local role = getRoleFromTool(child)
                if role then return role end
            end
        end
    end
    
    return "Unknown"
end

local function isEnemy(p)
    if p == lp then return false end
    local targetRole = getPlayerRole(p)
    if myRole == "Infected" and targetRole == "Survivor" then return true end
    if myRole == "Survivor" and targetRole == "Infected" then return true end
    return false
end

local black = Color3.fromRGB(0, 0, 0)
local white = Color3.fromRGB(255, 255, 255)
local espLibraries = {}

local function newQuad(thickness, color)
    local q = Drawing.new("Quad")
    q.Visible = false
    q.PointA = Vector2.new(0,0)
    q.PointB = Vector2.new(0,0)
    q.PointC = Vector2.new(0,0)
    q.PointD = Vector2.new(0,0)
    q.Color = color
    q.Filled = false
    q.Thickness = thickness
    q.Transparency = 1
    return q
end

local function newLine(thickness, color)
    local l = Drawing.new("Line")
    l.Visible = false
    l.From = Vector2.new(0,0)
    l.To = Vector2.new(0,0)
    l.Color = color
    l.Thickness = thickness
    l.Transparency = 1
    return l
end

local function newText(size, color)
    local t = Drawing.new("Text")
    t.Visible = false
    t.Text = ""
    t.Size = size
    t.Color = color
    t.Outline = true
    t.OutlineColor = black
    t.Center = true
    t.Font = 2
    return t
end

local function setVis(state, lib)
    for _, x in pairs(lib) do x.Visible = state end
end

local function makeESP(p)
    if p == lp then return end
    local lib = {
        blacktracer = newLine(2, black),
        tracer = newLine(1, black),
        black = newQuad(2, black),
        box = newQuad(1, black),
        healthbar = newLine(3, black),
        greenhealth = newLine(1.5, black),
        name = newText(13, white),
        role = newText(11, white),
    }
    espLibraries[p] = lib

    coroutine.wrap(function()
        local conn
        conn = run.RenderStepped:Connect(function()
            if not cfg.esp then setVis(false, lib) return end

            local char = p.Character
            local phrp = char and char:FindFirstChild("HumanoidRootPart")
            local phead = char and char:FindFirstChild("Head")
            local phum = char and char:FindFirstChild("Humanoid")

            if char and phrp and phum and phum.Health > 0 and phead then
                local humPos, onScreen = cam:WorldToViewportPoint(phrp.Position)
                if onScreen then
                    local head = cam:WorldToViewportPoint(phead.Position)
                    local distY = math.clamp((Vector2.new(head.X, head.Y) - Vector2.new(humPos.X, humPos.Y)).Magnitude, 2, math.huge)
                    local rc = roleColors[getPlayerRole(p)] or roleColors.Unknown

                    lib.box.Color = rc
                    lib.tracer.Color = rc

                    local function sizeQuad(item)
                        item.PointA = Vector2.new(humPos.X + distY, humPos.Y - distY*2)
                        item.PointB = Vector2.new(humPos.X - distY, humPos.Y - distY*2)
                        item.PointC = Vector2.new(humPos.X - distY, humPos.Y + distY*2)
                        item.PointD = Vector2.new(humPos.X + distY, humPos.Y + distY*2)
                    end
                    sizeQuad(lib.box)
                    sizeQuad(lib.black)

                    lib.name.Text = p.Name
                    lib.name.Color = white
                    lib.name.Position = Vector2.new(humPos.X, humPos.Y - distY*2 - 14)
                    lib.name.Visible = true

                    local roleText = getPlayerRole(p)
                    lib.role.Text = roleText
                    lib.role.Color = rc
                    lib.role.Position = Vector2.new(humPos.X, humPos.Y + distY*2 + 3)
                    lib.role.Visible = true

                    if cfg.tracers then
                        lib.tracer.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y)
                        lib.blacktracer.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y)
                        lib.tracer.To = Vector2.new(humPos.X, humPos.Y + distY*2)
                        lib.blacktracer.To = Vector2.new(humPos.X, humPos.Y + distY*2)
                        lib.tracer.Visible = true
                        lib.blacktracer.Visible = true
                    else
                        lib.tracer.Visible = false
                        lib.blacktracer.Visible = false
                    end

                    local d = (Vector2.new(humPos.X - distY, humPos.Y - distY*2) - Vector2.new(humPos.X - distY, humPos.Y + distY*2)).Magnitude
                    local healthOff = phum.Health / phum.MaxHealth * d
                    lib.greenhealth.Color = Color3.fromRGB(255,0,0):lerp(Color3.fromRGB(0,255,0), phum.Health / phum.MaxHealth)
                    lib.greenhealth.From = Vector2.new(humPos.X - distY - 4, humPos.Y + distY*2)
                    lib.greenhealth.To = Vector2.new(humPos.X - distY - 4, humPos.Y + distY*2 - healthOff)
                    lib.healthbar.From = Vector2.new(humPos.X - distY - 4, humPos.Y + distY*2)
                    lib.healthbar.To = Vector2.new(humPos.X - distY - 4, humPos.Y - distY*2)

                    lib.box.Visible = true
                    lib.black.Visible = true
                    lib.healthbar.Visible = true
                    lib.greenhealth.Visible = true
                else
                    setVis(false, lib)
                end
            else
                setVis(false, lib)
                if not plrs:FindFirstChild(p.Name) then conn:Disconnect() end
            end
        end)
    end)()
end

for _, p in plrs:GetPlayers() do makeESP(p) end
plrs.PlayerAdded:Connect(makeESP)

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.2
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Transparency = 0.5
fovCircle.Visible = false

task.spawn(function()
    while true do
        task.wait(0.3)
        myRole = getPlayerRole(lp)
    end
end)

run.RenderStepped:Connect(function()
    myRole = getPlayerRole(lp)
    
    local mousePos = uis:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Radius = cfg.fov
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Visible = cfg.aimbot
    
    if not hrp or not hrp.Parent then return end

    if cfg.aimbot then
        local target, shortest = nil, math.huge
        for _, p in plrs:GetPlayers() do
            if not isEnemy(p) then continue end
            
            local head = p.Character and p.Character:FindFirstChild("Head")
            if head and hrp then
                local dist = (hrp.Position - head.Position).Magnitude
                if dist <= cfg.maxdist then
                    local pos, onScreen = cam:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local mag = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if mag < cfg.fov and mag < shortest then
                            shortest = mag
                            target = head
                        end
                    end
                end
            end
        end
        if target then
            if cfg.method == "CFrame" then
                cam.CFrame = CFrame.new(cam.CFrame.Position, target.Position)
            elseif cfg.method == "MouseMoveRel" and mousemoverel then
                local tpos = cam:WorldToViewportPoint(target.Position)
                mousemoverel((tpos.X - mousePos.X) * cfg.smooth, (tpos.Y - mousePos.Y) * cfg.smooth)
            end
        end
    end
end)

local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/IcantAffordSynapse/SimpleLib/refs/heads/main/SimpleLib.lua"))()
local win = lib:Window("script for game aint even out yet")
local main = win:AddSection("Main")

main:Toggle("aimbot", cfg.aimbot, function(s) cfg.aimbot = s saveCfg() end)
main:Slider("fov size", 50, 400, cfg.fov, function(v) cfg.fov = v saveCfg() end)
main:Slider("smoothness", 1, 10, cfg.smooth * 10, function(v) cfg.smooth = v / 10 saveCfg() end)
main:Slider("max distance", 50, 500, cfg.maxdist, function(v) cfg.maxdist = v saveCfg() end)
main:Dropdown("aim method", {"MouseMoveRel", "CFrame"}, function(v) cfg.method = v saveCfg() end)
main:Toggle("esp", cfg.esp, function(s)
    cfg.esp = s
    if not s then
        for _, l in espLibraries do setVis(false, l) end
    end
    saveCfg()
end)
main:Toggle("tracers", cfg.tracers, function(s) cfg.tracers = s saveCfg() end)
