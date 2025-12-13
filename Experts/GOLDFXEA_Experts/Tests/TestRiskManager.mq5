// TestRiskManager.mq5
#property script_show_inputs
#include <GoldFXEAProject/Utils/Logger.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>

void OnStart()
{
    CLogger* logger = new CLogger(LOG_LEVEL_INFO, false, true);
    logger.Initialize();
    
    CRiskManager* risk = new CRiskManager(logger);
    risk.Initialize();
    risk.SetRiskParameters(2.0, 5.0, 20.0, 10);
    
    // Get current symbol from chart
    string symbol = _Symbol;
    Print("Testing with symbol: ", symbol);
    
    // Calculate stop loss in points (not pips)
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // For 50 pips stop loss
    double slPips = 50.0;
    double slPoints = slPips * 10; // For 5-digit broker (e.g., 1.10500)
    
    // Adjust for 3-digit brokers (e.g., JPY pairs)
    if(digits == 3 || digits == 2)
        slPoints = slPips;
    
    Print("Stop Loss: ", slPips, " pips = ", slPoints, " points");
    
    // Test lot size calculation
    double lots = risk.CalculateLotSize(symbol, slPoints);
    Print("Calculated lot size for ", slPips, " pip SL: ", lots);
    
    // Test trade permission
    string reason;
    bool canTrade = risk.CanOpenNewTrade(symbol, lots, reason);
    Print("Can open trade: ", (canTrade ? "YES" : "NO"), " Reason: ", reason);
    
    // Display account info
    Print("Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
    Print("Account Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
    Print("Free Margin: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
    
    delete risk;
    delete logger;
}