#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Phase 4D PMA Setup deterministic probe"

#include "../watch/setup/PmaSetupEngine.mqh"
#include "../watch/setup/SetupOutputArbitrator.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[PMA_SETUP_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[PMA_SETUP_TEST][FAIL] ", name);
   }
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

bool Apply(CPmaSetupEngine &engine,
           const ENUM_JINPA_MARKET_STATE state,
           const datetime impulseStartTime,
           const ENUM_MARKET_CYCLE cycle,
           const bool confirmed,
           const bool consumed,
           const datetime microImpulse,
           const datetime anchorTime,
           const double baseHigh,
           const double baseLow,
           MqlRates &rates[])
{
   return engine.Apply(state, impulseStartTime, cycle,
                       confirmed, consumed, microImpulse,
                       anchorTime, baseHigh, baseLow,
                       rates, rates[ArraySize(rates) - 1].time);
}

void PrepareReady(CPmaSetupEngine &engine,
                  MqlRates &rates[],
                  const datetime start,
                  const ENUM_MARKET_CYCLE cycle)
{
   AddBar(rates, Bar(start, 108, 102, 105));
   Apply(engine, JINPA_STATE_IMPULSE, start, cycle,
         false, false, start, 0, 0, 0, rates);
   AddBar(rates, Bar(start + 10, 109, 101, 105));
   Apply(engine, JINPA_STATE_IMPULSE, start, cycle,
         true, true, start, start, 110, 100, rates);
}

void TestImpulseArming(void)
{
   CPmaSetupEngine engine;
   MqlRates rates[];
   AddBar(rates, Bar(100, 108, 102, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 100, MARKET_CYCLE_BULL,
         false, false, 100, 0, 0, 0, rates);
   Check(engine.SetupText() == "bres-pma"
         && engine.Status() == JINPA_PMA_STATUS_WATCH,
         "ARM_01_NEW_IMPULSE_WATCH");
   Check(engine.ImpulseStartTime() == 100
         && engine.Direction() == JINPA_PMA_DIRECTION_BUY,
         "ARM_02_IDENTITY_AND_BULL_DIRECTION");

   AddBar(rates, Bar(110, 109, 103, 106));
   Apply(engine, JINPA_STATE_IMPULSE, 100, MARKET_CYCLE_BULL,
         false, false, 100, 0, 0, 0, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_WATCH
         && engine.ImpulseStartTime() == 100
         && engine.BaseTime() == 0,
         "ARM_03_REPEATED_IMPULSE_NO_REARM");

   AddBar(rates, Bar(200, 208, 202, 205));
   Apply(engine, JINPA_STATE_IMPULSE, 200, MARKET_CYCLE_BEAR,
         false, false, 200, 0, 0, 0, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_WATCH
         && engine.ImpulseStartTime() == 200
         && engine.Direction() == JINPA_PMA_DIRECTION_SELL,
         "ARM_04_NEW_IMPULSE_REPLACES_OLD_LIFECYCLE");

   CPmaSetupEngine guard;
   MqlRates guardRates[];
   AddBar(guardRates, Bar(210, 108, 102, 105));
   Apply(guard, JINPA_STATE_COMPRESSION, 210, MARKET_CYCLE_BULL,
         false, false, 210, 0, 0, 0, guardRates);
   Check(guard.Status() == JINPA_PMA_STATUS_NONE,
         "ARM_05_NON_IMPULSE_DOES_NOT_ARM");
}

void TestMicroBaseReadyAndSnapshot(void)
{
   CPmaSetupEngine engine;
   MqlRates rates[];
   AddBar(rates, Bar(300, 108, 102, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 300, MARKET_CYCLE_BULL,
         false, false, 300, 0, 0, 0, rates);
   AddBar(rates, Bar(310, 109, 101, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 300, MARKET_CYCLE_BULL,
         false, false, 300, 300, 110, 100, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_WATCH,
         "READY_06_UNCONFIRMED_CANDIDATE_REMAINS_WATCH");

   AddBar(rates, Bar(320, 109, 101, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 300, MARKET_CYCLE_BULL,
         true, true, 999, 300, 110, 100, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_WATCH,
         "READY_07_WRONG_IMPULSE_MICRO_BASE_IGNORED");

   AddBar(rates, Bar(330, 109, 101, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 300, MARKET_CYCLE_BULL,
         true, true, 300, 300, 110, 100, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_READY,
         "READY_08_FIRST_CONFIRMED_MICRO_BASE_READY");
   Check(engine.BaseTime() == 300 && engine.BaseHigh() == 110
         && engine.BaseLow() == 100,
         "READY_09_EXACT_UPSTREAM_BASE_SNAPSHOT");

   AddBar(rates, Bar(340, 115, 95, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 300, MARKET_CYCLE_BULL,
         true, true, 300, 300, 999, 1, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_READY
         && engine.BaseHigh() == 110 && engine.BaseLow() == 100,
         "READY_10_UPSTREAM_VALUES_CANNOT_MUTATE_SNAPSHOT");
}

void TestBullRules(void)
{
   CPmaSetupEngine success;
   MqlRates successRates[];
   PrepareReady(success, successRates, 400, MARKET_CYCLE_BULL);
   AddBar(successRates, Bar(420, 112, 104, 111));
   Apply(success, JINPA_STATE_IMPULSE, 400, MARKET_CYCLE_BULL,
         false, true, 400, 0, 0, 0, successRates);
   Check(success.Status() == JINPA_PMA_STATUS_ACTIVE
         && success.Direction() == JINPA_PMA_DIRECTION_BUY
         && success.TriggerBarTime() == 420,
         "BULL_11_CLOSE_ABOVE_ACTIVE_BUY");

   CPmaSetupEngine failure;
   MqlRates failureRates[];
   PrepareReady(failure, failureRates, 500, MARKET_CYCLE_BULL);
   AddBar(failureRates, Bar(520, 106, 98, 99));
   Apply(failure, JINPA_STATE_IMPULSE, 500, MARKET_CYCLE_BULL,
         false, true, 500, 0, 0, 0, failureRates);
   Check(failure.Status() == JINPA_PMA_STATUS_INVALID,
         "BULL_12_CLOSE_BELOW_INVALID");

   CPmaSetupEngine equalHigh;
   MqlRates equalHighRates[];
   PrepareReady(equalHigh, equalHighRates, 600, MARKET_CYCLE_BULL);
   AddBar(equalHighRates, Bar(620, 112, 104, 110));
   Apply(equalHigh, JINPA_STATE_IMPULSE, 600, MARKET_CYCLE_BULL,
         true, true, 600, 600, 110, 100, equalHighRates);
   Check(equalHigh.Status() == JINPA_PMA_STATUS_READY,
         "BULL_13_EQUAL_BASE_HIGH_REMAINS_READY");

   CPmaSetupEngine equalLow;
   MqlRates equalLowRates[];
   PrepareReady(equalLow, equalLowRates, 700, MARKET_CYCLE_BULL);
   AddBar(equalLowRates, Bar(720, 106, 98, 100));
   Apply(equalLow, JINPA_STATE_IMPULSE, 700, MARKET_CYCLE_BULL,
         true, true, 700, 700, 110, 100, equalLowRates);
   Check(equalLow.Status() == JINPA_PMA_STATUS_READY,
         "BULL_14_EQUAL_BASE_LOW_REMAINS_READY");

   CPmaSetupEngine wickHigh;
   MqlRates wickHighRates[];
   PrepareReady(wickHigh, wickHighRates, 800, MARKET_CYCLE_BULL);
   AddBar(wickHighRates, Bar(820, 120, 104, 105));
   Apply(wickHigh, JINPA_STATE_IMPULSE, 800, MARKET_CYCLE_BULL,
         true, true, 800, 800, 110, 100, wickHighRates);
   Check(wickHigh.Status() == JINPA_PMA_STATUS_READY,
         "BULL_15_UPPER_WICK_ONLY_REMAINS_READY");

   CPmaSetupEngine wickLow;
   MqlRates wickLowRates[];
   PrepareReady(wickLow, wickLowRates, 900, MARKET_CYCLE_BULL);
   AddBar(wickLowRates, Bar(920, 106, 90, 105));
   Apply(wickLow, JINPA_STATE_IMPULSE, 900, MARKET_CYCLE_BULL,
         true, true, 900, 900, 110, 100, wickLowRates);
   Check(wickLow.Status() == JINPA_PMA_STATUS_READY,
         "BULL_16_LOWER_WICK_ONLY_REMAINS_READY");
}

void TestBearRules(void)
{
   CPmaSetupEngine success;
   MqlRates successRates[];
   PrepareReady(success, successRates, 1000, MARKET_CYCLE_BEAR);
   AddBar(successRates, Bar(1020, 106, 98, 99));
   Apply(success, JINPA_STATE_IMPULSE, 1000, MARKET_CYCLE_BEAR,
         false, true, 1000, 0, 0, 0, successRates);
   Check(success.Status() == JINPA_PMA_STATUS_ACTIVE
         && success.Direction() == JINPA_PMA_DIRECTION_SELL,
         "BEAR_17_CLOSE_BELOW_ACTIVE_SELL");

   CPmaSetupEngine failure;
   MqlRates failureRates[];
   PrepareReady(failure, failureRates, 1100, MARKET_CYCLE_BEAR);
   AddBar(failureRates, Bar(1120, 112, 104, 111));
   Apply(failure, JINPA_STATE_IMPULSE, 1100, MARKET_CYCLE_BEAR,
         false, true, 1100, 0, 0, 0, failureRates);
   Check(failure.Status() == JINPA_PMA_STATUS_INVALID,
         "BEAR_18_CLOSE_ABOVE_INVALID");

   CPmaSetupEngine equality;
   MqlRates equalityRates[];
   PrepareReady(equality, equalityRates, 1200, MARKET_CYCLE_BEAR);
   AddBar(equalityRates, Bar(1220, 111, 99, 100));
   Apply(equality, JINPA_STATE_IMPULSE, 1200, MARKET_CYCLE_BEAR,
         true, true, 1200, 1200, 110, 100, equalityRates);
   Check(equality.Status() == JINPA_PMA_STATUS_READY,
         "BEAR_19_EQUAL_BOUNDARY_REMAINS_READY");

   CPmaSetupEngine wick;
   MqlRates wickRates[];
   PrepareReady(wick, wickRates, 1300, MARKET_CYCLE_BEAR);
   AddBar(wickRates, Bar(1320, 120, 90, 105));
   Apply(wick, JINPA_STATE_IMPULSE, 1300, MARKET_CYCLE_BEAR,
         true, true, 1300, 1300, 110, 100, wickRates);
   Check(wick.Status() == JINPA_PMA_STATUS_READY,
         "BEAR_20_WICK_ONLY_EXCURSION_REMAINS_READY");
}

void TestTerminalAndTimeout(void)
{
   CPmaSetupEngine engine;
   MqlRates rates[];
   PrepareReady(engine, rates, 1400, MARKET_CYCLE_BULL);
   AddBar(rates, Bar(1420, 112, 104, 111));
   Apply(engine, JINPA_STATE_IMPULSE, 1400, MARKET_CYCLE_BULL,
         false, true, 1400, 0, 0, 0, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_ACTIVE,
         "TERMINAL_21_TRIGGER_BAR_REMAINS_ACTIVE");
   Check(!Apply(engine, JINPA_STATE_IMPULSE, 1400, MARKET_CYCLE_BULL,
                false, true, 1400, 0, 0, 0, rates)
         && engine.Status() == JINPA_PMA_STATUS_ACTIVE,
         "TERMINAL_22_SAME_BAR_CANNOT_INVALIDATE_ACTIVE");
   AddBar(rates, Bar(1430, 111, 103, 106));
   Apply(engine, JINPA_STATE_IMPULSE, 1400, MARKET_CYCLE_BULL,
         false, true, 1400, 0, 0, 0, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_INVALID,
         "TERMINAL_23_NEXT_LATER_BAR_INVALID");
   AddBar(rates, Bar(1440, 110, 102, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 1400, MARKET_CYCLE_BULL,
         false, true, 1400, 0, 0, 0, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_NONE
         && engine.SetupText() == "-",
         "TERMINAL_24_FOLLOWING_LATER_BAR_NONE");

   CPmaSetupEngine timeout;
   MqlRates timeoutRates[];
   PrepareReady(timeout, timeoutRates, 1500, MARKET_CYCLE_BULL);
   AddBar(timeoutRates, Bar(1520, 109, 101, 105));
   Apply(timeout, JINPA_STATE_IMPULSE, 1500, MARKET_CYCLE_BULL,
         false, true, 1500, 0, 0, 0, timeoutRates);
   Check(timeout.Status() == JINPA_PMA_STATUS_INVALID
         && timeout.BaseHigh() == 110 && timeout.BaseLow() == 100,
         "TIMEOUT_25_UPSTREAM_RESET_INVALID_PRESERVES_SNAPSHOT");
}

void TestSameBarStateExit(void)
{
   CPmaSetupEngine success;
   MqlRates successRates[];
   PrepareReady(success, successRates, 1600, MARKET_CYCLE_BULL);
   AddBar(successRates, Bar(1620, 112, 104, 111));
   Apply(success, JINPA_STATE_CORRECTION, 1600, MARKET_CYCLE_BULL,
         false, true, 1600, 0, 0, 0, successRates);
   Check(success.Status() == JINPA_PMA_STATUS_ACTIVE,
         "ORDER_26_DIRECTIONAL_SUCCESS_BEATS_SAME_BAR_CORRECTION");

   CPmaSetupEngine neutral;
   MqlRates neutralRates[];
   PrepareReady(neutral, neutralRates, 1700, MARKET_CYCLE_BULL);
   AddBar(neutralRates, Bar(1720, 109, 101, 105));
   Apply(neutral, JINPA_STATE_CORRECTION, 1700, MARKET_CYCLE_BULL,
         true, true, 1700, 1700, 110, 100, neutralRates);
   Check(neutral.Status() == JINPA_PMA_STATUS_INVALID,
         "ORDER_27_NO_OUTCOME_CORRECTION_INVALIDATES");

   CPmaSetupEngine opposite;
   MqlRates oppositeRates[];
   PrepareReady(opposite, oppositeRates, 1800, MARKET_CYCLE_BULL);
   AddBar(oppositeRates, Bar(1820, 106, 98, 99));
   Apply(opposite, JINPA_STATE_CORRECTION, 1800, MARKET_CYCLE_BULL,
         false, true, 1800, 0, 0, 0, oppositeRates);
   Check(opposite.Status() == JINPA_PMA_STATUS_INVALID,
         "ORDER_28_OPPOSITE_BREAK_BEATS_CONTEXT_CLEANUP_AS_INVALID");
}

void TestOnePerImpulseAndGuards(void)
{
   CPmaSetupEngine engine;
   MqlRates rates[];
   PrepareReady(engine, rates, 1900, MARKET_CYCLE_BULL);
   AddBar(rates, Bar(1920, 106, 98, 99));
   Apply(engine, JINPA_STATE_IMPULSE, 1900, MARKET_CYCLE_BULL,
         false, true, 1900, 0, 0, 0, rates);
   AddBar(rates, Bar(1930, 109, 101, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 1900, MARKET_CYCLE_BULL,
         true, true, 1900, 1900, 110, 100, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_NONE,
         "ONCE_29_INVALID_CLEARS_TO_NONE");
   AddBar(rates, Bar(1940, 109, 101, 105));
   Apply(engine, JINPA_STATE_IMPULSE, 1900, MARKET_CYCLE_BULL,
         true, true, 1900, 1900, 110, 100, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_NONE
         && engine.ImpulseStartTime() == 1900,
         "ONCE_30_SAME_IMPULSE_CANNOT_REARM_OR_READY");
   AddBar(rates, Bar(2000, 208, 202, 205));
   Apply(engine, JINPA_STATE_IMPULSE, 2000, MARKET_CYCLE_BEAR,
         false, false, 2000, 0, 0, 0, rates);
   Check(engine.Status() == JINPA_PMA_STATUS_WATCH
         && engine.ImpulseStartTime() == 2000,
         "ONCE_31_GENUINE_NEW_IMPULSE_WATCH");

   CPmaSetupEngine unknown;
   MqlRates unknownRates[];
   AddBar(unknownRates, Bar(2100, 108, 102, 105));
   Apply(unknown, JINPA_STATE_IMPULSE, 2100, MARKET_CYCLE_BULL,
         false, false, 2100, 0, 0, 0, unknownRates);
   AddBar(unknownRates, Bar(2110, 109, 103, 106));
   Apply(unknown, JINPA_STATE_IMPULSE, 2100, MARKET_CYCLE_UNKNOWN,
         false, false, 2100, 0, 0, 0, unknownRates);
   Check(unknown.Status() == JINPA_PMA_STATUS_INVALID,
         "GUARD_32_UNKNOWN_CYCLE_INVALIDATES_WATCH");

   CPmaSetupEngine changed;
   MqlRates changedRates[];
   PrepareReady(changed, changedRates, 2200, MARKET_CYCLE_BULL);
   AddBar(changedRates, Bar(2220, 109, 101, 105));
   Apply(changed, JINPA_STATE_IMPULSE, 2200, MARKET_CYCLE_BEAR,
         true, true, 2200, 2200, 110, 100, changedRates);
   Check(changed.Status() == JINPA_PMA_STATUS_INVALID,
         "GUARD_33_CYCLE_CHANGE_INVALIDATES_READY");
   changed.Reset();
   Check(changed.Status() == JINPA_PMA_STATUS_NONE
         && changed.ImpulseStartTime() == 0
         && changed.BaseTime() == 0,
         "GUARD_34_RESET_CLEARS_CONTEXT");
}

void TestOutputArbitration(void)
{
   CSetupOutputArbitrator arbitrator;
   SymbolState output;
   output.structure = "CONTINUATION";
   arbitrator.Project("-", "NONE", "bres-pma", "WATCH",
                      "bres-pmb", "INVALID", output);
   Check(output.setup == "bres-pma" && output.setupStatus == "WATCH",
         "OUTPUT_35_RANGE_INVALID_CANNOT_HIDE_PMA_WATCH");
   Check(output.structure == "CONTINUATION",
         "OUTPUT_36_PMA_NEVER_OVERWRITES_STRUCTURE");

   arbitrator.Project("revs-pps", "INVALID", "bres-pma", "READY",
                      "-", "NONE", output);
   Check(output.setup == "bres-pma" && output.setupStatus == "READY",
         "OUTPUT_37_PULLBACK_INVALID_CANNOT_HIDE_PMA_READY");
   arbitrator.Project("revs-ppf", "WATCH", "bres-pma", "ACTIVE",
                      "-", "NONE", output);
   Check(output.setup == "bres-pma" && output.setupStatus == "ACTIVE",
         "OUTPUT_38_PMA_ACTIVE_VISIBLE_OVER_NEW_PPF_WATCH");
   Check(output.setup == "bres-pma" && output.setupStatus == "ACTIVE"
         && StringFind(output.setup, "revs-ppf") < 0,
         "OUTPUT_39_SINGLE_SETUP_OUTPUT_ONLY");
}

void TestReplayParity(void)
{
   CPmaSetupEngine forward;
   CPmaSetupEngine replay;
   MqlRates forwardRates[];
   MqlRates replayRates[];
   AddBar(forwardRates, Bar(2300, 108, 102, 105));
   Apply(forward, JINPA_STATE_IMPULSE, 2300, MARKET_CYCLE_BEAR,
         false, false, 2300, 0, 0, 0, forwardRates);
   AddBar(forwardRates, Bar(2310, 109, 101, 105));
   Apply(forward, JINPA_STATE_IMPULSE, 2300, MARKET_CYCLE_BEAR,
         true, true, 2300, 2300, 110, 100, forwardRates);
   AddBar(forwardRates, Bar(2320, 106, 98, 99));
   Apply(forward, JINPA_STATE_IMPULSE, 2300, MARKET_CYCLE_BEAR,
         false, true, 2300, 0, 0, 0, forwardRates);

   AddBar(replayRates, Bar(2300, 108, 102, 105));
   Apply(replay, JINPA_STATE_IMPULSE, 2300, MARKET_CYCLE_BEAR,
         false, false, 2300, 0, 0, 0, replayRates);
   AddBar(replayRates, Bar(2310, 109, 101, 105));
   Apply(replay, JINPA_STATE_IMPULSE, 2300, MARKET_CYCLE_BEAR,
         true, true, 2300, 2300, 110, 100, replayRates);
   AddBar(replayRates, Bar(2320, 106, 98, 99));
   Apply(replay, JINPA_STATE_IMPULSE, 2300, MARKET_CYCLE_BEAR,
         false, true, 2300, 0, 0, 0, replayRates);
   Check(forward.Status() == replay.Status()
         && forward.Direction() == replay.Direction()
         && forward.BaseTime() == replay.BaseTime()
         && forward.TriggerBarTime() == replay.TriggerBarTime(),
         "REPLAY_40_CHRONOLOGICAL_FORWARD_REPLAY_PARITY");
}

void TestStartupConsumedLatch(void)
{
   CPmaSetupEngine bull;
   MqlRates bullRates[];
   AddBar(bullRates, Bar(2400, 109, 101, 105));
   Apply(bull, JINPA_STATE_IMPULSE, 2300, MARKET_CYCLE_BULL,
         false, true, 2300, 0, 0, 0, bullRates);
   Check(bull.Status() == JINPA_PMA_STATUS_NONE
         && bull.ImpulseStartTime() == 2300
         && bull.LifecycleUsed(),
         "REPLAY_41_CONSUMED_BULL_IMPULSE_CANNOT_REARM_WATCH");

   CPmaSetupEngine bear;
   MqlRates bearRates[];
   AddBar(bearRates, Bar(2500, 209, 201, 205));
   Apply(bear, JINPA_STATE_IMPULSE, 2400, MARKET_CYCLE_BEAR,
         false, true, 2400, 0, 0, 0, bearRates);
   Check(bear.Status() == JINPA_PMA_STATUS_NONE
         && bear.ImpulseStartTime() == 2400
         && bear.LifecycleUsed(),
         "REPLAY_42_CONSUMED_BEAR_IMPULSE_CANNOT_REARM_WATCH");

   CPmaSetupEngine currentBase;
   MqlRates currentRates[];
   AddBar(currentRates, Bar(2600, 109, 101, 105));
   Apply(currentBase, JINPA_STATE_IMPULSE, 2500, MARKET_CYCLE_BULL,
         true, true, 2500, 2550, 110, 100, currentRates);
   Check(currentBase.Status() == JINPA_PMA_STATUS_READY
         && currentBase.BaseTime() == 2550,
         "REPLAY_43_CURRENT_CONFIRMED_BASE_STILL_REBUILDS_READY");
}

int OnInit(void)
{
   TestImpulseArming();
   TestMicroBaseReadyAndSnapshot();
   TestBullRules();
   TestBearRules();
   TestTerminalAndTimeout();
   TestSameBarStateExit();
   TestOnePerImpulseAndGuards();
   TestOutputArbitration();
   TestReplayParity();
   TestStartupConsumedLatch();
   Print("[PMA_SETUP_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 push=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void)
{
   ExpertRemove();
}
