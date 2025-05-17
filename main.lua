-- main.lua
-- Pure-Lua minimal parallax + adaptive zoom example (no external libs needed)

local SCREEN_W, SCREEN_H = 800, 600
local WORLD_W,  WORLD_H  = 1500, 1000

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

function love.load()
    love.window.setMode(SCREEN_W, SCREEN_H)

    -- Load parallax images (288×192)
    layers = {
        { img = love.graphics.newImage('assets/bg.png'), speed = 0.2 },
        { img = love.graphics.newImage('assets/mg.png'), speed = 0.5 },
        { img = love.graphics.newImage('assets/fg.png'), speed = 1.0 }
    }

    -- Initialize player & boss
    player = { x = 100, y = WORLD_H/2, size = 20 }
    boss   = { x = WORLD_W - 100, y = WORLD_H/2, size = 30 }

    -- Zoom parameters
    zoomBase  = 400
    minZoom, maxZoom = 0.5, 2

    -- Initial midpoint & zoom
    mx, my = (player.x + boss.x)/2, (player.y + boss.y)/2
    zoomLevel = 1
end

function love.update(dt)
    -- Player movement
    if love.keyboard.isDown('left') then
        player.x = clamp(player.x - 200 * dt, 0, WORLD_W)
    elseif love.keyboard.isDown('right') then
        player.x = clamp(player.x + 200 * dt, 0, WORLD_W)
    end

    -- Compute midpoint & distance
    local px, py = player.x, player.y
    local bx, by = boss.x, boss.y
    mx = (px + bx) * 0.5
    my = (py + by) * 0.5
    local dist = math.abs(px - bx)

    -- Adaptive zoom
    zoomLevel = clamp(zoomBase / dist, minZoom, maxZoom)

    -- Clamp camera so view stays within world bounds
    local halfW = SCREEN_W / (2 * zoomLevel)
    local halfH = SCREEN_H / (2 * zoomLevel)
    mx = clamp(mx, halfW, WORLD_W - halfW)
    my = clamp(my, halfH, WORLD_H - halfH)
end

function love.draw()
    -- Apply camera: center and zoom
    love.graphics.push()
    love.graphics.translate(SCREEN_W/2, SCREEN_H/2)
    love.graphics.scale(zoomLevel)
    love.graphics.translate(-mx, -my)

    -- Draw parallax layers stretched across world
    for _, layer in ipairs(layers) do
        -- calculate full-world stretch
        local iw, ih = layer.img:getDimensions()
        local sx, sy = WORLD_W/iw, WORLD_H/ih
        
        -- Calculate parallax positions - slower layers move less
        -- Layer with speed=0 stays fixed relative to screen
        -- Layer with speed=1 moves exactly with the world
        local layerX = mx * layer.speed - WORLD_W/2 * layer.speed
        local layerY = my * layer.speed - WORLD_H/2 * layer.speed
        
        love.graphics.draw(layer.img, layerX, layerY, 0, sx, sy)
    end

    -- Draw player & boss on top
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle('fill', player.x, player.y, player.size)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', boss.x - boss.size/2, boss.y - boss.size/2, boss.size, boss.size)
    love.graphics.setColor(1, 1, 1)

    love.graphics.pop()
end
