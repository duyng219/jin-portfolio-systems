#property strict
#property version "1.00"
#property description "JINPA DEV CoreBox deterministic non-trading probe"

#include "../watch/WatchIntegration.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string testName, const string detail)
{
   if(condition)
   {
      g_passed++;
      Print("[COREBOX_DEV_TEST][PASS] ", testName, " | ", detail);
   }
   else
   {
      g_failed++;
      Print("[COREBOX_DEV_TEST][FAIL] ", testName, " | ", detail);
   }
}

bool SamePrice(const double left, const double right)
{
   return MathAbs(left - right) < 0.0000001;
}

void ConfigureProbeEngine(CPriceStructureEngine &engine,
                          const int swingLeftBars,
                          const int swingRightBars,
                          const int atrPeriod,
                          const double atrBuffer,
                          const int confirmCloses)
{
   engine.Configure(swingLeftBars, swingRightBars,
                    true, 1.2, atrPeriod, 500,
                    true, atrBuffer, confirmCloses,
                    false, false);
}

int EventCount(CPriceStructureEngine &engine,
               const ENUM_STRUCTURE_EVENT_TYPE eventType)
{
   StructureEvent events[];
   engine.LabProbeEventHistory(events);
   int count = 0;
   for(int index = 0; index < ArraySize(events); index++)
      if(events[index].type == eventType)
         count++;
   return count;
}

void FeedCleanBull(CPriceStructureEngine &engine)
{
   engine.LabProbeSwing(SWING_LOW, 100.0, 1010, 1011);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1020, 1021);
   engine.LabProbeSwing(SWING_LOW, 98.0, 1030, 1031);
   engine.LabProbeSwing(SWING_HIGH, 104.0, 1040, 1041);
}

void FeedParityDataset(CPriceStructureEngine &engine)
{
   engine.LabProbeSwing(SWING_LOW, 100.0, 1010, 1011);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1020, 1021);
   engine.LabProbeClose(111.0, 1030);
   engine.LabProbeClose(105.0, 1031);
   engine.LabProbeSwing(SWING_LOW, 98.0, 1040, 1041);
   engine.LabProbeSwing(SWING_HIGH, 104.0, 1050, 1051);
   engine.LabProbeClose(111.0, 1060);
   engine.LabProbeClose(112.0, 1061);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1070, 1071);
}

void TestBullContinuation()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1010, 1011);
   engine.LabProbeClose(111.0, 1020);
   engine.LabProbeClose(112.0, 1021);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.generation == 2
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 95.0)
         && state.coreBox.cycle == MARKET_CYCLE_BULL
         && !state.sidewayBox.sidewayConfirmed,
         "TEST_01_BULL_CONTINUATION", "H1/O dual boundaries");
}

void TestBearContinuation()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1010, 1011);
   engine.LabProbeClose(89.0, 1020);
   engine.LabProbeClose(88.0, 1021);
   engine.LabProbeSwing(SWING_LOW, 80.0, 1030, 1031);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.generation == 2
         && SamePrice(state.coreBox.coreHigh.price, 105.0)
         && SamePrice(state.coreBox.coreLow.price, 80.0)
         && state.coreBox.cycle == MARKET_CYCLE_BEAR,
         "TEST_02_BEAR_CONTINUATION", "O/L1 dual boundaries");
}

void TestBullToBear()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1010, 1011);
   engine.LabProbeClose(89.0, 1020);
   engine.LabProbeClose(88.0, 1021);
   engine.LabProbeSwing(SWING_LOW, 80.0, 1030, 1031);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.cycle == MARKET_CYCLE_BEAR
         && SamePrice(state.coreBox.coreHigh.price, 105.0)
         && SamePrice(state.coreBox.coreLow.price, 80.0)
         && EventCount(engine, CYCLE_CHANGED) == 1,
         "TEST_03_BULL_TO_BEAR", "single cycle flip");
}

void TestBearToBull()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1010, 1011);
   engine.LabProbeClose(111.0, 1020);
   engine.LabProbeClose(112.0, 1021);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.cycle == MARKET_CYCLE_BULL
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 95.0)
         && EventCount(engine, CYCLE_CHANGED) == 1,
         "TEST_04_BEAR_TO_BULL", "single cycle flip");
}

void TestCleanBullSideway()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   PriceStructureState state = engine.LabProbeState();
   Check(state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.confirmationType == SIDEWAY_CLEAN_2_LEG
         && state.sidewayBox.internalConfirmedSwingCount == 4
         && EventCount(engine, LEG_1_CONFIRMED) == 1
         && EventCount(engine, LEG_2_CONFIRMED) == 1
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "TEST_05_CLEAN_BULL_SIDEWAY", "confirmed on recovery swing #4");
}

void TestCleanBearSideway()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_HIGH, 100.0, 1010, 1011);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1020, 1021);
   engine.LabProbeSwing(SWING_HIGH, 102.0, 1030, 1031);
   engine.LabProbeSwing(SWING_LOW, 96.0, 1040, 1041);
   PriceStructureState state = engine.LabProbeState();
   Check(state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.confirmationType == SIDEWAY_CLEAN_2_LEG
         && state.sidewayBox.internalConfirmedSwingCount == 4
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "TEST_06_CLEAN_BEAR_SIDEWAY", "symmetric recovery timing");
}

void TestNoisySixSwing()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1010, 1011);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1020, 1021);
   engine.LabProbeSwing(SWING_HIGH, 104.0, 1030, 1031);
   engine.LabProbeSwing(SWING_LOW, 96.0, 1040, 1041);
   engine.LabProbeSwing(SWING_HIGH, 103.0, 1050, 1051);
   PriceStructureState beforeSix = engine.LabProbeState();
   engine.LabProbeSwing(SWING_LOW, 97.0, 1060, 1061);
   PriceStructureState state = engine.LabProbeState();
   Check(!beforeSix.sidewayBox.sidewayConfirmed
         && state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.confirmationType == SIDEWAY_NOISY_6_SWING
         && state.sidewayBox.internalConfirmedSwingCount == 6,
         "TEST_07_NOISY_6_SWING", "false at 5, true at 6");
}

void TestFalseBreakBeforeSideway()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeClose(111.0, 1010);
   engine.LabProbeClose(105.0, 1011);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.generation == 1
         && SamePrice(state.coreBox.coreHigh.price, 110.0)
         && SamePrice(state.coreBox.coreLow.price, 90.0)
         && !state.sidewayBox.sidewayConfirmed
         && EventCount(engine, CORE_BREAK_FAILED) == 1,
         "TEST_08_FALSE_BREAK_BEFORE_SIDEWAY", "box and detector retained");
}

void TestFalseBreakAfterSideway()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeClose(111.0, 1050);
   engine.LabProbeClose(105.0, 1051);
   PriceStructureState state = engine.LabProbeState();
   Check(state.sidewayBox.sidewayConfirmed
         && state.coreBox.generation == 1
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1
         && EventCount(engine, CORE_BREAK_FAILED) == 1,
         "TEST_09_FALSE_BREAK_AFTER_SIDEWAY", "latch and event uniqueness");
}

void TestBreakAfterSideway()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeClose(111.0, 1050);
   engine.LabProbeClose(112.0, 1051);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1060, 1061);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.generation == 2
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 98.0)
         && !state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.internalConfirmedSwingCount == 0,
         "TEST_10_BREAK_AFTER_SIDEWAY", "new lifecycle resets latch/legs/count");
}

void TestInternalNoiseImmutability()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1010, 1011);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1020, 1021);
   engine.LabProbeSwing(SWING_HIGH, 103.0, 1030, 1031);
   engine.LabProbeSwing(SWING_LOW, 96.0, 1040, 1041);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.generation == 1
         && SamePrice(state.coreBox.coreHigh.price, 110.0)
         && SamePrice(state.coreBox.coreLow.price, 90.0),
         "TEST_11_INTERNAL_TOPOLOGY_NOISE", "dual boundaries immutable");
}

void TestStage210Causality()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 120.0, 80.0, 1000, false);
   engine.LabProbeSwing(SWING_LOW, 90.0, 1010, 1011);   // HL(1)
   engine.LabProbeSwing(SWING_LOW, 95.0, 1020, 1021);   // HL
   engine.LabProbeSwing(SWING_HIGH, 125.0, 1030, 1031); // HH
   engine.LabProbeSwing(SWING_HIGH, 115.0, 1040, 1041); // LH(2)
   engine.LabProbeSwing(SWING_LOW, 100.0, 1050, 1051);  // HL
   engine.LabProbeSwing(SWING_LOW, 75.0, 1060, 1061);   // LL(3)
   engine.LabProbeClose(79.0, 1070);
   engine.LabProbeClose(85.0, 1071);                    // false break
   engine.LabProbeSwing(SWING_HIGH, 130.0, 1080, 1081); // HH(4)
   engine.LabProbeClose(79.0, 1090);
   engine.LabProbeClose(78.0, 1091);
   engine.LabProbeSwing(SWING_LOW, 70.0, 1100, 1101);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.generation == 2
         && SamePrice(state.coreBox.coreHigh.price, 130.0)
         && state.coreBox.coreHigh.classification == STRUCT_HH
         && !SamePrice(state.coreBox.coreHigh.price, 115.0),
         "TEST_12_STAGE_2_10_CAUSALITY", "HH(4) origin retained as HH");
}

void TestDualRendererContract()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   CStructureDebugRenderer renderer;
   renderer.Configure(true, true);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord sideway[];
   PriceStructureState before = engine.LabProbeState();
   renderer.Update(before, swings, broken, sideway);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1010, 1011);
   engine.LabProbeClose(111.0, 1020);
   engine.LabProbeClose(105.0, 1021);
   PriceStructureState unchanged = engine.LabProbeState();
   renderer.Update(unchanged, swings, broken, sideway);
   engine.LabProbeClose(111.0, 1030);
   engine.LabProbeClose(112.0, 1031);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1040, 1041);
   PriceStructureState changed = engine.LabProbeState();
   renderer.Update(changed, swings, broken, sideway);

   const string highName = "JINPA_STRUCT_CORE_HIGH";
   const string lowName = "JINPA_STRUCT_CORE_LOW";
   int ownedLineCount = 0;
   const int lineCount = ObjectsTotal(0, 0, OBJ_HLINE);
   for(int index = 0; index < lineCount; index++)
      if(StringFind(ObjectName(0, index, 0, OBJ_HLINE),
                    "JINPA_STRUCT_CORE_") == 0)
         ownedLineCount++;
   const bool rendererOk = ObjectFind(0, highName) >= 0
      && ObjectFind(0, lowName) >= 0
      && ownedLineCount == 2
      && SamePrice(ObjectGetDouble(0, highName, OBJPROP_PRICE), 120.0)
      && SamePrice(ObjectGetDouble(0, lowName, OBJPROP_PRICE), 95.0);
   Check(before.coreBox.valid
         && SamePrice(unchanged.coreBox.coreHigh.price, 110.0)
         && SamePrice(unchanged.coreBox.coreLow.price, 90.0)
         && changed.coreBox.generation == 2
         && rendererOk,
         "TEST_13_DUAL_RENDERER", "exactly two stable lines, atomic new generation");
   renderer.Destroy();
}

void TestBootstrapParity()
{
   CPriceStructureEngine bootstrap;
   CPriceStructureEngine sequential;
   bootstrap.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, true);
   sequential.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedParityDataset(bootstrap);
   FeedParityDataset(sequential);
   PriceStructureState left = bootstrap.LabProbeState();
   PriceStructureState right = sequential.LabProbeState();
   StructureEvent leftEvents[];
   StructureEvent rightEvents[];
   bootstrap.LabProbeEventHistory(leftEvents);
   sequential.LabProbeEventHistory(rightEvents);
   bool eventParity = ArraySize(leftEvents) == ArraySize(rightEvents);
   for(int index = 0; eventParity && index < ArraySize(leftEvents); index++)
      eventParity = leftEvents[index].type == rightEvents[index].type
                    && leftEvents[index].identity == rightEvents[index].identity
                    && leftEvents[index].reason == rightEvents[index].reason;
   Check(SamePrice(left.coreBox.coreHigh.price, right.coreBox.coreHigh.price)
         && SamePrice(left.coreBox.coreLow.price, right.coreBox.coreLow.price)
         && left.coreBox.cycle == right.coreBox.cycle
         && left.coreBox.generation == right.coreBox.generation
         && left.sidewayBox.sidewayConfirmed
            == right.sidewayBox.sidewayConfirmed
         && left.sidewayBox.leg1Confirmed == right.sidewayBox.leg1Confirmed
         && left.sidewayBox.leg2Confirmed == right.sidewayBox.leg2Confirmed
         && left.sidewayBox.internalConfirmedSwingCount
            == right.sidewayBox.internalConfirmedSwingCount
         && eventParity,
         "TEST_14_BOOTSTRAP_PARITY", "state and ordered semantic events exact");
}

void TestDefaultConfigurationGolden()
{
   CPriceStructureEngine engine;
   ConfigureProbeEngine(engine, 5, 5, 14, 0.10, 2);
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedParityDataset(engine);
   PriceStructureState state = engine.LabProbeState();
   StructureEvent events[];
   engine.LabProbeEventHistory(events);
   const ENUM_STRUCTURE_EVENT_TYPE golden[] =
   {
      CORE_BOX_INITIALIZED,
      LEG_1_CONFIRMED,
      CORE_BREAK_CANDIDATE,
      CORE_BREAK_FAILED,
      LEG_2_CONFIRMED,
      SIDEWAY_CONFIRMED,
      CORE_BREAK_CANDIDATE,
      CORE_BOX_TRANSITION_STARTED,
      CORE_BOX_CHANGED
   };
   bool orderedEvents = ArraySize(events) == ArraySize(golden);
   for(int index = 0; orderedEvents && index < ArraySize(golden); index++)
      orderedEvents = events[index].type == golden[index];
   Check(state.coreBox.valid && state.coreBox.generation == 2
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 98.0)
         && state.coreBox.cycle == MARKET_CYCLE_BULL
         && !state.sidewayBox.sidewayConfirmed
         && orderedEvents,
         "CONFIG_01_DEFAULT_GOLDEN", "5/5, ATR 14x0.10, closes 2 exact event order");
}

void TestWatchConfigurationAndValidation()
{
   CWatchIntegration watch;
   int left = 0;
   int right = 0;
   int atrPeriod = 0;
   double buffer = 0.0;
   int closes = 0;
   bool showCore = false;
   bool showSwings = false;
   watch.GetStructureConfiguration(left, right, atrPeriod, buffer, closes,
                                   showCore, showSwings);
   const bool defaults = left == 5 && right == 5 && atrPeriod == 14
                         && SamePrice(buffer, 0.10) && closes == 2
                         && showCore && showSwings;
   const bool accepted = watch.ConfigureStructure(4, 3, 10, 0.25, 3,
                                                   false, true);
   watch.GetStructureConfiguration(left, right, atrPeriod, buffer, closes,
                                   showCore, showSwings);
   const bool routed = left == 4 && right == 3 && atrPeriod == 10
                       && SamePrice(buffer, 0.25) && closes == 3
                       && !showCore && showSwings;
   const bool invalidRejected =
      !watch.ConfigureStructure(0, 3, 10, 0.25, 3, true, true)
      && !watch.ConfigureStructure(3, 0, 10, 0.25, 3, true, true)
      && !watch.ConfigureStructure(3, 3, 0, 0.25, 3, true, true)
      && !watch.ConfigureStructure(3, 3, 10, -0.01, 3, true, true)
      && !watch.ConfigureStructure(3, 3, 10, 0.25, 0, true, true);
   Check(defaults && accepted && routed && invalidRejected,
         "CONFIG_02_WATCH_ROUTING_VALIDATION",
         "defaults/routing valid; invalid values rejected");
}

void TestSwingWindowSmoke(const int left, const int right,
                          const string testName)
{
   CPriceStructureEngine engine;
   ConfigureProbeEngine(engine, left, right, 14, 0.10, 2);
   int actualLeft = 0;
   int actualRight = 0;
   int atrPeriod = 0;
   double buffer = 0.0;
   int closes = 0;
   engine.LabProbeConfiguration(actualLeft, actualRight, atrPeriod,
                                buffer, closes);
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedParityDataset(engine);
   PriceStructureState state = engine.LabProbeState();
   Check(actualLeft == left && actualRight == right
         && state.coreBox.valid && state.coreBox.generation >= 1
         && !state.cycleState.breakCandidate,
         testName, "requested swing windows active; lifecycle valid");
}

void TestATRBufferSmoke()
{
   CPriceStructureEngine engine;
   ConfigureProbeEngine(engine, 5, 5, 14, 0.50, 2);
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeClose(110.40, 1010, 1.0);
   PriceStructureState below = engine.LabProbeState();
   engine.LabProbeClose(110.60, 1011, 1.0);
   PriceStructureState above = engine.LabProbeState();
   Check(!below.cycleState.breakCandidate
         && above.cycleState.breakCandidate
         && SamePrice(above.cycleState.breakLevel, 110.50),
         "CONFIG_05_ATR_BUFFER_SMOKE", "0.50 changes active threshold to 110.50");
}

void BuildATRRates(MqlRates &rates[])
{
   ArrayResize(rates, 7);
   for(int index = 0; index < 7; index++)
   {
      ZeroMemory(rates[index]);
      rates[index].close = 100.0;
      rates[index].high = 100.0 + index;
      rates[index].low = 100.0 - index;
   }
}

void TestATRPeriodSmoke()
{
   CPriceStructureEngine period3;
   CPriceStructureEngine period5;
   ConfigureProbeEngine(period3, 5, 5, 3, 0.10, 2);
   ConfigureProbeEngine(period5, 5, 5, 5, 0.10, 2);
   MqlRates rates[];
   BuildATRRates(rates);
   const double atr3 = period3.LabProbeCalculateATR(rates, 6);
   const double atr5 = period5.LabProbeCalculateATR(rates, 6);
   Check(SamePrice(atr3, 10.0) && SamePrice(atr5, 8.0)
         && !SamePrice(atr3, atr5),
         "CONFIG_06_ATR_PERIOD_SMOKE", "period 3 and 5 drive active ATR window");
}

void TestConfirmClosesSmoke()
{
   CPriceStructureEngine engine;
   ConfigureProbeEngine(engine, 5, 5, 14, 0.10, 3);
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeClose(111.0, 1010);
   engine.LabProbeClose(112.0, 1011);
   PriceStructureState afterTwo = engine.LabProbeState();
   engine.LabProbeClose(113.0, 1012);
   PriceStructureState afterThree = engine.LabProbeState();
   Check(afterTwo.cycleState.breakCandidate
         && afterTwo.cycleState.confirmationCount == 2
         && !afterTwo.pendingCoreBox.active
         && afterThree.pendingCoreBox.active,
         "CONFIG_07_CONFIRM_CLOSES_SMOKE", "3 confirms on third consecutive close");
}

int CountOwnedObjects(const string prefix, const ENUM_OBJECT objectType)
{
   int count = 0;
   const int total = ObjectsTotal(0, 0, objectType);
   for(int index = 0; index < total; index++)
      if(StringFind(ObjectName(0, index, 0, objectType), prefix) == 0)
         count++;
   return count;
}

int CountOwnedObjectsAny(const string prefix)
{
   int count = 0;
   const int total = ObjectsTotal(0, 0, -1);
   for(int index = 0; index < total; index++)
      if(StringFind(ObjectName(0, index, 0, -1), prefix) == 0)
         count++;
   return count;
}

void TestDisplayCombination(const bool showCore,
                            const bool showSwings,
                            const string testName)
{
   CPriceStructureEngine engine;
   ConfigureProbeEngine(engine, 5, 5, 14, 0.10, 2);
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedParityDataset(engine);
   PriceStructureState before = engine.LabProbeState();
   StructureEvent beforeEvents[];
   engine.LabProbeEventHistory(beforeEvents);

   SwingPoint swings[];
   ArrayResize(swings, 4);
   ResetSwingPoint(swings[0]);
   ResetSwingPoint(swings[1]);
   ResetSwingPoint(swings[2]);
   ResetSwingPoint(swings[3]);
   swings[0].time = 1010;
   swings[0].price = 100.0;
   swings[0].type = SWING_LOW;
   swings[0].classification = STRUCT_HL;
   swings[0].confirmed = true;
   swings[1].time = 1020;
   swings[1].price = 105.0;
   swings[1].type = SWING_HIGH;
   swings[1].classification = STRUCT_LH;
   swings[1].confirmed = true;
   swings[2].time = 1040;
   swings[2].price = 98.0;
   swings[2].type = SWING_LOW;
   swings[2].classification = STRUCT_LL;
   swings[2].confirmed = true;
   swings[3].time = 1070;
   swings[3].price = 120.0;
   swings[3].type = SWING_HIGH;
   swings[3].classification = STRUCT_HH;
   swings[3].confirmed = true;
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];

   CStructureDebugRenderer renderer;
   renderer.Configure(showCore, showSwings);
   renderer.Destroy();
   renderer.Update(before, swings, broken, boxes);
   const int coreLines = CountOwnedObjects(
      "JINPA_STRUCT_CORE_", OBJ_HLINE);
   const int swingLabels = CountOwnedObjects(
      "JINPA_SWING_", OBJ_TEXT);
   const int allCoreObjects = CountOwnedObjectsAny(
      "JINPA_STRUCT_CORE_");
   const int allSwingObjects = CountOwnedObjectsAny(
      "JINPA_SWING_");
   PriceStructureState after = engine.LabProbeState();
   StructureEvent afterEvents[];
   engine.LabProbeEventHistory(afterEvents);
   bool eventParity = ArraySize(beforeEvents) == ArraySize(afterEvents);
   for(int index = 0; eventParity && index < ArraySize(beforeEvents); index++)
      eventParity = beforeEvents[index].type == afterEvents[index].type
                    && beforeEvents[index].identity == afterEvents[index].identity
                    && beforeEvents[index].reason == afterEvents[index].reason;
   const bool goldenState = before.coreBox.valid
                            && before.coreBox.generation == 2
                            && SamePrice(before.coreBox.coreHigh.price, 120.0)
                            && SamePrice(before.coreBox.coreLow.price, 98.0)
                            && before.coreBox.cycle == MARKET_CYCLE_BULL
                            && !before.pendingCoreBox.active
                            && !before.sidewayBox.sidewayConfirmed
                            && !before.sidewayBox.leg1Confirmed
                            && !before.sidewayBox.leg2Confirmed
                            && before.sidewayBox.internalConfirmedSwingCount == 0
                            && ArraySize(beforeEvents) == 9;
   const bool stateParity = SamePrice(before.coreBox.coreHigh.price,
                                       after.coreBox.coreHigh.price)
                            && SamePrice(before.coreBox.coreLow.price,
                                         after.coreBox.coreLow.price)
                            && before.coreBox.cycle == after.coreBox.cycle
                            && before.coreBox.generation == after.coreBox.generation
                            && before.sidewayBox.sidewayConfirmed
                               == after.sidewayBox.sidewayConfirmed
                            && before.sidewayBox.leg1Confirmed
                               == after.sidewayBox.leg1Confirmed
                            && before.sidewayBox.leg2Confirmed
                               == after.sidewayBox.leg2Confirmed
                             && before.sidewayBox.internalConfirmedSwingCount
                                == after.sidewayBox.internalConfirmedSwingCount
                             && before.pendingCoreBox.active
                                == after.pendingCoreBox.active
                             && before.cycleState.breakCandidate
                                == after.cycleState.breakCandidate
                             && before.cycleState.confirmationCount
                                == after.cycleState.confirmationCount
                             && before.lastSwingHigh.time == after.lastSwingHigh.time
                             && before.lastSwingLow.time == after.lastSwingLow.time
                             && eventParity;
   Check(coreLines == (showCore ? 2 : 0)
          && swingLabels == (showSwings ? 4 : 0)
          && (showCore || allCoreObjects == 0)
          && allSwingObjects == (showSwings ? 4 : 0)
          && goldenState && stateParity,
         testName, "visual inventory only; structural state/events identical");
   renderer.Destroy();
}

bool HasDuplicateEventIdentities(CPriceStructureEngine &engine)
{
   StructureEvent events[];
   engine.LabProbeEventHistory(events);
   for(int left = 0; left < ArraySize(events); left++)
      for(int right = left + 1; right < ArraySize(events); right++)
         if(events[left].identity == events[right].identity)
            return true;
   return false;
}

bool SameCase5StateAndEvents(CPriceStructureEngine &leftEngine,
                             CPriceStructureEngine &rightEngine)
{
   PriceStructureState left = leftEngine.LabProbeState();
   PriceStructureState right = rightEngine.LabProbeState();
   StructureEvent leftEvents[];
   StructureEvent rightEvents[];
   leftEngine.LabProbeEventHistory(leftEvents);
   rightEngine.LabProbeEventHistory(rightEvents);
   bool eventParity = ArraySize(leftEvents) == ArraySize(rightEvents);
   for(int index = 0; eventParity && index < ArraySize(leftEvents); index++)
      eventParity = leftEvents[index].type == rightEvents[index].type
                    && leftEvents[index].identity == rightEvents[index].identity
                    && leftEvents[index].reason == rightEvents[index].reason;
   return left.coreBox.valid == right.coreBox.valid
          && left.coreBox.lifecycle == right.coreBox.lifecycle
          && SamePrice(left.coreBox.coreHigh.price, right.coreBox.coreHigh.price)
          && SamePrice(left.coreBox.coreLow.price, right.coreBox.coreLow.price)
          && left.coreBox.cycle == right.coreBox.cycle
          && left.coreBox.generation == right.coreBox.generation
          && left.pendingCoreBox.active == right.pendingCoreBox.active
          && left.pendingCoreBox.direction == right.pendingCoreBox.direction
          && left.pendingCoreBox.targetGeneration
             == right.pendingCoreBox.targetGeneration
          && left.pendingCoreBox.breakOrigin.time
             == right.pendingCoreBox.breakOrigin.time
          && SamePrice(left.pendingCoreBox.breakOrigin.price,
                       right.pendingCoreBox.breakOrigin.price)
          && left.sidewayBox.leg1Confirmed == right.sidewayBox.leg1Confirmed
          && left.sidewayBox.leg2Confirmed == right.sidewayBox.leg2Confirmed
          && left.sidewayBox.sidewayConfirmed
             == right.sidewayBox.sidewayConfirmed
          && left.sidewayBox.internalConfirmedSwingCount
             == right.sidewayBox.internalConfirmedSwingCount
          && eventParity;
}

void BeginUpTransition(CPriceStructureEngine &engine,
                       const double originLow = 95.0,
                       const datetime startTime = 1010)
{
   engine.LabProbeSwing(SWING_LOW, originLow, startTime, startTime + 1);
   engine.LabProbeClose(111.0, startTime + 10);
   engine.LabProbeClose(112.0, startTime + 11);
}

void BeginDownTransition(CPriceStructureEngine &engine,
                         const double originHigh = 105.0,
                         const datetime startTime = 1010)
{
   engine.LabProbeSwing(SWING_HIGH, originHigh, startTime, startTime + 1);
   engine.LabProbeClose(89.0, startTime + 10);
   engine.LabProbeClose(88.0, startTime + 11);
}

void TestCase5BullContinuation()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   PriceStructureState pending = engine.LabProbeState();
   StructureEvent events[];
   engine.LabProbeEventHistory(events);
   const bool order = ArraySize(events) == 4
      && events[0].type == CORE_BOX_INITIALIZED
      && events[1].type == LEG_1_CONFIRMED
      && events[2].type == CORE_BREAK_CANDIDATE
      && events[3].type == CORE_BOX_TRANSITION_STARTED;
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   PriceStructureState complete = engine.LabProbeState();
   Check(!pending.coreBox.valid
         && pending.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && SamePrice(pending.coreBox.coreLow.price, 95.0)
         && !pending.coreBox.coreHigh.confirmed
         && pending.coreBox.generation == 1
         && pending.pendingCoreBox.targetGeneration == 2
         && pending.coreSwing.hasCoreLow
         && !pending.coreSwing.hasCoreHigh
         && SamePrice(pending.coreSwing.coreSwingLow, 95.0)
         && !pending.sidewayBox.leg1Confirmed
         && pending.sidewayBox.internalConfirmedSwingCount == 0
         && complete.coreBox.valid
         && complete.coreBox.lifecycle == CORE_BOX_COMPLETE
         && complete.coreBox.generation == 2
         && SamePrice(complete.coreBox.coreHigh.price, 120.0)
         && SamePrice(complete.coreBox.coreLow.price, 95.0)
         && order,
         "CASE5_01_BULL_CONTINUATION",
         "origin Low immediate; High pending; one completion");
}

void TestCase5BearContinuation()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   PriceStructureState pending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_LOW, 80.0, 1030, 1031);
   PriceStructureState complete = engine.LabProbeState();
   Check(!pending.coreBox.valid
         && pending.coreBox.lifecycle == CORE_BOX_PENDING_LOW
         && SamePrice(pending.coreBox.coreHigh.price, 105.0)
         && !pending.coreBox.coreLow.confirmed
         && pending.coreBox.generation == 1
         && pending.coreSwing.hasCoreHigh
         && !pending.coreSwing.hasCoreLow
         && SamePrice(pending.coreSwing.coreSwingHigh, 105.0)
         && complete.coreBox.valid && complete.coreBox.generation == 2
         && SamePrice(complete.coreBox.coreHigh.price, 105.0)
         && SamePrice(complete.coreBox.coreLow.price, 80.0),
         "CASE5_02_BEAR_CONTINUATION",
         "origin High immediate; Low pending; one completion");
}

void TestCase5BullToBear()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   PriceStructureState pending = engine.LabProbeState();
   StructureEvent pendingEvents[];
   engine.LabProbeEventHistory(pendingEvents);
   const bool order = ArraySize(pendingEvents) == 4
      && pendingEvents[0].type == CORE_BOX_INITIALIZED
      && pendingEvents[1].type == CORE_BREAK_CANDIDATE
      && pendingEvents[2].type == CYCLE_CHANGED
      && pendingEvents[3].type == CORE_BOX_TRANSITION_STARTED;
   engine.LabProbeSwing(SWING_LOW, 80.0, 1030, 1031);
   PriceStructureState complete = engine.LabProbeState();
   Check(pending.cycleState.cycle == MARKET_CYCLE_BEAR
         && pending.coreBox.cycle == MARKET_CYCLE_BEAR
         && pending.coreBox.lifecycle == CORE_BOX_PENDING_LOW
         && SamePrice(pending.coreBox.coreHigh.price, 105.0)
         && EventCount(engine, CYCLE_CHANGED) == 1
         && complete.coreBox.valid && complete.coreBox.generation == 2
         && order,
         "CASE5_03_BULL_TO_BEAR",
         "cycle flips at break; expansion Low completes later");
}

void TestCase5BearToBull()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   PriceStructureState pending = engine.LabProbeState();
   StructureEvent pendingEvents[];
   engine.LabProbeEventHistory(pendingEvents);
   const bool order = ArraySize(pendingEvents) == 4
      && pendingEvents[0].type == CORE_BOX_INITIALIZED
      && pendingEvents[1].type == CORE_BREAK_CANDIDATE
      && pendingEvents[2].type == CYCLE_CHANGED
      && pendingEvents[3].type == CORE_BOX_TRANSITION_STARTED;
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   PriceStructureState complete = engine.LabProbeState();
   Check(pending.cycleState.cycle == MARKET_CYCLE_BULL
         && pending.coreBox.cycle == MARKET_CYCLE_BULL
         && pending.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && SamePrice(pending.coreBox.coreLow.price, 95.0)
         && EventCount(engine, CYCLE_CHANGED) == 1
         && complete.coreBox.valid && complete.coreBox.generation == 2
         && order,
         "CASE5_04_BEAR_TO_BULL",
         "mirror cycle timing and delayed expansion completion");
}

void TestCase5NoEarlyLeg()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   const int leg1Before = EventCount(engine, LEG_1_CONFIRMED);
   engine.LabProbeSwing(SWING_LOW, 100.0, 1030, 1031);
   engine.LabProbeSwing(SWING_HIGH, 108.0, 1040, 1041);
   engine.LabProbeSwing(SWING_LOW, 99.0, 1050, 1051);
   PriceStructureState state = engine.LabProbeState();
   Check(state.pendingCoreBox.active
         && state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && !state.sidewayBox.leg1Confirmed
         && !state.sidewayBox.leg2Confirmed
         && !state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.internalConfirmedSwingCount == 0
         && EventCount(engine, LEG_1_CONFIRMED) == leg1Before,
         "CASE5_05_NO_EARLY_LEG",
         "pending swings excluded from detector");
}

void TestCase5LegAfterCompletion()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   const int leg1Before = EventCount(engine, LEG_1_CONFIRMED);
   const int leg2Before = EventCount(engine, LEG_2_CONFIRMED);
   const int sidewayBefore = EventCount(engine, SIDEWAY_CONFIRMED);
   engine.LabProbeSwing(SWING_LOW, 100.0, 1040, 1041);
   engine.LabProbeSwing(SWING_HIGH, 110.0, 1050, 1051);
   engine.LabProbeSwing(SWING_LOW, 98.0, 1060, 1061);
   engine.LabProbeSwing(SWING_HIGH, 109.0, 1070, 1071);
   PriceStructureState state = engine.LabProbeState();
   Check(state.sidewayBox.leg1Confirmed
         && state.sidewayBox.leg2Confirmed
         && state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.confirmationType == SIDEWAY_CLEAN_2_LEG
         && EventCount(engine, LEG_1_CONFIRMED) == leg1Before + 1
         && EventCount(engine, LEG_2_CONFIRMED) == leg2Before + 1
         && EventCount(engine, SIDEWAY_CONFIRMED) == sidewayBefore + 1,
         "CASE5_06_LEG_AFTER_COMPLETION",
         "clean Sideway starts only after Box completion");
}

void TestCase5NoisyCountReset()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   engine.LabProbeSwing(SWING_LOW, 100.0, 1030, 1031);
   engine.LabProbeSwing(SWING_HIGH, 109.0, 1040, 1041);
   PriceStructureState pending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1050, 1051);
   engine.LabProbeSwing(SWING_HIGH, 110.0, 1060, 1061);
   engine.LabProbeSwing(SWING_LOW, 101.0, 1070, 1071);
   engine.LabProbeSwing(SWING_HIGH, 109.0, 1080, 1081);
   engine.LabProbeSwing(SWING_LOW, 102.0, 1090, 1091);
   engine.LabProbeSwing(SWING_HIGH, 108.0, 1100, 1101);
   PriceStructureState beforeSix = engine.LabProbeState();
   engine.LabProbeSwing(SWING_LOW, 103.0, 1110, 1111);
   PriceStructureState state = engine.LabProbeState();
   Check(pending.sidewayBox.internalConfirmedSwingCount == 0
         && !beforeSix.sidewayBox.sidewayConfirmed
         && beforeSix.sidewayBox.internalConfirmedSwingCount == 5
         && state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.confirmationType == SIDEWAY_NOISY_6_SWING
         && state.sidewayBox.internalConfirmedSwingCount == 6,
         "CASE5_07_NOISY_COUNT_RESET",
         "pending excluded; noisy fallback fires at post-completion six");
}

void TestCase5MultipleExpansionExtremes()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   engine.LabProbeClose(120.0, 1030);
   engine.LabProbeClose(125.0, 1031);
   engine.LabProbeClose(130.0, 1032);
   PriceStructureState provisional = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 130.0, 1032, 1035);
   PriceStructureState complete = engine.LabProbeState();
   Check(provisional.pendingCoreBox.active
         && provisional.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && !provisional.coreBox.coreHigh.confirmed
         && provisional.coreBox.generation == 1
         && complete.coreBox.valid
         && SamePrice(complete.coreBox.coreHigh.price, 130.0)
         && complete.coreBox.generation == 2,
         "CASE5_08_MULTIPLE_EXPANSION_EXTREMES",
         "unconfirmed extremes ignored; confirmed extreme promoted");
}

void TestCase5ConfirmedBreakIrreversible()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   const int failedBefore = EventCount(engine, CORE_BREAK_FAILED);
   engine.LabProbeClose(105.0, 1030);
   engine.LabProbeClose(100.0, 1031);
   PriceStructureState state = engine.LabProbeState();
   Check(state.pendingCoreBox.active
         && state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && SamePrice(state.coreBox.coreLow.price, 95.0)
         && state.coreBox.generation == 1
         && EventCount(engine, CORE_BREAK_FAILED) == failedBefore,
         "CASE5_09_CONFIRMED_BREAK_IRREVERSIBLE",
         "retracement cannot restore broken old Box");
}

void TestCase5FalseBreakPreConfirmation()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeClose(111.0, 1010);
   engine.LabProbeClose(105.0, 1011);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.valid
         && state.coreBox.lifecycle == CORE_BOX_COMPLETE
         && state.coreBox.generation == 1
         && SamePrice(state.coreBox.coreHigh.price, 110.0)
         && SamePrice(state.coreBox.coreLow.price, 90.0)
         && !state.pendingCoreBox.active
         && EventCount(engine, CORE_BREAK_FAILED) == 1,
         "CASE5_10_FALSE_BREAK_PRE_CONFIRMATION",
         "old False Break behavior preserved");
}

void TestCase5NextBreakAfterComplete()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   engine.LabProbeSwing(SWING_LOW, 100.0, 1040, 1041);
   engine.LabProbeClose(121.0, 1050);
   engine.LabProbeClose(122.0, 1051);
   PriceStructureState state = engine.LabProbeState();
   Check(state.pendingCoreBox.active
         && state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && state.coreBox.generation == 2
         && state.pendingCoreBox.targetGeneration == 3
         && SamePrice(state.coreBox.coreLow.price, 100.0)
         && !state.coreBox.coreHigh.confirmed
         && !state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.internalConfirmedSwingCount == 0,
         "CASE5_11_NEXT_BREAK_AFTER_COMPLETE",
         "lifecycle repeats without stale state");
}

void TestCase5SwingTypePreserved()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   PriceStructureState pending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   PriceStructureState complete = engine.LabProbeState();
   Check(pending.coreBox.coreLow.classification == STRUCT_HL
         && pending.pendingCoreBox.breakOrigin.classification == STRUCT_HL
         && complete.coreBox.coreLow.classification == STRUCT_HL
         && complete.coreBox.coreHigh.classification == STRUCT_HH,
         "CASE5_12_SWINGTYPE_PRESERVED",
         "topology classification unchanged by Core role");
}

void TestCase5GenerationAudit()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   PriceStructureState firstPending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   PriceStructureState firstComplete = engine.LabProbeState();
   engine.LabProbeSwing(SWING_LOW, 100.0, 1040, 1041);
   engine.LabProbeClose(121.0, 1050);
   engine.LabProbeClose(122.0, 1051);
   PriceStructureState secondPending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 130.0, 1060, 1061);
   PriceStructureState secondComplete = engine.LabProbeState();
   Check(firstPending.coreBox.generation == 1
         && firstPending.pendingCoreBox.targetGeneration == 2
         && firstComplete.coreBox.generation == 2
         && secondPending.coreBox.generation == 2
         && secondPending.pendingCoreBox.targetGeneration == 3
         && secondComplete.coreBox.generation == 3
         && EventCount(engine, CORE_BOX_TRANSITION_STARTED) == 2
         && EventCount(engine, CORE_BOX_CHANGED) == 2,
         "CASE5_13_GENERATION_AUDIT",
         "one increment per completed Box; none at transition");
}

void TestCase5EventDuplicateAudit()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   engine.LabProbeClose(105.0, 1030);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1040, 1041);
   Check(!HasDuplicateEventIdentities(engine)
         && EventCount(engine, CORE_BOX_TRANSITION_STARTED) == 1
         && EventCount(engine, CORE_BOX_CHANGED) == 1,
         "CASE5_14_EVENT_DUPLICATE_AUDIT",
         "zero duplicate semantic identities");
}

void TestCase5RendererPendingHigh()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   PriceStructureState state = engine.LabProbeState();
   CStructureDebugRenderer renderer;
   renderer.Configure(true, false);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   renderer.Update(state, swings, broken, boxes);
   const bool ok = ObjectFind(0, "JINPA_STRUCT_CORE_HIGH") < 0
                   && ObjectFind(0, "JINPA_STRUCT_CORE_LOW") >= 0
                   && CountOwnedObjects(
                        "JINPA_STRUCT_CORE_", OBJ_HLINE) == 1
                   && SamePrice(ObjectGetDouble(0,
                        "JINPA_STRUCT_CORE_LOW", OBJPROP_PRICE), 95.0);
   renderer.Destroy();
   Check(ok, "CASE5_15_RENDERER_PENDING_HIGH",
         "only promoted Low rendered; no fabricated High");
}

void TestCase5RendererPendingLow()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   PriceStructureState state = engine.LabProbeState();
   CStructureDebugRenderer renderer;
   renderer.Configure(true, false);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   renderer.Update(state, swings, broken, boxes);
   const bool ok = ObjectFind(0, "JINPA_STRUCT_CORE_HIGH") >= 0
                   && ObjectFind(0, "JINPA_STRUCT_CORE_LOW") < 0
                   && CountOwnedObjects(
                        "JINPA_STRUCT_CORE_", OBJ_HLINE) == 1
                   && SamePrice(ObjectGetDouble(0,
                        "JINPA_STRUCT_CORE_HIGH", OBJPROP_PRICE), 105.0);
   renderer.Destroy();
   Check(ok, "CASE5_16_RENDERER_PENDING_LOW",
         "only promoted High rendered; no fabricated Low");
}

void TestCase5DisplayOff()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   PriceStructureState before = engine.LabProbeState();
   CStructureDebugRenderer renderer;
   renderer.Configure(false, true);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   renderer.Update(before, swings, broken, boxes);
   PriceStructureState after = engine.LabProbeState();
   const bool noCoreObjects = CountOwnedObjectsAny(
      "JINPA_STRUCT_CORE_") == 0;
   renderer.Destroy();
   Check(noCoreObjects
         && before.coreBox.lifecycle == after.coreBox.lifecycle
         && before.coreBox.generation == after.coreBox.generation
         && before.pendingCoreBox.active == after.pendingCoreBox.active,
         "CASE5_17_DISPLAY_OFF",
         "zero Core visuals; transition state unchanged");
}

void BuildCase5OHLC(MqlRates &rates[])
{
   const double highs[] = {100.0, 96.0, 100.0, 112.0,
                           113.0, 120.0, 115.0, 114.0};
   const double lows[] = {99.0, 95.0, 99.0, 110.0,
                          111.0, 115.0, 109.0, 108.0};
   const double closes[] = {99.5, 95.5, 99.5, 111.0,
                            112.0, 118.0, 110.0, 109.0};
   ArrayResize(rates, 8);
   ArraySetAsSeries(rates, false);
   for(int index = 0; index < 8; index++)
   {
      ZeroMemory(rates[index]);
      rates[index].time = 1010 + index;
      rates[index].open = closes[index];
      rates[index].high = highs[index];
      rates[index].low = lows[index];
      rates[index].close = closes[index];
   }
}

void TestCase5BootstrapSequentialParity()
{
   CPriceStructureEngine bootstrap;
   CPriceStructureEngine sequential;
   bootstrap.Configure(1, 1, false, 0.0, 1, 100,
                       false, 0.0, 2, false, false);
   sequential.Configure(1, 1, false, 0.0, 1, 100,
                        false, 0.0, 2, false, false);
   bootstrap.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, true);
   sequential.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   MqlRates rates[];
   BuildCase5OHLC(rates);
   bootstrap.LabProbeProcessRates(rates, true);
   sequential.LabProbeProcessRates(rates, false);
   PriceStructureState state = sequential.LabProbeState();
   Check(SameCase5StateAndEvents(bootstrap, sequential)
         && state.coreBox.valid
         && state.coreBox.lifecycle == CORE_BOX_COMPLETE
         && state.coreBox.generation == 2
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 95.0),
         "CASE5_18_BOOTSTRAP_SEQUENTIAL",
         "same OHLC gives exact state, origin and event order");
}

void TestRepairA1CandidatePivotCompletes()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1005, 1006);
   engine.LabProbeClose(111.0, 1010);
   engine.LabProbeClose(112.0, 1011);
   PriceStructureState pending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1010, 1015);
   PriceStructureState complete = engine.LabProbeState();
   Check(pending.pendingCoreBox.candidateStartTime == 1010
         && pending.pendingCoreBox.confirmedBreakTime == 1011
         && complete.coreBox.valid
         && complete.coreBox.lifecycle == CORE_BOX_COMPLETE
         && SamePrice(complete.coreBox.coreHigh.price, 120.0)
         && SamePrice(complete.coreBox.coreLow.price, 95.0)
         && complete.coreBox.generation == 2,
         "REPAIR_A1_CANDIDATE_PIVOT_COMPLETES",
         "pivot at candidate start accepted after post-break confirmation");
}

void TestRepairA2OldPivotRejected()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1005, 1006);
   engine.LabProbeClose(111.0, 1010);
   engine.LabProbeClose(112.0, 1011);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1009, 1015);
   PriceStructureState state = engine.LabProbeState();
   Check(state.pendingCoreBox.active
         && state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && !state.coreBox.coreHigh.confirmed
         && state.coreBox.generation == 1
         && EventCount(engine, CORE_BOX_CHANGED) == 0,
         "REPAIR_A2_OLD_PIVOT_REJECTED",
         "late confirmation cannot admit pivot before candidate start");
}

void TestRepairA3CandidateResetCausalWindow()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1005, 1006);
   engine.LabProbeClose(111.0, 1010);
   engine.LabProbeClose(105.0, 1011);
   engine.LabProbeClose(112.0, 1020);
   engine.LabProbeClose(113.0, 1021);
   PriceStructureState pending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1020, 1025);
   PriceStructureState complete = engine.LabProbeState();
   Check(EventCount(engine, CORE_BREAK_FAILED) == 1
         && pending.pendingCoreBox.candidateStartTime == 1020
         && complete.coreBox.valid
         && SamePrice(complete.coreBox.coreHigh.price, 120.0)
         && complete.coreBox.generation == 2,
         "REPAIR_A3_CANDIDATE_RESET_WINDOW",
         "failed candidate A cannot leak into confirmed candidate B");
}

void TestRepairA4ConfirmedExtremeOnly()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1005, 1006);
   engine.LabProbeClose(111.0, 1010);
   engine.LabProbeClose(112.0, 1011);
   engine.LabProbeClose(120.0, 1012);
   engine.LabProbeClose(125.0, 1013);
   engine.LabProbeClose(130.0, 1014);
   PriceStructureState provisional = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 130.0, 1014, 1019);
   PriceStructureState complete = engine.LabProbeState();
   Check(provisional.pendingCoreBox.active
         && !provisional.coreBox.coreHigh.confirmed
         && provisional.coreBox.generation == 1
         && complete.coreBox.valid
         && SamePrice(complete.coreBox.coreHigh.price, 130.0)
         && complete.coreBox.generation == 2,
         "REPAIR_A4_CONFIRMED_EXTREME_ONLY",
         "provisional prices ignored; confirmed SwingPoint promoted");
}

void TestRepairA5BearMirror()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1005, 1006);
   engine.LabProbeClose(89.0, 1010);
   engine.LabProbeClose(88.0, 1011);
   engine.LabProbeSwing(SWING_LOW, 80.0, 1010, 1015);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.valid
         && state.coreBox.lifecycle == CORE_BOX_COMPLETE
         && SamePrice(state.coreBox.coreHigh.price, 105.0)
         && SamePrice(state.coreBox.coreLow.price, 80.0)
         && state.coreBox.generation == 2,
         "REPAIR_A5_BEAR_MIRROR",
         "bear expansion pivot at candidate start accepted symmetrically");
}

void BuildPendingHighRecovery(CPriceStructureEngine &engine)
{
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   engine.LabProbeSwing(SWING_HIGH, 108.0, 1022, 1023);
}

void BuildPendingLowRecovery(CPriceStructureEngine &engine)
{
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   engine.LabProbeSwing(SWING_LOW, 92.0, 1022, 1023);
}

void TestRepairB1PendingHighReversal()
{
   CPriceStructureEngine engine;
   BuildPendingHighRecovery(engine);
   engine.LabProbeClose(94.0, 1030);
   PriceStructureState candidate = engine.LabProbeState();
   engine.LabProbeClose(93.0, 1031);
   PriceStructureState state = engine.LabProbeState();
   StructureEvent events[];
   engine.LabProbeEventHistory(events);
   const int count = ArraySize(events);
   const bool order = count >= 3
      && events[count - 3].type == CORE_BREAK_CANDIDATE
      && events[count - 2].type == CYCLE_CHANGED
      && events[count - 1].type == CORE_BOX_TRANSITION_STARTED;
   Check(candidate.cycleState.breakCandidate
         && candidate.cycleState.breakDirection == CORE_BREAK_DOWN
         && candidate.cycleState.confirmationCount == 1
         && state.cycleState.cycle == MARKET_CYCLE_BEAR
         && state.coreBox.lifecycle == CORE_BOX_PENDING_LOW
         && SamePrice(state.coreBox.coreHigh.price, 108.0)
         && !state.coreBox.coreLow.confirmed
         && state.coreBox.generation == 1
         && state.pendingCoreBox.targetGeneration == 2
         && !state.sidewayBox.leg1Confirmed
         && !state.sidewayBox.leg2Confirmed
         && !state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.internalConfirmedSwingCount == 0
         && !HasDuplicateEventIdentities(engine)
         && order,
         "REPAIR_B1_PENDING_HIGH_REVERSAL",
         "authoritative Low breaks; Bull pending superseded by Bear pending");
}

void TestRepairB2PendingLowReversal()
{
   CPriceStructureEngine engine;
   BuildPendingLowRecovery(engine);
   engine.LabProbeClose(106.0, 1030);
   PriceStructureState candidate = engine.LabProbeState();
   engine.LabProbeClose(107.0, 1031);
   PriceStructureState state = engine.LabProbeState();
   StructureEvent events[];
   engine.LabProbeEventHistory(events);
   const int count = ArraySize(events);
   const bool order = count >= 3
      && events[count - 3].type == CORE_BREAK_CANDIDATE
      && events[count - 2].type == CYCLE_CHANGED
      && events[count - 1].type == CORE_BOX_TRANSITION_STARTED;
   Check(candidate.cycleState.breakCandidate
         && candidate.cycleState.breakDirection == CORE_BREAK_UP
         && candidate.cycleState.confirmationCount == 1
         && state.cycleState.cycle == MARKET_CYCLE_BULL
         && state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && SamePrice(state.coreBox.coreLow.price, 92.0)
         && !state.coreBox.coreHigh.confirmed
         && state.coreBox.generation == 1
         && state.pendingCoreBox.targetGeneration == 2
         && !state.sidewayBox.leg1Confirmed
         && !state.sidewayBox.leg2Confirmed
         && !state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.internalConfirmedSwingCount == 0
         && !HasDuplicateEventIdentities(engine)
         && order,
         "REPAIR_B2_PENDING_LOW_REVERSAL",
         "authoritative High breaks; Bear pending superseded by Bull pending");
}

void TestRepairB3PendingFalseBreaks()
{
   CPriceStructureEngine highPending;
   BuildPendingHighRecovery(highPending);
   highPending.LabProbeClose(94.0, 1030);
   highPending.LabProbeClose(96.0, 1031);
   PriceStructureState highState = highPending.LabProbeState();

   CPriceStructureEngine lowPending;
   BuildPendingLowRecovery(lowPending);
   lowPending.LabProbeClose(106.0, 1030);
   lowPending.LabProbeClose(104.0, 1031);
   PriceStructureState lowState = lowPending.LabProbeState();
   Check(highState.pendingCoreBox.active
         && highState.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && SamePrice(highState.coreBox.coreLow.price, 95.0)
         && !highState.cycleState.breakCandidate
         && EventCount(highPending, CORE_BREAK_FAILED) == 1
         && lowState.pendingCoreBox.active
         && lowState.coreBox.lifecycle == CORE_BOX_PENDING_LOW
         && SamePrice(lowState.coreBox.coreHigh.price, 105.0)
         && !lowState.cycleState.breakCandidate
         && EventCount(lowPending, CORE_BREAK_FAILED) == 1,
         "REPAIR_B3_PENDING_FALSE_BREAKS",
         "both pending directions reset candidate and retain authority");
}

void TestRepairB4NoPhantomGeneration()
{
   CPriceStructureEngine engine;
   BuildPendingHighRecovery(engine);
   engine.LabProbeClose(94.0, 1030);
   engine.LabProbeClose(93.0, 1031);
   PriceStructureState replacement = engine.LabProbeState();
   engine.LabProbeSwing(SWING_LOW, 80.0, 1040, 1045);
   PriceStructureState complete = engine.LabProbeState();
   Check(replacement.coreBox.generation == 1
         && replacement.pendingCoreBox.targetGeneration == 2
         && complete.coreBox.valid
         && complete.coreBox.generation == 2
         && EventCount(engine, CORE_BOX_TRANSITION_STARTED) == 2
         && EventCount(engine, CORE_BOX_CHANGED) == 1,
         "REPAIR_B4_NO_PHANTOM_GENERATION",
         "superseded incomplete G2 is not counted; completion is G2 once");
}

void TestRepairB5SupersessionStateAudit()
{
   CPriceStructureEngine engine;
   BuildPendingHighRecovery(engine);
   engine.LabProbeClose(94.0, 1030);
   engine.LabProbeClose(93.0, 1031);
   PriceStructureState state = engine.LabProbeState();
   Check(state.pendingCoreBox.active
         && state.pendingCoreBox.direction == CORE_BREAK_DOWN
         && SamePrice(state.pendingCoreBox.brokenBoundary, 95.0)
         && state.pendingCoreBox.candidateStartTime == 1030
         && state.pendingCoreBox.confirmedBreakTime == 1031
         && state.pendingCoreBox.breakOrigin.confirmed
         && state.pendingCoreBox.breakOrigin.type == SWING_HIGH
         && SamePrice(state.pendingCoreBox.breakOrigin.price, 108.0)
         && state.pendingCoreBox.oldCycle == MARKET_CYCLE_BULL
         && state.pendingCoreBox.newCycle == MARKET_CYCLE_BEAR
         && state.pendingCoreBox.targetGeneration == 2
         && !state.cycleState.breakCandidate
         && state.cycleState.breakDirection == CORE_BREAK_NONE
         && state.cycleState.breakCandidateTime == 0
         && state.cycleState.confirmationCount == 0
         && SamePrice(state.cycleState.breakLevel, 0.0)
         && SamePrice(state.cycleState.brokenCoreLevel, 0.0),
         "REPAIR_B5_SUPERSESSION_STATE_AUDIT",
         "one replacement authority; old pending and candidate state cleared");
}

void TestRepairB6RendererDirectionChange()
{
   CPriceStructureEngine engine;
   BuildPendingHighRecovery(engine);
   CStructureDebugRenderer renderer;
   renderer.Configure(true, false);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   PriceStructureState before = engine.LabProbeState();
   renderer.Update(before, swings, broken, boxes);
   const bool beforeOk = ObjectFind(0,
                            "JINPA_STRUCT_CORE_LOW") >= 0
                         && ObjectFind(0,
                            "JINPA_STRUCT_CORE_HIGH") < 0;
   engine.LabProbeClose(94.0, 1030);
   engine.LabProbeClose(93.0, 1031);
   PriceStructureState after = engine.LabProbeState();
   renderer.Update(after, swings, broken, boxes);
   const bool afterOk = ObjectFind(0,
                           "JINPA_STRUCT_CORE_HIGH") >= 0
                        && ObjectFind(0,
                           "JINPA_STRUCT_CORE_LOW") < 0
                        && CountOwnedObjects(
                           "JINPA_STRUCT_CORE_", OBJ_HLINE) == 1
                        && SamePrice(ObjectGetDouble(0,
                           "JINPA_STRUCT_CORE_HIGH",
                           OBJPROP_PRICE), 108.0);
   renderer.Destroy();
   Check(beforeOk && afterOk,
         "REPAIR_B6_RENDERER_DIRECTION_CHANGE",
         "obsolete Low removed; only replacement authoritative High remains");
}

int OnInit()
{
   TestBullContinuation();
   TestBearContinuation();
   TestBullToBear();
   TestBearToBull();
   TestCleanBullSideway();
   TestCleanBearSideway();
   TestNoisySixSwing();
   TestFalseBreakBeforeSideway();
   TestFalseBreakAfterSideway();
   TestBreakAfterSideway();
   TestInternalNoiseImmutability();
   TestStage210Causality();
   TestDualRendererContract();
   TestBootstrapParity();
   const int semanticPassed = g_passed;
   const int semanticFailed = g_failed;
   TestDefaultConfigurationGolden();
   TestWatchConfigurationAndValidation();
   TestSwingWindowSmoke(4, 4, "CONFIG_03_SWING_4_4_SMOKE");
   TestSwingWindowSmoke(3, 3, "CONFIG_04_SWING_3_3_SMOKE");
   TestATRBufferSmoke();
   TestATRPeriodSmoke();
   TestConfirmClosesSmoke();
   const int parameterPassed = g_passed - semanticPassed;
   const int parameterFailed = g_failed - semanticFailed;
   TestDisplayCombination(true, true, "DISPLAY_A_CORE_ON_SWINGS_ON");
   TestDisplayCombination(true, false, "DISPLAY_B_CORE_ON_SWINGS_OFF");
   TestDisplayCombination(false, true, "DISPLAY_C_CORE_OFF_SWINGS_ON");
   TestDisplayCombination(false, false, "DISPLAY_D_CORE_OFF_SWINGS_OFF");
   const int displayPassed = g_passed - semanticPassed - parameterPassed;
   const int displayFailed = g_failed - semanticFailed - parameterFailed;
   const int beforeCase5Passed = g_passed;
   const int beforeCase5Failed = g_failed;
   TestCase5BullContinuation();
   TestCase5BearContinuation();
   TestCase5BullToBear();
   TestCase5BearToBull();
   TestCase5NoEarlyLeg();
   TestCase5LegAfterCompletion();
   TestCase5NoisyCountReset();
   TestCase5MultipleExpansionExtremes();
   TestCase5ConfirmedBreakIrreversible();
   TestCase5FalseBreakPreConfirmation();
   TestCase5NextBreakAfterComplete();
   TestCase5SwingTypePreserved();
   TestCase5GenerationAudit();
   TestCase5EventDuplicateAudit();
   TestCase5RendererPendingHigh();
   TestCase5RendererPendingLow();
   TestCase5DisplayOff();
   TestCase5BootstrapSequentialParity();
   TestRepairA1CandidatePivotCompletes();
   TestRepairA2OldPivotRejected();
   TestRepairA3CandidateResetCausalWindow();
   TestRepairA4ConfirmedExtremeOnly();
   TestRepairA5BearMirror();
   TestRepairB1PendingHighReversal();
   TestRepairB2PendingLowReversal();
   TestRepairB3PendingFalseBreaks();
   TestRepairB4NoPhantomGeneration();
   TestRepairB5SupersessionStateAudit();
   TestRepairB6RendererDirectionChange();
   const int case5Passed = g_passed - beforeCase5Passed;
   const int case5Failed = g_failed - beforeCase5Failed;
   Print("[COREBOX_DEV_TEST][SECTIONS] semantic=", semanticPassed,
         "/", semanticFailed,
         " parameter=", parameterPassed, "/", parameterFailed,
         " display=", displayPassed, "/", displayFailed,
         " case5=", case5Passed, "/", case5Failed);
   Print("[COREBOX_DEV_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick()
{
   ExpertRemove();
}
