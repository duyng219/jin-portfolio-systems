#property strict
#property version "1.10"
#include "../watch/setup/PullbackSetupEngine.mqh"
#include "../watch/setup/PullbackBaseRenderer.mqh"
#include "../watch/ui/MarketRadar.mqh"
int g_passed=0,g_failed=0;
void Check(bool ok,string name){if(ok){g_passed++;Print("[PULLBACK_SETUP_TEST][PASS] ",name);}else{g_failed++;Print("[PULLBACK_SETUP_TEST][FAIL] ",name);}}
PriceStructureState Source(ENUM_MARKET_CYCLE cycle){PriceStructureState s;ResetPriceStructureState(s);s.initialized=true;s.cycleState.cycle=cycle;return s;}
MqlRates Bar(datetime t,double h,double l,double c){MqlRates b;ZeroMemory(b);b.time=t;b.open=c;b.high=h;b.low=l;b.close=c;return b;}
void AddBar(MqlRates &a[],const MqlRates &b){int n=ArraySize(a);ArrayResize(a,n+1);a[n]=b;}
SwingPoint Swing(ENUM_SWING_TYPE type,datetime pivot,datetime confirm,double price){SwingPoint p;ResetSwingPoint(p);p.type=type;p.time=pivot;p.confirmationTime=confirm;p.price=price;p.confirmed=true;return p;}
void AddSwing(SwingPoint &a[],const SwingPoint &p){int n=ArraySize(a);ArrayResize(a,n+1);a[n]=p;}
bool Apply(CPullbackSetupEngine &e,string previous,ENUM_JINPA_MARKET_STATE state,PriceStructureState &source,SwingPoint &swings[],MqlRates &rates[],SymbolState &out)
{return e.Apply(previous,state,source,swings,rates,rates[ArraySize(rates)-1].time,out);}

void TestBullUnifiedLifecycle()
{
   CPullbackSetupEngine e; PriceStructureState source=Source(MARKET_CYCLE_BULL); SwingPoint swings[];MqlRates rates[];SymbolState out;out.setup="-";out.setupStatus="NONE";out.structure="NONE";
   e.ConfigureSwingRightBars(1);
   AddBar(rates,Bar(100,110,100,105));
   Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-ppf"&&out.setupStatus=="WATCH"&&e.BaseTime()==0,"PPF_01_CORRECTION_START_WATCH_NO_BASE");
   Check(!Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out),"PPF_02_NO_NEW_BAR_NO_TRANSITION");
   AddBar(rates,Bar(110,107,98,101));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="WATCH","PPF_03_NO_CONFIRMED_SWING_STAYS_WATCH");
   AddSwing(swings,Swing(SWING_LOW,110,120,98));AddBar(rates,Bar(120,106,100,103));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseTime()==110&&e.BaseHigh()==107&&e.BaseLow()==98&&out.structure!="LEG 1","PPF_04_SWING_LOW_EXACT_PIVOT_BASE_READY_NO_LEG");
   AddBar(rates,Bar(130,999,97,105));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&out.structure!="LEG 1","PPF_05_NO_BREAK_NO_LEG");
   AddBar(rates,Bar(140,105,95,99));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,140,150,95));AddBar(rates,Bar(150,104,97,101));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseTime()==140&&e.BaseHigh()==105,"PPF_06_DEEPER_CANDIDATE_REPLACES_BASE");
   AddBar(rates,Bar(160,108,101,106));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 1"&&e.Leg1ConfirmedBarTime()==160,"PPF_07_BREAK_CONFIRMS_LEG1_AND_ACTIVE_SAME_BAR");
   AddBar(rates,Bar(170,107,100,103));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="INVALID"&&out.structure!="LEG 1"&&e.Leg1ConfirmedBarTime()==160,"PPF_08_ACTIVE_NEXT_BAR_INVALID_PRESERVES_LEG1_ARM");
   AddBar(rates,Bar(180,106,99,102));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="NONE","PPF_09_INVALID_NEXT_BAR_NONE");
   AddBar(rates,Bar(190,109,101,105));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="-","PPS_10_NO_TURNING_SWING_NO_WATCH");
   AddSwing(swings,Swing(SWING_HIGH,190,200,109));AddBar(rates,Bar(200,108,102,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="WATCH"&&e.PpsTurningSwingTime()==190,"PPS_11_POST_LEG1_TURNING_HIGH_WATCH");
   AddBar(rates,Bar(210,106,96,100));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,210,220,96));AddBar(rates,Bar(220,105,99,102));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseTime()==210&&e.BaseHigh()==106,"PPS_12_NEXT_LOW_EXACT_BASE_READY");
   AddBar(rates,Bar(230,109,101,107));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="ACTIVE"&&out.structure=="LEG 2"&&e.Leg2ConfirmedBarTime()==230,"PPS_13_BREAK_CONFIRMS_LEG2_AND_ACTIVE_SAME_BAR");
   AddBar(rates,Bar(240,108,100,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="INVALID"&&e.Leg1ConfirmedBarTime()==0&&e.Leg2ConfirmedBarTime()==0&&e.PpsTurningSwingTime()==0,"PPS_14_ACTIVE_NEXT_BAR_INVALID_CONSUMES_CHAIN_CONTEXT");
   AddBar(rates,Bar(250,107,99,103));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="-"&&out.setupStatus=="NONE","PPS_15_TERMINAL_INVALID_CLEARS_TO_NONE");
   AddBar(rates,Bar(260,112,101,106));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,260,270,112));AddBar(rates,Bar(270,110,102,105));bool rearmed=Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(!rearmed&&out.setup=="-"&&out.setupStatus=="NONE","PPS_16_LATER_BULL_HIGH_CANNOT_REARM_OR_SOURCE_WATCH_PUSH");
   AddBar(rates,Bar(280,109,100,104));Apply(e,"CORRECTION",JINPA_STATE_IMPULSE,source,swings,rates,out);AddBar(rates,Bar(290,108,99,103));Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-ppf"&&out.setupStatus=="WATCH","PPS_17_NEW_CORRECTION_STARTS_GENUINE_NEW_PPF_CHAIN");
   AddBar(rates,Bar(300,106,95,100));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddSwing(swings,Swing(SWING_LOW,300,310,95));AddBar(rates,Bar(310,105,97,101));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(320,109,102,108));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(330,108,100,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(340,107,99,103));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(350,113,101,107));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddSwing(swings,Swing(SWING_HIGH,350,360,113));AddBar(rates,Bar(360,111,102,106));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="WATCH"&&e.Leg1ConfirmedBarTime()==320&&e.PpsTurningSwingTime()==350,"PPS_18_NEW_LEG1_CAN_ARM_ONE_NEW_PPS");
}

void TestBearAndInvalidation()
{
   CPullbackSetupEngine e;PriceStructureState source=Source(MARKET_CYCLE_BEAR);SwingPoint swings[];MqlRates rates[];SymbolState out;out.setup="-";out.setupStatus="NONE";out.structure="NONE";
   e.ConfigureSwingRightBars(1);
   AddBar(rates,Bar(300,110,100,105));Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(310,112,103,108));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,310,320,112));AddBar(rates,Bar(320,110,104,107));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseHigh()==112&&e.BaseLow()==103,"PPF_15_BEAR_HIGH_READY");
   AddBar(rates,Bar(330,105,99,102));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 1","PPF_16_BEAR_BREAK_LEG1_ACTIVE");
   CPullbackSetupEngine invalid;PriceStructureState bull=Source(MARKET_CYCLE_BULL);SwingPoint none[];MqlRates rr[];SymbolState ss;ss.setup="-";ss.setupStatus="NONE";ss.structure="NONE";
   invalid.ConfigureSwingRightBars(1);
   AddBar(rr,Bar(400,110,100,105));Apply(invalid,"IMPULSE",JINPA_STATE_CORRECTION,bull,none,rr,ss);AddBar(rr,Bar(410,109,99,103));Apply(invalid,"CORRECTION",JINPA_STATE_IMPULSE,bull,none,rr,ss);
   Check(ss.setupStatus=="INVALID","CONTEXT_17_LEAVING_CORRECTION_INVALIDATES");
}

void TestBullBaseFailureAndPpsRecovery()
{
   CPullbackSetupEngine e;PriceStructureState source=Source(MARKET_CYCLE_BULL);SwingPoint swings[];MqlRates rates[];SymbolState out;out.setup="-";out.setupStatus="NONE";out.structure="NONE";
   e.ConfigureSwingRightBars(1);
   AddBar(rates,Bar(10000,112,102,107));Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(10010,110,100,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,10010,10020,100));AddBar(rates,Bar(10020,108,101,105));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   double originalHigh=e.BaseHigh(),originalLow=e.BaseLow();datetime originalCandidate=e.CandidateSwingTime();
   AddBar(rates,Bar(10030,115,99,105));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseHigh()==originalHigh&&e.BaseLow()==originalLow&&e.CandidateSwingTime()==originalCandidate,"FAILURE_18_BULL_INSIDE_AND_WICK_PRESERVE_IMMUTABLE_BASE");
   AddBar(rates,Bar(10040,101,98,99));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-ppf"&&out.setupStatus=="WATCH"&&out.structure!="LEG 1"&&!e.HasActiveBase()&&e.CandidateSwingTime()==0,"FAILURE_19_BULL_CLOSE_BELOW_BASE_RETURNS_WATCH_AND_CLEARS_CANDIDATE");
   AddBar(rates,Bar(10050,103,97,101));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="WATCH"&&!e.HasActiveBase()&&e.BaseTime()==0,"FAILURE_20_NO_SWING_NO_NEW_BASE");
   AddBar(rates,Bar(10060,109,95,100));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,10060,10070,95));AddBar(rates,Bar(10070,108,97,103));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.CandidateSwingTime()==10060&&e.BaseHigh()==109&&e.BaseLow()==95,"FAILURE_21_NEW_BULL_SWING_CREATES_NEW_READY_BASE");
   AddBar(rates,Bar(10080,111,100,110));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 1","FAILURE_22_NEW_BASE_SUCCESS_CONFIRMS_LEG1");
   AddBar(rates,Bar(10090,109,99,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(10100,108,98,103));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(10110,111,100,105));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,10110,10120,111));AddBar(rates,Bar(10120,109,101,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(10130,107,96,100));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,10130,10140,96));AddBar(rates,Bar(10140,106,98,102));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="READY","FAILURE_23_BULL_PPS_READY");
   datetime turning=e.PpsTurningSwingTime(),leg1=e.Leg1ConfirmedBarTime();
   AddBar(rates,Bar(10150,100,94,95));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="WATCH"&&out.structure!="LEG 2"&&e.PpsTurningSwingTime()==turning&&e.Leg1ConfirmedBarTime()==leg1,"FAILURE_24_BULL_PPS_FAILURE_PRESERVES_TURNING_AND_LEG1_CONTEXT");
   AddBar(rates,Bar(10160,102,93,98));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="WATCH"&&!e.HasActiveBase(),"FAILURE_25_BULL_PPS_WAITS_WITHOUT_BASE");
   AddBar(rates,Bar(10170,105,92,97));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,10170,10180,92));AddBar(rates,Bar(10180,104,94,99));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.CandidateSwingTime()==10170,"FAILURE_26_BULL_PPS_NEW_SWING_READY");
   AddBar(rates,Bar(10190,107,100,106));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 2","FAILURE_27_BULL_PPS_SUCCESS_ONLY_CONFIRMS_LEG2");
}

void TestBearBaseFailureAndPpsRecovery()
{
   CPullbackSetupEngine e;PriceStructureState source=Source(MARKET_CYCLE_BEAR);SwingPoint swings[];MqlRates rates[];SymbolState out;out.setup="-";out.setupStatus="NONE";out.structure="NONE";
   e.ConfigureSwingRightBars(1);
   AddBar(rates,Bar(11000,202,188,195));Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(11010,200,190,195));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,11010,11020,200));AddBar(rates,Bar(11020,198,191,194));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(11030,201,189,195));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseHigh()==200&&e.BaseLow()==190,"FAILURE_28_BEAR_WICK_ABOVE_PRESERVES_READY_BASE");
   AddBar(rates,Bar(11040,203,197,201));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="WATCH"&&!e.HasActiveBase()&&e.CandidateSwingTime()==0&&out.structure!="LEG 1","FAILURE_29_BEAR_CLOSE_ABOVE_BASE_RETURNS_WATCH");
   AddBar(rates,Bar(11050,204,194,198));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(11060,205,192,199));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,11060,11070,205));AddBar(rates,Bar(11070,203,193,198));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.CandidateSwingTime()==11060,"FAILURE_30_NEW_BEAR_SWING_READY");
   AddBar(rates,Bar(11080,196,189,191));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 1","FAILURE_31_NEW_BEAR_BASE_SUCCESS_CONFIRMS_LEG1");
   AddBar(rates,Bar(11090,199,190,195));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(11100,200,191,196));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(11110,198,187,192));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,11110,11120,187));AddBar(rates,Bar(11120,199,189,194));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(11130,210,195,202));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,11130,11140,210));AddBar(rates,Bar(11140,208,197,203));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="READY","FAILURE_32_BEAR_PPS_READY");
   AddBar(rates,Bar(11150,212,205,211));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="WATCH"&&out.structure!="LEG 2","FAILURE_33_BEAR_PPS_FAILURE_RETURNS_WATCH");
   AddBar(rates,Bar(11160,211,199,204));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="WATCH"&&!e.HasActiveBase(),"FAILURE_34_BEAR_PPS_WAITS_WITHOUT_BASE");
   AddBar(rates,Bar(11170,215,198,207));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,11170,11180,215));AddBar(rates,Bar(11180,213,200,206));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.CandidateSwingTime()==11170,"FAILURE_35_BEAR_PPS_NEW_SWING_READY");
   AddBar(rates,Bar(11190,201,195,197));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 2","FAILURE_36_BEAR_PPS_SUCCESS_ONLY_CONFIRMS_LEG2");
}

void TestSameBarOldBasePriority()
{
   CPullbackSetupEngine e;PriceStructureState source=Source(MARKET_CYCLE_BULL);SwingPoint swings[];MqlRates rates[];SymbolState out;out.setup="-";out.setupStatus="NONE";out.structure="NONE";e.ConfigureSwingRightBars(1);
   AddBar(rates,Bar(12000,112,102,106));Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(12010,110,100,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,12010,12020,100));AddBar(rates,Bar(12020,108,102,105));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(12030,109,95,103));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,12030,12040,95));AddBar(rates,Bar(12040,107,97,99));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.CandidateSwingTime()==12030&&e.BaseLow()==95&&e.BaseHigh()==109,"ORDER_37_OLD_BASE_FAILURE_FINALIZED_BEFORE_SAME_BAR_NEW_CANDIDATE");
}

void BuildBullPpsWatch(CPullbackSetupEngine &e,PriceStructureState &source,SwingPoint &swings[],MqlRates &rates[],SymbolState &out,const datetime t)
{
   e.ConfigureSwingRightBars(1);source=Source(MARKET_CYCLE_BULL);out.setup="-";out.setupStatus="NONE";out.structure="NONE";
   AddBar(rates,Bar(t,112,102,106));Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+10,110,100,104));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,t+10,t+20,100));AddBar(rates,Bar(t+20,108,102,105));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+30,112,105,111));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+40,111,103,107));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(t+50,110,102,106));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+60,115,105,109));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,t+60,t+70,115));AddBar(rates,Bar(t+70,112,104,108));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
}

void BuildBearPpsWatch(CPullbackSetupEngine &e,PriceStructureState &source,SwingPoint &swings[],MqlRates &rates[],SymbolState &out,const datetime t)
{
   e.ConfigureSwingRightBars(1);source=Source(MARKET_CYCLE_BEAR);out.setup="-";out.setupStatus="NONE";out.structure="NONE";
   AddBar(rates,Bar(t,202,188,195));Apply(e,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+10,200,190,196));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,t+10,t+20,200));AddBar(rates,Bar(t+20,198,192,195));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+30,195,187,189));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+40,197,188,193));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(t+50,198,189,194));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddBar(rates,Bar(t+60,195,180,187));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,t+60,t+70,180));AddBar(rates,Bar(t+70,196,183,190));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
}

void TestBullPpsCompressionLifecycle()
{
   CPullbackSetupEngine e;PriceStructureState source;SwingPoint swings[];MqlRates rates[];SymbolState out;BuildBullPpsWatch(e,source,swings,rates,out,13000);
   datetime leg=e.Leg1ConfirmedBarTime(),turn=e.PpsTurningSwingTime();
   AddBar(rates,Bar(13080,113,103,108));Apply(e,"CORRECTION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="WATCH"&&e.Leg1ConfirmedBarTime()==leg&&e.PpsTurningSwingTime()==turn,"COMPRESSION_41_BULL_PPS_WATCH_AND_CONTEXT_SURVIVE");
   AddBar(rates,Bar(13085,112,102,107));Apply(e,"COMPRESSION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   Check(out.setup=="revs-pps"&&out.setupStatus=="WATCH"&&e.Leg1ConfirmedBarTime()==leg,"COMPRESSION_41B_RETURN_TO_CORRECTION_DOES_NOT_RESTART_PPF");
   AddBar(rates,Bar(13090,109,95,101));Apply(e,"CORRECTION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,13090,13100,95));AddBar(rates,Bar(13100,108,97,102));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   double high=e.BaseHigh(),low=e.BaseLow();datetime candidate=e.CandidateSwingTime();
   Check(out.setupStatus=="READY"&&candidate==13090&&high==109&&low==95,"COMPRESSION_42_BULL_PPS_CAN_ENTER_READY");
   AddBar(rates,Bar(13110,120,94,103));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseHigh()==high&&e.BaseLow()==low&&e.CandidateSwingTime()==candidate,"COMPRESSION_43_BULL_READY_BASE_SURVIVES_IMMUTABLY");
   AddBar(rates,Bar(13120,100,93,94));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="WATCH"&&e.Leg1ConfirmedBarTime()==leg&&e.PpsTurningSwingTime()==turn&&!e.HasActiveBase(),"COMPRESSION_44_BULL_BASE_FAILURE_RETURNS_WATCH_WITH_CONTEXT");
   AddBar(rates,Bar(13130,108,90,98));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_LOW,13130,13140,90));AddBar(rates,Bar(13140,107,93,100));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   out.structure="SIDEWAY";AddBar(rates,Bar(13150,111,101,109));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 2"&&e.Leg2ConfirmedBarTime()==13150,"COMPRESSION_45_BULL_PPS_ACTIVE_AND_CURRENT_LEG2_PRECEDENCE");
   AddBar(rates,Bar(13160,109,99,104));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="INVALID"&&e.Leg1ConfirmedBarTime()==0&&e.PpsTurningSwingTime()==0,"TERMINAL_46_BULL_COMPRESSION_INVALID_CONSUMES_CONTEXT");
   AddBar(rates,Bar(13170,108,98,103));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setup=="-"&&out.setupStatus=="NONE","TERMINAL_47_BULL_COMPRESSION_CLEARS_TO_NONE");
   AddBar(rates,Bar(13180,114,100,107));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);AddSwing(swings,Swing(SWING_HIGH,13180,13190,114));AddBar(rates,Bar(13190,112,102,106));bool rearmed=Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(!rearmed&&out.setup=="-"&&out.setupStatus=="NONE","TERMINAL_48_BULL_SIDEWAY_HIGH_CANNOT_REARM_PPS");
}

void TestBearPpsCompressionLifecycle()
{
   CPullbackSetupEngine e;PriceStructureState source;SwingPoint swings[];MqlRates rates[];SymbolState out;BuildBearPpsWatch(e,source,swings,rates,out,14000);
   datetime leg=e.Leg1ConfirmedBarTime(),turn=e.PpsTurningSwingTime();
   AddBar(rates,Bar(14080,210,195,202));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,14080,14090,210));AddBar(rates,Bar(14090,208,198,203));Apply(e,"CORRECTION",JINPA_STATE_CORRECTION,source,swings,rates,out);
   double high=e.BaseHigh(),low=e.BaseLow();datetime candidate=e.CandidateSwingTime();
   Check(out.setupStatus=="READY"&&candidate==14080&&high==210&&low==195,"COMPRESSION_46_BEAR_PPS_READY_BEFORE_COMPRESSION");
   AddBar(rates,Bar(14100,211,190,202));Apply(e,"CORRECTION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="READY"&&e.BaseHigh()==high&&e.BaseLow()==low&&e.CandidateSwingTime()==candidate&&e.Leg1ConfirmedBarTime()==leg&&e.PpsTurningSwingTime()==turn,"COMPRESSION_47_BEAR_READY_BASE_AND_CONTEXT_SURVIVE");
   AddBar(rates,Bar(14110,212,205,211));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="WATCH"&&e.Leg1ConfirmedBarTime()==leg&&e.PpsTurningSwingTime()==turn,"COMPRESSION_49_BEAR_BASE_FAILURE_RETURNS_WATCH_WITH_CONTEXT");
   AddBar(rates,Bar(14120,215,198,207));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   AddSwing(swings,Swing(SWING_HIGH,14120,14130,215));AddBar(rates,Bar(14130,213,200,206));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   AddBar(rates,Bar(14140,201,195,197));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="ACTIVE"&&out.structure=="LEG 2"&&e.Leg2ConfirmedBarTime()==14140,"COMPRESSION_48_BEAR_PPS_ACTIVE");
   AddBar(rates,Bar(14150,203,194,199));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setupStatus=="INVALID"&&e.Leg1ConfirmedBarTime()==0&&e.PpsTurningSwingTime()==0,"TERMINAL_49_BEAR_COMPRESSION_INVALID_CONSUMES_CONTEXT");
   AddBar(rates,Bar(14160,204,193,200));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setup=="-"&&out.setupStatus=="NONE","TERMINAL_50_BEAR_COMPRESSION_CLEARS_TO_NONE");
   AddBar(rates,Bar(14170,205,185,192));Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);AddSwing(swings,Swing(SWING_LOW,14170,14180,185));AddBar(rates,Bar(14180,203,188,195));bool rearmed=Apply(e,"COMPRESSION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(!rearmed&&out.setup=="-"&&out.setupStatus=="NONE","TERMINAL_51_BEAR_SIDEWAY_LOW_CANNOT_REARM_PPS");
}

void TestCompressionEdgesAndInvalidation()
{
   CPullbackSetupEngine turn;PriceStructureState bull=Source(MARKET_CYCLE_BULL);SwingPoint ts[];MqlRates tr[];SymbolState to;to.setup="-";to.setupStatus="NONE";to.structure="NONE";turn.ConfigureSwingRightBars(1);
   AddBar(tr,Bar(15000,112,102,106));Apply(turn,"IMPULSE",JINPA_STATE_CORRECTION,bull,ts,tr,to);AddBar(tr,Bar(15010,110,100,104));Apply(turn,"CORRECTION",JINPA_STATE_CORRECTION,bull,ts,tr,to);
   AddSwing(ts,Swing(SWING_LOW,15010,15020,100));AddBar(tr,Bar(15020,108,102,105));Apply(turn,"CORRECTION",JINPA_STATE_CORRECTION,bull,ts,tr,to);AddBar(tr,Bar(15030,115,105,111));Apply(turn,"CORRECTION",JINPA_STATE_CORRECTION,bull,ts,tr,to);
   AddSwing(ts,Swing(SWING_HIGH,15030,15040,115));AddBar(tr,Bar(15040,112,104,108));Apply(turn,"CORRECTION",JINPA_STATE_COMPRESSION,bull,ts,tr,to);
   Check(to.setup=="revs-pps"&&to.setupStatus=="WATCH"&&turn.PpsTurningSwingTime()==15030,"EDGE_51_SAME_BAR_TURNING_AND_SIDEWAY_STARTS_PPS");

   CPullbackSetupEngine candidate;PriceStructureState bear;SwingPoint cs[];MqlRates cr[];SymbolState co;BuildBearPpsWatch(candidate,bear,cs,cr,co,15100);
   AddBar(cr,Bar(15180,210,195,202));Apply(candidate,"CORRECTION",JINPA_STATE_CORRECTION,bear,cs,cr,co);AddSwing(cs,Swing(SWING_HIGH,15180,15190,210));AddBar(cr,Bar(15190,208,198,203));Apply(candidate,"CORRECTION",JINPA_STATE_COMPRESSION,bear,cs,cr,co);
   Check(co.setup=="revs-pps"&&co.setupStatus=="READY"&&candidate.CandidateSwingTime()==15180,"EDGE_52_SAME_BAR_CANDIDATE_AND_SIDEWAY_ENTERS_READY");

   CPullbackSetupEngine changed;PriceStructureState changedSource;SwingPoint xs[];MqlRates xr[];SymbolState xo;BuildBullPpsWatch(changed,changedSource,xs,xr,xo,15300);changedSource.cycleState.cycle=MARKET_CYCLE_BEAR;AddBar(xr,Bar(15380,113,103,108));Apply(changed,"CORRECTION",JINPA_STATE_COMPRESSION,changedSource,xs,xr,xo);
   Check(xo.setupStatus=="INVALID"&&changed.Leg1ConfirmedBarTime()==0&&changed.PpsTurningSwingTime()==0,"INVALID_53_CYCLE_CHANGE_STILL_INVALIDATES_PPS_WATCH");

   CPullbackSetupEngine unknown;PriceStructureState unknownSource;SwingPoint us[];MqlRates ur[];SymbolState uo;BuildBearPpsWatch(unknown,unknownSource,us,ur,uo,15500);AddBar(ur,Bar(15580,210,195,202));Apply(unknown,"CORRECTION",JINPA_STATE_CORRECTION,unknownSource,us,ur,uo);AddSwing(us,Swing(SWING_HIGH,15580,15590,210));AddBar(ur,Bar(15590,208,198,203));Apply(unknown,"CORRECTION",JINPA_STATE_CORRECTION,unknownSource,us,ur,uo);unknownSource.cycleState.cycle=MARKET_CYCLE_UNKNOWN;AddBar(ur,Bar(15600,207,197,202));Apply(unknown,"CORRECTION",JINPA_STATE_COMPRESSION,unknownSource,us,ur,uo);
   Check(uo.setupStatus=="INVALID"&&unknown.Leg1ConfirmedBarTime()==0&&unknown.PpsTurningSwingTime()==0,"INVALID_54_UNKNOWN_CYCLE_STILL_INVALIDATES_PPS_READY");

   CPullbackSetupEngine changedReady;PriceStructureState readySource;SwingPoint ys[];MqlRates yr[];SymbolState yo;BuildBearPpsWatch(changedReady,readySource,ys,yr,yo,15700);AddBar(yr,Bar(15780,210,195,202));Apply(changedReady,"CORRECTION",JINPA_STATE_CORRECTION,readySource,ys,yr,yo);AddSwing(ys,Swing(SWING_HIGH,15780,15790,210));AddBar(yr,Bar(15790,208,198,203));Apply(changedReady,"CORRECTION",JINPA_STATE_CORRECTION,readySource,ys,yr,yo);readySource.cycleState.cycle=MARKET_CYCLE_BULL;AddBar(yr,Bar(15800,207,197,202));Apply(changedReady,"CORRECTION",JINPA_STATE_COMPRESSION,readySource,ys,yr,yo);
   Check(yo.setupStatus=="INVALID"&&changedReady.Leg1ConfirmedBarTime()==0,"INVALID_55_CYCLE_CHANGE_STILL_INVALIDATES_PPS_READY");

   CPullbackSetupEngine unknownWatch;PriceStructureState watchSource;SwingPoint zs[];MqlRates zr[];SymbolState zo;BuildBullPpsWatch(unknownWatch,watchSource,zs,zr,zo,15900);watchSource.cycleState.cycle=MARKET_CYCLE_UNKNOWN;AddBar(zr,Bar(15980,113,103,108));Apply(unknownWatch,"CORRECTION",JINPA_STATE_COMPRESSION,watchSource,zs,zr,zo);
   Check(zo.setupStatus=="INVALID"&&unknownWatch.PpsTurningSwingTime()==0,"INVALID_56_UNKNOWN_CYCLE_STILL_INVALIDATES_PPS_WATCH");
}

void TestPpfRemainsCorrectionOnly()
{
   CPullbackSetupEngine watch;PriceStructureState source=Source(MARKET_CYCLE_BULL);SwingPoint swings[];MqlRates rates[];SymbolState out;out.setup="-";out.setupStatus="NONE";out.structure="NONE";watch.ConfigureSwingRightBars(1);
   AddBar(rates,Bar(16000,110,100,105));Apply(watch,"IMPULSE",JINPA_STATE_CORRECTION,source,swings,rates,out);AddBar(rates,Bar(16010,109,101,104));Apply(watch,"CORRECTION",JINPA_STATE_COMPRESSION,source,swings,rates,out);
   Check(out.setup=="revs-ppf"&&out.setupStatus=="INVALID","PPF_57_WATCH_REMAINS_INVALID_IN_COMPRESSION");
   CPullbackSetupEngine ready;SwingPoint rs[];MqlRates rr[];SymbolState ro;ro.setup="-";ro.setupStatus="NONE";ro.structure="NONE";ready.ConfigureSwingRightBars(1);
   AddBar(rr,Bar(16100,110,100,105));Apply(ready,"IMPULSE",JINPA_STATE_CORRECTION,source,rs,rr,ro);AddBar(rr,Bar(16110,108,98,102));Apply(ready,"CORRECTION",JINPA_STATE_CORRECTION,source,rs,rr,ro);AddSwing(rs,Swing(SWING_LOW,16110,16120,98));AddBar(rr,Bar(16120,107,100,103));Apply(ready,"CORRECTION",JINPA_STATE_CORRECTION,source,rs,rr,ro);AddBar(rr,Bar(16130,106,99,102));Apply(ready,"CORRECTION",JINPA_STATE_COMPRESSION,source,rs,rr,ro);
   Check(ro.setup=="revs-ppf"&&ro.setupStatus=="INVALID","PPF_58_READY_REMAINS_INVALID_IN_COMPRESSION");
}

void TestFourBarBaseBuilder()
{
   CPullbackSetupEngine bull;bull.ConfigureSwingRightBars(3);PriceStructureState bs=Source(MARKET_CYCLE_BULL);SwingPoint sw[];MqlRates r[];SymbolState o;o.setup="-";o.setupStatus="NONE";o.structure="NONE";
   AddBar(r,Bar(1000,120,90,105));Apply(bull,"IMPULSE",JINPA_STATE_CORRECTION,bs,sw,r,o);
   AddBar(r,Bar(1010,999,1,500));AddBar(r,Bar(1020,888,2,400));AddBar(r,Bar(1030,777,3,300));
   AddBar(r,Bar(1040,106,100,103));AddBar(r,Bar(1050,108,101,104));AddBar(r,Bar(1060,107,102,105));AddSwing(sw,Swing(SWING_LOW,1040,1070,100));AddBar(r,Bar(1070,110,103,106));Apply(bull,"CORRECTION",JINPA_STATE_CORRECTION,bs,sw,r,o);
   Check(o.setupStatus=="READY"&&bull.BaseLow()==100&&bull.BaseHigh()==110,"BASE_19_BULL_PIVOT_THROUGH_R3_ONLY");
   AddBar(r,Bar(1080,999,0,109));Apply(bull,"CORRECTION",JINPA_STATE_CORRECTION,bs,sw,r,o);
   Check(o.setupStatus=="READY"&&bull.BaseHigh()==110,"BASE_20_R4_EXCLUDED_AND_WICK_NO_BREAK");

   CPullbackSetupEngine bear;bear.ConfigureSwingRightBars(3);PriceStructureState brs=Source(MARKET_CYCLE_BEAR);SwingPoint bw[];MqlRates br[];SymbolState bo;bo.setup="-";bo.setupStatus="NONE";bo.structure="NONE";
   AddBar(br,Bar(2000,210,180,195));Apply(bear,"IMPULSE",JINPA_STATE_CORRECTION,brs,bw,br,bo);
   AddBar(br,Bar(2010,999,1,500));AddBar(br,Bar(2020,888,2,400));AddBar(br,Bar(2030,777,3,300));
   AddBar(br,Bar(2040,200,194,197));AddBar(br,Bar(2050,199,192,196));AddBar(br,Bar(2060,198,193,195));AddSwing(bw,Swing(SWING_HIGH,2040,2070,200));AddBar(br,Bar(2070,197,190,194));Apply(bear,"CORRECTION",JINPA_STATE_CORRECTION,brs,bw,br,bo);
   Check(bo.setupStatus=="READY"&&bear.BaseHigh()==200&&bear.BaseLow()==190,"BASE_21_BEAR_PIVOT_THROUGH_R3_ONLY");
}

void TestBaseVisual()
{
   CPullbackBaseRenderer renderer;string high="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3000_HIGH";string low="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3000_LOW";
   renderer.Destroy();
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","READY",3000,3000,3180,110,100);
   Check(ObjectFind(0,high)>=0&&ObjectFind(0,low)>=0&&(color)ObjectGetInteger(0,high,OBJPROP_COLOR)==clrWhite&&ObjectGetInteger(0,high,OBJPROP_WIDTH)==1,"VISUAL_22_WHITE_THIN_READY_BASE");
   string highB="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3240_HIGH";string lowB="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3240_LOW";
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","READY",3240,3240,3420,108,98);
   Check(ObjectFind(0,high)<0&&ObjectFind(0,low)<0&&ObjectFind(0,highB)>=0&&ObjectFind(0,lowB)>=0,"VISUAL_23_REPLACEMENT_DELETES_A_AND_CREATES_B");
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","ACTIVE",3240,3240,3480,108,98);
   Check(ObjectFind(0,highB)>=0&&ObjectFind(0,lowB)>=0&&(datetime)ObjectGetInteger(0,highB,OBJPROP_TIME,1)==3480,"VISUAL_24_ACTIVE_FREEZES_AND_PRESERVES_BASE");
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","INVALID",0,0,3540,0,0);
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"-","NONE",0,0,3600,0,0);
   Check(ObjectFind(0,highB)>=0&&ObjectFind(0,lowB)>=0&&(datetime)ObjectGetInteger(0,highB,OBJPROP_TIME,1)==3480,"VISUAL_25_PPF_CONFIRMED_SURVIVES_AND_IS_IMMUTABLE");
   string highC="JINPA_PULLBACK_BASE_revs-pps_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3600_HIGH";
   string lowC="JINPA_PULLBACK_BASE_revs-pps_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3600_LOW";
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-pps","READY",3600,3600,3780,120,105);renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-pps","WATCH",0,0,3840,0,0);
   Check(ObjectFind(0,highC)<0&&ObjectFind(0,lowC)<0,"VISUAL_26_FAILURE_DELETES_UNCONFIRMED_BASE");
   string highD="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3900_HIGH";
   string lowD="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_3900_LOW";
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","READY",3900,3900,3960,130,115);renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","READY",3900,3900,4020,130,115);
   Check((datetime)ObjectGetInteger(0,highD,OBJPROP_TIME,1)==4020&&ObjectGetDouble(0,highD,OBJPROP_PRICE,0)==130&&ObjectGetDouble(0,highD,OBJPROP_PRICE,1)==130,"VISUAL_38_INSIDE_BAR_EXTENDS_ENDPOINT_WITHOUT_LEVEL_CHANGE");
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","INVALID",0,0,4080,0,0);
   Check(ObjectFind(0,highD)<0&&ObjectFind(0,lowD)<0,"VISUAL_39_PRE_ACTIVE_INVALIDATION_DELETES_PAIR");
   string highE="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_4200_HIGH";
   string lowE="JINPA_PULLBACK_BASE_revs-ppf_"+_Symbol+"_"+IntegerToString((int)_Period)+"_4200_LOW";
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","READY",4200,4200,4260,128,112);
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-ppf","ACTIVE",4200,4200,4320,128,112);
   string highF="JINPA_PULLBACK_BASE_revs-pps_"+_Symbol+"_"+IntegerToString((int)_Period)+"_4500_HIGH";
   string lowF="JINPA_PULLBACK_BASE_revs-pps_"+_Symbol+"_"+IntegerToString((int)_Period)+"_4500_LOW";
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-pps","READY",4500,4500,4560,126,114);
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-pps","ACTIVE",4500,4500,4620,126,114);
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"revs-pps","INVALID",0,0,4680,0,0);
   renderer.Update(_Symbol,(ENUM_TIMEFRAMES)_Period,"-","NONE",0,0,4740,0,0);
   Check(ObjectFind(0,highE)>=0&&ObjectFind(0,lowE)>=0&&ObjectFind(0,highF)>=0&&ObjectFind(0,lowF)>=0,"VISUAL_40_PPF_AND_PPS_CONFIRMED_BASES_REMAIN_UNIQUE");
   Check((datetime)ObjectGetInteger(0,highF,OBJPROP_TIME,1)==4620&&ObjectFind(0,highB)>=0,"VISUAL_41_PPS_CONFIRMED_SURVIVES_AND_IS_IMMUTABLE");renderer.Destroy();
}

void TestRadarReady()
{
   SymbolState s[1];s[0].symbol=_Symbol;s[0].timeframe=(ENUM_TIMEFRAMES)_Period;s[0].cycle="BULL";s[0].regime="TREND";s[0].state="CORRECTION";s[0].structure="NONE";s[0].setup="revs-ppf";s[0].setupStatus="READY";s[0].isReady=true;
   CMarketRadar r;r.Configure(true,CORNER_RIGHT_LOWER,15,20,20,9);bool made=r.Create(s);r.Update(s,true);Check(made&&ObjectGetString(0,"JINPA_RADAR_ROW_000_COL_07",OBJPROP_TEXT)=="READY","RADAR_18_READY_VISIBLE");
   s[0].regime="RANGE";s[0].state="COMPRESSION";s[0].structure="SIDEWAY";s[0].setup="revs-pps";s[0].setupStatus="WATCH";r.Update(s,true);
   Check(ObjectGetString(0,"JINPA_RADAR_ROW_000_COL_03",OBJPROP_TEXT)=="RANGE"&&ObjectGetString(0,"JINPA_RADAR_ROW_000_COL_04",OBJPROP_TEXT)=="COMPRESSION"&&ObjectGetString(0,"JINPA_RADAR_ROW_000_COL_05",OBJPROP_TEXT)=="SIDEWAY"&&ObjectGetString(0,"JINPA_RADAR_ROW_000_COL_06",OBJPROP_TEXT)=="revs-pps"&&ObjectGetString(0,"JINPA_RADAR_ROW_000_COL_07",OBJPROP_TEXT)=="WATCH","RADAR_59_SIDEWAY_AND_PPS_COEXIST");r.Destroy();
}
int OnInit(){TestBullUnifiedLifecycle();TestBearAndInvalidation();TestBullBaseFailureAndPpsRecovery();TestBearBaseFailureAndPpsRecovery();TestSameBarOldBasePriority();TestBullPpsCompressionLifecycle();TestBearPpsCompressionLifecycle();TestCompressionEdgesAndInvalidation();TestPpfRemainsCorrectionOnly();TestFourBarBaseBuilder();TestBaseVisual();TestRadarReady();Print("[PULLBACK_SETUP_TEST][SUMMARY] passed=",g_passed," failed=",g_failed," trades=0 pending=0 cancels=0 closes=0 push=0");return g_failed==0?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick(){ExpertRemove();}
