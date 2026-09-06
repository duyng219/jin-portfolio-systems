//+------------------------------------------------------------------+
//|                                                TradeExecutor.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

//+------------------------------------------------------------------+
//| CTradeExecutor Class - Gửi lệnh mở, đóng và sửa đổi vị thế       |
//+------------------------------------------------------------------+

class CTradeExecutor
{
    protected:
        ulong                       OpenPosition(string pSymbol,ENUM_ORDER_TYPE pType, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL);
        bool                        OpenPending(string pSymbol,ENUM_ORDER_TYPE pType,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,double pStopLimit=0,datetime pExpiration=0, string pComment=NULL);

        ulong                       magicNumber;
        ulong                       deviation;
        ENUM_ORDER_TYPE_FILLING     fillingType;
        ENUM_ACCOUNT_MARGIN_MODE    marginMode;

    public:
        MqlTradeRequest             request;
        MqlTradeResult              result;

                                    CTradeExecutor(void);
        
        //Trade methods
        ulong                       Buy(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL);
        ulong                       Sell(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL);
        bool                        BuyStop(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL);
		bool                        SellStop(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL);
		
		bool                        BuyLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL);
		bool                        SellLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL);
		
		bool                        BuyStopLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,double pStopLimit=0,datetime pExpiration=0,string pComment=NULL);
		bool                        SellStopLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,double pStopLimit=0,datetime pExpiration=0,string pComment=NULL);

        void                        ModifyPosition(string pSymbol, ulong pTicket, double pStopLoss=0, double pTakeProfit=0);
        void                       ModifyPending(ulong pTicket,double pPrice=0,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0);

        void                        CloseTrades(string pSymbol, string pExitSignal);
        void                        Delete(ulong pTicket);

        datetime                    GetExpirationTime(ushort pOrderExpirationMinutes);	
        ulong                       GetPendingTicket(string pSymbol,ulong pMagic);

        //Các phương thức hỗ trợ kiểm tra đầu vào
        void                        SetMarginMode(void) {marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);}
        bool                        IsHedging(void) {return (marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);}
        void                        SetMagicNumber(ulong pMagic) {magicNumber = pMagic;}
        void                        SetDeviation(ulong pDeviation) {deviation = pDeviation;}
        void                        SetFillingType(ENUM_ORDER_TYPE_FILLING pFillingType) {fillingType = pFillingType;}
        bool                        IsFillingTypeAllowed(int pFillType);
        string                      GetFillingTypeName(int pFillType);

        bool                        CheckPlacedPosition(ulong pMagic);
        bool                        CheckPositionProfitOrStopReached(ulong pMagic);
        bool                        SelectPosition(string symbol);  
        
};

//+------------------------------------------------------------------+
//| CTradeExecutor Class Methods                                     |
//+------------------------------------------------------------------+

CTradeExecutor::CTradeExecutor(void)
{
    SetMarginMode();

    ZeroMemory(request);
    ZeroMemory(result);
}

ulong CTradeExecutor::OpenPosition(string pSymbol,ENUM_ORDER_TYPE pType, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL)
{
    ZeroMemory(request);
    ZeroMemory(result);

    //Request Parameters
    request.action       = TRADE_ACTION_DEAL;
    request.magic        = magicNumber;
    request.symbol       = pSymbol;
    request.type         = pType;
    request.volume       = pVolume;
    request.price        = pPrice; //Lệnh thị trường không cần giá nhưng một số brokers yêu cầu giá phải được truyền vào các tham số lệnh
    request.sl           = pStopLoss;
    request.tp           = pTakeProfit;
    request.deviation    = deviation;
    request.type_filling = fillingType;
    request.comment      = pComment;

    //Request Send
    if(!OrderSend(request,result))
        Print("..OrderSend lỗi đặt lệnh giao dịch: ", GetLastError()); //Nếu yêu cầu không được gửi, in mã lỗi

    //Trade Information - result.price không được sử dụng cho lệnh thị trường
    Print("..Order(Lệnh thị trường) #",result.order," đã gửi: ",result.retcode,", Volume: ",result.volume," Price: ",result.price,", Bid: ",result.bid,", Ask: ",result.ask);

    if( result.retcode==TRADE_RETCODE_DONE         || 
        result.retcode==TRADE_RETCODE_DONE_PARTIAL || 
        result.retcode==TRADE_RETCODE_PLACED       || 
        result.retcode==TRADE_RETCODE_NO_CHANGES    )
    {
        return result.order;
    }
    else return 0;
}

bool CTradeExecutor::OpenPending(string pSymbol,ENUM_ORDER_TYPE pType,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,double pStopLimit=0,datetime pExpiration=0,string pComment=NULL)
{
	ZeroMemory(request); //Clear request structure
	ZeroMemory(result);  //Clear result structure

    //Request Parameters
    request.action       = TRADE_ACTION_PENDING;                     
    request.symbol       = pSymbol;     // Tên cặp tiền giao dịch                         
    request.volume       = pVolume;     // Khối lượng giao dịch                 
    request.type         = pType;       //Kiểu lệnh (ORDER_TYPE_BUY_STOP, ORDER_TYPE_SELL_LIMIT,…)
    request.deviation    = deviation;   // Độ lệch giá cho lệnh chờ. Đặt giá trị này để 0 nếu không muốn sử dụng Deviation                                  
    request.magic        = magicNumber; // Magic Number để nhận diện lệnh của EA. Đặt giá trị này để 0 nếu không muốn sử dụng Magic Number                       
    request.comment      = pComment;    // Comment cho lệnh. Đặt giá trị này để NULL nếu không muốn sử dụng Comment
    request.type_filling = fillingType;
    request.sl           = pStopLoss;   // Đặt Stop Loss & Take Profit nếu có
    request.tp           = pTakeProfit; // Đặt Stop Loss & Take Profit nếu có
    request.stoplimit    = pStopLimit;  // Dành cho lệnh Stop-Limit. Giá mà lệnh sẽ được thực hiện sau khi giá thị trường đạt đến giá Stop

    double tickSize      = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    request.price        = round(pPrice/tickSize) * tickSize; // Làm tròn giá đặt lệnh theo tick size để tránh lỗi không hợp lệ. Điều này đặc biệt quan trọng với các cặp tiền có số lẻ
	
	if(pExpiration > 0)  // Nếu pExpiration > 0, lệnh sẽ có thời gian hết hạn
	{
		request.expiration = pExpiration;
		request.type_time = ORDER_TIME_SPECIFIED;
	} 
	else request.type_time = ORDER_TIME_GTC; // Ngược lại, ORDER_TIME_GTC có nghĩa là lệnh sẽ tồn tại cho đến khi được khớp hoặc bị hủy

    //Request Send
    if(!OrderSend(request,result))
    Print("..OrderSend trade placement error: ", GetLastError());     //if request was not send, print error code
   
    //Trade Information - result.price not used for market orders
    Print("..Pending Order(Lệnh chờ) #",result.order," đã gửi: ",result.retcode,", Volume: ",result.volume,", Price: ",result.price,", Bid: ",result.bid,", Ask: ",result.ask); 

    if( result.retcode == TRADE_RETCODE_DONE         || 
        result.retcode == TRADE_RETCODE_DONE_PARTIAL || 
        result.retcode == TRADE_RETCODE_PLACED       || 
        result.retcode == TRADE_RETCODE_NO_CHANGES    ) 
	{
    /*Nếu result.retcode trả về một trong các mã:
        •	TRADE_RETCODE_DONE: Lệnh được thực hiện.
        •	TRADE_RETCODE_DONE_PARTIAL: Lệnh khớp một phần.
        •	TRADE_RETCODE_PLACED: Lệnh chờ được đặt thành công.
        •	TRADE_RETCODE_NO_CHANGES: Lệnh không thay đổi (đã tồn tại).
        •	→ Trả về true (thành công).
        •	Ngược lại, trả về false (không thành công)
    */
      return true;
    }
    else return false;   	
}

ulong CTradeExecutor::Buy(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL)
{
    pComment = "BUY" + " | " + pSymbol + " | " + string(magicNumber);
    double price = SymbolInfoDouble(pSymbol,SYMBOL_ASK);

    ulong ticket = OpenPosition(pSymbol,ORDER_TYPE_BUY,pVolume,pPrice,pStopLoss,pTakeProfit,pComment);
    return(ticket);
}

ulong CTradeExecutor::Sell(string pSymbol, double pVolume, double pPrice, double pStopLoss=0, double pTakeProfit=0, string pComment=NULL)
{
    pComment = "SELL" + " | " + pSymbol + " | " + string(magicNumber);
    double price = SymbolInfoDouble(pSymbol,SYMBOL_BID);
		
	ulong ticket = OpenPosition(pSymbol,ORDER_TYPE_SELL,pVolume,pPrice,pStopLoss,pTakeProfit,pComment);
	return(ticket);
}

bool CTradeExecutor::BuyLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL)
{
	pComment = "BUY LIMIT" + " | " + pSymbol + " | " + string(magicNumber);
	
	bool success = OpenPending(pSymbol,ORDER_TYPE_BUY_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
	return(success);
}

bool CTradeExecutor::SellLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL)
{
	pComment = "SELL LIMIT" + " | " + pSymbol + " | " + string(magicNumber);
		
	bool success = OpenPending(pSymbol,ORDER_TYPE_SELL_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
	return(success);
}

bool CTradeExecutor::BuyStop(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL)
{
	pComment = "BUY STOP" + " | " + pSymbol + " | " + string(magicNumber);

	bool success = OpenPending(pSymbol,ORDER_TYPE_BUY_STOP,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
	return(success);
}

bool CTradeExecutor::SellStop(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0,string pComment=NULL)
{
	pComment = "SELL STOP" + " | " + pSymbol + " | " + string(magicNumber);
	
	bool success = OpenPending(pSymbol,ORDER_TYPE_SELL_STOP,pVolume,pPrice,pStopLoss,pTakeProfit,0,pExpiration,pComment);
	return(success);
}

bool CTradeExecutor::BuyStopLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,double pStopLimit=0,datetime pExpiration=0,string pComment=NULL)
{
	pComment = "BUY STOP-LIMIT" + " | " + pSymbol + " | " + string(magicNumber);
	
	bool success = OpenPending(pSymbol,ORDER_TYPE_BUY_STOP_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,pStopLimit,pExpiration,pComment);
	return(success);
}

bool CTradeExecutor::SellStopLimit(string pSymbol,double pVolume,double pPrice,double pStopLoss=0,double pTakeProfit=0,double pStopLimit=0,datetime pExpiration=0,string pComment=NULL)
{
	pComment = "SELL STOP-LIMIT" + " | " + pSymbol + " | " + string(magicNumber);
	
	bool success = OpenPending(pSymbol,ORDER_TYPE_SELL_STOP_LIMIT,pVolume,pPrice,pStopLoss,pTakeProfit,pStopLimit,pExpiration,pComment);
	return(success);
}

void CTradeExecutor::ModifyPosition(string pSymbol, ulong pTicket, double pStopLoss=0, double pTakeProfit=0)
{
    if(!CheckPlacedPosition(magicNumber)) return;

    ZeroMemory(request);
    ZeroMemory(result);

    double tickSize = SymbolInfoDouble(pSymbol,SYMBOL_TRADE_TICK_SIZE);
    int digits      = (int)SymbolInfoInteger(pSymbol,SYMBOL_DIGITS);

    if(pStopLoss>0)   pStopLoss   = round(pStopLoss/tickSize) * tickSize;
    if(pTakeProfit>0) pTakeProfit = round(pTakeProfit/tickSize) * tickSize;

    request.action      = TRADE_ACTION_SLTP;
    request.position    = pTicket;
	request.sl          = pStopLoss;
	request.tp          = pTakeProfit;
	request.symbol      = pSymbol;
	request.comment     = "MODIFY.SL-TP." + " | " + pSymbol + " | " + string(magicNumber) + ", SL: " + DoubleToString(request.sl,digits) + ", TP: "+ DoubleToString(request.tp,digits);

    if(request.sl > 0 || request.tp > 0) 
	{
		Sleep(1000);
		bool sent = OrderSend(request,result);
		Print(result.comment);
		
		if(!sent) 
		{
		   Print("..OrderSend Modification error: ", GetLastError());
		   Sleep(3000);
   		
            sent = OrderSend(request,result);
            Print(result.comment);
            if(!sent) Print("..OrderSend 2nd Try Modification error: ", GetLastError());
		}
      
        if( result.retcode == TRADE_RETCODE_DONE         || 
            result.retcode == TRADE_RETCODE_DONE_PARTIAL || 
            result.retcode == TRADE_RETCODE_PLACED       || 
            result.retcode == TRADE_RETCODE_NO_CHANGES   )
        {
            Print(pSymbol, " #",pTicket, " modified(đã sửa đổi SL)");
        }				
	}
}

void CTradeExecutor::ModifyPending(ulong pTicket,double pPrice=0,double pStopLoss=0,double pTakeProfit=0,datetime pExpiration=0)
{	
	if(!OrderSelect(pTicket)) {
	   Print("..Error selecting order ", pTicket); return;}
	
	if(pPrice == 0 && pStopLoss == 0 && pTakeProfit == 0 && pExpiration == 0) return;

	ZeroMemory(request);
	ZeroMemory(result);
	   
	string orderSymbol   = OrderGetString(ORDER_SYMBOL);
	ulong orderMagic     = OrderGetInteger(ORDER_MAGIC);
    double tickSize      = SymbolInfoDouble(orderSymbol,SYMBOL_TRADE_TICK_SIZE);
    int digits           = (int)SymbolInfoInteger(orderSymbol,SYMBOL_DIGITS);
   
	if(pPrice > 0)       request.price        = pPrice;
	if(pStopLoss > 0)    request.sl           = pStopLoss;
	if(pTakeProfit > 0)  request.tp           = pTakeProfit;	
	
	if(pExpiration > 0) 
	{
		request.expiration = pExpiration;
		request.type_time = ORDER_TIME_SPECIFIED;
	}

	request.action    = TRADE_ACTION_MODIFY;
	request.order     = pTicket;
	request.comment  = "MODIFY.P-ORDER" + " | " + orderSymbol + " | " + string(orderMagic); 
	
	bool sent = OrderSend(request,result);
	Print(result.comment);
	
	if(!sent) 
	{
	   Print("..OrderSend Modification error: ", GetLastError());
	   Sleep(3000);
		
		sent = OrderSend(request,result);
		Print(result.comment);
		if(!sent) Print("..OrderSend 2nd Try Modification error: ", GetLastError());
	}
  
    if( result.retcode == TRADE_RETCODE_DONE         || 
        result.retcode == TRADE_RETCODE_DONE_PARTIAL || 
        result.retcode == TRADE_RETCODE_PLACED       || 
        result.retcode == TRADE_RETCODE_NO_CHANGES   ) 
	{
      Print(orderSymbol, " #",pTicket, " modified");
    }	
}

void CTradeExecutor::CloseTrades(string pSymbol, string pExitSignal)
{
    if(!CheckPlacedPosition(magicNumber)) return;

    ZeroMemory(request);
    ZeroMemory(result);

    ulong posMagic      = PositionGetInteger(POSITION_MAGIC);
    ulong posType       = PositionGetInteger(POSITION_TYPE);
    ulong posTicket     = PositionGetInteger(POSITION_TICKET);
    string posSymbol    = PositionGetString(POSITION_SYMBOL);

    if(posSymbol == pSymbol && posMagic == magicNumber && posType == POSITION_TYPE_BUY && (pExitSignal == "EXIT_BUY" || pExitSignal == "EXIT"))
    {
        request.action          = TRADE_ACTION_DEAL;
        request.type            = ORDER_TYPE_SELL;
        request.symbol          = pSymbol;
        request.volume          = PositionGetDouble(POSITION_VOLUME);
        request.price           = SymbolInfoDouble(pSymbol, SYMBOL_BID);
        request.deviation       = deviation;
        request.type_filling    = fillingType;
        request.position        = posTicket;

    }
    else if(posSymbol == pSymbol && posMagic == magicNumber && posType == POSITION_TYPE_SELL && (pExitSignal == "EXIT_SELL" || pExitSignal == "EXIT"))
    {
        request.action          = TRADE_ACTION_DEAL;
        request.type            = ORDER_TYPE_BUY;
        request.symbol          = pSymbol;
        request.volume          = PositionGetDouble(POSITION_VOLUME);
        request.price           = SymbolInfoDouble(pSymbol, SYMBOL_ASK);
        request.deviation       = deviation;
        request.type_filling    = fillingType;
        request.position        = posTicket;
    }
    if(request.action == TRADE_ACTION_DEAL)   //Added to prevent sending the order when there is no exit signal
        if(!OrderSend(request,result))
            Print("..OrderSend trade close error: ", GetLastError());     //if request was not send, print error code
	   		
   if(  result.retcode == TRADE_RETCODE_DONE         || 
        result.retcode == TRADE_RETCODE_DONE_PARTIAL || 
        result.retcode == TRADE_RETCODE_PLACED       || 
        result.retcode == TRADE_RETCODE_NO_CHANGES   ) 
	{
      Print(pSymbol, " #",posTicket, " closed(đã đóng)");
   }
}

void CTradeExecutor::Delete(ulong pTicket)
{
	if(!OrderSelect(pTicket)) {
	   Print("..Error selecting order ", pTicket); return;}
	  	
	ZeroMemory(request);
	ZeroMemory(result);

	string orderSymbol = OrderGetString(ORDER_SYMBOL);
	
	request.action    = TRADE_ACTION_REMOVE;
	request.order     = pTicket;
    request.comment   = "DELETED O#" + string(pTicket) + " | " + orderSymbol;
   
    if(!OrderSend(request,result))
        Print("..OrderSend delete pending error: ", GetLastError());     //if request was not send, print error code
	   		
    if( result.retcode == TRADE_RETCODE_DONE         || 
        result.retcode == TRADE_RETCODE_DONE_PARTIAL || 
        result.retcode == TRADE_RETCODE_PLACED       || 
        result.retcode == TRADE_RETCODE_NO_CHANGES   ) 
	{
        Print(orderSymbol, " #",pTicket, " deleted");
    }
}

// Nhận thời gian hết hạn cho các lệnh đang chờ xử lý tính bằng giây
datetime CTradeExecutor::GetExpirationTime(ushort pOrderExpirationMinutes)
{
   datetime orderExpirationSeconds = TimeCurrent() + pOrderExpirationMinutes * 60;
   
   return(orderExpirationSeconds); 
}

// Lấy số thứ tự của lệnh chờ theo Magic Number và Symbol
ulong CTradeExecutor::GetPendingTicket(string pSymbol, ulong pMagic)
{
	int total=OrdersTotal(); 
	   
    for(int i=total-1; i>=0; i--)
    {
        ulong orderTicket = OrderGetTicket(i);                   
        ulong magic       = OrderGetInteger(ORDER_MAGIC);              
        string symbol     = OrderGetString(ORDER_SYMBOL);
        
        if(magic==pMagic && symbol == pSymbol) return(orderTicket);
    }
   
    return 0; 
}

// Kiểm tra xem có vị thế nào thuộc về pSymbol không.
// Nếu bạn muốn kiểm tra xem EA có đang mở vị thế trên cặp tiền này không, nên dùng SelectPosition().
bool CTradeExecutor::SelectPosition(string pSymbol)
{
   bool res = false;
   
   if(IsHedging())
    {
      int total = PositionsTotal();
      
      for(int i = total - 1; i >= 0; i--)
        {
            string positionSymbol = PositionGetSymbol(i);
            
            if(positionSymbol == pSymbol && magicNumber == PositionGetInteger(POSITION_MAGIC))
            {
                res = true;
                break;
            }
        }
    }
    else
        res = PositionSelect(pSymbol);
        //PositionSelect() chỉ hoạt động trong chế độ “netting” (một vị thế duy nhất trên mỗi symbol).
        //Nếu tài khoản sử dụng hedging (cho phép nhiều vị thế trên cùng một cặp tiền), thì PositionSelect() chỉ chọn vị thế tổng của symbol đó và không hỗ trợ chọn từng lệnh riêng lẻ.
      
    return(res);
}

// Kiểm tra xem có vị thế nào thuộc về pMagic không.
// Nếu chỉ muốn biết có bất kỳ lệnh nào của EA đang chạy không, CheckPlacedPosition() sẽ hiệu quả hơn.
bool CTradeExecutor::CheckPlacedPosition(ulong pMagic)
{
    bool placedPosition = false;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong positionTicket = PositionGetTicket(i);
        PositionSelectByTicket(positionTicket);

        ulong posMagic = PositionGetInteger(POSITION_MAGIC);

        if(posMagic == pMagic)
        {
            placedPosition = true;
            break;
        }
    }
    return placedPosition;   
}

bool CTradeExecutor::CheckPositionProfitOrStopReached(ulong pMagic)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong positionTicket = PositionGetTicket(i);
        PositionSelectByTicket(positionTicket);

        ulong posMagic = PositionGetInteger(POSITION_MAGIC);
        double posStopLoss = PositionGetDouble(POSITION_SL);
        double posPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
        double posProfit = PositionGetDouble(POSITION_PROFIT);

        // Kiểm tra nếu vị thế có magic number tương ứng
        if(posMagic == pMagic)
        {
            // Kiểm tra nếu StopLoss đạt đến Entry hoặc vị thế đang có lợi nhuận
            //if(posStopLoss >= posPriceOpen || posProfit > 0)
            // Kiểm tra nếu StopLoss đạt đến Entry  (Trailing Stop)
            if(posStopLoss >= posPriceOpen)
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| NON-CLASS TRADE FUNCTIONS                                        |
//+------------------------------------------------------------------+

bool CTradeExecutor::IsFillingTypeAllowed(int pFillType)
{
    //Lấy giá trị của thuộc tính Filling of Symbol hiện tại
    int symbolFillingMode = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    //Trả về "true" nếu chế độ fill_type được phép
    return ((symbolFillingMode & pFillType) == pFillType);
}

string CTradeExecutor::GetFillingTypeName(int pFillType)
{
    switch(pFillType)
    {
        case ORDER_FILLING_FOK:
            return "ORDER_FILLING_FOK.";
        case ORDER_FILLING_IOC:
            return "ORDER_FILLING_IOC.";
        case ORDER_FILLING_RETURN:
            return "ORDER_FILLING_RETURN.";
        default:
            return "UNKNOWN_FILLING_TYPE.";
    }
}

// Adjust stop level
double AdjustAboveStopLevel(string pSymbol,double pCurrentPrice,double pPriceToAdjust,int pPointsToAdd = 10)
{
	double adjustedPrice = pPriceToAdjust;
	
	double point      = SymbolInfoDouble(pSymbol,SYMBOL_POINT);
	long stopsLevel   = SymbolInfoInteger(pSymbol,SYMBOL_TRADE_STOPS_LEVEL);
	
	if(stopsLevel > 0)
	{
	   double stopsLevelPrice = stopsLevel * point;          //stops level points in price
	   stopsLevelPrice = pCurrentPrice + stopsLevelPrice;    //stops price level - distance from bid/ask
   	
   	double addPoints = pPointsToAdd * point;              //Points that will be added/subtracted to stops level price to make sure our price covers the distance
   	
   	if(adjustedPrice <= stopsLevelPrice + addPoints) 
   	{
   		adjustedPrice = stopsLevelPrice + addPoints;
   		Print("..Price adjusted above stop level to "+ string(adjustedPrice));		
   	}
	}
	 
	return adjustedPrice;
}

double AdjustBelowStopLevel(string pSymbol,double pCurrentPrice,double pPriceToAdjust,int pPointsToAdd = 10)
{
	double adjustedPrice = pPriceToAdjust;
	
	double point      = SymbolInfoDouble(pSymbol,SYMBOL_POINT);
	long stopsLevel   = SymbolInfoInteger(pSymbol,SYMBOL_TRADE_STOPS_LEVEL);
	
	if(stopsLevel > 0)
	{
	   double stopsLevelPrice = stopsLevel * point;          //stops level points in price
	   stopsLevelPrice = pCurrentPrice - stopsLevelPrice;    //stops price level - distance from bid/ask
   	
   	double addPoints = pPointsToAdd * point;              //Points that will be added/subtracted to stops level price to make sure our price covers the distance
   	
   	if(adjustedPrice >= stopsLevelPrice - addPoints) 
   	{
   		adjustedPrice = stopsLevelPrice - addPoints;
   		Print("..Price adjusted below stop level to "+ string(adjustedPrice));		
   	}
	}
	 
	return adjustedPrice;
}

// Delay program execution when market is closed
void DelayOnMarketClose(ENUM_TIMEFRAMES pTimeframe)
{
   //Current time
   MqlDateTime time;
   TimeCurrent(time);
   
   if(MQLInfoInteger(MQL_TESTER) && time.hour==0)
   {
      if(pTimeframe >= PERIOD_H4) Sleep(1800000); //300000 5min 1800000 30min  3600000 60min 
      else                        Sleep(300000);
   }                                                                                                                                                                                                                                                                                               
}
//+------------------------------------------------------------------+