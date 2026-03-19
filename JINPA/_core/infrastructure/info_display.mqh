//+------------------------------------------------------------------+
//|                                                InfoDisplay.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

//+------------------------------------------------------------------+
//| CInfoDisplay Class                                               |
//+------------------------------------------------------------------+
class CInfoDisplay
{
private:
    int chart_width;
    int chart_height;
    
    bool CreateText(string objName, string text, int x, int y, int fontSize, color clrText, string font);

public:
    CInfoDisplay();
    
    void UpdateDisplay(double dailyDD, double monthlyDD, int openBuy, int openSell, 
                      double balance, double risk, int spread, ulong magicNumber);
    void UpdateButtonTooltips(double askPrice, double bidPrice);
    void ClearDisplay();
};

//+------------------------------------------------------------------+
//| CInfoDisplay Constructor                                         |
//+------------------------------------------------------------------+
CInfoDisplay::CInfoDisplay()
{
    chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
}

//+------------------------------------------------------------------+
//| Create Text Object                                               |
//+------------------------------------------------------------------+
bool CInfoDisplay::CreateText(string objName, string text, int x, int y, int fontSize, color clrText, string font)
{
    ResetLastError();
    if(!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
    {
        Print(__FUNCTION__, "Error creating object ", GetLastError());
        return(false);
    }
    
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrText);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
    
    return(true);
}

//+------------------------------------------------------------------+
//| Update Display Information                                       |
//+------------------------------------------------------------------+
void CInfoDisplay::UpdateDisplay(double dailyDD, double monthlyDD, int openBuy, int openSell, 
                                 double balance, double risk, int spread, ulong magicNumber)
{
    color textColor = C'193,191,184';
    
    // Build info strings
    Comment("EA Manual Trading; Magic Number: ", magicNumber);
    
    string strBalanceAndRisk = "Account Balance: " + DoubleToString(balance, 2) + 
                               "$ | Risk: " + DoubleToString(risk, 2) + "%";
    string strMaxDDDaily = "Max Drawdown Daily: " + DoubleToString(dailyDD, 2) + "%";
    string strMaxDDMonthly = "Max Drawdown Monthly: " + DoubleToString(monthlyDD, 2) + "%";
    string strSpread = "Spread: " + IntegerToString(spread, 2) + " points";
    string strOpenBuy = "Open Buy: " + IntegerToString(openBuy);
    string strOpenSell = "Open Sell: " + IntegerToString(openSell);
    
    // Display info
    CreateText("Text1", strBalanceAndRisk, int(chart_width * 0.01), int(chart_height * 0.05), 8, textColor, "Arial");
    CreateText("Text2", strMaxDDDaily, int(chart_width * 0.01), int(chart_height * 0.08), 8, textColor, "Arial");
    CreateText("Text3", strMaxDDMonthly, int(chart_width * 0.01), int(chart_height * 0.11), 8, textColor, "Arial");
    CreateText("Text4", strSpread, int(chart_width * 0.01), int(chart_height * 0.14), 8, textColor, "Arial");
    CreateText("Text5", strOpenBuy, int(chart_width * 0.01), int(chart_height * 0.17), 8, textColor, "Arial");
    CreateText("Text6", strOpenSell, int(chart_width * 0.01), int(chart_height * 0.20), 8, textColor, "Arial");
}

//+------------------------------------------------------------------+
//| Update Button Tooltips                                           |
//+------------------------------------------------------------------+
void CInfoDisplay::UpdateButtonTooltips(double askPrice, double bidPrice)
{
    string strBuy = "Buy at: " + DoubleToString(askPrice, 5);
    ObjectSetString(0, "Btn Buy", OBJPROP_TOOLTIP, strBuy);
    ObjectSetString(0, "Btn Buy Stop", OBJPROP_TOOLTIP, "Buy Stop");
    ObjectSetString(0, "Btn Buy Limit", OBJPROP_TOOLTIP, "Buy Limit");

    string strSell = "Sell at: " + DoubleToString(bidPrice, 5);
    ObjectSetString(0, "Btn Sell", OBJPROP_TOOLTIP, strSell);
    ObjectSetString(0, "Btn Sell Stop", OBJPROP_TOOLTIP, "Sell Stop");
    ObjectSetString(0, "Btn Sell Limit", OBJPROP_TOOLTIP, "Sell Limit");
}

//+------------------------------------------------------------------+
//| Clear Display                                                    |
//+------------------------------------------------------------------+
void CInfoDisplay::ClearDisplay()
{
    // Delete text objects
    ObjectDelete(0, "Text1");
    ObjectDelete(0, "Text2");
    ObjectDelete(0, "Text3");
    ObjectDelete(0, "Text4");
    ObjectDelete(0, "Text5");
    ObjectDelete(0, "Text6");
    
    Comment("");
}
