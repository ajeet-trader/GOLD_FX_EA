//+------------------------------------------------------------------+
//|                                         XAUUSDScalping.mqh       |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| XAUUSD M15 Scalping Strategy                                      |
//| Uses: EMA(5/13) + Stochastic + Low ATR (consolidation)          |
//+------------------------------------------------------------------+
class CXAUUSDScalping : public CStrategyBase
{
private:
    // Strategy parameters
    int m_emaFastPeriod;
    int m_emaSlowPeriod;
    int m_stochKPeriod;
    int m_stochDPeriod;
    int m_stochSlowing;
    double m_stochOverbought;
    double m_stochOversold;
    int m_atrPeriod;
    double m_atrLowThreshold;  // Low ATR for consolidation
    double m_atrMultiplierSL;
    double m_atrMultiplierTP;
    int m_minBarsSinceSignal;
    
    // Market state
    datetime m_lastBarTime;
    double m_avgATR;
    
public:
    // Constructor
    CXAUUSDScalping(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("XAUUSD_Scalping", logger, riskManager)
    {
        // Default parameters for scalping
        m_emaFastPeriod = 5;
        m_emaSlowPeriod = 13;
        m_stochKPeriod = 5;
        m_stochDPeriod = 3;
        m_stochSlowing = 3;
        m_stochOverbought = 80.0;
        m_stochOversold = 20.0;
        m_atrPeriod = 14;
        m_atrLowThreshold = 0.8;  // ATR below 80% of average = consolidation
        m_atrMultiplierSL = 1.5;  // Quick scalp stops
        m_atrMultiplierTP = 2.5;  // Quick scalp targets
        m_minBarsSinceSignal = 1;
        m_lastBarTime = 0;
        m_avgATR = 0.0;
    }
    
    // Initialize strategy
    virtual bool Initialize() override
    {
        // Set default config if not set
        if(m_config.symbol == "")
        {
            m_config.symbol = "XAUUSD";
            m_config.timeframe = PERIOD_M15;
            m_config.strategyType = STRATEGY_SCALPING;
            m_config.riskPercent = 1.0;  // Lower risk for scalping
            m_config.maxOpenTrades = 2;  // Allow multiple scalp positions
            m_config.magicNumber = EA_MAGIC_NUMBER + 4;
        }
        
        // Call base initialization
        if(!CStrategyBase::Initialize())
            return false;
        
        m_logger.Info("Creating indicators for XAUUSD Scalping", m_moduleName);
        
        // Create indicators
        m_handleEMA_Fast = CreateIndicator("EMA_Fast", "MA", m_emaFastPeriod);
        m_handleEMA_Slow = CreateIndicator("EMA_Slow", "MA", m_emaSlowPeriod);
        m_handleStochastic = CreateIndicator("Stochastic", "STOCHASTIC", 
                                            m_stochKPeriod, m_stochDPeriod, m_stochSlowing);
        m_handleATR = CreateIndicator("ATR", "ATR", m_atrPeriod);
        
        // Validate indicators
        if(m_handleEMA_Fast == INVALID_HANDLE || m_handleEMA_Slow == INVALID_HANDLE ||
           m_handleStochastic == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create required indicators", m_moduleName);
            return false;
        }
        
        // Wait for indicator data
        if(!WaitForIndicatorData(m_handleEMA_Fast, m_emaSlowPeriod + 10) ||
           !WaitForIndicatorData(m_handleEMA_Slow, m_emaSlowPeriod + 10) ||
           !WaitForIndicatorData(m_handleStochastic, m_stochKPeriod + 10) ||
           !WaitForIndicatorData(m_handleATR, m_atrPeriod + 10))
        {
            m_logger.Error("Timeout waiting for indicator data", m_moduleName);
            return false;
        }
        
        // Calculate average ATR
        CalculateAvgATR();
        
        m_logger.Info("XAUUSD Scalping strategy ready", m_moduleName);
        m_status = MODULE_STATUS_RUNNING;
        return true;
    }
    
    // Process tick
    virtual void ProcessTick(MqlTick &tick) override
    {
        // Check if new bar
        datetime currentBarTime = iTime(m_config.symbol, m_config.timeframe, 0);
        if(currentBarTime == m_lastBarTime)
            return;
        
        m_lastBarTime = currentBarTime;
        
        // Update open positions count
        m_openPositions = CountOpenPositions();
        
        // Recalculate average ATR periodically
        if(Bars(m_config.symbol, m_config.timeframe, 0, TimeCurrent()) % 20 == 0)
            CalculateAvgATR();
        
        // Generate and process signal
        TradeSignal signal = GenerateSignal();
        
        if(signal.signalType != SIGNAL_NONE && ValidateSignal(signal))
        {
            m_lastSignal = signal;
            m_lastSignalTime = TimeCurrent();
            
            m_logger.Info(StringFormat("New %s signal generated: Confidence=%.2f, Reason=%s",
                         SignalTypeToString(signal.signalType), signal.confidence, signal.reason),
                         m_moduleName);
        }
    }
    
    // Generate trading signal
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        // Update indicator values
        if(!UpdateIndicators())
        {
            m_logger.Debug("Failed to update indicators", m_moduleName);
            return signal;
        }
        
        // Check if max trades reached
        if(m_openPositions >= m_config.maxOpenTrades)
        {
            signal.signalType = SIGNAL_NONE;
            return signal;
        }
        
        // Get current values
        double emaFastCurrent = m_emaFast[0];
        double emaFastPrevious = m_emaFast[1];
        double emaSlowCurrent = m_emaSlow[0];
        double emaSlowPrevious = m_emaSlow[1];
        double atrCurrent = m_atr[0];
        double stochMain = m_stochMain[0];
        double stochSignal = m_stochSignal[0];
        double stochMainPrev = m_stochMain[1];
        double stochSignalPrev = m_stochSignal[1];
        
        // Check for consolidation (low volatility)
        bool lowVolatility = (atrCurrent < m_avgATR * m_atrLowThreshold);
        
        if(!lowVolatility)
        {
            signal.signalType = SIGNAL_NONE;
            return signal;  // Only trade in consolidation
        }
        
        // Check for bullish scalp setup
        bool emaBullishCross = (emaFastPrevious <= emaSlowPrevious) && (emaFastCurrent > emaSlowCurrent);
        bool stochOversoldBounce = (stochMainPrev < m_stochOversold) && (stochMain > m_stochOversold);
        bool stochBullishCross = (stochMainPrev <= stochSignalPrev) && (stochMain > stochSignal);
        
        if(emaBullishCross || (stochOversoldBounce && stochBullishCross))
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = CalculateConfidence(true, emaFastCurrent, emaSlowCurrent,
                                                   stochMain, atrCurrent);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            
            signal.reason = StringFormat("Bullish Scalp: EMA Cross + Stoch=%.1f + Low ATR", stochMain);
            return signal;
        }
        
        // Check for bearish scalp setup
        bool emaBearishCross = (emaFastPrevious >= emaSlowPrevious) && (emaFastCurrent < emaSlowCurrent);
        bool stochOverboughtDrop = (stochMainPrev > m_stochOverbought) && (stochMain < m_stochOverbought);
        bool stochBearishCross = (stochMainPrev >= stochSignalPrev) && (stochMain < stochSignal);
        
        if(emaBearishCross || (stochOverboughtDrop && stochBearishCross))
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = CalculateConfidence(false, emaFastCurrent, emaSlowCurrent,
                                                   stochMain, atrCurrent);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
            
            signal.reason = StringFormat("Bearish Scalp: EMA Cross + Stoch=%.1f + Low ATR", stochMain);
            return signal;
        }
        
        signal.signalType = SIGNAL_NONE;
        return signal;
    }
    
    // Validate signal
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        if(signal.signalType == SIGNAL_NONE)
            return false;
        
        if(signal.confidence < 0.55)  // Lower threshold for scalping
        {
            m_logger.Debug(StringFormat("Signal confidence too low: %.2f", signal.confidence), m_moduleName);
            return false;
        }
        
        if(!IsTradingAllowed())
        {
            m_logger.Debug("Trading not allowed currently", m_moduleName);
            return false;
        }
        
        // Less restrictive timing for scalping
        if(m_lastSignalTime > 0)
        {
            int barsSinceSignal = Bars(m_config.symbol, m_config.timeframe, m_lastSignalTime, TimeCurrent());
            if(barsSinceSignal < m_minBarsSinceSignal)
            {
                m_logger.Debug(StringFormat("Too soon since last signal (%d bars)", barsSinceSignal), m_moduleName);
                return false;
            }
        }
        
        return true;
    }
    
    // Calculate stop loss
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        stopLoss = CalculateATRStopLoss(entryPrice, orderType, m_atrMultiplierSL);
    }
    
    // Calculate take profit
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        takeProfit = CalculateATRTakeProfit(entryPrice, orderType, m_atrMultiplierTP);
    }
    
    // Should close position
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        if(!PositionSelectByTicket(ticket))
            return false;
        
        if(!UpdateIndicators())
            return false;
        
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        double emaFastCurrent = m_emaFast[0];
        double emaSlowCurrent = m_emaSlow[0];
        double stochMain = m_stochMain[0];
        double stochSignal = m_stochSignal[0];
        
        // Quick exit on opposite signal (scalping exits fast)
        if(posType == POSITION_TYPE_BUY)
        {
            if(emaFastCurrent < emaSlowCurrent || (stochMain < stochSignal && stochMain > 70))
            {
                m_logger.Info("Closing BUY scalp - Opposite signal", m_moduleName);
                return true;
            }
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            if(emaFastCurrent > emaSlowCurrent || (stochMain > stochSignal && stochMain < 30))
            {
                m_logger.Info("Closing SELL scalp - Opposite signal", m_moduleName);
                return true;
            }
        }
        
        return false;
    }
    
    // Should modify position
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;  // No modification for quick scalps
    }
    
    // Get market condition
    virtual string GetMarketCondition() override
    {
        if(!UpdateIndicators())
            return "UNKNOWN";
        
        double atrCurrent = m_atr[0];
        
        if(atrCurrent < m_avgATR * 0.7)
            return "LOW_VOLATILITY";
        else if(atrCurrent > m_avgATR * 1.3)
            return "HIGH_VOLATILITY";
        else
            return "NORMAL";
    }
    
private:
    // Update all indicators
    bool UpdateIndicators()
    {
        ArrayResize(m_emaFast, 3);
        ArrayResize(m_emaSlow, 3);
        ArrayResize(m_stochMain, 3);
        ArrayResize(m_stochSignal, 3);
        ArrayResize(m_atr, 3);
        
        if(CopyBuffer(m_handleEMA_Fast, 0, 0, 3, m_emaFast) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Slow, 0, 0, 3, m_emaSlow) <= 0) return false;
        if(CopyBuffer(m_handleStochastic, 0, 0, 3, m_stochMain) <= 0) return false;
        if(CopyBuffer(m_handleStochastic, 1, 0, 3, m_stochSignal) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
    
    // Calculate average ATR
    void CalculateAvgATR()
    {
        double atrValues[];
        ArraySetAsSeries(atrValues, true);
        
        if(CopyBuffer(m_handleATR, 0, 0, 50, atrValues) > 0)
        {
            double sum = 0.0;
            for(int i = 0; i < 50; i++)
                sum += atrValues[i];
            m_avgATR = sum / 50.0;
            
            m_logger.Debug(StringFormat("Average ATR calculated: %.5f", m_avgATR), m_moduleName);
        }
    }
    
    // Calculate signal confidence
    double CalculateConfidence(bool isBullish, double emaFast, double emaSlow,
                              double stoch, double atr)
    {
        double confidence = 0.5;
        
        // EMA separation component (max +0.20)
        double emaSeparation = MathAbs(emaFast - emaSlow) / emaSlow * 100.0;
        if(emaSeparation > 0.5)
            confidence += 0.20;
        else if(emaSeparation > 0.3)
            confidence += 0.10;
        
        // Stochastic position component (max +0.20)
        if(isBullish && stoch < 40)
            confidence += 0.20;
        else if(!isBullish && stoch > 60)
            confidence += 0.20;
        else if(isBullish && stoch < 50)
            confidence += 0.10;
        else if(!isBullish && stoch > 50)
            confidence += 0.10;
        
        // Low volatility component (max +0.10)
        double atrRatio = atr / m_avgATR;
        if(atrRatio < 0.7)
            confidence += 0.10;
        else if(atrRatio < 0.8)
            confidence += 0.05;
        
        return MathMin(confidence, 1.0);
    }
};
//+------------------------------------------------------------------+