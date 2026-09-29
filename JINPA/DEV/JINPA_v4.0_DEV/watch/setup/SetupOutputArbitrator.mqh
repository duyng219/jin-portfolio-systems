#ifndef JINPA_WATCHER_SETUP_OUTPUT_ARBITRATOR_MQH
#define JINPA_WATCHER_SETUP_OUTPUT_ARBITRATOR_MQH

#include "../core/WatcherTypes.mqh"

// Selects one presentation output without mutating any owning setup engine.
class CSetupOutputArbitrator
{
private:
   void Select(const string setup, const string status,
               SymbolState &state) const
   {
      state.setup = setup;
      state.setupStatus = status;
   }

public:
   void Project(const string pullbackSetup,
                const string pullbackStatus,
                const string pmaSetup,
                const string pmaStatus,
                const string rangeSetup,
                const string rangeStatus,
                SymbolState &state) const
   {
      // Preserve Phase 4C confirmed-signal ordering. Persistent overlap with
      // PMA is structurally excluded; explicit PMA priority covers its actual
      // same-bar boundaries against new/stale non-Impulse projections.
      if(pullbackStatus == "ACTIVE")
         Select(pullbackSetup, pullbackStatus, state);
      else if(rangeStatus == "ACTIVE")
         Select(rangeSetup, rangeStatus, state);
      else if(pmaStatus == "ACTIVE")
         Select(pmaSetup, pmaStatus, state);
      else if(pmaStatus == "READY")
         Select(pmaSetup, pmaStatus, state);
      else if(pullbackStatus == "READY")
         Select(pullbackSetup, pullbackStatus, state);
      else if(pmaStatus == "WATCH")
         Select(pmaSetup, pmaStatus, state);
      else if(pullbackStatus == "WATCH")
         Select(pullbackSetup, pullbackStatus, state);
      else if(rangeStatus == "WATCH")
         Select(rangeSetup, rangeStatus, state);
      else if(pmaStatus == "INVALID")
         Select(pmaSetup, pmaStatus, state);
      else if(pullbackStatus == "INVALID")
         Select(pullbackSetup, pullbackStatus, state);
      else if(rangeStatus == "INVALID")
         Select(rangeSetup, rangeStatus, state);
      else
         Select("-", "NONE", state);
   }
};

#endif
