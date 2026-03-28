//+------------------------------------------------------------------+
//|                                                info_display.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_INFO_DISPLAY_MQH
#define JINPA_INFO_DISPLAY_MQH

//+------------------------------------------------------------------+
//| CInfoDisplay — Hiển thị stats trên chart (góc trên-phải)        |
//+------------------------------------------------------------------+
class CInfoDisplay
{
private:
    int chart_width;
    int chart_height;

    // Tạo label nếu chưa có, cập nhật text mỗi lần gọi
    void SetText(string objName, string text, int x, int y, int fontSize, color clrText);

public:
    CInfoDisplay();

    void UpdateDisplay(double dailyDD, double monthlyDD, int openBuy, int openSell,
                       double balance, double risk, int spread, ulong magicNumber);
    void UpdateButtonTooltips(double askPrice, double bidPrice);
    void ClearDisplay();
};

CInfoDisplay::CInfoDisplay()
{
    chart_width  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
}

void CInfoDisplay::SetText(string objName, string text, int x, int y, int fontSize, color clrText)
{
    // Chỉ tạo object một lần, những lần sau chỉ update text
    if(ObjectFind(0, objName) < 0)
    {
        if(!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
        {
            Print(__FUNCTION__, " - Error creating ", objName, ": ", GetLastError());
            return;
        }
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, objName, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_COLOR,     clrText);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE,  fontSize);
    }
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
}

void CInfoDisplay::UpdateDisplay(double dailyDD, double monthlyDD, int openBuy, int openSell,
                                  double balance, double risk, int spread, ulong magicNumber)
{
    color textColor = C'193,191,184';
    int   x         = (int)(chart_width * 0.01);

    Comment("EA Manual Trading | Magic: ", magicNumber);

    SetText("InfoBalance",  "Balance: " + DoubleToString(balance, 2) + "$ | Risk: " + DoubleToString(risk, 2) + "%",
            x, (int)(chart_height * 0.05), 8, textColor);

    SetText("InfoDailyDD",  "Daily DD: "   + DoubleToString(dailyDD,   2) + "%",
            x, (int)(chart_height * 0.08), 8, textColor);

    SetText("InfoMonthlyDD","Monthly DD: " + DoubleToString(monthlyDD, 2) + "%",
            x, (int)(chart_height * 0.11), 8, textColor);

    SetText("InfoSpread",   "Spread: "     + IntegerToString(spread)     + " pts",
            x, (int)(chart_height * 0.14), 8, textColor);

    SetText("InfoOpenBuy",  "Open Buy: "   + IntegerToString(openBuy),
            x, (int)(chart_height * 0.17), 8, textColor);

    SetText("InfoOpenSell", "Open Sell: "  + IntegerToString(openSell),
            x, (int)(chart_height * 0.20), 8, textColor);
}

void CInfoDisplay::UpdateButtonTooltips(double askPrice, double bidPrice)
{
    ObjectSetString(0, "Btn Buy",        OBJPROP_TOOLTIP, "Buy at: "  + DoubleToString(askPrice, 5));
    ObjectSetString(0, "Btn Buy Stop",   OBJPROP_TOOLTIP, "Buy Stop");
    ObjectSetString(0, "Btn Buy Limit",  OBJPROP_TOOLTIP, "Buy Limit");
    ObjectSetString(0, "Btn Sell",       OBJPROP_TOOLTIP, "Sell at: " + DoubleToString(bidPrice, 5));
    ObjectSetString(0, "Btn Sell Stop",  OBJPROP_TOOLTIP, "Sell Stop");
    ObjectSetString(0, "Btn Sell Limit", OBJPROP_TOOLTIP, "Sell Limit");
}

void CInfoDisplay::ClearDisplay()
{
    ObjectDelete(0, "InfoBalance");
    ObjectDelete(0, "InfoDailyDD");
    ObjectDelete(0, "InfoMonthlyDD");
    ObjectDelete(0, "InfoSpread");
    ObjectDelete(0, "InfoOpenBuy");
    ObjectDelete(0, "InfoOpenSell");
    Comment("");
}

#endif
