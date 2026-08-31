//+------------------------------------------------------------------+
//|                                                 jinpa-manual.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "1.00"
#property description "JINPA - Manual Trading Assistant"
#property description ""
#property description "Price Action based manual trading with one-click order entry and ATR risk management"
#property strict

//+------ INCLUDES ------+//
#include <Trade/Trade.mqh>
#include "_core/framework_manager.mqh"

//+------ GLOBAL OBJECTS ------+//
CTrade                           trade;                              // MT5 built-in trade object (dùng cho tất cả orders)
CRiskManager               RM;                                 // Tính lot size
CPositionManager         PM;                                // SL/TP, Trailing Stop
CBar                               Bar;                                // Bar OHLCV data
CiATR                             ATR;                               // ATR indicator
CiMA                              MA;                                // Moving Average indicator
CUIManager                  uiManager;                     // 10 buttons trên chart
CDrawdownManager    drawdownManager;       // Theo dõi drawdown ngày/tháng
COrderExecutor             orderExecutor;               // Bridge UI → orders
CInfoDisplay                  infoDisplay;                    // Stats display

//+------ TRADING SETTINGS ------+//
sinput group                              "────────────── BASIC SETTINGS ──────────────"
input ulong                               MagicNumber                   = 1010;   // Magic Number
input int                                    slPointsValue                      = 0;      // Stop Loss Points - 0 = Use ATR
input ushort                              POExpirationMinutes       = 360;    // Pending Order Expiration (minutes)
input double                             MaxDrawdownDaily           = 0;      // Max Daily Drawdown (%) - 0 = Disabled

sinput group                              "────────────── RISK MANAGEMENT ────────────"
input ENUM_MONEY_MANAGEMENT    MoneyManagement      = MM_EQUITY_RISK_PERCENT; // Risk Method
input double                              RiskPercent                      = 0.5;   // Risk per Trade (%) - 0.1 to 5
input double                              FixedVolume                    = 0.01;  // Fixed Lot Size (when using fixed MM)
input double                              MinLotPerEquitySteps      = 500;   // Equity per Lot (e.g. 500 USD = 0.01 lot)

sinput group                              "────────────── MOVING AVERAGE ─────────────"
input int                                       MAPeriod             = 21;          // Period
input ENUM_MA_METHOD         MAMethod          = MODE_EMA;    // Type
input int                                       MAShift                = 0;           // Shift
input ENUM_APPLIED_PRICE       MAPrice               = PRICE_CLOSE; // Applied Price

sinput group                              "─────────────── ATR SETTINGS ──────────────"
input int                                       ATRPeriod                     = 14;  // Period
input double                                ATRFactor                      = 2;   // Factor (for SL & Trailing SL)
input double                                ATRFactorPO                 = 2;   // Factor (for Pending Order)

sinput group                              "──────────── TRAILING STOP ─────────────────"
input ENUM_TSL_MODE            TSLMode          = TSL_CONTINUOUS; // Trailing Stop Mode
input double                              TSLActivationATR = 1.0;            // Breakeven First: kích hoạt sau X ATR lãi
input double                              TSLStepATR       = 1.0;            // Step: dịch SL tối thiểu X ATR mỗi bước

sinput group                              "────────────────── LOGGING ─────────────────"
input ENUM_LOG_LEVEL             LogLevel = LOG_INFO;              // Log Level

int OnInit()
{
    // Set magic number trên CTrade — áp dụng cho tất cả orders
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

    uiManager.Initialize();
    Sleep(100);

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

    SOrderExecutorParams params;
    params.magicNumber          = MagicNumber;
    params.moneyManagement      = MoneyManagement;
    params.minLotPerEquitySteps = MinLotPerEquitySteps;
    params.riskPercent          = RiskPercent;
    params.fixedVolume          = FixedVolume;
    params.poExpirationMinutes  = POExpirationMinutes;
    params.logLevel             = LogLevel;

    orderExecutor.Initialize(_Symbol, &RM, &PM, &trade, &uiManager, params);

    Print("JINPA initialized successfully.");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    uiManager.Destroy(reason);
    infoDisplay.ClearDisplay();
    Print("JINPA stopped — reason: ", reason);
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
    drawdownManager.UpdateMonthly();

    double dailyDD   = drawdownManager.GetDailyPercent();
    double monthlyDD = drawdownManager.GetMonthlyPercent();

    if(MaxDrawdownDaily > 0 && dailyDD <= -MaxDrawdownDaily)
    {
        Comment("Max Daily DD reached: ", DoubleToString(MathAbs(dailyDD), 2), "% — Trading Halted!");
        return;
    }

    //──────────────────────────────────────────────────────────────────
    // 4 - UPDATE INFORMATION DISPLAY
    //──────────────────────────────────────────────────────────────────
    int openBuy  = CPositionHelper::CountBuyPositions(_Symbol);
    int openSell = CPositionHelper::CountSellPositions(_Symbol);
    int spread   = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

    infoDisplay.UpdateDisplay(dailyDD, monthlyDD, openBuy, openSell,
                              AccountInfoDouble(ACCOUNT_BALANCE), RiskPercent,
                              spread, MagicNumber);
    infoDisplay.UpdateButtonTooltips(askPrice, bidPrice);

    //──────────────────────────────────────────────────────────────────
    // 5 - HANDLE BUTTON ORDERS
    //──────────────────────────────────────────────────────────────────
    orderExecutor.HandleAllOrders(askPrice, bidPrice, atrValue, atrValuePO, slPointsValue);

    //──────────────────────────────────────────────────────────────────
    // 6 - TRAILING STOP LOSS
    //──────────────────────────────────────────────────────────────────
    PM.TrailingStopLossByATR(_Symbol, MagicNumber, ATR.main[1], ATRFactor,
                             TSLMode, TSLActivationATR, TSLStepATR);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    uiManager.OnChartEvent(id, lparam, dparam, sparam);
}
