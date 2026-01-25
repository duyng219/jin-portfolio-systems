# CLAUDE.md - JINPA System

> Hướng dẫn cho AI Agent khi làm việc với JINPA
> Manual Trading System - Hỗ trợ giao dịch thủ công với Price Action

Version: 1.0.0 | System: JINPA | Updated: 2026-01-23

---

## Vai trò của AI Agent

Bạn là coding assistant chuyên về MQL5, giúp implement và maintain JINPA Manual Trading System.

---

## Context hiện tại

```
JINPA/
├── _core/              # Core logic độc lập
│   ├── managers/      # Business logic
│   └── infrastructure/ # UI, utils
│
├── jinpa-manual.mq5   # EA chính
├── ui_components.mqh  # UI components
├── configs/           # Configs
└── logs/             # Logs
```

QUAN TRỌNG: JINPA và JINQA hoàn toàn độc lập. KHÔNG share code giữa hai hệ thống.

---

## Quy tắc Cơ bản

### 1. Include Paths
```mql5
// ĐÚNG - Full path từ JINLABS
#include <JINLABS/JINPA/_core/managers/risk_manager.mqh>

// SAI - Relative path
#include "../_core/risk_manager.mqh"

// SAI - Include từ JINQA
#include <JINLABS/JINQA/_core/managers/risk_manager.mqh>
```

### 2. Naming Conventions
```mql5
// Classes: PascalCase
class CRiskManager { };

// Functions: PascalCase
void CalculateRisk();

// Variables: camelCase
double riskAmount;

// Constants: UPPER_SNAKE_CASE
#define MAX_RISK_PCT 0.02
```

### 3. File Headers

File .mq5 (EA) - FULL HEADER:
```mql5
//+------------------------------------------------------------------+
//|                                                 jinpa-manual.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "1.0.0"
#property description "JINPA - Manual Trading Assistant"
#property description ""
#property description "Price Action based manual trading system with: Quick order entry via hotkeys. Automatic risk calculator. Position management UI"
#property strict
```

File .mqh (Include) - MINIMAL HEADER:
```mql5
//+------------------------------------------------------------------+
//|                        risk_manager.mqh - Risk Management Module |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_RISK_MANAGER_MQH
#define JINPA_RISK_MANAGER_MQH

// ... code ...

#endif
```

Lý do: File .mq5 hiển thị trong MT5 Navigator với description. File .mqh chỉ cần header ngắn + include guard.

---

## Khi User Yêu cầu

### Request: "Implement risk manager"
Bạn làm:
1. Đọc `SPEC_JINPA-SYSTEM.md` (nếu có)
2. Tạo `_core/managers/risk_manager.mqh`
3. Implement các functions cơ bản:
   - `Initialize()`
   - `CalculatePositionSize()`
   - `ValidateRisk()`
4. Include guard đầy đủ
5. Comment rõ ràng
6. Test example

### Request: "Add buy hotkey"
Bạn làm:
1. Kiểm tra `configs/hotkeys.json`
2. Update `ui_components.mqh`
3. Add event handler trong `jinpa-manual.mq5`
4. Test flow: Hotkey -> Handler -> Execution

### Request: "Fix compile error"
Bạn làm:
1. Đọc error message
2. Check include paths
3. Check syntax
4. Fix và explain

---

## Cấu trúc Code Pattern

### EA File (jinpa-manual.mq5)
```mql5
//+------------------------------------------------------------------+
//|                                                 jinpa-manual.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "1.0.0"
#property description "JINPA - Manual Trading Assistant"
#property description ""
#property description "Price Action based manual trading with hotkeys and risk management"
#property strict

// Includes
#include <JINLABS/JINPA/_core/managers/account_manager.mqh>
#include <JINLABS/JINPA/_core/managers/risk_manager.mqh>
#include <JINLABS/JINPA/ui_components.mqh>

// Globals
CAccountManager g_accountMgr;
CRiskManager g_riskMgr;
CUIManager g_uiMgr;

// Event handlers
int OnInit() {
    if(!g_accountMgr.Initialize()) return INIT_FAILED;
    if(!g_riskMgr.Initialize()) return INIT_FAILED;
    if(!g_uiMgr.Initialize()) return INIT_FAILED;
    return INIT_SUCCEEDED;
}

void OnTick() {
    g_uiMgr.Update();
}

void OnDeinit(const int reason) {
    g_uiMgr.Destroy();
}

void OnChartEvent(...) {
    g_uiMgr.HandleEvent(...);
}
```

### Manager Class Pattern
```mql5
//+------------------------------------------------------------------+
//|                        risk_manager.mqh - Risk Management Module |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_RISK_MANAGER_MQH
#define JINPA_RISK_MANAGER_MQH

class CRiskManager {
private:
    double m_riskPct;
    double m_maxRiskPct;
    
public:
    CRiskManager() : m_riskPct(0.02), m_maxRiskPct(0.05) {}
    
    bool Initialize() {
        // Load config
        // Validate
        return true;
    }
    
    double CalculatePositionSize(string symbol, double slPips) {
        // Implementation
        return 0.0;
    }
};

#endif
```

---

## Điều TUYỆT ĐỐI TRÁNH

### KHÔNG BAO GIỜ:
1. Include code từ JINQA
2. Dùng relative paths
3. Hardcode values (dùng config)
4. Skip include guards
5. Code không có comments
6. Ignore compile warnings
7. Mix JINPA và JINQA logic

### LUÔN LUÔN:
1. Dùng full include paths
2. Add include guards
3. Comment mỗi function
4. Validate inputs
5. Handle errors
6. Test trước khi commit
7. Update CHANGELOG khi thay đổi

---

## Common Tasks

### Task: Tạo Manager mới
```
1. File: _core/managers/new_manager.mqh
2. Include guard: JINPA_NEW_MANAGER_MQH
3. Class: CNewManager
4. Methods: Initialize(), Core logic
5. Include trong EA file
6. Test
```

### Task: Add UI Button
```
1. Define button properties trong ui_components.mqh
2. Create button trong OnInit
3. Handle click trong OnChartEvent
4. Trigger action qua managers
5. Test visual và logic
```

### Task: Read Config
```
1. Check configs/symbols.json hoặc hotkeys.json
2. Parse JSON
3. Validate values
4. Apply trong manager
5. Log errors nếu có
```

---

## Checklist Trước Khi Code

```
[ ] Đã đọc SPEC (nếu có)?
[ ] Biết file nào cần edit?
[ ] Include paths đúng?
[ ] Naming conventions đúng?
[ ] Include guards có đủ?
[ ] Comments có rõ?
[ ] Có handle errors?
[ ] Có test được không?
```

---

## Debug Tips

### Compile Error
```
Error: Cannot open include file
-> Check path: JINLABS/JINPA/_core/...
-> Check file tồn tại
-> Check spelling

Error: Undeclared identifier
-> Check include order
-> Check class/function defined
```

### Runtime Error
```
EA không khởi động
-> Check OnInit() return value
-> Check Print() outputs
-> Check Experts log

UI không hiện
-> Check chart size
-> Check ObjectCreate() returns
-> Check z-order
```

---

## Giao tiếp với User

### Khi User hỏi chung chung
```
"Implement risk manager"
-> Bạn hỏi: "Bạn muốn risk manager có những features gì?"
-> Hoặc: "Tôi sẽ implement basic risk manager với calculate position size. OK không?"
```

### Khi có nhiều cách làm
```
"Add hotkey"
-> Bạn giải thích: "Có 2 cách: (1) OnChartEvent, (2) Timer polling. Nên dùng (1)."
-> Implement cách tốt nhất
```

### Khi cần thông tin thêm
```
"Fix bug"
-> Bạn hỏi: "Bug ở đâu? Compile error hay runtime? Error message là gì?"
```

---

## Tài liệu Tham khảo

Khi cần thêm context:
- `README.md` - Overview
- `SPEC_JINPA-SYSTEM.md` - Chi tiết specs
- `CHANGELOG.md` - Lịch sử thay đổi
- `../ARCHITECTURE.md` - Kiến trúc tổng thể

---

## Ví dụ Conversation

User: Implement risk calculator trong JINPA

AI: Tôi sẽ tạo `_core/managers/risk_manager.mqh` với các functions:
- `CalculatePositionSize()` - Tính lot size dựa trên SL và risk%
- `ValidateRisk()` - Kiểm tra risk limits
- `GetMaxPositionSize()` - Lấy max lot allowed

Formula: `Lots = (Equity × RiskPct) / (SL_Pips × PipValue)`

Bạn có muốn thêm feature nào không?

---

User: Yes, add max daily loss limit

AI: OK, tôi sẽ thêm:
- `m_maxDailyLoss` variable
- `CheckDailyLoss()` function
- `ResetDailyCounter()` at day change

Config sẽ đọc từ `configs/symbols.json`:
```json
{
  "risk_settings": {
    "risk_per_trade_pct": 0.02,
    "max_daily_loss_pct": 0.05
  }
}
```

---

## Mục tiêu cuối cùng

JINPA là hệ thống giúp trader thủ công:
- Entry/Exit nhanh với hotkeys
- Tính risk tự động
- Quản lý positions dễ dàng
- Log trades để review

Code phải:
- Sạch, dễ đọc
- Modularity tốt
- Dễ maintain
- Performant

---

Happy coding!
