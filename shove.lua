-- Internal state variables grouped in a local table
local state = {
  settings = {
    scaler = "aspect",
    scaler_mode = "translate"
  },
  dimensions = {
    window = {width = 0, height = 0},
    shove = {width = 0, height = 0},
    draw = {width = 0, height = 0}
  },
  transform = {
    scale = {x = 0, y = 0},
    offset = {x = 0, y = 0}
  },
  render = {
    canvases = {},
    canvasOptions = {}
  }
}

local function calculateTransforms()
  -- Calculate initial scale factors (used by most modes)
  state.transform.scale.x = state.dimensions.window.width / state.dimensions.shove.width
  state.transform.scale.y = state.dimensions.window.height / state.dimensions.shove.height

  if state.settings.scaler == "aspect" or state.settings.scaler == "pixel" then
    local scaleVal = math.min(state.transform.scale.x, state.transform.scale.y)
    -- Apply pixel-perfect integer scaling if needed
    if state.settings.scaler == "pixel" then
      -- floor to nearest integer and fallback to scale 1
      scaleVal = math.max(math.floor(scaleVal), 1)
    end
    -- Calculate centering offset
    state.transform.offset.x = math.floor((state.transform.scale.x - scaleVal) * (state.dimensions.shove.width / 2))
    state.transform.offset.y = math.floor((state.transform.scale.y - scaleVal) * (state.dimensions.shove.height / 2))
    -- Apply same scale to width and height
    state.transform.scale.x, state.transform.scale.y = scaleVal, scaleVal
  elseif state.settings.scaler == "stretch" then
    -- Stretch scaling: no offset
    state.transform.offset.x, state.transform.offset.y = 0, 0
  else
    -- No scaling
    state.transform.scale.x, state.transform.scale.y = 1, 1
    -- Center the view in the window
    state.transform.offset.x = math.floor((state.dimensions.window.width - state.dimensions.shove.width) / 2)
    state.transform.offset.y = math.floor((state.dimensions.window.height - state.dimensions.shove.height) / 2)
  end
  -- Calculate final draw dimensions
  state.dimensions.draw.width = state.dimensions.window.width - state.transform.offset.x * 2
  state.dimensions.draw.height = state.dimensions.window.height - state.transform.offset.y * 2
  -- Set appropriate filter based on scaling mode
  love.graphics.setDefaultFilter(state.settings.scaler == "pixel" and "nearest" or "linear")
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
      canvas = love.graphics.newCanvas(state.dimensions.shove.width, state.dimensions.shove.height),
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
        canvas = love.graphics.newCanvas(state.dimensions.shove.width, state.dimensions.shove.height),
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
  setupScreen = function(width, height, settingsTable)
    state.dimensions.shove.width = width
    state.dimensions.shove.height = height
    state.dimensions.window.width, state.dimensions.window.height = love.graphics.getDimensions()
    state.settings = settingsTable or {}
    state.settings.scaler = state.settings.scaler or "aspect"
    state.settings.scaler_mode = state.settings.scaler_mode or "translate"
    calculateTransforms()
    if state.settings.scaler_mode == "canvas" then
      setupCanvas({ "default" })
    end
  end,

  setupCanvas = setupCanvas,

  setCanvas = function(name)
    if state.settings.scaler_mode ~= "canvas" then
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
    state.settings.scaler = settingsTable.scaler or state.settings.scaler
    state.settings.scaler_mode = settingsTable.scaler_mode or state.settings.scaler_mode
  end,

  toGame = function(x, y)
    x, y = x - state.transform.offset.x, y - state.transform.offset.y
    local normalX, normalY = x / state.dimensions.draw.width, y / state.dimensions.draw.height

    x = (x >= 0 and x <= state.dimensions.shove.width * state.transform.scale.x) and
        math.floor(normalX * state.dimensions.shove.width) or false
    y = (y >= 0 and y <= state.dimensions.shove.height * state.transform.scale.y) and
        math.floor(normalY * state.dimensions.shove.height) or false
    return x, y
  end,

  toReal = function(x, y)
    local realX = state.transform.offset.x + (state.dimensions.draw.width * x) / state.dimensions.shove.width
    local realY = state.transform.offset.y + (state.dimensions.draw.height * y) / state.dimensions.shove.height
    return realX, realY
  end,

  start = function()
    if state.settings.scaler_mode == "canvas" then
      love.graphics.push()
      love.graphics.setCanvas(state.render.canvasOptions)
    else
      love.graphics.translate(state.transform.offset.x, state.transform.offset.y)
      love.graphics.setScissor(state.transform.offset.x, state.transform.offset.y,
                              state.dimensions.shove.width * state.transform.scale.x,
                              state.dimensions.shove.height * state.transform.scale.y)
      love.graphics.push()
      love.graphics.scale(state.transform.scale.x, state.transform.scale.y)
    end
  end,

  finish = function(shader)
    if state.settings.scaler_mode == "canvas" then
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
      love.graphics.translate(state.transform.offset.x, state.transform.offset.y)
      love.graphics.push()
      love.graphics.scale(state.transform.scale.x, state.transform.scale.y)
      do
        local shader = shader or render.shader
        applyShaders(render.canvas, type(shader) == "table" and shader or { shader })
      end
      love.graphics.pop()
      love.graphics.translate(-state.transform.offset.x, -state.transform.offset.y)

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
      love.graphics.translate(-state.transform.offset.x, -state.transform.offset.y)
    end
  end,

  resize = function(width, height)
    state.dimensions.window.width = width
    state.dimensions.window.height = height
    calculateTransforms()
  end,

  getWidth = function()
    return state.dimensions.shove.width
  end,

  getHeight = function()
    return state.dimensions.shove.height
  end,

  getDimensions = function()
    return state.dimensions.shove.width, state.dimensions.shove.height
  end,
}
