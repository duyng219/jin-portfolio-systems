# JINPA_DEV Migration Manifest

Stage 2 baseline frozen: 2026-09-05

Role: development, research, backtest, and validation candidate. Validated features are migrated from `JINPA_DEV` into a future live release derived from `JINPA_v2.4`; this document does not authorize changing `JINPA_v2.4` directly.

## Frozen architecture

```text
JINPA_DEV
├── Manual execution
├── Risk and order execution
├── ATR trailing stop
├── Automatic MagicNumber
├── Trade / TSL / EXIT lifecycle logging
└── WATCH (read-only market intelligence)
    ├── Structure Engine
    ├── Debug Renderer
    ├── Journal channels
    ├── Push notification manager
    └── Market Radar
```

Runtime rule: one chart = one current symbol = one current timeframe = one WATCH context. WATCH is driven from `OnTick()` with a closed/new-bar gate. There is no timer, scanner, heartbeat, or multi-symbol orchestration. REGIME, PHASE, and SETUP remain display placeholders; do not claim those engines are implemented.

## Active compile graph

```text
JINPA_DEV.mq5
├── <Trade/Trade.mqh>
├── _core/framework_manager.mqh
│   ├── managers/indicators_manager.mqh
│   ├── managers/bar_manager.mqh
│   ├── managers/risk_manager.mqh
│   ├── managers/drawdown_manager.mqh
│   ├── managers/position_manager.mqh
│   │   └── infrastructure/position_helper.mqh
│   ├── infrastructure/ui_manager.mqh
│   ├── infrastructure/info_display.mqh
│   └── infrastructure/order_executor.mqh
│       ├── managers/risk_manager.mqh
│       ├── managers/position_manager.mqh
│       ├── infrastructure/ui_manager.mqh
│       └── infrastructure/position_helper.mqh
├── _core/infrastructure/magic_number_resolver.mqh
└── watch/WatchIntegration.mqh
    ├── structure/PriceStructureEngine.mqh
    │   ├── structure/StructureTypes.mqh
    │   ├── core/WatcherTypes.mqh
    │   └── core/WatcherLogger.mqh
    ├── structure/StructureDebugRenderer.mqh
    ├── structure/StructureNotificationManager.mqh
    └── ui/MarketRadar.mqh
```

Repeated guarded includes in `order_executor.mqh` are harmless compile dependencies, not alternate implementations.

## Source classification

### A — Active

- `JINPA_DEV.mq5`
- `_core/framework_manager.mqh`
- `_core/managers/{indicators_manager,bar_manager,risk_manager,drawdown_manager,position_manager}.mqh`
- `_core/infrastructure/{ui_manager,info_display,order_executor,position_helper,magic_number_resolver}.mqh`
- `watch/WatchIntegration.mqh`
- `watch/core/{WatcherTypes,WatcherLogger}.mqh`
- `watch/structure/{StructureTypes,PriceStructureEngine,StructureDebugRenderer,StructureNotificationManager}.mqh`
- `watch/ui/MarketRadar.mqh`

### B — Legacy / inactive

- `jinpa-manual.mq5/.ex5`
- `JINPA_v2.2.mq5/.ex5` and `JINPA_v2.2_DOC_VI.md`
- `_panel/{panel_main,panel_defines,trade_log}.mqh`
- `_core/managers/{trade_executor,time_manager,account_manager}.mqh`

These files are not reachable from the active compile graph. Do not delete them during the Stage 2 freeze.

### C — Standalone WATCH reference

- Sibling project `../JINPA_WATCH/`, including `JINPA_WATCHER.mq5`, is a reference implementation only.
- JINPA_DEV compiles its own integrated `watch/` copies and has no runtime/include dependency on the standalone project.

### D — Live JINPA_v2.4

- Sibling project `../JINPA_v2.4/` is the untouched live/stable branch.
- Migration target is a future release derived from v2.4, not a direct Stage 2.9 edit.

### E — Inactive artifacts needing retention review

- `configs/symbols.json`, `configs/hotkeys.json`: not read by the active EA.
- Root README/spec/changelog, historical compile log, and platform metadata may describe earlier generations.
- Review documentation ownership before any later cleanup; none affects runtime.

## Frozen configuration baseline

### WATCH Structure Engine

| Setting | Value |
|---|---:|
| SwingLeftBars | 5 |
| SwingRightBars | 5 |
| UseMinSwingDistanceATR | true |
| MinSwingDistanceATR | 1.2 |
| ATRPeriod | 14 |
| StructureLookbackBars | 500 |
| UseCoreBreakATRBuffer | true |
| CoreBreakATRBuffer | 0.10 |
| EnableStructureAuditLog | false |
| EnableCoreBreakAuditLog | false |

`CWatchIntegration::Initialize()` passes these exact stored values into `CPriceStructureEngine::Configure()`.

### Execution defaults and assumptions

- Default money management: equity risk percent, 0.5%.
- Fixed-volume fallback setting: 0.01; minimum-lot equity step: 500.
- `slPointsValue=0` selects ATR SL; source defaults are ATR(14), SL factor 2.5, pending offset factor 2.5.
- Market orders retain current Ask/Bid entry and existing ATR/manual-points SL behavior.
- BUY STOP: entry `Ask + atrPO`; SL `Ask - atrPO` (subject to existing tick-size normalization).
- SELL STOP: entry `Bid - atrPO`; SL `Bid + atrPO`.
- BUY LIMIT: entry `Ask - atrPO`; SL `entry - atrSL`.
- SELL LIMIT: entry `Bid + atrPO`; SL `entry + atrSL`.
- Pending margin validation uses the actual pending enum and requested `poPrice`; volume is not margin-capped.

### Automatic MagicNumber

| Canonical symbol | Magic |
|---|---:|
| XAUUSD | 101001 |
| BTCUSD | 101002 |
| ETHUSD | 101003 |
| EURUSD | 101004 |
| USDJPY | 101005 |
| US30 | 101006 |
| Unknown fallback | 109999 |

Broker prefix/suffix symbols are canonicalized once during EA initialization. The resolved value is set on the shared `CTrade` object and used by ownership filters.

## Migration checklist: JINPA_DEV to future live release

| Feature | Authoritative source | Current behavior | Validation status | Required migration target | Dependencies / caveats |
|---|---|---|---|---|---|
| WATCH boundary | `watch/WatchIntegration.mqh` | Single current-symbol/timeframe context; bootstrap then new-bar updates | Golden PASS | Integrate lifecycle calls into future v2.5 `OnInit/OnTick/OnChartEvent/OnDeinit` | WATCH must remain read-only |
| Structure types | `watch/structure/StructureTypes.mqh`, `watch/core/WatcherTypes.mqh` | Shared snapshots/events/enums | Compile + golden PASS | Port before Engine/renderer/radar | Do not invent Regime/Phase/Setup semantics |
| Structure Engine | `watch/structure/PriceStructureEngine.mqh` | Frozen 5/5, ATR filters, lookback 500 | 141-event golden PASS | Port unchanged first; optimize only in later research | Depends on Watcher types/logger |
| Structure Journal | `watch/core/WatcherLogger.mqh` | Stable `[JINPA][SWING/CORE/CYCLE/SIDEWAY]` channels | Golden PASS, duplicates 0 | Preserve channel text for regression comparison | Audit channels are disabled by baseline |
| Renderer | `watch/structure/StructureDebugRenderer.mqh` | Read-only snapshot consumer; prefix-scoped object ownership | Visual/template recovery PASS | Port renderer lifecycle and all owned prefixes | No historical pruning; object count grows |
| Push | `watch/structure/StructureNotificationManager.mqh` | Event queue, session-local identity dedup, one dispatch per update | Tester suppression validated | Port manager and tester guard together | Live Push not fully runtime validated; no retry/persistence |
| Market Radar | `watch/ui/MarketRadar.mqh` | One-row, ten-column bottom-right panel | Visual/template recovery PASS | Port together with WatchIntegration recovery calls | Columns Regime/Phase/Setup remain placeholders |
| Auto MagicNumber | `_core/infrastructure/magic_number_resolver.mqh` | Canonical mapping plus 109999 fallback | Runtime/static PASS | Resolve once and apply to shared trade object | Preserve ownership checks throughout lifecycle |
| Pending risk fix | `_core/infrastructure/order_executor.mqh` | LIMIT SL uses `atrSL`; pending margin uses correct enum/entry | BTCUSD runtime PASS | Port handler signatures, formulas, and margin context atomically | Do not replace with volume cap |
| Risk verification | `_core/managers/risk_manager.mqh` | Verify volume, then `OrderCalcMargin(type,symbol,volume,price)` vs free margin | Runtime PASS | Reuse existing interface | Broker pending-margin policy may legitimately return zero |
| Trade logging | `_core/infrastructure/order_executor.mqh` | One concise `[JINPA][TRADE]` result; CTrade success noise suppressed | Runtime PASS | Port logger and `CTrade` log-level setup together | Preserve error retcodes/descriptions |
| ATR TSL | `_core/managers/position_manager.mqh` | Symbol+Magic filtering; throttled/step ATR updates | Stage 2.6 runtime baseline | Port only after position ownership wiring | Current algorithm is frozen, not optimized |
| EXIT logging | `JINPA_DEV.mq5` | `OnTradeTransaction` accepts DEAL_ADD OUT/OUT_BY and classifies SL/TP/Manual/Other | Runtime/static PASS | Port helpers and transaction hook together | Entry-deal history fallback supports ownership; partial exits log per closing deal |
| Manual UI | `_core/infrastructure/ui_manager.mqh` | Ten CButton objects at X=15/Y=45 with frozen palette | Visual/template PASS | Port geometry, palette, event forwarding, and recovery as one unit | Existing chart-resize behavior persists until recreation |
| Info display | `_core/infrastructure/info_display.mqh` | Recreates labels during normal updates; validates all ten button objects | Template recovery PASS | Port with UI recovery coordination | Object names must not collide with WATCH prefixes |
| Template recovery | UI manager, info display, renderer, radar, WatchIntegration | Detect/recreate missing owned objects without EA restart | Real-template visual PASS | Preserve prefix-scoped cleanup and chart-change handling | No timer dependency |

## Frozen UI baselines

### Manual panel

- Origin: X=15, Y=45; ten buttons, two columns and five rows.
- BUY `C'20,34,38'`; SELL `C'43,26,30'`.
- CANCEL/CLOSE `C'14,18,24'`.
- Text `C'225,230,238'`; border `C'55,64,76'`.

### WATCH Market Radar

- `CORNER_RIGHT_LOWER`; right margin 15 px; bottom margin 20 px; prefix `JINPA_RADAR_`.
- Columns: SYMBOL, TF, CYCLE, CORE, REGIME, PHASE, STRUCT, SETUP, STATUS, LAST EVENT.
- Footer: WATCHER, SYMBOL, ACTIVE, TF, LAST UPDATE.
- Background `C'14,18,24'`; grid `C'75,86,102'`; outer border `C'85,96,112'`; primary cell text `C'225,230,238'`.

## Logging and lifecycle invariants

- Stable channel namespace remains `[JINPA][TRADE]`, `[JINPA][TSL]`, `[JINPA][EXIT]`, `[JINPA][SWING]`, `[JINPA][CORE]`, `[JINPA][CYCLE]`, and `[JINPA][SIDEWAY]`.
- EXIT path: `OnTradeTransaction()` → `TRADE_TRANSACTION_DEAL_ADD` → history selection → `DEAL_ENTRY_OUT/OUT_BY` → symbol/Magic/position-history ownership filter → one exit summary per closing deal.
- Pending placement/deletion and SL modification do not satisfy the closing-deal gate and cannot create false EXIT messages.
- Object cleanup is owner-scoped: manual/Info object names, `JINPA_STRUCT_` renderer families, and `JINPA_RADAR_` radar family remain separate.

## Validation baseline

- Compile: 0 errors, 0 warnings.
- BTCUSD H1, equity-risk 0.5%, approximately USD 10,000, leverage 1:100: BUY/SELL Market, BUY/SELL STOP, and BUY/SELL LIMIT accepted in Stage 2.8C; corrected LIMIT volumes were 0.02/0.03 rather than approximately 50 lots.
- Golden dataset `EURUSD_M1_QDM,H1,2026-07-01..2026-08-15`: INIT 1; SWING 88; CORE 38; CYCLE 9; SIDEWAY 6; 141 meaningful events excluding INIT; duplicate 0; warning 0; error 0.
- Renamed-artifact long-range smoke `EURUSD_M1_QDM,H1,2025-01-02..2026-08-15`: 894,884 available ticks, 3,744 generated bars, 63 MB, 782 meaningful events, duplicate 0, warning 0, error 0. The local isolated history set is smaller than the earlier reference, so this is a lifecycle/regression check rather than an exact event-count comparison.
- Stage 2.6 observed 31 successful ATR trailing modifications with zero TSL errors.
- Real-template validation recovered manual controls, InfoDisplay, renderer, and Market Radar without an EA restart or duplicate loop.
- Previous long-range reference: approximately 9,970 bars, 2,383,180 ticks, 99 MB, and 1,422 WATCH objects over 2025-01-02..2026-08-15. These are smoke references, not exact acceptance values.

## Known limitations

- Closing Visual Strategy Tester while ticks are still draining can emit teardown-only chart-object creation error `4001` after the tester's `close visual tester window` marker. No such error was present during normal runtime or template recovery; use the non-visual golden run for lifecycle/regression acceptance.

- Live-device Push has not been fully runtime validated.
- Notification queue dispatches one event per Engine update, so a burst may drain slowly.
- Push deduplication is session-local; there is no retry or persistence policy.
- Renderer has no historical pruning policy; owned objects grow over long history.
- Manual button geometry may retain its existing layout after chart resize until recreation.
- Market Radar is intentionally single-row/current-chart only.
- REGIME, PHASE, STRUCT/SETUP semantics beyond currently populated fields are not implemented.
- Unknown symbols deliberately use fallback Magic 109999; operators must assess collision risk before live migration.
- Pending margin returned by `OrderCalcMargin` is broker/account specific and may be zero until activation.

## Migration gate

Before a future live release, compile and repeat: identity/Magic initialization, manual UI inventory, Market/STOP/LIMIT execution, cancel/close/EXIT, TSL ownership, real-template recovery, WATCH golden baseline, and a long-range smoke test. Any semantic change must first be validated in JINPA_DEV and recorded here before porting.
