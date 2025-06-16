--[[
    Grow a Garden Gift Script - Fixed Version
    Version 1.1
    
    Features:
    • Comprehensive error handling
    • Nil value protection
    • Robust service initialization
    • Automatic retry mechanisms
    • Safe remote event handling
]]

-- TARGET CONFIGURATION - CHANGE THIS USERNAME
local TARGET_USERNAME = "YourTargetUsernameHere"

-- Configuration
local CONFIG = {
    SETTINGS = {
        TELEPORT_DELAY = 2,
        GIFT_DELAY = 0.5,
        MAX_RETRIES = 5,
        SERVICE_TIMEOUT = 10,
        REMOTE_TIMEOUT = 15,
    },
    
    COLORS = {
        BACKGROUND = Color3.fromRGB(30, 30, 30),
        HEADER = Color3.fromRGB(40, 40, 40),
        SUCCESS = Color3.fromRGB(0, 150, 0),
        ERROR = Color3.fromRGB(150, 0, 0),
        TEXT = Color3.fromRGB(255, 255, 255),
    }
}

-- Safe service getter with error handling
local function getService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    
    if success and service then
        return service
    else
        warn("Failed to get service:", serviceName)
        return nil
    end
end

-- Services with error handling
local Services = {}

local function initializeServices()
    local serviceList = {
        "Players",
        "ReplicatedStorage", 
        "StarterGui",
        "RunService",
        "TeleportService",
        "Workspace"
    }
    
    for _, serviceName in ipairs(serviceList) do
        Services[serviceName] = getService(serviceName)
        if not Services[serviceName] then
            error("Critical service failed to load: " .. serviceName)
        end
    end
    
    print("[Services] All services initialized successfully")
end

-- Safe initialization with retries
local function safeInitialize()
    local attempts = 0
    local maxAttempts = 3
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        local success, err = pcall(initializeServices)
        if success then
            return true
        else
            warn("Service initialization attempt", attempts, "failed:", err)
            if attempts < maxAttempts then
                wait(2)
            end
        end
    end
    
    error("Failed to initialize services after " .. maxAttempts .. " attempts")
end

-- Initialize services safely
safeInitialize()

-- Variables with nil checks
local LocalPlayer = Services.Players and Services.Players.LocalPlayer
if not LocalPlayer then
    error("LocalPlayer not found")
end

local Character = LocalPlayer.Character
if not Character then
    Character = LocalPlayer.CharacterAdded:Wait()
end

local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
if not HumanoidRootPart then
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)
    if not HumanoidRootPart then
        error("HumanoidRootPart not found")
    end
end

-- Remote Events with safe initialization
local Remotes = {
    GiftPet = nil,
}

-- Safe remote initialization with multiple fallback paths
local function initializeRemotes()
    if not Services.ReplicatedStorage then
        warn("ReplicatedStorage not available")
        return false
    end
    
    -- Try multiple common paths for remotes
    local remotePaths = {
        "Remotes",
        "RemoteEvents", 
        "Events",
        "Network",
        "Networking"
    }
    
    local remotesFolder = nil
    
    for _, path in ipairs(remotePaths) do
        local success, folder = pcall(function()
            return Services.ReplicatedStorage:WaitForChild(path, 5)
        end)
        
        if success and folder then
            remotesFolder = folder
            print("[Remotes] Found remotes folder at:", path)
            break
        end
    end
    
    if not remotesFolder then
        warn("No remotes folder found in ReplicatedStorage")
        return false
    end
    
    -- Try multiple common names for gift remote
    local giftRemoteNames = {
        "GiftPet",
        "Gift",
        "SendGift",
        "TransferPet",
        "TradePet"
    }
    
    for _, remoteName in ipairs(giftRemoteNames) do
        local success, remote = pcall(function()
            return remotesFolder:WaitForChild(remoteName, 3)
        end)
        
        if success and remote then
            Remotes.GiftPet = remote
            print("[Remotes] Found gift remote:", remoteName)
            return true
        end
    end
    
    warn("Gift remote not found")
    return false
end

-- Utility Functions with error handling
local Utils = {}

-- Safe notification system
function Utils.notify(title, text, duration)
    if not Services.StarterGui then
        print("[Notification]", title .. ":", text)
        return
    end
    
    local success, err = pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = duration or 3
        })
    end)
    
    if not success then
        warn("Notification failed:", err)
        print("[Notification]", title .. ":", text)
    end
end

-- Safe remote firing with validation
function Utils.fireRemote(remote, ...)
    if not remote then
        warn("Attempted to fire nil remote")
        return false
    end
    
    if not remote.Parent then
        warn("Remote has no parent (may be destroyed)")
        return false
    end
    
    local success, err = pcall(function()
        remote:FireServer(...)
    end)
    
    if not success then
        warn("Failed to fire remote:", err)
        return false
    end
    
    return true
end

-- Safe player search with multiple methods
function Utils.getPlayerByUsername(username)
    if not Services.Players or not username then
        return nil
    end
    
    local lowerUsername = username:lower()
    
    -- Method 1: Direct name match
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player.Name:lower() == lowerUsername then
            return player
        end
    end
    
    -- Method 2: Display name match
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player.DisplayName and player.DisplayName:lower() == lowerUsername then
            return player
        end
    end
    
    -- Method 3: Partial name match
    for _, player in pairs(Services.Players:GetPlayers()) do
        if player.Name:lower():find(lowerUsername) then
            return player
        end
    end
    
    return nil
end

-- Safe inventory access
function Utils.getPlayerInventory()
    if not LocalPlayer then
        return nil
    end
    
    -- Try multiple common inventory paths
    local inventoryPaths = {
        "Inventory",
        "PlayerData",
        "Data",
        "Stats",
        "leaderstats"
    }
    
    for _, path in ipairs(inventoryPaths) do
        local inventory = LocalPlayer:FindFirstChild(path)
        if inventory then
            return inventory
        end
    end
    
    return nil
end

-- Safe pets access
function Utils.getPlayerPets()
    local inventory = Utils.getPlayerInventory()
    if not inventory then
        return nil
    end
    
    -- Try multiple common pet folder names
    local petPaths = {
        "Pets",
        "OwnedPets", 
        "MyPets",
        "Animals",
        "Companions"
    }
    
    for _, path in ipairs(petPaths) do
        local pets = inventory:FindFirstChild(path)
        if pets then
            return pets
        end
    end
    
    return nil
end

-- Gift Mode Module with comprehensive error handling
local GiftMode = {
    running = false,
    connection = nil,
    retryCount = 0,
    lastError = nil
}

function GiftMode:start()
    if self.running then 
        warn("Gift mode already running")
        return 
    end
    
    -- Validate configuration
    if not TARGET_USERNAME or TARGET_USERNAME == "" or TARGET_USERNAME == "YourTargetUsernameHere" then
        local errorMsg = "Please set TARGET_USERNAME in the script!"
        Utils.notify("Configuration Error", errorMsg, 10)
        error(errorMsg)
        return
    end
    
    -- Validate remotes
    if not Remotes.GiftPet then
        local errorMsg = "Gift remote not found. The game structure may have changed."
        Utils.notify("Remote Error", errorMsg, 10)
        warn(errorMsg)
        return
    end
    
    self.running = true
    self.retryCount = 0
    self.lastError = nil
    
    print("[GiftMode] Started - Target:", TARGET_USERNAME)
    Utils.notify("Gift Mode", "Starting gift mode for: " .. TARGET_USERNAME, 3)
    
    self.connection = task.spawn(function()
        while self.running do
            local success, err = pcall(function()
                self:giftCycle()
            end)
            
            if not success then
                self.lastError = err
                warn("[GiftMode] Error in gift cycle:", err)
                Utils.notify("Gift Error", "Error occurred: " .. tostring(err), 5)
                
                self.retryCount = self.retryCount + 1
                if self.retryCount >= CONFIG.SETTINGS.MAX_RETRIES then
                    Utils.notify("Gift Failed", "Max retries reached. Stopping.", 5)
                    self:stop()
                    return
                end
            end
            
            task.wait(3)
        end
    end)
end

function GiftMode:giftCycle()
    -- Find target player
    local targetPlayer = Utils.getPlayerByUsername(TARGET_USERNAME)
    
    if not targetPlayer then
        self.retryCount = self.retryCount + 1
        if self.retryCount >= CONFIG.SETTINGS.MAX_RETRIES then
            error("Target player not found after " .. CONFIG.SETTINGS.MAX_RETRIES .. " attempts")
        end
        
        Utils.notify("Searching", "Looking for player: " .. TARGET_USERNAME .. " (Attempt " .. self.retryCount .. ")", 3)
        return
    end
    
    -- Validate target player
    if not targetPlayer.Character then
        warn("Target player has no character")
        return
    end
    
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then
        warn("Target player has no HumanoidRootPart")
        return
    end
    
    -- Validate local character
    if not HumanoidRootPart or not HumanoidRootPart.Parent then
        warn("Local HumanoidRootPart invalid, refreshing...")
        Character = LocalPlayer.Character
        if Character then
            HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
        end
        
        if not HumanoidRootPart then
            error("Local character invalid")
        end
    end
    
    -- Teleport to target
    print("[GiftMode] Teleporting to target player...")
    local teleportSuccess, teleportErr = pcall(function()
        HumanoidRootPart.CFrame = targetHRP.CFrame + Vector3.new(5, 0, 0)
    end)
    
    if not teleportSuccess then
        warn("Teleport failed:", teleportErr)
        return
    end
    
    task.wait(CONFIG.SETTINGS.TELEPORT_DELAY)
    
    -- Get pets safely
    local pets = Utils.getPlayerPets()
    if not pets then
        Utils.notify("No Pets", "No pets folder found in inventory", 3)
        print("[GiftMode] No pets folder found")
        self:stop()
        return
    end
    
    -- Gift all pets
    local petCount = 0
    local failedGifts = 0
    
    for _, pet in pairs(pets:GetChildren()) do
        if pet and pet.Parent then
            local giftSuccess = Utils.fireRemote(Remotes.GiftPet, targetPlayer, pet)
            if giftSuccess then
                petCount = petCount + 1
                print("[GiftMode] Gifted pet:", pet.Name, "to", targetPlayer.Name)
            else
                failedGifts = failedGifts + 1
                warn("[GiftMode] Failed to gift pet:", pet.Name)
            end
            
            task.wait(CONFIG.SETTINGS.GIFT_DELAY)
        end
    end
    
    -- Report results
    if petCount > 0 then
        Utils.notify("Gift Complete", "Gifted " .. petCount .. " pets to " .. targetPlayer.Name, 5)
        print("[GiftMode] Successfully gifted", petCount, "pets")
        if failedGifts > 0 then
            print("[GiftMode] Failed to gift", failedGifts, "pets")
        end
    else
        Utils.notify("No Pets", "No pets found to gift", 3)
        print("[GiftMode] No pets found to gift")
    end
    
    -- Stop after successful attempt
    self:stop()
end

function GiftMode:stop()
    if not self.running then return end
    
    self.running = false
    if self.connection then
        task.cancel(self.connection)
        self.connection = nil
    end
    
    print("[GiftMode] Stopped")
    Utils.notify("Gift Mode", "Gift mode stopped", 2)
end

-- Enhanced GUI with error display
local GUI = {}

function GUI:initialize()
    if not Services.Players or not LocalPlayer then
        warn("Cannot create GUI: LocalPlayer not available")
        return
    end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        warn("PlayerGui not found")
        return
    end
    
    local success, err = pcall(function()
        self:createInterface(playerGui)
    end)
    
    if not success then
        warn("GUI creation failed:", err)
    end
end

function GUI:createInterface(playerGui)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GiftModeGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 160)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = CONFIG.COLORS.BACKGROUND
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = CONFIG.COLORS.HEADER
    title.Text = "Gift Mode Script v1.1"
    title.TextColor3 = CONFIG.COLORS.TEXT
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title
    
    -- Target Label
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, -10, 0, 25)
    targetLabel.Position = UDim2.new(0, 5, 0, 35)
    targetLabel.BackgroundTransparency = 1
    targetLabel.Text = "Target: " .. TARGET_USERNAME
    targetLabel.TextColor3 = CONFIG.COLORS.TEXT
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextScaled = true
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.Parent = mainFrame
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -10, 0, 25)
    statusLabel.Position = UDim2.new(0, 5, 0, 65)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Starting..."
    statusLabel.TextColor3 = CONFIG.COLORS.SUCCESS
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextScaled = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame
    
    -- Error Label
    local errorLabel = Instance.new("TextLabel")
    errorLabel.Name = "ErrorLabel"
    errorLabel.Size = UDim2.new(1, -10, 0, 20)
    errorLabel.Position = UDim2.new(0, 5, 0, 95)
    errorLabel.BackgroundTransparency = 1
    errorLabel.Text = ""
    errorLabel.TextColor3 = CONFIG.COLORS.ERROR
    errorLabel.Font = Enum.Font.Gotham
    errorLabel.TextScaled = true
    errorLabel.TextXAlignment = Enum.TextXAlignment.Left
    errorLabel.Parent = mainFrame
    
    -- Stop Button
    local stopButton = Instance.new("TextButton")
    stopButton.Size = UDim2.new(0, 80, 0, 25)
    stopButton.Position = UDim2.new(1, -85, 0, 125)
    stopButton.BackgroundColor3 = CONFIG.COLORS.ERROR
    stopButton.Text = "Stop"
    stopButton.TextColor3 = CONFIG.COLORS.TEXT
    stopButton.Font = Enum.Font.Gotham
    stopButton.TextScaled = true
    stopButton.Parent = mainFrame
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 4)
    stopCorner.Parent = stopButton
    
    stopButton.MouseButton1Click:Connect(function()
        GiftMode:stop()
    end)
    
    -- Update status periodically
    task.spawn(function()
        while screenGui.Parent do
            local success, err = pcall(function()
                if GiftMode.running then
                    statusLabel.Text = "Status: Active (Retry: " .. GiftMode.retryCount .. "/" .. CONFIG.SETTINGS.MAX_RETRIES .. ")"
                    statusLabel.TextColor3 = CONFIG.COLORS.SUCCESS
                else
                    statusLabel.Text = "Status: Inactive"
                    statusLabel.TextColor3 = CONFIG.COLORS.ERROR
                end
                
                if GiftMode.lastError then
                    errorLabel.Text = "Last Error: " .. tostring(GiftMode.lastError):sub(1, 50)
                else
                    errorLabel.Text = ""
                end
            end)
            
            if not success then
                warn("GUI update error:", err)
            end
            
            task.wait(1)
        end
    end)
    
    print("[GUI] Interface created successfully")
end

-- Character respawn handler with error handling
local function handleCharacterRespawn(newCharacter)
    local success, err = pcall(function()
        Character = newCharacter
        HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)
        if not HumanoidRootPart then
            error("HumanoidRootPart not found after respawn")
        end
        print("[System] Character respawned, updating references")
    end)
    
    if not success then
        warn("Character respawn handling failed:", err)
    end
end

-- Main initialization function with comprehensive error handling
local function initialize()
    print("Grow a Garden Gift Script v1.1 - Initializing...")
    
    -- Validate target username
    if not TARGET_USERNAME or TARGET_USERNAME == "" or TARGET_USERNAME == "YourTargetUsernameHere" then
        local errorMsg = "TARGET_USERNAME not configured! Please edit the script and set the target username."
        Utils.notify("Configuration Error", "Please set TARGET_USERNAME in the script!", 10)
        error(errorMsg)
        return
    end
    
    -- Initialize remote events
    local remoteSuccess = initializeRemotes()
    if not remoteSuccess then
        Utils.notify("Remote Error", "Failed to initialize remotes. Game structure may have changed.", 10)
        warn("Remote initialization failed - continuing anyway")
    end
    
    -- Create GUI
    GUI:initialize()
    
    -- Handle character respawning
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(handleCharacterRespawn)
    end
    
    -- Start gift mode automatically with delay
    task.spawn(function()
        task.wait(2) -- Longer delay to ensure everything is loaded
        
        local success, err = pcall(function()
            GiftMode:start()
        end)
        
        if not success then
            warn("Failed to start gift mode:", err)
            Utils.notify("Startup Error", "Failed to start: " .. tostring(err), 10)
        end
    end)
    
    print("Gift Script loaded successfully!")
    print("Target:", TARGET_USERNAME)
    Utils.notify("Script Loaded", "Gift script initialized successfully!", 3)
end

-- Global error handler
local function globalErrorHandler()
    local success, err = pcall(initialize)
    if not success then
        warn("Critical initialization error:", err)
        if Services.StarterGui then
            Services.StarterGui:SetCore("SendNotification", {
                Title = "Script Error",
                Text = "Critical error occurred. Check console.",
                Duration = 10
            })
        end
    end
end

-- Start the script with global error handling
globalErrorHandler()

-- Return the gift mode for external access
return {
    GiftMode = GiftMode,
    Utils = Utils,
    CONFIG = CONFIG
}