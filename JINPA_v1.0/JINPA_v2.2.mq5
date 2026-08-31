//+------------------------------------------------------------------+
//|                                                  JINPA_v2.2.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "2.20"
#property description "JINPA v2.2 - Manual Trading Assistant"
#property description ""
#property description "Price Action based manual trading with CAppDialog panel — comment auto-assign per setup"
#property strict

//+------ INCLUDES ------+//
#include <Trade/Trade.mqh>
#include "_core/managers/indicators_manager.mqh"
#include "_core/managers/bar_manager.mqh"
#include "_core/managers/risk_manager.mqh"
#include "_core/managers/drawdown_manager.mqh"
#include "_core/managers/position_manager.mqh"
#include "_core/infrastructure/info_display.mqh"
#include "_panel/panel_main.mqh"

//+------ GLOBAL OBJECTS ------+//
CTrade           trade;
CRiskManager     RM;
CPositionManager PM;
CBar             Bar;
CiATR            ATR;
CiMA             MA;
CDrawdownManager drawdownManager;
CInfoDisplay     infoDisplay;
CJINPAPanel      g_panel;

//+------ TRADING SETTINGS ------+//
sinput group                              "────────────── BASIC SETTINGS ──────────────"
input ulong                               MagicNumber                   = 1010;   // Magic Number
input int                                    slPointsValue                      = 0;      // Stop Loss Points - 0 = Use ATR
input ushort                              POExpirationMinutes       = 360;    // Pending Order Expiration (minutes)
input double                             MaxDrawdownDaily           = 0;      // Max Daily Drawdown (%) - 0 = Disabled

sinput group                              "────────────── RISK MANAGEMENT ────────────"
input ENUM_MONEY_MANAGEMENT    MoneyManagement      = MM_EQUITY_RISK_PERCENT; // Risk Method
input double                              RiskPercent                      = 0.5;   // Risk per Trade (%)
input double                              FixedVolume                    = 0.01;  // Fixed Lot Size
input double                              MinLotPerEquitySteps      = 500;   // Equity per Lot

sinput group                              "────────────── MOVING AVERAGE ─────────────"
input int                                       MAPeriod             = 21;
input ENUM_MA_METHOD         MAMethod          = MODE_EMA;
input int                                       MAShift                = 0;
input ENUM_APPLIED_PRICE       MAPrice               = PRICE_CLOSE;

sinput group                              "─────────────── ATR SETTINGS ──────────────"
input int                                       ATRPeriod                     = 14;
input double                                ATRFactor                      = 2;   // Factor (SL & Trailing SL)
input double                                ATRFactorPO                 = 2;   // Factor (Pending Order offset)

sinput group                              "──────────── TRAILING STOP ─────────────────"
input ENUM_TSL_MODE            TSLMode          = TSL_STEP;
input double                              TSLActivationATR = 1.0;
input double                              TSLStepATR       = 1.0;

sinput group                              "────────────────── LOGGING ─────────────────"
input ENUM_LOG_LEVEL             LogLevel = LOG_INFO;

int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);

    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Alert("Trading is disabled in Terminal!");
        return INIT_FAILED;
    }

    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Alert("EA not allowed to trade! Please enable AutoTrading.");
        return INIT_FAILED;
    }

    if(!SymbolSelect(_Symbol, true))
    {
        Alert("Failed to select symbol: ", _Symbol);
        return INIT_FAILED;
    }

    Print("Symbol — Min Vol: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
          " | Max Vol: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
          " | Step: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));

    if(MA.Init(_Symbol, _Period, MAPeriod, MAShift, MAMethod, MAPrice) == -1)
    {
        Alert("MA indicator initialization failed!");
        return INIT_FAILED;
    }

    if(ATR.Init(_Symbol, _Period, ATRPeriod) == -1)
    {
        Alert("ATR indicator initialization failed!");
        return INIT_FAILED;
    }

    // ── Tính vị trí và kích thước panel ────────────────────────────
    // panelX: khoảng cách từ cạnh trái chart đến cạnh trái panel (px)
    int panelX = 20;

    // panelY: khoảng cách từ đỉnh chart đến đỉnh panel (px)
    // Đặt ngay dưới thanh symbol/timeframe của MT5 (~20px từ trên)
    int panelY = 20;

    // chartH: chiều cao vùng chart chính (subwindow 0) tính bằng px
    // Không bao gồm các indicator subwindow bên dưới
    int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

    // panelH: tự động co giãn theo chiều cao chart.
    // Không ép MIN_PANEL_H ở đây để panel không bị cắt khi MT5 chia nhiều chart.
    int panelH = chartH - panelY - 4;
    if(panelH < 260)
        panelH = 260;

    if(!g_panel.Create(0, "JINPA v2.2", 0, panelX, panelY, panelX + PANEL_W, panelY + panelH))
    {
        Alert("Panel creation failed!");
        return INIT_FAILED;
    }

    // Wire panel tới các dependencies
    g_panel.SetDependencies(_Symbol, MagicNumber,
                            &RM, &PM, &trade,
                            MoneyManagement, MinLotPerEquitySteps,
                            RiskPercent, FixedVolume, POExpirationMinutes,
                            LogLevel);

    g_panel.Run();  // bắt buộc để CAppDialog xử lý events
    g_panel.RefreshVisuals();

    Print("JINPA v2.2 initialized successfully.");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    g_panel.Destroy(reason);
    infoDisplay.ClearDisplay();
    Print("JINPA v2.2 stopped — reason: ", reason);
}

void OnTick()
{
    //──────────────────────────────────────────────────────────────────
    // 1 - REFRESH INDICATORS
    //──────────────────────────────────────────────────────────────────
    MA.RefreshMain();
    ATR.RefreshMain();

    double atrValue   = ATR.main[1] * ATRFactor;    // SL & Trailing SL
    double atrValuePO = ATR.main[0] * ATRFactorPO;  // Pending order offset

    //──────────────────────────────────────────────────────────────────
    // 2 - GET MARKET PRICES
    //──────────────────────────────────────────────────────────────────
    Bar.Refresh(_Symbol, PERIOD_CURRENT, 6);
    double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    //──────────────────────────────────────────────────────────────────
    // 3 - UPDATE DRAWDOWN TRACKING
    //──────────────────────────────────────────────────────────────────
    drawdownManager.UpdateDaily();

    double dailyDD = drawdownManager.GetDailyPercent();
    bool   dailyHalt = (MaxDrawdownDaily > 0 && dailyDD <= -MaxDrawdownDaily);

    if(dailyHalt)
    {
        Comment("Max Daily DD reached: ", DoubleToString(MathAbs(dailyDD), 2), "% — Trading Halted!");
    }
    else
        g_panel.SetTradingHalt(false);

    //──────────────────────────────────────────────────────────────────
    // 4 - UPDATE INFORMATION DISPLAY
    //──────────────────────────────────────────────────────────────────
    infoDisplay.UpdatePoolSummary(_Symbol, MagicNumber, RiskPercent, dailyDD);
    infoDisplay.UpdateButtonTooltips(askPrice, bidPrice);

    //──────────────────────────────────────────────────────────────────
    // 5 - UPDATE PANEL + PERIODIC LOG REFRESH
    //──────────────────────────────────────────────────────────────────
    g_panel.UpdateMarketData(atrValue, atrValuePO, slPointsValue, dailyDD);
    if(dailyHalt)
        g_panel.SetTradingHalt(true, "Max Daily DD reached: " + DoubleToString(MathAbs(dailyDD), 2) + "%");
    g_panel.Tick();

    //──────────────────────────────────────────────────────────────────
    // 6 - TRAILING STOP LOSS
    //──────────────────────────────────────────────────────────────────
    PM.TrailingStopLossByATR(_Symbol, MagicNumber, ATR.main[1], ATRFactor,
                             TSLMode, TSLActivationATR, TSLStepATR);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    g_panel.ChartEvent(id, lparam, dparam, sparam);
}
