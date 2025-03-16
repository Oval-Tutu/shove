local fontSize = 18
local lineHeight = fontSize + 4
local debugFont = love.graphics.newFont(fontSize)
local shoveDebug = {
  shove = nil,                        -- Reference to the main Shöve instance
  isActive = false,                   -- is Overlay visible
  hasVsync = love.window.getVSync(),  -- is VSync enabled
  collectionInterval = 0.2,           -- How often to collect metrics (seconds)
  lastCollectionTime = 0,             -- Timestamp of last collection
  lastEventPushTime = 0,              -- Timestamp of last event push
  metrics = {},                       -- Container for collected metrics
  particleCount = 0,                  -- Total particle count
  particleSystems = {},               -- Table to store references to particle systems
  controller = {
    cooldown = 0.2,                   -- Cooldown for controller input
    lastCheckTime = 0,                -- Last time controller input was checked
  },
  touch = {
    cornerSize = 80,                  -- Size of corner activation area in pixels
    lastTapTime = 0,                  -- Time of last tap for double-tap detection
    doubleTapThreshold = 0.5,         -- Maximum time between taps to register as double-tap
    overlayArea = {x=0, y=0, width=0, height=0}  -- Will be updated in showMetrics
  },
  colorRed = { 1, 0.5, 0.5, 1 },
  colorGreen = { 0.5, 1, 0.5, 1 },
  colorBlue = { 0.5, 0.5, 1, 1 },
  colorPurple = { 0.75, 0.5, 1, 1 },
  colorWhite = { 1, 1, 1, 1 },
}
local cachedHardwareInfo = {}
local cachedPerformanceInfo = {}
local cachedShoveInfo = {}
local cachedLayerInfo = {}

function shoveDebug.init(shoveRef)
  shoveDebug.shove = shoveRef
  local originalHandlers = {}
  local debugEventsToHook = {
    "keypressed",
    "touchpressed",
    "gamepadpressed",
  }
  -- Hook debug into events
  for _, event in ipairs(debugEventsToHook) do
    -- Store original handler
    originalHandlers[event] = love.handlers[event]
    love.handlers[event] = function(...)
      -- Call our debug handler
      if shoveDebug[event] then
        shoveDebug[event](...)
      end
      -- Call the original handler
      if originalHandlers[event] then
        originalHandlers[event](...)
      end
    end
  end

  -- Collect static metrics
  shoveDebug.metrics.arch = love.system.getOS() ~= "Web" and require("ffi").arch or "Web"
  shoveDebug.metrics.os = love.system.getOS()
  shoveDebug.metrics.cpuCount = love.system.getProcessorCount()
  shoveDebug.metrics.rendererName,
  shoveDebug.metrics.rendererVersion,
  shoveDebug.metrics.rendererVendor,
  shoveDebug.metrics.rendererDevice = love.graphics.getRendererInfo()
  local graphicsSupported = love.graphics.getSupported()
  shoveDebug.metrics.glsl3 = graphicsSupported.glsl3
  shoveDebug.metrics.pixelShaderHighp = graphicsSupported.pixelshaderhighp
  cachedHardwareInfo = {
    string.format("%s (%s): %s x CPU", shoveDebug.metrics.os, shoveDebug.metrics.arch, shoveDebug.metrics.cpuCount),
    string.format("%s (%s)", shoveDebug.metrics.rendererName, shoveDebug.metrics.rendererVendor),
    string.format("%s", shoveDebug.metrics.rendererDevice:sub(1,23)),
    string.format("%s", shoveDebug.metrics.rendererVersion:sub(1,30)),
    string.format("GLSL 3.0: %s", shoveDebug.metrics.glsl3 and "Yes" or "No"),
    string.format("Highp Pixel Shader: %s", shoveDebug.metrics.pixelShaderHighp and "Yes" or "No"),
    ""
  }

  -- Set up the metrics collection event handler
  love.handlers["shove_collect_metrics"] = function()
    -- Check if enough time has passed since last collection
    local currentTime = love.timer.getTime()
    if currentTime - shoveDebug.lastCollectionTime < shoveDebug.collectionInterval then
      return
    end
    shoveDebug.lastCollectionTime = currentTime

    -- Collect metrics
    shoveDebug.metrics.fps = love.timer.getFPS()
    shoveDebug.metrics.memory = collectgarbage("count")
    shoveDebug.metrics.stats = love.graphics.getStats()
    shoveDebug.metrics.state = shoveDebug.shove.getState()

    local textureMemoryMB = shoveDebug.metrics.stats.texturememory / (1024 * 1024)
    local memoryMB = shoveDebug.metrics.memory / 1024
    local frameTime = love.timer.getDelta() * 1000
    local textureMemoryMB = shoveDebug.metrics.stats.texturememory / (1024 * 1024)
    local memoryMB = shoveDebug.metrics.memory / 1024

    -- Calculate total particle count
    local totalParticles = 0
    for ps, _ in pairs(shoveDebug.particleSystems) do
      if ps:isActive() then
        totalParticles = totalParticles + ps:getCount()
      end
    end
    shoveDebug.metrics.particleCount = totalParticles

    cachedPerformanceInfo = {
      string.format("FPS: %.0f (%.1f ms)", shoveDebug.metrics.fps, frameTime),
      string.format("VSync: %s", shoveDebug.hasVsync and "On" or "Off"),
      string.format("Draw Calls: %d (%d batched)", shoveDebug.metrics.stats.drawcalls, shoveDebug.metrics.stats.drawcallsbatched),
      string.format("Canvases: %d (%d switches)", shoveDebug.metrics.stats.canvases, shoveDebug.metrics.stats.canvasswitches),
      string.format("Shader Switches: %d", shoveDebug.metrics.stats.shaderswitches),
      string.format("Particles: %d", totalParticles),
      string.format("Images: %d", shoveDebug.metrics.stats.images),
      string.format("Fonts: %d", shoveDebug.metrics.stats.fonts),
      string.format("VRAM: %.1f MB", textureMemoryMB),
      string.format("RAM: %.1f MB", memoryMB),
      ""
    }
    cachedShoveInfo = {
      string.format("Shöve %s", shove._VERSION.string),
      string.format("Mode: %s  /  %s  /  %s", shoveDebug.metrics.state.renderMode, shoveDebug.metrics.state.fitMethod, shoveDebug.metrics.state.scalingFilter),
      string.format("Window: %d x %d", shoveDebug.metrics.state.screen_width, shoveDebug.metrics.state.screen_height),
      string.format("Viewport: %d x %d", shoveDebug.metrics.state.viewport_width, shoveDebug.metrics.state.viewport_height),
      string.format("Rendered: %d x %d", shoveDebug.metrics.state.rendered_width, shoveDebug.metrics.state.rendered_height),
      string.format("Scale: %.1f x %.1f", shoveDebug.metrics.state.scale_x, shoveDebug.metrics.state.scale_y),
      string.format("Offset: %d x %d", shoveDebug.metrics.state.offset_x, shoveDebug.metrics.state.offset_y),
      ""
    }
    cachedLayerInfo = {}
    if shoveDebug.metrics.state.renderMode == "layer" then
      cachedLayerInfo = {
        string.format("Layers: (%d / %s)", shoveDebug.metrics.state.layers.count, shoveDebug.metrics.state.layers.active),
      }
    end
  end
end

local function infoLooper(info, x, y, colorHeader)
  if #info == 0 then return y end

  for i=1, #info do
    if i == 1 then
      love.graphics.setColor(colorHeader)
    elseif i == 2 then
      love.graphics.setColor(shoveDebug.colorWhite)
    end
    love.graphics.print(info[i], x, y)
    y = y + lineHeight
  end
  return y
end

--- Display debug information
---@param x number|nil X position for debug display (default: 10)
---@param y number|nil Y position for debug display (default: 10)
---@return nil
function shoveDebug.showMetrics()
  if not shoveDebug.isActive then return end

  -- Save current graphics state
  local r, g, b, a = love.graphics.getColor()
  local font = love.graphics.getFont()
  local blendMode, blendAlphaMode = love.graphics.getBlendMode()

  love.graphics.setFont(debugFont)

  -- Default position in top-left corner with small margin
  local panelPadding = 10
  local panelWidth = 320
  local panelHeight = 0
  local x = love.graphics.getWidth() - panelWidth - panelPadding
  local y = panelPadding
  local currentX = x + panelPadding
  local currentY = y + panelPadding

  panelHeight = (#cachedShoveInfo + #cachedHardwareInfo + #cachedPerformanceInfo) * lineHeight
  if shoveDebug.metrics.state.renderMode == "layer" then
    panelHeight = panelHeight + (#cachedLayerInfo + shoveDebug.metrics.state.layers.count) * lineHeight
    panelHeight = panelHeight + panelPadding * 2
  end

  -- Update the overlay touch area dimensions
  shoveDebug.touch.overlayArea = {
    x = x,                  -- Left position of overlay
    y = y,                  -- Top position of overlay
    width = panelWidth,     -- Width of overlay
    height = panelHeight    -- Height of overlay
  }

  -- Panel
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
  -- Panel Border
  love.graphics.setColor(0.5, 0.5, 0.5, 1)
  love.graphics.rectangle("line", x, y, panelWidth, panelHeight)

  currentY = infoLooper(cachedHardwareInfo, currentX, currentY, shoveDebug.colorBlue)
  currentY = infoLooper(cachedPerformanceInfo, currentX, currentY, shoveDebug.colorBlue)
  currentY = infoLooper(cachedShoveInfo, currentX, currentY, shoveDebug.colorPurple)

  -- Draw layer info
  if shoveDebug.metrics.state.renderMode == "layer" then
    currentY = infoLooper(cachedLayerInfo, currentX, currentY, shoveDebug.colorPurple)
    local color = shoveDebug.colorWhite
    local old_color = nil
    local layer = shoveDebug.metrics.state.layers.ordered
    local layerText = ""
    for i=1, #layer do
      if layer[i].name ~= "_composite" and layer[i].name ~= "_tmp" then
        layerText = string.format(
          "%d: %s (%s / %s)",
          layer[i].zIndex,
          layer[i].name,
          layer[i].blendMode,
          layer[i].blendAlphaMode:sub(1,4)
        )
        if layer[i].name == shoveDebug.metrics.state.layers.active then
          color = shoveDebug.colorGreen
        end
        if not layer[i].visible then
          color = shoveDebug.colorRed
        end
        if color ~= old_color then
          love.graphics.setColor(color)
        end
        love.graphics.print(layerText, currentX, currentY)
        old_color = color
        currentY = currentY + lineHeight
      end
    end
  end

  -- Restore graphics state
  love.graphics.setColor(r, g, b, a)
  love.graphics.setFont(font)
  love.graphics.setBlendMode(blendMode, blendAlphaMode)

  -- Time-based throttle synchronized with collection interval
  local currentTime = love.timer.getTime()
  -- Push at half the rate (twice the interval)
  local pushInterval = shoveDebug.collectionInterval * 2
  if currentTime - shoveDebug.lastEventPushTime >= pushInterval then
    love.event.push("shove_collect_metrics")
    shoveDebug.lastEventPushTime = currentTime
  end
end

local function toggleOverlay()
  shoveDebug.isActive = not shoveDebug.isActive
  if shoveDebug.isActive then
    shoveDebug.lastCollectionTime = 0
    love.event.push("shove_collect_metrics")
  end
  print("Debug overlay is now " .. (shoveDebug.isActive and "visible" or "hidden"))
end

local function toggleVSync()
  if not shoveDebug.isActive then return end

  shoveDebug.hasVsync = not shoveDebug.hasVsync
  love.window.setVSync(shoveDebug.hasVsync)
  print("VSync is now " .. (shoveDebug.hasVsync and "On" or "Off"))
end

--- Detects if a touch/click position is inside the corner activation area
---@param x number Touch/click x-coordinate
---@param y number Touch/click y-coordinate
---@return boolean True if touch is in the corner activation area
local function isTouchInCorner(x, y)
  local w, h = love.graphics.getDimensions()
  return x >= w - shoveDebug.touch.cornerSize and y <= shoveDebug.touch.cornerSize
end

--- Detects if a touch/click position is inside the overlay area
---@param x number Touch/click x-coordinate
---@param y number Touch/click y-coordinate
---@return boolean True if touch is in the corner activation area
local function isTouchInsideOverlay(x, y)
  local area = shoveDebug.touch.overlayArea
  return x >= area.x and x <= area.x + area.width and
         y >= area.y and y <= area.y + area.height
end

function shoveDebug.gamepadpressed(joystick, button)
  local currentTime = love.timer.getTime()
  if currentTime - shoveDebug.controller.lastCheckTime < shoveDebug.controller.cooldown then
    return
  end
  shoveDebug.controller.lastCheckTime = currentTime

  -- Toggle with Select + Y/Triangle
  if button == "back" and joystick:isGamepadDown("y") then
    toggleOverlay()
  end
  -- Toggle VSync with Select + B/Circle when debug is active
  if shoveDebug.isActive and button == "back" and joystick:isGamepadDown("b") then
    toggleVSync()
  end
end

function shoveDebug.keypressed(key)
  -- Toggle with Ctrl+D or Cmd+D
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "d" then
    toggleOverlay()
  end
  -- Toggle VSync with Ctrl+V or Cmd+V when debug is active
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "v" then
    toggleVSync()
  end
end

--- Handles touch input for toggling debug overlay and VSync
---@param id any Touch ID from LÖVE
---@param x number The x-coordinate of the touch
---@param y number The y-coordinate of the touch
---@return nil
function shoveDebug.touchpressed(id, x, y)
  local currentTime = love.timer.getTime()
  local timeSinceLastTap = currentTime - shoveDebug.touch.lastTapTime

  if shoveDebug.isActive and isTouchInsideOverlay(x, y) then
    -- Handle touches inside the active overlay
    if timeSinceLastTap <= shoveDebug.touch.doubleTapThreshold then
      toggleVSync()
      shoveDebug.touch.lastTapTime = 0
    else
      shoveDebug.touch.lastTapTime = currentTime
    end
  elseif isTouchInCorner(x, y) then
    -- Toggle overlay with double-tap in corner
    if timeSinceLastTap <= shoveDebug.touch.doubleTapThreshold then
      toggleOverlay()
      shoveDebug.touch.lastTapTime = 0
    else
      shoveDebug.touch.lastTapTime = currentTime
    end
  end
end

--- Register a particle system to be tracked in metrics
---@param particleSystem love.ParticleSystem The particle system to track
---@return nil
function shoveDebug.registerParticleSystem(particleSystem)
  shoveDebug.particleSystems[particleSystem] = true
end

--- Unregister a particle system from tracking
---@param particleSystem love.ParticleSystem The particle system to unregister
---@return nil
function shoveDebug.unregisterParticleSystem(particleSystem)
  shoveDebug.particleSystems[particleSystem] = nil
end

return shoveDebug
