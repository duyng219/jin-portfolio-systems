//+------------------------------------------------------------------+
//|                                              PositionManager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

#include "trade_executor.mqh"
//AdjustStopLvl is used by SL,TP, TSL & BE functions

//+------------------------------------------------------------------+
//| CPM Class - Stop Loss, Take Profit, TSL & BE                     |
//+------------------------------------------------------------------+
class CPM
{
    public:
        MqlTradeRequest     request;
        MqlTradeResult      result;

                            CPM(void);

        double              CalculatorStopLoss(string pSymbol, string pEntrySignal, int pSLFixedPoints);
        double              CalculateStopLossByATR(string pSymbol, string pEntrySignal, double pATRValue, double pATRFactor);

        void              TrailingStopLoss(string pSymbol,ulong pMagic,int pTSLFixedPoints);
        void              TrailingStopLossByATR(string pSymbol, ulong pMagic, double atrValue, double pATRFactor);
};

//+------------------------------------------------------------------+
//| CPM Class Methods                                                |
//+------------------------------------------------------------------+
CPM::CPM()
{
    ZeroMemory(request);
    ZeroMemory(result);
}

double CPM::CalculatorStopLoss(string pSymbol, string pEntrySignal, int pSLFixedPoints)
{
    double stopLoss = 0.0;
    double askPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);
    double tickSize = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    double point    = SymbolInfoDouble(pSymbol,SYMBOL_POINT);

    if(pEntrySignal == "BUY")
    {
        if(pSLFixedPoints > 0){ 
            stopLoss = askPrice - (pSLFixedPoints * point); }
    }
    else if(pEntrySignal == "SELL")
    {
        if(pSLFixedPoints > 0){ 
            stopLoss = bidPrice + (pSLFixedPoints * point); }
    }

    stopLoss = round(stopLoss/tickSize) * tickSize;
    return stopLoss;
}

double CPM::CalculateStopLossByATR(string pSymbol, string pEntrySignal, double pATRValue, double pATRFactor)
{
    double stopLoss = 0.0;
    double atrStopLossDistance = pATRValue * pATRFactor;
    double askPrice = SymbolInfoDouble(pSymbol, SYMBOL_ASK);
    double bidPrice = SymbolInfoDouble(pSymbol, SYMBOL_BID);
    double tickSize = SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_SIZE);

    if (pEntrySignal == "BUY")
    {
        stopLoss = askPrice - atrStopLossDistance;
    }
    else if (pEntrySignal == "SELL")
    {
        stopLoss = bidPrice + atrStopLossDistance;
    }

    stopLoss = round(stopLoss / tickSize) * tickSize;
    return stopLoss;
}

void CPM::TrailingStopLoss(string pSymbol,ulong pMagic,int pTSLFixedPoints)
{	
	for(int i = PositionsTotal() - 1; i >= 0; i--)
	{
      //Reset of request and result values
      ZeroMemory(request);
      ZeroMemory(result);
         	   
	   ulong positionTicket = PositionGetTicket(i);
	   PositionSelectByTicket(positionTicket);
   
      string posSymbol        = PositionGetString(POSITION_SYMBOL);   
	   ulong posMagic          = PositionGetInteger(POSITION_MAGIC);
	   ulong posType           = PositionGetInteger(POSITION_TYPE);
      double currentStopLoss  = PositionGetDouble(POSITION_SL);
      double tickSize         = SymbolInfoDouble(posSymbol,SYMBOL_TRADE_TICK_SIZE);
      double point            = SymbolInfoDouble(posSymbol,SYMBOL_POINT);   
      	   
	   double newStopLoss;
	   
	   if(posSymbol == pSymbol && posMagic == pMagic && posType == POSITION_TYPE_BUY)
	   {        
         double bidPrice = SymbolInfoDouble(posSymbol,SYMBOL_BID);  
         newStopLoss = bidPrice - (pTSLFixedPoints * point);
         newStopLoss = AdjustBelowStopLevel(posSymbol,bidPrice,newStopLoss);         
         newStopLoss = round(newStopLoss/tickSize) * tickSize;
         
         if(newStopLoss > currentStopLoss)
         {
            request.action    = TRADE_ACTION_SLTP;
            request.position  = positionTicket;
            request.comment   = "TSL." + " | " + posSymbol + " | " + string(pMagic);
            request.sl        = newStopLoss;
            request.tp        = PositionGetDouble(POSITION_TP);          
         }     
	   }
	   else if(posSymbol == pSymbol && posMagic == pMagic && posType == POSITION_TYPE_SELL)
	   {                 
         double askPrice = SymbolInfoDouble(posSymbol,SYMBOL_ASK);                  
         newStopLoss = askPrice + (pTSLFixedPoints * point);
         newStopLoss = AdjustAboveStopLevel(posSymbol,askPrice,newStopLoss);
         newStopLoss = round(newStopLoss/tickSize) * tickSize;
         
         if(newStopLoss < currentStopLoss)
         {
            request.action    = TRADE_ACTION_SLTP;
            request.position  = positionTicket;
            request.comment   = "TSL." + " | " + posSymbol + " | " + string(pMagic);
            request.sl        = newStopLoss;  
            request.tp        = PositionGetDouble(POSITION_TP);                              
         }        
	   } 
      
      if(request.sl > 0)
      {
         bool sent = OrderSend(request,result);
   	   if(!sent) Print("OrderSend TSL error: ", GetLastError());           
      }
	}
}
/*
void CPM::TrailingStopLossByATR(string pSymbol, ulong pMagic, double atrValue)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ZeroMemory(request);
        ZeroMemory(result);

        ulong positionTicket = PositionGetTicket(i);
        PositionSelectByTicket(positionTicket);
        string posSymbol = PositionGetString(POSITION_SYMBOL);
        ulong posMagic = PositionGetInteger(POSITION_MAGIC);
        ulong posType = PositionGetInteger(POSITION_TYPE);
        double currentStopLoss = PositionGetDouble(POSITION_SL);
        double tickSize = SymbolInfoDouble(posSymbol, SYMBOL_TRADE_TICK_SIZE);
        double point = SymbolInfoDouble(posSymbol, SYMBOL_POINT);

        if(posSymbol == pSymbol && posMagic == pMagic)
        {
            double newStopLoss = 0.0;

            if(posType == POSITION_TYPE_BUY)
            {
                double bidPrice = SymbolInfoDouble(posSymbol, SYMBOL_BID);
                newStopLoss = bidPrice - atrValue;
                newStopLoss = AdjustBelowStopLevel(posSymbol, bidPrice, newStopLoss);
                newStopLoss = round(newStopLoss / tickSize) * tickSize;

                if(newStopLoss > currentStopLoss)
                {
                    request.action = TRADE_ACTION_SLTP;
                    request.position = positionTicket;
                    request.comment = "ATR TSL." + " | " + posSymbol + " | " + string(pMagic);
                    request.sl = newStopLoss;
                    request.tp = PositionGetDouble(POSITION_TP);
                }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
                double askPrice = SymbolInfoDouble(posSymbol, SYMBOL_ASK);
                newStopLoss = askPrice + atrValue;
                newStopLoss = AdjustAboveStopLevel(posSymbol, askPrice, newStopLoss);
                newStopLoss = round(newStopLoss / tickSize) * tickSize;

                if(newStopLoss < currentStopLoss)
                {
                    request.action = TRADE_ACTION_SLTP;
                    request.position = positionTicket;
                    request.comment = "ATR TSL." + " | " + posSymbol + " | " + string(pMagic);
                    request.sl = newStopLoss;
                    request.tp = PositionGetDouble(POSITION_TP);
                }
            }

            if(request.sl > 0)
            {
                bool sent = OrderSend(request, result);
                if(!sent) Print("OrderSend ATR TSL error: ", GetLastError());
            }
        }
    }
}
*/

void CPM::TrailingStopLossByATR(string pSymbol, ulong pMagic, double atrValue, double pATRFactor)
{
    double atrStopLossDistance = atrValue * pATRFactor;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ZeroMemory(request);
        ZeroMemory(result);

        ulong positionTicket = PositionGetTicket(i);
        PositionSelectByTicket(positionTicket);
        string posSymbol = PositionGetString(POSITION_SYMBOL);
        ulong posMagic = PositionGetInteger(POSITION_MAGIC);
        ulong posType = PositionGetInteger(POSITION_TYPE);
        double currentStopLoss = PositionGetDouble(POSITION_SL);
        double tickSize = SymbolInfoDouble(posSymbol, SYMBOL_TRADE_TICK_SIZE);
        double point = SymbolInfoDouble(posSymbol, SYMBOL_POINT);

        if(posSymbol == pSymbol && posMagic == pMagic)
        {
            double newStopLoss = 0.0;

            if(posType == POSITION_TYPE_BUY)
            {
                double bidPrice = SymbolInfoDouble(posSymbol, SYMBOL_BID);
                newStopLoss = bidPrice - atrStopLossDistance;
                newStopLoss = AdjustBelowStopLevel(posSymbol, bidPrice, newStopLoss);
                newStopLoss = round(newStopLoss / tickSize) * tickSize;

                if(newStopLoss > currentStopLoss)
                {
                    request.action = TRADE_ACTION_SLTP;
                    request.position = positionTicket;
                    request.comment = "ATR TSL | BUY | " + posSymbol + " | " + string(pMagic);
                    request.sl = newStopLoss;
                    request.tp = PositionGetDouble(POSITION_TP);
                }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
                double askPrice = SymbolInfoDouble(posSymbol, SYMBOL_ASK);
                newStopLoss = askPrice + atrStopLossDistance;
                newStopLoss = AdjustAboveStopLevel(posSymbol, askPrice, newStopLoss);
                newStopLoss = round(newStopLoss / tickSize) * tickSize;

                if(newStopLoss < currentStopLoss)
                {
                    request.action = TRADE_ACTION_SLTP;
                    request.position = positionTicket;
                    request.comment = "ATR TSL | SELL | " + posSymbol + " | " + string(pMagic);
                    request.sl = newStopLoss;
                    request.tp = PositionGetDouble(POSITION_TP);
                }
            }

            if(request.sl > 0)
            {
                bool sent = OrderSend(request, result);
                if(!sent) Print("OrderSend ATR TSL error: ", GetLastError());
            }
        }
    }
}