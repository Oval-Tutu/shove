return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(960, 540, { renderMode = "layer" })
    shove.setWindowMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    image = love.graphics.newImage("multiple-shaders/love.png")
    shader1 = love.graphics.newShader("multiple-shaders/shader1.glsl")
    shader2 = love.graphics.newShader("multiple-shaders/shader2.glsl")

    -- Add global effects to chain multiple shaders
    shove.addGlobalEffect(shader1)
    shove.addGlobalEffect(shader2)
    time = 0
  end

  function love.update(dt)
    time = (time + dt) % 1
    shader1:send("shift", 4 + math.cos(time * math.pi * 2) * 2)
    shader2:send("setting1", 40 + math.cos(love.timer.getTime() * 2) * 10)
  end

  function love.draw()
    shove.beginDraw()
      love.graphics.setBackgroundColor(0, 0, 0)
      love.graphics.draw(
        image,
        (shove.getViewportWidth() - image:getWidth()) * 0.5,
        (shove.getViewportHeight() - image:getHeight()) * 0.5
      )
    shove.endDraw()
  end
end
