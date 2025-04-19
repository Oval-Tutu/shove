return function()
  local userCanvas = nil
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(800, 600, { fitMethod = "none", renderMode = "direct" })
    shove.setWindowMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    love.graphics.setNewFont(16)
    userCanvas = love.graphics.newCanvas(200, 200)
  end

  function love.draw()
    -- Clear background with midnight blue
    love.graphics.clear(0.1, 0.1, 0.3)
    shove.beginDraw()
      -- Draw a black rectangle with a white outline as the background for the Shöve viewport
      love.graphics.clear(0, 0, 0)
      love.graphics.setColor(1, 1, 1)
      love.graphics.rectangle("line", 0, 0, 800, 600)

      -- Draw a red circle in the Shöve viewport
      love.graphics.setColor(1, 0, 0)
      love.graphics.circle("fill", 200, 150, 100)

      -- User manually changes canvas during Shöve's drawing cycle
      love.graphics.setCanvas(userCanvas)
      love.graphics.setColor(0, 1, 0)
      love.graphics.rectangle("fill", 50, 50, 100, 100)
      love.graphics.setCanvas()

      -- Draw a blue circle inside the red circle as the canvas state is now restored
      love.graphics.setColor(0, 0, 1)
      love.graphics.circle("fill", 200, 150, 50)

      -- Draw a yellow cross intersecting the circles
      love.graphics.setColor(1, 1, 0)
      love.graphics.line(200, 0, 200, 600)
      love.graphics.line(0, 150, 800, 150)
    shove.endDraw()

    -- Draw the user's canvas to screen directly (outside Shöve)
    love.graphics.draw(userCanvas, 580, 10)

    -- Display explanation
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Red circle: Initial Shöve drawing", 10, 10)
    love.graphics.print("Green square: Rendered to user canvas", 10, 30)
    love.graphics.print("Blue circle: After canvas reset", 10, 50)
  end
end
