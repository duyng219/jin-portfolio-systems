#ifndef JINPA_AUTO_TRADE_POLICY_MQH
#define JINPA_AUTO_TRADE_POLICY_MQH

#include "AutoTradeTypes.mqh"

// Stateless setup-identity filter. Runtime eligibility and execution remain
// outside this policy.
class CAutoTradePolicy
{
public:
    static bool IsSetupAllowed(const JINPA_AUTO_SETUP_MODE mode,
                               const string setup);
};

bool CAutoTradePolicy::IsSetupAllowed(const JINPA_AUTO_SETUP_MODE mode,
                                      const string setup)
{
    if(mode == AUTO_PULLBACK)
        return setup == "revs-ppf" || setup == "revs-pps";

    if(mode == AUTO_BREAKOUT)
        return setup == "bres-pmb" || setup == "bres-pma";

    if(mode == AUTO_RANGE_REVERSAL)
        return setup == "revs-pfb" || setup == "revs-pmr";

    if(mode == AUTO_ALL)
        return setup == "revs-ppf" || setup == "revs-pps"
               || setup == "bres-pmb" || setup == "bres-pma"
               || setup == "revs-pfb" || setup == "revs-pmr";

    return false;
}

#endif // JINPA_AUTO_TRADE_POLICY_MQH
