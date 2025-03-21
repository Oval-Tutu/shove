# Shöve 📐
**A resolution-handling and rendering library for [LÖVE](https://love2d.org/)**

Shöve is a powerful, flexible resolution-handling and rendering library for the LÖVE framework.
Using Shöve, you can develop your game at a fixed resolution while scaling to fit the window or screen - all with a simple, intuitive API.

## Why Shöve?

Shöve takes the [`dev` branch of push](https://github.com/Ulydev/push/tree/dev), redesigns the API, and builds on its Canvas rendering concept to create a powerful and intuitive library that can handle complex rendering scenarios.

### Key Features

#### 🖼️ Two Powerful Render Modes

- **Direct Mode**: Simple scaling and positioning
- **Layer Mode**: Advanced rendering with multiple layers

####  📏 Complete Resolution Management

- **Multiple Fit Methods**: Choose from aspect-preserving, pixel-perfect, stretch, or no scaling
- **Dynamic Resizing**: Responds instantly to window/screen changes
- **Coordinate Conversion**: Seamlessly map between screen and game coordinates

#### 🥞 Layer-Based Rendering

- **Layer-Based System**: Organize your rendering into logical layers
- **Z-Order Control**: Easily change which layers appear on top
- **Visibility Toggling**: Show or hide entire layers with a single call
- **Complex UIs**: Put your HUD, menus, dialogs, and tooltips on separate layers for easy management.
- **Integrated Profiling**: Measure performance and debug rendering issues

#### ✨ Effect Pipeline

- **Per-Layer Effects**: Apply shaders to specific layers only
- **Global Effects**: Transform your entire game with post-processing
- **Effect Chaining**: Combine multiple shaders for complex visual styles
- **Smart Masking**: Use any layer as a mask for another

**Shöve offers a progressive learning curve**—start simple and add complexity as needed ‍🧑‍🎓

## Quick Start

Here's a basic example to get started with Shöve.

```lua
shove = require("shove")

function love.load()
  -- Initialize Shöve with fixed game resolution and options
  shove.setResolution(400, 300, {fitMethod = "aspect"})
  -- Set up a resizable window
  shove.setWindowMode(800, 600, {resizable = true})
end

function love.draw()
  shove.beginDraw()
    -- Your game here!
    love.graphics.clear(0.1, 0.1, 0.2)
    love.graphics.setColor(0.918, 0.059, 0.573)
    love.graphics.rectangle("fill", 150 + math.sin(love.timer.getTime()) * 150, 100, 100, 100)
  shove.endDraw()
end

function love.keypressed(key)
  if key == "escape" then love.event.quit() end
end
```

You can now draw your game at a fixed resolution and have it scale to fit the window.

**💡 NOTE!** That is all you need to get started! **Everything else that follows is optional**, but very tasty 👅

# Demos ️🕹️

Run `love demo/` to explore all demos. Use <kbd>SPACE</kbd> to cycle through examples, <kbd>f</kbd> to toggle fullscreen, and <kbd>ESC</kbd> to exit.

Each demo showcases different Shöve capabilities:
- [**low-res**](https://github.com/Oval-Tutu/shove/blob/main/demo/low-res/init.lua):: Pixel-perfect scaling with a tiny 64x64 resolution
- [**single-shader**](https://github.com/Oval-Tutu/shove/blob/main/demo/single-shader/init.lua): Apply shaders to specific layers
- [**multiple-shaders**](https://github.com/Oval-Tutu/shove/blob/main/demo/multiple-shaders/init.lua): Chain multiple effects
- [**mouse-input**](https://github.com/Oval-Tutu/shove/blob/main/demo/mouse-input/init.lua): Convert between screen and viewport coordinates
- [**canvases-shaders**](https://github.com/Oval-Tutu/shove/blob/main/demo/canvases-shaders/init.lua): Apply different effects to different layers
- [**stencil**](https://github.com/Oval-Tutu/shove/blob/main/demo/stencil/init.lua): Use stencil buffers with layers
- [**mask**](https://github.com/Oval-Tutu/shove/blob/main/demo/mask/init.lua): Create dynamic visibility with layer masking
- [**parallax**](https://github.com/Oval-Tutu/shove/blob/main/demo/parallax/init.lua): Multi-layered background scrolling with animated particles and bloom effects

# Shöve Guide 📚

This guide provides documentation for using Shöve.

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
  - **Layer Masks**: Layers that control visibility of other layers
- **Shaders**: [GLSL](https://www.khronos.org/opengl/wiki/Core_Language_(GLSL)) programs that transform pixel colors
  - **Layer Effects**: Shaders applied to specific layers
  - **Persistent Global Effects**: Shaders applied to the final composited output
  - **Transient Global Effects**: Shaders applied to the final output for a single frame

## Fit Methods and Scaling

Shöve offers several methods to fit your game to different screen sizes:

- **aspect**: Maintains aspect ratio, scales as large as possible (*default*)
- **pixel**: Integer scaling only, for pixel-perfect rendering
- **stretch**: Stretches to fill the entire window
- **none**: No scaling, centered in the window

```lua
-- Use pixel-perfect scaling
shove.setResolution(320, 240, {fitMethod = "pixel"})
```

### Scaling Filters

The `scalingFilter` option determines how textures are scaled when rendering your game. Here's how it works:

You can set `scalingFilter` in two ways:

1. **At initialization:**
   ```lua
   shove.setResolution(800, 600, {
     fitMethod = "aspect",
     scalingFilter = "nearest" -- Set filtering explicitly
   })
   ```

2. **At runtime:**
   ```lua
   shove.setScalingFilter("linear")
   ```

If `scalingFilter` is not explicitly specified, Shöve automatically selects a default based on your `fitMethod`:

With `fitMethod = "pixel"` it defaults to `"nearest"` filtering to preserve pixel-perfect appearance. With all other fit methods (`"aspect"`, `"stretch"`, `"none"`) it defaults to `"linear"` filtering for smoother scaling.

- `nearest`: Nearest-neighbor filtering (sharp, pixel-perfect, no interpolation)
- `linear`: Linear filtering (smooth blending between pixels)

Here are the typical use cases:

- Use `"nearest"` when creating pixel art games where you want to preserve the crisp edges of your pixels
- Use `"linear"` for smoother visuals with games that use higher resolution assets
- Override the default when you need a specific visual style regardless of fit method

You can check the current setting at any time with `shove.getScalingFilter()`.

## Window Management

Shöve provides wrapper functions for LÖVE's window management.
Set the window dimensions and properties with automatic resize handling using `shove.setWindowMode(width, height, flags)`.

**💡 NOTE:** For best results, call `shove.setResolution()` before using these window management functions to ensure proper viewport initialization.


```lua
-- Create a window half the size of the desktop
local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
shove.setWindowMode(desktopWidth * 0.5, desktopHeight * 0.5, {
  resizable = true,
  vsync = true,
  minwidth = 400,
  minheight = 300
})
```

Use `shove.updateWindowMode(width, height, flags)` to change the window size and properties.

## Render Modes

### Direct Rendering

Direct rendering is simple and lightweight.
It's suitable for games that don't need advanced rendering features.

**💡NOTE!** With direct rendering enabled, none of the layer rendering or effects functions are available.

```lua
-- Initialize with direct rendering mode
shove.setResolution(960, 540, {renderMode = "direct"})

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

Think of Shöve's layers like Photoshop or Figma layers—separate "sheets" that combine to create your complete scene.


```lua
-- Traditional approach (harder to manage)
function love.draw()
  drawBackground()
  drawCharacters()
  drawParticles()
  drawUI()
  if debugMode then drawDebugInfo() end
end
```

With Shöve's layers, you can organize these logically and manage them independently:

```lua
-- Layer approach (more flexible and organized)
shove.beginDraw()
  shove.beginLayer("background")
    drawBackground()
  shove.endLayer()

  shove.beginLayer("gameplay")
    drawCharacters()
    drawParticles()
  shove.endLayer()

  shove.beginLayer("ui")
    drawUI()
  shove.endLayer()

  -- Only rendered when debug mode is on
  shove.beginLayer("debug")
    if debugMode then
      shove.showLayer("debug")
      drawDebugInfo()
    else
      shove.hideLayer("debug")
    end
  shove.endLayer()
shove.endDraw()
```

#### Key Benefits

Many of the benefits of Shöve's layers are similar to those in professional creative software:

- **Independent Control:** Hide, show, or modify layers without affecting others
- **Z-Ordering:** Change which elements appear on top
- **Effect Application:** Apply shaders to specific layers
- **Visual Debugging:** Toggle debug visualization on/off
- **State Management:** Control entire game states through layer visibility

Layer rendering provides powerful features for organizing your rendering into separate layers that can be manipulated independently.
Under the hood, Shöve uses [LÖVE's Canvas system](https://love2d.org/wiki/Canvas) to achieve this, but hides the complexity behind a simple API.

```lua
shove = require("shove")
-- Initialize with layer rendering mode
shove.setResolution(800, 600, {renderMode = "layer"})

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

Shöve provides functions to convert between screen and game viewport coordinates:

```lua
function love.mousepressed(screenX, screenY, button)
  -- Convert screen coordinates to viewport coordinates
  local inViewport, gameX, gameY = shove.screenToViewport(screenX, screenY)

  if inViewport then
    -- Mouse is inside the game viewport
    handleClick(gameX, gameY, button)
  end
end

-- Get mouse position directly in viewport coordinates
function love.update(dt)
  local mouseInViewport, mouseX, mouseY = shove.mouseToViewport()
  if inside then
    player:aimToward(mouseX, mouseY)
  end
end

-- Convert viewport coordinates back to screen coordinates
function drawScreenUI()
  local screenX, screenY = shove.viewportToScreen(playerX, playerY)
  -- Draw something at the screen position
end
```

## Layer Management

While Shöve automatically creates layers when you first draw to them after declaring them with `beginLayer()`, there are several compelling reasons to manually create layers with `createLayer()` instead:

```lua
-- Create a layer with specific properties
shove.createLayer("ui", {
  zIndex = 100,      -- Ensure UI is always on top
  visible = false,   -- Start hidden until needed
  stencil = true     -- Enable stencil support
})
```

Manual creation lets you configure layers with specific options from the start, rather than using defaults and modifying later.
Pre-defining your layers creates a clear "blueprint" of your rendering architecture:

```lua
function initLayers()
  -- Background layers
  shove.createLayer("sky", {zIndex = 10})
  shove.createLayer("mountains", {zIndex = 20})
  shove.createLayer("clouds", {zIndex = 25})

  -- Gameplay layers
  shove.createLayer("terrain", {zIndex = 30})
  shove.createLayer("entities", {zIndex = 40})
  shove.createLayer("particles", {zIndex = 50})

  -- UI layers
  shove.createLayer("hud", {zIndex = 100})
  shove.createLayer("menu", {zIndex = 110})
  shove.createLayer("debug", {zIndex = 1000, visible = debugMode})
end
```

This approach documents your rendering pipeline and makes relationships between layers clear.
Manual creation allows you to configure layer relationships before any drawing occurs:

```lua
-- Set up mask relationships at initialization
shove.createLayer("lightning_mask", {stencil = true})
shove.createLayer("foreground")
shove.setLayerMask("foreground", "lightning_mask")

-- Apply initial effects
shove.createLayer("underwater")
shove.addEffect("underwater", waterDistortionShader)
```

Creating all layers upfront improves predictability:

- All canvases are allocated at once rather than during gameplay
- Memory usage is more consistent
- No canvas creation overhead during rendering
- Dynamic layer creation can cause hitching or frame drops when over used

```lua
function love.load()
  -- Game setup
  setupEntities()
  loadResources()

  -- Define our rendering architecture upfront
  shove.createLayer("background", {zIndex = 10})
  shove.createLayer("middleground", {zIndex = 20})
  shove.createLayer("entities", {zIndex = 30})
  shove.createLayer("particles", {zIndex = 40})
  shove.createLayer("ui", {zIndex = 100})

  -- Configure special properties
  shove.addEffect("background", parallaxEffect)
  shove.createLayer("mask_layer", {stencil = true})
  shove.setLayerMask("particles", "mask_layer")
end
```

With this approach, your rendering architecture is clearly defined, properly configured, and ready to use before your first frame is drawn.

## Blend Modes

Shove provides full support for LÖVE's blend modes at the layer level. This gives you precise control over how layers blend with each other when composited.

### Blend Mode Constants

For convenience and better code readability, Shove provides constants for all available blend modes:

```lua
-- Use constants instead of string literals
shove.setLayerBlendMode("particles", shove.BLEND.ADD)

-- Available blend mode constants
shove.BLEND.ALPHA    -- Normal alpha blending (default)
shove.BLEND.REPLACE  -- Replace pixels without blending
shove.BLEND.SCREEN   -- Screen blending (lightens)
shove.BLEND.ADD      -- Additive blending (glow effects)
shove.BLEND.SUBTRACT -- Subtractive blending
shove.BLEND.MULTIPLY -- Multiply colors (darkening)
shove.BLEND.LIGHTEN  -- Keep lighter colors
shove.BLEND.DARKEN   -- Keep darker colors

-- Alpha mode constants
shove.ALPHA.MULTIPLY     -- Standard alpha multiplication (default)
shove.ALPHA.PREMULTIPLIED -- For pre-multiplied alpha content
```

## Blend Modes

You can set blend modes either during layer creation or at any time afterward:

```lua
-- Set blend mode during layer creation
shove.createLayer("glow", {
  zIndex = 50,
  blendMode = shove.BLEND.ADD,      -- Additive blending
  blendAlphaMode = shove.ALPHA.MULTIPLY -- Default alpha mode
})

-- Set blend mode for an existing layer
shove.setLayerBlendMode("particles", shove.BLEND.ADD)
shove.setLayerBlendMode("ui", shove.BLEND.ALPHA, shove.ALPHA.PREMULTIPLIED)

-- Get current blend modes
local blendMode, alphaMode = shove.getLayerBlendMode("particles")
```

### Common Blend Mode Use Cases

Different blend modes enable various visual effects:

- **ADD**: Perfect for glowing effects, particle systems, light sources
  ```lua
  shove.setLayerBlendMode("fire", shove.BLEND.ADD)
  ```
- **MULTIPLY**: Great for shadows and darkening effects
  ```lua
  shove.setLayerBlendMode("shadow", shove.BLEND.MULTIPLY)
  ```
- **SCREEN**: Useful for lightning, lasers, and brightening effects
  ```lua
  shove.setLayerBlendMode("lightning", shove.BLEND.SCREEN)
  ```
- **ALPHA**: Standard transparency blending (default)
  ```lua
  shove.setLayerBlendMode("ui", shove.BLEND.ALPHA)
  ```

For proper rendering of content drawn to canvases, Shöve automatically uses premultiplied alpha when compositing layers, while respecting each layer's blend mode setting.

## Layer Masking

Layer masking in Shöve provides a straightforward way to control visibility between layers.
The masking system uses one layer's content to determine which parts of another layer are visible.

Behind the scenes, Shöve's layer masking system works through these steps:

1. **Mask Layer Creation**: A layer is created that will serve as the mask
2. **Mask Content Drawing**: Content is drawn to this layer (typically shapes or patterns)
3. **Mask Assignment**: The `shove.setLayerMask("targetLayer", "maskLayer")` function assigns the relationship
4. **Rendering Process**:
   - When the target layer is drawn, Shöve detects it has a mask assigned
   - Shöve converts the mask layer's content into an alpha mask
   - The target layer is only visible where the mask layer has non-transparent pixels

Behind the scenes, Shöve uses [LÖVE's stencil system](https://love2d.org/wiki/love.graphics.stencil) and automatically manages the stencil buffer and shader masks for you.

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

Shöve's layer masking offers an elegant abstraction over LÖVE's stencil buffer, trading some low-level flexibility for ease of use and integration with the layer-based rendering architecture.

1. **Simplified API**: Layer masks provide a straightforward, higher-level API that doesn't require understanding stencil buffer mechanics
   ```lua
   shove.setLayerMask("content", "mask")
   ```
   versus
   ```lua
   love.graphics.stencil(stencilFunction, "replace", 1)
   love.graphics.setStencilTest("greater", 0)
   -- Draw content
   love.graphics.setStencilTest()
   ```
2. **Persistent Relationship**: The mask relationship stays in effect until changed, requiring no repeated setup each frame
3. **Dynamic Masking**: The mask layer can be animated or changed over time, and the masking relationship automatically updates
4. **Layer Management Integration**: Masks inherit all layer system benefits like z-ordering, visibility toggling, and effects
5. **Reusability**: A single mask layer can be used to mask multiple target layers
6. **Declarative Style**: The mask relationship is defined separately from drawing operations, leading to cleaner, more maintainable code

Although layer masks provide a high-level API for masking, there are scenarios where manual stencil buffer manipulation might be more appropriate and Shöve supports direct access to the stencil buffer for advanced use cases.

The layer mask approach separates the mask definition from its application, resulting in more modular, maintainable code that follows a declarative programming style. The stencil approach gives more immediate control but requires more technical knowledge and careful state management.

## Effect System

Shöve includes a powerful effect system for applying [Shaders](https://love2d.org/wiki/Shader) to layers or the final output.

The effect system is designed to be efficient by:

- Only creating temporary canvases when needed
- Resizing canvases only when the viewport changes
- Applying effects only to visible layers
- Only processing active effects

**💡NOTE!** Each additional effect requires more GPU processing. **Complex shaders or many effects can impact performance**.

### Layer Effects

Layer effects provide a powerful way to apply shader-based visual effects to specific layers independently.
This creates a flexible rendering pipeline where different parts of your scene can have unique visual treatments.

Layer effects provide a clean abstraction over LÖVE's shader system that integrates with the layer-based rendering architecture, giving you powerful visual capabilities with a simple API. Here's how it works:

1. Shöve checks if the specified layer exists, creating it if necessary
2. Shöve verifies that the layer's internal structure includes an `effects` table
3. The shader is added to this `effects` table for the layer
4. Effects are stored in order of addition, which determines their application sequence

During the rendering process, here's what happens:

1. When `beginLayer()` is called, Shöve sets the current active layer
2. All drawing commands between `beginLayer()` and `endLayer()` are captured on the layer's canvas
3. When `endLayer()` is called, Shöve checks if the layer has any effects
4. If effects exist, each is applied sequentially to the layer's canvas
5. The effects processing occurs before the layer is composited with other layers

Each effect's shader transforms the entire layer canvas, not individual drawing operations.
This means that all content drawn to a layer is processed together by its effects.

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

When multiple effects are added to a layer, they form a processing chain:

- The original content is drawn to a temporary canvas
- The first effect processes this canvas, outputting to another canvas
- The second effect takes that output as input, processing to yet another canvas
- This continues through all effects in the layer's effect list
- The final processed canvas becomes the layer's output
- This approach allows effects to build upon each other, creating complex visual treatments that wouldn't be possible with a single shader.

### Global Effects

In Shöve, global effects are shaders applied to the final composite image after all layers have been rendered and combined.
They affect the entire viewport output rather than individual layers.
This is implemented using LÖVE's shader system, which processes the pixels of a canvas through a GLSL shader program.

When you apply global effects, here's what happens under the hood:

- All layers are first rendered to their individual canvases
- These layer canvases are composited together in z-order to a final canvas
- The global effects are then applied to this final canvas
- The resulting image is scaled and positioned according to the fit method
- Finally, the processed image is drawn to the screen

```lua
-- Apply effects to the final composited output
local bloomShader = love.graphics.newShader("bloom.glsl")

-- Persistent: Set up persistent global effects, most common use case
shove.addGlobalEffect(bloomShader)

-- Transient: Apply a transient global effect for a single frame
shove.beginDraw()
  -- Draw content
shove.endDraw({bloomShader})
```

For most use cases requiring consistent effects, `addGlobalEffect` is the cleaner approach.
For dynamic or temporary effects, passing shaders directly to `endDraw` provides more flexibility.

#### Persistent: Using `addGlobalEffect(bloomShader)`

This method registers the shader as a **persistent global effect**. In the implementation:

1. The shader is added to an internal table of global effects
2. It's automatically applied during every subsequent call to `endDraw`
3. The effect persists until explicitly removed with `removeGlobalEffect` or cleared with `clearGlobalEffects`
4. These persistent effects are applied before any transient effects passed to `endDraw`

This approach is better for:
- Consistent visual effects that should apply across multiple frames
- Effects that you want to toggle on and off programmatically
- When you need to manage multiple global effects that are applied consistently

#### Transient: Passing Effects to `endDraw({bloomShader})`

This method applies the shader(s) **only for the current frame**, when you pass shaders to `endDraw`:

1. Shöve takes the array of shaders you provide
2. It applies them in sequence after compositing all layers
3. The shaders are used just once and don't persist to the next frame
4. These one-time effects are applied **after** any persistent global effects

This approach is useful for:
- Effects that you want to apply only temporarily
- Visual transitions that should last just one frame
- Dynamic effects where you need to create new shader instances each frame

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

### Drawing to Layers with Callbacks

`drawOnLayer()` provides a convenient way to temporarily switch to a different layer, perform drawing operations, and then automatically return to the previous layer - all without disrupting your main drawing flow.
It elegantly handles all the layer switching mechanics, allowing you to focus on your drawing code rather than layer management.

How it Works:
1. **Validates context**: Checks if rendering is in "layer" mode and we're currently in an active drawing cycle.
2. **Preserves state**: Saves the currently active layer.
3. **Switches context**: Activates the target layer.
4. **Executes callback**: Runs your drawing function on that layer.
5. **Restores context**: Returns to the previous layer (or ends layer drawing if there was no previous layer).

Example usage:

```lua
shove.beginDraw()
  -- Draw main content
  shove.beginLayer("game")
    drawGameWorld()
  shove.endLayer()

  -- Draw something to a specialized layer with a callback
  shove.drawOnLayer("particles", function()
    spawnExplosionParticles(x, y)
  end)

  -- Continue with normal drawing flow
  shove.beginLayer("ui")
    drawUI()
  shove.endLayer()
shove.endDraw()
```

Here are some good use cases for `drawOnLayer()`:

1. **Isolated drawing tasks**: When you need to draw to multiple layers but want to keep your code organized.
2. **Reusable drawing functions**: Create modular drawing functions that can be applied to any layer.
3. **Dynamic UI elements**: Draw UI components (like tooltips or notifications) to their own layers without breaking your main drawing flow.
4. **Temporary effects**: Draw short-lived visual effects to dedicated layers.
5. **State-based drawing**: Switch layers based on game state without complex conditional logic.

### Manual Compositing

The `drawComposite()` function performs an intermediate composite and draw operation during an active drawing cycle.
Specifically, it:

1. Takes all layers that have been drawn so far in the current frame
2. Composites these layers together according to their z-index ordering
3. Applies transient global effects that are passed as an argument
4. Applied persistent global effects only when specifically requested
5. Renders this composite using the configured fit method
6. Critically, **it does not end the drawing process**, allowing further layers to be drawn afterward

This differs from the typical `beginDraw()`/`endDraw()` cycle, where compositing and drawing only happen at the end when `endDraw()` is called.

The `drawComposite()` function provides a powerful tool for advanced rendering techniques.
It gives you finer control over the rendering pipeline by allowing intermediate compositing and drawing operations within a single frame.

- `drawComposite()` → Composite and draw the current state with no transient or persistent effects
- `drawComposite({anEffect}, false)` → Composite and draw the current state with a transient effect
- `drawComposite({anEffect, anotherEffect}, true)` → Composite and draw the current state with transient and persistent effects
- `drawComposite(nil, true)` → Composite and draw the current state with persistent effects

While most games won't need this level of control, it can be useful for complex visual effects, multi-stage rendering, debugging, or interactive applications that need to respond to partially-rendered content.
You can manually trigger the compositing process before the end of drawing:

### When to Use `drawComposite()`

#### Multi-Pass Rendering

```lua
shove.beginDraw()
  -- Draw world and characters
  shove.beginLayer("world")
    drawWorld()
  shove.endLayer()

  shove.beginLayer("characters")
    drawCharacters()
  shove.endLayer()

  -- Composite and draw what we have so far
  shove.drawComposite()

  -- Draw second pass with effects that need to see the first pass result
  shove.beginLayer("lighting")
    drawDynamicLighting() -- This might use rendered result as input
  shove.endLayer()

  shove.beginLayer("ui")
    drawUserInterface()
  shove.endLayer()
shove.endDraw()
```

#### Visual Debugging

```lua
shove.beginDraw()
  -- Draw base layers

  -- Show intermediate result for debugging
  shove.drawComposite()

  -- Debug visualization appears on top
  shove.beginLayer("debug")
    drawCollisionBoxes()
    drawPathfindingGrid()
  shove.endLayer()
shove.endDraw()
```

#### Interactive Layer Building

For cases where layers depend on previous composite results:

```lua
shove.beginDraw()
  -- Draw background layers

  -- Draw to screen so we can capture player input on what's been drawn so far
  shove.drawComposite()

  -- Get player input based on what they see
  local selectedPosition = getPlayerSelection()

  -- Continue drawing with new information
  shove.beginLayer("selection")
    drawSelectionHighlight(selectedPosition)
  shove.endLayer()
shove.endDraw()
```

Manual compositing has some advantages and considerations:

#### Advantages:

- Enables more complex rendering pipelines
- Allows for effects that need to see intermediate results
- Supports interactive feedback during rendering
- Can help with memory management for complex scenes
- Provides a way to debug rendering issues

#### Considerations:

- Multiple composites in a single frame can affect performance
- Each call creates additional draw operations
- May complicate the rendering logic and make code harder to follow
- Generally not needed for simple rendering scenarios

### Resize Callbacks

Shöve provides a resize callback system that allows you to register functions that automatically run after window resize events.
This is useful for adapting UI layouts, recreating canvases, and handling other resize-dependent operations.

Use `shove.setResizeCallback()` to register a function to be called after resolution transforms are recalculated during resize operations.

```lua
shove.setResizeCallback(function(width, height)
  -- width and height are the new window dimensions
  -- Resize-dependent code here
end)
```

`shove.getResizeCallback()` can be used to retrieve the currently registered resize callback function.

If you need multiple resize handlers, you can implement your own dispatch system:
```lua
local resizeHandlers = {}

local function masterResizeCallback()
  for _, handler in ipairs(resizeHandlers) do
    handler()
  end
end

-- Set up the master callback
shove.setResizeCallback(masterResizeCallback)

-- Add handlers as needed
function addResizeHandler(handler)
  table.insert(resizeHandlers, handler)
end
```

### Performance Profiler

Shöve includes a built-in performance profiler that provides real-time information about resolution management, layer status, and rendering performance.
This can help diagnose scaling issues and optimize your game during development.
The profiler does not have any active code paths active until you enable it, so it has zero impact on performance when hidden.

The profiler overlay displays:
- Hardware information (OS, CPU, GPU)
- Performance metrics (FPS, draw calls, memory usage)
- Resolution and scaling information
- Detailed layer information (when using layer rendering)

The profiler is rendered after at the end of `shove.endDraw()` and can be toggled on/off with a keyboard shortcut.

```lua
-- The profiler loads automatically when the library initializes
function love.draw()
  shove.beginDraw()
  -- Your drawing code here
  shove.endDraw()
  -- ** profiler rendered at the end of shove.endDraw() here **
end
```

When evaluating batch processing impact, pay attention to:

1. **State Changes**: Fewer is better, especially on mobile
2. **Batch Groups**: Number of layer groups with similar properties
3. **Batched Layers**: Total layers processed in batches
4. **Batched Effect Operations**: How many effect applications were optimized

#### Profiler Controls

- **Keyboard:** <kbd>Ctrl</kbd> + <kbd>P</kbd> to toggle overlay
- **Keyboard:** <kbd>Ctrl</kbd> + <kbd>T</kbd> to toggle FPS overlay
- **Keyboard:** <kbd>Ctrl</kbd> + <kbd>V</kbd> to toggle VSync (when overlay is visible)
- **Keyboard:** <kbd>Ctrl</kbd> + <kbd>S</kbd> to toggle overlay size
- **Controller:** Select + A/Cross to toggle overlay
- **Controller:** Select + B/Circle to toggle VSync (when overlay is visible)
- **Controller:** Select + Y/Triangle to toggle overlay size
- **Touch:** Double-tap top right corner to toggle overlay
- **Touch:** Double-tap the overlay to toggle VSync (when overlay is visible)
- **Touch:** Double-tap overlay panel border/edge to toggle overlay size

#### Profiler Performance Considerations

When running at very high frame rates (many hundred of FPS), the profiler itself introduces a small but measurable performance overhead.
In our testing we observed the profiler's impact to be approximately 1.2% to 1.5% of total FPS.
This overhead comes from the additional calculations, memory access, and UI rendering that the profiler performs each frame to track and display metrics.

For most development scenarios, this minimal impact won't affect your workflow. However, when performing precise performance benchmarking or optimization on high-end systems, consider temporarily disabling the profiler by using the toggle shortcut (<kbd>Ctrl</kbd> + <kbd>P</kbd>) or removing the profiler module entirely for the most accurate measurements.

#### Disabling the Profiler for Production

The profiler is implemented in a separate file (`shove-profiler.lua`) so you can easily disable it in production builds.
Remove profiler file in your production builds and Shöve will automatically detect its absence and use a no-op stub implementation.
This approach ensures that the profiler adds zero overhead to your game in production releases while exposing useful tooling during development.

## Optimizing Layer Rendering

Shöve implements several sophisticated rendering optimizations that can help improve performance when using layer-based rendering. These optimizations focus on reducing state changes and minimizing draw calls.

### Key Optimizations

#### Layer Batching

The core optimization in Shöve is layer batching, which:

1. **Groups similar layers** based on shared properties (blend mode, effects, masks)
2. **Processes effects in batches** to reduce shader switches
3. **Minimizes state changes** by setting blend modes once per batch
4. **Optimizes memory usage** with persistent table reuse

These optimizations are particularly valuable for:
- Games with many layers using the same blend mode
- Scenes with multiple layers sharing identical effects
- Lower-end hardware where state changes are expensive
- Mobile devices where reducing draw calls improves battery life

### Controlling Batch Processing

Batch processing is enabled by default for layer-based render but can be toggled at runtime:

```lua
-- Disable batch processing
local previousState = shove.setLayerBatching(false)

-- Check current batch processing state
local batchingEnabled = shove.getLayerBatching()

-- Re-enable batch processing
shove.setLayerBatching(true)
```

#### When to Disable Batching

Despite its benefits, batch processing adds some CPU overhead. Consider disabling it when:

- Your game has very few layers (less than 3-4)
- Layers have unique blend modes or effects (no batching opportunities)
- You're CPU-bound rather than GPU-bound
- Profiler metrics show no significant reduction in state changes

#### Testing Your Specific Case

Since rendering performance is highly dependent on your specific game and target hardware, use the profiler to test both modes:
1. Run your game with default settings (batching enabled)
2. Note the FPS and state change metrics
3. Disable batching: `shove.setLayerBatching(false)`
4. Compare metrics to determine the best configuration

The ideal setting varies by game, so let your profiler results guide your decision rather than assuming one approach is always better.

## API Reference

### Initialization and Setup

- `shove.setResolution(width, height, options)` - Initialize with game resolution
- `shove.setWindowMode(width, height, options)` - Set window mode
- `shove.updateWindowMode(width, height, options)` - Update window mode
- `shove.resize(width, height)` - Update when window size changes

### Drawing Flow

- `shove.beginDraw()` - Start drawing operations
- `shove.endDraw(globalEffects)` - End drawing and display result

### Coordinate Handling

- `shove.isInViewport(x, y)` - Check if coordinates are inside viewport
- `shove.mouseToViewport()` - Convert mouse position to viewport
- `shove.screenToViewport(x, y)` - Convert screen coordinates to viewport
- `shove.viewportToScreen(x, y)` - Convert viewport coordinates to screen

### Utility Functions

- `shove.getFitMethod()` - Get current fit method
- `shove.setFitMethod(fitMethod)` - Set fit method
- `shove.getRenderMode()` - Get current render mode
- `shove.setRenderMode(renderMode)` - Set render mode
- `shove.getScalingFilter()` - Get current scaling filter
- `shove.setScalingFilter(scalingFilter)` - Set scaling filter
- `shove.getResizeCallback()` - Get the current resize callback
- `shove.setResizeCallback(callback)` - Register a resize callback
- `shove.getViewportWidth()` - Get viewport width
- `shove.getViewportHeight()` - Get viewport height
- `shove.getViewportDimensions()` - Get viewport dimensions
- `shove.getViewport()` - Get viewport rectangle in screen coordinates
- `shove.handleDebugKeys()` - Display debug information
- `shove.showDebugInfo(x, y, options)` - Display custom debug information

### Layer Operations

- `shove.beginLayer(name)` - Start drawing to a layer
- `shove.endLayer()` - Finish drawing to a layer
- `shove.createLayer(name, options)` - Create a new layer
- `shove.removeLayer(name)` - Remove a layer
- `shove.hasLayer(name)` - Check if a layer exists
- `shove.getLayerOrder(name)` - Get layer drawing order
- `shove.setLayerOrder(name, zIndex)` - Set layer drawing order
- `shove.getLayerBlendMode(name)` - Get the blend mode and alpha mode of a layer
- `shove.setLayerBlendMode(name, blendMode, alphaMode)` - Set blend mode and optional alpha mode
- `shove.isLayerVisible(name)` - Check if a layer is visible
- `shove.hideLayer(name)` - Hide a layer
- `shove.showLayer(name)` - Show a layer
- `shove.getLayerMask(name)` - Get the mask of a layer
- `shove.setLayerMask(name, maskName)` - Set a layer as a mask
- `shove.drawOnLayer(name, drawFunc)` - Draw to a layer with a callback
- `shove.drawComposite(globalEffects, applyPersistentEffects)` - Composite and draw the current state

### Effect System

- `shove.addEffect(layerName, effect)` - Add an effect to a layer
- `shove.removeEffect(layerName, effect)` - Remove an effect from a layer
- `shove.clearEffects(layerName)` - Clear all effects from a layer
- `shove.addGlobalEffect(effect)` - Add a global effect
- `shove.removeGlobalEffect(effect)` - Remove a global effect
- `shove.clearGlobalEffects()` - Clear all global effects
