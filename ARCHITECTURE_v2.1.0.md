# JINLABS — System Architecture Documentation
“Định nghĩa thuật ngữ chuẩn dùng trong toàn bộ hệ: xem std-glossary.md.”

> **Tài liệu tổng quan về kiến trúc hệ thống JINLABS**
>
> Version: 2.1.0
> Last Updated: 2026-01-25  
> Author: DuyQuant  

---
## Mục lục
1. [Tổng quan Hệ thống](#1-tổng-quan-hệ-thống)  
2. [Cấu trúc Thư mục Chi tiết](#2-cấu-trúc-thư-mục-chi-tiết)  
3. [Quy ước Đặt tên](#3-quy-ước-đặt-tên)  
4. [Include Files & Dependencies](#4-include-files--dependencies)  
5. [Git Repository Setup](#5-git-repository-setup)  
6. [Development Workflow](#6-development-workflow)  
7. [Best Practices](#7-best-practices)  
8. [Troubleshooting](#8-troubleshooting)  

---

## 1. Tổng quan Hệ thống

### 1.1 Triết lý thiết kế (non‑negotiable)
- **Portfolio of Trading Systems**: không có “holy grail”; mỗi system tối ưu cho một regime.
- **Cắt left-tail, mở right-tail**: rủi ro phải bị chặn bằng gate; lợi nhuận để chạy bằng quản trị lệnh thắng.
- **Tách lớp**: Strategy (tín hiệu) tách khỏi Execution (đặt lệnh), Risk (gate), Session (time gate), Logging (quan sát).
- **Độc lập subsystem**: MR/MO/TF hoạt động độc lập; hạn chế coupling để tránh “một lỗi kéo sập tất cả”.
- **Quan sát được**: mọi quyết định gate phải log (allowed/block + reason + số).

### 1.2 Phân cấp hệ thống
- **JINPA**: manual / price action assistant (UI/UX).
- **JINQA**: algorithmic systems (subsystems + strategy packages).
  - Subsystems: **MR (Mean Reversion)**, **MO (Momentum)**, **TF (Trend Following)**.
  - Mỗi strategy = 1 “package” (mq5 entry + orchestration mqh + setups/).

### 1.3 Luồng xử lý chuẩn (1 tick)
1) **Session gate** (đúng giờ giao dịch?)  
2) **Bar gate / throttle** (new bar, giảm spam tick)  
3) **Strategy** tạo signal  
4) **Position gate** (multi-position chỉ khi lệnh trước đã BE/profit-protected)  
5) **Risk gate** (SL-based exposure, tổng rủi ro <= cap)  
6) **Trade execution** (place/modify/close)  
7) **Logging** (snapshot + sự kiện + lỗi)

### 1.4 Cấu trúc Thư mục MQL5
```
MQL5/
└─ Experts/
   └─ JINLABS/
      │
      ├─ README.md                           # Project overview
      ├─ ARCHITECTURE.md                     # ★ Tài liệu này
      │
      ├─ JINPA/                              # ★ MANUAL TRADING SYSTEM
      │  ├─ README.md                        # JINPA overview
      │  ├─ SPEC_JINPA-SYSTEM.md            # SPEC cấp system
      │  ├─ CHANGELOG.md                     # Version history
      │  ├─ CLAUDE.md                        # ★ Cho AI Agent
      │  ├─ .gitignore                       # Git ignore rules
      │  │
      │  ├─ _core/                           # ★ Core riêng cho JINPA
      │  │  ├─ README.md
      │  │  │
      │  │  ├─ managers/
      │  │  │  ├─ account_manager.mqh
      │  │  │  ├─ bar_manager.mqh
      │  │  │  ├─ position_manager.mqh
      │  │  │  ├─ risk_manager.mqh
      │  │  │  ├─ time_manager.mqh
      │  │  │  └─ trade_executor.mqh
      │  │  │
      │  │  └─ infrastructure/
      │  │     ├─ ui_base.mqh
      │  │     └─ utils.mqh
      │  │
      │  ├─ jinpa-manual.mq5                 # EA chính
      │  ├─ ui_components.mqh
      │  │
      │  ├─ configs/
      │  │  ├─ symbols.json
      │  │  └─ hotkeys.json
      │  │
      │  └─ logs/
      │     └─ .gitkeep
      │
      └─ JINQA/                              # ★ ALGO TRADING SYSTEM
         ├─ README.md                        # JINQA overview
         ├─ SPEC_JINQA-SYSTEM.md            # SPEC cấp system
         ├─ CHANGELOG.md                     # System-wide version history
         ├─ CLAUDE.md                        # ★ Cho AI Agent
         ├─ .gitignore                       # Git ignore rules
         │
         ├─ _core/                           # ★ Core riêng cho JINQA
         │  ├─ README.md
         │  │
         │  ├─ managers/
         │  │  ├─ account_manager.mqh
         │  │  ├─ bar_manager.mqh
         │  │  ├─ position_manager.mqh
         │  │  ├─ risk_manager.mqh
         │  │  ├─ time_manager.mqh
         │  │  └─ trade_executor.mqh
         │  │
         │  ├─ infrastructure/
         │  │  ├─ logger.mqh
         │  │  ├─ ui_base.mqh
         │  │  └─ utils.mqh
         │  │
         │  └─ interfaces/                   # Định nghĩa contracts
         │     ├─ ISetup.mqh
         │     ├─ IStrategy.mqh
         │     └─ IRiskModel.mqh
         │
         ├─ _shared/                         # ★ Reserved (chưa dùng)
         │  └─ README.md                     # Giải thích mục đích
         │
         ├─ MR/                              # ★ Mean Reversion Subsystem
         │  ├─ README.md                     # MR subsystem overview
         │  ├─ SPEC_JINQA-MR-SUBSYS.md      # SPEC cấp subsystem
         │  ├─ CHANGELOG_MR-SUBSYS.md        # Subsystem version history
         │  │
         │  └─ stra101-mr-revs/              # Strategy package
         │     ├─ README.md
         │     ├─ SPEC_stra101-mr-revs.md   # Strategy SPEC
         │     ├─ CHANGELOG_stra101.md       # Strategy CHANGELOG
         │     │
         │     ├─ stra101-mr-revs.mq5       # EA file
         │     ├─ stra101_mr_revs.mqh       # Orchestration
         │     │
         │     └─ setups/
         │        ├─ revs_pfb.mqh           # Setup 1
         │        ├─ revs_pmr.mqh           # Setup 2
         │        └─ _tests/                # Unit tests
         │           ├─ test_revs_pfb.mqh
         │           └─ test_revs_pmr.mqh
         │
         ├─ MO/                              # ★ Momentum Subsystem
         │  ├─ README.md
         │  ├─ SPEC_JINQA-MO-SUBSYS.md
         │  ├─ CHANGELOG_MO-SUBSYS.md
         │  │
         │  └─ stra201-mo-bres/
         │     ├─ README.md
         │     ├─ SPEC_stra201-mo-bres.md
         │     ├─ CHANGELOG_stra201.md
         │     │
         │     ├─ stra201-mo-bres.mq5
         │     ├─ stra201_mo_bres.mqh
         │     │
         │     └─ setups/
         │        ├─ bres_pmb.mqh
         │        ├─ bres_pma.mqh
         │        └─ _tests/
         │
         ├─ TF/                              # ★ Trend Following Subsystem
         │  ├─ README.md
         │  ├─ SPEC_JINQA-TF-SUBSYS.md
         │  ├─ CHANGELOG_TF-SUBSYS.md
         │  │
         │  └─ stra301-tf-pull/
         │     ├─ README.md
         │     ├─ SPEC_stra301-tf-pull.md
         │     ├─ CHANGELOG_stra301.md
         │     │
         │     ├─ stra301-tf-pull.mq5
         │     ├─ stra301_tf_pull.mqh
         │     │
         │     └─ setups/
         │        ├─ pull_ppf.mqh
         │        ├─ pull_pps.mqh
         │        └─ _tests/
         │
         ├─ configs/                         # ★ JINQA configs
         │  ├─ environments/
         │  │  ├─ dev.json
         │  │  ├─ staging.json
         │  │  └─ production.json
         │  │
         │  ├─ symbols.json
         │  ├─ buckets.json
         │  └─ risk_limits.json
         │
         ├─ analytics/                       # ★ Analytics tập trung
         │  ├─ snapshots/
         │  │  ├─ by_strategy/
         │  │  │  ├─ stra101_v0.1.0_2025-01-15.yaml
         │  │  │  ├─ stra201_v0.1.0_2025-01-15.yaml
         │  │  │  └─ stra301_v0.1.0_2025-01-15.yaml
         │  │  └─ portfolio/
         │  │     └─ jinqa_portfolio_2025-01-15.yaml
         │  │
         │  ├─ backtest/
         │  │  ├─ stra101/
         │  │  ├─ stra201/
         │  │  └─ stra301/
         │  │
         │  └─ compare/
         │     ├─ mr_vs_mo_2024.html
         │     └─ subsystem_performance.html
         │
         └─ logs/                            # ★ JINQA logs
            ├─ trades/
            │  ├─ raw/
            │  │  ├─ stra101_trades_2025-01.csv
            │  │  ├─ stra201_trades_2025-01.csv
            │  │  └─ stra301_trades_2025-01.csv
            │  └─ unified/
            │     └─ jinqa_all_trades_2025-01.csv
            │
            ├─ performance/
            │  ├─ daily/
            │  │  ├─ stra101_daily_2025-01.csv
            │  │  ├─ stra201_daily_2025-01.csv
            │  │  ├─ stra301_daily_2025-01.csv
            │  │  └─ jinqa_portfolio_daily_2025-01.csv
            │  │
            │  └─ rolling/
            │     └─ jinqa_rolling_30d_2025-01.csv
            │
            └─ errors/
               ├─ by_strategy/
               │  ├─ stra101_errors_2025-01.log
               │  ├─ stra201_errors_2025-01.log
               │  └─ stra301_errors_2025-01.log
               └─ system_errors.log
```
---

## 2. Cấu trúc Thư mục Chi tiết
### 2.1 Root Level
```
JINLABS/
├─ README.md              # Giới thiệu project, quick start guide
└─ ARCHITECTURE.md        # Tài liệu này
```
### 2.2 JINPA/ (Manual Trading System)
```
JINPA/
├─ README.md                   # JINPA overview
├─ SPEC_JINPA-SYSTEM.md       # System specification
├─ CHANGELOG.md                # Version history
├─ CLAUDE.md                   # AI Agent instructions
├─ .gitignore                  # Git ignore rules
│
├─ _core/                      # ★ Core riêng cho JINPA
│  ├─ README.md
│  │
│  ├─ managers/
│  │  ├─ account_manager.mqh
│  │  ├─ bar_manager.mqh
│  │  ├─ position_manager.mqh
│  │  ├─ risk_manager.mqh
│  │  ├─ time_manager.mqh
│  │  └─ trade_executor.mqh
│  │
│  └─ infrastructure/
│     ├─ ui_base.mqh
│     └─ utils.mqh
│
├─ jinpa-manual.mq5            # EA chính
├─ ui_components.mqh           # UI components
│
├─ configs/
│  ├─ symbols.json
│  └─ hotkeys.json
│
└─ logs/
   └─ .gitkeep
```
### 2.3 JINQA/ (Algorithmic Trading System)
#### 2.3.1 JINQA Root
```
JINQA/
├─ README.md                   # JINQA overview
├─ SPEC_JINQA-SYSTEM.md       # System-level specification
├─ CHANGELOG.md                # System-wide version history
├─ CLAUDE.md                   # AI Agent instructions
└─ .gitignore                  # Git ignore rules
```
#### 2.3.2 JINQA/_core/ (Core riêng cho JINQA)
```
_core/
├─ README.md              # Documentation của core modules
│
├─ managers/              # Business logic managers
│  ├─ account_manager.mqh      # Quản lý thông tin account
│  ├─ bar_manager.mqh          # Quản lý bar data (OHLC)
│  ├─ position_manager.mqh     # Quản lý positions
│  ├─ risk_manager.mqh         # Tính toán rủi ro, sizing
│  ├─ time_manager.mqh         # Quản lý thời gian
│  └─ trade_executor.mqh       # Thực thi lệnh
│
├─ infrastructure/        # Hạ tầng hỗ trợ
│  ├─ logger.mqh               # Logging system
│  ├─ ui_base.mqh              # Base UI components
│  └─ utils.mqh                # Utility functions
│
└─ interfaces/            # Contract definitions
   ├─ ISetup.mqh               # Interface cho setup
   ├─ IStrategy.mqh            # Interface cho strategy
   └─ IRiskModel.mqh           # Interface cho risk model
```
#### 2.3.3 JINQA/_shared/ (Reserved)
```
_shared/
└─ README.md              # Giải thích mục đích folder
```
**Mô tả:**
- **Hiện tại chưa sử dụng**
- Dành cho logic dùng chung giữa subsystems trong tương lai
- Ví dụ: Nếu sau này cần shared regime detector, portfolio coordinator, v.v.

```markdown
# JINQA Shared Logic (Reserved)

This folder is reserved for future shared logic between subsystems.

Currently not in use. Each subsystem (MR/MO/TF) operates independently
with its own logic and rules.

Potential future use cases:
- Cross-subsystem regime detection
- Portfolio-level coordination
- Shared performance tracking
- Common validation rules

Do not add files here unless there is clear need for
shared logic across multiple subsystems.
```
#### 2.3.4 MR/ (Mean Reversion Subsystem)
```
MR/
├─ README.md                   # MR subsystem overview
├─ SPEC_JINQA-MR-SUBSYS.md    # Subsystem specification
├─ CHANGELOG_MR-SUBSYS.md     # Subsystem version history
│
└─ stra101-mr-revs/           # Strategy package folder
   ├─ README.md
   ├─ SPEC_stra101-mr-revs.md        # Strategy SPEC
   ├─ CHANGELOG_stra101.md            # Strategy CHANGELOG
   │
   ├─ stra101-mr-revs.mq5             # EA file (entry point)
   ├─ stra101_mr_revs.mqh             # Strategy orchestration
   │
   └─ setups/
      ├─ revs_pfb.mqh                 # Setup 1: False break reversal
      ├─ revs_pmr.mqh                 # Setup 2: Marginal rejection
      └─ _tests/                      # Unit tests
         ├─ test_revs_pfb.mqh
         └─ test_revs_pmr.mqh
```
**Đặc điểm:**
- **MR Subsystem** độc lập, tập trung vào mean reversion
- Có logic riêng để detect regime phù hợp
- Mỗi strategy package nằm trong folder riêng
- SPEC và CHANGELOG ở cả cấp subsystem và strategy

**File structure:**
- `.mq5`: EA file, attach lên chart
- `_mr_revs.mqh`: Strategy orchestration, điều phối setups
- `setups/*.mqh`: Implementation của từng setup
- `_tests/`: Unit tests
  
#### 2.3.5 MO/ (Momentum Subsystem)
```
MO/
├─ README.md
├─ SPEC_JINQA-MO-SUBSYS.md
├─ CHANGELOG_MO-SUBSYS.md
│
└─ stra201-mo-bres/
   ├─ README.md
   ├─ SPEC_stra201-mo-bres.md
   ├─ CHANGELOG_stra201.md
   │
   ├─ stra201-mo-bres.mq5
   ├─ stra201_mo_bres.mqh
   │
   └─ setups/
      ├─ bres_pmb.mqh            # Breakout from micro-base
      ├─ bres_pma.mqh            # Breakout from micro-accumulation
      └─ _tests/
```
**Đặc điểm:**
- **MO Subsystem** độc lập, tập trung vào momentum/breakout
- Có logic riêng để detect momentum regime
- Cấu trúc tương tự MR

#### 2.3.6 TF/ (Trend Following Subsystem)
```
TF/
├─ README.md
├─ SPEC_JINQA-TF-SUBSYS.md
├─ CHANGELOG_TF-SUBSYS.md
│
└─ stra301-tf-pull/
   ├─ README.md
   ├─ SPEC_stra301-tf-pull.md
   ├─ CHANGELOG_stra301.md
   │
   ├─ stra301-tf-pull.mq5
   ├─ stra301_tf_pull.mqh
   │
   └─ setups/
      ├─ pull_ppf.mqh            # Pullback - first leg
      ├─ pull_pps.mqh            # Pullback - second leg
      └─ _tests/
```
**Đặc điểm:**
- **TF Subsystem** độc lập, tập trung vào trend following
- Có logic riêng để detect trending regime
- Cấu trúc tương tự MR và MO

#### 2.3.7 configs/ (JINQA Configs)
```
configs/
├─ environments/               # Environment-specific configs
│  ├─ dev.json                # Development
│  ├─ staging.json            # Staging/forward testing
│  └─ production.json         # Live trading
│
├─ symbols.json               # Symbol settings
├─ buckets.json               # Symbol grouping
└─ risk_limits.json           # Risk limits
```
**symbols.json** - Cấu hình từng symbol:
```json
{
  "EURUSD": {
    "spread_median_points": 1.2,
    "commission_per_lot": 7.0,
    "bucket": "FX_MAJOR",
    "active": true,
    "min_volume": 0.01,
    "max_volume": 10.0,
    "trading_hours": "24/7"
  }
}
```

**risk_limits.json** - Giới hạn rủi ro:
```json
{
  "global": {
    "max_heat_pct": 0.018,
    "max_heat_hard_pct": 0.025,
    "risk_per_trade_pct": 0.002
  },
  "per_strategy": {
    "stra101": {
      "max_heat_pct": 0.006,
      "max_concurrent_trades": 3
    }
  }
}
```
**buckets.json** - Phân nhóm symbols:
```json
{
  "FX_MAJOR": ["EURUSD", "GBPUSD", "USDJPY"],
  "FX_MINOR": ["EURGBP", "EURJPY"],
  "METALS": ["XAUUSD", "XAGUSD"],
  "CRYPTO": ["BTCUSD", "ETHUSD"]
}
```
#### 2.3.8 analytics/ (Analytics & Reports)
```
analytics/
├─ snapshots/                  # Performance snapshots
│  ├─ by_strategy/
│  │  ├─ stra101_v0.1.0_2025-01-15.yaml
│  │  ├─ stra201_v0.1.0_2025-01-15.yaml
│  │  └─ stra301_v0.1.0_2025-01-15.yaml
│  └─ portfolio/
│     └─ jinqa_portfolio_2025-01-15.yaml
│
├─ backtest/                   # Backtest reports
│  ├─ stra101/
│  │  └─ report_2023_2024.html
│  ├─ stra201/
│  └─ stra301/
│
└─ compare/                    # Cross-strategy comparisons
   ├─ mr_vs_mo_2024.html
   └─ subsystem_performance.html
```
**Mô tả:**
- **snapshots/**: Performance snapshot theo version
- **backtest/**: HTML reports từ Strategy Tester
- **compare/**: So sánh cross-strategy/subsystem

#### 2.3.9 logs/ (Logging Output)
```
logs/
├─ trades/                     # Trade logs
│  ├─ raw/                    # Logs theo từng strategy
│  │  ├─ stra101_trades_2025-01.csv
│  │  ├─ stra201_trades_2025-01.csv
│  │  └─ stra301_trades_2025-01.csv
│  └─ unified/                # Logs gộp
│     └─ jinqa_all_trades_2025-01.csv
│
├─ performance/
│  ├─ daily/                  # Daily summaries
│  │  ├─ stra101_daily_2025-01.csv
│  │  ├─ stra201_daily_2025-01.csv
│  │  ├─ stra301_daily_2025-01.csv
│  │  └─ jinqa_portfolio_daily_2025-01.csv
│  │
│  └─ rolling/                # Rolling window stats
│     └─ jinqa_rolling_30d_2025-01.csv
│
└─ errors/                     # Error logs
   ├─ by_strategy/
   │  ├─ stra101_errors_2025-01.log
   │  ├─ stra201_errors_2025-01.log
   │  └─ stra301_errors_2025-01.log
   └─ system_errors.log
```
**Mô tả:**
- **trades/raw/**: CSV logs riêng từng strategy
- **trades/unified/**: Gộp tất cả strategies cho portfolio analysis
- **performance/**: Daily summaries và rolling statistics
- **errors/**: Error tracking theo strategy

---

## 3. Quy ước Đặt tên

### 3.1 Strategy numbering
```
100-199: Mean Reversion (MR)
200-299: Momentum (MO)
300-399: Trend Following (TF)
400-499: Reserved
```

### 3.2 Quy ước tên file/folder (ngắn gọn)
- EA file (gạch ngang): `stra<NNN>-<family>-<package>.mq5`
  - Ví dụ: `stra101-mr-revs.mq5`, `stra201-mo-bres.mq5`, `stra301-tf-pull.mq5`
- Orchestration include (gạch dưới): `stra<NNN>_<family>_<package>.mqh`
  - Ví dụ: `stra101_mr_revs.mqh`
- Setup file: `<package>_<setup_id>.mqh`
  - Ví dụ: `revs_pfb.mqh`, `bres_pmb.mqh`, `pull_ppf.mqh`
- Folder package: `stra<NNN>-<family>-<package>/`
- Log files (gợi ý):
  - Trades: `stra<NNN>_trades_YYYY-MM.csv`
  - Errors: `stra<NNN>_errors_YYYY-MM.log`

### 3.3 Quy ước setup id
- Setup id phải **ngắn, mô tả hành vi**, nhất quán trong package.
- Gợi ý pattern: `<family_prefix><2-3 chữ>` (ví dụ: `pfb`, `pmb`, `ppf`).
- Ví dụ:
  - revs_pfb    (reversal from false break)
  - revs_pmr    (reversal from marginal rejection)
  - bres_pmb    (breakout from micro-base)
  - bres_pma    (breakout from micro-accumulation)
  - pull_ppf    (pullback - first leg)
  - pull_pps    (pullback - second leg)

### 3.4 Quy ước biến/hàm

#### Class Names (PascalCase)
```mql5
class CAccountManager { };
class CRiskManager { };
class CRevsPFB { };
```

#### Function Names (PascalCase)
```mql5
void CalculateRisk();
bool CheckEntry();
double GetPositionSize();
```

#### Variable Names (camelCase hoặc snake_case)
```mql5
// camelCase (preferred)
double riskAmount;
string strategyId;
int totalTrades;

// snake_case (cho config/constants)
const string STRATEGY_ID = "stra101-mr-revs";
const double RISK_PER_TRADE = 0.002;
```

#### Constants (UPPER_SNAKE_CASE)
```mql5
#define MAX_HEAT 0.018
#define STRATEGY_VERSION "v0.1.0"
const int MAGIC_BASE = 101000;
```

---

## 4. Include Files & Dependencies

### 4.1 Include hierarchy (chuẩn)
#### JINPA Include Pattern
```
jinpa-manual.mq5
  └─> JINPA/_core/managers/*.mqh
       └─> JINPA/_core/infrastructure/*.mqh
```

#### JINQA Include Pattern
```
stra<NNN>-<family>-<package>.mq5
  └─> stra<NNN>_<family>_<package>.mqh
       ├─> setups/*.mqh
       │    └─> JINQA/_core/interfaces/*.mqh
       └─> JINQA/_core/managers/*.mqh
            ├─> JINQA/_core/infrastructure/*.mqh
            └─> JINQA/_core/interfaces/*.mqh
```

### 4.2 Quy tắc include (tối thiểu)
- JINPA và JINQA **không share core**.
- `_core/` phải **agnostic** (không biết strategy cụ thể).
- Tránh include vòng; ưu tiên interface + injection.
- Mọi dependency mới trong `_core/` = xem như “breaking risk” (test tất cả strategies).

### 4.3 Include Best Practices

```mql5
// 1. Dùng full path từ JINLABS root
#include <JINLABS/JINQA/_core/managers/risk_manager.mqh>
#include <JINLABS/JINPA/_core/managers/risk_manager.mqh>

// 2. Group includes theo category
// JINQA Core
#include <JINLABS/JINQA/_core/managers/account_manager.mqh>
#include <JINLABS/JINQA/_core/managers/risk_manager.mqh>

// Strategy specific
#include <JINLABS/JINQA/MR/stra101-mr-revs/stra101_mr_revs.mqh>

// 3. Include guards trong .mqh files
#ifndef JINQA_RISK_MANAGER_MQH
#define JINQA_RISK_MANAGER_MQH
// ... code ...
#endif

---

## 5. Git Repository Setup

### 5.1 .gitignore

```gitignore
# ============================================================
# JINLABS .gitignore
# ============================================================
# --- MetaTrader 5 compiled outputs ---
**/*.ex5
# --- MT5 runtime junk ---
**/Logs/
**/log/
**/logs/
**/Tester/
**/tester/
**/bases/
**/history/
**/ticks/
**/*.tmp
**/*.dat
**/*.hcc
**/*.hcd
**/*.log

# Tester artifacts
**/reports/
**/cache/

# Runtime exports
MQL5/Files/JINLABS/data/
MQL5/Files/JINLABS/logs/

# --- OS / IDE ---
.DS_Store
Thumbs.db
.vscode/
.idea/
*.swp
*.swo
*~

# --- Sensitive data ---
**/configs/environments/production.json
**/credentials.json
**/*secret*.json

# --- Build artifacts ---
**/build/
**/dist/

# --- Large files (optional) ---
# JINQA/analytics/backtest/*.html
# JINQA/analytics/snapshots/*.yaml

# --- Temporary files ---
**/*.bak
**/*.backup
**/temp/
**/tmp/

# --- Python (monitoring scripts) ---
__pycache__/
*.py[cod]
*$py.class
.Python
venv/
env/
.env

# --- Node.js (web dashboard) ---
node_modules/
npm-debug.log
yarn-error.log
```

### 5.2 Branch & version (tối giản)
- `main`: ổn định (deploy/forward/realtime)
- `dev`: phát triển
- `feature/<name>`: tính năng nhỏ
- Version: `MAJOR.MINOR.PATCH`
  - PATCH: sửa bug / refactor nhỏ
  - MINOR: thêm tính năng tương thích
  - MAJOR: breaking changes

```
main                    # Production-ready
  └─ dev                # Development
       ├─ feature/jinpa-ui-enhancement
       ├─ feature/jinqa-mr-101
       ├─ feature/jinqa-mo-201
       ├─ bugfix/logger-crash
       └─ refactor/risk-manager
```
**Workflow:**
1. Feature development: `dev` → `feature/xxx`
2. Testing complete: `feature/xxx` → `dev`
3. Release ready: `dev` → `main`
---

### 5.3 Commit message (ngắn, rõ)
Format: <type>(<scope>): <subject>

Types:
- `feat: New feature`
- `fix: Bug fix`
- `refactor: Code refactoring`
- `docs: Documentation`
- `test: Tests`
- `chore: Maintenance`

Examples:
feat(stra101): Add revs_pfb setup
fix(jinqa-logger): Fix CSV write error
refactor(jinpa-core): Reorganize managers folder
docs(architecture): Update to v2.0.0 - independent systems
test(stra201): Add unit tests for bres_pmb
chore(gitignore): Ignore production configs

---

## 6. Development Workflow

### 6.1 Typical Development Cycle
```
1. Planning
   └─ Write SPEC_*.md
   └─ Define interfaces (if needed)
   └─ Plan tests
2. Development
   └─ Create feature branch
   └─ Implement code
   └─ Write unit tests
   └─ Update CHANGELOG
3. Testing
   └─ Unit tests
   └─ Backtest on dev config
   └─ Forward test on staging
   └─ Review results
4. Deployment
   └─ Merge to dev
   └─ Test on demo account
   └─ Merge to main
   └─ Deploy to live
5. Monitoring
   └─ Track performance
   └─ Log analysis
   └─ Snapshot creation
   └─ Iterate
```

### 6.2 Thêm Strategy mới (JINQA)
**Step-by-step guide:**
```
1. Determine subsystem
   - MR, MO, or TF?
   - Check if subsystem exists, create if needed
2. Create strategy package folder
   JINQA/<SUBSYSTEM>/stra<NNN>-<family>-<package>/
3. Create files
   - README.md
   - SPEC_stra<NNN>-<family>-<package>.md
   - CHANGELOG_stra<NNN>.md
   - stra<NNN>-<family>-<package>.mq5
   - stra<NNN>_<family>_<package>.mqh
   - setups/<setup1>.mqh
   - setups/<setup2>.mqh
   - setups/_tests/
4. Write SPEC
   - Objective
   - Regime detection logic (specific to this strategy)
   - Setups description
   - Entry/Exit rules
   - Risk rules
   - Validation criteria
5. Implement code
   - Strategy orchestration with regime logic
   - Setup implementations
   - Use interfaces from JINQA/_core/interfaces/
6. Add to configs
   - Update symbols.json if needed
   - Add to risk_limits.json
7. Test
   - Unit tests for setups
   - Backtest
   - Forward test
8. Document
   - Update README.md
   - Update CHANGELOG
   - Create snapshot baseline
9. Deploy
   - Commit to feature branch
   - Merge to dev
   - Test on demo
   - Merge to main
```

### 6.3 Thêm subsystem mới
- Chỉ tạo khi có **logic/regime khác hẳn**, không phải “đổi điểm vào”.
- Subsystem mới phải độc lập (spec + changelog riêng).
```
1. Create subsystem folder
   JINQA/<NEW_SUBSYSTEM>/
2. Create subsystem docs
   - README.md
   - SPEC_JINQA-<NEW_SUBSYSTEM>-SUBSYS.md
   - CHANGELOG_<NEW_SUBSYSTEM>-SUBSYS.md
3. Define subsystem characteristics
   - Regime definition
   - Common logic (if any)
   - Entry/Exit philosophy
   - Risk approach
4. Create first strategy
   Follow steps in 6.2
5. Update portfolio configs
   - Add to analytics/compare/
   - Add to logs structure
```

### 6.4 Version Update Workflow
**Khi update strategy version:**
```
1. Determine version change
   - PATCH: bug fix, no behavior change
   - MINOR: behavior change, same idea
   - MAJOR: fundamental change

2. Create snapshot before change
   - Save current performance
   - Document baseline metrics

3. Update files
   - Version in .mq5 (#property version)
   - Version in orchestration .mqh
   - Update CHANGELOG

4. Make changes
   - Implement updates
   - Test thoroughly

5. Create snapshot after change
   - Save new performance
   - Compare with baseline

6. Document
   - Update CHANGELOG with details
   - Note expected impact
   - Add validation plan

7. Commit
   - Descriptive commit message
   - Include version bump
```

---

## 7. Best Practices

### 7.1 Tách lớp rõ ràng
- Strategy không đặt lệnh.
- Execution không “đoán” signal.
- Risk/Session là gate bắt buộc, không rải if/else.

### 7.2 Risk & trade management
- **SL-based exposure** là chuẩn.
- Multi-position: chỉ mở thêm khi lệnh trước đã được bảo vệ BE/profit.
- Không gỡ lỗ bằng tăng rủi ro theo drawdown.
- Risk Rules (Hard Constraints)
  - std-risk-rules.md là nguồn luật rủi ro chính thức (single source of truth).
  - Mọi thay đổi về risk chỉ sửa trong Sstd-risk-rules.md; phần 7.2 chỉ là tóm tắt.
  - Khi ra quyết định (mở lệnh / tăng exposure / scale-in), bắt buộc chạy các gate trong std-risk-rules.md và log lý do.

### 7.3 Config
- Config hóa: symbol settings, risk limits, environments.
- Default phải bảo thủ; production khác dev/staging rõ ràng.

### 7.4 Logging
- Mọi gate phải log: allowed/block + reason + số liệu (equity, risk_total, risk_new, cap).
- ERROR phải có context + last_error.
- “Chuẩn log chi tiết: xem std-logging.md (single source of truth).”

### 7.5 Testing & monitoring (tối thiểu)
- Smoke test: compile + run on demo.
- Theo dõi: DD, losing streak, slippage, entry mismatch; có kill-switch.
- “Pipeline đánh giá (Backtest → MC → Forward → Realtime): xem spec-eval-pipeline.md.”
- “Điều kiện Go/No-Go trước khi realtime: xem spec-forward-filter-8.md.”
- “Chuẩn 15 metrics để đánh giá/monitor: xem spec-metrics-15.md.”

---

## 8. Troubleshooting

### 8.1 Vấn đề hay gặp
```
**Issue: EA không compile**
Error: Cannot open include file
**Solution:**
- Check include paths trong Tools → Options → Directories
- Verify file tồn tại ở đúng path
- Check spelling và case sensitivity
- Kiểm tra đang include từ đúng hệ thống (JINPA vs JINQA)
```

```
**Issue: Logs không ghi được**
Error: FileOpen failed, error 5002
**Solution:**
- Check FILE_COMMON flag
- Verify folder permissions
- Check path không có ký tự đặc biệt
```

```
**Issue: Strategy không entry**
**Debug checklist:**
- [ ] Check global filters (spread, time, rollover)
- [ ] Check regime validation (specific to subsystem)
- [ ] Check heat limits
- [ ] Check position manager (max positions)
- [ ] Enable debug logging
- [ ] Review last error logs
```

```
**Issue: Cross-include giữa JINPA và JINQA**
Error: Undefined symbol or wrong includes
**Solution:**
- Verify đang include từ đúng `_core/`
- JINPA code → JINPA/_core/
- JINQA code → JINQA/_core/
- NEVER mix the two
```

### 8.2 Debug mode
Enable debug logging:
```mql5
#define DEBUG_MODE
#ifdef DEBUG_MODE
    #define DebugLog(msg) Print("[DEBUG] ", msg)
#else
    #define DebugLog(msg)
#endif
```

---

## Tổng kết
- Kiến trúc này tối ưu cho mục tiêu: **bền vững, cắt left-tail, mở right-tail, portfolio mindset**.
- Giữ cấu trúc thư mục (section 2) làm “xương sống”, còn lại là các luật ngắn để dev và AI Agent bám theo.

### Next Steps
1. Review kiến trúc mới
2. Setup git repository
3. Implement JINPA hoặc JINQA đầu tiên
4. Follow development workflow
5. Scale dần dần

---

**Maintainer:** DuyQuant  
**Last Updated:** 2026-01-25
**Version:** 2.1.0
