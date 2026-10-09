#ifndef JINPA_SETUP_ACTIVE_ARROW_RENDERER_MQH
#define JINPA_SETUP_ACTIVE_ARROW_RENDERER_MQH

#include "../core/WatcherTypes.mqh"
#include "../core/WatcherLogger.mqh"

// Presentation-only observer of the final arbitrated setup output.
// It never owns setup semantics, notifications or execution.
class CSetupActiveArrowRenderer
{
private:
   long   m_chartId;
   string m_prefix;
   bool   m_observationInitialized;
   string m_previousSetup;
   string m_previousStatus;
   string m_previousDirection;

   bool IsCanonicalSetup(const string setup) const
   {
      return setup == "bres-pmb" || setup == "bres-pma"
             || setup == "revs-pfb" || setup == "revs-pmr"
             || setup == "revs-ppf" || setup == "revs-pps";
   }

   string Sanitize(const string value) const
   {
      string result = "";
      const string allowed =
         "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
      const int length = StringLen(value);
      for(int index = 0; index < length; index++)
      {
         const string character = StringSubstr(value, index, 1);
         result += StringFind(allowed, character) >= 0 ? character : "_";
      }
      return result;
   }

   string StableHash(const string value) const
   {
      uint hash = 2166136261;
      const int length = StringLen(value);
      for(int index = 0; index < length; index++)
      {
         hash ^= (uint)StringGetCharacter(value, index);
         hash *= 16777619;
      }
      return StringFormat("%08X", hash);
   }

   string ObjectName(const string symbol,
                     const ENUM_TIMEFRAMES timeframe,
                     const datetime activationBarTime,
                     const string setup,
                     const string direction) const
   {
      const string suffix = "_" + IntegerToString((int)timeframe) + "_"
                            + IntegerToString((long)activationBarTime) + "_"
                            + Sanitize(setup) + "_" + direction;
      string safeSymbol = Sanitize(symbol);
      string name = m_prefix + safeSymbol + suffix;
      if(StringLen(name) > 63)
      {
         safeSymbol = StringSubstr(safeSymbol, 0, 4) + "_"
                      + StableHash(symbol);
         name = m_prefix + safeSymbol + suffix;
      }
      return name;
   }

   double VisualOffset(const string symbol,
                       const MqlRates &signalBar) const
   {
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const double range = MathMax(0.0, signalBar.high - signalBar.low);
      return MathMax(10.0 * point, 0.05 * range);
   }

   bool Render(const string symbol,
               const ENUM_TIMEFRAMES timeframe,
               const string setup,
               const string direction,
               const datetime activationBarTime)
   {
      const string name = ObjectName(symbol, timeframe, activationBarTime,
                                     setup, direction);
      if(ObjectFind(m_chartId, name) >= 0)
         return true;

      const int shift = iBarShift(symbol, timeframe, activationBarTime, true);
      if(shift < 0)
      {
         WatcherLogWarning("SETUP_ARROW " + symbol + " "
                           + WatcherTimeframeToString(timeframe)
                           + " | activation bar not found");
         return false;
      }

      MqlRates signalBars[1];
      if(CopyRates(symbol, timeframe, shift, 1, signalBars) != 1
         || signalBars[0].time != activationBarTime)
      {
         WatcherLogWarning("SETUP_ARROW " + symbol + " "
                           + WatcherTimeframeToString(timeframe)
                           + " | activation OHLC unavailable");
         return false;
      }

      const double offset = VisualOffset(symbol, signalBars[0]);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const bool isBuy = direction == "BUY";
      const double price = NormalizeDouble(
         isBuy ? signalBars[0].low - offset : signalBars[0].high + offset,
         digits);
      const ENUM_OBJECT objectType = isBuy ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;

      if(!ObjectCreate(m_chartId, name, objectType, 0,
                       activationBarTime, price))
      {
         WatcherLogError("SETUP_ARROW " + symbol + " "
                         + WatcherTimeframeToString(timeframe)
                         + " | object create failed | error="
                         + IntegerToString(GetLastError()));
         return false;
      }

      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR,
                       isBuy ? clrOrange : clrOrange);
      ObjectSetInteger(m_chartId, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 25);
      ObjectSetString(m_chartId, name, OBJPROP_TOOLTIP,
                      setup + " " + direction + " ACTIVE");
      ChartRedraw(m_chartId);

      WatcherLog("SETUP_ARROW", symbol + " "
                 + WatcherTimeframeToString(timeframe) + " | "
                 + setup + " | " + direction + " | bar="
                 + TimeToString(activationBarTime, TIME_DATE | TIME_MINUTES)
                 + " | CREATED");
      return true;
   }

   void StoreObservation(const string setup,
                         const string status,
                         const string direction)
   {
      m_previousSetup = setup;
      m_previousStatus = status;
      m_previousDirection = direction;
   }

public:
   CSetupActiveArrowRenderer(void)
      : m_chartId(0), m_prefix("JINPA_SETUP_ARROW_")
   {
      Reset();
   }

   void Reset(void)
   {
      m_observationInitialized = false;
      m_previousSetup = "-";
      m_previousStatus = "NONE";
      m_previousDirection = "NONE";
   }

   void Observe(const string symbol,
                const ENUM_TIMEFRAMES timeframe,
                const string setup,
                const string status,
                const string direction,
                const datetime activationBarTime)
   {
      // Bootstrap establishes a baseline only. It must not turn an ACTIVE
      // attach-time snapshot into a fabricated runtime transition.
      if(!m_observationInitialized)
      {
         StoreObservation(setup, status, direction);
         m_observationInitialized = true;
         return;
      }

      const bool activeTransition = IsCanonicalSetup(setup)
                                    && status == "ACTIVE"
                                    && (direction == "BUY"
                                        || direction == "SELL")
                                    && activationBarTime > 0
                                    && (m_previousStatus != "ACTIVE"
                                        || m_previousSetup != setup
                                        || m_previousDirection != direction);
      if(activeTransition)
         Render(symbol, timeframe, setup, direction, activationBarTime);

      StoreObservation(setup, status, direction);
   }

   void Destroy(void)
   {
      ObjectsDeleteAll(m_chartId, m_prefix);
      ChartRedraw(m_chartId);
      Reset();
   }
};

#endif
