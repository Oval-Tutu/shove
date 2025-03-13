# Shöve 📐
**A resolution-handling and rendering library for LÖVE**

Shöve is a powerful, flexible resolution-handling library for the [LÖVE](https://love2d.org/) framework. Using Shöve, you can develop your game at a fixed resolution while scaling to fit the window or screen - all with a simple, intuitive API.

Shöve started as a fork of the popular [push](https://github.com/Ulydev/push) library, building on its solid foundation and incorporating community contributed fixes and improvements with additional features and API changes built by team at [Oval Tutu](https://oval-tutu.com) 🩰

## Core Philosophy

Shöve was redesigned to **make resolution handling both simple and powerful**:

- Create pixel-perfect games that scale beautifully 👾
- Organize drawing operations logically with minimal overhead 📝
- Apply visual effects with ease ✨
- Never worry about different screen sizes again 💪

Shöve has a clean API with intuitive functions with consistent naming patterns that offers a progressive learning curve where you can start simple, add complexity as needed.

## Key Features

Shöve offers two render modes:

- **Direct Mode**: Simple scaling and positioning, similar to the original `push` library
- **Layer Mode**: Advanced rendering with support for multiple layers, effects, and compositing

### Complete Resolution Management

- **Multiple Fit Methods**: Choose from aspect-preserving, pixel-perfect, stretch, or no scaling
- **Dynamic Resizing**: Responds instantly to window/screen changes
- **Coordinate Conversion**: Seamlessly map between screen and game coordinates

### Layer-Based Rendering

- **Layer-Based System**: Organize your rendering into logical layers
- **Z-Order Control**: Easily change which layers appear on top
- **Visibility Toggling**: Show or hide entire layers with a single call
- **Complex UIs**: Put your HUD, menus, dialogs, and tooltips on separate layers for easy management.

### Effect Pipeline

- **Per-Layer Effects**: Apply shaders to specific layers only
- **Global Effects**: Transform your entire game with post-processing
- **Effect Chaining**: Combine multiple shaders for complex visual styles
- **Smart Masking**: Use any layer as a mask for another
- **Stencil Support**: Full integration with LÖVE's stencil system

Get started with Shöve today and see how beautiful your LÖVE game can be!

# Demo

The complete suit of demos can originally be found in `push` have been ported to Shöve and can be found in the `demo/` directory.

- Run `love demo/` to view all the demos.
- Press <kbd>SPACE</kbd> to switch between them.
- While running a demo resize the window to see how the resolution changes.

# Shöve Guide

This guide provides documentation for using Shöve, a resolution-handling and rendering library for LÖVE.

## Installation

Place `shove.lua` in your project directory and require it in your code:

```lua
shove = require("shove")
```

## Basic Concepts

Shöve provides a system for rendering your game at a fixed resolution while scaling to fit to the window or screen.

- **Viewport**: The fixed resolution area where your game is drawn
- **Screen**: The window or screen where the game is displayed
- **Layers**: Separate rendering surfaces that can be manipulated independently
- **Effects**: Shaders that can be applied to layers or the final output

## Quick Start

Here's a basic example to get started with Shöve.

```lua
function love.load()
  -- Set up a resizable window
  love.window.setMode(1280, 720, {resizable = true})

  -- Initialize Shöve with fixed game resolution and options
  shove.initResolution(800, 600, {
    fitMethod = "pixel", -- "pixel", "aspect", "stretch", or "none"
    renderMode = "direct" -- "direct" or "layer"
  })
end

function love.resize(width, height)
  -- Update Shöve when window size changes
  shove.resize(width, height)
end

function love.draw()
  shove.beginDraw()
    -- Draw your game here
    love.graphics.rectangle("fill", 50, 50, 200, 150)
  shove.endDraw()
end
```

That is all you need to get started with Shöve! You can now draw your game at a fixed resolution and have it scale to fit the window. **Everything else that follows is optional** and allows you to take advantage of more advanced features.

## Scaling and Fit Methods

Shöve offers several methods to fit your game to different screen sizes:

- **aspect**: Maintains aspect ratio, scales as large as possible (*default*)
- **pixel**: Integer scaling only, for pixel-perfect rendering, also enables nearest-neighbor filtering
- **stretch**: Stretches to fill the entire window
- **none**: No scaling, centered in the window

```lua
-- Use pixel-perfect scaling
shove.initResolution(320, 240, {fitMethod = "pixel"})
```

## Render Modes

### Direct Rendering

Direct rendering is simple and lightweight. It's suitable for games that don't need advanced rendering features. **With direct rendering enabled, none of the layer or effects functions are available.**

```lua
-- Initialize with direct rendering mode
shove.initResolution(800, 600, {renderMode = "direct"})

function love.draw()
  shove.beginDraw()
    -- All drawing operations are directly scaled and positioned
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", 100, 100, 200, 200)

    -- Drawing happens on a single surface
    love.graphics.setColor(0, 0, 1)
    love.graphics.circle("fill", 400, 300, 50)
  shove.endDraw()
end
```

### Layer-Based Rendering

Layer rendering provides powerful features for organizing your rendering into separate layers that can be manipulated independently.

```lua
-- Initialize with layer rendering mode
shove.initResolution(800, 600, {renderMode = "layer"})

function love.load()
  -- Create some layers (optional, they're created automatically when used)
  shove.createLayer("background")
  shove.createLayer("entities")
  shove.createLayer("ui", {zIndex = 10}) -- Higher zIndex renders on top
end

function love.draw()
  shove.beginDraw()
    -- Draw to the background layer
    shove.beginLayer("background")
      love.graphics.setColor(0.2, 0.3, 0.8)
      love.graphics.rectangle("fill", 0, 0, 800, 600)
    shove.endLayer()

    -- Draw to the entities layer
    shove.beginLayer("entities")
      love.graphics.setColor(1, 1, 1)
      love.graphics.circle("fill", 400, 300, 50)
    shove.endLayer()

    -- Draw to the UI layer
    shove.beginLayer("ui")
      love.graphics.setColor(1, 0.8, 0)
      love.graphics.print("Score: 100", 20, 20)
    shove.endLayer()
  shove.endDraw()
end
```

## Coordinate Handling

Shöve provides functions to convert between screen and viewport coordinates:

```lua
function love.mousepressed(screenX, screenY, button)
  -- Convert screen coordinates to viewport coordinates
  local insideViewport, gameX, gameY = shove.toViewport(screenX, screenY)

  if insideViewport then
    -- Mouse is inside the game viewport
    handleClick(gameX, gameY, button)
  end
end

-- Get mouse position directly in viewport coordinates
function love.update(dt)
  local insideViewport, mouseX, mouseY = shove.mouseToViewport()
  if inside then
    player:aimToward(mouseX, mouseY)
  end
end

-- Convert viewport coordinates back to screen coordinates
function drawScreenUI()
  local screenX, screenY = shove.toScreen(playerX, playerY)
  -- Draw something at the screen position
end
```

## Layer Management

When using the layer rendering mode, you have several functions to manage layers:

### Dynamic Layer Creation

Layers are automatically created when you try to draw to them:

```lua
shove.beginDraw()
  -- This creates the "dynamic" layer if it doesn't exist
  shove.beginLayer("dynamic")
    -- Draw content
  shove.endLayer()
shove.endDraw()
```

### Manual Layer Creation and Organisation

```lua
-- Create a layer with options
shove.createLayer("particles", {
  zIndex = 5, -- Controls draw order (higher = on top)
  visible = true, -- Can be toggled
  stencil = false, -- Whether layer supports stencil operations
  blendMode = "alpha" -- Blend mode for the layer
})

-- Check if a layer exists
if shove.layerExists("background") then
  -- Do something with the layer
end

-- Change layer drawing order
shove.setLayerOrder("ui", 100) -- Make UI render on top

-- Toggle layer visibility
shove.setLayerVisible("debug", false) -- Hide debug layer
```

### Drawing to Layers

```lua
-- Basic layer drawing
shove.beginDraw()
  shove.beginLayer("background")
    -- Draw background content
  shove.endLayer()

  shove.beginLayer("entities")
    -- Draw entities
  shove.endLayer()
shove.endDraw()

-- Draw directly to a layer with a callback function:
shove.drawToLayer("explosion", function()
  drawExplosionEffect()
end)
```

### Layer Masking

You can use one layer as a mask for another:

```lua
-- Create a mask layer
shove.beginDraw()
  shove.beginLayer("mask")
    -- Draw shapes to define the visible area
    love.graphics.circle("fill", 400, 300, 100)
  shove.endLayer()

  -- Set the mask
  shove.setLayerMask("content", "mask")

  -- Draw content that will be masked
  shove.beginLayer("content")
    -- This will only be visible inside the circle
    drawComplexScene()
  shove.endLayer()
shove.endDraw()
```

## Effect System

Shöve includes a powerful effect system for applying shaders to layers or the final output.

### Layer Effects

```lua
-- Create some shaders
local blurShader = love.graphics.newShader("blur.glsl")
local waveShader = love.graphics.newShader("wave.glsl")

-- Add effects to specific layers
shove.addEffect("water", waveShader)
shove.addEffect("background", blurShader)

-- Remove an effect
shove.removeEffect("background", blurShader)

-- Clear all effects from a layer
shove.clearEffects("water")
```

### Global Effects

```lua
-- Apply effects to the final composited output
local bloomShader = love.graphics.newShader("bloom.glsl")

-- Option 1: Apply for a single frame
shove.beginDraw()
  -- Draw content
shove.endDraw({bloomShader})

-- Option 2: Set up persistent global effects
shove.addGlobalEffect(bloomShader)
```

### Chaining Effects

When multiple effects are added to a layer or set globally, they're applied in sequence:

```lua
-- Create a chain of effects
local effects = {
  love.graphics.newShader("grayscale.glsl"),
  love.graphics.newShader("vignette.glsl"),
  love.graphics.newShader("scanlines.glsl")
}

-- Apply the chain to a layer
for _, effect in ipairs(effects) do
  shove.addEffect("final", effect)
end
```

## Advanced Techniques

### Manual Compositing

You can manually trigger the compositing process before the end of drawing:

```lua
shove.beginDraw()
  -- Draw to some layers

  -- Composite and draw the current state
  shove.compositeAndDraw()

  -- Draw more layers that will appear on top
shove.endDraw()
```

## API Reference

### Initialization and Setup

- `shove.initResolution(width, height, options)` - Initialize with game resolution
- `shove.resize(width, height)` - Update when window size changes

### Drawing Flow

- `shove.beginDraw()` - Start drawing operations
- `shove.endDraw(globalEffects)` - End drawing and display result

### Coordinate Handling

- `shove.toViewport(x, y)` - Convert screen coordinates to viewport
- `shove.toScreen(x, y)` - Convert viewport coordinates to screen
- `shove.mouseToViewport()` - Get mouse position in viewport coordinates
- `shove.inViewport(x, y)` - Check if coordinates are inside viewport

### Utility Functions

- `shove.getViewportWidth()` - Get viewport width
- `shove.getViewportHeight()` - Get viewport height
- `shove.getViewportDimensions()` - Get viewport dimensions
- `shove.getViewport()` - Get viewport rectangle in screen coordinates

### Layer Operations

- `shove.createLayer(name, options)` - Create a new layer
- `shove.removeLayer(name)` - Remove a layer
- `shove.layerExists(name)` - Check if a layer exists
- `shove.setLayerOrder(name, zIndex)` - Set layer drawing order
- `shove.setLayerVisible(name, isVisible)` - Toggle layer visibility
- `shove.setLayerMask(name, maskName)` - Set a layer as a mask
- `shove.beginLayer(name)` - Start drawing to a layer
- `shove.endLayer()` - Finish drawing to a layer
- `shove.drawToLayer(name, drawFunc)` - Draw to a layer with a callback

### Effect System

- `shove.addEffect(layerName, effect)` - Add an effect to a layer
- `shove.removeEffect(layerName, effect)` - Remove an effect from a layer
- `shove.clearEffects(layerName)` - Clear all effects from a layer
- `shove.addGlobalEffect(effect)` - Add a global effect
- `shove.removeGlobalEffect(effect)` - Remove a global effect
- `shove.clearGlobalEffects()` - Clear all global effects
