//+------------------------------------------------------------------+
//| TestCommentResolver.mqh                                          |
//| Read-only WATCH-aware Comment tagging for manual TEST orders     |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_TEST_COMMENT_RESOLVER_MQH
#define JINPA_TEST_COMMENT_RESOLVER_MQH

#include "../watch/WatchIntegration.mqh"

class CTestCommentResolver
{
private:
    CWatchIntegration* m_watch;

    string RequestedDirection(const ENUM_ORDER_TYPE orderType) const;
    bool   IsValidSetup(const string setup) const;
    bool   IsUsableStatus(const string status) const;
    string CompatibleCandidate(const string setup,
                               const string status,
                               const string direction,
                               const string requestedDirection) const;

public:
    CTestCommentResolver();
    bool   Initialize(CWatchIntegration* watch);
    string Resolve(const ENUM_ORDER_TYPE orderType) const;
    string ResolveSnapshot(const WatchSetupSnapshot &snapshot,
                           const ENUM_ORDER_TYPE orderType) const;
};

CTestCommentResolver::CTestCommentResolver() : m_watch(NULL)
{
}

bool CTestCommentResolver::Initialize(CWatchIntegration* watch)
{
    m_watch = watch;
    return (m_watch != NULL);
}

string CTestCommentResolver::RequestedDirection(const ENUM_ORDER_TYPE orderType) const
{
    if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP
       || orderType == ORDER_TYPE_BUY_LIMIT)
        return "BUY";
    if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP
       || orderType == ORDER_TYPE_SELL_LIMIT)
        return "SELL";
    return "NONE";
}

bool CTestCommentResolver::IsValidSetup(const string setup) const
{
    return setup == "bres-pma" || setup == "bres-pmb"
           || setup == "revs-pfb" || setup == "revs-pmr"
           || setup == "revs-ppf" || setup == "revs-pps";
}

bool CTestCommentResolver::IsUsableStatus(const string status) const
{
    return status == "WATCH" || status == "READY" || status == "ACTIVE";
}

string CTestCommentResolver::CompatibleCandidate(
    const string setup,
    const string status,
    const string direction,
    const string requestedDirection) const
{
    if(!IsValidSetup(setup) || !IsUsableStatus(status))
        return "";
    if(direction == "NONE" || direction != requestedDirection)
        return "";
    return setup;
}

string CTestCommentResolver::Resolve(const ENUM_ORDER_TYPE orderType) const
{
    if(m_watch == NULL)
        return "test-none";

    WatchSetupSnapshot snapshot;
    if(!m_watch.GetSetupSnapshot(snapshot))
        return "test-none";
    return ResolveSnapshot(snapshot, orderType);
}

string CTestCommentResolver::ResolveSnapshot(const WatchSetupSnapshot &snapshot,
                                             const ENUM_ORDER_TYPE orderType) const
{
    const string requestedDirection = RequestedDirection(orderType);
    if(!snapshot.isReady || requestedDirection == "NONE")
        return "test-none";

    // Radar/final projection is the first authority, regardless of whether
    // the Radar object is visible on the chart.
    string resolved = CompatibleCandidate(snapshot.finalSetup,
                                          snapshot.finalStatus,
                                          snapshot.finalDirection,
                                          requestedDirection);
    if(resolved != "")
        return resolved;

    // If final output points the other way, inspect the already-authoritative
    // internal owners using the same status priority as the Radar arbitrator.
    const string statuses[3] = {"ACTIVE", "READY", "WATCH"};
    for(int statusIndex = 0; statusIndex < 3; statusIndex++)
    {
        const string wantedStatus = statuses[statusIndex];
        if(wantedStatus == "ACTIVE")
        {
            if(snapshot.pullbackStatus == wantedStatus)
            {
                resolved = CompatibleCandidate(snapshot.pullbackSetup,
                                               snapshot.pullbackStatus,
                                               snapshot.pullbackDirection,
                                               requestedDirection);
                if(resolved != "") return resolved;
            }
            if(snapshot.rangeStatus == wantedStatus)
            {
                resolved = CompatibleCandidate(snapshot.rangeSetup,
                                               snapshot.rangeStatus,
                                               snapshot.rangeDirection,
                                               requestedDirection);
                if(resolved != "") return resolved;
            }
            if(snapshot.pmaStatus == wantedStatus)
            {
                resolved = CompatibleCandidate(snapshot.pmaSetup,
                                               snapshot.pmaStatus,
                                               snapshot.pmaDirection,
                                               requestedDirection);
                if(resolved != "") return resolved;
            }
            continue;
        }

        if(snapshot.pmaStatus == wantedStatus)
        {
            resolved = CompatibleCandidate(snapshot.pmaSetup,
                                           snapshot.pmaStatus,
                                           snapshot.pmaDirection,
                                           requestedDirection);
            if(resolved != "") return resolved;
        }
        if(snapshot.pullbackStatus == wantedStatus)
        {
            resolved = CompatibleCandidate(snapshot.pullbackSetup,
                                           snapshot.pullbackStatus,
                                           snapshot.pullbackDirection,
                                           requestedDirection);
            if(resolved != "") return resolved;
        }
        if(snapshot.rangeStatus == wantedStatus)
        {
            resolved = CompatibleCandidate(snapshot.rangeSetup,
                                           snapshot.rangeStatus,
                                           snapshot.rangeDirection,
                                           requestedDirection);
            if(resolved != "") return resolved;
        }
    }

    // Lightweight fallbacks reuse existing WATCH facts only.  No setup
    // transition or price-pattern rule is recreated here.
    const string cycleDirection = snapshot.cycle == "BULL"
                                  ? "BUY"
                                  : (snapshot.cycle == "BEAR" ? "SELL" : "NONE");
    if(snapshot.state == "IMPULSE" && snapshot.microBaseConfirmed
       && cycleDirection == requestedDirection)
        return "bres-pma";

    if(snapshot.structure == "LEG 1"
       && (snapshot.state == "CORRECTION" || snapshot.state == "COMPRESSION")
       && cycleDirection == requestedDirection)
        return "revs-pps";

    if(snapshot.rangeSetup == "edge-mix" && snapshot.rangeStatus == "WATCH"
       && snapshot.rangeDirection == requestedDirection)
        return "bres-pmb";

    return "test-none";
}

#endif // JINPA_TEST_COMMENT_RESOLVER_MQH
