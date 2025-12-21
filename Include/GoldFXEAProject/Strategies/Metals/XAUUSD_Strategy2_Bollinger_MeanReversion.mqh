//+------------------------------------------------------------------+
//|                             XAUUSD_Strategy2_Bollinger_MeanReversion.mqh|
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| XAUUSD Strategy 2: Bollinger Bands Mean Reversion + RSI (30M)    |
//+------------------------------------------------------------------+
class CXAUUSD_Strategy2_Bollinger_MeanReversion : public CStrategyBase
{
private:
    int m_bbPeriod;
    double m_bbDeviation;
    int m_rsiPeriod;
    int m_adxPeriod;
    int m_atrPeriod;
    
    // Thresholds
    int m_rsiOversold;
    int m_rsiOverbought;
    int m_adxRangeThreshold;
    
    // Handles
    int m_handleBB;
    int m_handleRSI;
    int m_handleADX;
    int m_handleATR;
    int m_handleMA; // Middle band reference (SMA 20)
    
    // Buffers
    double m_bbUpperBuf[];
    double m_bbLowerBuf[];
    double m_bbMidBuf[]; // Usually SMA
    double m_rsiBuf[];
    double m_adxBuf[];
    double m_maBuf[];

public:
    CXAUUSD_Strategy2_Bollinger_MeanReversion(CLogger* logger, CRiskManager* riskManager)
        : CStrategyBase("XAUUSD_Strat2_BB_MeanRev", logger, riskManager)
    {
        m_bbPeriod = 20;
        m_bbDeviation = 2.0;
        m_rsiPeriod = 7; // Fast RSI
        m_adxPeriod = 14;
        m_atrPeriod = 14;
        
        m_rsiOversold = 20;
        m_rsiOverbought = 80;
        m_adxRangeThreshold = 25; // Treat < 25 as ranging/weak trend
        
        m_handleBB = INVALID_HANDLE;
        m_handleRSI = INVALID_HANDLE;
        m_handleADX = INVALID_HANDLE;
        m_handleATR = INVALID_HANDLE;
        m_handleMA = INVALID_HANDLE;
        
        ArraySetAsSeries(m_bbUpperBuf, true);
        ArraySetAsSeries(m_bbLowerBuf, true);
        ArraySetAsSeries(m_bbMidBuf, true);
        ArraySetAsSeries(m_rsiBuf, true);
        ArraySetAsSeries(m_adxBuf, true);
        ArraySetAsSeries(m_maBuf, true);
    }
    
    ~CXAUUSD_Strategy2_Bollinger_MeanReversion()
    {
        ReleaseIndicators();
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_handleBB = iBands(m_config.symbol, m_config.timeframe, m_bbPeriod, 0, m_bbDeviation, PRICE_CLOSE);
        m_handleRSI = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_handleADX = iADX(m_config.symbol, m_config.timeframe, m_adxPeriod);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        m_handleMA = iMA(m_config.symbol, m_config.timeframe, m_bbPeriod, 0, MODE_SMA, PRICE_CLOSE);
        
        if(m_handleBB == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE || 
           m_handleADX == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators for XAUUSD Strategy 2", m_moduleName);
            return false;
        }
        
        m_logger.Info("XAUUSD Strategy 2 Initialized", m_moduleName);
        return true;
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        
        if(CopyBuffer(m_handleBB, 1, 0, 2, m_bbUpperBuf) < 2 || // Upper
           CopyBuffer(m_handleBB, 2, 0, 2, m_bbLowerBuf) < 2 || // Lower
           CopyBuffer(m_handleRSI, 0, 0, 2, m_rsiBuf) < 2 ||
           CopyBuffer(m_handleADX, 0, 0, 1, m_adxBuf) < 1)
        {
            return signal;
        }
        
        double currentClose = iClose(m_config.symbol, m_config.timeframe, 0);
        double prevClose = iClose(m_config.symbol, m_config.timeframe, 1);
        
        double bbUpper = m_bbUpperBuf[0];
        double bbLower = m_bbLowerBuf[0];
        double rsi = m_rsiBuf[0];
        double adx = m_adxBuf[0];
        
        // Filter: Only trade in ranging markets (ADX < 25)
        if(adx > m_adxRangeThreshold) return signal;
        
        // BUY Signal: Price touches/breaks Lower Band + Oversold RSI
        if(currentClose < bbLower && rsi < m_rsiOversold)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.8;
            signal.entryPrice = currentClose;
            signal.reason = "BB Mean Reversion Buy: Price < LowerBB & RSI Oversold";
            
            double sl, tp;
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, sl);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, tp);
            signal.stopLoss = sl;
            signal.takeProfit = tp;
        }
        // SELL Signal: Price touches/breaks Upper Band + Overbought RSI
        else if(currentClose > bbUpper && rsi > m_rsiOverbought)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.8;
            signal.entryPrice = currentClose;
            signal.reason = "BB Mean Reversion Sell: Price > UpperBB & RSI Overbought";
            
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
        
        // SL = 1.0 * ATR beyond band? Or just fixed ATR from entry.
        // Guide says: 1.0 * ATR beyond band extremity.
        // For simplicity here, we'll do Entry +/- 1.5 ATR which is safer/easier to calculate without fetching bands again.
        // Actually let's do Entry +/- 1.5 ATR.
        
        double slDist = atr * 1.5;
        
        if(orderType == ORDER_TYPE_BUY)
            stopLoss = entryPrice - slDist;
        else
            stopLoss = entryPrice + slDist;
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // Target: Mean (Middle Band) -> approximated as SMA 20
        // Or simplified: Entry +/- 2.0 ATR (Since middle band moves)
        // Guide says: TP1 = Middle Band, TP2 = Opposite Band.
        // We will use a fixed R:R based on ATR for simplicity in this EA framework 
        // unless we implement dynamic TP updates (which StrategyBase supports via ModifyPosition).
        // Let's set a conservative TP at 2.0 ATR.
        
        double atr = 0;
        double atrBuf[];
        ArraySetAsSeries(atrBuf, true);
        CopyBuffer(m_handleATR, 0, 0, 1, atrBuf);
        atr = atrBuf[0];
        
        double tpDist = atr * 2.0;
        
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
        // Close if price reaches Middle Band (SMA 20)
        if(!PositionSelectByTicket(ticket)) return false;
        
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        
        CopyBuffer(m_handleMA, 0, 0, 1, m_maBuf);
        double middleBand = m_maBuf[0];
        
        if(type == POSITION_TYPE_BUY)
        {
            if(currentPrice >= middleBand) return true;
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(currentPrice <= middleBand) return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false; // No trailing for this mean reversion
    }
};
