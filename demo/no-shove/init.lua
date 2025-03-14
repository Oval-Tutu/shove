return function()
  function love.load()
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    love.window.setMode(windowWidth * 0.5, windowHeight * 0.5, {
      fullscreen = false,
      resizable = true
    })
    love.mouse.setVisible(false)
    love.graphics.setNewFont(16)
    love.graphics.setDefaultFilter("nearest", "nearest")
    image = love.graphics.newImage("low-res/image.png")

    gameWidth, gameHeight = 64, 64
    gameCanvas = love.graphics.newCanvas(gameWidth, gameHeight)
    gameCanvas:setFilter("nearest", "nearest")

    abs, pi, time = 0, 0, 0
    w = gameWidth
  end

  function love.update(dt)
    time = (time + dt) % 1
    abs = math.abs(time - 0.5)
    pi = math.cos(math.pi * 2 * time)
  end

  function calculateIntegerScale()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local scaleX = windowWidth / gameWidth
    local scaleY = windowHeight / gameHeight
    local scale = math.min(scaleX, scaleY)
    return math.max(1, math.floor(scale))
  end

  function love.draw()
    -- Draw everything to our low-resolution canvas
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0, 0, 0)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, 0, 0)

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.printf(
      "Hi!",
      31,
      23 - pi * 2,
      w,
      "center",
      -0.15 + 0.5 * abs,
      abs * 0.25 + 1,
      abs * 0.25 + 1,
      w * 0.5,
      12
    )
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(
      "Hi!",
      30,
      22 - pi * 2,
      w,
      "center",
      -0.15 + 0.5 * abs,
      abs * 0.25 + 1,
      abs * 0.25 + 1,
      w * 0.5,
      12
    )

    -- Calculate scaling and position for the canvas
    local scale = calculateIntegerScale()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local offsetX = math.floor((windowWidth - (gameWidth * scale)) / 2)
    local offsetY = math.floor((windowHeight - (gameHeight * scale)) / 2)

    -- Convert mouse position to game coordinates
    local mouseX, mouseY = love.mouse.getPosition()
    local gameMouseX = math.floor((mouseX - offsetX) / scale)
    local gameMouseY = math.floor((mouseY - offsetY) / scale)

    -- Check if mouse is within the game area
    local isMouseInGame = gameMouseX >= 0 and gameMouseX < gameWidth and
                         gameMouseY >= 0 and gameMouseY < gameHeight
    if isMouseInGame then
      love.graphics.setColor(0, 0, 0, 0.85)
      love.graphics.printf("LÖVE", 2, 48, w, "center")
      love.graphics.setColor(1, 1, 1)
      local cursorSize = 1
      love.graphics.rectangle("fill", gameMouseX - cursorSize, gameMouseY, cursorSize * 2 + 1, 1)
      love.graphics.rectangle("fill", gameMouseX, gameMouseY - cursorSize, 1, cursorSize * 2 + 1)
    end

    -- Reset canvas and draw the game canvas scaled to the screen
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, offsetX, offsetY, 0, scale, scale)
  end
end
