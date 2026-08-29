#ifndef JINPA_WATCHER_SYMBOL_SCANNER_MQH
#define JINPA_WATCHER_SYMBOL_SCANNER_MQH

#include "WatcherTypes.mqh"
#include "WatcherLogger.mqh"

bool IsNewBar(SymbolState &state)
{
   ResetLastError();
   const datetime currentBarTime = iTime(state.symbol, state.timeframe, 0);

   if(currentBarTime <= 0)
   {
      state.isReady = false;
      return false;
   }

   state.lastUpdate = TimeCurrent();

   if(state.lastBarTime <= 0)
   {
      state.lastBarTime = currentBarTime;
      state.isReady = true;
      return false;
   }

   state.isReady = true;

   if(currentBarTime > state.lastBarTime)
   {
      state.lastBarTime = currentBarTime;
      return true;
   }

   return false;
}

class CSymbolScanner
{
private:
   SymbolState m_states[];
   int         m_configuredSymbolCount;
   int         m_activityTimeoutSeconds;

   void UpdateActivity(const int index, const bool logTransition)
   {
      const bool previousActive = m_states[index].isActive;
      const bool hadPreviousState = m_states[index].activityInitialized;

      MqlTick tick;
      ResetLastError();
      if(SymbolInfoTick(m_states[index].symbol, tick) && tick.time > 0)
         m_states[index].lastTickTime = tick.time;

      bool currentActive = true;
      if(!(bool)MQLInfoInteger(MQL_TESTER))
      {
         datetime currentServerTime = TimeTradeServer();
         if(currentServerTime <= 0)
            currentServerTime = TimeCurrent();

         currentActive = false;
         if(m_states[index].lastTickTime > 0 && currentServerTime > 0)
         {
            const long tickAge = (long)currentServerTime
                                 - (long)m_states[index].lastTickTime;
            currentActive = tickAge <= (long)m_activityTimeoutSeconds;
         }
      }

      m_states[index].isActive = currentActive;
      m_states[index].activityInitialized = true;

      if(logTransition && hadPreviousState && previousActive != currentActive)
      {
         WatcherLog("MARKET", m_states[index].symbol + " | "
                    + (previousActive ? "ACTIVE" : "INACTIVE") + " -> "
                    + (currentActive ? "ACTIVE" : "INACTIVE"));
      }
   }

   void AddSymbol(const string symbol, const ENUM_TIMEFRAMES timeframe)
   {
      const int index = ArraySize(m_states);
      ArrayResize(m_states, index + 1);

      m_states[index].symbol      = symbol;
      m_states[index].timeframe   = timeframe;
      m_states[index].lastBarTime = 0;
      m_states[index].lastUpdate  = 0;
      m_states[index].cycle       = "UNKNOWN";
      m_states[index].activeCorePrice = 0.0;
      m_states[index].hasActiveCore = false;
      m_states[index].regime      = "UNKNOWN";
      m_states[index].phase       = "UNKNOWN";
      m_states[index].structure   = "UNKNOWN";
      m_states[index].setup       = "-";
      m_states[index].setupStatus = "NONE";
      m_states[index].lastEvent   = "WAITING";
      m_states[index].lastEventTime = 0;
      m_states[index].isReady     = false;
      m_states[index].isActive    = false;
      m_states[index].lastTickTime = 0;
      m_states[index].activityInitialized = false;

      IsNewBar(m_states[index]);
      UpdateActivity(index, false);
   }

public:
   bool Initialize(const string symbolsList,
                   const ENUM_TIMEFRAMES timeframe,
                   const int activityTimeoutSeconds)
   {
      ArrayResize(m_states, 0);
      m_configuredSymbolCount = 0;
      m_activityTimeoutSeconds = activityTimeoutSeconds;

      string candidates[];
      string configuredSymbols[];
      const ushort separator = StringGetCharacter(",", 0);
      const int candidateCount = StringSplit(symbolsList, separator, candidates);

      if(candidateCount <= 0)
      {
         WatcherLogError("Symbol list is empty or cannot be parsed.");
         return false;
      }

      for(int index = 0; index < candidateCount; index++)
      {
         string symbol = candidates[index];
         StringTrimLeft(symbol);
         StringTrimRight(symbol);

         if(symbol == "")
            continue;

         bool duplicate = false;
         const int configuredCount = ArraySize(configuredSymbols);
         for(int configuredIndex = 0; configuredIndex < configuredCount; configuredIndex++)
         {
            if(configuredSymbols[configuredIndex] == symbol)
            {
               duplicate = true;
               break;
            }
         }

         if(duplicate)
         {
            WatcherLog("INIT", "Duplicate symbol skipped: " + symbol);
            continue;
         }

         ArrayResize(configuredSymbols, configuredCount + 1);
         configuredSymbols[configuredCount] = symbol;
         m_configuredSymbolCount++;

         ResetLastError();
         if(!SymbolSelect(symbol, true))
         {
            const int errorCode = GetLastError();
            WatcherLogError("Symbol unavailable and skipped: " + symbol
                            + " | error=" + IntegerToString(errorCode));
            continue;
         }

         AddSymbol(symbol, timeframe);
         const int stateIndex = ArraySize(m_states) - 1;
         const string status = m_states[stateIndex].isReady ? "READY" : "WAITING_DATA";
         WatcherLog("INIT", "Symbol added: " + symbol
                    + " | timeframe=" + WatcherTimeframeToString(timeframe)
                    + " | status=" + status);
      }

      if(ArraySize(m_states) == 0)
      {
         WatcherLogError("No valid symbols remain after validation.");
         return false;
      }

      return true;
   }

   void Scan()
   {
      const int count = ArraySize(m_states);

      for(int index = 0; index < count; index++)
      {
         UpdateActivity(index, true);
         const bool wasReady = m_states[index].isReady;
         const bool newBar = IsNewBar(m_states[index]);

         if(!m_states[index].isReady)
         {
            if(wasReady || m_states[index].lastEvent != "WAITING")
            {
               const int errorCode = GetLastError();
               WatcherLogError("Market data unavailable: " + m_states[index].symbol
                               + " | timeframe=" + WatcherTimeframeToString(m_states[index].timeframe)
                               + " | error=" + IntegerToString(errorCode));
               m_states[index].lastEvent = "WAITING";
               m_states[index].lastEventTime = TimeCurrent();
            }
            continue;
         }

         if(!wasReady)
         {
            WatcherLog("SCAN", "Market data ready: " + m_states[index].symbol
                       + " | timeframe=" + WatcherTimeframeToString(m_states[index].timeframe));
            m_states[index].lastEvent = "DATA READY";
            m_states[index].lastEventTime = TimeCurrent();
         }

         if(newBar)
         {
            m_states[index].lastEvent = "NEW_BAR";
            m_states[index].lastEventTime = m_states[index].lastBarTime;
            WatcherLog("NEW_BAR", m_states[index].symbol
                       + " | " + WatcherTimeframeToString(m_states[index].timeframe)
                       + " | " + TimeToString(m_states[index].lastBarTime, TIME_DATE | TIME_MINUTES));
         }
      }
   }

   int Count() const
   {
      return ArraySize(m_states);
   }

   int ConfiguredCount() const
   {
      return m_configuredSymbolCount;
   }

   int ActiveCount() const
   {
      int activeCount = 0;
      const int count = ArraySize(m_states);
      for(int index = 0; index < count; index++)
      {
         if(m_states[index].isActive)
            activeCount++;
      }
      return activeCount;
   }

   string SymbolSummary() const
   {
      string summary = "";
      const int count = ArraySize(m_states);

      for(int index = 0; index < count; index++)
      {
         if(index > 0)
            summary += ",";
         summary += m_states[index].symbol;
      }

      return summary;
   }

   void CopyStates(SymbolState &states[]) const
   {
      const int count = ArraySize(m_states);
      ArrayResize(states, count);

      for(int index = 0; index < count; index++)
         states[index] = m_states[index];
   }
};

#endif
