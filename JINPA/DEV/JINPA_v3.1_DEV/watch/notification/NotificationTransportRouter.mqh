#ifndef JINPA_NOTIFICATION_TRANSPORT_ROUTER_MQH
#define JINPA_NOTIFICATION_TRANSPORT_ROUTER_MQH

#include "TelegramNotificationTransport.mqh"

enum ENUM_JINPA_NOTIFICATION_ROUTE_RESULT
{
   JINPA_ROUTE_TELEGRAM_SUCCESS = 0,
   JINPA_ROUTE_MT5_SUCCESS,
   JINPA_ROUTE_TELEGRAM_FAILED_MT5_SUCCESS,
   JINPA_ROUTE_ALL_TRANSPORTS_FAILED,
   JINPA_ROUTE_NO_TRANSPORT_AVAILABLE,
   JINPA_ROUTE_TESTER_SUPPRESSED
};

// Delivery routing only. Policy, formatting, FIFO and dedup remain owned by
// CStructureNotificationManager.
class CNotificationTransportRouter
{
private:
   CTelegramNotificationTransport m_telegram;
   bool   m_enableMt5Push;
   int    m_telegramAttempts;
   int    m_mt5Attempts;
   int    m_lastMt5Error;
   bool   m_lastTelegramAttempted;
   bool   m_lastMt5Attempted;
   bool   m_startupHandled;
   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT m_startupResult;

   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT RouteInternal(
      const string message, const bool injected,
      const bool telegramSuccess, const bool mt5Success)
   {
      m_lastTelegramAttempted = false;
      m_lastMt5Attempted = false;
      if(!injected && (bool)MQLInfoInteger(MQL_TESTER))
         return JINPA_ROUTE_TESTER_SUPPRESSED;

      if(m_telegram.State() == JINPA_TELEGRAM_READY)
      {
         m_lastTelegramAttempted = true;
         m_telegramAttempts++;
         const bool sent = injected ? telegramSuccess
                                    : m_telegram.Send(message);
         if(sent)
            return JINPA_ROUTE_TELEGRAM_SUCCESS;
         if(!m_enableMt5Push)
            return JINPA_ROUTE_ALL_TRANSPORTS_FAILED;

         m_lastMt5Attempted = true;
         m_mt5Attempts++;
         ResetLastError();
         const bool fallbackSent = injected ? mt5Success
                                            : SendNotification(message);
         m_lastMt5Error = fallbackSent ? 0 : GetLastError();
         return fallbackSent ? JINPA_ROUTE_TELEGRAM_FAILED_MT5_SUCCESS
                             : JINPA_ROUTE_ALL_TRANSPORTS_FAILED;
      }

      if(!m_enableMt5Push)
         return JINPA_ROUTE_NO_TRANSPORT_AVAILABLE;

      m_lastMt5Attempted = true;
      m_mt5Attempts++;
      ResetLastError();
      const bool sent = injected ? mt5Success : SendNotification(message);
      m_lastMt5Error = sent ? 0 : GetLastError();
      return sent ? JINPA_ROUTE_MT5_SUCCESS
                  : JINPA_ROUTE_ALL_TRANSPORTS_FAILED;
   }

public:
   CNotificationTransportRouter(void)
   {
      m_enableMt5Push = false;
      m_telegramAttempts = 0;
      m_mt5Attempts = 0;
      m_lastMt5Error = 0;
      m_lastTelegramAttempted = false;
      m_lastMt5Attempted = false;
      m_startupHandled = false;
      m_startupResult = JINPA_ROUTE_NO_TRANSPORT_AVAILABLE;
   }

   void Configure(const bool enableTelegramPush,
                  const string telegramBotToken,
                  const string telegramChatId,
                  const bool enableMt5Push)
   {
      m_telegram.Configure(enableTelegramPush, telegramBotToken,
                           telegramChatId);
      m_enableMt5Push = enableMt5Push;
      m_telegramAttempts = 0;
      m_mt5Attempts = 0;
      m_lastMt5Error = 0;
      m_lastTelegramAttempted = false;
      m_lastMt5Attempted = false;
      m_startupHandled = false;
      m_startupResult = JINPA_ROUTE_NO_TRANSPORT_AVAILABLE;
   }

   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT Route(const string message)
   {
      return RouteInternal(message, false, false, false);
   }

   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT RouteStartup(const string message)
   {
      if(m_startupHandled)
         return m_startupResult;
      m_startupHandled = true;
      m_startupResult = Route(message);
      return m_startupResult;
   }

   bool HasAvailableTransport(void) const
   {
      return m_telegram.State() == JINPA_TELEGRAM_READY || m_enableMt5Push;
   }

   string StatusText(void) const
   {
      string telegram = "OFF";
      if(m_telegram.State() == JINPA_TELEGRAM_READY)
         telegram = "ON/READY";
      else if(m_telegram.State() == JINPA_TELEGRAM_NOT_CONFIGURED)
         telegram = "ON/NOT CONFIGURED";

      const string mt5 = m_enableMt5Push ? "ON" : "OFF";
      const string primary = m_telegram.State() == JINPA_TELEGRAM_READY
                             ? "TELEGRAM"
                             : (m_enableMt5Push ? "MT5" : "NONE");
      const string fallback = m_telegram.State() == JINPA_TELEGRAM_READY
                              && m_enableMt5Push ? "MT5" : "NONE";
      return "Telegram=" + telegram + " | MT5=" + mt5
             + " | Primary=" + primary + " | Fallback=" + fallback;
   }

   string ConfigurationReason(void) const
   {
      if(m_telegram.State() != JINPA_TELEGRAM_NOT_CONFIGURED)
         return "";
      return m_telegram.StatusText();
   }

   string NoTransportWarningText(void) const
   {
      return "WARNING: No available notification transport";
   }

   string StartupMessage(const string symbol,
                         const string timeframeText) const
   {
      string telegram = "OFF";
      if(m_telegram.State() == JINPA_TELEGRAM_READY)
         telegram = "ON/READY";
      else if(m_telegram.State() == JINPA_TELEGRAM_NOT_CONFIGURED)
         telegram = "ON/NOT CONFIGURED";
      return "JINPA Watch | " + symbol + " " + timeframeText
             + "\nNotification System Ready\nTelegram: " + telegram
             + "\nMT5 Push: " + (m_enableMt5Push ? "ON" : "OFF");
   }

   string TelegramDiagnostic(void) const { return m_telegram.StatusText(); }
   int LastMt5Error(void) const { return m_lastMt5Error; }
   bool LastTelegramAttempted(void) const { return m_lastTelegramAttempted; }
   bool LastMt5Attempted(void) const { return m_lastMt5Attempted; }
   int TelegramAttemptCount(void) const { return m_telegramAttempts; }
   int Mt5AttemptCount(void) const { return m_mt5Attempts; }
   bool StartupHandled(void) const { return m_startupHandled; }

   // Deterministic injection seams: no HTTP or terminal Push API is called.
   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT LabProbeRoute(
      const bool telegramSuccess, const bool mt5Success)
   {
      return RouteInternal("probe", true, telegramSuccess, mt5Success);
   }

   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT LabProbeRouteStartup(
      const bool telegramSuccess, const bool mt5Success)
   {
      if(m_startupHandled)
         return m_startupResult;
      m_startupHandled = true;
      m_startupResult = RouteInternal("startup probe", true,
                                      telegramSuccess, mt5Success);
      return m_startupResult;
   }
};

string JinpaNotificationRouteResultText(
   const ENUM_JINPA_NOTIFICATION_ROUTE_RESULT result)
{
   if(result == JINPA_ROUTE_TELEGRAM_SUCCESS)
      return "TELEGRAM_SUCCESS";
   if(result == JINPA_ROUTE_MT5_SUCCESS)
      return "MT5_SUCCESS";
   if(result == JINPA_ROUTE_TELEGRAM_FAILED_MT5_SUCCESS)
      return "TELEGRAM_FAILED_MT5_SUCCESS";
   if(result == JINPA_ROUTE_ALL_TRANSPORTS_FAILED)
      return "ALL_TRANSPORTS_FAILED";
   if(result == JINPA_ROUTE_TESTER_SUPPRESSED)
      return "TESTER_SUPPRESSED";
   return "NO_TRANSPORT_AVAILABLE";
}

#endif
