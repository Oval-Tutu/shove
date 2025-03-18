shove = require("shove")

local demo_index = 1
local is_fullscreen = love.window.getFullscreen()
local demo_data = {
  --{ module = "no-shove" },
  { module = "low-res" },
  { module = "single-shader" },
  { module = "multiple-shaders" },
  { module = "mouse-input" },
  { module = "canvases-shaders" },
  { module = "stencil" },
  { module = "mask" },
  { module = "parallax" },
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

-- Helper function for cycling demos
function cycle_demo(direction)
  if direction > 0 then
    demo_index = (demo_index < #demos) and demo_index + 1 or 1
  else
    demo_index = (demo_index > 1) and demo_index - 1 or #demos
  end
  demo_load()
end

function love.keypressed(key)
  if key == "space" or key == "right" then
    cycle_demo(1)
  elseif key == "left" then
    cycle_demo(-1)
  elseif key == "f" then
    is_fullscreen = not is_fullscreen
    love.window.setFullscreen(is_fullscreen)
  elseif key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  end
end

demo_load()
