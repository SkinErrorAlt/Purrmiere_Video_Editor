# Handoff, 2026-11-05

Read this first, then `docs/AGENT_RULES.md`. This file is self contained: the state, the next jobs in order,
the commands, and the traps. The long history is in `OUTSTANDING.md`, newest pass at the top. `BUGS.md` has
the open faults, `FIXED_BUGS.md` the closed ones, `REJECTED.md` the things Ava has already turned down.

**This replaces the handoff of 2026-11-02, which was wrong about two things.** It said the Object Select model
would not open outside the app and blamed onnxruntime. The model opens fine; see `[O-001]` in
`FIXED_BUGS.md`. And it recorded the timeline redraw ceiling as something that grows with project size. It
does not; see `[C-154]` in `BUGS.md`. Do not act on the old file.

## State on the day

- The app holds **259 transitions and 685 effects**.
- **The release.** Still the open question. Nothing had been cut since 2026-11-01 21:19, so everything from
  passes 32 to 38 is unreleased: the fifty new effects and transitions, the hover highlight, the brush. The
  harness was run today and found five reds, four of them real faults that would have shipped, listed in the
  pass 39 entry in `OUTSTANDING.md`. Four are fixed. The fifth, `native_export_test`, is suspect rather than
  understood, because probe runs were going alongside the harness and that suite is paced by the decoder.
  **Next: run it on a quiet machine, then run the whole harness again with nothing else running, then cut.**
- Nothing is committed or pushed. **Never commit or push.** Ava updates GitHub herself with
  `Push to GitHub.bat` at milestones.
- Ava's copy is from 2026-11-01 20:26. Check `C:\Purrmiere_Stable\STAMP.json` against `release\STAMP.json`;
  she moves her copy by running `Update Purrmiere.bat` after a release is cut.

## What shipped today

| Pass | What |
|---|---|
| 39 | The pass 38 painted stroke was measured and was making selection **worse** than the single click it replaced. Fixed: few prompt points, no box round the stroke. Plus the bridge now says why it failed instead of letting callers invent a reason, and four faults found by the release run. |

Page for Ava, newest first:

- The brush measured: https://claude.ai/artifact/WMwe3FuCsKBaS1dSWQwi7N
- Paint to select and the Mask Brush (pass 38): https://claude.ai/artifact/BWBKm47DrbcazbnEBD6t8A
- Six rebuilt and the fifteen cut: https://claude.ai/artifact/H91MrLvkV22SC7f9exhSQK
- All 259 transitions: https://claude.ai/artifact/G1pVgeeNpwATbxLkSMQHpr
- The 130 new effects: https://claude.ai/artifact/Wpx5VCJ88gvq4qPRcsj5fm

## Waiting on Ava, do not decide these

1. **Star Filter makes a plus now, not a cross.** Its rewrite in the unreleased work moved the Angle default
   from 45 to 0. The dial works; only the default changed. She picks which default she wants.
2. **Two cross stitch effects, same idea.** The new `cross_stitch` (more control) and the older
   `purr_cross_stitch` (simpler) had the same label; the new one is now "Counted Cross Stitch". If she only
   wants one, the other goes.
3. **The timeline redraw at the 32 to 40 px band.** The fix with real leverage changes what is on screen at
   that zoom, so it wants rendered before and after strips and her eye. See `[C-154]`.
4. **Mark the true selections.** Three frames of her own footage are on
   https://claude.ai/artifact/EMgoBZMi191PLmrdLP5r4K with paint, erase, brush size, zoom and pan. Once she
   has painted them, read the masks back with the `ArtifactData` tool from the `truth` collection (a packed
   bitmap, 480 by 270, base64 of one bit a pixel) and retune the prompts against what she actually wanted.
   On real footage the model scored well on the bus (it thought 0.951), mixed on the figure (0.717) and
   poorly on the character in the dark doorway (0.466), so its own confidence tracks quality usefully.
5. **The dragged element's own snap box.** A title now offers its words as snap lines, which is the targets
   half of her text snapping ask. The other half is that `monitor_handles` passes `monitor_snap.begin` an
   empty own-quad callable, so while dragging only the pivot snaps and never the edges. Filling it in
   changes snapping for every handle drag of every kind of clip, so it wants the live GUI and her eye.

## Next jobs, in order

1. **Finish the release.** `native_export_test` alone on a quiet machine, then the full harness with nothing
   else running, then cut. Nothing else should be running while the harness runs: timing suites pick it up.
2. **Object Select on real footage.** Everything measured today is one synthetic circle. The next real step
   is her own clips, which also settles whether the tracking complaint is gone now that the stored prompt is
   no longer poisoned.
3. **The retry on low confidence: DONE.** `ObjectSelect.pick` asks again with the middle positive point when
   the model's predicted iou is under `RETRY_BELOW` 0.35, and keeps whichever answer it is more confident in.
   Proved by switching it off and on against ground truth: a stroke running off the object went from 0.071 to
   0.962, and a stroke that stays on is unchanged at 0.948. `pass39_retry_test` 9 / 0.
4. Then the rest of Object Select, job `0a` in `RESUME.md`: the Fast and Best switch, the download sheet with
   the pinned hashes, the guided refine shader so the edge lands at 1080, feeding the model from the shared
   `track_feed` instead of seeking a frame (about 20 fps today, the target is 120), more than one object a
   clip, then Milestone 4.
5. Pre existing and untouched: "Engine: frame history for time effects, float buffers between effect passes".
   Two of Ava's requests are blocked on it, see below.

## Blocked on engine work, do not fake these

- **Transition parameters of type `texture`: DONE, it was never blocked.** One branch in
  `TransitionRegistry.shader_value` handles `TYPE_OBJECT`: a saved path becomes a texture through the cached
  `LayerChain.texture_from_path`, an already loaded texture passes through, anything else leaves the sampler
  empty. No native rebuild, no new file. `pass39_transition_texture_test` 14 / 0, 13 / 1 planted. **What is
  left is on the transition, not the engine:** Card Shuffle has to declare a `texture` parameter in its
  manifest and sample it in its shader. The panel already builds the row for it.
- **Frame history.** A transition shader only ever sees the two clip textures at the current instant. This is
  why Card Shuffle cannot show real frames from between the two shots and Flipbook cannot put a different
  real frame on each page. Both do the honest approximation and say so in their blurbs.

## Files added today

- `project/tools/pass39_objsel_open_probe.gd`: the bridge, the runtime, both manifests, the model open, and a
  table of prompts with their iou against a known truth mask. `PASS39_LIGHT=1` stops before the model opens.
- `project/tools/pass39_timeline_cost_probe.gd`: the timeline redraw cost against clip count and against
  zoom, with the draw broken into its parts.
- `project/tools/pass39_stroke_prompt_test.gd`: the suite guarding the stroke prompt fix.

Changed: `engine/brush_stroke.gd`, `modules/core_panels/object_ui.gd`, `host/purr.gd`, `tools/host_test.gd`,
`tools/panels_test.gd`, `tools/compositor_test.gd`, `tools/pass12_fx_v3_test.gd`,
`effects/cross_stitch/effect.json`, `BUGS.md`, `FIXED_BUGS.md`, `OUTSTANDING.md`.

## Commands

One suite, headless:

```
C:\Users\lwil5\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Purrmiere_Video_Editor\project --script res://tools/<name>.gd
```

The `_console.exe` build is required or there is no output. Drop `--headless` and add `--position 1980,60`
when the suite needs a GPU: headless reports a GPU but renders garbage. GPU suites that relaunch themselves
through `gpu_relaunch.gd` now default to `1980,60`, the monitor she has, so `PURR_WINDOW_POS` is no longer
needed; it still overrides the default if a screen moves.

Full harness: `tools\run_tests.bat`, which cuts a release when green with no arguments.
`tools\run_tests.bat --skip <name>` skips a suite and then does not auto release.
`powershell -File tools\make_release.ps1` does the release alone. A full run takes well over half an hour.

Rebuild the engine: `native\purrcore\build.bat`. It fails with "Access is denied" while her app holds the DLL,
so close the app first. The editor loads the **debug** DLL, so engine work only reaches her when the debug
target is rebuilt. Both DLLs are current as of 2026-11-01 21:05 and no native source is newer.

## Traps that cost time

- **Running anything alongside the harness.** Timing and decoder paced suites pick it up. This cost a
  `native_export_test` result today that now has to be re-run before it can be believed.
- **Running a batch file from the Bash tool.** `cmd /c "tools\run_tests.bat"` under Git Bash gets its argument
  path converted, opens an interactive shell and exits 0 having run nothing. Use the PowerShell tool:
  `& cmd.exe /c "tools\run_tests.bat"`.
- **Long heredoc Bash commands** fail with "unexpected EOF". Write long files with the Write tool and run
  scripts with `python -I <path>`.
- **Python non raw strings eat Windows paths.** `"...objsel\runtime"` puts a carriage return in your document
  and `"C:\Users"` is a unicode escape error. Write the file with the Write tool and splice it in, or use raw
  strings.
- **`ObjectSelect.pick` takes normalised points, not pixels.** Passing pixel coordinates returns an empty
  matte with a NaN score and looks exactly like a broken model. The pass 30 suites show the right shape.
- **`load()` returns a non null Shader even when it fails to compile**, so `sh != null` proves nothing. Rely
  on the behavioural render checks instead.
- **Godot drawing** is only allowed inside `_draw()`. To test drawing code, pull the geometry out into a pure
  static function and test that.

## House rules, broken most often

Full text in `docs/AGENT_RULES.md`.

- No comments in code, of any kind. No em dashes or en dashes anywhere, in code or in docs.
- GDScript: static typing everywhere, no `class_name`, `gui_input` handlers named `_on_input`, never `match`
  inside a lambda, hide with `visible = false`.
- Every part ships a headless suite under `project/tools/` with a `PLANT` constant that makes it fail when
  true. Prove it both ways and report both numbers.
- Never write into `C:\Purrmiere_Stable`. That is Ava's editing copy. All work happens in
  `C:\Purrmiere_Video_Editor`.
- Suites write into `purrtest/data/<pid>`, never her real folder at
  `C:\Users\lwil5\OneDrive\Documents\Purrmiere`.

## Ava's standing preferences

- Show results on a web page she can open, never only a local file path.
- Effects and transitions must be convincing looks, never UI or template graphics. A transition has to look
  like the thing it is named after, not like the geometry of the thing it is named after.
- Read `REJECTED.md` before adding anything new. Fifteen items were built and cut on 2026-11-02 and none of
  them is to be rebuilt under that name or another one. If something comes back for rework a second time, ask
  whether she wants it at all.
- Look at the rendered output, and at the measured numbers, not just the test tallies. The biggest finding
  today came from scoring the model against a truth mask rather than trusting a passing suite.
- Keep working through the queue without asking; stop only when it is empty, blocked on something only she
  can answer, or she says stop.
- Say plainly what was not verified rather than implying it was.
