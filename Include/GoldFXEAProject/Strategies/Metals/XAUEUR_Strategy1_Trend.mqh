//+------------------------------------------------------------------+
//|                                           XAUEUR_Strategy1_Trend.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| XAUEUR Strategy 1: Gold/Euro Cross Trend Strategy (4H)           |
//+------------------------------------------------------------------+
class CXAUEUR_Strategy1_Trend : public CStrategyBase
{
private:
    int m_emaFastPeriod;
    int m_emaSlowPeriod;
    int m_rsiPeriod;
    int m_atrPeriod;
    datetime m_lastBarTime;

public:
    CXAUEUR_Strategy1_Trend(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("XAUEUR_Strategy1_Trend", logger, riskManager)
    {
        m_emaFastPeriod = 20;
        m_emaSlowPeriod = 50;
        m_rsiPeriod = 14;
        m_atrPeriod = 14;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "XAUEUR";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 1.0;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 502;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleEMA_Fast = CreateIndicator("EMA_20_4H", "MA", m_emaFastPeriod);
        m_handleEMA_Slow = CreateIndicator("EMA_50_4H", "MA", m_emaSlowPeriod);
        m_handleRSI = CreateIndicator("RSI_14_4H", "RSI", m_rsiPeriod);
        m_handleATR = CreateIndicator("ATR_14_4H", "ATR", m_atrPeriod);
        
        return (m_handleEMA_Fast != INVALID_HANDLE && m_handleEMA_Slow != INVALID_HANDLE && 
                m_handleRSI != INVALID_HANDLE && m_handleATR != INVALID_HANDLE);
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
        }
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        if(!UpdateIndicators()) return signal;
        if(m_openPositions > 0) return signal;
        
        bool crossoverLong = m_emaFast[1] > m_emaSlow[1] && m_emaFast[2] <= m_emaSlow[2];
        bool crossoverShort = m_emaFast[1] < m_emaSlow[1] && m_emaFast[2] >= m_emaSlow[2];
        
        bool rsiBullish = m_rsi[1] > 50;
        bool rsiBearish = m_rsi[1] < 50;
        
        if(crossoverLong && rsiBullish)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.85;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "XAUEUR-1: EMA Cross + RSI (4H)";
             return signal;
        }
        
        if(crossoverShort && rsiBearish)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.85;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "XAUEUR-1: EMA Cross + RSI (4H)";
             return signal;
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override { return (signal.signalType != SIGNAL_NONE); }
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override { stopLoss = CalculateATRStopLoss(entryPrice, orderType, 2.0); }
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override { takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 3.0); }
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_emaFast, 3);
        ArrayResize(m_emaSlow, 3);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_atr, 3);
        if(CopyBuffer(m_handleEMA_Fast, 0, 0, 3, m_emaFast) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Slow, 0, 0, 3, m_emaSlow) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        return true;
    }
};
