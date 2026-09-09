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

The trace is intentionally JSON-safe and stable across runs. It is the Godot
counterpart to a future original-runtime capture with the same cursor keys.

`tools/qa_verify_story_trace.gd` replays the same route and compares every
structural frame with the committed baseline. Audio processing timing is not
compared as a boolean; resource and command identities are compared instead.

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
5. Run the opening trace and focused UI regressions before accepting a change.
