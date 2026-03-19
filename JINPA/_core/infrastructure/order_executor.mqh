//+------------------------------------------------------------------+
//|                                                  OrderExecutor.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

#include <Trade/Trade.mqh>
#include "../managers/risk_manager.mqh"
#include "../managers/position_manager.mqh"
#include "../managers/trade_executor.mqh"
#include "ui_manager.mqh"
#include "position_helper.mqh"

//+------------------------------------------------------------------+
//| COrderExecutor Class                                             |
//+------------------------------------------------------------------+
class COrderExecutor
{
private:
    CRM* riskManager;
    CPM* positionManager;
    CTradeExecutor* tradeExecutor;
    CTrade* trade;
    CUIManager* uiManager;
    CBar bar;
    
    string symbol;
    ENUM_MONEY_MANAGEMENT moneyManagement;
    double minLotPerEquitySteps;
    double riskPercent;
    double fixedVolume;
    ushort poExpirationMinutes;
    ulong magicNumber;

public:
    COrderExecutor();
    
    void Initialize(string sym, CRM* rm, CPM* pm, CTradeExecutor* te, CTrade* t, CUIManager* ui, ulong magic,
                   ENUM_MONEY_MANAGEMENT mm, double minLot, double risk, double fixedVol, ushort expiration);
    
    void HandleAllOrders(double askPrice, double bidPrice, double atr, double atrPO, int slPoints);
    
private:
    void HandleBuyMarket(double askPrice, double stopLoss);
    void HandleSellMarket(double bidPrice, double stopLoss);
    void HandleBuyStop(double askPrice, double atr);
    void HandleSellStop(double bidPrice, double atr);
    void HandleBuyLimit(double askPrice, double atr);
    void HandleSellLimit(double bidPrice, double atr);
    void HandleCancelBuyOrder();
    void HandleCancelSellOrder();
    void HandleCloseBuyPosition();
    void HandleCloseSellPosition();
};

//+------------------------------------------------------------------+
//| COrderExecutor Constructor                                       |
//+------------------------------------------------------------------+
COrderExecutor::COrderExecutor()
{
    riskManager = NULL;
    positionManager = NULL;
    tradeExecutor = NULL;
    trade = NULL;
    uiManager = NULL;
}

//+------------------------------------------------------------------+
//| Initialize Order Executor                                        |
//+------------------------------------------------------------------+
void COrderExecutor::Initialize(string sym, CRM* rm, CPM* pm, CTradeExecutor* te, CTrade* t, CUIManager* ui, ulong magic,
                               ENUM_MONEY_MANAGEMENT mm, double minLot, double risk, double fixedVol, ushort expiration)
{
    symbol = sym;
    riskManager = rm;
    positionManager = pm;
    tradeExecutor = te;
    trade = t;
    uiManager = ui;
    magicNumber = magic;
    moneyManagement = mm;
    minLotPerEquitySteps = minLot;
    riskPercent = risk;
    fixedVolume = fixedVol;
    poExpirationMinutes = expiration;
    
    bar.Refresh(symbol, PERIOD_CURRENT, 6);
}

//+------------------------------------------------------------------+
//| Handle All Orders                                                |
//+------------------------------------------------------------------+
void COrderExecutor::HandleAllOrders(double askPrice, double bidPrice, double atr, double atrPO, int slPointsValue)
{
    bar.Refresh(symbol, PERIOD_CURRENT, 6);
    
    // BUY button pressed
    if(uiManager.BuyPressed())
    {
        double stopLoss = 0;
        if(slPointsValue > 0)
        {
            double averageLow = CPositionHelper::GetAverageLow(3);
            stopLoss = MathMax(averageLow + (slPointsValue * _Point), askPrice - (slPointsValue * _Point));
        }
        else
        {
            stopLoss = positionManager.CalculateStopLossByATR(symbol, "BUY", atr, 1.0);
        }
        HandleBuyMarket(askPrice, stopLoss);
        uiManager.ResetBuyPressed();
    }
    
    // SELL button pressed
    if(uiManager.SellPressed())
    {
        double stopLoss = 0;
        if(slPointsValue > 0)
        {
            double averageHigh = CPositionHelper::GetAverageHigh(3);
            stopLoss = MathMin(averageHigh - (slPointsValue * _Point), bidPrice + (slPointsValue * _Point));
        }
        else
        {
            stopLoss = positionManager.CalculateStopLossByATR(symbol, "SELL", atr, 1.0);
        }
        HandleSellMarket(bidPrice, stopLoss);
        uiManager.ResetSellPressed();
    }
    
    // BUY STOP button pressed
    if(uiManager.BuyStopped())
    {
        HandleBuyStop(askPrice, atrPO);
        uiManager.ResetBuyStopped();
    }
    
    // SELL STOP button pressed
    if(uiManager.SellStopped())
    {
        HandleSellStop(bidPrice, atrPO);
        uiManager.ResetSellStopped();
    }
    
    // BUY LIMIT button pressed
    if(uiManager.BuyLimited())
    {
        HandleBuyLimit(askPrice, atrPO);
        uiManager.ResetBuyLimited();
    }
    
    // SELL LIMIT button pressed
    if(uiManager.SellLimited())
    {
        HandleSellLimit(bidPrice, atrPO);
        uiManager.ResetSellLimited();
    }
    
    // CANCEL BUY button pressed
    if(uiManager.BuyCancelled())
    {
        HandleCancelBuyOrder();
        uiManager.ResetBuyCancelled();
    }
    
    // CANCEL SELL button pressed
    if(uiManager.SellCancelled())
    {
        HandleCancelSellOrder();
        uiManager.ResetSellCancelled();
    }
    
    // CLOSE BUY button pressed
    if(uiManager.BuyClosed())
    {
        HandleCloseBuyPosition();
        uiManager.ResetBuyClosed();
    }
    
    // CLOSE SELL button pressed
    if(uiManager.SellClosed())
    {
        HandleCloseSellPosition();
        uiManager.ResetSellClosed();
    }
}

//+------------------------------------------------------------------+
//| Handle Buy Market Order                                          |
//+------------------------------------------------------------------+
void COrderExecutor::HandleBuyMarket(double askPrice, double stopLoss)
{
    double volume = riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps, 
                                                riskPercent, MathAbs(askPrice - stopLoss), fixedVolume, ORDER_TYPE_BUY);
    if(volume > 0)
    {
        trade.Buy(volume, symbol, askPrice, stopLoss, 0);
    }
}

//+------------------------------------------------------------------+
//| Handle Sell Market Order                                         |
//+------------------------------------------------------------------+
void COrderExecutor::HandleSellMarket(double bidPrice, double stopLoss)
{
    double volume = riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps, 
                                                riskPercent, MathAbs(bidPrice - stopLoss), fixedVolume, ORDER_TYPE_SELL);
    if(volume > 0)
    {
        trade.Sell(volume, symbol, bidPrice, stopLoss, 0);
    }
}

//+------------------------------------------------------------------+
//| Handle Buy Stop Order                                            |
//+------------------------------------------------------------------+
void COrderExecutor::HandleBuyStop(double askPrice, double atrPO)
{
    double poPrice = askPrice + atrPO;
    double stopLossATR = positionManager.CalculateStopLossByATR(symbol, "BUY", atrPO, 1.0);
    double volume = riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps, 
                                                riskPercent, MathAbs(poPrice - stopLossATR), fixedVolume, ORDER_TYPE_BUY);
    datetime expiration = tradeExecutor.GetExpirationTime(poExpirationMinutes);
    
    if(volume > 0)
    {
        tradeExecutor.BuyStop(symbol, volume, poPrice, stopLossATR, 0, expiration);
    }
}

//+------------------------------------------------------------------+
//| Handle Sell Stop Order                                           |
//+------------------------------------------------------------------+
void COrderExecutor::HandleSellStop(double bidPrice, double atrPO)
{
    double poPrice = bidPrice - atrPO;
    double stopLossATR = positionManager.CalculateStopLossByATR(symbol, "SELL", atrPO, 1.0);
    double volume = riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps, 
                                                riskPercent, MathAbs(poPrice - stopLossATR), fixedVolume, ORDER_TYPE_SELL);
    datetime expiration = tradeExecutor.GetExpirationTime(poExpirationMinutes);
    
    if(volume > 0)
    {
        tradeExecutor.SellStop(symbol, volume, poPrice, stopLossATR, 0, expiration);
    }
}

//+------------------------------------------------------------------+
//| Handle Buy Limit Order                                           |
//+------------------------------------------------------------------+
void COrderExecutor::HandleBuyLimit(double askPrice, double atrPO)
{
    double poPrice = askPrice - atrPO;
    double stopLossATR = positionManager.CalculateStopLossByATR(symbol, "BUY", atrPO, 1.0);
    stopLossATR -= 100 * _Point;
    double volume = riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps, 
                                                riskPercent, MathAbs(poPrice - stopLossATR), fixedVolume, ORDER_TYPE_BUY);
    datetime expiration = tradeExecutor.GetExpirationTime(poExpirationMinutes);
    
    if(volume > 0)
    {
        tradeExecutor.BuyLimit(symbol, volume, poPrice, stopLossATR, 0, expiration);
    }
}

//+------------------------------------------------------------------+
//| Handle Sell Limit Order                                          |
//+------------------------------------------------------------------+
void COrderExecutor::HandleSellLimit(double bidPrice, double atrPO)
{
    double poPrice = bidPrice + atrPO;
    double stopLossATR = positionManager.CalculateStopLossByATR(symbol, "SELL", atrPO, 1.0);
    stopLossATR += 100 * _Point;
    double volume = riskManager.MoneyManagement(symbol, moneyManagement, minLotPerEquitySteps, 
                                                riskPercent, MathAbs(poPrice - stopLossATR), fixedVolume, ORDER_TYPE_SELL);
    datetime expiration = tradeExecutor.GetExpirationTime(poExpirationMinutes);
    
    if(volume > 0)
    {
        tradeExecutor.SellLimit(symbol, volume, poPrice, stopLossATR, 0, expiration);
    }
}

//+------------------------------------------------------------------+
//| Handle Cancel Buy Order                                          |
//+------------------------------------------------------------------+
void COrderExecutor::HandleCancelBuyOrder()
{
    ulong ticket = tradeExecutor.GetPendingTicket(symbol, magicNumber);
    if(ticket > 0)
    {
        tradeExecutor.Delete(ticket);
    }
}

//+------------------------------------------------------------------+
//| Handle Cancel Sell Order                                         |
//+------------------------------------------------------------------+
void COrderExecutor::HandleCancelSellOrder()
{
    ulong ticket = tradeExecutor.GetPendingTicket(symbol, magicNumber);
    if(ticket > 0)
    {
        tradeExecutor.Delete(ticket);
    }
}

//+------------------------------------------------------------------+
//| Handle Close Buy Position                                        |
//+------------------------------------------------------------------+
void COrderExecutor::HandleCloseBuyPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            ulong posTicket = PositionGetTicket(i);
            trade.PositionClose(posTicket);
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Handle Close Sell Position                                       |
//+------------------------------------------------------------------+
void COrderExecutor::HandleCloseSellPosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
            ulong posTicket = PositionGetTicket(i);
            trade.PositionClose(posTicket);
            break;
        }
    }
}
