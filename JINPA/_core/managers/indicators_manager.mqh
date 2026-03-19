//+------------------------------------------------------------------+
//|                                                                          Indicators.mqh |
//|                                                                                        duyng |
//|                                                  https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

#define VALUES_TO_COPY 10 // Hằng số được truyền vào hàm copybuffer để chỉ định lượng dữ liệu chúng ta muốn sao chép từ một chỉ báo

//+------------------------------------------------------------------+
//| Base Class                                                                                  |
//+------------------------------------------------------------------+
class CIndicator
{
    protected:
        int         handle;

    public:
        double      main[];

                    CIndicator(void);
        
        virtual int Init(void) { return(handle); }
        void        RefreshMain(void);
};

CIndicator::CIndicator(void)
{
    ArraySetAsSeries(main,true);
}

void CIndicator::RefreshMain(void)
{
    ResetLastError();

    if(CopyBuffer(handle,0,0,VALUES_TO_COPY,main) < 0)
        Print("..FILL_ERROR: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Moving Average                                                                        |
//+------------------------------------------------------------------+

class CiMA : public CIndicator
{
    public:
        int Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pMAPeriod, int pMAShift, ENUM_MA_METHOD pMAMethod, ENUM_APPLIED_PRICE pMAPrice);
};

int CiMA::Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, int pMAPeriod, int pMAShift, ENUM_MA_METHOD pMAMethod, ENUM_APPLIED_PRICE pMAPrice)
{
    //Trong trường hợp lỗi khi khởi tạo MA, GetLastError() sẽ lấy mã lỗi và lưu trữ trong _lastError.
    //ResetLastError sẽ thay đổi biến _lastError thành 0
    ResetLastError();

    //Một định danh duy nhất cho chỉ báo. Được sử dụng cho tất cả các hành động liên quan đến chỉ báo, chẳng hạn như sao chép dữ liệu và xóa chỉ báo
    handle = iMA(pSymbol,pTimeframe,pMAPeriod,pMAShift,pMAMethod,pMAPrice);

    if(handle == INVALID_HANDLE)
    {
        return -1;
        Print("..Đã xảy ra lỗi khi khởi tạo chỉ báo MA: ", GetLastError());
    }

    Print("..MA Indicator đã được khởi tạo thành công.");
    
    return(handle);
}

//+-------- Moving Average Signal Functions --------+//

string MA_EntrySignal(double pPrice1, double pPrice2, double pMA1, double pMA2)
{
    string str = "";
    string indicatorValues;

    if(pPrice2 <= pMA2 && pPrice1 > pMA1) {str = "BUY";}
    else if(pPrice2 >= pMA2 && pPrice1 < pMA1) {str = "SELL";}
    else {str = "NO_TRADE";}

    if(str == "BUY" || str == "SELL")
    {
        StringConcatenate(indicatorValues,  "MA 1: ", DoubleToString(pMA1,_Digits)," | ",
                                            "MA 2: ", DoubleToString(pMA2,_Digits)," | ",
                                            "Close 1: ", DoubleToString(pPrice1,_Digits)," | ",
                                            "Close 2: ", DoubleToString(pPrice2,_Digits));

        Print(str, " SIGNAL DETECED(TÍN HIỆU ĐÃ ĐƯỢC PHÁT HIỆN)", " | ", "Indicator Valuess: ", indicatorValues);
    }
    return str;
}

string MA_ExitSignal(double pPrice1, double pPrice2, double pMA1, double pMA2)
{
    string str = "";
    string indicatorValues;

    if(pPrice2 <= pMA2 && pPrice1 > pMA1) {str = "EXIT_SELL";}
    else if(pPrice2 >= pMA2 && pPrice1 < pMA1) {str = "EXIT_BUY";}
    else {str = "NO_EXIT";}

    if(str == "EXIT_BUY" || str == "EXIT_SELL")
    {
        StringConcatenate(indicatorValues,  "MA 1: ", DoubleToString(pMA1,_Digits)," | ",
                                            "MA 2: ", DoubleToString(pMA2,_Digits)," | ",
                                            "Close 1: ", DoubleToString(pPrice1,_Digits)," | ",
                                            "Close 2: ", DoubleToString(pPrice2,_Digits));

        Print(str, " SIGNAL DETECED(TÍN HIỆU ĐÃ ĐƯỢC PHÁT HIỆN)", " | ", "Indicator Valuess: ", indicatorValues);
    }
    return str;
}

        //--Phần kiểm tra isTrend sử dụng class để tính toán và trả về entrySignal và isTrend
        //--Kiểm tra Trend hiện tại BUY(UPTREND) & SELL(DOWNTREND)
        // string isTrend = "";
        // if((dateFilter == true)  && 
        //     ((entrySignal=="BUY" && isTrend=="UP_TREND") || 
        //     (entrySignal=="SELL" && isTrend=="DOWN_TREND")))
        // {

//+------------------------------------------------------------------+
//| ATR                                                              |
//+------------------------------------------------------------------+
class CiATR : public CIndicator 
{
    public:
	int Init(string pSymbol,ENUM_TIMEFRAMES pTimeframe,int pATRPeriod);
};

int CiATR::Init(string pSymbol,ENUM_TIMEFRAMES pTimeframe,int pATRPeriod)
{
   ResetLastError();
   
   handle = iATR(pSymbol,pTimeframe,pATRPeriod);
   
   if(handle == INVALID_HANDLE) 
   {
        return -1;
        Print("Đã xảy ra lỗi khi khởi tạo chỉ báo ATR: ", GetLastError());                    
   }
   
   Print("ATR Indicator đã được khởi tạo thành công.");
   
   return(handle);
}

//+------------------------------------------------------------------+
//| Volume                                                           |
//+------------------------------------------------------------------+
class CiVolume : public CIndicator
{
    public:
        int Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, ENUM_APPLIED_VOLUME pVolumeType);
};

int CiVolume::Init(string pSymbol, ENUM_TIMEFRAMES pTimeframe, ENUM_APPLIED_VOLUME pVolumeType)
{
    ResetLastError();
    
    handle = (int)iVolume(pSymbol, pTimeframe, pVolumeType);
    
    if(handle == INVALID_HANDLE)
    {
        Print("Đã xảy ra lỗi khi khởi tạo chỉ báo Volume: ", GetLastError());
        return -1;
    }

    Print("Volume Indicator đã được khởi tạo thành công.");

    
    return(handle);
}