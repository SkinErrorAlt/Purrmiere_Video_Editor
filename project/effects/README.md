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

## Earlier frames (frame history)

An effect can read earlier frames of its own input, the picture entering the effect after
every effect above it, by adding a `history` block to `effect.json` and including the
engine's helper in its shader:

```
"history": {"max": 62, "reach": ["echoes", "echo_time"], "seconds": ["echo_time"]}
```

```
#include "res://engine/history.gdshaderinc"
...
vec4 now = texture(TEXTURE, UV);
vec4 back = history_between(age_in_frames, UV, now);
```

- `max` is the most frames the effect may ever look back (up to 62).
- `reach` says how far it looks back right now: the product of the named params, in frames
  of the sequence; a param listed in `seconds` is turned into frames first. Leave `reach` out
  to always keep `max` frames.
- `history_frame(age, uv, now)` reads the frame `age` sequence frames back (1 is the frame
  before this one), `history_between(age, uv, now)` mixes the two frames around a fractional
  age, and `history_has(age)` says whether that frame exists. `history_count` is how many
  frames back can be read and `history_fps` the sequence frame rate. A frame that does not
  exist returns `now`. Before the clip's first frame there are no earlier frames, so ages that
  reach past the start read the first frame.
- The frames are always the effect's input at the earlier frame times, never what happened
  to be shown. Playing at 1x feeds them as it goes; a jump, a step, a pause after fast play or
  an edit to anything above the effect rebuilds the missing frames from their times before the
  picture is called finished, so export, stepping and playback show the same frame. While
  playing with skipped frames the nearest kept frame stands in until playback stops.
- Each kept frame costs a picture the size of the effect's input on the graphics card
  (1080p: about 8 MB a frame), so keep `max` to what the look needs.

## Listening to the clip's sound (reactive listen)

An effect can react to sound with no keyframes by adding a `reactive` block to its
`effect.json`. The older form (`drive`, `level`, `wave`, `spectrum`, `beats`, used by the
`audio_*` effects) turns one band of the sound into one param. The `listen` form gives the
shader a whole set of measurements of the sound at once, read by `engine/sound_features.gd`:

```
"reactive": {"listen": true}
"reactive": {"listen": {"hits": 64, "past": "travel"}, "defaults": {"snd_threshold": 5.0}}
```

```
#include "res://engine/sound.gdshaderinc"
...
float push = snd_bass * amount;
```

Where the sound comes from is the same as every reactive effect: the Sound well, which
starts on the clip's own sound (a video clip's embedded audio, or its linked audio clip)
and also takes another clip or a file from the bin. The time used is the sound clip's own
source time, so its trim, its speed (keyframed speed too) and where the linked audio sits
on the timeline are all respected, and the Offset setting nudges it. An effect with only a
`listen` block shows Sound, By hand, Offset, Sensitivity (scales the levels and hit
strengths), Threshold (levels under it read 0, weaker hits are ignored) and Hit decay.

How it works: the first time a file is heard, the native envelope builder decodes it once
to 48 kHz mono and measures seven bands (full, 30 to 120 Hz, 120 to 400, 400 to 1500, 1500
to 4000, 4000 to 9000, 9000 to 16000) 200 times a second, and keeps that on disk beside the
media cache. One pass in GDScript then turns it into a table at 100 rows a second plus a list
of hits, kept in memory per file. Every value is looked up from that table at the frame's
time, so playback, pause, scrubbing, stepping and export see exactly the same numbers. Until
a new file has been read the values are all at rest and the compositor reports the sound as
pending, which export waits for before it writes the frame. 60 seconds of sound costs about
330 KB of envelope (in memory and on disk) and about 280 KB of table, and the feature pass
takes about 55 ms on top of the native read.

Levels are in decibels against the file's own loud parts (0 is 36 dB under them, 1 is about
3 dB over), so they move evenly with what you hear rather than jumping only on the loudest
peak. All of these are floats you read by declaring them, and the include declares them all:

| uniform | meaning |
|---|---|
| `snd_level` | overall loudness, 0 to 1, quick to rise and quick to fall |
| `snd_bass`, `snd_mid`, `snd_treble` | the same for 30 to 120 Hz, 400 to 4000 Hz, 4 to 16 kHz |
| `snd_voice` | how much it sounds like someone talking, 0 to 1: speech has syllables, its energy in the voice range and little deep bass, so music, engines and gunfire stay low |
| `snd_voice_slow` | the same, rising over about a second and falling over about three, for things that build while someone keeps talking |
| `snd_bright` | where the sound's weight sits, 0 deep to 1 bright (held at the last value through silence) |
| `snd_noise` | how harsh or noisy it is (flat spread of energy across the bands, such as explosions, static, wind, crowd hiss), only when it is also loud |
| `snd_sustain` | how held the sound is: it climbs over half a second while a sound keeps going and drops as soon as the sound breaks, so short hits never raise it |
| `snd_level_slow` | loudness rising over a second and falling over two and a half |
| `snd_hit` | the latest hit, its strength fading over Hit decay |
| `snd_hit_age` | seconds of timeline since the latest hit (1000 when there has been none) |
| `snd_hit_strength`, `snd_hit_seed`, `snd_hit_low` | the latest hit's strength, a fixed random number for it, and how much of its rise was below 400 Hz (0 a sharp crack, 1 a deep boom) |
| `snd_hits`, `snd_hit_sum` | how many hits, and their strengths added up, since the clip's sound began |
| `snd_quiet` | seconds of silence so far (0 while there is sound) |
| `snd_dose` | loud seconds heard since the clip began: the level added up over time, which never goes down within the clip |

Hits are found from sudden rises across the bands at once (at least 70 ms apart), land
within a few milliseconds of the sound, and syllables of speech count as weak hits.

`"hits": N` (up to 64) also fills `snd_hits_tex`, N texels wide, newest first, each
`(age in seconds, strength, seed, low)` with an age under 0 for an empty slot, and
`snd_hits_n` with how many are filled. `snd_hit_at(i)` in the include reads one. Only hits
since the clip's sound began are listed, so an effect can keep a record of all of them (the
Hit Fracture effect cracks once per big hit).

`"past": seconds` (a number or the key of a param) fills `snd_past_tex`, 64 texels covering
the last that many seconds, `(level, bass, voice, treble)`, and `snd_past(back)` reads it,
`back` 0 now and 1 the oldest. The Speaker Cone effect lays it out along the radius so a
boom rolls outward.

By hand sets every level to the Hand amount, with no hits. In the Effects panel preview card
the values are a fixed lively set so the card shows the look. A mix or nested sequence as the
source is not read by `listen` yet; the values stay at rest.

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
| `plane3d` with `"units": "frame"` | the same plane in the shared camera of PLANE_CONTRACT (frame heights, roll after swivel after tilt): corners scale, edge crosses tilt and swivel, the knob above the top edge rolls, dragging inside moves the offset | `tilt`, `swivel`, `roll`, `distance`, `fov`, `scale` (float params) and `offset` (a vec2 param), named like the effect's `depth` block |
| `regions` | the Pair View region boxes, which the engine draws itself | no fields |

A `point`, `line` or `quad` key names a `vec2` param read in UV, 0 at the top left
of the frame and 1 at the bottom right. An `angle` key names a float in degrees.
The four `edges` keys name floats from 0 to 1 measured inward from their own side,
so `right` 0.2 is a fifth of the way in from the right. An effect may list several
groups, and `crop`, `before_after`, `callout`, `corner_pin` and `transform_extra`
are the examples to copy.

In a multi pass effect, `px_scale` is the scale of that pass's input, so in the last pass of a down and up chain it can be 1/8 or 1/16, and neither `textureSize(effect_tex, 0)` nor `SCREEN_PIXEL_SIZE` gives the layer size there. A final pass that draws something a set number of pixels wide should read the output size from `fwidth(UV)` and convert `px_scale` to output pixels (see `photo_snap` and `focus_area`).

An effect that must draw over the whole frame, not only inside its clip's picture, adds `"canvas": "frame"` to its `effect.json` (see `blur_fill`, `pip_frame`, `split_screen`, `device_frame`). From its first pass on, the layer is drawn on a canvas of the frame's shape round the clip's fitted picture, the same canvas Pair View uses, so later effects, the monitor handles and clicks all work on the whole frame. Its passes get `source_box` (where the effect's input sits inside the canvas, in UV) and `canvas_px` (the canvas size). Every pass may also declare `seq_fps` to read the sequence frame rate.

## Text only effects

An effect that changes a title's characters rather than its picture declares
`"applies_to": "text"` and a `"text_transform"` naming one of the transforms in
`doc/text_fx/text_fx.gd` (`TRANSFORMS`), with `"passes": []` and
`"category": "Text"`. The 34 shipped ones are the `text_*` folders: ciphers,
encodings, hashes, AES and the horror and VHS helpers.

- They go on titles only. Dropping, double clicking, pasting or dragging one onto
  any other clip is refused with "Text effects go on titles only".
- They run in stack order before the title is laid out, each on the text the one
  above it made, so changing the order changes the result. A turned off one passes
  the text on. Amount changes that share of the text from the start.
- Their values are ordinary effect values: keyframes, presets and copy and paste
  all work. A `string` param with `"keyable": true` (a key, a passphrase, a hidden
  message) holds its value from key to key.
- Styling runs and the letter rig's per letter values follow the characters to
  where a transform moves them; when the length changes without a known map they
  are spread along the new text in proportion.
- Effect Controls shows, for each one, the text it gets, the text it gives and, in
  plain words, whether it can work on that input. The Effects panel's info for it
  shows a worked example.
