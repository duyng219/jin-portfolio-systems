//+------------------------------------------------------------------+
//| TestPanel.mqh                                                    |
//| Lightweight manual interaction UI for JINPA v3.2 TEST mode      |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_TEST_PANEL_MQH
#define JINPA_TEST_PANEL_MQH

#include <Controls/Button.mqh>
#include "../_panel/panel_defines.mqh"
#include "TestCommentResolver.mqh"
#include "../trade/ManualTradeController.mqh"

#define JINPA_TEST_LEGACY_TITLE "JINPA_TEST_PANEL_TITLE"
#define JINPA_TEST_BUY_MARKET  "JINPA_TEST_PANEL_BUY_MARKET"
#define JINPA_TEST_SELL_MARKET "JINPA_TEST_PANEL_SELL_MARKET"
#define JINPA_TEST_BUY_STOP    "JINPA_TEST_PANEL_BUY_STOP"
#define JINPA_TEST_SELL_STOP   "JINPA_TEST_PANEL_SELL_STOP"
#define JINPA_TEST_BUY_LIMIT   "JINPA_TEST_PANEL_BUY_LIMIT"
#define JINPA_TEST_SELL_LIMIT  "JINPA_TEST_PANEL_SELL_LIMIT"
#define JINPA_TEST_CANCEL_BUY  "JINPA_TEST_PANEL_CANCEL_BUY"
#define JINPA_TEST_CANCEL_SELL "JINPA_TEST_PANEL_CANCEL_SELL"
#define JINPA_TEST_CLOSE_BUY   "JINPA_TEST_PANEL_CLOSE_BUY"
#define JINPA_TEST_CLOSE_SELL  "JINPA_TEST_PANEL_CLOSE_SELL"

struct STestPanelConfig
{
    ENUM_MONEY_MANAGEMENT moneyManagement;
    double                minLotPerEquitySteps;
    double                riskPercent;
    double                fixedVolume;
    ushort                pendingExpirationMinutes;
    int                   stopLossPoints;
    int                   logLevel;
};

class CTestPanel
{
private:
    long                    m_chart;
    int                     m_subwindow;
    bool                    m_initialized;
    bool                    m_recoveryPending;
    bool                    m_tradingHalted;
    string                  m_haltReason;
    double                  m_atrSL;
    double                  m_atrPO;
    int                     m_stopLossPoints;
    STestPanelConfig        m_config;
    CManualTradeController* m_controller;
    CTestCommentResolver*   m_commentResolver;

    CButton m_buyMarket;
    CButton m_sellMarket;
    CButton m_buyStop;
    CButton m_sellStop;
    CButton m_buyLimit;
    CButton m_sellLimit;
    CButton m_cancelBuy;
    CButton m_cancelSell;
    CButton m_closeBuy;
    CButton m_closeSell;

    bool CreateButton(CButton &button,
                      const string name,
                      const string text,
                      const int x1,
                      const int y1,
                      const int x2,
                      const int y2,
                      const color background,
                      const int fontSize);
    bool CreateObjects();
    void DestroyObjects(const int reason);
    bool AreObjectsPresent() const;
    bool IsOwnedObject(const string name) const;
    void RecoverIfNeeded();
    void PlaceOrder(const ENUM_ORDER_TYPE orderType);
    void ProcessActions();

public:
    CTestPanel();
    bool Initialize(const long chart,
                    const int subwindow,
                    CManualTradeController* controller,
                    CTestCommentResolver* commentResolver,
                    const STestPanelConfig &config);
    void Shutdown(const int reason);
    void SetTradingHalt(const bool halted, const string reason = "");
    void UpdateMarketData(const double atrSL,
                          const double atrPO,
                          const int stopLossPoints,
                          const double dailyDD);
    void Tick();
    void OnChartEvent(const int id,
                      const long &lparam,
                      const double &dparam,
                      const string &sparam);
};

CTestPanel::CTestPanel() :
    m_chart(0),
    m_subwindow(0),
    m_initialized(false),
    m_recoveryPending(false),
    m_tradingHalted(false),
    m_haltReason(""),
    m_atrSL(0.0),
    m_atrPO(0.0),
    m_stopLossPoints(0),
    m_controller(NULL),
    m_commentResolver(NULL)
{
}

bool CTestPanel::CreateButton(CButton &button,
                              const string name,
                              const string text,
                              const int x1,
                              const int y1,
                              const int x2,
                              const int y2,
                              const color background,
                              const int fontSize)
{
    if(!button.Create(m_chart, name, m_subwindow, x1, y1, x2, y2))
        return false;
    button.Text(text);
    button.Color(C'225,230,238');
    button.ColorBackground(background);
    button.ColorBorder(C'70,82,98');
    button.Font("Consolas");
    button.FontSize(fontSize);
    ObjectSetInteger(m_chart, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    return true;
}

bool CTestPanel::CreateObjects()
{
    const int buttonWidth  = ScaleUI(132);
    const int buttonHeight = ScaleUI(30);
    const int left         = ScaleUI(5);
    const int top          = ScaleUI(45);
    const int columnGap    = ScaleUI(4);
    const int rowGap       = ScaleUI(2);
    const int rowStep      = buttonHeight + rowGap;
    const int rightColumn  = left + buttonWidth + columnGap;
    const int fontSize     = ScaleFont(8);

    // Remove the retired P3 title if an older build left it on the chart.
    if(ObjectFind(m_chart, JINPA_TEST_LEGACY_TITLE) >= 0)
        ObjectDelete(m_chart, JINPA_TEST_LEGACY_TITLE);

    const color buyColor = C'20,58,47';
    const color sellColor = C'67,31,37';
    const color neutralColor = C'23,29,38';

    if(!CreateButton(m_buyMarket, JINPA_TEST_BUY_MARKET, "BUY MKT",
                     left, top, left + buttonWidth, top + buttonHeight,
                     buyColor, fontSize)) return false;
    if(!CreateButton(m_sellMarket, JINPA_TEST_SELL_MARKET, "SELL MKT",
                     rightColumn, top, rightColumn + buttonWidth, top + buttonHeight,
                     sellColor, fontSize)) return false;
    if(!CreateButton(m_buyStop, JINPA_TEST_BUY_STOP, "BUY STOP",
                     left, top + rowStep, left + buttonWidth, top + rowStep + buttonHeight,
                     buyColor, fontSize)) return false;
    if(!CreateButton(m_sellStop, JINPA_TEST_SELL_STOP, "SELL STOP",
                     rightColumn, top + rowStep, rightColumn + buttonWidth, top + rowStep + buttonHeight,
                     sellColor, fontSize)) return false;
    if(!CreateButton(m_buyLimit, JINPA_TEST_BUY_LIMIT, "BUY LIMIT",
                     left, top + 2 * rowStep, left + buttonWidth, top + 2 * rowStep + buttonHeight,
                     buyColor, fontSize)) return false;
    if(!CreateButton(m_sellLimit, JINPA_TEST_SELL_LIMIT, "SELL LIMIT",
                     rightColumn, top + 2 * rowStep, rightColumn + buttonWidth, top + 2 * rowStep + buttonHeight,
                     sellColor, fontSize)) return false;
    if(!CreateButton(m_cancelBuy, JINPA_TEST_CANCEL_BUY, "CANCEL BUY",
                     left, top + 3 * rowStep,
                     left + buttonWidth, top + 3 * rowStep + buttonHeight,
                     neutralColor, fontSize)) return false;
    if(!CreateButton(m_cancelSell, JINPA_TEST_CANCEL_SELL, "CANCEL SELL",
                     rightColumn, top + 3 * rowStep,
                     rightColumn + buttonWidth, top + 3 * rowStep + buttonHeight,
                     neutralColor, fontSize)) return false;
    if(!CreateButton(m_closeBuy, JINPA_TEST_CLOSE_BUY, "CLOSE BUY",
                     left, top + 4 * rowStep,
                     left + buttonWidth, top + 4 * rowStep + buttonHeight,
                     neutralColor, fontSize)) return false;
    if(!CreateButton(m_closeSell, JINPA_TEST_CLOSE_SELL, "CLOSE SELL",
                     rightColumn, top + 4 * rowStep,
                     rightColumn + buttonWidth, top + 4 * rowStep + buttonHeight,
                     neutralColor, fontSize)) return false;

    ObjectSetString(m_chart, JINPA_TEST_CANCEL_BUY, OBJPROP_TOOLTIP,
                    "Cancel all matching Buy-side pending orders");
    ObjectSetString(m_chart, JINPA_TEST_CANCEL_SELL, OBJPROP_TOOLTIP,
                    "Cancel all matching Sell-side pending orders");
    ObjectSetString(m_chart, JINPA_TEST_CLOSE_BUY, OBJPROP_TOOLTIP,
                    "Close all matching Buy positions");
    ObjectSetString(m_chart, JINPA_TEST_CLOSE_SELL, OBJPROP_TOOLTIP,
                    "Close all matching Sell positions");
    ChartRedraw(m_chart);
    return true;
}

void CTestPanel::DestroyObjects(const int reason)
{
    if(ObjectFind(m_chart, JINPA_TEST_LEGACY_TITLE) >= 0)
        ObjectDelete(m_chart, JINPA_TEST_LEGACY_TITLE);
    m_buyMarket.Destroy(reason);
    m_sellMarket.Destroy(reason);
    m_buyStop.Destroy(reason);
    m_sellStop.Destroy(reason);
    m_buyLimit.Destroy(reason);
    m_sellLimit.Destroy(reason);
    m_cancelBuy.Destroy(reason);
    m_cancelSell.Destroy(reason);
    m_closeBuy.Destroy(reason);
    m_closeSell.Destroy(reason);
}

bool CTestPanel::AreObjectsPresent() const
{
    return ObjectFind(m_chart, JINPA_TEST_BUY_MARKET) >= 0
           && ObjectFind(m_chart, JINPA_TEST_SELL_MARKET) >= 0
           && ObjectFind(m_chart, JINPA_TEST_BUY_STOP) >= 0
           && ObjectFind(m_chart, JINPA_TEST_SELL_STOP) >= 0
           && ObjectFind(m_chart, JINPA_TEST_BUY_LIMIT) >= 0
           && ObjectFind(m_chart, JINPA_TEST_SELL_LIMIT) >= 0
           && ObjectFind(m_chart, JINPA_TEST_CANCEL_BUY) >= 0
           && ObjectFind(m_chart, JINPA_TEST_CANCEL_SELL) >= 0
           && ObjectFind(m_chart, JINPA_TEST_CLOSE_BUY) >= 0
           && ObjectFind(m_chart, JINPA_TEST_CLOSE_SELL) >= 0;
}

bool CTestPanel::IsOwnedObject(const string name) const
{
    return StringFind(name, "JINPA_TEST_PANEL_") == 0;
}

void CTestPanel::RecoverIfNeeded()
{
    if(!m_recoveryPending && AreObjectsPresent())
        return;

    m_recoveryPending = false;
    DestroyObjects(REASON_CHARTCHANGE);
    if(!CreateObjects())
        Print("[JINPA][TEST_PANEL][ERROR] Object recovery failed.");
}

bool CTestPanel::Initialize(const long chart,
                            const int subwindow,
                            CManualTradeController* controller,
                            CTestCommentResolver* commentResolver,
                            const STestPanelConfig &config)
{
    if(controller == NULL || !controller.IsReady() || commentResolver == NULL)
        return false;

    m_chart            = chart;
    m_subwindow        = subwindow;
    m_controller       = controller;
    m_commentResolver  = commentResolver;
    m_config           = config;
    m_stopLossPoints   = config.stopLossPoints;
    m_tradingHalted    = false;
    m_haltReason       = "";
    m_recoveryPending  = false;
    m_initialized      = CreateObjects();
    if(!m_initialized)
        DestroyObjects(REASON_INITFAILED);
    return m_initialized;
}

void CTestPanel::Shutdown(const int reason)
{
    if(m_initialized)
        DestroyObjects(reason);
    m_initialized = false;
    m_recoveryPending = false;
}

void CTestPanel::SetTradingHalt(const bool halted, const string reason)
{
    m_tradingHalted = halted;
    m_haltReason = reason;
}

void CTestPanel::UpdateMarketData(const double atrSL,
                                  const double atrPO,
                                  const int stopLossPoints,
                                  const double dailyDD)
{
    m_atrSL = atrSL;
    m_atrPO = atrPO;
    m_stopLossPoints = stopLossPoints;
}

void CTestPanel::PlaceOrder(const ENUM_ORDER_TYPE orderType)
{
    if(m_tradingHalted)
    {
        Print("[JINPA][WARN] TEST order blocked | ", m_haltReason);
        return;
    }

    SManualTradeRequest request;
    request.orderType                = orderType;
    request.moneyManagement          = m_config.moneyManagement;
    request.minLotPerEquitySteps     = m_config.minLotPerEquitySteps;
    request.riskPercent              = m_config.riskPercent;
    request.fixedVolume              = m_config.fixedVolume;
    request.useATRStopLoss           = (m_stopLossPoints <= 0);
    request.stopLossPoints           = m_stopLossPoints;
    request.atrStopLoss              = m_atrSL;
    request.atrPendingOffset         = m_atrPO;
    request.pendingExpirationMinutes = m_config.pendingExpirationMinutes;
    request.logLevel                 = m_config.logLevel;
    request.comment                  = m_commentResolver.Resolve(orderType);

    m_controller.Execute(request);
}

void CTestPanel::ProcessActions()
{
    if(m_buyMarket.Pressed())
    {
        m_buyMarket.Pressed(false);
        PlaceOrder(ORDER_TYPE_BUY);
    }
    if(m_sellMarket.Pressed())
    {
        m_sellMarket.Pressed(false);
        PlaceOrder(ORDER_TYPE_SELL);
    }
    if(m_buyStop.Pressed())
    {
        m_buyStop.Pressed(false);
        PlaceOrder(ORDER_TYPE_BUY_STOP);
    }
    if(m_sellStop.Pressed())
    {
        m_sellStop.Pressed(false);
        PlaceOrder(ORDER_TYPE_SELL_STOP);
    }
    if(m_buyLimit.Pressed())
    {
        m_buyLimit.Pressed(false);
        PlaceOrder(ORDER_TYPE_BUY_LIMIT);
    }
    if(m_sellLimit.Pressed())
    {
        m_sellLimit.Pressed(false);
        PlaceOrder(ORDER_TYPE_SELL_LIMIT);
    }
    if(m_cancelBuy.Pressed())
    {
        m_cancelBuy.Pressed(false);
        m_controller.CancelBuyPending(m_config.logLevel);
    }
    if(m_cancelSell.Pressed())
    {
        m_cancelSell.Pressed(false);
        m_controller.CancelSellPending(m_config.logLevel);
    }
    if(m_closeBuy.Pressed())
    {
        m_closeBuy.Pressed(false);
        m_controller.CloseBuyPositions(m_config.logLevel);
    }
    if(m_closeSell.Pressed())
    {
        m_closeSell.Pressed(false);
        m_controller.CloseSellPositions(m_config.logLevel);
    }
}

void CTestPanel::Tick()
{
    if(!m_initialized)
        return;
    RecoverIfNeeded();
    ProcessActions();
}

void CTestPanel::OnChartEvent(const int id,
                              const long &lparam,
                              const double &dparam,
                              const string &sparam)
{
    if(!m_initialized)
        return;

    m_buyMarket.OnEvent(id, lparam, dparam, sparam);
    m_sellMarket.OnEvent(id, lparam, dparam, sparam);
    m_buyStop.OnEvent(id, lparam, dparam, sparam);
    m_sellStop.OnEvent(id, lparam, dparam, sparam);
    m_buyLimit.OnEvent(id, lparam, dparam, sparam);
    m_sellLimit.OnEvent(id, lparam, dparam, sparam);
    m_cancelBuy.OnEvent(id, lparam, dparam, sparam);
    m_cancelSell.OnEvent(id, lparam, dparam, sparam);
    m_closeBuy.OnEvent(id, lparam, dparam, sparam);
    m_closeSell.OnEvent(id, lparam, dparam, sparam);

    if(id == CHARTEVENT_CHART_CHANGE
       || (id == CHARTEVENT_OBJECT_DELETE && IsOwnedObject(sparam)))
        m_recoveryPending = true;
}

#endif // JINPA_TEST_PANEL_MQH
