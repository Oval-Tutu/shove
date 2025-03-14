return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    love.window.setMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    shove.initResolution(960, 540, { renderMode = "layer" })
    image = love.graphics.newImage("single-shader/love.png")
    shader = love.graphics.newShader("single-shader/shader.glsl")

    shove.createLayer("background", { zIndex = 10 })
    shove.createLayer("image", { zIndex = 20 })

    -- Add shader as a layer effect
    shove.addEffect("image", shader)
    time = 0
  end

  function love.update(dt)
    time = (time + dt) % 1
    shader:send("strength", 2 + math.cos(time * math.pi * 2) * 0.5)
  end

  function love.draw()
    shove.beginDraw()
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
      shove.endLayer()

      -- Will have the layer effect applied
      shove.beginLayer("image")
        love.graphics.draw(
          image,
          (shove.getViewportWidth() - image:getWidth()) * 0.5,
          (shove.getViewportHeight() - image:getHeight()) * 0.5
        )
      shove.endLayer()
    shove.endDraw()
  end
end
