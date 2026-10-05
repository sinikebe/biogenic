# Gene foundation: where it stopped (2026-10-05, paused for usage)

**Drop this `wip-notes/` folder before merging anything.** These notes are
scratch, kept here only so a resumed session loses nothing.

- **dev** has phases 1a to 3 (PRs #190 to #193). The dev app is on content 193.
- **PR #194, phase 4** (the rules on the handshake, protocol 8): CI green on
  `d25d50d`, reviewed, verdict "ship to dev". The review's fixes are on
  `claude/nifty-cray-bs1zs2-wip-phase4-fixes`, on top of `b63e365`, whose tree
  is the PR's code. Items 1 to 5 are done (5 inside the WIP commit); 6 to 8 and
  the one `Wire.RULES` pin move are left (`fix4-PROGRESS.md`; the review itself
  is `review-4-PROGRESS.md`). To resume: finish them, cherry-pick the branch's
  commits after `b63e365` onto the PR branch (which also has `d25d50d`, the
  CLAUDE.md fix), move the pin once, CI, launcher check, squash-merge.
- **Phase 5** (ceilings, names gate, one-entry variants, calls 6 to 13,
  README and gene skill): `claude/nifty-cray-bs1zs2-wip-phase5`, from
  `b63e365` (`PROGRESS-5.md`). Open finding: registering a second, unworn tail
  variant changes the seeded run; find why before item 4's timing. After #194
  merges, rebase onto dev and put the stat rows' `group` on the rules row line.
- **Phase 6** (looks by family): `claude/nifty-cray-bs1zs2-wip-phase6`, from
  `b63e365` (`PROGRESS-6.md`). Left: planted faults, the draw-cost bench, the
  final frames, gene-looks.md's "As built", the README paragraph. It is a
  visible change, so its PR gets a player-facing title.
- **Phase 7** (common and rare genes): not started; after phase 5.
  `docs/design/gene-rarity.md`, answered by the owner.
- Scratch evidence (baselines, shots, logs) lived in the session's scratchpad
  and is gone with its container: re-run what a PROGRESS file says passed.
