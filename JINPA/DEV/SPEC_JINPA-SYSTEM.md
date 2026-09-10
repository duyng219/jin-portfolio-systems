# SPEC — JINPA System

> Tài liệu kỹ thuật: kiến trúc, luồng xử lý, các class và công thức

---

## 1. Kiến trúc tổng thể

```
jinpa-manual.mq5
│
├── Global objects
│   ├── CTrade trade              ← MT5 built-in trade object
│   ├── CRM RM                   ← Risk / lot sizing
│   ├── CPM PM                   ← Position manager (SL/TP/TSL)
│   ├── CTradeExecutor Trade     ← Gửi orders tới broker
│   ├── CBar Bar                 ← OHLCV bar data
│   ├── CiATR ATR                ← ATR indicator
│   ├── CiMA MA                  ← MA indicator
│   ├── CUIManager uiManager     ← 10 buttons trên chart
│   ├── CDrawdownManager         ← Track drawdown ngày/tháng
│   ├── COrderExecutor           ← Bridge UI buttons → orders
│   └── CInfoDisplay             ← Stats display
│
└── _core/framework_manager.mqh  ← include tất cả managers + infra
```

---

## 2. Luồng xử lý OnTick

```
OnTick()
│
├── 1. Refresh ATR, MA values
│
├── 2. Refresh Bar data (6 bars), lấy Ask/Bid
│
├── 3. DrawdownManager.UpdateDaily() + UpdateMonthly()
│   └── Nếu dailyDD >= MaxDrawdownDaily → return (halt)
│
├── 4. Đếm open buy/sell positions
│
├── 5. InfoDisplay.UpdateDisplay() + UpdateButtonTooltips()
│
├── 6. OrderExecutor.HandleAllOrders(ask, bid, atr, ...)
│   ├── Mỗi button được poll qua uiManager.XxxPressed()
│   ├── Nếu pressed → tính SL → tính volume → gửi order
│   └── Reset button state
│
└── 7. PM.TrailingStopLossByATR() — cập nhật TSL tất cả positions
```

---

## 3. Các Class & Trách nhiệm

### CRM — Risk Manager (`risk_manager.mqh`)

Tính lot size theo 5 phương pháp:

| Enum | Công thức |
|------|-----------|
| `MM_MIN_LOT_SIZE` | `SYMBOL_VOLUME_MIN` |
| `MM_MIN_LOT_PER_EQUITY` | `Equity / Steps × VolMin` |
| `MM_FIXED_LOT_SIZE` | `FixedVolume` |
| `MM_FIXED_LOT_PER_EQUITY` | `Equity / Steps × FixedVolume` |
| `MM_EQUITY_RISK_PERCENT` | Xem công thức bên dưới |

**Công thức MM_EQUITY_RISK_PERCENT:**
```
maxRisk      = RiskPercent% × Equity
riskPerPoint = maxRisk / (SL_distance / Point)
lots         = riskPerPoint / TickValue
```

Sau khi tính xong: `VerifyVolume()` clamp vào [min, max] và round theo step. `VerifyMargin()` kiểm tra free margin.

---

### CPM — Position Manager (`position_manager.mqh`)

**CalculateStopLossByATR(symbol, "BUY"/"SELL", atrValue, atrFactor)**
```
BUY  → SL = Ask − (atrValue × atrFactor)
SELL → SL = Bid + (atrValue × atrFactor)
```

**TrailingStopLossByATR(symbol, magic, atrValue, atrFactor)**
```
Duyệt tất cả positions theo symbol + magic:
BUY  → newSL = Bid − atrDistance
       Cập nhật nếu newSL > currentSL (chỉ kéo lên)
SELL → newSL = Ask + atrDistance
       Cập nhật nếu newSL < currentSL (chỉ kéo xuống)
```

---

### CTradeExecutor — Trade Executor (`trade_executor.mqh`)

Wrapper gửi orders tới MT5, handle cả market và pending:

| Method | Order Type |
|--------|-----------|
| `Buy()` | `ORDER_TYPE_BUY` (market) |
| `Sell()` | `ORDER_TYPE_SELL` (market) |
| `BuyStop()` | `ORDER_TYPE_BUY_STOP` (pending) |
| `SellStop()` | `ORDER_TYPE_SELL_STOP` (pending) |
| `BuyLimit()` | `ORDER_TYPE_BUY_LIMIT` (pending) |
| `SellLimit()` | `ORDER_TYPE_SELL_LIMIT` (pending) |
| `Delete(ticket)` | Hủy pending order |
| `ModifyPosition()` | Sửa SL/TP position |

Pending orders dùng `ORDER_TIME_SPECIFIED` với expiration từ input `POExpirationMinutes`.

Hàm hỗ trợ: `AdjustAboveStopLevel()` / `AdjustBelowStopLevel()` — đảm bảo SL không vi phạm broker stops level.

---

### COrderExecutor — Order Executor (`order_executor.mqh`)

Bridge giữa UI buttons và trade logic. `HandleAllOrders()` poll 10 button states mỗi tick:

```
BuyPressed      → tính SL (ATR hoặc fixed points) → HandleBuyMarket()
SellPressed     → tính SL → HandleSellMarket()
BuyStopped      → HandleBuyStop()   : price = Ask + ATR
SellStopped     → HandleSellStop()  : price = Bid − ATR
BuyLimited      → HandleBuyLimit()  : price = Ask − ATR
SellLimited     → HandleSellLimit() : price = Bid + ATR
BuyCancelled    → GetPendingTicket() → Delete()
SellCancelled   → GetPendingTicket() → Delete()
BuyClosed       → loop positions → PositionClose(first buy)
SellClosed      → loop positions → PositionClose(first sell)
```

**SL khi dùng slPoints > 0 (manual points):**
```
BUY  → SL = max(avgLow3bars + slPoints×Point, Ask − slPoints×Point)
SELL → SL = min(avgHigh3bars − slPoints×Point, Bid + slPoints×Point)
```

---

### CUIManager — UI Manager (`ui_manager.mqh`)

Tạo và quản lý 10 `CButton` objects trên chart. Layout dựa trên % kích thước chart:

```
BUY group (x = 3% chart_width):        SELL group (x = 10% chart_width):
  [Buy]          y = 10%                 [Sell]
  [Buy Stop]     y = 10% + 1×btnH        [Sell Stop]
  [Buy Limit]    y = 10% + 2×btnH        [Sell Limit]
  [Cancel Buy]   y = 10% + 2.85×btnH     [Cancel Sell]
  [Close Buy]    y = 10% + 3.75×btnH     [Close Sell]
```

Auto-recreate buttons khi chart bị resize (`CHARTEVENT_CHART_CHANGE`) hoặc button bị xóa (`CHARTEVENT_OBJECT_DELETE`).

---

### CDrawdownManager — Drawdown Manager (`drawdown_manager.mqh`)

Theo dõi equity cao nhất / thấp nhất trong ngày và tháng:

```
DrawdownPercent = (minEquity − maxEquity) / maxEquity × 100
```

Reset daily: khi `hour==0 && min==0` (đầu ngày mới).
Reset monthly: khi tháng thay đổi.

---

### CInfoDisplay — Info Display (`info_display.mqh`)

Tạo 6 `OBJ_LABEL` objects góc trên-phải chart. Gọi mỗi tick qua `UpdateDisplay()`. Update tooltip các buttons qua `UpdateButtonTooltips()`.

---

### CPositionHelper — Position Helper (`position_helper.mqh`)

Static class, không cần khởi tạo:

| Method | Mô tả |
|--------|-------|
| `CountBuyPositions(symbol)` | Đếm buy positions của symbol |
| `CountSellPositions(symbol)` | Đếm sell positions của symbol |
| `GetAverageHigh(n=3)` | Trung bình high của n bars gần nhất |
| `GetAverageLow(n=3)` | Trung bình low của n bars gần nhất |

---

## 4. Luồng khởi tạo OnInit

```
OnInit()
├── Trade.SetMagicNumber()
├── Kiểm tra TERMINAL_TRADE_ALLOWED + MQL_TRADE_ALLOWED
├── SymbolSelect(_Symbol)
├── uiManager.Initialize()  → CreateAllButtons()
├── MA.Init()               → handle error → INIT_FAILED
├── ATR.Init()              → handle error → INIT_FAILED
└── orderExecutor.Initialize(tất cả params)
```

---

## 5. Known Issues (cần fix)

| # | Vấn đề | Vị trí |
|---|--------|--------|
| 1 | Include dùng relative path `../managers/...` | `order_executor.mqh:10-14` |
| 2 | `HandleCancelBuyOrder` và `HandleCancelSellOrder` logic giống hệt nhau — không phân biệt order type | `order_executor.mqh:289-307` |
| 3 | `UpdateDisplay()` gọi `ObjectCreate()` mỗi tick → in error liên tục khi object đã tồn tại | `info_display.mqh:44` |
| 4 | Drawdown reset điều kiện `min==0` có thể reset nhiều lần trong phút đầu ngày | `drawdown_manager.mqh:59` |
