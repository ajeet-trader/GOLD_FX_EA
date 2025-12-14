//+------------------------------------------------------------------+
//|                                               SymbolManager.mqh |
//|                        Copyright 2023, YOUR_NAME_OR_COMPANY_NAME |
//|                                      https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, YOUR_NAME_OR_COMPANY_NAME"
#property link      "https://www.example.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CSymbolManager class                                             |
//| Responsible for finding the correct, broker-specific symbol.     |
//+------------------------------------------------------------------+
class CSymbolManager
{
private:
    static string m_suffix_list[];

public:
    //--- Default constructor
    CSymbolManager() {}
    //--- Destructor
    ~CSymbolManager() {}

    //--- Method to get the correct symbol
    static string GetCorrectSymbol(string baseSymbol);
};

//--- Array of common suffixes
string CSymbolManager::m_suffix_list[] = {"", "m", ".m", "c", ".c", "-pro", ".pro", "-ecn", ".ecn"};

//+------------------------------------------------------------------+
//| Gets the correct symbol by trying different suffixes.            |
//+------------------------------------------------------------------+
string CSymbolManager::GetCorrectSymbol(string baseSymbol)
{
    // First, check if the base symbol exists
    if(SymbolInfoString(baseSymbol, SYMBOL_DESCRIPTION) != "")
    {
        return baseSymbol;
    }

    // If not, iterate through common suffixes
    for(int i = 0; i < ArraySize(m_suffix_list); i++)
    {
        string newSymbol = baseSymbol + m_suffix_list[i];
        if(SymbolInfoString(newSymbol, SYMBOL_DESCRIPTION) != "")
        {
            Print("Symbol found: ", newSymbol);
            return newSymbol;
        }
    }

    // If no symbol is found, return the base symbol (which will likely fail later, but it's a fallback)
    Print("Warning: Could not find a valid symbol for ", baseSymbol);
    return baseSymbol;
}
//+------------------------------------------------------------------+
