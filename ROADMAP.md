# Purrmiere roadmap

**Reconciled against the code on 2026-11-05.** Five items this file still listed as to-do were found already
shipped and are now marked so; do not rebuild them. A page of what is genuinely left, grouped and with the
big items flagged: https://claude.ai/artifact/Bof4vc47bGntv9nKHFnFWx

The full backlog, captured from Ava's 2026-10-31 "everything" dump plus the earlier lists. Organized
by theme; faithful to intent, paraphrased. Status: [ ] not started, [~] in progress, [x] done.
Effect/transition requests are also tracked in `EFFECTS_AND_TRANSITIONS.md`; open bugs in `BUGS.md`.

## Audit results (2026-10-31, backlog-audit workflow — verified against code)

**Already DONE** (do not rebuild): #13 PairView keyframes default to Hold (`key_defaults.gd`);
#6d audio track labels Mic/Game/Discord + "Track names" preset (`stream_roles.gd`); #6e per-view
audio passthrough / routing / "always heard" / per-view offset (`view_map/view_streams/audio_graph/
pv_audio/offset_editor`); #5 easier EQ control (many EQ effects incl. simple one-knob ones).

**PARTIAL** (infra exists; only the specific gap is open): #1 transition linger+freeze (hold-prev +
prefetch exist; freeze = transition shaders compile on first use, no playback prewarm → add prewarm);
#11 audio cut-out right of cut (prime-ahead exists; HDD latency not covered → widen prime window);
#15 launch freeze (shader-warm deferral exists; re-reported → investigate); #6a view colouring (auto
colours applied; user colour-PICK + save-in-preset missing — small); #4 text snap (snap system works
but uses full-frame box; wire `TitleBounds` tight box — small); EQ draggable curve (curve widget
exists for video curves; no audio EQ uses it → wire to an EQ); #7 3D audio (2D angle/distance pan is
keyframeable; 3D orbit view + tracking link + range-mask missing); #8 move tool (Track-Select fwd/back
exists; "laggy/unreliable" unaddressed); #10 sub-video swap (replace-footage exists; cross-clip align
markers missing); #6f per-view SFX (works via routing; no dedicated feature); encryption/scramble
(`tile_scramble` exists but has a seed; wants no-seed + re-randomize button); outlines (multi_outline/
stroke/electric_edge/mask-draw exist; missing ripple style, bezier curves, outlines-carry-effects,
attach-to-follow); paper cutout (exists, not Spider-Verse quality); #16 project select (manual
thumbnail exists; auto last-frame + list/grouping + multi-project combine missing).

**MISSING** (build from scratch): #6b PairView border frame per view; #6c PairView solo-view-on-
timeline (deadspace/overlap-warn/auto-fix); #2 pairview audio switch latency; #3 multi-select effects
+ save subset as preset; #9 slide-tool rework; audio adjustment layers; physics object/ball spawner;
range/measure text.

Overnight focus: EFFECTS & TRANSITIONS (buildable + testable headlessly). App-subsystem features
(pair view, audio menus, timeline tools) are specced and flagged — riskier to do without GUI testing.

## Flagship physics / visual effects

- [~] **Crumble 3D** - picture breaks into real 3D pieces, native baked collision, tumble, reveal
  behind. Native bake done (<1 ms, deterministic); 3D render proof done; being wired into the live
  compositor now. See `docs/27`.
- [ ] **Glass breaking** (NEW #1) - breaks where you click, realistically, with particles; the glass
  refracts the video properly; a toggle to have the video be *behind* the glass instead of *being*
  the glass. (Reuses the physics bake + 3D pieces + a refraction shader.)
- [ ] **Physics object spawner** - spawn balls/shapes (and images, and black/white shapes as
  colliders) triggered by a keyframe (like a button) or a beat. Per-object: shape, material presets,
  gravity (incl. low-grav preset), velocity, bake toggle. Collides with other objects and with
  invisible bounding boxes (so things can land on tabs/UI). Mouse-draggable, and the object's
  velocity/position can be plugged into other params. Choose whether screen bounds are ground (all
  sides or only some). Math/material presets.
- [ ] **Outlines system** - electric outline that glows and ripples, many outline types + custom
  ones, settings. Outlines can themselves carry other effects (incl. transition effects). Apply to
  inside/outside of images, gifs, videos, crops, masks of any kind. A drawing tool (points + curves,
  mask-style, not slow tracing) that can be attached by dragging an attach handle onto anything so it
  follows that thing.
- [ ] 40+ more effects/transitions, mostly physics-based (see Transitions and Effects sections).

## Transitions

- [x] Reveal (`reveal`, v1.1), Dispersion Wipe (`dispersion_wipe`) - built; Reveal still to render on
  the showcase page.
- [x] **Shipped 2026-10-31 (11 new, on the Transitions page v11, 220 total):** Luma Warp, Ink in Water,
  Datamosh Bloom, Rack Focus, Anime Speed Lines, Shockwave, Hyperspace Warp, Anamorphic Flare, Motion
  Whip, Zoom Punch, Invert Flash. Research of 46 unique ones in `docs/29_TRANSITION_PROPOSALS.json`;
  the other 35 (incl. physics ones: Liquid Pour, Cloth Drop, Sand Dissolve, Glass Smash, Domino
  Cascade, etc.) are queued - the physics ones reuse the Glass/Crumble native bake + 3D pass.
- [ ] **50 more unique transitions** - find the weak spots other programs filled and attack there;
  plus meme transitions from YouTube/other sources. Compile onto a board/page; right-click a
  transition -> "rework" to write a spec (with images) saved to a file describing exactly what's
  wanted. (This rework-request flow itself is a feature to build.)
- [x] Cut Through Black - hard dip to black between shots. SHIPPED as the `cut_through_black` transition; verified in the tree 2026-11-05.
- [ ] More physics-based transitions (bake + randomness): fluid flow, physical shatter/scatter, etc.

## Effects (non-physics)

- [x] Crumble (shader draft, `crumble`, v1.2), Frequency Separation (`frequency_separation`).
- [x] **Shipped 2026-10-31:** Comic Halftone (`comic_halftone`, Spider-Verse CMYK dots + ink, v1.5),
  Pixel Scramble (`pixel_scramble`, privacy/encrypt mosaic, v1.4). On the Effects page v5.
  Physics flagships shipped same day: Crumble 3D (`crumble_3d`, v1.3), Glass Break (`glass_break`, v1.6).
- [ ] More from **Photoshop and Photoshop-like programs** (beyond the ~73 already added).
- [ ] **Advanced colour grading** - toward DaVinci level and beyond, with ways to break the skill
  barrier DaVinci has (make pro grading approachable).
- [ ] **Encryption / pixelate-scramble** effect - randomize the big pixels / scramble while keeping
  it looking good, or full scramble; randomness options (no seed) + a single "re-randomize" button.
- [ ] **Paper cut-out** fix - should look like the Spider-Verse paper character; current one falls
  short.
- [ ] **Range/measure text** - select ranges and display them as numbers (e.g. total length of all),
  and other readouts.

## Audio

- [ ] **Audio adjustment layers.**
- [ ] **EQ menu** - draggable points on a curve (like audio editors), curve shaping per point like a
  keyframe; more physical "break it down and show the audio" menus for audio effects.
- [x] Easier EQ-control effect. SHIPPED as several one-knob EQ effects. The DRAGGABLE CURVE is the part still open, listed above.
- [ ] **3D tracked audio** - audio can be 3D via tracking: range limits, smooth L/R equalization that
  still conveys direction, lock to specific hearing ranges. Custom view with value sliders AND a 3D
  preview (left-click orbit, move points to "mask" the range). Keyframeable.

## Pair View

- [x] Colour the different views (e.g. pink for one, blue for another); save those colours in presets
  so they line up. SHIPPED 2026-11-06: a Colour submenu on each view's right click in the Views panel, the 16
  named label colours plus Pick its own. The view already carried a colour and the preset already saved it;
  only the picker was missing. Palette index, not a free colour, because the same number colours the timeline
  clips. `pass41_view_colour_test`.
- [x] Presets save audio per track too: labels (Mic / Game / Discord), passthrough and per-track offset.
  SHIPPED: `doc/stream_roles.gd` carries the labels, with view_streams / audio_graph / pv_audio / offset_editor
  behind them; verified 2026-11-05.
- [x] Per-view sound effects / specifics (add SFX to a specific view). SHIPPED 2026-11-06: right click a
  sound clip, "Heard only in", pick the views. The model could already do it (`ViewMap.hears` checks a view's
  clips before its tracks) and nothing ever wrote it. `pass41_view_sfx_test`.
- [~] **Solo a view on the timeline** SHIPPED 2026-11-06 except the collapse: solo by view name across every
  Pair View clip, built as a mode of the existing timeline filter, saved in `track_view`. Deadspace toggle,
  movement locked by default, red overlap bands, the Keep overlapping / Cut the covered / Nudge to fit popup,
  and Go to the next overlap as a bindable command. `ui/timeline/timeline_view_solo.gd`,
  `pass41_view_solo_test` 94/0. **Left, and it needs Ava:** drawing the soloed clips collapsed together needs
  a display time map on both the canvas and the hit test, or a destructive ripple whose sync rules are hers to
  set. Also hers: with movement off every clip is locked, not only the soloed view's.
- [~] **Border frame per view** SHIPPED 2026-11-06 except an animated border: a picture of her own per view,
  its opening found from the picture's own transparency (flood filled from the edge so cut-outs are not
  mistaken for the opening), a per view keyframeable zoom inside it (the global `zoom` was shared by every
  view, so this did not exist), and the view's name on a plate drawn from one packed strip. Costs under the
  measurement's own noise. `doc/view_border.gd`, `pass41_view_border_test` 52/0. **Left:** a looping video or
  gif as the border, and a frame on a Picture in Picture inset. **Watch `[E-101]`:** the shader now wants 18
  samplers against Vulkan's promised floor of 16, which matters for the friend's standalone build.
- [x] **Sub-video replace** SHIPPED 2026-11-06: a sync mark is a new marker kind, so no format change and it
  appears in the Kind dropdown for free. Drop one on a moment visible in both recordings, then "Replace with
  it, lined up on the sync marks". Says which side is missing a mark, and says how far short it fell when the
  new recording cannot reach. `doc/sync_align.gd`, `pass41_subvideo_test`.
- [x] Selecting or deleting takes the whole thing unless a modifier is held (Ava, 2026-11-06: "ensuring
  when deleting/selecting something without holding a specific button... it will select the entire thing. In
  pair view it doesn't currently"). SHIPPED: the modifier was already Ctrl and already worked; what failed
  was what counted as "the whole thing". `move_rule.own_partners` only took a linked clip when the overlap
  was one for one, and a Pair View is one long recording over several short pieces a track, so it took
  nothing. Measured: clicking the recording took 1 piece of 9, now 9. `move_rule.pair_bound` /
  `pair_videos_over` decide it, `pass41_pair_pick_test`.
- [ ] More pair-view ideas TBD.

## Transitions and objects

- [x] **Transitions placed anywhere, not just between two clips** SHIPPED 2026-11-06: a track holds free
  standing ones, `doc/free_transition.gd`, blending to the track below and to transparent when there is
  nothing there. Migration 2 to 3 is a data no-op on existing projects, proved by deep equality; saved
  projects render 0 of 255 different. `pass45_free_transition_test` 88/0. **Left:** Effect Controls does not
  show a selected free one, and ripple and roll do not move them. **Watch `[D-030]`**: an older build that
  re-saves such a project drops them.
- [x] **The cut out object as its own source** SHIPPED 2026-11-06, linked per decision 2, 3.9 us a frame to
  follow the link. `doc/object_source.gd`, `pass45_object_source_test` 79/0. **Left:** no Bake, and a speed
  ramp on the source clip cannot be carried.
- [x] **A stand in character while the rest has not arrived** SHIPPED 2026-11-06 as the decode look,
  `doc/text_decode.gd`, deterministic per frame, default off, `pass45_text_decode_test` 85/0.
- [ ] **Soloed clips drawn collapsed together** (decision 4): not built. It needs one display time map applied
  in both directions from `timeline_canvas.gd` and `timeline_paint.gd`, which were held by the transitions
  rewrite. Wants a pass of its own that owns those two files.

## Editing tools

- [ ] **Move tool** (from-click ripple) - grab everything from where you click to the end (clips,
  SFX, all) and move it; must be fully optimized / not laggy, so you can make room.
- [ ] **Slide tool** rework - hard to use today; near a cut just move it. In a pair-view clip at a
  view-switch cut, stretch the keyframe position so it lines up with the cut, moving only that
  specific "cut" keyframe, not all keyframes.
- [ ] **Multi-select effects** - select more than one effect; right-click multiple selected -> save as
  a preset.
- [ ] **Text snapping** - snap with a bounding box like Premiere Pro.

## Timeline / keyframes

- [ ] Multi-instance timeline keyframing - select multiple things and keyframe; show a line for every
  instance's location so you can track as it changes. A toggle to copy instead (the current behavior).
- [x] #12 live-keyframe stray key on release - fixed.
- [x] #13 PairView keyframe defaults to **Hold**. SHIPPED: `doc/key_defaults.gd` holds view, view2, layout, grid, view_mode, group and sound_view; verified 2026-11-05.

## Bugs

- [ ] #1 transition shows previous frame ~1 s after a cut; full-speed playback sometimes freezes.
- [ ] #11 audio cuts out on the right side of a cut, then returns (slower on HDD). Diagnosed
  (`BUGS.md` [A-040]); needs native fix.
- [ ] #2 pair-view audio doesn't show for a moment before cutting in; must be near-instant.
- [ ] #15 app freezes for a while on launch.

## Text presets and the curve

- [x] **Text presets with a browser, her own presets and her own groups** (Ava, 2026-11-06, point 7). SHIPPED:
  `modules/core_panels/text_presets_sheet.gd` with a real render per row, search, group chips, and her own
  presets saved as ordinary `text_style` presets tagged into groups, so no new preset kind and no schema
  change. Seven built-in finished looks, since the 12 that existed set only the animation.
  `pass44_text_presets_test` 152/0 headless, 167/0 windowed.
- [x] **A gizmo for bending text round a curve** SHIPPED: `modules/core_panels/monitor_text_path.gd`, drawn on
  the Program monitor with grab points for arc, circle and wave, and a dot per point on a drawn path with the
  mask pen's own add and remove gestures. Four guards keep it from stealing a click.
  `pass44_text_path_gizmo_test` 76/0, saved titles render at worst 0 of 255 different.
- [x] **How much of the text has appeared, as a count** SHIPPED: `reveal_count`, keyframeable, default -1
  meaning off so every saved title is unchanged.
- [ ] **A stand-in character while the rest has not arrived** (the other reading of "what character will
  appear"): junk letters in the unsettled positions, a decode look. Needs a character pool, a settle order and
  a reseed. **Waiting on Ava** to say whether this is what she meant.

## Bin

- [x] **A shelf in the bin sidebar** (Ava, 2026-11-06: "a way to pin folders and locations of the folder to the
  bin so then you can just access them really fast like in other editing software... like having it on the
  side bar which is collapseable and you just drag and put a folder but also files if you want to the sidebar.
  I want it so you can even create sub collapseable tabs so you create tabs of how many you want with whatever
  you want also colorable and nameable"). Model built and tested: `doc/bin_shelf.gd`, `pass43_bin_shelf_test`
  46/0, 44/2 with PLANT. Tabs she makes, each nameable, colourable from the same 16 colour palette clips and
  markers use, and collapsible, holding folders and files. Machine wide in `Prefs`, nothing in the project
  file. SHIPPED: the sidebar is `modules/core_panels/bin_shelf_view.gd`, default shut so the bin is unchanged
  for anyone who never opens it, drag a folder or file from Windows onto a tab to pin it, click a file to
  import it or a folder to open the picker already there. `pass43_bin_shelf_ui_test` 87/0. Left: no dragging
  items to reorder, and the missing path check is explicit rather than a watcher.

## Project / UX

- [ ] **Project select** - show the last frame the user was on (low-q screenshot, refreshed); option
  in project settings to use current frame / an image for the thumbnail. List view again, with
  grouping. A simple tool to build one huge video from many projects of the same game: drag a project
  in, keep them as separate projects, choose per-sub-project whether it force-loads / force-doesn't on
  opening the main project (for performance).
- [x] #18 shareable repo + self-updating `.bat` + standalone exe + GitHub Release - done.

## Shared tech (enables many of the above)

- [~] Native physics bake core (`PurrPhysics`) - done; reused by all physics effects.
- [~] **`(min, max)` baked-range value type** - CORE SHIPPED and tested (`AnimProp.make_range`); the only part
  left is typing "(##,##)" straight into a number box. See `docs/27`.
- [ ] **Per-element pick/override** - click an element (piece/object) at its live on-screen position
  -> glow -> right-click to set its own values; generalizes across effects. See `docs/27`.
