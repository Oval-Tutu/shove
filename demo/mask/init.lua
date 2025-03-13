return function()
  local gameWidth, gameHeight = 64, 64

  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth * 0.5, windowHeight * 0.5

  love.window.setMode(windowWidth, windowHeight, { fullscreen = false, resizable = true })
  shove.initResolution(gameWidth, gameHeight, { fitMethod = "pixel", renderMode = "layer" })

  function love.load()
    time = 0
    love.graphics.setNewFont(32)
    background = love.graphics.newImage("low-res/image.png")
  end

  function love.update(dt)
    time = (time + dt) % 1
  end

  function love.draw()
    shove.beginDraw()
      -- Draw a black background layer
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
      shove.endLayer()

      -- Draw our mask (a square that moves around in a circular pattern)
      shove.beginLayer("mask_layer", { stencil = true })
        love.graphics.setColor(1, 1, 1)
        local time = love.timer.getTime() * 3
        local centerX = shove.getViewportWidth() * 0.5 + math.cos(time) * 20
        local centerY = shove.getViewportHeight() * 0.5 + math.sin(time) * 20
        local size = 20 + math.sin(time) * 4  -- Size that varies over time
        love.graphics.rectangle("fill", centerX - size/2, centerY - size/2, size, size)
      shove.endLayer()

      -- Set the mask layer for content
      shove.setLayerMask("content_layer", "mask_layer")

      -- Draw content that will be masked
      shove.beginLayer("content_layer")
        love.graphics.draw(background, 0, 0)
      shove.endLayer()

      -- Draw cursor on a different layer
      shove.beginLayer("cursor_layer", { zIndex = 100 })
        love.graphics.setColor(1, 1, 1)
        local insideViewport, mouseX, mouseY = shove.mouseToViewport()
        if insideViewport then
          love.graphics.points(
            mouseX,
            mouseY - 1,
            mouseX - 1,
            mouseY,
            mouseX,
            mouseY,
            mouseX + 1,
            mouseY,
            mouseX,
            mouseY + 1
          )
        end
      shove.endLayer()
    shove.endDraw()
  end
end
