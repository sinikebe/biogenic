# PROGRESS-5 — genes as data, phase 5

Worktree: $S/genes/p5 (branch phase-5, base b63e365). Notes: $S/genes/notes/p5/.
$S = /tmp/claude-0/-home-user-biogenic/ca8eaf53-ebf6-5e74-8c32-ffc13b1863be/scratchpad

## RESUME POINT -- paused 2026-10-05 on the coordinator's word (read this first)

HEAD **79cf090** `chore: genes as data: WIP phase 5 (paused)` on branch phase-5 (base b63e365). Tree clean, nothing
pushed, no stash (stashes are shared across worktrees: never use one). Nothing of mine was running at the pause.

Commits: f430095 item 1 | 06c6482 call 6 | 0255802 call 7 | bf9efc9 call 8 | 4d6eea4 call 10 (group = plain row
field) | 13817e5 call 12 | 01f8a0f call 13 | **79cf090 WIP** = every uncommitted change at the pause: the ceilings
(code), game/genes/README.md, .claude/skills/gene/SKILL.md.

### First thing on resuming: split 79cf090 into focused commits
`git -C $S/genes/p5 reset HEAD~1` (mixed: files kept, unstaged; README/SKILL untracked again), then stage per commit
with `python3 $N/scripts/stage_hunks.py $S/genes/p5 <path> <hunk indices>` (indices = `git diff -U3` against 01f8a0f,
as listed under "Commits" below on 2026-10-05; re-list with the awk one-liner if anything moved). Titles
`chore: genes as data: ...`, the two trailers.
- (a) rulebook owner bits: game/mechanics/rulebook.gd, own_rules.gd, programs_page.gd, drop.gd (all hunks);
  food.gd hunks 0,1,2; tools/drop_probe.gd hunks 4,5,6,7,10; tools/gene_probe.gd hunks 0-4 (all).
- (b) census from INF: tools/drop_probe.gd hunk 0.
- (c) lineage line by key: food.gd hunks 3,4; drop_probe.gd hunks 1,2,3,8,9 (`_keyed()`, pins untouched).
- (d) tier clamp: tools/drive.gd (`--sample=` clamp reads GenomeNode.TIER_MAX).
- (e) TIER_MAX lives in gene.gd (`const TIER_MAX := 3`); genome.gd reads it; wire.gd preloads gene.gd,
  `TIER_TOP := Gene.TIER_MAX`, four "loads nothing but the body plan" comments updated.
- (f) tools/net_fuzz.gd: genomes from Catalogue.keys() + invented names (15%), tiers 0..Wire.TIER_TOP.
- (g) game/genes/README.md + .claude/skills/gene/SKILL.md.

### Each item of the brief
1. Implicit first variant -- **DONE** (f430095; spec §6.2, §12.3 note). gene probe 56 PASS then; plants m1a-e FAIL.
2. Phase 3 review calls -- **DONE**: 6 06c6482, 7 0255802, 8 bf9efc9 (mechanics only; player words wait for the
   first organ that turns one_variant on -- said in README and spec §6.3), 9 no change (to record in §15.6),
   10 4d6eea4, 11 phase 6's (untouched), 12 13817e5, 13 01f8a0f (ci.yml "Check the gene names" comment is stale:
   report, do not edit). Plants: m6a/b, m7a/b, m8a-d, m10a-d, m12a/b, m13_gaps, m13_comments all shown failing
   (logs p5/mut/*.log, edits p5/mut/edits/).
3. §13 ceilings -- **CODE DONE, in 79cf090, to be split (above)**. Left in it:
   - plant lineage `left(4)` back in a scratch copy and show `drop_probe -- --tail-only` fail (p5_mut.sh);
   - net_probe `--sister-only`, `--server-only`, `--referee-only` in unshare (p5_net.sh) on the final tree, for
     TIER_TOP and the rulebook (pond rules);
   - spec §13 notes saying which were already done: GENES_MAX/ORDER_MAX derived in phase 2 and probes already hold
     all three wire limits to their sources (TIER_TOP now derived); cilia.gd:1457/1495 literal tier clamps and
     signal_bus.gd ORGAN_TIER_MAX are phase 6's files (report, untouched); program_words clampi(test,0,3) is a test
     index, not a tier; claims bits are still one int (a 63-trigger ceiling) -- say so.
   Passed on the q3 snapshot ($N/p5-q3 = 79cf090's code): **drop_probe ALL PASS, 143 checks, pins held**
   (p5/drop-q3.log); gene probe 62 ALL PASS; plants mc1-4 FAIL as wanted; bench p5/bench/rulebook-bench-1.txt
   (choose ~9.9-10.7 us and worn ~6.8-7.3 us medians, both trees: equal within noise); q2 suite (rulebook only):
   boots, input traces b3230c7a/2419a0d0/855b1048, library 7397a410 x3, back, levels PASS; net_fuzz ALL PASS (door
   too) with the new genomes.
4. by_organ's other path -- **HALF-DONE**. Trees: $N/p5/item4/v0 (= q3 = 79cf090 code) and $N/p5/item4/v1 (= v0 +
   scratch variant in flagellum.gd `_init`: `variants = [{"variant": &"probeswift", "order": 920, "water":
   {"drifter": false}}]`; checked with tools/p5_item4_check.gd: organ_of = flagellum, `_owners_are_keys` false,
   not in drifters()). **FINDING, unexplained yet: the seeded run moves with the variant registered** --
   `drive --seed=7 --mode=1 --scheme=0 --radius=30 --genome=cytostome:1,cirrus:1,flagellum:1,chemocyte:1,ampulla:1
   --age=900 --fingerprint=3000`: v0 23c9a2ab... (field meals 9, wakes 0, chews 464, overlaps 17449), v1
   e8201b54... (field meals 0, wakes 3, chews 1124, overlaps 8731) -- p5/item4/fp-v0.log, fp-v1.log. An unworn,
   undrawn variant should not move a body: find why before timing (suspects: a random draw over a pool built from
   keys()/live() or tagged lists -- sample/floor/peer pools, drifter_genes/short_genes; ranks shifting because
   probeswift files between toxicyst and rhabdom; Stats.of's multi-provider path for impulse_speed/gaps). If it is
   a bug, fix it (and say so in §15.6); if a deliberate draw, make v1 neutral; then time.
   Timing command (as the as-built records did; ~85 s a run, 24 runs ~35 min, machine otherwise quiet):
   `bash $N/scripts/macro.sh $N/p5/item4/macro-a 3 $N/p5/item4/v0 $N/p5/item4/v1` then the same with
   `macro-b 3 $N/p5/item4/v1 $N/p5/item4/v0`; median + spread per mode; make cheaper (cache per body) only if v1 is
   beyond v0's spread.
5. Playbook -- **WRITTEN, not final**: game/genes/README.md, .claude/skills/gene/SKILL.md (frontmatter `name: gene`,
   description, no disable-model-invocation). Left: re-read both against the final code and commands; spec §16 to
   point at README.
6. Spec -- **NOT STARTED**: status line (~line 15), §13 notes, §15.6 "As built: phase 5" (by file; differences from
   design and why; what was checked; deferred), §16 -> README.

§14 proving nothing changed -- **NOT STARTED on the final tree**. Plan: `git -C $S/genes/p5 archive <final HEAD> |
tar -x -C $N/p5-final`, import (then nothing to restore: not the worktree), then `bash $N/scripts/suite.sh
$N/p5-final $N/p5/final $N/p5/xdg/final boots input library back levels i18n fuzz rules drop net fp`; Wire.RULES
95c66e7e... and DropSave.rules() e4213164... unchanged (rules step); fp hashes vs $N/p5-base; 34 frames vs base
renders (render.sh + pixdiff.py; 3 renders of the final tree first, 0 px); .pot current, fr.po unchanged; saves
(base writes, final reopens and re-saves identically -- saves_4.sh template); dumps (stats_values.gd, vocab_dump.gd:
owner bits are numbers now -- explain); net_probe full + net_drop in unshare; gene probe + names gate.

Baselines: **$N/p5-base** = `git -C $S/genes/p5 archive b63e365 | tar -x -C $N/p5-base`, imported (p5/import-base.log,
0 script errors). **Base renders $N/p5/renders**: 17 poses x 2 sizes x rounds b1,b2,b3 (p5_base_renders.sh), 0 px
b1-b2 and b1-b3. Test trees: $N/p5-dev (sync_p5.sh mirror), $N/p5-q3 (79cf090's code), $N/p5/item4/{v0,v1}.

Report items so far: ci.yml gene-names step comment stale; phase 6's literal tier ceilings (cilia.gd, signal_bus.gd);
call 9 unchanged; claims bits still one int; riskiest = the rulebook's masks going int -> PackedInt64Array (packed
arrays alias on plain assignment; `obj.packed[i] |= x` writes through).

**The next command I would have run** (item 4, where the two runs part):
`diff <(grep -v sha256 $N/p5/item4/fp-v0.log) <(grep -v sha256 $N/p5/item4/fp-v1.log) | head -40`
-- after splitting 79cf090 as above.

## Status (history)
- [x] 0. read spec (all), PROGRESS-3/4, scripts (suite.sh, render.sh, final_4.sh in notes/scripts)

## Design decisions (item 1, implicit first variant)
- RULE (a): an organ's own name is its first key (implicit first variant = the organ instance itself, as today
  for no-variants) whenever it has a place in the order (organ.order >= 0) -- every shipped organ but the toxin;
  an organ with variants and NO order of its own (toxin, probe's gland/probeorgan/probetail) lists its first
  variant itself (forms each with key+order); its name is no key. No-variants path unchanged (rhabdom -1 keyed).
- entries: born defaults 0 (not inherited); order still inherited (uniform) BUT gene probe fails a key filed
  from a variant entry whose order is not set by its entry/form, or shared with another key (says why: ties).
- Catalogue.register(): an organ of an index organ's name STANDS IN ITS PLACE (as an edit to that file);
  forget() puts the index's own back. So probe faster tail = tail's own file + one entry (flagellum + probeswift),
  net_probe _faster_tail/_longer_palp unchanged in code; gene_probe _strain_of_shipped must keep toxin's own
  variants + 1 entry (else it'd replace corrosive).
- gene_probe _keys_of() must follow rule (a).

## Setup (done)
- N = $S/genes/notes; outputs in $N/p5/. Base tree $N/p5-base = archive of b63e365, imported (0 script errors).
- unshare --net WORKS here (reviewer also adds `ip addr add 10.77.0.5/24 dev lo`). Run net_probe/net_fuzz/net_drop inside it.
- Base renders: $N/scripts/p5_base_renders.sh (17 poses x 2 sizes x rounds b1,b2,b3) -> $N/p5/renders, pixdiff files there.
- Reusable: $N/scripts/suite.sh <tree> <out> <xdg> steps... ; render.sh ; pixdiff.py ; stats_values.gd ; vocab_dump.gd ;
  dump_1b.gd ; rules_dump.gd ; saves_4.sh (template for saves).

## Other findings (from reading)
- call 7 sites now: cell.gd tail_level() ~899; food.gd 7947 (b.tail_level), 8677 (_rest_on), 8976 (_stun).
- call 12 sites now: food.gd 4433-4434 (restore_person_genome), 4880-4881 (set_person_genome): swap order before genome.
- call 10: stats.gd _combined ~274; groups = gene_probe TOGETHER -> move to stats.gd GROUPS (probe pins TOGETHER == Stats.GROUPS).
- lineage_line left(4) labels are INSIDE pinned drop_probe lines (THREE_ONE, DEV, PACK3, TAIL): plan = game labels by key;
  probe expands the pins' 4-letter labels to keys (injective today, asserted) and compares at full strength; pins untouched.
- rulebook owner bits: int masks; consumers rulebook.gd, food.gd (Body.worn, _worn_of), own_rules.gd, programs_page.gd
  (_worn, _awake, _asleep_line), drop.gd daughter_behaviours, gene_probe, drop_probe. Bits are not saved or fingerprinted.

## Commits
- C1 f430095 item 1 (implicit first variant; born 0; order check; register stands in place; probe faster tail one entry;
  spec §6.2 + §12.3 note). gene 56 ALL PASS (p5/gene-c1.log). net --sister/--server/--invites 123/57/54 PASS.
  Plants (p5/mut/*.log, edits in p5/mut/edits): m1a no order -> order check FAIL w/ reason; m1b nameless -> clash FAIL;
  m1c old rule -> 2 FAIL; m1d no born default -> 2 FAIL; m1e register appends -> faster tail FAIL (after adding
  gene(plain)==tail identity).
- Tools: scripts/sync_p5.sh (worktree -> p5-dev), scripts/p5_mut.sh <name> <edit.py> <probe> [args], scripts/p5_net.sh
  <tree> <log> <scene> -- args (unshare).
- C2 06c6482 call 6 (peer born keys; _erase_variety; probe 188/400 vs 0 one_variant). plants m6a/m6b FAIL.
- C3 0255802 call 7 (Catalogue.worn_levels(tiers, genome) + organ_level; cell tail_level; food Body.tail_level; own_rules
  worn() uses worn_levels). probe check [3,3,true,3,true]. plants m7a/m7b FAIL. (stubs in net_probe/field_diff answer
  tiers/level_of only -> helper takes genome Object, no new genome method.)
- quick suite q1 (C1-C3): boots 7/7, input b3230c7a/2419a0d0/855b1048, library 7397a410 x3, back, levels PASS.
- base renders DONE: 3 rounds x 34 frames, 0 px b1-b2, b1-b3 (p5/renders).
- C4 bf9efc9 call 8 (Drop.takes_back; _give_back_by_peer; genome _lapse over strain slot; _other_strains; placing 3rd
  elem; drop_probe dna1 3-elem; spec §6.3; gene.gd doc). gene 59 PASS; drop --dna-only 17 PASS. plants m8a-d FAIL.
- C5 c4b8793 call 10 (GROUPS const + Stats.grouped; probe pins TOGETHER, best-combine check; faster tail gaps 2.1).
  COORDINATOR (mid-task): phase 4 review adds `stat.<row>=<better>,<combine>` lines to rules.gd; darts rows -> contact;
  pin moves. Wants call 10's group as a PLAIN ROW FIELD Stats.of reads (they fold it into the rules line at rebase).
  => restructure: every ROWS row gets "group": &"<lead stat>" (or &""), Stats.of reads the row field, groups() derived;
     AMEND C5 (stash call 12 first).
- call 12 (person order before genome) DONE in worktree, uncommitted: food.gd 2 sites + gene_probe _person_order();
  probe 61 PASS; plants m12a/m12b FAIL ([5,9,9,5] / [9,5,5,9] vs [9,9,5,5]).
- C5 AMENDED -> 4d6eea4 call 10 as ROW FIELD: every ROWS row has "group": &"<lead>" or &""; Stats.of reads the row
  field; Stats.groups() derived (ROWS order); Stats.grouped(tiers, lead). Probe: TOGETHER (rows' order) pinned to
  Stats.groups(); row check asks group + lead is its own group's first; best-combine check. plants m10a-d FAIL.
  (stash used then dropped; patch p5/call12.patch). NOTE stashes are SHARED across worktrees: never use stash again.
- C6 13817e5 call 12 (order before genome at both sites; probe _person_order [9,9,5,5]). gene 61 ALL PASS.
- NEXT: call 13 (names gate), then ceilings (rulebook bits, census INF, lineage_line, TIER_MAX clamps, net_fuzz,
  wire limits), item 4 measure, README+SKILL, spec §15.6, final evidence.
- C7 01f8a0f call 13 names gate (GATED exts, _code_of, _shader_code, _gene_names 21, _names_pattern regex w/ backref,
  spec §12.2). 0 names in 75 files. plants m13_gaps (7 FAIL lines; OLD gate ALL PASS) / m13_comments (ALL PASS; OLD
  gate FAILED 2). ci.yml comment stale (report; do not edit).
- item 2 calls DONE: 6,7,8,10,12,13 (9 no change, 11 phase 6).
- NEXT: ceilings.
- CEILINGS (worktree, uncommitted, to be committed separately; use scripts/stage_hunks.py for mixed files):
  * rulebook owner bits: numbered bits, WORD=63, masks PackedInt64Array; Rule.needs (word0 int) + Rule.far; has_bit,
    awake, without, _mark (NOT _set: clashes Object._set), _covers, _need; consumers food(hunks 0-2), own_rules,
    programs_page, drop.gd, drop_probe (hunks 4-7 after moving _keyed), gene_probe (_owner_bits check + bit reads).
    gene 62 PASS; plants mc1-4 FAIL; bench choose/worn equal within noise (p5/bench/rulebook-bench-1.txt).
    q2 suite (rulebook only): boots, input traces, library 7397a410 x3, back, levels PASS; drop running (b..q2).
  * census INF: drop_probe hunk 0.
  * lineage_line by key: food hunks 3-4; drop_probe _keyed() (pins untouched) hunks 1,2,3,8,9. Verify w/ drop
    --tail-only + full drop; plant left(4) back.
  * tier clamps: drive.gd --sample clamp -> GenomeNode.TIER_MAX. cilia.gd:1457,1495 + signal_bus ORGAN_TIER_MAX are
    PHASE 6's files -> report, don't touch. program_words clampi(test,0,3) is a test index, not a tier.
  * wire limits: GENES_MAX/ORDER_MAX already derived (phase 2), probes already hold all 3 to sources. TIER_TOP now
    derived: gene.gd const TIER_MAX := 3; genome.gd TIER_MAX := Catalogue.Gene.TIER_MAX; wire.gd preloads gene.gd,
    TIER_TOP := Gene.TIER_MAX; wire.gd "loads nothing but the body plan" comments updated. gene 62 PASS.
  * net_fuzz: _tiers_from from Catalogue.keys() + _invented names (15%), tier 0..TIER_TOP. fuzz ALL PASS (door too).
- item 4 plan: tree V0 (final) vs V1 (= V0 + flagellum variant NOT a drifter), macro.sh field-cost seed 7, modes 1/0.
