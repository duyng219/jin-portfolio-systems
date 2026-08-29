#ifndef JINPA_WATCHER_MARKET_RADAR_MQH
#define JINPA_WATCHER_MARKET_RADAR_MQH

#include "../core/WatcherTypes.mqh"
#include "../core/WatcherLogger.mqh"

#define JINPA_RADAR_COLUMN_COUNT 10
#define JINPA_RADAR_FOOTER_FIELD_COUNT 5

enum ENUM_RADAR_LAYOUT_PROFILE
{
   RADAR_LAYOUT_COMPACT = 0,
   RADAR_LAYOUT_WIDE,
   RADAR_LAYOUT_ULTRA
};

class CMarketRadar
{
private:
   const string     m_prefix;
   long             m_chartId;
   bool             m_enabled;
   ENUM_BASE_CORNER m_corner;
   int              m_x;
   int              m_y;
   int              m_rowHeight;
   int              m_fontSize;
   int              m_rowCount;
   int              m_panelWidth;
   int              m_panelHeight;
   int              m_columnWidths[JINPA_RADAR_COLUMN_COUNT];
   int              m_columnOffsets[JINPA_RADAR_COLUMN_COUNT];
   int              m_footerOffsets[JINPA_RADAR_FOOTER_FIELD_COUNT];
   int              m_lastChartWidth;
   ENUM_RADAR_LAYOUT_PROFILE m_layoutProfile;

   string BackgroundName() const
   {
      return m_prefix + "BG";
   }

   string TitleName() const
   {
      return m_prefix + "TITLE";
   }

   string FooterWatcherName() const
   {
      return m_prefix + "FOOTER_WATCHER";
   }

   string FooterScannerName() const
   {
      return m_prefix + "FOOTER_SCANNER";
   }

   string FooterActiveName() const
   {
      return m_prefix + "FOOTER_ACTIVE";
   }

   string FooterTfName() const
   {
      return m_prefix + "FOOTER_TF";
   }

   string FooterTimeName() const
   {
      return m_prefix + "FOOTER_TIME";
   }

   string HeaderName(const int column) const
   {
      return m_prefix + "HEADER_" + IntegerToString(column, 2, '0');
   }

   string CellName(const int row, const int column) const
   {
      return m_prefix + "ROW_" + IntegerToString(row, 3, '0')
             + "_COL_" + IntegerToString(column, 2, '0');
   }

   string HorizontalLineName(const int line) const
   {
      return m_prefix + "GRID_H_" + IntegerToString(line, 3, '0');
   }

   string ColumnHeader(const int column) const
   {
      switch(column)
      {
         case 0: return "SYMBOL";
         case 1: return "TF";
         case 2: return "CYCLE";
         case 3: return "CORE";
         case 4: return "REGIME";
         case 5: return "PHASE";
         case 6: return "STRUCT";
         case 7: return "SETUP";
         case 8: return "STATUS";
         case 9: return "LAST EVENT";
      }

      return "";
   }

   string LayoutProfileName(const ENUM_RADAR_LAYOUT_PROFILE profile) const
   {
      if(profile == RADAR_LAYOUT_ULTRA)
         return "ULTRA";
      if(profile == RADAR_LAYOUT_WIDE)
         return "WIDE";
      return "COMPACT";
   }

   void ApplyLayoutMetrics(const ENUM_RADAR_LAYOUT_PROFILE profile)
   {
      if(profile == RADAR_LAYOUT_ULTRA)
      {
         // Semantic ULTRA widths: long analytical fields receive most of the
         // additional space; SYMBOL/TF remain intentionally compact.
         m_columnWidths[0] = 90;  m_columnWidths[1] = 46;
         m_columnWidths[2] = 120; m_columnWidths[3] = 115;
         m_columnWidths[4] = 130; m_columnWidths[5] = 120;
         m_columnWidths[6] = 125; m_columnWidths[7] = 100;
         m_columnWidths[8] = 94;  m_columnWidths[9] = 240;

         m_footerOffsets[0] = 10;
         m_footerOffsets[1] = 190;
         m_footerOffsets[2] = 365;
         m_footerOffsets[3] = 525;
         m_footerOffsets[4] = 625;
      }
      else if(profile == RADAR_LAYOUT_WIDE)
      {
         m_columnWidths[0] = 82;  m_columnWidths[1] = 42;
         m_columnWidths[2] = 102; m_columnWidths[3] = 108;
         m_columnWidths[4] = 108; m_columnWidths[5] = 100;
         m_columnWidths[6] = 108; m_columnWidths[7] = 92;
         m_columnWidths[8] = 88;  m_columnWidths[9] = 180;

         m_footerOffsets[0] = 10;
         m_footerOffsets[1] = 165;
         m_footerOffsets[2] = 305;
         m_footerOffsets[3] = 435;
         m_footerOffsets[4] = 510;
      }
      else
      {
         m_columnWidths[0] = 72; m_columnWidths[1] = 34;
         m_columnWidths[2] = 88; m_columnWidths[3] = 90;
         m_columnWidths[4] = 94; m_columnWidths[5] = 86;
         m_columnWidths[6] = 92; m_columnWidths[7] = 76;
         m_columnWidths[8] = 72; m_columnWidths[9] = 150;

         m_footerOffsets[0] = 10;
         m_footerOffsets[1] = 130;
         m_footerOffsets[2] = 230;
         m_footerOffsets[3] = 320;
         m_footerOffsets[4] = 375;
      }

      int offset = 10;
      for(int column = 0; column < JINPA_RADAR_COLUMN_COUNT; column++)
      {
         m_columnOffsets[column] = offset;
         offset += m_columnWidths[column];
      }
      m_panelWidth = offset + 10;
   }

   void CalculateResponsiveLayout()
   {
      long chartWidthValue = 0;
      if(!ChartGetInteger(m_chartId, CHART_WIDTH_IN_PIXELS, 0, chartWidthValue))
         chartWidthValue = 0;

      const int chartWidth = (int)chartWidthValue;
      ApplyLayoutMetrics(RADAR_LAYOUT_COMPACT);
      const int compactWidth = m_panelWidth;
      ApplyLayoutMetrics(RADAR_LAYOUT_WIDE);
      const int wideWidth = m_panelWidth;
      ApplyLayoutMetrics(RADAR_LAYOUT_ULTRA);
      const int ultraWidth = m_panelWidth;
      const int availableWidth = MathMax(0, chartWidth - (m_x * 2));

      // Wide is selected only when the drawable viewport comfortably fits the
      // footprint of both profiles. This derives the breakpoint from the UI's
      // own minimum widths instead of assuming a Windows resolution or DPI.
      const int wideThreshold = compactWidth + wideWidth + 80;
      // Runtime logs on the 2880x1800 Visual Tester show available widths of
      // 2137-2193 px. 2100 keeps that complete observed range in ULTRA while
      // the 1910 px Full-HD chart remains COMPACT.
      const int ultraThreshold = 2100;
      ENUM_RADAR_LAYOUT_PROFILE profile = RADAR_LAYOUT_COMPACT;
      if(availableWidth >= ultraThreshold)
         profile = RADAR_LAYOUT_ULTRA;
      else if(availableWidth >= wideThreshold)
         profile = RADAR_LAYOUT_WIDE;

      const bool layoutChanged = chartWidth != m_lastChartWidth
                                 || profile != m_layoutProfile;

      ApplyLayoutMetrics(profile);
      m_lastChartWidth = chartWidth;
      m_layoutProfile = profile;

      if(layoutChanged)
      {
         WatcherLog("RADAR][LAYOUT", "chart_width=" + IntegerToString(chartWidth)
                    + " | available_width=" + IntegerToString(availableWidth)
                    + " | profile=" + LayoutProfileName(profile)
                    + " | panel_width=" + IntegerToString(m_panelWidth)
                    + " | wide_threshold=" + IntegerToString(wideThreshold)
                    + " | ultra_threshold=" + IntegerToString(ultraThreshold)
                    + " | ultra_width=" + IntegerToString(ultraWidth));
      }
   }

   int ColumnWidth(const int column) const
   {
      if(column < 0 || column >= JINPA_RADAR_COLUMN_COUNT)
         return 0;
      return m_columnWidths[column];
   }

   int ColumnOffset(const int column) const
   {
      if(column < 0 || column >= JINPA_RADAR_COLUMN_COUNT)
         return 10;
      return m_columnOffsets[column];
   }

   int LabelX(const int leftOffset) const
   {
      if(m_corner == CORNER_RIGHT_UPPER || m_corner == CORNER_RIGHT_LOWER)
         return m_x + m_panelWidth - leftOffset;

      return m_x + leftOffset;
   }

   int LabelY(const int topOffset) const
   {
      if(m_corner == CORNER_LEFT_LOWER || m_corner == CORNER_RIGHT_LOWER)
         return m_y + m_panelHeight - topOffset;

      return m_y + topOffset;
   }

   bool CreateLabel(const string name, const string text, const color textColor)
   {
      ResetLastError();
      if(!ObjectCreate(m_chartId, name, OBJ_LABEL, 0, 0, 0))
      {
         WatcherLogError("Radar label creation failed: " + name
                         + " | error=" + IntegerToString(GetLastError()));
         return false;
      }

      ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chartId, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(m_chartId, name, OBJPROP_FONTSIZE, m_fontSize);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 20);
      ObjectSetString(m_chartId, name, OBJPROP_FONT, "Consolas");
      ObjectSetString(m_chartId, name, OBJPROP_TEXT, text);
      return true;
   }

   bool CreateBackground()
   {
      const string name = BackgroundName();
      ResetLastError();
      if(!ObjectCreate(m_chartId, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         WatcherLogError("Radar background creation failed"
                         + " | error=" + IntegerToString(GetLastError()));
         return false;
      }

      ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chartId, name, OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(m_chartId, name, OBJPROP_YDISTANCE, m_y);
      ObjectSetInteger(m_chartId, name, OBJPROP_XSIZE, m_panelWidth);
      ObjectSetInteger(m_chartId, name, OBJPROP_YSIZE, m_panelHeight);
      ObjectSetInteger(m_chartId, name, OBJPROP_BGCOLOR, C'14,18,24');
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, C'85,96,112');
      ObjectSetInteger(m_chartId, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 10);
      return true;
   }

   bool CreateGridLine(const string name)
   {
      ResetLastError();
      if(!ObjectCreate(m_chartId, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         WatcherLogError("Radar grid line creation failed: " + name
                         + " | error=" + IntegerToString(GetLastError()));
         return false;
      }

      ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chartId, name, OBJPROP_BGCOLOR, C'75,86,102');
      ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, C'75,86,102');
      ObjectSetInteger(m_chartId, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true);
      ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 15);
      return true;
   }

   void SetRectangleGeometry(const string name,
                             const int leftOffset,
                             const int topOffset,
                             const int width,
                             const int height)
   {
      int xDistance = m_x + leftOffset;
      int yDistance = m_y + topOffset;

      if(m_corner == CORNER_RIGHT_UPPER || m_corner == CORNER_RIGHT_LOWER)
         xDistance = m_x + m_panelWidth - leftOffset - width;

      if(m_corner == CORNER_LEFT_LOWER || m_corner == CORNER_RIGHT_LOWER)
         yDistance = m_y + m_panelHeight - topOffset - height;

      ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chartId, name, OBJPROP_XDISTANCE, xDistance);
      ObjectSetInteger(m_chartId, name, OBJPROP_YDISTANCE, yDistance);
      ObjectSetInteger(m_chartId, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chartId, name, OBJPROP_YSIZE, height);
   }

   void SetLabelPosition(const string name, const int leftOffset, const int topOffset)
   {
      ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chartId, name, OBJPROP_XDISTANCE, LabelX(leftOffset));
      ObjectSetInteger(m_chartId, name, OBJPROP_YDISTANCE, LabelY(topOffset));
   }

   void SetTextIfChanged(const string name, const string text)
   {
      if(ObjectGetString(m_chartId, name, OBJPROP_TEXT) != text)
         ObjectSetString(m_chartId, name, OBJPROP_TEXT, text);
   }

   void SetColorIfChanged(const string name, const color textColor)
   {
      if((color)ObjectGetInteger(m_chartId, name, OBJPROP_COLOR) != textColor)
         ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, textColor);
   }

   color CellColor(const SymbolState &state, const int column) const
   {
      const color neutralText = C'225,230,238';
      const color neutralState = C'145,145,145';

      if(column == 2)
      {
         if(state.cycle == "BULL")
            return C'110,185,135';
         if(state.cycle == "BEAR")
            return C'195,115,115';
         return neutralState;
      }

      if(column == 3)
         return state.hasActiveCore && state.activeCorePrice > 0.0
                ? C'210,160,95' : neutralState;

      return neutralText;
   }

   string CellValue(const SymbolState &state, const int column) const
   {
      switch(column)
      {
         case 0: return state.symbol;
         case 1: return WatcherTimeframeToString(state.timeframe);
         case 2:
         {
            if(state.cycle == "BULL")
               return "BULL (UP)";
            if(state.cycle == "BEAR")
               return "BEAR (DOWN)";
            return "UNKNOWN";
         }
         case 3:
         {
            if(!state.hasActiveCore || state.activeCorePrice <= 0.0)
               return "-";
            const int digits = (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS);
            return DoubleToString(state.activeCorePrice, digits);
         }
         case 4: return state.regime;
         case 5: return state.phase;
         case 6: return state.structure;
         case 7: return state.setup;
         case 8: return state.setupStatus;
         case 9: return state.lastEvent;
      }

      return "";
   }

   void ApplyTestData(const int row, SymbolState &state) const
   {
      if(row == 0)
      {
         state.cycle       = "BULL";
         state.activeCorePrice = 3341.20;
         state.hasActiveCore = true;
         state.regime      = "TREND_WEAK";
         state.phase       = "CORRECTION";
         state.structure   = "PB LEG 2";
         state.setup       = "revs-pps";
         state.setupStatus = "READY";
         state.lastEvent   = "PB2 detected";
      }
      else if(row == 1)
      {
         state.cycle       = "BEAR";
         state.activeCorePrice = 1.16850;
         state.hasActiveCore = true;
         state.regime      = "RANGE";
         state.phase       = "COMPRESSION";
         state.structure   = "UPPER BUILD";
         state.setup       = "bres-pmb";
         state.setupStatus = "WATCH";
         state.lastEvent   = "Compression";
      }
      else if(row == 2)
      {
         state.cycle       = "BULL";
         state.activeCorePrice = 117420.0;
         state.hasActiveCore = true;
         state.regime      = "TREND_STRONG";
         state.phase       = "IMPULSE";
         state.structure   = "IMPULSE";
         state.setup       = "-";
         state.setupStatus = "NONE";
         state.lastEvent   = "New HH";
      }
   }

public:
   CMarketRadar() : m_prefix("JINPA_RADAR_")
   {
      m_chartId    = 0;
      m_enabled    = false;
      m_corner     = CORNER_LEFT_UPPER;
      m_x          = 10;
      m_y          = 20;
      m_rowHeight  = 20;
      m_fontSize   = 9;
      m_rowCount   = 0;
      m_panelWidth = 0;
      m_panelHeight = 0;
      m_lastChartWidth = -1;
      m_layoutProfile = RADAR_LAYOUT_COMPACT;
      ApplyLayoutMetrics(RADAR_LAYOUT_COMPACT);
   }

   void Configure(const bool enabled,
                  const ENUM_BASE_CORNER corner,
                  const int x,
                  const int y,
                  const int rowHeight,
                  const int fontSize)
   {
      m_enabled   = enabled;
      m_corner    = corner;
      m_x         = x;
      m_y         = y;
      m_rowHeight = rowHeight;
      m_fontSize  = fontSize;
   }

   bool Create(const SymbolState &states[])
   {
      if(!m_enabled)
         return true;

      Destroy();
      m_rowCount = ArraySize(states);
      CalculateResponsiveLayout();
      m_panelHeight = 60 + (m_rowCount * m_rowHeight) + 36;

      if(!CreateBackground())
         return false;

      for(int line = 0; line < 3; line++)
      {
         if(!CreateGridLine(HorizontalLineName(line)))
         {
            Destroy();
            return false;
         }
      }

      if(!CreateLabel(TitleName(), "JINPA WATCH v1.1", C'255,190,80'))
      {
         Destroy();
         return false;
      }

      if(!CreateLabel(FooterWatcherName(), "", C'145,185,215')
         || !CreateLabel(FooterScannerName(), "", C'145,185,215')
         || !CreateLabel(FooterActiveName(), "", C'145,185,215')
         || !CreateLabel(FooterTfName(), "", C'145,185,215')
         || !CreateLabel(FooterTimeName(), "", C'145,185,215'))
      {
         Destroy();
         return false;
      }

      for(int column = 0; column < JINPA_RADAR_COLUMN_COUNT; column++)
      {
         if(!CreateLabel(HeaderName(column), ColumnHeader(column), C'115,195,255'))
         {
            Destroy();
            return false;
         }
      }

      for(int row = 0; row < m_rowCount; row++)
      {
         for(int column = 0; column < JINPA_RADAR_COLUMN_COUNT; column++)
         {
            if(!CreateLabel(CellName(row, column), "", C'225,230,238'))
            {
               Destroy();
               return false;
            }
         }
      }

      RefreshLayout();
      ChartRedraw(m_chartId);
      WatcherLog("INIT", "Market Radar created | rows=" + IntegerToString(m_rowCount));
      return true;
   }

   void Update(const SymbolState &states[],
               const bool testMode,
               const int validSymbolCount,
               const int configuredSymbolCount,
               const int activeSymbolCount,
               const ENUM_TIMEFRAMES scannerTimeframe,
               const bool watcherActive)
   {
      if(!m_enabled)
         return;

      if(ArraySize(states) != m_rowCount)
      {
         if(!Create(states))
            return;
      }

      SetTextIfChanged(TitleName(), testMode
                       ? "JINPA WATCH v1.1 | TEST MODE"
                       : "JINPA WATCH v1.1");

      for(int row = 0; row < m_rowCount; row++)
      {
         SymbolState displayState = states[row];
         if(testMode)
            ApplyTestData(row, displayState);

         for(int column = 0; column < JINPA_RADAR_COLUMN_COUNT; column++)
         {
            const string cellName = CellName(row, column);
            SetTextIfChanged(cellName, CellValue(displayState, column));
            SetColorIfChanged(cellName, CellColor(displayState, column));
         }
      }

      SetTextIfChanged(FooterWatcherName(), "WATCHER: "
                       + (watcherActive ? "ACTIVE" : "STARTING"));
      SetTextIfChanged(FooterScannerName(), "SCANNER: "
                       + IntegerToString(validSymbolCount) + "/"
                       + IntegerToString(configuredSymbolCount));
      SetTextIfChanged(FooterActiveName(), "ACTIVE: "
                       + IntegerToString(activeSymbolCount) + "/"
                       + IntegerToString(validSymbolCount));
      SetTextIfChanged(FooterTfName(), "TF: "
                       + WatcherTimeframeToString(scannerTimeframe));
      SetTextIfChanged(FooterTimeName(), "LAST UPDATE: "
                       + TimeToString(TimeCurrent(), TIME_MINUTES));

      ChartRedraw(m_chartId);
   }

   void RefreshLayout()
   {
      if(!m_enabled || ObjectFind(m_chartId, BackgroundName()) < 0)
         return;

      CalculateResponsiveLayout();

      const string background = BackgroundName();
      ObjectSetInteger(m_chartId, background, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chartId, background, OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(m_chartId, background, OBJPROP_YDISTANCE, m_y);
      ObjectSetInteger(m_chartId, background, OBJPROP_XSIZE, m_panelWidth);
      ObjectSetInteger(m_chartId, background, OBJPROP_YSIZE, m_panelHeight);

      SetLabelPosition(TitleName(), 10, 8);
      for(int column = 0; column < JINPA_RADAR_COLUMN_COUNT; column++)
         SetLabelPosition(HeaderName(column), ColumnOffset(column), 36);

      SetRectangleGeometry(HorizontalLineName(0), 10, 31, m_panelWidth - 20, 1);
      SetRectangleGeometry(HorizontalLineName(1), 10, 55, m_panelWidth - 20, 1);

      for(int row = 0; row < m_rowCount; row++)
      {
         const int top = 61 + (row * m_rowHeight);
         for(int column = 0; column < JINPA_RADAR_COLUMN_COUNT; column++)
            SetLabelPosition(CellName(row, column), ColumnOffset(column), top);

      }

      const int footerSeparatorTop = 60 + (m_rowCount * m_rowHeight);
      SetRectangleGeometry(HorizontalLineName(2), 10, footerSeparatorTop,
                           m_panelWidth - 20, 1);
      const int footerTop = 60 + (m_rowCount * m_rowHeight) + 9;
      SetLabelPosition(FooterWatcherName(), m_footerOffsets[0], footerTop);
      SetLabelPosition(FooterScannerName(), m_footerOffsets[1], footerTop);
      SetLabelPosition(FooterActiveName(), m_footerOffsets[2], footerTop);
      SetLabelPosition(FooterTfName(), m_footerOffsets[3], footerTop);
      SetLabelPosition(FooterTimeName(), m_footerOffsets[4], footerTop);

      ChartRedraw(m_chartId);
   }

   void Destroy()
   {
      ObjectsDeleteAll(m_chartId, m_prefix);
      m_rowCount = 0;
      ChartRedraw(m_chartId);
   }
};

#endif
