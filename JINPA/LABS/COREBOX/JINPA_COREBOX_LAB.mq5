//+------------------------------------------------------------------+
//|                                           JINPA_COREBOX_LAB.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "1.00"
#property description "JINPA COREBOX LAB - Experimental dual-boundary structure"
#property description ""
#property description "Price Action based manual trading with one-click order entry and ATR risk management"
#property strict

//+------ INCLUDES ------+//
#include <Trade/Trade.mqh>
#include "_core/framework_manager.mqh"
#include "_core/infrastructure/magic_number_resolver.mqh"
#include "watch/WatchIntegration.mqh"

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
CWatchIntegration        watchIntegration;           // Read-only WATCH boundary
ulong                    MagicNumber = 0;             // Resolved once per EA instance
string                   CanonicalSymbol = "UNKNOWN";

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
input double                                ATRFactorSL                 = 2.5;   // Factor for initial Stop Loss
input double                                ATRFactorTSL                = 3.5;   // Factor for Trailing Stop distance
input double                                ATRFactorPO                 = 2.5;   // Factor (for Pending Order)

sinput group                              "──────────── TRAILING STOP ─────────────────"
input ENUM_TSL_MODE            TSLMode          = TSL_STEP;       // Trailing Stop Mode
input double                              TSLActivationATR = 2.5;            // Breakeven First: kích hoạt sau X ATR lãi
input double                              TSLStepATR       = 2.5;            // Step: dịch SL tối thiểu X ATR mỗi bước

sinput group                              "──────────── STRUCTURE ENGINE ───────────────"
input int                                 SwingLeftBars             = 5;     // Confirmed swing left window
input int                                 SwingRightBars            = 5;     // Confirmed swing right window
input int                                 StructureATRPeriod         = 14;    // Shared swing-distance/Core-break ATR
input double                              CoreBreakATRBuffer         = 0.10;  // Core boundary ATR multiplier
input int                                 CoreBreakConfirmCloses     = 2;     // Consecutive closes beyond boundary

sinput group                              "──────────── STRUCTURE DISPLAY ──────────────"
input bool                                ShowCoreBox                = true;  // Show Core High + Core Low
input bool                                ShowStructureSwings        = true;  // Show HH/HL/LH/LL

sinput group                              "────────────────── LOGGING ─────────────────"
input ENUM_LOG_LEVEL             LogLevel = LOG_INFO;              // Log Level

int OnInit()
{
    if(SwingLeftBars < 1 || SwingRightBars < 1
       || StructureATRPeriod < 1 || CoreBreakATRBuffer < 0.0
       || CoreBreakConfirmCloses < 1)
    {
        Print("[JINPA][COREBOX_LAB][ERROR] Invalid Structure configuration",
              " | SwingLeftBars=", SwingLeftBars,
              " | SwingRightBars=", SwingRightBars,
              " | StructureATRPeriod=", StructureATRPeriod,
              " | CoreBreakATRBuffer=", DoubleToString(CoreBreakATRBuffer, 4),
              " | CoreBreakConfirmCloses=", CoreBreakConfirmCloses);
        return INIT_PARAMETERS_INCORRECT;
    }

    if(!watchIntegration.ConfigureStructure(SwingLeftBars,
                                            SwingRightBars,
                                            StructureATRPeriod,
                                            CoreBreakATRBuffer,
                                            CoreBreakConfirmCloses,
                                            ShowCoreBox,
                                            ShowStructureSwings))
    {
        Print("[JINPA][COREBOX_LAB][ERROR] Structure configuration rejected");
        return INIT_PARAMETERS_INCORRECT;
    }

    const bool knownSymbol = CMagicNumberResolver::Resolve(_Symbol, MagicNumber,
                                                            CanonicalSymbol);
    if(!knownSymbol)
        Print("[JINPA][WARN] Unknown symbol ", _Symbol,
              " | using fallback Magic ", MagicNumber);

    // Set magic number trên CTrade — áp dụng cho tất cả orders
    trade.SetExpertMagicNumber(MagicNumber);
    // Tester defaults CTrade to LOG_LEVEL_ALL. Keep its failures, but let
    // COrderExecutor own the single concise success summary.
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

    if(!watchIntegration.Initialize(_Symbol, (ENUM_TIMEFRAMES)_Period))
        Print("[JINPA][WATCH][WARN] Integration disabled — initialization failed.");

    Print("[JINPA V1 INPUT 1/3] Symbol=", _Symbol,
          " | Magic=", MagicNumber,
          " | POExpMin=", POExpirationMinutes,
          " | MaxDD=", DoubleToString(MaxDrawdownDaily, 2), "%");
    Print("[JINPA V1 INPUT 2/3] MM=", EnumToString(MoneyManagement),
          " | Risk=", DoubleToString(RiskPercent, 2), "%",
          " | FixedLot=", DoubleToString(FixedVolume, 2),
          " | MinLotEqStep=", DoubleToString(MinLotPerEquitySteps, 2),
          " | SLPoints=", slPointsValue);
    Print("[JINPA V1 INPUT 3/3] MA=", IntegerToString(MAPeriod), "/", EnumToString(MAMethod),
          " | ATR=", IntegerToString(ATRPeriod),
          " | ATRFactorSL=", DoubleToString(ATRFactorSL, 2),
          " | ATRFactorTSL=", DoubleToString(ATRFactorTSL, 2),
          " | ATRFactorPO=", DoubleToString(ATRFactorPO, 2),
          " | TSL=", EnumToString(TSLMode),
          " | TSLActivationATR=", DoubleToString(TSLActivationATR, 2),
          " | TSLStepATR=", DoubleToString(TSLStepATR, 2),
          " | LogLevel=", EnumToString(LogLevel));
    Print("JINPA COREBOX LAB initialized successfully.");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    uiManager.Destroy(reason);
    infoDisplay.ClearDisplay();
    watchIntegration.Shutdown();
    Print("JINPA COREBOX LAB stopped — reason: ", reason);
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
    if(!infoDisplay.UpdateButtonTooltips(askPrice, bidPrice) && !IsStopped())
    {
        uiManager.RecreateAllButtons();
        infoDisplay.UpdateButtonTooltips(askPrice, bidPrice);
    }

    //──────────────────────────────────────────────────────────────────
    // 5 - HANDLE BUTTON ORDERS
    //──────────────────────────────────────────────────────────────────
    orderExecutor.HandleAllOrders(askPrice, bidPrice, atrValue, atrValuePO, slPointsValue);

    //──────────────────────────────────────────────────────────────────
    // 6 - TRAILING STOP LOSS
    //──────────────────────────────────────────────────────────────────
    PM.TrailingStopLossByATR(_Symbol, MagicNumber, ATR.main[1], ATRFactorTSL,
                             TSLMode, TSLActivationATR, TSLStepATR);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    uiManager.OnChartEvent(id, lparam, dparam, sparam);

    if(id == CHARTEVENT_CHART_CHANGE)
        watchIntegration.OnChartChange();
}

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    if(transaction.type == TRADE_TRANSACTION_DEAL_ADD)
        LogExitDeal(transaction.deal);
}
