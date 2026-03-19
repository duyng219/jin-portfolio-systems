//+------------------------------------------------------------------+
//|                                                                    jinpa-manual.mq5 |
//|                                                                                       duyng |
//|                                                  https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property version   "1.00"

//+------ INCLUDES ------+//
#include <Trade/Trade.mqh>
#include "_core/framework_manager.mqh"

//+------ GLOBAL OBJECTS ------+//
// Trade & Core Objects
CTrade trade;                      // Core trade object
CPM PM;                             // Position manager
CRM RM;                             // Risk manager
CTradeExecutor Trade;              // Trade executor
CBar Bar;                           // Bar info handler
CiATR ATR;                          // ATR indicator
CiMA MA;                            // Moving average indicator

// UI & Manager Objects
CUIManager uiManager;              // UI management
CDrawdownManager drawdownManager;  // Drawdown tracking
COrderExecutor orderExecutor;      // Order execution
CInfoDisplay infoDisplay;          // Info display

//+------ TRADING SETTINGS ------+//
sinput group                               "────────────── BASIC SETTINGS ──────────────"
input ulong                                 MagicNumber = 0001;                     // Magic Number
input int                                      slPoints = 0;                                      // Stop Loss Points - 0 = Use ATR
input ushort                                POExpirationMinutes = 360;            // Pending Order Expiration (minutes)
input double                               MaxDrawdownDaily = 0;                  // Max Daily Drawdown (%) - 0 = Disabled

sinput group                               "────────────── RISK MANAGEMENT ────────────"
input ENUM_MONEY_MANAGEMENT  MoneyManagement = MM_EQUITY_RISK_PERCENT; // Risk Method
input double                                RiskPercent = 0.2;                              // Risk per Trade (%)
input double                                FixedVolume = 0.01;                         // Fixed Lot Size
input double                                MinLotPerEquitySteps = 500;           // Minimum Lot per Equity

sinput group                               "────────────── MOVING AVERAGE ─────────────"
input int                                      MAPeriod = 21;                                   // Period
input ENUM_MA_METHOD        MAMethod = MODE_EMA;                 // Type
input int                                      MAShift = 0;                                        // Shift
input ENUM_APPLIED_PRICE      MAPrice = PRICE_CLOSE;                    // Applied Price

sinput group                               "─────────────── ATR SETTINGS ──────────────"
input int                                      ATRPeriod = 14;                                  // Period
input double                               ATRFactor = 1;                                    // Factor (for SL)
input double                               ATRFactorPO = 1;                               // Factor (for Pending Order)

int OnInit()
{  
    // Set magic number
    Trade.SetMagicNumber(MagicNumber);

    // Validate trading is allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Alert("Trading is disabled in Terminal!");
        return(INIT_FAILED);
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Alert("EA not allowed to trade! Please enable AutoTrading!");
        return(INIT_FAILED);
    }
    
    // Select and validate symbol
    if(!SymbolSelect(_Symbol, true))
    {
        Alert("Failed to select symbol: " + _Symbol);
        return(INIT_FAILED);
    }
    
    // Display symbol volume specifications in Experts tab
    Print("Symbol Info - Min Vol: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
          " | Max Vol: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
          " | Step: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));

    // Initialize UI manager
    uiManager.Initialize();
    Sleep(100);

    // Initialize Moving Average indicator
    int MAHandle = MA.Init(_Symbol, _Period, MAPeriod, MAShift, MAMethod, MAPrice);
    if(MAHandle == -1)
    {
        Alert("Moving Average indicator initialization failed!");
        return(INIT_FAILED);
    }

    // Initialize ATR indicator
    int ATRHandle = ATR.Init(_Symbol, _Period, ATRPeriod);   
    if(ATRHandle == -1)
    {
        Alert("ATR indicator initialization failed!");
        return(INIT_FAILED);
    }
    
    // Initialize order executor with all parameters
    orderExecutor.Initialize(_Symbol, &RM, &PM, &Trade, &trade, &uiManager, 
                            MagicNumber, MoneyManagement, MinLotPerEquitySteps, 
                            RiskPercent, FixedVolume, POExpirationMinutes);
    
    Print("EA Initialized Successfully!");
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    // Clean up UI elements and info displays
    uiManager.Destroy(reason);
    infoDisplay.ClearDisplay();
    
    Print("EA Stopped - Reason Code: " + IntegerToString(reason));
}

void OnTick()
{ 
    //──────────────────────────────────────────────────────────────────
    // 1 - REFRESH INDICATORS
    //──────────────────────────────────────────────────────────────────
    MA.RefreshMain();
    double ma1 = MA.main[1];

    ATR.RefreshMain();
    double atr0 = ATR.main[0];
    double atr1 = ATR.main[1]; 
    double ATRValue = atr1 * ATRFactor;      // Stop loss adjustment value
    double ATRValuePO = atr0 * ATRFactorPO;  // Pending order adjustment value

    //──────────────────────────────────────────────────────────────────
    // 2 - GET CURRENT MARKET PRICES
    //──────────────────────────────────────────────────────────────────
    Bar.Refresh(_Symbol, PERIOD_CURRENT, 6);
    double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    //──────────────────────────────────────────────────────────────────
    // 3 - UPDATE DRAWDOWN TRACKING
    //──────────────────────────────────────────────────────────────────
    drawdownManager.UpdateDaily();
    drawdownManager.UpdateMonthly();

    double dailyDD = drawdownManager.GetDailyPercent();
    double monthlyDD = drawdownManager.GetMonthlyPercent();

    // Stop trading if maximum daily drawdown is reached
    if(MaxDrawdownDaily > 0)
    {
        if(dailyDD >= MaxDrawdownDaily)
        {
            string message = "Max Daily DD: " + DoubleToString(dailyDD, 2) + "% - Trading Halted!";
            Comment(message);
            return; 
        }
    }

    //──────────────────────────────────────────────────────────────────
    // 4 - GET POSITION COUNT & MARKET DATA
    //──────────────────────────────────────────────────────────────────
    int openBuy = CPositionHelper::CountBuyPositions(_Symbol);
    int openSell = CPositionHelper::CountSellPositions(_Symbol);
    int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    
    //──────────────────────────────────────────────────────────────────
    // 5 - UPDATE INFORMATION DISPLAY
    //──────────────────────────────────────────────────────────────────
    infoDisplay.UpdateDisplay(dailyDD, monthlyDD, openBuy, openSell,
                             AccountInfoDouble(ACCOUNT_BALANCE), RiskPercent, 
                             spread, MagicNumber);
    infoDisplay.UpdateButtonTooltips(askPrice, bidPrice);
    
    //──────────────────────────────────────────────────────────────────
    // 6 - EXECUTE PENDING & MARKET ORDERS
    //──────────────────────────────────────────────────────────────────
    orderExecutor.HandleAllOrders(askPrice, bidPrice, ATRValue, ATRValuePO, slPoints);

    //──────────────────────────────────────────────────────────────────
    // 7 - MANAGE TRAILING STOP LOSS
    //──────────────────────────────────────────────────────────────────
    PM.TrailingStopLossByATR(_Symbol, MagicNumber, ATRValue, ATRFactor);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Route all UI events to manager (button clicks, mouse interactions, etc.)
    uiManager.OnChartEvent(id, lparam, dparam, sparam);
}
