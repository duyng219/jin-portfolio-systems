# JINPA v3.2 LIVE — Unified Runtime Candidate

> Phase P5.1 candidate only. The architecture compiles, but v3.2 has not
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
- Comment resolution is independent of `ShowWatchPanel`; hiding Radar does not
  disable the WATCH semantic snapshot.
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

Final runtime contract:

- LIVE: production panel and Comment; external push according to Inputs when
  not running in Strategy Tester.
- TEST: TEST panel and WATCH-aware Comment; primarily intended for Strategy
  Tester/DEMO, with warning-only admission elsewhere; external notification
  forced off regardless of account type.
- Shared: WATCH, execution, risk, DD, trailing and notification policy/queue.

> MT5 Expert Advisor hỗ trợ giao dịch thủ công
> One-click order entry + ATR-based risk management

Version: 3.2 LIVE candidate | Platform: MetaTrader 5

Migration status: Phase P5.1 warning-only TEST environment admission and the
Phase P5 runtime notification gate are implemented. LIVE parity, TEST execution
safety and external delivery suppression are statically audited; terminal
runtime validation remains pending. Credentials remain runtime-only.

---

## Cách dùng

1. Attach `JINPA_v3.2_LIVE.ex5` lên chart
2. Bật **AutoTrading** trong MT5
3. 10 buttons xuất hiện góc trên-trái chart
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
| **Cancel Buy Order** | Hủy pending buy order đang chờ |
| **Cancel Sell Order** | Hủy pending sell order đang chờ |
| **Close Buy** | Đóng buy position đầu tiên |
| **Close Sell** | Đóng sell position đầu tiên |

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
JINPA/
├── jinpa-manual.mq5              # EA chính
├── _core/
│   ├── framework_manager.mqh     # Hub include tất cả modules
│   ├── managers/
│   │   ├── risk_manager.mqh      # Tính lot size (5 phương pháp)
│   │   ├── position_manager.mqh  # SL/TP, Trailing Stop by ATR
│   │   ├── trade_executor.mqh    # Gửi orders tới MT5
│   │   ├── drawdown_manager.mqh  # Theo dõi drawdown ngày/tháng
│   │   ├── bar_manager.mqh       # OHLCV data
│   │   ├── indicators_manager.mqh # ATR, MA wrappers
│   │   └── time_manager.mqh      # Kiểm tra giờ giao dịch
│   └── infrastructure/
│       ├── ui_manager.mqh        # 10 buttons trên chart
│       ├── order_executor.mqh    # Bridge UI → trade logic
│       ├── info_display.mqh      # Hiển thị stats trên chart
│       └── position_helper.mqh   # Static helpers (count, avg high/low)
└── configs/
    ├── symbols.json
    └── hotkeys.json
```

---

## Tài liệu kỹ thuật

Xem `SPEC_JINPA-SYSTEM.md` để hiểu chi tiết luồng xử lý, các class và công thức tính toán.



Trong JINPA_v2.mq5 là version mới của manual trading của tôi khác là sử dụng bảng panel để vào lệnh, tôi muốn thêm chức năng khi gửi lệnh thì tự động gán các  comment vào lệnh , bạn có thể tạo 1 thư mục mới để đưa những file code liên quan đến panel vào và đổi tên cho 2 file .mq5 cho tách bạch giúp tôi version 1 và version 2           
tôi có danh sách các comment theo từng vị thế vào lệnh như: 
bres-pma
 bres-pmb 
 bres-pmb-st 
 revs-ppf 
 revs-pps 
 revs-pmr
  revs-pfb 
  
  _0 : vào lệnh đúng setup (lợi thế rr giảm khi xác suất đúng) 
  _1 : vào lệnh sớm hơn setup (lợi thế rr cao hơn khi xác suất đúng) 
  _bias : khi backtest vào lệnh bị trễ nên tua lại để vào đúng setup dẫn đến bias xem trước tương lai (nhưng vẫn muốn đúng các setup trong các điều kiện môi trường thị trường) 
  VD: 
  revs-ppf_0 
  revs-ppf_1
