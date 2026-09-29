# JINPA Changelog

## v4.0 DEV baseline — Phase V4-FORK-01

- Forked from canonical `JINPA_v3.2_LIVE`.
- Version and product identity update only.
- Zero intended strategy or execution semantic change.
- Auto Trade is not implemented yet.

## v3.2 LIVE candidate — Phase P7C (Setup ACTIVE Arrows)

- Added one historical chart arrow when the final arbitrated WATCH output for
  one of the six canonical setups transitions into `ACTIVE`.
- BUY arrows point up below the authoritative activation closed bar; SELL
  arrows point down above it, using a small ATR-based visual offset.
- Arrow identity is deterministic by symbol, timeframe, activation bar, setup
  and direction. Continued `ACTIVE` bars do not create duplicates.
- Rendering is independent of WATCH collapse state, runtime mode and
  notification eligibility. It is visualization-only and adds no Auto Trade
  or manual-execution path.
- Arrows persist through later lifecycle changes during the current EA session
  and the renderer removes only its own `JINPA_SETUP_ARROW_` objects on
  teardown. Historical lifecycle replay is not invented on initialization.
- Runtime visual validation is not claimed.

## v3.2 LIVE candidate — Phase P7B (Collapsible WATCH Radar)

- Removed the legacy WATCH visibility input. Radar UI now always exists and
  exposes one namespaced `JINPA_RADAR_TOGGLE` control with `-`/`+`; there is no
  close control.
- Consolidated the existing WATCH `v1.1` identity into one UI version constant
  and standardized the single-row header as `JINPA Watch v1.1`,
  `Update: HH:MM`, and the presentation toggle.
- LIVE initializes collapsed and TEST initializes expanded. Both states remain
  anchored at the scaled bottom-right margin and user choice survives chart
  resize and object recovery for the current EA session.
- Collapse hides only Radar body objects. WATCH engines, semantic state,
  resolver snapshots, setup arbitration and notification processing continue
  unchanged; expanding restores the existing eight-column table.
- Normal charts toggle from `CHARTEVENT_OBJECT_CLICK`; Visual Strategy Tester
  retains a state-poll fallback. Runtime visual validation is not claimed.

## v3.2 LIVE candidate — Phase P7A (Normal-chart TEST Interaction)

- Fixed the TEST panel's normal-chart execution path: namespaced
  `CHARTEVENT_OBJECT_CLICK` events now dispatch immediately instead of waiting
  for a transient pressed state to be observed by a later market tick.
- Retained button-state polling only for Visual Strategy Tester compatibility;
  both paths converge on one dispatcher, reset button state before execution
  and submit at most one shared-controller request per handled interaction.
- Added concise click-source and shared `CTrade` result diagnostics, including
  symbol, retcode and retcode description. No credentials are logged.
- Preserved the approved compact TEST geometry, LIVE panel behavior, WATCH,
  notification suppression, DD rules and the no-Auto-Trade firewall.
- Compile/static validation is recorded by the P7A report; broker-side normal
  chart and Strategy Tester interaction remain runtime validation items.

## v3.2 LIVE candidate — Phase P6 (Final Static Architecture Audit)

- PASS: LIVE and TEST differ only at panel, Comment policy, visual identity and
  external-notification permission boundaries; execution and strategy services
  converge on the shared production architecture.
- PASS: all reachable manual market/pending, cancel and close paths converge on
  `CManualTradeController`; the only other reachable `OrderSend` is the existing
  `CPositionManager` trailing `TRADE_ACTION_SLTP` modification.
- PASS: core managers/configs and all WATCH engines, setup engines, arbitration,
  renderers and Radar retain v3.1 LIVE parity. The TEST resolver is read-only.
- Classified legacy framework/UI/order-executor sources as physically retained
  but unreachable from the active include graph.
- Recorded the future DEV invariant: R&D consumers may differ, but WATCH,
  execution, risk, position, DD, trailing, setup and notification policy must
  not fork from the canonical LIVE architecture.
- No production/parity blocker was found. Runtime, replay and real-transport
  validation remain pending; Auto Trade and Trade Arrow remain absent.

## v3.2 LIVE candidate — Phase P5.1 (Relax TEST Environment Gate)

- Replaced the TEST account-type hard admission gate with environment
  identification and a single startup warning for REAL, CONTEST or unknown
  normal-chart environments.
- Strategy Tester remains the preferred environment identity regardless of the
  connected account trade mode; DEMO remains warning-free.
- TEST panel, shared manual execution, WATCH, risk, DD and trailing now remain
  available regardless of account classification.
- Preserved the Phase P5 authority: TEST always forces external notifications
  off before Telegram, MT5 Push, fallback or external retry.
- LIVE runtime admission and behavior remain unchanged. Auto Trade and Trade
  Arrow remain absent.

## v3.2 LIVE candidate — Phase P5 (Runtime Notification Gate)

- Added router-owned RuntimeMode external permission with explicit terminal
  `RUNTIME_MODE_SUPPRESSED`, distinct from `TESTER_SUPPRESSED`.
- TEST now reaches the shared policy, suppression, dedup and FIFO pipeline but
  cannot call Telegram `WebRequest`, MT5 `SendNotification` or fallback.
- Runtime/tester-suppressed queue heads are consumed without retry increments,
  retained heads or retry warnings.
- Startup external delivery now requires LIVE mode outside Strategy Tester.
- Added sanitized `ExternalPush` startup status and one TEST suppression notice.
- Preserved Telegram's defensive Strategy Tester guard and all existing LIVE
  transport, fallback, HTTP classification and reliability behavior.
- Auto Trade and Trade Arrow remain absent.

## v3.2 LIVE candidate — Phase P4 (Unified Safety Gate)

- Introduced authoritative RuntimeMode environment identification at the start
  of `OnInit`. Its original account-type admission restriction was superseded
  by the Phase P5.1 warning-only policy above.
- Added sanitized startup environment identity: REAL, DEMO, CONTEST,
  STRATEGY_TESTER or UNKNOWN.
- Audited the unified boundary: separate UI/Comment policies converge on the
  shared manual controller, risk/position managers, CTrade and Magic filtering.
- Confirmed shared DD, trailing, WATCH/setup/renderers and notification policy
  lifecycle. Final external notification permission remains pending Phase P5.
- Auto Trade and Trade Arrow remain absent.

## v3.2 LIVE candidate — Phase P3 (TEST Panel + Comment Resolver)

- Added the namespaced `CTestPanel` with the DEV-style ten-button interaction
  surface, chart-resize/object-recovery support and TEST-only cleanup.
- Routed all six TEST entries and all four cancel/close actions through the
  shared production-safe `CManualTradeController`; the DEV executor was not
  copied or imported.
- Added `CTestCommentResolver` and a minimal read-only WATCH setup snapshot.
  Current direction-compatible WATCH/READY/ACTIVE setup context is preferred;
  lightweight existing-context fallbacks end at `test-none`.
- TEST pending-order Comments are fixed at creation time. Cancel/close actions
  do not resolve or create Comments.
- Preserved the LIVE panel path and LIVE Comment taxonomy unchanged.
- RuntimeMode notification suppression remains pending Phase P5. Auto Trade
  and Trade Arrow remain absent.

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
  legacy Radar visibility behavior.
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
- The former Radar visibility option remains presentation-only; WATCH core
  continues while its UI is hidden.
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
