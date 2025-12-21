//+------------------------------------------------------------------+
//|                                         XAGUSD_Strategy1_Breakout.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| XAGUSD Strategy 1: Volatility Breakout with ATR Bands (4H)       |
//+------------------------------------------------------------------+
class CXAGUSD_Strategy1_Breakout : public CStrategyBase
{
private:
    int m_atrPeriod;
    int m_rangePeriod;
    int m_adxPeriod;
    double m_rangeMultiplier;
    datetime m_lastBarTime;

public:
    CXAGUSD_Strategy1_Breakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("XAGUSD_Strategy1_Breakout", logger, riskManager)
    {
        m_atrPeriod = 14;
        m_rangePeriod = 10;
        m_adxPeriod = 14;
        m_rangeMultiplier = 1.2; // Silver is more volatile than gold
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "XAGUSD";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_BREAKOUT;
            m_config.riskPercent = 1.0;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 501;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleATR = CreateIndicator("ATR_14_4H", "ATR", m_atrPeriod);
        m_handleADX = CreateIndicator("ADX_14_4H", "ADX", m_adxPeriod);
        
        return (m_handleATR != INVALID_HANDLE && m_handleADX != INVALID_HANDLE);
    }
    
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
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        if(!UpdateIndicators()) return signal;
        if(m_openPositions > 0) return signal;
        
        double atr = m_atr[1];
        double maxHigh = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_rangePeriod, 1));
        double minLow = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_rangePeriod, 1));
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        
        bool isConsolidating = (maxHigh - minLow) < (m_rangeMultiplier * atr);
        bool adxTrending = m_adx[1] > 25;
        
        bool breakoutLong = closePrice > (maxHigh + 0.2 * atr);
        bool breakoutShort = closePrice < (minLow - 0.2 * atr);
        
        if(isConsolidating && adxTrending && breakoutLong)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.82;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "XAG-1: Volatility Breakout (4H)";
             return signal;
        }
        
        if(isConsolidating && adxTrending && breakoutShort)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.82;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "XAG-1: Volatility Breakout (4H)";
             return signal;
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override { return (signal.signalType != SIGNAL_NONE); }
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override { stopLoss = CalculateATRStopLoss(entryPrice, orderType, 2.5); }
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override { takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 4.0); }
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override 
    {
        if(!PositionSelectByTicket(ticket)) return false;
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        if(m_atr[0] == 0) return false;
        double atr = m_atr[0];
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            double proposedSL = currentPrice - 2.0 * atr;
            if(proposedSL > currentSL) { newSL = proposedSL; newTP = PositionGetDouble(POSITION_TP); return true; }
        }
        else
        {
            double proposedSL = currentPrice + 2.0 * atr;
            if(proposedSL < currentSL || currentSL == 0) { newSL = proposedSL; newTP = PositionGetDouble(POSITION_TP); return true; }
        }
        return false;
    }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_atr, 3);
        ArrayResize(m_adx, 3);
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        if(CopyBuffer(m_handleADX, 0, 0, 3, m_adx) <= 0) return false;
        return true;
    }
};
