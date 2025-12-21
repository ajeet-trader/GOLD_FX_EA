//+------------------------------------------------------------------+
//|                                XAUUSD_Strategy3_Keltner_Scalp.mqh|
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| XAUUSD Strategy 3: Keltner Channel Scalping (5M)                 |
//+------------------------------------------------------------------+
class CXAUUSD_Strategy3_Keltner_Scalp : public CStrategyBase
{
private:
    int m_emaPeriod;
    int m_atrPeriod;
    double m_keltnerMultiplier;
    int m_rsiPeriod;
    
    int m_handleEMA;
    int m_handleATR;
    int m_handleRSI;
    
    double m_emaBuf[];
    double m_atrBuf[];
    double m_rsiBuf[];

public:
    CXAUUSD_Strategy3_Keltner_Scalp(CLogger* logger, CRiskManager* riskManager)
        : CStrategyBase("XAUUSD_Strat3_Keltner_Scalp", logger, riskManager)
    {
        m_emaPeriod = 20;
        m_atrPeriod = 10;
        m_keltnerMultiplier = 1.5;
        m_rsiPeriod = 14;
        
        m_handleEMA = INVALID_HANDLE;
        m_handleATR = INVALID_HANDLE;
        m_handleRSI = INVALID_HANDLE;
        
        ArraySetAsSeries(m_emaBuf, true);
        ArraySetAsSeries(m_atrBuf, true);
        ArraySetAsSeries(m_rsiBuf, true);
    }
    
    ~CXAUUSD_Strategy3_Keltner_Scalp()
    {
        ReleaseIndicators();
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleEMA = iMA(m_config.symbol, m_config.timeframe, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        m_handleRSI = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        
        if(m_handleEMA == INVALID_HANDLE || m_handleATR == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators for XAUUSD Strategy 3", m_moduleName);
            return false;
        }
        
        m_logger.Info("XAUUSD Strategy 3 Initialized", m_moduleName);
        return true;
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        
        if(CopyBuffer(m_handleEMA, 0, 0, 2, m_emaBuf) < 2 ||
           CopyBuffer(m_handleATR, 0, 0, 2, m_atrBuf) < 2 ||
           CopyBuffer(m_handleRSI, 0, 0, 2, m_rsiBuf) < 2)
        {
            return signal;
        }
        
        double currentClose = iClose(m_config.symbol, m_config.timeframe, 0);
        double currentLow = iLow(m_config.symbol, m_config.timeframe, 0);
        double currentHigh = iHigh(m_config.symbol, m_config.timeframe, 0);
        
        double ema = m_emaBuf[0];
        double atr = m_atrBuf[0];
        double rsi = m_rsiBuf[0];
        
        double upperChannel = ema + (atr * m_keltnerMultiplier);
        double lowerChannel = ema - (atr * m_keltnerMultiplier);
        
        // BUY Logic:
        // 1. Price touches Lower Channel
        // 2. RSI > 50 (Momentum)
        // 3. Close > EMA (Pullback into trend? The guide says "Close > EMA" for Buy)
        // Wait, if Close > EMA, it can't be touching Lower Channel (which is EMA - ATR*1.5).
        // Guide logic correction: "Price touches lower Keltner... Close > EMA(20)" -> This implies a wick touch and close back up?
        // Or maybe checking previous bar?
        // Let's assume: Low <= LowerChannel AND Close > EMA (strong rejection)
        
        if(currentLow <= lowerChannel && currentClose > ema && rsi > 50 && rsi < 70)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.7;
            signal.entryPrice = currentClose;
            signal.reason = "Keltner Scalp Buy: Touch Lower & Rejection";
            
            double sl, tp;
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, sl);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, tp);
            signal.stopLoss = sl;
            signal.takeProfit = tp;
        }
        // SELL Logic:
        // High >= UpperChannel AND Close < EMA (rejection)
        else if(currentHigh >= upperChannel && currentClose < ema && rsi < 50 && rsi > 30)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.7;
            signal.entryPrice = currentClose;
            signal.reason = "Keltner Scalp Sell: Touch Upper & Rejection";
            
            double sl, tp;
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, sl);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, tp);
            signal.stopLoss = sl;
            signal.takeProfit = tp;
        }
        
        return signal;
    }
    
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        double atr = 0;
        double atrBuf[];
        ArraySetAsSeries(atrBuf, true);
        CopyBuffer(m_handleATR, 0, 0, 1, atrBuf);
        atr = atrBuf[0];
        
        // Guide: SL = 0.8 * ATR
        double slDist = atr * 0.8;
        
        if(orderType == ORDER_TYPE_BUY)
            stopLoss = entryPrice - slDist;
        else
            stopLoss = entryPrice + slDist;
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        double atr = 0;
        double atrBuf[];
        ArraySetAsSeries(atrBuf, true);
        CopyBuffer(m_handleATR, 0, 0, 1, atrBuf);
        atr = atrBuf[0];
        
        // Guide: TP = 1.2 * ATR
        double tpDist = atr * 1.2;
        
        if(orderType == ORDER_TYPE_BUY)
            takeProfit = entryPrice + tpDist;
        else
            takeProfit = entryPrice - tpDist;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        if(signal.signalType == SIGNAL_NONE) return false;
        return true;
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Scalping: Close at TP (handled by SL/TP) or Time Limit (60 mins)
        if(!PositionSelectByTicket(ticket)) return false;
        
        long openTime = PositionGetInteger(POSITION_TIME);
        long currentTime = TimeCurrent();
        
        // Time Exit: 60 minutes = 3600 seconds
        if(currentTime - openTime > 3600)
        {
            return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }
};
