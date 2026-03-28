//+------------------------------------------------------------------+
//|                                                 risk_manager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_RISK_MANAGER_MQH
#define JINPA_RISK_MANAGER_MQH

enum ENUM_MONEY_MANAGEMENT
{
    MM_MIN_LOT_SIZE,         // Lot tối thiểu của symbol
    MM_MIN_LOT_PER_EQUITY,   // Lot tối thiểu × (Equity / Steps)
    MM_FIXED_LOT_SIZE,       // Lot cố định
    MM_FIXED_LOT_PER_EQUITY, // Lot cố định × (Equity / Steps)
    MM_EQUITY_RISK_PERCENT   // % rủi ro trên Equity (default)
};

//+------------------------------------------------------------------+
//| CRiskManager — Tính lot size theo nhiều phương pháp              |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    // Tính lot theo % risk: lots = (Equity×risk%) / (SL/Point × TickValue)
    double CalculateVolumeRiskPerc(string pSymbol, double pRiskPercent, double pSLInPricePoints);

public:
    double MoneyManagement(string pSymbol, ENUM_MONEY_MANAGEMENT pMM, double pMinLotPerEquitySteps,
                           double pRiskPercent, double pSLInPricePoints, double pFixedVol,
                           ENUM_ORDER_TYPE pOrderType, double pOpenPrice = 0.0);

    double VerifyVolume(string pSymbol, double pVolume);
    bool   VerifyMargin(string pSymbol, double pVolume, ENUM_ORDER_TYPE pOrderType, double pOpenPrice = 0.0);
};

double CRiskManager::MoneyManagement(string pSymbol, ENUM_MONEY_MANAGEMENT pMM, double pMinLotPerEquitySteps,
                                     double pRiskPercent, double pSLInPricePoints, double pFixedVol,
                                     ENUM_ORDER_TYPE pOrderType, double pOpenPrice = 0.0)
{
    double volume = 0;

    switch(pMM)
    {
        case MM_MIN_LOT_SIZE:
            volume = SymbolInfoDouble(pSymbol, SYMBOL_VOLUME_MIN);
            break;

        case MM_MIN_LOT_PER_EQUITY:
            if(pMinLotPerEquitySteps == 0) { Print(__FUNCTION__, "() - MinLotPerEquitySteps expected"); break; }
            volume = AccountInfoDouble(ACCOUNT_EQUITY) / pMinLotPerEquitySteps
                     * SymbolInfoDouble(pSymbol, SYMBOL_VOLUME_MIN);
            break;

        case MM_FIXED_LOT_SIZE:
            if(pFixedVol == 0) { Print(__FUNCTION__, "() - FixedVolume expected"); break; }
            volume = pFixedVol;
            break;

        case MM_FIXED_LOT_PER_EQUITY:
            if(pMinLotPerEquitySteps == 0 || pFixedVol == 0) { Print(__FUNCTION__, "() - FixedLotPerEquity params expected"); break; }
            volume = AccountInfoDouble(ACCOUNT_EQUITY) / pMinLotPerEquitySteps * pFixedVol;
            break;

        case MM_EQUITY_RISK_PERCENT:
            volume = CalculateVolumeRiskPerc(pSymbol, pRiskPercent, pSLInPricePoints);
            break;
    }

    if(volume > 0)
    {
        volume = VerifyVolume(pSymbol, volume);
        if(!VerifyMargin(pSymbol, volume, pOrderType, pOpenPrice)) volume = 0;
    }

    return volume;
}

double CRiskManager::CalculateVolumeRiskPerc(string pSymbol, double pRiskPercent, double pSLInPricePoints)
{
    if(pRiskPercent <= 0 || pSLInPricePoints <= 0)
    {
        Print(__FUNCTION__, "() - Invalid RiskPercent or SL distance");
        return 0;
    }

    double tickValue = SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_VALUE);
    if(tickValue <= 0)
    {
        Print(__FUNCTION__, "() - Invalid tickValue for: ", pSymbol);
        return 0;
    }

    double maxRisk     = pRiskPercent * 0.01 * AccountInfoDouble(ACCOUNT_EQUITY);
    double riskPerPoint = maxRisk / (pSLInPricePoints / SymbolInfoDouble(pSymbol, SYMBOL_POINT));

    if(riskPerPoint <= 0)
    {
        Print(__FUNCTION__, "() - Invalid riskPerPoint");
        return 0;
    }

    return riskPerPoint / tickValue;
}

double CRiskManager::VerifyVolume(string pSymbol, double pVolume)
{
    double minVol  = SymbolInfoDouble(pSymbol, SYMBOL_VOLUME_MIN);
    double maxVol  = SymbolInfoDouble(pSymbol, SYMBOL_VOLUME_MAX);
    double stepVol = SymbolInfoDouble(pSymbol, SYMBOL_VOLUME_STEP);

    if(pVolume < minVol)
    {
        Print("[WARN] Lot clamped to minimum ", DoubleToString(minVol, 2),
              " (calculated: ", DoubleToString(pVolume, 4), ")"
              " — actual risk exceeds target");
        return minVol;
    }
    if(pVolume > maxVol) return maxVol;
    return MathRound(pVolume / stepVol) * stepVol;
}

bool CRiskManager::VerifyMargin(string pSymbol, double pVolume, ENUM_ORDER_TYPE pOrderType, double pOpenPrice = 0.0)
{
    if(pOpenPrice == 0)
    {
        if(pOrderType == ORDER_TYPE_BUY)       pOpenPrice = SymbolInfoDouble(pSymbol, SYMBOL_ASK);
        else if(pOrderType == ORDER_TYPE_SELL) pOpenPrice = SymbolInfoDouble(pSymbol, SYMBOL_BID);
    }

    double margin;
    if(!OrderCalcMargin(pOrderType, pSymbol, pVolume, pOpenPrice, margin))
    {
        Print(__FUNCTION__, "() - Error calculating margin");
        return false;
    }

    if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
    {
        Print("No free margin to open trade");
        return false;
    }

    return true;
}

#endif
