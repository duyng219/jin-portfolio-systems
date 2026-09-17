#ifndef JINPA_WATCHER_MARKET_STATE_ENGINE_MQH
#define JINPA_WATCHER_MARKET_STATE_ENGINE_MQH

#include "../core/WatcherTypes.mqh"
#include "../structure/StructureTypes.mqh"

enum ENUM_JINPA_MARKET_REGIME
{
   JINPA_REGIME_UNKNOWN = 0,
   JINPA_REGIME_RANGE,
   JINPA_REGIME_TREND
};

enum ENUM_JINPA_MARKET_STATE
{
   JINPA_STATE_UNKNOWN = 0,
   JINPA_STATE_COMPRESSION,
   JINPA_STATE_EXPANSION,
   JINPA_STATE_IMPULSE,
   JINPA_STATE_CORRECTION
};

struct MarketStateTransitionRecord
{
   ENUM_JINPA_MARKET_STATE fromState;
   ENUM_JINPA_MARKET_STATE toState;
   ENUM_MARKET_CYCLE       cycle;
   datetime                transitionTime;
   double                  transitionClose;
   datetime                breakoutTime;
   double                  breakoutClose;
   datetime                impulseStartTime;
   datetime                swingPivotTime;
   datetime                swingConfirmationTime;
   ENUM_STRUCTURE_POINT    swingClassification;
};

string JinpaMarketRegimeToString(const ENUM_JINPA_MARKET_REGIME regime)
{
   if(regime == JINPA_REGIME_RANGE)
      return "RANGE";
   if(regime == JINPA_REGIME_TREND)
      return "TREND";
   return "UNKNOWN";
}

string JinpaMarketStateToString(const ENUM_JINPA_MARKET_STATE state)
{
   if(state == JINPA_STATE_COMPRESSION)
      return "COMPRESSION";
   if(state == JINPA_STATE_EXPANSION)
      return "EXPANSION";
   if(state == JINPA_STATE_IMPULSE)
      return "IMPULSE";
   if(state == JINPA_STATE_CORRECTION)
      return "CORRECTION";
   return "UNKNOWN";
}

// Read-only chronological consumer of Stage 2 history. Stable timestamps make
// startup and forward updates resolve the same lifecycle without persistence.
class CMarketStateEngine
{
private:
   ENUM_JINPA_MARKET_REGIME m_regime;
   ENUM_JINPA_MARKET_STATE  m_state;
   ENUM_MARKET_CYCLE        m_cycle;
   bool                     m_hasBreakout;
   datetime                 m_breakoutTime;
   double                   m_breakoutClose;
   datetime                 m_impulseStartTime;
   MarketStateTransitionRecord m_transitions[];

   bool IsSidewayActive(const PriceStructureState &structureState) const
   {
      return structureState.sidewayBox.active
             || structureState.sidewayBox.sidewayConfirmed
             || structureState.sidewayBox.status == SIDEWAY_BOX_ACTIVE;
   }

   void AppendTransition(const ENUM_JINPA_MARKET_STATE nextState,
                         const datetime transitionTime,
                         const double transitionClose,
                         const SwingPoint &swing)
   {
      if(nextState == m_state)
         return;

      const int index = ArraySize(m_transitions);
      ArrayResize(m_transitions, index + 1);
      m_transitions[index].fromState = m_state;
      m_transitions[index].toState = nextState;
      m_transitions[index].cycle = m_cycle;
      m_transitions[index].transitionTime = transitionTime;
      m_transitions[index].transitionClose = transitionClose;
      m_transitions[index].breakoutTime = m_breakoutTime;
      m_transitions[index].breakoutClose = m_breakoutClose;
      m_transitions[index].impulseStartTime = m_impulseStartTime;
      m_transitions[index].swingPivotTime = swing.time;
      m_transitions[index].swingConfirmationTime = swing.confirmationTime;
      m_transitions[index].swingClassification = swing.classification;
      m_state = nextState;
   }

   void EnterCompression(const datetime transitionTime,
                         const double transitionClose)
   {
      SwingPoint noSwing;
      ResetSwingPoint(noSwing);
      AppendTransition(JINPA_STATE_COMPRESSION, transitionTime,
                       transitionClose, noSwing);
      m_regime = JINPA_REGIME_RANGE;
      m_hasBreakout = false;
      m_breakoutTime = 0;
      m_breakoutClose = 0.0;
      m_impulseStartTime = 0;
   }

   void EnterExpansion(const ENUM_MARKET_CYCLE cycle,
                       const datetime breakoutTime,
                       const double breakoutClose)
   {
      m_cycle = cycle;
      m_hasBreakout = true;
      m_breakoutTime = breakoutTime;
      m_breakoutClose = breakoutClose;
      m_impulseStartTime = 0;
      m_regime = JINPA_REGIME_TREND;

      SwingPoint noSwing;
      ResetSwingPoint(noSwing);
      AppendTransition(JINPA_STATE_EXPANSION, breakoutTime,
                       breakoutClose, noSwing);
   }

   void ProcessClosedBar(const MqlRates &bar,
                         const StructureEvent &events[],
                         const SwingPoint &swings[])
   {
      bool breakConfirmedOnBar = false;
      const int eventCount = ArraySize(events);
      for(int index = 0; index < eventCount; index++)
      {
         if(events[index].eventBarTime != bar.time)
            continue;

         if(events[index].type == CORE_BOX_TRANSITION_STARTED)
         {
            EnterExpansion(events[index].cycleAfter, bar.time, bar.close);
            breakConfirmedOnBar = true;
         }
         else if(events[index].type == SIDEWAY_CONFIRMED)
            EnterCompression(bar.time, bar.close);
      }

      // The confirmed-break candle establishes the reference only. A strictly
      // later closed candle is required for directional follow-through.
      if(!breakConfirmedOnBar && m_hasBreakout
         && m_state == JINPA_STATE_EXPANSION
         && bar.time > m_breakoutTime)
      {
         const bool continuation =
            (m_cycle == MARKET_CYCLE_BULL && bar.close > m_breakoutClose)
            || (m_cycle == MARKET_CYCLE_BEAR && bar.close < m_breakoutClose);
         if(continuation)
         {
            m_impulseStartTime = bar.time;
            SwingPoint noSwing;
            ResetSwingPoint(noSwing);
            AppendTransition(JINPA_STATE_IMPULSE, bar.time, bar.close,
                             noSwing);
         }
      }

      if(m_state != JINPA_STATE_IMPULSE || m_impulseStartTime <= 0)
         return;

      const int swingCount = ArraySize(swings);
      for(int index = 0; index < swingCount; index++)
      {
         const SwingPoint point = swings[index];
         if(!point.confirmed || point.confirmationTime != bar.time
            || point.confirmationTime <= m_impulseStartTime)
            continue;

         const bool directionalExtreme =
            (m_cycle == MARKET_CYCLE_BULL
             && point.classification == STRUCT_HH)
            || (m_cycle == MARKET_CYCLE_BEAR
                && point.classification == STRUCT_LL);
         if(!directionalExtreme)
            continue;

         AppendTransition(JINPA_STATE_CORRECTION, bar.time, bar.close,
                          point);
         break;
      }
   }

public:
   CMarketStateEngine(void) { Reset(); }

   void Reset(void)
   {
      m_regime = JINPA_REGIME_UNKNOWN;
      m_state = JINPA_STATE_UNKNOWN;
      m_cycle = MARKET_CYCLE_UNKNOWN;
      m_hasBreakout = false;
      m_breakoutTime = 0;
      m_breakoutClose = 0.0;
      m_impulseStartTime = 0;
      ArrayResize(m_transitions, 0);
   }

   void Rebuild(const PriceStructureState &structureState,
                const SwingPoint &swings[],
                const StructureEvent &events[],
                const MqlRates &rates[],
                const datetime lastClosedBarTime)
   {
      Reset();
      if(!structureState.initialized)
         return;

      const int rateCount = ArraySize(rates);
      for(int index = 0; index < rateCount; index++)
      {
         if(rates[index].time > lastClosedBarTime)
            break;
         ProcessClosedBar(rates[index], events, swings);
      }

      m_cycle = structureState.cycleState.cycle;
      if(IsSidewayActive(structureState))
      {
         double lastClose = 0.0;
         for(int index = rateCount - 1; index >= 0; index--)
         {
            if(rates[index].time <= lastClosedBarTime)
            {
               lastClose = rates[index].close;
               break;
            }
         }
         EnterCompression(lastClosedBarTime, lastClose);
      }
      else
         m_regime = JINPA_REGIME_TREND;
   }

   bool Apply(const PriceStructureState &structureState,
              const SwingPoint &swings[],
              const StructureEvent &events[],
              const MqlRates &rates[],
              const datetime lastClosedBarTime,
              SymbolState &symbolState)
   {
      Rebuild(structureState, swings, events, rates, lastClosedBarTime);
      const string regimeText = JinpaMarketRegimeToString(m_regime);
      const string stateText = JinpaMarketStateToString(m_state);
      const bool changed = symbolState.regime != regimeText
                           || symbolState.state != stateText;
      symbolState.regime = regimeText;
      symbolState.state = stateText;
      return changed;
   }

   ENUM_JINPA_MARKET_REGIME Regime(void) const { return m_regime; }
   ENUM_JINPA_MARKET_STATE State(void) const { return m_state; }
   ENUM_MARKET_CYCLE Cycle(void) const { return m_cycle; }
   bool HasBreakout(void) const { return m_hasBreakout; }
   datetime BreakoutTime(void) const { return m_breakoutTime; }
   double BreakoutClose(void) const { return m_breakoutClose; }
   datetime ImpulseStartTime(void) const { return m_impulseStartTime; }

   void GetTransitions(MarketStateTransitionRecord &transitions[]) const
   {
      const int count = ArraySize(m_transitions);
      ArrayResize(transitions, count);
      for(int index = 0; index < count; index++)
         transitions[index] = m_transitions[index];
   }
};

#endif
