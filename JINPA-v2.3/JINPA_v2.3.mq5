//+------------------------------------------------------------------+
//|                                                  JINPA_v2.3.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "2.30"
#property description "JINPA v2.3 - Manual Trading Assistant"
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
input double                              DisplayVirtualCapital     = 10000;  // Display Virtual Capital - 0 = Account Equity only
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
input double                                ATRFactorSL                 = 2.5;   // Factor for initial Stop Loss
input double                                ATRFactorTSL                = 3.5;   // Factor for Trailing Stop distance
input double                                ATRFactorPO                 = 2.5;   // Factor (Pending Order offset)

sinput group                              "──────────── TRAILING STOP ─────────────────"
input ENUM_TSL_MODE            TSLMode          = TSL_STEP;
input double                              TSLActivationATR = 2.5;
input double                              TSLStepATR       = 2.5;   // Minimum ATR move between TSL updates

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

    int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    SetUIScaleOverride(GetChartAwareUIScale(chartW, chartH));

    // ── Tính vị trí và kích thước panel ────────────────────────────
    // panelX: khoảng cách từ cạnh trái chart đến cạnh trái panel (px)
    int panelX = ScaleUI(20);

    // panelY: khoảng cách từ đỉnh chart đến đỉnh panel (px)
    // Đặt ngay dưới thanh symbol/timeframe của MT5 (~20px từ trên)
    int panelY = ScaleUI(20);

    // panelH: tự động co giãn theo chiều cao chart.
    // Không ép MIN_PANEL_H ở đây để panel không bị cắt khi MT5 chia nhiều chart.
    int panelW = ScaleUI(PANEL_W);
    int panelH = chartH - panelY - ScaleUI(4);
    if(panelH < ScaleUI(260))
        panelH = ScaleUI(260);
    if((long)TerminalInfoInteger(TERMINAL_SCREEN_DPI) < JINPA_UI_REFERENCE_DPI)
        panelH = MathMin(panelH, ScaleUI(MIN_PANEL_H));

    if(!g_panel.Create(0, "JINPA v2.3", 0, panelX, panelY, panelX + panelW, panelY + panelH))
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

    Print("[JINPA INPUT 1/3] Symbol=", _Symbol,
          " | Magic=", MagicNumber,
          " | POExpMin=", POExpirationMinutes,
          " | MaxDD=", DoubleToString(MaxDrawdownDaily, 2), "%");
    Print("[JINPA INPUT 2/3] MM=", EnumToString(MoneyManagement),
          " | Risk=", DoubleToString(RiskPercent, 2), "%",
          " | FixedLot=", DoubleToString(FixedVolume, 2),
          " | MinLotEqStep=", DoubleToString(MinLotPerEquitySteps, 2),
          " | DisplayVC=", DoubleToString(DisplayVirtualCapital, 2),
          " | SLPoints=", slPointsValue);
    Print("[JINPA INPUT 3/3] MA=", IntegerToString(MAPeriod), "/", EnumToString(MAMethod),
          " | ATR=", IntegerToString(ATRPeriod),
          " | ATRFactorSL=", DoubleToString(ATRFactorSL, 2),
          " | ATRFactorTSL=", DoubleToString(ATRFactorTSL, 2),
          " | ATRFactorPO=", DoubleToString(ATRFactorPO, 2),
          " | TSL=", EnumToString(TSLMode),
          " | LogLevel=", EnumToString(LogLevel));
    Print("JINPA v2.3 initialized successfully.");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    g_panel.Destroy(reason);
    infoDisplay.ClearDisplay();
    Print("JINPA v2.3 stopped — reason: ", reason);
}

void OnTick()
{
    //──────────────────────────────────────────────────────────────────
    // 1 - REFRESH INDICATORS
    //──────────────────────────────────────────────────────────────────
    MA.RefreshMain();
    ATR.RefreshMain();

    double atrValue   = ATR.main[1] * ATRFactorSL;  // Initial Stop Loss
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
    infoDisplay.UpdatePoolSummary(_Symbol, MagicNumber, RiskPercent, dailyDD, DisplayVirtualCapital);
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
    PM.TrailingStopLossByATR(_Symbol, MagicNumber, ATR.main[1], ATRFactorTSL,
                             TSLMode, TSLActivationATR, TSLStepATR);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    g_panel.ChartEvent(id, lparam, dparam, sparam);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    if(trans.type == TRADE_TRANSACTION_HISTORY_ADD && trans.order > 0)
    {
        if(!HistoryOrderSelect(trans.order))
            return;

        string orderSymbol = HistoryOrderGetString(trans.order, ORDER_SYMBOL);
        if(orderSymbol != _Symbol)
            return;

        long orderMagic = HistoryOrderGetInteger(trans.order, ORDER_MAGIC);
        if(MagicNumber > 0 && orderMagic != (long)MagicNumber)
            return;

        ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)HistoryOrderGetInteger(trans.order, ORDER_STATE);
        if(orderState == ORDER_STATE_EXPIRED)
        {
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(trans.order, ORDER_TYPE);
            datetime expiration = (datetime)HistoryOrderGetInteger(trans.order, ORDER_TIME_EXPIRATION);

            Print("[Order EXPIRED] #", trans.order,
                  " | ", orderSymbol,
                  " | Type=", EnumToString(orderType),
                  " | Vol=", DoubleToString(HistoryOrderGetDouble(trans.order, ORDER_VOLUME_INITIAL), 2),
                  " | Price=", DoubleToString(HistoryOrderGetDouble(trans.order, ORDER_PRICE_OPEN), _Digits),
                  " | Exp=", TimeToString(expiration, TIME_DATE | TIME_MINUTES));
        }

        return;
    }

    if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
        return;

    if(!HistoryDealSelect(trans.deal))
        return;

    string dealSymbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
    if(dealSymbol != _Symbol)
        return;

    long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
    if(MagicNumber > 0 && dealMagic != (long)MagicNumber)
        return;

    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
        return;

    ENUM_DEAL_TYPE   type   = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
    ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);

    Print("[Deal CLOSED] Deal #", trans.deal,
          " | Pos #", (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID),
          " | ", dealSymbol,
          " | Type=", EnumToString(type),
          " | Reason=", EnumToString(reason),
          " | Vol=", DoubleToString(HistoryDealGetDouble(trans.deal, DEAL_VOLUME), 2),
          " | Price=", DoubleToString(HistoryDealGetDouble(trans.deal, DEAL_PRICE), _Digits),
          " | Profit=", DoubleToString(HistoryDealGetDouble(trans.deal, DEAL_PROFIT), 2));
}
