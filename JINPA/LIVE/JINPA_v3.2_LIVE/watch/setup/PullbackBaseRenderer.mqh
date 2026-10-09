#ifndef JINPA_PULLBACK_BASE_RENDERER_MQH
#define JINPA_PULLBACK_BASE_RENDERER_MQH
#include "PullbackSetupEngine.mqh"

class CPullbackBaseRenderer
{
private:
   long m_chartId;
   string m_prefix,m_highName,m_lowName;

   void LogError(const string reason,const string name="") const
   {
      Print("[JINPA][PULLBACK_BASE][ERROR] ",reason,
            (name==""?"":" | object="+name));
   }

   bool PriceMatches(const double actual,const double expected) const
   {
      const double tolerance=MathMax(1.0e-10,MathAbs(expected)*1.0e-12);
      return MathAbs(actual-expected)<=tolerance;
   }

   bool ReadLine(const string name,datetime &start,datetime &finish,
                 double &price0,double &price1) const
   {
      if(name==""||ObjectFind(m_chartId,name)<0)return false;
      long type=0,time0=0,time1=0;
      if(!ObjectGetInteger(m_chartId,name,OBJPROP_TYPE,0,type)
         ||(ENUM_OBJECT)type!=OBJ_TREND
         ||!ObjectGetInteger(m_chartId,name,OBJPROP_TIME,0,time0)
         ||!ObjectGetInteger(m_chartId,name,OBJPROP_TIME,1,time1)
         ||!ObjectGetDouble(m_chartId,name,OBJPROP_PRICE,0,price0)
         ||!ObjectGetDouble(m_chartId,name,OBJPROP_PRICE,1,price1))return false;
      start=(datetime)time0;finish=(datetime)time1;
      return start>0&&price0>0.0&&price1>0.0;
   }

   bool LineMatches(const string name,const datetime start,const datetime finish,
                    const double price) const
   {
      datetime actualStart=0,actualFinish=0;double price0=0.0,price1=0.0;
      return ReadLine(name,actualStart,actualFinish,price0,price1)
             &&actualStart==start&&actualFinish==finish
             &&PriceMatches(price0,price)&&PriceMatches(price1,price);
   }

   bool LineReadyToFreeze(const string name,const datetime start,
                          const double price) const
   {
      datetime actualStart=0,actualFinish=0;double price0=0.0,price1=0.0;
      return ReadLine(name,actualStart,actualFinish,price0,price1)
             &&actualStart==start&&actualFinish>actualStart
             &&PriceMatches(price0,price)&&PriceMatches(price1,price);
   }

   bool DeleteObject(const string name) const
   {
      if(name==""||ObjectFind(m_chartId,name)<0)return true;
      if(!ObjectDelete(m_chartId,name))return false;
      return ObjectFind(m_chartId,name)<0;
   }

   bool DeleteActive(void)
   {
      const bool highDeleted=DeleteObject(m_highName);
      const bool lowDeleted=DeleteObject(m_lowName);
      const bool clean=highDeleted&&lowDeleted
                       &&(m_highName==""||ObjectFind(m_chartId,m_highName)<0)
                       &&(m_lowName==""||ObjectFind(m_chartId,m_lowName)<0);
      if(!clean)
      {
         LogError("PAIR_DELETE_FAILED");
         return false;
      }
      m_highName="";m_lowName="";
      return true;
   }

   bool Draw(const string name,const datetime start,const datetime finish,
             const double price,const string tooltip)
   {
      if(name==""||start<=0||finish<=start||price<=0.0)return false;
      if(ObjectFind(m_chartId,name)>=0)
      {
         long type=0;
         if(!ObjectGetInteger(m_chartId,name,OBJPROP_TYPE,0,type)
            ||(ENUM_OBJECT)type!=OBJ_TREND)
         {
            if(!DeleteObject(name))return false;
         }
      }
      if(ObjectFind(m_chartId,name)<0
         &&!ObjectCreate(m_chartId,name,OBJ_TREND,0,start,price,finish,price))return false;
      if(!ObjectMove(m_chartId,name,0,start,price)
         ||!ObjectMove(m_chartId,name,1,finish,price)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_COLOR,clrWhite)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_STYLE,STYLE_SOLID)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_WIDTH,1)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_RAY_LEFT,false)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_RAY_RIGHT,false)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_SELECTABLE,false)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_HIDDEN,true)
         ||!ObjectSetInteger(m_chartId,name,OBJPROP_BACK,true)
         ||!ObjectSetString(m_chartId,name,OBJPROP_TOOLTIP,tooltip))return false;
      return LineMatches(name,start,finish,price);
   }

   bool DrawPair(const datetime start,const datetime finish,
                 const double high,const double low)
   {
      const bool highDrawn=Draw(m_highName,start,finish,high,
                                "JINPA PULLBACK BASE HIGH");
      if(!highDrawn)LogError("DRAW_HIGH_FAILED",m_highName);
      const bool lowDrawn=Draw(m_lowName,start,finish,low,
                               "JINPA PULLBACK BASE LOW");
      if(!lowDrawn)LogError("DRAW_LOW_FAILED",m_lowName);
      const bool valid=highDrawn&&lowDrawn
                       &&LineMatches(m_highName,start,finish,high)
                       &&LineMatches(m_lowName,start,finish,low);
      if(!valid)LogError("PAIR_VERIFY_FAILED");
      return valid;
   }

   bool Freeze(const string name,const datetime finish)
   {
      datetime start=0,currentFinish=0;double price0=0.0,price1=0.0;
      if(!ReadLine(name,start,currentFinish,price0,price1)
         ||finish<=start||!PriceMatches(price0,price1))return false;
      if(!ObjectMove(m_chartId,name,1,finish,price0))return false;
      return LineMatches(name,start,finish,price0);
   }

   bool ConfirmActive(const string symbol,const ENUM_TIMEFRAMES tf,
                      const string setup,const datetime candidate,
                      const datetime start,const datetime finish,
                      const double high,const double low)
   {
      const string highName=Name(symbol,tf,setup,candidate,true);
      const string lowName=Name(symbol,tf,setup,candidate,false);
      if(highName!=m_highName||lowName!=m_lowName)
      {
         if(!DeleteActive())return false;
         m_highName=highName;m_lowName=lowName;
      }
      if(!LineReadyToFreeze(m_highName,start,high)
         ||!LineReadyToFreeze(m_lowName,start,low))
      {
         if(!DeleteActive())return false;
         m_highName=highName;m_lowName=lowName;
         if(!DrawPair(start,finish,high,low))
         {
            DeleteActive();
            return false;
         }
      }
      const bool highFrozen=Freeze(m_highName,finish);
      if(!highFrozen)LogError("FREEZE_HIGH_FAILED",m_highName);
      const bool lowFrozen=Freeze(m_lowName,finish);
      if(!lowFrozen)LogError("FREEZE_LOW_FAILED",m_lowName);
      if(!highFrozen||!lowFrozen
         ||!LineMatches(m_highName,start,finish,high)
         ||!LineMatches(m_lowName,start,finish,low))
      {
         LogError("PAIR_VERIFY_FAILED");
         DeleteActive();
         return false;
      }
      m_highName="";m_lowName="";
      return true;
   }

   string Name(const string symbol,const ENUM_TIMEFRAMES tf,const string setup,
               const datetime candidate,const bool high)const
   {
      const int timeframeMinutes=PeriodSeconds(tf)/60;
      return m_prefix+setup+"_"+symbol+"_"+IntegerToString(timeframeMinutes)+"_"
             +IntegerToString((long)candidate)+(high?"_HIGH":"_LOW");
   }

public:
   CPullbackBaseRenderer(void):m_chartId(0),m_prefix("JINPA_PULLBACK_BASE_")
   {m_highName="";m_lowName="";}

   void Update(const string symbol,const ENUM_TIMEFRAMES tf,const string setup,
               const string status,const datetime candidate,const datetime start,
               const datetime finish,const double high,const double low)
   {
      const bool valid=candidate>0&&start>0&&finish>start&&high>low;
      if(status=="ACTIVE")
      {
         if(!valid)
         {
            DeleteActive();
         }
         else ConfirmActive(symbol,tf,setup,candidate,start,finish,high,low);
         ChartRedraw(m_chartId);
         return;
      }
      if(status!="READY"||!valid)
      {
         DeleteActive();
         ChartRedraw(m_chartId);
         return;
      }
      const string highName=Name(symbol,tf,setup,candidate,true);
      const string lowName=Name(symbol,tf,setup,candidate,false);
      if(highName!=m_highName||lowName!=m_lowName)
      {
         if(!DeleteActive())
         {
            ChartRedraw(m_chartId);
            return;
         }
         m_highName=highName;m_lowName=lowName;
      }
      if(!DrawPair(start,finish,high,low))DeleteActive();
      ChartRedraw(m_chartId);
   }

   void Destroy(void)
   {
      const int deleted=ObjectsDeleteAll(m_chartId,m_prefix);
      if(deleted<0)LogError("PAIR_DELETE_FAILED");
      m_highName="";m_lowName="";
      ChartRedraw(m_chartId);
   }
};
#endif
