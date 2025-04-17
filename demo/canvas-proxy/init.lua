return function()
  local userCanvas = nil
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(800, 600, { fitMethod = "none", renderMode = "direct" })
    shove.setWindowMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    userCanvas = love.graphics.newCanvas(200, 200)
  end

  function love.draw()
    -- Clear background
    love.graphics.clear(0.1, 0.1, 0.3)
    -- Begin Shöve's drawing context
    shove.beginDraw()
      love.graphics.clear(0, 0, 0)
      love.graphics.setColor(1, 1, 1)
      love.graphics.rectangle("line", 0, 0, 800, 600)
      -- Draw a red circle in the Shöve managed area
      love.graphics.setColor(1, 0, 0)
      love.graphics.circle("fill", 200, 150, 100)

      -- User manually changes canvas during Shöve's drawing cycle
      love.graphics.setCanvas(userCanvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.setColor(0, 1, 0)
      love.graphics.rectangle("fill", 50, 50, 100, 100)
      love.graphics.setCanvas() -- Reset to default

      -- This blue circle should now appear properly with our fix
      -- since the canvas state is properly restored
      love.graphics.setColor(0, 0, 1)
      love.graphics.circle("fill", 200, 150, 50)

      -- Add to draw function
      love.graphics.setColor(1, 1, 0)
      love.graphics.line(200, 0, 200, 600)  -- Vertical line at x=200
      love.graphics.line(0, 150, 800, 150)  -- Horizontal line at y=150

    -- End Shöve's drawing context
    shove.endDraw()

    -- Draw the user's canvas to screen directly (outside Shöve)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(userCanvas, 580, 10)

    -- Display explanation
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Red circle: Initial Shöve drawing", 10, 310)
    love.graphics.print("Green square: Rendered to user canvas", 10, 330)
    love.graphics.print("Blue circle: After canvas reset", 10, 350)

    local x, y = love.graphics.transformPoint(0, 0)
    print("Current transform origin:", x, y)
  end
end
