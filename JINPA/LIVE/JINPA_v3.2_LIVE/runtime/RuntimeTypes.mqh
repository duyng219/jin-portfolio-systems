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

#endif // JINPA_RUNTIME_TYPES_MQH
