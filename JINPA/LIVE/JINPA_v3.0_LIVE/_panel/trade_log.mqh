//+------------------------------------------------------------------+
//|                                                trade_log.mqh    |
//|                         JINPA v2 — Open positions log + export  |
//+------------------------------------------------------------------+
#property strict

#ifndef JINPA_TRADE_LOG_MQH
#define JINPA_TRADE_LOG_MQH

struct STradeEntry
{
    ulong    ticket;
    string   type;
    double   entry;
    double   sl;
    double   tp;
    string   comment;
    datetime time;
};

//+------------------------------------------------------------------+
//| CTradeLog — Quét vị thế mở và export CSV/JSON                   |
//+------------------------------------------------------------------+
class CTradeLog
{
private:
    STradeEntry m_data[];
    int         m_count;
    string      m_symbol;
    ulong       m_magic;

public:
    CTradeLog() : m_count(0), m_magic(0) {}

    void Init(string symbol, ulong magic)
    {
        m_symbol = symbol;
        m_magic  = magic;
    }

    // Quét lại toàn bộ vị thế đang mở của symbol + magic này
    void Refresh()
    {
        m_count = 0;
        ArrayResize(m_data, 0);

        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))                      continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol)      continue;
            if(m_magic > 0 && PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;

            ArrayResize(m_data, m_count + 1);
            m_data[m_count].ticket  = ticket;
            m_data[m_count].type    = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            m_data[m_count].entry   = PositionGetDouble(POSITION_PRICE_OPEN);
            m_data[m_count].sl      = PositionGetDouble(POSITION_SL);
            m_data[m_count].tp      = PositionGetDouble(POSITION_TP);
            m_data[m_count].comment = PositionGetString(POSITION_COMMENT);
            m_data[m_count].time    = (datetime)PositionGetInteger(POSITION_TIME);
            m_count++;
        }
    }

    int Count() const { return m_count; }

    // Format: Ticket | Comment | Time
    string GetRow(int i) const
    {
        if(i < 0 || i >= m_count) return "";
        STradeEntry e = m_data[i];
        string ticket = IntegerToString((long)e.ticket);
        if(StringLen(ticket) > 8)
            ticket = StringSubstr(ticket, StringLen(ticket) - 8);

        string comment = e.comment;
        if(StringLen(comment) > 12)
            comment = StringSubstr(comment, 0, 12);

        return StringFormat("%8s  %-12s  %s",
            ticket, comment, TimeToString(e.time, TIME_MINUTES));
    }

    // Export sang CSV (ghi vào MQL5/Files/)
    bool ExportCSV(string filename)
    {
        int fh = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
        if(fh == INVALID_HANDLE)
        {
            Print("[TradeLog] Cannot open: ", filename);
            return false;
        }
        FileWrite(fh, "Ticket", "Type", "Entry", "SL", "TP", "Comment", "Time");
        for(int i = 0; i < m_count; i++)
        {
            STradeEntry e = m_data[i];
            FileWrite(fh,
                (long)e.ticket,
                e.type,
                DoubleToString(e.entry, _Digits),
                DoubleToString(e.sl,    _Digits),
                DoubleToString(e.tp,    _Digits),
                e.comment,
                TimeToString(e.time));
        }
        FileClose(fh);
        Print("[TradeLog] CSV saved: ", filename, " (", m_count, " rows)");
        return true;
    }

    // Export sang JSON (ghi vào MQL5/Files/)
    bool ExportJSON(string filename)
    {
        int fh = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
        if(fh == INVALID_HANDLE)
        {
            Print("[TradeLog] Cannot open: ", filename);
            return false;
        }
        FileWriteString(fh, "[\n");
        for(int i = 0; i < m_count; i++)
        {
            STradeEntry e = m_data[i];
            string sep = (i < m_count - 1) ? "," : "";
            FileWriteString(fh, StringFormat(
                "  {\"ticket\":%I64u,\"type\":\"%s\","
                "\"entry\":%.5f,\"sl\":%.5f,\"tp\":%.5f,"
                "\"comment\":\"%s\",\"time\":\"%s\"}%s\n",
                e.ticket, e.type, e.entry, e.sl, e.tp,
                e.comment, TimeToString(e.time), sep));
        }
        FileWriteString(fh, "]\n");
        FileClose(fh);
        Print("[TradeLog] JSON saved: ", filename, " (", m_count, " entries)");
        return true;
    }
};

#endif
