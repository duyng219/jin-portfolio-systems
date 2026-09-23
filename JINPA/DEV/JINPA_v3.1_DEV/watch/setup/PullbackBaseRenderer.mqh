#ifndef JINPA_PULLBACK_BASE_RENDERER_MQH
#define JINPA_PULLBACK_BASE_RENDERER_MQH
#include "PullbackSetupEngine.mqh"

class CPullbackBaseRenderer
{
private:
   long m_chartId;
   string m_prefix,m_highName,m_lowName;
   void Freeze(const string name,const datetime finish)
   {if(name==""||finish<=0||ObjectFind(m_chartId,name)<0)return;datetime start=(datetime)ObjectGetInteger(m_chartId,name,OBJPROP_TIME,0);double price=ObjectGetDouble(m_chartId,name,OBJPROP_PRICE,0);if(finish>start)ObjectMove(m_chartId,name,1,finish,price);}
   void FreezeActive(const datetime finish)
   {Freeze(m_highName,finish);Freeze(m_lowName,finish);m_highName="";m_lowName="";}
   string Name(const string symbol,const ENUM_TIMEFRAMES tf,const string setup,const datetime candidate,const bool high)const
   {return m_prefix+setup+"_"+symbol+"_"+IntegerToString((int)tf)+"_"+IntegerToString((long)candidate)+(high?"_HIGH":"_LOW");}
   bool Draw(const string name,const datetime start,const datetime finish,const double price,const string tooltip)
   {
      if(ObjectFind(m_chartId,name)<0&&!ObjectCreate(m_chartId,name,OBJ_TREND,0,start,price,finish,price))return false;
      ObjectMove(m_chartId,name,0,start,price);ObjectMove(m_chartId,name,1,finish,price);
      ObjectSetInteger(m_chartId,name,OBJPROP_COLOR,clrWhite);ObjectSetInteger(m_chartId,name,OBJPROP_STYLE,STYLE_SOLID);ObjectSetInteger(m_chartId,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(m_chartId,name,OBJPROP_RAY_LEFT,false);ObjectSetInteger(m_chartId,name,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(m_chartId,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(m_chartId,name,OBJPROP_HIDDEN,true);ObjectSetInteger(m_chartId,name,OBJPROP_BACK,true);ObjectSetString(m_chartId,name,OBJPROP_TOOLTIP,tooltip);return true;
   }
public:
   CPullbackBaseRenderer(void):m_chartId(0),m_prefix("JINPA_PULLBACK_BASE_"){m_highName="";m_lowName="";}
   void Update(const string symbol,const ENUM_TIMEFRAMES tf,const string setup,const string status,const datetime candidate,const datetime start,const datetime finish,const double high,const double low)
   {
      if(status!="READY"||candidate<=0||start<=0||finish<=start||high<=low){FreezeActive(finish);ChartRedraw(m_chartId);return;}
      string hn=Name(symbol,tf,setup,candidate,true),ln=Name(symbol,tf,setup,candidate,false);if(hn!=m_highName||ln!=m_lowName)FreezeActive(finish);m_highName=hn;m_lowName=ln;
      Draw(hn,start,finish,high,"JINPA PULLBACK BASE HIGH");Draw(ln,start,finish,low,"JINPA PULLBACK BASE LOW");ChartRedraw(m_chartId);
   }
   void Destroy(void){m_highName="";m_lowName="";ObjectsDeleteAll(m_chartId,m_prefix);ChartRedraw(m_chartId);}
};
#endif
