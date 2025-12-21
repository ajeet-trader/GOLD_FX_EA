//+------------------------------------------------------------------+
//|                               EURGBP_Strategy1_SMA_Trend.mqh      |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

class CEURGBP_Strategy1_SMA_Trend : public CStrategyBase
{
private:
    int m_smaPeriod;
    int m_emaFastPeriod;
    int m_emaSlowPeriod;
    int m_atrPeriod;
    
    int m_handleSMA;
    int m_handleEMAFast;
    int m_handleEMASlow;
    int m_handleATR;
    
    double m_smaBuf[];
    double m_emaFastBuf[];
    double m_emaSlowBuf[];

public:
    CEURGBP_Strategy1_SMA_Trend(CLogger* logger, CRiskManager* riskManager)
        : CStrategyBase("EURGBP_Strat1_SMA_Trend", logger, riskManager)
    {
        m_smaPeriod = 200;
        m_emaFastPeriod = 20;
        m_emaSlowPeriod = 50;
        m_atrPeriod = 14;
        
        m_handleSMA = INVALID_HANDLE;
        m_handleEMAFast = INVALID_HANDLE;
        m_handleEMASlow = INVALID_HANDLE;
        m_handleATR = INVALID_HANDLE;
        
        ArraySetAsSeries(m_smaBuf, true);
        ArraySetAsSeries(m_emaFastBuf, true);
        ArraySetAsSeries(m_emaSlowBuf, true);
    }
    
    ~CEURGBP_Strategy1_SMA_Trend()
    {
        ReleaseIndicators();
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleSMA = iMA(m_config.symbol, m_config.timeframe, m_smaPeriod, 0, MODE_SMA, PRICE_CLOSE);
        m_handleEMAFast = iMA(m_config.symbol, m_config.timeframe, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleEMASlow = iMA(m_config.symbol, m_config.timeframe, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_handleSMA == INVALID_HANDLE || m_handleEMAFast == INVALID_HANDLE || 
           m_handleEMASlow == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators for EURGBP Strategy 1", m_moduleName);
            return false;
        }
        
        return true;
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        
        if(CopyBuffer(m_handleSMA, 0, 0, 1, m_smaBuf) < 1 ||
           CopyBuffer(m_handleEMAFast, 0, 0, 1, m_emaFastBuf) < 1 ||
           CopyBuffer(m_handleEMASlow, 0, 0, 1, m_emaSlowBuf) < 1)
        {
            return signal;
        }
        
        double sma200 = m_smaBuf[0];
        double ema20 = m_emaFastBuf[0];
        double ema50 = m_emaSlowBuf[0];
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        
        // Long: Close > 200 SMA AND EMA20 > EMA50
        if(close > sma200 && ema20 > ema50)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.8;
            signal.entryPrice = close;
            signal.reason = "Trend Buy: > SMA200 & EMA Cross";
            
            double sl, tp;
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, sl);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, tp);
            signal.stopLoss = sl;
            signal.takeProfit = tp;
        }
        // Short: Close < 200 SMA AND EMA20 < EMA50
        else if(close < sma200 && ema20 < ema50)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.8;
            signal.entryPrice = close;
            signal.reason = "Trend Sell: < SMA200 & EMA Cross";
            
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
        
        // Guide: Exit if Close < 200 SMA OR EMA20 < EMA50.
        // Also mentions R:R 1:1.5-2.0.
        // We'll use ATR SL for safety. Let's say 2.0 ATR.
        
        double slDist = atr * 2.0;
        
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
        
        // R:R 1:2.0
        double tpDist = atr * 4.0;
        
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
        if(!PositionSelectByTicket(ticket)) return false;
        
        CopyBuffer(m_handleSMA, 0, 0, 1, m_smaBuf);
        CopyBuffer(m_handleEMAFast, 0, 0, 1, m_emaFastBuf);
        CopyBuffer(m_handleEMASlow, 0, 0, 1, m_emaSlowBuf);
        
        double sma200 = m_smaBuf[0];
        double ema20 = m_emaFastBuf[0];
        double ema50 = m_emaSlowBuf[0];
        double close = iClose(m_config.symbol, m_config.timeframe, 0);
        long type = PositionGetInteger(POSITION_TYPE);
        
        if(type == POSITION_TYPE_BUY)
        {
            // Exit: Close < 200 SMA OR EMA20 < EMA50
            if(close < sma200 || ema20 < ema50) return true;
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(close > sma200 || ema20 > ema50) return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }
};
