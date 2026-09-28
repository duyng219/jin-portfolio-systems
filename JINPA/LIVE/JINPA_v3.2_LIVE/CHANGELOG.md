# JINPA Changelog

## v3.2 LIVE candidate — Phase P2 (Runtime Mode Core)

- Started the unified runtime architecture from the frozen v3.1 LIVE source.
- Added the explicit `JINPA_RUNTIME_MODE` input contract with LIVE and TEST.
- Added `CRuntimePanelHost`; LIVE retains `CJINPAPanel`, while TEST remains a
  safe panel-free placeholder pending Phase P3.
- Added the shared `CManualTradeController` for all six manual entry types,
  side-wide pending cancellation and side-wide position closure.
- Routed the LIVE panel through the shared controller while retaining the
  existing setup/suffix/custom Comment construction, DD halt, log and CSV UI.
- Kept WATCH semantics and current notification behavior mode-independent.
- Deferred the TEST panel and `CTestCommentResolver` to Phase P3, the external
  notification runtime gate to Phase P5, and Auto Trade/Trade Arrow entirely.
- Candidate status only: v3.2 runtime validation is not claimed.

## v3.1 LIVE — Migration Phase M6 (Production Parity Audit)

- PASS: production `_core` matches v3.0 byte-for-byte; the panel differs only
  by the approved v3.1 caption and CSV filename prefix.
- PASS: WATCH, setup, arbitration, renderer and notification authority modules
  match frozen DEV byte-for-byte; merged integration preserves display-only
  `ShowWatchPanel` behavior.
- No parity defect or release blocker was found. M7 runtime/live transport
  validation remains pending; production release completion and long-term LIVE
  stability are not claimed.

## v3.1 LIVE — Migration Phase M5 (Final Main Integration Audit)

- Confirms the production main lifecycle, CAppDialog panel, manual execution,
  Comment path, risk/order/trailing behavior and trade transaction handling.
- Confirms the complete WATCH/notification integration, accepted input
  defaults, LIVE branding, panel caption and CSV prefix.
- M6 parity audit and M7 runtime/live transport validation remain pending;
  this audit does not claim long-term LIVE stability.

## v3.1 LIVE — Migration Phase M4 (Notification Stack)

- Replaces the legacy notification authority atomically with the frozen Phase
  5 six-setup and structure-event policy.
- Uses Telegram as primary transport and MT5 Push as fallback, with bounded
  FIFO retry/reliability and one direct startup notification per successful
  WATCH initialization.
- Suppresses real external transports in Strategy Tester while preserving the
  notification lifecycle; credentials remain runtime-only and sanitized.
- Runtime/live transport validation remains pending M7. Auto Trade, Trade
  Arrow, panel execution and manual Comment behavior remain unchanged.

## v3.1 LIVE — Migration Phase M3 (Setup + Renderer + Radar Output)

- Migrates frozen `revs-ppf`, `revs-pps`, `bres-pmb`, `revs-pfb`,
  `revs-pmr` and `bres-pma` setup lifecycles.
- Activates the frozen Setup Output Arbitrator and final Radar SETUP/STATUS
  projection while preserving independent internal setup ownership.
- Activates confirmed Micro Base and Pullback Base renderers.
- Keeps setup evaluation closed-bar and observer-only; Auto Trade and Trade
  Arrow remain deferred.
- Keeps the legacy LIVE structure notification path temporarily unchanged;
  frozen notification policy, Telegram, router and reliability remain pending M4.

## v3.1 LIVE — Migration Phase M2 (WATCH Core)

- Created from the v3.0 LIVE production tree; the frozen DEV main/UI/executor
  was not used as the release base.
- Preserves the production CAppDialog panel, manual execution, trade Comment,
  risk/order/trailing path, DD panel halt, trade log and transaction handlers.
- Migrates frozen WatcherTypes, Market State, Market Structure, Radar and
  Structure renderer while retaining Price Structure already identical to DEV.
- Changes confirmed-swing defaults from `5/5` to `3/3`.
- Sets ATR defaults to period `14`, SL `2.2`, TSL `2.5`, PO `2.5`.
- `ShowWatchPanel` remains Radar-only; WATCH core continues while hidden.
- Setup engines/renderers and the frozen notification transport/reliability
  stack remain pending for M3/M4.

## v3.0 LIVE — Corrective Stage 2 release

- Built from the frozen v2.5 production base.
- Preserves the v2.5 LIVE panel, trade-comment workflow, execution, risk, Magic, Daily DD and CSV schema.
- Transplants the validated Stage 2 Structure, renderer semantics and seven notification groups from v3.1 DEV.
- Status: frozen production; Stage 3 development is prohibited in this tree.
- Known limitations: generation ordinals are session/history-relative; notification dedup is session-local with no persistence or retry; renderer object pruning is deferred.

## v2.4

- Tach rieng `ATRFactorSL` va `ATRFactorTSL`.
- Giu cau hinh hien tai: `ATRFactorSL = 2.5`, `ATRFactorTSL = 3.5`, `TSLStepATR = 2.5` va `TSLMode = TSL_STEP`.
- Nang metadata, panel title va ten file export CSV len JINPA v2.4.
