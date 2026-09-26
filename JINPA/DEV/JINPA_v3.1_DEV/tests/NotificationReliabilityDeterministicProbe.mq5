#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Phase 5E notification reliability probe"

#include "../watch/structure/StructureNotificationManager.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[NOTIFICATION_RELIABILITY_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[NOTIFICATION_RELIABILITY_TEST][FAIL] ", name);
   }
}

void EnqueueWatch(CStructureNotificationManager &manager,
                  const datetime barTime)
{
   manager.EnqueueSetupTransition(
      "XAUUSD", PERIOD_H1, barTime,
      "-", "NONE", "revs-ppf", "WATCH",
      "BULL", "CORRECTION", "LEG 1", 0.0, 0.0);
}

void DispatchOne(CStructureNotificationManager &manager,
                 const ENUM_JINPA_NOTIFICATION_ROUTE_RESULT result,
                 const ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS classification)
{
   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT results[1];
   ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS classifications[1];
   results[0] = result;
   classifications[0] = classification;
   manager.LabProbeDispatchCycle(results, classifications);
}

void TestSuccessRemoval(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   EnqueueWatch(manager, D'2026.09.01 01:00');
   DispatchOne(manager, JINPA_ROUTE_TELEGRAM_SUCCESS,
               JINPA_DELIVERY_SUCCESS);
   Check(manager.LabProbeQueueSize() == 0,
         "SUCCESS_01_TELEGRAM_REMOVES_ITEM");

   EnqueueWatch(manager, D'2026.09.01 02:00');
   DispatchOne(manager, JINPA_ROUTE_TELEGRAM_FAILED_MT5_SUCCESS,
               JINPA_DELIVERY_SUCCESS);
   Check(manager.LabProbeQueueSize() == 0,
         "SUCCESS_02_FALLBACK_REMOVES_ITEM");
}

void TestRetryLifecycle(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   EnqueueWatch(manager, D'2026.09.02 01:00');
   const string identity = manager.LabProbeQueueIdentity(0);

   DispatchOne(manager, JINPA_ROUTE_ALL_TRANSPORTS_FAILED,
               JINPA_DELIVERY_RETRYABLE_FAILURE);
   Check(manager.LabProbeQueueSize() == 1
         && manager.LabProbeHeadRetryCount() == 1,
         "RETRY_03_FIRST_FAILURE_RETAINED");
   DispatchOne(manager, JINPA_ROUTE_ALL_TRANSPORTS_FAILED,
               JINPA_DELIVERY_RETRYABLE_FAILURE);
   Check(manager.LabProbeQueueSize() == 1
         && manager.LabProbeHeadRetryCount() == 2,
         "RETRY_04_SECOND_FAILURE_RETAINED");
   Check(manager.LabProbeQueueIdentity(0) == identity
         && manager.LabProbeKnownIdentityCount() == 1,
         "RETRY_05_IDENTITY_AND_DEDUP_UNCHANGED");
   DispatchOne(manager, JINPA_ROUTE_ALL_TRANSPORTS_FAILED,
               JINPA_DELIVERY_RETRYABLE_FAILURE);
   Check(manager.LabProbeQueueSize() == 0,
         "RETRY_06_THIRD_FAILURE_DROPPED");
   Check(manager.LabProbeMaxRetry() == 2,
         "RETRY_07_MAX_RETRY_CONTRACT");
}

void TestFailureClassification(void)
{
   CNotificationTransportRouter router;
   router.Configure(true, "token", "chat", false);
   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT result =
      router.LabProbeRouteClassified(
         false, false, JINPA_TELEGRAM_FAILURE_TEMPORARY);
   Check(router.Classify(result) == JINPA_DELIVERY_RETRYABLE_FAILURE,
         "CLASS_08_TELEGRAM_TEMPORARY_RETRYABLE");

   router.Configure(true, "token", "chat", false);
   result = router.LabProbeRouteClassified(
      false, false, JINPA_TELEGRAM_FAILURE_PERMANENT);
   Check(router.Classify(result)
         == JINPA_DELIVERY_NON_RETRYABLE_FAILURE,
         "CLASS_09_TELEGRAM_PERMANENT_NOT_RETRYABLE");

   router.Configure(false, "", "", true);
   result = router.LabProbeRoute(false, false);
   Check(router.Classify(result) == JINPA_DELIVERY_RETRYABLE_FAILURE,
         "CLASS_10_MT5_FAILURE_RETRYABLE");

   router.Configure(false, "", "", false);
   result = router.LabProbeRoute(false, false);
   Check(router.Classify(result)
         == JINPA_DELIVERY_NON_RETRYABLE_FAILURE,
         "CLASS_11_NO_TRANSPORT_NOT_RETRYABLE");

   router.Configure(true, "token", "chat", true);
   result = router.LabProbeRouteClassified(
      false, false, JINPA_TELEGRAM_FAILURE_PERMANENT);
   Check(router.Classify(result) == JINPA_DELIVERY_RETRYABLE_FAILURE,
         "CLASS_12_FAILED_MT5_FALLBACK_RETRYABLE");

   CTelegramNotificationTransport telegram;
   telegram.Configure(true, "token", "chat");
   telegram.LabProbeClassifyResponse(401, 0, "{\"ok\":false}");
   Check(telegram.FailureClass() == JINPA_TELEGRAM_FAILURE_PERMANENT,
         "CLASS_13_HTTP_401_PERMANENT");
   telegram.LabProbeClassifyResponse(503, 0, "");
   Check(telegram.FailureClass() == JINPA_TELEGRAM_FAILURE_TEMPORARY,
         "CLASS_14_HTTP_503_TEMPORARY");
   telegram.LabProbeClassifyResponse(-1, 4014, "");
   Check(telegram.FailureClass() == JINPA_TELEGRAM_FAILURE_TEMPORARY,
         "CLASS_15_WEBREQUEST_FAILURE_TEMPORARY");
}

void TestNonRetryableAndTester(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   EnqueueWatch(manager, D'2026.09.03 01:00');
   DispatchOne(manager, JINPA_ROUTE_NO_TRANSPORT_AVAILABLE,
               JINPA_DELIVERY_NON_RETRYABLE_FAILURE);
   Check(manager.LabProbeQueueSize() == 0,
         "TERMINAL_16_NO_TRANSPORT_DROPPED");

   EnqueueWatch(manager, D'2026.09.03 02:00');
   DispatchOne(manager, JINPA_ROUTE_ALL_TRANSPORTS_FAILED,
               JINPA_DELIVERY_NON_RETRYABLE_FAILURE);
   Check(manager.LabProbeQueueSize() == 0,
         "TERMINAL_17_HTTP_401_EQUIVALENT_DROPPED");

   manager.Configure(true, false);
   manager.ConfigureTransports(true, "token", "chat", true);
   EnqueueWatch(manager, D'2026.09.03 03:00');
   manager.DispatchNext();
   Check((bool)MQLInfoInteger(MQL_TESTER)
         && manager.LabProbeQueueSize() == 0
         && manager.LabProbeHeadRetryCount() == -1,
         "TESTER_18_CONSUMED_WITHOUT_RETRY");
   Check(manager.LabProbeRealSendAttempts() == 0,
         "TESTER_19_NO_REAL_MT5_ATTEMPT");
}

void TestMultiDispatchAndFifo(void)
{
   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT successResults[4];
   ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS successClasses[4];
   for(int index = 0; index < 4; index++)
   {
      successResults[index] = JINPA_ROUTE_TELEGRAM_SUCCESS;
      successClasses[index] = JINPA_DELIVERY_SUCCESS;
   }

   CStructureNotificationManager three;
   three.Configure(true, false);
   EnqueueWatch(three, D'2026.09.04 01:00');
   EnqueueWatch(three, D'2026.09.04 02:00');
   EnqueueWatch(three, D'2026.09.04 03:00');
   three.LabProbeDispatchCycle(successResults, successClasses);
   Check(three.LabProbeQueueSize() == 0,
         "DISPATCH_20_THREE_PROCESSED_IN_CYCLE");

   CStructureNotificationManager four;
   four.Configure(true, false);
   EnqueueWatch(four, D'2026.09.04 04:00');
   EnqueueWatch(four, D'2026.09.04 05:00');
   EnqueueWatch(four, D'2026.09.04 06:00');
   EnqueueWatch(four, D'2026.09.04 07:00');
   const string fourthIdentity = four.LabProbeQueueIdentity(3);
   four.LabProbeDispatchCycle(successResults, successClasses);
   Check(four.LabProbeQueueSize() == 1
         && four.LabProbeQueueIdentity(0) == fourthIdentity
         && four.LabProbeMaxDispatchPerCycle() == 3,
         "DISPATCH_21_CAP_THREE_LEAVES_FOURTH");

   CStructureNotificationManager blocked;
   blocked.Configure(true, false);
   EnqueueWatch(blocked, D'2026.09.04 08:00');
   EnqueueWatch(blocked, D'2026.09.04 09:00');
   const string firstIdentity = blocked.LabProbeQueueIdentity(0);
   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT blockedResults[2];
   ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS blockedClasses[2];
   blockedResults[0] = JINPA_ROUTE_ALL_TRANSPORTS_FAILED;
   blockedClasses[0] = JINPA_DELIVERY_RETRYABLE_FAILURE;
   blockedResults[1] = JINPA_ROUTE_TELEGRAM_SUCCESS;
   blockedClasses[1] = JINPA_DELIVERY_SUCCESS;
   blocked.LabProbeDispatchCycle(blockedResults, blockedClasses);
   Check(blocked.LabProbeQueueSize() == 2
         && blocked.LabProbeQueueIdentity(0) == firstIdentity
         && blocked.LabProbeHeadRetryCount() == 1,
         "FIFO_22_RETRYABLE_HEAD_BLOCKS_NEWER_ITEM");

   CStructureNotificationManager terminal;
   terminal.Configure(true, false);
   EnqueueWatch(terminal, D'2026.09.04 10:00');
   EnqueueWatch(terminal, D'2026.09.04 11:00');
   ENUM_JINPA_NOTIFICATION_ROUTE_RESULT terminalResults[2];
   ENUM_JINPA_NOTIFICATION_DELIVERY_CLASS terminalClasses[2];
   terminalResults[0] = JINPA_ROUTE_NO_TRANSPORT_AVAILABLE;
   terminalClasses[0] = JINPA_DELIVERY_NON_RETRYABLE_FAILURE;
   terminalResults[1] = JINPA_ROUTE_TELEGRAM_SUCCESS;
   terminalClasses[1] = JINPA_DELIVERY_SUCCESS;
   terminal.LabProbeDispatchCycle(terminalResults, terminalClasses);
   Check(terminal.LabProbeQueueSize() == 0,
         "FIFO_23_TERMINAL_HEAD_ALLOWS_NEXT_ITEM");
}

void TestQueueCapAndStartup(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   EnqueueWatch(manager, D'2026.09.05 00:00');
   const string oldestIdentity = manager.LabProbeQueueIdentity(0);
   for(int index = 1; index <= 50; index++)
      EnqueueWatch(manager, D'2026.09.05 00:00' + index * 3600);

   Check(manager.LabProbeQueueSize() == 50
         && manager.LabProbeMaxQueueSize() == 50,
         "QUEUE_24_CAP_REMAINS_FIFTY");
   Check(manager.LabProbeQueueIdentity(0) != oldestIdentity
         && manager.LabProbeQueueIdentity(49) != ""
         && manager.LabProbeKnownIdentityCount() == 51,
         "QUEUE_25_OLDEST_DROPPED_NEWEST_RETAINED");

   CStructureNotificationManager startup;
   startup.Configure(true, false);
   startup.ConfigureTransports(true, "token", "chat", true);
   EnqueueWatch(startup, D'2026.09.08 01:00');
   const int before = startup.LabProbeQueueSize();
   const ENUM_JINPA_NOTIFICATION_ROUTE_RESULT result =
      startup.SendStartupNotification("XAUUSD", PERIOD_H1);
   Check((bool)MQLInfoInteger(MQL_TESTER)
         && result == JINPA_ROUTE_TESTER_SUPPRESSED
         && startup.LabProbeQueueSize() == before,
         "STARTUP_26_DIRECT_AND_OUTSIDE_RETRY_QUEUE");
}

int OnInit(void)
{
   TestSuccessRemoval();
   TestRetryLifecycle();
   TestFailureClassification();
   TestNonRetryableAndTester();
   TestMultiDispatchAndFifo();
   TestQueueCapAndStartup();
   Print("[NOTIFICATION_RELIABILITY_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0"
         " http_attempts=0 mt5_attempts=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
