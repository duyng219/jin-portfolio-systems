#ifndef JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH
#define JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH

#include "StructureTypes.mqh"
#include "../core/WatcherTypes.mqh"
#include "../core/WatcherLogger.mqh"

// Notification Policy v1.0. Detectors remain notification-agnostic; this
// class owns eligibility, formatting, session deduplication and bounded send.
class CStructureNotificationManager
{
private:
   bool   m_enabled;
   bool   m_enableAuditLog;
   string m_queueMessages[];
   string m_queueLabels[];
   string m_queueIdentities[];
   string m_knownIdentities[];
   int    m_realSendAttempts;

   bool IsKnownIdentity(const string identity) const
   {
      for(int index = 0; index < ArraySize(m_knownIdentities); index++)
      {
         if(m_knownIdentities[index] == identity)
            return true;
      }
      return false;
   }

   bool ShouldNotify(const StructureEvent &event) const
   {
      if(!m_enabled)
         return false;
      if(event.type == CYCLE_CHANGED)
         return event.cycleBefore != MARKET_CYCLE_UNKNOWN
                && event.cycleAfter != MARKET_CYCLE_UNKNOWN
                && event.cycleBefore != event.cycleAfter;
      return event.type == CORE_BREAK_CANDIDATE
             || event.type == CORE_BOX_TRANSITION_STARTED
             || event.type == LEG_1_CONFIRMED
             || event.type == LEG_2_CONFIRMED
             || event.type == CORE_BREAK_FAILED
             || event.type == SIDEWAY_CONFIRMED;
   }

   bool IsMarketStructureEligible(const string structure) const
   {
      return structure == "RANGE EDGE" || structure == "REJECTION"
             || structure == "MICRO BASE" || structure == "BREAKOUT";
   }

   bool IsSetupEligible(const string setup, const string status) const
   {
      return (setup == "revs-ppf" || setup == "revs-pps")
             && (status == "WATCH" || status == "ACTIVE");
   }

   string FormatCycle(const ENUM_MARKET_CYCLE cycle) const
   {
      if(cycle == MARKET_CYCLE_BULL)
         return "Bull";
      if(cycle == MARKET_CYCLE_BEAR)
         return "Bear";
      return "Unknown";
   }

   string FormatCoreType(const ENUM_CORE_SWING_TYPE coreType) const
   {
      if(coreType == CORE_SWING_LOW)
         return "Core Low";
      if(coreType == CORE_SWING_HIGH)
         return "Core High";
      return "Core";
   }

   string Uppercase(const string value) const
   {
      string result = value;
      StringToUpper(result);
      return result;
   }

   string Naturalize(const string value) const
   {
      if(value == "BULL")        return "Bull";
      if(value == "BEAR")        return "Bear";
      if(value == "UNKNOWN")     return "Unknown";
      if(value == "COMPRESSION") return "Compression";
      if(value == "EXPANSION")   return "Expansion";
      if(value == "IMPULSE")     return "Impulse";
      if(value == "CORRECTION")  return "Correction";
      if(value == "LEG 1")       return "Leg 1";
      if(value == "LEG 2")       return "Leg 2";
      if(value == "SIDEWAY")     return "Sideway";
      if(value == "FALSE BREAK") return "False Break";
      if(value == "RANGE EDGE")  return "Range Edge";
      if(value == "REJECTION")   return "Rejection";
      if(value == "MICRO BASE")  return "Micro Base";
      if(value == "BREAKOUT")    return "Breakout";
      if(value == "CONTINUATION") return "Continuation";
      if(value == "NONE")        return "None";
      if(value == "WATCH")       return "Watch";
      if(value == "ACTIVE")      return "Active";
      if(value == "INVALID")     return "Invalid";
      if(value == "revs-ppf")    return "Revs-ppf";
      if(value == "revs-pps")    return "Revs-pps";
      return value;
   }

   int PriceDigits(const string symbol) const
   {
      const long digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      return digits >= 0 && digits <= 8 ? (int)digits : 2;
   }

   string Header(const string symbol,
                 const ENUM_TIMEFRAMES timeframe) const
   {
      return "JINPA Watch | " + symbol + " "
             + WatcherTimeframeToString(timeframe) + "\n";
   }

   string Context(const string cycle, const string state,
                  const string structure) const
   {
      return Naturalize(cycle) + " | " + Naturalize(state) + " | "
             + Naturalize(structure);
   }

   string BuildMessage(const StructureEvent &event) const
   {
      const string heading = Header(event.symbol, event.timeframe);
      const int digits = PriceDigits(event.symbol);

      if(event.type == CORE_BREAK_CANDIDATE)
      {
         string message = heading + "Break Candidate\n"
                          + FormatCycle(event.cycleBefore) + " | "
                          + FormatCoreType(event.coreType);
         if(event.breakLevel > 0.0)
            message += "\nBreak Level "
                       + DoubleToString(event.breakLevel, digits);
         return message;
      }

      if(event.type == CORE_BOX_TRANSITION_STARTED)
      {
         string message = heading + "Core Updated\n"
                          + FormatCycle(event.cycleAfter) + " | "
                          + FormatCoreType(event.coreType);
         if(event.oldCoreLevel > 0.0 && event.newCoreLevel > 0.0)
            message += "\n" + DoubleToString(event.oldCoreLevel, digits)
                       + " → "
                       + DoubleToString(event.newCoreLevel, digits);
         return message;
      }

      if(event.type == CYCLE_CHANGED)
      {
         string message = heading + "Cycle Changed\n"
                          + FormatCycle(event.cycleBefore) + " → "
                          + FormatCycle(event.cycleAfter);
         const double brokenCore = event.breakLevel > 0.0
                                   ? event.breakLevel
                                   : event.oldCoreLevel;
         if(brokenCore > 0.0)
            message += "\nBroken Core "
                       + DoubleToString(brokenCore, digits);
         return message;
      }

      if(event.type == LEG_1_CONFIRMED)
         return heading + "Leg 1 Confirmed\n"
                + FormatCycle(event.cycleAfter)
                + " | Correction | Leg 1";

      if(event.type == LEG_2_CONFIRMED)
         return heading + "Leg 2 Confirmed\n"
                + FormatCycle(event.cycleAfter)
                + " | Correction | Leg 2";

      if(event.type == CORE_BREAK_FAILED)
         return heading + "False Break\n"
                + FormatCycle(event.cycleAfter)
                + " | Compression | False Break";

      if(event.type == SIDEWAY_CONFIRMED)
         return heading + "Sideway Confirmed\n"
                + FormatCycle(event.cycleAfter)
                + " | Compression | Sideway";

      return "";
   }

   string BuildMarketStructureMessage(
      const string symbol, const ENUM_TIMEFRAMES timeframe,
      const string cycle, const string state,
      const string structure) const
   {
      if(!IsMarketStructureEligible(structure))
         return "";
      string message = Header(symbol, timeframe) + Naturalize(structure) + "\n"
                       + Context(cycle, state, structure);
      if(structure == "MICRO BASE")
         message += "\nBase confirmed";
      return message;
   }

   string BuildSetupMessage(
      const string symbol, const ENUM_TIMEFRAMES timeframe,
      const string setup, const string status,
      const string cycle, const string state, const string structure,
      const double baseHigh, const double baseLow) const
   {
      if(!IsSetupEligible(setup, status))
         return "";

      string message = Header(symbol, timeframe) + Naturalize(setup)
                       + " | " + Naturalize(status) + "\n"
                       + Context(cycle, state, structure);
      if(status == "WATCH")
      {
         if(setup == "revs-ppf")
            message += "\nPullback tracking started";
         else if(cycle == "BULL")
            message += "\nLocal Swing High confirmed";
         else if(cycle == "BEAR")
            message += "\nLocal Swing Low confirmed";
      }
      else if(status == "ACTIVE")
      {
         const int digits = PriceDigits(symbol);
         if(cycle == "BULL" && baseHigh > 0.0)
            message += "\nClose > Base High "
                       + DoubleToString(baseHigh, digits);
         else if(cycle == "BEAR" && baseLow > 0.0)
            message += "\nClose < Base Low "
                       + DoubleToString(baseLow, digits);
      }
      return message;
   }

   bool QueueMessage(const string identity, const string label,
                     const string message)
   {
      if(!m_enabled || identity == "" || message == ""
         || IsKnownIdentity(identity))
         return false;

      int index = ArraySize(m_knownIdentities);
      ArrayResize(m_knownIdentities, index + 1);
      m_knownIdentities[index] = identity;

      index = ArraySize(m_queueMessages);
      ArrayResize(m_queueMessages, index + 1);
      ArrayResize(m_queueLabels, index + 1);
      ArrayResize(m_queueIdentities, index + 1);
      m_queueMessages[index] = message;
      m_queueLabels[index] = label;
      m_queueIdentities[index] = identity;

      if(m_enableAuditLog)
         WatcherLog("PUSH_QUEUE", label);
      return true;
   }

   void RemoveFirstQueuedMessage()
   {
      const int count = ArraySize(m_queueMessages);
      for(int index = 1; index < count; index++)
      {
         m_queueMessages[index - 1] = m_queueMessages[index];
         m_queueLabels[index - 1] = m_queueLabels[index];
         m_queueIdentities[index - 1] = m_queueIdentities[index];
      }
      const int nextSize = MathMax(0, count - 1);
      ArrayResize(m_queueMessages, nextSize);
      ArrayResize(m_queueLabels, nextSize);
      ArrayResize(m_queueIdentities, nextSize);
   }

public:
   CStructureNotificationManager()
   {
      m_enabled = true;
      m_enableAuditLog = false;
      m_realSendAttempts = 0;
   }

   void Configure(const bool enabled, const bool enableAuditLog)
   {
      m_enabled = enabled;
      m_enableAuditLog = enableAuditLog;
      m_realSendAttempts = 0;
      ArrayResize(m_queueMessages, 0);
      ArrayResize(m_queueLabels, 0);
      ArrayResize(m_queueIdentities, 0);
      ArrayResize(m_knownIdentities, 0);
   }

   void Enqueue(const StructureEvent &event)
   {
      if(!ShouldNotify(event))
         return;
      QueueMessage(event.identity,
                   event.symbol + " "
                   + WatcherTimeframeToString(event.timeframe) + " | "
                   + StructureEventTypeToString(event.type),
                   BuildMessage(event));
   }

   bool EnqueueMarketStructureTransition(
      const string symbol, const ENUM_TIMEFRAMES timeframe,
      const datetime closedBarTime,
      const string previousStructure, const string currentStructure,
      const string cycle, const string state)
   {
      if(previousStructure == currentStructure
         || !IsMarketStructureEligible(currentStructure))
         return false;
      const string identity = symbol + "|"
         + IntegerToString((int)timeframe) + "|"
         + IntegerToString((long)closedBarTime)
         + "|MARKET_STRUCTURE|" + currentStructure;
      return QueueMessage(identity,
                          symbol + " " + WatcherTimeframeToString(timeframe)
                          + " | " + currentStructure,
                          BuildMarketStructureMessage(symbol, timeframe,
                             cycle, state, currentStructure));
   }

   bool EnqueueSetupTransition(
      const string symbol, const ENUM_TIMEFRAMES timeframe,
      const datetime closedBarTime,
      const string previousSetup, const string previousStatus,
      const string currentSetup, const string currentStatus,
      const string cycle, const string state, const string structure,
      const double baseHigh, const double baseLow)
   {
      if(previousSetup == currentSetup && previousStatus == currentStatus)
         return false;
      if(!IsSetupEligible(currentSetup, currentStatus))
         return false;
      const string identity = symbol + "|"
         + IntegerToString((int)timeframe) + "|"
         + IntegerToString((long)closedBarTime)
         + "|SETUP|" + currentSetup + "|" + currentStatus;
      return QueueMessage(identity,
                          symbol + " " + WatcherTimeframeToString(timeframe)
                          + " | " + Uppercase(currentSetup) + " "
                          + currentStatus,
                          BuildSetupMessage(symbol, timeframe,
                             currentSetup, currentStatus, cycle, state,
                             structure, baseHigh, baseLow));
   }

   void DispatchNext()
   {
      if(ArraySize(m_queueMessages) == 0)
         return;

      const string message = m_queueMessages[0];
      const string label = m_queueLabels[0];
      const string identity = m_queueIdentities[0];
      RemoveFirstQueuedMessage();

      // Eligibility and queueing still run in Strategy Tester, but the real
      // terminal Push API is never called there.
      if((bool)MQLInfoInteger(MQL_TESTER))
         return;

      ResetLastError();
      m_realSendAttempts++;
      if(SendNotification(message))
      {
         if(m_enableAuditLog)
            WatcherLog("PUSH_SEND", label + " | SUCCESS");
         return;
      }

      const int errorCode = GetLastError();
      WatcherLogError("Notification failed | event=" + identity
                      + " | error=" + IntegerToString(errorCode));
      if(m_enableAuditLog)
         WatcherLog("PUSH_SEND", label + " | FAILED | error="
                    + IntegerToString(errorCode));
   }

   bool LabProbeEligible(const StructureEvent &event) const
   {
      return ShouldNotify(event);
   }

   string LabProbeBuildMessage(const StructureEvent &event) const
   {
      return BuildMessage(event);
   }

   int LabProbeQueueSize() const
   {
      return ArraySize(m_queueMessages);
   }

   int LabProbeKnownIdentityCount() const
   {
      return ArraySize(m_knownIdentities);
   }

   int LabProbeRealSendAttempts() const
   {
      return m_realSendAttempts;
   }

   void LabProbeDrainMessages(string &messages[])
   {
      const int count = ArraySize(m_queueMessages);
      ArrayResize(messages, count);
      for(int index = 0; index < count; index++)
      {
         messages[index] = m_queueMessages[0];
         RemoveFirstQueuedMessage();
      }
   }
};

#endif
