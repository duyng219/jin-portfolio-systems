# JINPA v2.5

**Status:** LIVE CANDIDATE — RE-FROZEN AFTER STAGE 2.10

**Release date:** 2026-09-06
**Re-freeze date:** 2026-09-08

## 1. Purpose

JINPA v2.5 is the frozen production manual-trading assistant for the JINPA portfolio workflow. It combines the production `CJINPAPanel`, deterministic symbol Magic resolution, risk-controlled execution, position lifecycle management, price-structure intelligence, chart rendering, Push notifications, and optional Daily Drawdown protection.

## 2. Production architecture

```text
JINPA_v2.5.mq5
├── Production UI
│   └── CJINPAPanel
├── Production Managers
│   ├── IndicatorsManager
│   ├── BarManager
│   ├── RiskManager
│   ├── DrawdownManager
│   └── PositionManager
├── Production Infrastructure
│   ├── InfoDisplay
│   ├── PositionHelper
│   └── MagicNumberResolver
├── Production Execution
│   ├── Market BUY / SELL
│   ├── BUY STOP / SELL STOP
│   ├── BUY LIMIT / SELL LIMIT
│   ├── Cancel / Close
│   ├── ATR TSL
│   └── EXIT lifecycle
└── WatchIntegration
    ├── PriceStructureEngine
    ├── StructureDebugRenderer
    └── StructureNotificationManager
```

The active graph excludes MarketRadar, scanners, multi-symbol orchestration, `OnTimer`, heartbeat, DEV `CUIManager`/`COrderExecutor`, and all Stage 3 regime/setup/signal engines.

## 3. Major changes from v2.4

- Deterministic Auto Magic with supported broker symbol variants.
- Structured TRADE, TSL, EXIT, WARN, and ERROR logging.
- Correct market, STOP, and LIMIT execution paths.
- Correct LIMIT entry-relative ATR stop and risk/margin sizing.
- Complete cancel, close, TSL, and EXIT lifecycle integration.
- Frozen Price Structure Engine, renderer, and eligible-event Push pipeline.
- Runtime-validated optional Daily Drawdown entry gate.
- Production header `JINPA v2.5` and panel top offset `Y = 40`.

## 4. Auto Magic mapping

| Canonical symbol | Magic |
|---|---:|
| XAUUSD | 101001 |
| BTCUSD | 101002 |
| ETHUSD | 101003 |
| EURUSD | 101004 |
| USDJPY | 101005 |
| US30 | 101006 |
| Unsupported symbol fallback | 109999 |

Recognized variants are the canonical name, `M` prefix/suffix, `.A`, `.PRO`, `#`, and `_M1_QDM` suffix.

## 5. Trading execution behavior

The production panel owns market BUY/SELL, pending-order placement, cancellation, and side-specific position closing. Orders use the resolved Magic and the exact setup/suffix/custom comment selected in the panel. All six entry paths share the Daily DD execution gate.

## 6. Pending-order fixes

BUY/SELL STOP and BUY/SELL LIMIT are runtime verified. LIMIT stop loss is derived from the pending entry price, and risk volume uses the actual pending entry-to-stop distance. Broker margin behavior remains account/symbol dependent.

## 7. TSL

ATR trailing supports the configured mode, activation distance, and step. BUY and SELL TSL changes were broker-confirmed. The TSL path remains active when Daily DD blocks new entries.

## 8. EXIT lifecycle

Natural SL, trailed-SL, and manual EXIT events are runtime verified with correct JINPA ownership filtering. False and duplicate EXIT observations were zero. Partial close and `OUT_BY` remain untested.

## 9. Price Structure Engine

The frozen engine processes closed-bar structure, swings, Core changes, break candidates/failures, and confirmed cycle transitions. It remains independent of the trading-entry halt.

## 10. Structure Renderer

The renderer displays historical swing annotations and the active Core level/label. Historical objects are retained and are not pruned.

## 11. Push notifications

Push identity remains `JINPA WATCH | SYMBOL TF`. Eligible events are exactly:

- `CORE_SWING_CHANGED`
- `CORE_BREAK_CANDIDATE`
- `CYCLE_CHANGED`

Queue order is FIFO, with at most one dispatch attempt per live new bar. Dedup is session-local. There is no retry or persistent queue. Real phone delivery and zero true duplicates were confirmed during M9-D.

## 12. Daily Drawdown behavior

- Reference: peak equity tracked by `DrawdownManager` during the current day/session.
- Formula: `(minEquityToday - maxEquityToday) / maxEquityToday * 100`.
- `MaxDrawdownDaily = 0`: OFF.
- `2.00`: 2%; `3.00`: 3%.
- Breach comparison: `dailyDD <= -MaxDrawdownDaily`.
- A breach blocks new entries but does not block Close, PositionManager, TSL, EXIT, Structure, Renderer, or Notification processing.
- Daily rollover uses broker/server `TimeCurrent()` and resets the daily reference.

The normal user setting is OFF. When enabled operationally, the intended limit is approximately 2–3%; runtime validation used a lower safe threshold.

## 13. Intended live workflow

1. Open or load the chart.
2. Confirm the Default MT5 template is already applied.
3. Select the intended timeframe, normally H1 or higher.
4. Attach `JINPA_v2.5`.
5. Verify the resolved Magic.
6. Trade through `CJINPAPanel`.

Do not repeatedly re-apply templates while JINPA is attached; stale Trade Log `LogRow` objects may remain. This does not affect the normal workflow above.

## 14. Runtime validation summary

| Capability | Verification |
|---|---|
| Auto Magic | RUNTIME VERIFIED |
| Comment workflow | RUNTIME VERIFIED |
| BUY Market | RUNTIME VERIFIED |
| SELL Market | RUNTIME VERIFIED |
| BUY STOP | RUNTIME VERIFIED |
| SELL STOP | RUNTIME VERIFIED |
| BUY LIMIT | RUNTIME VERIFIED |
| SELL LIMIT | RUNTIME VERIFIED |
| Cancel Buy | RUNTIME VERIFIED |
| Cancel Sell | RUNTIME VERIFIED |
| Close Buy | RUNTIME VERIFIED |
| Close Sell | RUNTIME VERIFIED |
| Risk sizing | RUNTIME VERIFIED |
| LIMIT ATR-SL fix | RUNTIME VERIFIED |
| Pending margin context | RUNTIME VERIFIED |
| ATR TSL | RUNTIME VERIFIED |
| EXIT SL | RUNTIME VERIFIED |
| EXIT Manual | RUNTIME VERIFIED |
| Daily DD OFF | RUNTIME VERIFIED |
| Daily DD ON | RUNTIME VERIFIED |
| DD entry halt | RUNTIME VERIFIED |
| DD Close safety | RUNTIME VERIFIED |
| DD / Structure independence | RUNTIME VERIFIED |
| DD / Renderer independence | RUNTIME VERIFIED |
| DD / Notification independence | STATIC VERIFIED |
| Structure Engine | RUNTIME VERIFIED |
| Structure Renderer | RUNTIME VERIFIED |
| Phone Push | RUNTIME VERIFIED |
| Push dedup | RUNTIME VERIFIED |
| Normal live workflow | RUNTIME VERIFIED |
| Template static-label recovery | RUNTIME VERIFIED |
| Compile | RUNTIME VERIFIED — 0 errors, 0 warnings |

M9-B verified all six execution paths, both cancel and close sides, Magic `101002`, exact comments, and LIMIT sizing. M9-C verified BUY/SELL TSL and EXIT behavior with zero false or duplicate TSL/EXIT events. M9-D verified real Push delivery, DD OFF/ON, entry halt, safe Close, subsystem independence, daily reset, and clean final inventory.

## 15. Known limitations

1. Partial close runtime is not tested.
2. `OUT_BY` runtime is not tested.
3. Notification queue dispatches at most one item per new bar.
4. Notification dedup is session-local.
5. Push has no retry.
6. Push queue is not persistent.
7. Renderer retains historical chart objects.
8. Renderer has no pruning.
9. Object count grows with chart history.
10. Strategy Tester Journal may buffer output until pause, stop, or completion.
11. Unknown-symbol fallback Magic `109999` may collide across unsupported symbols.
12. Pending-margin behavior may vary by broker, symbol, and account.
13. Applying templates while the EA is attached may leave stale Trade Log `LogRow` objects.
14. Daily DD state is memory/session based and resets through its daily lifecycle.
15. DD scaling at 2–3% is source-verified; runtime triggering used a lower safe threshold.
16. Live production beyond Exness Demo remains the user's operational responsibility.

## 16. Protected predecessor

`JINPA_v2.4` remains the previous stable production reference and was not modified during the v2.5 freeze.

## 17. Development branch

`JINPA_DEV` remains the development/R&D line. Stage 3 work resumes there, not in frozen v2.5.

## 18. Final source fingerprint

Production main-source SHA-256:

`55f237018910755e080eed0806d52317fb1617d87927a86541e90271453ae120`

## 19. EX5 SHA-256

Final X64 artifact: `348248` bytes

SHA-256: `1530f97a45deec2b4fb8ac6455958e56a3c908d1e8a8b51603f615b1e69a2996`

## 20. Release status

**LIVE CANDIDATE — RE-FROZEN AFTER STAGE 2.10**

No further feature development is permitted in v2.5. Only critical production fixes may reopen this boundary.

## Post-freeze Structure patch — Stage 2.10

Stage 2.10 corrected Core reassignment after a confirmed Structure break. The previous algorithm selected the nearest confirmed `LH` after BULL → BEAR and the nearest confirmed `HL` after BEAR → BULL. That coupled Core role incorrectly to swing topology.

The corrected rule assigns the new Core from the confirmed Break-Origin swing of the final break leg:

- BULL → BEAR: New Core High is the captured confirmed Swing High, whether `HH` or `LH`.
- BEAR → BULL: New Core Low is the captured confirmed Swing Low, whether `LL` or `HL`.
- A newer confirmed same-side extreme replaces the candidate origin before second-close confirmation.
- A failed break clears the candidate origin without changing the existing Core.
- Swing topology remains immutable: an `HH` promoted to Core High remains `HH`, and an `LL` promoted to Core Low remains `LL`.

The deterministic Stage 2.10 golden case produced SWING `2`, CORE_BREAK_CANDIDATE `1`, CYCLE_CHANGED `1`, CORE_SWING_INITIALIZED `1`, and duplicates `0`. It verified the canonical `LH(2) @ 110` → `HH(4) @ 120` correction, the symmetric LL case, legacy LH/HL behavior, false-break retention, multiple-origin replacement, SwingType preservation, bootstrap/sequential parity, and DEV/v2.5 ordered-stream parity.

`JINPA_DEV` and v2.5 use byte-identical corrected Structure Engines. No production execution, risk, panel, position lifecycle, renderer, notification, or Daily Drawdown architecture changed in Stage 2.10. Earlier M1–M9 evidence remains historical evidence from before this targeted patch.
