#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Stage 3 Market Structure deterministic probe"

#include "../watch/state/MarketStructureEngine.mqh"
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
                     JINPA_STRUCTURE_LEG_1),
         "CASE_S5_CORRECTION_LEG1");
   source.sidewayBox.leg2Confirmed = true;
   Check(IsStructure(JINPA_STATE_CORRECTION, source,
                     JINPA_STRUCTURE_LEG_2),
         "CASE_S6_LEG2_PRIORITY_OVER_LEG1");

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
                     JINPA_STRUCTURE_LEG_1),
         "CASE_S8_FALSE_BREAK_LEG1_STABLE");

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
                                 JINPA_STRUCTURE_LEG_1);
   source.sidewayBox.leg2Confirmed = true;
   const bool leg2 = IsStructure(JINPA_STATE_CORRECTION, source,
                                 JINPA_STRUCTURE_LEG_2);
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
   Check(before == JINPA_STRUCTURE_LEG_2 && after == before,
         "BOOTSTRAP_RESTART_STATELESS_PARITY");
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
   radar.Destroy();
}

int OnInit(void)
{
   TestRequiredCases();
   TestFlowsAndAuthority();
   TestPanelValue();
   Print("[MARKET_STRUCTURE_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
