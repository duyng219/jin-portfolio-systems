# JINLABS

> **Portfolio Hệ thống Giao dịch**  
> Thủ công (JINPA) + Tự động (JINQA)  
> By DuyQuant

Version: 2.1.0 | Platform: MetaTrader 5

---

## Giới thiệu

JINLABS gồm 2 hệ thống độc lập là JINPA (Hỗ trợ giao dịch thủ công với Price Action) và JINQA (Giao dịch tự động theo thuật toán)

---

## Quick Start

### JINPA (Thủ công)
```
1. Mở: JINLABS/JINPA/jinpa-manual.mq5
2. Compile và attach lên chart
3. Dùng UI để trade
```

### JINQA (Tự động)
```
1. Chọn strategy: JINQA/MR/stra101-mr-revs/
2. Compile stra101-mr-revs.mq5
3. Backtest hoặc live trade
```

---

## Cấu trúc

```
JINLABS/
├── JINPA/              # Hệ thống thủ công
│   ├── _core/         # Core riêng
│   └── jinpa-manual.mq5
│
└── JINQA/              # Hệ thống tự động
    ├── _core/         # Core riêng
    ├── MR/            # Mean Reversion
    ├── MO/            # Momentum
    └── TF/            # Trend Following
```

---

## Tài liệu

| File | Mô tả |
|------|-------|
| `ARCHITECTURE.md` | Kiến trúc chi tiết |
| `JINPA/README.md` | Hướng dẫn JINPA |
| `JINQA/README.md` | Hướng dẫn JINQA |

---

## Cài đặt

1. Copy folder `JINLABS/` vào: `MQL5/Experts/`
2. Refresh MetaEditor (Ctrl+R)
3. Compile EA cần dùng

---

## Logs & Analytics

```
JINQA/logs/          # Trade logs, errors
JINQA/analytics/     # Performance reports
```

---

## Support

- Author: DuyQuant
- Issues: Tạo issue trong Git repo
- Docs: Xem `ARCHITECTURE.md`

---

**License**: Private | **Version**: 2.1.0
