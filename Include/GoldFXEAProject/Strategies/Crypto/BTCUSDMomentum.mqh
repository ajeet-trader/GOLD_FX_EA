//+------------------------------------------------------------------+
//|                                         BTCUSDMomentum.mqh       |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| BTCUSD M30 Momentum Strategy                                      |
//| Uses: RSI(14) + Stochastic(5,3,3) + Volume Profile              |
//+------------------------------------------------------------------+
class CBTCUSDMomentum : public CStrategyBase
{
private:
    // Strategy parameters
    int m_rsiPeriod;
    double m_rsiOverbought;
    double m_rsiOversold;
    int m_stochKPeriod;
    int m_stochDPeriod;
    int m_stochSlowing;
    double m_volumeThreshold;
    double m_atrMultiplierSL;
    double m_atrMultiplierTP;
    int m_minBarsSinceSignal;
    
    // Volume tracking
    int m_handleVolume;
    double m_volumeMA[];
    double m_volumeCurrent[];
    
    // Market state
    datetime m_lastBarTime;
    
public:
    // Constructor
    CBTCUSDMomentum(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("BTCUSD_Momentum", logger, riskManager)
    {
        // Default parameters (adjusted for crypto volatility)
        m_rsiPeriod = 14;
        m_rsiOverbought = 70.0;
        m_rsiOversold = 30.0;
        m_stochKPeriod = 5;
        m_stochDPeriod = 3;
        m_stochSlowing = 3;
        m_volumeThreshold = 1.3;  // Lower threshold for crypto
        m_atrMultiplierSL = 2.0;  // Tighter stops for volatile crypto
        m_atrMultiplierTP = 4.0;
        m_minBarsSinceSignal = 2;
        m_lastBarTime = 0;
        m_handleVolume = INVALID_HANDLE;
        
        ArraySetAsSeries(m_volumeMA, true);
        ArraySetAsSeries(m_volumeCurrent, true);
    }
    
    // Initialize strategy
    virtual bool Initialize() override
    {
        // Set default config if not set
        if(m_config.symbol == "")
        {
            m_config.symbol = "BTCUSD";
            m_config.timeframe = PERIOD_M30;
            m_config.strategyType = STRATEGY_MOMENTUM;
            m_config.riskPercent = 1.0;  // Lower risk for volatile crypto
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 3;
        }
        
        // Call base initialization
        if(!CStrategyBase::Initialize())
            return false;
        
        m_logger.Info("Creating indicators for BTCUSD Momentum", m_moduleName);
        
        // Create indicators
        m_handleRSI = CreateIndicator("RSI", "RSI", m_rsiPeriod);
        m_handleStochastic = CreateIndicator("Stochastic", "STOCHASTIC", 
                                            m_stochKPeriod, m_stochDPeriod, m_stochSlowing);
        m_handleATR = CreateIndicator("ATR", "ATR", 14);
        m_handleVolume = iVolumes(m_config.symbol, m_config.timeframe, VOLUME_TICK);
        
        // Validate indicators
        if(m_handleRSI == INVALID_HANDLE || m_handleStochastic == INVALID_HANDLE || 
           m_handleATR == INVALID_HANDLE || m_handleVolume == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create required indicators", m_moduleName);
            return false;
        }
        
        // Wait for indicator data
        if(!WaitForIndicatorData(m_handleRSI, m_rsiPeriod + 10) ||
           !WaitForIndicatorData(m_handleStochastic, m_stochKPeriod + 10) ||
           !WaitForIndicatorData(m_handleATR, 14 + 10) ||
           !WaitForIndicatorData(m_handleVolume, 20))
        {
            m_logger.Error("Timeout waiting for indicator data", m_moduleName);
            return false;
        }
        
        m_logger.Info("BTCUSD Momentum strategy ready", m_moduleName);
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
        
        // Get current values
        double rsiCurrent = m_rsi[0];
        double rsiPrevious = m_rsi[1];
        double stochMain = m_stochMain[0];
        double stochSignal = m_stochSignal[0];
        double stochMainPrev = m_stochMain[1];
        double stochSignalPrev = m_stochSignal[1];
        double volumeCurrent = m_volumeCurrent[0];
        double volumeMA = m_volumeMA[0];
        
        // Check for bullish momentum
        bool rsiRising = (rsiCurrent > 50.0) && (rsiCurrent > rsiPrevious);
        bool stochBullishCross = (stochMainPrev <= stochSignalPrev) && (stochMain > stochSignal);
        bool highVolume = (volumeCurrent > volumeMA * m_volumeThreshold);
        bool rsiNotOverbought = (rsiCurrent < m_rsiOverbought);
        
        if(rsiRising && stochBullishCross && highVolume && rsiNotOverbought)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = CalculateConfidence(true, rsiCurrent, stochMain, 
                                                   volumeCurrent, volumeMA);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            
            signal.reason = StringFormat("Bullish Momentum: RSI=%.1f, Stoch Cross, Vol=%.1fx",
                                        rsiCurrent, volumeCurrent / volumeMA);
            return signal;
        }
        
        // Check for bearish momentum
        bool rsiFalling = (rsiCurrent < 50.0) && (rsiCurrent < rsiPrevious);
        bool stochBearishCross = (stochMainPrev >= stochSignalPrev) && (stochMain < stochSignal);
        bool rsiNotOversold = (rsiCurrent > m_rsiOversold);
        
        if(rsiFalling && stochBearishCross && highVolume && rsiNotOversold)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = CalculateConfidence(false, rsiCurrent, stochMain,
                                                   volumeCurrent, volumeMA);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
            
            signal.reason = StringFormat("Bearish Momentum: RSI=%.1f, Stoch Cross, Vol=%.1fx",
                                        rsiCurrent, volumeCurrent / volumeMA);
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
        
        if(signal.confidence < 0.60)
        {
            m_logger.Debug(StringFormat("Signal confidence too low: %.2f", signal.confidence), m_moduleName);
            return false;
        }
        
        if(!IsTradingAllowed())
        {
            m_logger.Debug("Trading not allowed currently", m_moduleName);
            return false;
        }
        
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
        
        double rsiCurrent = m_rsi[0];
        double stochMain = m_stochMain[0];
        double stochSignal = m_stochSignal[0];
        
        if(posType == POSITION_TYPE_BUY)
        {
            // Close if RSI overbought or stochastic bearish cross
            if(rsiCurrent > m_rsiOverbought || (stochMain < stochSignal && stochMain > 80))
            {
                m_logger.Info("Closing BUY position - Momentum reversal", m_moduleName);
                return true;
            }
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            // Close if RSI oversold or stochastic bullish cross
            if(rsiCurrent < m_rsiOversold || (stochMain > stochSignal && stochMain < 20))
            {
                m_logger.Info("Closing SELL position - Momentum reversal", m_moduleName);
                return true;
            }
        }
        
        return false;
    }
    
    // Should modify position
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }
    
    // Get market condition
    virtual string GetMarketCondition() override
    {
        if(!UpdateIndicators())
            return "UNKNOWN";
        
        double rsiCurrent = m_rsi[0];
        
        if(rsiCurrent > 70)
            return "OVERBOUGHT";
        else if(rsiCurrent < 30)
            return "OVERSOLD";
        else if(rsiCurrent > 45 && rsiCurrent < 55)
            return "NEUTRAL";
        else
            return "TRENDING";
    }
    
private:
    // Update all indicators
    bool UpdateIndicators()
    {
        ArrayResize(m_rsi, 3);
        ArrayResize(m_stochMain, 3);
        ArrayResize(m_stochSignal, 3);
        ArrayResize(m_atr, 3);
        
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleStochastic, 0, 0, 3, m_stochMain) <= 0) return false;
        if(CopyBuffer(m_handleStochastic, 1, 0, 3, m_stochSignal) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        if(CopyBuffer(m_handleVolume, 0, 0, 3, m_volumeCurrent) <= 0) return false;
        
        // Calculate volume MA
        ArrayResize(m_volumeMA, 1);
        m_volumeMA[0] = 0.0;
        double tempVolume[];
        ArraySetAsSeries(tempVolume, true);
        
        if(CopyBuffer(m_handleVolume, 0, 0, 20, tempVolume) > 0)
        {
            double sum = 0.0;
            for(int i = 0; i < 20; i++)
                sum += tempVolume[i];
            m_volumeMA[0] = sum / 20.0;
        }
        
        return true;
    }
    
    // Calculate signal confidence
    double CalculateConfidence(bool isBullish, double rsi, double stoch, 
                              double volumeCurrent, double volumeMA)
    {
        double confidence = 0.5;
        
        // RSI momentum component (max +0.25)
        double rsiStrength = MathAbs(rsi - 50.0);
        if(rsiStrength > 20)
            confidence += 0.25;
        else if(rsiStrength > 10)
            confidence += 0.15;
        
        // Stochastic position component (max +0.15)
        if(isBullish && stoch < 50)
            confidence += 0.15;
        else if(!isBullish && stoch > 50)
            confidence += 0.15;
        
        // Volume component (max +0.10)
        double volumeRatio = volumeCurrent / volumeMA;
        if(volumeRatio > 1.5)
            confidence += 0.10;
        else if(volumeRatio > 1.3)
            confidence += 0.05;
        
        return MathMin(confidence, 1.0);
    }
    
    // Deinitialize
    virtual void Deinitialize() override
    {
        if(m_handleVolume != INVALID_HANDLE)
        {
            IndicatorRelease(m_handleVolume);
            m_handleVolume = INVALID_HANDLE;
        }
        
        CStrategyBase::Deinitialize();
    }
};
//+------------------------------------------------------------------+