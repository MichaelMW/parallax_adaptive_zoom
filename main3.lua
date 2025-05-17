local Camera   = require 'utils.camera'
local Parallax = require 'utils.parallax'
local gamera   = require 'utils.gamera'

function love.load()
    -- choose one camera for zoom and parallax
    camera = Camera(0,0)
    -- or: camera = gamera.new(0,0,worldW,worldH)
    -- setup layers: image, base scale, and depth speed
    layers = {
      Parallax.newLayer{ image=love.graphics.newImage('bg.png'),
                         scale=0.5, speed=0.5 },
      Parallax.newLayer{ image=love.graphics.newImage('mg.png'),
                         scale=0.8, speed=0.8 },
      Parallax.newLayer{ image=love.graphics.newImage('fg.png'),
                         scale=1.0, speed=1.0 },
    }
end

function love.update(dt)
    -- center camera on midpoint
    local mx, my = (player.x+boss.x)/2, (player.y+boss.y)/2
    camera:lookAt(mx, my)
    -- zoom inversely proportional to distance
    local dist = ((player.x-boss.x)^2+(player.y-boss.y)^2)^0.5
    camera:zoomTo(math.clamp(zoomBase/dist, minZ, maxZ))
    -- sync parallax with camera
    for _, layer in ipairs(layers) do
      layer.scale = layer.baseScale * camera.scale
      layer.offsetX = camera.x
      layer.offsetY = camera.y
    end
end

function love.draw()
    camera:attach()
      -- draw each parallax layer
      for _, layer in ipairs(layers) do
        layer:draw(function()
          love.graphics.draw(layer.image, 0, 0)
        end)
      end
      -- draw game sprites
      player:draw()
      boss:draw()
    camera:detach()
end
