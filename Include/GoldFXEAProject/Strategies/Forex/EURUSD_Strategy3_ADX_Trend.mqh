//+------------------------------------------------------------------+
//|                                   EURUSD_Strategy3_ADX_Trend.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| EURUSD Strategy 3: ADX Trend Strength Filter + EMA20/50           |
//+------------------------------------------------------------------+
class CEURUSD_Strategy3_ADX_Trend : public CStrategyBase
{
private:
    int m_adxPeriod;
    int m_emaFastPeriod;
    int m_emaSlowPeriod;
    
    double m_diPlus[];
    double m_diMinus[];
    
    datetime m_lastBarTime;

public:
    CEURUSD_Strategy3_ADX_Trend(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("EURUSD_Strategy3_ADX_Trend", logger, riskManager)
    {
        m_adxPeriod = 14;
        m_emaFastPeriod = 20;
        m_emaSlowPeriod = 50;
        
        ArraySetAsSeries(m_diPlus, true);
        ArraySetAsSeries(m_diMinus, true);
        
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "EURUSD";
            m_config.timeframe = PERIOD_H1;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 1.0;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 103;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for EURUSD Strategy 3", m_moduleName);
        
        m_handleADX = CreateIndicator("ADX", "ADX", m_adxPeriod);
        m_handleEMA_Fast = CreateIndicator("EMA_Fast", "MA", m_emaFastPeriod);
        m_handleEMA_Slow = CreateIndicator("EMA_Slow", "MA", m_emaSlowPeriod);
        m_handleATR = CreateIndicator("ATR", "ATR", 14);
        m_handleMACD = CreateIndicator("MACD", "MACD", 12, 26, 9);
        
        if(m_handleADX == INVALID_HANDLE || m_handleEMA_Fast == INVALID_HANDLE ||
           m_handleEMA_Slow == INVALID_HANDLE || m_handleATR == INVALID_HANDLE ||
           m_handleMACD == INVALID_HANDLE)
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
        double adx = m_adx[0];
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        double atr = m_atr[0];
        
        // Long Entry
        bool adxStrong = adx > 25;
        bool diBullish = m_diPlus[0] > m_diMinus[0];
        bool emaTrendBullish = m_emaFast[0] > m_emaSlow[0];
        bool breakoutBullish = close > (m_emaSlow[0] + 0.5 * atr);
        bool macdBullish = m_macdMain[0] > m_macdSignal[0];
        
        if(adxStrong && diBullish && emaTrendBullish && breakoutBullish && macdBullish)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.85;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            signal.reason = "ADX Trend Breakout (Long)";
            return signal;
        }
        
        // Short Entry
        bool diBearish = m_diMinus[0] > m_diPlus[0];
        bool emaTrendBearish = m_emaFast[0] < m_emaSlow[0];
        bool breakoutBearish = close < (m_emaSlow[0] - 0.5 * atr);
        bool macdBearish = m_macdMain[0] < m_macdSignal[0];
        
        if(adxStrong && diBearish && emaTrendBearish && breakoutBearish && macdBearish)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.85;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
            signal.reason = "ADX Trend Breakout (Short)";
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
        // 1.5 * ATR
        stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.5);
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // 2.5 * ATR
        takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 2.5);
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        if(!PositionSelectByTicket(ticket)) return false;
        
        if(!UpdateIndicators()) return false;
        
        // ADX Exit: ADX < 20
        if(m_adx[0] < 20)
        {
             m_logger.Info("Closing position - ADX below 20", m_moduleName);
             return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Trailing Stop: Activate after breakeven? 
        // Logic: Trail 1 ATR below highest high.
        // Simplified implementation:
        if(!PositionSelectByTicket(ticket)) return false;
        if(m_atr[0] == 0) return false;
        
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        
        if(type == POSITION_TYPE_BUY)
        {
            double proposedSL = currentPrice - 1.0 * m_atr[0];
            if(proposedSL > currentSL)
            {
                newSL = proposedSL;
                newTP = PositionGetDouble(POSITION_TP);
                return true;
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            double proposedSL = currentPrice + 1.0 * m_atr[0];
            if(proposedSL < currentSL || currentSL == 0)
            {
                newSL = proposedSL;
                newTP = PositionGetDouble(POSITION_TP);
                return true;
            }
        }
        
        return false;
    }

private:
    bool UpdateIndicators()
    {
        ArrayResize(m_adx, 3);
        ArrayResize(m_diPlus, 3);
        ArrayResize(m_diMinus, 3);
        ArrayResize(m_emaFast, 3);
        ArrayResize(m_emaSlow, 3);
        ArrayResize(m_atr, 3);
        ArrayResize(m_macdMain, 3);
        ArrayResize(m_macdSignal, 3);
        
        if(CopyBuffer(m_handleADX, 0, 0, 3, m_adx) <= 0) return false;
        if(CopyBuffer(m_handleADX, 1, 0, 3, m_diPlus) <= 0) return false; // +DI is buffer 1? Standard ADX: 0=ADX, 1=+DI, 2=-DI
        if(CopyBuffer(m_handleADX, 2, 0, 3, m_diMinus) <= 0) return false;
        
        if(CopyBuffer(m_handleEMA_Fast, 0, 0, 3, m_emaFast) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Slow, 0, 0, 3, m_emaSlow) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 0, 0, 3, m_macdMain) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 1, 0, 3, m_macdSignal) <= 0) return false;
        
        return true;
    }
};
