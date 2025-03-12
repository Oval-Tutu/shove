-- Internal state variables grouped in a single-level table
local state = {
  -- Settings
  scaler = "aspect",
  scaler_mode = "translate",
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
  -- Keep render as-is
  render = { canvases = {}, canvasOptions = {} }
}

local function calculateTransforms()
  -- Calculate initial scale factors (used by most modes)
  state.scale_x = state.screen_width / state.viewport_width
  state.scale_y = state.screen_height / state.viewport_height

  if state.scaler == "aspect" or state.scaler == "pixel" then
    local scaleVal = math.min(state.scale_x, state.scale_y)
    -- Apply pixel-perfect integer scaling if needed
    if state.scaler == "pixel" then
      -- floor to nearest integer and fallback to scale 1
      scaleVal = math.max(math.floor(scaleVal), 1)
    end
    -- Calculate centering offset
    state.offset_x = math.floor((state.scale_x - scaleVal) * (state.viewport_width / 2))
    state.offset_y = math.floor((state.scale_y - scaleVal) * (state.viewport_height / 2))
    -- Apply same scale to width and height
    state.scale_x, state.scale_y = scaleVal, scaleVal
  elseif state.scaler == "stretch" then
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
  love.graphics.setDefaultFilter(state.scaler == "pixel" and "nearest" or "linear")
end

local function setupCanvas(canvasTable)
  -- Final render
  table.insert(canvasTable, { name = "_render", private = true })

  state.render.canvases = {}

  for i = 1, #canvasTable do
    local params = canvasTable[i]

    table.insert(state.render.canvases, {
      name = params.name,
      private = params.private,
      shader = params.shader,
      canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height),
      stencil = params.stencil,
    })
  end

  state.render.canvasOptions = { state.render.canvases[1].canvas, stencil = state.render.canvases[1].stencil }
end

local function getCanvasTable(name)
  for i = 1, #state.render.canvases do
    if state.render.canvases[i].name == name then
      return state.render.canvases[i]
    end
  end
end

local function applyShaders(canvas, shaders)
  local shader = love.graphics.getShader()

  if #shaders <= 1 then
    love.graphics.setShader(shaders[1])
    love.graphics.draw(canvas)
  else
    local _canvas = love.graphics.getCanvas()
    local tmp = getCanvasTable("_tmp")
    local outputCanvas
    local inputCanvas

    -- Only create "_tmp" canvas if needed
    if not tmp then
      table.insert(state.render.canvases, {
        name = "_tmp",
        private = true,
        canvas = love.graphics.newCanvas(state.viewport_width, state.viewport_height),
      })
      tmp = getCanvasTable("_tmp")
    end

    love.graphics.push()
    love.graphics.origin()
    for i = 1, #shaders do
      inputCanvas = i % 2 == 1 and canvas or tmp.canvas
      outputCanvas = i % 2 == 0 and canvas or tmp.canvas
      love.graphics.setCanvas(outputCanvas)
      love.graphics.clear()
      love.graphics.setShader(shaders[i])
      love.graphics.draw(inputCanvas)
      love.graphics.setCanvas(inputCanvas)
    end
    love.graphics.pop()
    love.graphics.setCanvas(_canvas)
    love.graphics.draw(outputCanvas)
  end

  love.graphics.setShader(shader)
end

-- Public API
return {
  initResolution = function(width, height, settingsTable)
    state.viewport_width = width
    state.viewport_height = height
    state.screen_width, state.screen_height = love.graphics.getDimensions()

    -- Handle settings
    if settingsTable then
      state.scaler = settingsTable.scaler or "aspect"
      state.scaler_mode = settingsTable.scaler_mode or "translate"
    else
      state.scaler = "aspect"
      state.scaler_mode = "translate"
    end

    calculateTransforms()
    if state.scaler_mode == "canvas" then
      setupCanvas({ "default" })
    end
  end,

  setupCanvas = setupCanvas,

  setCanvas = function(name)
    if state.scaler_mode ~= "canvas" then
      return true
    end

    local canvasTable = getCanvasTable(name)
    return love.graphics.setCanvas({ canvasTable.canvas, stencil = canvasTable.stencil })
  end,

  setShader = function(name, shader)
    if not shader then
      getCanvasTable("_render").shader = name
    else
      getCanvasTable(name).shader = shader
    end
  end,

  updateSettings = function(settingsTable)
    state.scaler = settingsTable.scaler or state.scaler
    state.scaler_mode = settingsTable.scaler_mode or state.scaler_mode
  end,

  -- Convert coordinates from screen to game viewport coordinates
  toViewport = function(x, y)
    x, y = x - state.offset_x, y - state.offset_y
    local normalX, normalY = x / state.rendered_width, y / state.rendered_height

    x = (x >= 0 and x <= state.viewport_width * state.scale_x) and
        math.floor(normalX * state.viewport_width) or false
    y = (y >= 0 and y <= state.viewport_height * state.scale_y) and
        math.floor(normalY * state.viewport_height) or false
    return x, y
  end,

  -- Convert coordinates from game viewport to screen coordinates
  toScreen = function(x, y)
    local realX = state.offset_x + (state.rendered_width * x) / state.viewport_width
    local realY = state.offset_y + (state.rendered_height * y) / state.viewport_height
    return realX, realY
  end,

  startDraw = function()
    if state.scaler_mode == "canvas" then
      love.graphics.push()
      love.graphics.setCanvas(state.render.canvasOptions)
    else
      love.graphics.translate(state.offset_x, state.offset_y)
      love.graphics.setScissor(state.offset_x, state.offset_y,
                              state.viewport_width * state.scale_x,
                              state.viewport_height * state.scale_y)
      love.graphics.push()
      love.graphics.scale(state.scale_x, state.scale_y)
    end
  end,

  stopDraw = function(shader)
    if state.scaler_mode == "canvas" then
      local render = getCanvasTable("_render")

      love.graphics.pop()
      -- Draw canvas
      love.graphics.setCanvas(render.canvas)
      -- Do not draw render yet
      for i = 1, #state.render.canvases do
        local canvasTable = state.render.canvases[i]
        if not canvasTable.private then
          local shader = canvasTable.shader
          applyShaders(canvasTable.canvas, type(shader) == "table" and shader or { shader })
        end
      end
      love.graphics.setCanvas()

      -- Now draw render
      love.graphics.translate(state.offset_x, state.offset_y)
      love.graphics.push()
        love.graphics.scale(state.scale_x, state.scale_y)
        do
          local shader = shader or render.shader
          applyShaders(render.canvas, type(shader) == "table" and shader or { shader })
        end
      love.graphics.pop()
      love.graphics.translate(-state.offset_x, -state.offset_y)
      -- Clear canvas
      for i = 1, #state.render.canvases do
        love.graphics.setCanvas(state.render.canvases[i].canvas)
        love.graphics.clear()
      end
      love.graphics.setCanvas()
      love.graphics.setShader()
    else
      love.graphics.pop()
      love.graphics.setScissor()
      love.graphics.translate(-state.offset_x, -state.offset_y)
    end
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

  -- Returns the game viewport rectangle in screen coordinates (x, y, width, height)
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
    if state.scaler == "stretch" then
      return true
    end

    local viewX, viewY, viewWidth, viewHeight = state.offset_x, state.offset_y,
                                               state.viewport_width * state.scale_x,
                                               state.viewport_height * state.scale_y

    return x >= viewX and x < viewX + viewWidth and
           y >= viewY and y < viewY + viewHeight
  end,
}
