return function()
  -- LÖVE resolution 640x480, resizable
  love.window.setMode(640, 480, { resizable = true })
  -- shove resolution 64x64, pixel perfect scaling, drawn to a canvas
  shove.initResolution(64, 64, { fitMethod = "pixel", renderMode = "layer" })

  function love.load()
    time = 0
    love.mouse.setVisible(false)
    love.graphics.setNewFont(16)
    image = love.graphics.newImage("low-res/image.png")
  end

  function love.update(dt)
    time = (time + dt) % 1
  end

  function love.draw()
    shove.beginDraw()
      love.graphics.setBackgroundColor(0, 0, 0)
      -- Draw background image
      shove.beginLayer("image")
        love.graphics.draw(image, 0, 0)
      shove.endLayer()

      -- Animated "Hi!" text
      local abs = math.abs(time - 0.5)
      local pi = math.cos(math.pi * 2 * time)
      local w = shove.getViewportWidth()
      shove.beginLayer("animation")
        love.graphics.setColor(0, 0, 0, 0.5)
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

      -- Draw cursor
      local insideViewport, mouseX, mouseY = shove.mouseToViewport()
      if insideViewport then
        shove.beginLayer("cursor")
          love.graphics.setColor(1, 1, 1)
          if mouseX and mouseY then
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
      end
    shove.endDraw()
  end
end
