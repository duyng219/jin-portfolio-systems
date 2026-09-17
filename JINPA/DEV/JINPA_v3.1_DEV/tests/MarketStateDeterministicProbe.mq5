#property strict
#property version "1.10"
#property description "JINPA v3.1 DEV Stage 3 Market State transition probe"

#include "../watch/state/MarketStateEngine.mqh"
#include "../watch/ui/MarketRadar.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[MARKET_STATE_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[MARKET_STATE_TEST][FAIL] ", name);
   }
}

PriceStructureState BaseState(const ENUM_MARKET_CYCLE cycle)
{
   PriceStructureState state;
   ResetPriceStructureState(state);
   state.initialized = true;
   state.coreBox.valid = true;
   state.coreBox.lifecycle = CORE_BOX_COMPLETE;
   state.coreBox.cycle = cycle;
   state.cycleState.cycle = cycle;
   return state;
}

void AddBar(MqlRates &bars[], const datetime time, const double close,
            const double high = 0.0, const double low = 0.0)
{
   const int index = ArraySize(bars);
   ArrayResize(bars, index + 1);
   ZeroMemory(bars[index]);
   bars[index].time = time;
   bars[index].open = close;
   bars[index].high = high > 0.0 ? high : close;
   bars[index].low = low > 0.0 ? low : close;
   bars[index].close = close;
}

void AddEvent(StructureEvent &events[], const ENUM_STRUCTURE_EVENT_TYPE type,
              const datetime time, const ENUM_MARKET_CYCLE cycle)
{
   const int index = ArraySize(events);
   ArrayResize(events, index + 1);
   ZeroMemory(events[index]);
   events[index].type = type;
   events[index].eventBarTime = time;
   events[index].cycleBefore = cycle;
   events[index].cycleAfter = cycle;
}

void AddExtreme(SwingPoint &swings[], const ENUM_MARKET_CYCLE cycle,
                const datetime pivotTime, const datetime confirmationTime)
{
   const int index = ArraySize(swings);
   ArrayResize(swings, index + 1);
   ResetSwingPoint(swings[index]);
   swings[index].time = pivotTime;
   swings[index].confirmationTime = confirmationTime;
   swings[index].confirmed = true;
   swings[index].type = cycle == MARKET_CYCLE_BULL ? SWING_HIGH : SWING_LOW;
   swings[index].classification = cycle == MARKET_CYCLE_BULL
                                   ? STRUCT_HH : STRUCT_LL;
}

bool Resolve(CMarketStateEngine &engine, PriceStructureState &source,
             SwingPoint &swings[], StructureEvent &events[], MqlRates &bars[],
             const datetime through,
             const ENUM_JINPA_MARKET_REGIME regime,
             const ENUM_JINPA_MARKET_STATE state)
{
   engine.Rebuild(source, swings, events, bars, through);
   return engine.Regime() == regime && engine.State() == state;
}

void TestExpansionImpulseCases()
{
   SwingPoint swings[];
   StructureEvent events[];
   MqlRates bars[];
   CMarketStateEngine engine;
   PriceStructureState bull = BaseState(MARKET_CYCLE_BULL);
   AddBar(bars, 1000, 100.0, 102.0, 99.0);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, MARKET_CYCLE_BULL);
   AddBar(bars, 1060, 101.0);
   Check(Resolve(engine, bull, swings, events, bars, 1060,
                 JINPA_REGIME_TREND, JINPA_STATE_IMPULSE),
         "CASE_E1_BULL_IMMEDIATE_CONTINUATION");

   ArrayResize(bars, 1);
   AddBar(bars, 1060, 99.8);
   AddBar(bars, 1120, 99.9);
   AddBar(bars, 1180, 100.1);
   const bool delayed = Resolve(engine, bull, swings, events, bars, 1060,
                                JINPA_REGIME_TREND, JINPA_STATE_EXPANSION)
                        && Resolve(engine, bull, swings, events, bars, 1120,
                                   JINPA_REGIME_TREND, JINPA_STATE_EXPANSION)
                        && Resolve(engine, bull, swings, events, bars, 1180,
                                   JINPA_REGIME_TREND, JINPA_STATE_IMPULSE)
                        && engine.BreakoutClose() == 100.0;
   Check(delayed, "CASE_E2_BULL_DELAYED_FIXED_REFERENCE");

   ArrayResize(bars, 1);
   AddBar(bars, 1060, 100.5);
   Check(Resolve(engine, bull, swings, events, bars, 1060,
                 JINPA_REGIME_TREND, JINPA_STATE_IMPULSE)
         && engine.BreakoutClose() == 100.0,
         "CASE_E3_BULL_WICK_NOISE_USES_BREAKOUT_CLOSE");

   PriceStructureState bear = BaseState(MARKET_CYCLE_BEAR);
   ArrayResize(events, 0);
   ArrayResize(bars, 0);
   AddBar(bars, 1000, 100.0);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, MARKET_CYCLE_BEAR);
   AddBar(bars, 1060, 100.2);
   AddBar(bars, 1120, 99.8);
   Check(Resolve(engine, bear, swings, events, bars, 1060,
                 JINPA_REGIME_TREND, JINPA_STATE_EXPANSION)
         && Resolve(engine, bear, swings, events, bars, 1120,
                    JINPA_REGIME_TREND, JINPA_STATE_IMPULSE),
         "CASE_E4_BEAR_SYMMETRIC_DELAYED_CONTINUATION");

   Check(Resolve(engine, bear, swings, events, bars, 1000,
                 JINPA_REGIME_TREND, JINPA_STATE_EXPANSION),
         "CASE_E5_BREAKOUT_CANDLE_CANNOT_SELF_TRIGGER");
}

void TestImpulseCorrectionCases()
{
   CMarketStateEngine engine;
   SwingPoint swings[];
   StructureEvent events[];
   MqlRates bars[];
   PriceStructureState bull = BaseState(MARKET_CYCLE_BULL);
   AddBar(bars, 1000, 100.0);
   AddBar(bars, 1060, 100.5);
   AddBar(bars, 1120, 100.4);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, MARKET_CYCLE_BULL);
   AddExtreme(swings, MARKET_CYCLE_BULL, 1040, 1120);
   Check(Resolve(engine, bull, swings, events, bars, 1060,
                 JINPA_REGIME_TREND, JINPA_STATE_IMPULSE)
         && Resolve(engine, bull, swings, events, bars, 1120,
                    JINPA_REGIME_TREND, JINPA_STATE_CORRECTION),
         "CASE_I1_BULL_NEW_HH_AFTER_IMPULSE");

   PriceStructureState bear = BaseState(MARKET_CYCLE_BEAR);
   ArrayResize(swings, 0);
   ArrayResize(events, 0);
   ArrayResize(bars, 0);
   AddBar(bars, 1000, 100.0);
   AddBar(bars, 1060, 99.5);
   AddBar(bars, 1120, 99.6);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, MARKET_CYCLE_BEAR);
   AddExtreme(swings, MARKET_CYCLE_BEAR, 1040, 1120);
   Check(Resolve(engine, bear, swings, events, bars, 1060,
                 JINPA_REGIME_TREND, JINPA_STATE_IMPULSE)
         && Resolve(engine, bear, swings, events, bars, 1120,
                    JINPA_REGIME_TREND, JINPA_STATE_CORRECTION),
         "CASE_I2_BEAR_NEW_LL_AFTER_IMPULSE");

   ArrayResize(swings, 0);
   AddExtreme(swings, MARKET_CYCLE_BULL, 900, 1000);
   ArrayResize(events, 0);
   ArrayResize(bars, 0);
   AddBar(bars, 1000, 100.0);
   AddBar(bars, 1060, 100.5);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, MARKET_CYCLE_BULL);
   Check(Resolve(engine, bull, swings, events, bars, 1060,
                 JINPA_REGIME_TREND, JINPA_STATE_IMPULSE),
         "CASE_I3_OLD_HH_EXCLUDED");

   ArrayResize(swings, 0);
   AddExtreme(swings, MARKET_CYCLE_BEAR, 900, 1000);
   ArrayResize(events, 0);
   ArrayResize(bars, 0);
   AddBar(bars, 1000, 100.0);
   AddBar(bars, 1060, 99.5);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, MARKET_CYCLE_BEAR);
   Check(Resolve(engine, bear, swings, events, bars, 1060,
                 JINPA_REGIME_TREND, JINPA_STATE_IMPULSE),
         "CASE_I4_OLD_LL_EXCLUDED");

   AddBar(bars, 1120, 99.6);
   AddExtreme(swings, MARKET_CYCLE_BEAR, 1040, 1120);
   const bool beforeLeg = Resolve(engine, bear, swings, events, bars, 1120,
                                  JINPA_REGIME_TREND,
                                  JINPA_STATE_CORRECTION)
                          && !bear.sidewayBox.leg1Confirmed;
   bear.sidewayBox.leg1Confirmed = true;
   Check(beforeLeg
         && Resolve(engine, bear, swings, events, bars, 1120,
                    JINPA_REGIME_TREND, JINPA_STATE_CORRECTION),
         "CASE_I5_CORRECTION_PRECEDES_AND_PERSISTS_THROUGH_LEG1");
}

bool FullCycle(const ENUM_MARKET_CYCLE cycle)
{
   CMarketStateEngine engine;
   SwingPoint swings[];
   StructureEvent events[];
   MqlRates bars[];
   PriceStructureState source = BaseState(cycle);
   AddBar(bars, 900, 100.0);
   AddBar(bars, 1000, 100.0);
   AddBar(bars, 1060, cycle == MARKET_CYCLE_BULL ? 100.5 : 99.5);
   AddBar(bars, 1120, cycle == MARKET_CYCLE_BULL ? 100.4 : 99.6);
   AddBar(bars, 1180, 100.0);
   AddEvent(events, SIDEWAY_CONFIRMED, 900, cycle);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, cycle);
   AddExtreme(swings, cycle, 1040, 1120);
   AddEvent(events, SIDEWAY_CONFIRMED, 1180, cycle);

   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   const bool compression = Resolve(engine, source, swings, events, bars, 900,
                                    JINPA_REGIME_RANGE,
                                    JINPA_STATE_COMPRESSION);
   ResetSidewayBoxState(source.sidewayBox);
   const bool expansion = Resolve(engine, source, swings, events, bars, 1000,
                                  JINPA_REGIME_TREND,
                                  JINPA_STATE_EXPANSION);
   const bool impulse = Resolve(engine, source, swings, events, bars, 1060,
                                JINPA_REGIME_TREND,
                                JINPA_STATE_IMPULSE);
   const bool correction = Resolve(engine, source, swings, events, bars, 1120,
                                   JINPA_REGIME_TREND,
                                   JINPA_STATE_CORRECTION);
   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   const bool recompression = Resolve(engine, source, swings, events, bars,
                                      1180, JINPA_REGIME_RANGE,
                                      JINPA_STATE_COMPRESSION);
   return compression && expansion && impulse && correction && recompression;
}

void TestLifecycleGuards()
{
   Check(FullCycle(MARKET_CYCLE_BULL), "FULL_CYCLE_BULL");
   Check(FullCycle(MARKET_CYCLE_BEAR), "FULL_CYCLE_BEAR");

   CMarketStateEngine engine;
   SwingPoint swings[];
   StructureEvent events[];
   MqlRates bars[];
   PriceStructureState source = BaseState(MARKET_CYCLE_BULL);
   AddBar(bars, 1000, 100.0);
   AddBar(bars, 1060, 100.5);
   AddBar(bars, 1120, 100.4);
   AddBar(bars, 1140, 100.3);
   AddBar(bars, 1180, 101.0);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1000, MARKET_CYCLE_BULL);
   AddExtreme(swings, MARKET_CYCLE_BULL, 1040, 1120);
   AddEvent(events, CORE_BREAK_FAILED, 1140, MARKET_CYCLE_BULL);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 1180, MARKET_CYCLE_BEAR);
   Check(Resolve(engine, source, swings, events, bars, 1140,
                 JINPA_REGIME_TREND, JINPA_STATE_CORRECTION),
         "FALSE_BREAK_DOES_NOT_CHANGE_CORRECTION");
   source.cycleState.cycle = MARKET_CYCLE_BEAR;
   source.coreBox.cycle = MARKET_CYCLE_BEAR;
   Check(Resolve(engine, source, swings, events, bars, 1180,
                 JINPA_REGIME_TREND, JINPA_STATE_EXPANSION)
         && engine.Cycle() == MARKET_CYCLE_BEAR
         && engine.BreakoutTime() == 1180 && engine.BreakoutClose() == 101.0,
         "CONFIRMED_BREAK_OVERRIDES_AND_RESETS_LIFECYCLE");

   source.sidewayBox.active = true;
   source.sidewayBox.sidewayConfirmed = true;
   source.sidewayBox.status = SIDEWAY_BOX_ACTIVE;
   Check(Resolve(engine, source, swings, events, bars, 1180,
                 JINPA_REGIME_RANGE, JINPA_STATE_COMPRESSION),
         "SIDEWAY_ACTIVE_FINAL_AUTHORITY");

   source = BaseState(MARKET_CYCLE_BULL);
   ArrayResize(events, 0);
   ArrayResize(swings, 0);
   ArrayResize(bars, 0);
   AddBar(bars, 2000, 100.0);
   AddBar(bars, 2060, 100.5);
   AddBar(bars, 2120, 100.4);
   AddEvent(events, CORE_BOX_TRANSITION_STARTED, 2000,
            MARKET_CYCLE_BULL);
   AddExtreme(swings, MARKET_CYCLE_BULL, 2040, 2120);
   CMarketStateEngine restarted;
   const bool bootstrapFinal = Resolve(restarted, source, swings, events,
                                       bars, 2120, JINPA_REGIME_TREND,
                                       JINPA_STATE_CORRECTION);
   CMarketStateEngine forward;
   Resolve(forward, source, swings, events, bars, 2000,
           JINPA_REGIME_TREND, JINPA_STATE_EXPANSION);
   Resolve(forward, source, swings, events, bars, 2060,
           JINPA_REGIME_TREND, JINPA_STATE_IMPULSE);
   const bool forwardFinal = Resolve(forward, source, swings, events, bars,
                                     2120, JINPA_REGIME_TREND,
                                     JINPA_STATE_CORRECTION);
   Check(bootstrapFinal && forwardFinal
         && restarted.BreakoutTime() == forward.BreakoutTime()
         && restarted.BreakoutClose() == forward.BreakoutClose()
         && restarted.ImpulseStartTime() == forward.ImpulseStartTime(),
         "BOOTSTRAP_REPLAY_EQUALS_FORWARD_RESULT");
}

int CountRadarObjects()
{
   int count = 0;
   const int total = ObjectsTotal(0, -1, -1);
   for(int index = 0; index < total; index++)
      if(StringFind(ObjectName(0, index, -1, -1), "JINPA_RADAR_") == 0)
         count++;
   return count;
}

void TestPanelContract()
{
   SymbolState states[1];
   states[0].symbol = _Symbol;
   states[0].timeframe = (ENUM_TIMEFRAMES)_Period;
   states[0].cycle = "BULL";
   states[0].regime = "RANGE";
   states[0].state = "COMPRESSION";
   states[0].structure = "PLACEHOLDER";
   states[0].setup = "-";
   states[0].setupStatus = "NONE";
   states[0].lastEvent = "SIDEWAY CONFIRMED";
   states[0].isReady = true;

   CMarketRadar radar;
   radar.Configure(true, CORNER_RIGHT_LOWER, 15, 20, 20, 9);
   const bool created = radar.Create(states);
   radar.Update(states, true);
   const string expected[8] = {"SYMBOL", "TF", "CYCLE", "REGIME", "STATE",
                               "STRUCTURE", "SETUP", "STATUS"};
   bool headers = true;
   for(int column = 0; column < 8; column++)
      headers = headers && ObjectGetString(0, "JINPA_RADAR_HEADER_"
         + IntegerToString(column, 2, '0'), OBJPROP_TEXT) == expected[column];
   Check(created && headers, "PANEL_A_EXACT_EIGHT_HEADERS");
   Check(ObjectFind(0, "JINPA_RADAR_HEADER_08") < 0,
         "PANEL_B_NO_LAST_EVENT_MAIN_COLUMN");
   Check(ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_03", OBJPROP_TEXT)
         == "RANGE" && ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_04",
         OBJPROP_TEXT) == "COMPRESSION", "PANEL_C_REGIME_STATE_VALUES");
   Check(ObjectGetString(0, "JINPA_RADAR_TITLE", OBJPROP_TEXT)
         == "JINPA WATCH v1.1"
         && StringFind(ObjectGetString(0, "JINPA_RADAR_HEADER_UPDATED",
                                      OBJPROP_TEXT), "UPDATED: ") == 0
         && (int)ObjectGetInteger(0, "JINPA_RADAR_HEADER_UPDATED",
                                  OBJPROP_FONTSIZE) == 8
         && ObjectFind(0, "JINPA_RADAR_FOOTER_TF") < 0
         && ObjectGetString(0, "JINPA_RADAR_FOOTER_EVENT", OBJPROP_TEXT)
            == "LAST EVENT: SIDEWAY CONFIRMED",
         "PANEL_D_ACCEPTED_HEADER_FOOTER_CONTRACT");
   states[0].regime = "TREND";
   states[0].state = "EXPANSION";
   states[0].lastEvent = "CORE BREAK CONFIRMED";
   radar.Update(states, true);
   Check(ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_03", OBJPROP_TEXT)
         == "TREND" && ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_04",
         OBJPROP_TEXT) == "EXPANSION", "PANEL_E_UPDATED_STATE_VALUE");
   Check(CountRadarObjects() == 26, "PANEL_F_NO_DUPLICATE_OBJECTS");
   radar.Destroy();
   Check(CountRadarObjects() == 0, "PANEL_G_DESTROY_CLEAN");
}

int OnInit()
{
   TestExpansionImpulseCases();
   TestImpulseCorrectionCases();
   TestLifecycleGuards();
   Print("[MARKET_STATE_TEST][SEMANTIC_SUMMARY] passed=", g_passed,
         " failed=", g_failed);
   TestPanelContract();
   Print("[MARKET_STATE_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick() { ExpertRemove(); }
