#ifndef JINPA_WATCHER_MARKET_STRUCTURE_ENGINE_MQH
#define JINPA_WATCHER_MARKET_STRUCTURE_ENGINE_MQH

#include "MarketStateEngine.mqh"

enum ENUM_JINPA_MARKET_STRUCTURE
{
   JINPA_STRUCTURE_NONE = 0,
   JINPA_STRUCTURE_SIDEWAY,
   JINPA_STRUCTURE_BREAKOUT,
   JINPA_STRUCTURE_CONTINUATION,
   JINPA_STRUCTURE_LEG_1,
   JINPA_STRUCTURE_LEG_2,
   JINPA_STRUCTURE_RANGE_EDGE,
   JINPA_STRUCTURE_REJECTION,
   JINPA_STRUCTURE_FALSE_BREAK,
   JINPA_STRUCTURE_MICRO_BASE
};

string JinpaMarketStructureToString(
   const ENUM_JINPA_MARKET_STRUCTURE structure)
{
   if(structure == JINPA_STRUCTURE_SIDEWAY)
      return "SIDEWAY";
   if(structure == JINPA_STRUCTURE_BREAKOUT)
      return "BREAKOUT";
   if(structure == JINPA_STRUCTURE_CONTINUATION)
      return "CONTINUATION";
   if(structure == JINPA_STRUCTURE_LEG_1)
      return "LEG 1";
   if(structure == JINPA_STRUCTURE_LEG_2)
      return "LEG 2";
   if(structure == JINPA_STRUCTURE_RANGE_EDGE)
      return "RANGE EDGE";
   if(structure == JINPA_STRUCTURE_REJECTION)
      return "REJECTION";
   if(structure == JINPA_STRUCTURE_FALSE_BREAK)
      return "FALSE BREAK";
   if(structure == JINPA_STRUCTURE_MICRO_BASE)
      return "MICRO BASE";
   return "NONE";
}

struct MicroBaseCandidateState
{
   bool     active;
   bool     confirmed;
   datetime anchorTime;
   double   anchorHigh;
   double   anchorLow;
   int      barCount;
   datetime lastProcessedBarTime;
};

// Stage 3 projection. Sideway classification is closed-bar/stateless; the
// Impulse-only Micro Base candidate is instance-scoped to this WATCH context.
class CMarketStructureEngine
{
private:
   MicroBaseCandidateState m_microBase;
   datetime                m_microBaseImpulseStartTime;
   bool                    m_microBaseConsumed;

   void ResetMicroBase(void)
   {
      m_microBase.active = false;
      m_microBase.confirmed = false;
      m_microBase.anchorTime = 0;
      m_microBase.anchorHigh = 0.0;
      m_microBase.anchorLow = 0.0;
      m_microBase.barCount = 0;
      m_microBase.lastProcessedBarTime = 0;
   }

   void SelectMicroBaseAnchor(const MqlRates &closedBar)
   {
      m_microBase.active = true;
      m_microBase.confirmed = false;
      m_microBase.anchorTime = closedBar.time;
      m_microBase.anchorHigh = closedBar.high;
      m_microBase.anchorLow = closedBar.low;
      m_microBase.barCount = 1;
      m_microBase.lastProcessedBarTime = closedBar.time;
   }

   ENUM_JINPA_MARKET_STRUCTURE ResolveMicroBase(
      const ENUM_JINPA_MARKET_REGIME marketRegime,
      const ENUM_JINPA_MARKET_STATE marketState,
      const ENUM_MARKET_CYCLE cycle,
      const string previousStructure,
      const MqlRates &closedBar,
      const ENUM_JINPA_MARKET_STRUCTURE fallback)
   {
      if(marketRegime != JINPA_REGIME_TREND
         || marketState != JINPA_STATE_IMPULSE
         || cycle == MARKET_CYCLE_UNKNOWN)
      {
         ResetMicroBase();
         return fallback;
      }

      if(!m_microBase.active)
      {
         if(m_microBaseConsumed)
            return JINPA_STRUCTURE_CONTINUATION;
         if(previousStructure == "CONTINUATION")
            SelectMicroBaseAnchor(closedBar);
         return JINPA_STRUCTURE_CONTINUATION;
      }

      if(closedBar.time <= m_microBase.lastProcessedBarTime)
         return m_microBase.confirmed
                ? JINPA_STRUCTURE_MICRO_BASE
                : JINPA_STRUCTURE_CONTINUATION;

      const bool upperBreak = closedBar.close > m_microBase.anchorHigh;
      const bool lowerBreak = closedBar.close < m_microBase.anchorLow;
      const bool trendDirectionBreak =
         (cycle == MARKET_CYCLE_BULL && upperBreak)
         || (cycle == MARKET_CYCLE_BEAR && lowerBreak);
      const bool oppositeBreak =
         (cycle == MARKET_CYCLE_BULL && lowerBreak)
         || (cycle == MARKET_CYCLE_BEAR && upperBreak);
      if(trendDirectionBreak || oppositeBreak)
      {
         ResetMicroBase();
         return JINPA_STRUCTURE_CONTINUATION;
      }

      m_microBase.barCount++;
      m_microBase.lastProcessedBarTime = closedBar.time;
      if(m_microBase.barCount > 8)
      {
         ResetMicroBase();
         return JINPA_STRUCTURE_CONTINUATION;
      }

      if(m_microBase.barCount >= 3)
      {
         m_microBase.confirmed = true;
         m_microBaseConsumed = true;
      }
      return m_microBase.confirmed
             ? JINPA_STRUCTURE_MICRO_BASE
             : JINPA_STRUCTURE_CONTINUATION;
   }

   ENUM_JINPA_MARKET_STRUCTURE RebuildMicroBaseImpulse(
      const ENUM_MARKET_CYCLE cycle,
      const MqlRates &rates[],
      const datetime impulseStartTime,
      const datetime lastClosedBarTime)
   {
      ResetMicroBase();
      m_microBaseConsumed = false;
      string previousStructure = "BREAKOUT";
      ENUM_JINPA_MARKET_STRUCTURE structure =
         JINPA_STRUCTURE_CONTINUATION;
      bool firstEligibleBar = true;

      for(int index = 0; index < ArraySize(rates); index++)
      {
         if(rates[index].time < impulseStartTime)
            continue;
         if(rates[index].time > lastClosedBarTime)
            break;

         // If the exact impulse-start bar is outside available history, the
         // first available later bar follows an already established
         // CONTINUATION projection.
         if(firstEligibleBar && rates[index].time > impulseStartTime)
            previousStructure = "CONTINUATION";
         structure = ResolveMicroBase(
            JINPA_REGIME_TREND, JINPA_STATE_IMPULSE, cycle,
            previousStructure, rates[index], JINPA_STRUCTURE_CONTINUATION);
         previousStructure = JinpaMarketStructureToString(structure);
         firstEligibleBar = false;
      }
      return structure;
   }

   bool IsSidewayActive(const PriceStructureState &structureState) const
   {
      return structureState.sidewayBox.active
             || structureState.sidewayBox.sidewayConfirmed
             || structureState.sidewayBox.status == SIDEWAY_BOX_ACTIVE;
   }

   bool HasValidSidewayBounds(
      const PriceStructureState &structureState) const
   {
      return structureState.sidewayBox.boxHigh
                > structureState.sidewayBox.boxLow
             && structureState.sidewayBox.boxLow > 0.0;
   }

   bool IsRangeEdge(const PriceStructureState &structureState,
                    const MqlRates &closedBar,
                    const double edgeDistance) const
   {
      if(!HasValidSidewayBounds(structureState) || edgeDistance < 0.0)
         return false;

      return closedBar.close
                >= structureState.sidewayBox.boxHigh - edgeDistance
             || closedBar.close
                <= structureState.sidewayBox.boxLow + edgeDistance;
   }

   bool IsRejection(const PriceStructureState &structureState,
                    const MqlRates &closedBar) const
   {
      if(!HasValidSidewayBounds(structureState))
         return false;

      const bool upperRejection =
         closedBar.high >= structureState.sidewayBox.boxHigh
         && closedBar.close < structureState.sidewayBox.boxHigh;
      const bool lowerRejection =
         closedBar.low <= structureState.sidewayBox.boxLow
         && closedBar.close > structureState.sidewayBox.boxLow;
      return upperRejection || lowerRejection;
   }

   bool HasEventAt(const StructureEvent &events[],
                   const datetime closedBarTime,
                   const ENUM_STRUCTURE_EVENT_TYPE eventType) const
   {
      const int count = ArraySize(events);
      for(int index = count - 1; index >= 0; index--)
      {
         if(events[index].eventBarTime < closedBarTime)
            break;
         if(events[index].eventBarTime == closedBarTime
            && events[index].type == eventType)
            return true;
      }
      return false;
   }

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

   double CalculateATR(const MqlRates &rates[], const int endIndex,
                       const int atrPeriod) const
   {
      const int firstIndex = endIndex - atrPeriod + 1;
      if(atrPeriod < 1 || firstIndex < 1)
         return 0.0;

      double trueRangeSum = 0.0;
      for(int index = firstIndex; index <= endIndex; index++)
      {
         const double previousClose = rates[index - 1].close;
         const double trueRange = MathMax(
            rates[index].high - rates[index].low,
            MathMax(MathAbs(rates[index].high - previousClose),
                    MathAbs(rates[index].low - previousClose)));
         trueRangeSum += trueRange;
      }
      return trueRangeSum / atrPeriod;
   }

public:
   CMarketStructureEngine(void) { Reset(); }

   void Reset(void)
   {
      ResetMicroBase();
      m_microBaseImpulseStartTime = 0;
      m_microBaseConsumed = false;
   }

   ENUM_JINPA_MARKET_STRUCTURE Derive(
      const ENUM_JINPA_MARKET_STATE marketState,
      const PriceStructureState &structureState) const
   {
      if(marketState == JINPA_STATE_COMPRESSION
         && IsSidewayActive(structureState))
         return JINPA_STRUCTURE_SIDEWAY;

      if(marketState == JINPA_STATE_EXPANSION)
         return JINPA_STRUCTURE_BREAKOUT;

      if(marketState == JINPA_STATE_IMPULSE)
         return JINPA_STRUCTURE_CONTINUATION;

      return JINPA_STRUCTURE_NONE;
   }

   ENUM_JINPA_MARKET_STRUCTURE Derive(
      const ENUM_JINPA_MARKET_STATE marketState,
      const PriceStructureState &structureState,
      const MqlRates &closedBar,
      const double edgeDistance,
      const bool falseBreakConfirmed) const
   {
      if(marketState != JINPA_STATE_COMPRESSION
         || !IsSidewayActive(structureState))
         return Derive(marketState, structureState);

      if(falseBreakConfirmed)
         return JINPA_STRUCTURE_FALSE_BREAK;
      if(IsRejection(structureState, closedBar))
         return JINPA_STRUCTURE_REJECTION;
      if(IsRangeEdge(structureState, closedBar, edgeDistance))
         return JINPA_STRUCTURE_RANGE_EDGE;
      return JINPA_STRUCTURE_SIDEWAY;
   }

   bool Apply(const ENUM_JINPA_MARKET_STATE marketState,
              const PriceStructureState &structureState,
              SymbolState &symbolState) const
   {
      const string structureText = JinpaMarketStructureToString(
         Derive(marketState, structureState));
      const bool changed = symbolState.structure != structureText;
      symbolState.structure = structureText;
      return changed;
   }

   bool Apply(const ENUM_JINPA_MARKET_STATE marketState,
              const PriceStructureState &structureState,
              const StructureEvent &events[],
              const MqlRates &rates[],
              const datetime lastClosedBarTime,
              const int atrPeriod,
              const double edgeATRMultiplier,
              SymbolState &symbolState) const
   {
      ENUM_JINPA_MARKET_STRUCTURE structure =
         Derive(marketState, structureState);
      const int closedIndex = FindClosedBarIndex(rates, lastClosedBarTime);
      const bool sidewayConfirmedNow = HasEventAt(
         events, lastClosedBarTime, SIDEWAY_CONFIRMED);
      if(closedIndex >= 0 && !sidewayConfirmedNow)
      {
         const double atr = CalculateATR(rates, closedIndex, atrPeriod);
         const double edgeDistance = atr * MathMax(0.0, edgeATRMultiplier);
         structure = Derive(marketState, structureState,
                            rates[closedIndex], edgeDistance,
                            HasEventAt(events, lastClosedBarTime,
                                       CORE_BREAK_FAILED));
      }

      const string structureText = JinpaMarketStructureToString(structure);
      const bool changed = symbolState.structure != structureText;
      symbolState.structure = structureText;
      return changed;
   }

   bool Apply(const ENUM_JINPA_MARKET_REGIME marketRegime,
              const ENUM_JINPA_MARKET_STATE marketState,
              const datetime impulseStartTime,
              const string previousStructure,
              const PriceStructureState &structureState,
              const StructureEvent &events[],
              const MqlRates &rates[],
              const datetime lastClosedBarTime,
              const int atrPeriod,
              const double edgeATRMultiplier,
              SymbolState &symbolState)
   {
      ENUM_JINPA_MARKET_STRUCTURE structure =
         Derive(marketState, structureState);
      const int closedIndex = FindClosedBarIndex(rates, lastClosedBarTime);
      const bool sidewayConfirmedNow = HasEventAt(
         events, lastClosedBarTime, SIDEWAY_CONFIRMED);
      if(closedIndex >= 0 && !sidewayConfirmedNow
         && marketState == JINPA_STATE_COMPRESSION)
      {
         const double atr = CalculateATR(rates, closedIndex, atrPeriod);
         const double edgeDistance = atr * MathMax(0.0, edgeATRMultiplier);
         structure = Derive(marketState, structureState,
                            rates[closedIndex], edgeDistance,
                            HasEventAt(events, lastClosedBarTime,
                                       CORE_BREAK_FAILED));
      }

      const bool impulseContext = marketRegime == JINPA_REGIME_TREND
                                  && marketState == JINPA_STATE_IMPULSE
                                  && structureState.cycleState.cycle
                                     != MARKET_CYCLE_UNKNOWN;
      const bool newImpulse = impulseContext && impulseStartTime > 0
                              && impulseStartTime
                                 != m_microBaseImpulseStartTime;
      if(newImpulse)
      {
         m_microBaseImpulseStartTime = impulseStartTime;
         structure = RebuildMicroBaseImpulse(
            structureState.cycleState.cycle, rates, impulseStartTime,
            lastClosedBarTime);
      }
      else if(closedIndex >= 0)
         structure = ResolveMicroBase(
            marketRegime, marketState, structureState.cycleState.cycle,
            previousStructure, rates[closedIndex], structure);
      else if(marketRegime != JINPA_REGIME_TREND
              || marketState != JINPA_STATE_IMPULSE)
         ResetMicroBase();

      const string structureText = JinpaMarketStructureToString(structure);
      const bool changed = symbolState.structure != structureText;
      symbolState.structure = structureText;
      return changed;
   }

   bool MicroBaseConfirmed(void) const
   {
      return m_microBase.active && m_microBase.confirmed;
   }

   datetime MicroBaseAnchorTime(void) const
   {
      return m_microBase.anchorTime;
   }

   double MicroBaseHigh(void) const
   {
      return m_microBase.anchorHigh;
   }

   double MicroBaseLow(void) const
   {
      return m_microBase.anchorLow;
   }

   bool MicroBaseConsumed(void) const
   {
      return m_microBaseConsumed;
   }

   datetime MicroBaseImpulseStartTime(void) const
   {
      return m_microBaseImpulseStartTime;
   }
};

#endif
