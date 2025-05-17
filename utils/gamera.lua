-- gamera.lua v1.0.1

-- Copyright (c) 2018 Enrique García Cota
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- Based on YaciCode, from Julien Patte and LuaObject, from Sebastien Rocca-Serra

---@diagnostic disable: undefined-global
local love = love

local gamera = {}

-- Private attributes and methods

local gameraMt = {__index = gamera}
local abs, min, max = math.abs, math.min, math.max

local function clamp(x, minX, maxX)
  return x < minX and minX or (x>maxX and maxX or x)
end

local function checkNumber(value, name)
  if type(value) ~= 'number' then
    error(name .. " must be a number (was: " .. tostring(value) .. ")")
  end
end

local function checkPositiveNumber(value, name)
  if type(value) ~= 'number' or value <=0 then
    error(name .. " must be a positive number (was: " .. tostring(value) ..")")
  end
end

local function checkAABB(l,t,w,h)
  checkNumber(l, "l")
  checkNumber(t, "t")
  checkPositiveNumber(w, "w")
  checkPositiveNumber(h, "h")
end

-- Added smoothing functions from camera.lua
gamera.smooth = {}

function gamera.smooth.none()
  return function(dx,dy) return dx,dy end
end

function gamera.smooth.linear(speed)
  assert(type(speed) == "number", "Invalid parameter: speed = "..tostring(speed))
  return function(dx,dy, s)
    -- normalize direction
    local d = math.sqrt(dx*dx+dy*dy)
    if d == 0 then return 0,0 end -- If already at target, no movement
    local delta_t = love.timer.getDelta() -- Get dt for frame-rate independent movement
    local dts = math.min((s or speed) * delta_t, d) -- prevent overshooting the goal
    
    return (dx/d)*dts, (dy/d)*dts
  end
end

function gamera.smooth.damped(stiffness)
  assert(type(stiffness) == "number", "Invalid parameter: stiffness = "..tostring(stiffness))
  return function(dx,dy, s)
    local delta_t = love.timer.getDelta() -- Get dt for frame-rate independent movement
    local dts = delta_t * (s or stiffness)
    return dx*dts, dy*dts
  end
end
-- End of added smoothing functions

-- Scale smoothers: operate on a scale difference only
gamera.smooth.scale_none = function()
  return function(dscale)
    return dscale
  end
end

gamera.smooth.scale_linear = function(speed)
  assert(type(speed) == "number", "Invalid parameter: speed = "..tostring(speed))
  return function(dscale)
    local dt = love.timer.getDelta()
    local amt = math.min(math.abs(dscale), speed * dt)
    return (dscale < 0 and -amt or amt)
  end
end

gamera.smooth.scale_damped = function(stiffness)
  assert(type(stiffness) == "number", "Invalid parameter: stiffness = "..tostring(stiffness))
  return function(dscale)
    local dt = love.timer.getDelta()
    return dscale * dt * stiffness
  end
end

local function getVisibleArea(self, scale)
  scale = scale or self.scale
  local sin, cos = abs(self.sin), abs(self.cos)
  local w,h = self.w / scale, self.h / scale
  w,h = cos*w + sin*h, sin*w + cos*h
  return min(w,self.ww), min(h, self.wh)
end

local function cornerTransform(self, x,y)
  local scale, sin, cos = self.scale, self.sin, self.cos
  x,y = x - self.x, y - self.y
  x,y = -cos*x + sin*y, -sin*x - cos*y
  return self.x - (x/scale + self.l), self.y - (y/scale + self.t)
end

local function adjustPosition(self)
  local wl,wt,ww,wh = self.wl, self.wt, self.ww, self.wh
  local w,h = getVisibleArea(self)
  local w2,h2 = w*0.5, h*0.5

  local left, right  = wl + w2, wl + ww - w2
  local top,  bottom = wt + h2, wt + wh - h2

  self.x, self.y = clamp(self.x, left, right), clamp(self.y, top, bottom)
end

local function adjustScale(self)
  local w,h,ww,wh = self.w, self.h, self.ww, self.wh
  local rw,rh     = getVisibleArea(self, 1)      -- rotated frame: area around the window, rotated without scaling
  local sx,sy     = rw/ww, rh/wh                 -- vert/horiz scale: minimun scales that the window needs to occupy the world
  local rscale    = max(sx,sy)

  self.scale = max(self.scale, rscale)
end

-- Public interface

function gamera.new(l,t,w,h, smoother_func) -- Added smoother_func argument
  local sw,sh = love.graphics.getWidth(), love.graphics.getHeight()

  local cam = setmetatable({
    x=0, y=0, -- Initial position, will be adjusted by setWorld
    scale=1,
    angle=0, sin=math.sin(0), cos=math.cos(0),
    l=0, t=0, w=sw, h=sh, w2=sw*0.5, h2=sh*0.5,
    smoother = smoother_func or gamera.smooth.none(), -- Store the smoother
    target_x = nil, -- Initialize target position
    target_y = nil,
    target_scale = 1,              -- initialize target scale
    scale_smoother = gamera.smooth.scale_none()  -- default scale smoother
  }, gameraMt)

  cam:setWorld(l,t,w,h) -- This sets initial cam.x, cam.y based on world and window via adjustPosition

  -- Initialize target to current position *after* setWorld has potentially adjusted x,y
  cam.target_x = cam.x 
  cam.target_y = cam.y
  cam.target_scale = cam.scale
  
  return cam
end

function gamera:setWorld(l,t,w,h)
  checkAABB(l,t,w,h)

  self.wl, self.wt, self.ww, self.wh = l,t,w,h

  adjustPosition(self)
end

function gamera:setWindow(l,t,w,h)
  checkAABB(l,t,w,h)

  self.l, self.t, self.w, self.h, self.w2, self.h2 = l,t,w,h, w*0.5, h*0.5

  adjustPosition(self)
end

function gamera:setPosition(x,y)
  checkNumber(x, "x")
  checkNumber(y, "y")

  self.x, self.y = x,y
  -- Also update target_x and target_y if we do an immediate jump
  -- to prevent smoother from immediately trying to go back.
  self.target_x = x
  self.target_y = y

  adjustPosition(self)
end

function gamera:setScale(scale)
  checkNumber(scale, "scale")

  self.scale = scale

  adjustScale(self)
  adjustPosition(self)
end

function gamera:setScaleForced(scale)
  checkNumber(scale, "scale")

  self.scale = scale

  adjustPosition(self)
end

function gamera:setAngle(angle)
  checkNumber(angle, "angle")

  self.angle = angle
  self.cos, self.sin = math.cos(angle), math.sin(angle)

  adjustScale(self)
  adjustPosition(self)
end

function gamera:getWorld()
  return self.wl, self.wt, self.ww, self.wh
end

function gamera:getWindow()
  return self.l, self.t, self.w, self.h
end

function gamera:getPosition()
  return self.x, self.y
end

function gamera:getScale()
  return self.scale
end

function gamera:getAngle()
  return self.angle
end

function gamera:getVisible()
  local w,h = getVisibleArea(self)
  return self.x - w*0.5, self.y - h*0.5, w, h
end

function gamera:getVisibleCorners()
  local x,y,w2,h2 = self.x, self.y, self.w2, self.h2

  local x1,y1 = cornerTransform(self, x-w2,y-h2)
  local x2,y2 = cornerTransform(self, x+w2,y-h2)
  local x3,y3 = cornerTransform(self, x+w2,y+h2)
  local x4,y4 = cornerTransform(self, x-w2,y+h2)

  return x1,y1,x2,y2,x3,y3,x4,y4
end

function gamera:draw(f)
  local sx, sy, sw, sh = love.graphics.getScissor()
  love.graphics.setScissor(self:getWindow())

  love.graphics.push()
    local scale = self.scale
    love.graphics.scale(scale)

    love.graphics.translate((self.w2 + self.l) / scale, (self.h2+self.t) / scale)
    love.graphics.rotate(-self.angle)
    love.graphics.translate(-self.x, -self.y)

    f(self:getVisible())

  love.graphics.pop()

  love.graphics.setScissor(sx, sy, sw, sh)
end

function gamera:toWorld(x,y)
  local scale, sin, cos = self.scale, self.sin, self.cos
  x,y = (x - self.w2 - self.l) / scale, (y - self.h2 - self.t) / scale
  x,y = cos*x - sin*y, sin*x + cos*y
  return x + self.x, y + self.y
end

function gamera:toScreen(x,y)
  local scale, sin, cos = self.scale, self.sin, self.cos
  x,y = x - self.x, y - self.y
  x,y = cos*x + sin*y, -sin*x + cos*y
  return scale * x + self.w2 + self.l, scale * y + self.h2 + self.t
end

function gamera:setSmoother(smoother_func)
  self.smoother = smoother_func or gamera.smooth.none()
  return self -- Allow chaining
end

function gamera:setTargetPosition(x,y)
  checkNumber(x, "target_x")
  checkNumber(y, "target_y")
  self.target_x = x
  self.target_y = y
  return self -- Allow chaining
end

function gamera:update(dt) -- dt from love.update, though smoothers use love.timer.getDelta()
  -- Smooth scale toward target_scale
  local ds = self.target_scale - self.scale
  local snap_th = 0.001
  if math.abs(ds) <= snap_th then
    self.scale = self.target_scale
    adjustScale(self)
    adjustPosition(self)
  else
    local dscale = self.scale_smoother(ds)
    self.scale = self.scale + dscale
    adjustScale(self)
    adjustPosition(self)
  end

  if self.target_x ~= nil and self.target_y ~= nil then
    local current_x, current_y = self.x, self.y

    local dx = self.target_x - current_x
    local dy = self.target_y - current_y

    -- If already very close to the target, snap to avoid tiny oscillations
    local snap_threshold = 0.05 -- Adjust as needed
    if math.abs(dx) < snap_threshold and math.abs(dy) < snap_threshold then
        if current_x ~= self.target_x or current_y ~= self.target_y then
            self.x = self.target_x
            self.y = self.target_y
            adjustPosition(self) -- Clamp after snapping
        end
        return -- Snapped or already at target
    end

    -- The smoother functions use love.timer.getDelta() internally.
    local move_dx, move_dy = self.smoother(dx, dy)

    self.x = current_x + move_dx
    self.y = current_y + move_dy
    
    adjustPosition(self)
  end
end

-- Set desired zoom level (scale) with smoothing
function gamera:setTargetScale(scale)
  checkNumber(scale, "target_scale")
  self.target_scale = scale
  return self
end

-- Choose a scale smoother function (e.g., gamera.smooth.scale_linear or scale_damped)
function gamera:setScaleSmoother(fn)
  self.scale_smoother = fn or gamera.smooth.scale_none()
  return self
end

return gamera




