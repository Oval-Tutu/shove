--[[ Multiple canvases and shaders ]]--

return function ()

  love.graphics.setDefaultFilter("linear", "linear") --default filter

  local gameWidth, gameHeight = 800, 600

  local windowWidth, windowHeight = love.window.getDesktopDimensions()
  windowWidth, windowHeight = windowWidth*.5, windowHeight*.5

  love.window.setMode(windowWidth, windowHeight, {fullscreen = false, highdpi = true, resizable = true})
  shove.setupScreen(gameWidth, gameHeight, { canvas = true })

  time = 0

  function love.load()
    image1 = love.graphics.newImage( "canvases-shaders/love1.png" )
    image2 = love.graphics.newImage( "canvases-shaders/love2.png" )

    shader1 = love.graphics.newShader("canvases-shaders/shader1.fs")
    shader2 = love.graphics.newShader("canvases-shaders/shader2.fs")

    shove.setupCanvas({
      { name = "shader", shader = shader1 }, --applied only to one canvas
      { name = "noshader" }
    })
    shove.setShader( shader2 ) --applied to final render
  end

  function love.update(dt)
    time = (time + dt) % 1

    shader1:send("shift", 4 + math.cos( time * math.pi * 2 ) * .5)
    shader2:send("time", love.timer.getTime())
  end

  function love.draw()
    shove.start()

    love.graphics.setColor(255, 255, 255)

    shove.setCanvas("shader")
    love.graphics.draw(image1, (gameWidth-image1:getWidth())*.5, (gameHeight-image1:getHeight())*.5 - 100) --global shader + canvas shader will be applied

    shove.setCanvas("noshader")
    love.graphics.draw(image2, (gameWidth-image2:getWidth())*.5, (gameHeight-image2:getHeight())*.5 + 100) --only global shader will be applied

    shove.finish()
  end

end
