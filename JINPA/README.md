# JINPA - Manual Trading System

> **Hệ thống Hỗ trợ Giao dịch Thủ công**  
> Price Action + UI Tools + Risk Management

Version: 1.0.0 | Part of JINLABS

---

## Giới thiệu

JINPA là hệ thống hỗ trợ giao dịch thủ công dựa trên Price Action, giúp:

✅ Entry/Exit nhanh với hotkeys  
✅ Vẽ levels và quản lý orders  
✅ Tính risk tự động  
✅ Log trades để review

---

## Quick Start

### Sử dụng cơ bản

```
1. Attach jinpa-manual.mq5 lên chart
2. UI panel sẽ hiện bên phải chart
3. Dùng buttons hoặc hotkeys để trade
```

### Hotkeys mặc định

| Phím | Chức năng |
|------|-----------|
| `Ctrl+B` | Buy market |
| `Ctrl+S` | Sell market |
| `Ctrl+L` | Draw horizontal line |
| `Ctrl+R` | Calculate risk |
| `F1` | Show hotkey help |

Tùy chỉnh: xem `configs/hotkeys.json`

---

## Tính năng

### 1. Quick Order Entry
- Đặt lệnh nhanh với hotkeys
- Auto-calculate lot size theo risk%
- One-click SL/TP placement

### 2. Drawing Tools
- Vẽ S/R levels
- Mark entry zones
- Price action annotations

### 3. Risk Calculator
- Input: SL distance (pips)
- Output: Lot size cho risk% cố định
- Hiển thị ngay trên UI

### 4. Position Management
- View open positions
- Modify SL/TP
- Close partial/full
- Break-even trigger

---

#include "managers/indicators_manager.mqh";
#include "managers/trade_executor.mqh";
#include "managers/position_manager.mqh";
#include "managers/time_manager.mqh"
#include "managers/bar_manager.mqh"
#include "managers/risk_manager.mqh"

## Cấu trúc Files

```
JINPA/
├── jinpa-manual.mq5          # EA chính
├── ui_components.mqh     # UI components
│
├── _core/                    # Core logic
│   ├── managers/
│   │   ├── account_manager.mqh
│   │   ├── risk_manager.mqh
│   │   ├── position_manager.mqh
│   │   ├── indicators_manager.mqh
│   │   ├── bar_manager.mqh
│   │   ├── time_manager.mqh
│   │   └── trade_executor.mqh
│   └── infrastructure/
│       ├── ui_base.mqh
│       └── utils.mqh
│
├── configs/
│   ├── symbols.json         # Symbol settings
│   └── hotkeys.json         # Hotkey mappings
│
└── logs/                     # Trade logs
```

---

## Configuration

### symbols.json
```json
{
  "EURUSD": {
    "risk_pct": 0.02,
    "min_sl_pips": 10,
    "max_sl_pips": 100
  }
}
```

### hotkeys.json
```json
{
  "buy_market": "Ctrl+B",
  "sell_market": "Ctrl+S",
  "draw_line": "Ctrl+L",
  "close_all": "Ctrl+X"
}
```

---

## Workflow Giao dịch

### Setup Phase
```
1. Phân tích chart (PA, S/R, patterns)
2. Mark levels với drawing tools
3. Xác định entry zone
```

### Execution Phase
```
1. Price vào zone → Press hotkey (Ctrl+B/S)
2. JINPA tự động:
   - Calculate lot size
   - Place order với SL/TP
   - Log trade
```

### Management Phase
```
1. Monitor position trên UI panel
2. Modify SL/TP nếu cần
3. Close theo plan
```

---

## Risk Management

### Cài đặt mặc định
- Risk per trade: **2%** của equity
- Min SL: **10 pips**
- Max SL: **100 pips**
- Max positions: **3**

### Tính toán Lot Size
```
Formula:
Lot Size = (Equity × Risk%) / (SL_Pips × PipValue)

Ví dụ:
Equity: $10,000
Risk: 2% = $200
SL: 20 pips
PipValue: $10 (1 lot EURUSD)

→ Lot Size = $200 / (20 × $10) = 1.0 lot
```

---

## Logging

### Trade Logs
```
logs/trades_YYYY-MM.csv

Columns:
- Timestamp
- Symbol
- Side (Buy/Sell)
- Entry
- SL/TP
- Exit
- P&L
- Notes (manual input)
```

### Review Logs
```
1. Export CSV từ logs/
2. Analyze trong Excel/Python
3. Identify patterns
4. Improve discipline
```

---

## UI Components

### Main Panel (Bên phải chart)
```
┌─────────────────┐
│ JINPA v1.0.0   │
├─────────────────┤
│ [BUY]  [SELL]  │
│ [CLOSE ALL]    │
│                │
│ Risk: 2.0%     │
│ SL: 20 pips    │
│ Size: 1.0 lot  │
│                │
│ Open: 2        │
│ P&L: +$45.20   │
└─────────────────┘
```

### Drawing Toolbar (Trên chart)
```
[Line] [Rect] [Text] [Clear]
```

---

## Best Practices

### ✅ DO:
- Phân tích kỹ trước khi vào lệnh
- Stick to plan (SL/TP đã định)
- Log notes sau mỗi trade
- Review logs cuối tuần
- Respect max daily loss

### ❌ DON'T:
- Vào lệnh impulse
- Move SL xa hơn plan
- Revenge trade sau loss
- Over-trade (>5 trades/day)
- Ignore risk limits

---

## Troubleshooting

### UI không hiện
```
→ Check chart size (minimum 1200×800)
→ Restart EA
→ Check Expert Advisors enabled
```

### Hotkeys không work
```
→ Check hotkeys.json format
→ Verify no conflict với MT5 hotkeys
→ Restart MetaTrader
```

### Risk calculator sai
```
→ Check symbols.json pip value
→ Verify account currency
→ Check broker commission settings
```

---

## Updates & Changelog

### v1.0.0 (Current)
- ✅ Basic UI components
- ✅ Hotkey system
- ✅ Risk calculator
- ✅ Position management
- ✅ Trade logging

### Planned (v1.1.0)
- 🔜 Templates cho setups
- 🔜 Price alerts
- 🔜 Session statistics
- 🔜 Mobile notifications

Chi tiết: xem `CHANGELOG.md`

---

## Tài liệu Thêm

- `SPEC_JINPA-SYSTEM.md` - Chi tiết kỹ thuật
- `../ARCHITECTURE.md` - Kiến trúc tổng thể
- `CLAUDE.md` - Hướng dẫn cho AI Agent

---

## Support

- Author: JIN / DuyQuant
- Issues: Report qua Git repo
- Questions: Xem ARCHITECTURE.md

---

**License**: Private | **Version**: 1.0.0 | **Platform**: MT5
