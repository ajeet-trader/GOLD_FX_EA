//+------------------------------------------------------------------+
//|                                     EURUSDTrendFollowing.mqh     |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| EURUSD H1 Trend-Following Strategy                                |
//| Uses: 50/200 EMA crossover + ADX(14) > 25 + MACD confirmation    |
//+------------------------------------------------------------------+
class CEURUSDTrendFollowing : public CStrategyBase
{
private:
    // Strategy parameters
    int m_emaFastPeriod;
    int m_emaSlowPeriod;
    int m_adxPeriod;
    double m_adxThreshold;
    int m_macdFast;
    int m_macdSlow;
    int m_macdSignal;
    double m_atrMultiplierSL;
    double m_atrMultiplierTP;
    int m_minBarsSinceSignal;
    
    // Market state
    bool m_inTrend;
    datetime m_lastBarTime;
    
public:
    // Constructor
    CEURUSDTrendFollowing(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("EURUSD_TrendFollowing", logger, riskManager)
    {
        // Default parameters
        m_emaFastPeriod = 50;
        m_emaSlowPeriod = 200;
        m_adxPeriod = 14;
        m_adxThreshold = 25.0;
        m_macdFast = 12;
        m_macdSlow = 26;
        m_macdSignal = 9;
        m_atrMultiplierSL = 3.0;
        m_atrMultiplierTP = 6.0;
        m_minBarsSinceSignal = 3;
        m_inTrend = false;
        m_lastBarTime = 0;
    }
    
    // Initialize strategy
    virtual bool Initialize() override
    {
        // Set default config if not set
        if(m_config.symbol == "")
        {
            m_config.symbol = "EURUSD";
            m_config.timeframe = PERIOD_H1;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 1.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 1;
        }
        
        // Call base initialization
        if(!CStrategyBase::Initialize())
            return false;
        
        m_logger.Info("Creating indicators for EURUSD Trend-Following", m_moduleName);
        
        // Create indicators
        m_handleEMA_Fast = CreateIndicator("EMA_Fast", IND_MA, m_emaFastPeriod);
        m_handleEMA_Slow = CreateIndicator("EMA_Slow", IND_MA, m_emaSlowPeriod);
        m_handleADX = CreateIndicator("ADX", IND_ADX, m_adxPeriod);
        m_handleMACD = CreateIndicator("MACD", IND_MACD, m_macdFast, m_macdSlow, m_macdSignal);
        m_handleATR = CreateIndicator("ATR", IND_ATR, 14);
        
        // Validate indicators
        if(m_handleEMA_Fast == INVALID_HANDLE || m_handleEMA_Slow == INVALID_HANDLE ||
           m_handleADX == INVALID_HANDLE || m_handleMACD == INVALID_HANDLE ||
           m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create required indicators", m_moduleName);
            return false;
        }
        
        // Wait for indicator data
        if(!WaitForIndicatorData(m_handleEMA_Fast, m_emaSlowPeriod + 10) ||
           !WaitForIndicatorData(m_handleEMA_Slow, m_emaSlowPeriod + 10) ||
           !WaitForIndicatorData(m_handleADX, m_adxPeriod + 10) ||
           !WaitForIndicatorData(m_handleMACD, m_macdSlow + 10) ||
           !WaitForIndicatorData(m_handleATR, 14 + 10))
        {
            m_logger.Error("Timeout waiting for indicator data", m_moduleName);
            return false;
        }
        
        m_logger.Info("EURUSD Trend-Following strategy ready", m_moduleName);
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
        
        // Check if already in trade
        if(m_openPositions > 0)
        {
            signal.signalType = SIGNAL_NONE;
            return signal;
        }
        
        // Get current indicator values
        double emaFastCurrent = m_emaFast[0];
        double emaFastPrevious = m_emaFast[1];
        double emaSlowCurrent = m_emaSlow[0];
        double emaSlowPrevious = m_emaSlow[1];
        double adxCurrent = m_adx[0];
        double macdMain = m_macdMain[0];
        double macdSignal = m_macdSignal[0];
        
        // Check for bullish trend
        bool bullishCrossover = (emaFastPrevious <= emaSlowPrevious) && (emaFastCurrent > emaSlowCurrent);
        bool strongTrend = adxCurrent > m_adxThreshold;
        bool macdBullish = macdMain > macdSignal && macdMain > 0;
        
        if(bullishCrossover && strongTrend && macdBullish)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = CalculateConfidence(true, adxCurrent, macdMain, macdSignal);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            
            signal.reason = StringFormat("Bullish EMA Crossover + ADX=%.1f + MACD Bullish", adxCurrent);
            
            m_inTrend = true;
            return signal;
        }
        
        // Check for bearish trend
        bool bearishCrossover = (emaFastPrevious >= emaSlowPrevious) && (emaFastCurrent < emaSlowCurrent);
        bool macdBearish = macdMain < macdSignal && macdMain < 0;
        
        if(bearishCrossover && strongTrend && macdBearish)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = CalculateConfidence(false, adxCurrent, macdMain, macdSignal);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
            
            signal.reason = StringFormat("Bearish EMA Crossover + ADX=%.1f + MACD Bearish", adxCurrent);
            
            m_inTrend = true;
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
        
        // Check confidence threshold
        if(signal.confidence < 0.60)
        {
            m_logger.Debug(StringFormat("Signal confidence too low: %.2f", signal.confidence), m_moduleName);
            return false;
        }
        
        // Check if trading is allowed
        if(!IsTradingAllowed())
        {
            m_logger.Debug("Trading not allowed currently", m_moduleName);
            return false;
        }
        
        // Check minimum time between signals
        if(m_lastSignalTime > 0)
        {
            int barsSinceSignal = Bars(m_config.symbol, m_config.timeframe, m_lastSignalTime, TimeCurrent());
            if(barsSinceSignal < m_minBarsSinceSignal)
            {
                m_logger.Debug(StringFormat("Too soon since last signal (%d bars)", barsSinceSignal), m_moduleName);
                return false;
            }
        }
        
        // Validate stop loss and take profit
        if(signal.stopLoss <= 0 || signal.takeProfit <= 0)
        {
            m_logger.Error("Invalid SL/TP levels", m_moduleName);
            return false;
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
        
        // Update indicators
        if(!UpdateIndicators())
            return false;
        
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // Check for opposite signal
        double emaFastCurrent = m_emaFast[0];
        double emaSlowCurrent = m_emaSlow[0];
        double macdMain = m_macdMain[0];
        double macdSignal = m_macdSignal[0];
        
        if(posType == POSITION_TYPE_BUY)
        {
            // Close if bearish conditions
            if(emaFastCurrent < emaSlowCurrent || (macdMain < macdSignal && macdMain < 0))
            {
                m_logger.Info("Closing BUY position - Bearish signal detected", m_moduleName);
                return true;
            }
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            // Close if bullish conditions
            if(emaFastCurrent > emaSlowCurrent || (macdMain > macdSignal && macdMain > 0))
            {
                m_logger.Info("Closing SELL position - Bullish signal detected", m_moduleName);
                return true;
            }
        }
        
        return false;
    }
    
    // Should modify position
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Implement trailing stop logic here if needed
        return false;
    }
    
    // Get market condition
    virtual string GetMarketCondition() override
    {
        if(!UpdateIndicators())
            return "UNKNOWN";
        
        double adxCurrent = m_adx[0];
        
        if(adxCurrent > 40)
            return "STRONG_TREND";
        else if(adxCurrent > 25)
            return "TREND";
        else if(adxCurrent > 20)
            return "WEAK_TREND";
        else
            return "RANGING";
    }
    
private:
    // Update all indicators
    bool UpdateIndicators()
    {
        if(CopyBuffer(m_handleEMA_Fast, 0, 0, 3, m_emaFast) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Slow, 0, 0, 3, m_emaSlow) <= 0) return false;
        if(CopyBuffer(m_handleADX, 0, 0, 3, m_adx) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 0, 0, 3, m_macdMain) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 1, 0, 3, m_macdSignal) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
    
    // Calculate signal confidence
    double CalculateConfidence(bool isBullish, double adx, double macdMain, double macdSignal)
    {
        double confidence = 0.5; // Base confidence
        
        // ADX strength component (max +0.25)
        if(adx > 40)
            confidence += 0.25;
        else if(adx > 30)
            confidence += 0.15;
        else if(adx > 25)
            confidence += 0.10;
        
        // MACD strength component (max +0.25)
        double macdDiff = MathAbs(macdMain - macdSignal);
        if(macdDiff > 0.0010)
            confidence += 0.25;
        else if(macdDiff > 0.0005)
            confidence += 0.15;
        else
            confidence += 0.05;
        
        return MathMin(confidence, 1.0);
    }
};
//+------------------------------------------------------------------+