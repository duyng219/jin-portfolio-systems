//+------------------------------------------------------------------+
//|                                             panel_defines.mqh   |
//|                         JINPA v2 — Constants and enums for panel |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_PANEL_DEFINES_MQH
#define JINPA_PANEL_DEFINES_MQH

//+------ Setup types ------+//
#define PANEL_SETUPS_COUNT 9
const string PANEL_SETUPS[PANEL_SETUPS_COUNT] = {
    "bres-pma",
    "bres-pmb",
    "bres-pmb-st",
    "revs-ppf",
    "revs-pps",
    "revs-pmr",
    "revs-pmr-st",
    "revs-pfb",
    "none"
};

//+------ Entry suffixes ------+//
#define PANEL_SUFFIXES_COUNT 3
const string PANEL_SUFFIXES[PANEL_SUFFIXES_COUNT] = {
    "_0_",
    "_1_",
    "_bias_"
};

//+------ SL mode indices ------+//
#define PANEL_SL_ATR_IDX   0
#define PANEL_SL_FIXED_IDX 1

// ════════════════════════════════════════════════════════════════════
//  GEOMETRY — chỉnh các hằng số dưới đây để thay đổi kích thước panel
// ════════════════════════════════════════════════════════════════════

// ── Margin & spacing ─────────────────────────────────────────────
#define MX        6   // Margin ngang/dọc cơ bản (px) — khoảng cách mép ngoài block
#define BTN_GAP   4   // Khoảng cách giữa các nút bấm trong cùng một block
#define BLK_GAP   6   // Khoảng cách giữa hai block liền kề
#define BLOCK_PAD 8   // Padding bên trong block (top và bottom)
#define TITLE_GAP 12   // Khoảng cách từ title block xuống nội dung

// ── Kích thước từng phần tử ───────────────────────────────────────
#define RH       28   // Chiều cao hàng input: CEdit, CComboBox
#define BTN_H    24   // Chiều cao nút bấm (font 9pt + 6px padding trên/dưới)
#define BTN_W   112   // Chiều rộng mỗi nút bấm — CHỈNH SỐ NÀY để thay đổi độ rộng nút
#define LOG_RH   14   // Chiều cao mỗi dòng trong trade log

// ── Caption bar (cố định bởi MT5, không chỉnh) ───────────────────
#define CAP_H    22   // Chiều cao thanh tiêu đề CAppDialog (MT5 quyết định)

// ── Chiều rộng panel — tự suy ra từ BTN_W, không cần chỉnh thủ công ──
// Công thức: (2 nút × BTN_W) + (3 × MX: trái/giữa/phải) + 6px frame
#define PANEL_W  (2 * BTN_W + 3 * MX + 6)

// ── Chiều cao tối thiểu panel (px) ───────────────────────────────
// Đây là chiều cao tối thiểu để hiển thị đủ 6 block nội dung.
// Trong JINPA_v2.mq5, PANEL_H thực tế được tính tự động theo độ cao chart.
// Nếu chart quá thấp, panel sẽ dùng MIN_PANEL_H làm fallback.
// Tăng số này nếu muốn panel tối thiểu cao hơn.
#define MIN_PANEL_H 760

// ════════════════════════════════════════════════════════════════════
//  UI SCALING
// ════════════════════════════════════════════════════════════════════
// 0 = calibration mode. The current 3K layout stays pixel-identical while
// OnInit logs DPI/chart/panel values. After measuring the 3K reference DPI,
// set JINPA_UI_REFERENCE_DPI to that value. Lower-DPI environments are not
// enlarged past 1.000 because chart objects already consume real chart pixels;
// enlarging them makes the panel cover too much of VPS charts.
#define JINPA_UI_REFERENCE_DPI 192
#define JINPA_UI_COMPACT_SCALE 0.75

double g_jinpaUIScaleOverride = 0.0;

double GetUIDPIScale()
{
    long dpi = TerminalInfoInteger(TERMINAL_SCREEN_DPI);
    if(dpi <= 0)
        dpi = 96;

    if(JINPA_UI_REFERENCE_DPI <= 0)
        return 1.0;

    double scale = (double)JINPA_UI_REFERENCE_DPI / (double)dpi;
    if(scale < 0.50)
        scale = 0.50;
    if(scale > 1.00)
        scale = 1.00;

    return scale;
}

void SetUIScaleOverride(double scale)
{
    if(scale <= 0.0)
    {
        g_jinpaUIScaleOverride = 0.0;
        return;
    }

    if(scale < 0.50)
        scale = 0.50;
    if(scale > 1.00)
        scale = 1.00;

    g_jinpaUIScaleOverride = scale;
}

double GetChartAwareUIScale(int chartW, int chartH)
{
    double scale = GetUIDPIScale();

    // If MT5 tiles many charts, the chart can be too short for the DPI scale.
    // Cap scale before object creation so panel height/click areas stay inside
    // the visible chart. The 3K reference charts stay at exactly 1.000.
    double maxByW = (chartW > 0) ? ((double)chartW / (double)(PANEL_W + 20)) : scale;
    double maxByH = (chartH > 0) ? ((double)chartH / (double)(260 + 20 + 4)) : scale;
    double maxFit = MathMin(maxByW, maxByH);

    if(maxFit > 0.0 && maxFit < scale)
        scale = maxFit;

    if(scale < 0.50)
        scale = 0.50;
    if(scale > 1.00)
        scale = 1.00;

    return scale;
}

double GetUIScale()
{
    double scale = 1.0;

    if(g_jinpaUIScaleOverride > 0.0)
        scale = g_jinpaUIScaleOverride;
    else
        scale = GetUIDPIScale();

    long dpi = TerminalInfoInteger(TERMINAL_SCREEN_DPI);
    if(dpi > 0 && dpi < JINPA_UI_REFERENCE_DPI)
        scale *= JINPA_UI_COMPACT_SCALE;

    if(scale < 0.50)
        scale = 0.50;
    if(scale > 1.00)
        scale = 1.00;

    return scale;
}

double GetUIFontScale()
{
    // Keep text readable on VPS. Geometry can be compact, but MT5 control
    // fonts should stay at the 3K reference size unless a higher-DPI screen
    // needs downscaling.
    double scale = GetUIDPIScale();
    if(scale > 1.00)
        scale = 1.00;
    if(scale < 1.00)
        scale = 1.00;

    return scale;
}

int ScaleUI(int value)
{
    return (int)MathRound((double)value * GetUIScale());
}

int ScaleFont(int value)
{
    int scaled = (int)MathRound((double)value * GetUIFontScale());
    return MathMax(6, scaled);
}

// ════════════════════════════════════════════════════════════════════
//  COLOR SYSTEM — Dark + Green flat theme
// ════════════════════════════════════════════════════════════════════

// ── Màu nền ──────────────────────────────────────────────────────
// #define CLR_BG_MAIN       C'33,39,54'    // Nền tổng thể panel (#212736)
#define CLR_BG_MAIN       C'238,241,245'    // Nền tổng thể panel, tạo dải phân tách giữa blocks
// #define CLR_BG_BLOCK      C'33,39,54'    // Nền mỗi block (#212736)
#define CLR_BG_BLOCK      clrWhite    // Nền mỗi block (#212736)
#define CLR_BORDER        clrDimGray     // Viền 1px cho block và input
#define CLR_CONTROL_BORDER clrSilver     // Viền nhạt cho input/button, cùng tông dropdown
#define CLR_SEPARATOR     C'42,48,62'    // Đường ngăn block, xám rất dịu gần màu nền

// ── Màu chữ ──────────────────────────────────────────────────────
#define CLR_TEXT_PRIMARY  clrWhite       // Chữ chính (input, neutral btn)
#define CLR_TEXT_COMMENT  clrSilver      // Chữ phụ, label, log rows
#define CLR_TITLE         C'17,17,21'        // Tiêu đề block — xanh neon

// ── Màu nút BUY (flat, không gradient) ───────────────────────────
// #define CLR_BTN_BUY       C'0,68,34'    // BUY nền: #004422 (xanh tối)
#define CLR_BTN_BUY       clrWhite    // BUY nền: #004422 (xanh tối)
#define CLR_TEXT_BUY      clrLime        // BUY text: xanh neon

// ── Màu nút SELL (flat, không gradient) ──────────────────────────
// #define CLR_BTN_SELL      C'68,17,17'   // SELL nền: #441111 (đỏ tối)
#define CLR_BTN_SELL      clrWhite    // SELL nền: #441111 (đỏ tối)
#define CLR_TEXT_SELL     clrRed         // SELL text: đỏ

// ── Màu nút Cancel / Neutral ─────────────────────────────────────
#define CLR_BTN_CANCEL    clrWhite    // Cancel nền: #222222
#define CLR_BTN_NEUTRAL   clrWhite    // Export CSV nền: #222222

// ── Reserve cho display trạng thái ───────────────────────────────
#define CLR_GREEN_OK      C'0,255,136'  // Trạng thái OK — #00FF88
#define CLR_RED_ERR       clrRed         // Trạng thái lỗi

//+------ Log Level enum (used by panel logger) ------+//
enum ENUM_LOG_LEVEL
{
    LOG_NONE  = 0,  // Tắt toàn bộ log
    LOG_ERROR = 1,  // Chỉ log lỗi
    LOG_INFO  = 2,  // Log thành công + lỗi (default)
    LOG_DEBUG = 3,  // Log chi tiết: params + result
};

#endif
