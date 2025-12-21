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

input group "=== EURUSD Strategies ==="
input bool     Enable_EURUSD_Strat1 = false;      // Strategy 1: EMA RSI (Trend)
input bool     Enable_EURUSD_Strat2 = false;      // Strategy 2: Bollinger MeanRev
input bool     Enable_EURUSD_Strat3 = false;      // Strategy 3: ADX Trend

input group "=== GBPUSD Strategies ==="
input bool     Enable_GBPUSD_Strat1 = false;      // Strategy 1: Fib Pullback (Trend)
input bool     Enable_GBPUSD_Strat2 = false;      // Strategy 2: RSI MeanRev
input bool     Enable_GBPUSD_Strat3 = false;      // Strategy 3: London Breakout

input group "=== USDJPY Strategies ==="
input bool     Enable_USDJPY_Strat1 = false;      // Strategy 1: ADX Trend
input bool     Enable_USDJPY_Strat2 = false;      // Strategy 2: Carry Trade

input group "=== Metals Strategies (XAUUSD) ==="
input bool     Enable_XAUUSD_Strat1 = false;      // Strategy 1: ADX Trend
input bool     Enable_XAUUSD_Strat2 = false;      // Strategy 2: Bollinger MeanRev
input bool     Enable_XAUUSD_Strat3 = false;      // Strategy 3: Keltner Scalp

input group "=== Remaining Forex Strategies ==="
input bool     Enable_EURGBP_Strat1 = false;      // EURGBP Strategy 1: SMA Trend
input bool     Enable_AUDUSD_Strat1 = false;      // AUDUSD Strategy 1: Breakout MeanRev

input group "=== Other Strategies ==="
input bool     Enable_BTCUSD_Strat1 = false;      // BTCUSD Strategy 1: RSI MACD
input bool     Enable_BTCUSD_Strat2 = false;      // BTCUSD Strategy 2: ATR Breakout
input bool     Enable_ETHUSD_Strat1 = false;      // ETHUSD Strategy 1: False Breakout
input bool     Enable_SOLUSD_Strat1 = false;      // SOLUSD Strategy 1: Breakout
input bool     Enable_XRPUSD_Strat1 = false;      // XRPUSD Strategy 1: MeanRev

input bool     Enable_XAGUSD_Strat1 = false;      // XAGUSD Strategy 1: Breakout
input bool     Enable_XAUEUR_Strat1 = false;      // XAUEUR Strategy 1: Trend

input bool     Enable_NZDUSD_Strat1 = false;      // NZDUSD Strategy 1: Breakout
input bool     Enable_USDCHF_Strat1 = false;      // USDCHF Strategy 1: MeanRev
input bool     Enable_USDCAD_Strat1 = false;      // USDCAD Strategy 1: Breakout
input bool     Enable_GBPJPY_Strat1 = false;      // GBPJPY Strategy 1: Ichimoku
input bool     Enable_EURNZD_Strat1 = false;      // EURNZD Strategy 1: Scalp

input bool     Enable_SP500_MeanRev = false;      // SP500 MeanRev (Pending)

input group "=== Energy Strategies ==="
input bool     Enable_USOIL_Strat1 = false;       // USOIL Strategy 1: MeanRev
input bool     Enable_USOIL_Strat2 = false;       // USOIL Strategy 2: Trend
input bool     Enable_UKOIL_Strat1 = false;       // UKOIL Strategy 1: Breakout
input bool     Enable_NATGAS_Strat1 = false;      // NATGAS Strategy 1: Squeeze
input bool     Enable_NATGAS_Strat2 = false;      // NATGAS Strategy 2: MeanRev
input bool     Enable_COPPER_Strat1 = false;      // COPPER Strategy 1: EMA
input bool     Enable_COPPER_Strat2 = false;      // COPPER Strategy 2: Bollinger

input group "=== Indices Strategies ==="
input bool     Enable_US500_Strat1 = false;       // US500 Strategy 1: MeanRev
input bool     Enable_USTEC_Strat1 = false;       // USTEC Strategy 1: ADX Trend
input bool     Enable_DE30_Strat1 = false;        // DE30 Strategy 1: ADX Trend
input bool     Enable_US30_Strat1 = false;        // US30 Strategy 1: MeanRev
input bool     Enable_JP225_Strat1 = false;       // JP225 Strategy 1: MACD Optimized
input bool     Enable_FTSE100_Strat1 = false;     // FTSE100 Strategy 1: Mean Reversion
input bool     Enable_AUS200_Strat1 = false;      // AUS200 Strategy 1: EMA ADX
input bool     Enable_FRA40_Strat1 = false;       // FRA40 Strategy 1: MACD EMA

input group "=== New Crypto Strategies ==="
input bool     Enable_LTCUSD_Strat1 = false;      // LTCUSD Strategy 1: Momentum
input bool     Enable_LTCUSD_Strat2 = false;      // LTCUSD Strategy 2: BTC-Anchored
input bool     Enable_ADAUSD_Strat1 = false;      // ADAUSD Strategy 1: Trend
input bool     Enable_ETHUSD_Strat2 = false;      // ETHUSD Strategy 2: BTC-Aligned

input group "=== New Forex Strategies ==="
input bool     Enable_CADJPY_Strat1 = false;      // CADJPY Strategy 1: Breakout
input bool     Enable_CHFJPY_Strat1 = false;      // CHFJPY Strategy 1: Momentum
input bool     Enable_AUDNZD_Strat1 = false;      // AUDNZD Strategy 1: Pullback
input bool     Enable_GBPNZD_Strat1 = false;      // GBPNZD Strategy 1: Correlation Reversal

input group "=== New Metals Strategies ==="
input bool     Enable_XAGUSD_Strat2 = false;      // XAGUSD Strategy 2: Volatility
input bool     Enable_XAUEUR_Strat2 = false;      // XAUEUR Strategy 2: MeanRev
input bool     Enable_XAGUSD_Strat3 = false;      // XAGUSD Strategy 3: Mean Reversion
input bool     Enable_XAGUSD_Strat4 = false;      // XAGUSD Strategy 4: Gold/Silver Pairs

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
    
    // Map Strategy Inputs
    config.enable_EURUSD_Strat1 = Enable_EURUSD_Strat1;
    config.enable_EURUSD_Strat2 = Enable_EURUSD_Strat2;
    config.enable_EURUSD_Strat3 = Enable_EURUSD_Strat3;
    config.enable_GBPUSD_Strat1 = Enable_GBPUSD_Strat1;
    config.enable_GBPUSD_Strat2 = Enable_GBPUSD_Strat2;
    config.enable_GBPUSD_Strat3 = Enable_GBPUSD_Strat3;
    config.enable_USDJPY_Strat1 = Enable_USDJPY_Strat1;
    config.enable_USDJPY_Strat2 = Enable_USDJPY_Strat2;
    config.enable_XAUUSD_Strat1 = Enable_XAUUSD_Strat1;
    config.enable_XAUUSD_Strat2 = Enable_XAUUSD_Strat2;
    config.enable_XAUUSD_Strat3 = Enable_XAUUSD_Strat3;
    config.enable_EURGBP_Strat1 = Enable_EURGBP_Strat1;
    config.enable_AUDUSD_Strat1 = Enable_AUDUSD_Strat1;
    
    config.enable_BTCUSD_Strat1 = Enable_BTCUSD_Strat1;
    config.enable_BTCUSD_Strat2 = Enable_BTCUSD_Strat2;
    config.enable_ETHUSD_Strat1 = Enable_ETHUSD_Strat1;
    config.enable_SOLUSD_Strat1 = Enable_SOLUSD_Strat1;
    config.enable_XRPUSD_Strat1 = Enable_XRPUSD_Strat1;
    
    config.enable_XAGUSD_Strat1 = Enable_XAGUSD_Strat1;
    config.enable_XAUEUR_Strat1 = Enable_XAUEUR_Strat1;
    
    config.enable_NZDUSD_Strat1 = Enable_NZDUSD_Strat1;
    config.enable_USDCHF_Strat1 = Enable_USDCHF_Strat1;
    config.enable_USDCAD_Strat1 = Enable_USDCAD_Strat1;
    config.enable_GBPJPY_Strat1 = Enable_GBPJPY_Strat1;
    config.enable_EURNZD_Strat1 = Enable_EURNZD_Strat1;
    
    config.enable_SP500_MeanRev = Enable_SP500_MeanRev;
    
    // Energy
    config.enable_USOIL_Strat1 = Enable_USOIL_Strat1;
    config.enable_USOIL_Strat2 = Enable_USOIL_Strat2;
    config.enable_UKOIL_Strat1 = Enable_UKOIL_Strat1;
    config.enable_NATGAS_Strat1 = Enable_NATGAS_Strat1;
    config.enable_NATGAS_Strat2 = Enable_NATGAS_Strat2;
    config.enable_COPPER_Strat1 = Enable_COPPER_Strat1;
    config.enable_COPPER_Strat2 = Enable_COPPER_Strat2;
    
    // Indices
    config.enable_US500_Strat1 = Enable_US500_Strat1;
    config.enable_USTEC_Strat1 = Enable_USTEC_Strat1;
    config.enable_DE30_Strat1 = Enable_DE30_Strat1;
    config.enable_US30_Strat1 = Enable_US30_Strat1;
    
    // Crypto
    config.enable_LTCUSD_Strat1 = Enable_LTCUSD_Strat1;
    config.enable_LTCUSD_Strat2 = Enable_LTCUSD_Strat2;
    config.enable_ADAUSD_Strat1 = Enable_ADAUSD_Strat1;
    config.enable_ETHUSD_Strat2 = Enable_ETHUSD_Strat2;
    
    // Forex
    config.enable_CADJPY_Strat1 = Enable_CADJPY_Strat1;
    config.enable_CHFJPY_Strat1 = Enable_CHFJPY_Strat1;
    config.enable_AUDNZD_Strat1 = Enable_AUDNZD_Strat1;
    
    // Metals
    config.enable_XAGUSD_Strat2 = Enable_XAGUSD_Strat2;
    config.enable_XAUEUR_Strat2 = Enable_XAUEUR_Strat2;
    config.enable_XAGUSD_Strat3 = Enable_XAGUSD_Strat3;
    config.enable_XAGUSD_Strat4 = Enable_XAGUSD_Strat4;
    
    // Final Audit Indices
    config.enable_JP225_Strat1 = Enable_JP225_Strat1;
    config.enable_FTSE100_Strat1 = Enable_FTSE100_Strat1;
    config.enable_AUS200_Strat1 = Enable_AUS200_Strat1;
    config.enable_FRA40_Strat1 = Enable_FRA40_Strat1;
    
    // Final Audit Forex
    config.enable_GBPNZD_Strat1 = Enable_GBPNZD_Strat1;
    
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