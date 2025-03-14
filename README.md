# Shöve 📐
**A resolution-handling and rendering library for [LÖVE](https://love2d.org/)**

Shöve is a powerful, flexible resolution-handling and rendering library for the LÖVE framework.
Using Shöve, you can develop your game at a fixed resolution while scaling to fit the window or screen - all with a simple, intuitive API.

Shöve started as a fork of the popular [push](https://github.com/Ulydev/push) library, building on its solid foundation and incorporating community contributed fixes and improvements with additional features and API changes built by the team at [Oval Tutu](https://oval-tutu.com) 🩰

## Why Shöve?

Shöve was takes the [`dev` branch of push](https://github.com/Ulydev/push/tree/dev) and redesigns the API and builds on its Canvas rendering concept to create a powerful and intuitive library that can handle complex rendering scenarios.

- Create pixel-perfect games that scale beautifully 👾
- Organize drawing operations logically 📝
- Apply visual effects with ease ✨
- Never worry about different screen sizes again 💪

Shöve has a clean API with with consistent naming patterns that offers a **progressive learning curve where you can start simple, add complexity as needed**. ‍🧑‍🎓

## Quick Start

Here's a basic example to get started with Shöve.

```lua
shove = require("shove")

function love.load()
  -- Initialize Shöve with fixed game resolution and options
  shove.initResolution(800, 600, {
    fitMethod = "pixel", -- "pixel", "aspect", "stretch", or "none"
    renderMode = "direct" -- "direct" or "layer"
  })
  -- Set up a resizable window
  shove.setMode(1280, 720, {resizable = true})
end

function love.resize(width, height)
  -- Update Shöve when window/screen size changes
  shove.resize(width, height)
end

function love.draw()
  shove.beginDraw()
    -- Draw your game here
    love.graphics.rectangle("fill", 50, 50, 200, 150)
  shove.endDraw()
end
```

You can now draw your game at a fixed resolution and have it scale to fit the window.

**💡 NOTE!** That is all you need to get started! **Everything else that follows is optional**, but very tasty 👅

## Key Features

Shöve offers two render modes:

- **Direct Mode**: Simple scaling and positioning, similar to the original push library
- **Layer Mode**: Advanced rendering with support for multiple layers, effects, and compositing

### Complete Resolution Management 📏

- **Multiple Fit Methods**: Choose from aspect-preserving, pixel-perfect, stretch, or no scaling
- **Dynamic Resizing**: Responds instantly to window/screen changes
- **Coordinate Conversion**: Seamlessly map between screen and game coordinates

### Layer-Based Rendering 🥞

- **Layer-Based System**: Organize your rendering into logical layers
- **Z-Order Control**: Easily change which layers appear on top
- **Visibility Toggling**: Show or hide entire layers with a single call
- **Complex UIs**: Put your HUD, menus, dialogs, and tooltips on separate layers for easy management.

### Effect Pipeline ✨

- **Per-Layer Effects**: Apply shaders to specific layers only
- **Global Effects**: Transform your entire game with post-processing
- **Effect Chaining**: Combine multiple shaders for complex visual styles
- **Smart Masking**: Use any layer as a mask for another

# Demo ️🕹️

The complete suite of demos can originally be found in push have been ported to Shöve and can be found in the `demo/` directory.

- Run `love demo/` to view all the demos.
- While running a demo resize the window to see how the resolution changes.
- Press <kbd>f</kbd> to toggle fullscreen.
- Press <kbd>SPACE</kbd> to to cycle through the demos.
- Press <kbd>ESC</kbd> to exit the demo.

## What is included in the demo?

- **low-res:** Demonstrates pixel-perfect scaling with a tiny 64x64 resolution.
  - Shows how to use layer-based rendering for a retro-style game with an animated text effect.
  - Also includes mouse coordinate conversion to display a custom cursor.
- **single-shader:** Shows how to apply a shader to a specific layer.
  - Demonstrates creating a layer, adding an effect to it, and animating shader parameters over time for dynamic visual effects.
- **multiple-shaders:** Illustrates how to chain multiple shaders together using global effects.
  - Shows how global effects are applied to the entire rendering output, creating complex visual transformations by combining shader effects.
- **mouse-input:** Focuses on coordinate conversion between screen and viewport spaces.
  - Demonstrates how to check if the mouse is inside the viewport and convert coordinates appropriately, essential for handling input in games with scaled resolution.
- **canvases-shaders**: Shows advanced layering with different effects applied to different layers.
  - Demonstrates using both layer-specific shaders and global shaders simultaneously, allowing for more complex visual compositions.
- **stencil:** Illustrates how to use the stencil buffer with Shöve's layer system.
  - Shows how to create complex masking effects with stencil testing, allowing you to limit rendering to specific shapes or areas.
- **mask:** Demonstrates Shöve's layer masking capabilities.
  - Shows how to use one layer as a mask for another, allowing you to create dynamic visibility effects where one layer controls what's visible in another.

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
shove.initResolution(320, 240, {fitMethod = "pixel"})
```

### Scaling Filters

The `scalingFilter` option determines how textures are scaled when rendering your game. Here's how it works:

You can set `scalingFilter` in two ways:

1. **At initialization:**
   ```lua
   shove.initResolution(800, 600, {
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
Set the window dimensions and properties with automatic resize handling using `shove.setMode(width, height, flags)`.

**💡 NOTE:** For best results, call `shove.initResolution()` before using these window management functions to ensure proper viewport initialization.


```lua
-- Create a window half the size of the desktop
local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
shove.setMode(desktopWidth * 0.5, desktopHeight * 0.5, {
  resizable = true,
  vsync = true,
  minwidth = 400,
  minheight = 300
})
```

Use `shove.updateMode(width, height, flags)` to change the window size and properties.

## Render Modes

### Direct Rendering

Direct rendering is simple and lightweight.
It's suitable for games that don't need advanced rendering features.

**💡NOTE!** With direct rendering enabled, none of the layer rendering or effects functions are available.

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

Shöve's layer-based rendering system brings the power and flexibility of professional creative software to your LÖVE games.
If you've ever used image editing, video production, or design tools, you'll immediately grasp what makes layers so valuable.

Conceptually, Shöve's layer-based rendering is like the layers in **Adobe Photoshop** or **Figma** – separate "sheets" that contain different elements of your game's visuals. Each layer exists independently but combines to create your complete scene.

Just as you might put background elements on one Photoshop layer, characters on another, and UI elements on a third, Shöve lets you organize your game's rendering the same way. Imagine you're creating a game with a complex UI system.
With traditional rendering, each frame requires carefully ordering every element:

```lua
-- Traditional approach
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
-- Layer approach
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

  shove.setLayerVisible("debug", debugMode)
  shove.beginLayer("debug")
    drawDebugInfo() -- Only rendered when debugMode is true
  shove.endLayer()
shove.endDraw()
```

Many of the benefits of Shöve's layers are similar to those in professional creative software:

- **Independent Control**: You can hide, show, or modify layers without affecting others
- **Z-Ordering**: You can change which elements appear on top by adjusting layer order
- **Effect Application**: Apply effects (shaders) to specific layers without affecting everything
- **Masking**: Create masking effects where one layer controls the visibility of another

For game developers specifically, layers offer powerful advantages:

- **Visual Debugging**: Toggle debug visualization layers on/off like in **Unity's Scene View**
- **Complex Effects**: Create advanced visual effects like reflections, lighting, or weather systems on isolated layers
- **State Management**: Show/hide entire game states (menus, dialogs, cutscenes) by controlling layer visibility
- **Composition**: Build up scenes from reusable components

Layer rendering provides powerful features for organizing your rendering into separate layers that can be manipulated independently.
Under the hood, Shöve uses [LÖVE's Canvas system](https://love2d.org/wiki/Canvas) to achieve this, but hides the complexity behind a simple API.

```lua
shove = require("shove")
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

Shöve provides functions to convert between screen and game viewport coordinates:

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

While Shöve automatically creates layers when you first reference them with `beginLayer()`, there are several compelling reasons to manually create layers with `createLayer()` instead:

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

`drawToLayer()` provides a convenient way to temporarily switch to a different layer, perform drawing operations, and then automatically return to the previous layer - all without disrupting your main drawing flow.
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
  shove.drawToLayer("particles", function()
    spawnExplosionParticles(x, y)
  end)

  -- Continue with normal drawing flow
  shove.beginLayer("ui")
    drawUI()
  shove.endLayer()
shove.endDraw()
```

Here are some good use cases for `drawToLayer()`:

1. **Isolated drawing tasks**: When you need to draw to multiple layers but want to keep your code organized.
2. **Reusable drawing functions**: Create modular drawing functions that can be applied to any layer.
3. **Dynamic UI elements**: Draw UI components (like tooltips or notifications) to their own layers without breaking your main drawing flow.
4. **Temporary effects**: Draw short-lived visual effects to dedicated layers.
5. **State-based drawing**: Switch layers based on game state without complex conditional logic.

### Manual Compositing

The `compositeAndDraw()` function performs an intermediate composite and draw operation during an active drawing cycle.
Specifically, it:

1. Takes all layers that have been drawn so far in the current frame
2. Composites these layers together according to their z-index ordering
3. Applies transient global effects that are passed as an argument
4. Applied persistent global effects only when specifically requested
5. Renders this composite using the configured fit method
6. Critically, **it does not end the drawing process**, allowing further layers to be drawn afterward

This differs from the typical `beginDraw()`/`endDraw()` cycle, where compositing and drawing only happen at the end when `endDraw()` is called.

The `compositeAndDraw()` function provides a powerful tool for advanced rendering techniques.
It gives you finer control over the rendering pipeline by allowing intermediate compositing and drawing operations within a single frame.

- `compositeAndDraw()` → Composite and draw the current state with no transient or persistent effects
- `compositeAndDraw({anEffect}, false)` → Composite and draw the current state with a transient effect
- `compositeAndDraw({anEffect, anotherEffect}, true)` → Composite and draw the current state with transient and persistent effects
- `compositeAndDraw(nil, true)` → Composite and draw the current state with persistent effects

While most games won't need this level of control, it can be useful for complex visual effects, multi-stage rendering, debugging, or interactive applications that need to respond to partially-rendered content.
You can manually trigger the compositing process before the end of drawing:

### When to Use `compositeAndDraw()`

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
  shove.compositeAndDraw()

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
  shove.compositeAndDraw()

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
  shove.compositeAndDraw()

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

### Debug Visualization

Shöve includes a built-in debug overlay that provides real-time information about resolution management, layer status, and rendering performance.
This can help diagnose scaling issues and optimize your game.

#### Integration

To enable the debug visualization in your project, add a call to `shove.debugHandler()` at the end of your `love.draw` function:

```lua
function love.draw()
  -- Start Shöve rendering
  shove.beginDraw()

  -- Your game drawing code
  -- ...

  -- End Shöve rendering
  shove.endDraw()

  -- Add debug visualization (must be after shove.endDraw)
  shove.debugHandler()
end
```

#### Function Keys

The debug display responds to the following function keys:

- **F1**: Full debug info (resolution, layers, and performance)
- **F2**: Basic info + performance metrics
- **F3**: Basic info + layer details
- **F4**: Basic resolution information only

#### Custom Integration

If you need different keys or display positions, you can use `shove.debugInfo()` directly:

```lua
-- In your draw function
if love.keyboard.isDown("tab") then
  -- Custom position (top-left) and configuration
  shove.debugInfo(10, 10, {
    showLayers = true,
    showPerformance = love.keyboard.isDown("lshift")
  })
end
```

## API Reference

### Initialization and Setup

- `shove.initResolution(width, height, options)` - Initialize with game resolution
- `shove.setMode(width, height, options)` - Set window mode
- `shove.updateMode(width, height, options)` - Update window mode
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
- `shove.debugHandler()` - Display debug information
- `shove.debugInfo(x, y, options)` - Display custom debug information

### Layer Operations

- `shove.beginLayer(name)` - Start drawing to a layer
- `shove.endLayer()` - Finish drawing to a layer
- `shove.createLayer(name, options)` - Create a new layer
- `shove.removeLayer(name)` - Remove a layer
- `shove.layerExists(name)` - Check if a layer exists
- `shove.getLayerOrder(name)` - Get layer drawing order
- `shove.setLayerOrder(name, zIndex)` - Set layer drawing order
- `shove.isLayerVisible(name)` - Check if a layer is visible
- `shove.setLayerVisible(name, isVisible)` - Toggle layer visibility
- `shove.setLayerMask(name, maskName)` - Set a layer as a mask
- `shove.drawToLayer(name, drawFunc)` - Draw to a layer with a callback
- `shove.compositeAndDraw(globalEffects, applyPersistentEffects)` - Composite and draw the current state

### Effect System

- `shove.addEffect(layerName, effect)` - Add an effect to a layer
- `shove.removeEffect(layerName, effect)` - Remove an effect from a layer
- `shove.clearEffects(layerName)` - Clear all effects from a layer
- `shove.addGlobalEffect(effect)` - Add a global effect
- `shove.removeGlobalEffect(effect)` - Remove a global effect
- `shove.clearGlobalEffects()` - Clear all global effects
