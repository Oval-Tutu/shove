return function()
  local gameWidth, gameHeight = 64, 64

  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth * 0.5, windowHeight * 0.5

  love.window.setMode(windowWidth, windowHeight, { fullscreen = false, resizable = true })
  shove.initResolution(gameWidth, gameHeight, { fitMethod = "pixel" })

  -- Create layers
  shove.createLayer("main_canvas")
  shove.createLayer("stencil_canvas", {stencil = true})

  function love.load()
    time = 0
    love.graphics.setNewFont(32)
    background = love.graphics.newImage("low-res/image.png")
  end

  function love.update(dt)
    time = (time + dt) % 1
  end

  function love.draw()
    shove.beginDraw()
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
      shove.endLayer()
      shove.beginLayer("stencil_canvas")
        love.graphics.stencil(function()
          love.graphics.setColor(1, 1, 1)
          local time = love.timer.getTime() * 3
          love.graphics.circle(
            "fill",
            shove.getViewportWidth() * 0.5 + math.cos(time) * 20,
            shove.getViewportHeight() * 0.5 + math.sin(time) * 20,
            10 + math.sin(time) * 2
          )
        end, "replace", 1)

        -- Draw background with stencil
        love.graphics.setStencilTest("greater", 0)
        love.graphics.draw(background, 0, 0)
        love.graphics.setStencilTest()
      shove.endLayer()

      -- Draw cursor on a different layer
      shove.beginLayer("main_canvas")
        love.graphics.setColor(1, 1, 1)
        local insideViewport, mouseX, mouseY = shove.mouseToViewport()
        if insideViewport then
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
    shove.endDraw()
  end
end
