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

---@class ShoveLayerOptions
---@field zIndex? number Z-order index (optional)
---@field visible? boolean Whether layer is visible (default: true)
---@field stencil? boolean Whether layer supports stencil operations (default: false)
---@field effects? love.Shader[] Effects to apply to the layer (optional)
---@field blendMode? love.BlendMode Blend mode for the layer (default: "alpha")
---@field blendAlphaMode? love.BlendAlphaMode Alpha blend mode (default: "alphamultiply")

--- Create a new layer or return existing one
---@param name string Layer name
---@param options? ShoveLayerOptions Layer configuration options
---@return ShoveLayer layer The created or existing layer
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
    blendAlphaMode = options.blendAlphaMode or "alphamultiply",
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

--- Get a layer by name
---@param name string Layer name
---@return ShoveLayer|nil layer The requested layer or nil if not found
local function getLayer(name)
  return state.layers.byName[name]
end

--- Set the currently active layer
---@param name string Layer name
---@return boolean success Whether the layer was found and set active
local function setActiveLayer(name)
  local layer = getLayer(name)
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
    canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height),
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
---@param name string Layer name
---@return boolean success Whether the layer was successfully activated
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
local function compositeLayersToScreen(globalEffects, applyPersistentEffects)
  if globalEffects ~= nil and type(globalEffects) ~= "table" then
    error("compositeLayersToScreen: globalEffects must be a table of shaders or nil", 2)
  end

  if type(applyPersistentEffects) ~= "boolean" then
    error("compositeLayersToScreen: applyPersistentEffects must be a boolean", 2)
  end

  if state.renderMode ~= "layer" then
    return false
  end

  -- Ensure we have a composite layer
  if not state.layers.composite then
    createCompositeLayer()
  end

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
      -- Apply mask if needed
      if layer.maskLayer then
        local maskLayer = getLayer(layer.maskLayer)
        if maskLayer then
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
      createLayer("default")
      createCompositeLayer()

      -- Don't activate layer right away, just mark it as active
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

      -- Composite and draw layers to screen (always apply global persistent effects in endDraw)
      compositeLayersToScreen(globalEffects, true)
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

    return true
  end,

  -- Layer management API

  --- Create a new layer
  ---@param name string Layer name
  ---@param options? ShoveLayerOptions Layer configuration options
  ---@return ShoveLayer layer The created layer
  createLayer = function(name, options)
    if type(name) ~= "string" then
      error("shove.createLayer: name must be a string", 2)
    end

    if name == "" then
      error("shove.createLayer: name cannot be empty", 2)
    end

    -- Check for reserved names
    if name == "_composite" or name == "_tmp" then
      error("shove.createLayer: '"..name.."' is a reserved layer name", 2)
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

    return createLayer(name, options)
  end,

  --- Remove a layer
  ---@param name string Layer name
  ---@return boolean success Whether layer was removed
  removeLayer = function(name)
    if type(name) ~= "string" then
      error("shove.removeLayer: name must be a string", 2)
    end

    if name == "" then
      error("shove.removeLayer: name cannot be empty", 2)
    end

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

  --- Check if a layer exists
  ---@param name string Layer name
  ---@return boolean exists Whether the layer exists
  hasLayer = function(name)
    if type(name) ~= "string" then
      error("shove.hasLayer: name must be a string", 2)
    end

    if name == "" then
      error("shove.hasLayer: name cannot be empty", 2)
    end

    return state.layers.byName[name] ~= nil
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
  ---@param name string Layer name
  ---@param zIndex number Z-order position
  ---@return boolean success Whether the layer order was changed
  setLayerOrder = function(name, zIndex)
    if type(name) ~= "string" then
      error("shove.setLayerOrder: name must be a string", 2)
    end

    if name == "" then
      error("shove.setLayerOrder: name cannot be empty", 2)
    end

    if type(zIndex) ~= "number" then
      error("shove.setLayerOrder: zIndex must be a number", 2)
    end

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

  --- Get the z-index order of a layer
  ---@param name string Layer name
  ---@return number|nil zIndex Z-order position, or nil if layer doesn't exist
  getLayerOrder = function(name)
    if type(name) ~= "string" then
      error("shove.getLayerOrder: name must be a string", 2)
    end

    if name == "" then
      error("shove.getLayerOrder: name cannot be empty", 2)
    end

    local layer = getLayer(name)
    if not layer then return nil end
    return layer.zIndex
  end,

--- Show a layer (make it visible)
---@param name string Layer name
---@return boolean success Whether the layer visibility was changed
  showLayer = function(name)
    if type(name) ~= "string" then
      error("shove.showLayer: name must be a string", 2)
    end

    if name == "" then
      error("shove.showLayer: name cannot be empty", 2)
    end

    local layer = getLayer(name)
    if not layer then
      return false
    end

    layer.visible = true
    return true
  end,

--- Hide a layer (make it invisible)
---@param name string Layer name
---@return boolean success Whether the layer visibility was changed
  hideLayer = function(name)
    if type(name) ~= "string" then
      error("shove.hideLayer: name must be a string", 2)
    end

    if name == "" then
      error("shove.hideLayer: name cannot be empty", 2)
    end

    local layer = getLayer(name)
    if not layer then
      return false
    end

    layer.visible = false
    return true
  end,

  --- Check if a layer is visible
  ---@param name string Layer name
  ---@return boolean|nil isVisible Whether the layer is visible, or nil if layer doesn't exist
  isLayerVisible = function(name)
    if type(name) ~= "string" then
      error("shove.isLayerVisible: name must be a string", 2)
    end

    if name == "" then
      error("shove.isLayerVisible: name cannot be empty", 2)
    end

    local layer = getLayer(name)
    if not layer then return nil end
    return layer.visible
  end,

--- Get the mask layer used by a layer
---@param name string Layer name
---@return string|nil maskName Name of the mask layer, or nil if no mask or layer doesn't exist
  getLayerMask = function(name)
    if type(name) ~= "string" then
      error("shove.getLayerMask: name must be a string", 2)
    end

    if name == "" then
      error("shove.getLayerMask: name cannot be empty", 2)
    end

    local layer = getLayer(name)
    if not layer then return nil end

    return layer.maskLayer
  end,

  --- Set a mask for a layer
  ---@param name string Layer name
  ---@param maskName string|nil Name of layer to use as mask, or nil to clear mask
  ---@return boolean success Whether the mask was set
  setLayerMask = function(name, maskName)
    if type(name) ~= "string" then
      error("shove.setLayerMask: name must be a string", 2)
    end

    if name == "" then
      error("shove.setLayerMask: name cannot be empty", 2)
    end

    if maskName ~= nil and type(maskName) ~= "string" then
      error("shove.setLayerMask: maskName must be a string or nil", 2)
    end

    if maskName == "" then
      error("shove.setLayerMask: maskName cannot be empty", 2)
    end

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
      layer.stencil = true
    else
      layer.maskLayer = nil
    end

    return true
  end,

  --- Begin drawing to a layer
  ---@param name string Layer name
  ---@return boolean success Whether the layer was activated
  beginLayer = function(name)
    if type(name) ~= "string" then
      error("shove.beginLayer: name must be a string", 2)
    end

    if name == "" then
      error("shove.beginLayer: name cannot be empty", 2)
    end

    return beginLayerDraw(name)
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
    return compositeLayersToScreen(globalEffects, applyPersistentEffects or false)
  end,

  --- Draw to a specific layer using a callback function
  ---@param name string Layer name
  ---@param drawFunc function Callback function to execute for drawing
  ---@return boolean success Whether drawing was performed
  drawToLayer = function(name, drawFunc)
    if type(name) ~= "string" then
      error("shove.drawToLayer: name must be a string", 2)
    end

    if name == "" then
      error("shove.drawToLayer: name cannot be empty", 2)
    end

    if type(drawFunc) ~= "function" then
      error("shove.drawToLayer: drawFunc must be a function", 2)
    end

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

    if not state.layers.composite then
      createCompositeLayer()
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

--- Display debug information about the current state of Shove
---@param x number|nil X position for debug display (default: 10)
---@param y number|nil Y position for debug display (default: 10)
---@param options table|nil Options for display {showLayers = false, showPerformance = false}
---@return nil
  showDebugInfo = function(x, y, options)
    if x ~= nil and type(x) ~= "number" then
      error("shove.showDebugInfo: x must be a number or nil", 2)
    end

    if y ~= nil and type(y) ~= "number" then
      error("shove.showDebugInfo: y must be a number or nil", 2)
    end

    if options ~= nil and type(options) ~= "table" and type(options) ~= "boolean" then
      error("shove.showDebugInfo: options must be a table, boolean, or nil", 2)
    end

    -- Default position in top-left corner with small margin
    x = x or 10
    y = y or 10

    -- Handle backwards compatibility and options
    local showLayers, showPerformance = false, false
    if type(options) == "boolean" then
      -- Old style: third param was just showLayers
      showLayers = options
    elseif type(options) == "table" then
      -- New style: options table
      showLayers = options.showLayers or false
      showPerformance = options.showPerformance or false
    end

    -- Save current graphics state
    local r, g, b, a = love.graphics.getColor()
    local font = love.graphics.getFont()
    local blendMode, blendAlphaMode = love.graphics.getBlendMode()

    -- Set a consistent debug font
    local debugFont = love.graphics.newFont(12)
    love.graphics.setFont(debugFont)

    -- Calculate panel height based on what's being shown
    local panelWidth = 230
    local panelHeight = 190

    if showLayers and state.renderMode == "layer" then
      panelHeight = panelHeight + 190 -- Extra space for layers
    end

    if showPerformance then
      panelHeight = panelHeight + 120 -- Extra space for performance stats
    end

    -- Background panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)

    -- Border
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)

    -- Header
    love.graphics.setColor(0.7, 0.9, 1, 1)
    love.graphics.print("Shöve", x + 10, y + 10)

    -- Reset text color
    love.graphics.setColor(1, 1, 1, 1)

    -- Build debug text with basic info
    local info = {
      string.format("Fit Method: %s", state.fitMethod),
      string.format("Render Mode: %s", state.renderMode),
      string.format("Scaling Filter: %s", state.scalingFilter),
      "",
      string.format("Window: %d x %d", state.screen_width, state.screen_height),
      string.format("Viewport: %d x %d", state.viewport_width, state.viewport_height),
      string.format("Rendered: %d x %d", state.rendered_width, state.rendered_height),
      "",
      string.format("Scale: %.3f x %.3f", state.scale_x, state.scale_y),
      string.format("Offset: %d x %d", state.offset_x, state.offset_y)
    }

    -- Draw basic info
    local lineHeight = 15
    local currentY = y + 25
    for i, line in ipairs(info) do
      love.graphics.print(line, x + 10, currentY + (i-1) * lineHeight)
    end
    currentY = currentY + #info * lineHeight + 10

    -- Draw performance info if requested
    if showPerformance then
      -- Get LÖVE graphics stats
      local stats = love.graphics.getStats()

      -- Performance header
      love.graphics.setColor(0.7, 0.9, 1, 1)
      love.graphics.print("Performance:", x + 10, currentY)
      love.graphics.setColor(1, 1, 1, 1)
      currentY = currentY + lineHeight

      local currentFPS = love.timer.getFPS()
      love.graphics.print(string.format("FPS: %d", currentFPS), x + 10, currentY)
      currentY = currentY + lineHeight

      -- Add frame time (time between frames)
      local frameDelta = love.timer.getDelta() * 1000 -- Convert to milliseconds
      love.graphics.print(string.format("Frame Time: %.2f ms", frameDelta), x + 10, currentY)
      currentY = currentY + lineHeight

      -- Canvas stats
      love.graphics.print(string.format("Canvases: %d", stats.canvases), x + 10, currentY)
      currentY = currentY + lineHeight

      -- Canvas switch stats
      love.graphics.print(string.format("Canvas Switches: %d", stats.canvasswitches), x + 10, currentY)
      currentY = currentY + lineHeight

      -- Shader switch stats
      love.graphics.print(string.format("Shader Switches: %d", stats.shaderswitches), x + 10, currentY)
      currentY = currentY + lineHeight

      -- Draw call stats
      love.graphics.print(string.format("Draw Calls: %d (%d batched)",
        stats.drawcalls, stats.drawcallsbatched), x + 10, currentY)
      currentY = currentY + lineHeight

      -- Texture memory stats
      local textureMemoryMB = stats.texturememory / (1024 * 1024)
      love.graphics.print(string.format("VRAM: %.1f MB", textureMemoryMB), x + 10, currentY)
      currentY = currentY + lineHeight

      currentY = currentY + 5 -- Add a small gap
    end

    -- Draw layer info if requested
    if showLayers and state.renderMode == "layer" then
      -- Section header
      love.graphics.setColor(0.7, 0.9, 1, 1)
      love.graphics.print("Layers:", x + 10, currentY)
      love.graphics.setColor(1, 1, 1, 1)
      currentY = currentY + lineHeight

      -- Count layers
      local layerCount = 0
      for _ in pairs(state.layers.byName) do layerCount = layerCount + 1 end

      love.graphics.print(string.format("Count: %d", layerCount), x + 10, currentY)
      currentY = currentY + lineHeight

      -- Display active layer
      local activeName = state.layers.active and state.layers.active.name or "none"
      love.graphics.print(string.format("Active: %s", activeName), x + 10, currentY)
      currentY = currentY + lineHeight

      -- List all layers
      love.graphics.print("Ordered layers:", x + 10, currentY)
      currentY = currentY + lineHeight

      for i, layer in ipairs(state.layers.ordered) do
        if layer.name ~= "_composite" and layer.name ~= "_tmp" then
          local visibility = layer.visible and "y" or "n"
          local layerInfo = string.format(
            "%d: %s [%s] %s/%s",
            layer.zIndex,
            layer.name,
            visibility,
            layer.blendMode,
            layer.blendAlphaMode:sub(1,4) -- Shortened for display
          )

          -- Highlight active layer
          if state.layers.active and layer.name == state.layers.active.name then
            love.graphics.setColor(1, 1, 0, 1)
          else
            love.graphics.setColor(1, 1, 1, 1)
          end

          love.graphics.print(layerInfo, x + 15, currentY)
          currentY = currentY + lineHeight
        end
      end
    end

    -- Restore graphics state
    love.graphics.setColor(r, g, b, a)
    love.graphics.setFont(font)
    love.graphics.setBlendMode(blendMode, blendAlphaMode)
  end,

  --- Handle displaying debug information based on function key presses
  --- F1: Full debug with layers and performance
  --- F2: Basic info with performance
  --- F3: Basic info with layers
  --- F4: Basic info only
  ---@return nil
  handleDebugKeys = function()
    local debugX = love.graphics.getWidth() - 240
    local debugY = 10

    if love.keyboard.isDown("f1") then
      -- Show full debug info including layers and performance when F1 is pressed
      shove.showDebugInfo(debugX, debugY, {showLayers = true, showPerformance = true})
    elseif love.keyboard.isDown("f2") then
      -- Show basic debug info + performance when F2 is pressed
      shove.showDebugInfo(debugX, debugY, {showPerformance = true})
    elseif love.keyboard.isDown("f3") then
      -- Show only layer info when F3 is pressed
      shove.showDebugInfo(debugX, debugY, {showLayers = true})
    elseif love.keyboard.isDown("f4") then
      -- Show basic debug info when F4 is pressed
      shove.showDebugInfo(debugX, debugY)
    end
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

--- Get the current resize callback function
---@return function|nil callback The current resize callback or nil if none is set
  getResizeCallback = function()
    return state.resizeCallback
  end,
}

return shove
