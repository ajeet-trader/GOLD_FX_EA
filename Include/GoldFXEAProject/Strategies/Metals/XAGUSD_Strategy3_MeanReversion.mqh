//+------------------------------------------------------------------+
//|                                     XAGUSD_Strategy3_MeanReversion.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * XAGUSD Strategy 3: Mean Reversion Bollinger (4H)
 * Type: Mean Reversion
 * 
 * Rules:
 * 1. Long: Price closes below lower BB(20, 2.0) AND RSI(7) < 25.
 * 2. Short: Price closes above upper BB(20, 2.0) AND RSI(7) > 75.
 * 3. SL: 2.0 * ATR(14).
 * 4. TP: MA(20) - middle Bollinger Band.
 */
class CXAGUSD_Strategy3_MeanReversion : public CStrategyBase
{
private:
    int m_bbPeriod;
    double m_bbDev;
    int m_rsiPeriod;
    int m_atrPeriod;
    
    int m_hBb;
    int m_hRsi;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CXAGUSD_Strategy3_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("XAGUSD_Strategy3_MeanReversion", logger, riskManager)
    {
        m_bbPeriod = 20;
        m_bbDev = 2.0;
        m_rsiPeriod = 7;
        m_atrPeriod = 14;
        
        m_hBb = INVALID_HANDLE;
        m_hRsi = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_hBb = iBands(m_config.symbol, m_config.timeframe, m_bbPeriod, 0, m_bbDev, PRICE_CLOSE);
        m_hRsi = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_hAtr = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_hBb == INVALID_HANDLE || m_hRsi == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
        {
            m_logger.Error("XAGUSD_Strategy3: Failed to initialize indicators", m_moduleName);
            return false;
        }
        
        return true;
    }
    
    virtual void ProcessTick(MqlTick &tick) override
    {
        if(m_status != MODULE_STATUS_INITIALIZED) return;
        
        datetime currentBar = iTime(m_config.symbol, m_config.timeframe, 0);
        if(currentBar != m_lastBarTime)
        {
            m_lastBarTime = currentBar;
            m_lastSignal = GenerateSignal();
            m_lastSignalTime = TimeCurrent();
        }
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        double bbUpper[], bbLower[], bbMiddle[], rsi[], atr[];
        
        if(CopyBuffer(m_hBb, 0, 1, 1, bbMiddle) < 1 ||
           CopyBuffer(m_hBb, 1, 1, 1, bbUpper) < 1 ||
           CopyBuffer(m_hBb, 2, 1, 1, bbLower) < 1 ||
           CopyBuffer(m_hRsi, 0, 1, 1, rsi) < 1 ||
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
        {
            return signal;
        }
        
        double close1 = iClose(m_config.symbol, m_config.timeframe, 1);
        
        // Long Entry
        if(close1 < bbLower[0] && rsi[0] < 25)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.75;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_ASK);
            signal.stopLoss = signal.entryPrice - (2.0 * atr[0]);
            signal.takeProfit = bbMiddle[0];
            signal.reason = "XAGUSD-3: Oversold BB Mean Reversion (4H)";
        }
        // Short Entry
        else if(close1 > bbUpper[0] && rsi[0] > 75)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.75;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_BID);
            signal.stopLoss = signal.entryPrice + (2.0 * atr[0]);
            signal.takeProfit = bbMiddle[0];
            signal.reason = "XAGUSD-3: Overbought BB Mean Reversion (4H)";
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE && signal.entryPrice > 0);
    }
    
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        double atr[];
        if(CopyBuffer(m_hAtr, 0, 1, 1, atr) > 0)
        {
            if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - (2.0 * atr[0]);
            else stopLoss = entryPrice + (2.0 * atr[0]);
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        double bbMiddle[];
        if(CopyBuffer(m_hBb, 0, 1, 1, bbMiddle) > 0)
        {
            takeProfit = bbMiddle[0];
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
