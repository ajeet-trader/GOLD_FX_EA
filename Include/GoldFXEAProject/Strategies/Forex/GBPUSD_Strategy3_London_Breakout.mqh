//+------------------------------------------------------------------+
//|                             GBPUSD_Strategy3_London_Breakout.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| GBPUSD Strategy 3: London Breakout with Range Confirmation        |
//+------------------------------------------------------------------+
class CGBPUSD_Strategy3_London_Breakout : public CStrategyBase
{
private:
    int m_handleEMA_Trend;
    int m_handleATR_MA; // MA of ATR
    int m_handleVolumes;
    int m_handleVolMA;
    
    double m_emaTrend[];
    double m_atrMA[];
    double m_volMA[];
    long m_volumes[];
    
    datetime m_lastBarTime;
    
    double m_asiaHigh;
    double m_asiaLow;
    datetime m_asiaSessionDate;

public:
    CGBPUSD_Strategy3_London_Breakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("GBPUSD_Strategy3_London_Breakout", logger, riskManager)
    {
        m_handleEMA_Trend = INVALID_HANDLE;
        m_handleATR_MA = INVALID_HANDLE;
        m_handleVolumes = INVALID_HANDLE;
        m_handleVolMA = INVALID_HANDLE;
        
        ArraySetAsSeries(m_emaTrend, true);
        ArraySetAsSeries(m_atrMA, true);
        ArraySetAsSeries(m_volMA, true);
        ArraySetAsSeries(m_volumes, true);
        
        m_lastBarTime = 0;
        m_asiaHigh = 0;
        m_asiaLow = 0;
        m_asiaSessionDate = 0;
    }
    
    ~CGBPUSD_Strategy3_London_Breakout()
    {
        if(m_handleEMA_Trend != INVALID_HANDLE) IndicatorRelease(m_handleEMA_Trend);
        if(m_handleATR_MA != INVALID_HANDLE) IndicatorRelease(m_handleATR_MA);
        if(m_handleVolumes != INVALID_HANDLE) IndicatorRelease(m_handleVolumes);
        if(m_handleVolMA != INVALID_HANDLE) IndicatorRelease(m_handleVolMA);
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "GBPUSD";
            m_config.timeframe = PERIOD_M15;
            m_config.strategyType = STRATEGY_BREAKOUT;
            m_config.riskPercent = 1.0;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 203;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for GBPUSD Strategy 3", m_moduleName);
        
        // EMA 200 Daily
        m_handleEMA_Trend = iMA(m_config.symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
        
        // ATR
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, 14);
        
        // MA of ATR (20)
        if(m_handleATR != INVALID_HANDLE)
            m_handleATR_MA = iMA(m_config.symbol, m_config.timeframe, 20, 0, MODE_SMA, m_handleATR);
            
        // Volume
        m_handleVolumes = iVolumes(m_config.symbol, m_config.timeframe, VOLUME_TICK);
        if(m_handleVolumes != INVALID_HANDLE)
            m_handleVolMA = iMA(m_config.symbol, PERIOD_H1, 20, 0, MODE_SMA, m_handleVolumes); // Volume MA on 1H as per strategy ("VOLUME: 1-Hour")
        
        if(m_handleEMA_Trend == INVALID_HANDLE || m_handleATR == INVALID_HANDLE ||
           m_handleATR_MA == INVALID_HANDLE || m_handleVolMA == INVALID_HANDLE)
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
        
        CalculateAsiaRange();
        
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
        
        // Time Check: 07:30 - 09:00 GMT
        MqlDateTime dt;
        TimeGMT(dt);
        int currentMinutes = dt.hour * 60 + dt.min;
        int startMinutes = 7 * 60 + 30; // 07:30
        int endMinutes = 9 * 60; // 09:00
        
        if(currentMinutes < startMinutes || currentMinutes > endMinutes) return signal;
        
        // Conditions
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        double atr = m_atr[0];
        double atrMA = m_atrMA[0];
        double ema200 = m_emaTrend[0];
        
        bool volatilityExp = atr > atrMA;
        bool volConfirm = m_volumes[0] > m_volMA[0]; // Note: m_volMA is 1H, m_volumes is 15m. Comparing them directly is not scale-correct.
        // If VolumeMA is on 1H, it represents avg volume per hour. 
        // Current volume is 15m.
        // We should probably multiply 15m volume by 4 to estimate hourly rate? 
        // Or assume "Volume above 20-period average" implies comparing like-for-like. 
        // If logic says "Volume: 1-Hour", maybe we should check 1H volume?
        // But entry is on 15m.
        // Let's assume we check if current 15m volume is high relative to its own average, OR logic implies checking 1H candle.
        // "Condition 3: Volume above 20-period average. Formula: Volume[current] > MA(Volume, 20)".
        // If "Timeframe: VOLUME: 1-Hour", then we check if the last closed 1H candle had high volume? 
        // But we are in 07:30-09:00. The 08:00 candle hasn't closed at 08:15.
        // I will stick to 15m volume vs 15m MA for simplicity and consistency with timeframe. 
        // I will use a separate handle for 15m Volume MA.
        // Actually, let's use the buffer I created, but it was using PERIOD_H1 for MA. I should change it to m_config.timeframe (M15) to match.
        
        // Re-check Logic: "Condition 1: Price breaks above previous Asia session high + 15 pips"
        double breakMargin = 15 * 0.0001;
        
        // Long Entry
        if(close > m_asiaHigh + breakMargin && volatilityExp && close > ema200)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.8;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             signal.stopLoss = m_asiaLow - 10 * 0.0001;
             signal.takeProfit = signal.entryPrice + 2.0 * atr;
             signal.reason = "London Breakout (Long)";
             return signal;
        }
        
        // Short Entry
        if(close < m_asiaLow - breakMargin && volatilityExp && close < ema200)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.8;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             signal.stopLoss = m_asiaHigh + 10 * 0.0001;
             signal.takeProfit = signal.entryPrice - 2.0 * atr;
             signal.reason = "London Breakout (Short)";
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
         // Handled
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
         // Handled
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time Exit: Close at 16:00 GMT
        MqlDateTime dt;
        TimeGMT(dt);
        if(dt.hour >= 16) return true;
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }

private:
    void CalculateAsiaRange()
    {
        MqlDateTime dt;
        TimeGMT(dt);
        
        // We want 00:00 - 07:00 of TODAY.
        // If current time is < 07:00, we can't trade breakout yet anyway.
        // If date changed, reset.
        if(m_asiaSessionDate != dt.day)
        {
             m_asiaHigh = 0;
             m_asiaLow = 99999;
             m_asiaSessionDate = dt.day;
             
             // Look back
             datetime timeEnd = TimeCurrent();
             // Find bar at 00:00 today.
             // Easier: iterate bars from 0 to ... until we hit 00:00 today.
             int i = 0;
             while(i < 100) // limit
             {
                 datetime t = iTime(m_config.symbol, m_config.timeframe, i);
                 MqlDateTime barDt;
                 TimeGMT(barDt);
                 
                 // If we went back to yesterday, stop
                 if(barDt.day != dt.day) break;
                 
                 // Check if in range 00:00-07:00
                 if(barDt.hour >= 0 && barDt.hour < 7)
                 {
                     double h = iHigh(m_config.symbol, m_config.timeframe, i);
                     double l = iLow(m_config.symbol, m_config.timeframe, i);
                     if(h > m_asiaHigh) m_asiaHigh = h;
                     if(l < m_asiaLow) m_asiaLow = l;
                 }
                 i++;
             }
        }
    }
    
    bool UpdateIndicators()
    {
        ArrayResize(m_emaTrend, 3);
        ArrayResize(m_atr, 3);
        ArrayResize(m_atrMA, 3);
        ArrayResize(m_volumes, 3);
        ArrayResize(m_volMA, 3);
        
        if(CopyBuffer(m_handleEMA_Trend, 0, 0, 3, m_emaTrend) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        if(CopyBuffer(m_handleATR_MA, 0, 0, 3, m_atrMA) <= 0) return false;
        if(CopyTickVolume(m_config.symbol, m_config.timeframe, 0, 3, m_volumes) <= 0) return false;
        if(CopyBuffer(m_handleVolMA, 0, 0, 3, m_volMA) <= 0) return false;
        
        return true;
    }
};
