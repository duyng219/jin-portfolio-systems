#ifndef JINPA_WATCHER_NOTIFICATION_MANAGER_MQH
#define JINPA_WATCHER_NOTIFICATION_MANAGER_MQH

#include "WatcherLogger.mqh"

class CNotificationManager
{
private:
   bool  m_enabled;
   ulong m_periodMilliseconds;
   ulong m_lastAttemptTick;

   string BuildMessage(const int symbolCount, const string symbols) const
   {
      string message = "JINPA WATCH | Heartbeat\n"
                       + "Status: Running\n"
                       + "Symbols: " + IntegerToString(symbolCount) + "\n"
                       + "Time: " + TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);

      const string symbolsLine = "\nWatch: " + symbols;
      if(StringLen(message) + StringLen(symbolsLine) <= 255)
         message += symbolsLine;

      return message;
   }

public:
   void Initialize(const bool enabled, const int notificationSeconds)
   {
      m_enabled = enabled;
      m_periodMilliseconds = (ulong)notificationSeconds * 1000;
      m_lastAttemptTick = GetTickCount64();
   }

   void Process(const int symbolCount, const string symbols)
   {
      if(!m_enabled)
         return;

      const ulong currentTick = GetTickCount64();
      if(currentTick - m_lastAttemptTick < m_periodMilliseconds)
         return;

      // Advance before sending so a failed call cannot be retried in this cycle.
      m_lastAttemptTick = currentTick;

      const string message = BuildMessage(symbolCount, symbols);
      ResetLastError();
      if(SendNotification(message))
      {
         WatcherLog("HEARTBEAT", "RUNNING");
         WatcherLog("NOTIFY", "Heartbeat sent | symbols=" + IntegerToString(symbolCount));
         return;
      }

      const int errorCode = GetLastError();
      WatcherLogError("Heartbeat notification failed | error=" + IntegerToString(errorCode));
   }
};

#endif
