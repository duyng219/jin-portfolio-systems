#ifndef JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH
#define JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH

#include "StructureTypes.mqh"
#include "../core/WatcherTypes.mqh"
#include "../core/WatcherLogger.mqh"
#include "../notification/NotificationTransportRouter.mqh"

#define JINPA_NOTIFICATION_MAX_RETRY          2
#define JINPA_NOTIFICATION_MAX_DISPATCH       3
#define JINPA_NOTIFICATION_MAX_QUEUE_SIZE    50

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
   int    m_queueRetryCounts[];
   string m_knownIdentities[];
   CNotificationTransportRouter m_transportRouter;
   datetime m_policyBarTime;
   bool   m_suppressBreakout;
   bool   m_suppressCoreUpdated;
   bool   m_suppressFalseBreak;
   bool   m_suppressRejection;
   bool   m_suppressMicroBase;
   bool   m_suppressLeg1;
   bool   m_suppressLeg2;

   void ResetClosedBarPolicy(const datetime closedBarTime)
   {
      m_policyBarTime = closedBarTime;
      m_suppressBreakout = false;
      m_suppressCoreUpdated = false;
      m_suppressFalseBreak = false;
      m_suppressRejection = false;
      m_suppressMicroBase = false;
      m_suppressLeg1 = false;
      m_suppressLeg2 = false;
   }

   bool SuppressStructureEvent(const StructureEvent &event) const
   {
      if(event.eventBarTime != m_policyBarTime)
         return false;
      return (event.type == CORE_BOX_TRANSITION_STARTED
              && m_suppressCoreUpdated)
             || (event.type == CORE_BREAK_FAILED
                 && m_suppressFalseBreak);
   }

   bool SuppressMarketStructure(const datetime closedBarTime,
                                const string structure) const
   {
      if(closedBarTime != m_policyBarTime)
         return false;
      return (structure == "BREAKOUT" && m_suppressBreakout)
             || (structure == "REJECTION" && m_suppressRejection)
             || (structure == "MICRO BASE" && m_suppressMicroBase)
             || (structure == "LEG 1" && m_suppressLeg1)
             || (structure == "LEG 2" && m_suppressLeg2);
   }

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
             || event.type == CORE_BREAK_FAILED
             || event.type == SIDEWAY_CONFIRMED;
   }

   bool IsMarketStructureEligible(const string structure) const
   {
      return structure == "LEG 1" || structure == "LEG 2"
             || structure == "RANGE EDGE" || structure == "REJECTION"
             || structure == "MICRO BASE" || structure == "BREAKOUT";
   }

   bool IsSetupEligible(const string setup, const string status) const
   {
      if(setup == "revs-ppf" || setup == "revs-pps"
         || setup == "bres-pma")
         return status == "WATCH" || status == "READY"
                || status == "ACTIVE";
      if(setup == "bres-pmb" || setup == "revs-pfb"
         || setup == "revs-pmr")
         return status == "ACTIVE";
      return false;
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
      if(value == "READY")       return "Ready";
      if(value == "ACTIVE")      return "Active";
      if(value == "INVALID")     return "Invalid";
      if(value == "revs-ppf")    return "Revs-ppf";
      if(value == "revs-pps")    return "Revs-pps";
      if(value == "bres-pmb")    return "Bres-pmb";
      if(value == "bres-pma")    return "Bres-pma";
      if(value == "revs-pfb")    return "Revs-pfb";
      if(value == "revs-pmr")    return "Revs-pmr";
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
      string heading = Naturalize(structure);
      if(structure == "LEG 1" || structure == "LEG 2")
         heading += " Confirmed";
      string message = Header(symbol, timeframe) + heading + "\n"
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
         else if(setup == "bres-pma")
            message += "\nImpulse tracking started";
         else if(cycle == "BULL")
            message += "\nLocal Swing High confirmed";
         else if(cycle == "BEAR")
            message += "\nLocal Swing Low confirmed";
      }
      else if(status == "READY")
      {
         const int digits = PriceDigits(symbol);
         if(baseLow > 0.0 && baseHigh > baseLow)
            message += "\nBase " + DoubleToString(baseLow, digits)
                       + " - " + DoubleToString(baseHigh, digits);
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

      if(ArraySize(m_queueMessages) >= JINPA_NOTIFICATION_MAX_QUEUE_SIZE)
      {
         RemoveFirstQueuedMessage();
         WatcherLogWarning("NOTIFICATION QUEUE FULL | dropped oldest"
                           " | size="
                           + IntegerToString(
                              JINPA_NOTIFICATION_MAX_QUEUE_SIZE));
      }

      int index = ArraySize(m_knownIdentities);
      ArrayResize(m_knownIdentities, index + 1);
      m_knownIdentities[index] = identity;

      index = ArraySize(m_queueMessages);
      ArrayResize(m_queueMessages, index + 1);
      ArrayResize(m_queueLabels, index + 1);
      ArrayResize(m_queueIdentities, index + 1);
      ArrayResize(m_queueRetryCounts, index + 1);
      m_queueMessages[index] = message;
      m_queueLabels[index] = label;
      m_queueIdentities[index] = identity;
      m_queueRetryCounts[index] = 0;

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
         m_queueRetryCounts[index - 1] = m_queueRetryCounts[index];
      }
      const int nextSize = MathMax(0, count - 1);
      ArrayResize(m_queueMessages, nextSize);
      ArrayResize(m_queueLabels, nextSize);
      ArrayResize(m_queueIdentities, nextSize);
      ArrayResize(m_queueRetryCounts, nextSize);
   }

   bool ApplyHeadOutcome(
      const ENUM_JINPA_NOTIFICATION_ROUTE_RESULT result,
      const ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS classification,
      const string failureReason = "")
   {
      if(ArraySize(m_queueMessages) == 0)
         return true;

      const string label = m_queueLabels[0];
      const string identity = m_queueIdentities[0];
      if(classification == JINPA_DELIVERY_SUCCESS)
      {
         RemoveFirstQueuedMessage();
         if(m_enableAuditLog)
            WatcherLog("PUSH_SEND", label + " | "
                       + JinpaNotificationRouteResultText(result));
         return true;
      }

      // Tester suppression is a terminal test-only outcome. Consuming it
      // prevents an intentionally disabled real transport from building an
      // endless retry queue during deterministic replay.
      if(classification == JINPA_DELIVERY_TESTER_SUPPRESSED)
      {
         RemoveFirstQueuedMessage();
         return true;
      }

      if(classification == JINPA_DELIVERY_NON_RETRYABLE_FAILURE)
      {
         WatcherLogWarning(
            "NOTIFICATION | DROPPED | non-retryable failure | event="
            + identity + " | result="
            + JinpaNotificationRouteResultText(result)
            + (failureReason == "" ? "" : " | reason=" + failureReason));
         RemoveFirstQueuedMessage();
         return true;
      }

      // retryCount is retries consumed after the initial attempt. Values 1
      // and 2 retain the head; the next failure is total attempt 3 and drops.
      if(m_queueRetryCounts[0] < JINPA_NOTIFICATION_MAX_RETRY)
      {
         m_queueRetryCounts[0]++;
         WatcherLogWarning("NOTIFICATION | RETRY | event=" + identity
                           + " | retry="
                           + IntegerToString(m_queueRetryCounts[0]) + "/"
                           + IntegerToString(
                              JINPA_NOTIFICATION_MAX_RETRY));
         return false;
      }

      WatcherLogWarning(
         "NOTIFICATION | DROPPED | retry limit exceeded | event="
         + identity);
      RemoveFirstQueuedMessage();
      return true;
   }

public:
   CStructureNotificationManager()
   {
      m_enabled = true;
      m_enableAuditLog = false;
      ResetClosedBarPolicy(0);
   }

   void Configure(const bool enabled, const bool enableAuditLog)
   {
      m_enabled = enabled;
      m_enableAuditLog = enableAuditLog;
      ArrayResize(m_queueMessages, 0);
      ArrayResize(m_queueLabels, 0);
      ArrayResize(m_queueIdentities, 0);
      ArrayResize(m_queueRetryCounts, 0);
      ArrayResize(m_knownIdentities, 0);
      ResetClosedBarPolicy(0);
   }

   void ConfigureTransports(const bool enableTelegramPush,
                            const string telegramBotToken,
                            const string telegramChatId,
                            const bool enableMt5Push)
   {
      m_transportRouter.Configure(enableTelegramPush, telegramBotToken,
                                  telegramChatId, enableMt5Push);
   }

   void BeginClosedBarPolicy(const datetime closedBarTime)
   {
      if(closedBarTime != m_policyBarTime)
         ResetClosedBarPolicy(closedBarTime);
   }

   void ObserveSetupTransition(const datetime closedBarTime,
                               const string setup,
                               const string status,
                               const bool changed)
   {
      BeginClosedBarPolicy(closedBarTime);
      if(!changed)
         return;

      if(setup == "bres-pmb" && status == "ACTIVE")
      {
         m_suppressBreakout = true;
         m_suppressCoreUpdated = true;
      }
      else if(setup == "revs-pfb" && status == "ACTIVE")
         m_suppressFalseBreak = true;
      else if(setup == "revs-pmr" && status == "ACTIVE")
         m_suppressRejection = true;
      else if(setup == "bres-pma" && status == "READY")
         m_suppressMicroBase = true;
      else if(setup == "revs-ppf" && status == "ACTIVE")
         m_suppressLeg1 = true;
      else if(setup == "revs-pps" && status == "ACTIVE")
         m_suppressLeg2 = true;
   }

   void Enqueue(const StructureEvent &event)
   {
      if(!ShouldNotify(event) || SuppressStructureEvent(event))
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
         || !IsMarketStructureEligible(currentStructure)
         || SuppressMarketStructure(closedBarTime, currentStructure))
         return false;
      string identity = symbol + "|"
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
      const double baseHigh, const double baseLow,
      const datetime candidateTime = 0)
   {
      const bool replacementReady = currentStatus == "READY"
                                    && candidateTime > 0;
      if(previousSetup == currentSetup && previousStatus == currentStatus
         && !replacementReady)
         return false;
      // A Base failure is a candidate reset, not a new setup WATCH event.
      // The next confirmed candidate receives its own READY notification.
      if(currentStatus == "WATCH" && previousStatus == "READY"
         && previousSetup == currentSetup)
         return false;
      if(!IsSetupEligible(currentSetup, currentStatus))
         return false;
      string identity = symbol + "|"
         + IntegerToString((int)timeframe) + "|SETUP|" + currentSetup
         + "|" + currentStatus + "|";
      if(currentStatus == "READY" && candidateTime > 0)
         identity += IntegerToString((long)candidateTime);
      else
         identity += IntegerToString((long)closedBarTime);
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
      int processed = 0;
      while(processed < JINPA_NOTIFICATION_MAX_DISPATCH
            && ArraySize(m_queueMessages) > 0)
      {
         const ENUM_JINPA_NOTIFICATION_ROUTE_RESULT result =
            m_transportRouter.Route(m_queueMessages[0]);
         const ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS classification =
            m_transportRouter.Classify(result);
         processed++;
         if(!ApplyHeadOutcome(result, classification,
                              m_transportRouter.FailureReason(result)))
            break;
      }
   }

   string TransportStatus(void) const
   {
      return m_transportRouter.StatusText();
   }

   string TransportConfigurationReason(void) const
   {
      return m_transportRouter.ConfigurationReason();
   }

   bool HasAvailableTransport(void) const
   {
      return m_transportRouter.HasAvailableTransport();
   }

   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT SendStartupNotification(
      const string symbol, const ENUM_TIMEFRAMES timeframe)
   {
      const ENUM_JINPA_NOTIFICATION_ROUTE_RESULT result =
         m_transportRouter.RouteStartup(
         m_transportRouter.StartupMessage(
            symbol, WatcherTimeframeToString(timeframe)));
      if(result == JINPA_ROUTE_ALL_TRANSPORTS_FAILED)
      {
         if(m_transportRouter.LastTelegramAttempted())
            WatcherLogError("TELEGRAM | "
                            + m_transportRouter.TelegramDiagnostic()
                            + " | event=STARTUP");
         if(m_transportRouter.LastMt5Attempted())
            WatcherLogError("MT5 PUSH | SEND FAILED | error="
                            + IntegerToString(
                               m_transportRouter.LastMt5Error())
                            + " | event=STARTUP");
      }
      else if(result != JINPA_ROUTE_TESTER_SUPPRESSED
              && result != JINPA_ROUTE_NO_TRANSPORT_AVAILABLE)
         WatcherLog("NOTIFICATION STARTUP",
                    JinpaNotificationRouteResultText(result));
      return result;
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

   int LabProbeHeadRetryCount(void) const
   {
      return ArraySize(m_queueRetryCounts) > 0 ? m_queueRetryCounts[0] : -1;
   }

   string LabProbeQueueIdentity(const int index) const
   {
      if(index < 0 || index >= ArraySize(m_queueIdentities))
         return "";
      return m_queueIdentities[index];
   }

   int LabProbeMaxRetry(void) const
   {
      return JINPA_NOTIFICATION_MAX_RETRY;
   }

   int LabProbeMaxDispatchPerCycle(void) const
   {
      return JINPA_NOTIFICATION_MAX_DISPATCH;
   }

   int LabProbeMaxQueueSize(void) const
   {
      return JINPA_NOTIFICATION_MAX_QUEUE_SIZE;
   }

   void LabProbeDispatchCycle(
      const ENUM_JINPA_NOTIFICATION_ROUTE_RESULT &results[],
      const ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS &classifications[])
   {
      const int available = MathMin(ArraySize(results),
                                    ArraySize(classifications));
      int processed = 0;
      while(processed < JINPA_NOTIFICATION_MAX_DISPATCH
            && processed < available
            && ArraySize(m_queueMessages) > 0)
      {
         const bool keepDispatching = ApplyHeadOutcome(
            results[processed], classifications[processed]);
         processed++;
         if(!keepDispatching)
            break;
      }
   }

   int LabProbeRealSendAttempts() const
   {
      return m_transportRouter.Mt5AttemptCount();
   }

   string LabProbeTelegramStatus(void) const
   {
      return m_transportRouter.TelegramDiagnostic();
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
