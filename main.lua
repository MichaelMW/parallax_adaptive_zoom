-- main_fixed.lua
-- Modularized parallax + adaptive zoom example

-- Configuration
local Config = {
    screen = { width = 800, height = 600 },
    world = { width = 900, height = 600 },
    ground = { height = 10 },
    zoom = { base = 400, min = 0.2, max = 0.7, smoothing = 0.1 },
    player = { speed = 200, size = 20, padding = 20 }
}

-- Global state
local Game = {
    player = nil,
    boss = nil,
    camera = {
        x = 0, 
        y = 0, 
        zoom = nil
    },
    layers = {},
    groundY = 0,
    worldCenterX = Config.world.width / 2,
    worldCenterY = Config.world.height / 2
}

------------------------------------------
-- Utility Functions
------------------------------------------

-- Simple clamp function
local function clamp(x, lo, hi)
    return math.max(lo, math.min(x, hi))
end

------------------------------------------
-- Camera Functions
------------------------------------------

-- Update camera position and zoom
local updateCamera = function()
    -- Calculate distance between player and boss (horizontal distance only)
    local dist = math.abs(Game.player.x - Game.boss.x)
    
    -- Calculate target zoom level based on distance
    local targetZoom = clamp(
        Config.zoom.base / dist,
        Config.zoom.min,
        Config.zoom.max
    )
    
    -- Compute midpoint between player and boss (x only)
    Game.camera.x = (Game.player.x + Game.boss.x) * 0.5
    
    -- Always center vertically at ground level
    Game.camera.y = Game.groundY
    
    -- Apply zoom smoothing
    if not Game.camera.zoom then
        Game.camera.zoom = targetZoom  -- First initialization
    else
        -- Smoothly interpolate towards target zoom
        Game.camera.zoom = Game.camera.zoom + 
            (targetZoom - Game.camera.zoom) * Config.zoom.smoothing
    end
end

-- Initialize camera
local function initCamera()
    updateCamera()  -- Set initial camera position
end

------------------------------------------
-- Resource Loading
------------------------------------------

-- Load all game resources
local function loadResources()
    -- Load parallax background layers
    Game.layers = {
        { img = love.graphics.newImage('assets/bg.png'), speed = 0.2 },
        { img = love.graphics.newImage('assets/mg.png'), speed = 0.5 },
        { img = love.graphics.newImage('assets/fg.png'), speed = 0.75 }
    }
end

-- Create game entities
local function createEntities()
    -- Initialize player
    Game.player = {
        x = 100,
        y = Game.groundY,
        size = Config.player.size
    }
    
    -- Initialize boss
    Game.boss = {
        x = Config.world.width - 100,
        y = Game.groundY,
        size = 30
    }
end

------------------------------------------
-- Input Handling
------------------------------------------

-- Handle keyboard input
local function handleInput(dt)
    -- Player movement (horizontal only)
    if love.keyboard.isDown('left') then
        Game.player.x = clamp(
            Game.player.x - Config.player.speed * dt,
            Config.player.padding,
            Config.world.width - Config.player.padding
        )
    elseif love.keyboard.isDown('right') then
        Game.player.x = clamp(
            Game.player.x + Config.player.speed * dt,
            Config.player.padding,
            Config.world.width - Config.player.padding
        )
    end
end

------------------------------------------
-- Drawing Functions
------------------------------------------

-- Draw parallax background layers
local function drawBackground()
    for _, layer in ipairs(Game.layers) do
        local iw, ih = layer.img:getDimensions()
        
        -- Simple proportional scaling
        local sx, sy = Config.world.width/iw, Config.world.height/ih
        
        -- Calculate parallax offset based on camera position
        local offsetX = (Game.camera.x - Game.worldCenterX) * (1 - layer.speed)
        local offsetY = (Game.camera.y - Config.screen.height + Config.ground.height) * (1 - layer.speed)
        
        -- Draw the layer with parallax offset
        love.graphics.draw(
            layer.img,
            offsetX,
            offsetY,
            0,  -- rotation
            sx, sy  -- scale
        )
    end
    
    -- Draw ground line
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.line(0, Game.groundY, Config.world.width, Game.groundY)
    love.graphics.setColor(1, 1, 1)
end

-- Draw game entities (player and boss)
local function drawEntities()
    -- Draw player (blue circle)
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle(
        'fill', 
        Game.player.x, 
        Game.player.y - Game.player.size / 2, 
        Game.player.size
    )
    
    -- Draw boss (red square)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle(
        'fill', 
        Game.boss.x - Game.boss.size/2, 
        Game.boss.y - Game.boss.size, 
        Game.boss.size, 
        Game.boss.size
    )
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- Draw heads-up display
local function drawHUD()
    -- Ensure text is white
    love.graphics.setColor(1, 1, 1)
    
    -- Calculate distance for display
    local dist = math.abs(Game.player.x - Game.boss.x)
    
    -- Display game information
    local info = {
        "CONTROLS: Left/Right arrows to move, ESC to quit",
        "----------------------------------------",
        string.format("Player: x=%.0f, y=%.0f", Game.player.x, Game.player.y),
        string.format("Boss:   x=%.0f, y=%.0f", Game.boss.x, Game.boss.y),
        string.format("Distance: %.0f", dist),
        "----------------------------------------",
        string.format("Camera: x=%.0f, y=%.0f", Game.camera.x, Game.camera.y), 
        string.format("Zoom: %.2f (Min: %.2f, Max: %.2f, Base: %.0f)", 
            Game.camera.zoom, Config.zoom.min, Config.zoom.max, Config.zoom.base),
        "----------------------------------------",
        "Parallax Layers:"
    }
    
    -- Add layer info
    for i, layer in ipairs(Game.layers) do
        table.insert(info, string.format("  Layer %d: Speed=%.1f", i, layer.speed))
    end
    
    -- Print each line
    for i, line in ipairs(info) do
        love.graphics.print(line, 10, 10 + (i-1) * 18)
    end
end

------------------------------------------
-- LÖVE Framework Callbacks
------------------------------------------

function love.load()
    -- Initialize the window
    love.window.setMode(Config.screen.width, Config.screen.height)
    love.graphics.setBackgroundColor(0, 0, 0)
    
    -- Set ground level
    Game.groundY = Config.screen.height - Config.ground.height
    
    -- Load game assets and create entities
    loadResources()
    createEntities()
    initCamera()
end

function love.update(dt)
    -- Handle player input
    handleInput(dt)
    
    -- Ensure player stays at ground level
    Game.player.y = Game.groundY
    
    -- Update camera position and zoom
    updateCamera()
end

function love.keypressed(key)
    if key == 'escape' then 
        love.event.quit() 
    end
end

function love.draw()
    -- Apply camera transform - this is the core of camera-based rendering
    love.graphics.push()
        love.graphics.translate(Config.screen.width/2, Config.screen.height - Config.ground.height)
        love.graphics.scale(Game.camera.zoom * 2)
        love.graphics.translate(-Game.camera.x, -Game.camera.y)
        
        -- Draw world elements
        drawBackground()
        drawEntities()
    love.graphics.pop()

    -- Draw HUD (outside camera transform)
    drawHUD()
end

function love.resize(w, h)
    Config.screen.width = w
    Config.screen.height = h
    Game.groundY = Config.screen.height - Config.ground.height
end
