shove = require("shove")

local demo_index = 1
local is_fullscreen = love.window.getFullscreen()
local demo_data = {
  { module = "low-res" },
  { module = "single-shader" },
  { module = "multiple-shaders" },
  { module = "mouse-input" },
  { module = "canvases-shaders" },
  { module = "stencil" },
  { module = "mask" },
}

local demos = {}
for i, demo in ipairs(demo_data) do
  demos[i] = require(demo.module)
end

function demo_title()
  local current = demo_data[demo_index]
  local fitMethod = shove.getFitMethod()
  local renderMode = shove.getRenderMode()
  local vpWidth, vpHeight = shove.getViewportDimensions()
  local demo_title = string.format("%s: (%s x %s) [%s / %s]", current.module, vpWidth, vpHeight, fitMethod, renderMode)
  print(demo_title)
  love.window.setTitle(demo_title)
end

function demo_load()
  demos[demo_index]()
  love.load()
  love.window.setFullscreen(is_fullscreen)
  demo_title()
end

function love.resize(w, h)
  shove.resize(w, h)
end

function love.keypressed(key)
  if key == "space" then
    demo_index = (demo_index < #demos) and demo_index + 1 or 1
    demo_load()
  elseif key == "f" then
    is_fullscreen = not is_fullscreen
    love.window.setFullscreen(is_fullscreen)
  elseif key == "a" then
    shove.setFitMethod("aspect")
    demo_title()
  elseif key == "s" then
    shove.setFitMethod("stretch")
    demo_title()
  elseif key == "p" then
    shove.setFitMethod("pixel")
    demo_title()
  elseif key == "n" then
    shove.setFitMethod("none")
    demo_title()
  elseif key == "d" then
    shove.setRenderMode("direct")
    demo_title()
  elseif key == "l" then
    shove.setRenderMode("layer")
    demo_title()
  elseif key == "r" then
    demo_load()
  elseif key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  end
end

demo_load()
