//+------------------------------------------------------------------+
//|                                         SOLUSD_Strategy1_Breakout.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| SOLUSD Strategy 1: Volatility Breakout Trend Strategy (4H)       |
//+------------------------------------------------------------------+
class CSOLUSD_Strategy1_Breakout : public CStrategyBase
{
private:
    // Strategy parameters
    int m_atrPeriod;
    int m_rangePeriod;
    int m_volPeriod;
    double m_rangeMultiplier;
    
    // Market state
    datetime m_lastBarTime;

public:
    // Constructor
    CSOLUSD_Strategy1_Breakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("SOLUSD_Strategy1_Breakout", logger, riskManager)
    {
        m_atrPeriod = 14;
        m_rangePeriod = 10;
        m_volPeriod = 20;
        m_rangeMultiplier = 1.5;
        
        m_lastBarTime = 0;
    }
    
    // Initialize
    virtual bool Initialize() override
    {
        // Default config
        if(m_config.symbol == "")
        {
            m_config.symbol = "SOLUSD";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_BREAKOUT;
            m_config.riskPercent = 0.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 404;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for SOLUSD Strategy 1", m_moduleName);
        
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
        double maxHigh = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_rangePeriod, 1));
        double minLow = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_rangePeriod, 1));
        
        // 1. Identify consolidation
        bool isConsolidating = (maxHigh - minLow) < (m_rangeMultiplier * atr);
        
        // 2. Breakout conditions
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        long volume = iVolume(m_config.symbol, m_config.timeframe, 1);
        double avgVol = 0;
        for(int i=1; i<=m_volPeriod; i++) avgVol += iVolume(m_config.symbol, m_config.timeframe, i);
        avgVol /= m_volPeriod;
        
        bool breakoutLong = closePrice > (maxHigh + 0.5 * atr) && volume > avgVol;
        bool breakoutShort = closePrice < (minLow - 0.5 * atr) && volume > avgVol;
        
        // Long Entry
        if(isConsolidating && breakoutLong)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.85;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "SOL-1: Volatility Breakout (4H)";
             return signal;
        }
        
        // Short Entry
        if(isConsolidating && breakoutShort)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.85;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "SOL-1: Volatility Breakout (4H)";
             return signal;
        }
        
        return signal;
    }
    
    // Validate Signal
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE);
    }

    // Stop Loss (2.0 * ATR)
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
         stopLoss = CalculateATRStopLoss(entryPrice, orderType, 2.0);
    }
    
    // Take Profit (2.0 * ATR)
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
         takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 2.0);
    }
    
    // Position Management
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time stop: 10 bars
        if(PositionSelectByTicket(ticket))
        {
            long timeOpen = PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - timeOpen > 10 * 4 * 3600) return true;
        }
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Trailing stop: 1.5 * ATR
        if(!PositionSelectByTicket(ticket)) return false;
        
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        
        if(m_atr[0] == 0) return false;
        
        double atr = m_atr[0];
        
        if(type == POSITION_TYPE_BUY)
        {
            double proposedSL = currentPrice - 1.5 * atr;
            if(proposedSL > currentSL)
            {
                newSL = proposedSL;
                newTP = PositionGetDouble(POSITION_TP);
                return true;
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            double proposedSL = currentPrice + 1.5 * atr;
            if(proposedSL < currentSL || currentSL == 0)
            {
                newSL = proposedSL;
                newTP = PositionGetDouble(POSITION_TP);
                return true;
            }
        }
        
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
