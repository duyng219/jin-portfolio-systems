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
   JINPA_STRUCTURE_LEG_2
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
   return "NONE";
}

// Stateless Stage 3 projection. STATE owns the broad phase; Stage 2 contributes
// only the authoritative Sideway and Leg flags permitted inside that phase.
class CMarketStructureEngine
{
private:
   bool IsSidewayActive(const PriceStructureState &structureState) const
   {
      return structureState.sidewayBox.active
             || structureState.sidewayBox.sidewayConfirmed
             || structureState.sidewayBox.status == SIDEWAY_BOX_ACTIVE;
   }

public:
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

      if(marketState == JINPA_STATE_CORRECTION)
      {
         if(structureState.sidewayBox.leg2Confirmed)
            return JINPA_STRUCTURE_LEG_2;
         if(structureState.sidewayBox.leg1Confirmed)
            return JINPA_STRUCTURE_LEG_1;
      }

      return JINPA_STRUCTURE_NONE;
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
};

#endif
