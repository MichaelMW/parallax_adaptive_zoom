-- main_minimal.lua
-- Ultra-simplified parallax + adaptive zoom example (bare essentials only)

local SCREEN_W, SCREEN_H = 800, 600
local WORLD_W, WORLD_H = 900, 600
local GROUND_HEIGHT = 10

-- Simple variables for clean implementation
local worldCenterX, worldCenterY = WORLD_W/2, WORLD_H/2
local layers = {}
local player, boss
local mx, my, zoomLevel
local zoomBase, minZoom, maxZoom
local groundY

-- Simple clamp function
local function clamp(x, lo, hi)
    return math.max(lo, math.min(x, hi))
end

function love.load()
    love.window.setMode(SCREEN_W, SCREEN_H)
    love.graphics.setBackgroundColor(0, 0, 0)
    
    -- Set ground level
    groundY = SCREEN_H - GROUND_HEIGHT
    
    -- Load images directly (no error handling for simplicity)
    layers = {
        { img = love.graphics.newImage('assets/bg.png'), speed = 0.2 },
        { img = love.graphics.newImage('assets/mg.png'), speed = 0.5 },
        { img = love.graphics.newImage('assets/fg.png'), speed = 1.0 }
    }

    -- Set initial positions
    player = { x = 100, y = groundY, size = 20 }
    boss = { x = WORLD_W - 100, y = groundY, size = 30 }

    -- Zoom parameters - simple and direct
    zoomBase = 400
    minZoom, maxZoom = 0.2, 0.7
    
    -- Initialize camera
    updateCamera()
end

-- Super simplified camera update
function updateCamera()
    -- Calculate zoom based on horizontal distance only
    local dist = math.abs(player.x - boss.x)
    local targetZoom = clamp(zoomBase / dist, minZoom, maxZoom)

    -- Camera at horizontal midpoint between player and boss
    mx = (player.x + boss.x) * 0.5
    
    -- Always center vertically at ground level
    my = groundY
    
    
    
    -- Simple smoothing
    if not zoomLevel then
        zoomLevel = targetZoom
    else
        zoomLevel = zoomLevel + (targetZoom - zoomLevel) * 0.1
    end
end

function love.update(dt)
    -- Basic player movement
    if love.keyboard.isDown('left') then
        player.x = clamp(player.x - 200 * dt, 20, WORLD_W - 20)
    elseif love.keyboard.isDown('right') then
        player.x = clamp(player.x + 200 * dt, 20, WORLD_W - 20)
    end
    
    -- Update camera
    updateCamera()
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
end

function love.draw()
    -- Apply camera transform - this is the core of camera-based rendering
    love.graphics.push()
        love.graphics.translate(SCREEN_W/2, SCREEN_H - GROUND_HEIGHT)
        love.graphics.scale(zoomLevel*2)
        love.graphics.translate(-mx, -my)

        
        -- Draw parallax layers - minimal implementation
        for _, layer in ipairs(layers) do
            local iw, ih = layer.img:getDimensions()
            
            -- Simple proportional scaling
            local sx, sy = WORLD_W/iw, WORLD_H/ih
            
            -- Calculate parallax offset based on camera position
            local offsetX = (mx - worldCenterX) * (1 - layer.speed)

            local offsetY = (my - SCREEN_H + GROUND_HEIGHT) * (1 - layer.speed)
            
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
        love.graphics.line(0, groundY, WORLD_W, groundY)
        
        -- Draw player (blue circle)
        love.graphics.setColor(0, 0, 1)
        love.graphics.circle('fill', player.x, player.y - player.size / 2, player.size)
        
        -- Draw boss (red square)
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle('fill', 
            boss.x - boss.size/2, boss.y - boss.size, boss.size, boss.size)
        
        -- Reset color
        love.graphics.setColor(1, 1, 1)

    love.graphics.pop()

    -- Enhanced HUD (drawn outside camera transform so it stays fixed on screen)
    love.graphics.setColor(1, 1, 1) -- Ensure text is white
    
    -- Calculate distance for display
    local dist = math.abs(player.x - boss.x)
    
    -- Display game information
    local info = {
        "CONTROLS: Left/Right arrows to move, ESC to quit",
        "----------------------------------------",
        string.format("Player: x=%.0f, y=%.0f", player.x, player.y),
        string.format("Boss:   x=%.0f, y=%.0f", boss.x, boss.y),
        string.format("Distance: %.0f", dist),
        "----------------------------------------",
        string.format("Camera: x=%.0f, y=%.0f", mx, my), 
        string.format("Zoom: %.2f (Min: %.2f, Max: %.2f, Base: %.0f)", 
            zoomLevel, minZoom, maxZoom, zoomBase),
        "----------------------------------------",
        "Parallax Layers:"
    }
    
    -- Add layer info
    for i, layer in ipairs(layers) do
        table.insert(info, string.format("  Layer %d: Speed=%.1f", i, layer.speed))
    end
    
    -- Print each line
    for i, line in ipairs(info) do
        love.graphics.print(line, 10, 10 + (i-1) * 18)
    end
    
end

-- Simple window resize handler
function love.resize(w, h)
    SCREEN_W, SCREEN_H = w, h
end
