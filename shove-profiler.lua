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
    sizes = {
      default = {
        fontSize = 18,
        lineHeight = 22, -- fontSize + 4
        panelWidth = 320,
        padding = 10
      },
      large = {
        fontSize = 26,
        lineHeight = 30, -- fontSize + 4
        panelWidth = 480,
        padding = 15
      }
    },
    collectionInterval = 0.2,
    colors = {
      red = { 1, 0.5, 0.5, 1 },
      green = { 0.5, 1, 0.5, 1 },
      blue = { 0.5, 0.5, 1, 1 },
      purple = { 0.75, 0.5, 1, 1 },
      yellow = { 1, 1, 0.5, 1 },
      orange = { 1, 0.7, 0.3, 1 },
      midGray = { 0.5, 0.5, 0.5, 1 },
      white = { 1, 1, 1, 1 },
    },
    -- Panel settings
    panel = {
      width = 320,
      padding = 10,
      height = 0,
      borderWidth = 5,
    },
    fonts = {}
  },
  -- State for overlay visibility and tracking
  state = {
    isOverlayVisible = false,
    isFpsOverlayVisible = false,
    isVsyncEnabled = love.window.getVSync(),
    lastCollectionTime = 0,
    lastEventPushTime = 0,
    currentSizePreset = "default",
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
      lastBorderTapTime = 0,
      lastBorderTapPosition = {x=0, y=0},
      cornerTaps = 0,
      lastCornerTapTime = 0,
      tripleTapThreshold = 0.5,
    }
  }
}

-- Initialize fonts for both size presets
local function initializeFonts()
  for sizeKey, sizeData in pairs(shoveProfiler.config.sizes) do
    shoveProfiler.config.fonts[sizeKey] = love.graphics.newFont(sizeData.fontSize)
  end
  shoveProfiler.config.font = shoveProfiler.config.fonts["default"]
end

-- Initialize with default size preset
local currentSize = shoveProfiler.config.sizes[shoveProfiler.state.currentSizePreset]
shoveProfiler.config.fontSize = currentSize.fontSize
shoveProfiler.config.lineHeight = currentSize.lineHeight
shoveProfiler.config.panel.width = currentSize.panelWidth
shoveProfiler.config.panel.padding = currentSize.padding

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
  -- Use the current size preset for panel calculations
  local currentSizePreset = shoveProfiler.state.currentSizePreset
  local currentSize = shoveProfiler.config.sizes[currentSizePreset]

  -- Calculate panel height based on content
  local contentHeight = (#cachedShoveInfo + #cachedHardwareInfo + #cachedPerformanceInfo) * shoveProfiler.config.lineHeight

  -- Add layer info height if using layer rendering
  if shoveProfiler.metrics.state and shoveProfiler.metrics.state.renderMode == "layer" then
    local layerCount = shoveProfiler.metrics.state.layers and (shoveProfiler.metrics.state.layers.count - shoveProfiler.metrics.state.layers.special_layer_count) or 0
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

--- Toggle between size presets
---@return nil
local function toggleSizePreset()
  if not shoveProfiler.state.isOverlayVisible then return end

  -- Toggle between default and large
  local newPreset = shoveProfiler.state.currentSizePreset == "default" and "large" or "default"
  shoveProfiler.state.currentSizePreset = newPreset

  -- Update current size properties
  local size = shoveProfiler.config.sizes[newPreset]
  shoveProfiler.config.fontSize = size.fontSize
  shoveProfiler.config.lineHeight = size.lineHeight
  shoveProfiler.config.panel.width = size.panelWidth
  shoveProfiler.config.panel.padding = size.padding

  -- Update font
  shoveProfiler.config.font = shoveProfiler.config.fonts[newPreset]

  -- Recalculate panel dimensions and refresh metrics
  updatePanelDimensions()
  love.event.push("shove_collect_metrics")
end

--- Sets up LÖVE event handlers for the profiler
---@param originalHandlers table Table to store original handlers
---@return nil
local function setupEventHandlers()
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
end

--- Collects static system metrics that don't change during runtime
---@return nil
local function collectStaticMetrics()
  local major, minor, revision = love.getVersion()
  shoveProfiler.metrics.loveVersion = string.format("%d.%d", major, minor)
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

  -- Cache hardware information
  cachedHardwareInfo = {
    string.format("%s %s (%s x CPU)", shoveProfiler.metrics.os, shoveProfiler.metrics.arch, shoveProfiler.metrics.cpuCount),
    string.format("%s (%s)", shoveProfiler.metrics.rendererName, shoveProfiler.metrics.rendererVendor),
    string.format("%s", shoveProfiler.metrics.rendererDevice:sub(1,23)),
    string.format("%s", shoveProfiler.metrics.rendererVersion:sub(1,30)),
    string.format("GLSL 3.0: %s", shoveProfiler.metrics.glsl3 and "Yes" or "No"),
    string.format("Highp Pixel Shader: %s", shoveProfiler.metrics.pixelShaderHighp and "Yes" or "No"),
    ""
  }
end

--- Sets up the metrics collection event handler
---@return nil
local function setupMetricsCollector()
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

    -- Safely get Shöve state
    if shoveProfiler.shove and type(shoveProfiler.shove.getState) == "function" then
      shoveProfiler.metrics.state = shoveProfiler.shove.getState()
    else
      shoveProfiler.metrics.state = {}
    end

    -- Safely access stats properties
    local stats = shoveProfiler.metrics.stats or {}
    local textureMemoryMB = (stats.texturememory or 0) / (1024 * 1024)
    local memoryMB = shoveProfiler.metrics.memory / 1024
    local frameTime = love.timer.getDelta() * 1000

    -- Calculate font count and adjust for the profiler's default fonts
    local fontCount = stats.fonts and (stats.fonts - 2) or 0

    -- Calculate total particle count
    local totalParticles = 0
    for ps, _ in pairs(shoveProfiler.particles.systems) do
      if ps and ps.isActive and ps:isActive() then
        totalParticles = totalParticles + ps:getCount()
      end
    end
    shoveProfiler.particles.count = totalParticles

    -- Build cached performance info
    cachedPerformanceInfo = {
      string.format("LÖVE %s ", shoveProfiler.metrics.loveVersion),
      string.format("FPS: %.0f (%.1f ms) [vsync: %s]", shoveProfiler.metrics.fps or 0, frameTime, shoveProfiler.state.isVsyncEnabled and "on" or "off"),
      string.format("Draw Calls: %d (%d batched)", stats.drawcalls or 0, stats.drawcallsbatched or 0),
      string.format("Canvases: %d (%d switches)", stats.canvases or 0, stats.canvasswitches or 0),
      string.format("Shader Switches: %d", stats.shaderswitches or 0),
      string.format("Particles: %d", totalParticles),
      string.format("Images: %d", stats.images or 0),
      string.format("Fonts: %d", fontCount),
      string.format("VRAM: %.1f MB", textureMemoryMB),
      string.format("RAM: %.1f MB", memoryMB),
      ""
    }

    -- Safely build Shöve info
    local state = shoveProfiler.metrics.state or {}

    -- Get batching state if available
    local batchingEnabled = "?"
    if shoveProfiler.shove and shoveProfiler.shove.getLayerBatching then
      batchingEnabled = shoveProfiler.shove.getLayerBatching() and "on" or "off"
    end

    cachedShoveInfo = {
      string.format("Shöve %s", (shove and shove._VERSION and shove._VERSION.string) or "Unknown"),
      string.format("Mode: %s  /  %s  /  %s", state.renderMode or "?", state.fitMethod or "?", state.scalingFilter or "?"),
      string.format("Window: %d x %d", state.screen_width or 0, state.screen_height or 0),
      string.format("Viewport: %d x %d", state.viewport_width or 0, state.viewport_height or 0),
      string.format("Rendered: %d x %d", state.rendered_width or 0, state.rendered_height or 0),
      string.format("Scale: %.1f x %.1f", state.scale_x or 0, state.scale_y or 0),
      string.format("Offset: %d x %d", state.offset_x or 0, state.offset_y or 0),
      ""
    }

    -- Safely build layer info
    for k in pairs(cachedLayerInfo) do cachedLayerInfo[k] = nil end
    local layerCount = 0
    local canvasCount = 0
    if state.renderMode == "layer" and state.layers then
      local layer_count = state.layers.count or 0
      local canvas_count = state.layers.canvas_count or 0
      local special_layer_count = state.layers.special_layer_count or 0
      layerCount = layer_count - special_layer_count
      canvasCount = canvas_count - special_layer_count
      local maskCount = state.layers.mask_count or 0

      -- Add special layer usage information
      local specialUsage = state.specialLayerUsage or {}

      cachedLayerInfo = {
        string.format("Render: ( Batching: %s )", batchingEnabled),
        string.format("Layers: %d (%d active)", layerCount, canvasCount - maskCount),
      }

      -- Add batching metrics if any batching occurred
      if (specialUsage.batchGroups or 0) > 0 then
        table.insert(cachedLayerInfo,
          string.format("Batches: %d (%d layers)",
            specialUsage.batchGroups,
            specialUsage.batchedLayers or 0)
        )
      end

      -- Only add Effects line if any effects were applied
      if (specialUsage.effectsApplied or 0) > 0 then
        table.insert(cachedLayerInfo,
        string.format("Effects: %d (%d %s)",
          specialUsage.effectsApplied,
          specialUsage.effectBufferSwitches or 0,
          (specialUsage.effectBufferSwitches or 0) == 1 and "switch" or "switches")
        )
      end

      -- Add batched effect operations if any occurred
      if (specialUsage.batchedEffectOperations or 0) > 0 then
        table.insert(cachedLayerInfo,
          string.format("Batched Effects: %d operations",
            specialUsage.batchedEffectOperations)
        )
      end

      -- Add state changes metric
      if (specialUsage.stateChanges or 0) > 0 then
        table.insert(cachedLayerInfo,
          string.format("State Changes: %d",
            specialUsage.stateChanges)
        )
      end

      table.insert(cachedLayerInfo, string.format("Composites: %d", specialUsage.compositeSwitches or 0))

    end
    updatePanelDimensions()
  end
end

--- Initialize the profiler with a reference to the Shöve instance
---@param shoveRef table Reference to the main Shöve instance
---@return boolean success Whether initialization was successful
function shoveProfiler.init(shoveRef)
  -- Validate input
  if not shoveRef then
    print("Error: Shöve reference is required to initialize the profiler")
    return false
  end
  -- Store Shöve reference
  shoveProfiler.shove = shoveRef

  -- Initialize fonts if not already done
  if next(shoveProfiler.config.fonts) == nil then
    initializeFonts()
  end

  setupEventHandlers()
  collectStaticMetrics()
  updatePanelDimensions()
  setupMetricsCollector()
  return true
end

--- Render a section of information with proper coloring
---@param info string[] Array of text lines to display
---@param x number X position to render at
---@param y number Y position to render at
---@param colorHeader table Color for the section header
---@return number newY The new Y position after rendering
local function renderInfoSection(info, x, y, colorHeader)
  if type(info) ~= "table" then
    return y
  end
  if type(x) ~= "number" or type(y) ~= "number" then
    return y
  end
  if type(colorHeader) ~= "table" then
    colorHeader = shoveProfiler.config.colors.white
  end

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

--- Renders layer information in the profiler overlay
---@param renderX number X position to render at
---@param renderY number Y position to render at
---@return number newY The new Y position after rendering
local function renderLayerInfo(renderX, renderY)
  if not shoveProfiler.metrics.state or shoveProfiler.metrics.state.renderMode ~= "layer" then
    return renderY
  end

  renderY = renderInfoSection(cachedLayerInfo, renderX, renderY, shoveProfiler.config.colors.purple)

  -- Safely access layer information
  local state = shoveProfiler.metrics.state
  if not state.layers or not state.layers.ordered then
    return renderY
  end

  local lastLayerIndex = state.layers.count - state.layers.special_layer_count
  local color = shoveProfiler.config.colors.white
  local old_color = nil
  local layerText = ""
  local effectsCount = 0
  local effectsInfo = ""
  local layers = state.layers.ordered
  for i=1, #layers do
    local layer = layers[i]
    if layer and layer.name and not layer.isSpecial then
      -- Calculate effects count for the layer
      effectsCount = layer.effects or 0
      -- Add global effects count to the last layer
      if i == lastLayerIndex then
        effectsCount = effectsCount + state.global_effects_count
      end
      effectsInfo = effectsCount > 0 and " [" .. effectsCount .. " fx]" or ""

      layerText = string.format(
        "%d: %s %s",
        layer.zIndex or 0,
        layer.name,
        effectsInfo
      )
      color = shoveProfiler.config.colors.white

      if not layer.visible then
        color = shoveProfiler.config.colors.red
      elseif layer.name == state.layers.active then
        color = shoveProfiler.config.colors.green
      elseif not layer.hasCanvas or layer.isUsedAsMask then
        -- Show mask layers in gray to indicate they're not composited
        color = shoveProfiler.config.colors.midGray
      end

      if color ~= old_color then
        love.graphics.setColor(color)
      end
      old_color = color

      love.graphics.print(layerText, renderX, renderY)
      renderY = renderY + shoveProfiler.config.lineHeight
    end
  end

  return renderY
end

--- Display performance metrics and profiling information
---@return nil
function shoveProfiler.renderOverlay()
  -- Save current graphics state
  local r, g, b, a = love.graphics.getColor()
  local font = love.graphics.getFont()
  local blendMode, blendAlphaMode = love.graphics.getBlendMode()

  -- First, render the full overlay if it's visible
  if shoveProfiler.state.isOverlayVisible then
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
    love.graphics.setColor(shoveProfiler.config.colors.midGray)
    love.graphics.rectangle("line", area.x, area.y, panel.width, panel.height)

    -- Render sections
    renderY = renderInfoSection(cachedHardwareInfo, renderX, renderY, shoveProfiler.config.colors.blue)
    renderY = renderInfoSection(cachedPerformanceInfo, renderX, renderY, shoveProfiler.config.colors.blue)
    renderY = renderInfoSection(cachedShoveInfo, renderX, renderY, shoveProfiler.config.colors.purple)
    renderY = renderLayerInfo(renderX, renderY)
  elseif shoveProfiler.state.isFpsOverlayVisible then
    -- Render minimal FPS overlay if enabled
    love.graphics.setFont(shoveProfiler.config.fonts["large"])
    local frameTime = love.timer.getDelta() * 1000
    local fpsText = string.format("FPS: %.0f (%.1f ms)",
                                  shoveProfiler.metrics.fps or 0,
                                  frameTime)

    -- Position in top-right corner with some padding
    local textWidth = shoveProfiler.config.fonts["large"]:getWidth(fpsText)
    local x = love.graphics.getWidth() - textWidth - 10
    local y = 10

    love.graphics.setColor(shoveProfiler.config.colors.orange)
    love.graphics.print(fpsText, x, y)
  end
  -- Restore graphics state
  love.graphics.setColor(r, g, b, a)
  love.graphics.setFont(font)
  love.graphics.setBlendMode(blendMode, blendAlphaMode)

  -- Time-based throttle synchronized with collection interval
  if shoveProfiler.state.isOverlayVisible or shoveProfiler.state.isFpsOverlayVisible then
    local currentTime = love.timer.getTime()
    -- Push at half the rate (twice the interval)
    local pushInterval = shoveProfiler.config.collectionInterval * 2
    if currentTime - shoveProfiler.state.lastEventPushTime >= pushInterval then
      love.event.push("shove_collect_metrics")
      shoveProfiler.state.lastEventPushTime = currentTime
    end
  end
end

--- Toggle the visibility of the profiler overlay
---@return nil
local function toggleOverlay()
  -- If FPS overlay is visible, hide it first
  if shoveProfiler.state.isFpsOverlayVisible then
    shoveProfiler.state.isFpsOverlayVisible = false
  end

  -- Toggle main overlay
  shoveProfiler.state.isOverlayVisible = not shoveProfiler.state.isOverlayVisible
  if shoveProfiler.state.isOverlayVisible then
    shoveProfiler.state.lastCollectionTime = 0
    love.event.push("shove_collect_metrics")
  end
end

--- Toggle the visibility of the minimal FPS overlay
---@return nil
local function toggleFpsOverlay()
  -- If main overlay is visible, hide it first
  if shoveProfiler.state.isOverlayVisible then
    shoveProfiler.state.isOverlayVisible = false
  end

  -- Toggle FPS overlay
  shoveProfiler.state.isFpsOverlayVisible = not shoveProfiler.state.isFpsOverlayVisible
  if shoveProfiler.state.isFpsOverlayVisible then
    -- Ensure metrics are collected for display
    shoveProfiler.state.lastCollectionTime = 0
    love.event.push("shove_collect_metrics")
  end
end

--- Toggle VSync on/off
---@return nil
local function toggleVSync()
  if not (shoveProfiler.state.isOverlayVisible or shoveProfiler.state.isFpsOverlayVisible) then
    return
  end

  shoveProfiler.state.isVsyncEnabled = not shoveProfiler.state.isVsyncEnabled
  love.window.setVSync(shoveProfiler.state.isVsyncEnabled)
end

--- Toggle layer batching on/off
---@return nil
local function toggleBatching()
  if not shoveProfiler.state.isOverlayVisible then return end
  if not shoveProfiler.shove or not shoveProfiler.shove.setLayerBatching then return end

  local currentState = shoveProfiler.shove.getLayerBatching()
  shoveProfiler.shove.setLayerBatching(not currentState)

  -- Force metrics collection to update display
  love.event.push("shove_collect_metrics")
end

--- Checks if a touch position is on the panel border
---@param x number Touch x-coordinate
---@param y number Touch y-coordinate
---@return boolean isOnBorder True if touch is on the panel border
local function isTouchOnPanelBorder(x, y)
  if not shoveProfiler.state.isOverlayVisible then return false end
  if type(x) ~= "number" or type(y) ~= "number" then return false end

  local area = shoveProfiler.input.touch.overlayArea
  local borderWidth = shoveProfiler.config.panel.borderWidth

  -- Check if touch is within border area (outer edge minus inner area)
  local isWithinOuterBounds = x >= area.x - borderWidth and
                             x <= area.x + area.width + borderWidth and
                             y >= area.y - borderWidth and
                             y <= area.y + area.height + borderWidth

  local isWithinInnerBounds = x > area.x + borderWidth and
                             x < area.x + area.width - borderWidth and
                             y > area.y + borderWidth and
                             y < area.y + area.height - borderWidth

  return isWithinOuterBounds and not isWithinInnerBounds
end

--- Detects if a touch/click position is inside the corner activation area
---@param x number Touch/click x-coordinate
---@param y number Touch/click y-coordinate
---@return boolean isInCorner True if touch is in the corner activation area
local function isTouchInCorner(x, y)
  if type(x) ~= "number" or type(y) ~= "number" then
    return false
  end

  local w, h = love.graphics.getDimensions()
  return x >= w - shoveProfiler.input.touch.cornerSize and y <= shoveProfiler.input.touch.cornerSize
end

--- Detects if a touch/click position is inside the overlay area
---@param x number Touch/click x-coordinate
---@param y number Touch/click y-coordinate
---@return boolean isInOverlay True if touch is inside the overlay area
local function isTouchInsideOverlay(x, y)
  if type(x) ~= "number" or type(y) ~= "number" then
    return false
  end

  local area = shoveProfiler.input.touch.overlayArea
  return x >= area.x and x <= area.x + area.width and
         y >= area.y and y <= area.y + area.height
end

--- Handle gamepad button presses for profiler control
---@param joystick love.Joystick The joystick that registered the press
---@param button string The button that was pressed
---@return nil
function shoveProfiler.gamepadpressed(joystick, button)
  if not joystick or type(button) ~= "string" then
    return
  end

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
  -- Toggle size preset with Select + Y/Triangle
  if (button == "back" and joystick:isGamepadDown("y")) or
     (button == "y" and joystick:isGamepadDown("back")) then
    toggleSizePreset()
  end
  -- Toggle batching with Select + X/Square when overlay is visible
  -- Toggle FPS overlay with Select + X/Square when overlay is not visible
  if (button == "back" and joystick:isGamepadDown("x")) or
     (button == "x" and joystick:isGamepadDown("back")) then
    if shoveProfiler.state.isOverlayVisible then
      toggleBatching()
    else
      toggleFpsOverlay()
    end
  end
end

--- Handle keyboard input for profiler control
---@param key string The key that was pressed
---@return nil
function shoveProfiler.keypressed(key)
  if type(key) ~= "string" then
    return
  end

  -- Toggle overlay with Ctrl+P or Cmd+P
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "p" then
    toggleOverlay()
  end
  -- Toggle FPS overlay with Ctrl+t or Cmd+t
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "t" then
    toggleFpsOverlay()
  end
  -- Toggle VSync with Ctrl+V or Cmd+V
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "v" then
    toggleVSync()
  end
  -- Toggle size preset with Ctrl+S or Cmd+S
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "s" then
    toggleSizePreset()
  end
  -- Toggle batching with Ctrl+B or Cmd+B
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "b" then
    toggleBatching()
  end
end

--- Handles touch input for toggling profiler overlay and VSync
---@param id any Touch ID from LÖVE
---@param x number The x-coordinate of the touch
---@param y number The y-coordinate of the touch
---@return nil
function shoveProfiler.touchpressed(id, x, y)
  if type(x) ~= "number" or type(y) ~= "number" then
    return
  end

  local currentTime = love.timer.getTime()

  -- Check for panel border taps to toggle size
  if isTouchOnPanelBorder(x, y) then
    local lastTapTime = shoveProfiler.input.touch.lastBorderTapTime
    local lastPos = shoveProfiler.input.touch.lastBorderTapPosition
    local distance = math.sqrt((x - lastPos.x)^2 + (y - lastPos.y)^2)

    -- Check if this is a double tap in roughly the same position
    if currentTime - lastTapTime <= shoveProfiler.input.touch.doubleTapThreshold and distance < 30 then
      toggleSizePreset()
      shoveProfiler.input.touch.lastBorderTapTime = 0
    else
      shoveProfiler.input.touch.lastBorderTapTime = currentTime
      shoveProfiler.input.touch.lastBorderTapPosition = {x = x, y = y}
    end
    return
  end

  -- Handle other touch interactions
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
    -- Check for triple tap to toggle FPS overlay
    if currentTime - shoveProfiler.input.touch.lastCornerTapTime <= shoveProfiler.input.touch.tripleTapThreshold then
      shoveProfiler.input.touch.cornerTaps = shoveProfiler.input.touch.cornerTaps + 1
      if shoveProfiler.input.touch.cornerTaps >= 3 then
        toggleFpsOverlay()
        shoveProfiler.input.touch.cornerTaps = 0
        shoveProfiler.input.touch.lastCornerTapTime = 0
      else
        shoveProfiler.input.touch.lastCornerTapTime = currentTime
      end
    else
      -- Reset corner tap counter for new sequence
      shoveProfiler.input.touch.cornerTaps = 1
      shoveProfiler.input.touch.lastCornerTapTime = currentTime
    end

    -- Toggle overlay with double-tap in corner (separate from triple tap)
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
---@return boolean success Whether registration was successful
function shoveProfiler.registerParticleSystem(particleSystem)
  if not particleSystem or type(particleSystem) ~= "userdata" or not particleSystem.isActive then
    print("Error: Invalid particle system provided to registerParticleSystem")
    return false
  end

  shoveProfiler.particles.systems[particleSystem] = true
  return true
end

--- Unregister a particle system from tracking
---@param particleSystem love.ParticleSystem The particle system to unregister
---@return boolean success Whether unregistration was successful
function shoveProfiler.unregisterParticleSystem(particleSystem)
  if not particleSystem then
    print("Error: Invalid particle system provided to unregisterParticleSystem")
    return false
  end

  if shoveProfiler.particles.systems[particleSystem] then
    shoveProfiler.particles.systems[particleSystem] = nil
    return true
  end
  return false
end

return shoveProfiler
