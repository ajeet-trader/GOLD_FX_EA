//+------------------------------------------------------------------+
//|                                                StrategyBase.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/IStrategy.mqh>
#include <GoldFXEAProject/Utils/Logger.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>

//+------------------------------------------------------------------+
//| CStrategyBase Class                                               |
//| Base implementation with common functionality                     |
//+------------------------------------------------------------------+
class CStrategyBase : public IStrategy
{
protected:
    CLogger* m_logger;
    CRiskManager* m_riskManager;
    
    // Indicator handles
    int m_handleEMA_Fast;
    int m_handleEMA_Slow;
    int m_handleATR;
    int m_handleADX;
    int m_handleMACD;
    int m_handleRSI;
    int m_handleStochastic;
    int m_handleBB;
    
    // Cached indicator values
    double m_emaFast[];
    double m_emaSlow[];
    double m_atr[];
    double m_adx[];
    double m_macdMain[];
    double m_macdSignal[];
    double m_rsi[];
    double m_stochMain[];
    double m_stochSignal[];
    double m_bbUpper[];
    double m_bbMiddle[];
    double m_bbLower[];
    
    // Position tracking
    datetime m_lastTradeTime;
    double m_lastTradePrice;
    
public:
    // Constructor
    CStrategyBase(string strategyName, CLogger* logger, CRiskManager* riskManager) 
        : IStrategy(strategyName)
    {
        m_logger = logger;
        m_riskManager = riskManager;
        m_lastTradeTime = 0;
        m_lastTradePrice = 0.0;
        
        // Initialize handles to INVALID_HANDLE
        m_handleEMA_Fast = INVALID_HANDLE;
        m_handleEMA_Slow = INVALID_HANDLE;
        m_handleATR = INVALID_HANDLE;
        m_handleADX = INVALID_HANDLE;
        m_handleMACD = INVALID_HANDLE;
        m_handleRSI = INVALID_HANDLE;
        m_handleStochastic = INVALID_HANDLE;
        m_handleBB = INVALID_HANDLE;
        
        // Set array as series
        ArraySetAsSeries(m_emaFast, true);
        ArraySetAsSeries(m_emaSlow, true);
        ArraySetAsSeries(m_atr, true);
        ArraySetAsSeries(m_adx, true);
        ArraySetAsSeries(m_macdMain, true);
        ArraySetAsSeries(m_macdSignal, true);
        ArraySetAsSeries(m_rsi, true);
        ArraySetAsSeries(m_stochMain, true);
        ArraySetAsSeries(m_stochSignal, true);
        ArraySetAsSeries(m_bbUpper, true);
        ArraySetAsSeries(m_bbMiddle, true);
        ArraySetAsSeries(m_bbLower, true);
    }
    
    // Destructor
    virtual ~CStrategyBase()
    {
        ReleaseIndicators();
    }
    
    // Initialize base strategy
    virtual bool Initialize() override
    {
        m_logger.Info(StringFormat("Initializing strategy for %s on %s", 
                     m_config.symbol, EnumToString(m_config.timeframe)), m_moduleName);
        
        m_status = MODULE_STATUS_INITIALIZING;
        
        // Validate configuration
        if(!ValidateConfig())
        {
            m_logger.Error("Invalid strategy configuration", m_moduleName);
            m_status = MODULE_STATUS_ERROR;
            return false;
        }
        
        m_status = MODULE_STATUS_INITIALIZED;
        m_logger.Info("Strategy initialized successfully", m_moduleName);
        return true;
    }
    
    // Process tick
    virtual void ProcessTick(MqlTick &tick) override
    {
        // Base implementation - override in derived classes
    }
    
    // Deinitialize
    virtual void Deinitialize() override
    {
        m_logger.Info("Strategy shutting down", m_moduleName);
        ReleaseIndicators();
        m_status = MODULE_STATUS_STOPPED;
    }
    
    // Get module info
    virtual string GetModuleInfo() override
    {
        return StringFormat("%s - %s on %s (%s)", 
                          m_moduleName, 
                          m_config.symbol,
                          EnumToString(m_config.timeframe),
                          StrategyTypeToString(m_config.strategyType));
    }
    
    // Check if trading is allowed
    virtual bool IsTradingAllowed() override
    {
        if(!m_config.enableTrading)
            return false;
        
        // Check if market is open
        datetime currentTime = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        // Example: Don't trade on weekends (for Forex)
        if(dt.day_of_week == 0 || dt.day_of_week == 6)
            return false;
        
        // Check max open trades
        if(m_openPositions >= m_config.maxOpenTrades)
            return false;
        
        return true;
    }
    
    // Get market condition
    virtual string GetMarketCondition() override
    {
        return "Unknown";
    }
    
    // Count open positions for this strategy
    int CountOpenPositions()
    {
        int count = 0;
        
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
                long magic = PositionGetInteger(POSITION_MAGIC);
                string symbol = PositionGetString(POSITION_SYMBOL);
                
                if(magic == m_config.magicNumber && symbol == m_config.symbol)
                    count++;
            }
        }
        
        return count;
    }
    
    // Get current market price
    double GetCurrentPrice(ENUM_ORDER_TYPE orderType)
    {
        MqlTick tick;
        if(!SymbolInfoTick(m_config.symbol, tick))
            return 0.0;
        
        return (orderType == ORDER_TYPE_BUY) ? tick.ask : tick.bid;
    }
    
    // Calculate ATR-based stop loss
    double CalculateATRStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double atrMultiplier = 2.0)
    {
        if(m_handleATR == INVALID_HANDLE)
            return 0.0;
        
        if(CopyBuffer(m_handleATR, 0, 0, 1, m_atr) <= 0)
            return 0.0;
        
        double atrValue = m_atr[0];
        double slDistance = atrValue * atrMultiplier;
        
        double stopLoss = 0.0;
        if(orderType == ORDER_TYPE_BUY)
            stopLoss = entryPrice - slDistance;
        else
            stopLoss = entryPrice + slDistance;
        
        return NormalizePrice(m_config.symbol, stopLoss);
    }
    
    // Calculate ATR-based take profit
    double CalculateATRTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double atrMultiplier = 4.0)
    {
        if(m_handleATR == INVALID_HANDLE)
            return 0.0;
        
        if(CopyBuffer(m_handleATR, 0, 0, 1, m_atr) <= 0)
            return 0.0;
        
        double atrValue = m_atr[0];
        double tpDistance = atrValue * atrMultiplier;
        
        double takeProfit = 0.0;
        if(orderType == ORDER_TYPE_BUY)
            takeProfit = entryPrice + tpDistance;
        else
            takeProfit = entryPrice - tpDistance;
        
        return NormalizePrice(m_config.symbol, takeProfit);
    }
    
protected:
    // Validate configuration
    bool ValidateConfig()
    {
        if(m_config.symbol == "")
        {
            m_logger.Error("Symbol not set", m_moduleName);
            return false;
        }
        
        if(!SymbolInfoInteger(m_config.symbol, SYMBOL_SELECT))
        {
            if(!SymbolSelect(m_config.symbol, true))
            {
                m_logger.Error("Failed to select symbol: " + m_config.symbol, m_moduleName);
                return false;
            }
        }
        
        if(m_config.magicNumber == 0)
        {
            m_logger.Warning("Magic number not set, using default", m_moduleName);
            m_config.magicNumber = EA_MAGIC_NUMBER;
        }
        
        return true;
    }
    
    // Create indicator
    int CreateIndicator(string indicatorName, string indicatorType, int period1 = 0, 
                       int period2 = 0, int period3 = 0)
    {
        int handle = INVALID_HANDLE;
        
        if(indicatorType == "MA")
        {
            handle = iMA(m_config.symbol, m_config.timeframe, period1, 0, MODE_EMA, PRICE_CLOSE);
        }
        else if(indicatorType == "ATR")
        {
            handle = iATR(m_config.symbol, m_config.timeframe, period1);
        }
        else if(indicatorType == "ADX")
        {
            handle = iADX(m_config.symbol, m_config.timeframe, period1);
        }
        else if(indicatorType == "MACD")
        {
            handle = iMACD(m_config.symbol, m_config.timeframe, period1, period2, period3, PRICE_CLOSE);
        }
        else if(indicatorType == "RSI")
        {
            handle = iRSI(m_config.symbol, m_config.timeframe, period1, PRICE_CLOSE);
        }
        else if(indicatorType == "STOCHASTIC")
        {
            handle = iStochastic(m_config.symbol, m_config.timeframe, period1, period2, period3, MODE_SMA, STO_LOWHIGH);
        }
        else if(indicatorType == "BANDS")
        {
            handle = iBands(m_config.symbol, m_config.timeframe, period1, 0, 2.0, PRICE_CLOSE);
        }
        
        if(handle == INVALID_HANDLE)
        {
            m_logger.Error(StringFormat("Failed to create %s indicator", indicatorName), m_moduleName);
        }
        else
        {
            m_logger.Debug(StringFormat("%s indicator created (Handle: %d)", indicatorName, handle), m_moduleName);
        }
        
        return handle;
    }
    
    // Release all indicators
    void ReleaseIndicators()
    {
        if(m_handleEMA_Fast != INVALID_HANDLE) { IndicatorRelease(m_handleEMA_Fast); m_handleEMA_Fast = INVALID_HANDLE; }
        if(m_handleEMA_Slow != INVALID_HANDLE) { IndicatorRelease(m_handleEMA_Slow); m_handleEMA_Slow = INVALID_HANDLE; }
        if(m_handleATR != INVALID_HANDLE) { IndicatorRelease(m_handleATR); m_handleATR = INVALID_HANDLE; }
        if(m_handleADX != INVALID_HANDLE) { IndicatorRelease(m_handleADX); m_handleADX = INVALID_HANDLE; }
        if(m_handleMACD != INVALID_HANDLE) { IndicatorRelease(m_handleMACD); m_handleMACD = INVALID_HANDLE; }
        if(m_handleRSI != INVALID_HANDLE) { IndicatorRelease(m_handleRSI); m_handleRSI = INVALID_HANDLE; }
        if(m_handleStochastic != INVALID_HANDLE) { IndicatorRelease(m_handleStochastic); m_handleStochastic = INVALID_HANDLE; }
        if(m_handleBB != INVALID_HANDLE) { IndicatorRelease(m_handleBB); m_handleBB = INVALID_HANDLE; }
    }
    
    // Wait for indicator data
    bool WaitForIndicatorData(int handle, int bufferCount = 1)
    {
        if(handle == INVALID_HANDLE)
            return false;
        
        int attempts = 0;
        while(attempts < 100)
        {
            if(BarsCalculated(handle) > bufferCount)
                return true;
            
            Sleep(10);
            attempts++;
        }
        
        return false;
    }
};

//+------------------------------------------------------------------+