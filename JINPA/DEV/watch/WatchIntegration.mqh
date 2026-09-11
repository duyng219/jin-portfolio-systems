#ifndef JINPA_WATCH_INTEGRATION_MQH
#define JINPA_WATCH_INTEGRATION_MQH

#include "structure/PriceStructureEngine.mqh"
#include "structure/StructureDebugRenderer.mqh"
#include "structure/StructureNotificationManager.mqh"
#include "ui/MarketRadar.mqh"

// Read-only boundary for the future single-symbol WATCH engine.
// This class must remain independent from all JINPA trading components.
class CWatchIntegration
{
private:
    string          m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    bool            m_enabled;
    datetime        m_lastBarTime;
    CPriceStructureEngine m_structureEngine;
    CStructureDebugRenderer m_structureRenderer;
    CStructureNotificationManager m_structureNotificationManager;
    CMarketRadar    m_marketRadar;
    SymbolState     m_states[1];
    PriceStructureState m_structureState;
    SwingPoint      m_structureSwings[];
    BrokenCoreRecord m_brokenCores[];
    SidewayBoxRecord m_sidewayBoxes[];

    // WATCH v1.1 structure defaults. Kept instance-scoped to avoid collisions
    // with JINPA trading inputs such as ATRPeriod.
    int             m_watchSwingLeftBars;
    int             m_watchSwingRightBars;
    bool            m_watchUseMinSwingDistanceATR;
    double          m_watchMinSwingDistanceATR;
    int             m_watchATRPeriod;
    int             m_watchStructureLookbackBars;
    bool            m_watchUseCoreBreakATRBuffer;
    double          m_watchCoreBreakATRBuffer;
    int             m_watchCoreBreakConfirmCloses;
    bool            m_watchEnableStructureAuditLog;
    bool            m_watchEnableCoreBreakAuditLog;
    bool            m_watchShowStructureSwings;
    bool            m_watchNotifyCoreSwingChange;
    bool            m_watchNotifyCoreBreakCandidate;
    bool            m_watchNotifyCycleChange;

    void            ResetContext(void);
    void            UpdateStructureRenderer(void);

public:
                    CWatchIntegration(void);

    bool            ConfigureStructure(const int swingLeftBars,
                                       const int swingRightBars,
                                       const int structureATRPeriod,
                                       const double coreBreakATRBuffer,
                                       const int coreBreakConfirmCloses,
                                       const bool showStructureSwings);
    void            GetStructureConfiguration(int &swingLeftBars,
                                              int &swingRightBars,
                                              int &structureATRPeriod,
                                              double &coreBreakATRBuffer,
                                              int &coreBreakConfirmCloses,
                                              bool &showStructureSwings) const;
    bool            Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe);
    void            ProcessTick(void);
    void            OnChartChange(void);
    void            Shutdown(void);
    bool            IsEnabled(void) const { return m_enabled; }
};

CWatchIntegration::CWatchIntegration(void)
{
    m_watchSwingLeftBars             = 5;
    m_watchSwingRightBars            = 5;
    m_watchUseMinSwingDistanceATR    = true;
    m_watchMinSwingDistanceATR       = 1.2;
    m_watchATRPeriod                 = 14;
    m_watchStructureLookbackBars     = 500;
    m_watchUseCoreBreakATRBuffer     = true;
    m_watchCoreBreakATRBuffer        = 0.10;
    m_watchCoreBreakConfirmCloses    = 2;
    m_watchEnableStructureAuditLog   = false;
    m_watchEnableCoreBreakAuditLog   = false;
    m_watchShowStructureSwings       = true;
    m_watchNotifyCoreSwingChange     = true;
    m_watchNotifyCoreBreakCandidate  = true;
    m_watchNotifyCycleChange         = true;

    ResetContext();
}

bool CWatchIntegration::ConfigureStructure(const int swingLeftBars,
                                           const int swingRightBars,
                                           const int structureATRPeriod,
                                           const double coreBreakATRBuffer,
                                           const int coreBreakConfirmCloses,
                                           const bool showStructureSwings)
{
    if(swingLeftBars < 1 || swingRightBars < 1
       || structureATRPeriod < 1 || coreBreakATRBuffer < 0.0
       || coreBreakConfirmCloses < 1)
        return false;

    m_watchSwingLeftBars          = swingLeftBars;
    m_watchSwingRightBars         = swingRightBars;
    m_watchATRPeriod              = structureATRPeriod;
    m_watchCoreBreakATRBuffer     = coreBreakATRBuffer;
    m_watchCoreBreakConfirmCloses = coreBreakConfirmCloses;
    m_watchShowStructureSwings    = showStructureSwings;
    return true;
}

void CWatchIntegration::GetStructureConfiguration(
    int &swingLeftBars,
    int &swingRightBars,
    int &structureATRPeriod,
    double &coreBreakATRBuffer,
    int &coreBreakConfirmCloses,
    bool &showStructureSwings) const
{
    swingLeftBars = m_watchSwingLeftBars;
    swingRightBars = m_watchSwingRightBars;
    structureATRPeriod = m_watchATRPeriod;
    coreBreakATRBuffer = m_watchCoreBreakATRBuffer;
    coreBreakConfirmCloses = m_watchCoreBreakConfirmCloses;
    showStructureSwings = m_watchShowStructureSwings;
}

void CWatchIntegration::ResetContext(void)
{
    m_symbol      = "";
    m_timeframe   = PERIOD_CURRENT;
    m_enabled     = false;
    m_lastBarTime = 0;

    m_states[0].symbol              = "";
    m_states[0].timeframe           = PERIOD_CURRENT;
    m_states[0].lastBarTime         = 0;
    m_states[0].lastUpdate          = 0;
    m_states[0].cycle               = "UNKNOWN";
    m_states[0].activeCorePrice     = 0.0;
    m_states[0].hasActiveCore       = false;
    m_states[0].regime              = "UNKNOWN";
    m_states[0].phase               = "UNKNOWN";
    m_states[0].structure           = "UNKNOWN";
    m_states[0].setup               = "-";
    m_states[0].setupStatus         = "NONE";
    m_states[0].lastEvent           = "WAITING";
    m_states[0].lastEventTime       = 0;
    m_states[0].isReady             = false;
    m_states[0].isActive            = false;
    m_states[0].lastTickTime        = 0;
    m_states[0].activityInitialized = false;

    ResetPriceStructureState(m_structureState);
    ArrayResize(m_structureSwings, 0);
    ArrayResize(m_brokenCores, 0);
    ArrayResize(m_sidewayBoxes, 0);
}

void CWatchIntegration::UpdateStructureRenderer(void)
{
    if(!m_structureEngine.GetSnapshot(m_symbol,
                                      m_timeframe,
                                      m_structureState,
                                      m_structureSwings,
                                      m_brokenCores,
                                      m_sidewayBoxes))
        return;

    // Rendering is a read-only consumer of the Engine snapshot. Individual
    // chart-object failures are logged by the renderer and remain non-fatal.
    m_structureRenderer.Update(m_structureState,
                               m_structureSwings,
                               m_brokenCores,
                               m_sidewayBoxes);
}

bool CWatchIntegration::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe)
{
    Shutdown();

    if(symbol == "" || timeframe == PERIOD_CURRENT)
        return false;

    const int atrHistoryBars = (m_watchUseMinSwingDistanceATR
                                || m_watchUseCoreBreakATRBuffer)
                               ? m_watchATRPeriod : 1;
    const int minimumLookback = atrHistoryBars + m_watchSwingLeftBars
                                + m_watchSwingRightBars + 3;
    if(m_watchSwingLeftBars < 1 || m_watchSwingRightBars < 1
       || m_watchATRPeriod < 1 || m_watchMinSwingDistanceATR < 0.0
       || m_watchCoreBreakATRBuffer < 0.0
       || m_watchCoreBreakConfirmCloses < 1
       || m_watchStructureLookbackBars < minimumLookback)
        return false;

    m_symbol      = symbol;
    m_timeframe   = timeframe;
    m_lastBarTime = iTime(m_symbol, m_timeframe, 0);
    m_states[0].symbol      = m_symbol;
    m_states[0].timeframe   = m_timeframe;
    m_states[0].lastBarTime = m_lastBarTime;
    m_states[0].isReady     = m_lastBarTime > 0;

    m_structureEngine.Configure(m_watchSwingLeftBars,
                                m_watchSwingRightBars,
                                m_watchUseMinSwingDistanceATR,
                                m_watchMinSwingDistanceATR,
                                m_watchATRPeriod,
                                m_watchStructureLookbackBars,
                                m_watchUseCoreBreakATRBuffer,
                                m_watchCoreBreakATRBuffer,
                                m_watchCoreBreakConfirmCloses,
                                m_watchEnableStructureAuditLog,
                                m_watchEnableCoreBreakAuditLog);

    // Initialize keeps an unready context available for the Engine's existing
    // history retry path; temporary CopyRates failure is not fatal to JINPA.
    if(!m_structureEngine.Initialize(m_states))
    {
        Shutdown();
        return false;
    }

    m_structureNotificationManager.Configure(
        m_watchNotifyCoreSwingChange,
        m_watchNotifyCoreBreakCandidate,
        m_watchNotifyCycleChange,
        m_watchEnableStructureAuditLog);

    m_structureRenderer.Configure(m_watchShowStructureSwings);
    m_structureRenderer.Destroy();
    UpdateStructureRenderer();

    // Integrated WATCH owns one current-chart row. Keep the latest standalone
    // visual identity while anchoring it away from JINPA's top-left controls.
    m_marketRadar.Configure(true, CORNER_RIGHT_LOWER, 15, 20, 20, 9);
    if(!m_marketRadar.Create(m_states))
    {
        Shutdown();
        return false;
    }

    m_enabled = true;
    m_marketRadar.Update(m_states, true);
    return true;
}

void CWatchIntegration::ProcessTick(void)
{
    if(!m_enabled)
        return;

    // Template application in Visual Tester may not emit a usable chart
    // event. This is a cheap object-health check; it rebuilds only if needed.
    m_marketRadar.RecoverIfNeeded(m_states, true);

    const datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
    if(currentBarTime <= 0 || currentBarTime <= m_lastBarTime)
        return;

    m_lastBarTime = currentBarTime;
    m_states[0].lastBarTime = currentBarTime;
    m_states[0].isReady = true;

    m_structureEngine.Update(m_states);
    UpdateStructureRenderer();
    m_marketRadar.Update(m_states, true);

    StructureEvent structureEvents[];
    m_structureEngine.ConsumeEvents(structureEvents);

    // Strategy Tester must preserve the validated consume/discard behavior and
    // must never enqueue or dispatch MT5 Push notifications.
    if(!(bool)MQLInfoInteger(MQL_TESTER))
    {
        const int eventCount = ArraySize(structureEvents);
        for(int index = 0; index < eventCount; index++)
            m_structureNotificationManager.Enqueue(structureEvents[index]);

        // Standalone WATCH dispatches at most one item per timer cycle. With no
        // timer in JINPA, preserve that bound once per live new-bar cycle.
        m_structureNotificationManager.DispatchNext();
    }

    ArrayResize(structureEvents, 0);
}

void CWatchIntegration::OnChartChange(void)
{
    if(!m_enabled)
        return;

    m_marketRadar.RecoverIfNeeded(m_states, true);
    m_marketRadar.RefreshLayout();
    m_structureRenderer.RefreshActiveCoreLabelPosition();
}

void CWatchIntegration::Shutdown(void)
{
    m_marketRadar.Destroy();
    m_structureRenderer.Destroy();
    ResetContext();
}

#endif
