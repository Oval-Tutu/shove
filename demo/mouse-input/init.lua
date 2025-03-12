return function()
  love.window.setMode(1280, 720, { resizable = true })
  shove.initResolution(800, 600, { fitMethod = "none", renderMode = "direct" })

  function love.load()
    love.mouse.setVisible(false)
    love.graphics.setNewFont(32)
  end

  function love.draw()
    local shoveWidth, shoveHeight = shove.getViewportDimensions()

    shove.beginDraw()
      love.graphics.setBackgroundColor(0, 0, 0)
      love.graphics.setColor(50, 0, 0)
      love.graphics.rectangle("fill", 0, 0, shoveWidth, shoveHeight)

      local isInside, mouseX, mouseY = shove.mouseToViewport()

      love.graphics.setColor(255, 255, 255)
      if isInside then
        love.graphics.circle("line", mouseX, mouseY, 10)
      end

      love.graphics.printf("mouse x : " .. (isInside and mouseX or "outside"), 25, 25, shoveWidth, "left")
      love.graphics.printf("mouse y : " .. (isInside and mouseY or "outside"), 25, 50, shoveWidth, "left")
    shove.endDraw()
  end
end
