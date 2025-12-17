//+------------------------------------------------------------------+
//|                               USDJPY_Strategy1_ADX_Trend.mqh     |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| USDJPY Strategy 1: ADX Trend Following with DI Crossover          |
//+------------------------------------------------------------------+
class CUSDJPY_Strategy1_ADX_Trend : public CStrategyBase
{
private:
    int m_handleEMA_Trend; // 50
    int m_handleEMA_LongTerm; // 200
    
    double m_diPlus[];
    double m_diMinus[];
    double m_emaTrend[];
    double m_emaLongTerm[];
    
    datetime m_lastBarTime;

public:
    CUSDJPY_Strategy1_ADX_Trend(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("USDJPY_Strategy1_ADX_Trend", logger, riskManager)
    {
        m_handleEMA_Trend = INVALID_HANDLE;
        m_handleEMA_LongTerm = INVALID_HANDLE;
        
        ArraySetAsSeries(m_diPlus, true);
        ArraySetAsSeries(m_diMinus, true);
        ArraySetAsSeries(m_emaTrend, true);
        ArraySetAsSeries(m_emaLongTerm, true);
        
        m_lastBarTime = 0;
    }
    
    ~CUSDJPY_Strategy1_ADX_Trend()
    {
        if(m_handleEMA_Trend != INVALID_HANDLE) IndicatorRelease(m_handleEMA_Trend);
        if(m_handleEMA_LongTerm != INVALID_HANDLE) IndicatorRelease(m_handleEMA_LongTerm);
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "USDJPY";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 1.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 301;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for USDJPY Strategy 1", m_moduleName);
        
        m_handleADX = iADX(m_config.symbol, m_config.timeframe, 14);
        m_handleEMA_Trend = iMA(m_config.symbol, m_config.timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
        m_handleEMA_LongTerm = iMA(m_config.symbol, m_config.timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, 14);
        
        if(m_handleADX == INVALID_HANDLE || m_handleEMA_Trend == INVALID_HANDLE || 
           m_handleEMA_LongTerm == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
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
        
        double adx = m_adx[0];
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        
        // Long Entry
        // ADX > 25
        bool adxCond = adx > 25;
        // +DI > -DI
        bool diDirection = m_diPlus[0] > m_diMinus[0];
        // +DI Crosses Above -DI
        bool diCrossover = (m_diPlus[0] > m_diMinus[0]) && (m_diPlus[1] <= m_diMinus[1]);
        // EMA50 > EMA200
        bool trendCond = m_emaTrend[0] > m_emaLongTerm[0];
        // Close > EMA50
        bool priceCond = close > m_emaTrend[0];
        
        if(adxCond && diDirection && diCrossover && trendCond && priceCond)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.8;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            signal.reason = "ADX DI Crossover (Long)";
            return signal;
        }
        
        // Short Entry
        bool diDirectionShort = m_diMinus[0] > m_diPlus[0];
        bool diCrossoverShort = (m_diMinus[0] > m_diPlus[0]) && (m_diMinus[1] <= m_diPlus[1]);
        bool trendCondShort = m_emaTrend[0] < m_emaLongTerm[0];
        bool priceCondShort = close < m_emaTrend[0];
        
        if(adxCond && diDirectionShort && diCrossoverShort && trendCondShort && priceCondShort)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.8;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
            signal.reason = "ADX DI Crossover (Short)";
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
        // 1.8 * ATR
        stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.8);
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // 3.0 * ATR
        takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 3.0);
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        if(!PositionSelectByTicket(ticket)) return false;
        if(!UpdateIndicators()) return false;
        
        long type = PositionGetInteger(POSITION_TYPE);
        
        // ADX Exit: ADX < 20
        if(m_adx[0] < 20) return true;
        
        // DI Reversal
        if(type == POSITION_TYPE_BUY)
        {
            if(m_diMinus[0] > m_diPlus[0]) return true;
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(m_diPlus[0] > m_diMinus[0]) return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Trailing Stop: 1.5 ATR profit -> Trail 1.5 ATR
        if(!PositionSelectByTicket(ticket)) return false;
        if(m_atr[0] == 0) return false;
        
        double currentSL = PositionGetDouble(POSITION_SL);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        double atr = m_atr[0];
        
        if(type == POSITION_TYPE_BUY)
        {
            if(currentPrice - openPrice > 1.5 * atr)
            {
                double proposedSL = currentPrice - 1.5 * atr;
                if(proposedSL > currentSL)
                {
                    newSL = proposedSL;
                    newTP = PositionGetDouble(POSITION_TP);
                    return true;
                }
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(openPrice - currentPrice > 1.5 * atr)
            {
                double proposedSL = currentPrice + 1.5 * atr;
                if(proposedSL < currentSL || currentSL == 0)
                {
                    newSL = proposedSL;
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
        ArrayResize(m_adx, 3);
        ArrayResize(m_diPlus, 3);
        ArrayResize(m_diMinus, 3);
        ArrayResize(m_emaTrend, 3);
        ArrayResize(m_emaLongTerm, 3);
        ArrayResize(m_atr, 3);
        
        if(CopyBuffer(m_handleADX, 0, 0, 3, m_adx) <= 0) return false;
        if(CopyBuffer(m_handleADX, 1, 0, 3, m_diPlus) <= 0) return false;
        if(CopyBuffer(m_handleADX, 2, 0, 3, m_diMinus) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Trend, 0, 0, 3, m_emaTrend) <= 0) return false;
        if(CopyBuffer(m_handleEMA_LongTerm, 0, 0, 3, m_emaLongTerm) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
};
