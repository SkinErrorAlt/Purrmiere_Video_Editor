# Overnight autonomous run — live checklist

## ☀️ MORNING SUMMARY (read this first)

Shipped overnight, all built + tested + on the showcase pages:

**Flagship physics (your top asks) — real native 3D physics in the engine:**
1. **Crumble 3D** — picture breaks into real 3D pieces, native rigid-body collision bake (~2.5 ms,
   780× faster than script, deterministic), tumble + reveal behind. Fully reviewed (7 findings) and
   fixed. Per-piece mass + gravity already in the sim.
2. **Glass Break** (your #1) — shatters from where you set the impact into 3D glass shards that fly
   out, refract the video and glint on their edges. Built a native C++ physics bake core in purrcore
   (`PurrPhysics`) that every physical effect reuses.
3. **Addressed your follow-up feedback** (pieces were flat squares / not 3D / wanted alpha): both now
   use `fracture_mesh.gd` — voronoi fracture into **irregular 3D shards with real extruded depth** (a
   wall of solid objects), **alpha-aware** so a transparent image/GIF turns 3D and breaks ONLY where
   it has content (verified), a **realistic glass** shader (chromatic dispersion, Beer-Lambert glass
   tint, fresnel edges — from a game-techniques research pass, `docs/30`), and the break **spreads
   from the impact** (staggered detach). v2 polish TODO: clean alpha silhouette (convex-decompose
   boundary pieces), glass dust/chips particles, screen-space refraction for a "video behind glass"
   mode. Effects page v8.

**New effects (5):** Comic Halftone (Spider-Verse CMYK dots+ink), Pixel Scramble (privacy/encrypt
mosaic), Cinematic Grade (one-dial film looks) [+ the 2 physics flagships].
**New transitions (20, page shows 229):** + Slit-Scan, Moire, Rewind (VHS), Glint, Chroma Warp, and: Luma Warp, Ink in Water, Datamosh Bloom, Rack Focus, Anime Speed Lines,
Shockwave, Hyperspace Warp, Anamorphic Flare, Motion Whip, Zoom Punch, Invert Flash, Zap, Glitch
Zoom, Paint Smear, Smooth Cut (15 of 46 researched — the other 31 are specced and queued in docs/29;
the physics ones will reuse the Glass/Crumble 3D-pass once generalised). Transitions page now 224.

**Pages (updated with version badges, newest-first):**
- Effects: https://claude.ai/artifact/Wpx5VCJ88gvq4qPRcsj5fm (v5)
- Transitions: https://claude.ai/artifact/G1pVgeeNpwATbxLkSMQHpr (v9)
- 3D Crumble deep-dive: https://claude.ai/artifact/VAF1gbd9FJC7xW3QFfs8sL

**Audited your old lists** (they were stale): DONE already = #13 pairview Hold, #6d audio labels,
#6e audio passthrough, #5 EQ. Full status in `ROADMAP.md`. The app-subsystem asks (pair view, audio
menus, slide/move tools, project select) are specced + flagged — they need the live GUI to test
safely, so I left them for us to do together rather than risk breaking them blind.

**Needs your call:** whether to keep the fast shader Crumble as a "Draft" or go 3D-only (3D bakes in
<1 ms, so Draft may be unnecessary). The 46-transition and effect queue is in `docs/29` + `ROADMAP.md`.

Suites all green: effect_check 669/0, pass25/26/27 physics 0 fail (PLANT proven). Engine rebuilt.
Details below.

## AVA ASK (mid-session): Rewind build-up - DONE (one live check pending)
Built as a TIMELINE command, not a shader (plain `rewind_scratch` transition kept untouched).
"Rewind build-up" on a video clip's right-click menu: duplicates the clip, ripple-pushes
everything after the cut forward by the build-up length, and plays the copy in REVERSE from the
cut frame back through a look-back window (default 6s), starting slow and speeding up (gentle
ramp, slow_factor default 0.7), then cuts on to the next clip. Custom dialog: look-back seconds,
build-up length, start speed. Reuses the same media (no footage copied on disk).
Files: doc/commands/tool_cmds.gd (RewindBuildup composite), doc/commands/edit_tools.gd
(rewind_buildup wrapper + 3 prefs), modules/core_panels/edit_commands.gd (dialog), catalogue.json,
ui/timeline/timeline_edit.gd (menu item + dispatch). Suite pass29 16/0 (PLANT 15/1): verifies the
reversed copy, ripple of B, exact 6s source span, slow->fast negative ramp, undo, window clamp.
host_test 58/0 (catalogue consistency), panels_test 211/0, pass14_speed 33/0 all still green.
PENDING: one live-GUI check of the dialog + menu click (structure mirrors Freeze frame exactly,
which works; all registration/catalogue tests pass). No native rebuild needed (pure GDScript).

## CRUMBLE FEATURE (loop task) - per-piece override DONE (bake + data), GUI pending live
- **Part 1 (baked physics in the pipeline): already done + green.** crumble_3d / glass_break are
  engine effects (empty passes, rendered by crumble_stage / glass_stage through a 3D CrumblePass /
  GlassPass wired into layer_chain). The plain shader `crumble` stays as the Draft mode (your call:
  keep both). pass26 21/0, pass27 18/0.
- **Part 2 (per-piece weight + gravity override) - bake + data layer DONE + tested.**
  Native physics_bake.cpp ALREADY takes per-piece `masses` + `gravities` (weight 0 pins a shard,
  gravity 0 floats it), so NO engine rebuild was needed. crumble_stage now reads `e["pieces"]`
  ({"<index>": {"weight":.., "gravity":..}}), builds the arrays and feeds the bake; the override is
  in the bake_key so it re-bakes on change. New undoable `EffectCmds.SetPieceOverride` + verb
  `Verbs.set_piece_override`; the override rides on the effect dict and survives save/load.
  Suite pass31 26/0 (PLANT 24/2): stamp, array build, negative-weight clamp, an end-to-end native
  bake proving a pinned + a floating piece, and the command round trip (set/undo/redo/clear).
  host_test still 58/0.
  VISIBLE PROOF published: https://claude.ai/artifact/JEoh65GgVvt5zmVjDJbbEN - a live before/after
  from the real pipeline: plain crumble clears the frame, the override version holds a scatter of
  pinned shards mid-fall.
  PENDING (needs you live): the on-screen piece picking (raycast a click to a shard), the glow, and
  the right-click physics menu - all call the finished verb. The 3D click + menu can only be built
  and seen in the live editor.
- **Glass Break also gets per-piece override** (mirror of crumble_stage): glass_stage reads
  `e["pieces"]`, builds masses/gravities, feeds the bake. The SetPieceOverride command + verb are
  effect-agnostic (keyed by effect uid), so they already cover glass too. pass27 now 23/0 (PLANT
  21/2).
- **Part 3 ((min,max) baked range) - core done + tested (pass30).** The "(##,##)" input widget is
  still the live-session follow-up (256KB effect_controls hot path, only runs with an effect
  selected in the GUI).

## WHERE THE CRUMBLE FEATURE STANDS (loop task at its autonomous limit)
Everything that can be built and proven headless is done, tested both ways, and shown:
baked Full mode + Draft shader (parts 1), per-piece weight/gravity on Crumble AND Glass with an
undoable command that round-trips (part 2 bake + data), and the (min,max) range core (part 3).
The ONLY remaining pieces each need the live editor WITH you, because they are 3D on-screen
interaction or the big live-only controls panel:
  - click a shard -> glow -> right-click physics menu (calls Verbs.set_piece_override) [Crumble + Glass]
  - the "(##,##)" range input widget in effect_controls_panel.gd
These can't be built or seen headless, and I will not touch the live GUI blind. Let's do them
together when you're at the editor.

## NOTE: full harness was memory-killed
The background full harness (b9xi0jh2e) was stopped by Claude Code because the SYSTEM went low on
memory while the session was idle - not a failure of the suite. Per policy I did not restart it on
my own. Touched suites were run individually and are green (pass26/27/31, host_test). Restart the
full harness when asked.

## SINCE THE "keep triggering yourself" NUDGE (continuous run, loop restored)
- **Swirl action** added to the physics transition engine (action 4: shards spiral around the
  impact point before tumbling). Now a param option on all 3 physics transitions. pass28 still green.
- **(min,max) baked-range value type - CORE DONE + tested.** New AnimProp static form
  `{"v": baked, "rng":[lo,hi], "seed": int}` baked once from a deterministic seed (reuses the
  existing hash64/unit RNG). Rides EVERY existing static read path unchanged (verified by a mapping
  workflow: every consumer branches on the `"a"` key, static reads only `"v"`; norm never strips
  dict keys; survives save/load and get/set). Helpers in doc/anim_prop.gd: make_range, is_range,
  range_of, range_seed, rebake_range (reroll), set_range_bounds. Suite pass30 18/0 (PLANT 17/1):
  bakes in-bounds, deterministic per seed, evaluate rides the static path, reroll stays in bounds,
  save/load preserves it, keyframing promotes to animated (documented). Bounds live ON the value
  dict, so NO new per-value storage needed (sidesteps the map's main caveat).
  - **UI affordance STAGED for a live session with Ava** (the "(##,##)" input + reroll). It belongs
    in effect_controls_panel.gd `_make_editors` float branch (~line 4213-4230), scoped to
    kind=='float' with min&max. Add two min/max PmFields + a reroll icon button (mirror the
    scale_link button at 4240-4245 and the modifier 'New seed' reseed at 4968-4970). Commit the new
    value dict through the existing `_write(spec, value)` -> `Verbs.set_effect_param`
    (verbs.gd:1629) -> `EffectCmds.SetEffectParam`; for a keyed param use `write_hold_key` (4769).
    Reroll = AnimProp.rebake_range(current, randi()); bounds edit = AnimProp.set_range_bounds.
    NOT applied headless: this file is 256KB and the row-build path only runs when an effect is
    selected in the live GUI, so it can't be verified without clicking - do it together live.
    Files: doc/anim_prop.gd (helpers), tools/pass30_range_value_test.gd.
- **Live TransitionUnit engine path validated** (was only parse-checked): pass28 now 38/0 - a real
  TransitionUnit activates the engine for shatter_3d, bakes shards through the real pass, and
  switches back to the 2D shader rect for a library transition.
- **Glass dust / chips** added to the Glass Smash (addresses the "extremely realistic" glass ask):
  a burst of glinting additive particles sprays from the impact and fades as the shards fall.
  Efficient analytic ballistic particles in a MultiMesh (one draw call, no extra bake, no stall).
  New engine/dust_particle.gdshader; dust_mm in shatter_pass.gd; _bake_dust/_drive_dust in
  transition_shatter.gd; "Dust and chips" + "Dust amount" params on glass_smash_3d. Default on for
  glass, off for solid breaks. pass28 still 38/0. Re-rendered + republished the Glass Smash sprite
  (Transitions page v18).
- **Full harness** launched in the background to validate the whole codebase at this point.

## NEXT UP (priority order, for when I resume)
1. DONE **Physics transition trio** - real baked-physics A->B breaks. Built a reusable engine-
   transition path: transition.json `"engine"` field, registry skips shader compile, TransitionUnit
   builds a 3D ShatterPass (own_world_3d) that fractures the outgoing frame into 3D shards over a
   back quad showing the incoming frame. Impact point (draggable), 4 actions, radial/even pattern,
   solid or glass material (reuses glass_shard shader - refraction/dispersion/fresnel), motion blur.
   Three transitions shipped on it: **Shatter 3D** (radial burst), **Glass Smash 3D** (fine
   refracting glass web), **Crumble 3D** (solid blocks topple+fall). Suite pass28 34/0 (PLANT 33/1);
   engine/ui transition suites + effect_check all still green. Showcased: Transitions page v17,
   232 transitions, img/{shatter_3d,glass_smash_3d,crumble_fall_3d}.jpg.
   Files: engine/shatter_pass.gd, engine/transition_shatter.gd, transitions/{shatter_3d,
   glass_smash_3d,crumble_fall_3d}/, tools/pass28_shatter_transition_test.gd, tools/make_shatter_preview.gd.
   NEXT physics transitions if wanted: Liquid Pour, Cloth Drop, Domino (docs/29) - need new sims.
2. **Physics polish** (Ava feedback follow-ons): true temporal/ghost motion blur (softer than the
   current velocity-stretch), clean alpha silhouette (convex-decompose boundary shards), multi-point
   **Custom Actions** (click to place several action points, each with mode + time), glass dust/chips
   particles.
3. **(min,max) baked-range value type** + **per-piece click->override** (docs/27).
4. More transitions/effects from docs/29 + ROADMAP; advanced colour, outlines ripple.
5. App-subsystem items (pair view, audio EQ curve/3D, slide/move tools, project select) - need the
   live GUI to test; do WITH Ava.

---


Ava is asleep (started 2026-10-31 ~06:00). Goal: get as much of `ROADMAP.md` done and verified as
possible, ready to go when she wakes. This file is the work-state: **reread it every loop tick**,
update status, keep going until the queue is empty or genuinely blocked on an Ava-only answer.
Full backlog detail in `ROADMAP.md`. Her note: the old lists are partly already done (verify first);
the fresh/important asks are the "end part" (glass break, 40+ physics transitions/effects, advanced
colour, EQ menu, 3D audio).

## Standing rules (recheck every tick)
- **Showcase pages stay current.** As effects/transitions ship, update the Effects page
  (https://claude.ai/artifact/Wpx5VCJ88gvq4qPRcsj5fm) and Transitions page
  (https://claude.ai/artifact/G1pVgeeNpwATbxLkSMQHpr) with the SAME rules: version badge at the
  bottom of the description (+0.1 per request, +1.0 per Purrmiere version), newest pinned to the top
  of its section, the "Newest" filter chip. Only new ones get the badge. So Ava sees what's new at a
  glance without testing. Current effects version baseline: v1.2 (shader Crumble); next new = v1.3.
- **No AI/UI look.** Convincing, quality visuals only; never fake UI panels or template graphics
  (the look she had me remove). Applies to effects AND to the showcase page designs.

## Loop protocol (moria / THE_LOOPHOLE)
- Keep working in-turn; background slow jobs (engine `build.bat`, suites, workflows) — they re-invoke
  the session on completion. If a turn would end with no background job pending and work remaining,
  spawn `sleep 20` in the background to resume.
- Every substantive task → a Workflow (ultracode on). Tests get PLANT both numbers. New items get an
  independent review. Visible results go on an Artifact page.
- Never write into `C:\Purrmiere_Stable`. Test windows on monitor at 1980,60.

## Queue (ordered; newest/flagship first)

### A. In flight
- [x] **Crumble 3D** live-compositor integration — DONE & verified. crumble_stage.gd + crumble_pass.gd
  + layer_chain branch (rebuild + per-frame hook; key fix: kind="effect" so the per-frame loop reaches
  the update) + crumble_3d/effect.json. Renders baked 3D pieces through the REAL compositor
  (make_effect_previews). effect_check_test 665/0. Remaining polish: PLANT suite for crumble_stage,
  independent review, showcase page, and decide Draft-shader vs 3D-only with Ava.

### B. Verify the old backlog — DONE (see ROADMAP.md "Audit results")
- [x] Audit workflow complete: 4 done, 14 partial, 8 missing. Done (skip): #13, #6d, #6e, #5.
  Overnight focus = effects/transitions (buildable+testable headlessly). App-subsystem items specced
  & flagged for Ava (riskier without GUI). Small safe wins possible later: #4 text tight-box snap,
  #6a view colour pick.

### C. New flagship builds (the "end part")
- [ ] **Glass breaking** effect — breaks where you click, particles, refraction, toggle video-behind
  vs video-is-glass. Reuses the physics bake + 3D pieces.
- [ ] **(min,max) baked-range** value type (foundational; docs/27).
- [ ] **Per-piece pick → glow → right-click override** (Crumble-first; docs/27).
- [ ] **Physics object spawner** (balls/shapes/images, colliders, bake, mouse-drag, plug velocity).
- [ ] **Outlines system** (electric glow/ripple + custom + drawing tool).

### D. Volume: transitions & effects
- [ ] 50 unique transitions (find competitor gaps; physics + meme) — research workflow → build batch.
- [ ] 40+ more effects, mostly physics; Photoshop-and-similar effects; encryption/pixelate; paper
  cutout fix; range/measure text.
- [ ] Advanced colour grading (DaVinci-level and beyond; lower the skill barrier).

### E. Audio
- [ ] EQ menu with draggable curve points (keyframeable curve); physical audio-breakdown menus.
- [ ] Audio adjustment layers. 3D tracked audio (orbit view, masked ranges).

### F. Pair view, editing tools, timeline, bugs, project UX
- [ ] (see ROADMAP.md sections) — triage after B establishes what's already done.

## Progress log (newest first)
- 09:55 — Second physics-feedback round done: **finer glass** (14x shard density, fine near impact so
  it reads as real cracking not big chunks), **Custom Actions** enum on both effects (Push away /
  Pull toward me [+toward camera, energy falls off outward] / Fall over / Explode), **Spin** (3D
  rotation) param, **Motion blur** param (optional, directional velocity-stretch; motion_blur=0 is a
  no-op), cards now start on the intact frame (poster 0). ALSO fixed a house-rule slip: stripped all
  comments from the new code (effect_check caught a `//` in cinematic_grade). New effect this round:
  **Cinematic Grade** (`cinematic_grade`, one-dial film looks). Suites: effect_check 669/0, pass26
  21/0, pass27 18/0. Effects page v9. Remaining physics polish (noted, next): true temporal/ghost
  motion blur for softer smear, clean alpha-silhouette (convex-decompose boundary shards), the full
  multi-point "click to place Custom Actions at times" interaction, glass dust particles.
- 09:10 — **Fracture geometry upgrade** (Ava feedback: pieces were flat squares, not 3D, no alpha).
  New `project/engine/fracture_mesh.gd`: voronoi fracture -> irregular convex cells -> **extruded 3D
  prisms with real depth** (front+back+side walls, proper normals), planar UVs (seamless at g=0),
  alpha-aware (skip transparent cells -> a transparent image/gif breaks only where it has content).
  Wired into BOTH crumble_stage + glass_stage (radial crack seeding for glass, uniform for crumble).
  Glass shader upgraded per research (docs/30): chromatic dispersion at edges, Beer-Lambert glass
  tint, fresnel edge glints, specular. Effects page v7 shows the real 3D shards. effect_check 668/0.
  NEXT realism (from docs/30): staggered detach / crack-spread-from-impact (doing now), alpha
  silhouette clipping (G4, non-convex boundary pieces), screen-space refraction for a video-behind
  mode (S1), glass dust/chips particles.
- 08:30 — 8 more transitions built + tested + showcased (Rack Focus, Anime Speed Lines, Shockwave,
  Hyperspace Warp, Anamorphic Flare, Motion Whip, Zoom Punch, Invert Flash, Zap, Glitch Zoom, Paint
  Smear, Smooth Cut) -> 15 new total, Transitions page v12 (224). effect_check 668/0. All built via
  the proven shader pipeline (write json+gdshader -> make_transition_previews -> verify). NEXT when
  resumed: physics transitions (reuse 3D pass), the (min,max) range value type, per-piece overrides,
  glass v2; app-subsystem features await the GUI / Ava.
- 08:00 — 3 new transitions built + tested on Bonelab->R6 footage: **Luma Warp** (melt along luma
  difference), **Ink in Water** (domain-warped fbm ink bloom), **Datamosh Bloom** (motion-vector
  block smear + mush + snap). Showcased on Transitions page v9 (v9 badge, newest). NOTE: originally
  also made a `light_leak` but it DUPLICATED an existing transition and I had overwritten the
  original — restored it from git, dropped my dupe. Full 46-proposal research in
  docs/29_TRANSITION_PROPOSALS.json (43 still to build; physics ones need the 3D-pass infra).
- 07:35 — **Glass Break** (`glass_break`, FLAGSHIP #1) built + working: radial shatter from impact,
  3D glass shards fly out toward camera, refraction + fresnel edge-glint shader (glass_shard.gdshader),
  reuses PurrPhysics + the crumble 3D-pass pattern (glass_stage.gd/glass_pass.gd, layer_chain branch).
  pass27 18/0 (17/1 PLANT), effect_check 668/0. Showcased on Effects page v5 (v1.6, leads Physics).
  v2 TODO: true video-behind toggle, particles, radial-voronoi cracks (spec docs/28). Transitions
  research done: 46 proposals saved to docs/29_TRANSITION_PROPOSALS.json. Building transitions next.
- 07:05 — Crumble 3D REVIEWED (7 confirmed findings) + ALL FIXED: own_world_3d isolation (critical),
  MSAA_4X, native RNG fixed-order determinism, squared-dist collision, g=0 perfectly intact (home+
  identity), sim-window so fall-away reliably clears by g=1, mesh rebuild on aspect change. Verified:
  f_000 intact, f_019 cleared. Suites: pass25 11/0, pass26 21/0, effect_check 667/0. Comic Halftone
  (`comic_halftone`, Spider-Verse CMYK dots+ink) built + renders great. Showcase batch for
  pixel_scramble+comic_halftone pending. Transitions-research workflow still running.
- 06:35 — Backlog audit DONE (ROADMAP updated). Pixel Scramble effect (`pixel_scramble`) built +
  renders (readable privacy mosaic -> full noise; shuffle/row/col modes). Transitions-research +
  crumble3d-review workflows running. Building comic halftone next. TODO showcase: pixel_scramble (and
  batch) on Effects page.
- 06:20 — Crumble 3D live-compositor integration DONE + verified (665/0, pass26 21/0 PLANT 20/1).
  Effects page -> v3: Crumble 3D (v1.3, animated) at top of Physics; shader Crumble = Draft. Version
  baseline now v1.3. Backlog-audit workflow running. About to review crumble_3d code + build ranges.
- 06:00 — Set up OVERNIGHT.md + ROADMAP.md. Crumble 3D wired, about to test.
