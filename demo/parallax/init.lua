return function()
  -- Parallax configuration
  local parallax = {
    layers = {},
    scrollAmplitude = 400,
    currentX = 0,            -- Current scroll position
    time = 0,                -- Time counter for scroll animation
    speed = 0.15
  }

  function love.load()
    -- Hide the mouse cursor
    love.mouse.setVisible(false)

    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    -- Use linear filtering for smooth scaling
    shove.setResolution(960, 540, { fitMethod = "aspect", renderMode = "layer", scalingFilter = "linear" })
    shove.setWindowMode(windowWidth * 0.5, windowHeight * 0.5, { fullscreen = false, resizable = true })

    -- Load layer images with adjusted depth values to ensure background has visible motion
    local layerImages = {
      { img = love.graphics.newImage("parallax/layer_01.png"), depth = 1.0, name = "layer_01" },   -- Foreground (moves the most)
      { img = love.graphics.newImage("parallax/layer_02.png"), depth = 0.9, name = "layer_02" },
      { img = love.graphics.newImage("parallax/layer_03.png"), depth = 0.8, name = "layer_03" },
      { img = love.graphics.newImage("parallax/layer_04.png"), depth = 0.65, name = "layer_04" },  -- Middle layer
      { img = love.graphics.newImage("parallax/layer_05.png"), depth = 0.5, name = "layer_05" },
      { img = love.graphics.newImage("parallax/layer_06.png"), depth = 0.35, name = "layer_06" },  -- Background has more movement now
      { img = love.graphics.newImage("parallax/layer_07.png"), depth = 0.2, name = "layer_07" }    -- Even the farthest background moves visibly
    }

    -- Get viewport dimensions
    local viewportWidth = shove.getViewportWidth()
    local viewportHeight = shove.getViewportHeight()

    -- Calculate scaling factors for each layer
    for i, layer in ipairs(layerImages) do
      local imgWidth, imgHeight = layer.img:getDimensions()

      -- Calculate scaling factor to properly fit within the viewport
      local scaleX = viewportWidth / imgWidth
      local scaleY = viewportHeight / imgHeight

      -- Use exact scaling for smooth appearance
      local scale = math.max(scaleX, scaleY) * 1.2

      -- Store layer data
      parallax.layers[i] = {
        img = layer.img,
        depth = layer.depth,
        name = layer.name,
        scale = scale,
        zIndex = 90 - (i * 10) -- Higher z-index for foreground layers
      }

      -- Create the layer
      shove.createLayer(layer.name, {zIndex = parallax.layers[i].zIndex})
    end

    -- Create background layer
    shove.createLayer("background", {zIndex = 5})
  end

  function love.update(dt)
    -- Update time counter
    parallax.time = parallax.time + dt

    -- Smooth sine wave scrolling animation
    parallax.currentX = math.sin(parallax.time * parallax.speed) * parallax.scrollAmplitude
  end

  -- This is deliberately not the optimised way to do this
  -- but it's a good way to demonstrate layer batching
  function love.draw()
    shove.beginDraw()
      -- Draw solid background
      shove.beginLayer("background")
        love.graphics.setBackgroundColor(0.1, 0.1, 0.15, 1)
        love.graphics.clear()
      shove.endLayer()

      -- Draw each parallax layer
      for i, layer in ipairs(parallax.layers) do
        shove.beginLayer(layer.name)
          -- Calculate parallax offset based on depth
          -- Allow sub-pixel movement for smoother animation
          local offsetX = parallax.currentX * layer.depth

          -- Get viewport dimensions
          local viewportWidth = shove.getViewportWidth()
          local viewportHeight = shove.getViewportHeight()

          -- Get scaled image dimensions
          local imgWidth = layer.img:getWidth() * layer.scale
          local imgHeight = layer.img:getHeight() * layer.scale

          -- Position Y so the bottom of the image aligns with bottom of viewport
          local posY = viewportHeight - imgHeight

          -- Calculate how many copies we need to cover viewport width plus scrolling range
          local totalWidthNeeded = viewportWidth + parallax.scrollAmplitude * 2 * layer.depth
          local copiesNeeded = math.ceil(totalWidthNeeded / imgWidth) + 1 -- Add one extra for safety

          -- Calculate starting X position to ensure smooth wrapping
          -- Use modulo to create repeating pattern with sub-pixel precision
          local baseX = offsetX % imgWidth

          -- Draw repeated copies of the image horizontally
          for j = 0, copiesNeeded do
            -- Allow sub-pixel positioning for smoother motion
            local drawX = baseX - imgWidth + (j * imgWidth)

            love.graphics.draw(
              layer.img,
              drawX,
              posY,
              0,
              layer.scale,
              layer.scale
            )
          end
        shove.endLayer()
      end
    shove.endDraw()
  end
end
