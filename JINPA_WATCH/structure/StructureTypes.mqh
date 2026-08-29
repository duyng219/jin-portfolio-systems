#ifndef JINPA_WATCHER_STRUCTURE_TYPES_MQH
#define JINPA_WATCHER_STRUCTURE_TYPES_MQH

enum ENUM_SWING_TYPE
{
   SWING_NONE = 0,
   SWING_HIGH,
   SWING_LOW
};

enum ENUM_STRUCTURE_POINT
{
   STRUCT_NONE = 0,
   STRUCT_HH,
   STRUCT_HL,
   STRUCT_LH,
   STRUCT_LL,
   STRUCT_EQUAL_HIGH,
   STRUCT_EQUAL_LOW
};

enum ENUM_BASIC_STRUCTURE
{
   BASIC_STRUCTURE_UNKNOWN = 0,
   BASIC_STRUCTURE_BULL,
   BASIC_STRUCTURE_BEAR,
   BASIC_STRUCTURE_MIXED
};

enum ENUM_CORE_SWING_TYPE
{
   CORE_SWING_NONE = 0,
   CORE_SWING_HIGH,
   CORE_SWING_LOW
};

enum ENUM_MARKET_CYCLE
{
   MARKET_CYCLE_UNKNOWN = 0,
   MARKET_CYCLE_BULL,
   MARKET_CYCLE_BEAR
};

enum ENUM_SIDEWAY_BOX_STATUS
{
   SIDEWAY_BOX_NONE = 0,
   SIDEWAY_BOX_CANDIDATE,
   SIDEWAY_BOX_ACTIVE,
   SIDEWAY_BOX_BROKEN,
   SIDEWAY_BOX_CANCELLED
};

enum ENUM_SIDEWAY_CANDIDATE_WAIT
{
   SIDEWAY_WAIT_NONE = 0,
   SIDEWAY_WAIT_POST_LL_HIGH,
   SIDEWAY_WAIT_POST_HH_LOW
};

enum ENUM_STRUCTURE_EVENT_TYPE
{
   STRUCTURE_EVENT_NONE = 0,
   CORE_SWING_INITIALIZED,
   CORE_SWING_CHANGED,
   CORE_BREAK_CANDIDATE,
   CORE_BREAK_FAILED,
   CYCLE_CHANGED
};

struct SwingPoint
{
   datetime             time;
   int                  shift;
   double               price;
   ENUM_SWING_TYPE      type;
   ENUM_STRUCTURE_POINT classification;
   datetime             confirmationTime;
   int                  originSwingRecordIndex;
   datetime             originSwingTime;
   double               originSwingPrice;
   bool                 confirmed;
};

struct CoreSwingState
{
   bool                 initialized;
   double               coreSwingHigh;
   double               coreSwingLow;
   datetime             coreSwingHighTime;
   datetime             coreSwingLowTime;
   bool                 hasCoreHigh;
   bool                 hasCoreLow;
   ENUM_CORE_SWING_TYPE activeCoreType;
   datetime             lastCoreUpdate;
};

struct SidewayBoxState
{
   ENUM_SIDEWAY_BOX_STATUS status;
   bool                 active;
   bool                 candidateActive;
   double               candidateBoxHigh;
   datetime             candidateBoxHighTime;
   double               candidateBoxLow;
   datetime             candidateBoxLowTime;
   datetime             candidateStartTime;
   datetime             candidateCreatedTime;
   int                  candidateBoundaryRecord;
   int                  candidatePullbackRecord;
   int                  candidateReversalRecord;
   int                  candidateTerminalRecord;
   datetime             candidateBoundaryTime;
   datetime             candidatePullbackTime;
   datetime             candidateReversalTime;
   datetime             candidateTerminalTime;
   datetime             candidateTerminalConfirmationTime;
   ENUM_SIDEWAY_CANDIDATE_WAIT candidateWaitState;
   ENUM_MARKET_CYCLE    cycleAtCandidate;
   double               coreAtCandidate;
   double               boxHigh;
   datetime             boxHighTime;
   double               boxLow;
   datetime             boxLowTime;
   datetime             boxStartTime;
   datetime             confirmedTime;
   datetime             lastUpdateTime;
   ENUM_MARKET_CYCLE    ownerCycle;
   double               activeCoreAtEntry;
};

struct CycleState
{
   ENUM_MARKET_CYCLE cycle;
   bool              breakCandidate;
   datetime          breakCandidateTime;
   double            breakLevel;
   double            brokenCoreLevel;
   int               confirmationCount;
   datetime          lastCycleChange;
};

struct PriceStructureState
{
   SwingPoint          lastSwingHigh;
   SwingPoint          previousSwingHigh;
   SwingPoint          lastSwingLow;
   SwingPoint          previousSwingLow;

   CoreSwingState      coreSwing;
   CycleState          cycleState;
   SidewayBoxState     sidewayBox;

   string              highStructure;
   string              lowStructure;
   string              structureSummary;
   ENUM_BASIC_STRUCTURE basicStructure;

   string              lastEvent;
   datetime            lastEventTime;
   datetime            lastStructureUpdate;
   bool                initialized;
};

struct StructureEvent
{
   ENUM_STRUCTURE_EVENT_TYPE type;
   string                    symbol;
   ENUM_TIMEFRAMES           timeframe;
   datetime                  eventBarTime;
   ENUM_MARKET_CYCLE         cycleBefore;
   ENUM_MARKET_CYCLE         cycleAfter;
   ENUM_CORE_SWING_TYPE      coreType;
   double                    oldCoreLevel;
   double                    newCoreLevel;
   double                    breakLevel;
   string                    reason;
   string                    identity;
};

struct StructureSwingRecord
{
   int        contextIndex;
   SwingPoint point;
};

struct BrokenCoreRecord
{
   string               symbol;
   ENUM_TIMEFRAMES      timeframe;
   ENUM_CORE_SWING_TYPE coreType;
   double               price;
   datetime             originTime;
   datetime             confirmationBreakTime;
   ENUM_MARKET_CYCLE    oldCycle;
   ENUM_MARKET_CYCLE    newCycle;
};

struct SidewayBoxRecord
{
   string                  symbol;
   ENUM_TIMEFRAMES         timeframe;
   double                  boxHigh;
   double                  boxLow;
   datetime                boxStartTime;
   datetime                boxEndTime;
   ENUM_SIDEWAY_BOX_STATUS endStatus;
};

struct PendingContinuationState
{
   bool                 active;
   ENUM_SWING_TYPE      referenceType;
   double               referencePrice;
   datetime             referenceTime;
   datetime             referenceConfirmationTime;
   datetime             breakTime;
   double               breakThreshold;
   ENUM_MARKET_CYCLE    cycleAtBreak;
   bool                 fromSidewayBox;
};

string StructurePointToString(const ENUM_STRUCTURE_POINT classification)
{
   switch(classification)
   {
      case STRUCT_HH:         return "HH";
      case STRUCT_HL:         return "HL";
      case STRUCT_LH:         return "LH";
      case STRUCT_LL:         return "LL";
      case STRUCT_EQUAL_HIGH: return "EH";
      case STRUCT_EQUAL_LOW:  return "EL";
      default:                return "-";
   }
}

string MarketCycleToString(const ENUM_MARKET_CYCLE cycle)
{
   switch(cycle)
   {
      case MARKET_CYCLE_BULL: return "BULL";
      case MARKET_CYCLE_BEAR: return "BEAR";
      default:                return "UNKNOWN";
   }
}

string CoreSwingTypeToString(const ENUM_CORE_SWING_TYPE coreType)
{
   switch(coreType)
   {
      case CORE_SWING_HIGH: return "Core High";
      case CORE_SWING_LOW:  return "Core Low";
      default:              return "Core";
   }
}

string StructureEventTypeToString(const ENUM_STRUCTURE_EVENT_TYPE eventType)
{
   switch(eventType)
   {
      case CORE_SWING_INITIALIZED: return "CORE_SWING_INITIALIZED";
      case CORE_SWING_CHANGED:     return "CORE_SWING_CHANGED";
      case CORE_BREAK_CANDIDATE:   return "CORE_BREAK_CANDIDATE";
      case CORE_BREAK_FAILED:      return "CORE_BREAK_FAILED";
      case CYCLE_CHANGED:          return "CYCLE_CHANGED";
      default:                     return "NONE";
   }
}

void ResetSwingPoint(SwingPoint &point)
{
   point.time           = 0;
   point.shift          = -1;
   point.price          = 0.0;
   point.type           = SWING_NONE;
   point.classification = STRUCT_NONE;
   point.confirmationTime = 0;
   point.originSwingRecordIndex = -1;
   point.originSwingTime = 0;
   point.originSwingPrice = 0.0;
   point.confirmed      = false;
}

void ResetCoreSwingState(CoreSwingState &state)
{
   state.initialized       = false;
   state.coreSwingHigh     = 0.0;
   state.coreSwingLow      = 0.0;
   state.coreSwingHighTime = 0;
   state.coreSwingLowTime  = 0;
   state.hasCoreHigh       = false;
   state.hasCoreLow        = false;
   state.activeCoreType    = CORE_SWING_NONE;
   state.lastCoreUpdate    = 0;
}

void ResetSidewayBoxState(SidewayBoxState &state)
{
   state.status            = SIDEWAY_BOX_NONE;
   state.active            = false;
   state.candidateActive   = false;
   state.candidateBoxHigh  = 0.0;
   state.candidateBoxHighTime = 0;
   state.candidateBoxLow   = 0.0;
   state.candidateBoxLowTime = 0;
   state.candidateStartTime = 0;
   state.candidateCreatedTime = 0;
   state.candidateBoundaryRecord = -1;
   state.candidatePullbackRecord = -1;
   state.candidateReversalRecord = -1;
   state.candidateTerminalRecord = -1;
   state.candidateBoundaryTime = 0;
   state.candidatePullbackTime = 0;
   state.candidateReversalTime = 0;
   state.candidateTerminalTime = 0;
   state.candidateTerminalConfirmationTime = 0;
   state.candidateWaitState = SIDEWAY_WAIT_NONE;
   state.cycleAtCandidate  = MARKET_CYCLE_UNKNOWN;
   state.coreAtCandidate   = 0.0;
   state.boxHigh           = 0.0;
   state.boxHighTime       = 0;
   state.boxLow            = 0.0;
   state.boxLowTime        = 0;
   state.boxStartTime      = 0;
   state.confirmedTime     = 0;
   state.lastUpdateTime    = 0;
   state.ownerCycle        = MARKET_CYCLE_UNKNOWN;
   state.activeCoreAtEntry = 0.0;
}

void ResetPendingContinuationState(PendingContinuationState &state)
{
   state.active                    = false;
   state.referenceType             = SWING_NONE;
   state.referencePrice            = 0.0;
   state.referenceTime             = 0;
   state.referenceConfirmationTime = 0;
   state.breakTime                  = 0;
   state.breakThreshold             = 0.0;
   state.cycleAtBreak               = MARKET_CYCLE_UNKNOWN;
   state.fromSidewayBox             = false;
}

void ResetCycleState(CycleState &state)
{
   state.cycle             = MARKET_CYCLE_UNKNOWN;
   state.breakCandidate    = false;
   state.breakCandidateTime = 0;
   state.breakLevel        = 0.0;
   state.brokenCoreLevel   = 0.0;
   state.confirmationCount = 0;
   state.lastCycleChange   = 0;
}

void ResetPriceStructureState(PriceStructureState &state)
{
   ResetSwingPoint(state.lastSwingHigh);
   ResetSwingPoint(state.previousSwingHigh);
   ResetSwingPoint(state.lastSwingLow);
   ResetSwingPoint(state.previousSwingLow);

   ResetCoreSwingState(state.coreSwing);
   ResetCycleState(state.cycleState);
   ResetSidewayBoxState(state.sidewayBox);
   state.highStructure       = "-";
   state.lowStructure        = "-";
   state.structureSummary    = "UNKNOWN";
   state.basicStructure      = BASIC_STRUCTURE_UNKNOWN;
   state.lastEvent           = "";
   state.lastEventTime       = 0;
   state.lastStructureUpdate = 0;
   state.initialized         = false;
}

#endif
