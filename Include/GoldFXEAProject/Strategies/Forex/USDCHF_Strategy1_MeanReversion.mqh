//+------------------------------------------------------------------+
//|                                     USDCHF_Strategy1_MeanReversion.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| USDCHF Strategy 1: Safe Haven Mean Reversion System (1H)         |
//+------------------------------------------------------------------+
class CUSDCHF_Strategy1_MeanReversion : public CStrategyBase
{
private:
    int m_bbPeriod;
    double m_bbDev;
    int m_rsiPeriod;
    int m_atrPeriod;
    datetime m_lastBarTime;

public:
    CUSDCHF_Strategy1_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("USDCHF_Strategy1_MeanReversion", logger, riskManager)
    {
        m_bbPeriod = 20;
        m_bbDev = 2.0;
        m_rsiPeriod = 14;
        m_atrPeriod = 14;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "USDCHF";
            m_config.timeframe = PERIOD_H1;
            m_config.strategyType = STRATEGY_MEAN_REVERSION;
            m_config.riskPercent = 1.0;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 602;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleBB = CreateIndicator("BB_20_2_1H", "BollingerBands", m_bbPeriod, 0, m_bbDev);
        m_handleRSI = CreateIndicator("RSI_14_1H", "RSI", m_rsiPeriod);
        m_handleATR = CreateIndicator("ATR_14_1H", "ATR", m_atrPeriod);
        
        return (m_handleBB != INVALID_HANDLE && m_handleRSI != INVALID_HANDLE && m_handleATR != INVALID_HANDLE);
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
        
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        double bbUpper = m_bbUpper[1];
        double bbLower = m_bbLower[1];
        double rsi = m_rsi[1];
        
        if(closePrice < bbLower && rsi < 30)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.82;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "USDCHF-1: BB + RSI Mean Reversion (1H)";
             return signal;
        }
        
        if(closePrice > bbUpper && rsi > 70)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.82;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "USDCHF-1: BB + RSI Mean Reversion (1H)";
             return signal;
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override { return (signal.signalType != SIGNAL_NONE); }
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override { stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.5); }
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override 
    { 
        double bbMiddle = m_bbMain[1];
        takeProfit = bbMiddle; 
    }
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_bbMain, 3);
        ArrayResize(m_bbUpper, 3);
        ArrayResize(m_bbLower, 3);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_atr, 3);
        if(CopyBuffer(m_handleBB, 0, 0, 3, m_bbMain) <= 0) return false;
        if(CopyBuffer(m_handleBB, 1, 0, 3, m_bbUpper) <= 0) return false;
        if(CopyBuffer(m_handleBB, 2, 0, 3, m_bbLower) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        return true;
    }
};
