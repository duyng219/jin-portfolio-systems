//+------------------------------------------------------------------+
//|                                              DrawdownManager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

//+------------------------------------------------------------------+
//| CDrawdownManager Class                                           |
//+------------------------------------------------------------------+
class CDrawdownManager
{
private:
    // Daily drawdown tracking
    double maxEquityToday;
    double minEquityToday;
    datetime lastResetDaily;
    
    // Monthly drawdown tracking
    double maxEquityMonth;
    double minEquityMonth;
    int lastResetMonth;

public:
    CDrawdownManager();
    
    void UpdateDaily();
    void UpdateMonthly();
    double GetDailyPercent();
    double GetMonthlyPercent();
    void Reset();
};

//+------------------------------------------------------------------+
//| CDrawdownManager Constructor                                     |
//+------------------------------------------------------------------+
CDrawdownManager::CDrawdownManager()
{
    maxEquityToday = 0.0;
    minEquityToday = 0.0;
    lastResetDaily = 0;
    
    maxEquityMonth = 0.0;
    minEquityMonth = 0.0;
    lastResetMonth = 0;
}

//+------------------------------------------------------------------+
//| Update Daily Drawdown                                            |
//+------------------------------------------------------------------+
void CDrawdownManager::UpdateDaily()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    datetime now = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(now, timeStruct);

    if(lastResetDaily == 0 || (timeStruct.hour == 0 && timeStruct.min == 0))
    {
        maxEquityToday = currentEquity;
        minEquityToday = currentEquity;
        lastResetDaily = now;
    }

    if(currentEquity > maxEquityToday)
    {
        maxEquityToday = currentEquity;
    }
    if(currentEquity < minEquityToday)
    {
        minEquityToday = currentEquity;
    }
}

//+------------------------------------------------------------------+
//| Update Monthly Drawdown                                          |
//+------------------------------------------------------------------+
void CDrawdownManager::UpdateMonthly()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    datetime now = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(now, timeStruct);

    if(lastResetMonth == 0 || timeStruct.mon != lastResetMonth)
    {
        maxEquityMonth = currentEquity;
        minEquityMonth = currentEquity;
        lastResetMonth = timeStruct.mon;
    }

    if(currentEquity > maxEquityMonth)
    {
        maxEquityMonth = currentEquity;
    }
    if(currentEquity < minEquityMonth)
    {
        minEquityMonth = currentEquity;
    }
}

//+------------------------------------------------------------------+
//| Get Daily Drawdown Percent                                       |
//+------------------------------------------------------------------+
double CDrawdownManager::GetDailyPercent()
{
    if(maxEquityToday == 0)
    {
        return 0.0;
    }

    double drawdownPercent = ((minEquityToday - maxEquityToday) / maxEquityToday) * 100.0;
    return drawdownPercent;
}

//+------------------------------------------------------------------+
//| Get Monthly Drawdown Percent                                     |
//+------------------------------------------------------------------+
double CDrawdownManager::GetMonthlyPercent()
{
    if(maxEquityMonth == 0)
    {
        return 0.0;
    }

    double drawdownPercent = ((minEquityMonth - maxEquityMonth) / maxEquityMonth) * 100.0;
    return drawdownPercent;
}

//+------------------------------------------------------------------+
//| Reset Drawdown                                                   |
//+------------------------------------------------------------------+
void CDrawdownManager::Reset()
{
    maxEquityToday = 0.0;
    minEquityToday = 0.0;
    lastResetDaily = 0;
    
    maxEquityMonth = 0.0;
    minEquityMonth = 0.0;
    lastResetMonth = 0;
}
