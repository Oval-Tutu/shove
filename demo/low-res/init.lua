return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(64, 64, { fitMethod = "pixel", renderMode = "layer" })
    shove.setWindowMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    love.mouse.setVisible(false)
    love.graphics.setNewFont(16)
    image = love.graphics.newImage("low-res/image.png")
    shove.createLayer("background", { zIndex = 10 })
    shove.createLayer("animation", { zIndex = 20 })
    shove.createLayer("cursor", { zIndex = 30 })
    abs, pi, time = 0, 0, 0
    w = shove.getViewportWidth()
  end

  function love.update(dt)
    time = (time + dt) % 1
    abs = math.abs(time - 0.5)
    pi = math.cos(math.pi * 2 * time)
    w = shove.getViewportWidth()
  end

  function love.draw()
    shove.beginDraw()
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
        love.graphics.draw(image, 0, 0)
      shove.endLayer()

      shove.beginLayer("animation")
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.printf(
          "Hi!",
          31,
          23 - pi * 2,
          w,
          "center",
          -0.15 + 0.5 * abs,
          abs * 0.25 + 1,
          abs * 0.25 + 1,
          w * 0.5,
          12
        )
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(
          "Hi!",
          30,
          22 - pi * 2,
          w,
          "center",
          -0.15 + 0.5 * abs,
          abs * 0.25 + 1,
          abs * 0.25 + 1,
          w * 0.5,
          12
        )
      shove.endLayer()

      -- Check if mouse is within the game area
      local mouseInViewport, mouseX, mouseY = shove.mouseToViewport()
      if mouseInViewport then
        shove.showLayer("cursor")
      else
        shove.hideLayer("cursor")
      end

      shove.beginLayer("cursor")
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.printf("SHÖVE", 2, 48, w, "center")
        love.graphics.setColor(1, 1, 1)
        local cursorSize = 1
        love.graphics.rectangle("fill", mouseX - cursorSize, mouseY, cursorSize * 2 + 1, 1)
        love.graphics.rectangle("fill", mouseX, mouseY - cursorSize, 1, cursorSize * 2 + 1)
      shove.endLayer()
    shove.endDraw()
  end
end
