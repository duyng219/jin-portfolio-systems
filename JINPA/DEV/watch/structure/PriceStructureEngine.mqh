#ifndef JINPA_WATCHER_PRICE_STRUCTURE_ENGINE_MQH
#define JINPA_WATCHER_PRICE_STRUCTURE_ENGINE_MQH

#include "StructureTypes.mqh"
#include "../core/WatcherTypes.mqh"
#include "../core/WatcherLogger.mqh"

class CPriceStructureEngine
{
private:
   int                   m_swingLeftBars;
   int                   m_swingRightBars;
   bool                  m_useDistanceFilter;
   double                m_minDistanceATR;
   int                   m_atrPeriod;
   int                   m_lookbackBars;
   bool                  m_useCoreBreakATRBuffer;
   double                m_coreBreakATRBuffer;
   bool                  m_isBootstrapping;
   bool                  m_enableAuditLog;
   bool                  m_enableCoreBreakAuditLog;

   string                m_symbols[];
   ENUM_TIMEFRAMES       m_timeframes[];
   PriceStructureState   m_states[];
   datetime              m_lastSeenCurrentBarTime[];
   datetime              m_lastProcessedClosedBarTime[];
   datetime              m_lastCandidateTime[];
   string                m_lastCandidateEventIdentity[];
   bool                  m_dataErrorLogged[];
   int                   m_swingCounts[];
   int                   m_lastHighRecordIndex[];
   int                   m_lastLowRecordIndex[];
   datetime              m_lastBullContinuationReferenceTime[];
   datetime              m_lastBearContinuationReferenceTime[];
   datetime              m_lastNoNewClosedBarAuditTime[];
   datetime              m_sidewayCandidateStartTime[];
   PendingContinuationState m_pendingContinuations[];
   SwingPoint            m_breakOrigins[];
   bool                  m_auditSnapshotInitialized[];
   string                m_lastAuditCycle[];
   double                m_lastAuditCorePrice[];
   bool                  m_lastAuditHasCore[];
   string                m_lastAuditStructure[];
   StructureSwingRecord  m_swingHistory[];
   BrokenCoreRecord      m_brokenCoreHistory[];
   SidewayBoxRecord      m_sidewayBoxHistory[];
   StructureEvent        m_pendingEvents[];

   int FindContext(const string symbol, const ENUM_TIMEFRAMES timeframe) const
   {
      const int count = ArraySize(m_symbols);
      for(int index = 0; index < count; index++)
      {
         if(m_symbols[index] == symbol && m_timeframes[index] == timeframe)
            return index;
      }

      return -1;
   }

   bool IsSwingHighCandidate(const MqlRates &rates[], const int index) const
   {
      const double candidate = rates[index].high;
      for(int offset = 1; offset <= m_swingLeftBars; offset++)
      {
         if(candidate <= rates[index - offset].high)
            return false;
      }

      for(int offset = 1; offset <= m_swingRightBars; offset++)
      {
         if(candidate <= rates[index + offset].high)
            return false;
      }

      return true;
   }

   bool IsSwingLowCandidate(const MqlRates &rates[], const int index) const
   {
      const double candidate = rates[index].low;
      for(int offset = 1; offset <= m_swingLeftBars; offset++)
      {
         if(candidate >= rates[index - offset].low)
            return false;
      }

      for(int offset = 1; offset <= m_swingRightBars; offset++)
      {
         if(candidate >= rates[index + offset].low)
            return false;
      }

      return true;
   }

   double CalculateATR(const MqlRates &rates[], const int endIndex) const
   {
      const int firstIndex = endIndex - m_atrPeriod + 1;
      if(firstIndex < 1)
         return 0.0;

      double trueRangeSum = 0.0;
      for(int index = firstIndex; index <= endIndex; index++)
      {
         const double highLow = rates[index].high - rates[index].low;
         const double highClose = MathAbs(rates[index].high - rates[index - 1].close);
         const double lowClose = MathAbs(rates[index].low - rates[index - 1].close);
         trueRangeSum += MathMax(highLow, MathMax(highClose, lowClose));
      }

      return trueRangeSum / (double)m_atrPeriod;
   }

   bool PassSwingDistanceFilter(const int contextIndex,
                                const ENUM_SWING_TYPE swingType,
                                const double candidatePrice,
                                const double atr) const
   {
      if(!m_useDistanceFilter)
         return true;
      if(atr <= 0.0)
         return false;

      double oppositePrice = 0.0;
      if(swingType == SWING_HIGH)
         oppositePrice = m_states[contextIndex].lastSwingLow.price;
      else if(swingType == SWING_LOW)
         oppositePrice = m_states[contextIndex].lastSwingHigh.price;

      if(oppositePrice <= 0.0)
         return true;

      return MathAbs(candidatePrice - oppositePrice) >= atr * m_minDistanceATR;
   }

   ENUM_STRUCTURE_POINT ClassifySwingHigh(const int contextIndex,
                                          const double price) const
   {
      const SwingPoint previous = m_states[contextIndex].lastSwingHigh;
      if(!previous.confirmed)
         return STRUCT_NONE;

      double pointSize = SymbolInfoDouble(m_symbols[contextIndex], SYMBOL_POINT);
      if(pointSize <= 0.0)
         pointSize = 0.00000001;

      if(MathAbs(price - previous.price) <= pointSize)
         return STRUCT_EQUAL_HIGH;
      return price > previous.price ? STRUCT_HH : STRUCT_LH;
   }

   ENUM_STRUCTURE_POINT ClassifySwingLow(const int contextIndex,
                                         const double price) const
   {
      const SwingPoint previous = m_states[contextIndex].lastSwingLow;
      if(!previous.confirmed)
         return STRUCT_NONE;

      double pointSize = SymbolInfoDouble(m_symbols[contextIndex], SYMBOL_POINT);
      if(pointSize <= 0.0)
         pointSize = 0.00000001;

      if(MathAbs(price - previous.price) <= pointSize)
         return STRUCT_EQUAL_LOW;
      return price > previous.price ? STRUCT_HL : STRUCT_LL;
   }

   void UpdateStructureSummary(const int contextIndex)
   {
      const ENUM_STRUCTURE_POINT highClass = m_states[contextIndex].lastSwingHigh.classification;
      const ENUM_STRUCTURE_POINT lowClass = m_states[contextIndex].lastSwingLow.classification;
      m_states[contextIndex].highStructure = StructurePointToString(highClass);
      m_states[contextIndex].lowStructure = StructurePointToString(lowClass);

      if(highClass == STRUCT_HH && lowClass == STRUCT_HL)
      {
         m_states[contextIndex].basicStructure = BASIC_STRUCTURE_BULL;
         m_states[contextIndex].structureSummary = "HH-HL";
      }
      else if(highClass == STRUCT_LH && lowClass == STRUCT_LL)
      {
         m_states[contextIndex].basicStructure = BASIC_STRUCTURE_BEAR;
         m_states[contextIndex].structureSummary = "LH-LL";
      }
      else if(highClass == STRUCT_NONE || lowClass == STRUCT_NONE)
      {
         m_states[contextIndex].basicStructure = BASIC_STRUCTURE_UNKNOWN;
         m_states[contextIndex].structureSummary = "UNKNOWN";
      }
      else
      {
         m_states[contextIndex].basicStructure = BASIC_STRUCTURE_MIXED;
         m_states[contextIndex].structureSummary = "MIXED";
      }
   }

   int AppendSwing(const int contextIndex, const SwingPoint &point)
   {
      const int recordIndex = ArraySize(m_swingHistory);
      ArrayResize(m_swingHistory, recordIndex + 1);
      m_swingHistory[recordIndex].contextIndex = contextIndex;
      m_swingHistory[recordIndex].point = point;
      m_swingCounts[contextIndex]++;
      return recordIndex;
   }

   string JournalCycleText(const ENUM_MARKET_CYCLE cycle) const
   {
      if(cycle == MARKET_CYCLE_BULL)
         return "Bull ↑";
      if(cycle == MARKET_CYCLE_BEAR)
         return "Bear ↓";
      return "Unknown";
   }

   string JournalCoreText(const ENUM_CORE_SWING_TYPE coreType) const
   {
      if(coreType == CORE_SWING_LOW)
         return "Core low";
      if(coreType == CORE_SWING_HIGH)
         return "Core high";
      return "Core";
   }

   void LogStructureEvent(const StructureEvent &event) const
   {
      const int digits = (int)SymbolInfoInteger(event.symbol, SYMBOL_DIGITS);
      const string prefix = event.symbol + " " + WatcherTimeframeToString(event.timeframe) + " | ";

      if(event.type == CORE_SWING_INITIALIZED)
      {
         WatcherLog("CORE", prefix + JournalCoreText(event.coreType)
                     + " initialized | " + DoubleToString(event.newCoreLevel, digits));
      }
      else if(event.type == CORE_SWING_CHANGED)
      {
         WatcherLog("CORE", prefix + JournalCoreText(event.coreType)
                    + " updated | " + DoubleToString(event.oldCoreLevel, digits)
                    + " → " + DoubleToString(event.newCoreLevel, digits));
      }
      else if(event.type == CORE_BREAK_CANDIDATE)
      {
         WatcherLog("CORE", prefix + "Break candidate | "
                    + JournalCycleText(event.cycleBefore) + " | "
                    + JournalCoreText(event.coreType) + " "
                    + DoubleToString(event.oldCoreLevel, digits));
      }
      else if(event.type == CORE_BREAK_FAILED)
      {
         WatcherLog("CORE", prefix + "Break failed | "
                    + JournalCycleText(event.cycleBefore));
      }
      else if(event.type == CYCLE_CHANGED)
      {
         WatcherLog("CYCLE", prefix + JournalCycleText(event.cycleBefore)
                    + " → " + JournalCycleText(event.cycleAfter)
                    + " | Confirmed");
      }
   }

   void AuditCoreUpdate(const int contextIndex,
                         const ENUM_CORE_SWING_TYPE coreType,
                         const SwingPoint &origin,
                         const double oldCore,
                         const double newCore,
                         const bool hadCore,
                         const double structuralLevel,
                         const string reason) const
   {
      if(!m_enableAuditLog)
         return;

      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      string structuralLabel = "Structural High";
      string originLabel = "Origin Swing Low";

      if(coreType == CORE_SWING_HIGH)
      {
         structuralLabel = "Structural Low";
         originLabel = "Origin Swing High";
      }

      WatcherLog("AUDIT][CORE", "\nSymbol: " + m_symbols[contextIndex]
                 + "\nTF: " + WatcherTimeframeToString(m_timeframes[contextIndex])
                  + "\nCycle: " + MarketCycleToString(m_states[contextIndex].cycleState.cycle)
                  + "\n" + structuralLabel + ": "
                  + DoubleToString(structuralLevel, digits)
                  + "\nConfirmation: " + reason
                  + "\n" + originLabel + ":\ntime="
                 + TimeToString(origin.time, TIME_DATE | TIME_MINUTES)
                 + "\nprice=" + DoubleToString(origin.price, digits)
                 + "\nOld " + CoreSwingTypeToString(coreType) + ": "
                 + (hadCore ? DoubleToString(oldCore, digits) : "-")
                 + "\nNew " + CoreSwingTypeToString(coreType) + ": "
                 + DoubleToString(newCore, digits)
                 + "\nCore Changed: TRUE");
   }

   string BootstrapAuditReason(const int contextIndex) const
   {
      if(!m_states[contextIndex].lastSwingHigh.confirmed
         || !m_states[contextIndex].lastSwingLow.confirmed)
         return "INSUFFICIENT_SWINGS";

      if(m_states[contextIndex].basicStructure == BASIC_STRUCTURE_MIXED)
         return "MIXED_STRUCTURE";

      if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_UNKNOWN)
      {
         if((m_states[contextIndex].lastSwingHigh.classification == STRUCT_HH
             && m_states[contextIndex].lastSwingHigh.originSwingPrice <= 0.0)
            || (m_states[contextIndex].lastSwingLow.classification == STRUCT_LL
                && m_states[contextIndex].lastSwingLow.originSwingPrice <= 0.0))
            return "NO_VALID_ORIGIN";
         return "STRUCTURE_SEQUENCE_NOT_CONFIRMED";
      }

      if(!m_states[contextIndex].coreSwing.hasCoreLow
         && !m_states[contextIndex].coreSwing.hasCoreHigh)
         return "NO_VALID_CORE";

      return "READY";
   }

   void AuditBootstrap(const int contextIndex) const
   {
      if(!m_enableAuditLog)
         return;

      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      string coreType = "NONE";
      string corePrice = "-";
      bool hasCore = false;

      if(m_states[contextIndex].coreSwing.hasCoreLow)
      {
         coreType = "LOW";
         corePrice = DoubleToString(m_states[contextIndex].coreSwing.coreSwingLow, digits);
         hasCore = true;
      }
      else if(m_states[contextIndex].coreSwing.hasCoreHigh)
      {
         coreType = "HIGH";
         corePrice = DoubleToString(m_states[contextIndex].coreSwing.coreSwingHigh, digits);
         hasCore = true;
      }

      WatcherLog("AUDIT][INIT", "\n" + m_symbols[contextIndex] + " "
                 + WatcherTimeframeToString(m_timeframes[contextIndex])
                 + "\nHigh Structure: " + m_states[contextIndex].highStructure
                 + "\nLow Structure: " + m_states[contextIndex].lowStructure
                 + "\nBasic Structure: " + m_states[contextIndex].structureSummary
                 + "\nCycle: " + MarketCycleToString(m_states[contextIndex].cycleState.cycle)
                 + "\nHas Active Core: " + (hasCore ? "TRUE" : "FALSE")
                 + "\nCore Type: " + coreType
                 + "\nCore Price: " + corePrice
                 + "\nReason: " + BootstrapAuditReason(contextIndex));
   }

   void AuditSnapshot(const int contextIndex, const SymbolState &symbolState)
   {
      if(!m_enableAuditLog)
         return;

      const bool changed = !m_auditSnapshotInitialized[contextIndex]
                           || m_lastAuditCycle[contextIndex] != symbolState.cycle
                           || m_lastAuditCorePrice[contextIndex] != symbolState.activeCorePrice
                           || m_lastAuditHasCore[contextIndex] != symbolState.hasActiveCore
                           || m_lastAuditStructure[contextIndex] != symbolState.structure;
      if(!changed)
         return;

      const int digits = (int)SymbolInfoInteger(symbolState.symbol, SYMBOL_DIGITS);
      const string expectedCycle = MarketCycleToString(m_states[contextIndex].cycleState.cycle);
      bool expectedHasCore = false;
      double expectedCorePrice = 0.0;
      if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow)
      {
         expectedHasCore = true;
         expectedCorePrice = m_states[contextIndex].coreSwing.coreSwingLow;
      }
      else if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BEAR
              && m_states[contextIndex].coreSwing.hasCoreHigh)
      {
         expectedHasCore = true;
         expectedCorePrice = m_states[contextIndex].coreSwing.coreSwingHigh;
      }

      const bool mappingOk = symbolState.cycle == expectedCycle
                             && symbolState.structure == m_states[contextIndex].structureSummary
                             && symbolState.hasActiveCore == expectedHasCore
                             && (!expectedHasCore
                                 || symbolState.activeCorePrice == expectedCorePrice);
      WatcherLog("AUDIT][SNAPSHOT", "\n" + symbolState.symbol + " "
                 + WatcherTimeframeToString(symbolState.timeframe)
                 + "\ncycle=" + symbolState.cycle
                 + "\ncore=" + (symbolState.hasActiveCore
                                  ? DoubleToString(symbolState.activeCorePrice, digits) : "-")
                 + "\nhasCore=" + (symbolState.hasActiveCore ? "true" : "false")
                 + "\nstructure=" + symbolState.structure
                 + "\nmapping=" + (mappingOk ? "OK" : "MISMATCH"));

      m_auditSnapshotInitialized[contextIndex] = true;
      m_lastAuditCycle[contextIndex] = symbolState.cycle;
      m_lastAuditCorePrice[contextIndex] = symbolState.activeCorePrice;
      m_lastAuditHasCore[contextIndex] = symbolState.hasActiveCore;
      m_lastAuditStructure[contextIndex] = symbolState.structure;
   }

   void AuditCycleEvent(const StructureEvent &event) const
   {
      if(!m_enableAuditLog)
         return;
      if(event.type != CORE_BREAK_CANDIDATE
         && event.type != CORE_BREAK_FAILED
         && event.type != CYCLE_CHANGED)
         return;

      const int digits = (int)SymbolInfoInteger(event.symbol, SYMBOL_DIGITS);
      int confirmationCount = 0;
      if(event.type == CORE_BREAK_CANDIDATE)
         confirmationCount = 1;
      else if(event.type == CYCLE_CHANGED)
         confirmationCount = 2;

      WatcherLog("AUDIT][CYCLE", "\n" + event.symbol + " "
                 + WatcherTimeframeToString(event.timeframe)
                 + "\nEvent: " + StructureEventTypeToString(event.type)
                 + "\nCycle: " + MarketCycleToString(event.cycleBefore)
                 + (event.type == CYCLE_CHANGED
                    ? " -> " + MarketCycleToString(event.cycleAfter) : "")
                 + "\nCore: " + DoubleToString(event.oldCoreLevel, digits)
                 + "\nBreak Level: " + DoubleToString(event.breakLevel, digits)
                 + "\nConfirmation Count: " + IntegerToString(confirmationCount));
   }

   void EmitEvent(const int contextIndex,
                  const ENUM_STRUCTURE_EVENT_TYPE eventType,
                  const datetime eventBarTime,
                  const ENUM_MARKET_CYCLE cycleBefore,
                  const ENUM_MARKET_CYCLE cycleAfter,
                  const ENUM_CORE_SWING_TYPE coreType,
                  const double oldCoreLevel,
                  const double newCoreLevel,
                  const double breakLevel,
                  const string reason)
   {
      StructureEvent event;
      event.type = eventType;
      event.symbol = m_symbols[contextIndex];
      event.timeframe = m_timeframes[contextIndex];
      event.eventBarTime = eventBarTime;
      event.cycleBefore = cycleBefore;
      event.cycleAfter = cycleAfter;
      event.coreType = coreType;
      event.oldCoreLevel = oldCoreLevel;
      event.newCoreLevel = newCoreLevel;
      event.breakLevel = breakLevel;
      event.reason = reason;
      const int eventDigits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      const double identityCoreLevel = eventType == CORE_BREAK_CANDIDATE
                                       ? oldCoreLevel : newCoreLevel;
      event.identity = event.symbol + "|" + IntegerToString((int)event.timeframe)
                        + "|" + IntegerToString((int)eventType)
                        + "|" + IntegerToString((long)eventBarTime)
                        + "|" + DoubleToString(identityCoreLevel, eventDigits)
                        + "|" + DoubleToString(breakLevel, eventDigits);

      // CORE_BREAK_CANDIDATE is a false -> true transition. Keep its stable
      // identity beyond ConsumeEvents() so the persistent candidate state can
      // never recreate the same event on a later timer execution.
      if(eventType == CORE_BREAK_CANDIDATE)
      {
         if(m_lastCandidateEventIdentity[contextIndex] == event.identity)
            return;
         m_lastCandidateEventIdentity[contextIndex] = event.identity;
      }

      if(eventType == CORE_SWING_INITIALIZED)
         m_states[contextIndex].lastEvent = CoreSwingTypeToString(coreType) + " initialized";
      else if(eventType == CORE_SWING_CHANGED)
         m_states[contextIndex].lastEvent = CoreSwingTypeToString(coreType)
                                            + " -> " + DoubleToString(newCoreLevel, eventDigits);
      else if(eventType == CORE_BREAK_CANDIDATE)
         m_states[contextIndex].lastEvent = "Core break candidate";
      else if(eventType == CORE_BREAK_FAILED)
         m_states[contextIndex].lastEvent = "Core break failed";
      else if(eventType == CYCLE_CHANGED)
         m_states[contextIndex].lastEvent = MarketCycleToString(cycleBefore)
                                            + " -> " + MarketCycleToString(cycleAfter);
      m_states[contextIndex].lastEventTime = eventBarTime;
      AuditCycleEvent(event);

      if(m_isBootstrapping)
         return;

      const int eventIndex = ArraySize(m_pendingEvents);
      ArrayResize(m_pendingEvents, eventIndex + 1);
      m_pendingEvents[eventIndex] = event;
      LogStructureEvent(event);
   }

   void SetCoreLow(const int contextIndex,
                   const SwingPoint &origin,
                   const datetime eventBarTime,
                   const string reason,
                   const double structuralLevel)
   {
      if(origin.price <= 0.0 || origin.time <= 0)
         return;

      const bool hadCore = m_states[contextIndex].coreSwing.hasCoreLow;
      const double oldCore = m_states[contextIndex].coreSwing.coreSwingLow;
      const datetime oldTime = m_states[contextIndex].coreSwing.coreSwingLowTime;
      if(hadCore && oldTime == origin.time)
         return;

      m_states[contextIndex].coreSwing.coreSwingLow = origin.price;
      m_states[contextIndex].coreSwing.coreSwingLowTime = origin.time;
      m_states[contextIndex].coreSwing.hasCoreLow = true;
      m_states[contextIndex].coreSwing.hasCoreHigh = false;
      m_states[contextIndex].coreSwing.coreSwingHigh = 0.0;
      m_states[contextIndex].coreSwing.coreSwingHighTime = 0;
      m_states[contextIndex].coreSwing.activeCoreType = CORE_SWING_LOW;
      m_states[contextIndex].coreSwing.initialized = true;
      m_states[contextIndex].coreSwing.lastCoreUpdate = eventBarTime;

      AuditCoreUpdate(contextIndex, CORE_SWING_LOW, origin,
                      oldCore, origin.price, hadCore, structuralLevel, reason);

      EmitEvent(contextIndex, hadCore ? CORE_SWING_CHANGED : CORE_SWING_INITIALIZED,
                 eventBarTime, MARKET_CYCLE_BULL, MARKET_CYCLE_BULL,
                 CORE_SWING_LOW, oldCore, origin.price, structuralLevel, reason);
   }

   void SetCoreHigh(const int contextIndex,
                    const SwingPoint &origin,
                    const datetime eventBarTime,
                    const string reason,
                    const double structuralLevel)
   {
      if(origin.price <= 0.0 || origin.time <= 0)
         return;

      const bool hadCore = m_states[contextIndex].coreSwing.hasCoreHigh;
      const double oldCore = m_states[contextIndex].coreSwing.coreSwingHigh;
      const datetime oldTime = m_states[contextIndex].coreSwing.coreSwingHighTime;
      if(hadCore && oldTime == origin.time)
         return;

      m_states[contextIndex].coreSwing.coreSwingHigh = origin.price;
      m_states[contextIndex].coreSwing.coreSwingHighTime = origin.time;
      m_states[contextIndex].coreSwing.hasCoreHigh = true;
      m_states[contextIndex].coreSwing.hasCoreLow = false;
      m_states[contextIndex].coreSwing.coreSwingLow = 0.0;
      m_states[contextIndex].coreSwing.coreSwingLowTime = 0;
      m_states[contextIndex].coreSwing.activeCoreType = CORE_SWING_HIGH;
      m_states[contextIndex].coreSwing.initialized = true;
      m_states[contextIndex].coreSwing.lastCoreUpdate = eventBarTime;

      AuditCoreUpdate(contextIndex, CORE_SWING_HIGH, origin,
                      oldCore, origin.price, hadCore, structuralLevel, reason);

      EmitEvent(contextIndex, hadCore ? CORE_SWING_CHANGED : CORE_SWING_INITIALIZED,
                 eventBarTime, MARKET_CYCLE_BEAR, MARKET_CYCLE_BEAR,
                 CORE_SWING_HIGH, oldCore, origin.price, structuralLevel, reason);
   }

   void HandleInitialCycleDirection(const int contextIndex, const SwingPoint &point)
   {
      // Confirmed local swings may establish the initial cycle direction, but
      // they never move the Core. Core updates are owned exclusively by the
      // closed-bar structural continuation-break path below.
      if(point.classification == STRUCT_HH)
      {
         if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_UNKNOWN
            && m_states[contextIndex].lastSwingLow.classification == STRUCT_HL)
            m_states[contextIndex].cycleState.cycle = MARKET_CYCLE_BULL;
      }
      else if(point.classification == STRUCT_LL)
      {
         if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_UNKNOWN
            && m_states[contextIndex].lastSwingHigh.classification == STRUCT_LH)
            m_states[contextIndex].cycleState.cycle = MARKET_CYCLE_BEAR;
      }
   }

   bool FindNearestOriginSwing(const int contextIndex,
                               const ENUM_SWING_TYPE originType,
                               const datetime structuralTime,
                               const datetime breakTime,
                               SwingPoint &origin,
                               int &confirmedCandidateCount,
                               int &rangeCandidateCount) const
   {
      ResetSwingPoint(origin);
      confirmedCandidateCount = 0;
      rangeCandidateCount = 0;
      for(int index = ArraySize(m_swingHistory) - 1; index >= 0; index--)
      {
         if(m_swingHistory[index].contextIndex != contextIndex)
            continue;

         const SwingPoint candidate = m_swingHistory[index].point;
         if(!candidate.confirmed || candidate.type != originType)
            continue;
         confirmedCandidateCount++;
         if(candidate.time <= structuralTime || candidate.time > breakTime)
            continue;

         rangeCandidateCount++;

         if(!origin.confirmed)
            origin = candidate;
      }

      return origin.confirmed;
   }

   datetime FindFirstRawReferenceBreakTime(const MqlRates &rates[],
                                           const int closedIndex,
                                           const ENUM_MARKET_CYCLE cycle,
                                           const SwingPoint &reference) const
   {
      for(int index = 0; index <= closedIndex; index++)
      {
         if(rates[index].time <= reference.time)
            continue;

         const bool rawBreak = cycle == MARKET_CYCLE_BULL
                               ? rates[index].close > reference.price
                               : rates[index].close < reference.price;
         if(rawBreak)
            return rates[index].time;
      }
      return 0;
   }

   void LogCoreBreakAudit(const int contextIndex,
                          const ENUM_MARKET_CYCLE cycle,
                          const SwingPoint &reference,
                          const MqlRates &closedBar,
                          const double atr,
                          const double buffer,
                          const double threshold,
                          const bool processed,
                          const int confirmedOriginCount,
                          const int rangeOriginCount,
                          const bool originFound,
                          const SwingPoint &origin,
                          const datetime firstRawBreakTime,
                          const string decision,
                          const string detail = "") const
   {
      if(!m_enableCoreBreakAuditLog || m_isBootstrapping)
         return;

      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      double currentCore = 0.0;
      bool hasCurrentCore = false;
      if(cycle == MARKET_CYCLE_BULL && m_states[contextIndex].coreSwing.hasCoreLow)
      {
         currentCore = m_states[contextIndex].coreSwing.coreSwingLow;
         hasCurrentCore = true;
      }
      else if(cycle == MARKET_CYCLE_BEAR && m_states[contextIndex].coreSwing.hasCoreHigh)
      {
         currentCore = m_states[contextIndex].coreSwing.coreSwingHigh;
         hasCurrentCore = true;
      }

      const double distance = cycle == MARKET_CYCLE_BULL
                              ? closedBar.close - threshold
                              : threshold - closedBar.close;
      const string referenceType = cycle == MARKET_CYCLE_BULL
                                   ? "SWING_HIGH" : "SWING_LOW";
      const string expectedOriginType = cycle == MARKET_CYCLE_BULL
                                        ? "SWING_LOW" : "SWING_HIGH";
      const bool brokeBeforeConfirmation = firstRawBreakTime > 0
                                           && reference.confirmationTime > 0
                                           && firstRawBreakTime
                                              < reference.confirmationTime;

      WatcherLog("CORE_BREAK_AUDIT",
                 "\nsymbol=" + m_symbols[contextIndex]
                 + "\ntf=" + WatcherTimeframeToString(m_timeframes[contextIndex])
                 + "\ncycle=" + MarketCycleToString(cycle)
                 + "\nreferenceType=" + referenceType
                 + "\nreferencePrice=" + DoubleToString(reference.price, digits)
                 + "\nreferenceTime=" + (reference.time > 0
                    ? TimeToString(reference.time, TIME_DATE | TIME_MINUTES) : "-")
                 + "\nreferenceConfirmationTime=" + (reference.confirmationTime > 0
                    ? TimeToString(reference.confirmationTime,
                                   TIME_DATE | TIME_MINUTES) : "-")
                 + "\nclose=" + DoubleToString(closedBar.close, digits)
                 + "\natr=" + DoubleToString(atr, digits)
                 + "\nbufferATR=" + DoubleToString(m_coreBreakATRBuffer, 2)
                 + "\nbuffer=" + DoubleToString(buffer, digits)
                 + "\nthreshold=" + DoubleToString(threshold, digits)
                 + "\ndistance=" + DoubleToString(distance, digits)
                 + "\nprocessed=" + (processed ? "TRUE" : "FALSE")
                 + "\nconfirmedOriginCandidateCount="
                    + IntegerToString(confirmedOriginCount)
                 + "\nrangeOriginCandidateCount=" + IntegerToString(rangeOriginCount)
                 + "\noriginFound=" + (originFound ? "TRUE" : "FALSE")
                 + "\noriginType=" + (originFound ? expectedOriginType : "-")
                 + "\noriginClassification=" + (originFound
                    ? StructurePointToString(origin.classification) : "-")
                 + "\noriginPrice=" + (originFound
                    ? DoubleToString(origin.price, digits) : "-")
                 + "\noriginTime=" + (originFound
                    ? TimeToString(origin.time, TIME_DATE | TIME_MINUTES) : "-")
                 + "\noriginConfirmationTime=" + (originFound
                    && origin.confirmationTime > 0
                    ? TimeToString(origin.confirmationTime,
                                   TIME_DATE | TIME_MINUTES) : "-")
                 + "\nfirstRawBreakTime=" + (firstRawBreakTime > 0
                    ? TimeToString(firstRawBreakTime, TIME_DATE | TIME_MINUTES) : "-")
                 + "\nbreakBeforeReferenceConfirmation="
                    + (brokeBeforeConfirmation ? "TRUE" : "FALSE")
                 + "\ncurrentCore=" + (hasCurrentCore
                    ? DoubleToString(currentCore, digits) : "-")
                 + "\ncandidateCore=" + (originFound
                    ? DoubleToString(origin.price, digits) : "-")
                 + "\ndecision=" + decision
                 + (detail == "" ? "" : "\ndetail=" + detail));
   }

   void LogNoNewClosedBarAudit(const int contextIndex,
                               const datetime currentBarTime,
                               const datetime latestClosedBarTime)
   {
      if(!m_enableCoreBreakAuditLog || m_isBootstrapping
         || currentBarTime <= 0
         || m_lastNoNewClosedBarAuditTime[contextIndex] == currentBarTime)
         return;

      m_lastNoNewClosedBarAuditTime[contextIndex] = currentBarTime;
      WatcherLog("CORE_BREAK_AUDIT",
                 "\nsymbol=" + m_symbols[contextIndex]
                 + "\ntf=" + WatcherTimeframeToString(m_timeframes[contextIndex])
                 + "\ncycle="
                    + MarketCycleToString(m_states[contextIndex].cycleState.cycle)
                 + "\ncurrentBarTime="
                    + TimeToString(currentBarTime, TIME_DATE | TIME_MINUTES)
                 + "\nlatestClosedBarTime=" + (latestClosedBarTime > 0
                    ? TimeToString(latestClosedBarTime,
                                   TIME_DATE | TIME_MINUTES) : "-")
                 + "\nlastProcessedClosedBarTime="
                    + (m_lastProcessedClosedBarTime[contextIndex] > 0
                       ? TimeToString(m_lastProcessedClosedBarTime[contextIndex],
                                      TIME_DATE | TIME_MINUTES) : "-")
                 + "\ndecision=REJECT_NO_NEW_CLOSED_BAR");
   }

   void LogPendingContinuation(const int contextIndex,
                               const PendingContinuationState &pending,
                               const datetime eventBarTime,
                               const string decision,
                               const int confirmedOriginCount,
                               const int rangeOriginCount,
                               const bool originFound,
                               const SwingPoint &origin,
                               const string detail = "") const
   {
      if(m_isBootstrapping)
         return;

      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      const string prefix = m_symbols[contextIndex] + " "
                            + WatcherTimeframeToString(m_timeframes[contextIndex])
                            + " | ";
      if(decision == "PENDING_ORIGIN_CREATED")
         WatcherLog("CORE", prefix + "Pending origin created");
      else if(decision == "PENDING_ORIGIN_CANCELLED_CYCLE_CHANGE")
         WatcherLog("CORE", prefix
                    + "Pending origin cancelled | Cycle changed");
      else if(decision == "PENDING_ORIGIN_EXPIRED")
         WatcherLog("CORE", prefix + "Pending origin expired");
      else if(decision == "PENDING_ORIGIN_RESOLVED")
      {
         const ENUM_CORE_SWING_TYPE resolvedCoreType =
            pending.cycleAtBreak == MARKET_CYCLE_BULL
            ? CORE_SWING_LOW : CORE_SWING_HIGH;
         WatcherLog("CORE", prefix + "Pending origin resolved"
                    + (originFound && detail == "CORE_MOVED"
                       ? " | " + JournalCoreText(resolvedCoreType) + " "
                         + DoubleToString(origin.price, digits)
                       : " | Core unchanged"));
      }

      if(!m_enableCoreBreakAuditLog)
         return;

      double currentCore = 0.0;
      bool hasCurrentCore = false;
      if(pending.cycleAtBreak == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow)
      {
         currentCore = m_states[contextIndex].coreSwing.coreSwingLow;
         hasCurrentCore = true;
      }
      else if(pending.cycleAtBreak == MARKET_CYCLE_BEAR
              && m_states[contextIndex].coreSwing.hasCoreHigh)
      {
         currentCore = m_states[contextIndex].coreSwing.coreSwingHigh;
         hasCurrentCore = true;
      }

      WatcherLog("CORE_BREAK_AUDIT",
                 "\nsymbol=" + m_symbols[contextIndex]
                 + "\ntf=" + WatcherTimeframeToString(m_timeframes[contextIndex])
                 + "\ncycle=" + MarketCycleToString(pending.cycleAtBreak)
                 + "\nreferenceType=" + (pending.referenceType == SWING_HIGH
                    ? "SWING_HIGH" : "SWING_LOW")
                 + "\nreferencePrice="
                    + DoubleToString(pending.referencePrice, digits)
                 + "\nreferenceTime="
                    + TimeToString(pending.referenceTime, TIME_DATE | TIME_MINUTES)
                 + "\nreferenceConfirmationTime="
                    + TimeToString(pending.referenceConfirmationTime,
                                   TIME_DATE | TIME_MINUTES)
                 + "\nbreakTime="
                    + TimeToString(pending.breakTime, TIME_DATE | TIME_MINUTES)
                 + "\nbreakThreshold="
                    + DoubleToString(pending.breakThreshold, digits)
                 + "\neventBarTime="
                    + TimeToString(eventBarTime, TIME_DATE | TIME_MINUTES)
                 + "\nconfirmedOriginCandidateCount="
                    + IntegerToString(confirmedOriginCount)
                 + "\nrangeOriginCandidateCount="
                    + IntegerToString(rangeOriginCount)
                 + "\noriginFound=" + (originFound ? "TRUE" : "FALSE")
                 + "\noriginClassification=" + (originFound
                    ? StructurePointToString(origin.classification) : "-")
                 + "\noriginPivotTime=" + (originFound
                    ? TimeToString(origin.time, TIME_DATE | TIME_MINUTES) : "-")
                 + "\noriginConfirmationTime=" + (originFound
                    ? TimeToString(origin.confirmationTime,
                                   TIME_DATE | TIME_MINUTES) : "-")
                 + "\ncurrentCore=" + (hasCurrentCore
                    ? DoubleToString(currentCore, digits) : "-")
                 + "\ncandidateCore=" + (originFound
                    ? DoubleToString(origin.price, digits) : "-")
                 + "\ndecision=" + decision
                 + (detail == "" ? "" : "\ndetail=" + detail));
   }

   void CreatePendingContinuation(const int contextIndex,
                                   const ENUM_MARKET_CYCLE cycle,
                                   const SwingPoint &reference,
                                   const MqlRates &breakBar,
                                   const double threshold,
                                   const int confirmedOriginCount,
                                   const int rangeOriginCount,
                                   const bool fromSidewayBox)
   {
      m_pendingContinuations[contextIndex].active = true;
      m_pendingContinuations[contextIndex].referenceType = reference.type;
      m_pendingContinuations[contextIndex].referencePrice = reference.price;
      m_pendingContinuations[contextIndex].referenceTime = reference.time;
      m_pendingContinuations[contextIndex].referenceConfirmationTime =
         reference.confirmationTime;
      m_pendingContinuations[contextIndex].breakTime = breakBar.time;
      m_pendingContinuations[contextIndex].breakThreshold = threshold;
      m_pendingContinuations[contextIndex].cycleAtBreak = cycle;
      m_pendingContinuations[contextIndex].fromSidewayBox = fromSidewayBox;

      SwingPoint noOrigin;
      ResetSwingPoint(noOrigin);
      LogPendingContinuation(contextIndex, m_pendingContinuations[contextIndex],
                             breakBar.time,
                             "PENDING_ORIGIN_CREATED",
                             confirmedOriginCount, rangeOriginCount,
                             false, noOrigin,
                             confirmedOriginCount > 0
                             ? "ORIGIN_TIME_RANGE_NOT_READY"
                             : "NO_VALID_ORIGIN_YET");
   }

   bool ResolvePendingContinuation(const int contextIndex,
                                   const MqlRates &closedBar,
                                   const SwingPoint &currentReference)
   {
      PendingContinuationState pending = m_pendingContinuations[contextIndex];
      if(!pending.active)
         return false;

      SwingPoint origin;
      ResetSwingPoint(origin);

      if(pending.cycleAtBreak != m_states[contextIndex].cycleState.cycle)
      {
         LogPendingContinuation(contextIndex, pending, closedBar.time,
                                "PENDING_ORIGIN_CANCELLED_CYCLE_CHANGE",
                                0, 0, false, origin);
         ResetPendingContinuationState(m_pendingContinuations[contextIndex]);
         return true;
      }

      if(m_states[contextIndex].cycleState.breakCandidate)
      {
         LogPendingContinuation(contextIndex, pending, closedBar.time,
                                "PENDING_ORIGIN_WAITING",
                                0, 0, false, origin,
                                "CORE_BREAK_CANDIDATE_ACTIVE");
         return true;
      }

      const bool newerReferenceAfterSidewayBreak = pending.fromSidewayBox
         && currentReference.type == pending.referenceType
         && currentReference.time > pending.breakTime;
      if((!pending.fromSidewayBox
          && currentReference.time != pending.referenceTime)
         || newerReferenceAfterSidewayBreak)
      {
         LogPendingContinuation(contextIndex, pending, closedBar.time,
                                "PENDING_ORIGIN_EXPIRED",
                                0, 0, false, origin,
                                "NEW_STRUCTURAL_REFERENCE="
                                + IntegerToString((long)currentReference.time));
         ResetPendingContinuationState(m_pendingContinuations[contextIndex]);
         return false;
      }

      int confirmedOriginCount = 0;
      int rangeOriginCount = 0;
      const ENUM_SWING_TYPE originType = pending.cycleAtBreak == MARKET_CYCLE_BULL
                                         ? SWING_LOW : SWING_HIGH;
      if(!FindNearestOriginSwing(contextIndex, originType,
                                 pending.referenceTime, pending.breakTime,
                                 origin, confirmedOriginCount,
                                 rangeOriginCount))
      {
         LogPendingContinuation(contextIndex, pending, closedBar.time,
                                "PENDING_ORIGIN_WAITING",
                                confirmedOriginCount, rangeOriginCount,
                                false, origin,
                                confirmedOriginCount > 0
                                ? "ORIGIN_TIME_RANGE_NOT_READY"
                                : "NO_VALID_ORIGIN_YET");
         return true;
      }

      bool monotonicPass = true;
      if(pending.cycleAtBreak == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow
         && origin.price <= m_states[contextIndex].coreSwing.coreSwingLow)
         monotonicPass = false;
      else if(pending.cycleAtBreak == MARKET_CYCLE_BEAR
              && m_states[contextIndex].coreSwing.hasCoreHigh
              && origin.price >= m_states[contextIndex].coreSwing.coreSwingHigh)
         monotonicPass = false;

      if(pending.cycleAtBreak == MARKET_CYCLE_BULL)
         m_lastBullContinuationReferenceTime[contextIndex] = pending.referenceTime;
      else
         m_lastBearContinuationReferenceTime[contextIndex] = pending.referenceTime;

      if(monotonicPass)
      {
         if(pending.cycleAtBreak == MARKET_CYCLE_BULL)
            SetCoreLow(contextIndex, origin, closedBar.time,
                       "Break High confirmed", pending.referencePrice);
         else
            SetCoreHigh(contextIndex, origin, closedBar.time,
                        "Break Low confirmed", pending.referencePrice);
      }

      LogPendingContinuation(contextIndex, pending, closedBar.time,
                             "PENDING_ORIGIN_RESOLVED",
                             confirmedOriginCount, rangeOriginCount,
                             true, origin,
                             monotonicPass ? "CORE_MOVED" : "REJECT_MONOTONIC");
      ResetPendingContinuationState(m_pendingContinuations[contextIndex]);
      return true;
   }

   void ProcessContinuationBreak(const int contextIndex,
                                 const ENUM_MARKET_CYCLE cycle,
                                 const SwingPoint &reference,
                                 const MqlRates &closedBar,
                                 const double atr,
                                 const double buffer,
                                 const double threshold,
                                 const datetime firstRawBreakTime,
                                 const bool fromSidewayBox)
   {
      SwingPoint origin;
      ResetSwingPoint(origin);
      int confirmedOriginCount = 0;
      int rangeOriginCount = 0;
      const ENUM_SWING_TYPE originType = cycle == MARKET_CYCLE_BULL
                                         ? SWING_LOW : SWING_HIGH;
      if(!FindNearestOriginSwing(contextIndex, originType, reference.time,
                                 closedBar.time, origin,
                                 confirmedOriginCount, rangeOriginCount))
      {
         CreatePendingContinuation(contextIndex, cycle, reference,
                                   closedBar, threshold,
                                   confirmedOriginCount, rangeOriginCount,
                                   fromSidewayBox);
         return;
      }

      bool monotonicPass = true;
      if(cycle == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow
         && origin.price <= m_states[contextIndex].coreSwing.coreSwingLow)
         monotonicPass = false;
      else if(cycle == MARKET_CYCLE_BEAR
              && m_states[contextIndex].coreSwing.hasCoreHigh
              && origin.price >= m_states[contextIndex].coreSwing.coreSwingHigh)
         monotonicPass = false;

      if(cycle == MARKET_CYCLE_BULL)
         m_lastBullContinuationReferenceTime[contextIndex] = reference.time;
      else
         m_lastBearContinuationReferenceTime[contextIndex] = reference.time;

      if(!monotonicPass)
      {
         LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                           threshold, false, confirmedOriginCount,
                           rangeOriginCount, true, origin,
                           firstRawBreakTime, "REJECT_MONOTONIC",
                           fromSidewayBox ? "SIDEWAY_BOX_BREAKOUT" : "");
         return;
      }

      if(cycle == MARKET_CYCLE_BULL)
         SetCoreLow(contextIndex, origin, closedBar.time,
                    "Break High confirmed", reference.price);
      else
         SetCoreHigh(contextIndex, origin, closedBar.time,
                     "Break Low confirmed", reference.price);

      LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                        threshold, false, confirmedOriginCount,
                        rangeOriginCount, true, origin,
                        firstRawBreakTime, "CORE_MOVED",
                        fromSidewayBox ? "SIDEWAY_BOX_BREAKOUT" : "");
   }

   void EvaluateStructuralContinuation(const int contextIndex,
                                       const MqlRates &rates[],
                                       const int closedIndex,
                                       const MqlRates &closedBar,
                                       const double atr)
   {
      const ENUM_MARKET_CYCLE cycle = m_states[contextIndex].cycleState.cycle;
      if(cycle == MARKET_CYCLE_UNKNOWN)
         return;

      const double buffer = m_useCoreBreakATRBuffer ? atr * m_coreBreakATRBuffer : 0.0;
      const SwingPoint reference = cycle == MARKET_CYCLE_BULL
                                   ? m_states[contextIndex].lastSwingHigh
                                   : m_states[contextIndex].lastSwingLow;
      const double threshold = cycle == MARKET_CYCLE_BULL
                               ? reference.price + buffer
                               : reference.price - buffer;
      if(ResolvePendingContinuation(contextIndex, closedBar, reference))
         return;

      double pointSize = SymbolInfoDouble(m_symbols[contextIndex], SYMBOL_POINT);
      if(pointSize <= 0.0)
         pointSize = 0.00000001;
      const double nearWindow = MathMax(buffer,
                                        atr > 0.0 ? atr * 0.05 : pointSize * 10.0);
      const bool relevant = reference.price > 0.0
                            && (cycle == MARKET_CYCLE_BULL
                                ? (closedBar.close > reference.price
                                   || (threshold >= closedBar.close
                                       && threshold - closedBar.close <= nearWindow))
                                : (closedBar.close < reference.price
                                   || (closedBar.close >= threshold
                                       && closedBar.close - threshold <= nearWindow)));
      if(!relevant)
         return;

      const bool processed = cycle == MARKET_CYCLE_BULL
                             ? reference.time
                               == m_lastBullContinuationReferenceTime[contextIndex]
                             : reference.time
                               == m_lastBearContinuationReferenceTime[contextIndex];
      const datetime firstRawBreakTime = FindFirstRawReferenceBreakTime(
                                            rates, closedIndex, cycle, reference);
      SwingPoint origin;
      ResetSwingPoint(origin);

      if(!reference.confirmed)
      {
         LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                           threshold, processed, 0, 0, false, origin,
                           firstRawBreakTime, "REJECT_REFERENCE_NOT_CONFIRMED");
         return;
      }
      if(m_states[contextIndex].cycleState.breakCandidate)
      {
         LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                           threshold, processed, 0, 0, false, origin,
                           firstRawBreakTime, "REJECT_OTHER",
                           "CORE_BREAK_CANDIDATE_ACTIVE");
         return;
      }
      if(m_useCoreBreakATRBuffer && atr <= 0.0)
      {
         LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                           threshold, processed, 0, 0, false, origin,
                           firstRawBreakTime, "REJECT_OTHER", "ATR_NOT_AVAILABLE");
         return;
      }
      if(processed)
      {
         LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                           threshold, true, 0, 0, false, origin,
                           firstRawBreakTime,
                           "REJECT_REFERENCE_ALREADY_PROCESSED");
         return;
      }

      if(cycle == MARKET_CYCLE_BULL)
      {
         if(closedBar.close <= threshold)
         {
            LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                              threshold, false, 0, 0, false, origin,
                              firstRawBreakTime,
                              "REJECT_CLOSE_BELOW_THRESHOLD");
            return;
         }

         ProcessContinuationBreak(contextIndex, cycle, reference, closedBar,
                                  atr, buffer, threshold, firstRawBreakTime,
                                  false);
      }
      else if(cycle == MARKET_CYCLE_BEAR)
      {
         if(closedBar.close >= threshold)
         {
            LogCoreBreakAudit(contextIndex, cycle, reference, closedBar, atr, buffer,
                              threshold, false, 0, 0, false, origin,
                              firstRawBreakTime,
                              "REJECT_CLOSE_ABOVE_THRESHOLD");
            return;
         }

         ProcessContinuationBreak(contextIndex, cycle, reference, closedBar,
                                  atr, buffer, threshold, firstRawBreakTime,
                                  false);
      }
   }

   void LogSwing(const int contextIndex, const SwingPoint &point) const
   {
      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      WatcherLog("SWING", m_symbols[contextIndex]
                 + " " + WatcherTimeframeToString(m_timeframes[contextIndex])
                 + " | " + StructurePointToString(point.classification)
                 + " | " + DoubleToString(point.price, digits));
   }

   void AcceptSwing(const int contextIndex,
                    const ENUM_SWING_TYPE swingType,
                    const MqlRates &rate,
                    const int shift,
                    const datetime confirmationTime)
   {
      SwingPoint point;
      ResetSwingPoint(point);
      point.time = rate.time;
      point.shift = shift;
      point.price = swingType == SWING_HIGH ? rate.high : rate.low;
      point.type = swingType;
      point.confirmationTime = confirmationTime;
      point.confirmed = true;

      if(swingType == SWING_HIGH)
      {
         point.classification = ClassifySwingHigh(contextIndex, point.price);
         point.originSwingRecordIndex = m_lastLowRecordIndex[contextIndex];
         if(m_states[contextIndex].lastSwingLow.confirmed
            && m_states[contextIndex].lastSwingLow.time < point.time)
         {
            point.originSwingTime = m_states[contextIndex].lastSwingLow.time;
            point.originSwingPrice = m_states[contextIndex].lastSwingLow.price;
         }

         m_states[contextIndex].previousSwingHigh = m_states[contextIndex].lastSwingHigh;
         m_states[contextIndex].lastSwingHigh = point;
      }
      else
      {
         point.classification = ClassifySwingLow(contextIndex, point.price);
         point.originSwingRecordIndex = m_lastHighRecordIndex[contextIndex];
         if(m_states[contextIndex].lastSwingHigh.confirmed
            && m_states[contextIndex].lastSwingHigh.time < point.time)
         {
            point.originSwingTime = m_states[contextIndex].lastSwingHigh.time;
            point.originSwingPrice = m_states[contextIndex].lastSwingHigh.price;
         }

         m_states[contextIndex].previousSwingLow = m_states[contextIndex].lastSwingLow;
         m_states[contextIndex].lastSwingLow = point;
      }

      m_states[contextIndex].lastStructureUpdate = confirmationTime;
      m_states[contextIndex].lastEvent = StructurePointToString(point.classification);
      m_states[contextIndex].lastEventTime = confirmationTime;
      UpdateStructureSummary(contextIndex);

      const int recordIndex = AppendSwing(contextIndex, point);
      if(swingType == SWING_HIGH)
         m_lastHighRecordIndex[contextIndex] = recordIndex;
      else
         m_lastLowRecordIndex[contextIndex] = recordIndex;

      // A confirmed same-side extreme formed while the two-close Core-break
      // candidate is active becomes the origin of the final confirmation leg.
      if(m_states[contextIndex].cycleState.breakCandidate)
      {
         const ENUM_SWING_TYPE originType =
            m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BULL
            ? SWING_HIGH : SWING_LOW;
         if(point.type == originType)
            m_breakOrigins[contextIndex] = point;
      }

      if(!m_isBootstrapping)
         LogSwing(contextIndex, point);
      HandleInitialCycleDirection(contextIndex, point);
   }

   bool HasActiveCoreForCycle(const int contextIndex) const
   {
      const ENUM_MARKET_CYCLE cycle = m_states[contextIndex].cycleState.cycle;
      return (cycle == MARKET_CYCLE_BULL
              && m_states[contextIndex].coreSwing.hasCoreLow)
             || (cycle == MARKET_CYCLE_BEAR
                 && m_states[contextIndex].coreSwing.hasCoreHigh);
   }

   double ActiveCorePriceForCycle(const int contextIndex) const
   {
      if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow)
         return m_states[contextIndex].coreSwing.coreSwingLow;
      if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BEAR
         && m_states[contextIndex].coreSwing.hasCoreHigh)
         return m_states[contextIndex].coreSwing.coreSwingHigh;
      return 0.0;
   }

   bool FindParentRangeRotation(const int contextIndex,
                                const datetime closedBarTime,
                                SwingPoint &directionalExtreme,
                                SwingPoint &firstRotation,
                                SwingPoint &internalTurn,
                                SwingPoint &rotationBreak,
                                int &extremeRecord,
                                int &firstRotationRecord,
                                int &internalTurnRecord,
                                int &rotationBreakRecord) const
   {
      ResetSwingPoint(directionalExtreme);
      ResetSwingPoint(firstRotation);
      ResetSwingPoint(internalTurn);
      ResetSwingPoint(rotationBreak);
      extremeRecord = -1;
      firstRotationRecord = -1;
      internalTurnRecord = -1;
      rotationBreakRecord = -1;

      const ENUM_MARKET_CYCLE cycle = m_states[contextIndex].cycleState.cycle;
      if(cycle == MARKET_CYCLE_UNKNOWN || !HasActiveCoreForCycle(contextIndex))
         return false;

      const ENUM_SWING_TYPE directionalType = cycle == MARKET_CYCLE_BEAR
                                               ? SWING_LOW : SWING_HIGH;
      const ENUM_SWING_TYPE rotationType = cycle == MARKET_CYCLE_BEAR
                                            ? SWING_HIGH : SWING_LOW;
      const ENUM_STRUCTURE_POINT extremeClass = cycle == MARKET_CYCLE_BEAR
                                                 ? STRUCT_LL : STRUCT_HH;
      const datetime coreTime = cycle == MARKET_CYCLE_BEAR
         ? m_states[contextIndex].coreSwing.coreSwingHighTime
         : m_states[contextIndex].coreSwing.coreSwingLowTime;

      // The newest directional extreme is the child boundary of the parent
      // trend range. Consecutive LL/HH continuations naturally replace it.
      for(int index = ArraySize(m_swingHistory) - 1; index >= 0; index--)
      {
         if(m_swingHistory[index].contextIndex != contextIndex)
            continue;
         const SwingPoint point = m_swingHistory[index].point;
         if(!point.confirmed || point.confirmationTime <= 0
            || point.confirmationTime > closedBarTime
            || point.confirmationTime <= m_sidewayCandidateStartTime[contextIndex]
            || point.time <= coreTime
            || point.type != directionalType
            || point.classification != extremeClass)
            continue;
         directionalExtreme = point;
         extremeRecord = index;
         break;
      }
      if(extremeRecord < 0)
         return false;

      const double parentCore = ActiveCorePriceForCycle(contextIndex);
      if((cycle == MARKET_CYCLE_BEAR
          && parentCore <= directionalExtreme.price)
         || (cycle == MARKET_CYCLE_BULL
             && parentCore >= directionalExtreme.price))
         return false;

      // Confirm a genuine internal rotation by price relationships rather
      // than by one hard-coded HH/HL/LH/LL label sequence:
      // extreme -> opposite swing -> contained turn -> opposite expansion.
      int stage = 0;
      const int historyCount = ArraySize(m_swingHistory);
      for(int index = extremeRecord + 1; index < historyCount; index++)
      {
         if(m_swingHistory[index].contextIndex != contextIndex)
            continue;
         const SwingPoint point = m_swingHistory[index].point;
         if(!point.confirmed || point.confirmationTime <= 0
            || point.confirmationTime > closedBarTime
            || point.time <= directionalExtreme.time
            || point.confirmationTime <= directionalExtreme.confirmationTime)
            continue;

         const bool insideParentRange = point.price > MathMin(parentCore,
                                                               directionalExtreme.price)
                                        && point.price < MathMax(parentCore,
                                                                directionalExtreme.price);
         if(!insideParentRange)
            return false;

         if(stage == 0)
         {
            if(point.type != rotationType)
               continue;
            firstRotation = point;
            firstRotationRecord = index;
            stage = 1;
            continue;
         }

         if(stage == 1)
         {
            if(point.type == rotationType)
            {
               const bool extendsRotation = cycle == MARKET_CYCLE_BEAR
                  ? point.price > firstRotation.price
                  : point.price < firstRotation.price;
               if(extendsRotation)
               {
                  firstRotation = point;
                  firstRotationRecord = index;
               }
               continue;
            }
            if(point.type != directionalType)
               continue;
            const bool turnsInside = cycle == MARKET_CYCLE_BEAR
               ? point.price > directionalExtreme.price
               : point.price < directionalExtreme.price;
            if(!turnsInside)
               return false;
            internalTurn = point;
            internalTurnRecord = index;
            stage = 2;
            continue;
         }

         if(point.type == directionalType)
         {
            const bool remainsContained = cycle == MARKET_CYCLE_BEAR
               ? point.price > directionalExtreme.price
               : point.price < directionalExtreme.price;
            if(!remainsContained)
               return false;
            internalTurn = point;
            internalTurnRecord = index;
            continue;
         }
         if(point.type != rotationType)
            continue;

         const bool confirmsRotation = cycle == MARKET_CYCLE_BEAR
            ? point.price > firstRotation.price
            : point.price < firstRotation.price;
         if(!confirmsRotation)
            continue;
         rotationBreak = point;
         rotationBreakRecord = index;
         return true;
      }
      return false;
   }

   void LogSidewayTransition(const int contextIndex,
                             const string state,
                             const SidewayBoxState &box,
                             const datetime eventTime,
                             const string detail = "") const
   {
      if(m_isBootstrapping)
         return;

      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      const string prefix = m_symbols[contextIndex] + " "
                            + WatcherTimeframeToString(m_timeframes[contextIndex])
                            + " | ";
      if(state == "CONFIRMED")
      {
         WatcherLog("SIDEWAY", prefix + JournalCycleText(box.ownerCycle)
                    + " | Activated | High "
                    + DoubleToString(box.boxHigh, digits)
                    + " | Low " + DoubleToString(box.boxLow, digits));
      }
      else if(state == "BREAKOUT")
      {
         const bool upperBreak = StringFind(detail, "BOX_BREAKOUT_UP") >= 0;
         WatcherLog("SIDEWAY", prefix
                    + (upperBreak ? "Breakout high | " : "Breakout low | ")
                    + DoubleToString(upperBreak ? box.boxHigh : box.boxLow,
                                     digits));
      }

      if(m_enableAuditLog || m_enableCoreBreakAuditLog)
      {
         WatcherLog("AUDIT][SIDEWAY", prefix + "state=" + state
                    + " | ownerCycle=" + MarketCycleToString(box.ownerCycle)
                    + " | boxHigh=" + DoubleToString(box.boxHigh, digits)
                    + " | boxLow=" + DoubleToString(box.boxLow, digits)
                    + " | coreFrozen="
                       + DoubleToString(box.activeCoreAtEntry, digits)
                    + " | eventTime="
                       + TimeToString(eventTime, TIME_DATE | TIME_MINUTES)
                    + (detail == "" ? "" : " | " + detail));
      }
   }

   void CancelPendingContinuationForSideway(const int contextIndex,
                                            const datetime eventBarTime)
   {
      if(!m_pendingContinuations[contextIndex].active)
         return;

      SwingPoint noOrigin;
      ResetSwingPoint(noOrigin);
      LogPendingContinuation(contextIndex, m_pendingContinuations[contextIndex],
                             eventBarTime, "PENDING_ORIGIN_EXPIRED",
                             0, 0, false, noOrigin,
                             "SIDEWAY_CONFIRMED");
      ResetPendingContinuationState(m_pendingContinuations[contextIndex]);
   }

   void ArchiveSidewayBox(const int contextIndex,
                          const datetime endTime,
                          const ENUM_SIDEWAY_BOX_STATUS endStatus)
   {
      const SidewayBoxState box = m_states[contextIndex].sidewayBox;
      if(m_isBootstrapping || !box.active || box.boxStartTime <= 0
         || endTime <= box.boxStartTime)
         return;

      SidewayBoxRecord record;
      record.symbol = m_symbols[contextIndex];
      record.timeframe = m_timeframes[contextIndex];
      record.boxHigh = box.boxHigh;
      record.boxLow = box.boxLow;
      record.boxStartTime = box.boxStartTime;
      record.boxEndTime = endTime;
      record.endStatus = endStatus;

      const int count = ArraySize(m_sidewayBoxHistory);
      for(int index = 0; index < count; index++)
      {
         if(m_sidewayBoxHistory[index].symbol == record.symbol
            && m_sidewayBoxHistory[index].timeframe == record.timeframe
            && m_sidewayBoxHistory[index].boxStartTime == record.boxStartTime)
            return;
      }

      ArrayResize(m_sidewayBoxHistory, count + 1);
      m_sidewayBoxHistory[count] = record;
   }

   void ExitSidewayBox(const int contextIndex,
                       const datetime eventTime,
                       const ENUM_SIDEWAY_BOX_STATUS endStatus,
                       const string logState,
                       const string detail = "")
   {
      if(!m_states[contextIndex].sidewayBox.active)
         return;

      const SidewayBoxState oldBox = m_states[contextIndex].sidewayBox;
      ArchiveSidewayBox(contextIndex, eventTime, endStatus);
      LogSidewayTransition(contextIndex, logState, oldBox, eventTime, detail);
      ResetSidewayBoxState(m_states[contextIndex].sidewayBox);
      m_states[contextIndex].sidewayBox.status = endStatus;
      m_sidewayCandidateStartTime[contextIndex] = eventTime;
   }

   void LogSidewayCandidateTransition(const int contextIndex,
                                      const string state,
                                      const SidewayBoxState &candidate,
                                      const datetime eventTime,
                                      const string detail = "") const
   {
      if(m_isBootstrapping
         || (!m_enableAuditLog && !m_enableCoreBreakAuditLog))
         return;

      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      WatcherLog("SIDEWAY", m_symbols[contextIndex] + " "
                 + WatcherTimeframeToString(m_timeframes[contextIndex])
                 + " | STATE=" + state
                 + " | cycle="
                    + MarketCycleToString(candidate.cycleAtCandidate)
                 + " | boxHigh="
                    + DoubleToString(candidate.candidateBoxHigh, digits)
                 + " | boxLow="
                    + DoubleToString(candidate.candidateBoxLow, digits)
                 + " | eventTime="
                    + TimeToString(eventTime, TIME_DATE | TIME_MINUTES)
                 + (detail == "" ? "" : " | " + detail));
   }

   void InvalidateSidewayCandidate(const int contextIndex,
                                   const datetime eventTime,
                                   const string state,
                                   const string reason)
   {
      if(!m_states[contextIndex].sidewayBox.candidateActive)
         return;

      const SidewayBoxState candidate = m_states[contextIndex].sidewayBox;
      LogSidewayCandidateTransition(contextIndex, state, candidate,
                                    eventTime, "reason=" + reason);
      ResetSidewayBoxState(m_states[contextIndex].sidewayBox);
      m_states[contextIndex].sidewayBox.status = SIDEWAY_BOX_CANCELLED;
      m_sidewayCandidateStartTime[contextIndex] = eventTime;
   }

   bool FindCandidateConfirmationSwing(const int contextIndex,
                                       const SidewayBoxState &candidate,
                                       SwingPoint &confirmationSwing,
                                       int &confirmationRecord) const
   {
      ResetSwingPoint(confirmationSwing);
      confirmationRecord = -1;
      const ENUM_SWING_TYPE requiredType =
         candidate.candidateWaitState == SIDEWAY_WAIT_POST_LL_HIGH
         ? SWING_HIGH : (candidate.candidateWaitState == SIDEWAY_WAIT_POST_HH_LOW
                         ? SWING_LOW : SWING_NONE);
      if(requiredType == SWING_NONE)
         return false;

      const int count = ArraySize(m_swingHistory);
      for(int index = candidate.candidateTerminalRecord + 1;
          index < count; index++)
      {
         if(m_swingHistory[index].contextIndex != contextIndex)
            continue;

         const SwingPoint point = m_swingHistory[index].point;
         if(!point.confirmed || point.type != requiredType
            || point.time <= candidate.candidateTerminalTime
            || point.confirmationTime
               <= candidate.candidateTerminalConfirmationTime)
            continue;

         confirmationSwing = point;
         confirmationRecord = index;
         return true;
      }
      return false;
   }

   bool TryCreateSidewayCandidate(const int contextIndex,
                                  const MqlRates &rates[],
                                  const int closedIndex,
                                  const MqlRates &closedBar,
                                  const double atr)
   {
      if(m_states[contextIndex].sidewayBox.active
         || m_states[contextIndex].sidewayBox.candidateActive
         || !HasActiveCoreForCycle(contextIndex))
         return false;
      if(m_useCoreBreakATRBuffer && atr <= 0.0)
         return false;

      SwingPoint directionalExtreme, firstRotation, internalTurn, rotationBreak;
      int extremeRecord, firstRotationRecord, internalTurnRecord;
      int rotationBreakRecord;
      if(!FindParentRangeRotation(contextIndex, closedBar.time,
                                  directionalExtreme, firstRotation,
                                  internalTurn, rotationBreak,
                                  extremeRecord, firstRotationRecord,
                                  internalTurnRecord, rotationBreakRecord))
         return false;

      const ENUM_MARKET_CYCLE cycle = m_states[contextIndex].cycleState.cycle;
      const double parentCore = ActiveCorePriceForCycle(contextIndex);
      const double boxHigh = cycle == MARKET_CYCLE_BULL
                             ? directionalExtreme.price : parentCore;
      const double boxLow = cycle == MARKET_CYCLE_BULL
                            ? parentCore : directionalExtreme.price;
      if(boxHigh <= boxLow)
         return false;

      const double buffer = m_useCoreBreakATRBuffer
                            ? atr * m_coreBreakATRBuffer : 0.0;
      const datetime boxStartTime = directionalExtreme.time;
      datetime latestPriorBreakTime = 0;
      for(int index = 0; index <= closedIndex; index++)
      {
         if(rates[index].time < boxStartTime)
            continue;
         if(rates[index].close > boxHigh + buffer
            || rates[index].close < boxLow - buffer)
            latestPriorBreakTime = rates[index].time;
      }
      if(latestPriorBreakTime > 0)
      {
         m_sidewayCandidateStartTime[contextIndex] = latestPriorBreakTime;
         return false;
      }

      SidewayBoxState candidate = m_states[contextIndex].sidewayBox;
      ResetSidewayBoxState(candidate);
      candidate.status = SIDEWAY_BOX_CANDIDATE;
      candidate.candidateActive = true;
      candidate.candidateBoxHigh = boxHigh;
      candidate.candidateBoxHighTime = cycle == MARKET_CYCLE_BULL
         ? directionalExtreme.time
         : m_states[contextIndex].coreSwing.coreSwingHighTime;
      candidate.candidateBoxLow = boxLow;
      candidate.candidateBoxLowTime = cycle == MARKET_CYCLE_BULL
         ? m_states[contextIndex].coreSwing.coreSwingLowTime
         : directionalExtreme.time;
      candidate.candidateStartTime = boxStartTime;
      candidate.candidateCreatedTime = closedBar.time;
      candidate.candidateBoundaryRecord = extremeRecord;
      candidate.candidatePullbackRecord = firstRotationRecord;
      candidate.candidateReversalRecord = internalTurnRecord;
      candidate.candidateTerminalRecord = rotationBreakRecord;
      candidate.candidateBoundaryTime = directionalExtreme.time;
      candidate.candidatePullbackTime = firstRotation.time;
      candidate.candidateReversalTime = internalTurn.time;
      candidate.candidateTerminalTime = rotationBreak.time;
      candidate.candidateTerminalConfirmationTime = rotationBreak.confirmationTime;
      candidate.candidateWaitState = cycle == MARKET_CYCLE_BULL
         ? SIDEWAY_WAIT_POST_LL_HIGH : SIDEWAY_WAIT_POST_HH_LOW;
      candidate.cycleAtCandidate = cycle;
      candidate.coreAtCandidate = ActiveCorePriceForCycle(contextIndex);
      m_states[contextIndex].sidewayBox = candidate;

      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      const string detail = cycle == MARKET_CYCLE_BULL
         ? "cycle=BULL | parentCore=" + DoubleToString(parentCore, digits)
           + " | extremeHH=" + DoubleToString(directionalExtreme.price, digits)
           + " | firstRotation=" + DoubleToString(firstRotation.price, digits)
           + " | internalTurn=" + DoubleToString(internalTurn.price, digits)
           + " | rotationBreak=" + DoubleToString(rotationBreak.price, digits)
           + " | waiting=POST_LL_HIGH | SIDEWAY=FALSE | CORE_FROZEN=FALSE"
         : "cycle=BEAR | parentCore=" + DoubleToString(parentCore, digits)
           + " | extremeLL=" + DoubleToString(directionalExtreme.price, digits)
           + " | firstRotation=" + DoubleToString(firstRotation.price, digits)
           + " | internalTurn=" + DoubleToString(internalTurn.price, digits)
           + " | rotationBreak=" + DoubleToString(rotationBreak.price, digits)
           + " | waiting=POST_HH_LOW | SIDEWAY=FALSE | CORE_FROZEN=FALSE";
      LogSidewayCandidateTransition(contextIndex,
                                    "ROTATION_STARTED",
                                    candidate, closedBar.time, detail);
      return false;
   }

   bool ActivateSidewayBox(const int contextIndex,
                           const double boxHigh,
                           const datetime boxHighTime,
                           const double boxLow,
                           const datetime boxLowTime,
                           const datetime boxStartTime,
                           const SwingPoint &confirmationSwing,
                           const MqlRates &closedBar,
                           const string source)
   {
      ResetSidewayBoxState(m_states[contextIndex].sidewayBox);
      m_states[contextIndex].sidewayBox.status = SIDEWAY_BOX_ACTIVE;
      m_states[contextIndex].sidewayBox.active = true;
      m_states[contextIndex].sidewayBox.boxHigh = boxHigh;
      m_states[contextIndex].sidewayBox.boxHighTime = boxHighTime;
      m_states[contextIndex].sidewayBox.boxLow = boxLow;
      m_states[contextIndex].sidewayBox.boxLowTime = boxLowTime;
      m_states[contextIndex].sidewayBox.boxStartTime = boxStartTime;
      m_states[contextIndex].sidewayBox.confirmedTime =
         confirmationSwing.confirmationTime;
      m_states[contextIndex].sidewayBox.lastUpdateTime = closedBar.time;
      m_states[contextIndex].sidewayBox.ownerCycle =
         m_states[contextIndex].cycleState.cycle;
      m_states[contextIndex].sidewayBox.activeCoreAtEntry =
         ActiveCorePriceForCycle(contextIndex);

      CancelPendingContinuationForSideway(contextIndex, closedBar.time);
      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      LogSidewayTransition(contextIndex, "CONFIRMED",
                           m_states[contextIndex].sidewayBox, closedBar.time,
                            "source=" + source
                            + " | ownerCycle="
                            + MarketCycleToString(
                                 m_states[contextIndex].sidewayBox.ownerCycle)
                           + " | confirmationSwing="
                           + StructurePointToString(
                                confirmationSwing.classification)
                           + " | confirmationSwingType="
                           + (confirmationSwing.type == SWING_HIGH ? "HIGH" : "LOW")
                           + " | confirmationSwingPrice="
                           + DoubleToString(confirmationSwing.price, digits)
                           + " | confirmationSwingTime="
                           + TimeToString(confirmationSwing.time,
                                          TIME_DATE | TIME_MINUTES));
      return true;
   }

   bool EvaluateSidewayCandidate(const int contextIndex,
                                 const MqlRates &closedBar,
                                 const double atr)
   {
      SidewayBoxState candidate = m_states[contextIndex].sidewayBox;
      if(!candidate.candidateActive)
         return false;

      if(candidate.cycleAtCandidate
         != m_states[contextIndex].cycleState.cycle)
      {
         InvalidateSidewayCandidate(contextIndex, closedBar.time,
                                    "CANDIDATE_CANCELLED", "CYCLE_CHANGE");
         return false;
      }
      const double symbolPoint = SymbolInfoDouble(m_symbols[contextIndex],
                                                   SYMBOL_POINT);
      if(MathAbs(ActiveCorePriceForCycle(contextIndex)
                 - candidate.coreAtCandidate) > symbolPoint * 0.5)
      {
         InvalidateSidewayCandidate(contextIndex, closedBar.time,
                                    "CANDIDATE_CANCELLED",
                                    "PARENT_CORE_CHANGED");
         return false;
      }
      if(m_useCoreBreakATRBuffer && atr <= 0.0)
         return false;

      const double buffer = m_useCoreBreakATRBuffer
                            ? atr * m_coreBreakATRBuffer : 0.0;
      const bool upperBreak = closedBar.close
                              > candidate.candidateBoxHigh + buffer;
      const bool lowerBreak = closedBar.close
                              < candidate.candidateBoxLow - buffer;
      if(upperBreak || lowerBreak)
      {
         const bool directionalContinuation =
            (candidate.cycleAtCandidate == MARKET_CYCLE_BEAR && lowerBreak)
            || (candidate.cycleAtCandidate == MARKET_CYCLE_BULL && upperBreak);
         InvalidateSidewayCandidate(contextIndex, closedBar.time,
                                    "CANDIDATE_CANCELLED",
                                    directionalContinuation
                                    ? "DIRECTIONAL_CONTINUATION"
                                    : "PARENT_CORE_BREAKOUT");
         return false;
      }

      SwingPoint confirmationSwing;
      int confirmationRecord = -1;
      if(!FindCandidateConfirmationSwing(contextIndex, candidate,
                                         confirmationSwing,
                                         confirmationRecord))
         return false;

      if(confirmationSwing.price <= candidate.candidateBoxLow
         || confirmationSwing.price >= candidate.candidateBoxHigh)
      {
         InvalidateSidewayCandidate(contextIndex,
                                    confirmationSwing.confirmationTime,
                                    "CANDIDATE_INVALIDATED",
                                    "CONFIRMATION_SWING_OUTSIDE");
         return false;
      }

      return ActivateSidewayBox(contextIndex,
                                candidate.candidateBoxHigh,
                                candidate.candidateBoxHighTime,
                                candidate.candidateBoxLow,
                                candidate.candidateBoxLowTime,
                                candidate.candidateStartTime,
                                confirmationSwing, closedBar,
                                candidate.candidateWaitState
                                == SIDEWAY_WAIT_POST_LL_HIGH
                                ? "PARENT_RANGE_BULL | confirmationRecord="
                                  + IntegerToString(confirmationRecord)
                                : "PARENT_RANGE_BEAR | confirmationRecord="
                                  + IntegerToString(confirmationRecord));
   }

   bool EvaluateSidewayLifecycle(const int contextIndex,
                                 const MqlRates &rates[],
                                 const int closedIndex,
                                 const MqlRates &closedBar,
                                 const double atr)
   {
      SidewayBoxState box = m_states[contextIndex].sidewayBox;
      if(!box.active)
      {
         if(box.candidateActive)
         {
            if(EvaluateSidewayCandidate(contextIndex, closedBar, atr))
               return true;
            if(m_states[contextIndex].sidewayBox.candidateActive)
               return false;
         }

         TryCreateSidewayCandidate(contextIndex, rates, closedIndex,
                                   closedBar, atr);
         return false;
      }

      // The owner cycle is immutable while price remains inside the parent
      // range. Internal structure continues to update, but it cannot replace
      // the protected Core/box authority.
      const ENUM_MARKET_CYCLE cycle = box.ownerCycle;
      if(m_useCoreBreakATRBuffer && atr <= 0.0)
      {
         m_states[contextIndex].sidewayBox.lastUpdateTime = closedBar.time;
         return true;
      }

      const double buffer = m_useCoreBreakATRBuffer
                            ? atr * m_coreBreakATRBuffer : 0.0;
      const bool upBreak = closedBar.close > box.boxHigh + buffer;
      const bool downBreak = closedBar.close < box.boxLow - buffer;
      if(!upBreak && !downBreak)
      {
         m_states[contextIndex].sidewayBox.lastUpdateTime = closedBar.time;
         return true;
      }

      const bool sameDirectionBreak = cycle == MARKET_CYCLE_BULL
                                      ? upBreak : downBreak;
      const string direction = upBreak
         ? "reason=BOX_BREAKOUT_UP" : "reason=BOX_BREAKOUT_DOWN";
      if(!sameDirectionBreak)
      {
         ExitSidewayBox(contextIndex, closedBar.time, SIDEWAY_BOX_BROKEN,
                        "BREAKOUT", direction);
         return true;
      }

      SwingPoint reference;
      ResetSwingPoint(reference);
      reference.type = cycle == MARKET_CYCLE_BULL ? SWING_HIGH : SWING_LOW;
      reference.price = cycle == MARKET_CYCLE_BULL ? box.boxHigh : box.boxLow;
      reference.time = cycle == MARKET_CYCLE_BULL ? box.boxHighTime : box.boxLowTime;
      reference.confirmationTime = box.confirmedTime;
      reference.confirmed = true;
      const double threshold = cycle == MARKET_CYCLE_BULL
                               ? box.boxHigh + buffer : box.boxLow - buffer;
      const datetime firstRawBreakTime = FindFirstRawReferenceBreakTime(
                                            rates, closedIndex, cycle, reference);
      ExitSidewayBox(contextIndex, closedBar.time, SIDEWAY_BOX_BROKEN,
                     "BREAKOUT", direction);

      if(!m_states[contextIndex].cycleState.breakCandidate)
         ProcessContinuationBreak(contextIndex, cycle, reference, closedBar,
                                  atr, buffer, threshold, firstRawBreakTime,
                                  true);
      return true;
   }

   void ResetBreakCandidate(const int contextIndex)
   {
      m_states[contextIndex].cycleState.breakCandidate = false;
      m_states[contextIndex].cycleState.breakCandidateTime = 0;
      m_states[contextIndex].cycleState.breakLevel = 0.0;
      m_states[contextIndex].cycleState.brokenCoreLevel = 0.0;
      m_states[contextIndex].cycleState.confirmationCount = 0;
      ResetSwingPoint(m_breakOrigins[contextIndex]);
   }

   void CancelPendingContinuationForCycleChange(const int contextIndex,
                                                const datetime eventBarTime)
   {
      if(!m_pendingContinuations[contextIndex].active)
         return;

      SwingPoint noOrigin;
      ResetSwingPoint(noOrigin);
      LogPendingContinuation(contextIndex, m_pendingContinuations[contextIndex],
                             eventBarTime,
                             "PENDING_ORIGIN_CANCELLED_CYCLE_CHANGE",
                             0, 0, false, noOrigin);
      ResetPendingContinuationState(m_pendingContinuations[contextIndex]);
   }

   void ArchiveBrokenCore(const int contextIndex,
                          const datetime confirmationBreakTime,
                          const ENUM_MARKET_CYCLE oldCycle,
                          const ENUM_MARKET_CYCLE newCycle)
   {
      // The active state is reconstructed during bootstrap, while historical
      // broken segments are intentionally runtime-only in v1.0.
      if(m_isBootstrapping || oldCycle == newCycle)
         return;

      BrokenCoreRecord record;
      record.symbol = m_symbols[contextIndex];
      record.timeframe = m_timeframes[contextIndex];
      record.coreType = CORE_SWING_NONE;
      record.price = 0.0;
      record.originTime = 0;
      record.confirmationBreakTime = confirmationBreakTime;
      record.oldCycle = oldCycle;
      record.newCycle = newCycle;

      if(oldCycle == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow)
      {
         record.coreType = CORE_SWING_LOW;
         record.price = m_states[contextIndex].coreSwing.coreSwingLow;
         record.originTime = m_states[contextIndex].coreSwing.coreSwingLowTime;
      }
      else if(oldCycle == MARKET_CYCLE_BEAR
              && m_states[contextIndex].coreSwing.hasCoreHigh)
      {
         record.coreType = CORE_SWING_HIGH;
         record.price = m_states[contextIndex].coreSwing.coreSwingHigh;
         record.originTime = m_states[contextIndex].coreSwing.coreSwingHighTime;
      }

      if(record.coreType == CORE_SWING_NONE || record.price <= 0.0
         || record.originTime <= 0 || confirmationBreakTime <= record.originTime)
         return;

      const int count = ArraySize(m_brokenCoreHistory);
      for(int index = 0; index < count; index++)
      {
         if(m_brokenCoreHistory[index].symbol == record.symbol
            && m_brokenCoreHistory[index].timeframe == record.timeframe
            && m_brokenCoreHistory[index].originTime == record.originTime
            && m_brokenCoreHistory[index].confirmationBreakTime == record.confirmationBreakTime)
            return;
      }

      ArrayResize(m_brokenCoreHistory, count + 1);
      m_brokenCoreHistory[count] = record;
   }

   void TryInitializeCoreAfterReversal(const int contextIndex,
                                       const datetime confirmationBarTime,
                                       const ENUM_MARKET_CYCLE newCycle,
                                       const double reversalBreakLevel,
                                       const SwingPoint &breakOrigin)
   {
      if(m_states[contextIndex].coreSwing.initialized)
         return;

      if(newCycle == MARKET_CYCLE_BULL
         && breakOrigin.confirmed && breakOrigin.type == SWING_LOW)
      {
         SetCoreLow(contextIndex, breakOrigin, confirmationBarTime,
                    "Reversal confirmed | break-origin low", reversalBreakLevel);
      }
      else if(newCycle == MARKET_CYCLE_BEAR
              && breakOrigin.confirmed && breakOrigin.type == SWING_HIGH)
      {
         SetCoreHigh(contextIndex, breakOrigin, confirmationBarTime,
                     "Reversal confirmed | break-origin high", reversalBreakLevel);
      }
   }

   void ConfirmCycleChange(const int contextIndex,
                           const datetime eventBarTime,
                           const ENUM_MARKET_CYCLE newCycle)
   {
      const ENUM_MARKET_CYCLE oldCycle = m_states[contextIndex].cycleState.cycle;
      const double brokenCore = m_states[contextIndex].cycleState.brokenCoreLevel;
      const double breakLevel = m_states[contextIndex].cycleState.breakLevel;
      const SwingPoint breakOrigin = m_breakOrigins[contextIndex];
      CancelPendingContinuationForCycleChange(contextIndex, eventBarTime);
      InvalidateSidewayCandidate(contextIndex, eventBarTime,
                                 "CANDIDATE_CANCELLED", "CYCLE_CHANGE");
      ArchiveBrokenCore(contextIndex, eventBarTime, oldCycle, newCycle);

      m_states[contextIndex].cycleState.cycle = newCycle;
      m_states[contextIndex].cycleState.lastCycleChange = eventBarTime;
      ResetBreakCandidate(contextIndex);

      // A new cycle starts without an invented protective core. Consume the
      // current structural reference so the reversal move itself cannot be
      // reused as a continuation on the next bar.
      ResetCoreSwingState(m_states[contextIndex].coreSwing);
      if(newCycle == MARKET_CYCLE_BULL)
         m_lastBullContinuationReferenceTime[contextIndex] =
            m_states[contextIndex].lastSwingHigh.time;
      else if(newCycle == MARKET_CYCLE_BEAR)
         m_lastBearContinuationReferenceTime[contextIndex] =
            m_states[contextIndex].lastSwingLow.time;

      EmitEvent(contextIndex, CYCLE_CHANGED, eventBarTime,
                oldCycle, newCycle, CORE_SWING_NONE,
                brokenCore, 0.0, breakLevel, "Two closed bars confirmed");

      // Initialize the protective Core from the confirmed swing extreme that
      // originates the final reversal leg. Swing topology remains untouched.
      TryInitializeCoreAfterReversal(contextIndex, eventBarTime,
                                    newCycle, breakLevel, breakOrigin);
   }

   void EvaluateCycleBreak(const int contextIndex,
                           const MqlRates &closedBar,
                           const double atr)
   {
      const ENUM_MARKET_CYCLE cycle = m_states[contextIndex].cycleState.cycle;
      if(cycle == MARKET_CYCLE_UNKNOWN)
         return;

      if(m_useCoreBreakATRBuffer && atr <= 0.0)
         return;

      if(m_states[contextIndex].cycleState.breakCandidate)
      {
         const double level = m_states[contextIndex].cycleState.breakLevel;
         const bool stillBroken = cycle == MARKET_CYCLE_BULL
                                  ? closedBar.close < level
                                  : closedBar.close > level;

         if(stillBroken)
         {
            m_states[contextIndex].cycleState.confirmationCount = 2;
            ConfirmCycleChange(contextIndex, closedBar.time,
                               cycle == MARKET_CYCLE_BULL
                               ? MARKET_CYCLE_BEAR : MARKET_CYCLE_BULL);
         }
         else
         {
            const double brokenCore = m_states[contextIndex].cycleState.brokenCoreLevel;
            const double candidateLevel = m_states[contextIndex].cycleState.breakLevel;
            ResetBreakCandidate(contextIndex);
            EmitEvent(contextIndex, CORE_BREAK_FAILED, closedBar.time,
                      cycle, cycle, CORE_SWING_NONE,
                      brokenCore, brokenCore, candidateLevel, "Next close reclaimed core");
         }
         return;
      }

      const double buffer = m_useCoreBreakATRBuffer ? atr * m_coreBreakATRBuffer : 0.0;
      double coreLevel = 0.0;
      double breakLevel = 0.0;
      bool broken = false;

      if(cycle == MARKET_CYCLE_BULL && m_states[contextIndex].coreSwing.hasCoreLow)
      {
         coreLevel = m_states[contextIndex].coreSwing.coreSwingLow;
         breakLevel = coreLevel - buffer;
         broken = closedBar.close < breakLevel;
      }
      else if(cycle == MARKET_CYCLE_BEAR && m_states[contextIndex].coreSwing.hasCoreHigh)
      {
         coreLevel = m_states[contextIndex].coreSwing.coreSwingHigh;
         breakLevel = coreLevel + buffer;
         broken = closedBar.close > breakLevel;
      }

      if(!broken)
         return;

      m_states[contextIndex].cycleState.breakCandidate = true;
      m_states[contextIndex].cycleState.breakCandidateTime = closedBar.time;
      m_states[contextIndex].cycleState.breakLevel = breakLevel;
      m_states[contextIndex].cycleState.brokenCoreLevel = coreLevel;
      m_states[contextIndex].cycleState.confirmationCount = 1;

      // Capture causality when the candidate starts. AcceptSwing may replace
      // this with a newer confirmed origin before the second close confirms.
      const SwingPoint breakOrigin = cycle == MARKET_CYCLE_BULL
                                     ? m_states[contextIndex].lastSwingHigh
                                     : m_states[contextIndex].lastSwingLow;
      if(breakOrigin.confirmed)
         m_breakOrigins[contextIndex] = breakOrigin;
      else
         ResetSwingPoint(m_breakOrigins[contextIndex]);

      EmitEvent(contextIndex, CORE_BREAK_CANDIDATE, closedBar.time,
                cycle, cycle,
                cycle == MARKET_CYCLE_BULL ? CORE_SWING_LOW : CORE_SWING_HIGH,
                coreLevel, coreLevel, breakLevel, "First close beyond core");
   }

   int ProcessRates(const int contextIndex,
                    const MqlRates &rates[],
                    const int ratesCount,
                    const bool bootstrap)
   {
      const int lastClosedIndex = ratesCount - 2;
      const int atrHistoryBars = (m_useDistanceFilter || m_useCoreBreakATRBuffer)
                                 ? m_atrPeriod : 1;
      const int firstClosedIndex = MathMax(m_swingLeftBars + m_swingRightBars,
                                           atrHistoryBars);
      if(lastClosedIndex < firstClosedIndex)
         return 0;

      int acceptedCount = 0;
      for(int closedIndex = firstClosedIndex; closedIndex <= lastClosedIndex; closedIndex++)
      {
         if(!bootstrap
            && rates[closedIndex].time <= m_lastProcessedClosedBarTime[contextIndex])
            continue;

         const int candidateIndex = closedIndex - m_swingRightBars;
         if(candidateIndex >= m_swingLeftBars
            && rates[candidateIndex].time > m_lastCandidateTime[contextIndex])
         {
            const double candidateATR = m_useDistanceFilter
                                        ? CalculateATR(rates, candidateIndex) : 0.0;
            const int shift = ratesCount - 1 - candidateIndex;

            if(IsSwingHighCandidate(rates, candidateIndex)
               && PassSwingDistanceFilter(contextIndex, SWING_HIGH,
                                          rates[candidateIndex].high, candidateATR))
            {
               AcceptSwing(contextIndex, SWING_HIGH, rates[candidateIndex], shift,
                           rates[closedIndex].time);
               acceptedCount++;
            }

            if(IsSwingLowCandidate(rates, candidateIndex)
               && PassSwingDistanceFilter(contextIndex, SWING_LOW,
                                          rates[candidateIndex].low, candidateATR))
            {
               AcceptSwing(contextIndex, SWING_LOW, rates[candidateIndex], shift,
                           rates[closedIndex].time);
               acceptedCount++;
            }

            m_lastCandidateTime[contextIndex] = rates[candidateIndex].time;
         }

         const double breakATR = m_useCoreBreakATRBuffer
                                  ? CalculateATR(rates, closedIndex) : 0.0;
         const bool coreFrozenOrBoxBreak = EvaluateSidewayLifecycle(
                                             contextIndex, rates, closedIndex,
                                             rates[closedIndex], breakATR);
         if(!coreFrozenOrBoxBreak)
            EvaluateStructuralContinuation(contextIndex, rates, closedIndex,
                                           rates[closedIndex], breakATR);
         // While a Sideway box is active, its immutable owner cycle and
         // protected boundaries outrank internal Core/Cycle break signals.
         if(!m_states[contextIndex].sidewayBox.active)
            EvaluateCycleBreak(contextIndex, rates[closedIndex], breakATR);
         m_lastProcessedClosedBarTime[contextIndex] = rates[closedIndex].time;
      }

      return acceptedCount;
   }

   bool BootstrapContext(const int contextIndex, const bool logFailure)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, false);
      ResetLastError();
      const int copied = CopyRates(m_symbols[contextIndex], m_timeframes[contextIndex],
                                   0, m_lookbackBars, rates);
      const int atrHistoryBars = (m_useDistanceFilter || m_useCoreBreakATRBuffer)
                                 ? m_atrPeriod : 1;
      const int minimumBars = atrHistoryBars + m_swingLeftBars
                              + m_swingRightBars + 3;

      if(copied < minimumBars)
      {
         if(logFailure && !m_dataErrorLogged[contextIndex])
         {
            WatcherLogWarning("Structure bootstrap waiting for history: "
                              + m_symbols[contextIndex]
                              + " | bars=" + IntegerToString(copied)
                              + " | required=" + IntegerToString(minimumBars)
                              + " | error=" + IntegerToString(GetLastError()));
            m_dataErrorLogged[contextIndex] = true;
         }
         return false;
      }

      const bool previousBootstrapState = m_isBootstrapping;
      m_isBootstrapping = true;
      ProcessRates(contextIndex, rates, copied, true);
      m_isBootstrapping = previousBootstrapState;

      m_states[contextIndex].initialized = true;
      m_states[contextIndex].lastStructureUpdate = TimeCurrent();
      m_lastSeenCurrentBarTime[contextIndex] = rates[copied - 1].time;
      m_dataErrorLogged[contextIndex] = false;

      string coreText = "Core -";
      const int digits = (int)SymbolInfoInteger(m_symbols[contextIndex], SYMBOL_DIGITS);
      if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow)
         coreText = "Core low "
                    + DoubleToString(m_states[contextIndex].coreSwing.coreSwingLow,
                                     digits);
      else if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BEAR
              && m_states[contextIndex].coreSwing.hasCoreHigh)
         coreText = "Core high "
                    + DoubleToString(m_states[contextIndex].coreSwing.coreSwingHigh,
                                     digits);

      WatcherLog("INIT", m_symbols[contextIndex] + " "
                 + WatcherTimeframeToString(m_timeframes[contextIndex])
                 + " | Ready | "
                 + JournalCycleText(m_states[contextIndex].cycleState.cycle)
                 + " | " + coreText);
      AuditBootstrap(contextIndex);
      return true;
   }

   void ApplyOutput(SymbolState &symbolState) const
   {
      const int contextIndex = FindContext(symbolState.symbol, symbolState.timeframe);
      if(contextIndex < 0 || !m_states[contextIndex].initialized)
      {
         symbolState.structure = "UNKNOWN";
         symbolState.cycle = "UNKNOWN";
         symbolState.activeCorePrice = 0.0;
         symbolState.hasActiveCore = false;
         return;
      }

      symbolState.structure = m_states[contextIndex].structureSummary;
      symbolState.cycle = MarketCycleToString(m_states[contextIndex].cycleState.cycle);
      symbolState.activeCorePrice = 0.0;
      symbolState.hasActiveCore = false;

      if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BULL
         && m_states[contextIndex].coreSwing.hasCoreLow)
      {
         symbolState.activeCorePrice = m_states[contextIndex].coreSwing.coreSwingLow;
         symbolState.hasActiveCore = true;
      }
      else if(m_states[contextIndex].cycleState.cycle == MARKET_CYCLE_BEAR
              && m_states[contextIndex].coreSwing.hasCoreHigh)
      {
         symbolState.activeCorePrice = m_states[contextIndex].coreSwing.coreSwingHigh;
         symbolState.hasActiveCore = true;
      }

      if(m_states[contextIndex].lastEvent != "")
      {
         symbolState.lastEvent = m_states[contextIndex].lastEvent;
         symbolState.lastEventTime = m_states[contextIndex].lastEventTime;
      }
   }

public:
   CPriceStructureEngine()
   {
      m_swingLeftBars = 3;
      m_swingRightBars = 3;
      m_useDistanceFilter = true;
      m_minDistanceATR = 1.0;
      m_atrPeriod = 14;
      m_lookbackBars = 300;
      m_useCoreBreakATRBuffer = true;
      m_coreBreakATRBuffer = 0.10;
      m_isBootstrapping = false;
      m_enableAuditLog = false;
      m_enableCoreBreakAuditLog = false;
   }

   void Configure(const int swingLeftBars,
                  const int swingRightBars,
                  const bool useDistanceFilter,
                  const double minDistanceATR,
                  const int atrPeriod,
                  const int lookbackBars,
                   const bool useCoreBreakATRBuffer,
                   const double coreBreakATRBuffer,
                   const bool enableAuditLog,
                   const bool enableCoreBreakAuditLog)
   {
      m_swingLeftBars = swingLeftBars;
      m_swingRightBars = swingRightBars;
      m_useDistanceFilter = useDistanceFilter;
      m_minDistanceATR = minDistanceATR;
      m_atrPeriod = atrPeriod;
      m_lookbackBars = lookbackBars;
      m_useCoreBreakATRBuffer = useCoreBreakATRBuffer;
      m_coreBreakATRBuffer = coreBreakATRBuffer;
      m_enableAuditLog = enableAuditLog;
      m_enableCoreBreakAuditLog = enableCoreBreakAuditLog;
   }

   bool Initialize(SymbolState &symbolStates[])
   {
      const int count = ArraySize(symbolStates);
      ArrayResize(m_symbols, count);
      ArrayResize(m_timeframes, count);
      ArrayResize(m_states, count);
      ArrayResize(m_lastSeenCurrentBarTime, count);
      ArrayResize(m_lastProcessedClosedBarTime, count);
      ArrayResize(m_lastCandidateTime, count);
      ArrayResize(m_lastCandidateEventIdentity, count);
      ArrayResize(m_dataErrorLogged, count);
      ArrayResize(m_swingCounts, count);
      ArrayResize(m_lastHighRecordIndex, count);
      ArrayResize(m_lastLowRecordIndex, count);
      ArrayResize(m_lastBullContinuationReferenceTime, count);
      ArrayResize(m_lastBearContinuationReferenceTime, count);
      ArrayResize(m_lastNoNewClosedBarAuditTime, count);
      ArrayResize(m_sidewayCandidateStartTime, count);
      ArrayResize(m_pendingContinuations, count);
      ArrayResize(m_breakOrigins, count);
      ArrayResize(m_auditSnapshotInitialized, count);
      ArrayResize(m_lastAuditCycle, count);
      ArrayResize(m_lastAuditCorePrice, count);
      ArrayResize(m_lastAuditHasCore, count);
      ArrayResize(m_lastAuditStructure, count);
      ArrayResize(m_swingHistory, 0);
      ArrayResize(m_brokenCoreHistory, 0);
      ArrayResize(m_sidewayBoxHistory, 0);
      ArrayResize(m_pendingEvents, 0);

      m_isBootstrapping = true;
      for(int index = 0; index < count; index++)
      {
         m_symbols[index] = symbolStates[index].symbol;
         m_timeframes[index] = symbolStates[index].timeframe;
         ResetPriceStructureState(m_states[index]);
         m_lastSeenCurrentBarTime[index] = 0;
         m_lastProcessedClosedBarTime[index] = 0;
         m_lastCandidateTime[index] = 0;
         m_lastCandidateEventIdentity[index] = "";
         m_dataErrorLogged[index] = false;
         m_swingCounts[index] = 0;
         m_lastHighRecordIndex[index] = -1;
         m_lastLowRecordIndex[index] = -1;
         m_lastBullContinuationReferenceTime[index] = 0;
         m_lastBearContinuationReferenceTime[index] = 0;
         m_lastNoNewClosedBarAuditTime[index] = 0;
         m_sidewayCandidateStartTime[index] = 0;
         ResetPendingContinuationState(m_pendingContinuations[index]);
         ResetSwingPoint(m_breakOrigins[index]);
         m_auditSnapshotInitialized[index] = false;
         m_lastAuditCycle[index] = "";
         m_lastAuditCorePrice[index] = 0.0;
         m_lastAuditHasCore[index] = false;
         m_lastAuditStructure[index] = "";
         BootstrapContext(index, true);
         ApplyOutput(symbolStates[index]);
         AuditSnapshot(index, symbolStates[index]);
      }
      m_isBootstrapping = false;

      // Historical reconstruction never leaks events into the live queue.
      ArrayResize(m_pendingEvents, 0);
      return count > 0;
   }

   void Update(SymbolState &symbolStates[])
   {
      const int count = ArraySize(symbolStates);
      for(int index = 0; index < count; index++)
      {
         const int contextIndex = FindContext(symbolStates[index].symbol,
                                              symbolStates[index].timeframe);
         if(contextIndex < 0)
            continue;

         if(!m_states[contextIndex].initialized)
         {
            if(symbolStates[index].isReady)
               BootstrapContext(contextIndex, true);
            ApplyOutput(symbolStates[index]);
            AuditSnapshot(contextIndex, symbolStates[index]);
            continue;
         }

         if(symbolStates[index].lastBarTime > m_lastSeenCurrentBarTime[contextIndex])
         {
            // A changed current-bar timestamp is not enough by itself. Events
            // are allowed only after MT5 exposes a genuinely newer closed bar.
            const datetime latestClosedBarTime = iTime(m_symbols[contextIndex],
                                                       m_timeframes[contextIndex], 1);
            if(latestClosedBarTime <= 0
               || latestClosedBarTime <= m_lastProcessedClosedBarTime[contextIndex])
            {
               LogNoNewClosedBarAudit(contextIndex,
                                      symbolStates[index].lastBarTime,
                                      latestClosedBarTime);
               ApplyOutput(symbolStates[index]);
               AuditSnapshot(contextIndex, symbolStates[index]);
               continue;
            }

            MqlRates rates[];
            ArraySetAsSeries(rates, false);
            ResetLastError();
            const int copied = CopyRates(m_symbols[contextIndex], m_timeframes[contextIndex],
                                         0, m_lookbackBars, rates);
            const int atrHistoryBars = (m_useDistanceFilter || m_useCoreBreakATRBuffer)
                                       ? m_atrPeriod : 1;
            const int minimumBars = atrHistoryBars + m_swingLeftBars
                                    + m_swingRightBars + 3;

            if(copied >= minimumBars)
            {
               ProcessRates(contextIndex, rates, copied, false);
               m_lastSeenCurrentBarTime[contextIndex] = symbolStates[index].lastBarTime;
               m_dataErrorLogged[contextIndex] = false;
            }
            else if(!m_dataErrorLogged[contextIndex])
            {
               WatcherLogWarning("Structure update waiting for history: "
                                 + m_symbols[contextIndex]
                                 + " | bars=" + IntegerToString(copied)
                                 + " | error=" + IntegerToString(GetLastError()));
               m_dataErrorLogged[contextIndex] = true;
            }
         }

         ApplyOutput(symbolStates[index]);
         AuditSnapshot(contextIndex, symbolStates[index]);
      }
   }

   void ConsumeEvents(StructureEvent &events[])
   {
      const int count = ArraySize(m_pendingEvents);
      ArrayResize(events, count);
      for(int index = 0; index < count; index++)
         events[index] = m_pendingEvents[index];
      ArrayResize(m_pendingEvents, 0);
   }

   bool GetSnapshot(const string symbol,
                     const ENUM_TIMEFRAMES timeframe,
                     PriceStructureState &state,
                     SwingPoint &swings[],
                     BrokenCoreRecord &brokenCores[],
                     SidewayBoxRecord &sidewayBoxes[]) const
   {
      ArrayResize(swings, 0);
      ArrayResize(brokenCores, 0);
      ArrayResize(sidewayBoxes, 0);
      const int contextIndex = FindContext(symbol, timeframe);
      if(contextIndex < 0 || !m_states[contextIndex].initialized)
         return false;

      state = m_states[contextIndex];
      const int historyCount = ArraySize(m_swingHistory);
      for(int index = 0; index < historyCount; index++)
      {
         if(m_swingHistory[index].contextIndex != contextIndex)
            continue;

         const int outputIndex = ArraySize(swings);
         ArrayResize(swings, outputIndex + 1);
         swings[outputIndex] = m_swingHistory[index].point;
      }

      const int brokenCount = ArraySize(m_brokenCoreHistory);
      for(int index = 0; index < brokenCount; index++)
      {
         if(m_brokenCoreHistory[index].symbol != symbol
            || m_brokenCoreHistory[index].timeframe != timeframe)
            continue;

         const int outputIndex = ArraySize(brokenCores);
         ArrayResize(brokenCores, outputIndex + 1);
         brokenCores[outputIndex] = m_brokenCoreHistory[index];
      }

      const int boxCount = ArraySize(m_sidewayBoxHistory);
      for(int index = 0; index < boxCount; index++)
      {
         if(m_sidewayBoxHistory[index].symbol != symbol
            || m_sidewayBoxHistory[index].timeframe != timeframe)
            continue;

         const int outputIndex = ArraySize(sidewayBoxes);
         ArrayResize(sidewayBoxes, outputIndex + 1);
         sidewayBoxes[outputIndex] = m_sidewayBoxHistory[index];
      }

      return true;
   }
};

#endif
