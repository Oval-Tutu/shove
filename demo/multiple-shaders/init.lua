return function()
  local gameWidth, gameHeight = 1080, 720
  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth * 0.5, windowHeight * 0.5

  love.window.setMode(windowWidth, windowHeight, { resizable = true })
  shove.initResolution(gameWidth, gameHeight, { renderMode = "layer" })

  function love.load()
    time = 0
    image = love.graphics.newImage("multiple-shaders/love.png")
    shader1 = love.graphics.newShader("multiple-shaders/shader1.fs")
    shader2 = love.graphics.newShader("multiple-shaders/shader2.fs")

    -- Add global effects to chain multiple shaders
    shove.addGlobalEffect(shader1)
    shove.addGlobalEffect(shader2)
  end

  function love.update(dt)
    time = (time + dt) % 1
    shader1:send("shift", 4 + math.cos(time * math.pi * 2) * 2)
    shader2:send("setting1", 40 + math.cos(love.timer.getTime() * 2) * 10)
  end

  function love.draw()
    shove.beginDraw()
      love.graphics.setBackgroundColor(0, 0, 0)
      love.graphics.draw(image, (gameWidth - image:getWidth()) * 0.5, (gameHeight - image:getHeight()) * 0.5)
    shove.endDraw()
  end
end
