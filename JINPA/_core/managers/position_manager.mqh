//+------------------------------------------------------------------+
//|                                              position_manager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_POSITION_MANAGER_MQH
#define JINPA_POSITION_MANAGER_MQH

#include "../infrastructure/position_helper.mqh"

enum ENUM_TSL_MODE
{
    TSL_CONTINUOUS,       // Kéo SL liên tục mỗi tick (mặc định)
    TSL_BREAKEVEN_FIRST,  // Chỉ bật sau khi lãi đủ X ATR
    TSL_STEP,             // Kéo SL theo bước, mỗi bước tối thiểu X ATR
};

//+------------------------------------------------------------------+
//| CPositionManager — Tính SL/TP và quản lý Trailing Stop          |
//+------------------------------------------------------------------+
class CPositionManager
{
public:
    MqlTradeRequest request;
    MqlTradeResult  result;

                    CPositionManager(void);

    // Tính SL từ khoảng cách ATR đã tính sẵn (pATRDistance = ATR × Factor)
    double          CalculateStopLossByATR(string pSymbol, string pEntrySignal, double pATRDistance);

    // Kéo SL theo ATR mỗi tick
    // atrValue      = ATR raw (ATR.main[1])
    // pATRFactor    = hệ số khoảng cách SL
    // tslMode       = chế độ trailing
    // activationATR = (BREAKEVEN_FIRST) số ATR lãi tối thiểu để kích hoạt
    // stepATR       = (STEP) số ATR tối thiểu mỗi lần dịch SL
    void            TrailingStopLossByATR(string pSymbol, ulong pMagic,
                                          double atrValue, double pATRFactor,
                                          ENUM_TSL_MODE tslMode       = TSL_CONTINUOUS,
                                          double        activationATR = 1.0,
                                          double        stepATR       = 1.0);
};

CPositionManager::CPositionManager(void)
{
    ZeroMemory(request);
    ZeroMemory(result);
}

double CPositionManager::CalculateStopLossByATR(string pSymbol, string pEntrySignal, double pATRDistance)
{
    double tickSize = SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_SIZE);
    double stopLoss = 0.0;

    if(pEntrySignal == "BUY")
        stopLoss = SymbolInfoDouble(pSymbol, SYMBOL_ASK) - pATRDistance;
    else if(pEntrySignal == "SELL")
        stopLoss = SymbolInfoDouble(pSymbol, SYMBOL_BID) + pATRDistance;

    return round(stopLoss / tickSize) * tickSize;
}

void CPositionManager::TrailingStopLossByATR(string pSymbol, ulong pMagic,
                                              double atrValue, double pATRFactor,
                                              ENUM_TSL_MODE tslMode,
                                              double        activationATR,
                                              double        stepATR)
{
    double distance       = atrValue * pATRFactor;   // khoảng cách SL so với giá
    double activationDist = atrValue * activationATR; // lãi tối thiểu để kích hoạt (BREAKEVEN)
    double stepDist       = atrValue * stepATR;       // bước dịch tối thiểu (STEP)

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ZeroMemory(request);
        ZeroMemory(result);

        ulong  ticket    = PositionGetTicket(i);
        PositionSelectByTicket(ticket);

        if(PositionGetString(POSITION_SYMBOL)  != pSymbol)        continue;
        if(PositionGetInteger(POSITION_MAGIC)  != (long)pMagic)   continue;

        ulong  posType   = PositionGetInteger(POSITION_TYPE);
        double currentSL = PositionGetDouble(POSITION_SL);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double tickSize  = SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_SIZE);
        double newSL     = 0.0;

        if(posType == POSITION_TYPE_BUY)
        {
            double bid = SymbolInfoDouble(pSymbol, SYMBOL_BID);

            // BREAKEVEN_FIRST: chỉ kích hoạt khi lãi >= activationDist
            if(tslMode == TSL_BREAKEVEN_FIRST && (bid - openPrice) < activationDist)
                continue;

            newSL = round((bid - distance) / tickSize) * tickSize;
            newSL = AdjustBelowStopLevel(pSymbol, bid, newSL);

            if(newSL <= currentSL) continue;

            // STEP: chỉ dịch khi newSL tiến thêm ít nhất stepDist so với currentSL
            if(tslMode == TSL_STEP && newSL < currentSL + stepDist) continue;
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            double ask = SymbolInfoDouble(pSymbol, SYMBOL_ASK);

            // BREAKEVEN_FIRST: chỉ kích hoạt khi lãi >= activationDist
            if(tslMode == TSL_BREAKEVEN_FIRST && (openPrice - ask) < activationDist)
                continue;

            newSL = round((ask + distance) / tickSize) * tickSize;
            newSL = AdjustAboveStopLevel(pSymbol, ask, newSL);

            if(newSL >= currentSL) continue;

            // STEP: chỉ dịch khi newSL lùi thêm ít nhất stepDist so với currentSL
            if(tslMode == TSL_STEP && newSL > currentSL - stepDist) continue;
        }

        request.action   = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.sl       = newSL;
        request.tp       = PositionGetDouble(POSITION_TP);
        request.comment  = "ATR TSL | " + pSymbol + " | " + string(pMagic);

        string direction = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
        if(!OrderSend(request, result))
        {
            Print("[ERROR] TSL ", direction, " #", ticket,
                  " | Code ", result.retcode, ": ", result.comment);
        }
        else
        {
            Print("[TSL] ", direction, " #", ticket, " ", pSymbol,
                  " | SL: ", DoubleToString(currentSL, _Digits),
                  " → ",     DoubleToString(newSL,     _Digits));
        }
    }
}

#endif
