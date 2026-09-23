#ifndef JINPA_WATCHER_PULLBACK_SETUP_ENGINE_MQH
#define JINPA_WATCHER_PULLBACK_SETUP_ENGINE_MQH
#include "../state/MarketStructureEngine.mqh"

enum ENUM_JINPA_SETUP { JINPA_SETUP_NONE=0, JINPA_SETUP_REVS_PPF, JINPA_SETUP_REVS_PPS };
enum ENUM_JINPA_SETUP_STATUS { JINPA_SETUP_STATUS_NONE=0, JINPA_SETUP_STATUS_WATCH, JINPA_SETUP_STATUS_READY, JINPA_SETUP_STATUS_ACTIVE, JINPA_SETUP_STATUS_INVALID };

string JinpaSetupToString(const ENUM_JINPA_SETUP v)
{ if(v==JINPA_SETUP_REVS_PPF) return "revs-ppf"; if(v==JINPA_SETUP_REVS_PPS) return "revs-pps"; return "-"; }
string JinpaSetupStatusToString(const ENUM_JINPA_SETUP_STATUS v)
{ if(v==JINPA_SETUP_STATUS_WATCH) return "WATCH"; if(v==JINPA_SETUP_STATUS_READY) return "READY"; if(v==JINPA_SETUP_STATUS_ACTIVE) return "ACTIVE"; if(v==JINPA_SETUP_STATUS_INVALID) return "INVALID"; return "NONE"; }

// Unified closed-bar authority: a confirmed SwingPoint creates a base; only
// a later close through that pivot candle confirms the Leg and Setup together.
class CPullbackSetupEngine
{
private:
   ENUM_JINPA_SETUP m_setup;
   ENUM_JINPA_SETUP_STATUS m_status;
   ENUM_MARKET_CYCLE m_cycle;
   double m_baseHigh,m_baseLow,m_candidatePrice;
   datetime m_baseTime,m_candidateTime,m_candidateConfirm,m_triggerTime;
   datetime m_invalidTime,m_lastBar,m_correctionStart;
   datetime m_leg1Candidate,m_leg1CandidateConfirm,m_leg1Bar;
   datetime m_leg2Candidate,m_leg2CandidateConfirm,m_leg2Bar;
   datetime m_turningTime,m_turningConfirm;
   int m_swingRightBars;

   int BarIndex(const MqlRates &rates[],const datetime time) const
   { for(int i=ArraySize(rates)-1;i>=0;i--){ if(rates[i].time==time) return i; if(rates[i].time<time) break; } return -1; }
   void ClearCandidate(void)
   { m_baseHigh=0; m_baseLow=0; m_candidatePrice=0; m_baseTime=0; m_candidateTime=0; m_candidateConfirm=0; m_triggerTime=0; }
   void ClearSetup(void)
   { m_setup=JINPA_SETUP_NONE; m_status=JINPA_SETUP_STATUS_NONE; m_invalidTime=0; ClearCandidate(); }
   void ClearLegs(void)
   { m_leg1Candidate=0; m_leg1CandidateConfirm=0; m_leg1Bar=0; m_leg2Candidate=0; m_leg2CandidateConfirm=0; m_leg2Bar=0; m_turningTime=0; m_turningConfirm=0; }
   void Watch(const ENUM_JINPA_SETUP setup)
   { m_setup=setup; m_status=JINPA_SETUP_STATUS_WATCH; m_invalidTime=0; ClearCandidate(); }
   void Invalidate(const datetime time)
   { if(m_setup==JINPA_SETUP_NONE) return; m_status=JINPA_SETUP_STATUS_INVALID; m_invalidTime=time; ClearCandidate(); }
   ENUM_SWING_TYPE CandidateType(void) const
   { return m_cycle==MARKET_CYCLE_BULL?SWING_LOW:(m_cycle==MARKET_CYCLE_BEAR?SWING_HIGH:SWING_NONE); }
   ENUM_SWING_TYPE TurningType(void) const
   { return m_cycle==MARKET_CYCLE_BULL?SWING_HIGH:(m_cycle==MARKET_CYCLE_BEAR?SWING_LOW:SWING_NONE); }
   bool FindSwing(const SwingPoint &swings[],const ENUM_SWING_TYPE type,const datetime bar,const datetime minPivot,const datetime minConfirm,SwingPoint &out) const
   { ResetSwingPoint(out); for(int i=ArraySize(swings)-1;i>=0;i--){ SwingPoint p=swings[i]; if(p.confirmed&&p.type==type&&p.confirmationTime==bar&&p.time>minPivot&&p.confirmationTime>minConfirm){out=p;return true;} } return false; }
   bool SelectCandidate(const SwingPoint &point,const MqlRates &rates[])
   {
      if(point.time==m_candidateTime&&point.confirmationTime==m_candidateConfirm) return false;
      if(m_status==JINPA_SETUP_STATUS_READY&&m_candidateTime>0)
      { if(m_cycle==MARKET_CYCLE_BULL&&point.price>=m_candidatePrice) return false; if(m_cycle==MARKET_CYCLE_BEAR&&point.price<=m_candidatePrice) return false; }
      int i=BarIndex(rates,point.time); int end=i+m_swingRightBars;
      if(i<0||m_swingRightBars<1||end>=ArraySize(rates)
         ||rates[end].time!=point.confirmationTime) return false;
      m_candidateTime=point.time; m_candidateConfirm=point.confirmationTime; m_candidatePrice=point.price;
      m_baseTime=point.time;
      if(m_cycle==MARKET_CYCLE_BULL)
      { m_baseLow=rates[i].low;m_baseHigh=rates[i].high;for(int j=i+1;j<=end;j++)m_baseHigh=MathMax(m_baseHigh,rates[j].high); }
      else
      { m_baseHigh=rates[i].high;m_baseLow=rates[i].low;for(int j=i+1;j<=end;j++)m_baseLow=MathMin(m_baseLow,rates[j].low); }
      m_triggerTime=0;m_status=JINPA_SETUP_STATUS_READY;return true;
   }
   bool CandidateAt(const SwingPoint &swings[],const MqlRates &rates[],const datetime bar)
   {
      datetime minPivot=0,minConfirm=m_correctionStart;
      if(m_setup==JINPA_SETUP_REVS_PPS){minPivot=m_turningTime;minConfirm=m_turningConfirm;}
      SwingPoint p; return FindSwing(swings,CandidateType(),bar,minPivot,minConfirm,p)&&SelectCandidate(p,rates);
   }
   bool TurningAt(const SwingPoint &swings[],const datetime bar,SwingPoint &out) const
   { return m_leg1Bar>0&&FindSwing(swings,TurningType(),bar,m_leg1Candidate,m_leg1Bar,out); }
   int BaseOutcome(const MqlRates &bar) const
   {
      if(m_status!=JINPA_SETUP_STATUS_READY||bar.time<=m_candidateConfirm) return 0;
      if(m_cycle==MARKET_CYCLE_BULL)
      { if(bar.close>m_baseHigh)return 1; if(bar.close<m_baseLow)return -1; }
      else if(m_cycle==MARKET_CYCLE_BEAR)
      { if(bar.close<m_baseLow)return 1; if(bar.close>m_baseHigh)return -1; }
      return 0;
   }
   void FailBase(void)
   { m_status=JINPA_SETUP_STATUS_WATCH;m_invalidTime=0;ClearCandidate(); }
   void Activate(const datetime bar)
   {
      m_status=JINPA_SETUP_STATUS_ACTIVE;m_triggerTime=bar;m_invalidTime=0;
      if(m_setup==JINPA_SETUP_REVS_PPF){m_leg1Candidate=m_candidateTime;m_leg1CandidateConfirm=m_candidateConfirm;m_leg1Bar=bar;}
      else {m_leg2Candidate=m_candidateTime;m_leg2CandidateConfirm=m_candidateConfirm;m_leg2Bar=bar;}
   }
   void Output(SymbolState &state) const
   {
      state.setup=JinpaSetupToString(m_setup);state.setupStatus=JinpaSetupStatusToString(m_status);
      if(m_status==JINPA_SETUP_STATUS_ACTIVE) state.structure=m_setup==JINPA_SETUP_REVS_PPF?"LEG 1":"LEG 2";
      else if(state.structure=="LEG 1"||state.structure=="LEG 2") state.structure="NONE";
   }
public:
   CPullbackSetupEngine(void){m_swingRightBars=3;Reset();}
   void Reset(void){ClearSetup();ClearLegs();m_cycle=MARKET_CYCLE_UNKNOWN;m_lastBar=0;m_correctionStart=0;if(m_swingRightBars<1)m_swingRightBars=3;}
   bool ConfigureSwingRightBars(const int value){if(value<1)return false;m_swingRightBars=value;return true;}
   bool Apply(const string previousState,const ENUM_JINPA_MARKET_STATE marketState,const PriceStructureState &source,const SwingPoint &swings[],const MqlRates &rates[],const datetime closedTime,SymbolState &state)
   {
      string oldSetup=state.setup,oldStatus=state.setupStatus,oldStructure=state.structure;
      int ci=BarIndex(rates,closedTime); if(ci<0||closedTime<=m_lastBar){Output(state);return oldSetup!=state.setup||oldStatus!=state.setupStatus||oldStructure!=state.structure;} m_lastBar=closedTime;
      MqlRates bar=rates[ci]; ENUM_MARKET_CYCLE cycle=source.cycleState.cycle; bool cycleChanged=m_cycle!=MARKET_CYCLE_UNKNOWN&&cycle!=m_cycle;m_cycle=cycle;
      if(m_status==JINPA_SETUP_STATUS_ACTIVE&&bar.time>m_triggerTime)
      { Invalidate(bar.time);if(cycleChanged||cycle==MARKET_CYCLE_UNKNOWN||marketState!=JINPA_STATE_CORRECTION){m_correctionStart=0;ClearLegs();}Output(state);return true; }
      if(m_status==JINPA_SETUP_STATUS_INVALID){if(bar.time>m_invalidTime)ClearSetup();else{Output(state);return oldSetup!=state.setup||oldStatus!=state.setupStatus||oldStructure!=state.structure;}}
      bool correctionStarted=marketState==JINPA_STATE_CORRECTION&&previousState!="CORRECTION";
      if(cycleChanged||cycle==MARKET_CYCLE_UNKNOWN||marketState!=JINPA_STATE_CORRECTION)
      { if(m_status==JINPA_SETUP_STATUS_WATCH||m_status==JINPA_SETUP_STATUS_READY)Invalidate(bar.time);else if(m_status==JINPA_SETUP_STATUS_NONE)ClearSetup();m_correctionStart=0;ClearLegs();Output(state);return oldSetup!=state.setup||oldStatus!=state.setupStatus||oldStructure!=state.structure; }
      if(correctionStarted){ClearLegs();m_correctionStart=bar.time;Watch(JINPA_SETUP_REVS_PPF);}
      if(m_setup==JINPA_SETUP_NONE&&m_leg1Bar>0){SwingPoint turn;if(TurningAt(swings,bar.time,turn)){m_turningTime=turn.time;m_turningConfirm=turn.confirmationTime;Watch(JINPA_SETUP_REVS_PPS);Output(state);return true;}}
      // Finalize the immutable old Base before considering a SwingPoint whose
      // confirmation lands on this same closed bar.  A failed Base returns to
      // WATCH without disturbing confirmed Leg or PPS turning context.
      if(m_status==JINPA_SETUP_STATUS_READY)
      {
         int outcome=BaseOutcome(bar);
         if(outcome>0){Activate(bar.time);Output(state);return true;}
         if(outcome<0)FailBase();
      }
      if(m_status==JINPA_SETUP_STATUS_WATCH||m_status==JINPA_SETUP_STATUS_READY)
      { if(CandidateAt(swings,rates,bar.time)){Output(state);return true;} }
      Output(state);return oldSetup!=state.setup||oldStatus!=state.setupStatus||oldStructure!=state.structure;
   }
   ENUM_JINPA_SETUP Setup(void)const{return m_setup;} ENUM_JINPA_SETUP_STATUS Status(void)const{return m_status;}
   double BaseHigh(void)const{return m_baseHigh;} double BaseLow(void)const{return m_baseLow;} datetime BaseTime(void)const{return m_baseTime;}
   datetime CandidateSwingTime(void)const{return m_candidateTime;} datetime CandidateConfirmationTime(void)const{return m_candidateConfirm;}
   datetime TriggerBarTime(void)const{return m_triggerTime;} datetime Leg1ConfirmedBarTime(void)const{return m_leg1Bar;} datetime Leg2ConfirmedBarTime(void)const{return m_leg2Bar;} datetime PpsTurningSwingTime(void)const{return m_turningTime;}
   bool HasActiveBase(void)const{return m_status==JINPA_SETUP_STATUS_READY&&m_baseTime>0&&m_baseHigh>m_baseLow;}
};
#endif
