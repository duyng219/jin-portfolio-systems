//+------------------------------------------------------------------+
//|                                              order_executor.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_ORDER_EXECUTOR_MQH
#define JINPA_ORDER_EXECUTOR_MQH

#include <Trade/Trade.mqh>
#include "../managers/risk_manager.mqh"
#include "../managers/position_manager.mqh"
#include "ui_manager.mqh"
#include "position_helper.mqh"

enum ENUM_LOG_LEVEL
{
    LOG_NONE  = 0,  // Tắt toàn bộ log
    LOG_ERROR = 1,  // Chỉ log lỗi
    LOG_INFO  = 2,  // Log thành công + lỗi (default)
    LOG_DEBUG = 3,  // Log chi tiết: params + result
};

//+------------------------------------------------------------------+
//| SOrderExecutorParams — Config group thay vì 12 tham số rời      |
//+------------------------------------------------------------------+
struct SOrderExecutorParams
{
    ulong                  magicNumber;
    ENUM_MONEY_MANAGEMENT  moneyManagement;
    double                 minLotPerEquitySteps;
    double                 riskPercent;
    double                 fixedVolume;
    ushort                 poExpirationMinutes;
    ENUM_LOG_LEVEL         logLevel;
};

//+------------------------------------------------------------------+
//| COrderExecutor — Bridge giữa UI buttons và CTrade               |
//+------------------------------------------------------------------+
class COrderExecutor
{
private:
    CRiskManager*    riskManager;
    CPositionManager* positionManager;
    CTrade*          trade;
    CUIManager*      uiManager;

    string                 symbol;
    ulong                  magicNumber;
    ENUM_MONEY_MANAGEMENT  moneyManagement;
    double                 minLotPerEquitySteps;
    double                 riskPercent;
    double                 fixedVolume;
    ushort                 poExpirationMinutes;
    ENUM_LOG_LEVEL         logLevel;

    // Tính lot size cho một lệnh
    double CalcVolume(double slDistance, ENUM_ORDER_TYPE orderType);

    // Thời gian hết hạn pending order
    datetime GetExpiration() { return TimeCurrent() + poExpirationMinutes * 60; }

    // Tìm pending ticket theo symbol + magic + hướng (buy/sell)
    ulong GetPendingBuyTicket();
    ulong GetPendingSellTicket();

    // Đọc CTrade result và in log theo logLevel
    void LogResult(string action);

    void HandleBuyMarket(double askPrice, double stopLoss);
    void HandleSellMarket(double bidPrice, double stopLoss);
    void HandleBuyStop(double askPrice, double atrPO);
    void HandleSellStop(double bidPrice, double atrPO);
    void HandleBuyLimit(double askPrice, double atrPO);
    void HandleSellLimit(double bidPrice, double atrPO);
    void HandleCancelBuyOrder();
    void HandleCancelSellOrder();
    void HandleCloseBuyPosition();
    void HandleCloseSellPosition();

public:
    COrderExecutor();

    void Initialize(string sym, CRiskManager* rm, CPositionManager* pm,
                    CTrade* t, CUIManager* ui, SOrderExecutorParams& params);

    // atrSL  = ATR × ATRFactor   (dùng cho SL lệnh thị trường & trailing SL)
    // atrPO  = ATR × ATRFactorPO (dùng cho offset pending order)
    void HandleAllOrders(double askPrice, double bidPrice,
                         double atrSL, double atrPO, int slPoints);
};

//+------------------------------------------------------------------+
COrderExecutor::COrderExecutor()
{
    riskManager     = NULL;
    positionManager = NULL;
    trade           = NULL;
    uiManager       = NULL;
}

void COrderExecutor::Initialize(string sym, CRiskManager* rm, CPositionManager* pm,
                                 CTrade* t, CUIManager* ui, SOrderExecutorParams& params)
{
    symbol               = sym;
    riskManager          = rm;
    positionManager      = pm;
    trade                = t;
    uiManager            = ui;
    magicNumber          = params.magicNumber;
    moneyManagement      = params.moneyManagement;
    minLotPerEquitySteps = params.minLotPerEquitySteps;
    riskPercent          = params.riskPercent;
    fixedVolume          = params.fixedVolume;
    poExpirationMinutes  = params.poExpirationMinutes;
    logLevel             = params.logLevel;
}

//+------------------------------------------------------------------+
//| Đọc CTrade result và in log theo level                           |
//+------------------------------------------------------------------+
void COrderExecutor::LogResult(string action)
{
    if(logLevel == LOG_NONE) return;

    uint   retcode = trade.ResultRetcode();
    bool   success = (retcode == TRADE_RETCODE_DONE         ||
                      retcode == TRADE_RETCODE_DONE_PARTIAL ||
                      retcode == TRADE_RETCODE_PLACED        ||
                      retcode == TRADE_RETCODE_NO_CHANGES);

    if(!success)
    {
        if(logLevel >= LOG_ERROR)
            Print("[ERROR] ", action,
                  " | Code ", retcode, ": ", trade.ResultRetcodeDescription());
        return;
    }

    if(logLevel >= LOG_INFO)
        Print("[OK] ", action,
              " | #", trade.ResultOrder(),
              " vol=", DoubleToString(trade.ResultVolume(), 2),
              " price=", DoubleToString(trade.ResultPrice(), _Digits));

    if(logLevel >= LOG_DEBUG)
        Print("     ask=", trade.ResultAsk(),
              " bid=", trade.ResultBid(),
              " | ", trade.ResultComment());
}

double COrderExecutor::CalcVolume(double slDistance, ENUM_ORDER_TYPE orderType)
{
    return riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps,
                                       riskPercent, slDistance, fixedVolume, orderType);
}

ulong COrderExecutor::GetPendingBuyTicket()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderGetInteger(ORDER_MAGIC)  != (long)magicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL)  != symbol)            continue;
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP_LIMIT)
            return ticket;
    }
    return 0;
}

ulong COrderExecutor::GetPendingSellTicket()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderGetInteger(ORDER_MAGIC) != (long)magicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) != symbol)            continue;
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT)
            return ticket;
    }
    return 0;
}

//+------------------------------------------------------------------+
void COrderExecutor::HandleAllOrders(double askPrice, double bidPrice,
                                      double atrSL, double atrPO, int slPoints)
{
    if(uiManager.BuyPressed())
    {
        double sl = (slPoints > 0)
            ? MathMax(CPositionHelper::GetAverageLow(3) + slPoints * _Point, askPrice - slPoints * _Point)
            : positionManager.CalculateStopLossByATR(symbol, "BUY", atrSL);
        HandleBuyMarket(askPrice, sl);
        uiManager.ResetBuyPressed();
    }

    if(uiManager.SellPressed())
    {
        double sl = (slPoints > 0)
            ? MathMin(CPositionHelper::GetAverageHigh(3) - slPoints * _Point, bidPrice + slPoints * _Point)
            : positionManager.CalculateStopLossByATR(symbol, "SELL", atrSL);
        HandleSellMarket(bidPrice, sl);
        uiManager.ResetSellPressed();
    }

    if(uiManager.BuyStopped())  { HandleBuyStop(askPrice, atrPO);  uiManager.ResetBuyStopped();  }
    if(uiManager.SellStopped()) { HandleSellStop(bidPrice, atrPO); uiManager.ResetSellStopped(); }
    if(uiManager.BuyLimited())  { HandleBuyLimit(askPrice, atrPO); uiManager.ResetBuyLimited();  }
    if(uiManager.SellLimited()) { HandleSellLimit(bidPrice, atrPO);uiManager.ResetSellLimited(); }

    if(uiManager.BuyCancelled())  { HandleCancelBuyOrder();    uiManager.ResetBuyCancelled();  }
    if(uiManager.SellCancelled()) { HandleCancelSellOrder();   uiManager.ResetSellCancelled(); }
    if(uiManager.BuyClosed())     { HandleCloseBuyPosition();  uiManager.ResetBuyClosed();     }
    if(uiManager.SellClosed())    { HandleCloseSellPosition(); uiManager.ResetSellClosed();    }
}

//+------------------------------------------------------------------+
void COrderExecutor::HandleBuyMarket(double askPrice, double stopLoss)
{
    double volume = CalcVolume(MathAbs(askPrice - stopLoss), ORDER_TYPE_BUY);
    if(logLevel >= LOG_DEBUG)
        Print("[DEBUG] BUY MARKET | vol=", DoubleToString(volume,2),
              " ask=", askPrice, " sl=", stopLoss);
    if(volume > 0) { trade.Buy(volume, symbol, askPrice, stopLoss, 0); LogResult("BUY MARKET"); }
}

void COrderExecutor::HandleSellMarket(double bidPrice, double stopLoss)
{
    double volume = CalcVolume(MathAbs(bidPrice - stopLoss), ORDER_TYPE_SELL);
    if(logLevel >= LOG_DEBUG)
        Print("[DEBUG] SELL MARKET | vol=", DoubleToString(volume,2),
              " bid=", bidPrice, " sl=", stopLoss);
    if(volume > 0) { trade.Sell(volume, symbol, bidPrice, stopLoss, 0); LogResult("SELL MARKET"); }
}

void COrderExecutor::HandleBuyStop(double askPrice, double atrPO)
{
    double poPrice = askPrice + atrPO;
    double sl      = positionManager.CalculateStopLossByATR(symbol, "BUY", atrPO);
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_BUY);
    if(logLevel >= LOG_DEBUG)
        Print("[DEBUG] BUY STOP | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.BuyStop(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("BUY STOP"); }
}

void COrderExecutor::HandleSellStop(double bidPrice, double atrPO)
{
    double poPrice = bidPrice - atrPO;
    double sl      = positionManager.CalculateStopLossByATR(symbol, "SELL", atrPO);
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_SELL);
    if(logLevel >= LOG_DEBUG)
        Print("[DEBUG] SELL STOP | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.SellStop(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("SELL STOP"); }
}

void COrderExecutor::HandleBuyLimit(double askPrice, double atrPO)
{
    double poPrice = askPrice - atrPO;
    double sl      = positionManager.CalculateStopLossByATR(symbol, "BUY", atrPO) - 100 * _Point;
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_BUY);
    if(logLevel >= LOG_DEBUG)
        Print("[DEBUG] BUY LIMIT | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.BuyLimit(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("BUY LIMIT"); }
}

void COrderExecutor::HandleSellLimit(double bidPrice, double atrPO)
{
    double poPrice = bidPrice + atrPO;
    double sl      = positionManager.CalculateStopLossByATR(symbol, "SELL", atrPO) + 100 * _Point;
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_SELL);
    if(logLevel >= LOG_DEBUG)
        Print("[DEBUG] SELL LIMIT | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.SellLimit(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("SELL LIMIT"); }
}

void COrderExecutor::HandleCancelBuyOrder()
{
    ulong ticket = GetPendingBuyTicket();
    if(ticket > 0) { trade.OrderDelete(ticket); LogResult("CANCEL BUY #" + string(ticket)); }
}

void COrderExecutor::HandleCancelSellOrder()
{
    ulong ticket = GetPendingSellTicket();
    if(ticket > 0) { trade.OrderDelete(ticket); LogResult("CANCEL SELL #" + string(ticket)); }
}

void COrderExecutor::HandleCloseBuyPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) != symbol) continue;
        if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
        ulong ticket = PositionGetTicket(i);
        trade.PositionClose(ticket);
        LogResult("CLOSE BUY #" + string(ticket));
        break;
    }
}

void COrderExecutor::HandleCloseSellPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) != symbol) continue;
        if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
        ulong ticket = PositionGetTicket(i);
        trade.PositionClose(ticket);
        LogResult("CLOSE SELL #" + string(ticket));
        break;
    }
}

#endif
