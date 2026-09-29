# JINPA v3.2 LIVE — Unified Runtime Candidate

> Phase P6 final static-audit candidate. The architecture compiles, but v3.2 has not
> completed runtime/replay validation and is not yet the production baseline.

## Phase P2 architecture

- Base: frozen `JINPA_v3.1_LIVE` production source.
- First input: `RuntimeMode` (`JINPA_MODE_LIVE` or `JINPA_MODE_TEST`).
- `CRuntimePanelHost` owns mode-specific UI lifecycle. P2 retained the existing
  LIVE panel and left the TEST panel as the explicit Phase P3 extension point.
- `CManualTradeController` is the single manual open/cancel/close authority.
  The LIVE panel still builds setup/suffix/custom Comment and passes it
  unchanged to the controller.
- WATCH remains mode-independent. Notification behavior is unchanged in P2;
  the external runtime gate is deferred to Phase P5.
- The P2 controller API accepts caller-owned Comments for the Phase P3 resolver.
- Auto Trade and Trade Arrow remain deferred.

## Phase P3 TEST mode

- TEST mode now creates a dedicated `CTestPanel` with ten manual controls:
  six entry buttons plus side-wide cancel and close actions.
- Every TEST action uses the same `CManualTradeController` as LIVE. The legacy
  DEV `COrderExecutor` and DEV runtime infrastructure are not imported.
- Entry Comments are resolved at click time by `CTestCommentResolver`. It reads
  a read-only WATCH snapshot, accepts direction-compatible WATCH/READY/ACTIVE
  setup context, applies only lightweight existing-context fallbacks, and uses
  `test-none` when no defensible label exists.
- Comment resolution is independent of Radar presentation; collapsing Radar
  does not disable the WATCH semantic snapshot.
- TEST manual entries respect the shared daily-DD halt. WATCH, shared managers
  and trailing continue through the common runtime lifecycle.
- Phase P3 intentionally left RuntimeMode external suppression for Phase P5.
- Orders remain click-only. Auto Trade and Trade Arrow are absent.

## Phase P4/P5.1 unified runtime boundary

- TEST mode is intended primarily for Strategy Tester or DEMO. Account type
  does not block initialization; REAL, CONTEST and nonstandard environments
  produce one startup warning before manual execution remains available.
- Environment identity uses `MQL_TESTER` first, then the authoritative
  `ACCOUNT_TRADE_MODE`; no server or account-name inference is used.
- LIVE mode remains unrestricted by account type; its existing terminal/EA
  trading checks remain authoritative.
- LIVE and TEST intentionally differ at the UI and Comment-policy boundary.
  Both converge on one `CManualTradeController`, shared risk/position managers,
  one `CTrade`, shared Magic filtering and the same WATCH runtime.
- Entry is blocked by the shared daily-DD halt in both modes; cancel/close stays
  available and trailing remains a mode-independent main-runtime service.
- Notification policy/queue/retry behavior remains shared. P5 owns the final
  external transport permission described below.

## Phase P5 notification boundary

- External delivery is allowed only for `JINPA_MODE_LIVE` outside Strategy
  Tester. LIVE then follows the existing Telegram/MT5 Inputs and fallback.
- TEST always returns terminal `RUNTIME_MODE_SUPPRESSED` at the router before
  Telegram `WebRequest` or MT5 `SendNotification` can be called.
- LIVE in Strategy Tester retains the distinct terminal result
  `TESTER_SUPPRESSED`. TEST mode has precedence when both conditions apply.
- Policy observation, eligibility, same-bar suppression, session dedup, FIFO,
  queue sizing and retry machinery still run identically in both modes.
  Suppressed queue heads are consumed without retry or retry-count changes.
- TEST never sends a startup notification. Telegram keeps its own defensive
  Strategy Tester guard as a second layer.

## Phase P6 unified architecture invariant

- LIVE and TEST differ only at the panel, Comment-policy, visual identity and
  external-notification permission boundaries.
- Both panels submit `SManualTradeRequest` to one `CManualTradeController`,
  which owns all manual market/pending placement, side-wide cancellation and
  side-wide position closure through the shared `CTrade` instance.
- Risk, position management, daily-DD, trailing, WATCH engines, six canonical
  setups, arbitration, renderers, Radar and notification policy/queue remain
  shared and mode-independent.
- The legacy `framework_manager`, `CUIManager`, `COrderExecutor` and
  `CTradeExecutor` sources remain physically present but are not reachable from
  the v3.2 main include graph and have no runtime authority.
- Static production parity is clean. Terminal, replay and real-transport
  validation remain pending and are not claimed by this audit.

## Phase P7A TEST interaction correction

- On a normal chart, each namespaced TEST button is dispatched directly from
  `CHARTEVENT_OBJECT_CLICK`; execution no longer waits for the next tick to
  observe a transient button state.
- Visual Strategy Tester retains button-state polling because its chart-event
  contract differs from a normal terminal chart. Both sources converge on the
  same TEST dispatcher, Comment resolver and `CManualTradeController`.
- The dispatcher clears button state before invoking the shared controller, so
  one handled interaction produces at most one manual request.
- TEST execution diagnostics identify the click source and the existing shared
  controller reports symbol plus `CTrade` retcode/description. This is a
  static/compile correction; broker-side runtime execution is not claimed.

## Phase P7B collapsible WATCH Radar

- WATCH Radar is always present and no longer has a user-facing visibility
  input. The only UI control is `JINPA_RADAR_TOGGLE`; `-` collapses the body and
  `+` expands it. No close/X control exists.
- The existing WATCH identity is consolidated as `v1.1`. The compact header is
  `JINPA Watch v1.1`, `Update: HH:MM`, and `-/+` on one row.
- LIVE starts collapsed; TEST starts expanded. Both use the existing
  bottom-right anchor with scaled 5 px reference margins, so expansion grows
  leftward/upward and remains inside the chart.
- Collapse is presentation-only: the eight-column body is hidden without
  clearing its objects or `SymbolState`; Price Structure, Market State, Market
  Structure, Pullback, Range Edge, PMA, arbitration, resolver snapshots and
  notification processing continue identically.
- The current toggle state survives chart resize and object recovery during the
  EA session. A fresh attach/reinitialization returns to the mode default.
- Runtime visual validation remains pending and is not claimed here.

Final runtime contract:

- LIVE: production panel and Comment; external push according to Inputs when
  not running in Strategy Tester.
- TEST: TEST panel and WATCH-aware Comment; primarily intended for Strategy
  Tester/DEMO, with warning-only admission elsewhere; external notification
  forced off regardless of account type.
- Shared: WATCH, execution, risk, DD, trailing and notification policy/queue.

Future development invariant:

- `JINPA_v3.2_LIVE` is the canonical production architecture.
- A future `JINPA_v3.2_DEV` must derive from the same WATCH, execution, risk,
  position, DD, trailing, setup and shared notification-policy implementations.
- R&D UI, external-push defaults/suppression and future consumers such as Auto
  Trade may differ. Auto Trade must consume the existing signal boundary and
  shared execution/risk stack; it must not fork those implementations.

> MT5 Expert Advisor hỗ trợ giao dịch thủ công
> One-click order entry + ATR-based risk management

Version: 3.2 LIVE candidate | Platform: MetaTrader 5

Migration status: Phase P6 final static architecture and production-parity
audit is complete. LIVE parity, TEST execution safety and external delivery
suppression are statically audited; terminal/replay/real-transport validation
remains pending. Credentials remain runtime-only.

---

## Cách dùng

1. Attach `JINPA_v3.2_LIVE.ex5` lên chart
2. Bật **AutoTrading** trong MT5
3. LIVE hiển thị production panel; TEST hiển thị 10 nút manual ở góc trên-trái
4. Click button để đặt/hủy/đóng lệnh

---

## Buttons

| Button | Hành động |
|--------|-----------|
| **Buy** | Market buy tại Ask, SL tính theo ATR |
| **Sell** | Market sell tại Bid, SL tính theo ATR |
| **Buy Stop** | Pending buy stop tại Ask + ATR |
| **Sell Stop** | Pending sell stop tại Bid − ATR |
| **Buy Limit** | Pending buy limit tại Ask − ATR |
| **Sell Limit** | Pending sell limit tại Bid + ATR |
| **Cancel Buy Order** | Hủy tất cả Buy-side pending orders khớp Symbol + Magic |
| **Cancel Sell Order** | Hủy tất cả Sell-side pending orders khớp Symbol + Magic |
| **Close Buy** | Đóng tất cả Buy positions khớp Symbol + Magic |
| **Close Sell** | Đóng tất cả Sell positions khớp Symbol + Magic |

---

## Input Parameters

### Basic Settings
| Parameter | Default | Mô tả |
|-----------|---------|-------|
| Magic Number | 1010 | ID định danh lệnh của EA |
| SL Points | 0 | Stop loss cố định (0 = dùng ATR) |
| PO Expiration | 360 phút | Thời gian hết hạn pending order |
| Max Daily Drawdown | 0% | Ngưỡng dừng giao dịch (0 = tắt) |

### Risk Management
| Parameter | Default | Mô tả |
|-----------|---------|-------|
| Money Management | Equity Risk % | Phương pháp tính lot |
| Risk Percent | 0.5% | % equity rủi ro mỗi lệnh |
| Fixed Volume | 0.01 | Lot cố định (khi dùng Fixed MM) |
| Min Lot Per Equity | 500 | USD/lot (khi dùng Per Equity MM) |

### ATR Settings
| Parameter | Default | Mô tả |
|-----------|---------|-------|
| ATR Period | 14 | Chu kỳ ATR |
| ATR Factor SL | 2.2 | Hệ số nhân ATR cho Stop Loss |
| ATR Factor TSL | 2.5 | Hệ số nhân ATR cho Trailing Stop |
| ATR Factor PO | 2.5 | Hệ số nhân ATR cho Pending Order |

---

## Info Display (góc trên-phải chart)

```
Account Balance: 10000.00$ | Risk: 0.20%
Max Drawdown Daily: -0.50%
Max Drawdown Monthly: -1.20%
Spread: 12 points
Open Buy: 1
Open Sell: 0
```

---

## Cấu trúc Files

```
JINPA_v3.2_LIVE/
├── JINPA_v3.2_LIVE.mq5          # Main lifecycle and shared services
├── runtime/                     # RuntimeMode, panel host, TEST UI/Comment
├── trade/ManualTradeController.mqh
├── _panel/panel_main.mqh        # Production LIVE UI/Comment policy
├── _core/                       # Shared risk, DD, position, indicators/info
├── watch/                       # Shared WATCH/setup/render/notification stack
└── configs/
```

Legacy framework/UI/order-executor files under `_core` are retained source
artifacts only. They are not included by `JINPA_v3.2_LIVE.mq5` or its active
include graph.

---

## Tài liệu kỹ thuật

Xem `SPEC_JINPA-SYSTEM.md` để hiểu chi tiết luồng xử lý, các class và công thức tính toán.
