shove = require("shove")
love.window.setTitle("Press space to switch demo!")

local examples = {
  "low-res",
  "single-shader",
  "multiple-shaders",
  "mouse-input",
  "canvases-shaders",
  "stencil",
}
local example = 1

for i = 1, #examples do
  examples[i] = require(examples[i])
end

-- Start first example
local success, err = pcall(function()
  examples[example]()
end)

if not success then
  print("Error loading example: " .. tostring(err))
end

function love.resize(w, h)
  shove.resize(w, h)
end

function love.keypressed(key)
  if key == "space" then
    -- Switch example
    example = (example < #examples) and example + 1 or 1

    -- Initialize new example with error handling
    local success = pcall(function()
      examples[example]()
      if love.load then love.load() end
    end)
  elseif key == "f" then
    -- Activate fullscreen mode
    love.window.setMode(0, 0, { fullscreen = true, fullscreentype = "desktop" })
    shove.resize(love.graphics.getDimensions())
  elseif key == "escape" and love.system.getOS() ~= "Web" then
    love.event.quit()
  end
end
