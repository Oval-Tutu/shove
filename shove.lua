-- Internal state variables
local state = {
  -- Settings
  fitMethod = "aspect",
  renderMode = "direct",
  -- Dimensions
  screen_width = 0,
  screen_height = 0,
  viewport_width = 0,
  viewport_height = 0,
  rendered_width = 0,
  rendered_height = 0,
  -- Transform
  scale_x = 0,
  scale_y = 0,
  offset_x = 0,
  offset_y = 0,
  -- Layer-based rendering system
  layers = {
    byName = {},    -- Layers indexed by name for quick lookup
    ordered = {},   -- Ordered array for rendering sequence
    active = nil,   -- Currently active layer for drawing
    composite = nil -- Final composite layer for output
  }
}

local function calculateTransforms()
  -- Calculate initial scale factors (used by most modes)
  state.scale_x = state.screen_width / state.viewport_width
  state.scale_y = state.screen_height / state.viewport_height

  if state.fitMethod == "aspect" or state.fitMethod == "pixel" then
    local scaleVal = math.min(state.scale_x, state.scale_y)
    -- Apply pixel-perfect integer scaling if needed
    if state.fitMethod == "pixel" then
      -- floor to nearest integer and fallback to scale 1
      scaleVal = math.max(math.floor(scaleVal), 1)
    end
    -- Calculate centering offset
    state.offset_x = math.floor((state.scale_x - scaleVal) * (state.viewport_width / 2))
    state.offset_y = math.floor((state.scale_y - scaleVal) * (state.viewport_height / 2))
    -- Apply same scale to width and height
    state.scale_x, state.scale_y = scaleVal, scaleVal
  elseif state.fitMethod == "stretch" then
    -- Stretch scaling: no offset
    state.offset_x, state.offset_y = 0, 0
  else
    -- No scaling
    state.scale_x, state.scale_y = 1, 1
    -- Center in the screen
    state.offset_x = math.floor((state.screen_width - state.viewport_width) / 2)
    state.offset_y = math.floor((state.screen_height - state.viewport_height) / 2)
  end
  -- Calculate final draw dimensions
  state.rendered_width = state.screen_width - state.offset_x * 2
  state.rendered_height = state.screen_height - state.offset_y * 2
  -- Set appropriate filter based on scaling mode
  love.graphics.setDefaultFilter(state.fitMethod == "pixel" and "nearest" or "linear")

  -- Recreate canvases for all layers when dimensions change
  if state.renderMode == "layer" then
    for _, layer in pairs(state.layers.byName) do
      layer.canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height)
    end

    if state.layers.composite then
      state.layers.composite.canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height)
    end
  end
end

-- Layer management functions
local function createLayer(name, options)
  options = options or {}

  if state.layers.byName[name] then
    -- Layer already exists
    return state.layers.byName[name]
  end

  local layer = {
    name = name,
    zIndex = options.zIndex or (#state.layers.ordered + 1),
    canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height),
    visible = options.visible ~= false, -- Default to visible
    stencil = options.stencil or false,
    effects = options.effects or {},
    blendMode = options.blendMode or "alpha",
    maskLayer = nil
  }

  state.layers.byName[name] = layer
  table.insert(state.layers.ordered, layer)

  -- Sort by zIndex
  table.sort(state.layers.ordered, function(a, b)
    return a.zIndex < b.zIndex
  end)

  return layer
end

local function getLayer(name)
  return state.layers.byName[name]
end

local function setActiveLayer(name)
  local layer = getLayer(name)
  if not layer then
    return false
  end

  state.layers.active = layer
  -- Don't set canvas active here - only do it during drawing
  return true
end

local function createCompositeLayer()
  local composite = {
    name = "_composite",
    zIndex = 9999, -- Always rendered last
    canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height),
    visible = true,
    effects = {}
  }

  state.layers.composite = composite
  return composite
end

local function applyEffects(canvas, effects)
  if not effects or #effects == 0 then
    love.graphics.draw(canvas)
    return
  end

  local shader = love.graphics.getShader()

  if #effects == 1 then
    love.graphics.setShader(effects[1])
    love.graphics.draw(canvas)
  else
    local _canvas = love.graphics.getCanvas()

    -- Create temp canvas if needed
    local tmpLayer = state.layers.byName["_tmp"]
    if not tmpLayer then
      tmpLayer = createLayer("_tmp", { visible = false })
    end
    local tmpCanvas = tmpLayer.canvas

    local outputCanvas
    local inputCanvas

    love.graphics.push()
    love.graphics.origin()
    for i = 1, #effects do
      inputCanvas = i % 2 == 1 and canvas or tmpCanvas
      outputCanvas = i % 2 == 0 and canvas or tmpCanvas
      love.graphics.setCanvas(outputCanvas)
      love.graphics.clear()
      love.graphics.setShader(effects[i])
      love.graphics.draw(inputCanvas)
      love.graphics.setCanvas(inputCanvas)
    end
    love.graphics.pop()
    love.graphics.setCanvas(_canvas)
    love.graphics.draw(outputCanvas)
  end

  love.graphics.setShader(shader)
end

-- Enhanced layer rendering functions
local function beginLayerDraw(name)
  if state.renderMode ~= "layer" then
    return false
  end

  local layer = getLayer(name)
  if not layer then
    -- Create layer if it doesn't exist
    layer = createLayer(name)
  end

  -- Set as current layer and activate canvas
  state.layers.active = layer
  love.graphics.setCanvas({ layer.canvas, stencil = layer.stencil })

  return true
end

local function endLayerDraw()
  -- Simply mark that we're done with this layer
  if state.renderMode == "layer" and state.inDrawMode then
    -- Reset canvas temporarily
    love.graphics.setCanvas()
    return true
  end
  return false
end

local function compositeLayersToScreen(globalEffects)
  if state.renderMode ~= "layer" then
    return false
  end

  -- Ensure we have a composite layer
  if not state.layers.composite then
    createCompositeLayer()
  end

  -- Prepare composite
  love.graphics.setCanvas(state.layers.composite.canvas)
  love.graphics.clear()

  -- Draw all visible layers in order
  for _, layer in ipairs(state.layers.ordered) do
    if layer.visible and layer.name ~= "_composite" and layer.name ~= "_tmp" then
      -- Apply mask if needed
      if layer.maskLayer then
        local maskLayer = getLayer(layer.maskLayer)
        if maskLayer then
          love.graphics.stencil(function()
            love.graphics.draw(maskLayer.canvas)
          end, "replace", 1)
          love.graphics.setStencilTest("greater", 0)
        end
      end

      -- Apply layer effects or draw directly
      if #layer.effects > 0 then
        applyEffects(layer.canvas, layer.effects)
      else
        love.graphics.draw(layer.canvas)
      end

      -- Reset stencil if used
      if layer.maskLayer then
        love.graphics.setStencilTest()
      end
    end
  end

  -- Reset canvas for screen drawing
  love.graphics.setCanvas()

  -- Draw composite to screen with scaling
  love.graphics.translate(state.offset_x, state.offset_y)
  love.graphics.push()
    love.graphics.scale(state.scale_x, state.scale_y)
    local effects = globalEffects or state.layers.composite.effects
    if effects and #effects > 0 then
      applyEffects(state.layers.composite.canvas, effects)
    else
      love.graphics.draw(state.layers.composite.canvas)
    end
  love.graphics.pop()
  love.graphics.translate(-state.offset_x, -state.offset_y)

  return true
end

-- Enhanced effect management functions
local function addEffect(layer, effect)
  if layer and effect then
    table.insert(layer.effects, effect)
    return true
  end
  return false
end

local function removeEffect(layer, effect)
  if not layer or not effect then return false end

  for i, e in ipairs(layer.effects) do
    if e == effect then
      table.remove(layer.effects, i)
      return true
    end
  end

  return false
end

local function clearEffects(layer)
  if layer then
    layer.effects = {}
    return true
  end
  return false
end

-- Public API
return {
  initResolution = function(width, height, settingsTable)
    -- Clear previous state
    state.layers.byName = {}
    state.layers.ordered = {}
    state.layers.active = nil
    state.layers.composite = nil

    state.viewport_width = width
    state.viewport_height = height
    state.screen_width, state.screen_height = love.graphics.getDimensions()

    if settingsTable then
      state.fitMethod = settingsTable.fitMethod or "aspect"
      state.renderMode = settingsTable.renderMode or "direct"
    else
      state.fitMethod = "aspect"
      state.renderMode = "direct"
    end

    calculateTransforms()

    -- Initialize layer system for buffer mode
    if state.renderMode == "layer" then
      createLayer("default")
      createCompositeLayer()

      -- Don't activate layer right away, just mark it as active
      state.layers.active = state.layers.byName["default"]
    end
  end,

  beginDraw = function()
    -- Set flag to indicate we're in drawing mode
    state.inDrawMode = true

    if state.renderMode == "layer" then
      love.graphics.push()

      -- If no active layer, set the default one
      if not state.layers.active and state.layers.byName["default"] then
        state.layers.active = state.layers.byName["default"]
      end

      -- Set canvas of the active layer now that we're drawing
      if state.layers.active then
        love.graphics.setCanvas({ state.layers.active.canvas, stencil = state.layers.active.stencil })
      end

      love.graphics.clear()
    else
      love.graphics.translate(state.offset_x, state.offset_y)
      love.graphics.setScissor(state.offset_x, state.offset_y,
                              state.viewport_width * state.scale_x,
                              state.viewport_height * state.scale_y)
      love.graphics.push()
      love.graphics.scale(state.scale_x, state.scale_y)
    end
  end,

  endDraw = function(globalEffects)
    if state.renderMode == "layer" then
      -- Ensure active layer is finished
      if state.layers.active then
        endLayerDraw()
      end

      -- Composite and draw layers to screen
      compositeLayersToScreen(globalEffects)
      love.graphics.pop()

      -- Clear all layer canvases
      for name, layer in pairs(state.layers.byName) do
        if name ~= "_composite" and name ~= "_tmp" then
          love.graphics.setCanvas(layer.canvas)
          love.graphics.clear()
        end
      end

      -- Make absolutely sure we reset canvas and shader
      love.graphics.setCanvas()
      love.graphics.setShader()
      love.graphics.setStencilTest()
    else
      love.graphics.pop()
      love.graphics.setScissor()
      love.graphics.translate(-state.offset_x, -state.offset_y)
    end

    -- Reset drawing mode flag
    state.inDrawMode = false
  end,

  -- Layer management API
  createLayer = function(name, options)
    return createLayer(name, options)
  end,

  removeLayer = function(name)
    if name == "_composite" or not state.layers.byName[name] then
      return false
    end

    -- Reset active layer if needed
    if state.layers.active == state.layers.byName[name] then
      state.layers.active = nil
    end

    -- Remove from collections
    for i, layer in ipairs(state.layers.ordered) do
      if layer.name == name then
        table.remove(state.layers.ordered, i)
        break
      end
    end

    state.layers.byName[name] = nil
    return true
  end,

  layerExists = function(name)
    return state.layers.byName[name] ~= nil
  end,

  setLayerOrder = function(name, zIndex)
    local layer = getLayer(name)
    if not layer or name == "_composite" then
      return false
    end

    layer.zIndex = zIndex

    -- Re-sort layers
    table.sort(state.layers.ordered, function(a, b)
      return a.zIndex < b.zIndex
    end)

    return true
  end,

  setLayerVisible = function(name, isVisible)
    local layer = getLayer(name)
    if not layer then
      return false
    end

    layer.visible = isVisible
    return true
  end,

  setLayerMask = function(name, maskName)
    local layer = getLayer(name)
    if not layer then
      return false
    end

    if maskName then
      local maskLayer = getLayer(maskName)
      if not maskLayer then
        return false
      end
      layer.maskLayer = maskName
    else
      layer.maskLayer = nil
    end

    return true
  end,

  beginLayer = function(name)
    return beginLayerDraw(name)
  end,

  endLayer = function()
    return endLayerDraw()
  end,

  compositeAndDraw = function(globalEffects)
    -- This allows manually compositing layers at any point
    return compositeLayersToScreen(globalEffects)
  end,

  -- Drawing helper functions
  drawToLayer = function(name, drawFunc)
    if state.renderMode ~= "layer" or not state.inDrawMode then
      return false
    end

    -- Save current layer
    local previousLayer = state.layers.active

    -- Switch to specified layer
    beginLayerDraw(name)

    -- Execute drawing function
    drawFunc()

    -- Return to previous layer
    if previousLayer then
      beginLayerDraw(previousLayer.name)
    else
      endLayerDraw()
    end

    return true
  end,

  -- Effect management API
  addEffect = function(layerName, effect)
    local layer = getLayer(layerName)
    if not layer then return false end
    return addEffect(layer, effect)
  end,

  removeEffect = function(layerName, effect)
    local layer = getLayer(layerName)
    if not layer then return false end
    return removeEffect(layer, effect)
  end,

  clearEffects = function(layerName)
    local layer = getLayer(layerName)
    if not layer then return false end
    return clearEffects(layer)
  end,

  -- Global effects management
  addGlobalEffect = function(effect)
    if not state.layers.composite then
      createCompositeLayer()
    end
    return addEffect(state.layers.composite, effect)
  end,

  removeGlobalEffect = function(effect)
    if not state.layers.composite then return false end
    return removeEffect(state.layers.composite, effect)
  end,

  clearGlobalEffects = function()
    if not state.layers.composite then return false end
    return clearEffects(state.layers.composite)
  end,

  -- Convert coordinates from screen to game viewport coordinates
  toViewport = function(x, y)
    x, y = x - state.offset_x, y - state.offset_y
    local normalX, normalY = x / state.rendered_width, y / state.rendered_height
    -- Calculate viewport positions even if outside viewport
    local viewportX = math.floor(normalX * state.viewport_width)
    local viewportY = math.floor(normalY * state.viewport_height)
    -- Determine if coordinates are inside the viewport
    local isInside = x >= 0 and x <= state.viewport_width * state.scale_x and
                     y >= 0 and y <= state.viewport_height * state.scale_y
    return isInside, viewportX, viewportY
  end,

  -- Convert coordinates from game viewport to screen coordinates
  toScreen = function(x, y)
    local screenX = state.offset_x + (state.rendered_width * x) / state.viewport_width
    local screenY = state.offset_y + (state.rendered_height * y) / state.viewport_height
    return screenX, screenY
  end,

  -- Convert mouse screen coordinates to game viewport coordinates
  mouseToViewport = function()
    local mouseX, mouseY = love.mouse.getPosition()
    return shove.toViewport(mouseX, mouseY)
  end,

  resize = function(width, height)
    state.screen_width = width
    state.screen_height = height
    calculateTransforms()
  end,

  getViewportWidth = function()
    return state.viewport_width
  end,

  getViewportHeight = function()
    return state.viewport_height
  end,

  getViewportDimensions = function()
    return state.viewport_width, state.viewport_height
  end,

  -- Returns the game viewport rectangle in screen coordinates
  getViewport = function()
    local x = state.offset_x
    local y = state.offset_y
    local width = state.viewport_width * state.scale_x
    local height = state.viewport_height * state.scale_y
    return x, y, width, height
  end,

  -- Check if screen coordinates are within the game viewport
  inViewport = function(x, y)
    -- If stretch scaling is in use, coords are always in the viewport
    if state.fitMethod == "stretch" then
      return true
    end

    local viewX, viewY, viewWidth, viewHeight = state.offset_x, state.offset_y,
                                               state.viewport_width * state.scale_x,
                                               state.viewport_height * state.scale_y

    return x >= viewX and x < viewX + viewWidth and
           y >= viewY and y < viewY + viewHeight
  end,
}
