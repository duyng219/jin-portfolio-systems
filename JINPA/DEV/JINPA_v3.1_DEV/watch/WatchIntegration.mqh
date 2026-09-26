#ifndef JINPA_WATCH_INTEGRATION_MQH
#define JINPA_WATCH_INTEGRATION_MQH

#include "structure/PriceStructureEngine.mqh"
#include "structure/StructureDebugRenderer.mqh"
#include "structure/StructureNotificationManager.mqh"
#include "state/MarketStateEngine.mqh"
#include "state/MarketStructureEngine.mqh"
#include "structure/MicroBaseRenderer.mqh"
#include "setup/PullbackSetupEngine.mqh"
#include "setup/RangeEdgeSetupEngine.mqh"
#include "setup/PmaSetupEngine.mqh"
#include "setup/SetupOutputArbitrator.mqh"
#include "setup/PullbackBaseRenderer.mqh"
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
    CMarketStateEngine m_marketStateEngine;
    CMarketStructureEngine m_marketStructureEngine;
    CMicroBaseRenderer m_microBaseRenderer;
    CPullbackSetupEngine m_pullbackSetupEngine;
    CRangeEdgeSetupEngine m_rangeEdgeSetupEngine;
    CPmaSetupEngine m_pmaSetupEngine;
    CSetupOutputArbitrator m_setupOutputArbitrator;
    CPullbackBaseRenderer m_pullbackBaseRenderer;
    string          m_lastMarketStructure;
    string          m_lastPullbackSetup;
    string          m_lastPullbackStatus;
    CMarketRadar    m_marketRadar;
    SymbolState     m_states[1];
    PriceStructureState m_structureState;
    SwingPoint      m_structureSwings[];
    BrokenCoreRecord m_brokenCores[];
    SidewayBoxRecord m_sidewayBoxes[];
    StructureEvent  m_structureEventHistory[];

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
    bool            m_watchEnableStructureNotifications;
    bool            m_enableTelegramPush;
    string          m_telegramBotToken;
    string          m_telegramChatId;
    bool            m_enableMt5Push;

    void            ResetContext(void);
    void            UpdateStructureConsumers(void);

public:
                    CWatchIntegration(void);

    bool            ConfigureStructure(const int swingLeftBars,
                                       const int swingRightBars,
                                       const int structureATRPeriod,
                                       const double coreBreakATRBuffer,
                                       const int coreBreakConfirmCloses,
                                       const bool showStructureSwings);
    void            ConfigureNotificationTransport(
                                       const bool enableTelegramPush,
                                       const string telegramBotToken,
                                       const string telegramChatId,
                                       const bool enableMt5Push);
    string          NotificationTransportStatus(void) const;
    string          NotificationConfigurationReason(void) const;
    bool            HasAvailableNotificationTransport(void) const;
    ENUM_JINPA_NOTIFICATION_ROUTE_RESULT SendStartupNotification(void);
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
    m_watchSwingLeftBars             = 3;
    m_watchSwingRightBars            = 3;
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
    m_watchEnableStructureNotifications = true;
    m_enableTelegramPush             = false;
    m_telegramBotToken               = "";
    m_telegramChatId                 = "";
    m_enableMt5Push                  = false;

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
    m_pullbackSetupEngine.ConfigureSwingRightBars(swingRightBars);
    return true;
}

void CWatchIntegration::ConfigureNotificationTransport(
    const bool enableTelegramPush,
    const string telegramBotToken,
    const string telegramChatId,
    const bool enableMt5Push)
{
    m_enableTelegramPush = enableTelegramPush;
    m_telegramBotToken = telegramBotToken;
    m_telegramChatId = telegramChatId;
    m_enableMt5Push = enableMt5Push;
    m_structureNotificationManager.ConfigureTransports(
       m_enableTelegramPush, m_telegramBotToken, m_telegramChatId,
       m_enableMt5Push);
}

string CWatchIntegration::NotificationTransportStatus(void) const
{
    return m_structureNotificationManager.TransportStatus();
}

string CWatchIntegration::NotificationConfigurationReason(void) const
{
    return m_structureNotificationManager.TransportConfigurationReason();
}

bool CWatchIntegration::HasAvailableNotificationTransport(void) const
{
    return m_structureNotificationManager.HasAvailableTransport();
}

ENUM_JINPA_NOTIFICATION_ROUTE_RESULT
CWatchIntegration::SendStartupNotification(void)
{
    if(!m_enabled)
        return JINPA_ROUTE_NO_TRANSPORT_AVAILABLE;
    return m_structureNotificationManager.SendStartupNotification(
       m_symbol, m_timeframe);
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
    m_lastMarketStructure = "UNKNOWN";
    m_lastPullbackSetup = "-";
    m_lastPullbackStatus = "NONE";

    m_states[0].symbol              = "";
    m_states[0].timeframe           = PERIOD_CURRENT;
    m_states[0].lastBarTime         = 0;
    m_states[0].lastUpdate          = 0;
    m_states[0].cycle               = "UNKNOWN";
    m_states[0].activeCorePrice     = 0.0;
    m_states[0].hasActiveCore       = false;
    m_states[0].regime              = "UNKNOWN";
    m_states[0].state               = "UNKNOWN";
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
    ArrayResize(m_structureEventHistory, 0);
    m_marketStateEngine.Reset();
    m_marketStructureEngine.Reset();
    m_pullbackSetupEngine.Reset();
    m_rangeEdgeSetupEngine.Reset();
    m_pmaSetupEngine.Reset();
}

void CWatchIntegration::UpdateStructureConsumers(void)
{
    if(!m_structureEngine.GetSnapshot(m_symbol,
                                      m_timeframe,
                                      m_structureState,
                                      m_structureSwings,
                                      m_brokenCores,
                                      m_sidewayBoxes))
        return;

    // Stage 2 already reconstructs these histories chronologically. Stage 3
    // replays them against the same closed bars and remains read-only.
    m_structureEngine.LabProbeEventHistory(m_structureEventHistory);
    MqlRates stateRates[];
    ArraySetAsSeries(stateRates, false);
    const int copied = CopyRates(m_symbol, m_timeframe, 0,
                                 m_watchStructureLookbackBars, stateRates);
    const datetime lastClosedBarTime = iTime(m_symbol, m_timeframe, 1);

    const string previousRegime = m_states[0].regime;
    const string previousState = m_states[0].state;
    const string previousStructure = m_lastMarketStructure;
    const string previousSetup = m_states[0].setup;
    const string previousSetupStatus = m_states[0].setupStatus;
    const string previousPullbackSetup = m_lastPullbackSetup;
    const string previousPullbackStatus = m_lastPullbackStatus;
    const string previousRangeSetup = m_rangeEdgeSetupEngine.SetupText();
    const string previousRangeStatus = m_rangeEdgeSetupEngine.StatusText();
    const string previousPmaSetup = m_pmaSetupEngine.SetupText();
    const string previousPmaStatus = m_pmaSetupEngine.StatusText();
    bool stateChanged = false;
    bool structureChanged = false;
    bool setupChanged = false;
    bool pullbackSetupChanged = false;
    bool rangeSetupChanged = false;
    bool pmaSetupChanged = false;
    if(copied > 0 && lastClosedBarTime > 0)
    {
       stateChanged = m_marketStateEngine.Apply(m_structureState,
                                                m_structureSwings,
                                                m_structureEventHistory,
                                                stateRates,
                                                lastClosedBarTime,
                                                m_states[0]);
       m_marketStructureEngine.Apply(m_marketStateEngine.Regime(),
                                     m_marketStateEngine.State(),
                                     m_marketStateEngine.ImpulseStartTime(),
                                     previousStructure,
                                     m_structureState,
                                     m_structureEventHistory,
                                     stateRates,
                                     lastClosedBarTime,
                                     m_watchATRPeriod,
                                     m_watchCoreBreakATRBuffer,
                                     m_states[0]);
       m_microBaseRenderer.Update(
          m_symbol, m_timeframe,
          m_marketStructureEngine.MicroBaseConfirmed(),
          m_marketStructureEngine.MicroBaseAnchorTime(),
          lastClosedBarTime,
          m_marketStructureEngine.MicroBaseHigh(),
          m_marketStructureEngine.MicroBaseLow());
       const string marketStructure = m_states[0].structure;
       SymbolState pullbackProjection = m_states[0];
       pullbackProjection.setup = m_lastPullbackSetup;
       pullbackProjection.setupStatus = m_lastPullbackStatus;
       pullbackSetupChanged = m_pullbackSetupEngine.Apply(
          previousState, m_marketStateEngine.State(),
          m_structureState, m_structureSwings, stateRates, lastClosedBarTime,
          pullbackProjection);
       m_lastPullbackSetup = pullbackProjection.setup;
       m_lastPullbackStatus = pullbackProjection.setupStatus;
       rangeSetupChanged = m_rangeEdgeSetupEngine.Apply(
          m_marketStateEngine.State(), m_structureState,
          m_structureEventHistory, lastClosedBarTime, marketStructure,
          m_marketStructureEngine.RangeEdgeSide());
       pmaSetupChanged = m_pmaSetupEngine.Apply(
          m_marketStateEngine.State(),
          m_marketStateEngine.ImpulseStartTime(),
          m_structureState.cycleState.cycle,
          m_marketStructureEngine.MicroBaseConfirmed(),
          m_marketStructureEngine.MicroBaseConsumed(),
          m_marketStructureEngine.MicroBaseImpulseStartTime(),
          m_marketStructureEngine.MicroBaseAnchorTime(),
          m_marketStructureEngine.MicroBaseHigh(),
          m_marketStructureEngine.MicroBaseLow(),
          stateRates, lastClosedBarTime);
       m_states[0].structure = pullbackProjection.structure;
       m_setupOutputArbitrator.Project(
          m_lastPullbackSetup, m_lastPullbackStatus,
          m_pmaSetupEngine.SetupText(), m_pmaSetupEngine.StatusText(),
          m_rangeEdgeSetupEngine.SetupText(),
          m_rangeEdgeSetupEngine.StatusText(), m_states[0]);
       setupChanged = previousSetup != m_states[0].setup
                      || previousSetupStatus != m_states[0].setupStatus;
       structureChanged = previousStructure != m_states[0].structure;
       m_lastMarketStructure = m_states[0].structure;

       // Notification policy consumes independent setup lifecycles. Register
       // every same-bar outcome before any Structure/Event item is enqueued so
       // semantic suppression never depends on queue insertion order.
       m_structureNotificationManager.BeginClosedBarPolicy(lastClosedBarTime);
       m_structureNotificationManager.ObserveSetupTransition(
          lastClosedBarTime, m_lastPullbackSetup, m_lastPullbackStatus,
          pullbackSetupChanged);
       m_structureNotificationManager.ObserveSetupTransition(
          lastClosedBarTime, m_rangeEdgeSetupEngine.SetupText(),
          m_rangeEdgeSetupEngine.StatusText(), rangeSetupChanged);
       m_structureNotificationManager.ObserveSetupTransition(
          lastClosedBarTime, m_pmaSetupEngine.SetupText(),
          m_pmaSetupEngine.StatusText(), pmaSetupChanged);
    }

    if(stateChanged)
    {
        WatcherLog("MARKET_STATE", m_symbol + " "
                   + WatcherTimeframeToString(m_timeframe)
                   + " | bar="
                   + TimeToString(m_states[0].lastBarTime,
                                  TIME_DATE | TIME_MINUTES)
                   + " | Regime " + previousRegime + " -> "
                   + m_states[0].regime
                   + " | State " + previousState + " -> "
                   + m_states[0].state);
    }

    if(structureChanged)
    {
        WatcherLog("MARKET_STRUCTURE", m_symbol + " "
                   + WatcherTimeframeToString(m_timeframe)
                   + " | bar="
                   + TimeToString(m_states[0].lastBarTime,
                                  TIME_DATE | TIME_MINUTES)
                   + " | Structure " + previousStructure + " -> "
                   + m_states[0].structure);

        // Bootstrap reconstruction runs while m_enabled is false. Only a
        // genuine live/tester closed-bar transition enters the Push queue.
        if(m_enabled)
            m_structureNotificationManager.EnqueueMarketStructureTransition(
               m_symbol, m_timeframe, lastClosedBarTime,
               previousStructure, m_states[0].structure,
               m_states[0].cycle, m_states[0].state);
    }

    if(setupChanged)
    {
        string transition = m_states[0].setup;
        if(previousSetup != m_states[0].setup)
            transition = previousSetup + " -> " + m_states[0].setup;
        else
            transition += " | " + previousSetupStatus + " -> "
                          + m_states[0].setupStatus;
        WatcherLog("SETUP", m_symbol + " "
                   + WatcherTimeframeToString(m_timeframe)
                   + " | bar="
                   + TimeToString(m_states[0].lastBarTime,
                                  TIME_DATE | TIME_MINUTES)
                   + " | " + transition
                   + " | status=" + m_states[0].setupStatus);

    }

    // Setup notifications consume each owning engine's internal transition,
    // independent from the single-output Radar projection.
    if(pullbackSetupChanged && m_enabled)
        m_structureNotificationManager.EnqueueSetupTransition(
           m_symbol, m_timeframe, lastClosedBarTime,
           previousPullbackSetup, previousPullbackStatus,
           m_lastPullbackSetup, m_lastPullbackStatus,
           m_states[0].cycle, m_states[0].state,
           m_states[0].structure,
           m_pullbackSetupEngine.BaseHigh(),
           m_pullbackSetupEngine.BaseLow(),
           m_pullbackSetupEngine.CandidateSwingTime());

    if(rangeSetupChanged && m_enabled)
        m_structureNotificationManager.EnqueueSetupTransition(
           m_symbol, m_timeframe, lastClosedBarTime,
           previousRangeSetup, previousRangeStatus,
           m_rangeEdgeSetupEngine.SetupText(),
           m_rangeEdgeSetupEngine.StatusText(),
           m_states[0].cycle, m_states[0].state,
           m_states[0].structure, 0.0, 0.0);

    if(pmaSetupChanged && m_enabled)
        m_structureNotificationManager.EnqueueSetupTransition(
           m_symbol, m_timeframe, lastClosedBarTime,
           previousPmaSetup, previousPmaStatus,
           m_pmaSetupEngine.SetupText(), m_pmaSetupEngine.StatusText(),
           m_states[0].cycle, m_states[0].state,
           m_states[0].structure,
           m_pmaSetupEngine.BaseHigh(), m_pmaSetupEngine.BaseLow(),
           m_pmaSetupEngine.BaseTime());

    // Rendering is a separate read-only consumer of the same Stage 2 snapshot.
    m_pullbackBaseRenderer.Update(
       m_symbol, m_timeframe, m_lastPullbackSetup, m_lastPullbackStatus,
       m_pullbackSetupEngine.CandidateSwingTime(),
       m_pullbackSetupEngine.BaseTime(), lastClosedBarTime,
       m_pullbackSetupEngine.BaseHigh(), m_pullbackSetupEngine.BaseLow());
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
        m_watchEnableStructureNotifications,
        m_watchEnableStructureAuditLog);
    m_structureNotificationManager.ConfigureTransports(
        m_enableTelegramPush, m_telegramBotToken, m_telegramChatId,
        m_enableMt5Push);

    m_structureRenderer.Configure(m_watchShowStructureSwings);
    m_structureRenderer.Destroy();
    UpdateStructureConsumers();

    // Integrated WATCH owns one current-chart row. Keep the latest standalone
    // visual identity while anchoring it away from JINPA's top-left controls.
    m_marketRadar.Configure(true, CORNER_RIGHT_LOWER, 15, 15, 15, 8);
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
    UpdateStructureConsumers();
    m_marketRadar.Update(m_states, true);

    StructureEvent structureEvents[];
    m_structureEngine.ConsumeEvents(structureEvents);

    // Tester follows the same eligibility/queue path. DispatchNext owns the
    // final MQL_TESTER guard and therefore never calls the real Push API.
    const int eventCount = ArraySize(structureEvents);
    for(int index = 0; index < eventCount; index++)
        m_structureNotificationManager.Enqueue(structureEvents[index]);

    // Preserve the existing bound: at most one queued item per new-bar cycle.
    // Additional eligible items remain FIFO queued; none are silently dropped.
    m_structureNotificationManager.DispatchNext();

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
    m_pullbackBaseRenderer.Destroy();
    m_microBaseRenderer.Destroy();
    m_structureRenderer.Destroy();
    ResetContext();
}

#endif
