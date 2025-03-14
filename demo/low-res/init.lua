return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(64, 64, { fitMethod = "pixel", renderMode = "layer" })
    shove.setMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
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

      local insideViewport, mouseX, mouseY = shove.mouseToViewport()
      -- If outside the viewport hide the cursor layer
      -- Invisible layers do not get rendered
      shove.setLayerVisible("cursor", insideViewport)

      shove.beginLayer("cursor")
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.printf("LÖVE", 2, 48, w, "center")
        love.graphics.setColor(1, 1, 1)
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
      shove.endLayer()
    shove.endDraw()
    shove.debugHandler()
  end
end
