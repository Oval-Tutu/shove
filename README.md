# Shöve 📐
Shöve is a simple resolution-handling library for [LÖVE](https://love2d.org/) that allows you to focus on making your game with a fixed resolution.
It is forked from from the [push](https://github.com/Ulydev/push) `dev` branch, includes community contributed fixes 🩹 with additional features and API changes from the team at [Oval Tutu](https://oval-tutu.com) 🩰

## Quick start

This example creates a 1920x1080 resizable window and sets Shöve to a scaled resolution.
Under the "Draw stuff here!" comment, add some drawing functions to see Shöve in action!
```lua
shove = require("shove")

-- Resizable 1920x1080 window
love.window.setMode(1920, 1080, {resizable = true})
-- 1920x1080 game resolution, scaled
shove.initResolution(1920, 1080, {scaler = "aspect"})

-- Make sure shove follows LÖVE's resizes
function love.resize(width, height)
  shove.resize(width, height)
end

function love.draw()
  shove.startDraw()
    -- Draw stuff here!
  shove.stopDraw()
end
```

### Demo

Run `love demo/` to view all the demos.
Press <kbd>SPACE</kbd> to switch between them.

## Usage

After applying changes to LÖVE's window using `love.window.setMode()`, initialise Shöve:
```lua
shove.initResolution(gameWidth, gameHeight, {scaler = ..., scaler_mode = ...})
```
`gameWidth` and `gameHeight` represent Shöve's fixed game resolution.

The last argument is a table containing settings for Shöve:
* `fitMethod` (string): select Shöve's fit method
  * `"aspect"`: preserve aspect ratio (*default*)
  * `"pixel"`: pixel-perfect scaling, applies nearest-neighbor filtering
  * `"stretch"`: stretch to the current window size
  * `"none"`: no scaling
* `renderMode` (string): select the rendering method
  * `"direct"`: uses `love.graphics.translate()` and `love.graphics.scale()` (*default*)
  * `"buffer"`: uses `love.graphics.setCanvas()`

Hook Shöve into the `love.resize()` function so that it follows LÖVE's resizes:
```lua
function love.resize(width, height)
  shove.resize(width, height)
end
```

Finally, apply Shöve transforms:
```lua
function love.draw()
  shove.startDraw()
    -- Draw stuff here!
  shove.stopDraw()
end
```

## Multiple shaders

Any method that takes a shader as an argument can also take a *table* of shaders instead.
The shaders will be applied in the order they're provided.

Set multiple global shaders
```lua
shove.setShader({ shader1, shader2 })
```

Set multiple canvas-specific shaders
```lua
shove.setupCanvas({{name = "multiple_shaders", shader = {shader1, shader2}}})
```

## Advanced canvases/shaders
Shöve provides basic canvas and shader functionality through the `scaler_mode` setting in `shove.initResolution()` and `shove.setShader()`, but you can also create additional canvases, name them for later use and apply multiple shaders to them.

Set up custom canvases:
```lua
shove.setupCanvas(canvasList)

-- e.g. shove.setupCanvas({{name = "foreground", shader = foregroundShader}, {name = "background"}})
```

Shaders can be passed to canvases directly through `shove.setupCanvas()`, or you can choose to set them later.
```lua
shove.setShader(canvasName, shader)
```

Then, you just need to draw your game on different canvases like you'd do with `love.graphics.setCanvas()`:
```lua
shove.setCanvas(canvasName)
```

## Misc
Update settings:
```lua
shove.updateSettings({settings})
```

Set a post-processing shader (will apply to the whole screen):
```lua
shove.setShader([canvasName], shader)
```
You don't need to call this every frame.
Simply call it once, and it will be stored into Shöve until you change it back to something else.
If no `canvasName` is passed, shader will apply to the final render.
Use it at your advantage to combine shader effects.

Convert coordinates:
```lua
 -- Convert coordinates from screen to game viewport
shove.toViewport(x, y)

 -- Convert coordinates from game viewport to screen coordinates
shove.toScreen(x, y)
```

Get game dimensions:
```lua
-- Returns game width
shove.getViewportWidth()

-- Returns game height
shove.getViewportHeight()

-- Returns shove.getGameWidth(), shove.getGameHeight()
shove.getViewportDimensions()

-- Returns the game viewport rectangle in window/screen coordinates (x, y, width, height)
shove.getViewport()

-- Returns true is if window coordinates are within the game viewport
shove.inViewport(x, y)
```

# Layer-Based Rendering in Shove

## Overview

Shove's layer-based rendering provides an intuitive way to organize your game's graphics into separate drawing surfaces that can be manipulated independently before being combined into the final image.

## Basic Layer Rendering

### Drawing to Layers

```lua
-- Start the drawing process
shove.beginDraw()

  -- Draw to a specific layer
  shove.beginLayer("background")
    love.graphics.clear(0.1, 0.2, 0.3)
    love.graphics.draw(backgroundImage, 0, 0)
  shove.endLayer()

  -- Draw to another layer
  shove.beginLayer("entities")
    for _, entity in ipairs(entities) do
      entity:draw()
    end
  shove.endLayer()

  -- Draw to a UI layer
  shove.beginLayer("ui")
    drawUI()
  shove.endLayer()

-- End drawing and composite all layers
shove.endDraw()
```

### Drawing Helper Functions

You can also use the `drawToLayer` helper function for a more functional approach:

```lua
shove.beginDraw()

  -- Draw background
  shove.drawToLayer("background", function()
    love.graphics.clear(0.1, 0.2, 0.3)
    love.graphics.draw(backgroundImage, 0, 0)
  end)

  -- Draw entities
  shove.drawToLayer("entities", function()
    for _, entity in ipairs(entities) do
      entity:draw()
    end
  end)

shove.endDraw()
```

Draw directly to a layer with a callback function:

```lua
shove.drawToLayer("ui", function()
  -- UI drawing operations
end)
```

Manually composite and draw layers at any point
```lua
shove.compositeAndDraw([globalEffects])
```

## Advanced Features

### Layer Compositing

You can manually trigger layer compositing at any point:

```lua
shove.beginDraw()
  -- Draw layers...

  -- Composite and draw current state to screen
  shove.compositeAndDraw()

  -- Continue drawing more layers...
shove.endDraw()
```

### Layer Effects (Shaders)

Apply effects to specific layers:

```lua
-- Setup a blur shader for the background
shove.setLayerEffects("background", blurShader)

-- Add bloom effect to the entities layer
shove.addLayerEffect("entities", bloomShader)
```

### Layer Masking

Use one layer as a mask for another:

```lua
-- Create a mask layer
shove.beginDraw()
  shove.beginLayer("mask")
    drawMaskElements()
  shove.endLayer()

  -- Set "mask" as a stencil for "content"
  shove.setLayerMask("content", "mask")

  shove.beginLayer("content")
    -- This will only be visible where the mask is
    drawContent()
  shove.endLayer()
shove.endDraw()
```

## Using with Legacy Code
If you're transitioning from older code, the legacy functions still work:

```lua
shove.startDraw()
  shove.setCanvas("layer1")
  -- drawing operations

  shove.setCanvas("layer2")
  -- more drawing operations
shove.stopDraw()
```

This code will automatically work with the layer system, with each canvas name becoming a layer.


# Effect System in Shove

## Overview

Shove's Effect System allows you to apply and chain shader effects to both individual layers and the final composited output.

## Basic Usage

### Adding Effects to Layers

```lua
-- Create a layer
shove.createLayer("background")

-- Add an effect (shader)
local waveShader = love.graphics.newShader("wave.glsl")
shove.addEffect("background", waveShader)

-- Add another effect to the same layer (chaining)
local blurShader = love.graphics.newShader("blur.glsl")
shove.addEffect("background", blurShader)

### Managing Effects

```lua
-- Remove a specific effect
shove.removeEffect("background", waveShader)

-- Clear all effects from a layer
shove.clearEffects("background")

-- Set multiple effects at once (replaces existing ones)
shove.setLayerEffects("background", {waveShader, blurShader})
```

## Global Effects

You can apply shader effects to the final output by passing them to `endDraw`:

```lua
local bloomShader = love.graphics.newShader("bloom.glsl")
shove.beginDraw()
  -- Drawing operations
shove.endDraw({bloomShader})
```

Or set up persistent global effects:

```lua
shove.setGlobalEffects({bloomShader})
```

## Effect Chaining

When multiple effects are added to a layer, they will be applied in sequence:

```lua
-- These effects will be applied in order:
-- 1. Apply grayscale
-- 2. Apply blur
-- 3. Apply wave distortion
shove.setLayerEffects("myLayer", {
  grayscaleShader,
  blurShader,
  waveShader
})
```

## Working with Layer Drawing

```lua
shove.beginDraw()

  -- Draw to a layer with effects
  shove.beginLayer("background")
    -- Draw content that will have effects applied
    love.graphics.draw(image, 0, 0)
  shove.endLayer()

  -- Draw to another layer without effects
  shove.beginLayer("ui")
    -- Draw UI elements without effects
    drawUI()
  shove.endLayer()

shove.endDraw()
```

## Legacy API Compatibility

The effect system is compatible with the older shader API:

```lua
-- These both do the same thing
shove.setShader(myShader)
shove.addGlobalEffect(myShader)

-- These both do the same thing
shove.setShader("myLayer", layerShader)
shove.setLayerEffects("myLayer", {layerShader})
```
