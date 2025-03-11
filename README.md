# Shöve 📐
Shöve is a simple resolution-handling library for [LÖVE](https://love2d.org/) that allows you to focus on making your game with a fixed resolution.
It is forked from from the [push](https://github.com/Ulydev/push) `dev` branch, includes community contributed fixes 🩹 with additional features and API changes from the team at [Oval Tutu](https://oval-tutu.com) 🩰

## Quick start

This example creates a 1920x1080 resizable window and sets Shöve to a scaled resolution.
Under the "Draw stuff here!" comment, add some drawing functions to see Shöve in action!
```lua
shove = require("shove")

love.window.setMode(1920, 1080, {resizable = true}) -- Resizable 1920x1080 window
shove.setupScreen(1920, 1080, {scaler = "normal"}) -- 1920x1080 game resolution, scaled

-- Make sure shove follows LÖVE's resizes
function love.resize(width, height)
  shove.resize(width, height)
end

function love.draw()
  shove.start()
    -- Draw stuff here!
  shove.finish()
end
```

### Demo

Run `love demo/` to view all the demos.
Press <kbd>SPACE</kbd> to switch between them.

## Usage

After applying changes to LÖVE's window using `love.window.setMode()`, initialise Shöve:
```lua
shove.setupScreen(shoveWidth, shoveHeight, {scaler = ..., canvas = ...})
```
`shoveWidth` and `shoveHeight` represent Shöve's fixed resolution.

The last argument is a table containing settings for Shöve:
* `scaler` (string): upscale Shöve's resolution to the current window size
  * `"normal"`: fit to the current window size, preserving aspect ratio
  * `"pixel-perfect"`: pixel-perfect scaling using integer scaling (for values ≥1, otherwise uses normal scaling)
  * `"stretched"`: stretch to the current window size
* `canvas` (bool): use and upscale canvas set to Shöve's resolution

Hook Shöve into the `love.resize()` function so that it follows LÖVE's resizes:
```lua
function love.resize(width, height)
  shove.resize(width, height)
end

Finally, apply Shöve transforms:
```lua
function love.draw()
  shove.start()
    -- Draw stuff here!
  shove.finish()
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
Shöve provides basic canvas and shader functionality through the `canvas` flag in `shove.setupScreen()` and `shove.setShader()`, but you can also create additional canvases, name them for later use and apply multiple shaders to them.

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
Simply call it once, and it will be stored into **Shöve** until you change it back to something else.
If no `canvasName` is passed, shader will apply to the final render. Use it at your advantage to combine shader effects.

Convert coordinates:
```lua
shove.toGame(x, y) -- Convert coordinates from screen to game (useful for mouse position)
-- shove.toGame will return false for values that are outside the game, be sure to check that before using them!

shove.toReal(x, y) -- Convert coordinates from game to screen
```

Get game dimensions:
```lua
shove.getWidth() -- Returns game width

shove.getHeight() -- Returns game height

shove.getDimensions() -- Returns shove.getWidth(), shove.getHeight()
```
