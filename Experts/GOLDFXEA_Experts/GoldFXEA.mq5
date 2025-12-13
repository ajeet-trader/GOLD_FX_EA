//+------------------------------------------------------------------+
//|                                                    GoldFXEA.mq5   |
//|                                  JULES Trading Systems            |
//|                                  https://julestrading.com         |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"
#property version   "1.00"
#property description "Multi-Asset, Multi-Strategy, Multi-Indicator Trading EA"
#property description "Phase 1: Core Framework Implementation"

// Include core engine
#include <GoldFXEAProject/Core/EAEngine.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== EA Configuration ==="
input bool     EnableTrading = true;              // Enable Live Trading
input bool     EnableLogging = true;              // Enable Detailed Logging
input ENUM_LOG_LEVEL LogLevel = LOG_LEVEL_INFO;   // Logging Level

input group "=== Risk Management ==="
input double   RiskPercentPerTrade = 1.5;         // Risk Per Trade (%)
input double   MaxDailyLoss = 5.0;                // Max Daily Loss (%)
input double   MaxDrawdown = 20.0;                // Max Drawdown (%)
input int      MaxOpenTrades = 10;                // Max Open Trades

input group "=== Strategy Selection ==="
input bool     EnableTrendFollowing = true;       // Enable Trend Following
input bool     EnableBreakout = false;            // Enable Breakout
input bool     EnableMeanReversion = false;       // Enable Mean Reversion
input bool     EnableScalping = false;            // Enable Scalping

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CEAEngine* g_engine = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Print banner
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║            GOLD FX EA - JULES Trading Systems             ║");
    Print("║                  Phase 1: Core Framework                  ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    
    // Create EA engine instance
    g_engine = new CEAEngine();
    
    if(g_engine == NULL)
    {
        Print("ERROR: Failed to create EA engine instance");
        return INIT_FAILED;
    }
    
    // Configure EA engine
    EAConfig config;
    config.enableTrading = EnableTrading;
    config.enableLogging = EnableLogging;
    config.logLevel = LogLevel;
    config.riskPercentPerTrade = RiskPercentPerTrade;
    config.maxDailyLoss = MaxDailyLoss;
    config.maxDrawdown = MaxDrawdown;
    config.maxOpenTrades = MaxOpenTrades;
    config.enableTrendFollowing = EnableTrendFollowing;
    config.enableBreakout = EnableBreakout;
    config.enableMeanReversion = EnableMeanReversion;
    config.enableScalping = EnableScalping;
    
    // Initialize EA engine
    if(!g_engine.Initialize(config))
    {
        Print("ERROR: Failed to initialize EA engine");
        delete g_engine;
        g_engine = NULL;
        return INIT_FAILED;
    }
    
    Print("✓ GoldFXEA initialized successfully");
    Print("✓ Trading Status: ", (EnableTrading ? "ENABLED" : "DISABLED"));
    Print("✓ Risk Per Trade: ", RiskPercentPerTrade, "%");
    Print("✓ Max Open Trades: ", MaxOpenTrades);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("╔════════════════════════════════════════════════════════════╗");
    Print("║              GoldFXEA Shutdown Initiated                   ║");
    Print("╚════════════════════════════════════════════════════════════╝");
    
    // Get deinit reason
    string reasonText = "";
    switch(reason)
    {
        case REASON_PROGRAM:     reasonText = "Expert removed from chart"; break;
        case REASON_REMOVE:      reasonText = "Expert removed from chart"; break;
        case REASON_RECOMPILE:   reasonText = "Expert recompiled"; break;
        case REASON_CHARTCHANGE: reasonText = "Chart period changed"; break;
        case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
        case REASON_PARAMETERS:  reasonText = "Input parameters changed"; break;
        case REASON_ACCOUNT:     reasonText = "Account changed"; break;
        case REASON_TEMPLATE:    reasonText = "New template applied"; break;
        case REASON_INITFAILED:  reasonText = "Initialization failed"; break;
        case REASON_CLOSE:       reasonText = "Terminal closed"; break;
        default:                 reasonText = "Unknown reason"; break;
    }
    
    Print("Deinitialize Reason: ", reasonText);
    
    // Deinitialize and cleanup EA engine
    if(g_engine != NULL)
    {
        g_engine.Deinitialize();
        delete g_engine;
        g_engine = NULL;
    }
    
    Print("✓ GoldFXEA deinitialized successfully");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Process tick if engine is initialized
    if(g_engine != NULL)
    {
        MqlTick tick;
        if(SymbolInfoTick(_Symbol, tick))
        {
            g_engine.OnTick(tick);
        }
    }
}

//+------------------------------------------------------------------+
//| Trade event function                                             |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Process trade events
    if(g_engine != NULL)
    {
        g_engine.OnTrade();
    }
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Process timer events
    if(g_engine != NULL)
    {
        g_engine.OnTimer();
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Handle chart events if needed
    if(g_engine != NULL)
    {
        // Future: Add chart event handling
    }
}
//+------------------------------------------------------------------+