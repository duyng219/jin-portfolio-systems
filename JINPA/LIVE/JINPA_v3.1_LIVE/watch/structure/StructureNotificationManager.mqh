#ifndef JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH
#define JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH

#include "StructureTypes.mqh"
#include "../core/WatcherTypes.mqh"
#include "../core/WatcherLogger.mqh"

class CStructureNotificationManager
{
private:
   bool           m_enabled;
   bool           m_enableAuditLog;
   StructureEvent m_queue[];
   string         m_knownIdentities[];
   int            m_realSendAttempts;

   bool IsKnownIdentity(const string identity) const
   {
      const int count = ArraySize(m_knownIdentities);
      for(int index = 0; index < count; index++)
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

   string FormatCycle(const ENUM_MARKET_CYCLE cycle) const
   {
      if(cycle == MARKET_CYCLE_BULL)
         return "BULL";
      if(cycle == MARKET_CYCLE_BEAR)
         return "BEAR";
      return "UNKNOWN";
   }

   string FormatCoreType(const ENUM_CORE_SWING_TYPE coreType) const
   {
      if(coreType == CORE_SWING_LOW)
         return "CORE LOW";
      if(coreType == CORE_SWING_HIGH)
         return "CORE HIGH";
      return "CORE";
   }

   string BuildMessage(const StructureEvent &event) const
   {
      const string heading = "JINPA | " + event.symbol + " "
                             + WatcherTimeframeToString(event.timeframe) + "\n";

      if(event.type == CORE_BREAK_CANDIDATE)
         return heading + "BREAK CANDIDATE | "
                + FormatCoreType(event.coreType) + " | "
                + FormatCycle(event.cycleBefore);

      if(event.type == CORE_BOX_TRANSITION_STARTED)
         return heading + "CORE UPDATED | "
                + FormatCoreType(event.coreType) + " | "
                + FormatCycle(event.cycleAfter);

      if(event.type == CYCLE_CHANGED)
         return heading + "CYCLE CHANGED | "
                + FormatCycle(event.cycleBefore) + " → "
                + FormatCycle(event.cycleAfter);

      if(event.type == LEG_1_CONFIRMED)
         return heading + "LEG 1 CONFIRMED | "
                + FormatCycle(event.cycleAfter);

      if(event.type == LEG_2_CONFIRMED)
         return heading + "LEG 2 CONFIRMED | "
                + FormatCycle(event.cycleAfter);

      if(event.type == CORE_BREAK_FAILED)
         return heading + "FALSE BREAK | "
                + FormatCoreType(event.coreType) + " | "
                + FormatCycle(event.cycleAfter);

      if(event.type == SIDEWAY_CONFIRMED)
         return heading + "SIDEWAY CONFIRMED | "
                + FormatCycle(event.cycleAfter);

      return "";
   }

   void RemoveFirstQueuedEvent()
   {
      const int count = ArraySize(m_queue);
      for(int index = 1; index < count; index++)
         m_queue[index - 1] = m_queue[index];
      ArrayResize(m_queue, MathMax(0, count - 1));
   }

public:
   CStructureNotificationManager()
   {
      m_enabled = true;
      m_enableAuditLog = false;
      m_realSendAttempts = 0;
   }

   void Configure(const bool enabled,
                  const bool enableAuditLog)
   {
      m_enabled = enabled;
      m_enableAuditLog = enableAuditLog;
      m_realSendAttempts = 0;
      ArrayResize(m_queue, 0);
      ArrayResize(m_knownIdentities, 0);
   }

   void Enqueue(const StructureEvent &event)
   {
      if(!ShouldNotify(event) || IsKnownIdentity(event.identity))
         return;

      const int identityIndex = ArraySize(m_knownIdentities);
      ArrayResize(m_knownIdentities, identityIndex + 1);
      m_knownIdentities[identityIndex] = event.identity;

      const int queueIndex = ArraySize(m_queue);
      ArrayResize(m_queue, queueIndex + 1);
      m_queue[queueIndex] = event;

      if(m_enableAuditLog)
      {
         WatcherLog("AUDIT][EVENT_QUEUE", "\n" + event.symbol + " "
                    + WatcherTimeframeToString(event.timeframe)
                    + "\nEvent: " + StructureEventTypeToString(event.type)
                    + "\nQueued: TRUE");
      }
   }

   void DispatchNext()
   {
      if(ArraySize(m_queue) == 0)
         return;

      const StructureEvent event = m_queue[0];
      RemoveFirstQueuedEvent();
      const string message = BuildMessage(event);
      if(message == "")
         return;

      // Integration already suppresses enqueue/dispatch in Strategy Tester.
      // Keep a second guard here so direct manager tests can never reach the
      // terminal Push API either.
      if((bool)MQLInfoInteger(MQL_TESTER))
         return;

      ResetLastError();
      m_realSendAttempts++;
      if(SendNotification(message))
      {
         if(m_enableAuditLog)
         {
            WatcherLog("AUDIT][PUSH", "\nEvent: "
                       + StructureEventTypeToString(event.type)
                       + "\nSendNotification: SUCCESS");
         }
         return;
      }

      const int errorCode = GetLastError();
      WatcherLogError("Structure notification failed | event=" + event.identity
                      + " | error=" + IntegerToString(errorCode));
      if(m_enableAuditLog)
      {
         WatcherLog("AUDIT][PUSH", "\nEvent: "
                    + StructureEventTypeToString(event.type)
                    + "\nSendNotification: FAILED"
                    + "\nGetLastError: " + IntegerToString(errorCode));
      }
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
      return ArraySize(m_queue);
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
      const int count = ArraySize(m_queue);
      ArrayResize(messages, count);
      for(int index = 0; index < count; index++)
      {
         messages[index] = BuildMessage(m_queue[0]);
         RemoveFirstQueuedEvent();
      }
   }
};

#endif
