//+------------------------------------------------------------------+
//|                             GBPUSD_Strategy2_RSI_MeanReversion.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| GBPUSD Strategy 2: RSI Overbought/Oversold with MA Confirmation   |
//+------------------------------------------------------------------+
class CGBPUSD_Strategy2_RSI_MeanReversion : public CStrategyBase
{
private:
    int m_rsiPeriod;
    int m_stochPeriod;
    int m_emaTrendPeriod;
    
    // int m_handleRSI; // Use base
    int m_handleEMA_Trend; // 4H
    
    // double m_rsi[]; // Use base
    double m_emaTrend[];
    
    datetime m_lastBarTime;

public:
    CGBPUSD_Strategy2_RSI_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("GBPUSD_Strategy2_RSI_MeanReversion", logger, riskManager)
    {
        m_rsiPeriod = 21;
        m_stochPeriod = 14;
        m_emaTrendPeriod = 50;
        
        m_handleRSI = INVALID_HANDLE;
        m_handleEMA_Trend = INVALID_HANDLE;
        
        ArraySetAsSeries(m_rsi, true);
        ArraySetAsSeries(m_emaTrend, true);
        
        m_lastBarTime = 0;
    }
    
    ~CGBPUSD_Strategy2_RSI_MeanReversion()
    {
        if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
        if(m_handleEMA_Trend != INVALID_HANDLE) IndicatorRelease(m_handleEMA_Trend);
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "GBPUSD";
            m_config.timeframe = PERIOD_M30;
            m_config.strategyType = STRATEGY_MEAN_REVERSION;
            m_config.riskPercent = 1.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 202;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for GBPUSD Strategy 2", m_moduleName);
        
        m_handleRSI = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_handleEMA_Trend = iMA(m_config.symbol, PERIOD_H4, m_emaTrendPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, 14);
        
        if(m_handleRSI == INVALID_HANDLE || m_handleEMA_Trend == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators", m_moduleName);
            return false;
        }
        
        return true;
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
        
        // Calculate StochRSI manually
        double stochRSI = CalculateStochRSI();
        
        double rsi = m_rsi[0];
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        double ema50_4H = m_emaTrend[0];
        
        // Yesterday's Low/High
        double prevDayLow = iLow(m_config.symbol, PERIOD_D1, 1);
        double prevDayHigh = iHigh(m_config.symbol, PERIOD_D1, 1);
        
        // Long Entry
        bool cond1 = rsi < 35;
        bool cond2 = stochRSI < 0.20;
        bool cond3 = close > ema50_4H; // Pullback in uptrend
        bool cond4 = close > prevDayLow; // Not breaking yesterday's low
        
        if(cond1 && cond2 && cond3 && cond4)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.75;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            
            // Stop Loss: Swing low - ATR. Simplified to Entry - 2*ATR if swing low not easily found, 
            // but logic says "Swing Low - ATR". Let's use recent lowest.
            double localLow = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, 10, 0));
            signal.stopLoss = localLow - m_atr[0];
            
            signal.takeProfit = signal.entryPrice + 2.5 * m_atr[0];
            signal.reason = "RSI Mean Reversion (Long)";
            return signal;
        }
        
        // Short Entry
        bool s_cond1 = rsi > 65;
        bool s_cond2 = stochRSI > 0.80;
        bool s_cond3 = close < ema50_4H;
        bool s_cond4 = close < prevDayHigh;
        
        if(s_cond1 && s_cond2 && s_cond3 && s_cond4)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.75;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            
            double localHigh = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, 10, 0));
            signal.stopLoss = localHigh + m_atr[0];
            
            signal.takeProfit = signal.entryPrice - 2.5 * m_atr[0];
            signal.reason = "RSI Mean Reversion (Short)";
            return signal;
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE);
    }

    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        // Handled in GenerateSignal
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // Handled in GenerateSignal
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Scaling Exit: Exit 50% when RSI crosses 50.
        // Full exit at TP.
        // We can't do partial here easily.
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }

private:
    bool UpdateIndicators()
    {
        // We need history for StochRSI
        int lookback = m_stochPeriod + m_rsiPeriod; 
        ArrayResize(m_rsi, lookback + 1);
        ArrayResize(m_emaTrend, 3);
        ArrayResize(m_atr, 3);
        
        if(CopyBuffer(m_handleRSI, 0, 0, lookback + 1, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Trend, 0, 0, 3, m_emaTrend) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
    
    double CalculateStochRSI()
    {
        // StochRSI = (CurrentRSI - LowestRSI) / (HighestRSI - LowestRSI)
        // over stochPeriod.
        
        double currentRSI = m_rsi[0];
        double minRSI = 100.0;
        double maxRSI = 0.0;
        
        for(int i = 0; i < m_stochPeriod; i++)
        {
            double r = m_rsi[i];
            if(r < minRSI) minRSI = r;
            if(r > maxRSI) maxRSI = r;
        }
        
        if(maxRSI - minRSI == 0) return 0.5;
        
        return (currentRSI - minRSI) / (maxRSI - minRSI);
    }
};
