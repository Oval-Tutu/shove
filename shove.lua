-- Internal state variables grouped in a local table
local state = {
  settings = {},
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

local function initValues()
  if state.settings.upscale then
    state.transform.scale.x = state.dimensions.window.width / state.dimensions.shove.width
    state.transform.scale.y = state.dimensions.window.height / state.dimensions.shove.height

    if state.settings.upscale == "normal" or state.settings.upscale == "pixel-perfect" then
      local scaleVal

      scaleVal = math.min(state.transform.scale.x, state.transform.scale.y)
      if scaleVal >= 1 and state.settings.upscale == "pixel-perfect" then
        scaleVal = math.floor(scaleVal)
      end

      state.transform.offset.x = math.floor((state.transform.scale.x - scaleVal) * (state.dimensions.shove.width / 2))
      state.transform.offset.y = math.floor((state.transform.scale.y - scaleVal) * (state.dimensions.shove.height / 2))

      state.transform.scale.x, state.transform.scale.y = scaleVal, scaleVal -- Apply same scale to width and height
    elseif state.settings.upscale == "stretched" then -- If stretched, no need to apply offset
      state.transform.offset.x, state.transform.offset.y = 0, 0
    else
      error("Invalid upscale setting")
    end
  else
    state.transform.scale.x, state.transform.scale.y = 1, 1

    state.transform.offset.x = math.floor((state.dimensions.window.width / state.dimensions.shove.width - 1) * (state.dimensions.shove.width / 2))
    state.transform.offset.y = math.floor((state.dimensions.window.height / state.dimensions.shove.height - 1) * (state.dimensions.shove.height / 2))
  end

  state.dimensions.draw.width = state.dimensions.window.width - state.transform.offset.x * 2
  state.dimensions.draw.height = state.dimensions.window.height - state.transform.offset.y * 2
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

local function start()
  if state.settings.canvas then
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

local function finish(shader)
  if state.settings.canvas then
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
end

-- Public API
return {
  setupScreen = function(width, height, settingsTable)
    state.dimensions.shove.width = width
    state.dimensions.shove.height = height
    state.dimensions.window.width, state.dimensions.window.height = love.graphics.getDimensions()
    state.settings = settingsTable

    initValues()

    if state.settings.canvas then
      setupCanvas({ "default" })
    end
  end,

  setupCanvas = setupCanvas,

  setCanvas = function(name)
    if not state.settings.canvas then
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
    state.settings.upscale = settingsTable.upscale or state.settings.upscale
    state.settings.canvas = settingsTable.canvas or state.settings.canvas
  end,

  toGame = function(x, y)
    local normalX, normalY

    x, y = x - state.transform.offset.x, y - state.transform.offset.y
    normalX, normalY = x / state.dimensions.draw.width, y / state.dimensions.draw.height

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

  start = start,
  finish = finish,

  resize = function(width, height)
    state.dimensions.window.width = width
    state.dimensions.window.height = height

    initValues()
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
