//+------------------------------------------------------------------+
//|                               USDJPY_Strategy2_Carry_Trade.mqh   |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| USDJPY Strategy 2: Carry Trade with Interest Rate Differential    |
//+------------------------------------------------------------------+
class CUSDJPY_Strategy2_Carry_Trade : public CStrategyBase
{
private:
    int m_handleEMA_LongTerm; // 200 Daily
    
    double m_emaLongTerm[];
    
    // Fundamental Inputs (Manual or Placeholder)
    double m_fedRate;
    double m_bojRate;
    
    datetime m_lastBarTime;

public:
    CUSDJPY_Strategy2_Carry_Trade(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("USDJPY_Strategy2_Carry_Trade", logger, riskManager)
    {
        m_handleEMA_LongTerm = INVALID_HANDLE;
        
        ArraySetAsSeries(m_emaLongTerm, true);
        
        // Current rates as of late 2024/2025
        m_fedRate = 5.25; 
        m_bojRate = 0.25;
        
        m_lastBarTime = 0;
    }
    
    ~CUSDJPY_Strategy2_Carry_Trade()
    {
        if(m_handleEMA_LongTerm != INVALID_HANDLE) IndicatorRelease(m_handleEMA_LongTerm);
    }
    
    virtual bool Initialize() override
    {
        if(m_config.symbol == "")
        {
            m_config.symbol = "USDJPY";
            m_config.timeframe = PERIOD_D1;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 2.0; // Position trading, higher risk? Or lower? Strategy says "1-1.5%".
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 302;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for USDJPY Strategy 2", m_moduleName);
        
        m_handleEMA_LongTerm = iMA(m_config.symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
        m_handleMACD = iMACD(m_config.symbol, PERIOD_D1, 12, 26, 9, PRICE_CLOSE);
        m_handleRSI = iRSI(m_config.symbol, PERIOD_D1, 14, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, PERIOD_D1, 14);
        
        if(m_handleEMA_LongTerm == INVALID_HANDLE || m_handleMACD == INVALID_HANDLE ||
           m_handleRSI == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
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
        
        // Fundamental Check
        if(m_fedRate - m_bojRate < 3.5) return signal;
        
        // Technicals
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        
        // EMA200 Sloping Up (Current > 30 bars ago)
        bool emaSlopeUp = m_emaLongTerm[0] > m_emaLongTerm[30];
        
        // MACD > Signal
        bool macdBullish = m_macdMain[0] > m_macdSignal[0];
        
        // RSI < 80
        bool rsiSafe = m_rsi[0] < 80;
        
        // Price > EMA200
        bool trendAlign = close > m_emaLongTerm[0];
        
        if(emaSlopeUp && macdBullish && rsiSafe && trendAlign)
        {
            signal.signalType = SIGNAL_BUY; // Carry Trade is Long USDJPY (Long USD, Short JPY)
            signal.confidence = 0.9;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            signal.reason = "Carry Trade (Long)";
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
        // 2.5 * ATR
        stopLoss = CalculateATRStopLoss(entryPrice, orderType, 2.5);
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // TP1: 2.0 ATR, TP2: 4.0 ATR. Average 3.0 ATR for single position
        takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 3.0);
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time Exit: 8 weeks (position trade)
        if(PositionSelectByTicket(ticket))
        {
            long timeOpen = PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - timeOpen > 8 * 7 * 24 * 3600) return true;
            
            // Unwind Exit: If Fed cuts or BOJ hikes? (Manual check on rates changing)
            // Or if technicals break down? e.g. Price < EMA200 significantly?
            // Strategy says "Close if BOJ hiking or Fed cutting". We can't detect news easily here.
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
        ArrayResize(m_emaLongTerm, 35); // Need 30 bars ago
        ArrayResize(m_macdMain, 3);
        ArrayResize(m_macdSignal, 3);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_atr, 3);
        
        if(CopyBuffer(m_handleEMA_LongTerm, 0, 0, 35, m_emaLongTerm) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 0, 0, 3, m_macdMain) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 1, 0, 3, m_macdSignal) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
};
