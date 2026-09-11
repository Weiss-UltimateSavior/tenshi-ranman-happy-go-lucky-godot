# Godot Compatibility Validation

## Goal

Each Godot scene must be traceable to an original SCN cursor and evaluated by
script state, visual composition, input result, and audio state. A screenshot
without its script cursor is not an acceptance artifact.

## Story Trace

`tools/qa_export_story_trace.gd` records the playable opening route in
`qa/traces/godot_opening_trace.json`. Every frame records:

- SCN storage, label target, scene index, and line index.
- Speaker, displayed text, and voice identifier.
- Stage, event, message face, character, and effect geometry.
- BGM, voice, and active sound state.
- Message-window mode, visibility, chapter/chart metadata, and quick-menu visibility.
- Branch state: flag values, pending selection, last selection/decision
  events, and the game-ended marker.

The trace is intentionally JSON-safe and stable across runs. It is the Godot
counterpart to a future original-runtime capture with the same cursor keys.

`tools/qa_verify_story_trace.gd` replays the same route and compares every
structural frame with the committed baseline. Audio processing timing is not
compared as a boolean; resource and command identities are compared instead.

A second baseline, `qa/traces/godot_branch_trace.json`, plays st04_04 through
the accessory dialog selection (佐奈), continues into st04_05, and records the
`CheckBranchFlags("acc_san")` branch decision to 0429_sel.ks *0429_san.

A third baseline, `qa/traces/godot_map_route_trace.json`, covers the map
selection route unlocked by the local PSB converter
(`tools/psb_to_json.py`, docs/plan/PLAN_P1_SCN_JSON_AND_STANDS.md §1):
st02_03 map choice (佐奈) → sn_map01.ks (60 frames) → st02_04.ks, with the
selection event recorded. Both
routes support user args on export/verify (`--storage/--target/--output/
--reference/--select-index`) so fixtures replay selections via
`apply_selection()` instead of real clicks.

`qa/` is git-ignored (it comes from the asset archives), so each developer
records their own baselines. Record them with an explicit frame count — the
exporter defaults to 32, which silently truncates longer routes:

```text
godot --headless --script res://tools/qa_export_story_trace.gd
godot --headless --script res://tools/qa_export_story_trace.gd -- "--storage=st04_04.ks" \
  "--target=*0429_4" "--select-index=1" "--entry-count=210" \
  "--output=res://qa/traces/godot_branch_trace.json"
godot --headless --script res://tools/qa_export_story_trace.gd -- "--storage=st02_03.ks" \
  "--target=*dummyselect1" "--select-index=1" "--entry-count=60" \
  "--output=res://qa/traces/godot_map_route_trace.json"
```

If a baseline predates a resource move or an asset fix it must be re-recorded:
the 2026-09-11 re-record moved `bgm_path` to `res://assets/audio/bgm/` (P2 §2
`.sli` work) and picked up the restored 佐奈 stand (P1 TLG filename repair), so
frames that previously recorded no character now record one.

## Branch Selection Coverage

- `tools/qa_branch_flags.gd`: flag table semantics (single, `&&` chains,
  unknown names, weighted sums, JSON round trip).
- `tools/qa_story_nexts_eval.gd`: eval-gated nexts, error.ks sentinel
  skipping, unconditional fallback, missing-json decision report.
- `tools/qa_story_selects.gd`: pending presentation, selidx ordering, eval
  filtering (st07_01 map), SetBranchFlags application, cross-file decisions.
- `tools/qa_saveload_branch.gd`: save v2 flags/history/pending-selection
  round trip.
- `tools/qa_capture_select_screens.gd`: dialog/map selection screenshots
  (windowed runs only; headless skips).

## Script Coverage Audit

`tools/audit_scn_command_coverage.gd` scans every extracted SCN JSON file and
writes `qa/reports/scn_command_coverage.json`. The report distinguishes direct
KAG command handlers from classes currently sent to the generic visual path.
Its review candidates determine the next script-compatibility implementation
work; command support is not inferred from a single route.

## Timeline And Effects

`StoryPlayer` preserves the SCN command barriers used by the original KAG
runtime: `wait time`, `waitvoice`, `wact`, and `delaydone`. The normal game
uses wall-clock timing; trace fixtures explicitly select instant mode so their
structural baselines remain deterministic.

`stageeff` is a dedicated layer between stage and event CG, as declared in
`main/envinit.tjs`. The implementation parses the original UTF-16 `.asd`
timeline, applies `ltAdditive` blending from `main/custom.tjs`, and advances
the original per-frame wait durations. TLG sequence conversion is queued in
the preload worker and never blocks scenario input.

Focused checks:

- `tools/qa_story_wait_semantics.gd`
- `tools/qa_stage_effect_animation.gd`

## Acceptance Sequence

1. Capture the original runtime at fixed SCN cursors.
2. Replay the same cursor sequence in Godot.
3. Compare layer state first, then screenshot pixels, then audio events.
4. Add a targeted regression test before changing a renderer or script rule.
5. Run both story traces (opening + branch) and the focused UI regressions
   before accepting a change:
   `godot --headless --script res://tools/qa_verify_story_trace.gd`
   `godot --headless --script res://tools/qa_verify_story_trace.gd -- "--reference=res://qa/traces/godot_branch_trace.json" "--storage=st04_04.ks" "--target=*0429_4" "--select-index=1"`
   plus `qa_branch_flags` / `qa_story_nexts_eval` / `qa_story_selects` /
   `qa_saveload_branch`.

Known boundary: branch targets whose SCN JSON was not exported (for example
0429_sel.ks) record their branch decision and stop with an explicit
"Scenario not found" error; the decision itself is the acceptance artifact
until the remaining SCN JSONs are added.
