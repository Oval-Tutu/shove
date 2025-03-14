return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    shove.setResolution(960, 540, { fitMethod = "aspect", renderMode = "layer" })
    shove.setWindowMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })
    nogame = love.graphics.newImage("stencil/nogame.png")

    shove.createLayer("background", { zIndex = 10 })
    -- If you want to use manually use the stencil buffer in a layer then
    -- create the layer with stencil flag set before calling beginLayer
    shove.createLayer("stencil", { stencil = true }, { zIndex = 20 })
    shove.createLayer("cursor", { zIndex = 30 })
  end

  function love.draw()
    shove.beginDraw()
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
      shove.endLayer()

      shove.beginLayer("stencil")
        love.graphics.stencil(function()
          love.graphics.setColor(1, 1, 1)
          local time = love.timer.getTime() * 1.5
          love.graphics.circle(
            "fill",
            shove.getViewportWidth() * 0.5 + math.cos(time) * 320,
            shove.getViewportHeight() * 0.5 + math.sin(time) * 50,
            150 + math.sin(time) * 64
          )
        end, "replace", 1)

        -- Draw background with stencil mask
        love.graphics.setStencilTest("greater", 0)
        love.graphics.draw(nogame, 0, 0)
        love.graphics.setStencilTest()
      shove.endLayer()

      local mouseInViewport, mouseX, mouseY = shove.mouseToViewport()
      -- If outside the viewport hide the cursor layer
      -- Invisible layers do not get rendered
      if mouseInViewport then
        shove.showLayer("cursor")
      else
        shove.hideLayer("cursor")
      end

      shove.beginLayer("cursor")
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", mouseX, mouseY, 16)
      shove.endLayer()
    shove.endDraw()
    shove.handleDebugKeys()
  end
end
