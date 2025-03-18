return function()
  -- Parallax configuration
  local parallax = {
    layers = {},
    scrollAmplitude = 600,
    currentX = 0,            -- Current scroll position
    time = 0,                -- Time counter for scroll animation
    speed = 0.15
  }

  -- Sparkle particle system
  local particles = {
    systems = {},       -- Multiple particle systems for varied effects
    texture = nil,
    count = 384,
    layer = "sparkles", -- Layer name for particles
    emitters = 3        -- Number of different emitter behaviors
  }

  -- Create a particle texture (small white circle with soft edges)
  local function createParticleTexture()
    local size = 16
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    -- Draw a soft white circle with gradient transparency
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")

    -- Draw several circles with decreasing size and alpha to create a soft glow
    for radius = size/2, 1, -2 do
      local alpha = radius/(size/2)
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.circle("fill", size/2, size/2, radius)
    end

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha", "alphamultiply")

    return canvas
  end

  -- Initialize the particle systems with different behaviors
  local function initParticleSystems()
    -- Create the particle texture
    particles.texture = createParticleTexture()

    -- Get viewport dimensions for positioning
    local viewportWidth = shove.getViewportWidth()
    local viewportHeight = shove.getViewportHeight()

    -- Create first particle system - floating upward sparkles
    local system1 = love.graphics.newParticleSystem(particles.texture, particles.count)
    system1:setParticleLifetime(1, 3)
    system1:setEmissionRate(30)
    system1:setSizeVariation(1)
    system1:setLinearAcceleration(-5, -10, 5, -30)
    system1:setColors(
      1, 1, 1, 0,       -- Start transparent
      1, 1, 0.8, 0.7,   -- Mid yellow-white
      0.9, 0.9, 1, 0.5, -- Light blue hint
      1, 1, 1, 0        -- End transparent
    )
    system1:setSizes(0.1, 0.3, 0.2, 0.1)
    system1:setRotation(0, math.pi*2)
    system1:setSpeed(10, 40)
    -- Emit from random positions across entire viewport
    system1:setEmissionArea("uniform", viewportWidth, viewportHeight/2)
    system1:setPosition(viewportWidth/2, viewportHeight * 0.75)

    -- Create second particle system - horizontal swirling sparkles
    local system2 = love.graphics.newParticleSystem(particles.texture, particles.count)
    system2:setParticleLifetime(2, 5)
    system2:setEmissionRate(20)
    system2:setSizeVariation(0.8)
    -- Create circular motion
    system2:setTangentialAcceleration(20, 50)
    system2:setRadialAcceleration(-10, 10)
    system2:setColors(
      0.9, 0.9, 1, 0,     -- Start transparent blue
      1, 0.8, 0.5, 0.6,    -- Mid gold
      0.8, 1, 0.8, 0.4,    -- Light green
      1, 1, 1, 0           -- End transparent
    )
    system2:setSizes(0.2, 0.4, 0.3, 0.1)
    system2:setRotation(0, math.pi*4)
    system2:setSpeed(5, 20)
    -- Emit across the middle of the screen
    system2:setEmissionArea("uniform", viewportWidth * 0.8, viewportHeight * 0.5)
    system2:setPosition(viewportWidth/2, viewportHeight/2)

    -- Create third particle system - random dancing sparkles
    local system3 = love.graphics.newParticleSystem(particles.texture, particles.count)
    system3:setParticleLifetime(1, 4)
    system3:setEmissionRate(15)
    system3:setSizeVariation(0.9)
    -- Random directions with slight upward bias
    system3:setLinearDamping(0.5, 1)
    system3:setColors(
      1, 0.7, 0.7, 0,     -- Start transparent pink
      1, 1, 0.9, 0.8,      -- Bright yellow-white
      0.7, 0.8, 1, 0.6,    -- Light blue
      1, 1, 1, 0           -- End transparent
    )
    system3:setSizes(0.1, 0.5, 0.3, 0.1)
    system3:setRotation(0, math.pi*8)
    system3:setLinearAcceleration(-20, -5, 20, 5)
    system3:setSpeed(10, 30)
    -- Emit in random bursts throughout the screen
    system3:setEmissionArea("uniform", viewportWidth * 0.9, viewportHeight * 0.8)
    system3:setPosition(viewportWidth/2, viewportHeight/2)

    -- Store all systems
    particles.systems = {system1, system2, system3}

    -- Register with Shove profiler
    if shove.profiler and shove.profiler.registerParticleSystem then
      for _, system in ipairs(particles.systems) do
        shove.profiler.registerParticleSystem(system)
      end
    end

    return particles.systems
  end

  function love.load()
    -- Hide the mouse cursor
    love.mouse.setVisible(false)

    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    -- Use linear filtering for smooth scaling
    shove.setResolution(1920, 1080, { fitMethod = "aspect", renderMode = "layer", scalingFilter = "linear" })
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

    -- Create sparkles layer with highest z-index (in front of all other layers)
    shove.createLayer(particles.layer, { zIndex = 100 })

    -- Initialize particle systems with different behaviors
    initParticleSystems()

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

    -- Update all particle systems
    for i, system in ipairs(particles.systems) do
      system:update(dt)

      -- Add some dynamic movement to particle emitters based on parallax
      local viewportWidth = shove.getViewportWidth()
      local viewportHeight = shove.getViewportHeight()

      -- Different movement patterns for each system
      if i == 1 then
        -- First system follows the parallax movement
        local offsetX = parallax.currentX * 0.1
        system:setPosition(viewportWidth/2 + offsetX, viewportHeight * 0.75)
      elseif i == 2 then
        -- Second system moves in a circular pattern
        local angle = parallax.time * 0.2
        local radius = viewportWidth * 0.2
        local centerX = viewportWidth/2 + math.sin(angle) * radius
        local centerY = viewportHeight/2 + math.cos(angle) * radius
        system:setPosition(centerX, centerY)
      elseif i == 3 then
        -- Third system moves in a figure-8 pattern
        local t = parallax.time * 0.3
        local scale = viewportWidth * 0.15
        local centerX = viewportWidth/2 + math.sin(t) * scale
        local centerY = viewportHeight/2 + math.sin(t * 2) * scale / 2
        system:setPosition(centerX, centerY)
      end
    end
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

      -- Draw sparkles layer on top of everything
      shove.beginLayer(particles.layer)
        -- Use additive blending for a glowing effect
        love.graphics.setBlendMode("add")

        -- Draw all particle systems
        for _, system in ipairs(particles.systems) do
          love.graphics.draw(system, 0, 0)
        end

        -- Reset blend mode
        love.graphics.setBlendMode("alpha")
      shove.endLayer()
    shove.endDraw()
  end
end
