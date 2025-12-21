//+------------------------------------------------------------------+
//|                                         GBPJPY_Strategy1_Ichimoku.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| GBPJPY Strategy 1: Ichimoku + RSI Mean Reversion (4H)            |
//+------------------------------------------------------------------+
class CGBPJPY_Strategy1_Ichimoku : public CStrategyBase
{
private:
    int m_tenkanPeriod;
    int m_kijunPeriod;
    int m_senkouPeriod;
    int m_emaPeriod;
    int m_rsiPeriod;
    int m_atrPeriod;
    
    int m_handleIchimoku;
    int m_handleEMA_Trend;
    
    double m_tenkan[];
    double m_kijun[];
    double m_senkouA[];
    double m_senkouB[];
    double m_emaTrend[];
    
    datetime m_lastBarTime;

public:
    CGBPJPY_Strategy1_Ichimoku(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("GBPJPY_Strategy1_Ichimoku", logger, riskManager)
    {
        m_tenkanPeriod = 9;
        m_kijunPeriod = 26;
        m_senkouPeriod = 52;
        m_emaPeriod = 200;
        m_rsiPeriod = 14;
        m_atrPeriod = 14;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "GBPJPY";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_MEAN_REVERSION;
            m_config.riskPercent = 1.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 801;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleIchimoku = iIchimoku(m_config.symbol, m_config.timeframe, m_tenkanPeriod, m_kijunPeriod, m_senkouPeriod);
        m_handleEMA_Trend = iMA(m_config.symbol, m_config.timeframe, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleRSI = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        return (m_handleIchimoku != INVALID_HANDLE && m_handleEMA_Trend != INVALID_HANDLE && 
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
        
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        double emaTrend = m_emaTrend[1];
        double kijun = m_kijun[1];
        double cloudTop = MathMax(m_senkouA[1], m_senkouB[1]);
        double cloudBottom = MathMin(m_senkouA[1], m_senkouB[1]);
        double rsi = m_rsi[1];
        
        bool inUptrend = closePrice > emaTrend && closePrice > cloudTop;
        bool inDowntrend = closePrice < emaTrend && closePrice < cloudBottom;
        
        // Buy Setup: In uptrend, pull back to Kijun or Cloud, RSI < 40
        if(inUptrend && closePrice <= kijun * 1.001 && rsi < 45)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.81;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "GBPJPY-1: Ichimoku + RSI Dip (4H)";
             return signal;
        }
        
        // Sell Setup: In downtrend, pull back to Kijun or Cloud, RSI > 60
        if(inDowntrend && closePrice >= kijun * 0.999 && rsi > 55)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.81;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "GBPJPY-1: Ichimoku + RSI Rally (4H)";
             return signal;
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override { return (signal.signalType != SIGNAL_NONE); }
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override { stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.5); }
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override { takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 3.0); }
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_tenkan, 3); ArraySetAsSeries(m_tenkan, true);
        ArrayResize(m_kijun, 3); ArraySetAsSeries(m_kijun, true);
        ArrayResize(m_senkouA, 3); ArraySetAsSeries(m_senkouA, true);
        ArrayResize(m_senkouB, 3); ArraySetAsSeries(m_senkouB, true);
        ArrayResize(m_emaTrend, 3); ArraySetAsSeries(m_emaTrend, true);
        ArrayResize(m_rsi, 3); ArraySetAsSeries(m_rsi, true);
        ArrayResize(m_atr, 3); ArraySetAsSeries(m_atr, true);
        
        if(CopyBuffer(m_handleIchimoku, 0, 0, 3, m_tenkan) <= 0) return false;
        if(CopyBuffer(m_handleIchimoku, 1, 0, 3, m_kijun) <= 0) return false;
        if(CopyBuffer(m_handleIchimoku, 2, 0, 3, m_senkouA) <= 0) return false;
        if(CopyBuffer(m_handleIchimoku, 3, 0, 3, m_senkouB) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Trend, 0, 0, 3, m_emaTrend) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
};
