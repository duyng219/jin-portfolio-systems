//+------------------------------------------------------------------+
//|                                           indicators_manager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_INDICATORS_MANAGER_MQH
#define JINPA_INDICATORS_MANAGER_MQH

#define VALUES_TO_COPY 10

//+------------------------------------------------------------------+
//| CIndicator — Base class cho tất cả indicators                    |
//+------------------------------------------------------------------+
class CIndicator
{
protected:
    int handle;

public:
    double main[];

                    CIndicator(void);
    virtual int     Init(void) { return handle; }
    void            RefreshMain(void);
};

CIndicator::CIndicator(void)
{
    ArraySetAsSeries(main, true);
}

void CIndicator::RefreshMain(void)
{
    ResetLastError();
    if(CopyBuffer(handle, 0, 0, VALUES_TO_COPY, main) < 0)
        Print("..CopyBuffer error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| CiMA — Moving Average                                            |
//+------------------------------------------------------------------+
class CiMA : public CIndicator
{
public:
    int Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pPeriod,
             int pShift, ENUM_MA_METHOD pMethod, ENUM_APPLIED_PRICE pPrice);
};

int CiMA::Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pPeriod,
               int pShift, ENUM_MA_METHOD pMethod, ENUM_APPLIED_PRICE pPrice)
{
    ResetLastError();
    handle = iMA(pSymbol, pTimeframe, pPeriod, pShift, pMethod, pPrice);
    if(handle == INVALID_HANDLE)
    {
        Print("..MA Init error: ", GetLastError());
        return -1;
    }
    return handle;
}

//+------------------------------------------------------------------+
//| CiATR — Average True Range                                       |
//+------------------------------------------------------------------+
class CiATR : public CIndicator
{
public:
    int Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pPeriod);
};

int CiATR::Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pPeriod)
{
    ResetLastError();
    handle = iATR(pSymbol, pTimeframe, pPeriod);
    if(handle == INVALID_HANDLE)
    {
        Print("..ATR Init error: ", GetLastError());
        return -1;
    }
    return handle;
}

#endif
