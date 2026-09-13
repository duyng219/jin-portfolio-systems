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
    double CalcVolume(double slDistance, ENUM_ORDER_TYPE orderType, double openPrice = 0.0);

    // Thời gian hết hạn pending order
    datetime GetExpiration() { return TimeCurrent() + poExpirationMinutes * 60; }

    // Tìm pending ticket theo symbol + magic + hướng (buy/sell)
    ulong GetPendingBuyTicket();
    ulong GetPendingSellTicket();

    // Đọc CTrade result và in log theo logLevel
    void LogResult(string action, double stopLoss = 0.0,
                   ulong targetTicket = 0, double targetVolume = 0.0,
                   bool includePrice = true, bool logSuccess = true);

    void HandleBuyMarket(double askPrice, double stopLoss);
    void HandleSellMarket(double bidPrice, double stopLoss);
    void HandleBuyStop(double askPrice, double atrPO);
    void HandleSellStop(double bidPrice, double atrPO);
    void HandleBuyLimit(double askPrice, double atrPO, double atrSL);
    void HandleSellLimit(double bidPrice, double atrPO, double atrSL);
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
void COrderExecutor::LogResult(string action, double stopLoss,
                                ulong targetTicket, double targetVolume,
                                bool includePrice, bool logSuccess)
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
            Print("[JINPA][ERROR] ", action, " failed",
                  " | retcode=", retcode,
                  " | ", trade.ResultRetcodeDescription());
        return;
    }

    if(!logSuccess)
        return;

    if(logLevel >= LOG_INFO)
    {
        const ulong  ticket = (targetTicket > 0) ? targetTicket : trade.ResultOrder();
        const double volume = (targetVolume > 0.0) ? targetVolume : trade.ResultVolume();
        const double price  = trade.ResultPrice();
        string message = "[JINPA][TRADE] " + action + " | #" + string(ticket);
        if(volume > 0.0)
            message += " | " + DoubleToString(volume, 2);
        if(includePrice && price > 0.0)
            message += " | " + DoubleToString(price, _Digits);
        if(stopLoss > 0.0)
            message += " | SL " + DoubleToString(stopLoss, _Digits);
        Print(message);
    }

    if(logLevel >= LOG_DEBUG)
        Print("[JINPA][TRADE] DEBUG ", action,
              " | ask=", trade.ResultAsk(),
              " bid=", trade.ResultBid(),
              " | ", trade.ResultComment());
}

double COrderExecutor::CalcVolume(double slDistance, ENUM_ORDER_TYPE orderType, double openPrice)
{
    return riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps,
                                       riskPercent, slDistance, fixedVolume, orderType, openPrice);
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
    if(uiManager.BuyLimited())  { HandleBuyLimit(askPrice, atrPO, atrSL); uiManager.ResetBuyLimited();  }
    if(uiManager.SellLimited()) { HandleSellLimit(bidPrice, atrPO, atrSL);uiManager.ResetSellLimited(); }

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
        Print("[JINPA][TRADE] DEBUG BUY MARKET | vol=", DoubleToString(volume,2),
              " ask=", askPrice, " sl=", stopLoss);
    if(volume > 0) { trade.Buy(volume, symbol, askPrice, stopLoss, 0); LogResult("BUY", stopLoss); }
}

void COrderExecutor::HandleSellMarket(double bidPrice, double stopLoss)
{
    double volume = CalcVolume(MathAbs(bidPrice - stopLoss), ORDER_TYPE_SELL);
    if(logLevel >= LOG_DEBUG)
        Print("[JINPA][TRADE] DEBUG SELL MARKET | vol=", DoubleToString(volume,2),
              " bid=", bidPrice, " sl=", stopLoss);
    if(volume > 0) { trade.Sell(volume, symbol, bidPrice, stopLoss, 0); LogResult("SELL", stopLoss); }
}

void COrderExecutor::HandleBuyStop(double askPrice, double atrPO)
{
    double poPrice = askPrice + atrPO;
    double sl      = positionManager.CalculateStopLossByATR(symbol, "BUY", atrPO);
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_BUY_STOP, poPrice);
    if(logLevel >= LOG_DEBUG)
        Print("[JINPA][TRADE] DEBUG BUY STOP | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.BuyStop(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("BUY STOP", sl); }
}

void COrderExecutor::HandleSellStop(double bidPrice, double atrPO)
{
    double poPrice = bidPrice - atrPO;
    double sl      = positionManager.CalculateStopLossByATR(symbol, "SELL", atrPO);
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_SELL_STOP, poPrice);
    if(logLevel >= LOG_DEBUG)
        Print("[JINPA][TRADE] DEBUG SELL STOP | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.SellStop(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("SELL STOP", sl); }
}

void COrderExecutor::HandleBuyLimit(double askPrice, double atrPO, double atrSL)
{
    double poPrice = askPrice - atrPO;
    double sl      = poPrice - atrSL;
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_BUY_LIMIT, poPrice);
    if(logLevel >= LOG_DEBUG)
        Print("[JINPA][TRADE] DEBUG BUY LIMIT | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.BuyLimit(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("BUY LIMIT", sl); }
}

void COrderExecutor::HandleSellLimit(double bidPrice, double atrPO, double atrSL)
{
    double poPrice = bidPrice + atrPO;
    double sl      = poPrice + atrSL;
    double volume  = CalcVolume(MathAbs(poPrice - sl), ORDER_TYPE_SELL_LIMIT, poPrice);
    if(logLevel >= LOG_DEBUG)
        Print("[JINPA][TRADE] DEBUG SELL LIMIT | vol=", DoubleToString(volume,2),
              " price=", poPrice, " sl=", sl);
    if(volume > 0) { trade.SellLimit(volume, poPrice, symbol, sl, 0, ORDER_TIME_SPECIFIED, GetExpiration()); LogResult("SELL LIMIT", sl); }
}

void COrderExecutor::HandleCancelBuyOrder()
{
    ulong ticket = GetPendingBuyTicket();
    if(ticket > 0) { trade.OrderDelete(ticket); LogResult("CANCEL BUY", 0.0, ticket, 0.0, false); }
}

void COrderExecutor::HandleCancelSellOrder()
{
    ulong ticket = GetPendingSellTicket();
    if(ticket > 0) { trade.OrderDelete(ticket); LogResult("CANCEL SELL", 0.0, ticket, 0.0, false); }
}

void COrderExecutor::HandleCloseBuyPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) != symbol) continue;
        if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
        ulong ticket = PositionGetTicket(i);
        double volume = PositionGetDouble(POSITION_VOLUME);
        trade.PositionClose(ticket);
        LogResult("CLOSE BUY", 0.0, ticket, volume, false, false);
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
        double volume = PositionGetDouble(POSITION_VOLUME);
        trade.PositionClose(ticket);
        LogResult("CLOSE SELL", 0.0, ticket, volume, false, false);
        break;
    }
}

#endif
