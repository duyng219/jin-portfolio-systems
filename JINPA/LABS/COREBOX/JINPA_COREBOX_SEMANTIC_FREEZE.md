# JINPA CORE BOX — SEMANTIC FREEZE

**STATUS: FROZEN FOR MIGRATION TO JINPA_DEV**

## 1. Purpose

This document freezes the validated Case 5 Core Box market-semantic contract before migration from `JINPA_COREBOX_LAB` to `JINPA_DEV`. It records the behavior already implemented and validated; it does not introduce, optimize, or reinterpret Structure logic.

## 2. Freeze record

- Freeze date: 2026-09-10 (Asia/Seoul)
- Branch: `main`
- HEAD: `136df9e437a2c048e48d4e1643bf7de23acfe396`
- Pre-document LAB full-tree baseline: 40 files, SHA-256 `1085f4d3d1b7dff8b2b741ae1fba9b1e51680d632cedea20996262ced3f14efa`
- LAB behavioral-source baseline (`*.mq5` and `*.mqh` only): 27 files, SHA-256 `207310d47d0adb04f35204d504c12161c4c76ae6fdac05d577f0fe3e7514d5f3`
- `JINPA_DEV`: 37 files, SHA-256 `ff62fec9c62d45224bcd3b79e3c37dfeec6d507a153acf0f93406fa26a2fa838`
- `JINPA_v2.5`: 41 files, SHA-256 `da62fcc1af296800d2e639184fb1f04073806b00180cd5d666eb331b819333b4`
- `JINPA_v2.4`: 30 files, SHA-256 `f51a4f98074f63127fd9b63f00508069fb0786d62dafff6cd1e62167dccca81e`

The full-tree LAB fingerprint above is the baseline before adding this document. The behavioral-source fingerprint excludes documentation and compiled artifacts so it can prove that the freeze created no source-behavior change. A full-tree post-document fingerprint is reported by the freeze validation record outside this self-referential document.

## 3. Architecture scope

This freeze covers Core Box market semantics: Core boundaries, confirmed Core Breaks, Break-Origin causality, expansion completion, pending lifecycle and recovery, Cycle transitions, False Breaks, Leg #1/#2, Sideway confirmation/latching, and SwingType/CoreRole independence.

It freezes the Case 5 semantic foundation only. It is not a freeze of all LAB implementation details and does not authorize migration in this task.

## 4. Dual Core Box definition

A `COMPLETE` Core Box contains both `Core High` and `Core Low`. Both are authoritative protected structural boundaries. Confirmed internal swings cannot move either boundary. A boundary changes only through a valid confirmed Core Break lifecycle.

## 5. Bull continuation

After a confirmed break above the current Core High:

1. The confirmed Break-Origin Low that directly created the bullish break leg becomes the new authoritative Core Low.
2. The lifecycle becomes `PENDING_HIGH`; no new Core High exists yet.
3. A confirmed expansion High is accepted only under the causal-window contract.
4. That expansion High becomes the new Core High and the Box becomes `COMPLETE`.
5. The Cycle remains `BULL` for Bull continuation.

## 6. Bear continuation

The Bear path is the exact structural mirror. A confirmed Core Low break promotes the directly causal Break-Origin High, enters `PENDING_LOW`, waits for a valid confirmed expansion Low, then completes the new Box. The Cycle remains `BEAR` for Bear continuation.

## 7. Break-Origin rule

Core reassignment uses the confirmed swing that directly originated the confirmed break leg, not the nearest LH/HL classification. A Bullish origin may be LL or HL; a Bearish origin may be HH or LH. Causal ownership is authoritative.

## 8. SwingType and CoreRole independence

Swing topology and Core role are independent dimensions. Assigning an HH as `CORE_HIGH` does not mutate HH into LH; assigning an LL as `CORE_LOW` does not mutate LL into HL. Original HH/HL/LH/LL classification remains intact.

## 9. Bug A — expansion causal window

An expansion swing is eligible only when:

```text
pivotTime >= candidateStartTime
AND
confirmationTime >= confirmedBreakTime
```

The candidate start is derived from the active break-candidate start. This permits a pivot formed during the breakout leg to be accepted after SwingRightBars later confirms it. The rejected rule `pivotTime >= confirmedBreakTime` must not be restored. Only a confirmed `SwingPoint` may become a Core boundary.

## 10. Bug B — pending authority

`PENDING` does not remove all Core authority:

- `PENDING_HIGH`: Core Low exists and is authoritative; Core High is nonexistent/pending.
- `PENDING_LOW`: Core High exists and is authoritative; Core Low is nonexistent/pending.

Only the existing authoritative boundary is evaluated for break. A nonexistent pending boundary must never be evaluated.

## 11. Pending recovery and supersession

If the authoritative boundary breaks before expansion completes, the pending transition is superseded atomically. The previous confirmed break remains historical fact; the engine does not restore the old completed Box or reinterpret that break as a False Break. It clears obsolete pending/candidate evidence, changes Cycle when required, promotes the new Break-Origin as the replacement authority, enters the corresponding new pending lifecycle, and waits for confirmed expansion.

Superseding an incomplete pending transition does not increment completed generation. Generation increments once only when a new Box becomes `COMPLETE`.

## 12. False Break behavior

A False Break leaves Core High, Core Low, and Cycle unchanged. It resets the active break candidate and associated candidate-origin evidence as required, then continues with the same Core Box. If Sideway is already confirmed, its latch remains confirmed; False Break does not restart Leg/Sideway counting or emit another Sideway confirmation.

## 13. COMPLETE versus PENDING gating

Leg and Sideway evaluation is enabled only for a `COMPLETE` Core Box. While `PENDING_HIGH` or `PENDING_LOW`, the engine must not start Leg #1, start Leg #2, confirm Sideway, or increment the noisy internal-swing count. The expansion-completion swing itself must not become Leg #1 accidentally.

## 14. Leg #1 and Leg #2 semantics

In Bull context, Leg #1 conceptually correlates with `revs-ppf` and Leg #2 with `revs-pps`. The canonical path is Core High, internal pullback/Leg #1, internal push, deeper Leg #2, then an internal recovery. Detection targets the two-leg internal transition inside an intact Core Box and is not restricted to topology labels alone. Bear behavior is the exact mirror. This contract does not implement a Setup Engine.

## 15. Clean Sideway

After a complete Box, Leg #1 forms, an internal push/recovery occurs, Leg #2 forms, and a confirmed recovery swing remains structurally inside both Core boundaries. Sideway is then confirmed. The clean pattern confirms on the recovery after the two-leg sequence; it does not wait unnecessarily for a sixth swing.

## 16. Noisy Sideway fallback

When clean topology is absent, six qualifying confirmed internal swings strictly inside the same intact complete Box confirm Sideway, provided neither Core boundary has been confirmed broken. Initial Core anchors are excluded. The counter is scoped to the current completed Box lifecycle. The threshold remains six and is not exposed or optimized by this freeze.

## 17. Sideway latch

Once confirmed for the current Core Box, Sideway remains latched. The engine does not continue counting to re-confirm it and emits no duplicate confirmation. The latch resets only after a real confirmed break of Core High or Core Low; a False Break does not release it.

## 18. Core Break confirmation defaults

The current research inputs remain unchanged:

- `SwingLeftBars = 5`
- `SwingRightBars = 5`
- `StructureATRPeriod = 14`
- `CoreBreakATRBuffer = 0.10`
- `CoreBreakConfirmCloses = 2`

The threshold is `boundary ± ATR × CoreBreakATRBuffer` and requires the configured consecutive closes. These values remain configurable research inputs and are not optimized by this freeze.

## 19. Display contract

The Structure display inputs remain `ShowCoreBox` and `ShowStructureSwings`. Display state never changes Engine state.

- A visible complete Box has exactly one active Core High and one active Core Low line.
- `PENDING_HIGH` displays only its authoritative Core Low.
- `PENDING_LOW` displays only its authoritative Core High.
- `ShowCoreBox=false` leaves zero LAB-owned Core objects.
- `ShowStructureSwings=true` displays HH/HL/LH/LL labels; `false` leaves zero LAB-owned swing objects.

## 20. Bug C — accepted known limitation

Generation is a session/history-relative bookkeeping ordinal. It is not market semantic, a stable CoreBox identity, or a persistent identity. Bootstrap resets it and recounts only complete Boxes reconstructible from the available finite history. Therefore the same Core High, Core Low, Cycle, and lifecycle can receive different generation values after restart, chart reopen, lookback change, or a change in available prehistory. The offset is not guaranteed to remain constant.

Bug C's root cause is understood and is intentionally not fixed by this freeze. It is non-blocking because static and runtime audits confirm generation does not control current market semantics.

## 21. Generation safety restriction

Generation must not be used as a persistent CoreBox ID, market-semantic identity, persistent foreign key, Stage 3 identity, Setup/Signal identity, backtest sample identity, or persistent dedup identity. It may remain a renderer label, debug/log value, and session-local ordinal.

A future architecture may rename it to `sessionGeneration` and add a deterministic `CoreBoxId`, but that requires a separate identity-contract task. Current `event.identity`, notification dedup, transition logic, Sideway logic, renderer object names/ownership, and trading do not materially depend on generation.

## 22. Renderer Object Pruning — deferred

Renderer pruning is deferred until after migration and full Structure regression, and is required before Stage 3. Future pruning may retain active Core boundaries and a bounded number of renderer-owned historical swings. It must never remove Engine state, delete manual/user objects, or perform broad unsafe cleanup. `ENGINE STATE != RENDERER OBJECT` is mandatory.

## 23. Deterministic regression evidence

The unchanged `CoreBoxLabDeterministicProbe` passed on 2026-09-10:

- Semantic: 14 passed / 0 failed
- Parameter: 7 passed / 0 failed
- Display: 4 passed / 0 failed
- Case 5 including A+B: 29 passed / 0 failed
- Total: 54 passed / 0 failed

The suite covers Bull/Bear continuation, Cycle changes, Stage 2.10 causality, False Breaks, clean/noisy Sideway, Sideway latch, pending gating/recovery/supersession, generation increment discipline, duplicate semantic event identities, renderer pending authority, and bootstrap/sequential semantic parity.

## 24. XAUUSD H1 real-market evidence

Replay range `2026-04-15` through `2026-05-31`, default Structure inputs, Exness-MT5Trial7 data:

- `2026-04-17 18:00`: BULL, COMPLETE, Core High `4889.872`, Core Low `4778.762`.
- `2026-04-20 04:00`: BEAR, COMPLETE, Core High `4889.872`, Core Low `4736.877`.
- Final replay state: BULL, COMPLETE, Core High `4595.286`, Core Low `4489.053`.
- 757 processed bars and 75 events.
- Longest observed pending interval: 13 hours; the former 44-day deadlock is absent.
- Trades/orders/cancels/closes/push: `0/0/0/0/0`.

Generation ordinal mismatch is excluded from semantic parity; all Core, Cycle, lifecycle, pending, origin, Leg, and Sideway checks remain authoritative.

## 25. Compile evidence

On 2026-09-10 using MetaEditor x64:

- `JINPA_COREBOX_LAB.mq5`: 0 errors / 0 warnings.
- `CoreBoxLabDeterministicProbe.mq5`: 0 errors / 0 warnings.

## 26. Protected-project evidence

`JINPA_DEV`, `JINPA_v2.5`, and `JINPA_v2.4` remained byte/tree-fingerprint identical throughout validation. No migration was performed.

## 27. Frozen market semantic

The following are frozen:

- Core High/Core Low authority and immutability under internal swings
- confirmed Core Break behavior and Cycle transition semantics
- causal Break-Origin selection
- expansion causal window
- pending lifecycle, authority, recovery, and supersession
- False Break behavior
- COMPLETE/PENDING Leg and Sideway gating
- Leg #1 and Leg #2 semantics
- clean and noisy Sideway confirmation and latch behavior
- SwingType/CoreRole independence
- current display-state separation from Engine state

## 28. Not frozen / deferred

The following remain outside this semantic freeze:

- persistent generation identity and future deterministic CoreBoxId
- renderer pruning and renderer performance optimization
- Structure parameter optimization
- Cases 1–4
- Market State / Regime Stage 3
- Setup Engine, Signal Engine, and seven-setup detection
- backtest/data infrastructure
- non-semantic implementation details that do not alter this contract

## 29. Migration boundary

The next authorized step is a separate `JINPA_COREBOX_LAB → JINPA_DEV` migration task. Migration must port this frozen behavior without redesign, optimization, Bug C repair, Cases 1–4 implementation, renderer pruning, or Stage 3 work.

## 30. Reopening policy

Frozen Core semantic must not change silently. If Cases 1–4 expose a conflict, work stops and records `SEMANTIC CONFLICT`, including the frozen rule, conflicting Case, chart/sequence evidence, proposed change, and downstream impact. Explicit approval is required before changing the contract.

Critical changes follow:

```text
investigate → reproduce → targeted fix → regression → re-freeze
```

This is the same discipline used for Stage 2.10 and Case 5 A+B.
