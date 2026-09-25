#ifndef JINPA_WATCHER_RANGE_EDGE_SETUP_ENGINE_MQH
#define JINPA_WATCHER_RANGE_EDGE_SETUP_ENGINE_MQH

#include "../state/MarketStructureEngine.mqh"

enum ENUM_JINPA_RANGE_EDGE_SETUP
{
   JINPA_RANGE_SETUP_NONE = 0,
   JINPA_RANGE_SETUP_BRES_PMB,
   JINPA_RANGE_SETUP_REVS_PFB,
   JINPA_RANGE_SETUP_REVS_PMR
};

enum ENUM_JINPA_RANGE_EDGE_STATUS
{
   JINPA_RANGE_STATUS_NONE = 0,
   JINPA_RANGE_STATUS_WATCH,
   JINPA_RANGE_STATUS_ACTIVE,
   JINPA_RANGE_STATUS_INVALID
};

enum ENUM_JINPA_SETUP_DIRECTION
{
   JINPA_DIRECTION_NONE = 0,
   JINPA_DIRECTION_BUY,
   JINPA_DIRECTION_SELL
};

string JinpaRangeEdgeSetupToString(const ENUM_JINPA_RANGE_EDGE_SETUP setup)
{
   if(setup == JINPA_RANGE_SETUP_BRES_PMB)
      return "bres-pmb";
   if(setup == JINPA_RANGE_SETUP_REVS_PFB)
      return "revs-pfb";
   if(setup == JINPA_RANGE_SETUP_REVS_PMR)
      return "revs-pmr";
   return "-";
}

string JinpaRangeEdgeStatusToString(const ENUM_JINPA_RANGE_EDGE_STATUS status)
{
   if(status == JINPA_RANGE_STATUS_WATCH)
      return "WATCH";
   if(status == JINPA_RANGE_STATUS_ACTIVE)
      return "ACTIVE";
   if(status == JINPA_RANGE_STATUS_INVALID)
      return "INVALID";
   return "NONE";
}

string JinpaSetupDirectionToString(const ENUM_JINPA_SETUP_DIRECTION direction)
{
   if(direction == JINPA_DIRECTION_BUY)
      return "BUY";
   if(direction == JINPA_DIRECTION_SELL)
      return "SELL";
   return "NONE";
}

// Closed-bar setup lifecycle for one retained Range Edge episode. Price and
// event geometry remain owned by MarketStructureEngine/PriceStructureEngine.
class CRangeEdgeSetupEngine
{
private:
   bool                          m_episodeEstablished;
   bool                          m_armed;
   bool                          m_consumed;
   bool                          m_wasAtEdge;
   ENUM_JINPA_RANGE_EDGE_SIDE    m_edgeSide;
   datetime                      m_edgeEntryTime;
   long                          m_ownerGeneration;
   ENUM_MARKET_CYCLE             m_armedCycle;
   ENUM_JINPA_RANGE_EDGE_SETUP   m_setup;
   ENUM_JINPA_RANGE_EDGE_STATUS  m_status;
   ENUM_JINPA_SETUP_DIRECTION    m_direction;
   datetime                      m_triggerTime;
   datetime                      m_invalidTime;
   datetime                      m_lastBarTime;

   bool IsSidewayActive(const PriceStructureState &source) const
   {
      return source.sidewayBox.active
             || source.sidewayBox.sidewayConfirmed
             || source.sidewayBox.status == SIDEWAY_BOX_ACTIVE;
   }

   long OwnerGeneration(const PriceStructureState &source) const
   {
      if(source.sidewayBox.ownerBoxGeneration > 0)
         return source.sidewayBox.ownerBoxGeneration;
      return source.coreBox.generation;
   }

   bool FindEventAt(const StructureEvent &events[],
                    const datetime barTime,
                    const ENUM_STRUCTURE_EVENT_TYPE type,
                    StructureEvent &event) const
   {
      for(int index = ArraySize(events) - 1; index >= 0; index--)
      {
         if(events[index].eventBarTime < barTime)
            break;
         if(events[index].eventBarTime == barTime
            && events[index].type == type
            && events[index].boxGeneration == m_ownerGeneration)
         {
            event = events[index];
            return true;
         }
      }
      return false;
   }

   bool EligibleReversal(void) const
   {
      return (m_armedCycle == MARKET_CYCLE_BULL
              && m_edgeSide == JINPA_EDGE_LOWER)
             || (m_armedCycle == MARKET_CYCLE_BEAR
                 && m_edgeSide == JINPA_EDGE_UPPER);
   }

   ENUM_JINPA_SETUP_DIRECTION EdgeDirection(void) const
   {
      if(m_edgeSide == JINPA_EDGE_UPPER)
         return JINPA_DIRECTION_BUY;
      if(m_edgeSide == JINPA_EDGE_LOWER)
         return JINPA_DIRECTION_SELL;
      return JINPA_DIRECTION_NONE;
   }

   ENUM_JINPA_SETUP_DIRECTION ReversalDirection(void) const
   {
      if(m_armedCycle == MARKET_CYCLE_BULL
         && m_edgeSide == JINPA_EDGE_LOWER)
         return JINPA_DIRECTION_BUY;
      if(m_armedCycle == MARKET_CYCLE_BEAR
         && m_edgeSide == JINPA_EDGE_UPPER)
         return JINPA_DIRECTION_SELL;
      return JINPA_DIRECTION_NONE;
   }

   void BeginEpisode(const ENUM_JINPA_RANGE_EDGE_SIDE side,
                     const datetime entryTime,
                     const long ownerGeneration,
                     const ENUM_MARKET_CYCLE cycle)
   {
      m_episodeEstablished = true;
      m_armed = true;
      m_consumed = false;
      m_wasAtEdge = true;
      m_edgeSide = side;
      m_edgeEntryTime = entryTime;
      m_ownerGeneration = ownerGeneration;
      m_armedCycle = cycle;
      m_setup = JINPA_RANGE_SETUP_NONE;
      m_status = JINPA_RANGE_STATUS_WATCH;
      m_direction = JINPA_DIRECTION_NONE;
      m_triggerTime = 0;
      m_invalidTime = 0;
   }

   void EndUnresolvedEpisode(void)
   {
      m_armed = false;
      m_wasAtEdge = false;
      m_setup = JINPA_RANGE_SETUP_NONE;
      m_status = JINPA_RANGE_STATUS_NONE;
      m_direction = JINPA_DIRECTION_NONE;
      m_triggerTime = 0;
      m_invalidTime = 0;
   }

   void Activate(const ENUM_JINPA_RANGE_EDGE_SETUP setup,
                 const ENUM_JINPA_SETUP_DIRECTION direction,
                 const datetime triggerTime)
   {
      m_setup = setup;
      m_status = JINPA_RANGE_STATUS_ACTIVE;
      m_direction = direction;
      m_triggerTime = triggerTime;
      m_invalidTime = 0;
      m_consumed = true;
      m_armed = false;
   }

   bool TryResolveOutcome(const StructureEvent &events[],
                          const datetime closedBarTime,
                          const string marketStructure,
                          const ENUM_JINPA_RANGE_EDGE_SIDE currentEdgeSide)
   {
      if(!m_episodeEstablished || !m_armed || m_consumed)
         return false;

      StructureEvent event;
      if(FindEventAt(events, closedBarTime,
                     CORE_BOX_TRANSITION_STARTED, event))
      {
         const bool matchingBreak =
            (m_edgeSide == JINPA_EDGE_UPPER
             && event.cycleAfter == MARKET_CYCLE_BULL)
            || (m_edgeSide == JINPA_EDGE_LOWER
                && event.cycleAfter == MARKET_CYCLE_BEAR);
         if(matchingBreak)
         {
            Activate(JINPA_RANGE_SETUP_BRES_PMB,
                     EdgeDirection(), closedBarTime);
            return true;
         }
      }

      const bool sameRetainedSide = currentEdgeSide == JINPA_EDGE_NONE
                                    || currentEdgeSide == m_edgeSide;
      if(FindEventAt(events, closedBarTime, CORE_BREAK_FAILED, event)
         && sameRetainedSide
         && EligibleReversal())
      {
         Activate(JINPA_RANGE_SETUP_REVS_PFB,
                  ReversalDirection(), closedBarTime);
         return true;
      }

      if(marketStructure == "REJECTION" && sameRetainedSide
         && EligibleReversal())
      {
         Activate(JINPA_RANGE_SETUP_REVS_PMR,
                  ReversalDirection(), closedBarTime);
         return true;
      }
      return false;
   }

public:
   CRangeEdgeSetupEngine(void) { Reset(); }

   void Reset(void)
   {
      m_episodeEstablished = false;
      m_armed = false;
      m_consumed = false;
      m_wasAtEdge = false;
      m_edgeSide = JINPA_EDGE_NONE;
      m_edgeEntryTime = 0;
      m_ownerGeneration = 0;
      m_armedCycle = MARKET_CYCLE_UNKNOWN;
      m_setup = JINPA_RANGE_SETUP_NONE;
      m_status = JINPA_RANGE_STATUS_NONE;
      m_direction = JINPA_DIRECTION_NONE;
      m_triggerTime = 0;
      m_invalidTime = 0;
      m_lastBarTime = 0;
   }

   bool Apply(const ENUM_JINPA_MARKET_STATE marketState,
              const PriceStructureState &source,
              const StructureEvent &events[],
              const datetime closedBarTime,
              const string marketStructure,
              const ENUM_JINPA_RANGE_EDGE_SIDE currentEdgeSide)
   {
      const ENUM_JINPA_RANGE_EDGE_SETUP oldSetup = m_setup;
      const ENUM_JINPA_RANGE_EDGE_STATUS oldStatus = m_status;
      const bool oldArmed = m_armed;
      const bool oldConsumed = m_consumed;
      const datetime oldEntry = m_edgeEntryTime;

      if(closedBarTime <= 0 || closedBarTime <= m_lastBarTime)
         return false;
      m_lastBarTime = closedBarTime;

      if(m_status == JINPA_RANGE_STATUS_ACTIVE
         && closedBarTime > m_triggerTime)
      {
         m_status = JINPA_RANGE_STATUS_INVALID;
         m_invalidTime = closedBarTime;
         return true;
      }
      if(m_status == JINPA_RANGE_STATUS_INVALID
         && closedBarTime > m_invalidTime)
      {
         m_setup = JINPA_RANGE_SETUP_NONE;
         m_status = JINPA_RANGE_STATUS_NONE;
         m_direction = JINPA_DIRECTION_NONE;
         m_triggerTime = 0;
         m_invalidTime = 0;
      }

      // Resolve retained ownership before generic State/Cycle/Sideway cleanup.
      // This preserves confirmed-break and false-break authority on their bar.
      if(TryResolveOutcome(events, closedBarTime, marketStructure,
                           currentEdgeSide))
         return true;

      const bool validContext = marketState == JINPA_STATE_COMPRESSION
                                && IsSidewayActive(source)
                                && source.cycleState.cycle
                                   != MARKET_CYCLE_UNKNOWN;
      const long generation = OwnerGeneration(source);
      if(!validContext)
      {
         if(m_status == JINPA_RANGE_STATUS_WATCH)
            EndUnresolvedEpisode();
         else
            m_wasAtEdge = false;
      }
      else if(m_episodeEstablished
              && source.cycleState.cycle != m_armedCycle)
      {
         // A confirmed break has already had its same-bar resolution chance
         // above. Any remaining Cycle change invalidates the old ownership.
         EndUnresolvedEpisode();
         m_episodeEstablished = false;
      }
      else if(m_episodeEstablished
              && generation != m_ownerGeneration)
      {
         if(currentEdgeSide != JINPA_EDGE_NONE
            && marketStructure == "RANGE EDGE")
            BeginEpisode(currentEdgeSide, closedBarTime, generation,
                         source.cycleState.cycle);
         else
         {
            EndUnresolvedEpisode();
            m_episodeEstablished = false;
            m_ownerGeneration = generation;
         }
      }
      else if(marketStructure == "RANGE EDGE"
              && currentEdgeSide != JINPA_EDGE_NONE)
      {
         const bool newEpisode = !m_episodeEstablished || !m_wasAtEdge
                                 || currentEdgeSide != m_edgeSide;
         if(newEpisode)
            BeginEpisode(currentEdgeSide, closedBarTime, generation,
                         source.cycleState.cycle);
         else
            m_wasAtEdge = true;
      }
      else if((marketStructure == "REJECTION"
               || marketStructure == "FALSE BREAK")
              && m_episodeEstablished
              && generation == m_ownerGeneration)
      {
         // A priority projection may hide RANGE EDGE on the resolution bar.
         // An ineligible outcome does not consume or erase the episode.
         m_wasAtEdge = true;
      }
      else if(m_status == JINPA_RANGE_STATUS_WATCH)
         EndUnresolvedEpisode();
      else
         m_wasAtEdge = false;

      return oldSetup != m_setup || oldStatus != m_status
             || oldArmed != m_armed || oldConsumed != m_consumed
             || oldEntry != m_edgeEntryTime;
   }

   string SetupText(void) const
   {
      if(m_status == JINPA_RANGE_STATUS_WATCH && m_armed)
         return "edge-mix";
      return JinpaRangeEdgeSetupToString(m_setup);
   }

   string StatusText(void) const
   {
      return JinpaRangeEdgeStatusToString(m_status);
   }

   bool IsArmed(void) const { return m_armed; }
   bool IsConsumed(void) const { return m_consumed; }
   ENUM_JINPA_RANGE_EDGE_SIDE EdgeSide(void) const { return m_edgeSide; }
   datetime EdgeEntryTime(void) const { return m_edgeEntryTime; }
   long OwnerBoxGeneration(void) const { return m_ownerGeneration; }
   ENUM_MARKET_CYCLE ArmedCycle(void) const { return m_armedCycle; }
   ENUM_JINPA_RANGE_EDGE_SETUP Setup(void) const { return m_setup; }
   ENUM_JINPA_RANGE_EDGE_STATUS Status(void) const { return m_status; }
   ENUM_JINPA_SETUP_DIRECTION Direction(void) const { return m_direction; }
   datetime TriggerBarTime(void) const { return m_triggerTime; }
};

#endif
