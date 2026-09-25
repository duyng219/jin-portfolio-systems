#ifndef JINPA_WATCHER_PMA_SETUP_ENGINE_MQH
#define JINPA_WATCHER_PMA_SETUP_ENGINE_MQH

#include "../state/MarketStructureEngine.mqh"

enum ENUM_JINPA_PMA_STATUS
{
   JINPA_PMA_STATUS_NONE = 0,
   JINPA_PMA_STATUS_WATCH,
   JINPA_PMA_STATUS_READY,
   JINPA_PMA_STATUS_ACTIVE,
   JINPA_PMA_STATUS_INVALID
};

enum ENUM_JINPA_PMA_DIRECTION
{
   JINPA_PMA_DIRECTION_NONE = 0,
   JINPA_PMA_DIRECTION_BUY,
   JINPA_PMA_DIRECTION_SELL
};

string JinpaPmaStatusToString(const ENUM_JINPA_PMA_STATUS status)
{
   if(status == JINPA_PMA_STATUS_WATCH)
      return "WATCH";
   if(status == JINPA_PMA_STATUS_READY)
      return "READY";
   if(status == JINPA_PMA_STATUS_ACTIVE)
      return "ACTIVE";
   if(status == JINPA_PMA_STATUS_INVALID)
      return "INVALID";
   return "NONE";
}

string JinpaPmaDirectionToString(const ENUM_JINPA_PMA_DIRECTION direction)
{
   if(direction == JINPA_PMA_DIRECTION_BUY)
      return "BUY";
   if(direction == JINPA_PMA_DIRECTION_SELL)
      return "SELL";
   return "NONE";
}

// One closed-bar bres-pma lifecycle per stable Market State Impulse identity.
// Micro Base discovery and lifetime remain owned by MarketStructureEngine.
class CPmaSetupEngine
{
private:
   ENUM_JINPA_PMA_STATUS     m_status;
   ENUM_JINPA_PMA_DIRECTION  m_direction;
   ENUM_MARKET_CYCLE         m_cycle;
   datetime                  m_impulseStartTime;
   datetime                  m_baseTime;
   double                    m_baseHigh;
   double                    m_baseLow;
   datetime                  m_triggerTime;
   datetime                  m_invalidTime;
   datetime                  m_lastBarTime;
   bool                      m_lifecycleUsed;

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

   void ClearBase(void)
   {
      m_baseTime = 0;
      m_baseHigh = 0.0;
      m_baseLow = 0.0;
   }

   void Arm(const datetime impulseStartTime,
            const ENUM_MARKET_CYCLE cycle)
   {
      m_status = JINPA_PMA_STATUS_WATCH;
      m_direction = cycle == MARKET_CYCLE_BULL
                    ? JINPA_PMA_DIRECTION_BUY
                    : JINPA_PMA_DIRECTION_SELL;
      m_cycle = cycle;
      m_impulseStartTime = impulseStartTime;
      m_triggerTime = 0;
      m_invalidTime = 0;
      m_lifecycleUsed = true;
      ClearBase();
   }

   void Invalidate(const datetime closedBarTime)
   {
      if(m_status == JINPA_PMA_STATUS_NONE)
         return;
      m_status = JINPA_PMA_STATUS_INVALID;
      m_invalidTime = closedBarTime;
      m_triggerTime = 0;
   }

   void SnapshotBase(const datetime anchorTime,
                     const double baseHigh,
                     const double baseLow)
   {
      m_baseTime = anchorTime;
      m_baseHigh = baseHigh;
      m_baseLow = baseLow;
      m_status = JINPA_PMA_STATUS_READY;
   }

   int BaseOutcome(const MqlRates &bar) const
   {
      if(m_status != JINPA_PMA_STATUS_READY
         || m_baseTime <= 0 || m_baseHigh <= m_baseLow)
         return 0;
      if(m_cycle == MARKET_CYCLE_BULL)
      {
         if(bar.close > m_baseHigh)
            return 1;
         if(bar.close < m_baseLow)
            return -1;
      }
      else if(m_cycle == MARKET_CYCLE_BEAR)
      {
         if(bar.close < m_baseLow)
            return 1;
         if(bar.close > m_baseHigh)
            return -1;
      }
      return 0;
   }

public:
   CPmaSetupEngine(void) { Reset(); }

   void Reset(void)
   {
      m_status = JINPA_PMA_STATUS_NONE;
      m_direction = JINPA_PMA_DIRECTION_NONE;
      m_cycle = MARKET_CYCLE_UNKNOWN;
      m_impulseStartTime = 0;
      m_triggerTime = 0;
      m_invalidTime = 0;
      m_lastBarTime = 0;
      m_lifecycleUsed = false;
      ClearBase();
   }

   bool Apply(const ENUM_JINPA_MARKET_STATE marketState,
              const datetime impulseStartTime,
              const ENUM_MARKET_CYCLE cycle,
              const bool microBaseConfirmed,
              const bool microBaseConsumed,
              const datetime microBaseImpulseStartTime,
              const datetime microBaseAnchorTime,
              const double microBaseHigh,
              const double microBaseLow,
              const MqlRates &rates[],
              const datetime closedBarTime)
   {
      const ENUM_JINPA_PMA_STATUS oldStatus = m_status;
      const datetime oldImpulse = m_impulseStartTime;
      const datetime oldBase = m_baseTime;
      const int closedIndex = FindClosedBarIndex(rates, closedBarTime);
      if(closedIndex < 0 || closedBarTime <= m_lastBarTime)
         return false;
      m_lastBarTime = closedBarTime;

      const bool newImpulse = marketState == JINPA_STATE_IMPULSE
                              && impulseStartTime > 0
                              && impulseStartTime != m_impulseStartTime;
      if(newImpulse)
      {
         m_status = JINPA_PMA_STATUS_NONE;
         m_direction = JINPA_PMA_DIRECTION_NONE;
         m_cycle = MARKET_CYCLE_UNKNOWN;
         m_impulseStartTime = impulseStartTime;
         m_triggerTime = 0;
         m_invalidTime = 0;
         m_lifecycleUsed = false;
         ClearBase();
         if(cycle != MARKET_CYCLE_UNKNOWN)
            Arm(impulseStartTime, cycle);
      }

      if(m_status == JINPA_PMA_STATUS_ACTIVE
         && closedBarTime > m_triggerTime)
      {
         m_status = JINPA_PMA_STATUS_INVALID;
         m_invalidTime = closedBarTime;
         return true;
      }
      if(m_status == JINPA_PMA_STATUS_INVALID
         && closedBarTime > m_invalidTime)
      {
         m_status = JINPA_PMA_STATUS_NONE;
         m_direction = JINPA_PMA_DIRECTION_NONE;
         m_triggerTime = 0;
         m_invalidTime = 0;
         ClearBase();
         return true;
      }

      // READY owns an immutable Base. Resolve its close outcome before any
      // same-bar State/Cycle invalidation, because Market State runs first.
      if(m_status == JINPA_PMA_STATUS_READY)
      {
         const int outcome = BaseOutcome(rates[closedIndex]);
         if(outcome > 0)
         {
            m_status = JINPA_PMA_STATUS_ACTIVE;
            m_triggerTime = closedBarTime;
            m_invalidTime = 0;
            return true;
         }
         if(outcome < 0)
         {
            Invalidate(closedBarTime);
            return true;
         }
      }

      const bool validImpulse = marketState == JINPA_STATE_IMPULSE
                                && impulseStartTime > 0
                                && impulseStartTime == m_impulseStartTime
                                && cycle != MARKET_CYCLE_UNKNOWN
                                && cycle == m_cycle;
      if((m_status == JINPA_PMA_STATUS_WATCH
          || m_status == JINPA_PMA_STATUS_READY)
         && !validImpulse)
      {
         Invalidate(closedBarTime);
         return true;
      }

      if(m_status == JINPA_PMA_STATUS_WATCH
         && microBaseConfirmed && microBaseConsumed
         && microBaseImpulseStartTime == m_impulseStartTime
         && microBaseAnchorTime > 0
         && microBaseHigh > microBaseLow)
      {
         SnapshotBase(microBaseAnchorTime,
                      microBaseHigh, microBaseLow);
         return true;
      }

      if(m_status == JINPA_PMA_STATUS_READY)
      {
         const bool sameConfirmedBase = microBaseConfirmed
            && microBaseConsumed
            && microBaseImpulseStartTime == m_impulseStartTime
            && microBaseAnchorTime == m_baseTime;
         if(!sameConfirmedBase)
         {
            Invalidate(closedBarTime);
            return true;
         }
      }

      return oldStatus != m_status || oldImpulse != m_impulseStartTime
             || oldBase != m_baseTime;
   }

   string SetupText(void) const
   {
      return m_status == JINPA_PMA_STATUS_NONE ? "-" : "bres-pma";
   }
   string StatusText(void) const
   {
      return JinpaPmaStatusToString(m_status);
   }
   ENUM_JINPA_PMA_STATUS Status(void) const { return m_status; }
   ENUM_JINPA_PMA_DIRECTION Direction(void) const { return m_direction; }
   ENUM_MARKET_CYCLE Cycle(void) const { return m_cycle; }
   datetime ImpulseStartTime(void) const { return m_impulseStartTime; }
   datetime BaseTime(void) const { return m_baseTime; }
   double BaseHigh(void) const { return m_baseHigh; }
   double BaseLow(void) const { return m_baseLow; }
   datetime TriggerBarTime(void) const { return m_triggerTime; }
   bool LifecycleUsed(void) const { return m_lifecycleUsed; }
};

#endif
