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
    //--- Gets alternative base symbols for common indices.
    static void GetAlternativeBaseSymbols(string baseSymbol, string &alternatives[])
    {
        // MQL5 requires arrays to be passed by reference to be modified
        string normalizedBase = baseSymbol;
        StringToUpper(normalizedBase);

        if(normalizedBase == "SP500")
        {
            ArrayResize(alternatives, 4);
            alternatives[0] = "SP500";
            alternatives[1] = "US500";
            alternatives[2] = "SPX500";
            alternatives[3] = "USA500";
        }
        else
        {
            ArrayResize(alternatives, 1);
            alternatives[0] = baseSymbol;
        }
    }

public:
    //--- Default constructor
    CSymbolManager() {}
    //--- Destructor
    ~CSymbolManager() {}

    //--- Method to get the correct symbol
    static string GetCorrectSymbol(string baseSymbol)
    {
        string baseSymbols[];
        GetAlternativeBaseSymbols(baseSymbol, baseSymbols);
        
        string suffixes[] = {"", "m", ".m", "c", ".c", "-pro", ".pro", "-ecn", ".ecn", ".cfd", "_cfd"};

        // Iterate through all possible base symbols (e.g., SP500, US500)
        for(int j = 0; j < ArraySize(baseSymbols); j++)
        {
            string currentBase = baseSymbols[j];

            // Iterate through common suffixes for that base
            for(int i = 0; i < ArraySize(suffixes); i++)
            {
                string newSymbol = currentBase + suffixes[i];
                // Check if symbol exists and is available in the Market Watch
                if(SymbolInfoString(newSymbol, SYMBOL_DESCRIPTION) != "" && SymbolSelect(newSymbol, true))
                {
                    Print("Symbol found: ", newSymbol);
                    return newSymbol;
                }
            }
        }

        // If no symbol is found, return the original base symbol
        Print("Warning: Could not find a valid symbol for ", baseSymbol);
        return baseSymbol;
    }
};
//+------------------------------------------------------------------+