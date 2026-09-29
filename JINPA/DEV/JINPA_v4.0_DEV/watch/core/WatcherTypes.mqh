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

   // Presentation-ready state populated by analysis engines.
   string          cycle;
   double          activeCorePrice;
   bool            hasActiveCore;
   string          regime;
   string          state;
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

// Read-only setup projection for UI/research consumers.  Direction is kept as
// BUY/SELL/NONE text so callers do not depend on individual engine enums.
struct WatchSetupSnapshot
{
   bool   isReady;
   bool   radarVisible;
   string cycle;
   string regime;
   string state;
   string structure;

   string finalSetup;
   string finalStatus;
   string finalDirection;

   string pullbackSetup;
   string pullbackStatus;
   string pullbackDirection;

   string pmaSetup;
   string pmaStatus;
   string pmaDirection;

   string rangeSetup;
   string rangeStatus;
   string rangeDirection;

   bool   microBaseConfirmed;
};

void ResetWatchSetupSnapshot(WatchSetupSnapshot &snapshot)
{
   snapshot.isReady              = false;
   snapshot.radarVisible         = false;
   snapshot.cycle                = "UNKNOWN";
   snapshot.regime               = "UNKNOWN";
   snapshot.state                = "UNKNOWN";
   snapshot.structure            = "UNKNOWN";
   snapshot.finalSetup           = "-";
   snapshot.finalStatus          = "NONE";
   snapshot.finalDirection       = "NONE";
   snapshot.pullbackSetup        = "-";
   snapshot.pullbackStatus       = "NONE";
   snapshot.pullbackDirection    = "NONE";
   snapshot.pmaSetup             = "-";
   snapshot.pmaStatus            = "NONE";
   snapshot.pmaDirection         = "NONE";
   snapshot.rangeSetup           = "-";
   snapshot.rangeStatus          = "NONE";
   snapshot.rangeDirection       = "NONE";
   snapshot.microBaseConfirmed   = false;
}

string WatcherTimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   string value = EnumToString(timeframe);
   const string prefix = "PERIOD_";

   if(StringFind(value, prefix) == 0)
      return StringSubstr(value, StringLen(prefix));

   return value;
}

#endif
