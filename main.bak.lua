-- main.lua
-- Pure-Lua minimal parallax + adaptive zoom example (no external libs needed)

local SCREEN_W, SCREEN_H = 800, 600
local WORLD_W,  WORLD_H  = 1500, 1000
local GROUND_HEIGHT = 30  -- Ground height from bottom of world
local worldCenterX, worldCenterY = WORLD_W/2, WORLD_H/2  -- World center coordinates

-- Track zoom mode for toggling
local zoomMode = 1  -- 1 = normal, 2 = wider range

-- Parallax layer definitions (image + speed factor)
local layers = {}

-- Clamp helper
local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

local player, boss
local mx, my, zoomLevel
local zoomBase, minZoom, maxZoom
local groundY  -- Y-position of the ground in world coordinates

function love.load()
    love.window.setMode(SCREEN_W, SCREEN_H)
    love.graphics.setBackgroundColor(0, 0, 0)  -- Black background for safety

    -- Compute ground Y position (from bottom of world)
    groundY = WORLD_H - GROUND_HEIGHT
    
    -- Load parallax images (288×192) with error handling
    local function safeLoadImage(path)
        local success, result = pcall(love.graphics.newImage, path)
        if success then
            return result
        else
            print("Warning: Failed to load image: " .. path)
            -- Create a simple colored placeholder
            local canvas = love.graphics.newCanvas(288, 192)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(math.random(), math.random(), math.random(), 1)
            love.graphics.setCanvas()
            return canvas
        end
    end
    
    layers = {
        { img = safeLoadImage('assets/bg.png'), speed = 0.2 },
        { img = safeLoadImage('assets/mg.png'), speed = 0.5 },
        { img = safeLoadImage('assets/fg.png'), speed = 1.0 }
    }

    -- Initialize player & boss - both at ground level
    player = { x = 100, y = groundY, size = 20 }
    boss   = { x = WORLD_W - 100, y = groundY, size = 30 }

    -- Zoom parameters
    zoomBase  = 100
    minZoom, maxZoom = 0.25, 0.75

    -- Initial midpoint & zoom
    updateCameraPosition()
end

-- Update camera position and zoom based on player and boss positions
function updateCameraPosition()
    -- Compute midpoint (x only)
    mx = (player.x + boss.x) * 0.5
    -- Always center on ground level
    my = groundY
    
    -- Calculate distance between player and boss (horizontal distance only)
    local dist = math.abs(player.x - boss.x)
    
    -- Adaptive zoom based on distance - add smoothing
    local zoomRanges = {
        {min = 0.25, max = 0.75},   -- Normal zoom range
        {min = 0.1, max = 1.0}      -- Extended zoom range
    }
    local targetZoom = clamp(zoomBase / dist, zoomRanges[zoomMode].min, zoomRanges[zoomMode].max)
    if not zoomLevel then
        zoomLevel = targetZoom  -- First initialization
    else
        -- Apply smoothing to zoom changes (reduce jarring transitions)
        zoomLevel = zoomLevel + (targetZoom - zoomLevel) * 0.1
    end
    
    -- Calculate visible area dimensions in world coordinates
    local visibleW = SCREEN_W / zoomLevel
    local visibleH = SCREEN_H / zoomLevel
    
    -- Clamp camera to ensure view stays within world bounds
    -- Using math.min/max for more predictable behavior
    mx = math.max(visibleW * 0.5, math.min(mx, WORLD_W - visibleW * 0.5))
    my = math.max(visibleH * 0.5, math.min(my, WORLD_H - visibleH * 0.5))
end

function love.update(dt)
    -- Player movement (horizontal only)
    if love.keyboard.isDown('left') then
        player.x = clamp(player.x - 200 * dt, 20, WORLD_W - 20)  -- Add padding
    elseif love.keyboard.isDown('right') then
        player.x = clamp(player.x + 200 * dt, 20, WORLD_W - 20)  -- Add padding
    end
    
    -- Ensure player stays at ground level
    player.y = groundY
    
    -- Update camera position and zoom
    updateCameraPosition()
end

function love.draw()
    -- Apply camera transform: center and zoom
    love.graphics.push()
    love.graphics.translate(SCREEN_W/2, SCREEN_H/2)
    love.graphics.scale(zoomLevel)
    love.graphics.translate(-mx, -my)

    -- Calculate visible area in world coordinates
    local visibleW = SCREEN_W / zoomLevel
    local visibleH = SCREEN_H / zoomLevel
    
    -- Draw parallax layers
    for _, layer in ipairs(layers) do
        -- Calculate scaling to fill the world
        local iw, ih = layer.img:getDimensions()
        local sx, sy = WORLD_W/iw, WORLD_H/ih
        
        -- Calculate parallax offsets - slower layers move less with camera
        -- Properly center each layer based on camera position and speed factor
        local layerOffsetX = (mx - WORLD_W/2) * (1 - layer.speed)
        local layerOffsetY = (my - WORLD_H/2) * (1 - layer.speed)
        
        -- Draw the layer with proper offset
        love.graphics.draw(
            layer.img,
            layerOffsetX,
            layerOffsetY,
            0,  -- rotation
            sx, sy  -- scale
        )
    end
    
    -- Draw ground line for reference
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(2 / zoomLevel)  -- Adjust line width for zoom
    love.graphics.line(0, groundY, WORLD_W, groundY)
    
    -- Draw player on top (blue circle)
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle('fill', player.x, player.y - player.size / 2, player.size)
    
    -- Draw boss on top (red square)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle(
        'fill', 
        boss.x - boss.size/2, 
        boss.y - boss.size, 
        boss.size, 
        boss.size
    )
    
    -- Reset color
    love.graphics.setColor(1, 1, 1)

    -- Show world boundaries for debugging
    love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
    love.graphics.rectangle('line', 0, 0, WORLD_W, WORLD_H)
    love.graphics.setColor(1, 1, 1)
    
    love.graphics.pop()
    
    -- Draw HUD info (outside camera transform)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format(
        "Player: %.0f, %.0f | Zoom: %.2f | Use left/right arrows to move", 
        player.x, player.y, zoomLevel
    ), 10, 10)
end

-- Add window resize handler to maintain proper aspect ratio
function love.resize(w, h)
    SCREEN_W, SCREEN_H = w, h
    updateCameraPosition()
end