//+------------------------------------------------------------------+
//|                                              PositionHelper.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

#include "../managers/bar_manager.mqh"


//+------------------------------------------------------------------+
//| CPositionHelper Class - Static Helper Functions                  |
//+------------------------------------------------------------------+
class CPositionHelper
{
public:
    static int CountBuyPositions(string symbol);
    static int CountSellPositions(string symbol);
    static double GetAverageHigh(int periods = 3);
    static double GetAverageLow(int periods = 3);
};

//+------------------------------------------------------------------+
//| Count Buy Positions                                              |
//+------------------------------------------------------------------+
int CPositionHelper::CountBuyPositions(string symbol)
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Count Sell Positions                                             |
//+------------------------------------------------------------------+
int CPositionHelper::CountSellPositions(string symbol)
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get Average High Price                                           |
//+------------------------------------------------------------------+
double CPositionHelper::GetAverageHigh(int periods = 3)
{
    CBar bar;
    bar.Refresh(_Symbol, PERIOD_CURRENT, periods);
    
    double sum = 0.0;
    for(int i = 1; i <= periods; i++)
    {
        sum += bar.High(i);
    }
    
    return sum / periods;
}

//+------------------------------------------------------------------+
//| Get Average Low Price                                            |
//+------------------------------------------------------------------+
double CPositionHelper::GetAverageLow(int periods = 3)
{
    CBar bar;
    bar.Refresh(_Symbol, PERIOD_CURRENT, periods);
    
    double sum = 0.0;
    for(int i = 1; i <= periods; i++)
    {
        sum += bar.Low(i);
    }
    
    return sum / periods;
}
