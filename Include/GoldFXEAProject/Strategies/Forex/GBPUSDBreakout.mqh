//+------------------------------------------------------------------+
//|                                         GBPUSDBreakout.mqh       |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| GBPUSD M30 Breakout Strategy                                      |
//| Uses: Bollinger Bands (20,2) + Volume spike + ATR expansion      |
//+------------------------------------------------------------------+
class CGBPUSDBreakout : public CStrategyBase
{
private:
    // Strategy parameters
    int m_bbPeriod;
    double m_bbDeviation;
    int m_atrPeriod;
    double m_volumeMultiplier;
    double m_atrExpansionThreshold;
    double m_atrMultiplierSL;
    double m_atrMultiplierTP;
    int m_minBarsSinceSignal;
    
    // Volume tracking
    int m_handleVolume;
    double m_volumeMA[];
    double m_volumeCurrent[];
    
    // Market state
    datetime m_lastBarTime;
    double m_lastATR;
    
public:
    // Constructor
    CGBPUSDBreakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("GBPUSD_Breakout", logger, riskManager)
    {
        // Default parameters
        m_bbPeriod = 20;
        m_bbDeviation = 2.0;
        m_atrPeriod = 14;
        m_volumeMultiplier = 1.5;
        m_atrExpansionThreshold = 1.2;
        m_atrMultiplierSL = 2.5;
        m_atrMultiplierTP = 5.0;
        m_minBarsSinceSignal = 2;
        m_lastBarTime = 0;
        m_lastATR = 0.0;
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
            m_config.symbol = "GBPUSD";
            m_config.timeframe = PERIOD_M30;
            m_config.strategyType = STRATEGY_BREAKOUT;
            m_config.riskPercent = 2.0;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 2;
        }
        
        // Call base initialization
        if(!CStrategyBase::Initialize())
            return false;
        
        m_logger.Info("Creating indicators for GBPUSD Breakout", m_moduleName);
        
        // Create indicators
        m_handleBB = CreateIndicator("Bollinger Bands", IND_BANDS, m_bbPeriod);
        m_handleATR = CreateIndicator("ATR", IND_ATR, m_atrPeriod);
        
        // Create volume indicator (iVolumes for tick volume)
        m_handleVolume = iVolumes(m_config.symbol, m_config.timeframe, VOLUME_TICK);
        
        // Validate indicators
        if(m_handleBB == INVALID_HANDLE || m_handleATR == INVALID_HANDLE || 
           m_handleVolume == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create required indicators", m_moduleName);
            return false;
        }
        
        // Wait for indicator data
        if(!WaitForIndicatorData(m_handleBB, m_bbPeriod + 10) ||
           !WaitForIndicatorData(m_handleATR, m_atrPeriod + 10) ||
           !WaitForIndicatorData(m_handleVolume, m_bbPeriod + 10))
        {
            m_logger.Error("Timeout waiting for indicator data", m_moduleName);
            return false;
        }
        
        m_logger.Info("GBPUSD Breakout strategy ready", m_moduleName);
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
        double bbUpper = m_bbUpper[0];
        double bbMiddle = m_bbMiddle[0];
        double bbLower = m_bbLower[0];
        double atrCurrent = m_atr[0];
        double atrPrevious = m_atr[1];
        double volumeCurrent = m_volumeCurrent[0];
        double volumeMA = m_volumeMA[0];
        
        // Get current price
        MqlTick tick;
        if(!SymbolInfoTick(m_config.symbol, tick))
            return signal;
        
        double currentPrice = (tick.ask + tick.bid) / 2.0;
        
        // Check for ATR expansion
        bool atrExpanding = (atrCurrent > atrPrevious * m_atrExpansionThreshold);
        
        // Check for volume spike
        bool volumeSpike = (volumeCurrent > volumeMA * m_volumeMultiplier);
        
        // Check for bullish breakout
        bool bullishBreakout = (currentPrice > bbUpper);
        
        if(bullishBreakout && volumeSpike && atrExpanding)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = CalculateConfidence(true, currentPrice, bbUpper, bbMiddle, 
                                                   volumeCurrent, volumeMA, atrCurrent, atrPrevious);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            
            signal.reason = StringFormat("Bullish BB Breakout + Volume Spike (%.1fx) + ATR Expansion",
                                        volumeCurrent / volumeMA);
            
            m_lastATR = atrCurrent;
            return signal;
        }
        
        // Check for bearish breakout
        bool bearishBreakout = (currentPrice < bbLower);
        
        if(bearishBreakout && volumeSpike && atrExpanding)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = CalculateConfidence(false, currentPrice, bbLower, bbMiddle,
                                                   volumeCurrent, volumeMA, atrCurrent, atrPrevious);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
            
            signal.reason = StringFormat("Bearish BB Breakout + Volume Spike (%.1fx) + ATR Expansion",
                                        volumeCurrent / volumeMA);
            
            m_lastATR = atrCurrent;
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
        if(signal.confidence < 0.65)
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
        double bbMiddle = m_bbMiddle[0];
        
        MqlTick tick;
        if(!SymbolInfoTick(m_config.symbol, tick))
            return false;
        
        double currentPrice = (tick.ask + tick.bid) / 2.0;
        
        // Close on retest of BB middle (mean reversion)
        if(posType == POSITION_TYPE_BUY)
        {
            if(currentPrice <= bbMiddle)
            {
                m_logger.Info("Closing BUY position - Price returned to BB middle", m_moduleName);
                return true;
            }
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            if(currentPrice >= bbMiddle)
            {
                m_logger.Info("Closing SELL position - Price returned to BB middle", m_moduleName);
                return true;
            }
        }
        
        return false;
    }
    
    // Should modify position
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // No modification logic for breakout strategy
        return false;
    }
    
    // Get market condition
    virtual string GetMarketCondition() override
    {
        if(!UpdateIndicators())
            return "UNKNOWN";
        
        double bbWidth = (m_bbUpper[0] - m_bbLower[0]) / m_bbMiddle[0] * 100.0;
        double atrCurrent = m_atr[0];
        
        if(bbWidth < 1.0 && atrCurrent < m_lastATR)
            return "CONSOLIDATION";
        else if(bbWidth > 3.0 && atrCurrent > m_lastATR * 1.5)
            return "HIGH_VOLATILITY";
        else
            return "NORMAL";
    }
    
private:
    // Update all indicators
    bool UpdateIndicators()
    {
        if(CopyBuffer(m_handleBB, 1, 0, 3, m_bbUpper) <= 0) return false;
        if(CopyBuffer(m_handleBB, 0, 0, 3, m_bbMiddle) <= 0) return false;
        if(CopyBuffer(m_handleBB, 2, 0, 3, m_bbLower) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        if(CopyBuffer(m_handleVolume, 0, 0, 3, m_volumeCurrent) <= 0) return false;
        
        // Calculate volume MA
        ArrayResize(m_volumeMA, 1);
        m_volumeMA[0] = 0.0;
        double tempVolume[];
        ArraySetAsSeries(tempVolume, true);
        
        if(CopyBuffer(m_handleVolume, 0, 0, m_bbPeriod, tempVolume) > 0)
        {
            double sum = 0.0;
            for(int i = 0; i < m_bbPeriod; i++)
                sum += tempVolume[i];
            m_volumeMA[0] = sum / m_bbPeriod;
        }
        
        return true;
    }
    
    // Calculate signal confidence
    double CalculateConfidence(bool isBullish, double price, double bbBound, double bbMiddle,
                              double volumeCurrent, double volumeMA, double atrCurrent, double atrPrevious)
    {
        double confidence = 0.5; // Base confidence
        
        // Breakout strength (max +0.25)
        double breakoutDistance = MathAbs(price - bbBound) / (bbBound - bbMiddle);
        if(breakoutDistance > 0.5)
            confidence += 0.25;
        else if(breakoutDistance > 0.3)
            confidence += 0.15;
        else
            confidence += 0.05;
        
        // Volume component (max +0.15)
        double volumeRatio = volumeCurrent / volumeMA;
        if(volumeRatio > 2.0)
            confidence += 0.15;
        else if(volumeRatio > 1.5)
            confidence += 0.10;
        
        // ATR expansion component (max +0.10)
        double atrRatio = atrCurrent / atrPrevious;
        if(atrRatio > 1.3)
            confidence += 0.10;
        else if(atrRatio > 1.2)
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