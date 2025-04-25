---@class ShoveProfiler
---@field shove table|nil Reference to the main Shöve instance
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
    overlayMode = "none", -- Can be "none", "fps", or "full"
    isVsyncEnabled = love.window.getVSync(),
    lastCollectionTime = 0,
    lastEventPushTime = 0,
    currentSizePreset = "default",
    overlayCanvas = nil,
    overlayNeedsUpdate = true,
    lastOverlayContentHash = "",
  },
  -- Metrics data containers
  metrics = {
    -- Add this new structure for FPS tracking
    fpsHistory = {
      values = {},       -- Array of recent FPS values
      maxSamples = 100,  -- Store 100 samples
      currentIndex = 1,  -- Current position in the circular buffer
      sum = 0,           -- Running sum of stored values
      count = 0,         -- Number of samples collected (up to maxSamples)
      avgFps = 0         -- The calculated average FPS
    }
  },
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

--- Check if content has changed
--- @param content string Content to hash
--- @return boolean changed True if content has changed
local function hasContentChanged(content)
  -- Check if content has changed
  local changed = content ~= shoveProfiler.state.lastOverlayContentHash

  -- Update the stored hash
  if changed then
    shoveProfiler.state.lastOverlayContentHash = content
  end

  return changed
end

--- Prepares overlay canvas if needed
--- @param width number Canvas width
--- @param height number Canvas height
--- @return boolean needsRedraw Whether the canvas needs to be redrawn
local function prepareOverlayCanvas(width, height)
  -- Check if a new canvas is needed
  local needsNewCanvas = not shoveProfiler.state.overlayCanvas or
                         shoveProfiler.state.overlayCanvas:getWidth() ~= width or
                         shoveProfiler.state.overlayCanvas:getHeight() ~= height

  -- Check if content has changed
  local needsRedraw = needsNewCanvas or shoveProfiler.state.overlayNeedsUpdate

  -- Create the canvas if needed
  if needsNewCanvas and needsRedraw then
    shoveProfiler.state.overlayCanvas = love.graphics.newCanvas(width, height)
  end

  return needsRedraw
end

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
  if shoveProfiler.state.overlayMode ~= "full" then return end

  shoveProfiler.state.overlayNeedsUpdate = true

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
    -- Minimal FPS calculation
    local fpsHistory = shoveProfiler.metrics.fpsHistory
    local currentFps = shoveProfiler.metrics.fps or 0
    local oldValue = fpsHistory.values[fpsHistory.currentIndex] or 0

    -- Update the running sum by adding new value and removing old one
    fpsHistory.sum = fpsHistory.sum + currentFps - oldValue
    fpsHistory.values[fpsHistory.currentIndex] = currentFps

    -- Update count and index
    if fpsHistory.count < fpsHistory.maxSamples then
      fpsHistory.count = fpsHistory.count + 1
    end
    fpsHistory.currentIndex = fpsHistory.currentIndex % fpsHistory.maxSamples + 1

    -- Calculate average
    if fpsHistory.count > 0 then
      fpsHistory.avgFps = fpsHistory.sum / fpsHistory.count
    end

    -- All the other metrics are collected in the render function
    if shoveProfiler.state.overlayMode == "full" then
      shoveProfiler.metrics.memory = collectgarbage("count")

      -- Use existing stats - only fetch them if they haven't already been captured
      if not shoveProfiler.metrics.stats then
        shoveProfiler.metrics.stats = love.graphics.getStats()
      end

      -- Safely get Shöve state
      if shoveProfiler.shove and type(shoveProfiler.shove.getState) == "function" then
        shoveProfiler.metrics.state = shoveProfiler.shove.getState()
      else
        shoveProfiler.metrics.state = {}
      end

      -- Safely access stats properties
      local stats = shoveProfiler.metrics.stats or {}
      local textureMemoryMB = string.format("%.1f MB", (stats.texturememory or 0) / (1024 * 1024))
      local memoryMB = string.format("%.1f MB", shoveProfiler.metrics.memory / 1024)
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
        string.format("FPS: %.0f (%.1f ms)", shoveProfiler.metrics.fps or 0, frameTime),
        string.format("FPS: %.0f (average)", shoveProfiler.metrics.fpsHistory.avgFps or 0),
        string.format("VSync: %s", shoveProfiler.state.isVsyncEnabled and "On" or "OFF"),
        string.format("Draw Calls: %d (%d batched)", stats.drawcalls or 0, stats.drawcallsbatched or 0),
        string.format("Canvases: %d (%d switches)", stats.canvases or 0, stats.canvasswitches or 0),
        string.format("Shader Switches: %d", stats.shaderswitches or 0),
        string.format("Particles: %d", totalParticles),
        string.format("Images: %d", stats.images or 0),
        string.format("Fonts: %d", fontCount),
        string.format("VRAM: %s", textureMemoryMB),
        string.format("RAM: %s", memoryMB),
        ""
      }

      -- Safely build Shöve info
      local state = shoveProfiler.metrics.state or {}

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
          string.format("Layers: %d (%d active)", layerCount, canvasCount - maskCount),
          string.format("Effects Applied: %d", specialUsage.effectsApplied or 0),
          string.format("Composites: %d", specialUsage.compositeSwitches or 0)
        }
      end

      local contentHash = shoveProfiler.metrics.fps ..
        shoveProfiler.metrics.fpsHistory.avgFps ..
        stats.drawcalls ..
        stats.drawcallsbatched ..
        stats.canvases ..
        stats.canvasswitches ..
        stats.shaderswitches ..
        totalParticles ..
        stats.images ..
        fontCount ..
        textureMemoryMB ..
        memoryMB ..
        tostring(#cachedShoveInfo) ..
        tostring(#cachedLayerInfo)
      shoveProfiler.state.overlayNeedsUpdate = hasContentChanged(contentHash)
    elseif shoveProfiler.state.overlayMode == "fps" then
      shoveProfiler.state.overlayNeedsUpdate = hasContentChanged(shoveProfiler.metrics.fps .. shoveProfiler.metrics.fpsHistory.avgFps)
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
  -- Skip rendering if overlay isn't visible
  if shoveProfiler.state.overlayMode == "none" then
    return
  end

  -- Update metrics at appropriate intervals
  local currentTime = love.timer.getTime()
  local pushInterval = shoveProfiler.config.collectionInterval * 2
  if currentTime - shoveProfiler.state.lastEventPushTime >= pushInterval then
    love.event.push("shove_collect_metrics")
    shoveProfiler.state.lastEventPushTime = currentTime
  end

  -- For minimal FPS overlay, we can directly render it (simple enough)
  if shoveProfiler.state.overlayMode == "fps" then
    -- Render the FPS counter
    local fpsText = string.format("FPS: %.0f (Avg. %.0f)", shoveProfiler.metrics.fps or 0, shoveProfiler.metrics.fpsHistory.avgFps or 0)
    local largeFont = shoveProfiler.config.fonts["large"]
    local textWidth = largeFont:getWidth(fpsText)
    local textHeight = largeFont:getHeight()
    local padding = shoveProfiler.config.sizes["large"].padding
    local canvasWidth = textWidth + (padding * 2)
    local canvasHeight = textHeight + (padding * 2)
    local x = love.graphics.getWidth() - canvasWidth - padding
    local y = padding

    -- Prepare the canvas for FPS overlay
    local needsRedraw = prepareOverlayCanvas(canvasWidth, canvasHeight)

    -- Handle the canvas creation/update as needed
    if needsRedraw then
      -- Render to canvas
      love.graphics.push("all")
      love.graphics.setCanvas(shoveProfiler.state.overlayCanvas)
      love.graphics.clear(0, 0, 0, 0.75)

      -- Save canvas origin for proper rendering
      love.graphics.origin()

      -- Draw border
      love.graphics.setColor(shoveProfiler.config.colors.midGray)
      love.graphics.rectangle("line", 0, 0, canvasWidth, canvasHeight)

      -- Render the FPS counter
      love.graphics.setFont(largeFont)
      love.graphics.setColor(shoveProfiler.config.colors.orange)
      love.graphics.print(fpsText, padding, padding)

      -- Restore rendering state
      love.graphics.pop()

      -- Mark canvas as updated
      shoveProfiler.state.overlayNeedsUpdate = false
    end

    -- Draw the cached canvas
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(shoveProfiler.state.overlayCanvas, x, y)
  elseif shoveProfiler.state.overlayMode == "full" then
    -- Create canvas if it doesn't exist or if dimensions changed
    local panel = shoveProfiler.config.panel
    local area = shoveProfiler.input.touch.overlayArea

    -- Prepare the canvas for full overlay
    local needsRedraw = prepareOverlayCanvas(panel.width, panel.height)

    -- Handle the canvas creation/update as needed
    if needsRedraw then
      -- Render to canvas
      love.graphics.push("all")
      love.graphics.setCanvas(shoveProfiler.state.overlayCanvas)
      love.graphics.clear(0, 0, 0, 0.75)

      -- Save canvas origin for proper rendering
      love.graphics.origin()

      -- Set font
      love.graphics.setFont(shoveProfiler.config.font)

      -- Draw border
      love.graphics.setColor(shoveProfiler.config.colors.midGray)
      love.graphics.rectangle("line", 0, 0, panel.width, panel.height)

      -- Render content sections to canvas
      local renderX = panel.padding
      local renderY = panel.padding

      renderY = renderInfoSection(cachedHardwareInfo, renderX, renderY, shoveProfiler.config.colors.blue)
      renderY = renderInfoSection(cachedPerformanceInfo, renderX, renderY, shoveProfiler.config.colors.blue)
      renderY = renderInfoSection(cachedShoveInfo, renderX, renderY, shoveProfiler.config.colors.purple)
      renderY = renderLayerInfo(renderX, renderY)

      -- Restore rendering state
      love.graphics.pop()

      -- Mark canvas as updated
      shoveProfiler.state.overlayNeedsUpdate = false
    end

    -- Draw the cached canvas
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(shoveProfiler.state.overlayCanvas, area.x, area.y)

    -- Capture stats at the end of rendering
    -- This ensures we get them before love.graphics.present() resets them
    shoveProfiler.metrics.stats = love.graphics.getStats()
  end
end

--- Toggle the overlay visibility
---@param requestedMode? string mode to toggle ("fps" or "full")
---@return nil
local function toggleOverlay(requestedMode)
  -- add tpye checking
  if requestedMode ~= "fps" and requestedMode ~= "full" and requestedMode ~= "none" then
    print("Error: Invalid overlay mode requested")
    return
  end

  if shoveProfiler.state.overlayMode == requestedMode then
    shoveProfiler.state.overlayMode = "none"
  else
    shoveProfiler.state.overlayMode = requestedMode
    shoveProfiler.state.overlayCanvas = nil
  end

  -- Collect metrics immediately if we're turning on an overlay
  if shoveProfiler.state.overlayMode ~= "none" then
    shoveProfiler.state.lastCollectionTime = 0
    love.event.push("shove_collect_metrics")
  end
end

--- Toggle VSync on/off
---@return nil
local function toggleVSync()
  if shoveProfiler.state.overlayMode == "none" then
    return
  end

  shoveProfiler.state.isVsyncEnabled = not shoveProfiler.state.isVsyncEnabled
  love.window.setVSync(shoveProfiler.state.isVsyncEnabled)
end

--- Checks if a touch position is on the panel border
---@param x number Touch x-coordinate
---@param y number Touch y-coordinate
---@return boolean isOnBorder True if touch is on the panel border
local function isTouchOnPanelBorder(x, y)
  if shoveProfiler.state.overlayMode ~= "full" then return false end
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
     toggleOverlay("full")
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
  -- Toggle FPS overlay with Select + X/Square
  if (button == "back" and joystick:isGamepadDown("x")) or
     (button == "x" and joystick:isGamepadDown("back")) then
      toggleOverlay("fps")
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
    toggleOverlay("full")
  end
  -- Toggle FPS overlay with Ctrl+t or Cmd+t
  if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") or
      love.keyboard.isDown("lgui") or love.keyboard.isDown("rgui")) and
     key == "t" then
    toggleOverlay("fps")
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

  if shoveProfiler.state.overlayMode == "full" and isTouchInsideOverlay(x, y) then
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
        toggleOverlay("fps")
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

    -- Toggle full overlay with double-tap in corner (separate from triple tap)
    if timeSinceLastTap <= shoveProfiler.input.touch.doubleTapThreshold then
      toggleOverlay("full")
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
