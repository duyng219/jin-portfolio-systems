#ifndef JINPA_MICRO_BASE_RENDERER_MQH
#define JINPA_MICRO_BASE_RENDERER_MQH

#include "../state/MarketStructureEngine.mqh"

class CMicroBaseRenderer
{
private:
   long   m_chartId;
   string m_prefix;
   string m_highName;
   string m_lowName;

   string Name(const string symbol, const ENUM_TIMEFRAMES timeframe,
               const datetime anchorTime, const bool high) const
   {
      return m_prefix + symbol + "_" + IntegerToString((int)timeframe)
             + "_" + IntegerToString((long)anchorTime)
             + (high ? "_HIGH" : "_LOW");
   }

   void Freeze(const string name, const datetime finish)
   {
      if(name == "" || finish <= 0 || ObjectFind(m_chartId, name) < 0)
         return;
      const datetime start = (datetime)ObjectGetInteger(
         m_chartId, name, OBJPROP_TIME, 0);
      const double price = ObjectGetDouble(
         m_chartId, name, OBJPROP_PRICE, 0);
      if(finish > start)
         ObjectMove(m_chartId, name, 1, finish, price);
   }

   void FreezeActive(const datetime finish)
   {
      Freeze(m_highName, finish);
      Freeze(m_lowName, finish);
      m_highName = "";
      m_lowName = "";
   }

   bool Draw(const string name, const datetime start,
             const datetime finish, const double price,
             const string tooltip)
   {
      if(ObjectFind(m_chartId, name) < 0
         && !ObjectCreate(m_chartId, name, OBJ_TREND, 0,
                          start, price, finish, price))
         return false;

      ObjectMove(m_chartId, name, 0, start, price);
      ObjectMove(m_chartId, name, 1, finish, price);
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(m_chartId, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chartId, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chartId, name, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true);
      ObjectSetString(m_chartId, name, OBJPROP_TOOLTIP, tooltip);
      return true;
   }

public:
   CMicroBaseRenderer(void) : m_chartId(0),
                              m_prefix("JINPA_MICRO_BASE_")
   {
      m_highName = "";
      m_lowName = "";
   }

   void Update(const string symbol, const ENUM_TIMEFRAMES timeframe,
               const bool confirmed, const datetime anchorTime,
               const datetime finish, const double baseHigh,
               const double baseLow)
   {
      if(!confirmed || anchorTime <= 0 || finish < anchorTime
         || baseHigh <= baseLow)
      {
         FreezeActive(finish);
         ChartRedraw(m_chartId);
         return;
      }

      const string highName = Name(symbol, timeframe, anchorTime, true);
      const string lowName = Name(symbol, timeframe, anchorTime, false);
      if(highName != m_highName || lowName != m_lowName)
         FreezeActive(finish);
      m_highName = highName;
      m_lowName = lowName;

      const bool highDrawn = Draw(m_highName, anchorTime, finish,
                                  baseHigh, "JINPA MICRO BASE HIGH");
      const bool lowDrawn = Draw(m_lowName, anchorTime, finish,
                                 baseLow, "JINPA MICRO BASE LOW");
      if(!highDrawn || !lowDrawn)
      {
         ObjectDelete(m_chartId, m_highName);
         ObjectDelete(m_chartId, m_lowName);
         m_highName = "";
         m_lowName = "";
      }
      ChartRedraw(m_chartId);
   }

   void Destroy(void)
   {
      m_highName = "";
      m_lowName = "";
      ObjectsDeleteAll(m_chartId, m_prefix);
      ChartRedraw(m_chartId);
   }
};

#endif
