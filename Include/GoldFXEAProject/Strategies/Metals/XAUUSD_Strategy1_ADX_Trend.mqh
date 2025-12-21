//+------------------------------------------------------------------+
//|                                     XAUUSD_Strategy1_ADX_Trend.mqh|
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| XAUUSD Strategy 1: ADX Trend Following with DI Crossover (4H)    |
//+------------------------------------------------------------------+
class CXAUUSD_Strategy1_ADX_Trend : public CStrategyBase
{
private:
    // Strategy specific parameters
    int m_adxPeriod;
    int m_adxThreshold;
    int m_emaFastPeriod; // 50
    int m_emaSlowPeriod; // 200
    int m_atrPeriod;
    
    // Indicator handles
    int m_handleADX;
    int m_handleEMAFast;
    int m_handleEMASlow;
    
    // Buffers
    double m_adxBuffer[];
    double m_pdiBuffer[];
    double m_mdiBuffer[];
    double m_emaFastBuffer[];
    double m_emaSlowBuffer[];

public:
    CXAUUSD_Strategy1_ADX_Trend(CLogger* logger, CRiskManager* riskManager)
        : CStrategyBase("XAUUSD_Strat1_ADX_Trend", logger, riskManager)
    {
        m_adxPeriod = 14;
        m_adxThreshold = 25;
        m_emaFastPeriod = 50;
        m_emaSlowPeriod = 200;
        m_atrPeriod = 14;
        
        // Initialize handles
        m_handleADX = INVALID_HANDLE;
        m_handleEMAFast = INVALID_HANDLE;
        m_handleEMASlow = INVALID_HANDLE;
        
        // Initialize buffers
        ArraySetAsSeries(m_adxBuffer, true);
        ArraySetAsSeries(m_pdiBuffer, true);
        ArraySetAsSeries(m_mdiBuffer, true);
        ArraySetAsSeries(m_emaFastBuffer, true);
        ArraySetAsSeries(m_emaSlowBuffer, true);
    }
    
    ~CXAUUSD_Strategy1_ADX_Trend()
    {
        ReleaseIndicators();
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        // Initialize Indicators
        m_handleADX = iADX(m_config.symbol, m_config.timeframe, m_adxPeriod);
        m_handleEMAFast = iMA(m_config.symbol, m_config.timeframe, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleEMASlow = iMA(m_config.symbol, m_config.timeframe, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_handleADX == INVALID_HANDLE || m_handleEMAFast == INVALID_HANDLE || 
           m_handleEMASlow == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators for XAUUSD Strategy 1", m_moduleName);
            return false;
        }
        
        m_logger.Info("XAUUSD Strategy 1 Initialized", m_moduleName);
        return true;
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        
        // Update Indicator Buffers
        if(CopyBuffer(m_handleADX, 0, 0, 3, m_adxBuffer) < 3 ||
           CopyBuffer(m_handleADX, 1, 0, 3, m_pdiBuffer) < 3 || // +DI
           CopyBuffer(m_handleADX, 2, 0, 3, m_mdiBuffer) < 3 || // -DI
           CopyBuffer(m_handleEMAFast, 0, 0, 3, m_emaFastBuffer) < 3 ||
           CopyBuffer(m_handleEMASlow, 0, 0, 3, m_emaSlowBuffer) < 3)
        {
            return signal;
        }
        
        double currentADX = m_adxBuffer[0];
        double currentPDI = m_pdiBuffer[0];
        double currentMDI = m_mdiBuffer[0];
        double prevPDI = m_pdiBuffer[1];
        double prevMDI = m_mdiBuffer[1];
        
        double currentFastEMA = m_emaFastBuffer[0];
        double currentSlowEMA = m_emaSlowBuffer[0];
        double currentClose = iClose(m_config.symbol, m_config.timeframe, 0);
        
        // Logic:
        // 1. ADX > 25 (Strong Trend)
        // 2. Trend Direction Filter: EMA50 > EMA200 (Uptrend) / EMA50 < EMA200 (Downtrend)
        // 3. Signal: +DI crosses above -DI (Buy) / -DI crosses above +DI (Sell)
        
        bool isStrongTrend = currentADX > m_adxThreshold;
        
        // BUY Signal
        if(isStrongTrend && 
           currentFastEMA > currentSlowEMA && // Uptrend context
           currentClose > currentFastEMA &&   // Price above fast EMA
           currentPDI > currentMDI && prevPDI <= prevMDI) // +DI Crossover
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.85;
            signal.entryPrice = currentClose;
            signal.reason = "ADX Trend Buy: +DI Cross + EMA Trend";
            
            double sl, tp;
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, sl);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, tp);
            signal.stopLoss = sl;
            signal.takeProfit = tp;
        }
        // SELL Signal
        else if(isStrongTrend && 
                currentFastEMA < currentSlowEMA && // Downtrend context
                currentClose < currentFastEMA &&   // Price below fast EMA
                currentMDI > currentPDI && prevMDI <= prevPDI) // -DI Crossover
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.85;
            signal.entryPrice = currentClose;
            signal.reason = "ADX Trend Sell: -DI Cross + EMA Trend";
            
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
        
        if(CopyBuffer(m_handleATR, 0, 0, 1, atrBuf) > 0)
            atr = atrBuf[0];
        else
            atr = 0.0050; // Fallback
            
        // SL = 1.5 * ATR
        double slDist = atr * 1.5;
        
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
        
        if(CopyBuffer(m_handleATR, 0, 0, 1, atrBuf) > 0)
            atr = atrBuf[0];
        else
            atr = 0.0050; // Fallback
            
        // TP = 3.0 * ATR
        double tpDist = atr * 3.0;
        
        if(orderType == ORDER_TYPE_BUY)
            takeProfit = entryPrice + tpDist;
        else
            takeProfit = entryPrice - tpDist;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        // Basic validation
        if(signal.signalType == SIGNAL_NONE) return false;
        if(signal.confidence < 0.6) return false;
        return true;
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Logic to close if DI reverses
        if(!PositionSelectByTicket(ticket)) return false;
        
        long type = PositionGetInteger(POSITION_TYPE);
        
        // Refresh buffers
        CopyBuffer(m_handleADX, 1, 0, 1, m_pdiBuffer);
        CopyBuffer(m_handleADX, 2, 0, 1, m_mdiBuffer);
        CopyBuffer(m_handleADX, 0, 0, 1, m_adxBuffer);
        
        double pdi = m_pdiBuffer[0];
        double mdi = m_mdiBuffer[0];
        double adx = m_adxBuffer[0];
        
        // Exit if ADX collapses (trend ends)
        if(adx < 20) return true;
        
        if(type == POSITION_TYPE_BUY)
        {
            // Exit Long if -DI crosses above +DI
            if(mdi > pdi) return true;
        }
        else if(type == POSITION_TYPE_SELL)
        {
            // Exit Short if +DI crosses above -DI
            if(pdi > mdi) return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Trailing Stop Logic: Trail at 1.0 * ATR if profit > 1.5 * ATR
        if(!PositionSelectByTicket(ticket)) return false;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        
        double atr = 0;
        double atrBuf[];
        ArraySetAsSeries(atrBuf, true);
        CopyBuffer(m_handleATR, 0, 0, 1, atrBuf);
        atr = atrBuf[0];
        
        double activationDist = 1.5 * atr;
        double trailDist = 1.0 * atr;
        
        if(type == POSITION_TYPE_BUY)
        {
            if(currentPrice - openPrice > activationDist)
            {
                double proposedSL = currentPrice - trailDist;
                if(proposedSL > currentSL && proposedSL > openPrice)
                {
                    newSL = proposedSL;
                    newTP = PositionGetDouble(POSITION_TP); // Keep existing TP
                    return true;
                }
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            if(openPrice - currentPrice > activationDist)
            {
                double proposedSL = currentPrice + trailDist;
                if((currentSL == 0 || proposedSL < currentSL) && proposedSL < openPrice)
                {
                    newSL = proposedSL;
                    newTP = PositionGetDouble(POSITION_TP);
                    return true;
                }
            }
        }
        
        return false;
    }
};
