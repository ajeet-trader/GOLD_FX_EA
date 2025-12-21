//+------------------------------------------------------------------+
//|                                   ETHUSD_Strategy1_False_Breakout.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| ETHUSD Strategy 1: Mean Reverting False Breakout System (4H)     |
//+------------------------------------------------------------------+
class CETHUSD_Strategy1_False_Breakout : public CStrategyBase
{
private:
    // Strategy parameters
    int m_atrPeriod;
    int m_rangePeriod;
    double m_breakoutFactor;
    
    // Market state
    datetime m_lastBarTime;
    
    // Tracking false breakout state
    bool m_waitingForLongReturn;
    bool m_waitingForShortReturn;
    double m_brokenSupport;
    double m_brokenResistance;
    int m_barsSinceBreak;

public:
    // Constructor
    CETHUSD_Strategy1_False_Breakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("ETHUSD_Strategy1_False_Breakout", logger, riskManager)
    {
        m_atrPeriod = 14;
        m_rangePeriod = 20;
        m_breakoutFactor = 0.5;
        
        m_lastBarTime = 0;
        m_waitingForLongReturn = false;
        m_waitingForShortReturn = false;
        m_brokenSupport = 0;
        m_brokenResistance = 0;
        m_barsSinceBreak = 0;
    }
    
    // Initialize
    virtual bool Initialize() override
    {
        // Default config
        if(m_config.symbol == "")
        {
            m_config.symbol = "ETHUSD";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_MEAN_REVERSION;
            m_config.riskPercent = 0.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 403;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for ETHUSD Strategy 1", m_moduleName);
        
        // Indicators
        m_handleATR = CreateIndicator("ATR_14_4H", "ATR", m_atrPeriod);
        
        // Validate handles
        if(m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators", m_moduleName);
            return false;
        }
        
        return true;
    }
    
    // Process Tick
    virtual void ProcessTick(MqlTick &tick) override
    {
        datetime currentBarTime = iTime(m_config.symbol, m_config.timeframe, 0);
        if(currentBarTime == m_lastBarTime) return;
        m_lastBarTime = currentBarTime;
        
        m_openPositions = CountOpenPositions();
        TradeSignal signal = GenerateSignal();
        
        if(signal.signalType != SIGNAL_NONE && ValidateSignal(signal))
        {
            m_lastSignal = signal;
            m_lastSignalTime = TimeCurrent();
            m_logger.Info(StringFormat("Signal: %s, Conf: %.2f, Reason: %s", 
                SignalTypeToString(signal.signalType), signal.confidence, signal.reason), m_moduleName);
        }
    }
    
    // Generate Signal
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        if(!UpdateIndicators()) return signal;
        if(m_openPositions > 0) return signal;
        
        // Logic
        double atr = m_atr[1];
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        double highPrice = iHigh(m_config.symbol, m_config.timeframe, 1);
        double lowPrice = iLow(m_config.symbol, m_config.timeframe, 1);
        
        // Resistance/Support
        double resistance = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_rangePeriod, 2));
        double support = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_rangePeriod, 2));
        
        // 1. Check for new break
        if(!m_waitingForLongReturn && !m_waitingForShortReturn)
        {
            if(lowPrice < (support - m_breakoutFactor * atr))
            {
                m_waitingForLongReturn = true;
                m_brokenSupport = support;
                m_barsSinceBreak = 0;
            }
            else if(highPrice > (resistance + m_breakoutFactor * atr))
            {
                m_waitingForShortReturn = true;
                m_brokenResistance = resistance;
                m_barsSinceBreak = 0;
            }
        }
        else
        {
            m_barsSinceBreak++;
            
            // 2. Check for return back inside range
            if(m_waitingForLongReturn)
            {
                if(closePrice > m_brokenSupport)
                {
                    signal.signalType = SIGNAL_BUY;
                    signal.confidence = 0.86;
                    signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
                    CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
                    CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
                    signal.reason = "ETH-1: False Breakout Support (4H)";
                    
                    m_waitingForLongReturn = false;
                    return signal;
                }
                
                if(m_barsSinceBreak > 3) m_waitingForLongReturn = false;
            }
            else if(m_waitingForShortReturn)
            {
                if(closePrice < m_brokenResistance)
                {
                    signal.signalType = SIGNAL_SELL;
                    signal.confidence = 0.86;
                    signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
                    CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
                    CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
                    signal.reason = "ETH-1: False Breakout Resistance (4H)";
                    
                    m_waitingForShortReturn = false;
                    return signal;
                }
                
                if(m_barsSinceBreak > 3) m_waitingForShortReturn = false;
            }
        }
        
        return signal;
    }
    
    // Validate Signal
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE);
    }

    // Stop Loss (1.5 * ATR beyond spike)
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
         stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.5);
    }
    
    // Take Profit (Middle of range)
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
         double resistance = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_rangePeriod, 1));
         double support = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_rangePeriod, 1));
         takeProfit = (resistance + support) / 2.0;
    }
    
    // Position Management
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time stop: 8 bars
        if(PositionSelectByTicket(ticket))
        {
            long timeOpen = PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - timeOpen > 8 * 4 * 3600) return true;
        }
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_atr, 3);
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        return true;
    }
};
