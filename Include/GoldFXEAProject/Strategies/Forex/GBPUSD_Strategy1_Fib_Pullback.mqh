//+------------------------------------------------------------------+
//|                                GBPUSD_Strategy1_Fib_Pullback.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| GBPUSD Strategy 1: Pullback into Trend with Fibonacci Retracement |
//+------------------------------------------------------------------+
class CGBPUSD_Strategy1_Fib_Pullback : public CStrategyBase
{
private:
    int m_emaTrendPeriod; // 50
    int m_emaLongTermPeriod; // 200
    int m_rsiPeriod;
    int m_volMaPeriod;
    
    int m_handleEMA_Trend; // 50
    int m_handleEMA_LongTerm; // 200
    // int m_handleRSI; // Use base
    int m_handleVolumes;
    int m_handleVolMA;
    
    double m_emaTrend[];
    double m_emaLongTerm[]; // Daily?
    // double m_rsi[]; // Use base
    double m_volMA[];
    long m_volumes[];
    
    datetime m_lastBarTime;

public:
    CGBPUSD_Strategy1_Fib_Pullback(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("GBPUSD_Strategy1_Fib_Pullback", logger, riskManager)
    {
        m_emaTrendPeriod = 50;
        m_emaLongTermPeriod = 200;
        m_rsiPeriod = 14;
        m_volMaPeriod = 20;
        
        m_handleEMA_Trend = INVALID_HANDLE;
        m_handleEMA_LongTerm = INVALID_HANDLE;
        m_handleRSI = INVALID_HANDLE;
        m_handleVolumes = INVALID_HANDLE;
        m_handleVolMA = INVALID_HANDLE;
        
        ArraySetAsSeries(m_emaTrend, true);
        ArraySetAsSeries(m_emaLongTerm, true);
        ArraySetAsSeries(m_rsi, true);
        ArraySetAsSeries(m_volMA, true);
        ArraySetAsSeries(m_volumes, true);
        
        m_lastBarTime = 0;
    }
    
    ~CGBPUSD_Strategy1_Fib_Pullback()
    {
        if(m_handleEMA_Trend != INVALID_HANDLE) IndicatorRelease(m_handleEMA_Trend);
        if(m_handleEMA_LongTerm != INVALID_HANDLE) IndicatorRelease(m_handleEMA_LongTerm);
        if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
        if(m_handleVolumes != INVALID_HANDLE) IndicatorRelease(m_handleVolumes);
        if(m_handleVolMA != INVALID_HANDLE) IndicatorRelease(m_handleVolMA);
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "GBPUSD";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 1.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 201;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for GBPUSD Strategy 1", m_moduleName);
        
        // EMA 50 (4H)
        m_handleEMA_Trend = iMA(m_config.symbol, PERIOD_H4, m_emaTrendPeriod, 0, MODE_EMA, PRICE_CLOSE);
        
        // EMA 200 (Daily)
        m_handleEMA_LongTerm = iMA(m_config.symbol, PERIOD_D1, m_emaLongTermPeriod, 0, MODE_EMA, PRICE_CLOSE);
        
        // RSI (14)
        m_handleRSI = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        
        // ATR
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, 14);
        
        // Volume
        m_handleVolumes = iVolumes(m_config.symbol, m_config.timeframe, VOLUME_TICK);
        if(m_handleVolumes != INVALID_HANDLE)
            m_handleVolMA = iMA(m_config.symbol, m_config.timeframe, m_volMaPeriod, 0, MODE_SMA, m_handleVolumes);
        
        if(m_handleEMA_Trend == INVALID_HANDLE || m_handleEMA_LongTerm == INVALID_HANDLE ||
           m_handleRSI == INVALID_HANDLE || m_handleVolMA == INVALID_HANDLE)
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
        
        // Trend Identification
        bool uptrend = m_emaTrend[0] > m_emaLongTerm[0];
        bool downtrend = m_emaTrend[0] < m_emaLongTerm[0];
        
        if(!uptrend && !downtrend) return signal;
        
        // Fib Detection
        // Look back 100 bars for High/Low
        int highestIdx = iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, 100, 1);
        int lowestIdx = iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, 100, 1);
        
        if(highestIdx < 0 || lowestIdx < 0) return signal;
        
        double swingHigh = iHigh(m_config.symbol, m_config.timeframe, highestIdx);
        double swingLow = iLow(m_config.symbol, m_config.timeframe, lowestIdx);
        double currentPrice = iClose(m_config.symbol, m_config.timeframe, 0);
        
        // RSI Condition
        double rsi = m_rsi[0];
        
        // Volume Condition
        bool volConfirm = m_volumes[0] > m_volMA[0];
        
        // Candle Pattern (Simplified: Bullish/Bearish Close vs Open)
        double open = iOpen(m_config.symbol, m_config.timeframe, 0);
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        double prevOpen = iOpen(m_config.symbol, m_config.timeframe, 1);
        double prevClose = iClose(m_config.symbol, m_config.timeframe, 1);
        
        // Bullish Engulfing: Close > Open, PrevClose < PrevOpen, Close > PrevOpen, Open < PrevClose
        bool bullishEngulfing = (close > open) && (prevClose < prevOpen) && (close > prevOpen) && (open < prevClose);
        // Pin Bar: Long lower wick (for buy)
        double high0 = iHigh(m_config.symbol, m_config.timeframe, 0);
        double low0 = iLow(m_config.symbol, m_config.timeframe, 0);
        double body = MathAbs(close - open);
        double totalRange = high0 - low0;
        bool bullishPinBar = (open - low0 > 0.6 * totalRange) || (close - low0 > 0.6 * totalRange); // Lower wick is 60% of range
        
        if(uptrend)
        {
            // Pullback to 38.2 - 50%
            // Range = High - Low.
            // Retracement Level from High down to Low? No, from Low up to High.
            // In uptrend, we measure move from Low to High. Pullback is down from High.
            // 38.2% Retracement = High - 0.382 * (High - Low)
            // 50% Retracement = High - 0.5 * (High - Low)
            
            // Wait, we need to ensure the Swing High is recent and Swing Low is older?
            // If highestIdx < lowestIdx, then High is more recent. Trend is Up. Correct.
            if(highestIdx < lowestIdx)
            {
                double range = swingHigh - swingLow;
                double fib38 = swingHigh - 0.382 * range;
                double fib50 = swingHigh - 0.5 * range;
                double fib61 = swingHigh - 0.618 * range;
                
                // Check if price is in zone (between 38.2 and 61.8 basically)
                // Strategy says 38.2 or 50.
                bool inZone = (currentPrice <= fib38 && currentPrice >= fib61); // Broaden slightly to catch it
                
                bool rsiCond = (rsi > 30 && rsi < 50);
                
                if(inZone && rsiCond && (bullishEngulfing || bullishPinBar) && volConfirm)
                {
                    signal.signalType = SIGNAL_BUY;
                    signal.confidence = 0.8;
                    signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
                    signal.stopLoss = swingLow; // Stop below swing low? "Above recent swing high + 20 pips" for SHORT. For LONG: Below recent swing low? Strategy says "Stop Loss: Above recent swing high + 20 pips" under "EXIT CONDITIONS". Wait.
                    // "ENTRY CONDITIONS (LONG)... EXIT CONDITIONS... Stop Loss: Above recent swing high". That must be for SHORT.
                    // "Stop Loss: 20-40 pips below entry" or "Below swing low".
                    // Let's use Swing Low (local low) or calculated from entry.
                    // The text says "Stop Loss: Above recent swing high + 20 pips" then "Formula: SL = Swing_High + 20_pips". This is definitely for Short.
                    // For Long, it should be Below Swing Low.
                    // I'll use Swing Low - 20 pips.
                    // But which Swing Low? The major one (swingLow variable) might be too far.
                    // I'll use a local low (Lowest in last 5 bars).
                    double localLow = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, 5, 0));
                    signal.stopLoss = localLow - 20 * 0.0001;
                    
                    signal.takeProfit = signal.entryPrice + (signal.entryPrice - signal.stopLoss) * 2.0; // 1:2 Risk Reward
                    signal.reason = "Fib Pullback (Long)";
                    return signal;
                }
            }
        }
        else if(downtrend)
        {
             // Swing Low is recent (lowestIdx < highestIdx)
             if(lowestIdx < highestIdx)
             {
                 double range = swingHigh - swingLow;
                 double fib38 = swingLow + 0.382 * range;
                 double fib50 = swingLow + 0.5 * range;
                 double fib61 = swingLow + 0.618 * range;
                 
                 bool inZone = (currentPrice >= fib38 && currentPrice <= fib61);
                 bool rsiCond = (rsi > 50 && rsi < 70);
                 
                 // Bearish Engulfing
                 bool bearishEngulfing = (close < open) && (prevClose > prevOpen) && (close < prevOpen) && (open > prevClose);
                 bool bearishPinBar = (high0 - open > 0.6 * totalRange) || (high0 - close > 0.6 * totalRange); // Upper wick
                 
                 if(inZone && rsiCond && (bearishEngulfing || bearishPinBar) && volConfirm)
                 {
                     signal.signalType = SIGNAL_SELL;
                     signal.confidence = 0.8;
                     signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
                     double localHigh = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, 5, 0));
                     signal.stopLoss = localHigh + 20 * 0.0001;
                     signal.takeProfit = signal.entryPrice - (signal.stopLoss - signal.entryPrice) * 2.0;
                     signal.reason = "Fib Pullback (Short)";
                     return signal;
                 }
             }
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE);
    }

    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
         // Logic inside GenerateSignal handles this
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
         // Logic inside GenerateSignal handles this
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Trailing Stop: Activate after 1:1 RR
        if(!PositionSelectByTicket(ticket)) return false;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double sl = PositionGetDouble(POSITION_SL);
        double risk = MathAbs(openPrice - sl);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        
        if(type == POSITION_TYPE_BUY)
        {
            if(currentPrice - openPrice > risk) // 1:1 Achieved
            {
                // Trail below swing lows? 
                // Simplified: Trail to Breakeven first
                if(sl < openPrice)
                {
                    newSL = openPrice;
                    newTP = PositionGetDouble(POSITION_TP);
                    return true;
                }
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(openPrice - currentPrice > risk)
            {
                if(sl > openPrice || sl == 0)
                {
                    newSL = openPrice;
                    newTP = PositionGetDouble(POSITION_TP);
                    return true;
                }
            }
        }
        
        return false;
    }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_emaTrend, 3);
        ArrayResize(m_emaLongTerm, 3);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_volMA, 3);
        ArrayResize(m_volumes, 3);
        ArrayResize(m_atr, 3);
        
        if(CopyBuffer(m_handleEMA_Trend, 0, 0, 3, m_emaTrend) <= 0) return false;
        if(CopyBuffer(m_handleEMA_LongTerm, 0, 0, 3, m_emaLongTerm) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleVolMA, 0, 0, 3, m_volMA) <= 0) return false;
        if(CopyTickVolume(m_config.symbol, m_config.timeframe, 0, 3, m_volumes) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
};
