return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    love.window.setMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    love.mouse.setVisible(false)
    shove.initResolution(960, 540, { fitMethod = "none", renderMode = "direct" })
    love.graphics.setNewFont(32)
  end

  function love.draw()
    local shoveWidth, shoveHeight = shove.getViewportDimensions()
    local isMouseInside, mouseX, mouseY = shove.mouseToViewport()
    local color = isMouseInside and { 0, 1, 0, 0.5 } or { 1, 0, 0, 0.5 }
    shove.beginDraw()
      love.graphics.setBackgroundColor(0, 0, 0)
      love.graphics.setColor(color)
      love.graphics.rectangle("fill", 0, 0, shoveWidth, shoveHeight)
      love.graphics.setColor(1, 1, 1)
      if isMouseInside then
        love.graphics.circle("line", mouseX, mouseY, 10)
      end
      love.graphics.printf("mouse x: " .. (isMouseInside and mouseX or "outside"), 25, 25, shoveWidth, "left")
      love.graphics.printf("mouse y: " .. (isMouseInside and mouseY or "outside"), 25, 50, shoveWidth, "left")
    shove.endDraw()
    shove.debugHandler()
  end
end
