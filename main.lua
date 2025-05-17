-- main.lua
-- Pure-Lua minimal parallax + adaptive zoom example (no external libs needed)

local SCREEN_W, SCREEN_H = 800, 600
local WORLD_W,  WORLD_H  = 1500, 1000

-- Parallax layer definitions (image + speed factor)
local layers = {}

-- Clamp helper\.
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
    zoomBase = 400
    minZoom, maxZoom = 0.5, 2

    -- Initialize camera focus & zoom
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
    mx = (player.x + boss.x) * 0.5
    my = (player.y + boss.y) * 0.5
    local dist = math.abs(player.x - boss.x)

    -- Adaptive zoom based on distance\z
    zoomLevel = clamp(zoomBase / dist, minZoom, maxZoom)
end

function love.draw()
    -- Center & zoom camera around midpoint
    love.graphics.push()
    love.graphics.translate(SCREEN_W/2, SCREEN_H/2)
    love.graphics.scale(zoomLevel)
    love.graphics.translate(-mx, -my)

    -- Draw parallax layers stretched across the world, no vertical tiling
    for _, layer in ipairs(layers) do
        local ox = -mx * layer.speed
        local oy = -my * layer.speed
        local iw, ih = layer.img:getDimensions()
        local sx = WORLD_W / iw
        local sy = WORLD_H / ih
        love.graphics.draw(layer.img, ox, oy, 0, sx, sy)
    end

    -- Draw player & boss
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle('fill', player.x, player.y, player.size)
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle('fill', boss.x - boss.size/2, boss.y - boss.size/2, boss.size, boss.size)
    love.graphics.setColor(1, 1, 1)

    love.graphics.pop()
end
