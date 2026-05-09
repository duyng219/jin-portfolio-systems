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
    void UpdatePoolSummary(string symbol, ulong magicNumber, double risk, double maxDrawdown);
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

void CInfoDisplay::UpdatePoolSummary(string symbol, ulong magicNumber, double risk, double maxDrawdown)
{
    chart_width  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

    color textColor = C'193,191,184';
    int   x         = (int)(chart_width * 0.01);
    int   y0        = (int)(chart_height * 0.05);
    int   rowGap    = 20;

    int running = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
        if(magicNumber > 0 && PositionGetInteger(POSITION_MAGIC) != (long)magicNumber) continue;
        running++;
    }

    HistorySelect(0, TimeCurrent());
    int    total       = 0;
    int    wins        = 0;
    double grossProfit = 0.0;
    double grossLoss   = 0.0;

    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != symbol) continue;
        if(magicNumber > 0 && HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)magicNumber) continue;
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        total++;
        if(profit > 0)
        {
            wins++;
            grossProfit += profit;
        }
        else if(profit < 0)
        {
            grossLoss += MathAbs(profit);
        }
    }

    double wr = (total > 0) ? 100.0 * wins / total : 0.0;
    double pf = (grossLoss > 0) ? grossProfit / grossLoss : 0.0;
    double ep = (total > 0) ? (grossProfit - grossLoss) / total : 0.0;

    Comment("EA Manual Trading | Magic: ", magicNumber);

    SetText("InfoPoolLine1",
            StringFormat("Balance: %.2f$  |  Equity: %.2f$",
                         AccountInfoDouble(ACCOUNT_BALANCE),
                         AccountInfoDouble(ACCOUNT_EQUITY)),
            x, y0, 8, textColor);

    SetText("InfoPoolLine2",
            StringFormat("Risk: %.2f%%", risk),
            x, y0 + rowGap, 8, textColor);

    SetText("InfoPoolLine3",
            StringFormat("Max Drawdown: %.2f%%", maxDrawdown),
            x, y0 + 2 * rowGap, 8, textColor);

    SetText("InfoPoolLine4",
            StringFormat("Running: %d", running),
            x, y0 + 3 * rowGap, 8, textColor);

    SetText("InfoPoolLine5",
            StringFormat("Trades: %d", total),
            x, y0 + 4 * rowGap, 8, textColor);

    SetText("InfoPoolLine6",
            StringFormat("EP: %.2f", ep),
            x, y0 + 5 * rowGap, 8, textColor);

    SetText("InfoPoolLine7",
            StringFormat("PF: %.2f", pf),
            x, y0 + 6 * rowGap, 8, textColor);

    SetText("InfoPoolLine8",
            StringFormat("WR: %.1f%%", wr),
            x, y0 + 7 * rowGap, 8, textColor);
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
    ObjectDelete(0, "InfoPoolLine1");
    ObjectDelete(0, "InfoPoolLine2");
    ObjectDelete(0, "InfoPoolLine3");
    ObjectDelete(0, "InfoPoolLine4");
    ObjectDelete(0, "InfoPoolLine5");
    ObjectDelete(0, "InfoPoolLine6");
    ObjectDelete(0, "InfoPoolLine7");
    ObjectDelete(0, "InfoPoolLine8");
    Comment("");
}

#endif
