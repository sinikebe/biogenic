# PROGRESS-6 — phase 6: organs look like what they do (PAUSED)

Worktree: $S/genes/p6, branch phase-6, base b63e365. Tree clean at **8cbb281**. Not pushed.
Notes: $N = $S/genes/notes/p6/ (frames in $N/raw/, scripts in $N/bin/, logs in $N/logs/).
Before tree: $N/before (git archive b63e365, imported). snap1: $N/snap1 (archive of 602bd5c, imported).

## Commits on phase-6
- 602bd5c the switch (families.gd, kinds.gd, organ files, catalogue accessors, cilia.gd, signal_bus, figure, gene probe)
- 5fb6520 tools: looks_sheet.{gd,tscn}, looks_specimens.gd, drive.gd --specimens=1
- 8cbb281 WIP (paused): docs edits so far (genes-and-cilia §4.4, dna-slots-ux §2.1, gene-catalogue §4.2/§6.2/§7.2/§12.1/§16)
- Proposed PR title (player-facing): "Organs now look like what they do: colour shows the family, shape shows the organ"
- When resuming: the WIP commit's subject must be reworded or squashed before merge (it is not a patch-note line).

## Brief items
- DONE families.gd, kinds.gd as data (602bd5c)
- DONE organ files: family + look per gene-looks §6; toxin's strains: no real strain exists, accents shown via tools/looks_specimens.gd only
- DONE catalogue look accessors: look(), family_of(), hue_of(), as_shipped(), _index_looks(), VARIANT_WORDS key
- DONE cilia.gd: one generator per kind on a Stretch skin; fringe/tile dispatch by kind; HUES, RESERVED_HUES, EARNED_COUNT, COUNT_EARNED, TILE_COUNT, TILE_LEN, TILE_COUNT_EARNED, per-gene tile branches gone; UNKNOWN_TINT, ACCENT_BEAD_MIN 2.6 new. Home organs bit-exact: $N/bin/compare_home.gd, 12,000 poses, 756,194 points, 0 differ
- DONE signal_bus: LIGHT_COLOR const amber (channel's own); BEAM/PING_COLOR from catalogue by channel; STRAIN_COLORS by dose (undelivered = SELF_COLOR); ice/pale moon gone; CHANNEL_LOBES
- DONE figure.gd: accent in chip's first lobe (3.6 px), accent before the word on the tray, explain_name() = `organ · variant`; normal_mode + cell_figure use it; earshot CODE_COLOR via hue_of
- DONE _draw_socket ghost: waiting organ's kind, outline only, pigment at ghost*0.6
- DONE gene probe look checks 1-11 (§8), hue floor replaced; ProbeGland/probeswift/probebarb variants with accents
- HALF planted faults: $N/bin/plants.py written (20 plants over checks 1-11), NOT RUN yet
- DONE docs pointers genes-and-cilia §4.4, dna-slots-ux §2.1; gene-catalogue §4.2 §6.2 §7.2 §12.1 §16 (in 8cbb281)
- NOT STARTED gene-looks.md: Status line ("built in phase 6") + "As built" section (files; deviations below; judged table; numbers)
- NOT STARTED playbook README paragraph about looks, to write in $N/ (for phase 5's README)
- HALF frames: all rendered + determinism done; judging mostly done (below); judged table not yet written; finals NOT yet copied to $N/shots/ (empty)
- NOT STARTED draw-cost bench (scripts ready: $N/bin/bench_draw.gd + bench_node.gd)

## Determinism (0 px, --seed=)
det1-3 (one, 1280, p6) 0 px; detfv1-3 (fv, 2400, p6) 0 px; bdet1-3 (one, before) 0 px.

## Frames rendered (both sizes unless noted), in $N/raw/
before_{fv,one,one_zoom,one_zoomgrey,one_zoomdeut,pause,choose,flood,lobes,offer_plastid,offer_ampulla,pads,trayplain,sheet,sheet_grey,sheet_deut}
after_{fv,one,one_zoom,one_zoomgrey,one_zoomdeut,pause,pausevar,tray,trayplain,choose,flood,lobes,offer_plastid,offer_ampulla,pads,sheet,sheet_grey,sheet_deut,sheet_vari,sheet_vari_grey,sheet_vari_deut,sheet_room}
compares: one_compare_*, cmp_offers_1280, cmp_pads_1280/_2400, cmp_pausevar_2400, cmp_choose_1280, cmp_fv_mid_2400, cmp_offer_plastid_strong, vari_rows34_zoom
before_sheet comes from a scratch tool in the before tree: $N/before/tools/looks_sheet_before.{gd,tscn} (same layout, families hardcoded).
Scripts: $N/bin/frames.sh (frame list), shoot.sh, sheet.sh, cvd.py <in> <out> grey|deut, crop.py, trio.py, diff.py.

## Judged (looked at, both sizes) — all PASS, notes for the table
- fv: reads by family (violet discs = senses, orange = armed/poison, gold inside = metabolism). Cost: born fringe one blue (oars+tail both moving).
- one_compare (+grey, deut): pass; every organ its own shape in luminance and deut.
- sheet / grey / deut: 17 organs at 1 and 3 copies + tiles; 17 tile glyphs distinct in grey; in deut moving+sensing meet in blue and eating/defending/metabolism in yellow, each told by build (only senses carry a pigment disc). Before sheet: 17 hues, generic tufts, deut merges several.
- sheet_vari (+grey): ring/diamond/bar on pigment, disc at tail root, strain beads disc/diamond/ring, plastid ring, vacuole disc; all hold in grey. Weakest: disc vs diamond strain beads at true size.
- sheet_room: hook, tri, bent rings, barb, stack, star, two-wave lash, four-turn coil render. A lash at 3 copies on a forward arc reads as a brush (also the tail variant if seated forward: sheet seats a home organ's variant in its home slot).
- pause: five colour groups; layout unchanged. pausevar: accent in first lobe, `ocellus · keeled`/`ocellus · ringed` line, ring pigment and diamond beads on figure.
- tray (2400+1280): accent before the word; small but legible at 1280; trayplain: shipped genes no accent, word x unchanged.
- choose: rungs group by family; poison locus marker orange.
- flood: lime -> orange. lobes: unchanged to the eye; beam lobe dE_ok 0.015, ping 0.039 (family shades), light unchanged (const).
- offers: bud = organ's tile, ghost = hollow outline (plastid) / ring-tipped pores + dim pigment (ampulla).
- pads (scheme 2): all four sky blue; dash pad glyph is now the coil tile, smaller than the old tuft, legible.
## Numbers
- before(b63e365) vs mock's before(77f90c3): 0 px on fv/one/pause/choose, both sizes.
- build vs mock after: fv 0.46-0.52%, one 0.18-0.22%, pause 0.39-0.49%, choose 0.31-0.51%, flood 0.13-0.16%, lobes 0.22-0.27%, offers 0.88-1.18% (strong px only: pigment seat kept at today's 0.80; tried socket's bead keeps today's brightening -- the mock's `tuft = false` lost it). pausevar 28-29% / sheet 20-24%: not pixel-comparable (specimens change water draws; sheet layout differs), judged by eye.
- before vs after: fv 13.6-14.1%, one 1.1%, pause 3.2-3.6%, choose 2.2-2.7%, pads 0.7-0.8%, lobes 7.0-7.3% (max 107, faint), flood 87.6% (colour), offers 0.4-0.7%.
## Deviations to record in "As built"
pigment seat kept at today's (0.80 of surface); SHADE_STEP_MIN 4.5 (eating shades step 5.1/4.9 deg at two decimals); per-kind ink/width (variant drawn as organ); tile caps TILE_MAT_MAX 11, TILE_LASH_MAX 3, TILE_REACH_MAX 0.46, oars tile phase 0.9; ghost: no GHOST_LEN shortening, socket bead keeps brightening; tray accent before word; VARIANT_WORDS + explain_name; CHANNEL_LOBES; LIGHT_COLOR const; tools looks_sheet/looks_specimens/drive --specimens.

## Checks
- ci_quick on p6 @602bd5c: boots, input path x3 schemes, gene-probe, gene-names, levels, i18n --check, --lint-all: ALL GREEN. .pot unchanged, fr.po unchanged (no new strings).
- heavy on snap1 (=602bd5c): empty library 7397a410 x3 (69,349 lines); drop_probe ALL PASS 143 (membrane 67a6afe687b3b316 = dev's, so DEV_MEMBRANE unchanged); net_probe ALL PASS 465 (Wire.RULES 95c66e7e537b56bf); net_fuzz, net_drop ALL PASS (all under unshare --net); DropSave.rules e4213164b90d.
- Since 602bd5c only tools/ (5fb6520) and docs (8cbb281) changed: re-run ci_quick at the end.

## Resume: next commands, in order
1. `python3 $N/bin/plants.py` (planted faults, checks 1-11) -> record result.
2. Bench, interleaved, 3 rounds each, quiet machine (pgrep godot first):
   `cd <tree> && xvfb-run -a -s "-screen 0 1280x720x24" ~/godot/godot --path <tree> --rendering-driver opengl3 --script $N/bin/bench_draw.gd`
   with <tree> = $N/before then $S/genes/p6; report p10/p50/p90 of _draw and frame.
3. Copy finals into $N/shots/ (before/after pairs, grey/deut sheets + one zoom, vari, room, tray, pads, offers, compares).
4. Write gene-looks.md Status + "As built" (judged table from above, numbers, deviations); README paragraph in $N/; commit `chore: genes as data: ...` docs.
5. `bash $N/bin/ci_quick.sh` (then `git checkout -- project.godot`), gene probe green.
6. Hand back: commits, PR title, decisions, judged table, numbers, unverified (phone draw cost; no real variant yet), riskiest (cilia.gd fringe/tile rewrite; as_shipped() relies on keys_of_organ()[0] being the organ as shipped -- phase 5's variant handling may change that).
