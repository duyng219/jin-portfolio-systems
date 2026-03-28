//+------------------------------------------------------------------+
//|                                             drawdown_manager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_DRAWDOWN_MANAGER_MQH
#define JINPA_DRAWDOWN_MANAGER_MQH

//+------------------------------------------------------------------+
//| CDrawdownManager — Theo dõi drawdown ngày và tháng               |
//+------------------------------------------------------------------+
class CDrawdownManager
{
private:
    double maxEquityToday;
    double minEquityToday;
    int    lastResetDay;    // reset khi sang ngày mới

    double maxEquityMonth;
    double minEquityMonth;
    int    lastResetMonth;  // reset khi sang tháng mới

public:
    CDrawdownManager();

    void   UpdateDaily();
    void   UpdateMonthly();
    double GetDailyPercent();
    double GetMonthlyPercent();
    void   Reset();
};

CDrawdownManager::CDrawdownManager()
{
    maxEquityToday = 0.0;
    minEquityToday = 0.0;
    lastResetDay   = 0;

    maxEquityMonth = 0.0;
    minEquityMonth = 0.0;
    lastResetMonth = 0;
}

void CDrawdownManager::UpdateDaily()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);

    // Reset một lần duy nhất khi sang ngày mới (so sánh ngày, không dùng hour/min)
    if(lastResetDay == 0 || t.day != lastResetDay)
    {
        maxEquityToday = currentEquity;
        minEquityToday = currentEquity;
        lastResetDay   = t.day;
    }

    if(currentEquity > maxEquityToday) maxEquityToday = currentEquity;
    if(currentEquity < minEquityToday) minEquityToday = currentEquity;
}

void CDrawdownManager::UpdateMonthly()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);

    if(lastResetMonth == 0 || t.mon != lastResetMonth)
    {
        maxEquityMonth = currentEquity;
        minEquityMonth = currentEquity;
        lastResetMonth = t.mon;
    }

    if(currentEquity > maxEquityMonth) maxEquityMonth = currentEquity;
    if(currentEquity < minEquityMonth) minEquityMonth = currentEquity;
}

// Trả về số âm: e.g. -2.5 nghĩa là drawdown 2.5%
double CDrawdownManager::GetDailyPercent()
{
    if(maxEquityToday == 0) return 0.0;
    return ((minEquityToday - maxEquityToday) / maxEquityToday) * 100.0;
}

double CDrawdownManager::GetMonthlyPercent()
{
    if(maxEquityMonth == 0) return 0.0;
    return ((minEquityMonth - maxEquityMonth) / maxEquityMonth) * 100.0;
}

void CDrawdownManager::Reset()
{
    maxEquityToday = 0.0;
    minEquityToday = 0.0;
    lastResetDay   = 0;

    maxEquityMonth = 0.0;
    minEquityMonth = 0.0;
    lastResetMonth = 0;
}

#endif
