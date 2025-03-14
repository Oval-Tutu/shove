return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(960, 540, { fitMethod = "none", renderMode = "direct" })
    shove.setMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    love.mouse.setVisible(false)
    love.graphics.setNewFont(32)
  end

  function love.draw()
    local shoveWidth, shoveHeight = shove.getViewportDimensions()
    local mouseInViewport, mouseX, mouseY = shove.getMouseInViewport()
    local color = mouseInViewport and { 0, 1, 0, 0.5 } or { 1, 0, 0, 0.5 }
    shove.beginDraw()
      love.graphics.setBackgroundColor(0, 0, 0)
      love.graphics.setColor(color)
      love.graphics.rectangle("fill", 0, 0, shoveWidth, shoveHeight)
      love.graphics.setColor(1, 1, 1)
      if mouseInViewport then
        love.graphics.circle("line", mouseX, mouseY, 10)
      end
      love.graphics.printf("mouse x: " .. (mouseInViewport and mouseX or "outside"), 25, 25, shoveWidth, "left")
      love.graphics.printf("mouse y: " .. (mouseInViewport and mouseY or "outside"), 25, 55, shoveWidth, "left")
    shove.endDraw()
    shove.debugHandler()
  end
end
