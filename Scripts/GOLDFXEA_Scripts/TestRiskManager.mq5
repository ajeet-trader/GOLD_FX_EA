//+------------------------------------------------------------------+
//|                                           TestRiskManager.mq5    |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"
#property version   "1.00"
#property script_show_inputs

#include <GoldFXEAProject/Utils/Logger.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║         Testing GoldFXEA Risk Manager Module              ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    
    // Create logger and risk manager
    CLogger* logger = new CLogger(LOG_LEVEL_INFO, false, true);
    logger.Initialize();
    
    CRiskManager* risk = new CRiskManager(logger);
    risk.Initialize();
    risk.SetRiskParameters(2.0, 5.0, 20.0, 10);
    
    // Get current symbol
    string symbol = _Symbol;
    Print("Testing with symbol: ", symbol);
    
    // Get symbol properties
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    
    Print("═══ Symbol Information ═══");
    Print("Point: ", point);
    Print("Digits: ", digits);
    Print("Tick Size: ", tickSize);
    Print("Tick Value: ", tickValue);
    Print("Contract Size: ", contractSize);
    
    // Calculate stop loss in points (not pips!)
    // For EURUSD: 1 pip = 0.0001 = 10 points (on 5-digit broker)
    // For USDJPY: 1 pip = 0.01 = 10 points (on 3-digit broker)
    
    double stopLossPips = 50.0;
    double stopLossPoints;
    
    if(digits == 5 || digits == 3)
    {
        // 5-digit (EURUSD: 1.10500) or 3-digit (USDJPY: 110.500)
        stopLossPoints = stopLossPips * 10;
    }
    else
    {
        // 4-digit (EURUSD: 1.1050) or 2-digit (USDJPY: 110.50)
        stopLossPoints = stopLossPips;
    }
    
    Print("═══ Stop Loss Calculation ═══");
    Print("Stop Loss: ", stopLossPips, " pips");
    Print("Stop Loss: ", stopLossPoints, " points");
    Print("Stop Loss: ", stopLossPoints * point, " price units");
    
    // Test lot size calculation
    Print("\n═══ Testing Lot Size Calculation ═══");
    double lots = risk.CalculateLotSize(symbol, stopLossPoints);
    Print("Calculated Lot Size: ", lots);
    
    // Calculate expected lot size manually for verification
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskPercent = 2.0;
    double riskAmount = balance * (riskPercent / 100.0);
    Print("Account Balance: ", balance);
    Print("Risk Amount (2%): ", riskAmount);
    
    // Test trade permission
    Print("\n═══ Testing Trade Permission ═══");
    string reason;
    bool canTrade = risk.CanOpenNewTrade(symbol, lots, reason);
    Print("Can Open Trade: ", (canTrade ? "YES ✓" : "NO ✗"));
    Print("Reason: ", reason);
    
    // Display account metrics
    Print("\n═══ Account Metrics ═══");
    Print("Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
    Print("Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
    Print("Free Margin: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
    Print("Margin Level: ", AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
    
    // Test with different stop loss sizes
    Print("\n═══ Testing Different Stop Loss Sizes ═══");
    double testSLPoints[] = {100, 200, 500, 1000}; // Different SL in points
    for(int i = 0; i < ArraySize(testSLPoints); i++)
    {
        double testLots = risk.CalculateLotSize(symbol, testSLPoints[i]);
        Print("SL: ", testSLPoints[i], " points → Lots: ", testLots);
    }
    
    // Cleanup
    delete risk;
    delete logger;
    
    Print("\n╔════════════════════════════════════════════════════════════╗");
    Print("║              Risk Manager Test Complete                   ║");
    Print("╚════════════════════════════════════════════════════════════╝");
}
//+------------------------------------------------------------------+