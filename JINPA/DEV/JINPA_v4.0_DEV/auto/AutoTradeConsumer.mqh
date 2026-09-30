#ifndef JINPA_AUTO_TRADE_CONSUMER_MQH
#define JINPA_AUTO_TRADE_CONSUMER_MQH

#include "AutoTradePolicy.mqh"
#include "../watch/core/WatcherTypes.mqh"

struct SAutoObservedEventIdentity
{
    string          symbol;
    ENUM_TIMEFRAMES timeframe;
    datetime        triggerBarTime;
    string          setup;
    string          direction;
};

// Session-local observation and deduplication only. An identity is remembered
// before policy handoff so disabled or filtered events cannot be replayed.
class CAutoTradeConsumer
{
private:
    bool                       m_observationInitialized;
    bool                       m_observationReliable;
    SAutoObservedEventIdentity m_observedIdentities[];

    bool IsValidActiveEvent(const SFinalSetupEvent &event) const;
    bool IsObserved(const SFinalSetupEvent &event) const;
    bool Remember(const SFinalSetupEvent &event);

public:
         CAutoTradeConsumer(void);
    void Reset(void);
    bool ConsumeEligibleEvent(const SFinalSetupEvent &event,
                              const bool enabled,
                              const JINPA_AUTO_SETUP_MODE mode,
                              SFinalSetupEvent &eligibleEvent);
};

CAutoTradeConsumer::CAutoTradeConsumer(void)
{
    Reset();
}

void CAutoTradeConsumer::Reset(void)
{
    m_observationInitialized = false;
    m_observationReliable = true;
    ArrayResize(m_observedIdentities, 0);
}

bool CAutoTradeConsumer::IsValidActiveEvent(
    const SFinalSetupEvent &event) const
{
    return event.setupStatus == "ACTIVE"
           && CAutoTradePolicy::IsSetupAllowed(AUTO_ALL, event.setup)
           && (event.direction == "BUY" || event.direction == "SELL")
           && event.triggerBarTime > 0;
}

bool CAutoTradeConsumer::IsObserved(const SFinalSetupEvent &event) const
{
    const int count = ArraySize(m_observedIdentities);
    for(int index = 0; index < count; index++)
    {
        if(m_observedIdentities[index].symbol == event.symbol
           && m_observedIdentities[index].timeframe == event.timeframe
           && m_observedIdentities[index].triggerBarTime == event.triggerBarTime
           && m_observedIdentities[index].setup == event.setup
           && m_observedIdentities[index].direction == event.direction)
            return true;
    }

    return false;
}

bool CAutoTradeConsumer::Remember(const SFinalSetupEvent &event)
{
    const int index = ArraySize(m_observedIdentities);
    if(ArrayResize(m_observedIdentities, index + 1) != index + 1)
    {
        m_observationReliable = false;
        return false;
    }

    m_observedIdentities[index].symbol         = event.symbol;
    m_observedIdentities[index].timeframe      = event.timeframe;
    m_observedIdentities[index].triggerBarTime = event.triggerBarTime;
    m_observedIdentities[index].setup          = event.setup;
    m_observedIdentities[index].direction      = event.direction;
    return true;
}

bool CAutoTradeConsumer::ConsumeEligibleEvent(
    const SFinalSetupEvent &event,
    const bool enabled,
    const JINPA_AUTO_SETUP_MODE mode,
    SFinalSetupEvent &eligibleEvent)
{
    ResetFinalSetupEvent(eligibleEvent);

    if(!m_observationReliable)
        return false;

    if(!m_observationInitialized)
    {
        m_observationInitialized = true;
        if(IsValidActiveEvent(event))
            Remember(event);
        return false;
    }

    if(!IsValidActiveEvent(event) || IsObserved(event))
        return false;

    // Consumption occurs before configuration filtering and before handoff.
    // A later enable/mode change therefore cannot replay this identity.
    if(!Remember(event))
        return false;
    if(!enabled || !CAutoTradePolicy::IsSetupAllowed(mode, event.setup))
        return false;

    eligibleEvent = event;
    return true;
}

#endif // JINPA_AUTO_TRADE_CONSUMER_MQH
