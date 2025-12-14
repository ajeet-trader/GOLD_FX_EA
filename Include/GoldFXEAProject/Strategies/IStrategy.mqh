//+------------------------------------------------------------------+
//|                                                    IStrategy.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Interfaces/IModule.mqh>
#include <GoldFXEAProject/Common/Common.mqh>

//+------------------------------------------------------------------+
//| Strategy Configuration Structure                                  |
//+------------------------------------------------------------------+
struct StrategyConfig
{
    string symbol;                    // Trading symbol
    ENUM_TIMEFRAMES timeframe;        // Primary timeframe
    ENUM_STRATEGY_TYPE strategyType;  // Strategy type
    double riskPercent;               // Risk per trade (%)
    int maxOpenTrades;                // Max simultaneous trades
    bool enableTrading;               // Enable/disable trading
    int magicNumber;                  // Unique magic number
    
    // Strategy-specific parameters
    string customParams;              // JSON or key-value pairs
    
    StrategyConfig()
    {
        symbol = "";
        timeframe = PERIOD_H1;
        strategyType = STRATEGY_TREND_FOLLOWING;
        riskPercent = 1.5;
        maxOpenTrades = 1;
        enableTrading = true;
        magicNumber = 0;
        customParams = "";
    }
};

//+------------------------------------------------------------------+
//| Trade Signal Structure                                            |
//+------------------------------------------------------------------+
struct TradeSignal
{
    ENUM_SIGNAL_TYPE signalType;     // Signal type (BUY/SELL/CLOSE)
    double confidence;                // Signal confidence (0.0-1.0)
    double entryPrice;                // Suggested entry price
    double stopLoss;                  // Suggested stop loss
    double takeProfit;                // Suggested take profit
    string reason;                    // Signal generation reason
    datetime timestamp;               // Signal timestamp
    
    TradeSignal()
    {
        signalType = SIGNAL_NONE;
        confidence = 0.0;
        entryPrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        reason = "";
        timestamp = 0;
    }
};

//+------------------------------------------------------------------+
//| IStrategy Interface                                               |
//| Base interface for all trading strategies                         |
//+------------------------------------------------------------------+
class IStrategy : public IModule
{
protected:
    StrategyConfig m_config;
    TradeSignal m_lastSignal;
    datetime m_lastSignalTime;
    int m_openPositions;
    
public:
    // Constructor
    IStrategy(string strategyName) : IModule(strategyName)
    {
        m_lastSignalTime = 0;
        m_openPositions = 0;
    }
    
    // Virtual destructor
    virtual ~IStrategy() {}
    
    // Configuration
    virtual void SetConfig(StrategyConfig &config) { m_config = config; }
    virtual StrategyConfig GetConfig() { return m_config; }
    
    // Core strategy methods - MUST be implemented
    virtual TradeSignal GenerateSignal() = 0;
    virtual bool ValidateSignal(TradeSignal &signal) = 0;
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) = 0;
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) = 0;
    
    // Position management
    virtual bool ShouldClosePosition(ulong ticket) = 0;
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) = 0;
    
    // Market analysis
    virtual bool IsTradingAllowed() = 0;
    virtual string GetMarketCondition() = 0;
    
    // Performance tracking
    virtual void OnTradeOpened(ulong ticket, double entryPrice) {}
    virtual void OnTradeClosed(ulong ticket, double exitPrice, double profit) {}
    virtual void OnTradeModified(ulong ticket, double newSL, double newTP) {}
    
    // Accessors
    virtual TradeSignal GetLastSignal() { return m_lastSignal; }
    virtual int GetOpenPositions() { return m_openPositions; }
    virtual void SetOpenPositions(int count) { m_openPositions = count; }
};
//+------------------------------------------------------------------+