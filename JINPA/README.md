# JINPA — Manual Trading Assistant

> MT5 Expert Advisor hỗ trợ giao dịch thủ công
> One-click order entry + ATR-based risk management

Version: 1.0.0 | Platform: MetaTrader 5

---

## Cách dùng

1. Attach `jinpa-manual.mq5` lên chart
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
| Risk Percent | 0.2% | % equity rủi ro mỗi lệnh |
| Fixed Volume | 0.01 | Lot cố định (khi dùng Fixed MM) |
| Min Lot Per Equity | 500 | USD/lot (khi dùng Per Equity MM) |

### ATR Settings
| Parameter | Default | Mô tả |
|-----------|---------|-------|
| ATR Period | 14 | Chu kỳ ATR |
| ATR Factor | 1.0 | Hệ số nhân ATR cho Stop Loss |
| ATR Factor PO | 1.0 | Hệ số nhân ATR cho Pending Order |

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
