return function()
  love.graphics.setDefaultFilter("linear", "linear")
  love.window.setMode(1280, 720, { resizable = true })
  shove.setupScreen(800, 600, { canvas = true })

  function love.load()
    love.mouse.setVisible(false)
    love.graphics.setNewFont(32)
  end

  function love.draw()
    local shoveWidth, shoveHeight = shove.getDimensions()

    shove.start()
      love.graphics.setColor(50, 0, 0)
      love.graphics.rectangle("fill", 0, 0, shoveWidth, shoveHeight)

      local mouseX, mouseY = love.mouse.getPosition()
      -- false is returned if mouse is outside the game screen
      mouseX, mouseY = shove.toGame(mouseX, mouseY)
      -- Good practice to floor returned values when simulating screen pixels
      if mouseX then
        mouseX = math.floor(mouseX)
      end
      if mouseY then
        mouseY = math.floor(mouseY)
      end

      love.graphics.setColor(255, 255, 255)
      if mouseX and mouseY then
        love.graphics.circle("line", mouseX, mouseY, 10)
      end

      love.graphics.printf("mouse x : " .. (mouseX or "outside"), 25, 25, shoveWidth, "left")
      love.graphics.printf("mouse y : " .. (mouseY or "outside"), 25, 50, shoveWidth, "left")
    shove.finish()
  end
end
