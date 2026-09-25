#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Phase 4C Range Edge Setup deterministic probe"

#include "../watch/setup/RangeEdgeSetupEngine.mqh"
#include "../watch/setup/PullbackSetupEngine.mqh"
#include "../watch/setup/SetupOutputArbitrator.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[RANGE_EDGE_SETUP_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[RANGE_EDGE_SETUP_TEST][FAIL] ", name);
   }
}

PriceStructureState RangeSource(const ENUM_MARKET_CYCLE cycle,
                                const long generation = 1)
{
   PriceStructureState source;
   ResetPriceStructureState(source);
   source.initialized = true;
   source.cycleState.cycle = cycle;
   source.coreBox.generation = generation;
   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   source.sidewayBox.ownerBoxGeneration = generation;
   source.sidewayBox.boxHigh = 110.0;
   source.sidewayBox.boxLow = 100.0;
   return source;
}

StructureEvent SetupEvent(const ENUM_STRUCTURE_EVENT_TYPE type,
                          const datetime time,
                          const ENUM_MARKET_CYCLE before,
                          const ENUM_MARKET_CYCLE after,
                          const long generation)
{
   StructureEvent event;
   ZeroMemory(event);
   event.type = type;
   event.eventBarTime = time;
   event.cycleBefore = before;
   event.cycleAfter = after;
   event.boxGeneration = generation;
   return event;
}

void AddEvent(StructureEvent &events[], const StructureEvent &event)
{
   const int count = ArraySize(events);
   ArrayResize(events, count + 1);
   events[count] = event;
}

MqlRates Bar(const datetime time, const double high,
             const double low, const double close)
{
   MqlRates bar;
   ZeroMemory(bar);
   bar.time = time;
   bar.open = close;
   bar.high = high;
   bar.low = low;
   bar.close = close;
   return bar;
}

void AddBar(MqlRates &rates[], const MqlRates &bar)
{
   const int count = ArraySize(rates);
   ArrayResize(rates, count + 1);
   rates[count] = bar;
}

SwingPoint Swing(const ENUM_SWING_TYPE type,
                 const datetime pivotTime,
                 const datetime confirmationTime,
                 const double price)
{
   SwingPoint point;
   ResetSwingPoint(point);
   point.type = type;
   point.time = pivotTime;
   point.confirmationTime = confirmationTime;
   point.price = price;
   point.confirmed = true;
   return point;
}

void AddSwing(SwingPoint &swings[], const SwingPoint &point)
{
   const int count = ArraySize(swings);
   ArrayResize(swings, count + 1);
   swings[count] = point;
}

bool ApplyPullback(CPullbackSetupEngine &engine,
                   const string previousState,
                   const ENUM_JINPA_MARKET_STATE state,
                   PriceStructureState &source,
                   SwingPoint &swings[], MqlRates &rates[],
                   SymbolState &output)
{
   return engine.Apply(previousState, state, source, swings, rates,
                       rates[ArraySize(rates) - 1].time, output);
}

void BuildBullPpsWatch(CPullbackSetupEngine &engine,
                       PriceStructureState &source,
                       SwingPoint &swings[], MqlRates &rates[],
                       SymbolState &output, const datetime start)
{
   engine.ConfigureSwingRightBars(1);
   source = RangeSource(MARKET_CYCLE_BULL, 20);
   output.setup = "-";
   output.setupStatus = "NONE";
   output.structure = "NONE";
   AddBar(rates, Bar(start, 112, 102, 106));
   ApplyPullback(engine, "IMPULSE", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
   AddBar(rates, Bar(start + 10, 110, 100, 104));
   ApplyPullback(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
   AddSwing(swings, Swing(SWING_LOW, start + 10, start + 20, 100));
   AddBar(rates, Bar(start + 20, 108, 102, 105));
   ApplyPullback(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
   AddBar(rates, Bar(start + 30, 112, 105, 111));
   ApplyPullback(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
   AddBar(rates, Bar(start + 40, 111, 103, 107));
   ApplyPullback(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
   AddBar(rates, Bar(start + 50, 110, 102, 106));
   ApplyPullback(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
   AddBar(rates, Bar(start + 60, 115, 105, 109));
   ApplyPullback(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
   AddSwing(swings, Swing(SWING_HIGH, start + 60, start + 70, 115));
   AddBar(rates, Bar(start + 70, 112, 104, 108));
   ApplyPullback(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                 source, swings, rates, output);
}

void Project(CRangeEdgeSetupEngine &engine,
             const string pullbackSetup,
             const string pullbackStatus,
             SymbolState &output)
{
   CSetupOutputArbitrator arbitrator;
   output.setup = "-";
   output.setupStatus = "NONE";
   arbitrator.Project(pullbackSetup, pullbackStatus,
                      "-", "NONE",
                      engine.SetupText(), engine.StatusText(), output);
}

void TestEdgeSideAuthority(void)
{
   CMarketStructureEngine engine;
   PriceStructureState source = RangeSource(MARKET_CYCLE_BULL, 2);
   MqlRates upper = Bar(100, 111, 108, 109.5);
   MqlRates lower = Bar(110, 102, 99, 100.5);
   MqlRates middle = Bar(120, 106, 104, 105.0);
   Check(engine.DeriveRangeEdgeSide(source, upper, 1.0)
         == JINPA_EDGE_UPPER, "EDGE_SIDE_01_UPPER_AUTHORITY");
   Check(engine.DeriveRangeEdgeSide(source, lower, 1.0)
         == JINPA_EDGE_LOWER, "EDGE_SIDE_02_LOWER_AUTHORITY");
   Check(engine.DeriveRangeEdgeSide(source, middle, 1.0)
         == JINPA_EDGE_NONE, "EDGE_SIDE_03_MIDDLE_NONE");

   source.sidewayBox.boxHigh = 101.0;
   source.sidewayBox.boxLow = 100.0;
   MqlRates overlap = Bar(130, 102, 99, 100.5);
   Check(engine.DeriveRangeEdgeSide(source, overlap, 1.0)
         == JINPA_EDGE_NONE, "EDGE_SIDE_04_OVERLAP_EXPLICITLY_AMBIGUOUS");
   Check(engine.Derive(JINPA_STATE_COMPRESSION, source, overlap,
                       1.0, false) == JINPA_STRUCTURE_RANGE_EDGE,
         "EDGE_SIDE_05_OVERLAP_PRESERVES_EXISTING_RANGE_EDGE_GEOMETRY");
}

void TestArmingAndIdentity(void)
{
   StructureEvent events[];
   PriceStructureState source = RangeSource(MARKET_CYCLE_BULL, 7);
   CRangeEdgeSetupEngine upper;
   upper.Apply(JINPA_STATE_COMPRESSION, source, events, 200,
               "RANGE EDGE", JINPA_EDGE_UPPER);
   SymbolState output;
   Project(upper, "-", "NONE", output);
   Check(upper.IsArmed() && upper.EdgeSide() == JINPA_EDGE_UPPER
         && upper.EdgeEntryTime() == 200
         && upper.OwnerBoxGeneration() == 7
         && output.setup == "edge-mix" && output.setupStatus == "WATCH",
         "ARM_06_UPPER_EDGE_MIX_WATCH");

   upper.Apply(JINPA_STATE_COMPRESSION, source, events, 210,
               "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(upper.IsArmed() && upper.EdgeEntryTime() == 200,
         "ARM_07_CONTINUOUS_EDGE_STABLE_IDENTITY");
   upper.Apply(JINPA_STATE_COMPRESSION, source, events, 220,
               "SIDEWAY", JINPA_EDGE_NONE);
   Check(!upper.IsArmed() && upper.Status() == JINPA_RANGE_STATUS_NONE,
         "ARM_08_MIDDLE_CLEARS_WATCH");
   upper.Apply(JINPA_STATE_COMPRESSION, source, events, 230,
               "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(upper.IsArmed() && upper.EdgeEntryTime() == 230,
         "ARM_09_LEAVE_AND_RETURN_NEW_EPISODE");
   upper.Apply(JINPA_STATE_COMPRESSION, source, events, 240,
               "RANGE EDGE", JINPA_EDGE_LOWER);
   Check(upper.EdgeSide() == JINPA_EDGE_LOWER
         && upper.EdgeEntryTime() == 240,
         "ARM_10_EDGE_SIDE_CHANGE_NEW_EPISODE");

   CRangeEdgeSetupEngine middle;
   middle.Apply(JINPA_STATE_COMPRESSION, source, events, 250,
                "SIDEWAY", JINPA_EDGE_NONE);
   Project(middle, "-", "NONE", output);
   Check(!middle.IsArmed() && output.setup == "-",
         "ARM_11_MIDDLE_NEVER_ARMS");

   CRangeEdgeSetupEngine guards;
   PriceStructureState unknown = RangeSource(MARKET_CYCLE_UNKNOWN, 7);
   guards.Apply(JINPA_STATE_COMPRESSION, unknown, events, 260,
                "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(!guards.IsArmed(), "ARM_12_UNKNOWN_CYCLE_BLOCKS_ARMING");
   PriceStructureState inactive = RangeSource(MARKET_CYCLE_BULL, 7);
   ResetSidewayBoxState(inactive.sidewayBox);
   guards.Apply(JINPA_STATE_COMPRESSION, inactive, events, 270,
                "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(!guards.IsArmed(), "ARM_13_INVALID_SIDEWAY_BLOCKS_ARMING");
   guards.Apply(JINPA_STATE_CORRECTION, source, events, 280,
                "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(!guards.IsArmed(), "ARM_14_NON_COMPRESSION_BLOCKS_ARMING");

   CRangeEdgeSetupEngine cycleGuard;
   cycleGuard.Apply(JINPA_STATE_COMPRESSION, source, events, 290,
                    "RANGE EDGE", JINPA_EDGE_UPPER);
   source.cycleState.cycle = MARKET_CYCLE_BEAR;
   cycleGuard.Apply(JINPA_STATE_COMPRESSION, source, events, 295,
                    "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(!cycleGuard.IsArmed()
         && cycleGuard.Status() == JINPA_RANGE_STATUS_NONE,
         "ARM_15_UNRESOLVED_ARMED_CYCLE_CHANGE_CLEARS_CONTEXT");
}

void TestPmbAndLifecycle(void)
{
   StructureEvent events[];
   PriceStructureState source = RangeSource(MARKET_CYCLE_BEAR, 8);
   CRangeEdgeSetupEngine upper;
   upper.Apply(JINPA_STATE_COMPRESSION, source, events, 300,
               "RANGE EDGE", JINPA_EDGE_UPPER);
   AddEvent(events, SetupEvent(CORE_BREAK_CANDIDATE, 310,
                              MARKET_CYCLE_BEAR, MARKET_CYCLE_BEAR, 8));
   upper.Apply(JINPA_STATE_COMPRESSION, source, events, 310,
               "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(upper.Status() == JINPA_RANGE_STATUS_WATCH
         && !upper.IsConsumed(), "PMB_12_CANDIDATE_NOT_ACTIVE");

   AddEvent(events, SetupEvent(CYCLE_CHANGED, 320,
                              MARKET_CYCLE_BEAR, MARKET_CYCLE_BULL, 8));
   AddEvent(events, SetupEvent(CORE_BOX_TRANSITION_STARTED, 320,
                              MARKET_CYCLE_BEAR, MARKET_CYCLE_BULL, 8));
   source.cycleState.cycle = MARKET_CYCLE_BULL;
   ResetSidewayBoxState(source.sidewayBox);
   upper.Apply(JINPA_STATE_EXPANSION, source, events, 320,
               "BREAKOUT", JINPA_EDGE_NONE);
   Check(upper.Setup() == JINPA_RANGE_SETUP_BRES_PMB
         && upper.Status() == JINPA_RANGE_STATUS_ACTIVE
         && upper.Direction() == JINPA_DIRECTION_BUY,
         "PMB_13_UPPER_ACTIVE_BUY_REGARDLESS_ARMED_BEAR_CYCLE");
   Check(upper.IsConsumed() && upper.TriggerBarTime() == 320,
         "PMB_14_CONFIRMED_BREAK_CONSUMES_EPISODE");

   upper.Apply(JINPA_STATE_EXPANSION, source, events, 330,
               "BREAKOUT", JINPA_EDGE_NONE);
   Check(upper.Status() == JINPA_RANGE_STATUS_INVALID,
         "LIFECYCLE_15_ACTIVE_NEXT_BAR_INVALID");
   upper.Apply(JINPA_STATE_COMPRESSION, RangeSource(MARKET_CYCLE_BULL, 8),
               events, 340, "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(upper.Status() == JINPA_RANGE_STATUS_NONE
         && upper.IsConsumed() && !upper.IsArmed(),
         "LIFECYCLE_16_INVALID_NEXT_BAR_NONE_NO_SAME_EPISODE_REARM");

   PriceStructureState restored = RangeSource(MARKET_CYCLE_BULL, 8);
   upper.Apply(JINPA_STATE_COMPRESSION, restored, events, 350,
               "SIDEWAY", JINPA_EDGE_NONE);
   upper.Apply(JINPA_STATE_COMPRESSION, restored, events, 360,
               "RANGE EDGE", JINPA_EDGE_UPPER);
   Check(upper.IsArmed() && !upper.IsConsumed()
         && upper.EdgeEntryTime() == 360,
         "EPISODE_17_NEW_APPROACH_REARMS");

   StructureEvent lowerEvents[];
   PriceStructureState lowerSource = RangeSource(MARKET_CYCLE_BULL, 9);
   CRangeEdgeSetupEngine lower;
   lower.Apply(JINPA_STATE_COMPRESSION, lowerSource, lowerEvents, 400,
               "RANGE EDGE", JINPA_EDGE_LOWER);
   AddEvent(lowerEvents, SetupEvent(CORE_BOX_TRANSITION_STARTED, 410,
                                   MARKET_CYCLE_BULL, MARKET_CYCLE_BEAR, 9));
   lowerSource.cycleState.cycle = MARKET_CYCLE_BEAR;
   ResetSidewayBoxState(lowerSource.sidewayBox);
   lower.Apply(JINPA_STATE_EXPANSION, lowerSource, lowerEvents, 410,
               "BREAKOUT", JINPA_EDGE_NONE);
   Check(lower.Setup() == JINPA_RANGE_SETUP_BRES_PMB
         && lower.Direction() == JINPA_DIRECTION_SELL,
         "PMB_18_LOWER_ACTIVE_SELL_REGARDLESS_ARMED_BULL_CYCLE");
}

void TestPfbAndPmrSymmetry(void)
{
   StructureEvent bullEvents[];
   PriceStructureState bull = RangeSource(MARKET_CYCLE_BULL, 10);
   CRangeEdgeSetupEngine bullLower;
   bullLower.Apply(JINPA_STATE_COMPRESSION, bull, bullEvents, 500,
                   "RANGE EDGE", JINPA_EDGE_LOWER);
   AddEvent(bullEvents, SetupEvent(CORE_BREAK_FAILED, 510,
                                  MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, 10));
   bullLower.Apply(JINPA_STATE_COMPRESSION, bull, bullEvents, 510,
                   "FALSE BREAK", JINPA_EDGE_LOWER);
   Check(bullLower.Setup() == JINPA_RANGE_SETUP_REVS_PFB
         && bullLower.Direction() == JINPA_DIRECTION_BUY,
         "PFB_19_BULL_LOWER_ACTIVE_BUY");

   StructureEvent bearEvents[];
   PriceStructureState bear = RangeSource(MARKET_CYCLE_BEAR, 11);
   CRangeEdgeSetupEngine bearUpper;
   bearUpper.Apply(JINPA_STATE_COMPRESSION, bear, bearEvents, 520,
                   "RANGE EDGE", JINPA_EDGE_UPPER);
   AddEvent(bearEvents, SetupEvent(CORE_BREAK_FAILED, 530,
                                  MARKET_CYCLE_BEAR, MARKET_CYCLE_BEAR, 11));
   bearUpper.Apply(JINPA_STATE_COMPRESSION, bear, bearEvents, 530,
                   "FALSE BREAK", JINPA_EDGE_UPPER);
   Check(bearUpper.Setup() == JINPA_RANGE_SETUP_REVS_PFB
         && bearUpper.Direction() == JINPA_DIRECTION_SELL,
         "PFB_20_BEAR_UPPER_ACTIVE_SELL");

   StructureEvent ineligibleEvents[];
   CRangeEdgeSetupEngine bullUpper;
   bullUpper.Apply(JINPA_STATE_COMPRESSION, bull, ineligibleEvents, 540,
                   "RANGE EDGE", JINPA_EDGE_UPPER);
   AddEvent(ineligibleEvents, SetupEvent(CORE_BREAK_FAILED, 550,
                                        MARKET_CYCLE_BULL,
                                        MARKET_CYCLE_BULL, 10));
   bullUpper.Apply(JINPA_STATE_COMPRESSION, bull, ineligibleEvents, 550,
                   "FALSE BREAK", JINPA_EDGE_UPPER);
   Check(bullUpper.Status() == JINPA_RANGE_STATUS_WATCH
         && !bullUpper.IsConsumed(),
         "PFB_21_BULL_UPPER_INELIGIBLE_NOT_CONSUMED");

   CRangeEdgeSetupEngine bearLower;
   bearLower.Apply(JINPA_STATE_COMPRESSION, bear, ineligibleEvents, 560,
                   "RANGE EDGE", JINPA_EDGE_LOWER);
   AddEvent(ineligibleEvents, SetupEvent(CORE_BREAK_FAILED, 570,
                                        MARKET_CYCLE_BEAR,
                                        MARKET_CYCLE_BEAR, 11));
   bearLower.Apply(JINPA_STATE_COMPRESSION, bear, ineligibleEvents, 570,
                   "FALSE BREAK", JINPA_EDGE_LOWER);
   Check(bearLower.Status() == JINPA_RANGE_STATUS_WATCH
         && !bearLower.IsConsumed(),
         "PFB_22_BEAR_LOWER_INELIGIBLE_NOT_CONSUMED");

   StructureEvent noEvents[];
   CRangeEdgeSetupEngine bullPmr;
   bullPmr.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 600,
                 "RANGE EDGE", JINPA_EDGE_LOWER);
   bullPmr.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 610,
                 "REJECTION", JINPA_EDGE_LOWER);
   Check(bullPmr.Setup() == JINPA_RANGE_SETUP_REVS_PMR
         && bullPmr.Direction() == JINPA_DIRECTION_BUY,
         "PMR_23_BULL_LOWER_ACTIVE_BUY");

   CRangeEdgeSetupEngine bearPmr;
   bearPmr.Apply(JINPA_STATE_COMPRESSION, bear, noEvents, 620,
                 "RANGE EDGE", JINPA_EDGE_UPPER);
   bearPmr.Apply(JINPA_STATE_COMPRESSION, bear, noEvents, 630,
                 "REJECTION", JINPA_EDGE_UPPER);
   Check(bearPmr.Setup() == JINPA_RANGE_SETUP_REVS_PMR
         && bearPmr.Direction() == JINPA_DIRECTION_SELL,
         "PMR_24_BEAR_UPPER_ACTIVE_SELL");

   CRangeEdgeSetupEngine bullWrong;
   bullWrong.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 640,
                   "RANGE EDGE", JINPA_EDGE_UPPER);
   bullWrong.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 650,
                   "REJECTION", JINPA_EDGE_UPPER);
   Check(bullWrong.Status() == JINPA_RANGE_STATUS_WATCH
         && !bullWrong.IsConsumed(),
         "PMR_25_BULL_UPPER_INELIGIBLE_NOT_CONSUMED");

   CRangeEdgeSetupEngine bearWrong;
   bearWrong.Apply(JINPA_STATE_COMPRESSION, bear, noEvents, 660,
                   "RANGE EDGE", JINPA_EDGE_LOWER);
   bearWrong.Apply(JINPA_STATE_COMPRESSION, bear, noEvents, 670,
                   "REJECTION", JINPA_EDGE_LOWER);
   Check(bearWrong.Status() == JINPA_RANGE_STATUS_WATCH
         && !bearWrong.IsConsumed(),
         "PMR_26_BEAR_LOWER_INELIGIBLE_NOT_CONSUMED");

   CRangeEdgeSetupEngine priority;
   StructureEvent priorityEvents[];
   priority.Apply(JINPA_STATE_COMPRESSION, bull, priorityEvents, 680,
                  "RANGE EDGE", JINPA_EDGE_LOWER);
   AddEvent(priorityEvents, SetupEvent(CORE_BREAK_FAILED, 690,
                                      MARKET_CYCLE_BULL,
                                      MARKET_CYCLE_BULL, 10));
   priority.Apply(JINPA_STATE_COMPRESSION, bull, priorityEvents, 690,
                  "REJECTION", JINPA_EDGE_LOWER);
   Check(priority.Setup() == JINPA_RANGE_SETUP_REVS_PFB,
         "PRIORITY_27_FALSE_BREAK_EVENT_WINS_REJECTION_PROJECTION");
   Check(priority.Status() == JINPA_RANGE_STATUS_ACTIVE
         && priority.TriggerBarTime() == 690,
         "PRIORITY_28_ONE_BAR_ONE_ACTIVE_SETUP");
}

void TestGenerationAndReplay(void)
{
   StructureEvent events[];
   PriceStructureState source = RangeSource(MARKET_CYCLE_BULL, 12);
   CRangeEdgeSetupEngine engine;
   engine.Apply(JINPA_STATE_COMPRESSION, source, events, 700,
                "RANGE EDGE", JINPA_EDGE_LOWER);
   source.sidewayBox.ownerBoxGeneration = 13;
   source.coreBox.generation = 13;
   engine.Apply(JINPA_STATE_COMPRESSION, source, events, 710,
                "RANGE EDGE", JINPA_EDGE_LOWER);
   Check(engine.IsArmed() && engine.OwnerBoxGeneration() == 13
         && engine.EdgeEntryTime() == 710,
         "EPISODE_29_NEW_GENERATION_NEW_IDENTITY");

   CRangeEdgeSetupEngine forward;
   CRangeEdgeSetupEngine replay;
   PriceStructureState replaySource = RangeSource(MARKET_CYCLE_BEAR, 14);
   StructureEvent replayEvents[];
   forward.Apply(JINPA_STATE_COMPRESSION, replaySource, replayEvents, 720,
                 "RANGE EDGE", JINPA_EDGE_UPPER);
   forward.Apply(JINPA_STATE_COMPRESSION, replaySource, replayEvents, 730,
                 "RANGE EDGE", JINPA_EDGE_UPPER);
   AddEvent(replayEvents, SetupEvent(CORE_BREAK_FAILED, 740,
                                    MARKET_CYCLE_BEAR,
                                    MARKET_CYCLE_BEAR, 14));
   forward.Apply(JINPA_STATE_COMPRESSION, replaySource, replayEvents, 740,
                 "FALSE BREAK", JINPA_EDGE_UPPER);
   replay.Apply(JINPA_STATE_COMPRESSION, replaySource, replayEvents, 720,
                "RANGE EDGE", JINPA_EDGE_UPPER);
   replay.Apply(JINPA_STATE_COMPRESSION, replaySource, replayEvents, 730,
                "RANGE EDGE", JINPA_EDGE_UPPER);
   replay.Apply(JINPA_STATE_COMPRESSION, replaySource, replayEvents, 740,
                "FALSE BREAK", JINPA_EDGE_UPPER);
   Check(forward.Setup() == replay.Setup()
         && forward.Status() == replay.Status()
         && forward.Direction() == replay.Direction()
         && forward.EdgeEntryTime() == replay.EdgeEntryTime(),
         "REPLAY_30_CHRONOLOGICAL_REPLAY_PARITY");
}

void TestConflictPolicy(void)
{
   StructureEvent events[];
   PriceStructureState bull = RangeSource(MARKET_CYCLE_BULL, 30);
   CRangeEdgeSetupEngine edge;
   edge.Apply(JINPA_STATE_COMPRESSION, bull, events, 800,
              "RANGE EDGE", JINPA_EDGE_LOWER);
   SymbolState output;
   Project(edge, "revs-pps", "WATCH", output);
   Check(edge.IsArmed() && output.setup == "revs-pps"
         && output.setupStatus == "WATCH",
         "CONFLICT_31_PPS_WATCH_DISPLAY_EDGE_ARMED_INTERNAL");
   Project(edge, "revs-pps", "READY", output);
   Check(edge.IsArmed() && output.setup == "revs-pps"
         && output.setupStatus == "READY",
         "CONFLICT_32_PPS_READY_DISPLAY_EDGE_MIX_HIDDEN");

   AddEvent(events, SetupEvent(CORE_BREAK_FAILED, 810,
                              MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, 30));
   edge.Apply(JINPA_STATE_COMPRESSION, bull, events, 810,
              "FALSE BREAK", JINPA_EDGE_LOWER);
   Project(edge, "revs-pps", "WATCH", output);
   Check(edge.Setup() == JINPA_RANGE_SETUP_REVS_PFB
         && output.setup == "revs-pfb" && output.setupStatus == "ACTIVE",
         "CONFLICT_33_PFB_ACTIVE_WINS_PPS_WATCH");

   StructureEvent noEvents[];
   CRangeEdgeSetupEngine pmr;
   pmr.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 820,
             "RANGE EDGE", JINPA_EDGE_LOWER);
   pmr.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 830,
             "REJECTION", JINPA_EDGE_LOWER);
   Project(pmr, "revs-pps", "READY", output);
   Check(output.setup == "revs-pmr" && output.setupStatus == "ACTIVE",
         "CONFLICT_34_PMR_ACTIVE_WINS_PPS_READY");
   Project(pmr, "revs-pps", "ACTIVE", output);
   Check(output.setup == "revs-pps" && output.setupStatus == "ACTIVE",
         "CONFLICT_35_PPS_ACTIVE_HIGHEST_PRIORITY");

   CRangeEdgeSetupEngine ineligible;
   ineligible.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 840,
                    "RANGE EDGE", JINPA_EDGE_UPPER);
   ineligible.Apply(JINPA_STATE_COMPRESSION, bull, noEvents, 850,
                    "REJECTION", JINPA_EDGE_UPPER);
   Project(ineligible, "revs-pps", "READY", output);
   Check(!ineligible.IsConsumed() && output.setup == "revs-pps"
         && output.setupStatus == "READY",
         "CONFLICT_36_INELIGIBLE_REJECTION_NEVER_DISPLACES_PPS");

   CRangeEdgeSetupEngine none;
   Project(none, "revs-pps", "WATCH", output);
   Check(output.setup == "revs-pps" && output.setupStatus == "WATCH",
         "CONFLICT_37_NO_RANGE_ACTIVE_PRESERVES_PHASE3_OUTPUT");

   CPullbackSetupEngine pullback;
   PriceStructureState pullbackSource;
   SwingPoint swings[];
   MqlRates rates[];
   SymbolState pullbackOutput;
   BuildBullPpsWatch(pullback, pullbackSource, swings, rates,
                     pullbackOutput, 1000);
   AddBar(rates, Bar(1080, 109, 95, 101));
   ApplyPullback(pullback, "CORRECTION", JINPA_STATE_COMPRESSION,
                 pullbackSource, swings, rates, pullbackOutput);
   AddSwing(swings, Swing(SWING_LOW, 1080, 1090, 95));
   AddBar(rates, Bar(1090, 108, 97, 102));
   ApplyPullback(pullback, "COMPRESSION", JINPA_STATE_COMPRESSION,
                 pullbackSource, swings, rates, pullbackOutput);
   Check(pullbackOutput.setup == "revs-pps"
         && pullbackOutput.setupStatus == "READY",
         "CONFLICT_38_REAL_PPS_READY_PRECONDITION");

   CRangeEdgeSetupEngine pmb;
   StructureEvent pmbEvents[];
   pmb.Apply(JINPA_STATE_COMPRESSION, pullbackSource, pmbEvents, 1090,
             "RANGE EDGE", JINPA_EDGE_UPPER);
   AddEvent(pmbEvents, SetupEvent(CORE_BOX_TRANSITION_STARTED, 1100,
                                 MARKET_CYCLE_BULL,
                                 MARKET_CYCLE_BULL, 20));
   ResetSidewayBoxState(pullbackSource.sidewayBox);
   AddBar(rates, Bar(1100, 120, 108, 118));
   ApplyPullback(pullback, "COMPRESSION", JINPA_STATE_EXPANSION,
                 pullbackSource, swings, rates, pullbackOutput);
   pmb.Apply(JINPA_STATE_EXPANSION, pullbackSource, pmbEvents, 1100,
             "BREAKOUT", JINPA_EDGE_NONE);
   Project(pmb, pullbackOutput.setup, pullbackOutput.setupStatus, output);
   Check(pullbackOutput.setup == "revs-pps"
         && pullbackOutput.setupStatus == "INVALID"
         && pmb.Setup() == JINPA_RANGE_SETUP_BRES_PMB
         && pmb.Status() == JINPA_RANGE_STATUS_ACTIVE,
         "CONFLICT_39_INTERNAL_PPS_INVALID_AND_PMB_ACTIVE_SAME_BAR");
   Check(output.setup == "bres-pmb" && output.setupStatus == "ACTIVE",
         "CONFLICT_40_PMB_ACTIVE_WINS_PPS_INVALID_OUTPUT");

   CPullbackSetupEngine actualPps;
   PriceStructureState actualSource;
   SwingPoint actualSwings[];
   MqlRates actualRates[];
   SymbolState actualOutput;
   BuildBullPpsWatch(actualPps, actualSource, actualSwings, actualRates,
                     actualOutput, 2000);
   CRangeEdgeSetupEngine actualPfb;
   StructureEvent actualPfbEvents[];
   actualPfb.Apply(JINPA_STATE_COMPRESSION, actualSource,
                   actualPfbEvents, 2070,
                   "RANGE EDGE", JINPA_EDGE_LOWER);
   AddBar(actualRates, Bar(2080, 109, 95, 101));
   ApplyPullback(actualPps, "CORRECTION", JINPA_STATE_COMPRESSION,
                 actualSource, actualSwings, actualRates, actualOutput);
   AddEvent(actualPfbEvents, SetupEvent(CORE_BREAK_FAILED, 2080,
                                       MARKET_CYCLE_BULL,
                                       MARKET_CYCLE_BULL, 20));
   actualPfb.Apply(JINPA_STATE_COMPRESSION, actualSource,
                   actualPfbEvents, 2080,
                   "FALSE BREAK", JINPA_EDGE_LOWER);
   Project(actualPfb, actualOutput.setup, actualOutput.setupStatus, output);
   Check(actualOutput.setup == "revs-pps"
         && actualOutput.setupStatus == "WATCH"
         && actualPfb.Setup() == JINPA_RANGE_SETUP_REVS_PFB
         && output.setup == "revs-pfb" && output.setupStatus == "ACTIVE",
         "CONFLICT_41_REAL_PPS_WATCH_CONTINUES_WHILE_PFB_WINS_OUTPUT");

   AddSwing(actualSwings, Swing(SWING_LOW, 2080, 2090, 95));
   AddBar(actualRates, Bar(2090, 108, 97, 102));
   ApplyPullback(actualPps, "COMPRESSION", JINPA_STATE_COMPRESSION,
                 actualSource, actualSwings, actualRates, actualOutput);
   CRangeEdgeSetupEngine actualPmr;
   StructureEvent actualPmrEvents[];
   actualPmr.Apply(JINPA_STATE_COMPRESSION, actualSource,
                   actualPmrEvents, 2090,
                   "RANGE EDGE", JINPA_EDGE_LOWER);
   AddBar(actualRates, Bar(2100, 108, 97, 102));
   ApplyPullback(actualPps, "COMPRESSION", JINPA_STATE_COMPRESSION,
                 actualSource, actualSwings, actualRates, actualOutput);
   actualPmr.Apply(JINPA_STATE_COMPRESSION, actualSource,
                   actualPmrEvents, 2100,
                   "REJECTION", JINPA_EDGE_LOWER);
   Project(actualPmr, actualOutput.setup, actualOutput.setupStatus, output);
   Check(actualOutput.setup == "revs-pps"
         && actualOutput.setupStatus == "READY"
         && actualPmr.Setup() == JINPA_RANGE_SETUP_REVS_PMR
         && output.setup == "revs-pmr" && output.setupStatus == "ACTIVE",
         "CONFLICT_42_REAL_PPS_READY_CONTINUES_WHILE_PMR_WINS_OUTPUT");
}

int OnInit(void)
{
   TestEdgeSideAuthority();
   TestArmingAndIdentity();
   TestPmbAndLifecycle();
   TestPfbAndPmrSymmetry();
   TestGenerationAndReplay();
   TestConflictPolicy();
   Print("[RANGE_EDGE_SETUP_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void)
{
   ExpertRemove();
}
