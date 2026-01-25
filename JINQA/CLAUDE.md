# CLAUDE.md - JINQA System

> Hướng dẫn cho AI Agent khi làm việc với JINQA
> Algorithmic Trading System - Portfolio chiến lược tự động

Version: 1.0.0 | System: JINQA | Updated: 2026-01-23

---

## Vai trò của AI Agent

Bạn là coding assistant chuyên về MQL5, giúp implement và maintain JINQA Algorithmic Trading System với 3 subsystems: MR, MO, TF.

---

## Context hiện tại

```
JINQA/
├── _core/              # Core logic độc lập
│   ├── managers/      # Business logic
│   ├── infrastructure/ # Logger, utils
│   └── interfaces/    # Contracts
│
├── _shared/           # Reserved (chưa dùng)
│
├── MR/                # Mean Reversion
│   └── stra101-mr-revs/
│
├── MO/                # Momentum
│   └── stra201-mo-bres/
│
├── TF/                # Trend Following
│   └── stra301-tf-pull/
│
├── configs/           # Configs
├── analytics/         # Reports
└── logs/             # Logs
```

QUAN TRỌNG:
- JINQA và JINPA hoàn toàn độc lập
- MR/MO/TF subsystems độc lập với nhau
- Mỗi subsystem có logic riêng, KHÔNG share regime detector

---

## Quy tắc Cơ bản

### 1. Include Paths
```mql5
// ĐÚNG - Full path từ JINLABS
#include <JINLABS/JINQA/_core/managers/risk_manager.mqh>
#include <JINLABS/JINQA/_core/interfaces/ISetup.mqh>
#include <JINLABS/JINQA/MR/stra101-mr-revs/setups/revs_pfb.mqh>

// SAI - Relative path
#include "../_core/risk_manager.mqh"

// SAI - Include từ JINPA
#include <JINLABS/JINPA/_core/managers/risk_manager.mqh>
```

### 2. Naming Conventions

Strategy Numbering:
```
100-199: MR (Mean Reversion)
200-299: MO (Momentum)
300-399: TF (Trend Following)
```

Files:
```
EA file:    stra101-mr-revs.mq5     (dấu gạch ngang)
Include:    stra101_mr_revs.mqh     (dấu gạch dưới)
Setup:      revs_pfb.mqh            (package_setupid)
```

Code:
```mql5
// Classes: PascalCase
class CStrategy101 { };
class CRevsPFB { };

// Functions: PascalCase
void OnTick();
bool CheckEntry();

// Variables: camelCase
double riskAmount;
string strategyId;

// Constants: UPPER_SNAKE_CASE
#define MAX_HEAT 0.018
```

### 3. Include Guards

File .mq5 (EA) - FULL HEADER:
```mql5
//+------------------------------------------------------------------+
//|                                              stra101-mr-revs.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "0.1.0"
#property description "Mean Reversion Strategy - Reversals"
#property description ""
#property description "Exploits false breakouts and rejection patterns in ranging markets. Setups: revs_pfb (false breaks), revs_pmr (marginal rejections)"
#property strict
```

File .mqh (Include) - MINIMAL HEADER:
```mql5
//+------------------------------------------------------------------+
//|                   revs_pfb.mqh - Reversal from False Break Setup |
//+------------------------------------------------------------------+
#property strict

#ifndef JINQA_REVS_PFB_MQH
#define JINQA_REVS_PFB_MQH

// ... code ...

#endif
```

Lý do: File .mq5 hiển thị trong MT5 Navigator. File .mqh chỉ cần header ngắn + include guard.

---

## Khi User Yêu cầu

### Request: "Create new MR strategy"
Bạn làm:
1. Hỏi: Strategy ID? (stra10X)
2. Hỏi: Setups nào? (VD: revs_pfb, revs_pmr)
3. Tạo structure:
   ```
   MR/stra10X-mr-package/
   ├── README.md
   ├── SPEC_stra10X-mr-package.md
   ├── CHANGELOG_stra10X.md
   ├── stra10X-mr-package.mq5
   ├── stra10X_mr_package.mqh
   └── setups/
       ├── setup1.mqh
       └── _tests/
   ```
4. Implement theo pattern (xem bên dưới)
5. Update configs

### Request: "Implement setup revs_pfb"
Bạn làm:
1. Đọc SPEC (nếu có)
2. Hỏi: Entry conditions? Exit rules? Risk calc?
3. Tạo `setups/revs_pfb.mqh`
4. Implement interface `ISetup`:
   ```mql5
   - Initialize()
   - CheckEntry()
   - CalculateRisk()
   - ValidateContext()
   - GetSetupID()
   ```
5. Tạo unit test trong `_tests/`

### Request: "Add logger"
Bạn làm:
1. Implement `_core/infrastructure/logger.mqh`
2. Methods:
   - `LogTrade()` - Log mỗi trade
   - `LogError()` - Log errors
   - `LogPerformance()` - Daily summary
3. CSV format cho easy analysis
4. Path: `logs/trades/raw/`

---

## Code Patterns

### 1. EA File Pattern
```mql5
//+------------------------------------------------------------------+
//|                                              stra101-mr-revs.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "0.1.0"
#property description "Mean Reversion Strategy - Reversals"
#property description ""
#property description "Exploits false breakouts and rejection patterns in ranging markets. Setups: revs_pfb, revs_pmr"
#property strict

// Core includes
#include <JINLABS/JINQA/_core/managers/account_manager.mqh>
#include <JINLABS/JINQA/_core/managers/risk_manager.mqh>
#include <JINLABS/JINQA/_core/managers/position_manager.mqh>
#include <JINLABS/JINQA/_core/managers/trade_executor.mqh>
#include <JINLABS/JINQA/_core/infrastructure/logger.mqh>

// Strategy
#include <JINLABS/JINQA/MR/stra101-mr-revs/stra101_mr_revs.mqh>

// Globals
CAccountManager g_accountMgr;
CRiskManager g_riskMgr;
CPositionManager g_posMgr;
CTradeExecutor g_executor;
CLogger g_logger;
CStrategy101 g_strategy;

int OnInit() {
    // Initialize managers
    if(!g_accountMgr.Initialize()) return INIT_FAILED;
    if(!g_riskMgr.Initialize()) return INIT_FAILED;
    if(!g_posMgr.Initialize()) return INIT_FAILED;
    if(!g_executor.Initialize()) return INIT_FAILED;
    if(!g_logger.Initialize("logs/")) return INIT_FAILED;
    
    // Initialize strategy với dependency injection
    if(!g_strategy.Initialize(&g_accountMgr, &g_riskMgr, 
                               &g_posMgr, &g_executor, &g_logger)) {
        return INIT_FAILED;
    }
    
    Print("stra101-mr-revs v0.1.0 initialized");
    return INIT_SUCCEEDED;
}

void OnTick() {
    g_strategy.OnTick();
}

void OnDeinit(const int reason) {
    g_strategy.Deinitialize();
    g_logger.Close();
}
```

### 2. Strategy Orchestration Pattern
```mql5
//+------------------------------------------------------------------+
//|              stra101_mr_revs.mqh - Strategy Orchestration Module |
//+------------------------------------------------------------------+
#property strict

#ifndef JINQA_STRA101_MR_REVS_MQH
#define JINQA_STRA101_MR_REVS_MQH

#include <JINLABS/JINQA/_core/interfaces/IStrategy.mqh>
#include <JINLABS/JINQA/_core/interfaces/ISetup.mqh>

// Setups
#include <JINLABS/JINQA/MR/stra101-mr-revs/setups/revs_pfb.mqh>
#include <JINLABS/JINQA/MR/stra101-mr-revs/setups/revs_pmr.mqh>

class CStrategy101 : public IStrategy {
private:
    // Dependencies (injected)
    CAccountManager* m_accountMgr;
    CRiskManager* m_riskMgr;
    CPositionManager* m_posMgr;
    CTradeExecutor* m_executor;
    CLogger* m_logger;
    
    // Setups
    CRevsPFB m_setupPFB;
    CRevsPMR m_setupPMR;
    
    // State
    string m_strategyId;
    string m_version;
    
public:
    CStrategy101() : 
        m_strategyId("stra101-mr-revs"),
        m_version("v0.1.0") {}
    
    bool Initialize(...) {
        // Store dependencies
        m_accountMgr = accountMgr;
        // ... store others
        
        // Initialize setups
        if(!m_setupPFB.Initialize(m_strategyId, m_version, m_logger))
            return false;
        if(!m_setupPMR.Initialize(m_strategyId, m_version, m_logger))
            return false;
            
        return true;
    }
    
    void OnTick() override {
        // Global filters
        if(!CheckGlobalFilters()) return;
        
        // Regime check (MR-specific logic)
        if(!IsValidMRRegime()) return;
        
        // Check setups (priority order)
        if(m_setupPFB.CheckEntry()) {
            ExecuteSetup(&m_setupPFB);
            return;
        }
        
        if(m_setupPMR.CheckEntry()) {
            ExecuteSetup(&m_setupPMR);
            return;
        }
    }
    
    bool IsValidMRRegime() {
        // MR-specific regime logic
        // Check: Low volatility? Range structure? No trend?
        double atr14 = iATR(Symbol(), PERIOD_CURRENT, 14, 0);
        double atr50 = iATR(Symbol(), PERIOD_CURRENT, 50, 0);
        
        if(atr14 > atr50 * 1.5) return false; // Too volatile
        
        // More checks...
        return true;
    }
    
    void ExecuteSetup(ISetup* setup) {
        // Validate context
        if(!setup->ValidateContext()) return;
        
        // Calculate risk
        double riskUsd = setup->CalculateRisk();
        
        // Check risk limits
        if(!m_riskMgr->ValidateRisk(riskUsd)) return;
        
        // Execute
        int ticket = m_executor->OpenPosition(/* params */);
        
        // Log
        if(ticket > 0) {
            m_logger->LogTrade(m_strategyId, setup->GetSetupID(), 
                              m_version, /* other params */);
        }
    }
};

#endif
```

### 3. Setup Implementation Pattern
```mql5
//+------------------------------------------------------------------+
//|                   revs_pfb.mqh - Reversal from False Break Setup |
//+------------------------------------------------------------------+
#property strict

#ifndef JINQA_REVS_PFB_MQH
#define JINQA_REVS_PFB_MQH

#include <JINLABS/JINQA/_core/interfaces/ISetup.mqh>

class CRevsPFB : public ISetup {
private:
    string m_strategyId;
    string m_version;
    string m_setupId;
    CLogger* m_logger;
    
public:
    CRevsPFB() : m_setupId("revs-pfb") {}
    
    bool Initialize(string strategyId, string version, CLogger* logger) {
        m_strategyId = strategyId;
        m_version = version;
        m_logger = logger;
        return true;
    }
    
    bool CheckEntry() override {
        // Entry logic
        // 1. Check false break occurred
        // 2. Check immediate rejection
        // 3. Check volume spike
        // 4. Validate support/resistance level
        
        return false; // Implement logic
    }
    
    double CalculateRisk() override {
        // Risk calculation specific to setup
        // Example: Fixed $20 per trade
        return 20.0;
    }
    
    bool ValidateContext() override {
        // Context validation
        // Check: Spread OK? Time filter OK? Max positions?
        return true;
    }
    
    string GetSetupID() override {
        return m_setupId;
    }
};

#endif
```

### 4. Interface Definitions
```mql5
//+------------------------------------------------------------------+
//|                               IStrategy.mqh - Strategy Interface |
//+------------------------------------------------------------------+
#property strict

#ifndef JINQA_ISTRATEGY_MQH
#define JINQA_ISTRATEGY_MQH

class IStrategy {
public:
    virtual bool Initialize(...) = 0;
    virtual void OnTick() = 0;
    virtual void Deinitialize() = 0;
};

#endif
```

```mql5
//+------------------------------------------------------------------+
//|                                     ISetup.mqh - Setup Interface |
//+------------------------------------------------------------------+
#property strict

#ifndef JINQA_ISETUP_MQH
#define JINQA_ISETUP_MQH

class ISetup {
public:
    virtual bool Initialize(string strategyId, string version, CLogger* logger) = 0;
    virtual bool CheckEntry() = 0;
    virtual double CalculateRisk() = 0;
    virtual bool ValidateContext() = 0;
    virtual string GetSetupID() = 0;
};

#endif
```

---

## Điều TUYỆT ĐỐI TRÁNH

### KHÔNG BAO GIỜ:
1. Include code từ JINPA
2. Share code giữa MR/MO/TF (mỗi subsystem độc lập)
3. Tạo centralized regime detector (mỗi strategy tự detect)
4. Hardcode values (dùng configs)
5. Skip logging
6. Ignore risk limits
7. Code không test được

### LUÔN LUÔN:
1. Dependency injection
2. Implement interfaces đầy đủ
3. Log mọi trade
4. Validate inputs
5. Handle errors gracefully
6. Unit test cho setups
7. Update CHANGELOG

---

## Common Tasks

### Task: Add new Strategy
```
1. Quyết định subsystem (MR/MO/TF)
2. Pick strategy number (stra1XX/2XX/3XX)
3. Tạo folder: subsystem/straXXX-family-package/
4. Tạo files: .mq5, .mqh, setups/, docs
5. Implement theo patterns
6. Config: Add to risk_limits.json
7. Test: Backtest -> Forward test -> Live
```

### Task: Add new Setup
```
1. File: setups/setup_id.mqh
2. Implement ISetup interface
3. Entry logic trong CheckEntry()
4. Risk calc trong CalculateRisk()
5. Context validation
6. Unit test trong _tests/
7. Add to strategy orchestration
```

### Task: Update Config
```
1. Edit configs/environments/dev.json (development)
2. Edit configs/symbols.json (symbol settings)
3. Edit configs/risk_limits.json (risk rules)
4. Test với dev config trước
5. Sau đó update staging/production
```

---

## Logging Requirements

Mỗi trade PHẢI log đầy đủ:
```csv
StrategyID, SetupID, Version, Timestamp, Symbol, Side,
Entry, SL, Exit, RiskUSD, PnLUSD, R_Result,
SpreadFlag, SlippageFlag, Clean
```

Example:
```
stra101-mr-revs, revs-pfb, v0.1.0, 2025-01-23 10:30:00, EURUSD, BUY,
1.08500, 1.08300, 1.08900, 20.00, 38.50, 1.93,
false, false, true
```

Paths:
- Trades: `logs/trades/raw/stra101_trades_2025-01.csv`
- Performance: `logs/performance/daily/stra101_daily_2025-01.csv`
- Errors: `logs/errors/by_strategy/stra101_errors_2025-01.log`

---

## Checklist Implementation

### New Strategy Checklist
```
[ ] Folder structure created?
[ ] README.md filled?
[ ] SPEC_*.md written?
[ ] CHANGELOG_*.md created?
[ ] EA file (.mq5) done?
[ ] Orchestration (.mqh) done?
[ ] Setups implemented?
[ ] Unit tests written?
[ ] Config added?
[ ] Backtest passed?
[ ] Forward test OK?
```

### Code Review Checklist
```
[ ] Include paths correct?
[ ] Naming conventions followed?
[ ] Include guards present?
[ ] Comments adequate?
[ ] Error handling done?
[ ] Logging implemented?
[ ] Risk validation done?
[ ] Compile warnings = 0?
```

---

## Debug Tips

### Strategy không entry
```
Checklist:
[ ] Regime valid? (check IsValidRegime())
[ ] Global filters passed?
[ ] Setup CheckEntry() returning true?
[ ] Risk limits OK?
[ ] Position slots available?
[ ] Time filters passed?

Enable debug:
#define DEBUG_MODE
DebugLog("Regime check: " + (IsValidMRRegime() ? "PASS" : "FAIL"));
```

### Compile Errors
```
"Cannot open include"
-> Check full path: JINLABS/JINQA/...
-> Check file exists
-> Check spelling

"Undeclared identifier"
-> Check include order
-> Check interface implemented
-> Check namespace
```

### Runtime Errors
```
"Invalid ticket"
-> Check trade execution logic
-> Check broker response
-> Check lot size calculation

"Logger write failed"
-> Check folder permissions
-> Check disk space
-> Check file path
```

---

## Giao tiếp với User

### User nói chung chung
```
User: "Create MR strategy"
AI: "OK, tôi sẽ tạo strategy mới trong MR subsystem.
     - Strategy ID: stra102 (tiếp theo sau stra101)
     - Package name: mr-bounce (hoặc bạn muốn tên gì?)
     - Setups: bounce_psr (bounce from S/R)
     Bạn có muốn thêm setup nào nữa không?"
```

### Cần clarification
```
User: "Implement setup"
AI: "Setup nào bạn muốn implement?
     - Trong strategy nào? (stra101, stra201, ...)
     - Setup ID? (VD: revs_pfb)
     - Entry conditions? Exit rules?
     Hoặc bạn có SPEC file không?"
```

### Suggest improvements
```
User: "Strategy entry quá nhiều trades"
AI: "Có thể do:
     1. Regime filter quá lỏng
     2. Setup validation chưa strict
     3. Time filter chưa đủ
     
     Giải pháp:
     - Tighten IsValidMRRegime()
     - Add more ValidateContext() checks
     - Add cooldown period
     
     Bạn muốn tôi implement giải pháp nào?"
```

---

## Ví dụ Conversations

### Example 1: New Strategy
```
User: Create MO strategy for breakouts

AI: Tôi sẽ tạo strategy trong MO subsystem:
    
    Strategy: stra202-mo-vbres (Volume Breakout Reversals)
    Setups:
    - vbres_hvb: High Volume Breakouts
    - vbres_cvb: Climax Volume Breakouts
    
    Structure:
    MO/stra202-mo-vbres/
    ├── stra202-mo-vbres.mq5
    ├── stra202_mo_vbres.mqh
    └── setups/
        ├── vbres_hvb.mqh
        └── vbres_cvb.mqh
    
    Regime detection logic:
    - Volume > 1.5× average
    - Price breaking key level
    - Momentum confirmed
    
    OK để bắt đầu?

User: Yes, but also add third setup for fakeout

AI: Got it! Thêm setup thứ 3:
    - vbres_fbo: Fakeout Breakouts
    
    Total 3 setups. Bắt đầu implement...
```

### Example 2: Fix Performance
```
User: stra101 win rate giảm từ 64% xuống 52%

AI: Cần kiểm tra:
    1. Market regime thay đổi?
    2. Setup validation degraded?
    3. Spread/slippage increased?
    
    Action plan:
    1. Review logs/trades/raw/stra101_trades_*.csv
    2. Check recent losing trades patterns
    3. Compare với baseline snapshot
    4. Tighten entry conditions nếu cần
    
    Bạn có thể share logs gần đây không?
```

---

## Tài liệu Tham khảo

Khi cần thêm context:
- `README.md` - System overview
- `SPEC_JINQA-SYSTEM.md` - System specs
- `MR/SPEC_JINQA-MR-SUBSYS.md` - MR subsystem specs
- `stra101-mr-revs/SPEC_stra101-mr-revs.md` - Strategy specs
- `../ARCHITECTURE.md` - Kiến trúc tổng thể
- `CHANGELOG.md` - Version history

---

## Mục tiêu cuối cùng

JINQA là portfolio các chiến lược tự động:
- MR cho ranging markets
- MO cho breakout phases
- TF cho trending markets

Mỗi strategy phải:
- Backtest với edge rõ ràng (EV_R >0.3)
- Log đầy đủ để review
- Risk management chặt chẽ
- Code sạch, maintainable
- Independent operation

Code philosophy:
- Simple > Complex
- Explicit > Implicit
- Testable > Clever
- Maintainable > Optimal

---

Build great strategies!
