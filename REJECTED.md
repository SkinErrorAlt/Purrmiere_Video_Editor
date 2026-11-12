# Rejected effects and transitions

Things that were built, shown to Ava, and taken out again because she did not want them.

**Read this before adding anything new.** If an idea on this page comes up again, it has already
been built once and rejected once. Do not rebuild it, do not rebuild it under a different name, and
do not rebuild it as a mode or a preset of something else. If there is a reason to revisit one, ask
Ava first and say that it is on this list.

The folders are gone from `project/transitions/` and `project/effects/`, the entries are gone from
`EFFECTS_AND_TRANSITIONS.md`, and the ids are gone from the suites in `project/tools/`. The ids are
kept here only so the names are not reused.

## Removed 2026-11-12, pass 54

Thrown on the keep or throw page (https://claude.ai/artifact/RdVLUic2HUEvJyuyxT7uqy):

- `wood_burn`, **Wood Burn** (Stylize): the picture burnt into pale wood like a laser engraver or pyrography pen,
  charring tan to black with the growth rings taking the burn deeper, smoke staining and raster lines.
- `blistering`, **Blistering** (Stylize): paint blisters swelling over the picture, lit and shadowed domes that
  burst onto rust, damp plaster or wood.

## Removed 2026-11-11, pass 52

From the pass 49 keep or throw page (https://claude.ai/artifact/RdVLUic2HUEvJyuyxT7uqy):

- `text_backdrop`, **Readable Backdrop** (Image Control): darkened or lightened only as much of the picture
  behind a text area as needed to reach a chosen contrast ratio for the text colour.

## Removed 2026-11-02, pass 36

Ava's reason, in her words: "These are being removed because I dislike the look of them and or they
feel low effort."

So the lesson is not only "not these fourteen". It is that a look which is only a geometric rule
applied to the frame reads as low effort however correct the maths is. Ten of the fourteen were a
shape swept over the picture or a panel rotated in space, with nothing in them that looked like the
real object they were named after.

### Transitions

| id | Name | Group | Why it went |
| --- | --- | --- | --- |
| `hourglass` | Hourglass | Shape | Sand through a waist, but it read as two bands sliding, not as falling sand. |
| `clock_hands` | Clock Hands | Wipe | A radar sweep claiming one ring per pass. A swept wedge and nothing more. |
| `zipper` | Zipper | Wipe | Teeth let go in pairs down the frame. The teeth did not look like metal. |
| `soap_bubbles` | Soap Bubbles | Particles | Bubbles as thin film lenses rising through the cut. |
| `accordion` | Accordion | Slide and Push | Bellows pleating shut to one side with alternate pleats shaded. |
| `dominoes` | Dominoes | 3D | A row of panels going over one by one. |
| `swing_card` | Swing Card | 3D | The incoming shot swinging down from a hinge on a damped pendulum. |
| `twirl_ribbon` | Twirl Ribbon | Distort | The frame wrung out to a twisted ribbon and unwound again. |
| `earthquake_crack` | Earthquake Crack | Glitch | A ragged crack heaving apart with the frame shaking. |
| `vertigo` | Vertigo | Zoom and Camera | A dolly zoom across the cut, push in while the lens pulls wide. |
| `paint_drip` | Paint Drip | Wipe | Paint poured in at one edge running down the frame. Rebuilt once from a lane wipe into a real sheet with rivulets, heavy heads and drops that break off and fall, and still cut. |

### Effects

| id | Name | Category | Why it went |
| --- | --- | --- | --- |
| `radio_waves` | Radio Waves | Generate | Rings going out from a point, widening and fading. |
| `griddler` | Griddler | Distort | Square tiles tipped on edge like a wall of louvres. |
| `lissajous` | Lissajous | Generate | The closed curve an oscilloscope draws from two tones. |
| `rainbow_arc` | Rainbow | Light & Shadow | A spectrum arc laid over the shot. |

### Cut after the rework

`paint_drip` was one of the seven sent back, was rebuilt from scratch as a sheet with real rivulets,
heavy heads and drops that break off and fall, and Ava cut it anyway. It is in the table above. The
lesson that one carries on its own: a rebuild does not save an idea she has already looked at twice.
If something comes back for rework a second time, ask whether she wants it at all before spending
another pass on it.

### What this leaves

Pass 32 shipped 50 items. 35 of them stay: 24 transitions and 11 effects. Seven of the survivors
were sent back for rework in the same message, six of those stayed, and all of it is written up in
`OUTSTANDING.md` under pass 36.

## The standing rule this came from

Already in memory as "important, convincing looks only; never fake UI or template graphics". Pass 36
adds the other half of it: a transition has to look like the thing it is named after, not like the
geometry of the thing it is named after. If the honest description of a look is "a shape sweeps
across" or "a panel rotates", it is not worth building.
