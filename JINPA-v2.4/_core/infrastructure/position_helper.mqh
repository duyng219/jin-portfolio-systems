//+------------------------------------------------------------------+
//|                                             position_helper.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_POSITION_HELPER_MQH
#define JINPA_POSITION_HELPER_MQH

//+------------------------------------------------------------------+
//| CPositionHelper — Static helpers, không cần khởi tạo            |
//+------------------------------------------------------------------+
class CPositionHelper
{
public:
    static int    CountBuyPositions(string symbol);
    static int    CountSellPositions(string symbol);
    static double GetAverageHigh(int periods = 3);
    static double GetAverageLow(int periods = 3);
};

int CPositionHelper::CountBuyPositions(string symbol)
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
        if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            count++;
    return count;
}

int CPositionHelper::CountSellPositions(string symbol)
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
        if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            count++;
    return count;
}

// Dùng iHigh/iLow built-in thay vì tạo CBar mới mỗi lần gọi
double CPositionHelper::GetAverageHigh(int periods = 3)
{
    double sum = 0.0;
    for(int i = 1; i <= periods; i++)
        sum += iHigh(_Symbol, PERIOD_CURRENT, i);
    return sum / periods;
}

double CPositionHelper::GetAverageLow(int periods = 3)
{
    double sum = 0.0;
    for(int i = 1; i <= periods; i++)
        sum += iLow(_Symbol, PERIOD_CURRENT, i);
    return sum / periods;
}

//+------------------------------------------------------------------+
//| Stop Level Helpers — đảm bảo SL/TP không vi phạm broker limits  |
//+------------------------------------------------------------------+

// Điều chỉnh giá lên trên mức stop level tối thiểu (dùng cho SELL SL, BUY TP)
double AdjustAboveStopLevel(string pSymbol, double pCurrentPrice, double pPriceToAdjust, int pPointsToAdd = 10)
{
    double adjustedPrice = pPriceToAdjust;
    double point         = SymbolInfoDouble(pSymbol, SYMBOL_POINT);
    long   stopsLevel    = SymbolInfoInteger(pSymbol, SYMBOL_TRADE_STOPS_LEVEL);

    if(stopsLevel > 0)
    {
        double minDistance = (stopsLevel + pPointsToAdd) * point;
        if(adjustedPrice <= pCurrentPrice + minDistance)
        {
            adjustedPrice = pCurrentPrice + minDistance;
            Print("..Price adjusted above stop level to ", adjustedPrice);
        }
    }

    return adjustedPrice;
}

// Điều chỉnh giá xuống dưới mức stop level tối thiểu (dùng cho BUY SL, SELL TP)
double AdjustBelowStopLevel(string pSymbol, double pCurrentPrice, double pPriceToAdjust, int pPointsToAdd = 10)
{
    double adjustedPrice = pPriceToAdjust;
    double point         = SymbolInfoDouble(pSymbol, SYMBOL_POINT);
    long   stopsLevel    = SymbolInfoInteger(pSymbol, SYMBOL_TRADE_STOPS_LEVEL);

    if(stopsLevel > 0)
    {
        double minDistance = (stopsLevel + pPointsToAdd) * point;
        if(adjustedPrice >= pCurrentPrice - minDistance)
        {
            adjustedPrice = pCurrentPrice - minDistance;
            Print("..Price adjusted below stop level to ", adjustedPrice);
        }
    }

    return adjustedPrice;
}

#endif
