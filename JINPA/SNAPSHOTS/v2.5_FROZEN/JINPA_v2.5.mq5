//+------------------------------------------------------------------+
//|                                                  JINPA_v2.5.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "2.50"
#property description "JINPA v2.5 - Manual Trading Assistant"
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
#include "_core/infrastructure/magic_number_resolver.mqh"
#include "_panel/panel_main.mqh"
#include "watch/WatchIntegration.mqh"

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
ulong            MagicNumber = 0;             // Resolved once per EA instance
string           CanonicalSymbol = "UNKNOWN";
CWatchIntegration watchIntegration;

int VolumeDigitsForSymbol(const string symbol)
{
    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int digits = 0;
    while(digits < 8 && MathAbs(step - MathRound(step)) > 1e-8)
    {
        step *= 10.0;
        digits++;
    }
    return digits;
}

string ExitReasonText(const ENUM_DEAL_REASON reason)
{
    if(reason == DEAL_REASON_SL) return "SL";
    if(reason == DEAL_REASON_TP) return "TP";
    if(reason == DEAL_REASON_CLIENT || reason == DEAL_REASON_MOBILE
       || reason == DEAL_REASON_WEB || reason == DEAL_REASON_EXPERT)
        return "Manual";
    return "Other";
}

bool IsJinpaPosition(const ulong positionId, const string symbol, const long closingDealMagic)
{
    if(closingDealMagic == (long)MagicNumber)
        return true;
    if(positionId == 0 || !HistorySelectByPosition(positionId))
        return false;

    const int deals = HistoryDealsTotal();
    for(int index = 0; index < deals; index++)
    {
        const ulong ticket = HistoryDealGetTicket(index);
        const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if((entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
           && HistoryDealGetString(ticket, DEAL_SYMBOL) == symbol
           && HistoryDealGetInteger(ticket, DEAL_MAGIC) == (long)MagicNumber)
            return true;
    }
    return false;
}

void LogExitDeal(const ulong dealTicket)
{
    if(dealTicket == 0 || !HistoryDealSelect(dealTicket))
        return;

    const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
        return;

    const string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
    const ulong positionId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
    const long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
    if(dealSymbol != _Symbol || !IsJinpaPosition(positionId, dealSymbol, dealMagic))
        return;

    const ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
    string originalSide;
    if(dealType == DEAL_TYPE_SELL)
        originalSide = "BUY";
    else if(dealType == DEAL_TYPE_BUY)
        originalSide = "SELL";
    else
        return;

    const double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
    const double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
    const ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
    const int priceDigits = (int)SymbolInfoInteger(dealSymbol, SYMBOL_DIGITS);

    Print("[JINPA][EXIT] ", originalSide,
          " | #", positionId,
          " | ", DoubleToString(volume, VolumeDigitsForSymbol(dealSymbol)),
          " | ", DoubleToString(price, priceDigits),
          " | ", ExitReasonText(reason));
}

//+------ TRADING SETTINGS ------+//
sinput group                              "────────────── BASIC SETTINGS ──────────────"
input double                              DisplayVirtualCapital     = 10000;  // Display Virtual Capital - 0 = Account Equity only
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
    const bool knownSymbol = CMagicNumberResolver::Resolve(_Symbol, MagicNumber,
                                                            CanonicalSymbol);
    if(!knownSymbol)
        Print("[JINPA][WARN] Unknown symbol ", _Symbol,
              " | using fallback Magic ", MagicNumber);

    trade.SetExpertMagicNumber(MagicNumber);
    trade.LogLevel(LOG_LEVEL_ERRORS);

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
    // Chừa vùng comment trạng thái/Magic ở đỉnh chart; giá trị là pixel chart trực tiếp.
    int panelY = 40;

    // panelH: tự động co giãn theo chiều cao chart.
    // Không ép MIN_PANEL_H ở đây để panel không bị cắt khi MT5 chia nhiều chart.
    int panelW = ScaleUI(PANEL_W);
    int panelH = chartH - panelY - ScaleUI(4);
    if(panelH < ScaleUI(260))
        panelH = ScaleUI(260);
    if((long)TerminalInfoInteger(TERMINAL_SCREEN_DPI) < JINPA_UI_REFERENCE_DPI)
        panelH = MathMin(panelH, ScaleUI(MIN_PANEL_H));

    if(!g_panel.Create(0, "JINPA v2.5", 0, panelX, panelY, panelX + panelW, panelY + panelH))
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

    if(!watchIntegration.Initialize(_Symbol, (ENUM_TIMEFRAMES)_Period))
        Print("[JINPA][WARN] Structure integration disabled — initialization failed.");

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
    Print("JINPA v2.5 initialized successfully.");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    g_panel.Destroy(reason);
    infoDisplay.ClearDisplay();
    watchIntegration.Shutdown();
    Print("JINPA v2.5 stopped — reason: ", reason);
}

void OnTick()
{
    watchIntegration.ProcessTick();

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

    if(id == CHARTEVENT_CHART_CHANGE)
        watchIntegration.OnChartChange();
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

    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        LogExitDeal(trans.deal);
}
