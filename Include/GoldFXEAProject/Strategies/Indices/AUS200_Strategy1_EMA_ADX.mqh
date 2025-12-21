//+------------------------------------------------------------------+
//|                                       AUS200_Strategy1_EMA_ADX.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * AUS200 Strategy 1: EMA ADX Trend (4H)
 * Type: Trend Following
 * 
 * Rules:
 * 1. Long: EMA(20) > EMA(50) AND ADX(14) > 25 AND +DI > -DI.
 * 2. Short: EMA(20) < EMA(50) AND ADX(14) > 25 AND -DI > +DI.
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 3.0 * ATR(14).
 */
class CAUS200_Strategy1_EMA_ADX : public CStrategyBase
{
private:
    int m_emaFast;
    int m_emaSlow;
    int m_adxPeriod;
    int m_atrPeriod;
    
    int m_hEmaFast;
    int m_hEmaSlow;
    int m_hAdx;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CAUS200_Strategy1_EMA_ADX(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("AUS200_Strategy1_EMA_ADX", logger, riskManager)
    {
        m_emaFast = 20;
        m_emaSlow = 50;
        m_adxPeriod = 14;
        m_atrPeriod = 14;
        
        m_hEmaFast = INVALID_HANDLE;
        m_hEmaSlow = INVALID_HANDLE;
        m_hAdx = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_hEmaFast = iMA(m_config.symbol, m_config.timeframe, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
        m_hEmaSlow = iMA(m_config.symbol, m_config.timeframe, m_emaSlow, 0, MODE_EMA, PRICE_CLOSE);
        m_hAdx = iADX(m_config.symbol, m_config.timeframe, m_adxPeriod);
        m_hAtr = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_hEmaFast == INVALID_HANDLE || m_hEmaSlow == INVALID_HANDLE || m_hAdx == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
        {
            m_logger.Error("AUS200_Strategy1: Failed to initialize indicators", m_moduleName);
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
        
        double emaFast[], emaSlow[], adx[], pdi[], mdi[], atr[];
        
        if(CopyBuffer(m_hEmaFast, 0, 1, 1, emaFast) < 1 ||
           CopyBuffer(m_hEmaSlow, 0, 1, 1, emaSlow) < 1 ||
           CopyBuffer(m_hAdx, 0, 1, 1, adx) < 1 ||
           CopyBuffer(m_hAdx, 1, 1, 1, pdi) < 1 ||
           CopyBuffer(m_hAdx, 2, 1, 1, mdi) < 1 ||
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
        {
            return signal;
        }
        
        // Long Entry
        if(emaFast[0] > emaSlow[0] && adx[0] > 25 && pdi[0] > mdi[0])
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.80;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_ASK);
            signal.stopLoss = signal.entryPrice - (1.5 * atr[0]);
            signal.takeProfit = signal.entryPrice + (3.0 * atr[0]);
            signal.reason = "AUS200-1: Strong Bullish Trend (4H)";
        }
        // Short Entry
        else if(emaFast[0] < emaSlow[0] && adx[0] > 25 && mdi[0] > pdi[0])
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.80;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_BID);
            signal.stopLoss = signal.entryPrice + (1.5 * atr[0]);
            signal.takeProfit = signal.entryPrice - (3.0 * atr[0]);
            signal.reason = "AUS200-1: Strong Bearish Trend (4H)";
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
            if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - (1.5 * atr[0]);
            else stopLoss = entryPrice + (1.5 * atr[0]);
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        double atr[];
        if(CopyBuffer(m_hAtr, 0, 1, 1, atr) > 0)
        {
            if(orderType == ORDER_TYPE_BUY) takeProfit = entryPrice + (3.0 * atr[0]);
            else takeProfit = entryPrice - (3.0 * atr[0]);
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
