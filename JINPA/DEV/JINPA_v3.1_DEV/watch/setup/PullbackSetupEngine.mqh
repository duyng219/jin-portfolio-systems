#ifndef JINPA_WATCHER_PULLBACK_SETUP_ENGINE_MQH
#define JINPA_WATCHER_PULLBACK_SETUP_ENGINE_MQH

#include "../state/MarketStructureEngine.mqh"

enum ENUM_JINPA_SETUP
{
   JINPA_SETUP_NONE = 0,
   JINPA_SETUP_REVS_PPF,
   JINPA_SETUP_REVS_PPS
};

enum ENUM_JINPA_SETUP_STATUS
{
   JINPA_SETUP_STATUS_NONE = 0,
   JINPA_SETUP_STATUS_WATCH,
   JINPA_SETUP_STATUS_ACTIVE,
   JINPA_SETUP_STATUS_INVALID
};

string JinpaSetupToString(const ENUM_JINPA_SETUP setup)
{
   if(setup == JINPA_SETUP_REVS_PPF)
      return "revs-ppf";
   if(setup == JINPA_SETUP_REVS_PPS)
      return "revs-pps";
   return "-";
}

string JinpaSetupStatusToString(const ENUM_JINPA_SETUP_STATUS status)
{
   if(status == JINPA_SETUP_STATUS_WATCH)
      return "WATCH";
   if(status == JINPA_SETUP_STATUS_ACTIVE)
      return "ACTIVE";
   if(status == JINPA_SETUP_STATUS_INVALID)
      return "INVALID";
   return "NONE";
}

// Closed-bar observer for the first two pullback setups. It consumes State,
// Structure, Cycle and the existing Local Swing history without execution.
class CPullbackSetupEngine
{
private:
   ENUM_JINPA_SETUP        m_setup;
   ENUM_JINPA_SETUP_STATUS m_status;
   ENUM_MARKET_CYCLE       m_cycle;
   double                  m_baseHigh;
   double                  m_baseLow;
   datetime                m_baseTime;
   datetime                m_triggerBarTime;
   datetime                m_invalidBarTime;
   datetime                m_lastProcessedBarTime;
   datetime                m_lastPpsSwingTime;
   datetime                m_lastPpsSwingConfirmationTime;

   int FindClosedBarIndex(const MqlRates &rates[],
                          const datetime closedBarTime) const
   {
      for(int index = ArraySize(rates) - 1; index >= 0; index--)
      {
         if(rates[index].time == closedBarTime)
            return index;
         if(rates[index].time < closedBarTime)
            break;
      }
      return -1;
   }

   void ClearCurrentSetup(void)
   {
      m_setup = JINPA_SETUP_NONE;
      m_status = JINPA_SETUP_STATUS_NONE;
      m_baseHigh = 0.0;
      m_baseLow = 0.0;
      m_baseTime = 0;
      m_triggerBarTime = 0;
      m_invalidBarTime = 0;
   }

   void StartWatching(const ENUM_JINPA_SETUP setup,
                      const MqlRates &closedBar)
   {
      m_setup = setup;
      m_status = JINPA_SETUP_STATUS_WATCH;
      m_baseHigh = closedBar.high;
      m_baseLow = closedBar.low;
      m_baseTime = closedBar.time;
      m_triggerBarTime = 0;
      m_invalidBarTime = 0;
   }

   void SetActive(const datetime triggerBarTime)
   {
      m_status = JINPA_SETUP_STATUS_ACTIVE;
      m_triggerBarTime = triggerBarTime;
      m_invalidBarTime = 0;
   }

   void SetInvalid(const datetime invalidBarTime)
   {
      if(m_setup == JINPA_SETUP_NONE)
         return;
      m_status = JINPA_SETUP_STATUS_INVALID;
      m_invalidBarTime = invalidBarTime;
   }

   bool FindPpsSwing(const ENUM_MARKET_CYCLE cycle,
                     const PriceStructureState &structureState,
                     const SwingPoint &swings[],
                     const datetime closedBarTime,
                     SwingPoint &matched) const
   {
      ResetSwingPoint(matched);
      if(!structureState.sidewayBox.leg1Confirmed
         || !structureState.sidewayBox.leg1Swing.confirmed)
         return false;

      const SwingPoint leg1 = structureState.sidewayBox.leg1Swing;
      const ENUM_SWING_TYPE requiredType =
         cycle == MARKET_CYCLE_BULL ? SWING_HIGH
         : (cycle == MARKET_CYCLE_BEAR ? SWING_LOW : SWING_NONE);
      if(requiredType == SWING_NONE)
         return false;

      for(int index = ArraySize(swings) - 1; index >= 0; index--)
      {
         const SwingPoint point = swings[index];
         if(!point.confirmed || point.type != requiredType
            || point.confirmationTime != closedBarTime
            || point.time <= leg1.time
            || point.confirmationTime <= leg1.confirmationTime)
            continue;
         if(point.time == m_lastPpsSwingTime
            && point.confirmationTime == m_lastPpsSwingConfirmationTime)
            continue;
         matched = point;
         return true;
      }
      return false;
   }

   void WriteOutput(SymbolState &symbolState) const
   {
      symbolState.setup = JinpaSetupToString(m_setup);
      symbolState.setupStatus = JinpaSetupStatusToString(m_status);
   }

public:
   CPullbackSetupEngine(void) { Reset(); }

   void Reset(void)
   {
      ClearCurrentSetup();
      m_cycle = MARKET_CYCLE_UNKNOWN;
      m_lastProcessedBarTime = 0;
      m_lastPpsSwingTime = 0;
      m_lastPpsSwingConfirmationTime = 0;
   }

   bool Apply(const string previousMarketState,
              const ENUM_JINPA_MARKET_STATE marketState,
              const string marketStructure,
              const PriceStructureState &structureState,
              const SwingPoint &swings[],
              const MqlRates &rates[],
              const datetime lastClosedBarTime,
              SymbolState &symbolState)
   {
      const string previousSetup = symbolState.setup;
      const string previousStatus = symbolState.setupStatus;
      const int closedIndex = FindClosedBarIndex(rates, lastClosedBarTime);
      if(closedIndex < 0)
      {
         WriteOutput(symbolState);
         return previousSetup != symbolState.setup
                || previousStatus != symbolState.setupStatus;
      }

      if(lastClosedBarTime <= m_lastProcessedBarTime)
      {
         WriteOutput(symbolState);
         return previousSetup != symbolState.setup
                || previousStatus != symbolState.setupStatus;
      }
      m_lastProcessedBarTime = lastClosedBarTime;

      const MqlRates closedBar = rates[closedIndex];
      const ENUM_MARKET_CYCLE currentCycle =
         structureState.cycleState.cycle;
      const bool cycleChanged = m_cycle != MARKET_CYCLE_UNKNOWN
                                && currentCycle != m_cycle;
      m_cycle = currentCycle;

      if(m_status == JINPA_SETUP_STATUS_ACTIVE
         && closedBar.time > m_triggerBarTime)
      {
         SetInvalid(closedBar.time);
         WriteOutput(symbolState);
         return previousSetup != symbolState.setup
                || previousStatus != symbolState.setupStatus;
      }

      if(m_status == JINPA_SETUP_STATUS_INVALID)
      {
         if(closedBar.time > m_invalidBarTime)
            ClearCurrentSetup();
         else
         {
            WriteOutput(symbolState);
            return previousSetup != symbolState.setup
                   || previousStatus != symbolState.setupStatus;
         }
      }

      const bool correctionStarted =
         marketState == JINPA_STATE_CORRECTION
         && previousMarketState != "CORRECTION";

      if(cycleChanged || currentCycle == MARKET_CYCLE_UNKNOWN
         || marketState != JINPA_STATE_CORRECTION)
      {
         if(m_status == JINPA_SETUP_STATUS_WATCH)
            SetInvalid(closedBar.time);
         else if(m_status == JINPA_SETUP_STATUS_NONE)
            ClearCurrentSetup();
         WriteOutput(symbolState);
         return previousSetup != symbolState.setup
                || previousStatus != symbolState.setupStatus;
      }

      if(correctionStarted)
         StartWatching(JINPA_SETUP_REVS_PPF, closedBar);

      SwingPoint ppsSwing;
      if(marketStructure == "LEG 1"
         && FindPpsSwing(currentCycle, structureState, swings,
                         closedBar.time, ppsSwing))
      {
         m_lastPpsSwingTime = ppsSwing.time;
         m_lastPpsSwingConfirmationTime = ppsSwing.confirmationTime;
         StartWatching(JINPA_SETUP_REVS_PPS, closedBar);
         WriteOutput(symbolState);
         return previousSetup != symbolState.setup
                || previousStatus != symbolState.setupStatus;
      }

      if(m_status == JINPA_SETUP_STATUS_WATCH
         && closedBar.time > m_baseTime)
      {
         const bool active =
            (currentCycle == MARKET_CYCLE_BULL
             && closedBar.close > m_baseHigh)
            || (currentCycle == MARKET_CYCLE_BEAR
                && closedBar.close < m_baseLow);
         if(active)
            SetActive(closedBar.time);
         else
         {
            m_baseHigh = closedBar.high;
            m_baseLow = closedBar.low;
            m_baseTime = closedBar.time;
         }
      }

      WriteOutput(symbolState);
      return previousSetup != symbolState.setup
             || previousStatus != symbolState.setupStatus;
   }

   ENUM_JINPA_SETUP Setup(void) const { return m_setup; }
   ENUM_JINPA_SETUP_STATUS Status(void) const { return m_status; }
   double BaseHigh(void) const { return m_baseHigh; }
   double BaseLow(void) const { return m_baseLow; }
   datetime BaseTime(void) const { return m_baseTime; }
   datetime TriggerBarTime(void) const { return m_triggerBarTime; }
};

#endif
