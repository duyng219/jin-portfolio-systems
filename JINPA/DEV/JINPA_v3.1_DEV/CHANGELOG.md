# JINPA Changelog

## v3.1 DEV — Phase 4D bres-pma Setup lifecycle

- Added a dedicated `bres-pma` Impulse setup lifecycle keyed by the existing `ImpulseStartTime` authority.
- A new Impulse arms WATCH; its first confirmed Micro Base snapshots immutable bounds and enters READY.
- A strict cycle-direction closed-bar Base break activates PMA, while an opposite break or expired/lost confirmed Base invalidates it.
- Added trigger-bar outcome-before-State-exit ordering, `ACTIVE -> INVALID -> NONE`, and one PMA lifecycle per Impulse.
- Reused the existing first-confirmed-per-Impulse Micro Base authority and `MicroBaseRenderer`; no detection or chart-object semantics changed.
- Added common single-output arbitration so valid PMA WATCH/READY/ACTIVE is not hidden by stale terminal output from another setup branch.
- Notification transport, execution, Pullback, Range Edge, Market State, Market Structure and LIVE remain unchanged.

## v3.1 DEV — Phase 4C Range Edge Setup engine

- Added deterministic upper/lower Range Edge side authority without changing existing edge or rejection geometry; overlapping edge bands remain `RANGE EDGE` but expose no arbitrary side.
- Added one owner-generation/side/entry-time Edge Episode lifecycle with the display-only `edge-mix / WATCH` alias and no READY state.
- Added `bres-pmb` from confirmed `CORE_BOX_TRANSITION_STARTED`, `revs-pfb` from eligible `CORE_BREAK_FAILED`, and `revs-pmr` from eligible retained-edge `REJECTION`, including explicit BUY/SELL metadata.
- Added trigger-bar `ACTIVE -> INVALID -> NONE`, outcome-only episode consumption, same-bar breakout-before-cleanup ordering, and chronological replay parity coverage.
- Added single-output arbitration that preserves internal PPS semantics: Pullback ACTIVE wins, otherwise Range Edge ACTIVE can replace PPS terminal INVALID; PPS READY/WATCH hides an unresolved `edge-mix` context.
- Kept notification transport, execution, Pullback rules, Market State, Core break detection, Micro Base, LIVE and chart UI unchanged.

## v3.1 DEV — Phase 4B first Micro Base per Impulse

- Limited `MICRO BASE` acceptance to the first confirmed Base of each stable `impulseStartTime` lifecycle.
- Failed candidates do not consume the Impulse; confirmation sets the latch, and a later Base break does not reset it.
- A genuinely new Impulse identity resets the latch, with closed-bar replay restoring the same consumed state after startup.
- Existing anchor geometry, containment, minimum/maximum bars, close-based break, Bull/Bear behavior and Phase 4A renderer style remain unchanged.

## v3.1 DEV — Phase 4A Micro Base visual only

- Added dedicated white BaseHigh/BaseLow chart lines for confirmed `MICRO BASE` zones.
- Confirmed lines extend on closed bars, then freeze and remain as visual history when the Micro Base ends.
- Unconfirmed candidates create no chart objects; object identity is isolated from Pullback Base visualization.
- Display-only enhancement: Micro Base detection, anchor, confirmation, lifecycle, structure precedence and setup semantics are unchanged.

## v3.1 DEV — Phase 3 Patch 6

- Pullback Base visualization now retains only confirmed PPF/PPS Bases that reach `ACTIVE` with confirmed `LEG 1`/`LEG 2`.
- Unconfirmed READY Base objects are deleted on candidate replacement, Base failure, or pre-ACTIVE invalidation/reset.
- Confirmed Base pairs freeze at the ACTIVE trigger bar and remain immutable historical chart structure until renderer shutdown.
- Setup lifecycle, Base calculation, notification policy, and LEG ownership semantics are unchanged.

## v3.1 DEV — Unreleased WATCH/structure display refinements

- Render all structure swing labels (`HH`, `LH`, `HL`, `LL`) in `RGB(80,220,150)` with font size `4`.
- Reduce active Core High/Core Low label font size from `9` to `8`.
- Remove the Core generation suffix (`G<number>`) from active Core High/Core Low labels while preserving pending-transition text.
- Keep Core High positioned above its line and Core Low below its line.
- Compact the WATCH panel configuration to offset `(15,15)`, row height `15`, and font size `8`.
- Reduce WATCH panel footer allowance from `36` to `27` pixels.
- Align the WATCH title and `UPDATED` text at top offset `5`.
- Move the WATCH column header to top offset `34`, its separators to offsets `25` and `52`, and the data row to top offset `59`.
- Display-only changes; no market-state, structure, setup, notification, or execution semantics were intentionally changed.

## v3.1 DEV — Development baseline

- Cloned from the validated v3.0 LIVE Stage 2 release.
- Functionally identical at creation; Stage 3 has not started.
- Status: the only active development baseline for future Stage 3 work.
- Known limitations carried forward unchanged from v3.0 LIVE.
