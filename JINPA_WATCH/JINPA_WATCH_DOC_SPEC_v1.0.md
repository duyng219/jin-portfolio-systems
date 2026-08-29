# JINPA_WATCH --- DOC SPEC v1.0

## 1. Mục tiêu

`JINPA_WATCH` là hệ thống quan sát thị trường hỗ trợ
`JINPA discretionary`.

Nhiệm vụ:

    READ MARKET
    → STRUCTURE
    → MARKET STATE
    → SETUP
    → EVENT
    → NOTIFY TRADER

JINPA_WATCH **không tự động giao dịch**.

Trader vẫn quyết định:

    TRADE
    WAIT
    SKIP

------------------------------------------------------------------------

# 2. Kiến trúc

    1 VPS
      │
      └── 1 MT5
            │
            ├── JINPA Manual EA
            │      └── Execution / Risk / SL / Trailing
            │
            └── JINPA_WATCHER
                   │
                   ├── Multi-Symbol Scanner
                   ├── Price Structure Engine
                   ├── Market State Engine
                   ├── Setup Engine
                   ├── Market Radar
                   ├── Market Flow History
                   └── Alert Engine

Hai EA chạy độc lập.

`JINPA_WATCHER` tuyệt đối không:

    Open Position
    Close Position
    Modify SL/TP
    Trailing Stop
    Modify Pending Order

------------------------------------------------------------------------

# 3. WATCHER FOUNDATION

Một instance quét nhiều symbol:

    JINPA_WATCHER
        ├── XAUUSD
        ├── EURUSD
        ├── BTCUSD
        ├── ...
        └── Symbol N

Cấu hình qua `input`.

Core runtime:

    OnInit()
    OnTimer()
    New Bar Detection
    CopyRates()
    State Storage
    Event Detection
    Logging

Không cần phân tích toàn bộ logic mỗi tick.

------------------------------------------------------------------------

# 4. PRICE STRUCTURE ENGINE

Mục tiêu:

> Xác định thị trường đang thực sự làm gì.

## Core Swing

    Swing High
    Swing Low

    HH
    HL
    LH
    LL

    Core Swing High
    Core Swing Low

Structure:

    HH + HL → Bull Structure
    LL + LH → Bear Structure
    Không tiếp diễn → Range / Transition

Cycle chỉ thay đổi sau khi cấu trúc chính bị phá và được xác nhận.

------------------------------------------------------------------------

## Structure Primitives

    IMPULSE

    PULLBACK
    ├── Leg 1
    ├── Leg 2
    └── Complex

    RANGE

    COMPRESSION / BUILD-UP

    EXPANSION

    BREAKOUT

    FALSE BREAK

    MICRO-BASE

Continuous metrics nên được lưu trước khi classification:

    ImpulseStrength
    ImpulseSizeATR

    PullbackDepth
    PullbackStrength
    PullbackLeg

    RangeWidthATR
    RangeOverlap

    CompressionScore

    BreakoutDistanceATR
    BreakoutStrength

    StructureConfidence

PRICE STRUCTURE ENGINE chỉ xây dựng **ngôn ngữ cấu trúc chung**.

Không chứa trực tiếp rule của:

    bres-pmb
    bres-pma
    revs-ppf
    revs-pps
    revs-pmr
    revs-pfb

------------------------------------------------------------------------

# 5. MARKET STATE ENGINE

Nhận dữ liệu từ Price Structure Engine và mô tả context hiện tại.

    CYCLE
    ├── BULL
    └── BEAR

    REGIME
    ├── RANGE
    ├── TREND_STRONG
    ├── TREND_WEAK
    └── TRANSITION

    PHASE
    ├── COMPRESSION
    ├── EXPANSION
    ├── IMPULSE
    └── CORRECTION

Ví dụ:

    BTCUSD H1

    Cycle: BULL
    Regime: TREND_WEAK
    Phase: CORRECTION

    Structure:
    Pullback Leg 2

    PullbackDepth: 0.38
    ImpulseStrength: 0.74

------------------------------------------------------------------------

# 6. SETUP ENGINE

Setup Engine sử dụng:

    PRICE STRUCTURE
    +
    MARKET STATE
    +
    SETUP RULES

để nhận diện setup JINPA.

Core setup:

    bres-pmb
    bres-pma

    revs-ppf
    revs-pps
    revs-pmr
    revs-pfb

Mỗi setup có state:

    NONE
    ↓
    WATCH
    ↓
    READY
    ↓
    TRIGGER

và:

    INVALID
    EXPIRED

JINPA_WATCH chỉ thông báo setup.

Không đưa ra quyết định:

    BUY
    SELL
    DO NOT TRADE

------------------------------------------------------------------------

# 7. MARKET EVENTS

JINPA_WATCH theo dõi ba nhóm event:

    MARKET STATE EVENT
    STRUCTURE EVENT
    SETUP EVENT

Ví dụ:

    [STATE]

    BTCUSD H1

    RANGE
    → TREND_STRONG

    [STRUCTURE]

    XAUUSD H1

    IMPULSE
    → PULLBACK LEG 1

    [SETUP]

    EURUSD H1

    revs-pps

    WATCH
    → READY

Không có meaningful event → không notification.

------------------------------------------------------------------------

# 8. EVENT PRIORITY

    P1 — HIGH

    Cycle Change
    Major Regime Change
    Breakout
    False Break
    Setup READY
    Setup TRIGGER

    P2 — MEDIUM

    Impulse → Correction
    Pullback Leg 1 → Leg 2
    Compression Detected
    Setup NONE → WATCH

    P3 — LOW

    Minor Swing Update
    Score Change
    Normal HH / HL / LH / LL evolution

Thông báo điện thoại:

    P1 + P2

Market Radar / History:

    P1 + P2 + P3

------------------------------------------------------------------------

# 9. MARKET RADAR

Panel tổng hợp tất cả symbol:

    JINPA MARKET RADAR

    SYMBOL   CYCLE   REGIME        PHASE        STRUCTURE      SETUP      STATUS

    XAUUSD   BULL    TREND_WEAK    CORRECTION   PB LEG 2       revs-pps   READY
    EURUSD   BULL    RANGE         COMPRESSION  UPPER BUILDUP  bres-pmb   WATCH
    BTCUSD   BULL    TREND_STRONG  IMPULSE      IMPULSE        -          NONE

Mục tiêu:

> Mở VPS → biết ngay symbol nào đáng mở chart.

------------------------------------------------------------------------

# 10. MARKET FLOW HISTORY

Mỗi symbol giữ lịch sử event gần nhất.

    BTCUSD H1

    09:00  RANGE
    10:00  COMPRESSION
    11:00  BREAKOUT
    12:00  TREND_STRONG / IMPULSE
    14:00  PULLBACK LEG 1
    15:00  revs-ppf WATCH

Trader có thể bắt lại market flow sau nhiều giờ không xem chart.

------------------------------------------------------------------------

# 11. ALERT ENGINE

Kênh:

    MT5 Push
    Telegram

Ví dụ:

    JINPA WATCH

    XAUUSD H1

    Cycle:
    BULL

    Regime:
    TREND_WEAK

    Phase:
    CORRECTION

    Structure:
    PULLBACK LEG 2
    MICRO-BASE

    Setup:
    revs-pps

    Status:
    WATCH → READY

Alert chỉ mô tả:

> Thị trường đang làm gì và setup nào đang hình thành.

Trader tự đọc chart và quyết định.

------------------------------------------------------------------------

# 12. BUILD ORDER

    01 FOUNDATION

    02 PRICE STRUCTURE ENGINE

    03 MARKET STATE

    04 MARKET RADAR

    05 EVENT ENGINE

    06 MT5 PUSH

    07 SETUP ENGINE

    08 MARKET FLOW HISTORY

    09 TELEGRAM

    10 REFINE / VALIDATE

Không cần hoàn thiện toàn bộ mới sử dụng.

Phiên bản đầu tiên chỉ cần:

    Scanner
    +
    State Storage
    +
    Timer
    +
    Logging
    +
    MT5 Push

hoạt động ổn định.

------------------------------------------------------------------------

# 13. CORE PRINCIPLE

    JINPA_WATCH
    =
    MARKET OBSERVER
    +
    STRUCTURE CLASSIFIER
    +
    STATE CLASSIFIER
    +
    SETUP DETECTOR
    +
    MARKET FLOW LOGGER
    +
    NOTIFICATION SYSTEM

Không phải:

    AUTO TRADING SYSTEM

JINPA_WATCH nói:

> **Thị trường đang làm gì.**

Không nói:

> **Trader phải làm gì.**

Quyết định cuối cùng luôn thuộc về `JINPA discretionary`.
