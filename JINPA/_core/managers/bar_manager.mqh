//+------------------------------------------------------------------+
//|                                                                     bar_manager.mqh |
//|                                                                                        duyng |
//|                                                  https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

//+------------------------------------------------------------------+
//| CBar Class - Bar Data (OHLC, time, Volume, Spread)               |
//+------------------------------------------------------------------+
class CBar
{
	public:
		MqlRates          bar[];

		                  CBar(void);
		
		void              Refresh(string pSymbol,ENUM_TIMEFRAMES pTimeframe,int pBarsToRefresh);

		datetime          Time(int pShift)        { return(bar[pShift].time);         }
		double            Open(int pShift)        { return(bar[pShift].open);         }
		double            High(int pShift)        { return(bar[pShift].high);         }
		double            Low(int pShift)         { return(bar[pShift].low);          }
		double            Close(int pShift)       { return(bar[pShift].close);        }
		long              TickVolume(int pShift)  { return(bar[pShift].tick_volume);  }
		int               Spread(int pShift)      { return(bar[pShift].spread);       }	
		long              Volume(int pShift)      { return(bar[pShift].real_volume);  } 
};


CBar::CBar(void)
{
	ArraySetAsSeries(bar,true);
}


void CBar::Refresh(string pSymbol,ENUM_TIMEFRAMES pTimeframe,int pBarsToRefresh)
{
	CopyRates(pSymbol,pTimeframe,0,pBarsToRefresh,bar);
}
