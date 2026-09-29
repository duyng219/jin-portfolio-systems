//+------------------------------------------------------------------+
//| RuntimeTypes.mqh                                                 |
//| JINPA v3.2 runtime mode contract                                 |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_RUNTIME_TYPES_MQH
#define JINPA_RUNTIME_TYPES_MQH

enum JINPA_RUNTIME_MODE
{
    JINPA_MODE_LIVE = 0,
    JINPA_MODE_TEST = 1
};

string JINPARuntimeModeName(const JINPA_RUNTIME_MODE mode)
{
    return (mode == JINPA_MODE_TEST ? "TEST" : "LIVE");
}

string JINPAAccountTradeModeName(const ENUM_ACCOUNT_TRADE_MODE tradeMode)
{
    if(tradeMode == ACCOUNT_TRADE_MODE_DEMO)
        return "DEMO";
    if(tradeMode == ACCOUNT_TRADE_MODE_CONTEST)
        return "CONTEST";
    if(tradeMode == ACCOUNT_TRADE_MODE_REAL)
        return "REAL";
    return "UNKNOWN";
}

// Strategy Tester is an explicit runtime environment regardless of the
// connected account category. Account trade mode is identification only.
string JINPARuntimeEnvironmentName()
{
    if((bool)MQLInfoInteger(MQL_TESTER))
        return "STRATEGY_TESTER";

    return JINPAAccountTradeModeName(
        (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE));
}

#endif // JINPA_RUNTIME_TYPES_MQH
