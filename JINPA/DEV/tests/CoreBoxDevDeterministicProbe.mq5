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
   renderer.Configure(true);
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
   const bool rendererOk = ObjectFind(0, highName) < 0
      && ObjectFind(0, lowName) >= 0
      && ownedLineCount == 1
      && SamePrice(ObjectGetDouble(0, lowName, OBJPROP_PRICE), 95.0);
   Check(before.coreBox.valid
         && SamePrice(unchanged.coreBox.coreHigh.price, 110.0)
         && SamePrice(unchanged.coreBox.coreLow.price, 90.0)
         && changed.coreBox.generation == 2
         && rendererOk,
         "TEST_13_DUAL_RENDERER", "Engine stays dual; chart shows protected Bull Low only");
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
   bool showSwings = false;
   watch.GetStructureConfiguration(left, right, atrPeriod, buffer, closes,
                                   showSwings);
   const bool defaults = left == 5 && right == 5 && atrPeriod == 14
                         && SamePrice(buffer, 0.10) && closes == 2
                         && showSwings;
   const bool accepted = watch.ConfigureStructure(4, 3, 10, 0.25, 3, false);
   watch.GetStructureConfiguration(left, right, atrPeriod, buffer, closes,
                                   showSwings);
   const bool routed = left == 4 && right == 3 && atrPeriod == 10
                       && SamePrice(buffer, 0.25) && closes == 3
                       && !showSwings;
   const bool invalidRejected =
      !watch.ConfigureStructure(0, 3, 10, 0.25, 3, true)
      && !watch.ConfigureStructure(3, 0, 10, 0.25, 3, true)
      && !watch.ConfigureStructure(3, 3, 0, 0.25, 3, true)
      && !watch.ConfigureStructure(3, 3, 10, -0.01, 3, true)
      && !watch.ConfigureStructure(3, 3, 10, 0.25, 0, true);
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

void TestDisplayCombination(const bool showSwings,
                            const bool repeatRefresh,
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
   renderer.Configure(showSwings);
   renderer.Destroy();
   renderer.Update(before, swings, broken, boxes);
   if(repeatRefresh)
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
   Check(coreLines == 1
          && ObjectFind(0, "JINPA_STRUCT_CORE_HIGH") < 0
          && ObjectFind(0, "JINPA_STRUCT_CORE_LOW") >= 0
          && swingLabels == (showSwings ? 4 : 0)
          && allCoreObjects >= 1 && allCoreObjects <= 2
          && allSwingObjects == (showSwings ? 4 : 0)
          && goldenState && stateParity,
         testName, "protected Core is automatic; swing option is independent");
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
   renderer.Configure(false);
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
   renderer.Configure(false);
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

void TestCase5AutomaticProtectedDisplay()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   PriceStructureState before = engine.LabProbeState();
   CStructureDebugRenderer renderer;
   renderer.Configure(true);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   renderer.Update(before, swings, broken, boxes);
   PriceStructureState after = engine.LabProbeState();
   const bool protectedCoreOnly = ObjectFind(0, "JINPA_STRUCT_CORE_LOW") >= 0
                                  && ObjectFind(0, "JINPA_STRUCT_CORE_HIGH") < 0
                                  && CountOwnedObjects(
                                     "JINPA_STRUCT_CORE_", OBJ_HLINE) == 1;
   renderer.Destroy();
   Check(protectedCoreOnly
         && before.coreBox.lifecycle == after.coreBox.lifecycle
         && before.coreBox.generation == after.coreBox.generation
         && before.pendingCoreBox.active == after.pendingCoreBox.active,
         "CASE5_17_AUTOMATIC_PROTECTED_DISPLAY",
         "protected Core stays visible; transition state unchanged");
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
   renderer.Configure(false);
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

void TestCase1HigherInternalHigh()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   PriceStructureState before = engine.LabProbeState();
   const int confirmationCount = EventCount(engine, SIDEWAY_CONFIRMED);
   engine.LabProbeSwing(SWING_HIGH, 107.0, 1050, 1051);
   PriceStructureState after = engine.LabProbeState();

   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   renderer.Update(before, swings, broken, boxes);
   renderer.Update(after, swings, broken, boxes);
   const string suffix = _Symbol + "_" + IntegerToString((int)_Period) + "_1000";
   const string highName = "JINPA_SIDEWAY_BOX_HIGH_" + suffix;
   const string lowName = "JINPA_SIDEWAY_BOX_LOW_" + suffix;
   const bool rendererOk = CountOwnedObjects("JINPA_SIDEWAY_BOX_HIGH_", OBJ_TREND) == 1
      && CountOwnedObjects("JINPA_SIDEWAY_BOX_LOW_", OBJ_TREND) == 1
      && SamePrice(ObjectGetDouble(0, highName, OBJPROP_PRICE, 0), 110.0)
      && SamePrice(ObjectGetDouble(0, lowName, OBJPROP_PRICE, 0), 90.0);
   renderer.Destroy();

   Check(before.sidewayBox.sidewayConfirmed
         && SamePrice(before.sidewayBox.boxHigh, 110.0)
         && SamePrice(before.sidewayBox.boxLow, 90.0)
         && SamePrice(after.sidewayBox.boxHigh, 110.0)
         && SamePrice(after.sidewayBox.boxLow, 90.0)
         && SamePrice(after.coreBox.coreHigh.price, 110.0)
         && SamePrice(after.coreBox.coreLow.price, 90.0)
         && after.coreBox.cycle == MARKET_CYCLE_BULL
         && EventCount(engine, SIDEWAY_CONFIRMED) == confirmationCount
         && rendererOk,
         "CASE1_A_HIGHER_INTERNAL_HIGH",
         "confirmed swing alone does not maintain the closed-bar range");
}

void TestCase1LowerInternalLow()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1050, 1051);
   PriceStructureState state = engine.LabProbeState();
   Check(SamePrice(state.sidewayBox.boxHigh, 110.0)
         && SamePrice(state.sidewayBox.boxLow, 90.0)
         && SamePrice(state.coreBox.coreHigh.price, 110.0)
         && SamePrice(state.coreBox.coreLow.price, 90.0)
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "CASE1_B_LOWER_INTERNAL_LOW",
         "confirmed swing alone does not maintain the closed-bar range");
}

void TestCase1AlternatingExpansion()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeSwing(SWING_HIGH, 107.0, 1050, 1051);
   engine.LabProbeSwing(SWING_LOW, 96.0, 1060, 1061);
   engine.LabProbeSwing(SWING_HIGH, 109.0, 1070, 1071);
   engine.LabProbeSwing(SWING_LOW, 91.0, 1080, 1081);
   PriceStructureState state = engine.LabProbeState();
   Check(SamePrice(state.sidewayBox.boxHigh, 110.0)
         && SamePrice(state.sidewayBox.boxLow, 90.0)
         && state.sidewayBox.lastUpdateTime == 1041
         && state.sidewayBox.sidewayConfirmed
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "CASE1_C_ALTERNATING_EXPANSION",
         "confirmed swings cannot compete with closed-bar maintenance");
}

void TestCase1NonExtremeUnchanged()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   const datetime updateTime = engine.LabProbeState().sidewayBox.lastUpdateTime;
   engine.LabProbeSwing(SWING_HIGH, 104.0, 1050, 1051);
   engine.LabProbeSwing(SWING_LOW, 99.0, 1060, 1061);
   PriceStructureState state = engine.LabProbeState();
   Check(SamePrice(state.sidewayBox.boxHigh, 110.0)
         && SamePrice(state.sidewayBox.boxLow, 90.0)
         && state.sidewayBox.lastUpdateTime == updateTime
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "CASE1_D_NON_EXTREME_UNCHANGED",
         "contained non-extremes do not move boundaries");
}

void TestCase1FalseBreakHigh()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeSwing(SWING_HIGH, 111.0, 1050, 1051);
   engine.LabProbeClose(111.0, 1060);
   engine.LabProbeClose(105.0, 1061);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.valid && state.coreBox.lifecycle == CORE_BOX_COMPLETE
         && SamePrice(state.coreBox.coreHigh.price, 110.0)
         && SamePrice(state.coreBox.coreLow.price, 90.0)
         && state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 110.0)
         && SamePrice(state.sidewayBox.boxLow, 90.0)
         && EventCount(engine, CORE_BREAK_FAILED) == 1
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "CASE1_E_FALSE_BREAK_HIGH",
         "upper excursion cannot escape Core or release latch");
}

void TestCase1FalseBreakLow()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeSwing(SWING_LOW, 89.0, 1050, 1051);
   engine.LabProbeClose(89.0, 1060);
   engine.LabProbeClose(95.0, 1061);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.valid && state.coreBox.lifecycle == CORE_BOX_COMPLETE
         && SamePrice(state.coreBox.coreHigh.price, 110.0)
         && SamePrice(state.coreBox.coreLow.price, 90.0)
         && state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 110.0)
         && SamePrice(state.sidewayBox.boxLow, 90.0)
         && EventCount(engine, CORE_BREAK_FAILED) == 1
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "CASE1_F_FALSE_BREAK_LOW",
         "lower excursion cannot escape Core or release latch");
}

void TestCase1ConfirmedBreakReset()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeSwing(SWING_HIGH, 109.0, 1050, 1051);
   engine.LabProbeSwing(SWING_LOW, 92.0, 1060, 1061);
   engine.LabProbeClose(111.0, 1070);
   engine.LabProbeClose(112.0, 1071);
   PriceStructureState pending = engine.LabProbeState();
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1080, 1081);
   PriceStructureState complete = engine.LabProbeState();
   Check(pending.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && !pending.sidewayBox.sidewayConfirmed
         && SamePrice(pending.sidewayBox.boxHigh, 0.0)
         && SamePrice(pending.sidewayBox.boxLow, 0.0)
         && complete.coreBox.valid && complete.coreBox.generation == 2
         && !complete.sidewayBox.sidewayConfirmed
         && SamePrice(complete.sidewayBox.boxHigh, 0.0)
         && SamePrice(complete.sidewayBox.boxLow, 0.0),
         "CASE1_G_CONFIRMED_BREAK_RESET",
         "dynamic range ends at confirmed break and cannot leak");
}

void TestCase1PendingHighDisabled()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeClose(111.0, 1050);
   engine.LabProbeClose(112.0, 1051);
   engine.LabProbeSwing(SWING_HIGH, 108.0, 1060, 1061);
   PriceStructureState state = engine.LabProbeState();
   Check(state.pendingCoreBox.active
         && state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && !state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 0.0)
         && SamePrice(state.sidewayBox.boxLow, 0.0)
         && state.sidewayBox.internalConfirmedSwingCount == 0,
         "FIXED_C1_L_PENDING_HIGH_DISABLED",
         "pending High cannot extend the frozen Sideway");
}

void TestCase1PendingLowDisabled()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCleanBull(engine);
   engine.LabProbeClose(89.0, 1050);
   engine.LabProbeClose(88.0, 1051);
   engine.LabProbeSwing(SWING_LOW, 92.0, 1060, 1061);
   PriceStructureState state = engine.LabProbeState();
   Check(state.pendingCoreBox.active
         && state.coreBox.lifecycle == CORE_BOX_PENDING_LOW
         && !state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 0.0)
         && SamePrice(state.sidewayBox.boxLow, 0.0)
         && state.sidewayBox.internalConfirmedSwingCount == 0,
         "FIXED_C1_M_PENDING_LOW_DISABLED",
         "pending Low cannot extend the frozen Sideway");
}

void FeedCase1Parity(CPriceStructureEngine &engine)
{
   FeedCleanBull(engine);
   engine.LabProbeSwing(SWING_HIGH, 107.0, 1050, 1051);
   engine.LabProbeSwing(SWING_LOW, 96.0, 1060, 1061);
   engine.LabProbeSwing(SWING_HIGH, 109.0, 1070, 1071);
   engine.LabProbeSwing(SWING_LOW, 92.0, 1080, 1081);
}

void TestCase1BootstrapSequentialParity()
{
   CPriceStructureEngine bootstrap;
   CPriceStructureEngine sequential;
   bootstrap.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, true);
   sequential.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedCase1Parity(bootstrap);
   FeedCase1Parity(sequential);
   PriceStructureState left = bootstrap.LabProbeState();
   PriceStructureState right = sequential.LabProbeState();
   Check(SamePrice(left.sidewayBox.boxHigh, right.sidewayBox.boxHigh)
         && SamePrice(left.sidewayBox.boxLow, right.sidewayBox.boxLow)
         && left.sidewayBox.boxHighTime == right.sidewayBox.boxHighTime
         && left.sidewayBox.boxLowTime == right.sidewayBox.boxLowTime
         && left.sidewayBox.lastUpdateTime == right.sidewayBox.lastUpdateTime
         && left.sidewayBox.sidewayConfirmed
         && right.sidewayBox.sidewayConfirmed
         && EventCount(bootstrap, SIDEWAY_CONFIRMED) == 1
         && EventCount(sequential, SIDEWAY_CONFIRMED) == 1
         && !HasDuplicateEventIdentities(bootstrap)
         && !HasDuplicateEventIdentities(sequential),
         "CASE1_J_BOOTSTRAP_SEQUENTIAL_PARITY",
         "final dynamic range and event uniqueness match");
}

void BuildClosedBarSideway(CPriceStructureEngine &engine,
                           const bool bootstrap = false)
{
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 120.0, 100.0, 1000,
                             bootstrap);
   engine.LabProbeSwing(SWING_LOW, 110.0, 1010, 1011);
   engine.LabProbeSwing(SWING_HIGH, 116.0, 1020, 1021);
   engine.LabProbeSwing(SWING_LOW, 108.0, 1030, 1031);
   engine.LabProbeSwing(SWING_HIGH, 115.0, 1040, 1041);
}

void TestClosedBarHighExpansion()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   PriceStructureState initial = engine.LabProbeState();
   engine.LabProbeClosedBar(117.0, 109.0, 115.0, 1050);
   PriceStructureState first = engine.LabProbeState();
   engine.LabProbeClosedBar(118.0, 110.0, 116.0, 1060);
   PriceStructureState second = engine.LabProbeState();
   Check(SamePrice(initial.sidewayBox.boxHigh, 120.0)
         && SamePrice(initial.sidewayBox.boxLow, 100.0)
         && SamePrice(first.sidewayBox.boxHigh, 120.0)
         && SamePrice(first.sidewayBox.boxLow, 100.0)
         && first.sidewayBox.lastUpdateTime == 1050
         && SamePrice(second.sidewayBox.boxHigh, 120.0)
         && SamePrice(second.sidewayBox.boxLow, 100.0)
         && second.sidewayBox.lastUpdateTime == 1060
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "FIXED_C1_A_INITIAL_LEVELS",
         "confirmation captures Core levels; closed bars extend time only");
}

void TestClosedBarLowExpansion()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(115.0, 107.0, 110.0, 1050);
   PriceStructureState first = engine.LabProbeState();
   engine.LabProbeClosedBar(114.0, 105.0, 109.0, 1060);
   PriceStructureState second = engine.LabProbeState();
   Check(SamePrice(first.sidewayBox.boxHigh, 120.0)
         && SamePrice(first.sidewayBox.boxLow, 100.0)
         && first.sidewayBox.lastUpdateTime == 1050
         && SamePrice(second.sidewayBox.boxHigh, 120.0)
         && SamePrice(second.sidewayBox.boxLow, 100.0)
         && second.sidewayBox.lastUpdateTime == 1060,
         "FIXED_C1_B_CLOSED_BAR_TIME_ONLY",
         "closed bars advance right endpoint without vertical movement");
}

void TestClosedBarBothSides()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(118.0, 106.0, 112.0, 1050);
   PriceStructureState state = engine.LabProbeState();
   Check(SamePrice(state.sidewayBox.boxHigh, 120.0)
         && SamePrice(state.sidewayBox.boxLow, 100.0)
         && state.sidewayBox.lastUpdateTime == 1050,
         "FIXED_C1_C_INTERNAL_HIGH_FIXED",
         "internal bar High cannot move SidewayHigh");
}

void TestClosedBarNoExtreme()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(118.0, 106.0, 112.0, 1050);
   engine.LabProbeClosedBar(117.0, 107.0, 112.0, 1060);
   PriceStructureState state = engine.LabProbeState();
   Check(SamePrice(state.sidewayBox.boxHigh, 120.0)
         && SamePrice(state.sidewayBox.boxLow, 100.0)
         && state.sidewayBox.lastUpdateTime == 1060,
         "FIXED_C1_D_INTERNAL_LOW_FIXED",
         "internal bar Low cannot move SidewayLow; time still advances");
}

void TestClosedBarNoSwingRequired()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   PriceStructureState initial = engine.LabProbeState();
   engine.LabProbeClosedBar(117.0, 109.0, 115.0, 1050);
   PriceStructureState first = engine.LabProbeState();
   engine.LabProbeClosedBar(118.5, 110.0, 116.0, 1060);
   PriceStructureState second = engine.LabProbeState();
   engine.LabProbeClosedBar(117.0, 106.0, 111.0, 1070);
   PriceStructureState third = engine.LabProbeState();
   engine.LabProbeClosedBar(119.0, 108.0, 114.0, 1080);
   PriceStructureState fourth = engine.LabProbeState();
   engine.LabProbeClosedBar(116.0, 105.0, 110.0, 1090);
   PriceStructureState fifth = engine.LabProbeState();
   Check(SamePrice(first.sidewayBox.boxHigh, 120.0)
         && SamePrice(second.sidewayBox.boxHigh, 120.0)
         && SamePrice(third.sidewayBox.boxHigh, 120.0)
         && SamePrice(fourth.sidewayBox.boxHigh, 120.0)
         && SamePrice(fifth.sidewayBox.boxHigh, 120.0)
         && SamePrice(fifth.sidewayBox.boxLow, 100.0)
         && first.sidewayBox.lastUpdateTime == 1050
         && second.sidewayBox.lastUpdateTime == 1060
         && third.sidewayBox.lastUpdateTime == 1070
         && fourth.sidewayBox.lastUpdateTime == 1080
         && fifth.sidewayBox.lastUpdateTime == 1090
         && fifth.lastSwingHigh.time == initial.lastSwingHigh.time
         && fifth.lastSwingLow.time == initial.lastSwingLow.time
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "FIXED_C1_F_MULTIPLE_CLOSED_BARS",
         "five-bar delay absent: right edge advances without new swing");
}

void TestClosedBarFormingIgnored()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   PriceStructureState whileForming = engine.LabProbeState();
   engine.LabProbeClosedBar(119.0, 109.0, 116.0, 1050);
   PriceStructureState afterClose = engine.LabProbeState();
   Check(SamePrice(whileForming.sidewayBox.boxHigh, 120.0)
         && whileForming.sidewayBox.lastUpdateTime == 1041
         && SamePrice(afterClose.sidewayBox.boxHigh, 120.0)
         && SamePrice(afterClose.sidewayBox.boxLow, 100.0)
         && afterClose.sidewayBox.lastUpdateTime == 1050,
         "FIXED_C1_E_FORMING_IGNORED",
         "right endpoint waits until candle enters closed-bar pipeline");
}

void TestClosedBarFirstBreakCandidate()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(121.0, 109.0, 121.0, 1050);
   PriceStructureState state = engine.LabProbeState();
   Check(SamePrice(state.sidewayBox.boxHigh, 120.0)
         && SamePrice(state.sidewayBox.boxLow, 100.0)
         && state.sidewayBox.lastUpdateTime == 1050
         && state.sidewayBox.active
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 100.0)
         && state.coreBox.cycle == MARKET_CYCLE_BULL
         && state.cycleState.breakCandidate,
         "FIXED_C1_G_FIRST_BREAK_CANDIDATE",
         "first qualifying close keeps Sideway active and advances its endpoint");
}

void TestClosedBarCoreLowClamp()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(115.0, 98.0, 101.0, 1050);
   PriceStructureState state = engine.LabProbeState();
   Check(SamePrice(state.sidewayBox.boxHigh, 120.0)
         && SamePrice(state.sidewayBox.boxLow, 100.0)
         && state.sidewayBox.lastUpdateTime == 1050
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 100.0)
         && state.coreBox.cycle == MARKET_CYCLE_BULL
         && !state.cycleState.breakCandidate,
         "FIXED_C1_D_LOW_EXCURSION_FIXED",
         "price excursion cannot move fixed SidewayLow");
}

void TestClosedBarFalseBreak()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(121.0, 109.0, 121.0, 1050);
   PriceStructureState candidate = engine.LabProbeState();
   engine.LabProbeClosedBar(119.0, 107.0, 119.0, 1060);
   PriceStructureState state = engine.LabProbeState();
   Check(candidate.cycleState.breakCandidate
         && state.coreBox.valid && state.coreBox.lifecycle == CORE_BOX_COMPLETE
         && SamePrice(state.coreBox.coreHigh.price, 120.0)
         && SamePrice(state.coreBox.coreLow.price, 100.0)
         && state.coreBox.cycle == MARKET_CYCLE_BULL
         && state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 120.0)
         && SamePrice(state.sidewayBox.boxLow, 100.0)
         && state.sidewayBox.lastUpdateTime == 1060
         && EventCount(engine, CORE_BREAK_FAILED) == 1
         && EventCount(engine, SIDEWAY_CONFIRMED) == 1,
         "FIXED_C1_H_FALSE_BREAK",
         "candidate reclaim retains fixed levels and continuing endpoint");
}

void TestClosedBarConfirmedBreak()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(121.0, 109.0, 121.0, 1050);
   engine.LabProbeClosedBar(122.0, 110.0, 122.0, 1060);
   PriceStructureState state = engine.LabProbeState();
   SidewayBoxRecord before[];
   engine.LabProbeSidewayHistory(before);
   engine.LabProbeClosedBar(119.0, 101.0, 110.0, 1070);
   SidewayBoxRecord after[];
   engine.LabProbeSidewayHistory(after);
   Check(state.pendingCoreBox.active
         && state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && !state.sidewayBox.active
         && !state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 0.0)
         && SamePrice(state.sidewayBox.boxLow, 0.0)
         && ArraySize(before) == 1 && ArraySize(after) == 1
         && SamePrice(after[0].boxHigh, 120.0)
         && SamePrice(after[0].boxLow, 100.0)
         && after[0].boxStartTime == 1000
         && after[0].boxEndTime == 1060
         && after[0].endStatus == SIDEWAY_BOX_BROKEN,
         "FIXED_C1_I_CONFIRMED_HIGH_BREAK",
         "old pair freezes at confirming candle and never extends again");
}

void TestClosedBarPendingHigh()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(121.0, 109.0, 121.0, 1050);
   engine.LabProbeClosedBar(122.0, 110.0, 122.0, 1060);
   engine.LabProbeClosedBar(119.0, 101.0, 110.0, 1070);
   PriceStructureState state = engine.LabProbeState();
   Check(state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && !state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 0.0)
         && SamePrice(state.sidewayBox.boxLow, 0.0),
         "FIXED_C1_L_PENDING_HIGH",
         "closed bars cannot extend Sideway while High is pending");
}

void TestClosedBarPendingLow()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(115.0, 99.0, 99.0, 1050);
   engine.LabProbeClosedBar(114.0, 98.0, 98.0, 1060);
   SidewayBoxRecord before[];
   engine.LabProbeSidewayHistory(before);
   engine.LabProbeClosedBar(119.0, 101.0, 110.0, 1070);
   PriceStructureState state = engine.LabProbeState();
   SidewayBoxRecord after[];
   engine.LabProbeSidewayHistory(after);
   Check(state.coreBox.lifecycle == CORE_BOX_PENDING_LOW
         && !state.sidewayBox.sidewayConfirmed
         && SamePrice(state.sidewayBox.boxHigh, 0.0)
         && SamePrice(state.sidewayBox.boxLow, 0.0)
         && ArraySize(before) == 1 && ArraySize(after) == 1
         && SamePrice(after[0].boxHigh, 120.0)
         && SamePrice(after[0].boxLow, 100.0)
         && after[0].boxEndTime == 1060,
         "FIXED_C1_J_CONFIRMED_LOW_BREAK",
         "lower break freezes mirror lifecycle at confirming candle");
}

void FeedClosedBarParity(CPriceStructureEngine &engine)
{
   engine.LabProbeClosedBar(117.0, 109.0, 115.0, 1050);
   engine.LabProbeClosedBar(118.5, 107.0, 114.0, 1060);
   engine.LabProbeClosedBar(117.0, 106.0, 112.0, 1070);
}

void TestClosedBarBootstrapSequentialParity()
{
   CPriceStructureEngine bootstrap;
   CPriceStructureEngine sequential;
   BuildClosedBarSideway(bootstrap, true);
   BuildClosedBarSideway(sequential, false);
   FeedClosedBarParity(bootstrap);
   FeedClosedBarParity(sequential);
   PriceStructureState left = bootstrap.LabProbeState();
   PriceStructureState right = sequential.LabProbeState();
   Check(SamePrice(left.sidewayBox.boxHigh, 120.0)
         && SamePrice(left.sidewayBox.boxLow, 100.0)
         && SamePrice(left.sidewayBox.boxHigh, right.sidewayBox.boxHigh)
         && SamePrice(left.sidewayBox.boxLow, right.sidewayBox.boxLow)
         && left.sidewayBox.boxHighTime == right.sidewayBox.boxHighTime
         && left.sidewayBox.boxLowTime == right.sidewayBox.boxLowTime
         && left.sidewayBox.lastUpdateTime == right.sidewayBox.lastUpdateTime
         && left.sidewayBox.sidewayConfirmed == right.sidewayBox.sidewayConfirmed
         && SamePrice(left.coreBox.coreHigh.price, right.coreBox.coreHigh.price)
         && SamePrice(left.coreBox.coreLow.price, right.coreBox.coreLow.price)
         && left.coreBox.cycle == right.coreBox.cycle,
         "FIXED_C1_N_BOOTSTRAP_SEQUENTIAL",
         "fixed levels, start/right time, latch and Core state match");
}

void TestFixedSidewayNewLifecycleIdentity()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(121.0, 109.0, 121.0, 1050);
   engine.LabProbeClosedBar(122.0, 110.0, 122.0, 1060);
   engine.LabProbeSwing(SWING_HIGH, 130.0, 1080, 1081);
   engine.LabProbeSwing(SWING_LOW, 115.0, 1090, 1091);
   engine.LabProbeSwing(SWING_HIGH, 125.0, 1100, 1101);
   engine.LabProbeSwing(SWING_LOW, 112.0, 1110, 1111);
   engine.LabProbeSwing(SWING_HIGH, 124.0, 1120, 1121);
   PriceStructureState state = engine.LabProbeState();
   SidewayBoxRecord history[];
   engine.LabProbeSidewayHistory(history);

   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   renderer.Update(state, swings, broken, history);
   const bool identityOk = CountOwnedObjects("JINPA_SIDEWAY_BOX_HIGH_",
                                             OBJ_TREND) == 2
      && CountOwnedObjects("JINPA_SIDEWAY_BOX_LOW_", OBJ_TREND) == 2;
   renderer.Destroy();

   Check(ArraySize(history) == 1
         && history[0].boxStartTime == 1000
         && history[0].boxEndTime == 1060
         && SamePrice(history[0].boxHigh, 120.0)
         && SamePrice(history[0].boxLow, 100.0)
         && state.sidewayBox.sidewayConfirmed
         && state.sidewayBox.boxStartTime == 1081
         && SamePrice(state.sidewayBox.boxHigh, 130.0)
         && SamePrice(state.sidewayBox.boxLow, 108.0)
         && identityOk,
         "FIXED_C1_K_NEW_LIFECYCLE_IDENTITY",
         "old frozen pair and new active pair use distinct start-time identity");
}

void BuildLeftEdgeState(PriceStructureState &state,
                        const datetime highTime,
                        const datetime lowTime,
                        const datetime lifecycleTime,
                        const datetime confirmationTime,
                        const datetime rightTime)
{
   ResetPriceStructureState(state);
   state.initialized = true;
   state.sidewayBox.active = true;
   state.sidewayBox.sidewayConfirmed = true;
   state.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   state.sidewayBox.boxHigh = 120.0;
   state.sidewayBox.boxHighTime = highTime;
   state.sidewayBox.boxLow = 100.0;
   state.sidewayBox.boxLowTime = lowTime;
   state.sidewayBox.boxStartTime = lifecycleTime;
   state.sidewayBox.confirmedTime = confirmationTime;
   state.sidewayBox.lastUpdateTime = rightTime;
}

string LeftEdgeObjectName(const bool isHigh,
                          const datetime lifecycleTime)
{
   return (isHigh ? "JINPA_SIDEWAY_BOX_HIGH_"
                  : "JINPA_SIDEWAY_BOX_LOW_")
          + _Symbol + "_" + IntegerToString((int)_Period) + "_"
          + IntegerToString((long)lifecycleTime);
}

datetime ObjectPointTime(const string name, const int point)
{
   return (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, point);
}

void RenderLeftEdgeState(const PriceStructureState &state,
                         CStructureDebugRenderer &renderer)
{
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   SidewayBoxRecord history[];
   renderer.Update(state, swings, broken, history);
}

void TestLeftEdgeAStateUsesOwnCoreTimes()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   PriceStructureState state = engine.LabProbeState();
   Check(state.sidewayBox.boxHighTime == 998
         && state.sidewayBox.boxLowTime == 999
         && state.sidewayBox.boxHighTime != state.sidewayBox.boxLowTime
         && SamePrice(state.sidewayBox.boxHigh, 120.0)
         && SamePrice(state.sidewayBox.boxLow, 100.0),
         "LEFT_EDGE_A_OWN_CORE_TIMES",
         "confirmed Sideway retains distinct authoritative Core swing times");
}

void TestLeftEdgeBHighEarlierThanLow()
{
   PriceStructureState state;
   BuildLeftEdgeState(state, 800, 900, 1000, 1500, 2000);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   RenderLeftEdgeState(state, renderer);
   const string highName = LeftEdgeObjectName(true, 1000);
   const string lowName = LeftEdgeObjectName(false, 1000);
   Check(ObjectPointTime(highName, 0) == 800
         && ObjectPointTime(lowName, 0) == 900
         && ObjectPointTime(highName, 0) < ObjectPointTime(lowName, 0),
         "LEFT_EDGE_B_HIGH_EARLIER",
         "High geometry begins at earlier CoreHigh swing");
   renderer.Destroy();
}

void TestLeftEdgeCLowEarlierThanHigh()
{
   PriceStructureState state;
   BuildLeftEdgeState(state, 900, 800, 1000, 1500, 2000);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   RenderLeftEdgeState(state, renderer);
   const string highName = LeftEdgeObjectName(true, 1000);
   const string lowName = LeftEdgeObjectName(false, 1000);
   Check(ObjectPointTime(highName, 0) == 900
         && ObjectPointTime(lowName, 0) == 800
         && ObjectPointTime(lowName, 0) < ObjectPointTime(highName, 0),
         "LEFT_EDGE_C_LOW_EARLIER",
         "Low geometry begins at earlier CoreLow swing");
   renderer.Destroy();
}

void TestLeftEdgeDLateConfirmationDoesNotMoveLeft()
{
   PriceStructureState state;
   BuildLeftEdgeState(state, 700, 800, 1000, 1900, 2000);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   RenderLeftEdgeState(state, renderer);
   const string highName = LeftEdgeObjectName(true, 1000);
   const string lowName = LeftEdgeObjectName(false, 1000);
   Check(ObjectPointTime(highName, 0) == 700
         && ObjectPointTime(lowName, 0) == 800
         && ObjectPointTime(highName, 0) != state.sidewayBox.confirmedTime
         && ObjectPointTime(lowName, 0) != state.sidewayBox.confirmedTime,
         "LEFT_EDGE_D_CONFIRMATION_INDEPENDENT",
         "late Sideway confirmation does not move either left endpoint");
   renderer.Destroy();
}

void TestLeftEdgeELifecycleIdentitySeparated()
{
   PriceStructureState state;
   BuildLeftEdgeState(state, 800, 900, 1000, 1500, 2000);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   RenderLeftEdgeState(state, renderer);
   const string highName = LeftEdgeObjectName(true, 1000);
   const string lowName = LeftEdgeObjectName(false, 1000);
   Check(ObjectFind(0, highName) >= 0 && ObjectFind(0, lowName) >= 0
         && ObjectPointTime(highName, 0) != 1000
         && ObjectPointTime(lowName, 0) != 1000
         && CountOwnedObjects("JINPA_SIDEWAY_BOX_HIGH_", OBJ_TREND) == 1
         && CountOwnedObjects("JINPA_SIDEWAY_BOX_LOW_", OBJ_TREND) == 1,
         "LEFT_EDGE_E_IDENTITY_GEOMETRY_SEPARATED",
         "boxStartTime names the lifecycle but does not define line geometry");
   renderer.Destroy();
}

void TestLeftEdgeFRightUpdatesPreserveLeft()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   RenderLeftEdgeState(engine.LabProbeState(), renderer);
   for(int index = 0; index < 5; index++)
   {
      const datetime barTime = 1050 + index * 10;
      engine.LabProbeClosedBar(118.0, 105.0, 112.0, barTime);
      RenderLeftEdgeState(engine.LabProbeState(), renderer);
   }
   const string highName = LeftEdgeObjectName(true, 1000);
   const string lowName = LeftEdgeObjectName(false, 1000);
   Check(ObjectPointTime(highName, 0) == 998
         && ObjectPointTime(lowName, 0) == 999
         && ObjectPointTime(highName, 1) == 1090
         && ObjectPointTime(lowName, 1) == 1090,
         "LEFT_EDGE_F_RIGHT_UPDATES",
         "five closed bars move point 1 only; both point 0 times remain fixed");
   renderer.Destroy();
}

void TestLeftEdgeGConfirmedBreakPreservesGeometry()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(121.0, 109.0, 121.0, 1050);
   engine.LabProbeClosedBar(122.0, 110.0, 122.0, 1060);
   engine.LabProbeClosedBar(119.0, 101.0, 110.0, 1070);
   SidewayBoxRecord history[];
   engine.LabProbeSidewayHistory(history);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   renderer.Update(engine.LabProbeState(), swings, broken, history);
   const string highName = LeftEdgeObjectName(true, 1000);
   const string lowName = LeftEdgeObjectName(false, 1000);
   Check(ArraySize(history) == 1
         && history[0].boxHighTime == 998
         && history[0].boxLowTime == 999
         && ObjectPointTime(highName, 0) == 998
         && ObjectPointTime(lowName, 0) == 999
         && ObjectPointTime(highName, 1) == 1060
         && ObjectPointTime(lowName, 1) == 1060,
         "LEFT_EDGE_G_BREAK_FREEZE",
         "archive preserves both Core swing starts and common frozen endpoint");
   renderer.Destroy();
}

void TestLeftEdgeHNewLifecycleIndependent()
{
   CPriceStructureEngine engine;
   BuildClosedBarSideway(engine);
   engine.LabProbeClosedBar(121.0, 109.0, 121.0, 1050);
   engine.LabProbeClosedBar(122.0, 110.0, 122.0, 1060);
   engine.LabProbeSwing(SWING_HIGH, 130.0, 1080, 1081);
   engine.LabProbeSwing(SWING_LOW, 115.0, 1090, 1091);
   engine.LabProbeSwing(SWING_HIGH, 125.0, 1100, 1101);
   engine.LabProbeSwing(SWING_LOW, 112.0, 1110, 1111);
   engine.LabProbeSwing(SWING_HIGH, 124.0, 1120, 1121);
   SidewayBoxRecord history[];
   engine.LabProbeSidewayHistory(history);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SwingPoint swings[];
   BrokenCoreRecord broken[];
   renderer.Update(engine.LabProbeState(), swings, broken, history);
   const string oldHigh = LeftEdgeObjectName(true, 1000);
   const string oldLow = LeftEdgeObjectName(false, 1000);
   const string newHigh = LeftEdgeObjectName(true, 1081);
   const string newLow = LeftEdgeObjectName(false, 1081);
   Check(ObjectPointTime(oldHigh, 0) == 998
         && ObjectPointTime(oldLow, 0) == 999
         && ObjectPointTime(oldHigh, 1) == 1060
         && ObjectPointTime(oldLow, 1) == 1060
         && ObjectPointTime(newHigh, 0) == 1080
         && ObjectPointTime(newLow, 0) == 1030
         && CountOwnedObjects("JINPA_SIDEWAY_BOX_HIGH_", OBJ_TREND) == 2
         && CountOwnedObjects("JINPA_SIDEWAY_BOX_LOW_", OBJ_TREND) == 2,
         "LEFT_EDGE_H_NEW_LIFECYCLE",
         "new lifecycle uses new Core swing geometry without moving history");
   renderer.Destroy();
}

void TestLeftEdgeIBootstrapSequentialParity()
{
   CPriceStructureEngine bootstrap;
   CPriceStructureEngine sequential;
   BuildClosedBarSideway(bootstrap, true);
   BuildClosedBarSideway(sequential, false);
   FeedClosedBarParity(bootstrap);
   FeedClosedBarParity(sequential);
   PriceStructureState left = bootstrap.LabProbeState();
   PriceStructureState right = sequential.LabProbeState();
   Check(SamePrice(left.sidewayBox.boxHigh, right.sidewayBox.boxHigh)
         && SamePrice(left.sidewayBox.boxLow, right.sidewayBox.boxLow)
         && left.sidewayBox.boxHighTime == right.sidewayBox.boxHighTime
         && left.sidewayBox.boxLowTime == right.sidewayBox.boxLowTime
         && left.sidewayBox.boxStartTime == right.sidewayBox.boxStartTime
         && left.sidewayBox.lastUpdateTime == right.sidewayBox.lastUpdateTime
         && left.sidewayBox.active == right.sidewayBox.active
         && left.sidewayBox.sidewayConfirmed
            == right.sidewayBox.sidewayConfirmed,
         "LEFT_EDGE_I_BOOTSTRAP_SEQUENTIAL",
         "prices, separate starts, right time and lifecycle status match");
}

string BrokenCoreObjectNameForTest(const BrokenCoreRecord &record)
{
   return "JINPA_BROKEN_CORE_" + record.symbol + "_"
          + IntegerToString((int)record.timeframe) + "_"
          + IntegerToString((long)record.originTime) + "_"
          + IntegerToString((long)record.confirmationBreakTime);
}

void FeedTwoCycleReversals(CPriceStructureEngine &engine)
{
   BeginDownTransition(engine);
   engine.LabProbeSwing(SWING_LOW, 80.0, 1030, 1031);
   BeginUpTransition(engine, 95.0, 1040);
}

void TestBrokenCoreABullToBear()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   Check(ArraySize(records) == 1
         && records[0].coreType == CORE_SWING_LOW
         && SamePrice(records[0].price, 90.0)
         && records[0].originTime == 999
         && records[0].confirmationBreakTime == 1021
         && records[0].oldCycle == MARKET_CYCLE_BULL
         && records[0].newCycle == MARKET_CYCLE_BEAR,
         "BROKEN_CORE_A_BULL_TO_BEAR",
         "old authoritative CoreLow archived at confirmed reversal");
}

void TestBrokenCoreBBearToBull()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   Check(ArraySize(records) == 1
         && records[0].coreType == CORE_SWING_HIGH
         && SamePrice(records[0].price, 110.0)
         && records[0].originTime == 998
         && records[0].confirmationBreakTime == 1021
         && records[0].oldCycle == MARKET_CYCLE_BEAR
         && records[0].newCycle == MARKET_CYCLE_BULL,
         "BROKEN_CORE_B_BEAR_TO_BULL",
         "old authoritative CoreHigh archived at confirmed reversal");
}

void TestBrokenCoreCFirstCandidate()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeClose(89.0, 1020);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   Check(ArraySize(records) == 0
         && engine.LabProbeState().cycleState.breakCandidate,
         "BROKEN_CORE_C_FIRST_CANDIDATE",
         "first qualifying close creates no historical record");
}

void TestBrokenCoreDFalseBreak()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   engine.LabProbeClose(89.0, 1020);
   engine.LabProbeClose(95.0, 1021);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   Check(ArraySize(records) == 0
         && EventCount(engine, CORE_BREAK_FAILED) == 1
         && engine.LabProbeState().cycleState.cycle == MARKET_CYCLE_BULL,
         "BROKEN_CORE_D_FALSE_BREAK",
         "reclaimed candidate creates no historical record");
}

void TestBrokenCoreEBullContinuation()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   Check(ArraySize(records) == 0
         && engine.LabProbeState().cycleState.cycle == MARKET_CYCLE_BULL,
         "BROKEN_CORE_E_BULL_CONTINUATION",
         "Bull-to-Bull break is not a Case-2 archive trigger");
}

void TestBrokenCoreFBearContinuation()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   Check(ArraySize(records) == 0
         && engine.LabProbeState().cycleState.cycle == MARKET_CYCLE_BEAR,
         "BROKEN_CORE_F_BEAR_CONTINUATION",
         "Bear-to-Bear break is not a Case-2 archive trigger");
}

void TestBrokenCoreGImmutability()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   BrokenCoreRecord before[];
   engine.LabProbeBrokenCoreHistory(before);
   engine.LabProbeClose(100.0, 1030);
   engine.LabProbeClose(101.0, 1040);
   engine.LabProbeClose(102.0, 1050);
   BrokenCoreRecord after[];
   engine.LabProbeBrokenCoreHistory(after);
   Check(ArraySize(before) == 1 && ArraySize(after) == 1
         && before[0].originTime == after[0].originTime
         && before[0].confirmationBreakTime
            == after[0].confirmationBreakTime
         && SamePrice(before[0].price, after[0].price)
         && after[0].originTime == 999
         && after[0].confirmationBreakTime == 1021,
         "BROKEN_CORE_G_IMMUTABILITY",
         "later bars cannot move or overwrite historical coordinates");
}

void TestBrokenCoreHMultipleReversals()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedTwoCycleReversals(engine);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   Check(ArraySize(records) == 2
         && records[0].coreType == CORE_SWING_LOW
         && SamePrice(records[0].price, 90.0)
         && records[0].originTime == 999
         && records[0].confirmationBreakTime == 1021
         && records[1].coreType == CORE_SWING_HIGH
         && SamePrice(records[1].price, 105.0)
         && records[1].originTime == 1010
         && records[1].confirmationBreakTime == 1051,
         "BROKEN_CORE_H_MULTIPLE_REVERSALS",
         "Bull-Bear-Bull retains two independent chronological records");
}

void TestBrokenCoreIRendererGeometry()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SwingPoint swings[];
   SidewayBoxRecord sideway[];
   renderer.Update(engine.LabProbeState(), swings, records, sideway);
   const string name = BrokenCoreObjectNameForTest(records[0]);
   Check(ObjectFind(0, name) >= 0
         && ObjectPointTime(name, 0) == 999
         && ObjectPointTime(name, 1) == 1021
         && SamePrice(ObjectGetDouble(0, name, OBJPROP_PRICE, 0), 90.0)
         && SamePrice(ObjectGetDouble(0, name, OBJPROP_PRICE, 1), 90.0)
         && (color)ObjectGetInteger(0, name, OBJPROP_COLOR) == clrWhite
         && !ObjectGetInteger(0, name, OBJPROP_RAY_LEFT)
         && !ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT),
         "BROKEN_CORE_I_RENDERER_GEOMETRY",
         "white finite line exactly matches archived start, end and price");
   renderer.Destroy();
}

void TestBrokenCoreJDuplicateRefresh()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   BrokenCoreRecord records[];
   engine.LabProbeBrokenCoreHistory(records);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SwingPoint swings[];
   SidewayBoxRecord sideway[];
   renderer.Update(engine.LabProbeState(), swings, records, sideway);
   renderer.Update(engine.LabProbeState(), swings, records, sideway);
   renderer.Update(engine.LabProbeState(), swings, records, sideway);
   const string name = BrokenCoreObjectNameForTest(records[0]);
   Check(CountOwnedObjects("JINPA_BROKEN_CORE_", OBJ_TREND) == 1
         && ObjectPointTime(name, 0) == 999
         && ObjectPointTime(name, 1) == 1021,
         "BROKEN_CORE_J_DUPLICATE_REFRESH",
         "repeated snapshot rendering retains one stable historical object");
   renderer.Destroy();
}

void TestBrokenCoreKBootstrapSequentialParity()
{
   CPriceStructureEngine bootstrap;
   CPriceStructureEngine sequential;
   bootstrap.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, true);
   sequential.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedTwoCycleReversals(bootstrap);
   FeedTwoCycleReversals(sequential);
   BrokenCoreRecord left[];
   BrokenCoreRecord right[];
   bootstrap.LabProbeBrokenCoreHistory(left);
   sequential.LabProbeBrokenCoreHistory(right);
   bool parity = ArraySize(left) == 2 && ArraySize(right) == 2;
   for(int index = 0; parity && index < ArraySize(left); index++)
      parity = left[index].symbol == right[index].symbol
               && left[index].timeframe == right[index].timeframe
               && left[index].coreType == right[index].coreType
               && SamePrice(left[index].price, right[index].price)
               && left[index].originTime == right[index].originTime
               && left[index].confirmationBreakTime
                  == right[index].confirmationBreakTime
               && left[index].oldCycle == right[index].oldCycle
               && left[index].newCycle == right[index].newCycle;
   Check(parity,
         "BROKEN_CORE_K_BOOTSTRAP_SEQUENTIAL",
         "identical history yields identical semantic archive records");
}

void SeedCase3CoreObjects()
{
   const string highLine = "JINPA_STRUCT_CORE_HIGH";
   const string lowLine = "JINPA_STRUCT_CORE_LOW";
   const string highLabel = "JINPA_STRUCT_CORE_HIGH_LABEL";
   const string lowLabel = "JINPA_STRUCT_CORE_LOW_LABEL";
   if(ObjectFind(0, highLine) < 0)
      ObjectCreate(0, highLine, OBJ_HLINE, 0, 0, 1.0);
   if(ObjectFind(0, lowLine) < 0)
      ObjectCreate(0, lowLine, OBJ_HLINE, 0, 0, 1.0);
   if(ObjectFind(0, highLabel) < 0)
      ObjectCreate(0, highLabel, OBJ_LABEL, 0, 0, 0);
   if(ObjectFind(0, lowLabel) < 0)
      ObjectCreate(0, lowLabel, OBJ_LABEL, 0, 0, 0);
}

bool Case3ProtectedVisual(const bool bull, const double expectedPrice)
{
   const string visibleLine = bull ? "JINPA_STRUCT_CORE_LOW"
                                   : "JINPA_STRUCT_CORE_HIGH";
   const string hiddenLine = bull ? "JINPA_STRUCT_CORE_HIGH"
                                  : "JINPA_STRUCT_CORE_LOW";
   const string visibleLabel = visibleLine + "_LABEL";
   const string hiddenLabel = hiddenLine + "_LABEL";
   return ObjectFind(0, visibleLine) >= 0
          && ObjectFind(0, hiddenLine) < 0
          && ObjectFind(0, visibleLabel) >= 0
          && ObjectFind(0, hiddenLabel) < 0
          && CountOwnedObjects("JINPA_STRUCT_CORE_", OBJ_HLINE) == 1
          && SamePrice(ObjectGetDouble(0, visibleLine, OBJPROP_PRICE),
                       expectedPrice)
          && (color)ObjectGetInteger(0, visibleLine, OBJPROP_COLOR)
             == C'255,165,0';
}

void RenderCase3(CStructureDebugRenderer &renderer,
                 const PriceStructureState &state,
                 const BrokenCoreRecord &broken[],
                 const SidewayBoxRecord &boxes[])
{
   SwingPoint swings[];
   renderer.Update(state, swings, broken, boxes);
}

void TestCase3ABullComplete()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   PriceStructureState state = engine.LabProbeState();
   RenderCase3(renderer, state, broken, boxes);
   Check(state.coreBox.valid
         && SamePrice(state.coreBox.coreHigh.price, 110.0)
         && SamePrice(state.coreBox.coreLow.price, 90.0)
         && Case3ProtectedVisual(true, 90.0),
         "C3_A_BULL_COMPLETE",
         "dual Engine Core retained; orange Low line/label only");
   renderer.Destroy();
}

void TestCase3BBearComplete()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   PriceStructureState state = engine.LabProbeState();
   RenderCase3(renderer, state, broken, boxes);
   Check(state.coreBox.valid && Case3ProtectedVisual(false, 110.0),
         "C3_B_BEAR_COMPLETE", "orange High line/label only");
   renderer.Destroy();
}

void TestCase3CBullPendingHigh()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   BeginUpTransition(engine);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   PriceStructureState state = engine.LabProbeState();
   RenderCase3(renderer, state, broken, boxes);
   Check(state.coreBox.lifecycle == CORE_BOX_PENDING_HIGH
         && Case3ProtectedVisual(true, 95.0),
         "C3_C_BULL_PENDING_HIGH", "authoritative Low remains visible");
   renderer.Destroy();
}

void TestCase3DBearPendingLow()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   PriceStructureState state = engine.LabProbeState();
   RenderCase3(renderer, state, broken, boxes);
   Check(state.coreBox.lifecycle == CORE_BOX_PENDING_LOW
         && Case3ProtectedVisual(false, 105.0),
         "C3_D_BEAR_PENDING_LOW", "authoritative High remains visible");
   renderer.Destroy();
}

void TestCase3EBullToBear()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   BrokenCoreRecord none[];
   SidewayBoxRecord boxes[];
   RenderCase3(renderer, engine.LabProbeState(), none, boxes);
   const bool before = Case3ProtectedVisual(true, 90.0);
   BeginDownTransition(engine);
   BrokenCoreRecord broken[];
   engine.LabProbeBrokenCoreHistory(broken);
   SeedCase3CoreObjects();
   RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   Check(before && Case3ProtectedVisual(false, 105.0)
         && CountOwnedObjects("JINPA_BROKEN_CORE_", OBJ_TREND) == 1,
         "C3_E_BULL_TO_BEAR",
         "stale orange Low removed; High active; white Low retained");
   renderer.Destroy();
}

void TestCase3FBearToBull()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   BrokenCoreRecord none[];
   SidewayBoxRecord boxes[];
   RenderCase3(renderer, engine.LabProbeState(), none, boxes);
   const bool before = Case3ProtectedVisual(false, 110.0);
   BeginUpTransition(engine);
   BrokenCoreRecord broken[];
   engine.LabProbeBrokenCoreHistory(broken);
   SeedCase3CoreObjects();
   RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   Check(before && Case3ProtectedVisual(true, 95.0)
         && CountOwnedObjects("JINPA_BROKEN_CORE_", OBJ_TREND) == 1,
         "C3_F_BEAR_TO_BULL",
         "stale orange High removed; Low active; white High retained");
   renderer.Destroy();
}

void TestCase3GNoValidCore()
{
   PriceStructureState state;
   ResetPriceStructureState(state);
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   RenderCase3(renderer, state, broken, boxes);
   Check(CountOwnedObjectsAny("JINPA_STRUCT_CORE_") == 0,
         "C3_G_NO_VALID_CORE", "empty snapshot clears lines and labels");
   renderer.Destroy();
}

void TestCase3HExactlyOneActiveCore()
{
   CPriceStructureEngine engine;
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   bool allHealthy = true;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   SeedCase3CoreObjects();
   RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   allHealthy = allHealthy && Case3ProtectedVisual(true, 90.0);
   BeginUpTransition(engine);
   SeedCase3CoreObjects();
   RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   allHealthy = allHealthy && Case3ProtectedVisual(true, 95.0);
   renderer.Destroy();
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   SeedCase3CoreObjects();
   RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   allHealthy = allHealthy && Case3ProtectedVisual(false, 110.0);
   BeginDownTransition(engine);
   SeedCase3CoreObjects();
   RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   allHealthy = allHealthy && Case3ProtectedVisual(false, 105.0);
   Check(allHealthy, "C3_H_EXACTLY_ONE_ACTIVE_CORE",
         "Bull/Bear COMPLETE and PENDING fixtures each own one orange line");
   renderer.Destroy();
}

void TestCase3ISidewayCoexistence()
{
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   CPriceStructureEngine bull;
   BuildClosedBarSideway(bull);
   SeedCase3CoreObjects();
   RenderCase3(renderer, bull.LabProbeState(), broken, boxes);
   bool coexist = Case3ProtectedVisual(true, 100.0)
                  && CountOwnedObjects("JINPA_SIDEWAY_BOX_HIGH_", OBJ_TREND) == 1
                  && CountOwnedObjects("JINPA_SIDEWAY_BOX_LOW_", OBJ_TREND) == 1;
   renderer.Destroy();
   CPriceStructureEngine bear;
   bear.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   bear.LabProbeSwing(SWING_HIGH, 100.0, 1010, 1011);
   bear.LabProbeSwing(SWING_LOW, 95.0, 1020, 1021);
   bear.LabProbeSwing(SWING_HIGH, 102.0, 1030, 1031);
   bear.LabProbeSwing(SWING_LOW, 96.0, 1040, 1041);
   SeedCase3CoreObjects();
   RenderCase3(renderer, bear.LabProbeState(), broken, boxes);
   coexist = coexist && Case3ProtectedVisual(false, 110.0)
             && CountOwnedObjects("JINPA_SIDEWAY_BOX_HIGH_", OBJ_TREND) == 1
             && CountOwnedObjects("JINPA_SIDEWAY_BOX_LOW_", OBJ_TREND) == 1;
   Check(coexist, "C3_I_SIDEWAY_COEXISTENCE",
         "Bull/Bear green ranges coexist with the protected orange side");
   renderer.Destroy();
}

void TestCase3JBrokenCoreCoexistence()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   FeedTwoCycleReversals(engine);
   BrokenCoreRecord broken[];
   engine.LabProbeBrokenCoreHistory(broken);
   SidewayBoxRecord boxes[];
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   Check(ArraySize(broken) == 2
         && CountOwnedObjects("JINPA_BROKEN_CORE_", OBJ_TREND) == 2
         && Case3ProtectedVisual(true, 95.0),
         "C3_J_BROKEN_CORE_COEXISTENCE",
         "two white reversals coexist with one current orange Low");
   renderer.Destroy();
}

void TestCase3KMultipleRefresh()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginDownTransition(engine);
   BrokenCoreRecord broken[];
   engine.LabProbeBrokenCoreHistory(broken);
   SidewayBoxRecord boxes[];
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   for(int index = 0; index < 5; index++)
      RenderCase3(renderer, engine.LabProbeState(), broken, boxes);
   Check(Case3ProtectedVisual(false, 105.0)
         && CountOwnedObjects("JINPA_BROKEN_CORE_", OBJ_TREND) == 0,
         "C3_K_MULTIPLE_REFRESH",
         "five refreshes retain one High and no stale/duplicate Core object");
   renderer.Destroy();
}

void TestCase3LBootstrapSequential()
{
   CPriceStructureEngine bootstrap;
   CPriceStructureEngine sequential;
   bootstrap.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, true);
   sequential.LabProbeInitialize(MARKET_CYCLE_BEAR, 110.0, 90.0, 1000, false);
   BeginUpTransition(bootstrap);
   BeginUpTransition(sequential);
   BrokenCoreRecord broken[];
   SidewayBoxRecord boxes[];
   CStructureDebugRenderer renderer;
   renderer.Configure(false);
   renderer.Destroy();
   SeedCase3CoreObjects();
   RenderCase3(renderer, bootstrap.LabProbeState(), broken, boxes);
   const bool left = Case3ProtectedVisual(true, 95.0);
   renderer.Destroy();
   SeedCase3CoreObjects();
   RenderCase3(renderer, sequential.LabProbeState(), broken, boxes);
   const bool right = Case3ProtectedVisual(true, 95.0);
   Check(left && right
         && SameCase5StateAndEvents(bootstrap, sequential),
         "C3_L_BOOTSTRAP_SEQUENTIAL",
         "same semantic state selects the same protected visible side");
   renderer.Destroy();
}

StructureEvent MakeNotificationEvent(
   const ENUM_STRUCTURE_EVENT_TYPE type,
   const string identity,
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const ENUM_MARKET_CYCLE cycleBefore,
   const ENUM_MARKET_CYCLE cycleAfter,
   const ENUM_CORE_SWING_TYPE coreType,
   const datetime eventTime)
{
   StructureEvent event;
   event.type = type;
   event.symbol = symbol;
   event.timeframe = timeframe;
   event.eventBarTime = eventTime;
   event.cycleBefore = cycleBefore;
   event.cycleAfter = cycleAfter;
   event.coreType = coreType;
   event.oldCoreLevel = 100.0;
   event.newCoreLevel = 101.0;
   event.breakLevel = 99.0;
   event.reason = "CASE4_PROBE";
   event.identity = identity;
   event.boxGeneration = 2;
   event.sidewayConfirmationType = SIDEWAY_CLEAN_2_LEG;
   return event;
}

int NotificationMessageCount(const string &messages[],
                             const string label)
{
   int count = 0;
   for(int index = 0; index < ArraySize(messages); index++)
      if(StringFind(messages[index], label) >= 0)
         count++;
   return count;
}

void EnqueuePendingEngineEvents(CPriceStructureEngine &engine,
                                CStructureNotificationManager &manager)
{
   StructureEvent events[];
   engine.ConsumeEvents(events);
   for(int index = 0; index < ArraySize(events); index++)
      manager.Enqueue(events[index]);
}

void TestNotificationABreakCandidate()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   StructureEvent event = MakeNotificationEvent(
      CORE_BREAK_CANDIDATE, "N-A", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_LOW, 1000);
   manager.Enqueue(event);
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 1
         && messages[0] == "JINPA | XAUUSD H1\n"
                           "BREAK CANDIDATE | CORE LOW | BULL",
         "N_A_BREAK_CANDIDATE", "one compact symbol/TF/Core/Cycle message");
}

void TestNotificationBCoreUpdated()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   StructureEvent discarded[];
   engine.ConsumeEvents(discarded);
   engine.LabProbeSwing(SWING_LOW, 95.0, 1010, 1011);
   engine.ConsumeEvents(discarded);
   engine.LabProbeClose(111.0, 1020);
   engine.LabProbeClose(112.0, 1021);
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   EnqueuePendingEngineEvents(engine, manager);
   engine.LabProbeSwing(SWING_HIGH, 120.0, 1030, 1031);
   EnqueuePendingEngineEvents(engine, manager);
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(NotificationMessageCount(messages, "CORE UPDATED") == 1
         && NotificationMessageCount(messages, "CORE_BOX_CHANGED") == 0
         && NotificationMessageCount(messages,
                                      "CORE UPDATED | CORE LOW | BULL") == 1,
         "N_B_CORE_UPDATED",
         "transition promotion maps once; completion noise is ignored");
}

void TestNotificationCCycleChanged()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   StructureEvent event = MakeNotificationEvent(
      CYCLE_CHANGED, "N-C", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BEAR, CORE_SWING_NONE, 1000);
   manager.Enqueue(event);
   manager.Enqueue(MakeNotificationEvent(
      CYCLE_CHANGED, "N-C-CONTINUATION", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_NONE, 1001));
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 1
         && StringFind(messages[0],
                       "CYCLE CHANGED | BULL → BEAR") >= 0,
         "N_C_CYCLE_CHANGED",
         "actual reversal formats once; Bull-to-Bull is ineligible");
}

void TestNotificationDLeg1()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   manager.Enqueue(MakeNotificationEvent(
      LEG_1_CONFIRMED, "N-D", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_NONE, 1000));
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 1
         && StringFind(messages[0], "LEG 1 CONFIRMED | BULL") >= 0,
         "N_D_LEG_1", "one event-driven Leg 1 notification");
}

void TestNotificationELeg2()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   manager.Enqueue(MakeNotificationEvent(
      LEG_2_CONFIRMED, "N-E", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BEAR, MARKET_CYCLE_BEAR, CORE_SWING_NONE, 1000));
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 1
         && StringFind(messages[0], "LEG 2 CONFIRMED | BEAR") >= 0,
         "N_E_LEG_2", "one event-driven Leg 2 notification");
}

void TestNotificationFFalseBreak()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   manager.Enqueue(MakeNotificationEvent(
      CORE_BREAK_FAILED, "N-F", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_LOW, 1000));
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 1
         && StringFind(messages[0],
                       "FALSE BREAK | CORE LOW | BULL") >= 0,
         "N_F_FALSE_BREAK", "candidate failure maps without a new detector");
}

void TestNotificationGSideway()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   manager.Enqueue(MakeNotificationEvent(
      SIDEWAY_CONFIRMED, "N-G", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BEAR, MARKET_CYCLE_BEAR, CORE_SWING_NONE, 1000));
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 1
         && StringFind(messages[0], "SIDEWAY CONFIRMED | BEAR") >= 0,
         "N_G_SIDEWAY_CONFIRMED", "one semantic Sideway notification");
}

void TestNotificationHConfirmedBreakNotFalseBreak()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   StructureEvent discarded[];
   engine.ConsumeEvents(discarded);
   BeginDownTransition(engine);
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   EnqueuePendingEngineEvents(engine, manager);
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(NotificationMessageCount(messages, "BREAK CANDIDATE") == 1
         && NotificationMessageCount(messages, "FALSE BREAK") == 0,
         "N_H_CONFIRMED_BREAK_NOT_FALSE_BREAK",
         "confirmed transition never fabricates candidate failure");
}

void TestNotificationIFirstCandidateDuplicate()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   StructureEvent event = MakeNotificationEvent(
      CORE_BREAK_CANDIDATE, "N-I", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_LOW, 1000);
   manager.Enqueue(event);
   manager.Enqueue(event);
   manager.Enqueue(event);
   Check(manager.LabProbeQueueSize() == 1
         && manager.LabProbeKnownIdentityCount() == 1,
         "N_I_FIRST_CANDIDATE_DUPLICATE",
         "same semantic identity is queued once");
}

void TestNotificationJLeg1DuplicateState()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   StructureEvent discarded[];
   engine.ConsumeEvents(discarded);
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   engine.LabProbeSwing(SWING_LOW, 100.0, 1010, 1011);
   EnqueuePendingEngineEvents(engine, manager);
   engine.LabProbeClosedBar(108.0, 96.0, 102.0, 1012);
   engine.LabProbeClosedBar(107.0, 97.0, 103.0, 1013);
   EnqueuePendingEngineEvents(engine, manager);
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(NotificationMessageCount(messages, "LEG 1 CONFIRMED") == 1,
         "N_J_LEG_1_DUPLICATE_STATE",
         "later bars with active Leg 1 emit no repeated event");
}

void TestNotificationKLeg2DuplicateState()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   StructureEvent discarded[];
   engine.ConsumeEvents(discarded);
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   engine.LabProbeSwing(SWING_LOW, 100.0, 1010, 1011);
   engine.LabProbeSwing(SWING_HIGH, 105.0, 1020, 1021);
   engine.LabProbeSwing(SWING_LOW, 98.0, 1030, 1031);
   EnqueuePendingEngineEvents(engine, manager);
   engine.LabProbeClosedBar(106.0, 96.0, 102.0, 1032);
   engine.LabProbeClosedBar(105.0, 97.0, 103.0, 1033);
   EnqueuePendingEngineEvents(engine, manager);
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(NotificationMessageCount(messages, "LEG 2 CONFIRMED") == 1,
         "N_K_LEG_2_DUPLICATE_STATE",
         "later bars with active Leg 2 emit no repeated event");
}

void TestNotificationLSidewayDuplicateState()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, false);
   StructureEvent discarded[];
   engine.ConsumeEvents(discarded);
   FeedCleanBull(engine);
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   EnqueuePendingEngineEvents(engine, manager);
   string initial[];
   manager.LabProbeDrainMessages(initial);
   engine.LabProbeClosedBar(108.0, 96.0, 102.0, 1050);
   engine.LabProbeClosedBar(107.0, 97.0, 103.0, 1060);
   EnqueuePendingEngineEvents(engine, manager);
   Check(NotificationMessageCount(initial, "SIDEWAY CONFIRMED") == 1
         && manager.LabProbeQueueSize() == 0,
         "N_L_SIDEWAY_DUPLICATE_STATE",
         "closed-bar right-edge updates emit no notification");
}

void TestNotificationMBootstrap()
{
   CPriceStructureEngine engine;
   engine.LabProbeInitialize(MARKET_CYCLE_BULL, 110.0, 90.0, 1000, true);
   FeedCleanBull(engine);
   engine.LabProbeClose(111.0, 1050);
   engine.LabProbeClose(105.0, 1051);
   StructureEvent pending[];
   engine.ConsumeEvents(pending);
   Check(ArraySize(pending) == 0,
         "N_M_BOOTSTRAP", "historical reconstruction exposes zero live events");
}

void TestNotificationNTesterSuppression()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   manager.Enqueue(MakeNotificationEvent(
      CORE_BREAK_CANDIDATE, "N-N", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_LOW, 1000));
   manager.DispatchNext();
   Check((bool)MQLInfoInteger(MQL_TESTER)
         && manager.LabProbeQueueSize() == 0
         && manager.LabProbeRealSendAttempts() == 0,
         "N_N_TESTER_SUPPRESSION",
         "direct dispatch is consumed without calling SendNotification");
}

void TestNotificationOSameBarDistinctEvents()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   manager.Enqueue(MakeNotificationEvent(
      CYCLE_CHANGED, "N-O-CYCLE", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BEAR, CORE_SWING_NONE, 1021));
   manager.Enqueue(MakeNotificationEvent(
      CORE_BOX_TRANSITION_STARTED, "N-O-CORE", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BEAR, CORE_SWING_HIGH, 1021));
   string messages[];
   manager.LabProbeDrainMessages(messages);
   Check(ArraySize(messages) == 2
         && StringFind(messages[0], "CYCLE CHANGED") >= 0
         && StringFind(messages[1], "CORE UPDATED") >= 0,
         "N_O_SAME_BAR_DISTINCT_EVENTS",
         "FIFO retains both distinct identities from one closed bar");
}

void TestNotificationPEventOrder()
{
   const ENUM_STRUCTURE_EVENT_TYPE types[] =
   {
      CORE_BREAK_CANDIDATE, CORE_BOX_TRANSITION_STARTED, CYCLE_CHANGED,
      LEG_1_CONFIRMED, LEG_2_CONFIRMED, CORE_BREAK_FAILED,
      SIDEWAY_CONFIRMED
   };
   const string labels[] =
   {
      "BREAK CANDIDATE", "CORE UPDATED", "CYCLE CHANGED",
      "LEG 1 CONFIRMED", "LEG 2 CONFIRMED", "FALSE BREAK",
      "SIDEWAY CONFIRMED"
   };
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   for(int index = 0; index < 7; index++)
      manager.Enqueue(MakeNotificationEvent(
         types[index], "N-P-" + IntegerToString(index), "XAUUSD", PERIOD_H1,
         index == 2 ? MARKET_CYCLE_BULL : MARKET_CYCLE_BEAR,
         MARKET_CYCLE_BEAR,
         index == 0 ? CORE_SWING_HIGH : index == 1 ? CORE_SWING_HIGH
         : index == 5 ? CORE_SWING_HIGH : CORE_SWING_NONE,
         1000 + index));
   string messages[];
   manager.LabProbeDrainMessages(messages);
   bool ordered = ArraySize(messages) == 7;
   for(int index = 0; ordered && index < 7; index++)
      ordered = StringFind(messages[index], labels[index]) >= 0;
   Check(ordered, "N_P_EVENT_ORDER", "notification FIFO matches enqueue order");
}

void TestNotificationQSessionDedup()
{
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   StructureEvent xau = MakeNotificationEvent(
      CORE_BREAK_CANDIDATE, "XAUUSD|60|candidate|1000", "XAUUSD", PERIOD_H1,
      MARKET_CYCLE_BULL, MARKET_CYCLE_BULL, CORE_SWING_LOW, 1000);
   StructureEvent eur = MakeNotificationEvent(
      CORE_BREAK_CANDIDATE, "EURUSD|120|candidate|1000", "EURUSD", PERIOD_H2,
      MARKET_CYCLE_BEAR, MARKET_CYCLE_BEAR, CORE_SWING_HIGH, 1000);
   manager.Enqueue(xau);
   manager.Enqueue(xau);
   manager.Enqueue(eur);
   Check(manager.LabProbeQueueSize() == 2
         && manager.LabProbeKnownIdentityCount() == 2,
         "N_Q_SESSION_DEDUP",
         "duplicate suppressed; symbol/timeframe identities stay independent");
}

void TestNotificationRFormatting()
{
   const ENUM_STRUCTURE_EVENT_TYPE types[] =
   {
      CORE_BREAK_CANDIDATE, CORE_BOX_TRANSITION_STARTED, CYCLE_CHANGED,
      LEG_1_CONFIRMED, LEG_2_CONFIRMED, CORE_BREAK_FAILED,
      SIDEWAY_CONFIRMED
   };
   const string bodies[] =
   {
      "BREAK CANDIDATE | CORE LOW | BULL",
      "CORE UPDATED | CORE LOW | BULL",
      "CYCLE CHANGED | BULL → BEAR",
      "LEG 1 CONFIRMED | BULL",
      "LEG 2 CONFIRMED | BULL",
      "FALSE BREAK | CORE LOW | BULL",
      "SIDEWAY CONFIRMED | BULL"
   };
   CStructureNotificationManager manager;
   manager.Configure(true, false);
   bool exact = true;
   for(int index = 0; exact && index < 7; index++)
   {
      StructureEvent event = MakeNotificationEvent(
         types[index], "N-R-" + IntegerToString(index), "XAUUSD", PERIOD_H1,
         MARKET_CYCLE_BULL,
         index == 2 ? MARKET_CYCLE_BEAR : MARKET_CYCLE_BULL,
         index == 0 || index == 1 || index == 5
         ? CORE_SWING_LOW : CORE_SWING_NONE,
         1000 + index);
      exact = manager.LabProbeEligible(event)
              && manager.LabProbeBuildMessage(event)
                 == "JINPA | XAUUSD H1\n" + bodies[index];
   }
   Check(exact, "N_R_FORMATTING", "all seven labels and compact bodies exact");
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
   TestDisplayCombination(true, false, "DISPLAY_A_PROTECTED_CORE_SWINGS_ON");
   TestDisplayCombination(false, false, "DISPLAY_B_PROTECTED_CORE_SWINGS_OFF");
   TestDisplayCombination(true, true, "DISPLAY_C_REPEAT_SWINGS_ON");
   TestDisplayCombination(false, true, "DISPLAY_D_REPEAT_SWINGS_OFF");
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
   TestCase5AutomaticProtectedDisplay();
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
   const int beforeCase1Passed = g_passed;
   const int beforeCase1Failed = g_failed;
   TestCase1HigherInternalHigh();
   TestCase1LowerInternalLow();
   TestCase1AlternatingExpansion();
   TestCase1NonExtremeUnchanged();
   TestCase1FalseBreakHigh();
   TestCase1FalseBreakLow();
   TestCase1ConfirmedBreakReset();
   TestCase1PendingHighDisabled();
   TestCase1PendingLowDisabled();
   TestCase1BootstrapSequentialParity();
   const int case1Passed = g_passed - beforeCase1Passed;
   const int case1Failed = g_failed - beforeCase1Failed;
   const int beforeClosedBarPassed = g_passed;
   const int beforeClosedBarFailed = g_failed;
   TestClosedBarHighExpansion();
   TestClosedBarLowExpansion();
   TestClosedBarBothSides();
   TestClosedBarNoExtreme();
   TestClosedBarNoSwingRequired();
   TestClosedBarFormingIgnored();
   TestClosedBarFirstBreakCandidate();
   TestClosedBarCoreLowClamp();
   TestClosedBarFalseBreak();
   TestClosedBarConfirmedBreak();
   TestFixedSidewayNewLifecycleIdentity();
   TestClosedBarPendingHigh();
   TestClosedBarPendingLow();
   TestClosedBarBootstrapSequentialParity();
   const int closedBarPassed = g_passed - beforeClosedBarPassed;
   const int closedBarFailed = g_failed - beforeClosedBarFailed;
   const int beforeLeftEdgePassed = g_passed;
   const int beforeLeftEdgeFailed = g_failed;
   TestLeftEdgeAStateUsesOwnCoreTimes();
   TestLeftEdgeBHighEarlierThanLow();
   TestLeftEdgeCLowEarlierThanHigh();
   TestLeftEdgeDLateConfirmationDoesNotMoveLeft();
   TestLeftEdgeELifecycleIdentitySeparated();
   TestLeftEdgeFRightUpdatesPreserveLeft();
   TestLeftEdgeGConfirmedBreakPreservesGeometry();
   TestLeftEdgeHNewLifecycleIndependent();
   TestLeftEdgeIBootstrapSequentialParity();
   const int leftEdgePassed = g_passed - beforeLeftEdgePassed;
   const int leftEdgeFailed = g_failed - beforeLeftEdgeFailed;
   const int beforeBrokenCorePassed = g_passed;
   const int beforeBrokenCoreFailed = g_failed;
   TestBrokenCoreABullToBear();
   TestBrokenCoreBBearToBull();
   TestBrokenCoreCFirstCandidate();
   TestBrokenCoreDFalseBreak();
   TestBrokenCoreEBullContinuation();
   TestBrokenCoreFBearContinuation();
   TestBrokenCoreGImmutability();
   TestBrokenCoreHMultipleReversals();
   TestBrokenCoreIRendererGeometry();
   TestBrokenCoreJDuplicateRefresh();
   TestBrokenCoreKBootstrapSequentialParity();
   const int brokenCorePassed = g_passed - beforeBrokenCorePassed;
   const int brokenCoreFailed = g_failed - beforeBrokenCoreFailed;
   const int beforeCase3Passed = g_passed;
   const int beforeCase3Failed = g_failed;
   TestCase3ABullComplete();
   TestCase3BBearComplete();
   TestCase3CBullPendingHigh();
   TestCase3DBearPendingLow();
   TestCase3EBullToBear();
   TestCase3FBearToBull();
   TestCase3GNoValidCore();
   TestCase3HExactlyOneActiveCore();
   TestCase3ISidewayCoexistence();
   TestCase3JBrokenCoreCoexistence();
   TestCase3KMultipleRefresh();
   TestCase3LBootstrapSequential();
   const int case3Passed = g_passed - beforeCase3Passed;
   const int case3Failed = g_failed - beforeCase3Failed;
   const int beforeNotificationPassed = g_passed;
   const int beforeNotificationFailed = g_failed;
   TestNotificationABreakCandidate();
   TestNotificationBCoreUpdated();
   TestNotificationCCycleChanged();
   TestNotificationDLeg1();
   TestNotificationELeg2();
   TestNotificationFFalseBreak();
   TestNotificationGSideway();
   TestNotificationHConfirmedBreakNotFalseBreak();
   TestNotificationIFirstCandidateDuplicate();
   TestNotificationJLeg1DuplicateState();
   TestNotificationKLeg2DuplicateState();
   TestNotificationLSidewayDuplicateState();
   TestNotificationMBootstrap();
   TestNotificationNTesterSuppression();
   TestNotificationOSameBarDistinctEvents();
   TestNotificationPEventOrder();
   TestNotificationQSessionDedup();
   TestNotificationRFormatting();
   const int notificationPassed = g_passed - beforeNotificationPassed;
   const int notificationFailed = g_failed - beforeNotificationFailed;
   Print("[COREBOX_DEV_TEST][SECTIONS] semantic=", semanticPassed,
         "/", semanticFailed,
         " parameter=", parameterPassed, "/", parameterFailed,
         " display=", displayPassed, "/", displayFailed,
         " case5=", case5Passed, "/", case5Failed,
         " case1_guard=", case1Passed, "/", case1Failed,
         " case1_fixed=", closedBarPassed, "/", closedBarFailed,
         " left_edge=", leftEdgePassed, "/", leftEdgeFailed,
         " broken_core=", brokenCorePassed, "/", brokenCoreFailed,
         " case3=", case3Passed, "/", case3Failed,
         " case4_notify=", notificationPassed, "/", notificationFailed);
   Print("[COREBOX_DEV_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick()
{
   ExpertRemove();
}
