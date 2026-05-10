//+------------------------------------------------------------------+
//|                                               panel_main.mqh    |
//|                         JINPA v2 — CAppDialog trading panel UI  |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_PANEL_MAIN_MQH
#define JINPA_PANEL_MAIN_MQH

#include <Trade/Trade.mqh>
#include <Controls/Dialog.mqh>
#include <Controls/Panel.mqh>
#include <Controls/Button.mqh>
#include <Controls/ComboBox.mqh>
#include <Controls/Edit.mqh>
#include <Controls/Label.mqh>

#include "../_core/managers/risk_manager.mqh"
#include "../_core/managers/position_manager.mqh"
#include "panel_defines.mqh"
#include "trade_log.mqh"

#define PANEL_LOG_ROWS 10

//+------------------------------------------------------------------+
//| CJINPAPanel — Flat design panel, 7 blocks                        |
//+------------------------------------------------------------------+
class CJINPAPanel : public CAppDialog
{
private:
    //── Full-panel background — phủ toàn bộ client area (kể cả khoảng trống giữa blocks) ──
    CPanel    m_panelBg;

    //── Block backgrounds — CPanel tạo OBJ_RECTANGLE_LABEL thật, là child của dialog ──
    // Add() background TRƯỚC controls → nền nằm phía sau (z-order theo thứ tự tạo)
    CPanel    m_bgBlocks[7];
    CPanel    m_sepBlocks[6];

    //── Block 1: SETUP ────────────────────────────────────────────
    CLabel    m_lblTitleSetup;
    CComboBox m_cmbSetup;
    CLabel    m_lblKey;
    CComboBox m_cmbSuffix;
    CEdit     m_edtCustom;

    //── Block 2: ORDER SIZE / RISK ────────────────────────────────
    CLabel    m_lblTitleSize;
    CLabel    m_lblRiskM;
    CComboBox m_cmbRiskM;
    CLabel    m_lblSLLabel;
    CComboBox m_cmbSL;

    //── Block 3: TRADE ────────────────────────────────────────────
    CLabel    m_lblTitleTrade;
    CButton   m_btnBuyMkt;
    CButton   m_btnSellMkt;
    CButton   m_btnBuyStop;
    CButton   m_btnSellStop;
    CButton   m_btnBuyLimit;
    CButton   m_btnSellLimit;

    //── Block 4: CANCEL ───────────────────────────────────────────
    CLabel    m_lblTitleCancel;
    CButton   m_btnCancelBO;
    CButton   m_btnCancelSO;
    CButton   m_btnCancelBuy;
    CButton   m_btnCancelSell;

    //── Block 5: TRADES LOG ───────────────────────────────────────
    CLabel    m_lblTitleLog;
    CLabel    m_lblLogCols;
    CLabel    m_logRows[PANEL_LOG_ROWS];

    //── Block 6: EXPORT ───────────────────────────────────────────
    CButton   m_btnExportCSV;

    //── Injected dependencies ──────────────────────────────────────
    string             m_symbol;
    ulong              m_magic;
    CRiskManager*      m_rm;
    CPositionManager*  m_pm;
    CTrade*            m_trade;
    ENUM_MONEY_MANAGEMENT m_mmType;
    double             m_minLotSteps;
    double             m_riskPct;
    double             m_fixedLot;
    ushort             m_poExpMin;
    ENUM_LOG_LEVEL     m_logLevel;
    bool               m_tradingHalted;
    string             m_haltReason;

    //── Market data (updated mỗi tick) ────────────────────────────
    double             m_atrSL;
    double             m_atrPO;
    int                m_slPoints;
    double             m_dailyDD;
    int                m_visibleLogRows;

    CTradeLog          m_log;

    //── Private helpers ───────────────────────────────────────────
    bool   CreateControls(int ox, int oy, int pw, int ph);
    void   StyleDialogFrame();
    void   RestyleStaticObjects();
    void   StyleComboText(string comboName, int fontSize = 8);
    bool   AddBlockBg(int idx, int x1, int y1, int x2, int y2);
    bool   AddSeparator(int idx, int x1, int y, int x2);
    bool   MakeBtn(CButton& btn, string nm, int x1, int y1, int x2, int y2,
                   string txt, color tc, color bc);
    bool   MakeLbl(CLabel& lbl, string nm, int x1, int y1, int x2, int y2,
                   string txt, color tc, string font = "Consolas", int sz = 8);
    double CalcSL(string dir, double basePrice);
    bool   IsWeekendFxLikeMarket();
    void   PlaceOrder(ENUM_ORDER_TYPE type);
    void   LogResult(string action);
    void   RefreshLog();

private:
    //── Button handlers ───────────────────────────────────────────
    void   OnBuyMarket();
    void   OnSellMarket();
    void   OnBuyStop();
    void   OnSellStop();
    void   OnBuyLimit();
    void   OnSellLimit();
    void   OnCancelBO();
    void   OnCancelSO();
    void   OnCancelBuy();
    void   OnCancelSell();
    void   OnExportCSV();

public:
    CJINPAPanel();

    virtual bool Create(const long chart, const string name, const int subwin,
                        const int x1, const int y1, const int x2, const int y2);

    void SetDependencies(string symbol, ulong magic,
                         CRiskManager* rm, CPositionManager* pm, CTrade* pTrade,
                         ENUM_MONEY_MANAGEMENT mm, double minLotSteps,
                         double riskPct, double fixedLot, ushort poExpMin,
                         ENUM_LOG_LEVEL logLevel);

    void   UpdateMarketData(double atrSL, double atrPO, int slPoints, double dailyDD = 0);
    void   SetTradingHalt(bool halted, string reason = "");
    void   RefreshVisuals();
    void   Tick();
    string GetComment();
    double GetLotSize(ENUM_ORDER_TYPE dir = ORDER_TYPE_BUY);

protected:
    virtual bool OnEvent(const int id, const long& lparam,
                         const double& dparam, const string& sparam);
};

//+--- Event routing -----------------------------------------------+//
EVENT_MAP_BEGIN(CJINPAPanel)
    ON_EVENT(ON_CLICK, m_btnBuyMkt,     OnBuyMarket)
    ON_EVENT(ON_CLICK, m_btnSellMkt,    OnSellMarket)
    ON_EVENT(ON_CLICK, m_btnBuyStop,    OnBuyStop)
    ON_EVENT(ON_CLICK, m_btnSellStop,   OnSellStop)
    ON_EVENT(ON_CLICK, m_btnBuyLimit,   OnBuyLimit)
    ON_EVENT(ON_CLICK, m_btnSellLimit,  OnSellLimit)
    ON_EVENT(ON_CLICK, m_btnCancelBO,   OnCancelBO)
    ON_EVENT(ON_CLICK, m_btnCancelSO,   OnCancelSO)
    ON_EVENT(ON_CLICK, m_btnCancelBuy,  OnCancelBuy)
    ON_EVENT(ON_CLICK, m_btnCancelSell, OnCancelSell)
    ON_EVENT(ON_CLICK, m_btnExportCSV,  OnExportCSV)
EVENT_MAP_END(CAppDialog)

//+------------------------------------------------------------------+
CJINPAPanel::CJINPAPanel() :
    m_rm(NULL), m_pm(NULL), m_trade(NULL),
    m_magic(0), m_mmType(MM_EQUITY_RISK_PERCENT),
    m_minLotSteps(500), m_riskPct(0.5), m_fixedLot(0.01),
    m_poExpMin(360), m_logLevel(LOG_INFO),
    m_atrSL(0), m_atrPO(0), m_slPoints(0), m_dailyDD(0),
    m_visibleLogRows(0),
    m_tradingHalted(false), m_haltReason("")
{
}

//+------------------------------------------------------------------+
bool CJINPAPanel::Create(const long chart, const string name, const int subwin,
                          const int x1, const int y1, const int x2, const int y2)
{
    if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
        return false;
    StyleDialogFrame();
    // Controls framework calls Shift(clientArea.Left(), clientArea.Top()) on every Add().
    // Pass (0,0) so coordinates stay relative to the client area; Shift() converts them
    // to absolute. Passing absolute coords here would double-shift and push wide controls
    // outside the container bounds, causing Contains()=false → Hide() on first Add().
    return CreateControls(0, 0, x2 - x1, y2 - y1);
}

//+------------------------------------------------------------------+
//| Đổi màu khung mặc định của CAppDialog                            |
//+------------------------------------------------------------------+
void CJINPAPanel::StyleDialogFrame()
{
    string borderName     = m_name + "Border";
    string backName       = m_name + "Back";
    string captionName    = m_name + "Caption";
    string clientBackName = m_name + "ClientBack";

    if(ObjectFind(m_chart_id, borderName) >= 0)
    {
        ObjectSetInteger(m_chart_id, borderName, OBJPROP_COLOR, CLR_SEPARATOR);
        ObjectSetInteger(m_chart_id, borderName, OBJPROP_BGCOLOR, CLR_BG_MAIN);
    }

    if(ObjectFind(m_chart_id, backName) >= 0)
    {
        ObjectSetInteger(m_chart_id, backName, OBJPROP_COLOR, CLR_BG_MAIN);
        ObjectSetInteger(m_chart_id, backName, OBJPROP_BGCOLOR, CLR_BG_MAIN);
    }

    if(ObjectFind(m_chart_id, captionName) >= 0)
    {
        ObjectSetInteger(m_chart_id, captionName, OBJPROP_COLOR, CLR_TEXT_COMMENT);
        ObjectSetInteger(m_chart_id, captionName, OBJPROP_BGCOLOR, CLR_BG_MAIN);
        ObjectSetInteger(m_chart_id, captionName, OBJPROP_BORDER_COLOR, CLR_BG_MAIN);
    }

    if(ObjectFind(m_chart_id, clientBackName) >= 0)
    {
        ObjectSetInteger(m_chart_id, clientBackName, OBJPROP_COLOR, CLR_BG_MAIN);
        ObjectSetInteger(m_chart_id, clientBackName, OBJPROP_BGCOLOR, CLR_BG_MAIN);
    }
}

//+------------------------------------------------------------------+
//| Re-apply styles after CAppDialog::Run() touches child objects.   |
//+------------------------------------------------------------------+
void CJINPAPanel::RestyleStaticObjects()
{
    string pnName = m_name + "PanelBg";
    if(ObjectFind(m_chart_id, pnName) >= 0)
    {
        ObjectSetInteger(m_chart_id, pnName, OBJPROP_COLOR, CLR_BG_MAIN);
        ObjectSetInteger(m_chart_id, pnName, OBJPROP_BGCOLOR, CLR_BG_MAIN);
        ObjectSetInteger(m_chart_id, pnName, OBJPROP_ZORDER, 0);
    }

}

//+------------------------------------------------------------------+
//| Block backgrounds disabled: MT5 can hide them on first render.   |
//+------------------------------------------------------------------+
bool CJINPAPanel::AddBlockBg(int idx, int x1, int y1, int x2, int y2)
{
    if(idx < 0 || idx >= 7) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Thin separators for header and Pool Summary only.                |
//+------------------------------------------------------------------+
bool CJINPAPanel::AddSeparator(int idx, int x1, int y, int x2)
{
    if(idx < 0 || idx >= 6) return false;
    if(idx > 1) return true;

    string sepName = m_name + "Sep" + IntegerToString(idx);
    if(ObjectFind(m_chart_id, sepName) >= 0)
        ObjectDelete(m_chart_id, sepName);

    if(!m_sepBlocks[idx].Create(m_chart_id, sepName, m_subwin, x1, y, x2, y + 1))
        return false;
    m_sepBlocks[idx].ColorBackground(CLR_SEPARATOR);
    m_sepBlocks[idx].Color(CLR_SEPARATOR);
    m_sepBlocks[idx].BorderType(BORDER_FLAT);
    if(!Add(m_sepBlocks[idx])) return false;
    ObjectSetInteger(m_chart_id, sepName, OBJPROP_COLOR, CLR_SEPARATOR);
    ObjectSetInteger(m_chart_id, sepName, OBJPROP_BGCOLOR, CLR_SEPARATOR);
    ObjectSetInteger(m_chart_id, sepName, OBJPROP_ZORDER, 1);
    return true;
}

//+------------------------------------------------------------------+
//| Helper tạo button — tránh lặp code                               |
//+------------------------------------------------------------------+
bool CJINPAPanel::MakeBtn(CButton& btn, string nm, int x1, int y1, int x2, int y2,
                           string txt, color tc, color bc)
{
    if(!btn.Create(m_chart_id, m_name + nm, m_subwin, x1, y1, x2, y2)) return false;
    btn.Text(txt);
    btn.Color(tc);
    btn.ColorBackground(bc);
    btn.ColorBorder(CLR_CONTROL_BORDER);
    btn.Font("Consolas");
    btn.FontSize(8);
    if(!Add(btn)) return false;
    ObjectSetInteger(m_chart_id, m_name + nm, OBJPROP_ZORDER, 2);
    return true;
}

//+------------------------------------------------------------------+
//| Helper tạo label — set ZORDER=1 tại creation → hiện ngay lần đầu|
//+------------------------------------------------------------------+
bool CJINPAPanel::MakeLbl(CLabel& lbl, string nm, int x1, int y1, int x2, int y2,
                            string txt, color tc, string font, int sz)
{
    if(!lbl.Create(m_chart_id, m_name + nm, m_subwin, x1, y1, x2, y2)) return false;
    lbl.Text(txt);
    lbl.Color(tc);
    lbl.Font(font);
    lbl.FontSize(sz);
    if(!Add(lbl)) return false;
    ObjectSetInteger(m_chart_id, m_name + nm, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(m_chart_id, m_name + nm, OBJPROP_ZORDER, 2);
    return true;
}

//+------------------------------------------------------------------+
//| Helper chỉnh font cho CComboBox và các item trong dropdown       |
//+------------------------------------------------------------------+
void CJINPAPanel::StyleComboText(string comboName, int fontSize)
{
    string editName = m_name + comboName + "Edit";
    if(ObjectFind(m_chart_id, editName) >= 0)
    {
        ObjectSetString(m_chart_id, editName, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(m_chart_id, editName, OBJPROP_FONTSIZE, fontSize);
    }

    string listPrefix = m_name + comboName + "ListItem";
    for(int i = 0; i < 20; i++)
    {
        string itemName = listPrefix + IntegerToString(i);
        if(ObjectFind(m_chart_id, itemName) < 0)
            continue;

        ObjectSetString(m_chart_id, itemName, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(m_chart_id, itemName, OBJPROP_FONTSIZE, fontSize);
    }
}

//+------------------------------------------------------------------+
bool CJINPAPanel::CreateControls(int ox, int oy, int pw, int ph)
{
    int BW  = BTN_W;               // chiều rộng mỗi nút
    int W   = 2 * BW + MX;        // chiều rộng 2 nút cạnh nhau
    int bgW = PANEL_W - 6;        // chiều rộng background block
    int clientH = ph - CAP_H - 6; // client area height (ph = total dialog height)

    // ── Full-panel background — Add() đầu tiên → z-order thấp nhất ──
    // Phủ toàn bộ client area để không có pixel xám/trắng lọt qua
    {
        string pnName = m_name + "PanelBg";
        if(!m_panelBg.Create(m_chart_id, pnName, m_subwin, ox, oy, ox + bgW, oy + clientH))
            return false;
        m_panelBg.ColorBackground(CLR_BG_MAIN);
        m_panelBg.Color(CLR_BG_MAIN);  // no visible border
        m_panelBg.BorderType(BORDER_FLAT);
        if(!Add(m_panelBg)) return false;
        ObjectSetInteger(m_chart_id, pnName, OBJPROP_COLOR, CLR_BG_MAIN);
        ObjectSetInteger(m_chart_id, pnName, OBJPROP_BGCOLOR, CLR_BG_MAIN);
        ObjectSetInteger(m_chart_id, pnName, OBJPROP_ZORDER, 0);
    }

    if(!AddSeparator(0, ox+MX, oy+MX, ox+bgW-MX)) return false;

    // ══════════════════════════════════════════════════════════════
    //  BLOCK 1 — SETUP
    //  Hàng 1: [setup combo ▼]  Key: [suffix ▼]
    //  Hàng 2: [custom text edit]
    // ══════════════════════════════════════════════════════════════
    int b1y1  = oy + MX;
    int tY1   = b1y1 + BLOCK_PAD;
    int yS0   = tY1 + LOG_RH + TITLE_GAP;   // hàng setup/suffix
    int yS1   = yS0 + RH + MX;      // hàng custom edit
    int b1y2  = yS1 + RH + BLOCK_PAD;

    if(!AddBlockBg(1, ox, b1y1, ox + bgW, b1y2)) return false;

    if(!MakeLbl(m_lblTitleSetup, "TitleSetup", ox+MX, tY1, ox+bgW-MX, tY1+LOG_RH,
                "SETUP", CLR_TITLE, "Consolas", 9)) return false;

    // setup combo | "Key:" label | suffix/key dropdown
    int suffixW = 58;
    int keyLblW = 28;
    int setupW  = W - suffixW - keyLblW - MX;

    if(!m_cmbSetup.Create(m_chart_id, m_name+"CmbSetup", m_subwin,
                           ox+MX, yS0, ox+MX+setupW, yS0+RH)) return false;
    StyleComboText("CmbSetup");
    for(int i = 0; i < PANEL_SETUPS_COUNT; i++)
        m_cmbSetup.AddItem(PANEL_SETUPS[i], i);
    m_cmbSetup.SelectByValue(3);
    if(!Add(m_cmbSetup)) return false;

    if(!MakeLbl(m_lblKey, "LblKey", ox+MX+setupW+MX, yS0, ox+MX+setupW+MX+keyLblW, yS0+RH,
                "Key:", CLR_TEXT_COMMENT)) return false;

    if(!m_cmbSuffix.Create(m_chart_id, m_name+"CmbSuffix", m_subwin,
                            ox+MX+setupW+MX+keyLblW, yS0, ox+MX+W, yS0+RH)) return false;
    StyleComboText("CmbSuffix");
    for(int i = 0; i < PANEL_SUFFIXES_COUNT; i++)
        m_cmbSuffix.AddItem(PANEL_SUFFIXES[i], i);
    m_cmbSuffix.SelectByValue(0);
    if(!Add(m_cmbSuffix)) return false;

    if(!m_edtCustom.Create(m_chart_id, m_name+"EdtCustom", m_subwin,
                            ox+MX, yS1, ox+MX+W, yS1+RH)) return false;
    m_edtCustom.Text("");
    m_edtCustom.Color(clrBlack);
    m_edtCustom.ColorBackground(clrWhite);
    m_edtCustom.ColorBorder(CLR_CONTROL_BORDER);
    m_edtCustom.Font("Consolas");
    m_edtCustom.FontSize(8);
    if(!Add(m_edtCustom)) return false;
    if(!AddSeparator(2, ox+MX, b1y2 + BLK_GAP / 2, ox+bgW-MX)) return false;

    // ══════════════════════════════════════════════════════════════
    //  BLOCK 2 — ORDER SIZE / RISK
    //  Hàng 1: Risk-m: [MM combo]  SL: [SL combo]
    // ══════════════════════════════════════════════════════════════
    int b2y1  = b1y2 + BLK_GAP;
    int tY2   = b2y1 + BLOCK_PAD;
    int yR0   = tY2 + LOG_RH + TITLE_GAP;
    int b2y2  = yR0 + RH + BLOCK_PAD;

    if(!AddBlockBg(2, ox, b2y1, ox + bgW, b2y2)) return false;

    if(!MakeLbl(m_lblTitleSize, "TitleSize", ox+MX, tY2, ox+bgW-MX, tY2+LOG_RH,
                "ORDER SIZE / RISK", CLR_TITLE, "Consolas", 9)) return false;

    // "Risk-m:" label | wider risk combo | "SL:" label | shorter SL combo
    int rLblW = 44, mmW = 118, slLblW = 22;

    if(!MakeLbl(m_lblRiskM, "LblRiskM", ox+MX, yR0, ox+MX+rLblW, yR0+RH,
                "Risk-m:", CLR_TEXT_COMMENT)) return false;

    if(!m_cmbRiskM.Create(m_chart_id, m_name+"CmbRiskM", m_subwin,
                           ox+MX+rLblW+MX, yR0, ox+MX+rLblW+MX+mmW, yR0+RH)) return false;
    StyleComboText("CmbRiskM");
    m_cmbRiskM.AddItem("min Lot",  MM_MIN_LOT_SIZE);
    m_cmbRiskM.AddItem("min/eq",   MM_MIN_LOT_PER_EQUITY);
    m_cmbRiskM.AddItem("fixed",    MM_FIXED_LOT_SIZE);
    m_cmbRiskM.AddItem("fixed/eq", MM_FIXED_LOT_PER_EQUITY);
    m_cmbRiskM.AddItem("eq risk %", MM_EQUITY_RISK_PERCENT);
    m_cmbRiskM.SelectByValue((long)m_mmType);
    if(!Add(m_cmbRiskM)) return false;

    int slLblX = ox+MX+rLblW+MX+mmW+MX;
    if(!MakeLbl(m_lblSLLabel, "LblSL", slLblX, yR0, slLblX+slLblW, yR0+RH,
                "SL:", CLR_TEXT_COMMENT)) return false;

    if(!m_cmbSL.Create(m_chart_id, m_name+"CmbSL", m_subwin,
                        slLblX+slLblW, yR0, ox+MX+W, yR0+RH)) return false;
    StyleComboText("CmbSL");
    m_cmbSL.AddItem("atr",   PANEL_SL_ATR_IDX);
    m_cmbSL.AddItem("fixed", PANEL_SL_FIXED_IDX);
    m_cmbSL.SelectByValue(PANEL_SL_ATR_IDX);
    if(!Add(m_cmbSL)) return false;
    if(!AddSeparator(2, ox+MX, b2y2 + BLK_GAP / 2, ox+bgW-MX)) return false;

    // ══════════════════════════════════════════════════════════════
    //  BLOCK 3 — TRADE
    //  3 cặp nút: Market / Stop / Limit
    // ══════════════════════════════════════════════════════════════
    int b3y1  = b2y2 + BLK_GAP;
    int tY3   = b3y1 + BLOCK_PAD;
    int yMkt  = tY3  + LOG_RH + TITLE_GAP;
    int yStop = yMkt  + BTN_H + BTN_GAP;
    int yLim  = yStop + BTN_H + BTN_GAP;
    int b3y2  = yLim  + BTN_H + BLOCK_PAD;

    if(!AddBlockBg(3, ox, b3y1, ox + bgW, b3y2)) return false;

    if(!MakeLbl(m_lblTitleTrade, "TitleTrade", ox+MX, tY3, ox+bgW-MX, tY3+LOG_RH,
                "TRADE", CLR_TITLE, "Consolas", 9)) return false;

    if(!MakeBtn(m_btnBuyMkt,    "BtnBuyMkt",   ox+MX,       yMkt,  ox+MX+BW,       yMkt+BTN_H,  "Buy Market",  CLR_TITLE,  CLR_BTN_BUY))  return false;
    if(!MakeBtn(m_btnSellMkt,   "BtnSellMkt",  ox+MX+BW+MX, yMkt,  ox+MX+BW+MX+BW, yMkt+BTN_H,  "Sell Market", CLR_TITLE,  CLR_BTN_SELL)) return false;
    if(!MakeBtn(m_btnBuyStop,   "BtnBuyStop",  ox+MX,       yStop, ox+MX+BW,       yStop+BTN_H, "B-Stop",      CLR_TITLE,  CLR_BTN_BUY))  return false;
    if(!MakeBtn(m_btnSellStop,  "BtnSellStop", ox+MX+BW+MX, yStop, ox+MX+BW+MX+BW, yStop+BTN_H, "S-Stop",      CLR_TITLE,  CLR_BTN_SELL)) return false;
    if(!MakeBtn(m_btnBuyLimit,  "BtnBuyLimit", ox+MX,       yLim,  ox+MX+BW,       yLim+BTN_H,  "B-Limit",     CLR_TITLE,  CLR_BTN_BUY))  return false;
    if(!MakeBtn(m_btnSellLimit, "BtnSellLimit",ox+MX+BW+MX, yLim,  ox+MX+BW+MX+BW, yLim+BTN_H,  "S-Limit",     CLR_TITLE,  CLR_BTN_SELL)) return false;
    if(!AddSeparator(3, ox+MX, b3y2 + BLK_GAP / 2, ox+bgW-MX)) return false;

    // ══════════════════════════════════════════════════════════════
    //  BLOCK 4 — CANCEL
    //  Hàng 1: Cancel BO / Cancel SO (xóa pending orders)
    //  Hàng 2: Cancel Buy / Cancel Sell (đóng positions)
    // ══════════════════════════════════════════════════════════════
    int b4y1  = b3y2 + BLK_GAP;
    int tY4   = b4y1 + BLOCK_PAD;
    int yBO   = tY4  + LOG_RH + TITLE_GAP;
    int yPos  = yBO  + BTN_H + BTN_GAP;
    int b4y2  = yPos + BTN_H + BLOCK_PAD;

    if(!AddBlockBg(4, ox, b4y1, ox + bgW, b4y2)) return false;

    if(!MakeLbl(m_lblTitleCancel, "TitleCancel", ox+MX, tY4, ox+bgW-MX, tY4+LOG_RH,
                "CANCEL", CLR_TITLE, "Consolas", 9)) return false;

    if(!MakeBtn(m_btnCancelBO,   "BtnCancelBO",   ox+MX,       yBO,  ox+MX+BW,       yBO+BTN_H,  "xBO",   CLR_TEXT_COMMENT, CLR_BTN_CANCEL)) return false;
    if(!MakeBtn(m_btnCancelSO,   "BtnCancelSO",   ox+MX+BW+MX, yBO,  ox+MX+BW+MX+BW, yBO+BTN_H,  "xSO",   CLR_TEXT_COMMENT, CLR_BTN_CANCEL)) return false;
    if(!MakeBtn(m_btnCancelBuy,  "BtnCancelBuy",  ox+MX,       yPos, ox+MX+BW,       yPos+BTN_H, "xBuy",  CLR_TEXT_COMMENT, CLR_BTN_CANCEL)) return false;
    if(!MakeBtn(m_btnCancelSell, "BtnCancelSell", ox+MX+BW+MX, yPos, ox+MX+BW+MX+BW, yPos+BTN_H, "xSell", CLR_TEXT_COMMENT, CLR_BTN_CANCEL)) return false;
    if(!AddSeparator(4, ox+MX, b4y2 + BLK_GAP / 2, ox+bgW-MX)) return false;

    // ══════════════════════════════════════════════════════════════
    //  BLOCK 5 — TRADES LOG
    //  Header cột + PANEL_LOG_ROWS dòng vị thế đang mở
    // ══════════════════════════════════════════════════════════════
    int b6y2 = oy + clientH - MX;
    int b6y1 = b6y2 - BTN_H - 2 * BLOCK_PAD;
    int yExp = b6y1 + BLOCK_PAD;

    int b5y1    = b4y2 + BLK_GAP;
    int tY5     = b5y1 + BLOCK_PAD;
    int yLCols  = tY5  + LOG_RH + TITLE_GAP;
    int yLog0   = yLCols + LOG_RH + 2;
    int b5y2    = b6y1 - BLK_GAP;
    int logRoom = b5y2 - yLog0 - BLOCK_PAD;
    m_visibleLogRows = MathMax(0, MathMin(PANEL_LOG_ROWS, logRoom / (LOG_RH + 2)));

    if(!AddBlockBg(5, ox, b5y1, ox + bgW, b5y2)) return false;

    if(!MakeLbl(m_lblTitleLog, "TitleLog", ox+MX, tY5, ox+bgW-MX, tY5+LOG_RH,
                "TRADES LOG", CLR_TITLE, "Consolas", 9)) return false;
    if(!MakeLbl(m_lblLogCols, "LblLogCols", ox+MX, yLCols, ox+MX+W, yLCols+LOG_RH,
                "Ticket    Comment       Time", CLR_TEXT_COMMENT, "Consolas", 8)) return false;
    for(int i = 0; i < m_visibleLogRows; i++)
    {
        int yRow = yLog0 + i * (LOG_RH + 2);
        if(!MakeLbl(m_logRows[i], "LogRow"+IntegerToString(i),
                    ox+MX, yRow, ox+MX+W, yRow+LOG_RH,
                    "", CLR_TEXT_COMMENT, "Consolas", 8)) return false;
    }
    if(!AddSeparator(5, ox+MX, b5y2 + BLK_GAP / 2, ox+bgW-MX)) return false;

    // ══════════════════════════════════════════════════════════════
    //  BLOCK 6 — EXPORT
    //  Nút toàn chiều rộng
    // ══════════════════════════════════════════════════════════════
    if(!AddBlockBg(6, ox, b6y1, ox + bgW, b6y2)) return false;

    if(!MakeBtn(m_btnExportCSV, "BtnExportCSV",
                ox+MX, yExp, ox+MX+W, yExp+BTN_H,
                "EXPORT CSV", CLR_TEXT_COMMENT, CLR_BTN_NEUTRAL)) return false;

    ChartRedraw(m_chart_id);
    return true;
}

//+------------------------------------------------------------------+
void CJINPAPanel::SetDependencies(string symbol, ulong magic,
                                   CRiskManager* rm, CPositionManager* pm, CTrade* pTrade,
                                   ENUM_MONEY_MANAGEMENT mm, double minLotSteps,
                                   double riskPct, double fixedLot, ushort poExpMin,
                                   ENUM_LOG_LEVEL logLevel)
{
    m_symbol      = symbol;
    m_magic       = magic;
    m_rm          = rm;
    m_pm          = pm;
    m_trade       = pTrade;
    m_mmType      = mm;
    m_minLotSteps = minLotSteps;
    m_riskPct     = riskPct;
    m_fixedLot    = fixedLot;
    m_poExpMin    = poExpMin;
    m_logLevel    = logLevel;

    m_cmbRiskM.SelectByValue((long)mm);
    m_log.Init(symbol, magic);
}

//+------------------------------------------------------------------+
void CJINPAPanel::UpdateMarketData(double atrSL, double atrPO, int slPoints, double dailyDD)
{
    m_atrSL    = atrSL;
    m_atrPO    = atrPO;
    m_slPoints = slPoints;
    m_dailyDD  = dailyDD;
}

//+------------------------------------------------------------------+
void CJINPAPanel::SetTradingHalt(bool halted, string reason)
{
    m_tradingHalted = halted;
    m_haltReason    = reason;
}

//+------------------------------------------------------------------+
void CJINPAPanel::RefreshVisuals()
{
    StyleDialogFrame();
    RestyleStaticObjects();
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
void CJINPAPanel::Tick()
{
    // Run() gán IDs nhưng không reset thuộc tính chart objects.
    // CPanel đã set màu và ZORDER đúng lúc Create()+Add(), nên không cần reapply.
    // Giữ lại ChartRedraw() để đảm bảo render sạch sau tick đầu tiên.
    static bool s_firstTick = false;
    if(!s_firstTick)
    {
        RefreshVisuals();
        s_firstTick = true;
    }

    Caption("jinpa-v2.1");

    // Refresh log mỗi 3 giây
    static datetime s_last = 0;
    if(TimeCurrent() - s_last >= 3)
    {
        RefreshLog();
        s_last = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
string CJINPAPanel::GetComment()
{
    long si = m_cmbSetup.Value();
    long xi = m_cmbSuffix.Value();
    if(si < 0 || si >= PANEL_SETUPS_COUNT)   return "";
    if(xi < 0 || xi >= PANEL_SUFFIXES_COUNT) return "";

    string base   = PANEL_SETUPS[(int)si] + PANEL_SUFFIXES[(int)xi];
    string custom = m_edtCustom.Text();
    return (custom != "" && custom != "_") ? base + custom : base;
}

//+------------------------------------------------------------------+
double CJINPAPanel::GetLotSize(ENUM_ORDER_TYPE dir)
{
    long mmVal = m_cmbRiskM.Value();
    ENUM_MONEY_MANAGEMENT mm = (mmVal >= 0 && mmVal <= 4) ?
                                (ENUM_MONEY_MANAGEMENT)(int)mmVal : m_mmType;

    bool   useATR = (m_cmbSL.Value() == PANEL_SL_ATR_IDX);
    double slDist = useATR ? m_atrSL : (m_slPoints * _Point);
    if(slDist <= 0) slDist = m_atrSL;

    return m_rm.MoneyManagement(m_symbol, mm, m_minLotSteps,
                                m_riskPct, slDist, m_fixedLot, dir);
}

//+------------------------------------------------------------------+
double CJINPAPanel::CalcSL(string dir, double basePrice)
{
    bool useATR = (m_cmbSL.Value() == PANEL_SL_ATR_IDX);
    if(useATR)
        return m_pm.CalculateStopLossByATR(m_symbol, dir, m_atrSL);

    if(dir == "BUY")  return basePrice - m_slPoints * _Point;
    else              return basePrice + m_slPoints * _Point;
}

//+------------------------------------------------------------------+
bool CJINPAPanel::IsWeekendFxLikeMarket()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(dt.day_of_week != 0 && dt.day_of_week != 6)
        return false;

    string base   = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
    string profit = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
    if(StringLen(base) != 3 || StringLen(profit) != 3)
        return false;

    string symbolName = m_symbol;
    string pairName   = base + profit;
    StringToUpper(symbolName);
    StringToUpper(pairName);

    return (StringFind(symbolName, pairName) >= 0);
}

//+------------------------------------------------------------------+
void CJINPAPanel::PlaceOrder(ENUM_ORDER_TYPE type)
{
    if(!m_trade || !m_rm || !m_pm)
    {
        Print("[Panel] Error: dependencies not set.");
        return;
    }

    if(m_tradingHalted)
    {
        Print("[Panel HALT] Order blocked: ", m_haltReason);
        return;
    }

    if(IsWeekendFxLikeMarket())
        Print("[Panel WARN] Weekend order attempt on ", m_symbol,
              " (FX/metal-like market). Today is Saturday/Sunday by broker server time. Please check before trading.");

    bool useATR    = (m_cmbSL.Value() == PANEL_SL_ATR_IDX);
    bool isPending = (type == ORDER_TYPE_BUY_STOP  || type == ORDER_TYPE_SELL_STOP ||
                      type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT);

    // Guard: ATR SL buffer not populated yet (happens on new charts or new bars)
    if(useATR && m_atrSL <= 0)
    {
        Print("[Panel] ATR SL not ready (atrSL=0) — wait a tick for indicator to load.");
        return;
    }
    // Guard: ATR PO offset = 0 makes pending price equal to current price → 10016
    if(isPending && m_atrPO <= 0)
    {
        Print("[Panel] ATR PO not ready (atrPO=0) — wait a tick for indicator to load.");
        return;
    }

    string   comment = GetComment();
    double   ask     = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    double   bid     = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    datetime exp     = TimeCurrent() + (datetime)m_poExpMin * 60;
    int      digits  = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    double   sl = 0, poPrice = 0, lot = 0;
    bool     traded = false;

    switch(type)
    {
        case ORDER_TYPE_BUY:
            sl  = CalcSL("BUY", ask);
            lot = GetLotSize(ORDER_TYPE_BUY);
            if(lot > 0) { m_trade.Buy(lot, m_symbol, ask, sl, 0, comment); traded = true; }
            break;

        case ORDER_TYPE_SELL:
            sl  = CalcSL("SELL", bid);
            lot = GetLotSize(ORDER_TYPE_SELL);
            if(lot > 0) { m_trade.Sell(lot, m_symbol, bid, sl, 0, comment); traded = true; }
            break;

        case ORDER_TYPE_BUY_STOP:
            poPrice = NormalizeDouble(ask + m_atrPO, digits);
            sl      = NormalizeDouble(poPrice - m_atrSL, digits);
            lot     = GetLotSize(ORDER_TYPE_BUY);
            if(lot > 0) { m_trade.BuyStop(lot, poPrice, m_symbol, sl, 0,
                                           ORDER_TIME_SPECIFIED, exp, comment); traded = true; }
            break;

        case ORDER_TYPE_SELL_STOP:
            poPrice = NormalizeDouble(bid - m_atrPO, digits);
            sl      = NormalizeDouble(poPrice + m_atrSL, digits);
            lot     = GetLotSize(ORDER_TYPE_SELL);
            if(lot > 0) { m_trade.SellStop(lot, poPrice, m_symbol, sl, 0,
                                            ORDER_TIME_SPECIFIED, exp, comment); traded = true; }
            break;

        case ORDER_TYPE_BUY_LIMIT:
            poPrice = NormalizeDouble(bid - m_atrPO, digits);
            sl      = NormalizeDouble(poPrice - m_atrSL, digits);
            lot     = GetLotSize(ORDER_TYPE_BUY);
            if(lot > 0) { m_trade.BuyLimit(lot, poPrice, m_symbol, sl, 0,
                                            ORDER_TIME_SPECIFIED, exp, comment); traded = true; }
            break;

        case ORDER_TYPE_SELL_LIMIT:
            poPrice = NormalizeDouble(ask + m_atrPO, digits);
            sl      = NormalizeDouble(poPrice + m_atrSL, digits);
            lot     = GetLotSize(ORDER_TYPE_SELL);
            if(lot > 0) { m_trade.SellLimit(lot, poPrice, m_symbol, sl, 0,
                                             ORDER_TIME_SPECIFIED, exp, comment); traded = true; }
            break;

        default: return;
    }

    if(traded)
    {
        LogResult(EnumToString(type));
        RefreshLog();
    }
    else
        Print("[Panel] Lot=0 — cannot place ", EnumToString(type),
              " | atrSL=", DoubleToString(m_atrSL, digits),
              " atrPO=", DoubleToString(m_atrPO, digits));
}

//+------------------------------------------------------------------+
void CJINPAPanel::LogResult(string action)
{
    if(m_logLevel == LOG_NONE || !m_trade) return;

    uint retcode = m_trade.ResultRetcode();
    bool ok = (retcode == TRADE_RETCODE_DONE        ||
               retcode == TRADE_RETCODE_PLACED       ||
               retcode == TRADE_RETCODE_DONE_PARTIAL ||
               retcode == TRADE_RETCODE_NO_CHANGES);

    if(ok && m_logLevel >= LOG_INFO)
        Print("[Panel OK] ", action, " | #", m_trade.ResultOrder(),
              " vol=", DoubleToString(m_trade.ResultVolume(), 2),
              " cmt=", GetComment());
    else if(!ok && m_logLevel >= LOG_ERROR)
        Print("[Panel ERR] ", action, " | ", retcode, ": ", m_trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
void CJINPAPanel::RefreshLog()
{
    m_log.Refresh();
    for(int i = 0; i < m_visibleLogRows; i++)
        m_logRows[i].Text((i < m_log.Count()) ? m_log.GetRow(i) : "");
    ChartRedraw();
}

//+--- Button handlers ─────────────────────────────────────────────+//

void CJINPAPanel::OnBuyMarket()   { m_btnBuyMkt.Pressed(false);    PlaceOrder(ORDER_TYPE_BUY); }
void CJINPAPanel::OnSellMarket()  { m_btnSellMkt.Pressed(false);   PlaceOrder(ORDER_TYPE_SELL); }
void CJINPAPanel::OnBuyStop()     { m_btnBuyStop.Pressed(false);   PlaceOrder(ORDER_TYPE_BUY_STOP); }
void CJINPAPanel::OnSellStop()    { m_btnSellStop.Pressed(false);  PlaceOrder(ORDER_TYPE_SELL_STOP); }
void CJINPAPanel::OnBuyLimit()    { m_btnBuyLimit.Pressed(false);  PlaceOrder(ORDER_TYPE_BUY_LIMIT); }
void CJINPAPanel::OnSellLimit()   { m_btnSellLimit.Pressed(false); PlaceOrder(ORDER_TYPE_SELL_LIMIT); }

void CJINPAPanel::OnCancelBO()
{
    m_btnCancelBO.Pressed(false);
    for(int i = OrdersTotal()-1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if(m_magic > 0 && OrderGetInteger(ORDER_MAGIC) != (long)m_magic) continue;
        ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_BUY_LIMIT)
            m_trade.OrderDelete(ticket);
    }
    RefreshLog();
}

void CJINPAPanel::OnCancelSO()
{
    m_btnCancelSO.Pressed(false);
    for(int i = OrdersTotal()-1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if(m_magic > 0 && OrderGetInteger(ORDER_MAGIC) != (long)m_magic) continue;
        ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(ot == ORDER_TYPE_SELL_STOP || ot == ORDER_TYPE_SELL_LIMIT)
            m_trade.OrderDelete(ticket);
    }
    RefreshLog();
}

void CJINPAPanel::OnCancelBuy()
{
    m_btnCancelBuy.Pressed(false);
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
        if(m_magic > 0 && PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            m_trade.PositionClose(ticket);
    }
    RefreshLog();
}

void CJINPAPanel::OnCancelSell()
{
    m_btnCancelSell.Pressed(false);
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
        if(m_magic > 0 && PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            m_trade.PositionClose(ticket);
    }
    RefreshLog();
}

void CJINPAPanel::OnExportCSV()
{
    m_btnExportCSV.Pressed(false);
    m_log.Refresh();
    string date = TimeToString(TimeCurrent(), TIME_DATE);
    StringReplace(date, ".", "-");
    m_log.ExportCSV("JINPA_v2_" + m_symbol + "_" + date + ".csv");
}

#endif
