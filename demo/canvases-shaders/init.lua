return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(960, 540, { renderMode = "layer" })
    shove.setWindowMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    image1 = love.graphics.newImage("canvases-shaders/love1.png")
    image2 = love.graphics.newImage("canvases-shaders/love2.png")
    shader1 = love.graphics.newShader("canvases-shaders/shader1.glsl")
    shader2 = love.graphics.newShader("canvases-shaders/shader2.glsl")

    -- Create layers
    shove.createLayer("background", { zIndex = 10 })
    shove.createLayer("image1", { zIndex = 20 })
    shove.createLayer("image2", { zIndex = 30 })
    -- Add effect to "image1" layer
    shove.addEffect("image1", shader1)
    -- Add global effect that will be applied to all layers
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
    shove.beginLayer("background")
    love.graphics.setBackgroundColor(0, 0, 0)
    shove.endLayer()

    --Draw image1 that will have layer and global effects applied
    shove.beginLayer("image1")
    love.graphics.draw(
      image1,
      (shove.getViewportWidth() - image1:getWidth()) * 0.5,
      (shove.getViewportHeight() - image1:getHeight()) * 0.5 - 100
    )
    shove.endLayer()

    -- Draw image2 that will only have global effects applied
    shove.beginLayer("image2")
    love.graphics.draw(
      image2,
      (shove.getViewportWidth() - image2:getWidth()) * 0.5,
      (shove.getViewportHeight() - image2:getHeight()) * 0.5 + 100
    )
    shove.endLayer()
    shove.endDraw()
    shove.handleDebugKeys()
  end
end
