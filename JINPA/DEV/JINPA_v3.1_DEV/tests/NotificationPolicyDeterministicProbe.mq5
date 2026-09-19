#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Notification Policy v1.0 deterministic probe"

#include "../watch/structure/StructureNotificationManager.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[NOTIFICATION_POLICY_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[NOTIFICATION_POLICY_TEST][FAIL] ", name);
   }
}

StructureEvent PolicyEvent(const ENUM_STRUCTURE_EVENT_TYPE type,
                           const string identity,
                           const ENUM_MARKET_CYCLE before,
                           const ENUM_MARKET_CYCLE after,
                           const ENUM_CORE_SWING_TYPE coreType,
                           const datetime barTime)
{
   StructureEvent event;
   event.type = type;
   event.symbol = "XAUUSD";
   event.timeframe = PERIOD_H1;
   event.eventBarTime = barTime;
   event.cycleBefore = before;
   event.cycleAfter = after;
   event.coreType = coreType;
   event.oldCoreLevel = 3720.0;
   event.newCoreLevel = 3724.0;
   event.breakLevel = 3728.4;
   event.reason = "POLICY_PROBE";
   event.identity = identity;
   event.boxGeneration = 1;
   event.sidewayConfirmationType = SIDEWAY_CLEAN_2_LEG;
   return event;
}

bool Contains(const string value, const string expected)
{
   return StringFind(value, expected) >= 0;
}

void TestExistingEvents(void)
{
   const ENUM_STRUCTURE_EVENT_TYPE types[] =
   {
      CORE_BREAK_CANDIDATE, CORE_BOX_TRANSITION_STARTED, CYCLE_CHANGED,
      LEG_1_CONFIRMED, LEG_2_CONFIRMED, SIDEWAY_CONFIRMED,
      CORE_BREAK_FAILED
   };
   const string expected[] =
   {
      "Break Candidate\nBull | Core Low\nBreak Level ",
      "Core Updated\nBear | Core High\n",
      "Cycle Changed\nBull → Bear\nBroken Core ",
      "Leg 1 Confirmed\nBull | Correction | Leg 1",
      "Leg 2 Confirmed\nBear | Correction | Leg 2",
      "Sideway Confirmed\nBull | Compression | Sideway",
      "False Break\nBear | Compression | False Break"
   };

   for(int index = 0; index < 7; index++)
   {
      CStructureNotificationManager manager;
      manager.Configure(true, false);
      const ENUM_MARKET_CYCLE after = index == 1 || index == 2
                                      || index == 4 || index == 6
                                      ? MARKET_CYCLE_BEAR
                                      : MARKET_CYCLE_BULL;
      const ENUM_CORE_SWING_TYPE coreType = index == 0 ? CORE_SWING_LOW
                                                : index == 1
                                                  ? CORE_SWING_HIGH
                                                  : CORE_SWING_NONE;
      StructureEvent event = PolicyEvent(types[index],
         "STRUCTURE|" + IntegerToString(index), MARKET_CYCLE_BULL,
         after, coreType, 1000 + index);
      manager.Enqueue(event);
      string messages[];
      manager.LabProbeDrainMessages(messages);
      Check(ArraySize(messages) == 1
            && StringFind(messages[0], "JINPA Watch | XAUUSD H1\n") == 0
            && Contains(messages[0], expected[index]),
            "STRUCTURE_EVENT_" + IntegerToString(index + 1));
   }
}

void TestMarketStructureTransitions(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);

   Check(manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2000, "SIDEWAY", "RANGE EDGE",
            "BULL", "COMPRESSION"),
         "MARKET_STRUCTURE_08_RANGE_EDGE_ELIGIBLE");
   Check(manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2001, "RANGE EDGE", "REJECTION",
            "BEAR", "COMPRESSION"),
         "MARKET_STRUCTURE_09_REJECTION_ELIGIBLE");
   Check(manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2002, "CONTINUATION", "MICRO BASE",
            "BULL", "IMPULSE"),
         "MARKET_STRUCTURE_10_MICRO_BASE_ELIGIBLE");
   Check(manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2003, "NONE", "BREAKOUT",
            "BEAR", "EXPANSION"),
         "MARKET_STRUCTURE_11_BREAKOUT_ELIGIBLE");
   Check(!manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2004, "BREAKOUT", "CONTINUATION",
            "BEAR", "IMPULSE"),
         "MARKET_STRUCTURE_12_CONTINUATION_INELIGIBLE");
   Check(!manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2005, "RANGE EDGE", "RANGE EDGE",
            "BULL", "COMPRESSION"),
         "MARKET_STRUCTURE_13_UNCHANGED_INELIGIBLE");

   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 4
         && Contains(messages[0],
                     "Range Edge\nBull | Compression | Range Edge")
         && Contains(messages[1],
                     "Rejection\nBear | Compression | Rejection")
         && Contains(messages[2],
                     "Micro Base\nBull | Impulse | Micro Base\nBase confirmed")
         && Contains(messages[3],
                     "Breakout\nBear | Expansion | Breakout"),
         "FORMATTER_22_MARKET_STRUCTURE_MESSAGES");
}

void TestSetupTransitions(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);

   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3000, "-", "NONE",
            "revs-ppf", "WATCH", "BULL", "CORRECTION", "NONE",
            3728.4, 3710.0),
         "SETUP_14_REVS_PPF_WATCH_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3001, "revs-ppf", "WATCH",
            "revs-ppf", "ACTIVE", "BULL", "CORRECTION", "LEG 1",
            3728.4, 3710.0),
         "SETUP_15_REVS_PPF_ACTIVE_ELIGIBLE");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3002, "revs-ppf", "ACTIVE",
            "revs-ppf", "INVALID", "BULL", "CORRECTION", "LEG 1",
            3728.4, 3710.0),
         "SETUP_16_REVS_PPF_INVALID_INELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3003, "revs-ppf", "WATCH",
            "revs-pps", "WATCH", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2),
         "SETUP_17_REVS_PPS_WATCH_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3004, "revs-pps", "WATCH",
            "revs-pps", "ACTIVE", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2),
         "SETUP_18_REVS_PPS_ACTIVE_ELIGIBLE");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3005, "revs-pps", "ACTIVE",
            "revs-pps", "INVALID", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2),
         "SETUP_19_REVS_PPS_INVALID_INELIGIBLE");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3006, "revs-pps", "WATCH",
            "revs-pps", "WATCH", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2),
         "SETUP_20_UNCHANGED_INELIGIBLE");

   // Replaying an identical transition identity on the same closed bar does
   // not grow the queue or known-identity set.
   const int before = manager.LabProbeQueueSize();
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3004, "revs-pps", "WATCH",
            "revs-pps", "ACTIVE", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2)
         && manager.LabProbeQueueSize() == before,
         "CLOSED_BAR_21_DUPLICATE_IDENTITY_SUPPRESSED");

   string messages[];
   manager.LabProbeDrainMessages(messages);
   const bool formatted = ArraySize(messages) == 4
      && Contains(messages[0],
                  "Revs-ppf | Watch\nBull | Correction | None\n"
                  "Pullback tracking started")
      && Contains(messages[1], "Revs-ppf | Active\n"
                  "Bull | Correction | Leg 1\nClose > Base High ")
      && Contains(messages[2], "Revs-pps | Watch\n"
                  "Bear | Correction | Leg 1\n"
                  "Local Swing Low confirmed")
      && Contains(messages[3], "Revs-pps | Active\n"
                  "Bear | Correction | Leg 1\nClose < Base Low ");
   // Included in check 22 together with the Market Structure formatter.
   Check(formatted, "FORMATTER_22_SETUP_MESSAGES");
}

void TestTesterGuard(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   manager.EnqueueMarketStructureTransition(
      "XAUUSD", PERIOD_H1, 4000, "NONE", "BREAKOUT",
      "BULL", "EXPANSION");
   manager.DispatchNext();
   Check((bool)MQLInfoInteger(MQL_TESTER)
         && manager.LabProbeQueueSize() == 0
         && manager.LabProbeRealSendAttempts() == 0,
         "TESTER_23_REAL_SEND_ATTEMPTS_ZERO");
}

int OnInit(void)
{
   TestExistingEvents();
   TestMarketStructureTransitions();
   TestSetupTransitions();
   TestTesterGuard();
   Print("[NOTIFICATION_POLICY_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push_attempts=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
