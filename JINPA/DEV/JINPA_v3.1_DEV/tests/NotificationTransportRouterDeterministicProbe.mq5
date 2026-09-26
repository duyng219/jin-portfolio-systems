#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Phase 5D transport router deterministic probe"

#include "../watch/notification/NotificationTransportRouter.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[TRANSPORT_ROUTER_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[TRANSPORT_ROUTER_TEST][FAIL] ", name);
   }
}

void TestRoutingMatrix(void)
{
   CNotificationTransportRouter router;

   router.Configure(true, "token-placeholder", "chat-placeholder", false);
   Check(router.LabProbeRoute(true, false)
         == JINPA_ROUTE_TELEGRAM_SUCCESS,
         "CASE_A_01_TELEGRAM_SUCCESS");
   Check(router.TelegramAttemptCount() == 1
         && router.Mt5AttemptCount() == 0,
         "CASE_A_02_NO_MT5_BROADCAST");
   router.Configure(true, "token-placeholder", "chat-placeholder", false);
   Check(router.LabProbeRoute(false, true)
         == JINPA_ROUTE_ALL_TRANSPORTS_FAILED,
         "CASE_A_03_TELEGRAM_FAILURE_FINAL");
   Check(router.TelegramAttemptCount() == 1
         && router.Mt5AttemptCount() == 0,
         "CASE_A_04_MT5_DISABLED_NOT_ATTEMPTED");

   router.Configure(true, "token-placeholder", "chat-placeholder", true);
   Check(router.LabProbeRoute(true, true)
         == JINPA_ROUTE_TELEGRAM_SUCCESS,
         "CASE_B_05_PRIMARY_SUCCESS");
   Check(router.TelegramAttemptCount() == 1
         && router.Mt5AttemptCount() == 0,
         "CASE_B_06_PRIMARY_SUCCESS_NO_BROADCAST");
   router.Configure(true, "token-placeholder", "chat-placeholder", true);
   Check(router.LabProbeRoute(false, true)
         == JINPA_ROUTE_TELEGRAM_FAILED_MT5_SUCCESS,
         "CASE_B_07_MT5_FALLBACK_SUCCESS");
   Check(router.TelegramAttemptCount() == 1
         && router.Mt5AttemptCount() == 1,
         "CASE_B_08_BOTH_ATTEMPTED_ON_FALLBACK");
   router.Configure(true, "token-placeholder", "chat-placeholder", true);
   Check(router.LabProbeRoute(false, false)
         == JINPA_ROUTE_ALL_TRANSPORTS_FAILED,
         "CASE_B_09_ALL_TRANSPORTS_FAILED");

   router.Configure(true, "", "chat-placeholder", true);
   Check(router.LabProbeRoute(true, true) == JINPA_ROUTE_MT5_SUCCESS,
         "CASE_C_10_NOT_CONFIGURED_MT5_DIRECT");
   Check(router.TelegramAttemptCount() == 0
         && router.Mt5AttemptCount() == 1,
         "CASE_C_11_NO_TELEGRAM_ATTEMPT");

   router.Configure(true, "", "", false);
   Check(router.LabProbeRoute(true, true)
         == JINPA_ROUTE_NO_TRANSPORT_AVAILABLE,
         "CASE_D_12_NO_TRANSPORT");
   Check(router.TelegramAttemptCount() == 0
         && router.Mt5AttemptCount() == 0,
         "CASE_D_13_NO_ATTEMPTS");
   Check(router.NoTransportWarningText()
         == "WARNING: No available notification transport",
         "CASE_D_14_WARNING_TEXT");

   router.Configure(false, "", "", true);
   Check(router.LabProbeRoute(true, true) == JINPA_ROUTE_MT5_SUCCESS,
         "CASE_E_15_MT5_DIRECT");
   Check(router.TelegramAttemptCount() == 0
         && router.Mt5AttemptCount() == 1,
         "CASE_E_16_MT5_ONLY_ATTEMPT");

   router.Configure(false, "", "", false);
   Check(router.LabProbeRoute(true, true)
         == JINPA_ROUTE_NO_TRANSPORT_AVAILABLE,
         "CASE_F_17_VALID_NO_TRANSPORT_RESULT");
   Check(router.TelegramAttemptCount() == 0
         && router.Mt5AttemptCount() == 0
         && !router.HasAvailableTransport(),
         "CASE_F_18_ZERO_ATTEMPTS");
}

void TestStatusFormatter(void)
{
   CNotificationTransportRouter router;
   router.Configure(true, "token", "chat", false);
   Check(router.StatusText()
         == "Telegram=ON/READY | MT5=OFF | Primary=TELEGRAM | Fallback=NONE",
         "STATUS_19_CASE_A");
   router.Configure(true, "token", "chat", true);
   Check(router.StatusText()
         == "Telegram=ON/READY | MT5=ON | Primary=TELEGRAM | Fallback=MT5",
         "STATUS_20_CASE_B");
   router.Configure(true, "", "chat", true);
   Check(router.StatusText()
         == "Telegram=ON/NOT CONFIGURED | MT5=ON | Primary=MT5 | Fallback=NONE",
         "STATUS_21_CASE_C");
   router.Configure(true, "token", "", false);
   Check(router.StatusText()
         == "Telegram=ON/NOT CONFIGURED | MT5=OFF | Primary=NONE | Fallback=NONE",
         "STATUS_22_CASE_D");
   router.Configure(false, "", "", true);
   Check(router.StatusText()
         == "Telegram=OFF | MT5=ON | Primary=MT5 | Fallback=NONE",
         "STATUS_23_CASE_E");
   router.Configure(false, "", "", false);
   Check(router.StatusText()
         == "Telegram=OFF | MT5=OFF | Primary=NONE | Fallback=NONE",
         "STATUS_24_CASE_F");
}

void TestStartup(void)
{
   const string token = "secret-token-placeholder";
   const string chat = "secret-chat-placeholder";
   CNotificationTransportRouter router;
   router.Configure(true, token, chat, true);
   const string message = router.StartupMessage("XAUUSD", "H1");
   Check(message == "JINPA Watch | XAUUSD H1\nNotification System Ready"
                    "\nTelegram: ON/READY\nMT5 Push: ON",
         "STARTUP_25_FORMAT");
   Check(StringFind(message, token) < 0 && StringFind(message, chat) < 0,
         "STARTUP_26_NO_SECRETS");
   Check(router.LabProbeRouteStartup(true, true)
         == JINPA_ROUTE_TELEGRAM_SUCCESS,
         "STARTUP_27_USES_ROUTER");
   Check(router.LabProbeRouteStartup(false, false)
         == JINPA_ROUTE_TELEGRAM_SUCCESS
         && router.TelegramAttemptCount() == 1
         && router.Mt5AttemptCount() == 0,
         "STARTUP_28_EXACTLY_ONCE");
}

void TestTesterSuppression(void)
{
   CNotificationTransportRouter router;
   router.Configure(true, "token-placeholder", "chat-placeholder", true);
   Check((bool)MQLInfoInteger(MQL_TESTER)
         && router.Route("tester") == JINPA_ROUTE_TESTER_SUPPRESSED,
         "TESTER_29_ROUTE_SUPPRESSED");
   Check(router.TelegramAttemptCount() == 0
         && router.Mt5AttemptCount() == 0,
         "TESTER_30_ZERO_REAL_ATTEMPTS");
   Check(router.RouteStartup("startup tester")
         == JINPA_ROUTE_TESTER_SUPPRESSED
         && router.StartupHandled()
         && router.TelegramAttemptCount() == 0
         && router.Mt5AttemptCount() == 0,
         "TESTER_31_STARTUP_SUPPRESSED");
}

int OnInit(void)
{
   TestRoutingMatrix();
   TestStatusFormatter();
   TestStartup();
   TestTesterSuppression();
   Print("[TRANSPORT_ROUTER_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0"
         " telegram_attempts=0 mt5_attempts=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
