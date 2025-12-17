//+------------------------------------------------------------------+
//|                             EURUSD_Strategy2_Bollinger_MeanReversion.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| EURUSD Strategy 2: Bollinger Bands Mean Reversion                 |
//+------------------------------------------------------------------+
class CEURUSD_Strategy2_Bollinger_MeanReversion : public CStrategyBase
{
private:
    int m_bbPeriod;
    double m_bbDev;
    int m_rsiPeriod;
    int m_volMaPeriod;
    
    int m_handleBB;
    int m_handleRSI;
    int m_handleVolumes;
    int m_handleVolMA;
    
    double m_bbUpper[];
    double m_bbLower[];
    double m_bbMid[];
    double m_rsi[];
    double m_volMA[];
    long m_volumes[];
    
    datetime m_lastBarTime;

public:
    CEURUSD_Strategy2_Bollinger_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("EURUSD_Strategy2_Bollinger_MeanReversion", logger, riskManager)
    {
        m_bbPeriod = 20;
        m_bbDev = 2.0;
        m_rsiPeriod = 7;
        m_volMaPeriod = 14;
        
        m_handleBB = INVALID_HANDLE;
        m_handleRSI = INVALID_HANDLE;
        m_handleVolumes = INVALID_HANDLE;
        m_handleVolMA = INVALID_HANDLE;
        
        ArraySetAsSeries(m_bbUpper, true);
        ArraySetAsSeries(m_bbLower, true);
        ArraySetAsSeries(m_bbMid, true);
        ArraySetAsSeries(m_rsi, true);
        ArraySetAsSeries(m_volMA, true);
        ArraySetAsSeries(m_volumes, true);
        
        m_lastBarTime = 0;
    }
    
    ~CEURUSD_Strategy2_Bollinger_MeanReversion()
    {
        if(m_handleBB != INVALID_HANDLE) IndicatorRelease(m_handleBB);
        if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
        if(m_handleVolMA != INVALID_HANDLE) IndicatorRelease(m_handleVolMA);
        if(m_handleVolumes != INVALID_HANDLE) IndicatorRelease(m_handleVolumes);
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "EURUSD";
            m_config.timeframe = PERIOD_M30; // Primary timeframe
            m_config.strategyType = STRATEGY_MEAN_REVERSION;
            m_config.riskPercent = 1.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 102;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for EURUSD Strategy 2", m_moduleName);
        
        // Bollinger Bands
        m_handleBB = iBands(m_config.symbol, m_config.timeframe, m_bbPeriod, 0, m_bbDev, PRICE_CLOSE);
        
        // RSI
        m_handleRSI = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        
        // ATR
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, 14);
        
        // Volume MA
        m_handleVolumes = iVolumes(m_config.symbol, m_config.timeframe, VOLUME_TICK);
        if(m_handleVolumes != INVALID_HANDLE)
        {
            m_handleVolMA = iMA(m_config.symbol, m_config.timeframe, m_volMaPeriod, 0, MODE_SMA, m_handleVolumes);
        }
        
        if(m_handleBB == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE || 
           m_handleATR == INVALID_HANDLE || m_handleVolMA == INVALID_HANDLE)
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
        
        // Logic
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        double low = iLow(m_config.symbol, m_config.timeframe, 0);
        double low1 = iLow(m_config.symbol, m_config.timeframe, 1);
        double low2 = iLow(m_config.symbol, m_config.timeframe, 2);
        
        double high = iHigh(m_config.symbol, m_config.timeframe, 0);
        double high1 = iHigh(m_config.symbol, m_config.timeframe, 1);
        double high2 = iHigh(m_config.symbol, m_config.timeframe, 2);
        
        // Long Setup (Oversold)
        // Close < Lower BB
        bool cond1 = close < m_bbLower[0];
        // RSI < 25
        bool cond2 = m_rsi[0] < 25;
        // Two consecutive bars with lower lows (Low[0] > Low[1] && Low[1] < Low[2]) ? 
        // Wait, "Low[current] > Low[1] AND Low[1] < Low[2]" -> This is a reversal pattern (Current low is higher than previous low, and previous low was lower than the one before it). i.e. a "V" shape bottom.
        bool cond3 = (low > low1) && (low1 < low2);
        // Volume > Volume MA
        bool cond4 = m_volumes[0] > m_volMA[0];
        
        if(cond1 && cond2 && cond3 && cond4)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.7;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            // Stop Loss: 2.5 * ATR
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            // TP1: Middle Band, TP2: Upper Band. We use simple TP here, maybe logic needs to handle partials.
            // For now set TP to Upper Band or a fixed R:R
            signal.takeProfit = m_bbUpper[0]; 
            signal.reason = "BB Mean Reversion (Long)";
            return signal;
        }
        
        // Short Setup (Overbought)
        // Close > Upper BB
        bool s_cond1 = close > m_bbUpper[0];
        // RSI > 75
        bool s_cond2 = m_rsi[0] > 75;
        // Reversal pattern: High[0] < High[1] && High[1] > High[2] (inverted V)
        bool s_cond3 = (high < high1) && (high1 > high2);
        // Volume
        bool s_cond4 = m_volumes[0] > m_volMA[0];
        
        if(s_cond1 && s_cond2 && s_cond3 && s_cond4)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.7;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            signal.takeProfit = m_bbLower[0];
            signal.reason = "BB Mean Reversion (Short)";
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
        stopLoss = CalculateATRStopLoss(entryPrice, orderType, 2.5);
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // Default behavior if not set by signal generation
        // But for this strategy, TP is dynamic (BB bands)
        // We set a fallback
        takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 3.0);
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time Exit: 24-36 hours
        if(PositionSelectByTicket(ticket))
        {
            long timeOpen = PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - timeOpen > 36 * 3600) return true;
            
            // Logic for partial exits or hitting Middle Band could go here
            // But we can't easily do partial close in this simple framework without more logic.
        }
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_bbUpper, 3);
        ArrayResize(m_bbLower, 3);
        ArrayResize(m_bbMid, 3);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_volMA, 3);
        ArrayResize(m_volumes, 3);
        ArrayResize(m_atr, 3);
        
        if(CopyBuffer(m_handleBB, 1, 0, 3, m_bbUpper) <= 0) return false;
        if(CopyBuffer(m_handleBB, 2, 0, 3, m_bbLower) <= 0) return false;
        if(CopyBuffer(m_handleBB, 0, 0, 3, m_bbMid) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleVolMA, 0, 0, 3, m_volMA) <= 0) return false;
        if(CopyTickVolume(m_config.symbol, m_config.timeframe, 0, 3, m_volumes) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
};
