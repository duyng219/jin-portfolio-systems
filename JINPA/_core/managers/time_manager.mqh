//+------------------------------------------------------------------+
//|                                                  TimeManager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property version   "1.00"
//+------------------------------------------------------------------+
//|  Enumerations                                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|  DateTime Base Class                                             |
//+------------------------------------------------------------------+
class CDateTime
{
    protected:
        //Variables
        MqlDateTime         currentDateTime;
    
    public:
        //Current Date & Time Methods
        int Year()          { TimeCurrent(currentDateTime); return currentDateTime.year;}
        int Month()         { TimeCurrent(currentDateTime); return currentDateTime.mon;}
        int Day()           { TimeCurrent(currentDateTime); return currentDateTime.day;}    //Day of month, 1 to 30/31, 28-29 feb
        int DayOfWeek()     { TimeCurrent(currentDateTime); return currentDateTime.day_of_week;}
        int Hour()          { TimeCurrent(currentDateTime); return currentDateTime.hour;}
        int Minute()        { TimeCurrent(currentDateTime); return currentDateTime.min;}
        int Seconds()       { TimeCurrent(currentDateTime); return currentDateTime.sec;}
};

class CDate : public CDateTime
{
    private:
        bool                daysOfWeek[7];
    
    public:
        //Date Signal Methods
        void                Init(bool pSunday,bool pMonday, bool pTuesday, bool pWednesday, bool pThursday, bool pFriday, bool pSaturday);

        //Day of Week Filter Method
        bool                DayOfWeekFilter();
        bool                IsTradingTime();
        bool                IsTradingDay(string &pReport);
};

void CDate::Init(bool pSunday,bool pMonday, bool pTuesday, bool pWednesday, bool pThursday, bool pFriday, bool pSaturday)
{
    daysOfWeek[0] = pSunday;
    daysOfWeek[1] = pMonday;
    daysOfWeek[2] = pTuesday;
    daysOfWeek[3] = pWednesday;
    daysOfWeek[4] = pThursday;
    daysOfWeek[5] = pFriday;
    daysOfWeek[6] = pSaturday;
}

bool CDate::DayOfWeekFilter()
{
    TimeCurrent(currentDateTime);
    // return (daysOfWeek[currentDateTime.day_of_week]);
    if(daysOfWeek[currentDateTime.day_of_week]) 
        return true;
    else
        Print(__FUNCTION__ + "(): Error - Check lại DayOfWeekFilter()", GetLastError());
        return false;
}

bool CDate::IsTradingDay(string &pReport)
{
    TimeCurrent(currentDateTime);
    int dayOfWeek = DayOfWeek();
    int hour = Hour();
    
    // Nếu là thứ 7 hoặc CN thì return false để dừng EA
    if(dayOfWeek == 0 || dayOfWeek == 6)
    {
        StringAdd(pReport,"Today is a non-trading day (Saturday or Sunday). EA will stop processing. " + "\n");
        // Print("Today is a non-trading day (Saturday or Sunday)");
        return false;
    }
    // Thứ Hai: chỉ bắt đầu giao dịch từ 7h
    // if (dayOfWeek == 1 && hour < 7)
    // {
    //     Print("Chưa đến giờ giao dịch sáng Thứ Hai, EA sẽ ngủ 1 giờ.");
    //     Sleep(3600);  // Ngủ 1 giờ
    //     return false;
    // }
    
    return true; // Cho phép EA hoạt động vào các ngày khác
}

bool CDate::IsTradingTime()
{
    TimeCurrent(currentDateTime);
    int dayOfWeek = DayOfWeek();
    int hour = Hour();

    // Kiểm tra nếu là Thứ Bảy hoặc Chủ Nhật
    if (dayOfWeek == 0 || dayOfWeek == 6)
    {
        Print("Ngoài giờ giao dịch, EA sẽ ngủ đến thứ Hai.");
        Sleep(3600 * 24);  // Ngủ 1 ngày
        return false;
    }

    // Thứ Hai: chỉ bắt đầu giao dịch từ 7h
    if (dayOfWeek == 1 && hour < 7)
    {
        Print("Chưa đến giờ giao dịch sáng Thứ Hai, EA sẽ ngủ 1 giờ.");
        Sleep(3600);  // Ngủ 1 giờ
        return false;
    }

    // Thứ Sáu: chỉ giao dịch đến 17h
    if (dayOfWeek == 5 && hour >= 17)
    {
        Print("Hết giờ giao dịch chiều Thứ Sáu, EA sẽ ngủ đến thứ Hai.");
        Sleep(3600 * 24);  // Ngủ 1 ngày
        return false;
    }

    return true; // Trong giờ giao dịch
}



