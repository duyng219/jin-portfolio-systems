#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Stage 3 Market Structure deterministic probe"

#include "../watch/state/MarketStructureEngine.mqh"
#include "../watch/structure/MicroBaseRenderer.mqh"
#include "../watch/ui/MarketRadar.mqh"

int g_passed = 0;
int g_failed = 0;
CMarketStructureEngine g_engine;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[MARKET_STRUCTURE_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[MARKET_STRUCTURE_TEST][FAIL] ", name);
   }
}

PriceStructureState BaseStructureState(void)
{
   PriceStructureState source;
   ResetPriceStructureState(source);
   source.initialized = true;
   return source;
}

bool IsStructure(const ENUM_JINPA_MARKET_STATE state,
                 const PriceStructureState &source,
                 const ENUM_JINPA_MARKET_STRUCTURE expected)
{
   return g_engine.Derive(state, source) == expected;
}

MqlRates ClosedBar(const datetime time, const double high,
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

bool IsRangeStructure(const PriceStructureState &source,
                      const MqlRates &closedBar,
                      const double edgeDistance,
                      const bool falseBreakConfirmed,
                      const ENUM_JINPA_MARKET_STRUCTURE expected)
{
   return g_engine.Derive(JINPA_STATE_COMPRESSION, source, closedBar,
                          edgeDistance, falseBreakConfirmed) == expected;
}

void AppendBar(MqlRates &rates[], const MqlRates &bar)
{
   const int index = ArraySize(rates);
   ArrayResize(rates, index + 1);
   rates[index] = bar;
}

string ApplyImpulseStructure(CMarketStructureEngine &engine,
                             const ENUM_JINPA_MARKET_REGIME regime,
                             const ENUM_JINPA_MARKET_STATE state,
                             const datetime impulseStartTime,
                             PriceStructureState &source,
                             MqlRates &rates[], SymbolState &symbolState)
{
   StructureEvent events[];
   const string previousStructure = symbolState.structure;
   const datetime closedTime = rates[ArraySize(rates) - 1].time;
   engine.Apply(regime, state, impulseStartTime, previousStructure,
                source, events, rates, closedTime, 1, 0.10, symbolState);
   return symbolState.structure;
}

string ApplyRuntimeStructure(CMarketStructureEngine &engine,
                             const ENUM_JINPA_MARKET_REGIME regime,
                             const ENUM_JINPA_MARKET_STATE state,
                             PriceStructureState &source,
                             MqlRates &rates[], SymbolState &symbolState)
{
   // Legacy geometry cases intentionally exercise the pre-existing rule
   // directly; Phase 4B identity behavior has dedicated tests below.
   return ApplyImpulseStructure(engine, regime, state, 0,
                                source, rates, symbolState);
}

void TestRequiredCases(void)
{
   PriceStructureState source = BaseStructureState();
   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   Check(IsStructure(JINPA_STATE_COMPRESSION, source,
                     JINPA_STRUCTURE_SIDEWAY),
         "CASE_S1_COMPRESSION_SIDEWAY");

   ResetSidewayBoxState(source.sidewayBox);
   Check(IsStructure(JINPA_STATE_EXPANSION, source,
                     JINPA_STRUCTURE_BREAKOUT),
         "CASE_S2_EXPANSION_BREAKOUT");
   Check(IsStructure(JINPA_STATE_IMPULSE, source,
                     JINPA_STRUCTURE_CONTINUATION),
         "CASE_S3_IMPULSE_CONTINUATION");
   Check(IsStructure(JINPA_STATE_CORRECTION, source,
                     JINPA_STRUCTURE_NONE),
         "CASE_S4_CORRECTION_WITHOUT_LEG_NONE");

   source.sidewayBox.leg1Confirmed = true;
   Check(IsStructure(JINPA_STATE_CORRECTION, source,
                     JINPA_STRUCTURE_NONE),
         "CASE_S5_COREBOX_LEG1_NOT_MARKET_STRUCTURE_AUTHORITY");
   source.sidewayBox.leg2Confirmed = true;
   Check(IsStructure(JINPA_STATE_CORRECTION, source,
                     JINPA_STRUCTURE_NONE),
         "CASE_S6_COREBOX_LEG2_NOT_MARKET_STRUCTURE_AUTHORITY");

   source = BaseStructureState();
   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   source.lastEvent = "FALSE BREAK";
   Check(IsStructure(JINPA_STATE_COMPRESSION, source,
                     JINPA_STRUCTURE_SIDEWAY),
         "CASE_S7_FALSE_BREAK_SIDEWAY_STABLE");

   ResetSidewayBoxState(source.sidewayBox);
   source.sidewayBox.leg1Confirmed = true;
   source.lastEvent = "FALSE BREAK";
   Check(IsStructure(JINPA_STATE_CORRECTION, source,
                     JINPA_STRUCTURE_NONE),
         "CASE_S8_CORRECTION_REMAINS_NONE_WITH_STALE_COREBOX_LEG");

   SymbolState symbolState;
   symbolState.structure = "LEG 2";
   Check(g_engine.Apply(JINPA_STATE_EXPANSION, source, symbolState)
         && symbolState.structure == "BREAKOUT",
         "CASE_S9_CORE_BREAK_SAME_CYCLE_BREAKOUT");

   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   symbolState.structure = "LEG 2";
   Check(g_engine.Apply(JINPA_STATE_COMPRESSION, source, symbolState)
         && symbolState.structure == "SIDEWAY",
         "CASE_S10_SIDEWAY_SAME_CYCLE_AUTHORITY");

   ResetSidewayBoxState(source.sidewayBox);
   Check(IsStructure(JINPA_STATE_IMPULSE, source,
                     JINPA_STRUCTURE_CONTINUATION),
         "CASE_S11_IMPULSE_REQUIRES_NO_PMA_BASE");
   Check(IsStructure(JINPA_STATE_EXPANSION, source,
                     JINPA_STRUCTURE_BREAKOUT),
         "CASE_S12_EXPANSION_REQUIRES_NO_PMB_BASE");
}

bool FullFlow(void)
{
   PriceStructureState source = BaseStructureState();
   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   const bool compression = IsStructure(JINPA_STATE_COMPRESSION, source,
                                        JINPA_STRUCTURE_SIDEWAY);

   ResetSidewayBoxState(source.sidewayBox);
   const bool expansion = IsStructure(JINPA_STATE_EXPANSION, source,
                                      JINPA_STRUCTURE_BREAKOUT);
   const bool impulse = IsStructure(JINPA_STATE_IMPULSE, source,
                                    JINPA_STRUCTURE_CONTINUATION);
   const bool earlyCorrection = IsStructure(JINPA_STATE_CORRECTION, source,
                                            JINPA_STRUCTURE_NONE);
   source.sidewayBox.leg1Confirmed = true;
   const bool leg1 = IsStructure(JINPA_STATE_CORRECTION, source,
                                 JINPA_STRUCTURE_NONE);
   source.sidewayBox.leg2Confirmed = true;
   const bool leg2 = IsStructure(JINPA_STATE_CORRECTION, source,
                                 JINPA_STRUCTURE_NONE);
   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   const bool recompression = IsStructure(JINPA_STATE_COMPRESSION, source,
                                          JINPA_STRUCTURE_SIDEWAY);
   return compression && expansion && impulse && earlyCorrection
          && leg1 && leg2 && recompression;
}

void TestFlowsAndAuthority(void)
{
   Check(FullFlow(), "FULL_FLOW_BULL");
   Check(FullFlow(), "FULL_FLOW_BEAR");

   PriceStructureState stale = BaseStructureState();
   stale.sidewayBox.active = true;
   stale.sidewayBox.sidewayConfirmed = true;
   stale.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   stale.sidewayBox.leg1Confirmed = true;
   stale.sidewayBox.leg2Confirmed = true;
   Check(IsStructure(JINPA_STATE_EXPANSION, stale,
                     JINPA_STRUCTURE_BREAKOUT)
         && IsStructure(JINPA_STATE_IMPULSE, stale,
                        JINPA_STRUCTURE_CONTINUATION),
         "STATE_AUTHORITY_BLOCKS_STALE_SIDEWAY_AND_LEGS");

   CMarketStructureEngine restarted;
   const ENUM_JINPA_MARKET_STRUCTURE before =
      g_engine.Derive(JINPA_STATE_CORRECTION, stale);
   const ENUM_JINPA_MARKET_STRUCTURE after =
      restarted.Derive(JINPA_STATE_CORRECTION, stale);
   Check(before == JINPA_STRUCTURE_NONE && after == before,
         "BOOTSTRAP_RESTART_STATELESS_PARITY");
}

void TestRangeContextExtensions(void)
{
   PriceStructureState source = BaseStructureState();
   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   source.sidewayBox.boxHigh = 110.0;
   source.sidewayBox.boxLow = 90.0;

   MqlRates bar = ClosedBar(1000, 101.0, 99.0, 100.0);
   Check(IsRangeStructure(source, bar, 1.0, false,
                          JINPA_STRUCTURE_SIDEWAY),
         "RANGE_A_MIDDLE_REMAINS_SIDEWAY");

   bar = ClosedBar(1060, 109.7, 108.8, 109.5);
   Check(IsRangeStructure(source, bar, 1.0, false,
                          JINPA_STRUCTURE_RANGE_EDGE),
         "RANGE_B_APPROACH_UPPER_EDGE");

   bar = ClosedBar(1120, 91.2, 90.3, 90.5);
   Check(IsRangeStructure(source, bar, 1.0, false,
                          JINPA_STRUCTURE_RANGE_EDGE),
         "RANGE_C_APPROACH_LOWER_EDGE");

   MqlRates rates[];
   ArrayResize(rates, 3);
   rates[0] = ClosedBar(1000, 105.0, 95.0, 100.0);
   rates[1] = ClosedBar(1060, 109.7, 99.0, 109.5);
   rates[2] = ClosedBar(1120, 112.0, 109.0, 111.0);
   StructureEvent noEvents[];
   SymbolState symbolState;
   symbolState.structure = "SIDEWAY";
   g_engine.Apply(JINPA_STATE_COMPRESSION, source, noEvents, rates, 1060,
                  1, 0.10, symbolState);
   Check(symbolState.structure == "RANGE EDGE",
         "RANGE_D_FORMING_WICK_IGNORED_USES_LAST_CLOSED_BAR");

   bar = ClosedBar(1180, 111.0, 108.0, 109.0);
   Check(IsRangeStructure(source, bar, 1.0, false,
                          JINPA_STRUCTURE_REJECTION),
         "RANGE_E_UPPER_REJECTION");

   bar = ClosedBar(1240, 92.0, 89.0, 91.0);
   Check(IsRangeStructure(source, bar, 1.0, false,
                          JINPA_STRUCTURE_REJECTION),
         "RANGE_F_LOWER_REJECTION");

   Check(IsRangeStructure(source, bar, 1.0, true,
                          JINPA_STRUCTURE_FALSE_BREAK),
         "RANGE_G_FALSE_BREAK_PRIORITY_OVER_REJECTION");

   StructureEvent events[];
   ArrayResize(events, 1);
   ZeroMemory(events[0]);
   events[0].type = CORE_BREAK_FAILED;
   events[0].eventBarTime = 1060;
   rates[1] = ClosedBar(1060, 111.0, 105.0, 109.0);
   symbolState.structure = "RANGE EDGE";
   g_engine.Apply(JINPA_STATE_COMPRESSION, source, events, rates, 1060,
                  1, 0.10, symbolState);
   Check(symbolState.structure == "FALSE BREAK",
         "RANGE_H_EXISTING_EVENT_WIRES_TO_SYMBOL_STATE");

   events[0].type = SIDEWAY_CONFIRMED;
   symbolState.structure = "LEG 1";
   g_engine.Apply(JINPA_STATE_COMPRESSION, source, events, rates, 1060,
                  1, 0.10, symbolState);
   Check(symbolState.structure == "SIDEWAY",
         "RANGE_I_CONFIRMATION_BAR_STARTS_AS_SIDEWAY");

   events[0].type = CORE_BREAK_FAILED;
   rates[2] = ClosedBar(1120, 101.0, 99.0, 100.0);
   g_engine.Apply(JINPA_STATE_COMPRESSION, source, events, rates, 1120,
                  1, 0.10, symbolState);
   Check(symbolState.structure == "SIDEWAY",
         "RANGE_J_FALSE_BREAK_EVENT_NOT_STICKY");

   Check(IsStructure(JINPA_STATE_EXPANSION, source,
                     JINPA_STRUCTURE_BREAKOUT)
         && IsStructure(JINPA_STATE_IMPULSE, source,
                        JINPA_STRUCTURE_CONTINUATION),
         "RANGE_K_EXPANSION_IMPULSE_UNCHANGED");

   source.sidewayBox.leg1Confirmed = true;
   Check(IsStructure(JINPA_STATE_CORRECTION, source,
                     JINPA_STRUCTURE_NONE),
         "RANGE_L_CORRECTION_LEG1_UNCHANGED");
   source.sidewayBox.leg2Confirmed = true;
   Check(IsStructure(JINPA_STATE_CORRECTION, source,
                     JINPA_STRUCTURE_NONE),
         "RANGE_M_CORRECTION_LEG2_UNCHANGED");
}

void TestMicroBaseLifecycle(void)
{
   PriceStructureState source = BaseStructureState();
   source.cycleState.cycle = MARKET_CYCLE_BULL;
   MqlRates rates[];
   SymbolState symbolState;
   symbolState.structure = "CONTINUATION";
   CMarketStructureEngine engine;

   AppendBar(rates, ClosedBar(1000, 110.0, 100.0, 108.0));
   const bool anchorContinuation =
      ApplyRuntimeStructure(engine, JINPA_REGIME_TREND,
                            JINPA_STATE_IMPULSE, source, rates,
                            symbolState) == "CONTINUATION";
   AppendBar(rates, ClosedBar(1060, 111.0, 101.0, 107.0));
   const bool twoBarsContinuation =
      ApplyRuntimeStructure(engine, JINPA_REGIME_TREND,
                            JINPA_STATE_IMPULSE, source, rates,
                            symbolState) == "CONTINUATION";
   Check(anchorContinuation && twoBarsContinuation,
         "MICRO_BASE_01_TWO_BARS_NOT_CONFIRMED");

   AppendBar(rates, ClosedBar(1120, 109.0, 99.0, 106.0));
   Check(ApplyRuntimeStructure(engine, JINPA_REGIME_TREND,
                               JINPA_STATE_IMPULSE, source, rates,
                               symbolState) == "MICRO BASE",
         "MICRO_BASE_02_ANCHOR_PLUS_TWO_INSIDE_CLOSES");
   Check(symbolState.structure == "MICRO BASE",
         "MICRO_BASE_03_WICKS_OUTSIDE_CLOSE_INSIDE_PERSISTS");
   Check(engine.MicroBaseConfirmed()
         && engine.MicroBaseAnchorTime() == 1000
         && engine.MicroBaseHigh() == 110.0
         && engine.MicroBaseLow() == 100.0,
         "MICRO_BASE_11_CONFIRMED_VISUAL_AUTHORITY_EXPOSED");

   CMarketStructureEngine earlyBreakEngine;
   MqlRates earlyRates[];
   SymbolState earlyState;
   earlyState.structure = "CONTINUATION";
   AppendBar(earlyRates, ClosedBar(2000, 110.0, 100.0, 108.0));
   ApplyRuntimeStructure(earlyBreakEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, earlyRates,
                         earlyState);
   AppendBar(earlyRates, ClosedBar(2060, 112.0, 109.0, 111.0));
   ApplyRuntimeStructure(earlyBreakEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, earlyRates,
                         earlyState);
   AppendBar(earlyRates, ClosedBar(2120, 111.0, 105.0, 107.0));
   ApplyRuntimeStructure(earlyBreakEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, earlyRates,
                         earlyState);
   AppendBar(earlyRates, ClosedBar(2180, 110.0, 104.0, 106.0));
   Check(ApplyRuntimeStructure(earlyBreakEngine, JINPA_REGIME_TREND,
                               JINPA_STATE_IMPULSE, source, earlyRates,
                               earlyState) == "CONTINUATION",
         "MICRO_BASE_04_PRE_MIN_CLOSE_BREAK_RESETS_CANDIDATE");

   AppendBar(rates, ClosedBar(1180, 112.0, 108.0, 111.0));
   Check(ApplyRuntimeStructure(engine, JINPA_REGIME_TREND,
                               JINPA_STATE_IMPULSE, source, rates,
                               symbolState) == "CONTINUATION",
         "MICRO_BASE_05_BULL_TREND_BREAK_CONTINUATION");

   CMarketStructureEngine bearEngine;
   PriceStructureState bearSource = BaseStructureState();
   bearSource.cycleState.cycle = MARKET_CYCLE_BEAR;
   MqlRates bearRates[];
   SymbolState bearState;
   bearState.structure = "CONTINUATION";
   AppendBar(bearRates, ClosedBar(3000, 110.0, 100.0, 102.0));
   ApplyRuntimeStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, bearSource, bearRates,
                         bearState);
   AppendBar(bearRates, ClosedBar(3060, 109.0, 99.0, 103.0));
   ApplyRuntimeStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, bearSource, bearRates,
                         bearState);
   AppendBar(bearRates, ClosedBar(3120, 108.0, 101.0, 104.0));
   ApplyRuntimeStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, bearSource, bearRates,
                         bearState);
   AppendBar(bearRates, ClosedBar(3180, 101.0, 98.0, 99.0));
   Check(ApplyRuntimeStructure(bearEngine, JINPA_REGIME_TREND,
                               JINPA_STATE_IMPULSE, bearSource,
                               bearRates, bearState) == "CONTINUATION",
         "MICRO_BASE_06_BEAR_TREND_BREAK_CONTINUATION");

   CMarketStructureEngine correctionEngine;
   MqlRates correctionRates[];
   SymbolState correctionState;
   correctionState.structure = "CONTINUATION";
   AppendBar(correctionRates, ClosedBar(4000, 110.0, 100.0, 108.0));
   ApplyRuntimeStructure(correctionEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, correctionRates,
                         correctionState);
   AppendBar(correctionRates, ClosedBar(4060, 109.0, 101.0, 107.0));
   ApplyRuntimeStructure(correctionEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, correctionRates,
                         correctionState);
   AppendBar(correctionRates, ClosedBar(4120, 108.0, 102.0, 106.0));
   ApplyRuntimeStructure(correctionEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, correctionRates,
                         correctionState);
   source.sidewayBox.leg1Confirmed = true;
   AppendBar(correctionRates, ClosedBar(4180, 107.0, 101.0, 103.0));
   Check(ApplyRuntimeStructure(correctionEngine, JINPA_REGIME_TREND,
                               JINPA_STATE_CORRECTION, source,
                               correctionRates, correctionState) == "NONE",
         "MICRO_BASE_07_CORRECTION_LEG_AUTHORITY");
   source.sidewayBox.leg1Confirmed = false;

   CMarketStructureEngine timeoutEngine;
   MqlRates timeoutRates[];
   SymbolState timeoutState;
   timeoutState.structure = "CONTINUATION";
   for(int index = 0; index < 9; index++)
   {
      AppendBar(timeoutRates, ClosedBar(5000 + index * 60,
                                        110.0, 100.0, 105.0));
      ApplyRuntimeStructure(timeoutEngine, JINPA_REGIME_TREND,
                            JINPA_STATE_IMPULSE, source, timeoutRates,
                            timeoutState);
   }
   Check(timeoutState.structure == "CONTINUATION",
         "MICRO_BASE_08_TIMEOUT_AFTER_EIGHT_BARS");

   CMarketStructureEngine sidewayEngine;
   PriceStructureState sidewaySource = BaseStructureState();
   sidewaySource.sidewayBox.active = true;
   sidewaySource.sidewayBox.sidewayConfirmed = true;
   sidewaySource.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   sidewaySource.sidewayBox.boxHigh = 110.0;
   sidewaySource.sidewayBox.boxLow = 90.0;
   MqlRates sidewayRates[];
   SymbolState sidewayState;
   sidewayState.structure = "CONTINUATION";
   AppendBar(sidewayRates, ClosedBar(6000, 101.0, 99.0, 100.0));
   Check(ApplyRuntimeStructure(sidewayEngine, JINPA_REGIME_RANGE,
                               JINPA_STATE_COMPRESSION, sidewaySource,
                               sidewayRates, sidewayState) == "SIDEWAY",
         "MICRO_BASE_09_SIDEWAY_CONTEXT_EXCLUDED");

   CMarketStructureEngine priorEngine;
   MqlRates priorRates[];
   SymbolState priorState;
   priorState.structure = "BREAKOUT";
   AppendBar(priorRates, ClosedBar(7000, 110.0, 100.0, 108.0));
   ApplyRuntimeStructure(priorEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, priorRates,
                         priorState);
   AppendBar(priorRates, ClosedBar(7060, 109.0, 101.0, 107.0));
   ApplyRuntimeStructure(priorEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, source, priorRates,
                         priorState);
   AppendBar(priorRates, ClosedBar(7120, 108.0, 102.0, 106.0));
   Check(ApplyRuntimeStructure(priorEngine, JINPA_REGIME_TREND,
                               JINPA_STATE_IMPULSE, source, priorRates,
                               priorState) == "CONTINUATION",
         "MICRO_BASE_10_REQUIRES_PRIOR_CONTINUATION_BEFORE_ANCHOR");
}

void TestMicroBaseVisualOnly(void)
{
   CMicroBaseRenderer renderer;
   renderer.Destroy();
   const string prefix = "JINPA_MICRO_BASE_" + _Symbol + "_"
                         + IntegerToString((int)_Period) + "_";
   const string highA = prefix + "5000_HIGH";
   const string lowA = prefix + "5000_LOW";

   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   false, 5000, 5120, 110.0, 100.0);
   Check(ObjectFind(0, highA) < 0 && ObjectFind(0, lowA) < 0,
         "MICRO_VISUAL_01_UNCONFIRMED_HAS_NO_OBJECTS");

   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   true, 5000, 5120, 110.0, 100.0);
   Check(ObjectFind(0, highA) >= 0 && ObjectFind(0, lowA) >= 0
         && ObjectGetDouble(0, highA, OBJPROP_PRICE, 0) == 110.0
         && ObjectGetDouble(0, lowA, OBJPROP_PRICE, 0) == 100.0
         && (color)ObjectGetInteger(0, highA, OBJPROP_COLOR) == clrWhite
         && ObjectGetInteger(0, highA, OBJPROP_STYLE) == STYLE_SOLID
         && ObjectGetInteger(0, highA, OBJPROP_WIDTH) == 1,
         "MICRO_VISUAL_02_CONFIRMED_DRAWS_WHITE_BASE_PAIR");

   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   true, 5000, 5180, 110.0, 100.0);
   Check((datetime)ObjectGetInteger(0, highA, OBJPROP_TIME, 1) == 5180
         && (datetime)ObjectGetInteger(0, lowA,
                                       OBJPROP_TIME, 1) == 5180,
         "MICRO_VISUAL_03_CONFIRMED_PAIR_EXTENDS");

   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   false, 0, 5240, 0.0, 0.0);
   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   false, 0, 5300, 0.0, 0.0);
   Check(ObjectFind(0, highA) >= 0 && ObjectFind(0, lowA) >= 0
         && (datetime)ObjectGetInteger(0, highA,
                                       OBJPROP_TIME, 1) == 5240,
         "MICRO_VISUAL_04_ENDED_PAIR_FREEZES_AND_REMAINS");

   const string highB = prefix + "6000_HIGH";
   const string lowB = prefix + "6000_LOW";
   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   true, 6000, 6120, 120.0, 115.0);
   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   false, 0, 6180, 0.0, 0.0);
   Check(ObjectFind(0, highA) >= 0 && ObjectFind(0, lowA) >= 0
         && ObjectFind(0, highB) >= 0 && ObjectFind(0, lowB) >= 0,
         "MICRO_VISUAL_05_CONFIRMED_HISTORIES_HAVE_UNIQUE_IDENTITIES");
   renderer.Destroy();
}

void TestFirstMicroBasePerImpulse(void)
{
   PriceStructureState source = BaseStructureState();
   source.cycleState.cycle = MARKET_CYCLE_BULL;
   CMarketStructureEngine engine;
   CMicroBaseRenderer renderer;
   renderer.Destroy();
   MqlRates rates[];
   SymbolState state;
   state.structure = "BREAKOUT";
   const datetime firstImpulse = 1000;

   AppendBar(rates, ClosedBar(1000, 112.0, 102.0, 110.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   Check(!engine.MicroBaseConsumed()
         && engine.MicroBaseImpulseStartTime() == firstImpulse,
         "MICRO_FIRST_01_NEW_IMPULSE_STARTS_UNCONSUMED");

   AppendBar(rates, ClosedBar(1060, 110.0, 100.0, 108.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   AppendBar(rates, ClosedBar(1120, 112.0, 109.0, 111.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   Check(!engine.MicroBaseConsumed() && !engine.MicroBaseConfirmed(),
         "MICRO_FIRST_02_FAILED_CANDIDATE_DOES_NOT_CONSUME");

   AppendBar(rates, ClosedBar(1180, 109.0, 101.0, 105.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   AppendBar(rates, ClosedBar(1240, 111.0, 99.0, 106.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   AppendBar(rates, ClosedBar(1300, 110.0, 100.0, 107.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   engine.MicroBaseConfirmed(),
                   engine.MicroBaseAnchorTime(), 1300,
                   engine.MicroBaseHigh(), engine.MicroBaseLow());
   const string prefix = "JINPA_MICRO_BASE_" + _Symbol + "_"
                         + IntegerToString((int)_Period) + "_";
   const string firstHigh = prefix + "1180_HIGH";
   Check(state.structure == "MICRO BASE"
         && engine.MicroBaseConfirmed()
         && engine.MicroBaseConsumed()
         && ObjectFind(0, firstHigh) >= 0,
         "MICRO_FIRST_03_LATER_CONFIRMED_BASE_CONSUMES_IMPULSE");

   AppendBar(rates, ClosedBar(1360, 111.0, 109.5, 110.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   engine.MicroBaseConfirmed(),
                   engine.MicroBaseAnchorTime(), 1360,
                   engine.MicroBaseHigh(), engine.MicroBaseLow());
   Check(state.structure == "CONTINUATION"
         && engine.MicroBaseConsumed()
         && (datetime)ObjectGetInteger(0, firstHigh,
                                       OBJPROP_TIME, 1) == 1360,
         "MICRO_FIRST_04_BREAK_KEEPS_CONSUMED_AND_FREEZES_VISUAL");

   AppendBar(rates, ClosedBar(1420, 120.0, 110.0, 115.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   AppendBar(rates, ClosedBar(1480, 121.0, 109.0, 116.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   AppendBar(rates, ClosedBar(1540, 122.0, 108.0, 117.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, state);
   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   engine.MicroBaseConfirmed(),
                   engine.MicroBaseAnchorTime(), 1540,
                   engine.MicroBaseHigh(), engine.MicroBaseLow());
   Check(state.structure == "CONTINUATION"
         && engine.MicroBaseConsumed()
         && !engine.MicroBaseConfirmed(),
         "MICRO_FIRST_05_SECOND_PATTERN_SAME_IMPULSE_IS_BLOCKED");
   Check(ObjectFind(0, prefix + "1420_HIGH") < 0
         && ObjectFind(0, firstHigh) >= 0,
         "MICRO_FIRST_06_NO_SECOND_VISUAL_IN_SAME_IMPULSE");

   CMarketStructureEngine rebuiltEngine;
   SymbolState rebuiltState;
   rebuiltState.structure = "UNKNOWN";
   ApplyImpulseStructure(rebuiltEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, firstImpulse,
                         source, rates, rebuiltState);
   Check(rebuiltState.structure == "CONTINUATION"
         && rebuiltEngine.MicroBaseConsumed()
         && !rebuiltEngine.MicroBaseConfirmed(),
         "MICRO_FIRST_07_REBUILD_RESTORES_CONSUMED_LATCH");

   AppendBar(rates, ClosedBar(1600, 118.0, 108.0, 112.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_CORRECTION, firstImpulse,
                         source, rates, state);
   const datetime secondImpulse = 2000;
   AppendBar(rates, ClosedBar(2000, 132.0, 122.0, 130.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, secondImpulse,
                         source, rates, state);
   Check(!engine.MicroBaseConsumed()
         && engine.MicroBaseImpulseStartTime() == secondImpulse,
         "MICRO_FIRST_08_NEW_IMPULSE_RESETS_CONSUMED");

   AppendBar(rates, ClosedBar(2060, 130.0, 120.0, 125.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, secondImpulse,
                         source, rates, state);
   AppendBar(rates, ClosedBar(2120, 131.0, 119.0, 126.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, secondImpulse,
                         source, rates, state);
   AppendBar(rates, ClosedBar(2180, 132.0, 118.0, 127.0));
   ApplyImpulseStructure(engine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, secondImpulse,
                         source, rates, state);
   renderer.Update(_Symbol, (ENUM_TIMEFRAMES)_Period,
                   engine.MicroBaseConfirmed(),
                   engine.MicroBaseAnchorTime(), 2180,
                   engine.MicroBaseHigh(), engine.MicroBaseLow());
   Check(state.structure == "MICRO BASE"
         && engine.MicroBaseConsumed()
         && ObjectFind(0, prefix + "2060_HIGH") >= 0
         && ObjectFind(0, firstHigh) >= 0,
         "MICRO_FIRST_09_NEW_IMPULSE_ACCEPTS_ONE_NEW_BASE");
   renderer.Destroy();

   PriceStructureState bearSource = BaseStructureState();
   bearSource.cycleState.cycle = MARKET_CYCLE_BEAR;
   CMarketStructureEngine bearEngine;
   MqlRates bearRates[];
   SymbolState bearState;
   bearState.structure = "BREAKOUT";
   AppendBar(bearRates, ClosedBar(3000, 210.0, 198.0, 200.0));
   ApplyImpulseStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, 3000,
                         bearSource, bearRates, bearState);
   AppendBar(bearRates, ClosedBar(3060, 210.0, 200.0, 205.0));
   ApplyImpulseStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, 3000,
                         bearSource, bearRates, bearState);
   AppendBar(bearRates, ClosedBar(3120, 211.0, 199.0, 204.0));
   ApplyImpulseStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, 3000,
                         bearSource, bearRates, bearState);
   AppendBar(bearRates, ClosedBar(3180, 212.0, 198.0, 203.0));
   ApplyImpulseStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, 3000,
                         bearSource, bearRates, bearState);
   AppendBar(bearRates, ClosedBar(3240, 200.0, 198.0, 199.0));
   ApplyImpulseStructure(bearEngine, JINPA_REGIME_TREND,
                         JINPA_STATE_IMPULSE, 3000,
                         bearSource, bearRates, bearState);
   Check(bearState.structure == "CONTINUATION"
         && bearEngine.MicroBaseConsumed()
         && !bearEngine.MicroBaseConfirmed(),
         "MICRO_FIRST_10_BEAR_CONFIRM_AND_BREAK_IS_SYMMETRIC");
}

void TestPanelValue(void)
{
   SymbolState states[1];
   states[0].symbol = _Symbol;
   states[0].timeframe = (ENUM_TIMEFRAMES)_Period;
   states[0].cycle = "BULL";
   states[0].regime = "TREND";
   states[0].state = "IMPULSE";
   states[0].structure = "CONTINUATION";
   states[0].setup = "-";
   states[0].setupStatus = "NONE";
   states[0].lastEvent = "CORE BREAK CONFIRMED";
   states[0].isReady = true;

   CMarketRadar radar;
   radar.Configure(true, CORNER_RIGHT_LOWER, 15, 20, 20, 9);
   const bool created = radar.Create(states);
   radar.Update(states, true);
   Check(created
         && ObjectGetString(0, "JINPA_RADAR_HEADER_05", OBJPROP_TEXT)
            == "STRUCTURE"
         && ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_05", OBJPROP_TEXT)
            == "CONTINUATION",
         "WATCH_PANEL_STRUCTURE_COLUMN_VALUE");
   states[0].structure = "RANGE EDGE";
   radar.Update(states, true);
   const bool rangeEdgeDisplayed =
      ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_05", OBJPROP_TEXT)
      == "RANGE EDGE";
   states[0].structure = "REJECTION";
   radar.Update(states, true);
   const bool rejectionDisplayed =
      ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_05", OBJPROP_TEXT)
      == "REJECTION";
   states[0].structure = "FALSE BREAK";
   radar.Update(states, true);
   const bool falseBreakDisplayed =
      ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_05", OBJPROP_TEXT)
      == "FALSE BREAK";
   states[0].structure = "MICRO BASE";
   radar.Update(states, true);
   const bool microBaseDisplayed =
      ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_05", OBJPROP_TEXT)
      == "MICRO BASE";
   Check(rangeEdgeDisplayed && rejectionDisplayed && falseBreakDisplayed
         && microBaseDisplayed,
         "WATCH_PANEL_EXTENDED_STRUCTURE_VALUES");
   radar.Destroy();
}

int OnInit(void)
{
   TestRequiredCases();
   TestFlowsAndAuthority();
   TestRangeContextExtensions();
   TestMicroBaseLifecycle();
   TestMicroBaseVisualOnly();
   TestFirstMicroBasePerImpulse();
   TestPanelValue();
   Print("[MARKET_STRUCTURE_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
