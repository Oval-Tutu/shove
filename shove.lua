---@class ShoveState
---@field fitMethod "aspect"|"pixel"|"stretch"|"none" Scaling method
---@field renderMode "direct"|"layer" Rendering approach
---@field scalingFilter "nearest"|"linear" Scaling filter for textures
---@field screen_width number Window width
---@field screen_height number Window height
---@field viewport_width number Internal game width
---@field viewport_height number Internal game height
---@field rendered_width number Actual rendered width after scaling
---@field rendered_height number Actual rendered height after scaling
---@field scale_x number Horizontal scaling factor
---@field scale_y number Vertical scaling factor
---@field offset_x number Horizontal offset for centering
---@field offset_y number Vertical offset for centering
---@field layers ShoveLayerSystem Layer management system
---@field maskShader love.Shader Shader used for layer masking
---@field resizeCallback function Callback function for window resize
---@field inDrawMode boolean Whether we're currently in drawing mode
-- Internal state variables
local state = {
  -- Settings
  fitMethod = "aspect",
  renderMode = "direct",
  scalingFilter = "linear",
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
  },
  -- Shader for masking
  maskShader = nil,
  resizeCallback = nil,
}

---@class ShoveLayerSystem
---@field byName table<string, ShoveLayer> Layers indexed by name
---@field ordered ShoveLayer[] Ordered array for rendering sequence
---@field active ShoveLayer|nil Currently active layer
---@field composite ShoveLayer|nil Composite layer for final output

---@class ShoveLayer
---@field name string Layer name
---@field zIndex number Z-order position (lower numbers draw first)
---@field canvas love.Canvas Canvas for drawing
---@field visible boolean Whether layer is visible
---@field stencil boolean Whether layer supports stencil operations
---@field effects love.Shader[] Array of shader effects to apply
---@field blendMode love.BlendMode Blend mode for the layer
---@field maskLayer string|nil Name of layer to use as mask

--- Creates mask shader for layer masking
local function createMaskShader()
  state.maskShader = love.graphics.newShader[[
    vec4 effect(vec4 color, Image tex, vec2 texCoord, vec2 screenCoord) {
      vec4 pixel = Texel(tex, texCoord);
      // Discard transparent or nearly transparent pixels
      if (pixel.a < 0.01) {
        discard;
      }
      return vec4(1.0);
    }
  ]]
end

--- Ensures a layer has a valid canvas
---@param layer ShoveLayer Layer to check
---@return love.Canvas canvas The layer's canvas
local function ensureLayerCanvas(layer)
  if not layer.canvas then
    layer.canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height)
  end
  return layer.canvas
end

--- Calculate transformation values based on current settings
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
  -- Set appropriate filter based on scaling configuration
  love.graphics.setDefaultFilter(state.scalingFilter)

  -- Recreate canvases only for layers that already have one when dimensions change
  if state.renderMode == "layer" then
    for _, layer in pairs(state.layers.byName) do
      if layer.canvas then
        layer.canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height)
      end
    end

    if state.layers.composite and state.layers.composite.canvas then
      state.layers.composite.canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height)
    end
  end
end

---@class ShoveLayerOptions
---@field zIndex? number Z-order index (optional)
---@field visible? boolean Whether layer is visible (default: true)
---@field stencil? boolean Whether layer supports stencil operations (default: false)
---@field effects? love.Shader[] Effects to apply to the layer (optional)
---@field blendMode? love.BlendMode Blend mode for the layer (default: "alpha")
---@field blendAlphaMode? love.BlendAlphaMode Alpha blend mode (default: "alphamultiply")

--- Create a new layer or return existing one
---@param layerName string Layer name
---@param options? ShoveLayerOptions Layer configuration options
---@return ShoveLayer layer The created or existing layer
local function createLayer(layerName, options)
  options = options or {}

  if state.layers.byName[layerName] then
    -- Layer already exists
    return state.layers.byName[layerName]
  end

  local layer = {
    name = layerName,
    zIndex = options.zIndex or (#state.layers.ordered + 1),
    -- Create canvas immediately for explicitly created layers
    canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height),
    visible = options.visible ~= false, -- Default to visible
    stencil = options.stencil or false,
    effects = options.effects or {},
    blendMode = options.blendMode or "alpha",
    blendAlphaMode = options.blendAlphaMode or "alphamultiply",
    maskLayer = nil
  }

  state.layers.byName[layerName] = layer
  table.insert(state.layers.ordered, layer)

  -- Sort by zIndex
  table.sort(state.layers.ordered, function(a, b)
    return a.zIndex < b.zIndex
  end)

  return layer
end

--- Get a layer by name
---@param layerName string Layer name
---@return ShoveLayer|nil layer The requested layer or nil if not found
local function getLayer(layerName)
  return state.layers.byName[layerName]
end

--- Set the currently active layer
---@param layerName string Layer name
---@return boolean success Whether the layer was found and set active
local function setActiveLayer(layerName)
  local layer = getLayer(layerName)
  if not layer then
    return false
  end

  state.layers.active = layer
  -- Don't set canvas active here - only do it during drawing
  return true
end

--- Create the composite layer used for final output
---@return ShoveLayer composite The composite layer
local function createCompositeLayer()
  local composite = {
    name = "_composite",
    zIndex = 9999, -- Always rendered last
    canvas = nil,  -- Deferred canvas creation
    visible = true,
    effects = {}
  }

  state.layers.composite = composite
  return composite
end

--- Apply a set of shader effects to a canvas
---@param canvas love.Canvas Canvas to apply effects to
---@param effects love.Shader[] Array of shader effects
local function applyEffects(canvas, effects)
  if not effects or #effects == 0 then
    -- Already using premultiplied from caller
    love.graphics.draw(canvas)
    return
  end

  local shader = love.graphics.getShader()
  local currentBlendMode, currentAlphaMode = love.graphics.getBlendMode()

  -- Set correct blend mode for canvas drawing
  love.graphics.setBlendMode("alpha", "premultiplied")

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
    -- Ensure the temporary canvas exists
    ensureLayerCanvas(tmpLayer)
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
  love.graphics.setBlendMode(currentBlendMode, currentAlphaMode)
end

--- Begin drawing to a specific layer
---@param layerName string Layer name
---@return boolean success Whether the layer was successfully activated
local function beginLayerDraw(layerName)
  if state.renderMode ~= "layer" then
    return false
  end

  local layer = getLayer(layerName)
  if not layer then
    -- Deferred canvas creation for implicitly created layers
    layer = {
      name = layerName,
      zIndex = #state.layers.ordered + 1,
      canvas = nil,
      visible = true,
      stencil = false,
      effects = {},
      blendMode = "alpha",
      blendAlphaMode = "alphamultiply",
      maskLayer = nil
    }

    state.layers.byName[layerName] = layer
    table.insert(state.layers.ordered, layer)

    -- Sort by zIndex
    table.sort(state.layers.ordered, function(a, b)
      return a.zIndex < b.zIndex
    end)
  end

  -- Ensure layer has a canvas before drawing
  ensureLayerCanvas(layer)

  -- Set as current layer and activate canvas
  state.layers.active = layer
  love.graphics.setCanvas({ layer.canvas, stencil = layer.stencil })
  love.graphics.clear() -- Clear the canvas when beginning to draw

  return true
end

--- End drawing to the current layer
---@return boolean success Whether the layer was successfully deactivated
local function endLayerDraw()
  -- Simply mark that we're done with this layer
  if state.renderMode == "layer" and state.inDrawMode then
    -- Reset canvas temporarily
    love.graphics.setCanvas()
    return true
  end
  return false
end

--- Composite all layers to screen
---@param globalEffects love.Shader[]|nil Optional effects to apply globally
---@param applyPersistentEffects boolean Whether to apply persistent global effects
---@return boolean success Whether compositing was performed
local function compositeLayersOnScreen(globalEffects, applyPersistentEffects)
  if globalEffects ~= nil and type(globalEffects) ~= "table" then
    error("compositeLayersOnScreen: globalEffects must be a table of shaders or nil", 2)
  end

  if type(applyPersistentEffects) ~= "boolean" then
    error("compositeLayersOnScreen: applyPersistentEffects must be a boolean", 2)
  end

  if state.renderMode ~= "layer" then
    return false
  end

  -- Ensure we have a composite layer
  if not state.layers.composite then
    createCompositeLayer()
  end

  -- Ensure composite layer has a canvas
  ensureLayerCanvas(state.layers.composite)

  -- Create mask shader if it doesn't exist
  if not state.maskShader then
    createMaskShader()
  end

  -- Store current blend mode
  local currentBlendMode, currentAlphaMode = love.graphics.getBlendMode()

  -- Prepare composite - add stencil=true to enable stencil operations
  love.graphics.setCanvas({ state.layers.composite.canvas, stencil = true })
  love.graphics.clear()

  -- Draw all visible layers in order
  for _, layer in ipairs(state.layers.ordered) do
    if layer.visible and layer.name ~= "_composite" and layer.name ~= "_tmp" then
      -- Skip layers without canvas (never drawn to)
      if layer.canvas then  -- Only process layers that have a canvas
        -- Apply mask if needed
        if layer.maskLayer then
          local maskLayer = getLayer(layer.maskLayer)
          if maskLayer and maskLayer.canvas then
            -- Clear stencil buffer first
            love.graphics.clear(false, false, true)
            love.graphics.stencil(function()
              -- Use mask shader to properly handle transparent pixels
              love.graphics.setShader(state.maskShader)
              love.graphics.draw(maskLayer.canvas)
              love.graphics.setShader()
            end, "replace", 1)
            -- Only draw where stencil value equals 1
            love.graphics.setStencilTest("equal", 1)
          end
        end

        -- Use premultiplied alpha when drawing canvases
        -- But respect the layer's blend mode
        love.graphics.setBlendMode(layer.blendMode, "premultiplied")

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
  end

  -- Reset canvas for screen drawing
  love.graphics.setCanvas()

  -- Draw composite to screen with scaling
  love.graphics.translate(state.offset_x, state.offset_y)
  love.graphics.push()
    love.graphics.scale(state.scale_x, state.scale_y)
    local effects = {}
    -- Only apply persistent global effects when requested
    if applyPersistentEffects then
      -- Start with persistent effects if available
      if state.layers.composite and #state.layers.composite.effects > 0 then
        for _, effect in ipairs(state.layers.composite.effects) do
          table.insert(effects, effect)
        end
      end
    end
    -- Append any transient effects
    if globalEffects and #globalEffects > 0 then
      for _, effect in ipairs(globalEffects) do
        table.insert(effects, effect)
      end
    end

    -- Use premultiplied alpha when drawing the composite canvas to screen
    love.graphics.setBlendMode("alpha", "premultiplied")

    if effects and #effects > 0 then
      applyEffects(state.layers.composite.canvas, effects)
    else
      love.graphics.draw(state.layers.composite.canvas)
    end
  love.graphics.pop()
  love.graphics.translate(-state.offset_x, -state.offset_y)

  -- Restore original blend mode
  love.graphics.setBlendMode(currentBlendMode, currentAlphaMode)

  return true
end

--- Add an effect to a layer
---@param layer ShoveLayer Layer to add effect to
---@param effect love.Shader Shader effect to add
---@return boolean success Whether the effect was added
local function addEffect(layer, effect)
  if layer and effect then
    table.insert(layer.effects, effect)
    return true
  end
  return false
end

--- Remove an effect from a layer
---@param layer ShoveLayer Layer to remove effect from
---@param effect love.Shader Shader effect to remove
---@return boolean success Whether the effect was removed
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

--- Clear all effects from a layer
---@param layer ShoveLayer Layer to clear effects from
---@return boolean success Whether effects were cleared
local function clearEffects(layer)
  if layer then
    layer.effects = {}
    return true
  end
  return false
end

---@class Shove
local shove = {
  --- Version
  _VERSION = {
    major = 1,
    minor = 0,
    patch = 3,
    string = "1.0.3"
  },
  --- Blend mode constants
  BLEND = {
    ALPHA = "alpha",
    REPLACE = "replace",
    SCREEN = "screen",
    ADD = "add",
    SUBTRACT = "subtract",
    MULTIPLY = "multiply",
    LIGHTEN = "lighten",
    DARKEN = "darken"
  },
  --- Alpha blend mode constants
  ALPHA = {
    MULTIPLY = "alphamultiply",
    PREMULTIPLIED = "premultiplied"
  },
  ---@class ShoveInitOptions
  ---@field fitMethod? "aspect"|"pixel"|"stretch"|"none" Scaling method
  ---@field renderMode? "direct"|"layer" Rendering approach
  ---@field scalingFilter? "nearest"|"linear" Scaling filter for textures

  --- Initialize the resolution system
  ---@param width number Viewport width
  ---@param height number Viewport height
  ---@param settingsTable? ShoveInitOptions Configuration options
  setResolution = function(width, height, settingsTable)
    if type(width) ~= "number" or width <= 0 then
      error("shove.setResolution: width must be a positive number", 2)
    end

    if type(height) ~= "number" or height <= 0 then
      error("shove.setResolution: height must be a positive number", 2)
    end

    if settingsTable ~= nil and type(settingsTable) ~= "table" then
      error("shove.setResolution: settingsTable must be a table or nil", 2)
    end

    -- Validate settings if provided
    if type(settingsTable) == "table" then
      -- Validate fitMethod
      if settingsTable.fitMethod ~= nil and
         settingsTable.fitMethod ~= "aspect" and
         settingsTable.fitMethod ~= "pixel" and
         settingsTable.fitMethod ~= "stretch" and
         settingsTable.fitMethod ~= "none" then
        error("shove.setResolution: fitMethod must be 'aspect', 'pixel', 'stretch', or 'none'", 2)
      end

      -- Validate renderMode
      if settingsTable.renderMode ~= nil and
         settingsTable.renderMode ~= "direct" and
         settingsTable.renderMode ~= "layer" then
        error("shove.setResolution: renderMode must be 'direct' or 'layer'", 2)
      end

      -- Validate scalingFilter
      if settingsTable.scalingFilter ~= nil and
         settingsTable.scalingFilter ~= "nearest" and
         settingsTable.scalingFilter ~= "linear" and
         settingsTable.scalingFilter ~= "none" then
        error("shove.setResolution: scalingFilter must be 'nearest', 'linear', or 'none'", 2)
      end
    end

    -- Clear previous state
    state.layers.byName = {}
    state.layers.ordered = {}
    state.layers.active = nil
    state.layers.composite = nil
    state.maskShader = nil

    state.viewport_width = width
    state.viewport_height = height
    state.screen_width, state.screen_height = love.graphics.getDimensions()

    if settingsTable then
      state.fitMethod = settingsTable.fitMethod or "aspect"
      state.renderMode = settingsTable.renderMode or "direct"
      if settingsTable.scalingFilter then
        state.scalingFilter = settingsTable.scalingFilter
      else
        state.scalingFilter = state.fitMethod == "pixel" and "nearest" or "linear"
      end
    else
      state.fitMethod = "aspect"
      state.renderMode = "direct"
      state.scalingFilter = "linear"
    end

    calculateTransforms()

    -- Initialize mask shader
    createMaskShader()

    -- Initialize layer system for buffer mode
    if state.renderMode == "layer" then
      -- Create default layer manually without canvas (deferred creation)
      -- This ensures no canvas is allocated unless actually drawn to
      state.layers.byName["default"] = {
        name = "default",
        zIndex = 1,
        canvas = nil, -- Deferred canvas creation
        visible = true,
        stencil = false,
        effects = {},
        blendMode = "alpha",
        blendAlphaMode = "alphamultiply",
        maskLayer = nil
      }
      table.insert(state.layers.ordered, state.layers.byName["default"])

      createCompositeLayer()

      -- Mark default as active (but don't create a canvas yet)
      state.layers.active = state.layers.byName["default"]
    end
  end,

--- Set the window mode with automatic resize handling
---@param width number Window width
---@param height number Window height
---@param flags table|nil Window flags (resizable, fullscreen, etc.)
---@return boolean success Whether the mode was set successfully
---@return string|nil error Error message if unsuccessful
  setWindowMode = function(width, height, flags)
    if type(width) ~= "number" or width <= 0 then
      error("shove.setWindowMode: width must be a positive number", 2)
    end

    if type(height) ~= "number" or height <= 0 then
      error("shove.setWindowMode: height must be a positive number", 2)
    end

    if flags ~= nil and type(flags) ~= "table" then
      error("shove.setWindowMode: flags must be a table or nil", 2)
    end

    local success, message = love.window.setMode(width, height, flags)

    if success then
      -- Only call resize if we're already initialized
      if state.viewport_width > 0 and state.viewport_height > 0 then
        local actualWidth, actualHeight = love.graphics.getDimensions()
        shove.resize(actualWidth, actualHeight)
      end
    end

    return success, message
  end,

--- Update the window mode with automatic resize handling
---@param width number Window width
---@param height number Window height
---@param flags table|nil Window flags (resizable, fullscreen, etc.)
---@return boolean success Whether the mode was updated successfully
---@return string|nil error Error message if unsuccessful
  updateWindowMode = function(width, height, flags)
    if type(width) ~= "number" or width <= 0 then
      error("shove.updateWindowMode: width must be a positive number", 2)
    end

    if type(height) ~= "number" or height <= 0 then
      error("shove.updateWindowMode: height must be a positive number", 2)
    end

    if flags ~= nil and type(flags) ~= "table" then
      error("shove.updateWindowMode: flags must be a table or nil", 2)
    end

    local success, message = love.window.updateWindowMode(width, height, flags)

    if success then
      -- Get the actual dimensions (might differ from requested)
      local actualWidth, actualHeight = love.graphics.getDimensions()
      shove.resize(actualWidth, actualHeight)
    end

    return success, message
  end,

  --- Begin drawing operations
  beginDraw = function()
    -- Check if we're already in drawing mode
    if state.inDrawMode then
      error("shove.beginDraw: Already in drawing mode. Call endDraw() before calling beginDraw() again.", 2)
      return false
    end

    -- Set flag to indicate we're in drawing mode
    state.inDrawMode = true

    if state.renderMode == "layer" then
      love.graphics.push()

      -- If no active layer, set the default one
      if not state.layers.active and state.layers.byName["default"] then
        state.layers.active = state.layers.byName["default"]
      end

      -- If the default layer has a canvas (which would happen if global effects were added),
      -- activate it so drawing commands go to it
      if state.layers.active and state.layers.active.name == "default" and
         state.layers.active.canvas then
        love.graphics.setCanvas({ state.layers.active.canvas, stencil = state.layers.active.stencil })
        love.graphics.clear()
      end
      -- Otherwise, wait until beginLayer is explicitly called

    else
      love.graphics.translate(state.offset_x, state.offset_y)
      love.graphics.setScissor(state.offset_x, state.offset_y,
                              state.viewport_width * state.scale_x,
                              state.viewport_height * state.scale_y)
      love.graphics.push()
      love.graphics.scale(state.scale_x, state.scale_y)
    end

    return true
  end,

  --- End drawing operations and display result
  ---@param globalEffects love.Shader[]|nil Optional effects to apply globally
  ---@return boolean success Whether drawing was ended successfully
  endDraw = function(globalEffects)
    -- Check if we're in drawing mode
    if not state.inDrawMode then
      error("shove.endDraw: Not in drawing mode. Call beginDraw() before calling endDraw().", 2)
      return false
    end

    -- Validate globalEffects parameter if provided
    if globalEffects ~= nil and type(globalEffects) ~= "table" then
      error("shove.endDraw: globalEffects must be a table of shaders or nil", 2)
      return false
    end

    if state.renderMode == "layer" then
      -- Ensure active layer is finished
      if state.layers.active then
        endLayerDraw()
      end

      -- If there are global effects but no layer has been drawn to,
      -- ensure we have at least the default layer with a canvas
      local hasGlobalEffects = (globalEffects and #globalEffects > 0) or
                               (state.layers.composite and #state.layers.composite.effects > 0)

      if hasGlobalEffects then
        local anyLayerHasCanvas = false
        -- Check if any visible layer has a canvas
        for _, layer in ipairs(state.layers.ordered) do
          if layer.visible and layer.name ~= "_composite" and layer.name ~= "_tmp" and layer.canvas then
            anyLayerHasCanvas = true
            break
          end
        end

        -- If no canvas exists but we have effects, create one for default layer
        if not anyLayerHasCanvas and state.layers.byName["default"] then
          ensureLayerCanvas(state.layers.byName["default"])
        end
      end

      -- Composite and draw layers to screen (always apply global persistent effects in endDraw)
      compositeLayersOnScreen(globalEffects, true)
      love.graphics.pop()

      -- Clear all layer canvases that exist
      for name, layer in pairs(state.layers.byName) do
        if name ~= "_composite" and name ~= "_tmp" and layer.canvas then
          -- Only try to clear canvases that actually exist
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

    shove.profiler.renderOverlay()

    return true
  end,

  -- Layer management API

  --- Create a new layer
  ---@param layerName string Layer name
  ---@param options? ShoveLayerOptions Layer configuration options
  ---@return ShoveLayer layer The created layer
  createLayer = function(layerName, options)
    if type(layerName) ~= "string" then
      error("shove.createLayer: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.createLayer: layerName cannot be empty", 2)
    end

    -- Check for reserved names
    if layerName == "_composite" or layerName == "_tmp" then
      error("shove.createLayer: '"..layerName.."' is a reserved layer name", 2)
    end

    -- Validate options if provided
    if options ~= nil then
      if type(options) ~= "table" then
        error("shove.createLayer: options must be a table", 2)
      end

      -- Validate specific options if they exist
      if options.zIndex ~= nil and type(options.zIndex) ~= "number" then
        error("shove.createLayer: zIndex must be a number", 2)
      end

      if options.visible ~= nil and type(options.visible) ~= "boolean" then
        error("shove.createLayer: visible must be a boolean", 2)
      end

      if options.stencil ~= nil and type(options.stencil) ~= "boolean" then
        error("shove.createLayer: stencil must be a boolean", 2)
      end

      if options.effects ~= nil and type(options.effects) ~= "table" then
        error("shove.createLayer: effects must be a table of shaders", 2)
      end

      if options.blendMode ~= nil then
        if type(options.blendMode) ~= "string" then
          error("shove.createLayer: blendMode must be a string", 2)
        end

        -- Optional: validate blend mode is one of LÖVE's supported values
        local validBlendModes = {
          alpha = true, replace = true, screen = true, add = true,
          subtract = true, multiply = true, lighten = true, darken = true
        }

        if not validBlendModes[options.blendMode] then
          error("shove.createLayer: '"..options.blendMode.."' is not a valid blend mode", 2)
        end
      end
    end

    return createLayer(layerName, options)
  end,

  --- Remove a layer
  ---@param layerName string Layer name
  ---@return boolean success Whether layer was removed
  removeLayer = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.removeLayer: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.removeLayer: layerName cannot be empty", 2)
    end

    if layerName == "_composite" or not state.layers.byName[layerName] then
      return false
    end

    -- Reset active layer if needed
    if state.layers.active == state.layers.byName[layerName] then
      state.layers.active = nil
    end

    -- Remove from collections
    for i, layer in ipairs(state.layers.ordered) do
      if layer.name == layerName then
        table.remove(state.layers.ordered, i)
        break
      end
    end

    state.layers.byName[layerName] = nil
    return true
  end,

  --- Check if a layer exists
  ---@param layerName string Layer name
  ---@return boolean exists Whether the layer exists
  hasLayer = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.hasLayer: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.hasLayer: layerName cannot be empty", 2)
    end

    return state.layers.byName[layerName] ~= nil
  end,

--- Set the blend mode for a layer
---@param layerName string Layer name
---@param blendMode love.BlendMode Blend mode to use
---@param blendAlphaMode? love.BlendAlphaMode Blend alpha mode (default: "alphamultiply")
---@return boolean success Whether the blend mode was set
  setLayerBlendMode = function(layerName, blendMode, blendAlphaMode)
    if type(layerName) ~= "string" then
      error("shove.setLayerBlendMode: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.setLayerBlendMode: layerName cannot be empty", 2)
    end

    if type(blendMode) ~= "string" then
      error("shove.setLayerBlendMode: blendMode must be a string", 2)
    end

    local validBlendModes = {
      alpha = true, replace = true, screen = true, add = true,
      subtract = true, multiply = true, lighten = true, darken = true
    }

    if not validBlendModes[blendMode] then
      error("shove.setLayerBlendMode: Invalid blend mode", 2)
    end

    if blendAlphaMode ~= nil and blendAlphaMode ~= "alphamultiply" and blendAlphaMode ~= "premultiplied" then
      error("shove.setLayerBlendMode: blendAlphaMode must be 'alphamultiply' or 'premultiplied'", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return false end

    layer.blendMode = blendMode
    layer.blendAlphaMode = blendAlphaMode or "alphamultiply"
    return true
  end,

--- Get the blend mode of a layer
---@param layerName string Layer name
---@return love.BlendMode|nil blendMode Current blend mode
---@return love.BlendAlphaMode|nil blendAlphaMode Current blend alpha mode
  getLayerBlendMode = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.getLayerBlendMode: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.getLayerBlendMode: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return nil, nil end

    return layer.blendMode, layer.blendAlphaMode
  end,

  --- Set the z-index order of a layer
  ---@param layerName string Layer name
  ---@param zIndex number Z-order position
  ---@return boolean success Whether the layer order was changed
  setLayerOrder = function(layerName, zIndex)
    if type(layerName) ~= "string" then
      error("shove.setLayerOrder: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.setLayerOrder: layerName cannot be empty", 2)
    end

    if type(zIndex) ~= "number" then
      error("shove.setLayerOrder: zIndex must be a number", 2)
    end

    local layer = getLayer(layerName)
    if not layer or layerName == "_composite" then
      return false
    end

    layer.zIndex = zIndex

    -- Re-sort layers
    table.sort(state.layers.ordered, function(a, b)
      return a.zIndex < b.zIndex
    end)

    return true
  end,

  --- Get the z-index order of a layer
  ---@param layerName string Layer name
  ---@return number|nil zIndex Z-order position, or nil if layer doesn't exist
  getLayerOrder = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.getLayerOrder: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.getLayerOrder: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return nil end
    return layer.zIndex
  end,

--- Show a layer (make it visible)
---@param layerName string Layer name
---@return boolean success Whether the layer visibility was changed
  showLayer = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.showLayer: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.showLayer: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then
      return false
    end

    layer.visible = true
    return true
  end,

--- Hide a layer (make it invisible)
---@param layerName string Layer name
---@return boolean success Whether the layer visibility was changed
  hideLayer = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.hideLayer: layerName must be a string", 2)
    end

    if name == "" then
      error("shove.hideLayer: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then
      return false
    end

    layer.visible = false
    return true
  end,

  --- Check if a layer is visible
  ---@param layerName string Layer name
  ---@return boolean|nil isVisible Whether the layer is visible, or nil if layer doesn't exist
  isLayerVisible = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.isLayerVisible: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.isLayerVisible: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return nil end
    return layer.visible
  end,

--- Get the mask layer used by a layer
---@param layerName string Layer name
---@return string|nil maskName Name of the mask layer, or nil if no mask or layer doesn't exist
  getLayerMask = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.getLayerMask: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.getLayerMask: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return nil end

    return layer.maskLayer
  end,

  --- Set a mask for a layer
  ---@param layerName string Layer name
  ---@param maskName string|nil Name of layer to use as mask, or nil to clear mask
  ---@return boolean success Whether the mask was set
  setLayerMask = function(layerName, maskName)
    if type(layerName) ~= "string" then
      error("shove.setLayerMask: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.setLayerMask: layerName cannot be empty", 2)
    end

    if maskName ~= nil and type(maskName) ~= "string" then
      error("shove.setLayerMask: maskName must be a string or nil", 2)
    end

    if maskName == "" then
      error("shove.setLayerMask: maskName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then
      return false
    end

    if maskName then
      local maskLayer = getLayer(maskName)
      if not maskLayer then
        return false
      end
      layer.maskLayer = maskName
      layer.stencil = true
    else
      layer.maskLayer = nil
    end

    return true
  end,

  --- Add a function to release canvas memory for unused layers
  ---@param layerName string Layer name
  ---@return boolean success Whether the canvas was released
  releaseLayerCanvas = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.releaseLayerCanvas: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.releaseLayerCanvas: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer or not layer.canvas then
      return false
    end

    layer.canvas:release()
    layer.canvas = nil
    return true
  end,

  --- Check if a layer has a canvas allocated
  ---@param layerName string Layer name
  ---@return boolean hasCanvas Whether the layer has a canvas allocated
  hasLayerCanvas = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.hasLayerCanvas: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.hasLayerCanvas: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    return layer ~= nil and layer.canvas ~= nil
  end,

  --- Begin drawing to a layer
  ---@param layerName string Layer name
  ---@return boolean success Whether the layer was activated
  beginLayer = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.beginLayer: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.beginLayer: layerName cannot be empty", 2)
    end

    return beginLayerDraw(layerName)
  end,

  --- End drawing to current layer
  ---@return boolean success Whether the layer was deactivated
  endLayer = function()
    return endLayerDraw()
  end,

  --- Composite and draw layers
  ---@param globalEffects love.Shader[]|nil Optional effects to apply globally for this draw
  ---@param applyPersistentEffects boolean|nil Whether to apply persistent global effects (default: false)
  ---@return boolean success Whether compositing was performed
  drawComposite = function(globalEffects, applyPersistentEffects)
    if globalEffects ~= nil and type(globalEffects) ~= "table" then
      error("shove.drawComposite: globalEffects must be a table of shaders or nil", 2)
    end

    if applyPersistentEffects ~= nil and type(applyPersistentEffects) ~= "boolean" then
      error("shove.drawComposite: applyPersistentEffects must be a boolean or nil", 2)
    end

    -- This allows manually compositing layers at any point with optional effect control
    return compositeLayersOnScreen(globalEffects, applyPersistentEffects or false)
  end,

  --- Draw to a specific layer using a callback function
  ---@param layerName string Layer name
  ---@param drawFunc function Callback function to execute for drawing
  ---@return boolean success Whether drawing was performed
  drawOnLayer = function(layerName, drawFunc)
    if type(layerName) ~= "string" then
      error("shove.drawOnLayer: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.drawOnLayer: layerName cannot be empty", 2)
    end

    if type(drawFunc) ~= "function" then
      error("shove.drawOnLayer: drawFunc must be a function", 2)
    end

    if state.renderMode ~= "layer" or not state.inDrawMode then
      return false
    end

    -- Save current layer
    local previousLayer = state.layers.active

    -- Switch to specified layer
    beginLayerDraw(layerName)

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

  --- Add an effect to a layer
  ---@param layerName string Layer name
  ---@param effect love.Shader Shader effect to add
  ---@return boolean success Whether the effect was added
  addEffect = function(layerName, effect)
    if type(layerName) ~= "string" then
      error("shove.addEffect: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.addEffect: layerName cannot be empty", 2)
    end

    if type(effect) ~= "userdata" then
      error("shove.addEffect: effect must be a shader object", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return false end
    return addEffect(layer, effect)
  end,

  --- Remove an effect from a layer
  ---@param layerName string Layer name
  ---@param effect love.Shader Shader effect to remove
  ---@return boolean success Whether the effect was removed
  removeEffect = function(layerName, effect)
    if type(layerName) ~= "string" then
      error("shove.removeEffect: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.removeEffect: layerName cannot be empty", 2)
    end

    if type(effect) ~= "userdata" then
      error("shove.removeEffect: effect must be a shader object", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return false end
    return removeEffect(layer, effect)
  end,

  --- Clear all effects from a layer
  ---@param layerName string Layer name
  ---@return boolean success Whether effects were cleared
  clearEffects = function(layerName)
    if type(layerName) ~= "string" then
      error("shove.clearEffects: layerName must be a string", 2)
    end

    if layerName == "" then
      error("shove.clearEffects: layerName cannot be empty", 2)
    end

    local layer = getLayer(layerName)
    if not layer then return false end
    return clearEffects(layer)
  end,

  --- Add a global effect
  ---@param effect love.Shader Shader effect to add globally
  ---@return boolean success Whether the effect was added
  addGlobalEffect = function(effect)
    if type(effect) ~= "userdata" then
      error("shove.addGlobalEffect: effect must be a shader object", 2)
    end

    -- Ensure we have a composite layer
    if not state.layers.composite then
      createCompositeLayer()
    end

    -- If any global effects are added, we need to ensure there's at least one layer with a canvas
    -- This is for cases where games use global effects but don't explicitly use layers
    if state.renderMode == "layer" and state.layers.byName["default"] then
      -- Force canvas creation for default layer if global effects are being used
      -- This ensures we'll have something to apply the effects to
      ensureLayerCanvas(state.layers.byName["default"])
    end

    return addEffect(state.layers.composite, effect)
  end,

  --- Remove a global effect
  ---@param effect love.Shader Shader effect to remove
  ---@return boolean success Whether the effect was removed
  removeGlobalEffect = function(effect)
    if type(effect) ~= "userdata" then
      error("shove.removeGlobalEffect: effect must be a shader object", 2)
    end

    if not state.layers.composite then return false end
    return removeEffect(state.layers.composite, effect)
  end,

  --- Clear all global effects
  ---@return boolean success Whether effects were cleared
  clearGlobalEffects = function()
    if not state.layers.composite then return false end
    return clearEffects(state.layers.composite)
  end,

  --- Convert screen coordinates to viewport coordinates
  ---@param x number Screen X coordinate
  ---@param y number Screen Y coordinate
  ---@return boolean inside Whether coordinates are inside viewport
  ---@return number viewX Viewport X coordinate
  ---@return number viewY Viewport Y coordinate
  screenToViewport = function(x, y)
    if type(x) ~= "number" then
      error("shove.screenToViewport: x must be a number", 2)
    end
    if type(y) ~= "number" then
      error("shove.screenToViewport: y must be a number", 2)
    end

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

  --- Convert viewport coordinates to screen coordinates
  ---@param x number Viewport X coordinate
  ---@param y number Viewport Y coordinate
  ---@return number screenX Screen X coordinate
  ---@return number screenY Screen Y coordinate
  viewportToScreen = function(x, y)
    if type(x) ~= "number" then
      error("shove.viewportToScreen: x must be a number", 2)
    end
    if type(y) ~= "number" then
      error("shove.viewportToScreen: y must be a number", 2)
    end

    local screenX = state.offset_x + (state.rendered_width * x) / state.viewport_width
    local screenY = state.offset_y + (state.rendered_height * y) / state.viewport_height
    return screenX, screenY
  end,

  --- Convert mouse position to viewport coordinates
  ---@return boolean inside Whether mouse is inside viewport
  ---@return number mouseX Viewport X coordinate
  ---@return number mouseY Viewport Y coordinate
  mouseToViewport = function()
    local mouseX, mouseY = love.mouse.getPosition()
    return shove.screenToViewport(mouseX, mouseY)
  end,

  --- Update dimensions when window is resized
  ---@param width number New window width
  ---@param height number New window height
  resize = function(width, height)
    if type(width) ~= "number" or width <= 0 then
      error("shove.resize: width must be a positive number", 2)
    end

    if type(height) ~= "number" or height <= 0 then
      error("shove.resize: height must be a positive number", 2)
    end

    state.screen_width = width
    state.screen_height = height
    calculateTransforms()
    -- Call resize callback if it exists
    if type(state.resizeCallback) == "function" then
      state.resizeCallback(width, height)
    end
  end,

  --- Get viewport width
  ---@return number width Viewport width
  getViewportWidth = function()
    return state.viewport_width
  end,

  --- Get viewport height
  ---@return number height Viewport height
  getViewportHeight = function()
    return state.viewport_height
  end,

  --- Get viewport dimensions
  ---@return number width Viewport width
  ---@return number height Viewport height
  getViewportDimensions = function()
    return state.viewport_width, state.viewport_height
  end,

  --- Get the game viewport rectangle in screen coordinates
  ---@return number x Left position
  ---@return number y Top position
  ---@return number width Width in screen pixels
  ---@return number height Height in screen pixels
  getViewport = function()
    local x = state.offset_x
    local y = state.offset_y
    local width = state.viewport_width * state.scale_x
    local height = state.viewport_height * state.scale_y
    return x, y, width, height
  end,

  --- Check if screen coordinates are within the game viewport
  ---@param x number Screen X coordinate
  ---@param y number Screen Y coordinate
  ---@return boolean inside Whether coordinates are inside viewport
  isInViewport = function(x, y)
    if type(x) ~= "number" then
      error("shove.isInViewport: x must be a number", 2)
    end
    if type(y) ~= "number" then
      error("shove.isInViewport: y must be a number", 2)
    end

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

  --- Get current fit method
  ---@return "aspect"|"pixel"|"stretch"|"none" fitMethod Current fit method
  getFitMethod = function()
    return state.fitMethod
  end,

  --- Set fit method
  ---@param method "aspect"|"pixel"|"stretch"|"none" New fit method
  ---@return boolean success Whether the method was set
  setFitMethod = function(method)
    if type(method) ~= "string" then
      error("shove.setFitMethod: method must be a string", 2)
    end

    local validMethods = {aspect = true, pixel = true, stretch = true, none = true}
    if not validMethods[method] then
      error("shove.setFitMethod: method must be 'aspect', 'pixel', 'stretch', or 'none'", 2)
    end

    state.fitMethod = method
    -- Recalculate transforms with current dimensions
    shove.resize(state.screen_width, state.screen_height)
    return true
  end,

  --- Get current render mode
  ---@return "direct"|"layer" renderMode Current render mode
  getRenderMode = function()
    return state.renderMode
  end,

  --- Set render mode
  ---@param mode "direct"|"layer" New render mode
  ---@return boolean success Whether the mode was set
  setRenderMode = function(mode)
    if type(mode) ~= "string" then
      error("shove.setRenderMode: mode must be a string", 2)
    end

    local validModes = {direct = true, layer = true}
    if not validModes[mode] then
      error("shove.setRenderMode: mode must be 'direct' or 'layer'", 2)
    end

    state.renderMode = mode
    -- Recalculate transforms with current dimensions
    shove.resize(state.screen_width, state.screen_height)
    return true
  end,

  --- Get current scaling filter
  ---@return "nearest"|"linear" scalingFilter Current scaling filter
  getScalingFilter = function()
    return state.scalingFilter
  end,

  --- Set scaling filter
  ---@param filter "nearest"|"linear" New scaling filter
  ---@return boolean success Whether the filter was set
  setScalingFilter = function(filter)
    if type(filter) ~= "string" then
      error("shove.setScalingFilter: filter must be a string", 2)
    end

    local validFilters = {nearest = true, linear = true, none = true}
    if not validFilters[filter] then
      error("shove.setScalingFilter: filter must be 'nearest', 'linear', or 'none'", 2)
    end

    state.scalingFilter = filter
    love.graphics.setDefaultFilter(filter)
    return true
  end,

--- Get the current resize callback function
---@return function|nil callback The current resize callback or nil if none is set
  getResizeCallback = function()
    return state.resizeCallback
  end,

--- Set a callback function to be called after resize operations
---@param callback function|nil Function to call after each resize, or nil to clear
---@return boolean success Whether the callback was set successfully
  setResizeCallback = function(callback)
    if callback ~= nil and type(callback) ~= "function" then
      error("shove.setResizeCallback: callback must be a function or nil", 2)
    end

    state.resizeCallback = callback
    return true
  end,

  --- Return a copy of relevant state data for debug metrics
  getState = function()
    -- Create an ordered array of layers with basic info for profiler
    local orderedLayerInfo = {}
    if state.renderMode == "layer" and #state.layers.ordered > 0 then
      for _, layer in ipairs(state.layers.ordered) do
        table.insert(orderedLayerInfo, {
          name = layer.name,
          zIndex = layer.zIndex,
          visible = layer.visible,
          blendMode = layer.blendMode,
          blendAlphaMode = layer.blendAlphaMode,
          hasCanvas = layer.canvas ~= nil, -- Add canvas existence info
          effects = #layer.effects
        })
      end
    end

    return {
      fitMethod = state.fitMethod,
      renderMode = state.renderMode,
      scalingFilter = state.scalingFilter,
      screen_width = state.screen_width,
      screen_height = state.screen_height,
      viewport_width = state.viewport_width,
      viewport_height = state.viewport_height,
      rendered_width = state.rendered_width,
      rendered_height = state.rendered_height,
      scale_x = state.scale_x,
      scale_y = state.scale_y,
      offset_x = state.offset_x,
      offset_y = state.offset_y,
      layers = state.renderMode == "layer" and {
        count = #state.layers.ordered,
        active = state.layers.active and state.layers.active.name or nil,
        ordered = orderedLayerInfo -- Now contains canvas info for each layer
      } or nil
    }
  end,
}

do
  -- Hook into love.resize()
  local originalResize = love.handlers["resize"]
  love.handlers["resize"] = function(...)
    shove.resize(...)
    if originalResize then
      originalResize(...)
    end
  end

  -- Determine where shove.lua is located
  local profilerName = "shove-profiler"
  local shoveDir = ""
  local pathSep = package.config:sub(1,1)
  do
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
      local path = info.source:sub(2)
      -- Use pattern based on OS path separator
      local pattern = pathSep == "/"
        and "(.+/)[^/]+%.lua$"
        or "(.+\\)[^\\]+%.lua$"
      shoveDir = path:match(pattern) or ""
    end
  end

  -- Build path with correct separator
  local profilerPath = shoveDir .. profilerName
  local requirePath = profilerPath:gsub(pathSep, ".")

  -- Load profiler module or create a stub module
  local success, shoveProfiler = pcall(require, requirePath)
  if not success then
    print("shove: Profiler module failed to load from: ", shoveProfiler)
    success, shoveProfiler = pcall(require, profilerName)
  end
  if success then
    shove.profiler = shoveProfiler
    shove.profiler.init(shove)
    print("shove: Profiler module loaded")
  else
    print("shove: Profiler module not found, using stub module")
    shove.profiler = {
      renderOverlay = function() end,
      registerParticleSystem = function() end,
      unregisterParticleSystem = function() end
    }
  end
end

return shove
