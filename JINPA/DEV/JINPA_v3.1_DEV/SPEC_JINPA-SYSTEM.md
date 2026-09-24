# SPEC — JINPA_v3.1_DEV Current System Baseline

**Baseline date:** 2026-09-22

**Product version:** `3.10` / JINPA v3.1 DEV

**Source baseline:** commit `3a8fe8cc4a343a23bee9f94a6f154a8bb5210f52` (`feat(jinpa): implement notification policy v1.0`)
**Authority:** runtime source under `JINPA/DEV/JINPA_v3.1_DEV/`

This is the single source-of-truth specification for JINPA v3.1 DEV. It
describes behavior implemented by the current source, including the Phase 2
Local Swing default change; it is not a target-design document. Planned work
is explicitly separated from current runtime behavior in section 17.

## 1. Purpose / Scope

Primary audited sources:

| Area | Source ownership |
|---|---|
| EA lifecycle, inputs, manual execution | `JINPA/DEV/JINPA_v3.1_DEV/JINPA_v3.1_DEV.mq5` |
| WATCH integration and closed-bar orchestration | `JINPA/DEV/JINPA_v3.1_DEV/watch/WatchIntegration.mqh` |
| WATCH runtime DTO and logger | `watch/core/WatcherTypes.mqh`, `watch/core/WatcherLogger.mqh` |
| Price Structure, Local Swing, Core, Cycle, Sideway | `watch/structure/PriceStructureEngine.mqh`, `watch/structure/StructureTypes.mqh` |
| Structure chart renderer | `watch/structure/StructureDebugRenderer.mqh` |
| Market Regime and State | `watch/state/MarketStateEngine.mqh` |
| Market Structure projection | `watch/state/MarketStructureEngine.mqh` |
| Confirmed Micro Base visualization | `watch/structure/MicroBaseRenderer.mqh` |
| Pullback Setup and unified Pullback Leg authority | `watch/setup/PullbackSetupEngine.mqh` |
| Active READY Base visualization | `watch/setup/PullbackBaseRenderer.mqh` |
| Notification Policy v1.0 | `watch/structure/StructureNotificationManager.mqh` |
| WATCH Radar | `watch/ui/MarketRadar.mqh` |
| Manual order bridge | `_core/infrastructure/order_executor.mqh` |
| Risk and position/trailing management | `_core/managers/risk_manager.mqh`, `_core/managers/position_manager.mqh` |
| Manual chart controls | `_core/infrastructure/ui_manager.mqh` |
| Deterministic probes | `tests/*.mq5` |

The `_panel/` directory is present in the DEV tree but is not included by the
current main EA. The active manual controls and information display come from
`_core/framework_manager.mqh` and its `_core` dependencies. The two JSON files
under `configs/` are currently empty and are not referenced by the compiled
`.mq5/.mqh` path.

## 2. Current Architecture

### 2.1 Analysis flow

```text
MT5 market data
  → CPriceStructureEngine
    → Local Swings / HH-HL-LH-LL
    → Core Box / Cycle / Sideway / StructureEvent history
  → CMarketStateEngine
  → CMarketStructureEngine
  → CPullbackSetupEngine
  → SymbolState
  → CMarketRadar + CStructureDebugRenderer
```

Notification branch:

```text
Price Structure StructureEvents
Market Structure transitions
Setup/Status transitions
  → CStructureNotificationManager
  → FIFO queue + session deduplication
  → MT5 SendNotification (live only)
```

Manual execution is a separate branch:

```text
Chart buttons
  → CUIManager
  → COrderExecutor
  → CTrade
  → market/pending order, cancel or close
```

WATCH analysis and Setup `ACTIVE` do not feed the manual execution branch.

## 3. Closed-Bar Pipeline

`OnTick()` calls `watchIntegration.ProcessTick()` before the legacy/manual EA
work. `ProcessTick()` returns unless the current chart bar time is strictly
newer than `m_lastBarTime`. On a new current bar:

1. The previous bar is now the latest closed bar.
2. `CPriceStructureEngine::Update()` additionally verifies that `iTime(...,1)`
   is newer than `m_lastProcessedClosedBarTime`; a changed current-bar stamp
   alone cannot create a structure event.
3. Price Structure processes chronological `CopyRates` data and records the
   closed bar as processed.
4. `UpdateStructureConsumers()` gets the snapshot and event history, then
   applies Market State, Market Structure and Setup in that order.
5. `SymbolState` and Radar are updated.
6. New Price Structure events are consumed into the notification queue.
7. At most one queued notification is dispatched per new-bar cycle.

No new closed bar means no Price Structure processing, State/Structure/Setup
transition, Radar semantic update, or notification dispatch.

### 3.1 Bootstrap

Initialization copies up to 500 bars and reconstructs Price Structure
chronologically with `m_isBootstrapping=true`. Events are retained in event
history for downstream replay, but are not exposed in the live pending-event
queue. Initial Market State/Structure/Setup projection happens while WATCH is
not enabled, so transition Push enqueue is suppressed. Radar is created only
after this projection.

### 3.2 Pipeline data contracts

#### 3.2.1 `SymbolState`

`watch/core/WatcherTypes.mqh` owns the row consumed by Radar:

- Identity/time: `symbol`, `timeframe`, `lastBarTime`, `lastUpdate`.
- Analysis: `cycle`, `activeCorePrice`, `hasActiveCore`, `regime`, `state`,
  `structure`, `setup`, `setupStatus`.
- Event/readiness: `lastEvent`, `lastEventTime`, `isReady`.
- Reserved activity fields: `isActive`, `lastTickTime`,
  `activityInitialized`.

Current single-symbol integration initializes the activity fields but does not
subsequently calculate a separate tick-activity state. Radar's footer count
uses `isReady`, not `isActive`.

#### 3.2.2 Price Structure snapshot

`PriceStructureState` contains the latest/previous high and low swings,
`CoreSwingState`, `CoreBoxState`, `PendingCoreBoxState`, `CycleState`,
`SidewayBoxState`, basic high/low structure summaries, last event metadata and
the initialization flag. Snapshot history additionally exposes confirmed
swings, broken cores and completed/active Sideway boxes.

## 4. Price Structure

### 4.1 Local Swing detection

Effective integrated defaults are `SwingLeftBars=3` and
`SwingRightBars=3`. A Swing High must be strictly higher than every high in
both windows; a Swing Low must be strictly lower than every low in both
windows. The pivot at index `candidateIndex` is confirmed only when the closed
bar at `candidateIndex + SwingRightBars` exists.

The distance filter is enabled internally. A candidate must be at least
`ATR × 1.2` from the most recent confirmed opposite-type swing. The first
candidate without an opposite swing passes. ATR must be available when the
filter is enabled.

Important effective-default note: the `CPriceStructureEngine` constructor
contains fallback values 3/3, `ATR × 1.0`, and 300 lookback bars.
`CWatchIntegration` also defaults its swing windows to 3/3, then the EA calls
`ConfigureStructure()` with the user-facing inputs before initialization.
Therefore the EA inputs remain runtime authority and the current default
effective swing window is 3/3. The integrated distance and lookback settings
remain `ATR × 1.2` and 500 bars.

### 4.2 `SwingPoint`

Important fields are pivot `time`, current `shift`, `price`, `type`,
HH/HL/LH/LL/equal `classification`, `confirmationTime`, opposite-origin record
index/time/price, and `confirmed`. A point's local classification is not
rewritten when the point later owns a Core role.

### 4.3 Classification

- Confirmed high above/below the previous confirmed high becomes `HH`/`LH`.
- Confirmed low above/below the previous confirmed low becomes `HL`/`LL`.
- Difference within one symbol point becomes `EH` or `EL`.
- The first same-type swing is unclassified (`STRUCT_NONE`).
- `HH + HL` yields basic Bull structure; `LH + LL` yields Bear; missing sides
  yield Unknown; other combinations yield Mixed.

### 4.4 Initial Cycle and Core Box

The initial Cycle becomes Bull when a confirmed `HH` exists with the latest
low classified `HL`; it becomes Bear when a confirmed `LL` exists with the
latest high classified `LH`. Once Cycle and both confirmed boundary swings
exist, the engine establishes a complete Core Box from the latest high and
low. Each completed box has a generation, creation time and owner Cycle.

The legacy `CoreSwingState` is synchronized from the Core Box: Bull protects
Core Low and Bear protects Core High. `SymbolState.activeCorePrice` exposes
only that protected side.

### 4.5 Core break lifecycle

Break evaluation uses closed candle `close`, never wick/intrabar price.

- Up candidate: close above `Core High + ATR × CoreBreakATRBuffer`.
- Down candidate: close below `Core Low - ATR × CoreBreakATRBuffer`.
- The first qualifying close emits `CORE_BREAK_CANDIDATE` and sets
  `confirmationCount=1`.
- Consecutive qualifying closes confirm when count reaches
  `CoreBreakConfirmCloses` (default 2).
- If the next close reclaims the threshold, the candidate resets and emits
  `CORE_BREAK_FAILED`.

A confirmed break archives the protected broken core/active Sideway where
applicable and immediately starts the next Core Box lifecycle. The confirmed
break-origin swing becomes one known boundary; the opposite boundary remains
absent (`PENDING_HIGH` or `PENDING_LOW`) until a later confirmed expansion
swing beyond the broken boundary completes the new box. Break direction owns
the resulting Bull/Bear Cycle. `CYCLE_CHANGED` is emitted only when old and new
Cycle differ; `CORE_BOX_TRANSITION_STARTED` represents the promoted boundary.

### 4.6 Sideway and Core Box legs

Only confirmed swings strictly inside a complete Core Box, after box creation
and different from the box boundaries, count as internal swings.

For a Bull box:

- LEG 1 is the first internal Swing Low.
- An internal Swing High after LEG 1 sets `oppositeSeenAfterLeg1`.
- LEG 2 is a later internal Swing Low below the LEG 1 low.
- A later internal Swing High after LEG 2 confirms clean Sideway.

For a Bear box the types and comparisons are mirrored: High, then Low, then a
higher High, then a later Low.

Sideway confirmation modes:

- `SIDEWAY_CLEAN_2_LEG`: the clean sequence above completes.
- `SIDEWAY_NOISY_6_SWING`: six confirmed internal swings accumulate first.

Confirmed Sideway uses the fixed Core Box high/low as price boundaries and
advances only its right edge (`lastUpdateTime`) on later closed bars. A
confirmed Core Box break archives/ends the active box.

### 4.7 Price Structure events

The enum currently contains:

- `CORE_SWING_INITIALIZED`, `CORE_SWING_CHANGED`
- `CORE_BREAK_CANDIDATE`, `CORE_BREAK_FAILED`
- `CYCLE_CHANGED`
- `CORE_BOX_INITIALIZED`, `CORE_BOX_CHANGED`
- `LEG_1_CONFIRMED`, `LEG_2_CONFIRMED`
- `SIDEWAY_CONFIRMED`
- `CORE_BOX_TRANSITION_STARTED`

Every event carries symbol/timeframe, closed event-bar time, cycles, core type,
old/new/break levels, reason, deterministic identity, box generation and
Sideway confirmation type. Bootstrap events enter history but not the pending
live queue.

The source still contains legacy continuation/Sideway helper functions for
compatibility and probes. The active `ProcessRates()` path accepts swings,
evaluates `EvaluateCoreBoxSwing()`, evaluates `EvaluateCoreBoxBreak()`, and
extends confirmed Core Box Sideway. This active path is the baseline described
above.

## 5. Market Regime

Owned by `watch/state/MarketStateEngine.mqh`.

REGIME values:

- `UNKNOWN` — reset/technical default.
- `RANGE` — entered with Compression/active Sideway.
- `TREND` — entered on expansion and used when the current snapshot is not
  Sideway-active.

The current Regime set is exactly `UNKNOWN / RANGE / TREND`.

Regime is the broad market context. An active Sideway/Compression resolves to
`RANGE`; Expansion and subsequent non-Sideway processing resolve to `TREND`.
`UNKNOWN` remains the reset/technical default.

## 6. Market State

Owned by `watch/state/MarketStateEngine.mqh` and rebuilt chronologically from
Price Structure event history plus closed rates on every apply.

STATE values:

- `UNKNOWN` — reset/technical default.
- `COMPRESSION`
- `EXPANSION`
- `IMPULSE`
- `CORRECTION`

The current State set is exactly
`UNKNOWN / COMPRESSION / EXPANSION / IMPULSE / CORRECTION`.

The engine rebuilds chronologically from Price Structure event history and
rates on every apply:

- `SIDEWAY_CONFIRMED` enters `COMPRESSION`, sets Regime `RANGE`, and clears
  breakout/impulse references. An active Sideway snapshot forces this result
  at the end of rebuild.
- `CORE_BOX_TRANSITION_STARTED` enters `EXPANSION`, stores the event's new
  Cycle plus breakout time/close, and sets Regime `TREND`.
- A strictly later closed bar enters `IMPULSE` only when its close continues
  beyond the stored breakout close in the Cycle direction.
- While in `IMPULSE`, a newly confirmed directional extreme after impulse
  start enters `CORRECTION`: `HH` for Bull or `LL` for Bear.
- A confirmed-break candle establishes Expansion only; it cannot also become
  Impulse on the same bar.

If history is insufficient to establish a semantic State, `UNKNOWN` remains a
valid runtime technical value even when the final non-Sideway Regime resolves
to `TREND`.

## 7. Market Structure

Owned by `watch/state/MarketStructureEngine.mqh`. Output is a single current
projection in `SymbolState.structure`.

### 7.1 Base mapping and priority

| Context | Structure | Rule/source |
|---|---|---|
| Compression + active Sideway | `SIDEWAY` | Base Compression projection |
| Expansion | `BREAKOUT` | Direct Market State mapping |
| Impulse | `CONTINUATION` | Direct Market State mapping, subject to Micro Base overlay |
| Correction | `NONE` | Base projection until unified Pullback Setup confirms a Leg |
| Other/technical | `NONE` | No semantic structure |

The integration reset value is `UNKNOWN`; after engine projection, the
technical no-match value is `NONE`.

### 7.2 Compression extensions

On a normal closed Compression bar, priority is:

1. `FALSE BREAK` when `CORE_BREAK_FAILED` exists at that closed bar.
2. `REJECTION` when High reaches/exceeds box high and Close finishes below it,
   or Low reaches/breaches box low and Close finishes above it.
3. `RANGE EDGE` when Close is within `ATR × CoreBreakATRBuffer` of either fixed
   Sideway boundary. The current multiplier is therefore the same configured
   `CoreBreakATRBuffer`, default 0.10.
4. `SIDEWAY` otherwise.

On the exact `SIDEWAY_CONFIRMED` event bar, the extensions are skipped and the
output is `SIDEWAY`.

### 7.3 Micro Base

Micro Base is an instance-scoped overlay allowed only in Regime `TREND`, State
`IMPULSE`, with a known Cycle. It is separate from Price Structure/Core Box.

- After Structure has reached `CONTINUATION`, the next processed closed bar
  becomes a fixed anchor (`anchorHigh`, `anchorLow`, count 1).
- Each later bar whose Close stays inside the anchor range increments the
  count. At count 3 the output becomes `MICRO BASE`.
- A Close outside either anchor boundary resets the candidate and returns
  `CONTINUATION`, regardless of whether the break is with or against Cycle.
- Count greater than 8 also resets to `CONTINUATION`.
- Leaving Trend/Impulse or losing Cycle resets the candidate.
- Wick excursions do not break the candidate; only Close is tested.

Each stable `MarketStateEngine.ImpulseStartTime()` owns one acceptance latch.
Zero or more candidates may fail without consuming that Impulse. The latch is
set only when the first candidate reaches the existing `barCount >= 3`
confirmation point. That accepted Micro Base continues its normal active and
break/timeout lifecycle, but its later reset to `CONTINUATION` does not clear
the latch. Further candidates and confirmations are blocked for the same
Impulse. A different non-zero `impulseStartTime` resets the latch and permits
one first confirmed Micro Base for the new Impulse. On startup, closed bars for
the current Impulse are replayed through the same detection function so the
consumed latch matches forward processing. This is explicitly the first
**confirmed** Micro Base, not the first candidate.

Current implementation does not use ATR, volume or MACD for Micro Base.
The detection rule, anchor selection, confirmation count, timeout and break
semantics remain owned exclusively by `MarketStructureEngine.mqh`.

Confirmed Micro Base visualization is a read-only enhancement. Once the
existing engine reports `confirmed=true`, `MicroBaseRenderer.mqh` draws the
engine-owned `anchorHigh` and `anchorLow` as white, solid, width-1 `OBJ_TREND`
segments beginning at `anchorTime`. The active pair extends to each latest
closed bar. When the engine no longer reports the confirmed Base, the pair
freezes at that closed bar and remains as immutable visual history. Candidate
and failed unconfirmed Micro Bases never create chart objects.

### 7.4 Transition behavior

The engine is applied only on the closed-bar integration path. Market Structure
transitions are detected by comparing the prior output string to the current
projection. Repeated identical structure on later bars is not a transition.
Micro Base carries its own bar-time guard. Other structures are recomputed
from the current State, snapshot, event-at-bar and closed candle.

## 8. Setup Engine

Owned by `watch/setup/PullbackSetupEngine.mqh`. This engine consumes Market
State, Market Structure, Cycle, existing confirmed Local Swing history and
closed rates. It does not place trades.

SETUP values:

- `-` (`JINPA_SETUP_NONE`)
- `revs-ppf`
- `revs-pps`

STATUS values:

- `NONE`
- `WATCH`
- `READY`
- `ACTIVE`
- `INVALID`

Nominal lifecycle:

```text
NONE → WATCH → READY → ACTIVE → INVALID → NONE
```

A PPF WATCH or READY setup becomes INVALID when Correction context is lost or
Cycle changes. After unified LEG 1, the armed PPS lifecycle instead accepts
both `CORRECTION` and `COMPRESSION`; Sideway/Compression alone does not
invalidate PPS. A READY Base failure is different from context invalidation:
the setup context remains valid and returns to WATCH.

### 8.1 Unified candidate and Base rule

A confirmed `SwingPoint` is a candidate, not a Leg. The shared Base builder
locates the exact pivot candle and the configured three chronological right
confirmation bars: `PIVOT + R1 + R2 + R3`. All four are closed when R3
confirms the current 3/3 Swing; R4/current is excluded.

- Bull Swing Low: `BaseLow = Pivot Low`; `BaseHigh` is the highest High from
  Pivot through R3.
- Bear Swing High: `BaseHigh = Pivot High`; `BaseLow` is the lowest Low from
  Pivot through R3.
- `BaseTime` and candidate identity remain `SwingPoint.time`; READY begins on
  the confirmation bar, never retroactively at the pivot.

A Base is immutable for the lifetime of one candidate identity: its High and
Low are never recalculated from a moving rates window. A newly confirmed,
deeper Bull Swing Low or higher Bear Swing High may finalize and replace an
unbroken Base. Otherwise the Base ends only by success, failure or context
invalidation. Only closed-bar Close is evaluated; wick-only excursions neither
activate nor fail a Setup.

On every READY closed bar, the engine evaluates the old active Base before it
processes a SwingPoint confirmed on that same bar. Success finalizes the old
Base as ACTIVE and does not consume a replacement candidate. Failure finalizes
the old Base, clears its candidate/Base fields, returns the same setup type to
WATCH, and may then accept a genuinely new SwingPoint confirmed on that bar.
This ordering prevents a new candidate from silently mutating the old Base.

### 8.2 `revs-ppf`

- Starts when current State is `CORRECTION` and previous State was not
  `CORRECTION`.
- It starts as `WATCH` without a Base.
- Bull: a newly confirmed Swing Low creates/replaces the Base and enters
  `READY`; a later `Close > BaseHigh` confirms `LEG 1` and PPF `ACTIVE` on the
  same closed bar. A later `Close < BaseLow` fails only that candidate and
  returns PPF to `WATCH` without a LEG.
- Bear mirrors this with Swing High: `Close < BaseLow` succeeds, while
  `Close > BaseHigh` fails the candidate and returns PPF to `WATCH`.
- A failed candidate is cleared. Until a new matching confirmed SwingPoint
  exists, WATCH owns no active Base and cannot redraw one at another level.

### 8.3 `revs-pps`

PPS is evaluated only after unified LEG 1 confirmation and does not run a
second swing detector.

- Bull requires a newly confirmed Swing High after the LEG 1 candidate and
  confirmation bar; Bear mirrors this with Swing Low. This turning swing
  starts PPS `WATCH`.
- The armed PPS context, PPS `WATCH`, and PPS `READY` are valid in either State
  `CORRECTION` or `COMPRESSION` while Cycle remains known and unchanged. This
  includes a turning Swing or candidate Swing confirmed on the same bar as
  `SIDEWAY_CONFIRMED`.
- Sideway/Compression alone does not clear unified LEG 1, the PPS turning Swing,
  the current candidate identity or an immutable READY Base.
- The next Bull Swing Low or Bear Swing High creates the shared four-closed-bar
  Base and enters `READY`; candidate replacement follows the same PPF rule.
- A later Bull `Close > BaseHigh` or Bear `Close < BaseLow` confirms `LEG 2`
  and PPS `ACTIVE` on the same closed bar.
- Bull `Close < BaseLow` or Bear `Close > BaseHigh` fails only the PPS
  candidate, returns PPS to `WATCH`, and preserves the already confirmed LEG 1
  and PPS turning-swing context. The next valid Swing candidate can create a
  new Base and re-enter `READY`.
- The consumed swing's pivot and confirmation times form an identity guard so
  the same minor swing cannot restart PPS.
- PPS replaces PPF as the single primary setup and initializes its rolling
  base from the PPS confirmation bar.
- Its Bull/Bear rolling-base trigger and ACTIVE/INVALID behavior are identical
  to PPF.
- PPS can confirm LEG 2 while State is `COMPRESSION`. Current projection
  precedence remains unchanged: on the PPS ACTIVE bar, the Pullback authority
  writes `Structure = LEG 2`, overriding the previously derived `SIDEWAY` value
  for that bar. This patch does not redesign Structure precedence.
- One unified LEG 1 can arm at most one PPS lifecycle. PPF ACTIVE terminal
  processing preserves LEG 1 long enough for the first valid turning Swing to
  start PPS. After PPS confirms LEG 2, the next closed bar changes PPS ACTIVE
  to INVALID and consumes the complete LEG 1/LEG 2/turning context. When the
  INVALID lifecycle subsequently clears to NONE, later Swing Highs/Lows cannot
  re-arm PPS from that old LEG 1. A new PPS requires a genuinely new upstream
  PPF and unified LEG 1 chain.

## 9. Setup Status Lifecycle

- `ACTIVE` remains for the trigger closed-bar cycle only; the next later
  closed bar changes it to `INVALID`.
- PPF ACTIVE terminal transition preserves its confirmed LEG 1 arm. PPS ACTIVE
  terminal transition clears LEG 1, LEG 2 and PPS turning metadata only after
  the ACTIVE/LEG 2 bar has already been output and notified.
- `INVALID` remains for that closed-bar cycle; the next later closed bar clears
  to `NONE` unless another valid start occurs through normal logic.
- No-new-bar calls are rejected by `m_lastProcessedBarTime`.
- Cycle change or unknown Cycle invalidates PPF/PPS and clears their stored
  context. PPF WATCH/READY additionally requires State `CORRECTION`. Armed PPS,
  PPS WATCH and PPS READY permit `CORRECTION` or `COMPRESSION`; other States
  invalidate them. Candidate Base failure does not invalidate the setup.
- No separate opposite-Core-break detector exists in the Pullback engine.
  Structural invalidation beyond reset is currently expressed through known,
  unchanged Cycle plus the setup-specific State gate above.

`CPullbackSetupEngine` is the single authority for Pullback candidate, Base,
READY, LEG 1/LEG 2 confirmation and PPF/PPS activation. CoreBox internal leg
fields remain Sideway mechanics but no longer project Market Structure LEG.

## 10. Radar

### 10.1 WATCH Radar

Owned by `watch/ui/MarketRadar.mqh`. Current title is `JINPA WATCH v1.1` and the
header timestamp is `UPDATED: HH:MM` using `TimeCurrent()`.

Columns and sources:

| Column | Source |
|---|---|
| SYMBOL | `SymbolState.symbol` |
| TF | formatted `SymbolState.timeframe` |
| CYCLE | `SymbolState.cycle`; rendered as `BULL (UP)`, `BEAR (DOWN)`, or `UNKNOWN` |
| REGIME | `SymbolState.regime` |
| STATE | `SymbolState.state` |
| STRUCTURE | `SymbolState.structure` |
| SETUP | `SymbolState.setup` |
| STATUS | `SymbolState.setupStatus` |

The columns are independent: `RANGE / COMPRESSION / SIDEWAY` can legitimately
coexist with `revs-pps / WATCH` or `revs-pps / READY`.

The integrated WATCH owns one current-chart row. Layout is bottom-right with
Compact/Wide/Ultra responsive profiles. `RecoverIfNeeded()` recreates missing
objects without changing analysis. `OnChartChange()` refreshes layout and Core
label position. Semantic row updates occur at initialization and each new
closed-bar cycle; object-health checks may run on other ticks.

Footer fields are `WATCHER`, `SYMBOL`, `ACTIVE`, and `LAST EVENT`. The current
ACTIVE count is the number of rows with `isReady=true`; it is not based on the
reserved `isActive` activity field.

### 10.2 Structure renderer

`StructureDebugRenderer.mqh` optionally draws confirmed HH/HL/LH/LL labels,
and always maintains applicable finite Broken Core lines, Sideway boundaries,
and the single currently protected Core boundary (Bull Core Low or Bear Core
High). `ShowStructureSwings=false` removes only swing annotations.

### 10.3 Pullback Base renderer

`PullbackBaseRenderer.mqh` draws each READY Base as a deterministic pair of
white, solid, width-1 `OBJ_TREND` segments. The active pair starts at pivot
time and extends to the latest closed bar. A READY Base is temporary:
replacement deletes the old pair before drawing the new candidate, and Base
failure (`READY` to `WATCH`) or any pre-ACTIVE invalidation/reset deletes the
active pair. WATCH without a candidate has no Base visual. Only a successful
directional breakout that produces `ACTIVE` together with confirmed `LEG 1`
(PPF) or `LEG 2` (PPS) freezes the pair at the trigger bar and preserves it as
immutable historical chart structure. Later `ACTIVE -> INVALID -> NONE`
transitions do not delete, extend, overwrite or reuse that confirmed pair.
Future confirmed pullback chains use their own deterministic candidate
identities, so multiple confirmed PPF/PPS Bases may coexist. Explicit EA
shutdown/deinit still follows the project renderer convention and removes all
owned Base objects.

### 10.4 Micro Base renderer

`MicroBaseRenderer.mqh` owns the separate `JINPA_MICRO_BASE_` object prefix.
Identity contains symbol, timeframe, anchor time and HIGH/LOW side. It consumes
only the existing engine's read-only confirmed flag, anchor time and Base
bounds; it does not calculate, confirm, reject or otherwise modify Micro Base
semantics. `Destroy()` follows the project convention and removes all objects
under its prefix on shutdown/reinitialization.

## 11. Notification Policy

Owned by `watch/structure/StructureNotificationManager.mqh` and connected in
`watch/WatchIntegration.mqh`.

Current format uses naturalized display text only; internal values stay
uppercase/lowercase as defined by their engines:

```text
JINPA Watch | {SYMBOL} {TF}
{Event or Setup | Status}
{Cycle | State | Structure}
{Optional useful detail}
```

### 11.1 Eligible notifications

Price Structure/Core/Cycle events:

- `CORE_BREAK_CANDIDATE` → Break Candidate.
- `CORE_BOX_TRANSITION_STARTED` → Core Updated.
- Actual old/new `CYCLE_CHANGED` → Cycle Changed.
- `SIDEWAY_CONFIRMED`.
- `CORE_BREAK_FAILED` → False Break.

Market Structure transitions, only when previous differs from current:

- Range Edge
- Rejection
- Micro Base
- Breakout
- Leg 1 and Leg 2 from the unified Pullback transition

Setup transitions:

- `revs-ppf` Watch, Ready and Active
- `revs-pps` Watch, Ready and Active

READY uses the natural setup format and adds
`Base {BaseLow} - {BaseHigh}` with the symbol's runtime price precision. It is
emitted only after a valid Pivot..R3 Base is built.

### 11.2 Intentionally ineligible

- Market Structure `CONTINUATION`.
- All Market State-only transitions.
- Setup `INVALID` and `NONE`.
- Setup `READY` to `WATCH` caused by candidate Base failure; the failure itself
  emits no repeated WATCH Push. The next candidate uses its own READY identity.
- Unchanged Market Structure or unchanged Setup/Status.
- `CORE_SWING_INITIALIZED`, `CORE_SWING_CHANGED`, `CORE_BOX_INITIALIZED` and
  `CORE_BOX_CHANGED` are recorded Price Structure events but are not directly
  Push-eligible. In particular, current “Core Updated” Push maps to
  `CORE_BOX_TRANSITION_STARTED`, not `CORE_SWING_CHANGED`.

### 11.3 Queue, identity and dispatch

- The manager owns one FIFO of already formatted messages.
- Price Structure dedup uses the event's deterministic source identity.
- Market Structure identity is symbol + timeframe + closed bar time + current
  structure.
- Normal Setup identity uses symbol + timeframe + closed bar time + setup +
  status. READY instead keys on symbol + timeframe + setup + status + candidate
  Swing time. Replacement can therefore emit one new READY Push while replay
  of the same candidate on any later bar remains deduped.
- Known identities are session-scoped and suppress repeated enqueue.
- Bootstrap transition enqueue is suppressed by `m_enabled=false`.
- Multiple eligible items on a bar remain queued in deterministic enqueue
  order; only one is removed/dispatched per subsequent new-bar cycle.
- The queue item is removed before calling MT5 Push. A failed live
  `SendNotification` is logged and is not automatically retried.
- The master notification flag currently defaults to enabled internally and
  is not a user-facing input.

### 11.4 Strategy Tester

Tester follows the same eligibility, formatting, queue and dedup paths.
`DispatchNext()` removes the bounded item but returns before
`SendNotification`; therefore real Push attempts remain zero. This is a second
guard at the transport boundary rather than a separate Tester policy.

## 12. Inputs / Configuration

### 12.1 User-facing EA inputs

| Input | Default | Purpose / consumer |
|---|---:|---|
| `slPointsValue` | `0` | Manual-order SL points; 0 selects ATR logic in main/order bridge |
| `POExpirationMinutes` | `360` | Pending-order expiry; `COrderExecutor` |
| `MaxDrawdownDaily` | `0` | Daily drawdown halt; 0 disables; main EA |
| `MoneyManagement` | `MM_EQUITY_RISK_PERCENT` | Manual order sizing mode; `CRiskManager` |
| `RiskPercent` | `0.5` | Equity risk percent for manual orders |
| `FixedVolume` | `0.01` | Fixed-lot modes |
| `MinLotPerEquitySteps` | `500` | Equity-per-lot scaling modes |
| `MAPeriod` | `21` | Main MA initialization/refresh |
| `MAMethod` | `MODE_EMA` | Main MA method |
| `MAShift` | `0` | Main MA shift |
| `MAPrice` | `PRICE_CLOSE` | Main MA applied price |
| `ATRPeriod` | `14` | Legacy/manual SL, pending offset and trailing ATR; separate from Structure ATR |
| `ATRFactorSL` | `2.5` | Initial manual-order SL distance |
| `ATRFactorTSL` | `3.5` | Trailing-stop distance |
| `ATRFactorPO` | `2.5` | Pending-order offset |
| `TSLMode` | `TSL_STEP` | Current trailing mode |
| `TSLActivationATR` | `2.5` | Breakeven-first activation parameter |
| `TSLStepATR` | `2.5` | Step trailing minimum movement parameter |
| `SwingLeftBars` | `3` | Local Swing left window; WATCH Price Structure |
| `SwingRightBars` | `3` | Local Swing right/confirmation window |
| `StructureATRPeriod` | `14` | Swing-distance and Core-break ATR |
| `CoreBreakATRBuffer` | `0.10` | Core break threshold and Market Structure edge-distance ATR multiplier |
| `CoreBreakConfirmCloses` | `2` | Required consecutive Core-boundary closes |
| `ShowStructureSwings` | `true` | HH/HL/LH/LL chart annotations |
| `LogLevel` | `LOG_INFO` | Manual order-result logging |

The MA is currently initialized and refreshed, but it does not drive the WATCH
engines or automatic entry decisions.

### 12.2 Internal WATCH configuration

| Setting | Effective default | Exposure |
|---|---:|---|
| Use swing minimum distance | `true` | Internal |
| Minimum swing distance | `1.2 ATR` | Internal |
| Structure lookback | `500` bars | Internal |
| Use Core break ATR buffer | `true` | Internal |
| Structure audit log | `false` | Internal |
| Core-break audit log | `false` | Internal |
| Structure notifications | `true` | Internal master flag |
| Radar | enabled, bottom-right, x=15, y=20, row=20, font=9 | Internal |

The public Structure inputs override the corresponding integration defaults
before Price Structure initialization. There is currently no user-facing
notification enable/disable input.

## 13. Execution Boundary

The correct current boundary is:

- WATCH, Market State, Market Structure, Pullback Setup, Radar and notification
  analysis are observer-only.
- Setup `ACTIVE` is a displayed/notified signal state only. It never calls
  `CTrade`, `OrderSend`, or `COrderExecutor`.
- The full JINPA EA is **not** observer-only. It retains manual one-click
  execution through ten chart buttons: market Buy/Sell, Buy/Sell Stop,
  Buy/Sell Limit, cancel Buy/Sell pending order, and close Buy/Sell position.
- `COrderExecutor` uses `CTrade`; the main EA also performs ATR trailing-stop
  management on each tick for matching symbol/magic positions.
- Low-level legacy `_core` classes also contain direct `OrderSend` utilities,
  although the active main button bridge uses `CTrade`.
- There is no automatic execution from WATCH Setup signals and no Auto Trade
  enable input in the current baseline.

### 13.1 Retained manual execution details

These legacy/manual details remain part of the current EA and are retained here
because they do not conflict with WATCH behavior:

- Risk sizing supports minimum lot, minimum-lot-per-equity, fixed lot,
  fixed-lot-per-equity and equity-risk-percent modes. Risk-percent sizing
  derives maximum account risk from equity and stop distance, then normalizes
  volume to broker minimum, maximum and step and checks available margin.
- ATR stop loss is below Ask for Buy and above Bid for Sell by
  `ATR × ATRFactorSL`. Trailing stop iterates matching symbol/magic
  positions and only moves Buy stops upward or Sell stops downward.
- Pending Buy/Sell Stop and Limit prices use the configured ATR offset and
  `ORDER_TIME_SPECIFIED` expiry from `POExpirationMinutes`.
- The ten-button UI contains Buy/Sell market, Stop, Limit, cancel and close
  controls. It is recreated on relevant chart resize/object-loss events.
- Drawdown management tracks daily/monthly equity extrema; the configured
  daily limit can halt the legacy/manual branch after WATCH has already
  processed the tick.
- The information display and button tooltips are refreshed by the manual
  branch. `CPositionHelper` supplies position counts and recent-bar average
  highs/lows used by that branch.

Deterministic WATCH probes do not press manual controls; their expected trade,
pending, cancel and close counters are zero.

## 14. Strategy Tester / Probes

| Probe | Responsibility | Current expected runtime summary |
|---|---|---:|
| `CoreBoxDevDeterministicProbe.mq5` | Stage 2 Local Swing/Core Box/Cycle/Sideway, bootstrap, renderer, configuration and legacy StructureEvent notification regression | `128/128 PASS` |
| `MarketStateDeterministicProbe.mq5` | Compression/Expansion/Impulse/Correction lifecycle, guards, bootstrap and Radar contract | `23/23 PASS` |
| `MarketStructureDeterministicProbe.mq5` | Base projection, authority/priority, Range Edge/Rejection/False Break, first-confirmed-per-Impulse Micro Base gate, confirmed-only visualization and Radar value | `57 checks` |
| `PullbackSetupDeterministicProbe.mq5` | Unified PPF/PPS candidate, immutable four-bar Base, Bull/Bear failure/recovery, single-use LEG 1→PPS chains, PPS terminal cleanup/no-rearm in Correction and Compression, same-bar Sideway edges, PPF strictness, cycle guards, confirmed-only Base history and Radar coexistence | `79 checks` |
| `NotificationPolicyDeterministicProbe.mq5` | Eligible policy including unified Leg, READY candidate identity, Base-failure WATCH suppression, READY formatting, FIFO/dedup and Tester guard | `31 checks` |

All engines and probes use deterministic closed-bar timestamps. The notification
probe requires `MQL_TESTER=true`, drains the queue, and asserts zero real
`SendNotification` attempts. Probe summaries expect execution counters zero.

## 15. Source Traceability

These are implementation facts that differ from common prior assumptions:

1. Effective default Local Swing is 3/3 across the EA inputs,
   WatchIntegration fallback and Price Structure constructor fallback. The EA
   inputs remain runtime authority through `ConfigureStructure()`.
2. Only the WATCH/Setup branch is observer-only. The full EA still supports
   manual execution and trailing-stop modification.
3. Notification “Core Updated” currently maps to
   `CORE_BOX_TRANSITION_STARTED`, not every Core Swing or Core Box changed
   event.
4. Radar's `ACTIVE` footer currently counts `isReady`; the independent
   activity fields are not populated after reset.
5. `CoreBreakATRBuffer` is also reused as the Market Structure RANGE EDGE
   distance multiplier.
6. Current Price Structure contains retained legacy helper code, but active
   `ProcessRates()` follows the Core Box path documented in section 4.

## 16. Current Baseline / Version

This specification originated from the audited implementation baseline before
Phase 2 and now incorporates the Phase 2 Local Swing default change:

- Baseline commit: `3a8fe8c`
  (full SHA `3a8fe8cc4a343a23bee9f94a6f154a8bb5210f52`).
- Baseline date: `2026-09-22`.
- Product version: `3.10` / JINPA v3.1 DEV.
- Phase 2 effective Local Swing default: `3/3`.
- Runtime authority: current source under
  `JINPA/DEV/JINPA_v3.1_DEV/`.

## 17. Known Gaps / Planned Changes

The following items are planned changes and are **not implemented in this
baseline**:

1. Review and fix Micro Base noise.
2. Clean up inputs and lock selected parameters.
3. Add Auto Trade with an enable/disable input.
4. Add trade arrows.
5. Add Telegram transport alongside MT5 Push.
6. Update this SPEC after every behavior change.

## 18. Code ↔ SPEC Consistency Checklist

- [x] Price Structure matches current source.
- [x] Market State matches current source.
- [x] Market Structure matches current source.
- [x] Setup matches current source.
- [x] Notification policy and display format match current source.
- [x] User-facing and internal defaults match current source.
- [x] Radar mapping and readiness behavior match current source.
- [x] Strategy Tester behavior matches current source.
- [x] WATCH versus manual execution boundary matches current source.
