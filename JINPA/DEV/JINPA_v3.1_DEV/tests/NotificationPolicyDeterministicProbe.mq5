#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Phase 5B unified notification deterministic probe"

#include "../watch/structure/StructureNotificationManager.mqh"
#include "../watch/setup/SetupOutputArbitrator.mqh"

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
      const bool internalLegEvent = index == 3 || index == 4;
      Check(internalLegEvent ? ArraySize(messages) == 0
            : ArraySize(messages) == 1
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
   Check(manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2004, "NONE", "LEG 1",
            "BULL", "CORRECTION"),
         "MARKET_STRUCTURE_12_UNIFIED_LEG1_ELIGIBLE");
   Check(manager.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 2005, "NONE", "LEG 2",
            "BEAR", "CORRECTION"),
         "MARKET_STRUCTURE_13_UNIFIED_LEG2_ELIGIBLE");
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
   Check(ArraySize(messages) == 6
         && Contains(messages[0],
                     "Range Edge\nBull | Compression | Range Edge")
         && Contains(messages[1],
                     "Rejection\nBear | Compression | Rejection")
         && Contains(messages[2],
                     "Micro Base\nBull | Impulse | Micro Base\nBase confirmed")
         && Contains(messages[3], "Breakout\nBear | Expansion | Breakout")
         && Contains(messages[4], "Leg 1 Confirmed\nBull | Correction | Leg 1")
         && Contains(messages[5], "Leg 2 Confirmed\nBear | Correction | Leg 2"),
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
            "XAUUSD", PERIOD_H1, 3007, "revs-ppf", "WATCH",
            "revs-ppf", "READY", "BULL", "CORRECTION", "NONE",
            3728.4, 3710.0, 3100),
         "SETUP_16B_REVS_PPF_READY_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3003, "revs-ppf", "WATCH",
            "revs-pps", "WATCH", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2),
         "SETUP_17_REVS_PPS_WATCH_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3004, "revs-pps", "WATCH",
            "revs-pps", "READY", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2, 4200),
         "SETUP_18_REVS_PPS_READY_ELIGIBLE");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3010, "revs-pps", "READY",
            "revs-pps", "READY", "BEAR", "CORRECTION", "LEG 1",
            3740.0, 3702.2, 4200),
         "SETUP_18B_SAME_READY_CANDIDATE_DEDUP");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3011, "revs-pps", "READY",
            "revs-pps", "READY", "BEAR", "CORRECTION", "LEG 1",
            3738.0, 3700.0, 4300),
         "SETUP_18C_REPLACEMENT_READY_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3004, "revs-pps", "READY",
            "revs-pps", "ACTIVE", "BEAR", "CORRECTION", "LEG 2",
            3738.0, 3700.0),
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
   const int beforeFailure = manager.LabProbeQueueSize();
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 3012, "revs-pps", "READY",
            "revs-pps", "WATCH", "BEAR", "CORRECTION", "LEG 1",
            0.0, 0.0)
         && manager.LabProbeQueueSize() == beforeFailure,
         "SETUP_20B_BASE_FAILURE_READY_TO_WATCH_NO_PUSH");

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
   int digits = (int)SymbolInfoInteger("XAUUSD", SYMBOL_DIGITS);
   if(digits < 0 || digits > 8)
      digits = 2;
   const string ppfBase = "Base " + DoubleToString(3710.0, digits)
                          + " - " + DoubleToString(3728.4, digits);
   const string ppsBaseA = "Base " + DoubleToString(3702.2, digits)
                           + " - " + DoubleToString(3740.0, digits);
   const string ppsBaseB = "Base " + DoubleToString(3700.0, digits)
                           + " - " + DoubleToString(3738.0, digits);
   const bool formatted = ArraySize(messages) == 7
      && Contains(messages[0],
                  "Revs-ppf | Watch\nBull | Correction | None\n"
                  "Pullback tracking started")
      && Contains(messages[1], "Revs-ppf | Active\n"
                  "Bull | Correction | Leg 1\nClose > Base High ")
      && Contains(messages[2], "Revs-ppf | Ready\n"
                  "Bull | Correction | None\n" + ppfBase)
      && Contains(messages[3], "Revs-pps | Watch\n"
                  "Bear | Correction | Leg 1\n"
                  "Local Swing Low confirmed")
      && Contains(messages[4], "Revs-pps | Ready\n"
                  "Bear | Correction | Leg 1\n" + ppsBaseA)
      && Contains(messages[5], "Revs-pps | Ready\n"
                  "Bear | Correction | Leg 1\n" + ppsBaseB)
      && Contains(messages[6], "Revs-pps | Active\n"
                  "Bear | Correction | Leg 2\nClose < Base Low ");
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

void TestSixSetupPolicy(void)
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);

   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5000, "-", "NONE",
            "bres-pma", "WATCH", "BULL", "IMPULSE", "CONTINUATION",
            0.0, 0.0),
         "SIX_SETUP_24_PMA_WATCH_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5010, "bres-pma", "WATCH",
            "bres-pma", "READY", "BULL", "IMPULSE", "MICRO BASE",
            110.0, 100.0, 4900),
         "SIX_SETUP_25_PMA_READY_ELIGIBLE");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5011, "bres-pma", "READY",
            "bres-pma", "READY", "BULL", "IMPULSE", "MICRO BASE",
            110.0, 100.0, 4900),
         "SIX_SETUP_25B_PMA_READY_IDENTITY_DEDUP");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5020, "bres-pma", "READY",
            "bres-pma", "ACTIVE", "BULL", "CORRECTION", "CONTINUATION",
            110.0, 100.0),
         "SIX_SETUP_26_PMA_ACTIVE_ELIGIBLE");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5030, "bres-pma", "ACTIVE",
            "bres-pma", "INVALID", "BULL", "CORRECTION", "NONE",
            110.0, 100.0),
         "SIX_SETUP_27_PMA_INVALID_EXCLUDED");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5040, "bres-pma", "INVALID",
            "-", "NONE", "BULL", "CORRECTION", "NONE", 0.0, 0.0),
         "SIX_SETUP_28_PMA_NONE_EXCLUDED");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5050, "bres-pma", "WATCH",
            "bres-pma", "WATCH", "BULL", "IMPULSE", "CONTINUATION",
            0.0, 0.0),
         "SIX_SETUP_29_UNCHANGED_PMA_NO_DUPLICATE");
   Check(!manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5060, "-", "NONE",
            "edge-mix", "WATCH", "BULL", "COMPRESSION", "RANGE EDGE",
            0.0, 0.0),
         "SIX_SETUP_30_EDGE_MIX_EXCLUDED");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5070, "edge-mix", "WATCH",
            "bres-pmb", "ACTIVE", "BULL", "EXPANSION", "BREAKOUT",
            0.0, 0.0),
         "SIX_SETUP_31_PMB_ACTIVE_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5080, "edge-mix", "WATCH",
            "revs-pfb", "ACTIVE", "BULL", "COMPRESSION", "FALSE BREAK",
            0.0, 0.0),
         "SIX_SETUP_32_PFB_ACTIVE_ELIGIBLE");
   Check(manager.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 5090, "edge-mix", "WATCH",
            "revs-pmr", "ACTIVE", "BEAR", "COMPRESSION", "REJECTION",
            0.0, 0.0),
         "SIX_SETUP_33_PMR_ACTIVE_ELIGIBLE");

   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 6
         && Contains(messages[0], "Bres-pma | Watch\n"
                     "Bull | Impulse | Continuation\n"
                     "Impulse tracking started")
         && Contains(messages[1], "Bres-pma | Ready\n"
                     "Bull | Impulse | Micro Base\nBase ")
         && Contains(messages[2], "Bres-pma | Active")
         && Contains(messages[3], "Bres-pmb | Active")
         && Contains(messages[4], "Revs-pfb | Active")
         && Contains(messages[5], "Revs-pmr | Active"),
         "SIX_SETUP_34_EXISTING_FORMAT_EXTENDED");
}

void TestSameBarSuppression(void)
{
   CStructureNotificationManager ppf;
   ppf.Configure(true, false);
   ppf.BeginClosedBarPolicy(6000);
   ppf.ObserveSetupTransition(6000, "revs-ppf", "ACTIVE", true);
   Check(!ppf.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 6000, "NONE", "LEG 1",
            "BULL", "CORRECTION")
         && ppf.EnqueueSetupTransition(
            "XAUUSD", PERIOD_H1, 6000, "revs-ppf", "READY",
            "revs-ppf", "ACTIVE", "BULL", "CORRECTION", "LEG 1",
            110.0, 100.0),
         "SUPPRESS_35_PPF_ACTIVE_WINS_LEG1");
   Check(ppf.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 5990, "NONE", "LEG 1",
            "BULL", "CORRECTION"),
         "SUPPRESS_36_SAME_BAR_ONLY_PRESERVES_EARLIER_CONTEXT");

   CStructureNotificationManager pps;
   pps.Configure(true, false);
   pps.ObserveSetupTransition(6010, "revs-pps", "ACTIVE", true);
   Check(!pps.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 6010, "NONE", "LEG 2",
            "BEAR", "CORRECTION"),
         "SUPPRESS_37_PPS_ACTIVE_WINS_LEG2");

   CStructureNotificationManager pma;
   pma.Configure(true, false);
   pma.ObserveSetupTransition(6020, "bres-pma", "READY", true);
   Check(!pma.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 6020, "CONTINUATION", "MICRO BASE",
            "BULL", "IMPULSE"),
         "SUPPRESS_38_PMA_READY_WINS_MICRO_BASE");
   Check(pma.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 6030, "CONTINUATION", "MICRO BASE",
            "BULL", "IMPULSE"),
         "SUPPRESS_39_MICRO_BASE_WITHOUT_PMA_READY_REMAINS");

   CStructureNotificationManager pmb;
   pmb.Configure(true, false);
   pmb.ObserveSetupTransition(6040, "bres-pmb", "ACTIVE", true);
   const bool breakoutSuppressed = !pmb.EnqueueMarketStructureTransition(
      "XAUUSD", PERIOD_H1, 6040, "SIDEWAY", "BREAKOUT",
      "BULL", "EXPANSION");
   StructureEvent coreUpdated = PolicyEvent(CORE_BOX_TRANSITION_STARTED,
      "PMB|CORE", MARKET_CYCLE_BEAR, MARKET_CYCLE_BULL,
      CORE_SWING_LOW, 6040);
   pmb.Enqueue(coreUpdated);
   StructureEvent cycle = PolicyEvent(CYCLE_CHANGED, "PMB|CYCLE",
      MARKET_CYCLE_BEAR, MARKET_CYCLE_BULL, CORE_SWING_NONE, 6040);
   pmb.Enqueue(cycle);
   Check(breakoutSuppressed && pmb.LabProbeQueueSize() == 1,
         "SUPPRESS_40_PMB_WINS_BREAKOUT_CORE_UPDATED_NOT_CYCLE");

   CStructureNotificationManager pfb;
   pfb.Configure(true, false);
   pfb.ObserveSetupTransition(6050, "revs-pfb", "ACTIVE", true);
   StructureEvent failed = PolicyEvent(CORE_BREAK_FAILED, "PFB|FAIL",
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_LOW, 6050);
   pfb.Enqueue(failed);
   Check(pfb.LabProbeQueueSize() == 0,
         "SUPPRESS_41_PFB_ACTIVE_WINS_CORE_BREAK_FAILED");

   CStructureNotificationManager pmr;
   pmr.Configure(true, false);
   pmr.ObserveSetupTransition(6060, "revs-pmr", "ACTIVE", true);
   Check(!pmr.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 6060, "RANGE EDGE", "REJECTION",
            "BULL", "COMPRESSION")
         && pmr.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 6070, "RANGE EDGE", "REJECTION",
            "BULL", "COMPRESSION"),
         "SUPPRESS_42_PMR_SAME_BAR_ONLY_REJECTION_POLICY");
}

void TestContextAndInternalAuthority(void)
{
   CStructureNotificationManager context;
   context.Configure(true, false);
   Check(context.EnqueueMarketStructureTransition(
            "XAUUSD", PERIOD_H1, 7000, "SIDEWAY", "RANGE EDGE",
            "BULL", "COMPRESSION"),
         "CONTEXT_43_RANGE_EDGE_REMAINS_ELIGIBLE");
   context.Enqueue(PolicyEvent(CORE_BREAK_CANDIDATE, "CTX|BREAK",
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_HIGH, 7010));
   context.Enqueue(PolicyEvent(SIDEWAY_CONFIRMED, "CTX|SIDEWAY",
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_NONE, 7020));
   context.Enqueue(PolicyEvent(CYCLE_CHANGED, "CTX|CYCLE",
      MARKET_CYCLE_BULL, MARKET_CYCLE_BEAR, CORE_SWING_NONE, 7030));
   Check(context.LabProbeQueueSize() == 4,
         "CONTEXT_44_BREAK_SIDEWAY_CYCLE_REMAIN_ELIGIBLE");

   CSetupOutputArbitrator arbitrator;
   SymbolState radar;
   radar.structure = "LEG 2";
   arbitrator.Project("revs-pps", "ACTIVE", "-", "NONE",
                      "revs-pfb", "ACTIVE", radar);
   CStructureNotificationManager internal;
   internal.Configure(true, false);
   internal.ObserveSetupTransition(7040, "revs-pps", "ACTIVE", true);
   internal.ObserveSetupTransition(7040, "revs-pfb", "ACTIVE", true);
   internal.EnqueueSetupTransition(
      "XAUUSD", PERIOD_H1, 7040, "revs-pps", "READY",
      "revs-pps", "ACTIVE", "BULL", "COMPRESSION", "LEG 2",
      110.0, 100.0);
   internal.EnqueueSetupTransition(
      "XAUUSD", PERIOD_H1, 7040, "edge-mix", "WATCH",
      "revs-pfb", "ACTIVE", "BULL", "COMPRESSION", "FALSE BREAK",
      0.0, 0.0);
   Check(radar.setup == "revs-pps" && radar.setupStatus == "ACTIVE"
         && internal.LabProbeQueueSize() == 2,
         "AUTHORITY_45_HIDDEN_RANGE_ACTIVE_STILL_NOTIFIES");
}

int OnInit(void)
{
   TestExistingEvents();
   TestMarketStructureTransitions();
   TestSetupTransitions();
   TestSixSetupPolicy();
   TestSameBarSuppression();
   TestContextAndInternalAuthority();
   TestTesterGuard();
   Print("[NOTIFICATION_POLICY_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push_attempts=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
