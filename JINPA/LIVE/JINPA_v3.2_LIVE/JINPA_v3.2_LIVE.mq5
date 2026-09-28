//+------------------------------------------------------------------+
//|                                            JINPA_v3.2_LIVE.mq5 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "3.20"
#property description "JINPA v3.2 LIVE - Unified Runtime Manual Trading Assistant"
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
#include "runtime/RuntimeTypes.mqh"
#include "trade/ManualTradeController.mqh"
#include "runtime/RuntimePanelHost.mqh"
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
CManualTradeController g_manualTradeController;
CTestCommentResolver g_testCommentResolver;
CRuntimePanelHost g_runtimePanel;
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
sinput group                              "──────────── RUNTIME MODE ────────────"
input JINPA_RUNTIME_MODE                  RuntimeMode              = JINPA_MODE_LIVE;

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
input double                                ATRFactorSL                 = 2.2;   // Factor for initial Stop Loss
input double                                ATRFactorTSL                = 2.5;   // Factor for Trailing Stop distance
input double                                ATRFactorPO                 = 2.5;   // Factor (Pending Order offset)

sinput group                              "──────────── TRAILING STOP ─────────────────"
input ENUM_TSL_MODE            TSLMode          = TSL_STEP;
input double                              TSLActivationATR = 2.5;
input double                              TSLStepATR       = 2.5;   // Minimum ATR move between TSL updates

sinput group                              "──────────── STRUCTURE ENGINE ───────────────"
input int                                 SwingLeftBars             = 3;     // Confirmed swing left window
input int                                 SwingRightBars            = 3;     // Confirmed swing right window
input int                                 StructureATRPeriod         = 14;    // Shared swing-distance/Core-break ATR
input double                              CoreBreakATRBuffer         = 0.10;  // Core boundary ATR multiplier
input int                                 CoreBreakConfirmCloses     = 2;     // Consecutive closes beyond boundary

sinput group                              "──────────── STRUCTURE DISPLAY ──────────────"
input bool                                ShowStructureSwings        = true;  // Show HH/HL/LH/LL
input bool                                ShowWatchPanel             = false; // Show WATCH Market Radar panel

sinput group                              "──────────── NOTIFICATIONS ─────────────"
input bool                                EnableTelegramPush         = true;
input string                              TelegramBotToken           = "";
input string                              TelegramChatId             = "";
input bool                                EnableMT5Push              = false;

sinput group                              "────────────────── LOGGING ─────────────────"
input ENUM_LOG_LEVEL             LogLevel = LOG_INFO;

int OnInit()
{
    const string runtimeEnvironment = JINPARuntimeEnvironmentName();
    if(RuntimeMode == JINPA_MODE_TEST
       && runtimeEnvironment != "STRATEGY_TESTER"
       && runtimeEnvironment != "DEMO")
    {
        if(runtimeEnvironment == "REAL")
            Print("[JINPA][RUNTIME][WARN] TEST MODE is running on a REAL account. ",
                  "Verify the selected runtime environment before manual execution.");
        else if(runtimeEnvironment == "CONTEST")
            Print("[JINPA][RUNTIME][WARN] TEST MODE is running on a CONTEST account. ",
                  "Verify the selected runtime environment before manual execution.");
        else
            Print("[JINPA][RUNTIME][WARN] TEST MODE is running in an UNKNOWN account environment. ",
                  "Verify the selected runtime environment before manual execution.");
    }
    const bool runtimeModeAllowsExternalNotifications =
        (RuntimeMode == JINPA_MODE_LIVE);
    const bool externalNotificationsAllowed =
        runtimeModeAllowsExternalNotifications
        && !(bool)MQLInfoInteger(MQL_TESTER);

    if(SwingLeftBars < 1 || SwingRightBars < 1
       || StructureATRPeriod < 1 || CoreBreakATRBuffer < 0.0
       || CoreBreakConfirmCloses < 1)
    {
        Print("[JINPA][v3.2 LIVE][ERROR] Invalid Structure configuration",
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
                                            ShowStructureSwings))
    {
        Print("[JINPA][v3.2 LIVE][ERROR] Structure configuration rejected");
        return INIT_PARAMETERS_INCORRECT;
    }

    const bool knownSymbol = CMagicNumberResolver::Resolve(_Symbol, MagicNumber,
                                                            CanonicalSymbol);
    if(!knownSymbol)
        Print("[JINPA][WARN] Unknown symbol ", _Symbol,
              " | using fallback Magic ", MagicNumber);

    trade.SetExpertMagicNumber(MagicNumber);
    trade.LogLevel(LOG_LEVEL_ERRORS);

    if(RuntimeMode == JINPA_MODE_LIVE && !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Alert("Trading is disabled in Terminal!");
        return INIT_FAILED;
    }

    if(RuntimeMode == JINPA_MODE_LIVE && !MQLInfoInteger(MQL_TRADE_ALLOWED))
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

    if(!g_manualTradeController.Initialize(_Symbol, MagicNumber, &RM, &PM, &trade))
    {
        Alert("Manual trade controller initialization failed!");
        return INIT_FAILED;
    }

    if(!g_testCommentResolver.Initialize(&watchIntegration))
    {
        Alert("TEST Comment resolver initialization failed!");
        return INIT_FAILED;
    }

    SRuntimePanelConfig panelConfig;
    panelConfig.symbol                   = _Symbol;
    panelConfig.magic                    = MagicNumber;
    panelConfig.moneyManagement          = MoneyManagement;
    panelConfig.minLotPerEquitySteps     = MinLotPerEquitySteps;
    panelConfig.riskPercent              = RiskPercent;
    panelConfig.fixedVolume              = FixedVolume;
    panelConfig.pendingExpirationMinutes = POExpirationMinutes;
    panelConfig.stopLossPoints           = slPointsValue;
    panelConfig.logLevel                 = LogLevel;

    if(!g_runtimePanel.Initialize(RuntimeMode, 0, 0,
                                panelX, panelY, panelX + panelW, panelY + panelH,
                                &g_manualTradeController, &g_testCommentResolver,
                                panelConfig))
    {
        Alert("Runtime panel initialization failed!");
        return INIT_FAILED;
    }

    watchIntegration.ConfigureNotificationTransport(
        runtimeModeAllowsExternalNotifications,
        EnableTelegramPush, TelegramBotToken, TelegramChatId,
        EnableMT5Push);
    const bool watchInitialized =
        watchIntegration.Initialize(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                    ShowWatchPanel);
    if(!watchInitialized)
        Print("[JINPA][WARN] Structure integration disabled — initialization failed.");

    string externalPushStatus = "FORCED_OFF";
    if(externalNotificationsAllowed)
    {
        if(watchIntegration.HasAvailableNotificationTransport())
            externalPushStatus = "ENABLED";
        else if(!EnableTelegramPush && !EnableMT5Push)
            externalPushStatus = "DISABLED_BY_INPUTS";
        else
            externalPushStatus = "UNAVAILABLE_CONFIGURATION";
    }

    Print("[JINPA v3.2 LIVE INPUT 1/5] RuntimeMode=", JINPARuntimeModeName(RuntimeMode),
          " | Environment=", runtimeEnvironment,
          " | Panel=", g_runtimePanel.Status(),
          " | ExternalPush=", externalPushStatus);
    Print("[JINPA v3.2 LIVE INPUT 2/5] Symbol=", _Symbol,
          " | Magic=", MagicNumber,
          " | POExpMin=", POExpirationMinutes,
          " | MaxDD=", DoubleToString(MaxDrawdownDaily, 2), "%");
    Print("[JINPA v3.2 LIVE INPUT 3/5] MM=", EnumToString(MoneyManagement),
          " | Risk=", DoubleToString(RiskPercent, 2), "%",
          " | FixedLot=", DoubleToString(FixedVolume, 2),
          " | MinLotEqStep=", DoubleToString(MinLotPerEquitySteps, 2),
          " | DisplayVC=", DoubleToString(DisplayVirtualCapital, 2),
          " | SLPoints=", slPointsValue);
    Print("[JINPA v3.2 LIVE INPUT 4/5] MA=", IntegerToString(MAPeriod), "/", EnumToString(MAMethod),
          " | ATR=", IntegerToString(ATRPeriod),
          " | ATRFactorSL=", DoubleToString(ATRFactorSL, 2),
          " | ATRFactorTSL=", DoubleToString(ATRFactorTSL, 2),
          " | ATRFactorPO=", DoubleToString(ATRFactorPO, 2),
          " | TSL=", EnumToString(TSLMode),
          " | LogLevel=", EnumToString(LogLevel));
    string notificationStatus = watchIntegration.NotificationTransportStatus();
    const string notificationReason =
        watchIntegration.NotificationConfigurationReason();
    if(notificationReason != "")
        notificationStatus += " | Reason=" + notificationReason;
    if(!watchInitialized)
        notificationStatus += " | Watch=UNAVAILABLE";
    Print("[JINPA v3.2 LIVE INPUT 5/5] ", notificationStatus);
    if(externalNotificationsAllowed
       && !watchIntegration.HasAvailableNotificationTransport())
        Print("[JINPA][WARN] WARNING: No available notification transport");
    if(RuntimeMode == JINPA_MODE_TEST)
    {
        Print("[JINPA][RUNTIME] TEST MODE ACTIVE");
        Print("[JINPA][RUNTIME] Panel=TEST | Execution=SHARED_CONTROLLER",
              " | CommentResolver=WATCH_AWARE");
        Print("[JINPA][RUNTIME] WATCH semantic core=ACTIVE");
        Print("[JINPA][RUNTIME] External notifications are suppressed.");
    }
    Print("JINPA v3.2 LIVE initialized successfully | RuntimeMode=",
          JINPARuntimeModeName(RuntimeMode), ".");
    if(watchInitialized && externalNotificationsAllowed)
        watchIntegration.SendStartupNotification();
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    g_runtimePanel.Shutdown(reason);
    infoDisplay.ClearDisplay();
    watchIntegration.Shutdown();
    Print("JINPA v3.2 LIVE stopped — reason: ", reason);
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
        g_runtimePanel.SetTradingHalt(false);

    //──────────────────────────────────────────────────────────────────
    // 4 - UPDATE INFORMATION DISPLAY
    //──────────────────────────────────────────────────────────────────
    infoDisplay.UpdatePoolSummary(_Symbol, MagicNumber, RiskPercent, dailyDD, DisplayVirtualCapital);
    infoDisplay.UpdateButtonTooltips(askPrice, bidPrice);

    //──────────────────────────────────────────────────────────────────
    // 5 - UPDATE PANEL + PERIODIC LOG REFRESH
    //──────────────────────────────────────────────────────────────────
    g_runtimePanel.UpdateMarketData(atrValue, atrValuePO, slPointsValue, dailyDD);
    if(dailyHalt)
        g_runtimePanel.SetTradingHalt(true, "Max Daily DD reached: " + DoubleToString(MathAbs(dailyDD), 2) + "%");
    g_runtimePanel.Tick();

    //──────────────────────────────────────────────────────────────────
    // 6 - TRAILING STOP LOSS
    //──────────────────────────────────────────────────────────────────
    PM.TrailingStopLossByATR(_Symbol, MagicNumber, ATR.main[1], ATRFactorTSL,
                             TSLMode, TSLActivationATR, TSLStepATR);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    g_runtimePanel.OnChartEvent(id, lparam, dparam, sparam);

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
