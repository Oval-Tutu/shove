---@class ShoveState
---@field fitMethod "aspect"|"pixel"|"stretch"|"none" Scaling method
---@field renderMode "direct"|"layer" Rendering approach
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
---@field inDrawMode boolean Whether we're currently in drawing mode
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
  },
  -- Shader for masking
  maskShader = nil
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

---@class ShoveLayerOptions
---@field zIndex? number Z-order index (optional)
---@field visible? boolean Whether layer is visible (default: true)
---@field stencil? boolean Whether layer supports stencil operations (default: false)
---@field effects? love.Shader[] Effects to apply to the layer (optional)
---@field blendMode? love.BlendMode Blend mode for the layer (default: "alpha")

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
    if globalEffects and type(globalEffects) == "table" and #globalEffects > 0 then
      for _, effect in ipairs(globalEffects) do
        table.insert(effects, effect)
      end
    end

    if effects and #effects > 0 then
      applyEffects(state.layers.composite.canvas, effects)
    else
      love.graphics.draw(state.layers.composite.canvas)
    end
  love.graphics.pop()
  love.graphics.translate(-state.offset_x, -state.offset_y)

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
  ---@class ShoveInitOptions
  ---@field fitMethod? "aspect"|"pixel"|"stretch"|"none" Scaling method
  ---@field renderMode? "direct"|"layer" Rendering approach

  --- Initialize the resolution system
  ---@param width number Viewport width
  ---@param height number Viewport height
  ---@param settingsTable? ShoveInitOptions Configuration options
  initResolution = function(width, height, settingsTable)
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
    else
      state.fitMethod = "aspect"
      state.renderMode = "direct"
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

  --- Begin drawing operations
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

  --- End drawing operations and display result
  ---@param globalEffects love.Shader[]|nil Optional effects to apply globally
  endDraw = function(globalEffects)
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
  end,

  -- Layer management API

  --- Create a new layer
  ---@param name string Layer name
  ---@param options? ShoveLayerOptions Layer configuration options
  ---@return ShoveLayer layer The created layer
  createLayer = function(name, options)
    return createLayer(name, options)
  end,

  --- Remove a layer
  ---@param name string Layer name
  ---@return boolean success Whether layer was removed
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

  --- Check if a layer exists
  ---@param name string Layer name
  ---@return boolean exists Whether the layer exists
  layerExists = function(name)
    return state.layers.byName[name] ~= nil
  end,

  --- Set the z-index order of a layer
  ---@param name string Layer name
  ---@param zIndex number Z-order position
  ---@return boolean success Whether the layer order was changed
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

  --- Get the z-index order of a layer
  ---@param name string Layer name
  ---@return number|nil zIndex Z-order position, or nil if layer doesn't exist
  getLayerOrder = function(name)
    local layer = getLayer(name)
    if not layer then return nil end
    return layer.zIndex
  end,

  --- Set layer visibility
  ---@param name string Layer name
  ---@param isVisible boolean Whether the layer should be visible
  ---@return boolean success Whether the layer visibility was changed
  setLayerVisible = function(name, isVisible)
    local layer = getLayer(name)
    if not layer then
      return false
    end

    layer.visible = isVisible
    return true
  end,

  --- Check if a layer is visible
  ---@param name string Layer name
  ---@return boolean|nil isVisible Whether the layer is visible, or nil if layer doesn't exist
  isLayerVisible = function(name)
    local layer = getLayer(name)
    if not layer then return nil end
    return layer.visible
  end,

  --- Set a mask for a layer
  ---@param name string Layer name
  ---@param maskName string|nil Name of layer to use as mask, or nil to clear mask
  ---@return boolean success Whether the mask was set
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
  compositeAndDraw = function(globalEffects, applyPersistentEffects)
    -- This allows manually compositing layers at any point with optional effect control
    return compositeLayersToScreen(globalEffects, applyPersistentEffects or false)
  end,

  --- Draw to a specific layer using a callback function
  ---@param name string Layer name
  ---@param drawFunc function Callback function to execute for drawing
  ---@return boolean success Whether drawing was performed
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

  --- Add an effect to a layer
  ---@param layerName string Layer name
  ---@param effect love.Shader Shader effect to add
  ---@return boolean success Whether the effect was added
  addEffect = function(layerName, effect)
    local layer = getLayer(layerName)
    if not layer then return false end
    return addEffect(layer, effect)
  end,

  --- Remove an effect from a layer
  ---@param layerName string Layer name
  ---@param effect love.Shader Shader effect to remove
  ---@return boolean success Whether the effect was removed
  removeEffect = function(layerName, effect)
    local layer = getLayer(layerName)
    if not layer then return false end
    return removeEffect(layer, effect)
  end,

  --- Clear all effects from a layer
  ---@param layerName string Layer name
  ---@return boolean success Whether effects were cleared
  clearEffects = function(layerName)
    local layer = getLayer(layerName)
    if not layer then return false end
    return clearEffects(layer)
  end,

  --- Add a global effect
  ---@param effect love.Shader Shader effect to add globally
  ---@return boolean success Whether the effect was added
  addGlobalEffect = function(effect)
    if not state.layers.composite then
      createCompositeLayer()
    end
    return addEffect(state.layers.composite, effect)
  end,

  --- Remove a global effect
  ---@param effect love.Shader Shader effect to remove
  ---@return boolean success Whether the effect was removed
  removeGlobalEffect = function(effect)
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

  --- Convert viewport coordinates to screen coordinates
  ---@param x number Viewport X coordinate
  ---@param y number Viewport Y coordinate
  ---@return number screenX Screen X coordinate
  ---@return number screenY Screen Y coordinate
  toScreen = function(x, y)
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
    return shove.toViewport(mouseX, mouseY)
  end,

  --- Update dimensions when window is resized
  ---@param width number New window width
  ---@param height number New window height
  resize = function(width, height)
    state.screen_width = width
    state.screen_height = height
    calculateTransforms()
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

  --- Get current fit method
  ---@return "aspect"|"pixel"|"stretch"|"none" fitMethod Current fit method
  getFitMethod = function()
    return state.fitMethod
  end,

  --- Set fit method
  ---@param method "aspect"|"pixel"|"stretch"|"none" New fit method
  ---@return boolean success Whether the method was set
  setFitMethod = function(method)
    local validMethods = {aspect = true, pixel = true, stretch = true, none = true}
    if not validMethods[method] then
      return false
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
    local validModes = {direct = true, layer = true}
    if not validModes[mode] then
      return false
    end

    state.renderMode = mode
    -- Recalculate transforms with current dimensions
    shove.resize(state.screen_width, state.screen_height)
    return true
  end,
}

return shove
