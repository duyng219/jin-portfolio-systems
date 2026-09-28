//+------------------------------------------------------------------+
//| RuntimePanelHost.mqh                                             |
//| Selects the active v3.2 runtime panel without changing strategy  |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_RUNTIME_PANEL_HOST_MQH
#define JINPA_RUNTIME_PANEL_HOST_MQH

#include "RuntimeTypes.mqh"
#include "../_panel/panel_main.mqh"

struct SRuntimePanelConfig
{
    string                 symbol;
    ulong                  magic;
    ENUM_MONEY_MANAGEMENT  moneyManagement;
    double                 minLotPerEquitySteps;
    double                 riskPercent;
    double                 fixedVolume;
    ushort                 pendingExpirationMinutes;
    ENUM_LOG_LEVEL         logLevel;
};

class CRuntimePanelHost
{
private:
    JINPA_RUNTIME_MODE      m_mode;
    bool                    m_initialized;
    CJINPAPanel             m_livePanel;

public:
    CRuntimePanelHost();

    bool Initialize(const JINPA_RUNTIME_MODE mode,
                    const long chart,
                    const int subwindow,
                    const int x1,
                    const int y1,
                    const int x2,
                    const int y2,
                    CManualTradeController* manualTradeController,
                    const SRuntimePanelConfig &config);
    void Shutdown(const int reason);
    void SetTradingHalt(const bool halted, const string reason = "");
    void UpdateMarketData(const double atrSL,
                          const double atrPO,
                          const int slPoints,
                          const double dailyDD);
    void Tick();
    void OnChartEvent(const int id,
                      const long &lparam,
                      const double &dparam,
                      const string &sparam);
    string Status() const;
};

CRuntimePanelHost::CRuntimePanelHost() :
    m_mode(JINPA_MODE_LIVE),
    m_initialized(false)
{
}

bool CRuntimePanelHost::Initialize(const JINPA_RUNTIME_MODE mode,
                                   const long chart,
                                   const int subwindow,
                                   const int x1,
                                   const int y1,
                                   const int x2,
                                   const int y2,
                                   CManualTradeController* manualTradeController,
                                   const SRuntimePanelConfig &config)
{
    m_mode = mode;

    if(m_mode == JINPA_MODE_TEST)
    {
        m_initialized = true;
        return true;
    }

    if(manualTradeController == NULL || !manualTradeController.IsReady())
    {
        Print("[JINPA][ERROR] LIVE panel cannot start: manual trade controller is not ready.");
        return false;
    }

    if(!m_livePanel.Create(chart, "JINPA v3.2 LIVE", subwindow, x1, y1, x2, y2))
        return false;

    m_livePanel.SetDependencies(config.symbol, config.magic,
                                manualTradeController,
                                config.moneyManagement,
                                config.minLotPerEquitySteps,
                                config.riskPercent,
                                config.fixedVolume,
                                config.pendingExpirationMinutes,
                                config.logLevel);
    m_livePanel.Run();
    m_livePanel.RefreshVisuals();
    m_initialized = true;
    return true;
}

void CRuntimePanelHost::Shutdown(const int reason)
{
    if(m_initialized && m_mode == JINPA_MODE_LIVE)
        m_livePanel.Destroy(reason);
    m_initialized = false;
}

void CRuntimePanelHost::SetTradingHalt(const bool halted, const string reason)
{
    if(m_initialized && m_mode == JINPA_MODE_LIVE)
        m_livePanel.SetTradingHalt(halted, reason);
}

void CRuntimePanelHost::UpdateMarketData(const double atrSL,
                                         const double atrPO,
                                         const int slPoints,
                                         const double dailyDD)
{
    if(m_initialized && m_mode == JINPA_MODE_LIVE)
        m_livePanel.UpdateMarketData(atrSL, atrPO, slPoints, dailyDD);
}

void CRuntimePanelHost::Tick()
{
    if(m_initialized && m_mode == JINPA_MODE_LIVE)
        m_livePanel.Tick();
}

void CRuntimePanelHost::OnChartEvent(const int id,
                                     const long &lparam,
                                     const double &dparam,
                                     const string &sparam)
{
    if(m_initialized && m_mode == JINPA_MODE_LIVE)
        m_livePanel.ChartEvent(id, lparam, dparam, sparam);
}

string CRuntimePanelHost::Status() const
{
    if(!m_initialized)
        return "NOT_INITIALIZED";
    return (m_mode == JINPA_MODE_LIVE ? "LIVE_PANEL" : "TEST_PANEL_PENDING");
}

#endif // JINPA_RUNTIME_PANEL_HOST_MQH
