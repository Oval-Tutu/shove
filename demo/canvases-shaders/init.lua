return function()
  local gameWidth, gameHeight = 800, 600
  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth * 0.5, windowHeight * 0.5
  love.window.setMode(windowWidth, windowHeight, { fullscreen = false, highdpi = true, resizable = true })
  shove.initResolution(gameWidth, gameHeight, { renderMode = "layer" })

  function love.load()
    time = 0
    image1 = love.graphics.newImage("canvases-shaders/love1.png")
    image2 = love.graphics.newImage("canvases-shaders/love2.png")
    shader1 = love.graphics.newShader("canvases-shaders/shader1.fs")
    shader2 = love.graphics.newShader("canvases-shaders/shader2.fs")

    -- Create layers
    shove.createLayer("image1")
    shove.createLayer("image2")

    -- Add effect to "image1" layer
    shove.addEffect("image1", shader1)

    -- Add global effect that will be applied to all layers
    shove.addGlobalEffect(shader2)
  end

  function love.update(dt)
    time = (time + dt) % 1
    shader1:send("shift", 4 + math.cos(time * math.pi * 2) * 0.5)
    shader2:send("time", love.timer.getTime())
  end

  function love.draw()
    shove.beginDraw()
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
      shove.endLayer()

      --Draw image1 that will have global and layer effects applied
      shove.beginLayer("image1")
        love.graphics.draw(image1, (gameWidth - image1:getWidth()) * 0.5, (gameHeight - image1:getHeight()) * 0.5 - 100)
      shove.endLayer()

      -- Draw image2 that will only have global effects applied
      shove.beginLayer("image2")
        love.graphics.draw(image2, (gameWidth - image2:getWidth()) * 0.5, (gameHeight - image2:getHeight()) * 0.5 + 100)
      shove.endLayer()
    shove.endDraw()
  end
end
