//+------------------------------------------------------------------+
//|                                      magic_number_resolver.mqh |
//|                     Deterministic JINPA magic number resolution |
//+------------------------------------------------------------------+
#ifndef JINPA_MAGIC_NUMBER_RESOLVER_MQH
#define JINPA_MAGIC_NUMBER_RESOLVER_MQH

#define JINPA_FALLBACK_MAGIC 109999

class CMagicNumberResolver
{
private:
    static bool MatchesCanonical(const string symbol, const string canonical);

public:
    static bool Resolve(const string rawSymbol, ulong &magicNumber,
                        string &canonicalSymbol);
};

bool CMagicNumberResolver::MatchesCanonical(const string symbol,
                                             const string canonical)
{
    return symbol == canonical
           || symbol == "M" + canonical
           || symbol == canonical + "M"
           || symbol == canonical + ".A"
           || symbol == canonical + ".PRO"
           || symbol == canonical + "#"
           || symbol == canonical + "_M1_QDM";
}

bool CMagicNumberResolver::Resolve(const string rawSymbol, ulong &magicNumber,
                                    string &canonicalSymbol)
{
    string symbol = rawSymbol;
    StringToUpper(symbol);

    if(MatchesCanonical(symbol, "XAUUSD")) { canonicalSymbol = "XAUUSD"; magicNumber = 101001; return true; }
    if(MatchesCanonical(symbol, "BTCUSD")) { canonicalSymbol = "BTCUSD"; magicNumber = 101002; return true; }
    if(MatchesCanonical(symbol, "ETHUSD")) { canonicalSymbol = "ETHUSD"; magicNumber = 101003; return true; }
    if(MatchesCanonical(symbol, "EURUSD")) { canonicalSymbol = "EURUSD"; magicNumber = 101004; return true; }
    if(MatchesCanonical(symbol, "USDJPY")) { canonicalSymbol = "USDJPY"; magicNumber = 101005; return true; }
    if(MatchesCanonical(symbol, "US30"))   { canonicalSymbol = "US30";   magicNumber = 101006; return true; }

    canonicalSymbol = "UNKNOWN";
    magicNumber = JINPA_FALLBACK_MAGIC;
    return false;
}

#endif
