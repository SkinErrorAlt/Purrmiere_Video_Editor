# Effects

Every folder here is one effect: an `effect.json` that names the params and the
passes, plus one `.gdshader` file per pass. The engine loads these folders, the
`effects/` folder of every module, and everything you drop into `user://effects/`.

## Adding your own shader

Nothing here needs the app rebuilt, and nothing here needs a restart. The folder
button in the Effects panel opens the right place; Purrmiere notices a change
within about two seconds and reloads on its own, and the reload button beside it
does it at once. A clip already on screen picks up an edited shader straight
away, so you can keep the app open, save the file, and watch the picture change.

1. Drop a single `.gdshader` file into the effects folder. The file name becomes
   the effect id and its label, and it lands in the "User" category.
2. Drop a folder into it containing `effect.gdshader`, and optionally an
   `effect.json` when you want a label, a category, several passes or nicer
   param names.

The effects folder is `effects/` inside the data folder, which is
`Documents\Purrmiere` unless it has been moved. Settings shows the exact path at
the top and has a button to open it.

A single shader is one pass. Its uniforms become the effect's params:

- `float`, `int`, `bool`, `vec2`, `vec3`, `vec4`, `sampler2D` are supported.
- `hint_range(min, max, step)` gives the slider its range and step.
- `source_color` (or a plain `vec4`) makes a colour picker.
- `sampler2D` becomes a picture file param. It also takes a `.cube` LUT file: the
  engine turns a 3D cube of size N into an RGB float strip N times N wide and N high
  (x is red plus blue times N, y is green); a 1D cube or one with its own DOMAIN is
  resampled to a 33 cube over 0 to 1 first. `lut/effect.gdshader` reads it with
  `texelFetch` and tetrahedral interpolation, and also reads HALD pictures.
- The default written after `=` is the param default.

Every param is keyframeable in Effect Controls. Names the engine sets itself are
never exposed as params, and you can read them in your shader by declaring them:

| uniform | meaning |
|---|---|
| `vec2 tex_size` | size in pixels of the texture the pass reads (`TEXTURE`) |
| `vec2 seq_size` | size in pixels of the sequence |
| `float time` | sequence time in seconds |
| `float clip_time` | seconds since the clip started |
| `float clip_duration` | length of the clip in seconds |
| `float px_scale` | how many rendered pixels one source pixel is right now; multiply pixel sized params by it so preview quality, blur downsampling and the Effects panel preview card keep the same look |
| `sampler2D source_tex` | the layer's original picture before any effect |
| `sampler2D effect_tex` | the picture entering this effect (useful in the last pass of a multi pass effect) |
| `sampler2D layer_tex` | a picked layer, for compound effects (not wired in this stage) |

Read the picture with `texture(TEXTURE, UV)`. A helper function cannot read `TEXTURE` itself, so pass it in as a
`sampler2D` argument. Pictures travel between passes at 8 bits a channel, so no pass sees values over 1 or under 0. Colour is premultiplied by alpha:
if your effect changes colours, divide by `a` first and multiply back at the end
(see `levels/effect.gdshader` for the pattern). Write the result to `COLOR`. Do
not read the screen texture; it is not the layer.

The shader must start with `shader_type canvas_item;`. The engine adds
`render_mode blend_disabled;` when you did not set a blend mode, so what you
write to `COLOR` is exactly what the next pass reads.

A shader that fails to compile disables that effect, reports the file in the
Events panel, and never blanks the picture. The compiler's message is in the
console log.

`_example_user_shader/effect.gdshader` is a small example to copy.

Every effect also carries an **Amount** from 0 to 100 per cent, which Purrmiere
adds itself and blends back against the picture before the effect. So a shader
does not need an `amount` uniform of its own to be faded in or keyframed; write
the effect at full strength and let Amount do the rest. An effect sitting at 100
per cent costs nothing extra, because the blend pass is only built when the
amount moves off it.

## Multi pass effects (effect.json)

```
{
  "id": "my_effect", "label": "My Effect", "category": "Stylize",
  "tags": ["graphic", "look"],
  "params": [
    {"key": "radius", "label": "Radius", "type": "float", "min": 0, "max": 100, "step": 0.1, "default": 8},
    {"key": "kernel", "label": "Kernel", "type": "enum", "choices": ["Smooth", "Flat"], "default": 0},
    {"key": "tint", "label": "Tint", "type": "color", "default": [1, 1, 1, 1]}
  ],
  "passes": [
    {"shader": "down.gdshader", "scale": 0.5, "when": {"param": "radius", "gt": 60}},
    {"shader": "blur.gdshader", "set": {"direction": [1, 0]}},
    {"shader": "blur.gdshader", "set": {"direction": [0, 1]}, "repeat": {"param": "iterations", "max": 3}},
    {"shader": "up.gdshader", "scale": 2.0, "when": {"param": "radius", "gt": 60}, "inputs": {"level_tex": 0}}
  ]
}
```

- `scale` is relative to the previous pass (0.5 halves, 2.0 doubles, never above the layer size).
- `set` writes constants into uniforms of that pass.
- `map` writes a param into a uniform of another name: `"map": {"radius": "softness"}`.
- `when` skips the pass unless the param passes the test (`gt`, `gte`, `lt`, `lte`, `eq`, `ne`).
- `repeat` runs the pass N times where N comes from an int param.
- `inputs` binds the output of an earlier pass (by index) to a sampler uniform.
- `"passes": "single"` is the shorthand for one `effect.gdshader` with discovered params.
- A shader path starting with `res://` reuses a shader from another effect folder.
- `"passes": []` declares an effect the compositor handles itself (the frame rate limiter).

## Tags

`"tags"` is an optional list of short words on the effect itself, beside
`category`. A category says where an effect lives, and an effect has exactly one;
a tag says what an effect is, and an effect can carry several or none. The Effects
panel uses them to filter, and its search box matches them as well as the label,
the id, the group, the blurb and the category.

Tags are free text, so a new one needs no code: write it into `effect.json` and it
appears in the panel's filter menu the next time the effects reload. They are read
lowercased, trimmed, deduplicated and sorted, a bare string is read as a one tag
list, and anything that is neither a list nor a string is ignored rather than an
error. An `effect.json` with no `tags` key is completely normal.

The ones the shipped library uses:

| tag | meaning | shipped |
|---|---|---|
| `graphic` | a visual element drawn on top of the picture to be read as a graphic: lower thirds, callouts, bars, frames, stickers, backdrops, badges | 24 |
| `light` | light and lens behaviour: glows, flares, rays, leaks, lens dirt, star filters | 19 |
| `look` | an emulation of a real medium or a recognisable style: VHS, camcorder, comic, film stocks | 62 |
| `measure` | a technical check or readout rather than part of the finished picture: scopes, zebras, guides, test patterns | 14 |
| `repair` | fixes a fault in the footage: denoise, deband, deblock, lens correction, dust and scratches | 26 |

To retag an effect, edit the one `"tags"` line in its `effect.json`: that is the
only place a tag is written. Nothing is cached in a build and nothing needs a
reimport. Press the reload button in the Effects panel, or just wait about two
seconds, and the new tag is live.

Param types: `float`, `int`, `bool`, `enum`, `vec2`, `vec3`, `color`, `texture`,
`curve` (a `{"points": [[x, y], ...]}` dictionary the engine turns into a 256
entry lookup texture bound to a `sampler2D` of the param's key), `layer`, `string`.
An enum param may carry `"writes"`: a table of values per choice that the effect
controls write into the other params when the choice changes (the Compression
effect's tiers use it).

A param may also carry `"unit"`, the suffix Effect Controls puts after the number
(`" px"`, `" deg"`, `" s"`, `" %"` and so on). `" px"` is the one the engine reads
as well as prints: the Effects panel preview card renders at 256 px wide, so a
param measured in pixels would look far too big there. An effect whose shader
reads `px_scale` is already right, because the preview feeds it the card to
sequence ratio. For an effect whose shader does not read `px_scale`, the preview
shrinks every `" px"` param by that same ratio instead, so mark pixel sized params
with it. Nothing else in the app changes the value: playback and export always
pass what the slider says.

## Handles on the Program monitor

An effect can put draggable handles on the Program monitor with a `handles` list in
its `effect.json`. 99 of the shipped effects have one. The handles appear when the
effect's handle button in Effect Controls is on, and they drag the named params,
keyframing them like any other edit.

```
"handles": [{"kind": "point", "key": "centre"}, {"kind": "angle", "key": "angle", "about": "centre"}]
```

| kind | what it draws | fields |
|---|---|---|
| `point` | a ring per named param, dragged anywhere in the frame | `key`, or `keys` for several |
| `line` | the same rings joined by a line | `keys`, two or more; `curve`, `true` draws a smooth curve through them |
| `angle` | a spin handle out on a circle | `key`, the angle in degrees; `about`, the optional `vec2` param it turns around (the frame centre when left out) |
| `ring` | a circle or box sized by a float param, dragged at its edge | `key`, the float size; `key_y`, an optional second float for the height; `about`, the `vec2` centre; `unit`, `h` (frame heights, the default) or `uv`; `scale`, from param to drawn size; `shape`, `circle` (the default) or `box`; `stretch`, `rotate` and `feather`, optional float params for the aspect, the turn and the soft edge; `feather_mode`, `add` (the default) or `outer`; `feather_scale` |
| `band` | a straight band across the frame with a middle bar, solid edges and dashed falloff lines | `key`, the float position of the band; `width`, the float height of the band; `feather`, the float falloff; `axis_from`, an optional param that stands the band upright |
| `quad` | four corners that move independently | `keys`, exactly four, ordered top left, top right, bottom right, bottom left |
| `edges` | one handle per side of a box | `left`, `top`, `right`, `bottom`, each the key of a float param; any side may be left out and gets no handle |
| `plane3d` | a 3D plane with corner and edge handles | `tilt`, `swivel`, `scale`, `distance`, `lens`, `skew_x`, `skew_y`, each the key of a float param |
| `regions` | the Pair View region boxes, which the engine draws itself | no fields |

A `point`, `line` or `quad` key names a `vec2` param read in UV, 0 at the top left
of the frame and 1 at the bottom right. An `angle` key names a float in degrees.
The four `edges` keys name floats from 0 to 1 measured inward from their own side,
so `right` 0.2 is a fifth of the way in from the right. An effect may list several
groups, and `crop`, `before_after`, `callout`, `corner_pin` and `transform_extra`
are the examples to copy.

In a multi pass effect, `px_scale` is the scale of that pass's input, so in the last pass of a down and up chain it can be 1/8 or 1/16, and neither `textureSize(effect_tex, 0)` nor `SCREEN_PIXEL_SIZE` gives the layer size there. A final pass that draws something a set number of pixels wide should read the output size from `fwidth(UV)` and convert `px_scale` to output pixels (see `photo_snap` and `focus_area`).

An effect that must draw over the whole frame, not only inside its clip's picture, adds `"canvas": "frame"` to its `effect.json` (see `blur_fill`, `pip_frame`, `split_screen`, `device_frame`). From its first pass on, the layer is drawn on a canvas of the frame's shape round the clip's fitted picture, the same canvas Pair View uses, so later effects, the monitor handles and clicks all work on the whole frame. Its passes get `source_box` (where the effect's input sits inside the canvas, in UV) and `canvas_px` (the canvas size). Every pass may also declare `seq_fps` to read the sequence frame rate.
