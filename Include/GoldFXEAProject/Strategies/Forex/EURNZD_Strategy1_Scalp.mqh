//+------------------------------------------------------------------+
//|                                         EURNZD_Strategy1_Scalp.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| EURNZD Strategy 1: Intraday S/R Scalp (15M)                      |
//+------------------------------------------------------------------+
class CEURNZD_Strategy1_Scalp : public CStrategyBase
{
private:
    int m_rangePeriod;
    int m_atrPeriod;
    datetime m_lastBarTime;

public:
    CEURNZD_Strategy1_Scalp(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("EURNZD_Strategy1_Scalp", logger, riskManager)
    {
        m_rangePeriod = 20;
        m_atrPeriod = 14;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "EURNZD";
            m_config.timeframe = PERIOD_M15;
            m_config.strategyType = STRATEGY_SCALPING;
            m_config.riskPercent = 0.5;
            m_config.maxOpenTrades = 2;
            m_config.magicNumber = EA_MAGIC_NUMBER + 901;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        m_handleATR = CreateIndicator("ATR_14_15M", "ATR", m_atrPeriod);
        return (m_handleATR != INVALID_HANDLE);
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
        if(m_openPositions >= m_config.maxOpenTrades) return signal;
        
        double maxHigh = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_rangePeriod, 1));
        double minLow = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_rangePeriod, 1));
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        
        if(closePrice > maxHigh)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.78;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "EURNZD-1: S/R Scalp Breakout (15M)";
             return signal;
        }
        
        if(closePrice < minLow)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.78;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "EURNZD-1: S/R Scalp Breakout (15M)";
             return signal;
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override { return (signal.signalType != SIGNAL_NONE); }
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override { stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.0); }
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override { takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 2.0); }
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_atr, 3);
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        return true;
    }
};
