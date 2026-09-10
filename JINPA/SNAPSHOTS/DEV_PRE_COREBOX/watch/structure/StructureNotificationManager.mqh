#ifndef JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH
#define JINPA_WATCHER_STRUCTURE_NOTIFICATION_MANAGER_MQH

#include "StructureTypes.mqh"
#include "../core/WatcherTypes.mqh"
#include "../core/WatcherLogger.mqh"

class CStructureNotificationManager
{
private:
   bool           m_notifyCoreSwingChange;
   bool           m_notifyCoreBreakCandidate;
   bool           m_notifyCycleChange;
   bool           m_enableAuditLog;
   StructureEvent m_queue[];
   string         m_knownIdentities[];

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
      if(event.type == CORE_SWING_CHANGED)
         return m_notifyCoreSwingChange;
      if(event.type == CORE_BREAK_CANDIDATE)
         return m_notifyCoreBreakCandidate;
      if(event.type == CYCLE_CHANGED)
         return m_notifyCycleChange;
      return false;
   }

   string FormatPrice(const string symbol, const double price) const
   {
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      return DoubleToString(price, digits);
   }

   string FormatCycle(const ENUM_MARKET_CYCLE cycle) const
   {
      if(cycle == MARKET_CYCLE_BULL)
         return "Bull ↑";
      if(cycle == MARKET_CYCLE_BEAR)
         return "Bear ↓";
      return "Unknown";
   }

   string FormatCoreType(const ENUM_CORE_SWING_TYPE coreType) const
   {
      if(coreType == CORE_SWING_LOW)
         return "Core low";
      if(coreType == CORE_SWING_HIGH)
         return "Core high";
      return "Core";
   }

   string FormatBrokenCoreType(const ENUM_MARKET_CYCLE oldCycle) const
   {
      if(oldCycle == MARKET_CYCLE_BULL)
         return "core low";
      if(oldCycle == MARKET_CYCLE_BEAR)
         return "core high";
      return "core";
   }

   string FormatCoreUpdateDetail(const ENUM_CORE_SWING_TYPE coreType,
                                 const string fallback) const
   {
      if(coreType == CORE_SWING_LOW)
         return "Break high confirmed";
      if(coreType == CORE_SWING_HIGH)
         return "Break low confirmed";
      return fallback;
   }

   string BuildMessage(const StructureEvent &event) const
   {
      const string heading = "JINPA WATCH | " + event.symbol + " "
                             + WatcherTimeframeToString(event.timeframe) + "\n";

      if(event.type == CORE_SWING_CHANGED)
      {
         return heading + "Core updated\n"
                + FormatCycle(event.cycleAfter) + " | "
                + FormatCoreType(event.coreType) + " "
                + FormatPrice(event.symbol, event.oldCoreLevel) + " → "
                + FormatPrice(event.symbol, event.newCoreLevel) + "\n"
                + FormatCoreUpdateDetail(event.coreType, event.reason);
      }

      if(event.type == CORE_BREAK_CANDIDATE)
      {
         return heading + "Core break candidate\n"
                + FormatCycle(event.cycleBefore) + " | "
                + FormatCoreType(event.coreType) + " "
                + FormatPrice(event.symbol, event.oldCoreLevel) + "\n"
                + "Waiting confirmation";
      }

      if(event.type == CYCLE_CHANGED)
      {
         return heading + "Cycle change\n"
                + FormatCycle(event.cycleBefore) + " → "
                + FormatCycle(event.cycleAfter) + "\n"
                + "Broken " + FormatBrokenCoreType(event.cycleBefore) + " "
                + FormatPrice(event.symbol, event.oldCoreLevel);
      }

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
      m_notifyCoreSwingChange = true;
      m_notifyCoreBreakCandidate = true;
      m_notifyCycleChange = true;
      m_enableAuditLog = false;
   }

   void Configure(const bool notifyCoreSwingChange,
                  const bool notifyCoreBreakCandidate,
                  const bool notifyCycleChange,
                  const bool enableAuditLog)
   {
      m_notifyCoreSwingChange = notifyCoreSwingChange;
      m_notifyCoreBreakCandidate = notifyCoreBreakCandidate;
      m_notifyCycleChange = notifyCycleChange;
      m_enableAuditLog = enableAuditLog;
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

      ResetLastError();
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
};

#endif
