#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Pullback Setup deterministic probe"

#include "../watch/setup/PullbackSetupEngine.mqh"
#include "../watch/ui/MarketRadar.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[PULLBACK_SETUP_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[PULLBACK_SETUP_TEST][FAIL] ", name);
   }
}

PriceStructureState SetupSource(const ENUM_MARKET_CYCLE cycle)
{
   PriceStructureState source;
   ResetPriceStructureState(source);
   source.initialized = true;
   source.cycleState.cycle = cycle;
   return source;
}

MqlRates SetupBar(const datetime time, const double high,
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

void AddSetupBar(MqlRates &rates[], const MqlRates &bar)
{
   const int index = ArraySize(rates);
   ArrayResize(rates, index + 1);
   rates[index] = bar;
}

SwingPoint SetupSwing(const ENUM_SWING_TYPE type,
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

bool ApplySetup(CPullbackSetupEngine &engine,
                const string previousState,
                const ENUM_JINPA_MARKET_STATE state,
                const string structure,
                PriceStructureState &source,
                SwingPoint &swings[], MqlRates &rates[],
                SymbolState &symbolState)
{
   return engine.Apply(previousState, state, structure, source, swings,
                       rates, rates[ArraySize(rates) - 1].time,
                       symbolState);
}

void TestPpfLifecycle(void)
{
   CPullbackSetupEngine engine;
   PriceStructureState source = SetupSource(MARKET_CYCLE_BULL);
   SwingPoint swings[];
   MqlRates rates[];
   SymbolState state;
   state.setup = "-";
   state.setupStatus = "NONE";

   AddSetupBar(rates, SetupBar(1000, 110.0, 100.0, 105.0));
   Check(ApplySetup(engine, "IMPULSE", JINPA_STATE_CORRECTION,
                    "NONE", source, swings, rates, state)
         && state.setup == "revs-ppf" && state.setupStatus == "WATCH"
         && engine.BaseHigh() == 110.0 && engine.BaseLow() == 100.0
         && engine.BaseTime() == 1000,
         "PPF_01_CORRECTION_STARTS_WATCH_WITH_INITIAL_BASE");

   Check(!ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
                     "NONE", source, swings, rates, state)
         && state.setupStatus == "WATCH" && engine.BaseTime() == 1000,
         "PPF_02_NO_NEW_CLOSED_BAR_NO_TRANSITION");

   AddSetupBar(rates, SetupBar(1060, 109.0, 101.0, 108.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "NONE", source, swings, rates, state);
   Check(state.setupStatus == "WATCH" && engine.BaseHigh() == 109.0
         && engine.BaseLow() == 101.0 && engine.BaseTime() == 1060,
         "PPF_03_BULL_WATCH_ROLLS_BASE");

   AddSetupBar(rates, SetupBar(1120, 111.0, 108.0, 109.5));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "NONE", source, swings, rates, state);
   Check(state.setup == "revs-ppf" && state.setupStatus == "ACTIVE"
         && engine.TriggerBarTime() == 1120,
         "PPF_04_BULL_CLOSE_ABOVE_PREVIOUS_BASE_HIGH_ACTIVE");

   AddSetupBar(rates, SetupBar(1180, 110.0, 105.0, 106.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "NONE", source, swings, rates, state);
   Check(state.setup == "revs-ppf" && state.setupStatus == "INVALID",
         "PPF_05_ACTIVE_NEXT_BAR_INVALID");

   CPullbackSetupEngine bearEngine;
   PriceStructureState bearSource = SetupSource(MARKET_CYCLE_BEAR);
   MqlRates bearRates[];
   SymbolState bearState;
   bearState.setup = "-";
   bearState.setupStatus = "NONE";
   AddSetupBar(bearRates, SetupBar(2000, 110.0, 100.0, 105.0));
   ApplySetup(bearEngine, "IMPULSE", JINPA_STATE_CORRECTION,
              "NONE", bearSource, swings, bearRates, bearState);
   AddSetupBar(bearRates, SetupBar(2060, 102.0, 98.0, 99.0));
   ApplySetup(bearEngine, "CORRECTION", JINPA_STATE_CORRECTION,
              "NONE", bearSource, swings, bearRates, bearState);
   Check(bearState.setup == "revs-ppf"
         && bearState.setupStatus == "ACTIVE",
         "PPF_06_BEAR_CLOSE_BELOW_PREVIOUS_BASE_LOW_ACTIVE");
}

void TestPpsLifecycle(void)
{
   CPullbackSetupEngine engine;
   PriceStructureState source = SetupSource(MARKET_CYCLE_BULL);
   SwingPoint swings[];
   MqlRates rates[];
   SymbolState state;
   state.setup = "-";
   state.setupStatus = "NONE";

   AddSetupBar(rates, SetupBar(3000, 110.0, 100.0, 105.0));
   ApplySetup(engine, "IMPULSE", JINPA_STATE_CORRECTION,
              "NONE", source, swings, rates, state);
   source.sidewayBox.leg1Confirmed = true;
   source.sidewayBox.leg1Swing = SetupSwing(SWING_LOW, 3020, 3060, 99.0);

   AddSetupBar(rates, SetupBar(3060, 109.0, 101.0, 105.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "LEG 1", source, swings, rates, state);
   Check(state.setup == "revs-ppf" && state.setupStatus == "WATCH",
         "PPS_07_LEG1_WITHOUT_MINOR_SWING_STAYS_PPF");

   ArrayResize(swings, 1);
   swings[0] = SetupSwing(SWING_HIGH, 2900, 3120, 108.0);
   AddSetupBar(rates, SetupBar(3120, 108.0, 102.0, 104.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "LEG 1", source, swings, rates, state);
   Check(state.setup == "revs-ppf",
         "PPS_08_OLD_SWING_BEFORE_LEG1_EXCLUDED");

   ArrayResize(swings, 2);
   swings[1] = SetupSwing(SWING_HIGH, 3080, 3180, 109.0);
   AddSetupBar(rates, SetupBar(3180, 109.0, 103.0, 105.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "LEG 1", source, swings, rates, state);
   Check(state.setup == "revs-pps" && state.setupStatus == "WATCH"
         && engine.BaseTime() == 3180,
         "PPS_09_BULL_CONFIRMED_SWING_HIGH_AFTER_LEG1_WATCH");

   AddSetupBar(rates, SetupBar(3240, 111.0, 106.0, 110.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "LEG 1", source, swings, rates, state);
   Check(state.setup == "revs-pps" && state.setupStatus == "ACTIVE",
         "PPS_10_ROLLING_BASE_BREAK_ACTIVE");

   AddSetupBar(rates, SetupBar(3300, 110.0, 104.0, 106.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_CORRECTION,
              "LEG 1", source, swings, rates, state);
   Check(state.setup == "revs-pps" && state.setupStatus == "INVALID",
         "PPS_11_ACTIVE_NEXT_BAR_INVALID");

   CPullbackSetupEngine bearEngine;
   PriceStructureState bearSource = SetupSource(MARKET_CYCLE_BEAR);
   MqlRates bearRates[];
   SwingPoint bearSwings[];
   SymbolState bearState;
   bearState.setup = "-";
   bearState.setupStatus = "NONE";
   AddSetupBar(bearRates, SetupBar(4000, 110.0, 100.0, 105.0));
   ApplySetup(bearEngine, "IMPULSE", JINPA_STATE_CORRECTION,
              "NONE", bearSource, bearSwings, bearRates, bearState);
   bearSource.sidewayBox.leg1Confirmed = true;
   bearSource.sidewayBox.leg1Swing =
      SetupSwing(SWING_HIGH, 4020, 4060, 111.0);
   ArrayResize(bearSwings, 1);
   bearSwings[0] = SetupSwing(SWING_LOW, 4080, 4120, 101.0);
   AddSetupBar(bearRates, SetupBar(4120, 108.0, 101.0, 104.0));
   ApplySetup(bearEngine, "CORRECTION", JINPA_STATE_CORRECTION,
              "LEG 1", bearSource, bearSwings, bearRates, bearState);
   Check(bearState.setup == "revs-pps"
         && bearState.setupStatus == "WATCH",
         "PPS_12_BEAR_CONFIRMED_SWING_LOW_AFTER_LEG1_WATCH");
}

void TestContextAndRadar(void)
{
   CPullbackSetupEngine engine;
   PriceStructureState source = SetupSource(MARKET_CYCLE_BULL);
   SwingPoint swings[];
   MqlRates rates[];
   SymbolState state;
   state.setup = "-";
   state.setupStatus = "NONE";
   AddSetupBar(rates, SetupBar(5000, 110.0, 100.0, 105.0));
   ApplySetup(engine, "IMPULSE", JINPA_STATE_CORRECTION,
              "NONE", source, swings, rates, state);
   AddSetupBar(rates, SetupBar(5060, 109.0, 101.0, 105.0));
   ApplySetup(engine, "CORRECTION", JINPA_STATE_IMPULSE,
              "CONTINUATION", source, swings, rates, state);
   Check(state.setup == "revs-ppf" && state.setupStatus == "INVALID",
         "CONTEXT_13_LEAVING_CORRECTION_INVALIDATES_SETUP");

   SymbolState panelStates[1];
   panelStates[0].symbol = _Symbol;
   panelStates[0].timeframe = (ENUM_TIMEFRAMES)_Period;
   panelStates[0].cycle = "BULL";
   panelStates[0].regime = "TREND";
   panelStates[0].state = "CORRECTION";
   panelStates[0].structure = "LEG 1";
   panelStates[0].setup = "revs-ppf";
   panelStates[0].setupStatus = "WATCH";
   panelStates[0].isReady = true;
   CMarketRadar radar;
   radar.Configure(true, CORNER_RIGHT_LOWER, 15, 20, 20, 9);
   const bool created = radar.Create(panelStates);
   radar.Update(panelStates, true);
   const bool ppf = ObjectGetString(
      0, "JINPA_RADAR_ROW_000_COL_06", OBJPROP_TEXT) == "revs-ppf"
      && ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_07", OBJPROP_TEXT)
         == "WATCH";
   panelStates[0].setup = "revs-pps";
   panelStates[0].setupStatus = "ACTIVE";
   radar.Update(panelStates, true);
   const bool pps = ObjectGetString(
      0, "JINPA_RADAR_ROW_000_COL_06", OBJPROP_TEXT) == "revs-pps"
      && ObjectGetString(0, "JINPA_RADAR_ROW_000_COL_07", OBJPROP_TEXT)
         == "ACTIVE";
   panelStates[0].setupStatus = "INVALID";
   radar.Update(panelStates, true);
   const bool invalid = ObjectGetString(
      0, "JINPA_RADAR_ROW_000_COL_07", OBJPROP_TEXT) == "INVALID";
   Check(created && ppf && pps && invalid,
         "RADAR_14_PULLBACK_SETUP_AND_STATUS_VALUES");
   radar.Destroy();
}

int OnInit(void)
{
   TestPpfLifecycle();
   TestPpsLifecycle();
   TestContextAndRadar();
   Print("[PULLBACK_SETUP_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
