#ifndef JINPA_WATCHER_TYPES_MQH
#define JINPA_WATCHER_TYPES_MQH

// Runtime state owned independently by each watched symbol.
// Future analysis states can be added here without coupling them to the scanner.
struct SymbolState
{
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime        lastBarTime;
   datetime        lastUpdate;

   // Presentation-ready state populated by future analysis engines.
   string          cycle;
   double          activeCorePrice;
   bool            hasActiveCore;
   string          regime;
   string          phase;
   string          structure;
   string          setup;
   string          setupStatus;

   string          lastEvent;
   datetime        lastEventTime;
   bool            isReady;

   // Runtime market-data activity. This is intentionally independent from
   // Price Structure so an inactive symbol keeps its last valid analysis.
   bool            isActive;
   datetime        lastTickTime;
   bool            activityInitialized;
};

string WatcherTimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   string value = EnumToString(timeframe);
   const string prefix = "PERIOD_";

   if(StringFind(value, prefix) == 0)
      return StringSubstr(value, StringLen(prefix));

   return value;
}

#endif
