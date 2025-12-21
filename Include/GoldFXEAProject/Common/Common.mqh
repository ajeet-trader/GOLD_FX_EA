//+------------------------------------------------------------------+
//|                                                       Common.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

//+------------------------------------------------------------------+
//| Common Enumerations                                              |
//+------------------------------------------------------------------+

// Logging levels
enum ENUM_LOG_LEVEL
{
    LOG_LEVEL_DEBUG = 0,    // Debug - All messages
    LOG_LEVEL_INFO = 1,     // Info - Important information
    LOG_LEVEL_WARNING = 2,  // Warning - Warnings only
    LOG_LEVEL_ERROR = 3,    // Error - Errors only
    LOG_LEVEL_CRITICAL = 4  // Critical - Critical errors only
};

// Module status
enum ENUM_MODULE_STATUS
{
    MODULE_STATUS_UNINITIALIZED = 0,  // Not initialized
    MODULE_STATUS_INITIALIZING = 1,   // Initializing
    MODULE_STATUS_INITIALIZED = 2,    // Initialized successfully
    MODULE_STATUS_RUNNING = 3,        // Running
    MODULE_STATUS_ERROR = 4,          // Error state
    MODULE_STATUS_STOPPED = 5         // Stopped
};

// Asset class types
enum ENUM_ASSET_CLASS
{
    ASSET_CLASS_FOREX = 0,     // Forex pairs
    ASSET_CLASS_CRYPTO = 1,    // Cryptocurrencies
    ASSET_CLASS_METALS = 2,    // Precious metals
    ASSET_CLASS_INDICES = 3    // Stock indices
};

// Strategy types
enum ENUM_STRATEGY_TYPE
{
    STRATEGY_TREND_FOLLOWING = 0,   // Trend following strategy
    STRATEGY_BREAKOUT = 1,          // Breakout strategy
    STRATEGY_MEAN_REVERSION = 2,    // Mean reversion strategy
    STRATEGY_SCALPING = 3,          // Scalping strategy
    STRATEGY_MOMENTUM = 4           // Momentum strategy
};

// Trade signal types
enum ENUM_SIGNAL_TYPE
{
    SIGNAL_NONE = 0,      // No signal
    SIGNAL_BUY = 1,       // Buy signal
    SIGNAL_SELL = 2,      // Sell signal
    SIGNAL_CLOSE_BUY = 3, // Close buy position
    SIGNAL_CLOSE_SELL = 4 // Close sell position
};

//+------------------------------------------------------------------+
//| Common Structures                                                |
//+------------------------------------------------------------------+

// EA configuration structure
struct EAConfig
{
    bool enableTrading;
    bool enableLogging;
    ENUM_LOG_LEVEL logLevel;
    double riskPercentPerTrade;
    double maxDailyLoss;
    double maxDrawdown;
    int maxOpenTrades;
    bool enable_EURUSD_Strat1;
    bool enable_EURUSD_Strat2;
    bool enable_EURUSD_Strat3;
    bool enable_GBPUSD_Strat1;
    bool enable_GBPUSD_Strat2;
    bool enable_GBPUSD_Strat3;
    bool enable_USDJPY_Strat1;
    bool enable_USDJPY_Strat2;
    bool enable_BTCUSD_Momentum;
    // Metals
    bool enable_XAUUSD_Strat1;
    bool enable_XAUUSD_Strat2;
    bool enable_XAUUSD_Strat3;
    // Remaining Forex
    bool enable_EURGBP_Strat1;
    bool enable_AUDUSD_Strat1;
    
    // Crypto Strategies
    bool enable_BTCUSD_Strat1;
    bool enable_BTCUSD_Strat2;
    bool enable_ETHUSD_Strat1;
    bool enable_SOLUSD_Strat1;
    bool enable_XRPUSD_Strat1;
    
    // Additional Metals
    bool enable_XAGUSD_Strat1;
    bool enable_XAUEUR_Strat1;
    
    // Additional Forex
    bool enable_NZDUSD_Strat1;
    bool enable_USDCHF_Strat1;
    bool enable_USDCAD_Strat1;
    bool enable_GBPJPY_Strat1;
    bool enable_EURNZD_Strat1;
    
    bool enable_SP500_MeanRev;
    
    // Energy
    bool enable_USOIL_Strat1;
    bool enable_USOIL_Strat2;
    bool enable_UKOIL_Strat1;
    bool enable_NATGAS_Strat1;
    bool enable_NATGAS_Strat2;
    bool enable_COPPER_Strat1;
    bool enable_COPPER_Strat2;
    
    // Additional Crypto
    bool enable_LTCUSD_Strat1;
    bool enable_LTCUSD_Strat2;
    bool enable_ADAUSD_Strat1;
    
    // Additional Indices
    bool enable_USTEC_Strat1;
    bool enable_DE30_Strat1;
    bool enable_US30_Strat1;
    
    // New Crypto
    bool enable_ETHUSD_Strat2;
    
    // New Forex
    bool enable_CADJPY_Strat1;
    bool enable_CHFJPY_Strat1;
    bool enable_AUDNZD_Strat1;
    
    // New Metals
    bool enable_XAGUSD_Strat2;
    bool enable_XAUEUR_Strat2;
    
    // Final Audit Strategies
    bool enable_JP225_Strat1;
    bool enable_FTSE100_Strat1;
    bool enable_AUS200_Strat1;
    bool enable_FRA40_Strat1;
    bool enable_GBPNZD_Strat1;
    bool enable_XAGUSD_Strat3;
    bool enable_XAGUSD_Strat4;
    
    // Constructor with default values
    EAConfig()
    {
        enableTrading = true;
        enableLogging = true;
        logLevel = LOG_LEVEL_INFO;
        riskPercentPerTrade = 1.5;
        maxDailyLoss = 5.0;
        maxDrawdown = 20.0;
        maxOpenTrades = 10;
        
        enable_EURUSD_Strat1 = false;
        enable_EURUSD_Strat2 = false;
        enable_EURUSD_Strat3 = false;
        enable_GBPUSD_Strat1 = false;
        enable_GBPUSD_Strat2 = false;
        enable_GBPUSD_Strat3 = false;
        enable_USDJPY_Strat1 = false;
        enable_USDJPY_Strat2 = false;
        enable_BTCUSD_Momentum = false;
        enable_XAUUSD_Strat1 = false;
        enable_XAUUSD_Strat2 = false;
        enable_XAUUSD_Strat3 = false;
        enable_EURGBP_Strat1 = false;
        enable_AUDUSD_Strat1 = false;
        
        enable_BTCUSD_Strat1 = false;
        enable_BTCUSD_Strat2 = false;
        enable_ETHUSD_Strat1 = false;
         enable_SOLUSD_Strat1 = false;
         enable_XRPUSD_Strat1 = false;
         
         enable_XAGUSD_Strat1 = false;
         enable_XAUEUR_Strat1 = false;
         
         enable_NZDUSD_Strat1 = false;
         enable_USDCHF_Strat1 = false;
         enable_USDCAD_Strat1 = false;
         enable_GBPJPY_Strat1 = false;
         enable_EURNZD_Strat1 = false;
         
         enable_SP500_MeanRev = false;
         
         // Energy
         enable_USOIL_Strat1 = false;
         enable_USOIL_Strat2 = false;
         enable_UKOIL_Strat1 = false;
         enable_NATGAS_Strat1 = false;
         enable_NATGAS_Strat2 = false;
         enable_COPPER_Strat1 = false;
         enable_COPPER_Strat2 = false;
         
         // Crypto
         enable_LTCUSD_Strat1 = false;
         enable_LTCUSD_Strat2 = false;
         enable_ADAUSD_Strat1 = false;
         enable_ETHUSD_Strat2 = false;
         
         // Indices
         enable_USTEC_Strat1 = false;
         enable_DE30_Strat1 = false;
         enable_US30_Strat1 = false;
         
         // Forex
         enable_CADJPY_Strat1 = false;
         enable_CHFJPY_Strat1 = false;
         enable_AUDNZD_Strat1 = false;
         
         // Metals
         enable_XAGUSD_Strat2 = false;
         enable_XAUEUR_Strat2 = false;
         
         // Final Audit Strategies
         enable_JP225_Strat1 = false;
         enable_FTSE100_Strat1 = false;
         enable_AUS200_Strat1 = false;
         enable_FRA40_Strat1 = false;
         enable_GBPNZD_Strat1 = false;
         enable_XAGUSD_Strat3 = false;
         enable_XAGUSD_Strat4 = false;
    }
};

// Trade request structure
struct TradeRequest
{
    string symbol;
    ENUM_ORDER_TYPE orderType;
    double volume;
    double stopLoss;
    double takeProfit;
    double price;
    string comment;
    int magicNumber;
    
    // Constructor
    TradeRequest()
    {
        symbol = "";
        orderType = ORDER_TYPE_BUY;
        volume = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        price = 0.0;
        comment = "";
        magicNumber = 0;
    }
};

// Trade result structure
struct TradeResult
{
    bool success;
    ulong ticket;
    double executedPrice;
    double executedVolume;
    uint retcode;
    string message;
    
    // Constructor
    TradeResult()
    {
        success = false;
        ticket = 0;
        executedPrice = 0.0;
        executedVolume = 0.0;
        retcode = 0;
        message = "";
    }
};

// Performance metrics structure
struct PerformanceMetrics
{
    double totalProfit;
    double totalLoss;
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double winRate;
    double profitFactor;
    double maxDrawdown;
    double sharpeRatio;
    datetime lastUpdateTime;
    
    // Constructor
    PerformanceMetrics()
    {
        totalProfit = 0.0;
        totalLoss = 0.0;
        totalTrades = 0;
        winningTrades = 0;
        losingTrades = 0;
        winRate = 0.0;
        profitFactor = 0.0;
        maxDrawdown = 0.0;
        sharpeRatio = 0.0;
        lastUpdateTime = 0;
    }
};

// Risk metrics structure
struct RiskMetrics
{
    double accountBalance;
    double accountEquity;
    double usedMargin;
    double freeMargin;
    double marginLevel;
    double dailyPnL;
    double weeklyPnL;
    double drawdownPercent;
    int openPositions;
    double totalExposure;
    
    // Constructor
    RiskMetrics()
    {
        accountBalance = 0.0;
        accountEquity = 0.0;
        usedMargin = 0.0;
        freeMargin = 0.0;
        marginLevel = 0.0;
        dailyPnL = 0.0;
        weeklyPnL = 0.0;
        drawdownPercent = 0.0;
        openPositions = 0;
        totalExposure = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Common Constants                                                 |
//+------------------------------------------------------------------+
#define EA_MAGIC_NUMBER 20251213          // EA magic number
#define EA_VERSION "1.0.0"                // EA version
#define MAX_RETRIES 3                     // Max trade retries
#define RETRY_DELAY_MS 1000               // Retry delay in milliseconds
#define ONTICK_MAX_TIME_MS 5              // Max OnTick processing time
#define SLIPPAGE_POINTS 10                // Max slippage in points

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+

// Convert asset class to string
string AssetClassToString(ENUM_ASSET_CLASS assetClass)
{
    switch(assetClass)
    {
        case ASSET_CLASS_FOREX:   return "Forex";
        case ASSET_CLASS_CRYPTO:  return "Crypto";
        case ASSET_CLASS_METALS:  return "Metals";
        case ASSET_CLASS_INDICES: return "Indices";
        default:                  return "Unknown";
    }
}

// Convert strategy type to string
string StrategyTypeToString(ENUM_STRATEGY_TYPE strategyType)
{
    switch(strategyType)
    {
        case STRATEGY_TREND_FOLLOWING: return "TrendFollowing";
        case STRATEGY_BREAKOUT:        return "Breakout";
        case STRATEGY_MEAN_REVERSION:  return "MeanReversion";
        case STRATEGY_SCALPING:        return "Scalping";
        case STRATEGY_MOMENTUM:        return "Momentum";
        default:                       return "Unknown";
    }
}

// Convert signal type to string
string SignalTypeToString(ENUM_SIGNAL_TYPE signalType)
{
    switch(signalType)
    {
        case SIGNAL_NONE:       return "None";
        case SIGNAL_BUY:        return "Buy";
        case SIGNAL_SELL:       return "Sell";
        case SIGNAL_CLOSE_BUY:  return "CloseBuy";
        case SIGNAL_CLOSE_SELL: return "CloseSell";
        default:                return "Unknown";
    }
}

// Get current timestamp string
string GetTimestamp()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                       dt.year, dt.mon, dt.day,
                       dt.hour, dt.min, dt.sec);
}

// Normalize price to symbol digits
double NormalizePrice(string symbol, double price)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

// Normalize lot size
double NormalizeLotSize(string symbol, double lots)
{
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    lots = MathFloor(lots / lotStep) * lotStep;
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    
    return NormalizeDouble(lots, 2);
}
//+------------------------------------------------------------------+