--[[ Shader usage ]]--

return function ()

  love.graphics.setDefaultFilter("linear", "linear") --default filter

  local gameWidth, gameHeight = 1080, 720

  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth*.5, windowHeight*.5

  love.window.setMode(windowWidth, windowHeight, {resizable = true})
  shove.setupScreen(gameWidth, gameHeight, {
    upscale = "normal",
    canvas = true
  })

  time = 0

  function love.load()
    image = love.graphics.newImage( "single-shader/love.png" )

    shader = love.graphics.newShader("single-shader/shader.fs")
    shove.setShader( shader )
  end

  function love.update(dt)
    time = (time + dt) % 1
    shader:send("strength", 2 + math.cos(time * math.pi * 2) * .4)
  end

  function love.draw()
    shove.start()

    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(image, (gameWidth-image:getWidth())*.5, (gameHeight-image:getHeight())*.5)

    shove.finish()
  end

end
