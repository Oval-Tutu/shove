return function()
  love.graphics.setDefaultFilter("linear", "linear")

  local gameWidth, gameHeight = 1080, 720

  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth * 0.5, windowHeight * 0.5

  love.window.setMode(windowWidth, windowHeight, { resizable = true })
  shove.setupScreen(gameWidth, gameHeight, { canvas = true })

  function love.load()
    time = 0
    image = love.graphics.newImage("single-shader/love.png")
    shader = love.graphics.newShader("single-shader/shader.fs")
    shove.setShader(shader)
  end

  function love.update(dt)
    time = (time + dt) % 1
    shader:send("strength", 2 + math.cos(time * math.pi * 2) * 0.4)
  end

  function love.draw()
    shove.start()
      love.graphics.setColor(255, 255, 255)
      love.graphics.draw(image, (gameWidth - image:getWidth()) * 0.5, (gameHeight - image:getHeight()) * 0.5)
    shove.finish()
  end
end
