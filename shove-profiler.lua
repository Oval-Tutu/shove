local _fontSize = 18
local _font = love.graphics.newFont(_fontSize)

---@class ShoveProfiler
---@field shove table Reference to the main Shöve instance
---@field config table Configuration settings
---@field state table State for overlay visibility and tracking
---@field metrics table Metrics data containers
---@field particles table Particle system tracking
---@field input table Input handling
local shoveProfiler = {
  -- Reference to the main Shöve instance
  shove = nil,
  -- Configuration settings
  config = {
    fontSize = _fontSize,
    lineHeight = _fontSize + 4,
    font = _font,
    collectionInterval = 0.2,
    colors = {
      red = { 1, 0.5, 0.5, 1 },
      green = { 0.5, 1, 0.5, 1 },
      blue = { 0.5, 0.5, 1, 1 },
      purple = { 0.75, 0.5, 1, 1 },
      white = { 1, 1, 1, 1 },
    },
    -- Panel settings
    panel = {
      width = 320,
      padding = 10,
      height = 0, -- Will be calculated dynamically
    }
  },
  -- State for overlay visibility and tracking
  state = {
    isOverlayVisible = false,
    isVsyncEnabled = love.window.getVSync(),
    lastCollectionTime = 0,
    lastEventPushTime = 0,
  },
  -- Metrics data containers
  metrics = {},
  -- Particle system tracking
  particles = {
    count = 0,
    systems = {},
  },
  -- Input handling
  input = {
    controller = {
      cooldown = 0.2,
      lastCheckTime = 0,
    },
    touch = {
      cornerSize = 80,
      lastTapTime = 0,
      doubleTapThreshold = 0.5,
      overlayArea = {x=0, y=0, width=0, height=0},
    }
  }
}

-- Cache for displayed information
---@type string[]
local cachedHardwareInfo = {}
---@type string[]
local cachedPerformanceInfo = {}
---@type string[]
local cachedShoveInfo = {}
---@type string[]
local cachedLayerInfo = {}

--- Update panel dimensions based on current metrics data
---@return nil
local function updatePanelDimensions()
  -- Calculate panel height based on content
  local contentHeight = (#cachedShoveInfo + #cachedHardwareInfo + #cachedPerformanceInfo) * shoveProfiler.config.lineHeight

  -- Add layer info height if using layer rendering
  if shoveProfiler.metrics.state and shoveProfiler.metrics.state.renderMode == "layer" then
    local layerCount = shoveProfiler.metrics.state.layers.count or 0
    contentHeight = contentHeight + (#cachedLayerInfo + layerCount) * shoveProfiler.config.lineHeight
    contentHeight = contentHeight + shoveProfiler.config.panel.padding * 2
  end

  shoveProfiler.config.panel.height = contentHeight

  -- Update the overlay touch area dimensions
  local screenWidth = love.graphics.getWidth()
  local x = screenWidth - shoveProfiler.config.panel.width - shoveProfiler.config.panel.padding
  local y = shoveProfiler.config.panel.padding

  shoveProfiler.input.touch.overlayArea = {
    x = x,
    y = y,
    width = shoveProfiler.config.panel.width,
    height = contentHeight
  }
end

--- Initialize the profiler with a reference to the Shöve instance
---@param shoveRef table Reference to the main Shöve instance
---@return nil
function shoveProfiler.init(shoveRef)
  shoveProfiler.shove = shoveRef
  local originalHandlers = {}
  local eventsToHook = {
    "keypressed",
    "touchpressed",
    "gamepadpressed",
  }
  -- Hook profiler into events
  for _, event in ipairs(eventsToHook) do
    -- Store original handler
    originalHandlers[event] = love.handlers[event]
    love.handlers[event] = function(...)
      -- Call our handler
      if shoveProfiler[event] then
        shoveProfiler[event](...)
      end
      -- Call the original handler
      if originalHandlers[event] then
        originalHandlers[event](...)
      end
    end
  end

  -- Collect static metrics
  shoveProfiler.metrics.arch = love.system.getOS() ~= "Web" and require("ffi").arch or "Web"
  shoveProfiler.metrics.os = love.system.getOS()
  shoveProfiler.metrics.cpuCount = love.system.getProcessorCount()
  shoveProfiler.metrics.rendererName,
  shoveProfiler.metrics.rendererVersion,
  shoveProfiler.metrics.rendererVendor,
  shoveProfiler.metrics.rendererDevice = love.graphics.getRendererInfo()
  local graphicsSupported = love.graphics.getSupported()
  shoveProfiler.metrics.glsl3 = graphicsSupported.glsl3
  shoveProfiler.metrics.pixelShaderHighp = graphicsSupported.pixelshaderhighp
  cachedHardwareInfo = {
    string.format("%s (%s): %s x CPU", shoveProfiler.metrics.os, shoveProfiler.metrics.arch, shoveProfiler.metrics.cpuCount),
    string.format("%s (%s)", shoveProfiler.metrics.rendererName, shoveProfiler.metrics.rendererVendor),
    string.format("%s", shoveProfiler.metrics.rendererDevice:sub(1,23)),
    string.format("%s", shoveProfiler.metrics.rendererVersion:sub(1,30)),
    string.format("GLSL 3.0: %s", shoveProfiler.metrics.glsl3 and "Yes" or "No"),
    string.format("Highp Pixel Shader: %s", shoveProfiler.metrics.pixelShaderHighp and "Yes" or "No"),
    ""
  }
  updatePanelDimensions()

  -- Set up the metrics collection event handler
  love.handlers["shove_collect_metrics"] = function()
    -- Check if enough time has passed since last collection
    local currentTime = love.timer.getTime()
    if currentTime - shoveProfiler.state.lastCollectionTime < shoveProfiler.config.collectionInterval then
      return
    end
    shoveProfiler.state.lastCollectionTime = currentTime

    -- Collect metrics
    shoveProfiler.metrics.fps = love.timer.getFPS()
    shoveProfiler.metrics.memory = collectgarbage("count")
    shoveProfiler.metrics.stats = love.graphics.getStats()
    shoveProfiler.metrics.state = shoveProfiler.shove.getState()

    local textureMemoryMB = shoveProfiler.metrics.stats.texturememory / (1024 * 1024)
    local memoryMB = shoveProfiler.metrics.memory / 1024
    local frameTime = love.timer.getDelta() * 1000

    -- Calculate total particle count
    local totalParticles = 0
    for ps, _ in pairs(shoveProfiler.particles.systems) do
      if ps:isActive() then
        totalParticles = totalParticles + ps:getCount()
      end
    end
    shoveProfiler.particles.count = totalParticles

    cachedPerformanceInfo = {
      string.format("FPS: %.0f (%.1f ms)", shoveProfiler.metrics.fps, frameTime),
      string.format("VSync: %s", shoveProfiler.state.isVsyncEnabled and "On" or "Off"),
      string.format("Draw Calls: %d (%d batched)", shoveProfiler.metrics.stats.drawcalls, shoveProfiler.metrics.stats.drawcallsbatched),
      string.format("Canvases: %d (%d switches)", shoveProfiler.metrics.stats.canvases, shoveProfiler.metrics.stats.canvasswitches),
      string.format("Shader Switches: %d", shoveProfiler.metrics.stats.shaderswitches),
      string.format("Particles: %d", totalParticles),
      string.format("Images: %d", shoveProfiler.metrics.stats.images),
      string.format("Fonts: %d", shoveProfiler.metrics.stats.fonts),
      string.format("VRAM: %.1f MB", textureMemoryMB),
      string.format("RAM: %.1f MB", memoryMB),
      ""
    }
    cachedShoveInfo = {
      string.format("Shöve %s", shove._VERSION.string),
      string.format("Mode: %s  /  %s  /  %s", shoveProfiler.metrics.state.renderMode, shoveProfiler.metrics.state.fitMethod, shoveProfiler.metrics.state.scalingFilter),
      string.format("Window: %d x %d", shoveProfiler.metrics.state.screen_width, shoveProfiler.metrics.state.screen_height),
      string.format("Viewport: %d x %d", shoveProfiler.metrics.state.viewport_width, shoveProfiler.metrics.state.viewport_height),
      string.format("Rendered: %d x %d", shoveProfiler.metrics.state.rendered_width, shoveProfiler.metrics.state.rendered_height),
      string.format("Scale: %.1f x %.1f", shoveProfiler.metrics.state.scale_x, shoveProfiler.metrics.state.scale_y),
      string.format("Offset: %d x %d", shoveProfiler.metrics.state.offset_x, shoveProfiler.metrics.state.offset_y),
      ""
    }
    cachedLayerInfo = {}
    if shoveProfiler.metrics.state.renderMode == "layer" then
      cachedLayerInfo = {
        string.format("Layers: (%d / %s)", shoveProfiler.metrics.state.layers.count, shoveProfiler.metrics.state.layers.active),
      }
    end
    updatePanelDimensions()
  end
end

--- Render a section of information with proper coloring
---@param info string[] Array of text lines to display
---@param x number X position to render at
---@param y number Y position to render at
---@param colorHeader table Color for the section header
---@return number newY The new Y position after rendering
local function renderInfoSection(info, x, y, colorHeader)
  if #info == 0 then return y end

  for i=1, #info do
    if i == 1 then
      love.graphics.setColor(colorHeader)
    elseif i == 2 then
      love.graphics.setColor(shoveProfiler.config.colors.white)
    end
    love.graphics.print(info[i], x, y)
    y = y + shoveProfiler.config.lineHeight
  end
  return y
end

--- Display performance metrics and profiling information
---@return nil
function shoveProfiler.renderOverlay()
  if not shoveProfiler.state.isOverlayVisible then return end

  -- Save current graphics state
  local r, g, b, a = love.graphics.getColor()
  local font = love.graphics.getFont()
  local blendMode, blendAlphaMode = love.graphics.getBlendMode()

  love.graphics.setFont(shoveProfiler.config.font)

  -- Get panel dimensions from config
  local panel = shoveProfiler.config.panel
  local area = shoveProfiler.input.touch.overlayArea
  local renderX = area.x + panel.padding
  local renderY = area.y + panel.padding

  -- Panel background
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", area.x, area.y, panel.width, panel.height)
  -- Panel Border
  love.graphics.setColor(0.5, 0.5, 0.5, 1)
  love.graphics.rectangle("line", area.x, area.y, panel.width, panel.height)

  -- Render sections
  renderY = renderInfoSection(cachedHardwareInfo, renderX, renderY, shoveProfiler.config.colors.blue)
  renderY = renderInfoSection(cachedPerformanceInfo, renderX, renderY, shoveProfiler.config.colors.blue)
  renderY = renderInfoSection(cachedShoveInfo, renderX, renderY, shoveProfiler.config.colors.purple)

  -- Draw layer info
  if shoveProfiler.metrics.state.renderMode == "layer" then
    renderY = renderInfoSection(cachedLayerInfo, renderX, renderY, shoveProfiler.config.colors.purple)
    local color = shoveProfiler.config.colors.white
    local old_color = nil
    local layer = shoveProfiler.metrics.state.layers.ordered
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
        if layer[i].name == shoveProfiler.metrics.state.layers.active then
          color = shoveProfiler.config.colors.green
        end
        if not layer[i].visible then
          color = shoveProfiler.config.colors.red
        end
        if color ~= old_color then
          love.graphics.setColor(color)
        end
        love.graphics.print(layerText, renderX, renderY)
        old_color = color
        renderY = renderY + shoveProfiler.config.lineHeight
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
  local pushInterval = shoveProfiler.config.collectionInterval * 2
  if currentTime - shoveProfiler.state.lastEventPushTime >= pushInterval then
    love.event.push("shove_collect_metrics")
    shoveProfiler.state.lastEventPushTime = currentTime
  end
end

--- Toggle the visibility of the profiler overlay
---@return nil
local function toggleOverlay()
  shoveProfiler.state.isOverlayVisible = not shoveProfiler.state.isOverlayVisible
  if shoveProfiler.state.isOverlayVisible then
    shoveProfiler.state.lastCollectionTime = 0
    love.event.push("shove_collect_metrics")
  end
end

--- Toggle VSync on/off
---@return nil
local function toggleVSync()
  if not shoveProfiler.state.isOverlayVisible then return end

  shoveProfiler.state.isVsyncEnabled = not shoveProfiler.state.isVsyncEnabled
  love.window.setVSync(shoveProfiler.state.isVsyncEnabled)
end

--- Detects if a touch/click position is inside the corner activation area
---@param x number Touch/click x-coordinate
---@param y number Touch/click y-coordinate
---@return boolean isInCorner True if touch is in the corner activation area
local function isTouchInCorner(x, y)
  local w, h = love.graphics.getDimensions()
  return x >= w - shoveProfiler.input.touch.cornerSize and y <= shoveProfiler.input.touch.cornerSize
end

--- Detects if a touch/click position is inside the overlay area
---@param x number Touch/click x-coordinate
---@param y number Touch/click y-coordinate
---@return boolean isInOverlay True if touch is inside the overlay area
local function isTouchInsideOverlay(x, y)
  local area = shoveProfiler.input.touch.overlayArea
  return x >= area.x and x <= area.x + area.width and
         y >= area.y and y <= area.y + area.height
end

--- Handle gamepad button presses for profiler control
---@param joystick love.Joystick The joystick that registered the press
---@param button string The button that was pressed
---@return nil
function shoveProfiler.gamepadpressed(joystick, button)
  local currentTime = love.timer.getTime()
  if currentTime - shoveProfiler.input.controller.lastCheckTime < shoveProfiler.input.controller.cooldown then
    return
  end
  shoveProfiler.input.controller.lastCheckTime = currentTime

  -- Toggle overlay with Select + A/Cross
  if (button == "back" and joystick:isGamepadDown("a")) or
     (button == "a" and joystick:isGamepadDown("back")) then
     toggleOverlay()
  end
  -- Toggle VSync with Select + B/Circle
  if (button == "back" and joystick:isGamepadDown("b")) or
     (button == "b" and joystick:isGamepadDown("back")) then
    toggleVSync()
  end
end

--- Handle keyboard input for profiler control
---@param key string The key that was pressed
---@return nil
function shoveProfiler.keypressed(key)
  -- Toggle overlay with Ctrl+P or Cmd+P
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "p" then
    toggleOverlay()
  end
  -- Toggle VSync with Ctrl+V or Cmd+V
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "v" then
    toggleVSync()
  end
end

--- Handles touch input for toggling profiler overlay and VSync
---@param id any Touch ID from LÖVE
---@param x number The x-coordinate of the touch
---@param y number The y-coordinate of the touch
---@return nil
function shoveProfiler.touchpressed(id, x, y)
  local currentTime = love.timer.getTime()
  local timeSinceLastTap = currentTime - shoveProfiler.input.touch.lastTapTime

  if shoveProfiler.state.isOverlayVisible and isTouchInsideOverlay(x, y) then
    -- Handle touches inside the active overlay
    if timeSinceLastTap <= shoveProfiler.input.touch.doubleTapThreshold then
      toggleVSync()
      shoveProfiler.input.touch.lastTapTime = 0
    else
      shoveProfiler.input.touch.lastTapTime = currentTime
    end
  elseif isTouchInCorner(x, y) then
    -- Toggle overlay with double-tap in corner
    if timeSinceLastTap <= shoveProfiler.input.touch.doubleTapThreshold then
      toggleOverlay()
      shoveProfiler.input.touch.lastTapTime = 0
    else
      shoveProfiler.input.touch.lastTapTime = currentTime
    end
  end
end

--- Register a particle system to be tracked in metrics
---@param particleSystem love.ParticleSystem The particle system to track
---@return nil
function shoveProfiler.registerParticleSystem(particleSystem)
  shoveProfiler.particles.systems[particleSystem] = true
end

--- Unregister a particle system from tracking
---@param particleSystem love.ParticleSystem The particle system to unregister
---@return nil
function shoveProfiler.unregisterParticleSystem(particleSystem)
  shoveProfiler.particles.systems[particleSystem] = nil
end

return shoveProfiler
