//+------------------------------------------------------------------+
//|                                                                         UIManager.mqh |
//|                                                                                         duyng |
//|                                                   https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

#ifndef JINPA_UI_MANAGER_MQH
#define JINPA_UI_MANAGER_MQH

#include <Controls/Button.mqh>
#include <Controls/Label.mqh>

//+------ Button Names ------+//
#define BTN_BUY_NAME "Btn Buy"
#define BTN_BUY_STOP_NAME "Btn Buy Stop"
#define BTN_BUY_LIMIT_NAME "Btn Buy Limit"
#define BTN_CANCEL_BUY_NAME "Btn Cancel Buy"
#define BTN_CLOSE_BUY_NAME "Btn Close Buy"

#define BTN_SELL_NAME "Btn Sell"
#define BTN_SELL_STOP_NAME "Btn Sell Stop"
#define BTN_SELL_LIMIT_NAME "Btn Sell Limit"
#define BTN_CANCEL_SELL_NAME "Btn Cancel Sell"
#define BTN_CLOSE_SELL_NAME "Btn Close Sell"

//+------------------------------------------------------------------+
//| CUIManager Class                                                 |
//+------------------------------------------------------------------+
class CUIManager
{
private:
    // Button Objects
    CButton btnBuy;
    CButton btnBuyStop;
    CButton btnBuyLimit;
    CButton btnCancelBuy;
    CButton btnCloseBuy;
    
    CButton btnSell;
    CButton btnSellStop;
    CButton btnSellLimit;
    CButton btnCancelSell;
    CButton btnCloseSell;
    
    // Chart dimensions
    int chart_width;
    int chart_height;
    
    // Button dimensions (percentage of chart)
    double BtnHeightPercent;
    double BtnWidthBuyPercent;
    double BtnWidthSellPercent;
    double BtnBuyStartPercent;
    double BtnSellStartPercent;
    double BtnStartYPercent;
    
    // BUY button colors
    color BtnBuyTextColor;
    color BtnBuyBackColor;
    color BtnBuyBorderColor;
    color BtnBuyCancelBackColor;
    
    // SELL button colors
    color BtnSellTextColor;
    color BtnSellBackColor;
    color BtnSellBorderColor;
    color BtnSellCancelBackColor;
    
public:
    // Constructor
    CUIManager();
    
    // Methods
    void Initialize();
    void CreateAllButtons();
    void Destroy(const int reason);
    void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
    
    // Button state getters
    bool BuyPressed() { return btnBuy.Pressed(); }
    bool BuyStopped() { return btnBuyStop.Pressed(); }
    bool BuyLimited() { return btnBuyLimit.Pressed(); }
    bool BuyCancelled() { return btnCancelBuy.Pressed(); }
    bool BuyClosed() { return btnCloseBuy.Pressed(); }
    
    bool SellPressed() { return btnSell.Pressed(); }
    bool SellStopped() { return btnSellStop.Pressed(); }
    bool SellLimited() { return btnSellLimit.Pressed(); }
    bool SellCancelled() { return btnCancelSell.Pressed(); }
    bool SellClosed() { return btnCloseSell.Pressed(); }
    
    // Reset button states
    void ResetBuyPressed() { btnBuy.Pressed(false); }
    void ResetBuyStopped() { btnBuyStop.Pressed(false); }
    void ResetBuyLimited() { btnBuyLimit.Pressed(false); }
    void ResetBuyCancelled() { btnCancelBuy.Pressed(false); }
    void ResetBuyClosed() { btnCloseBuy.Pressed(false); }
    
    void ResetSellPressed() { btnSell.Pressed(false); }
    void ResetSellStopped() { btnSellStop.Pressed(false); }
    void ResetSellLimited() { btnSellLimit.Pressed(false); }
    void ResetSellCancelled() { btnCancelSell.Pressed(false); }
    void ResetSellClosed() { btnCloseSell.Pressed(false); }
    
    // Tooltip methods
    void SetBuyTooltip(string tooltip) { ObjectSetString(0, BTN_BUY_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetBuyStopTooltip(string tooltip) { ObjectSetString(0, BTN_BUY_STOP_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetBuyLimitTooltip(string tooltip) { ObjectSetString(0, BTN_BUY_LIMIT_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetCancelBuyTooltip(string tooltip) { ObjectSetString(0, BTN_CANCEL_BUY_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetCloseBuyTooltip(string tooltip) { ObjectSetString(0, BTN_CLOSE_BUY_NAME, OBJPROP_TOOLTIP, tooltip); }
    
    void SetSellTooltip(string tooltip) { ObjectSetString(0, BTN_SELL_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetSellStopTooltip(string tooltip) { ObjectSetString(0, BTN_SELL_STOP_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetSellLimitTooltip(string tooltip) { ObjectSetString(0, BTN_SELL_LIMIT_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetCancelSellTooltip(string tooltip) { ObjectSetString(0, BTN_CANCEL_SELL_NAME, OBJPROP_TOOLTIP, tooltip); }
    void SetCloseSellTooltip(string tooltip) { ObjectSetString(0, BTN_CLOSE_SELL_NAME, OBJPROP_TOOLTIP, tooltip); }
};

//+------------------------------------------------------------------+
//| CUIManager Constructor                                           |
//+------------------------------------------------------------------+
CUIManager::CUIManager()
{
    chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    
    // Button dimensions (percentage of chart)
    BtnHeightPercent = 0.035;
    BtnWidthBuyPercent = 0.08;
    BtnWidthSellPercent = 0.08;
    BtnBuyStartPercent = 0.03;
    BtnSellStartPercent = 0.10;
    BtnStartYPercent = 0.10;
    
    // BUY button colors
    BtnBuyTextColor = clrWhite;
    BtnBuyBackColor = C'33,72,72';
    BtnBuyBorderColor = clrBlack;
    BtnBuyCancelBackColor = C'242, 220, 162';
    
    // SELL button colors
    BtnSellTextColor = clrWhite;
    BtnSellBackColor = C'112,43,43';
    BtnSellBorderColor = clrBlack;
    BtnSellCancelBackColor = C'242, 220, 162';
}

//+------------------------------------------------------------------+
//| Initialize UI Manager                                            |
//+------------------------------------------------------------------+
void CUIManager::Initialize()
{
    CreateAllButtons();
}

//+------------------------------------------------------------------+
//| Create All Buttons                                               |
//+------------------------------------------------------------------+
void CUIManager::CreateAllButtons()
{
    // Calculate dimensions and positions
    double btn_height_px = chart_height * BtnHeightPercent;
    double btn_width_buy_px = chart_width * BtnWidthBuyPercent;
    double btn_width_sell_px = chart_width * BtnWidthSellPercent;
    double btn_buy_x_start = chart_width * BtnBuyStartPercent;
    double btn_sell_x_start = chart_width * BtnSellStartPercent;
    double btn_y_start = chart_height * BtnStartYPercent;
    
    // Create BUY buttons
    btnBuy.Create(0, BTN_BUY_NAME, 0, int(btn_buy_x_start), int(btn_y_start), 
                  int(btn_buy_x_start + btn_width_buy_px), int(btn_y_start + btn_height_px));
    btnBuy.Text("Buy");
    btnBuy.Color(BtnBuyTextColor);
    btnBuy.ColorBackground(BtnBuyBackColor);
    btnBuy.ColorBorder(BtnBuyBorderColor);
    btnBuy.FontSize(11);

    double btn_y_offset = btn_height_px;
    btnBuyStop.Create(0, BTN_BUY_STOP_NAME, 0, int(btn_buy_x_start), int(btn_y_start + btn_y_offset), 
                      int(btn_buy_x_start + btn_width_buy_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnBuyStop.Text("Buy Stop");
    btnBuyStop.Color(BtnBuyTextColor);
    btnBuyStop.ColorBackground(BtnBuyBackColor);
    btnBuyStop.ColorBorder(BtnBuyBorderColor);
    btnBuyStop.FontSize(9);

    btn_y_offset *= 2;
    btnBuyLimit.Create(0, BTN_BUY_LIMIT_NAME, 0, int(btn_buy_x_start), int(btn_y_start + btn_y_offset), 
                       int(btn_buy_x_start + btn_width_buy_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnBuyLimit.Text("Buy Limit");
    btnBuyLimit.Color(BtnBuyTextColor);
    btnBuyLimit.ColorBackground(BtnBuyBackColor);
    btnBuyLimit.ColorBorder(BtnBuyBorderColor);
    btnBuyLimit.FontSize(9);

    btn_y_offset = btn_height_px * 2.85;
    btnCancelBuy.Create(0, BTN_CANCEL_BUY_NAME, 0, int(btn_buy_x_start), int(btn_y_start + btn_y_offset), 
                        int(btn_buy_x_start + btn_width_buy_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnCancelBuy.Text("Cancel Buy Order");
    btnCancelBuy.Color(BtnBuyBorderColor);
    btnCancelBuy.ColorBackground(BtnBuyCancelBackColor);
    btnCancelBuy.ColorBorder(BtnBuyBorderColor);
    btnCancelBuy.FontSize(7);
    ObjectSetString(0, BTN_CANCEL_BUY_NAME, OBJPROP_TOOLTIP, "Cancel Pending Order");

    btn_y_offset = btn_height_px * 3.75;
    btnCloseBuy.Create(0, BTN_CLOSE_BUY_NAME, 0, int(btn_buy_x_start), int(btn_y_start + btn_y_offset), 
                       int(btn_buy_x_start + btn_width_buy_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnCloseBuy.Text("Close Buy");
    btnCloseBuy.Color(BtnBuyBorderColor);
    btnCloseBuy.ColorBackground(clrWhite);
    btnCloseBuy.ColorBorder(BtnBuyBorderColor);
    btnCloseBuy.FontSize(9);
    ObjectSetString(0, BTN_CLOSE_BUY_NAME, OBJPROP_TOOLTIP, "Close Buy First");

    // Create SELL buttons
    btnSell.Create(0, BTN_SELL_NAME, 0, int(btn_sell_x_start), int(btn_y_start), 
                   int(btn_sell_x_start + btn_width_sell_px), int(btn_y_start + btn_height_px));
    btnSell.Text("Sell");
    btnSell.Color(BtnSellTextColor);
    btnSell.ColorBackground(BtnSellBackColor);
    btnSell.ColorBorder(BtnSellBorderColor);
    btnSell.FontSize(11);

    btn_y_offset = btn_height_px;
    btnSellStop.Create(0, BTN_SELL_STOP_NAME, 0, int(btn_sell_x_start), int(btn_y_start + btn_y_offset), 
                       int(btn_sell_x_start + btn_width_sell_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnSellStop.Text("Sell Stop");
    btnSellStop.Color(BtnSellTextColor);
    btnSellStop.ColorBackground(BtnSellBackColor);
    btnSellStop.ColorBorder(BtnSellBorderColor);
    btnSellStop.FontSize(9);

    btn_y_offset *= 2;
    btnSellLimit.Create(0, BTN_SELL_LIMIT_NAME, 0, int(btn_sell_x_start), int(btn_y_start + btn_y_offset), 
                        int(btn_sell_x_start + btn_width_sell_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnSellLimit.Text("Sell Limit");
    btnSellLimit.Color(BtnSellTextColor);
    btnSellLimit.ColorBackground(BtnSellBackColor);
    btnSellLimit.ColorBorder(BtnSellBorderColor);
    btnSellLimit.FontSize(9);

    btn_y_offset = btn_height_px * 2.85;
    btnCancelSell.Create(0, BTN_CANCEL_SELL_NAME, 0, int(btn_sell_x_start), int(btn_y_start + btn_y_offset), 
                         int(btn_sell_x_start + btn_width_sell_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnCancelSell.Text("Cancel Sell Order");
    btnCancelSell.Color(BtnSellBorderColor);
    btnCancelSell.ColorBackground(BtnSellCancelBackColor);
    btnCancelSell.ColorBorder(BtnSellBorderColor);
    btnCancelSell.FontSize(7);
    ObjectSetString(0, BTN_CANCEL_SELL_NAME, OBJPROP_TOOLTIP, "Cancel Pending Order");

    btn_y_offset = btn_height_px * 3.75;
    btnCloseSell.Create(0, BTN_CLOSE_SELL_NAME, 0, int(btn_sell_x_start), int(btn_y_start + btn_y_offset), 
                        int(btn_sell_x_start + btn_width_sell_px), int(btn_y_start + btn_y_offset + btn_height_px));
    btnCloseSell.Text("Close Sell");
    btnCloseSell.Color(BtnSellBorderColor);
    btnCloseSell.ColorBackground(clrWhite);
    btnCloseSell.ColorBorder(BtnSellBorderColor);
    btnCloseSell.FontSize(9);
    ObjectSetString(0, BTN_CLOSE_SELL_NAME, OBJPROP_TOOLTIP, "Close Sell First");

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Destroy UI Manager                                               |
//+------------------------------------------------------------------+
void CUIManager::Destroy(const int reason)
{
    btnBuy.Destroy(reason);
    btnBuyStop.Destroy(reason);
    btnBuyLimit.Destroy(reason);
    btnCancelBuy.Destroy(reason);
    btnCloseBuy.Destroy(reason);
    
    btnSell.Destroy(reason);
    btnSellStop.Destroy(reason);
    btnSellLimit.Destroy(reason);
    btnCancelSell.Destroy(reason);
    btnCloseSell.Destroy(reason);
}

//+------------------------------------------------------------------+
//| OnChartEvent Handler                                             |
//+------------------------------------------------------------------+
void CUIManager::OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    btnBuy.OnEvent(id, lparam, dparam, sparam);
    btnBuyStop.OnEvent(id, lparam, dparam, sparam);
    btnBuyLimit.OnEvent(id, lparam, dparam, sparam);
    btnCancelBuy.OnEvent(id, lparam, dparam, sparam);
    btnCloseBuy.OnEvent(id, lparam, dparam, sparam);
    
    btnSell.OnEvent(id, lparam, dparam, sparam);
    btnSellStop.OnEvent(id, lparam, dparam, sparam);
    btnSellLimit.OnEvent(id, lparam, dparam, sparam);
    btnCancelSell.OnEvent(id, lparam, dparam, sparam);
    btnCloseSell.OnEvent(id, lparam, dparam, sparam);

    // Handle chart change
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        if(ObjectFind(0, BTN_BUY_NAME) < 0)
        {
            Print("Chart changed. Recreating buttons...");
            CreateAllButtons();
        }
    }

    // Handle object delete event
    if(id == CHARTEVENT_OBJECT_DELETE)
    {
        if(sparam == BTN_BUY_NAME || sparam == BTN_BUY_STOP_NAME || 
           sparam == BTN_BUY_LIMIT_NAME || sparam == BTN_CANCEL_BUY_NAME || 
           sparam == BTN_CLOSE_BUY_NAME || sparam == BTN_SELL_NAME || 
           sparam == BTN_SELL_STOP_NAME || sparam == BTN_SELL_LIMIT_NAME || 
           sparam == BTN_CANCEL_SELL_NAME || sparam == BTN_CLOSE_SELL_NAME)
        {
            Print("Button deleted: ", sparam, ". Recreating all buttons...");
            CreateAllButtons();
        }
    }
}

#endif
