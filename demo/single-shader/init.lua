return function()
  local gameWidth, gameHeight = 1080, 720

  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth * 0.5, windowHeight * 0.5

  love.window.setMode(windowWidth, windowHeight, { resizable = true })
  shove.initResolution(gameWidth, gameHeight, { renderMode = "layer" })

  function love.load()
    time = 0
    image = love.graphics.newImage("single-shader/love.png")
    shader = love.graphics.newShader("single-shader/shader.fs")
    shove.createLayer("image")
    shove.addEffect("image", shader)
  end

  function love.update(dt)
    time = (time + dt) % 1
    shader:send("strength", 2 + math.cos(time * math.pi * 2) * 0.4)
  end

  function love.draw()
    shove.beginDraw()
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0, 0, 0)
      shove.endLayer()

      shove.beginLayer("image")
        love.graphics.draw(image, (gameWidth - image:getWidth()) * 0.5, (gameHeight - image:getHeight()) * 0.5)
      shove.endLayer()
    shove.endDraw()
  end
end
