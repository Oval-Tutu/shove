return function()
  -- LÖVE resolution 640x480, resizable
  love.window.setMode(640, 480, { resizable = true })
  -- shove resolution 64x64, pixel perfect scaling, drawn to a canvas
  shove.setupScreen(64, 64, { scaler = "pixel", scaler_mode = "canvas" })

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
    shove.start()
      local mouseX, mouseY = love.mouse.getPosition()
      -- If false is returned, that means the mouse is outside the game screen
      mouseX, mouseY = shove.toGame(mouseX, mouseY)

      local abs = math.abs(time - 0.5)
      local pi = math.cos(math.pi * 2 * time)
      local w = shove.getWidth()
      --for animating basic stuff

      love.graphics.draw(image, 0, 0)

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

      love.graphics.setColor(1, 1, 1)
      --cursor
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
    shove.finish()
  end
end
