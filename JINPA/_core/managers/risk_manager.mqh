//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

enum ENUM_MONEY_MANAGEMENT
{
    //MM_MIN_LOT_SIZE: Kích thước Volume tối thiểu của Symbol(VD: EURUSD Volume nhỏ nhất là 0.01)
    //MM_MIN_LOT_PER_EQUITY: Kích thước Volume tối thiểu / Vốn (VD: Account 1500(500(x3)) -> 3(Vốn chia đều) * 0.01(Volume Min Symbol) = 0.03)
    //MM_FIXED_LOT_SIZE: Kích thước Volume cố định(VD: Default 0.05 -> 0.05)
    //MM_FIXED_LOT_PER_EQUITY: Kích thước Volume tối thiểu / Vốn (VD: Account 1500(500(x3)) -> 3(Vốn chia đều) * 0.05(Volume cố định) = 0.15) (Khác với cách trên là thay vì dùng khối lượng nhỏ nhất thì ta truyền vào khối lượng cố định mà ta đưa vào)
    //MM_EQUITY_RISK_PERCENT: Phần trăm rủi ro trên Vốn(VD: 1%/10000$ = 100$)

    MM_MIN_LOT_SIZE,
    MM_MIN_LOT_PER_EQUITY,
    MM_FIXED_LOT_SIZE,
    MM_FIXED_LOT_PER_EQUITY,
    MM_EQUITY_RISK_PERCENT
};

class CRM
{
    private:
        double          CalculateVolumeRiskPerc(string pSymbol, double pRiskPercent, double pSLInPricePoints);

    public:
        //-- Methods for position sizing
        double          MoneyManagement(string pSymbol, ENUM_MONEY_MANAGEMENT pMoneyManagement, double pMinLotPerEquitySteps, double pRiskPercent, double pSLInPricePoints, double pFixedVol, ENUM_ORDER_TYPE pOrderType, double pOpenPrice=0.0);

        double          VerifyVolume(string pSymbol,double pVolume);            
        bool            VerifyMargin(string pSymbol,double pVolume,ENUM_ORDER_TYPE pOrderType,double pOpenPrice=0.0);

        //-- Methods to limit the loss during a specific time range (hours, days...)
        
};

double CRM::MoneyManagement(string pSymbol,ENUM_MONEY_MANAGEMENT pMoneyManagement,double pMinLotPerEquitySteps,double pRiskPercent,double pSLInPricePoints,double pFixedVol,ENUM_ORDER_TYPE pOrderType,double pOpenPrice=0.0)
{
   double volume = 0;
   
   switch(pMoneyManagement)
   {
      case MM_MIN_LOT_SIZE: 
         volume = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MIN);
         break;
      
      case MM_MIN_LOT_PER_EQUITY:
         if(pMinLotPerEquitySteps == 0) Print(__FUNCTION__ + "() - Minimum lots per equity steps is expected");
         volume = AccountInfoDouble(ACCOUNT_EQUITY) / pMinLotPerEquitySteps * SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MIN);//5000 1000 - 5*0.01=0.05
         break;
            
      case MM_FIXED_LOT_SIZE:
         if(pFixedVol == 0) Print(__FUNCTION__ + "() - Fixed volume is expected");
         volume = pFixedVol; 
         break;    
         
      case MM_FIXED_LOT_PER_EQUITY:
         if(pMinLotPerEquitySteps == 0 || pFixedVol == 0) Print(__FUNCTION__ + "() - Fixed lots per equity steps is expected");
         volume = AccountInfoDouble(ACCOUNT_EQUITY) / pMinLotPerEquitySteps * pFixedVol;
         break; 
         
      case MM_EQUITY_RISK_PERCENT:
         volume = CalculateVolumeRiskPerc(pSymbol,pRiskPercent,pSLInPricePoints);
         break;                              
   }
   
   if(volume > 0) 
   {
      //Volume normalization
      volume = VerifyVolume(pSymbol,volume);      
      
      //Margin check - volume changed to 0 if no free margin available      
      if(!VerifyMargin(pSymbol,volume,pOrderType,pOpenPrice)) volume = 0;
   }    
   
   return volume;  
}

double CRM::CalculateVolumeRiskPerc(string pSymbol, double pRiskPercent, double pSLInPricePoints)
{
    if(pRiskPercent <= 0 || pSLInPricePoints <= 0)
    {
        Print(__FUNCTION__ + "() - Lỗi khi tính toán khối lượng phần trăm trên mỗi lệnh, vui lòng kiểm tra RiskPercent và SL");
        return 0;
    }

    double tickValue = SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_VALUE);
    if(tickValue <= 0)
    {
        Print(__FUNCTION__ + "() - Giá trị tickValue không hợp lệ, kiểm tra lại symbol: " + pSymbol);
        return 0;
    }

    double maxRisk = pRiskPercent * 0.01 * AccountInfoDouble(ACCOUNT_EQUITY);
    double riskPerPoint = maxRisk / (pSLInPricePoints / SymbolInfoDouble(pSymbol, SYMBOL_POINT));

    if(riskPerPoint <= 0)
    {
        Print(__FUNCTION__ + "() - Giá trị riskPerPoint không hợp lệ, kiểm tra lại SL và RiskPercent");
        return 0;
    }

    double lotsRisked = riskPerPoint / tickValue;
    return lotsRisked;
}

//Verify and adjust volume
double CRM::VerifyVolume(string pSymbol,double pVolume)
{
	double minVolume  = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MIN);
	double maxVolume  = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_MAX);
	double stepVolume = SymbolInfoDouble(pSymbol,SYMBOL_VOLUME_STEP);
	
	double verifiedVol;
	
	if(pVolume < minVolume)       verifiedVol = minVolume;
	else if(pVolume > maxVolume)  verifiedVol = maxVolume;
	else                          verifiedVol = MathRound(pVolume / stepVolume) * stepVolume;    //0.057785  MathRound(0.057785 / 0.01) * 0.01 -> 0.06
	
	return verifiedVol;
}

//Verify margin - Sử dụng cho Pending Order
bool CRM::VerifyMargin(string pSymbol,double pVolume,ENUM_ORDER_TYPE pOrderType,double pOpenPrice=0.0) //pOpenPrice==0.0 su dung voi lenh cho Pending Order
{
   if(pOpenPrice == 0)
   {
      if(pOrderType == ORDER_TYPE_BUY)       pOpenPrice = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
      else if(pOrderType == ORDER_TYPE_SELL) pOpenPrice = SymbolInfoDouble(pSymbol,SYMBOL_BID);
   }
   
   double margin;
   if(!OrderCalcMargin(pOrderType,pSymbol,pVolume,pOpenPrice,margin)) Print(__FUNCTION__ + "(): Error calculating margin");
   
   if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE)) 
   {
      Print("No margin available to open a trade");
      return false;
   }   
   else return true;
}

// bool CRM::MaxLoss(double maxAllowedRiskPercent)
// {
//     double totalRiskPercent = 0.0;

//     // Duyệt qua tất cả các vị thế đang mở
//     for (int i = PositionsTotal() - 1; i >= 0; i--)
//     {
//         // Lấy mã số vị thế
//         ulong positionTicket = PositionGetTicket(i);
        
//         // Truy cập chi tiết của vị thế
//         if (PositionSelectByTicket(positionTicket))
//         {
//             // Tính toán rủi ro dựa trên chênh lệch giữa giá mở và dừng lỗ
//             double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
//             double stopLoss = PositionGetDouble(POSITION_SL);
//             double volume = PositionGetDouble(POSITION_VOLUME);

//             // Nếu có StopLoss, tính toán lỗ tiềm năng cho vị thế này
//             if (stopLoss > 0)
//             {
//                 double positionRisk = fabs(openPrice - stopLoss) * volume * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_TICK_VALUE);
                
//                 // Chuyển đổi rủi ro thành phần trăm trên vốn tài khoản
//                 double positionRiskPercent = (positionRisk / AccountInfoDouble(ACCOUNT_EQUITY)) * 100.0;
                
//                 // Cộng dồn rủi ro
//                 totalRiskPercent += positionRiskPercent;
//             }
//         }
//     }

//     // Kiểm tra nếu tổng rủi ro vượt quá mức cho phép
//     if (totalRiskPercent >= maxAllowedRiskPercent)
//     {
//         Print("Ngưỡng lỗ tối đa đã bị vượt: Rủi ro hiện tại là ", totalRiskPercent, "% của vốn.");
//         return true;  // Vượt quá ngưỡng cho phép, ngăn không cho mở lệnh mới
//     }
//     else
//     {
//         return false;  // Rủi ro trong ngưỡng cho phép
//     }
// }

/*
Giải thích

	1.	Tính toán Rủi ro cho Mỗi Vị thế: Với mỗi lệnh mở, hàm sẽ tính rủi ro bằng cách so sánh openPrice và stopLoss, có tính đến khối lượng vị thế và giá trị tick.
	2.	Chuyển đổi sang Phần trăm Vốn: Rủi ro của mỗi vị thế sẽ được chuyển thành phần trăm so với vốn tài khoản.
	3.	Cộng dồn Rủi ro: Hàm cộng dồn phần trăm rủi ro cho tất cả các lệnh đang mở.
	4.	Điều kiện Trả về: Nếu tổng phần trăm rủi ro đạt hoặc vượt maxAllowedRiskPercent (ví dụ: 5%), hàm sẽ trả về true để ngăn không cho mở thêm lệnh mới.

Cách Sử dụng

Bạn có thể gọi hàm này trong OnTick() hoặc bất kỳ logic kiểm tra mở lệnh nào để quyết định có cho phép mở lệnh mới hay không. Bạn có thể điều chỉnh maxAllowedRiskPercent theo nhu cầu, ví dụ 5.0 để giới hạn ở mức 5% vốn. Cách này giúp hệ thống tự động kiểm soát tổng rủi ro và ngăn mở lệnh mới khi vượt quá ngưỡng đã đặt ra.
*/


/*

Để đáp ứng yêu cầu mở nhiều vị thế nhưng chỉ khi vị thế trước đó đạt một trong hai điều kiện (StopLoss hoặc TrailingStop đã đạt đến điểm hòa vốn hoặc đang có lợi nhuận), chúng ta có thể điều chỉnh lớp CTradeExecutor với một hàm kiểm tra điều kiện này, đồng thời thêm logic vào OnTick để đáp ứng yêu cầu chiến lược.

1. Thêm hàm kiểm tra vị thế đạt điều kiện

Ta tạo thêm một hàm CheckPositionProfitOrStopReached để kiểm tra xem một vị thế cụ thể đã đạt đến điểm hòa vốn hay đang có lợi nhuận. Hàm này sẽ giúp xác định điều kiện mở thêm vị thế mới.

class CTradeExecutor
{
    // Các hàm hiện có...

    bool CheckPositionProfitOrStopReached(ulong pMagic)
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong positionTicket = PositionGetTicket(i);
            PositionSelectByTicket(positionTicket);

            ulong posMagic = PositionGetInteger(POSITION_MAGIC);
            double positionStopLoss = PositionGetDouble(POSITION_SL);
            double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
            double positionProfit = PositionGetDouble(POSITION_PROFIT);

            // Kiểm tra nếu vị thế có magic number tương ứng
            if(posMagic == pMagic)
            {
                // Kiểm tra nếu StopLoss đạt đến Entry hoặc vị thế đang có lợi nhuận
                if (positionStopLoss >= positionPriceOpen || positionProfit > 0)
                {
                    return true;
                }
            }
        }
        return false;
    }
};

Hàm này sẽ trả về true nếu có bất kỳ vị thế nào với MagicNumber đạt đến mức hòa vốn hoặc có lợi nhuận. Nếu không, hàm sẽ trả về false.

2. Sử dụng hàm CheckPositionProfitOrStopReached trong OnTick

Tiếp theo, chúng ta sử dụng hàm này trong OnTick() để kiểm tra điều kiện trước khi mở một vị thế mới. Điều này đảm bảo rằng chỉ khi có ít nhất một vị thế cũ đã đạt điều kiện thì vị thế mới mới được mở.

void OnTick()
{
    string entrySignal = "";  // Thay bằng logic lấy tín hiệu mua/bán thực tế
    ulong MagicNumber = 12345; // Magic number của hệ thống

    // Kiểm tra điều kiện mở vị thế
    if (!Trade.CheckPlacedPosition(MagicNumber) || Trade.CheckPositionProfitOrStopReached(MagicNumber))
    {   
        //----------------------------------------//
        //   STAGE 4: MỞ VỊ THẾ (TRADE PLACEMENT)
        //----------------------------------------//

        if (entrySignal == "BUY" || entrySignal == "SELL")
        {
            double volume = 0.01; // Thay bằng logic tính khối lượng thực tế

            if (entrySignal == "BUY")
            {
                // Logic mở vị thế BUY
                Trade.Buy(volume, Symbol());
            }
            else if (entrySignal == "SELL")
            {
                // Logic mở vị thế SELL
                Trade.Sell(volume, Symbol());
            }
        }
    }
}

3. Giải thích Logic

	•	Hàm OnTick kiểm tra xem liệu có bất kỳ vị thế nào đang mở với MagicNumber. Nếu không có vị thế nào mở, hoặc có nhưng đã đạt đến điểm hòa vốn hoặc đang có lợi nhuận, thì một vị thế mới sẽ được phép mở.
	•	Điều kiện này giúp hạn chế việc mở thêm vị thế chỉ khi các vị thế cũ đã đạt một ngưỡng an toàn.
*/