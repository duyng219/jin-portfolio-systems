#ifndef JINPA_WATCHER_STRUCTURE_DEBUG_RENDERER_MQH
#define JINPA_WATCHER_STRUCTURE_DEBUG_RENDERER_MQH

#include "StructureTypes.mqh"
#include "../core/WatcherLogger.mqh"

class CStructureDebugRenderer
{
private:
   const string m_prefix;
   const string m_swingPrefix;
   const string m_brokenCorePrefix;
   const string m_sidewayHighPrefix;
   const string m_sidewayLowPrefix;
   long         m_chartId;
   bool         m_showStructureSwings;
   double       m_activeCoreHigh;
   double       m_activeCoreLow;
   long         m_activeGeneration;
   ENUM_CORE_BOX_LIFECYCLE m_activeLifecycle;

   string SwingObjectName(const SwingPoint &point) const
   {
      return m_swingPrefix + StructurePointToString(point.classification)
             + "_" + IntegerToString((long)point.time);
   }

   bool DrawSwing(const SwingPoint &point)
   {
      if(point.classification == STRUCT_NONE)
         return true;

      const string name = SwingObjectName(point);
      if(ObjectFind(m_chartId, name) < 0)
      {
         ResetLastError();
         if(!ObjectCreate(m_chartId, name, OBJ_TEXT, 0, point.time, point.price))
         {
            WatcherLogError("Structure debug object failed: " + name
                            + " | error=" + IntegerToString(GetLastError()));
            return false;
         }

         const bool isHigh = point.type == SWING_HIGH;
         ObjectSetInteger(m_chartId, name, OBJPROP_COLOR,
                          isHigh ? C'255,110,110' : C'80,220,150');
         ObjectSetInteger(m_chartId, name, OBJPROP_FONTSIZE, 5);
         ObjectSetInteger(m_chartId, name, OBJPROP_ANCHOR,
                          isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
         ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
         ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
         ObjectSetInteger(m_chartId, name, OBJPROP_BACK, false);
         ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 5);
         ObjectSetString(m_chartId, name, OBJPROP_FONT, "Arial Bold");
         ObjectSetString(m_chartId, name, OBJPROP_TEXT,
                         StructurePointToString(point.classification));
      }
      else
      {
         ObjectMove(m_chartId, name, 0, point.time, point.price);
      }

      return true;
   }

   string BrokenCoreObjectName(const BrokenCoreRecord &record) const
   {
      return m_brokenCorePrefix
             + record.symbol + "_"
             + IntegerToString((int)record.timeframe) + "_"
             + IntegerToString((long)record.originTime) + "_"
             + IntegerToString((long)record.confirmationBreakTime);
   }

   bool DrawBrokenCore(const BrokenCoreRecord &record)
   {
      if(record.price <= 0.0 || record.originTime <= 0
         || record.confirmationBreakTime <= record.originTime)
         return false;

      const string name = BrokenCoreObjectName(record);
      if(ObjectFind(m_chartId, name) < 0)
      {
         ResetLastError();
         if(!ObjectCreate(m_chartId, name, OBJ_TREND, 0,
                          record.originTime, record.price,
                          record.confirmationBreakTime, record.price))
         {
            WatcherLogError("Broken Core object failed: " + name
                            + " | error=" + IntegerToString(GetLastError()));
            return false;
         }

      }
      else
      {
         ObjectMove(m_chartId, name, 0, record.originTime, record.price);
         ObjectMove(m_chartId, name, 1, record.confirmationBreakTime, record.price);
      }

      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(m_chartId, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chartId, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chartId, name, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true);
      ObjectSetString(m_chartId, name, OBJPROP_TOOLTIP, "JINPA BROKEN CORE");

      return true;
   }

   string SidewayObjectName(const SidewayBoxRecord &record,
                            const bool isHigh) const
   {
      return (isHigh ? m_sidewayHighPrefix : m_sidewayLowPrefix)
             + record.symbol + "_"
             + IntegerToString((int)record.timeframe) + "_"
             + IntegerToString((long)record.boxStartTime);
   }

   bool DrawSidewayBoundary(const SidewayBoxRecord &record,
                            const bool isHigh)
   {
      const double price = isHigh ? record.boxHigh : record.boxLow;
      const datetime leftTime = isHigh ? record.boxHighTime
                                       : record.boxLowTime;
      if(price <= 0.0 || leftTime <= 0 || record.boxStartTime <= 0
         || record.boxEndTime <= leftTime)
         return false;

      const string name = SidewayObjectName(record, isHigh);
      if(ObjectFind(m_chartId, name) < 0)
      {
         ResetLastError();
         if(!ObjectCreate(m_chartId, name, OBJ_TREND, 0,
                          leftTime, price,
                          record.boxEndTime, price))
         {
            WatcherLogError("Sideway boundary object failed: " + name
                            + " | error=" + IntegerToString(GetLastError()));
            return false;
         }
      }

      ObjectMove(m_chartId, name, 0, leftTime, price);
      ObjectMove(m_chartId, name, 1, record.boxEndTime, price);
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(m_chartId, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chartId, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chartId, name, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true);
      ObjectSetString(m_chartId, name, OBJPROP_TOOLTIP,
                      isHigh ? "JINPA SIDEWAY BOX HIGH"
                             : "JINPA SIDEWAY BOX LOW");
      return true;
   }

   void UpdateCoreLine(const string name,
                        const double price,
                        const color lineColor,
                        const string tooltip)
   {
      if(price <= 0.0)
      {
         ObjectDelete(m_chartId, name);
         return;
      }

      if(ObjectFind(m_chartId, name) < 0)
      {
         ResetLastError();
         if(!ObjectCreate(m_chartId, name, OBJ_HLINE, 0, 0, price))
         {
            WatcherLogError("Active Core line failed: " + name
                            + " | error=" + IntegerToString(GetLastError()));
            return;
         }
      }

      // Re-apply the complete visual state on refresh. This keeps the active
      // object deterministic in Visual Tester without recreating it.
      ObjectSetDouble(m_chartId, name, OBJPROP_PRICE, 0, price);
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(m_chartId, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chartId, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 4);
      ObjectSetString(m_chartId, name, OBJPROP_TOOLTIP, tooltip);
   }

   bool GetCoreLabelGeometry(const double price,
                             int &labelX,
                             int &priceY) const
   {
      long chartWidth = 0;
      long chartHeight = 0;
      if(!ChartGetInteger(m_chartId, CHART_WIDTH_IN_PIXELS, 0, chartWidth)
         || !ChartGetInteger(m_chartId, CHART_HEIGHT_IN_PIXELS, 0, chartHeight)
         || chartWidth <= 0 || chartHeight <= 0)
         return false;

      const int sampleY = MathMax((int)chartHeight / 2, 1);
      int subWindow = 0;
      datetime visibleTime = 0;
      double visiblePrice = 0.0;
      if(!ChartXYToTimePrice(m_chartId, (int)chartWidth / 2, sampleY,
                             subWindow, visibleTime, visiblePrice)
         || subWindow != 0 || visibleTime <= 0)
         return false;

      int unusedX = 0;
      if(!ChartTimePriceToXY(m_chartId, 0, visibleTime, price,
                             unusedX, priceY))
         return false;

      int plotRightX = (int)chartWidth - 1;
      for(int x = (int)chartWidth - 1; x >= 0; x--)
      {
         int probeSubWindow = 0;
         datetime probeTime = 0;
         double probePrice = 0.0;
         if(ChartXYToTimePrice(m_chartId, x, sampleY,
                               probeSubWindow, probeTime, probePrice)
            && probeSubWindow == 0)
         {
            plotRightX = x;
            break;
         }
      }

      const int rightMarginPixels = 16;
      labelX = MathMax(plotRightX - rightMarginPixels, rightMarginPixels);
      return true;
   }

   void UpdateCoreScreenLabel(const string name,
                              const double price,
                              const color textColor,
                              const string text,
                              const bool isCoreHigh)
   {
      if(price <= 0.0)
      {
         ObjectDelete(m_chartId, name);
         return;
      }

      int labelX = 0;
      int priceY = 0;
      if(!GetCoreLabelGeometry(price, labelX, priceY))
         return;

      if(ObjectFind(m_chartId, name) >= 0
         && (ENUM_OBJECT)ObjectGetInteger(m_chartId, name, OBJPROP_TYPE)
            != OBJ_LABEL)
         ObjectDelete(m_chartId, name);

      if(ObjectFind(m_chartId, name) < 0)
      {
         ResetLastError();
         if(!ObjectCreate(m_chartId, name, OBJ_LABEL, 0, 0, 0))
         {
            WatcherLogError("Active Core label failed: " + name
                            + " | error=" + IntegerToString(GetLastError()));
            return;
         }
      }

      const int verticalGapPixels = 2;
      ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartId, name, OBJPROP_XDISTANCE, labelX);
      ObjectSetInteger(m_chartId, name, OBJPROP_YDISTANCE,
                       isCoreHigh ? priceY - verticalGapPixels
                                  : priceY + verticalGapPixels);
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(m_chartId, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(m_chartId, name, OBJPROP_ANCHOR,
                       isCoreHigh ? ANCHOR_RIGHT_LOWER
                                  : ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 5);
      ObjectSetString(m_chartId, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetString(m_chartId, name, OBJPROP_TEXT, text);
   }

public:
   CStructureDebugRenderer() : m_prefix("JINPA_STRUCT_"),
                               m_swingPrefix("JINPA_SWING_"),
                               m_brokenCorePrefix("JINPA_BROKEN_CORE_"),
                               m_sidewayHighPrefix("JINPA_SIDEWAY_BOX_HIGH_"),
                               m_sidewayLowPrefix("JINPA_SIDEWAY_BOX_LOW_")
   {
      m_chartId = 0;
      m_showStructureSwings = true;
      m_activeCoreHigh = 0.0;
      m_activeCoreLow = 0.0;
      m_activeGeneration = 0;
      m_activeLifecycle = CORE_BOX_EMPTY;
   }

   void Configure(const bool showStructureSwings)
   {
      m_showStructureSwings = showStructureSwings;
      if(!m_showStructureSwings)
         ObjectsDeleteAll(m_chartId, m_swingPrefix);
   }

   void RefreshActiveCoreLabelPosition()
   {
      const color coreColor = C'255,165,0';
      const string generation = " G" + IntegerToString(m_activeGeneration);
      const string transition =
         m_activeLifecycle == CORE_BOX_PENDING_HIGH ? " | Pending High"
         : m_activeLifecycle == CORE_BOX_PENDING_LOW ? " | Pending Low" : "";
      UpdateCoreScreenLabel(m_prefix + "CORE_HIGH_LABEL", m_activeCoreHigh,
                            coreColor, "Core High" + generation + transition, true);
      UpdateCoreScreenLabel(m_prefix + "CORE_LOW_LABEL", m_activeCoreLow,
                            coreColor, "Core Low" + generation + transition, false);
      ChartRedraw(m_chartId);
   }

   void Update(const PriceStructureState &state,
               const SwingPoint &swings[],
               const BrokenCoreRecord &brokenCores[],
               const SidewayBoxRecord &sidewayBoxes[])
   {
      if(m_showStructureSwings)
      {
         const int count = ArraySize(swings);
         for(int index = 0; index < count; index++)
            DrawSwing(swings[index]);
      }
      else
         ObjectsDeleteAll(m_chartId, m_swingPrefix);

      const int brokenCount = ArraySize(brokenCores);
      for(int index = 0; index < brokenCount; index++)
         DrawBrokenCore(brokenCores[index]);

      const int boxCount = ArraySize(sidewayBoxes);
      for(int index = 0; index < boxCount; index++)
      {
         DrawSidewayBoundary(sidewayBoxes[index], true);
         DrawSidewayBoundary(sidewayBoxes[index], false);
      }

      if(state.sidewayBox.active)
      {
         SidewayBoxRecord activeBox;
         activeBox.symbol = _Symbol;
         activeBox.timeframe = (ENUM_TIMEFRAMES)_Period;
         activeBox.boxHigh = state.sidewayBox.boxHigh;
         activeBox.boxHighTime = state.sidewayBox.boxHighTime;
         activeBox.boxLow = state.sidewayBox.boxLow;
         activeBox.boxLowTime = state.sidewayBox.boxLowTime;
         activeBox.boxStartTime = state.sidewayBox.boxStartTime;
         activeBox.boxEndTime = state.sidewayBox.lastUpdateTime;
         activeBox.endStatus = SIDEWAY_BOX_ACTIVE;
         DrawSidewayBoundary(activeBox, true);
         DrawSidewayBoundary(activeBox, false);
      }

      // The Engine owns both Core boundaries.  The chart owns one protected
      // boundary only: Bull protects Low; Bear protects High.  Lifecycle is
      // checked as well so empty or inconsistent snapshots clear stale UI.
      const bool bullProtected = state.initialized
                                 && state.coreBox.cycle == MARKET_CYCLE_BULL
                                 && (state.coreBox.lifecycle == CORE_BOX_COMPLETE
                                     || state.coreBox.lifecycle
                                        == CORE_BOX_PENDING_HIGH)
                                 && state.coreBox.coreLow.confirmed;
      const bool bearProtected = state.initialized
                                 && state.coreBox.cycle == MARKET_CYCLE_BEAR
                                 && (state.coreBox.lifecycle == CORE_BOX_COMPLETE
                                     || state.coreBox.lifecycle
                                        == CORE_BOX_PENDING_LOW)
                                 && state.coreBox.coreHigh.confirmed;
      const double coreHigh = bearProtected
                              ? state.coreBox.coreHigh.price : 0.0;
      const double coreLow = bullProtected
                             ? state.coreBox.coreLow.price : 0.0;
      const color coreColor = C'255,165,0';

      // Stable names plus zero-price deletion remove the formerly protected
      // side in the same refresh without touching finite Broken Core history.
      UpdateCoreLine(m_prefix + "CORE_HIGH", coreHigh,
                     coreColor, "JINPA COREBOX | Core High");
      UpdateCoreLine(m_prefix + "CORE_LOW", coreLow,
                     coreColor, "JINPA COREBOX | Core Low");
      m_activeCoreHigh = coreHigh;
      m_activeCoreLow = coreLow;
      m_activeGeneration = state.pendingCoreBox.active
                           ? state.pendingCoreBox.targetGeneration
                           : state.coreBox.generation;
      m_activeLifecycle = state.coreBox.lifecycle;
      RefreshActiveCoreLabelPosition();
   }

   void Destroy()
   {
      ObjectsDeleteAll(m_chartId, m_prefix);
      ObjectsDeleteAll(m_chartId, m_swingPrefix);
      ObjectsDeleteAll(m_chartId, m_brokenCorePrefix);
      ObjectsDeleteAll(m_chartId, m_sidewayHighPrefix);
      ObjectsDeleteAll(m_chartId, m_sidewayLowPrefix);
      m_activeCoreHigh = 0.0;
      m_activeCoreLow = 0.0;
      m_activeGeneration = 0;
      m_activeLifecycle = CORE_BOX_EMPTY;
      ChartRedraw(m_chartId);
   }
};

#endif
