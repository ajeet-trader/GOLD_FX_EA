//+------------------------------------------------------------------+
//|                        AUDUSD_Strategy1_Breakout_MeanReversion.mqh|
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

class CAUDUSD_Strategy1_Breakout_MeanReversion : public CStrategyBase
{
private:
    int m_swingPeriod;
    int m_atrPeriod;
    
    int m_handleATR;
    double m_atrBuf[];

public:
    CAUDUSD_Strategy1_Breakout_MeanReversion(CLogger* logger, CRiskManager* riskManager)
        : CStrategyBase("AUDUSD_Strat1_Breakout_MR", logger, riskManager)
    {
        m_swingPeriod = 20;
        m_atrPeriod = 14;
        
        m_handleATR = INVALID_HANDLE;
        ArraySetAsSeries(m_atrBuf, true);
    }
    
    ~CAUDUSD_Strategy1_Breakout_MeanReversion()
    {
        ReleaseIndicators();
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators for AUDUSD Strategy 1", m_moduleName);
            return false;
        }
        
        return true;
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        
        if(CopyBuffer(m_handleATR, 0, 0, 1, m_atrBuf) < 1) return signal;
        
        double atr = m_atrBuf[0];
        
        // Logic:
        // 1. Find lowest low of last N bars (excluding current)
        // 2. Check if Previous Bar broke below it but Closed above it (False Breakout)
        // Or Current Bar breaks and closes back inside? Guide says "Close back above support in 1-3 bars".
        // Let's implement simpler version: Previous Bar made a new Low but Closed > SwingLow.
        
        int lowestIndex = iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_swingPeriod, 1);
        int highestIndex = iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_swingPeriod, 1);
        
        if(lowestIndex == -1 || highestIndex == -1) return signal;
        
        double swingLow = iLow(m_config.symbol, m_config.timeframe, lowestIndex);
        double swingHigh = iHigh(m_config.symbol, m_config.timeframe, highestIndex);
        
        double prevLow = iLow(m_config.symbol, m_config.timeframe, 1);
        double prevHigh = iHigh(m_config.symbol, m_config.timeframe, 1);
        double prevClose = iClose(m_config.symbol, m_config.timeframe, 1);
        
        double currentClose = iClose(m_config.symbol, m_config.timeframe, 0);
        
        // Long Setup (False Breakout Down)
        // Break below support by 0.5 ATR
        // Close back above support
        
        // Check if Previous bar broke swing low significantly
        if(prevLow < (swingLow - (0.5 * atr)) && prevClose > swingLow)
        {
             // We have a rejection candle at support
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.75;
             signal.entryPrice = currentClose;
             signal.reason = "False Breakout Buy: Rejection at Swing Low";
             
             double sl, tp;
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, sl);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, tp);
             signal.stopLoss = sl;
             signal.takeProfit = tp;
        }
        // Short Setup (False Breakout Up)
        else if(prevHigh > (swingHigh + (0.5 * atr)) && prevClose < swingHigh)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.75;
             signal.entryPrice = currentClose;
             signal.reason = "False Breakout Sell: Rejection at Swing High";
             
             double sl, tp;
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, sl);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, tp);
             signal.stopLoss = sl;
             signal.takeProfit = tp;
        }
        
        return signal;
    }
    
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        double atr = 0;
        double atrBuf[];
        ArraySetAsSeries(atrBuf, true);
        CopyBuffer(m_handleATR, 0, 0, 1, atrBuf);
        atr = atrBuf[0];
        
        // SL: 1.5 ATR below swing low.
        // Simplified: 1.5 ATR from entry for now.
        
        double slDist = atr * 1.5;
        
        if(orderType == ORDER_TYPE_BUY)
            stopLoss = entryPrice - slDist;
        else
            stopLoss = entryPrice + slDist;
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // TP: Middle of range or opposite swing.
        // Let's use 2.0 ATR (approx R:R 1.33)
        
        double atr = 0;
        double atrBuf[];
        ArraySetAsSeries(atrBuf, true);
        CopyBuffer(m_handleATR, 0, 0, 1, atrBuf);
        atr = atrBuf[0];
        
        double tpDist = atr * 2.0;
        
        if(orderType == ORDER_TYPE_BUY)
            takeProfit = entryPrice + tpDist;
        else
            takeProfit = entryPrice - tpDist;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        if(signal.signalType == SIGNAL_NONE) return false;
        return true;
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }
};
