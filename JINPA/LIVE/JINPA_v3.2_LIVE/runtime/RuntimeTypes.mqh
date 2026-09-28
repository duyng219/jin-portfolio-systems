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

// Single authority for mode/environment admission. Strategy Tester is an
// explicit TEST environment regardless of the connected account category.
bool JINPAValidateRuntimeEnvironment(const JINPA_RUNTIME_MODE mode,
                                     string &environment,
                                     string &failureReason)
{
    failureReason = "";
    if((bool)MQLInfoInteger(MQL_TESTER))
        environment = "STRATEGY_TESTER";
    else
        environment = JINPAAccountTradeModeName(
            (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE));

    if(mode == JINPA_MODE_LIVE)
        return true;
    if(environment == "STRATEGY_TESTER" || environment == "DEMO")
        return true;

    failureReason = "TEST MODE is allowed only in Strategy Tester or DEMO accounts.";
    return false;
}

#endif // JINPA_RUNTIME_TYPES_MQH
