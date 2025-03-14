return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(960, 540, { fitMethod = "aspect", renderMode = "layer" })
    shove.setMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    love.mouse.setVisible(false)
    nogame = love.graphics.newImage("mask/nogame.png")
    shove.createLayer("background", { zIndex = 10})
    shove.createLayer("image_mask")
    shove.createLayer("image", { zIndex = 20})
    shove.createLayer("cursor", { zIndex = 30})

    -- Set the mask for the image
    shove.setLayerMask("image", "image_mask")
  end

  function love.draw()
    shove.beginDraw()
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
      shove.endLayer()

      -- Create a mask layer
      shove.beginLayer("image_mask")
        love.graphics.setColor(1, 1, 1)
        local time = love.timer.getTime() * 1.5
        local centerX = shove.getViewportWidth() * 0.5 + math.cos(time) * 325
        local centerY = shove.getViewportHeight() * 0.5 + math.sin(time) * 90
        local size = 300 + math.sin(time) * 64
        love.graphics.rectangle("fill", centerX - size / 2, centerY - size / 2, size, size)
      shove.endLayer()

      -- Draw the image that will now be masked
      shove.beginLayer("image")
        love.graphics.draw(nogame, 0, 0)
      shove.endLayer()

      local insideViewport, mouseX, mouseY = shove.mouseToViewport()
      -- If outside the viewport hide the cursor layer
      -- Invisible layers do not get rendered
      shove.setLayerVisible("cursor", insideViewport)

      shove.beginLayer("cursor")
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", mouseX - 24, mouseY - 24, 24, 24)
      shove.endLayer()
    shove.endDraw()
    shove.debugHandler()
  end
end
