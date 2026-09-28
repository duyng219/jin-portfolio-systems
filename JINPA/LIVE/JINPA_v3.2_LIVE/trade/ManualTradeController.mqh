//+------------------------------------------------------------------+
//| ManualTradeController.mqh                                        |
//| Shared manual order execution for JINPA v3.2 runtime panels      |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_MANUAL_TRADE_CONTROLLER_MQH
#define JINPA_MANUAL_TRADE_CONTROLLER_MQH

#include <Trade/Trade.mqh>
#include "../_core/managers/risk_manager.mqh"
#include "../_core/managers/position_manager.mqh"

struct SManualTradeRequest
{
    ENUM_ORDER_TYPE        orderType;
    ENUM_MONEY_MANAGEMENT  moneyManagement;
    double                 minLotPerEquitySteps;
    double                 riskPercent;
    double                 fixedVolume;
    bool                   useATRStopLoss;
    int                    stopLossPoints;
    double                 atrStopLoss;
    double                 atrPendingOffset;
    ushort                 pendingExpirationMinutes;
    int                    logLevel;
    string                 comment;
};

class CManualTradeController
{
private:
    string             m_symbol;
    ulong              m_magic;
    CRiskManager*      m_riskManager;
    CPositionManager*  m_positionManager;
    CTrade*            m_trade;

    bool   DependenciesReady() const;
    bool   IsWeekendFxLikeMarket() const;
    double CalculateVolume(const SManualTradeRequest &request,
                           const double slDistance = 0.0,
                           const double openPrice = 0.0) const;
    double CalculateMarketStopLoss(const SManualTradeRequest &request,
                                   const bool isBuy,
                                   const double basePrice) const;
    void   LogResult(const string action, const int logLevel) const;
    int    CancelPendingSide(const bool buySide, const int logLevel);
    int    ClosePositionSide(const bool buySide, const int logLevel);

public:
    CManualTradeController();

    bool Initialize(const string symbol,
                    const ulong magic,
                    CRiskManager* riskManager,
                    CPositionManager* positionManager,
                    CTrade* tradeService);
    bool IsReady() const;
    bool Execute(const SManualTradeRequest &request);

    int CancelBuyPending(const int logLevel);
    int CancelSellPending(const int logLevel);
    int CloseBuyPositions(const int logLevel);
    int CloseSellPositions(const int logLevel);
};

CManualTradeController::CManualTradeController() :
    m_symbol(""),
    m_magic(0),
    m_riskManager(NULL),
    m_positionManager(NULL),
    m_trade(NULL)
{
}

bool CManualTradeController::Initialize(const string symbol,
                                        const ulong magic,
                                        CRiskManager* riskManager,
                                        CPositionManager* positionManager,
                                        CTrade* tradeService)
{
    m_symbol          = symbol;
    m_magic           = magic;
    m_riskManager     = riskManager;
    m_positionManager = positionManager;
    m_trade           = tradeService;

    return DependenciesReady();
}

bool CManualTradeController::DependenciesReady() const
{
    return (m_symbol != "" && m_riskManager != NULL &&
            m_positionManager != NULL && m_trade != NULL);
}

bool CManualTradeController::IsReady() const
{
    return DependenciesReady();
}

bool CManualTradeController::IsWeekendFxLikeMarket() const
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(dt.day_of_week != 0 && dt.day_of_week != 6)
        return false;

    string base   = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
    string profit = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
    if(StringLen(base) != 3 || StringLen(profit) != 3)
        return false;

    string symbolName = m_symbol;
    string pairName   = base + profit;
    StringToUpper(symbolName);
    StringToUpper(pairName);
    return (StringFind(symbolName, pairName) >= 0);
}

double CManualTradeController::CalculateVolume(const SManualTradeRequest &request,
                                               const double slDistance,
                                               const double openPrice) const
{
    double effectiveDistance = slDistance;
    if(effectiveDistance <= 0.0)
    {
        effectiveDistance = (request.useATRStopLoss
                             ? request.atrStopLoss
                             : request.stopLossPoints * _Point);
    }
    if(effectiveDistance <= 0.0)
        effectiveDistance = request.atrStopLoss;

    return m_riskManager.MoneyManagement(m_symbol,
                                         request.moneyManagement,
                                         request.minLotPerEquitySteps,
                                         request.riskPercent,
                                         effectiveDistance,
                                         request.fixedVolume,
                                         request.orderType,
                                         openPrice);
}

double CManualTradeController::CalculateMarketStopLoss(const SManualTradeRequest &request,
                                                       const bool isBuy,
                                                       const double basePrice) const
{
    if(request.useATRStopLoss)
        return m_positionManager.CalculateStopLossByATR(m_symbol,
                                                        (isBuy ? "BUY" : "SELL"),
                                                        request.atrStopLoss);

    const double distance = request.stopLossPoints * _Point;
    return NormalizeDouble(basePrice + (isBuy ? -distance : distance), _Digits);
}

void CManualTradeController::LogResult(const string action, const int logLevel) const
{
    if(logLevel < 1)
        return;

    const uint rc = m_trade.ResultRetcode();
    string shortAction = action;
    StringReplace(shortAction, "ORDER_TYPE_", "");
    StringReplace(shortAction, "_", " ");

    const bool ok = (rc == TRADE_RETCODE_DONE ||
                     rc == TRADE_RETCODE_PLACED ||
                     rc == TRADE_RETCODE_DONE_PARTIAL ||
                     rc == TRADE_RETCODE_NO_CHANGES);
    if(ok)
    {
        if(logLevel >= 2)
            Print("[JINPA][TRADE] ", shortAction,
                  " | #", m_trade.ResultOrder(),
                  " | ", DoubleToString(m_trade.ResultVolume(), 2),
                  " | ", DoubleToString(m_trade.ResultPrice(), _Digits));
    }
    else
    {
        Print("[JINPA][ERROR] ", shortAction, " failed",
              " | retcode=", rc,
              " | ", m_trade.ResultRetcodeDescription());
    }
}

bool CManualTradeController::Execute(const SManualTradeRequest &request)
{
    if(!DependenciesReady())
    {
        Print("[JINPA][ERROR] Manual trade controller dependencies not set.");
        return false;
    }

    if(IsWeekendFxLikeMarket())
        Print("[JINPA][WARN] Weekend order attempt on ", m_symbol,
              " (FX/metal-like market). Today is Saturday/Sunday by broker server time. Please check before trading.");

    const bool isPending = (request.orderType == ORDER_TYPE_BUY_STOP ||
                            request.orderType == ORDER_TYPE_SELL_STOP ||
                            request.orderType == ORDER_TYPE_BUY_LIMIT ||
                            request.orderType == ORDER_TYPE_SELL_LIMIT);
    if(request.useATRStopLoss && request.atrStopLoss <= 0.0)
    {
        Print("[JINPA][WARN] ATR SL not ready (atrSL=0) — wait a tick for indicator to load.");
        return false;
    }
    if(isPending && request.atrPendingOffset <= 0.0)
    {
        Print("[JINPA][WARN] ATR PO not ready (atrPO=0) — wait a tick for indicator to load.");
        return false;
    }

    const double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    const double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    const int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    const datetime expiration = TimeCurrent() + (int)request.pendingExpirationMinutes * 60;
    bool attempted = false;

    switch(request.orderType)
    {
        case ORDER_TYPE_BUY:
        {
            const double lot = CalculateVolume(request);
            if(lot > 0.0)
            {
                const double sl = CalculateMarketStopLoss(request, true, ask);
                m_trade.Buy(lot, m_symbol, ask, sl, 0.0, request.comment);
                attempted = true;
            }
            break;
        }

        case ORDER_TYPE_SELL:
        {
            const double lot = CalculateVolume(request);
            if(lot > 0.0)
            {
                const double sl = CalculateMarketStopLoss(request, false, bid);
                m_trade.Sell(lot, m_symbol, bid, sl, 0.0, request.comment);
                attempted = true;
            }
            break;
        }

        case ORDER_TYPE_BUY_STOP:
        {
            const double price = NormalizeDouble(ask + request.atrPendingOffset, digits);
            const double sl = NormalizeDouble(m_positionManager.CalculateStopLossByATR(
                                              m_symbol, "BUY", request.atrPendingOffset), digits);
            const double lot = CalculateVolume(request, MathAbs(price - sl), price);
            if(lot > 0.0)
            {
                m_trade.BuyStop(lot, price, m_symbol, sl, 0.0,
                                ORDER_TIME_SPECIFIED, expiration, request.comment);
                attempted = true;
            }
            break;
        }

        case ORDER_TYPE_SELL_STOP:
        {
            const double price = NormalizeDouble(bid - request.atrPendingOffset, digits);
            const double sl = NormalizeDouble(m_positionManager.CalculateStopLossByATR(
                                              m_symbol, "SELL", request.atrPendingOffset), digits);
            const double lot = CalculateVolume(request, MathAbs(sl - price), price);
            if(lot > 0.0)
            {
                m_trade.SellStop(lot, price, m_symbol, sl, 0.0,
                                 ORDER_TIME_SPECIFIED, expiration, request.comment);
                attempted = true;
            }
            break;
        }

        case ORDER_TYPE_BUY_LIMIT:
        {
            const double price = NormalizeDouble(ask - request.atrPendingOffset, digits);
            const double sl = NormalizeDouble(price - request.atrStopLoss, digits);
            const double lot = CalculateVolume(request, MathAbs(price - sl), price);
            if(lot > 0.0)
            {
                m_trade.BuyLimit(lot, price, m_symbol, sl, 0.0,
                                 ORDER_TIME_SPECIFIED, expiration, request.comment);
                attempted = true;
            }
            break;
        }

        case ORDER_TYPE_SELL_LIMIT:
        {
            const double price = NormalizeDouble(bid + request.atrPendingOffset, digits);
            const double sl = NormalizeDouble(price + request.atrStopLoss, digits);
            const double lot = CalculateVolume(request, MathAbs(sl - price), price);
            if(lot > 0.0)
            {
                m_trade.SellLimit(lot, price, m_symbol, sl, 0.0,
                                  ORDER_TIME_SPECIFIED, expiration, request.comment);
                attempted = true;
            }
            break;
        }

        default:
            Print("[JINPA][ERROR] Unsupported manual order type: ", EnumToString(request.orderType));
            return false;
    }

    if(attempted)
        LogResult(EnumToString(request.orderType), request.logLevel);
    else if(request.logLevel >= 1)
        Print("[JINPA][ERROR] Lot=0 — cannot place ", EnumToString(request.orderType),
              " | atrSL=", DoubleToString(request.atrStopLoss, digits),
              " atrPO=", DoubleToString(request.atrPendingOffset, digits));

    return attempted;
}

int CManualTradeController::CancelPendingSide(const bool buySide, const int logLevel)
{
    if(!DependenciesReady())
        return 0;

    int cancelled = 0;
    for(int i = OrdersTotal() - 1; i >= 0; --i)
    {
        const ulong ticket = OrderGetTicket(i);
        if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != m_symbol ||
           (m_magic > 0 && (ulong)OrderGetInteger(ORDER_MAGIC) != m_magic))
            continue;

        const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        const bool matches = (buySide
                              ? (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT)
                              : (type == ORDER_TYPE_SELL_STOP || type == ORDER_TYPE_SELL_LIMIT));
        if(!matches)
            continue;

        if(m_trade.OrderDelete(ticket))
        {
            ++cancelled;
            if(logLevel >= 2)
                Print("[JINPA][TRADE] CANCEL ", (buySide ? "BUY" : "SELL"), " | #", ticket);
        }
        else if(logLevel >= 1)
        {
            Print("[JINPA][ERROR] CANCEL ", (buySide ? "BUY" : "SELL"),
                  " failed | #", ticket,
                  " | retcode=", m_trade.ResultRetcode(),
                  " | ", m_trade.ResultRetcodeDescription());
        }
    }
    return cancelled;
}

int CManualTradeController::ClosePositionSide(const bool buySide, const int logLevel)
{
    if(!DependenciesReady())
        return 0;

    int closed = 0;
    for(int i = PositionsTotal() - 1; i >= 0; --i)
    {
        const ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != m_symbol ||
           (m_magic > 0 && (ulong)PositionGetInteger(POSITION_MAGIC) != m_magic))
            continue;

        const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if((buySide && type != POSITION_TYPE_BUY) || (!buySide && type != POSITION_TYPE_SELL))
            continue;

        if(m_trade.PositionClose(ticket))
            ++closed;
        else if(logLevel >= 1)
        {
            Print("[JINPA][ERROR] CLOSE ", (buySide ? "BUY" : "SELL"),
                  " failed | #", ticket,
                  " | retcode=", m_trade.ResultRetcode(),
                  " | ", m_trade.ResultRetcodeDescription());
        }
    }
    return closed;
}

int CManualTradeController::CancelBuyPending(const int logLevel)
{
    return CancelPendingSide(true, logLevel);
}

int CManualTradeController::CancelSellPending(const int logLevel)
{
    return CancelPendingSide(false, logLevel);
}

int CManualTradeController::CloseBuyPositions(const int logLevel)
{
    return ClosePositionSide(true, logLevel);
}

int CManualTradeController::CloseSellPositions(const int logLevel)
{
    return ClosePositionSide(false, logLevel);
}

#endif // JINPA_MANUAL_TRADE_CONTROLLER_MQH
