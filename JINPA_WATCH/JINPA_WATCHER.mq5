//+------------------------------------------------------------------+
//|                                                JINPA WATCH v1.1 |
//|                                       Copyright 2026, Duy Nguyen |
//|                                             https://duyquant.dev |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Duy Nguyen"
#property link      "https://duyquant.dev"
#property version   "1.10"
#property description "JINPA WATCH v1.1 - Core Swing and Cycle Observer"
#property strict

#include "core/SymbolScanner.mqh"
#include "core/NotificationManager.mqh"
#include "ui/MarketRadar.mqh"
#include "structure/PriceStructureEngine.mqh"
#include "structure/StructureDebugRenderer.mqh"
#include "structure/StructureNotificationManager.mqh"

input group "WATCHER SETTINGS"
input string          SymbolsList             = "XAUUSD,EURUSD,BTCUSD,GBPUSD,USDJPY,US30";
input ENUM_TIMEFRAMES ScannerTimeframe        = PERIOD_H1;

input group "STRUCTURE SENSITIVITY"
input double          MinSwingDistanceATR     = 1.2;
input double          CoreBreakATRBuffer      = 0.10;

// ==================================================
// JINPA_WATCH INTERNAL CONFIG
// ==================================================
const int              ScanIntervalSeconds     = 10;
const int              MarketActivityTimeoutSeconds = 120;

const bool             ShowMarketRadar         = true;
const bool             RadarTestMode           = false;
const ENUM_BASE_CORNER RadarCorner             = CORNER_LEFT_UPPER;
const int              RadarX                  = 10;
const int              RadarY                  = 20;
const int              RadarRowHeight          = 20;
const int              RadarFontSize           = 9;

const int              SwingLeftBars           = 5;
const int              SwingRightBars          = 5;
const bool             UseMinSwingDistanceATR  = true;
const int              ATRPeriod               = 14;
const int              StructureLookbackBars   = 500;

const bool             ShowStructureDebug      = true;
const bool             UseCoreBreakATRBuffer   = true;

const bool             NotifyCoreSwingChange   = true;
const bool             NotifyCoreBreakCandidate = true;
const bool             NotifyCycleChange       = true;

// ==================================================
// JINPA_WATCH INTERNAL DEVELOPMENT CONFIG
// ==================================================
const bool             EnableTestNotification  = false;
const int              TestNotificationSeconds = 60;
const bool             EnableStructureAuditLog = false;
const bool             EnableCoreBreakAuditLog = false;

CSymbolScanner       g_scanner;
CNotificationManager g_notificationManager;
CMarketRadar         g_marketRadar;
CPriceStructureEngine g_priceStructureEngine;
CStructureDebugRenderer g_structureDebugRenderer;
CStructureNotificationManager g_structureNotificationManager;
SymbolState          g_displayStates[];
PriceStructureState  g_chartStructureState;
SwingPoint           g_chartSwings[];
BrokenCoreRecord     g_chartBrokenCores[];
SidewayBoxRecord     g_chartSidewayBoxes[];
StructureEvent       g_structureEvents[];
datetime             g_testerLastBarTime = 0;

bool IsTesterMode()
{
   return (bool)MQLInfoInteger(MQL_TESTER);
}

void UpdateChartStructureDebug()
{
   if(!ShowStructureDebug)
      return;

   if(g_priceStructureEngine.GetSnapshot(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                          g_chartStructureState, g_chartSwings,
                                          g_chartBrokenCores,
                                          g_chartSidewayBoxes))
   {
      g_structureDebugRenderer.Update(g_chartStructureState, g_chartSwings,
                                      g_chartBrokenCores,
                                      g_chartSidewayBoxes);
   }
}

int OnInit()
{
   if(ScanIntervalSeconds <= 0)
   {
      WatcherLogError("ScanIntervalSeconds must be greater than zero.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(MarketActivityTimeoutSeconds <= 0)
   {
      WatcherLogError("MarketActivityTimeoutSeconds must be greater than zero.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(TestNotificationSeconds <= 0)
   {
      WatcherLogError("TestNotificationSeconds must be greater than zero.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(RadarX < 0 || RadarY < 0 || RadarRowHeight < 14 || RadarFontSize < 6)
   {
      WatcherLogError("Invalid Market Radar layout parameters.");
      return INIT_PARAMETERS_INCORRECT;
   }

   const int atrHistoryBars = (UseMinSwingDistanceATR || UseCoreBreakATRBuffer)
                              ? ATRPeriod : 1;
   const int minimumLookback = atrHistoryBars + SwingLeftBars + SwingRightBars + 3;
   if(SwingLeftBars < 1 || SwingRightBars < 1 || ATRPeriod < 1
      || MinSwingDistanceATR < 0.0 || CoreBreakATRBuffer < 0.0
      || StructureLookbackBars < minimumLookback)
   {
      WatcherLogError("Invalid Price Structure parameters"
                      + " | minimum_lookback=" + IntegerToString(minimumLookback));
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!g_scanner.Initialize(SymbolsList, ScannerTimeframe,
                            MarketActivityTimeoutSeconds))
      return INIT_FAILED;

   g_notificationManager.Initialize(EnableTestNotification, TestNotificationSeconds);
   g_scanner.CopyStates(g_displayStates);
   g_priceStructureEngine.Configure(SwingLeftBars, SwingRightBars,
                                    UseMinSwingDistanceATR, MinSwingDistanceATR,
                                     ATRPeriod, StructureLookbackBars,
                                     UseCoreBreakATRBuffer, CoreBreakATRBuffer,
                                     EnableStructureAuditLog,
                                     EnableCoreBreakAuditLog);

   if(!g_priceStructureEngine.Initialize(g_displayStates))
      return INIT_FAILED;

   g_structureNotificationManager.Configure(NotifyCoreSwingChange,
                                            NotifyCoreBreakCandidate,
                                            NotifyCycleChange,
                                            EnableStructureAuditLog);

   g_structureDebugRenderer.Configure(ShowStructureDebug);
   g_structureDebugRenderer.Destroy();
   UpdateChartStructureDebug();

   g_marketRadar.Configure(ShowMarketRadar, RadarCorner, RadarX, RadarY,
                           RadarRowHeight, RadarFontSize);

   if(!g_marketRadar.Create(g_displayStates))
      return INIT_FAILED;

   ResetLastError();
   if(!EventSetTimer(ScanIntervalSeconds))
   {
      const int errorCode = GetLastError();
      g_marketRadar.Destroy();
      g_structureDebugRenderer.Destroy();
      WatcherLogError("EventSetTimer failed | error=" + IntegerToString(errorCode));
      return INIT_FAILED;
   }

   g_marketRadar.Update(g_displayStates, RadarTestMode,
                         g_scanner.Count(), g_scanner.ConfiguredCount(),
                         g_scanner.ActiveCount(),
                         ScannerTimeframe, true);

   if(IsTesterMode())
      g_testerLastBarTime = iTime(_Symbol, ScannerTimeframe, 0);

   WatcherLog("INIT", "JINPA WATCH v1.1 started | symbols="
              + IntegerToString(g_scanner.Count()) + " | timeframe="
              + WatcherTimeframeToString(ScannerTimeframe));

   return INIT_SUCCEEDED;
}

void OnTimer()
{
   if(IsTesterMode())
      return;

   g_scanner.Scan();
   g_scanner.CopyStates(g_displayStates);
   g_priceStructureEngine.Update(g_displayStates);
   UpdateChartStructureDebug();
   g_marketRadar.Update(g_displayStates, RadarTestMode,
                         g_scanner.Count(), g_scanner.ConfiguredCount(),
                         g_scanner.ActiveCount(),
                         ScannerTimeframe, true);

   g_priceStructureEngine.ConsumeEvents(g_structureEvents);
   const int structureEventCount = ArraySize(g_structureEvents);
   for(int index = 0; index < structureEventCount; index++)
      g_structureNotificationManager.Enqueue(g_structureEvents[index]);
   g_structureNotificationManager.DispatchNext();
   g_notificationManager.Process(g_scanner.Count(), g_scanner.SymbolSummary());
}

void OnTick()
{
   if(!IsTesterMode())
      return;

   const datetime currentBarTime = iTime(_Symbol, ScannerTimeframe, 0);
   if(currentBarTime <= 0 || currentBarTime <= g_testerLastBarTime)
      return;

   g_testerLastBarTime = currentBarTime;

   g_scanner.Scan();
   g_scanner.CopyStates(g_displayStates);
   g_priceStructureEngine.Update(g_displayStates);
   UpdateChartStructureDebug();
   g_marketRadar.Update(g_displayStates, RadarTestMode,
                         g_scanner.Count(), g_scanner.ConfiguredCount(),
                         g_scanner.ActiveCount(),
                         ScannerTimeframe, true);

   g_priceStructureEngine.ConsumeEvents(g_structureEvents);

   ChartRedraw(0);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      g_marketRadar.RefreshLayout();
      g_structureDebugRenderer.RefreshActiveCoreLabelPosition();
   }
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   g_structureDebugRenderer.Destroy();
   g_marketRadar.Destroy();
   WatcherLog("SYSTEM", "JINPA WATCH stopped | reason="
              + IntegerToString(reason));
}
