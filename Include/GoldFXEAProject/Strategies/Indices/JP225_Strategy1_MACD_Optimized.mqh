//+------------------------------------------------------------------+
//|                                  JP225_Strategy1_MACD_Optimized.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * JP225 Strategy 1: MACD Optimized (4H)
 * Type: Trend Following
 * 
 * Rules:
 * 1. Long: MACD Line > Signal Line AND MACD Histogram > 0 AND Close > EMA(50).
 * 2. Short: MACD Line < Signal Line AND MACD Histogram < 0 AND Close < EMA(50).
 * 3. Optimized MACD Parameters: Fast=15, Slow=40, Signal=5.
 * 4. SL: 2.0 * ATR(14).
 * 5. TP: 2.5 * ATR(14).
 */
class CJP225_Strategy1_MACD_Optimized : public CStrategyBase
{
private:
    int m_macdFast;
    int m_macdSlow;
    int m_macdSignal;
    int m_emaPeriod;
    int m_atrPeriod;
    
    int m_hMacd;
    int m_hEma;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CJP225_Strategy1_MACD_Optimized(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("JP225_Strategy1_MACD_Optimized", logger, riskManager)
    {
        m_macdFast = 15;
        m_macdSlow = 40;
        m_macdSignal = 5;
        m_emaPeriod = 50;
        m_atrPeriod = 14;
        
        m_hMacd = INVALID_HANDLE;
        m_hEma = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_hMacd = iMACD(m_config.symbol, m_config.timeframe, m_macdFast, m_macdSlow, m_macdSignal, PRICE_CLOSE);
        m_hEma = iMA(m_config.symbol, m_config.timeframe, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_hAtr = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_hMacd == INVALID_HANDLE || m_hEma == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
        {
            m_logger.Error("JP225_Strategy1: Failed to initialize indicators", m_moduleName);
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
        
        double macdMain[], macdSignal[], ema[], atr[];
        
        if(CopyBuffer(m_hMacd, 0, 1, 2, macdMain) < 2 ||
           CopyBuffer(m_hMacd, 1, 1, 2, macdSignal) < 2 ||
           CopyBuffer(m_hEma, 0, 1, 1, ema) < 1 ||
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
        {
            return signal;
        }
        
        double close1 = iClose(m_config.symbol, m_config.timeframe, 1);
        double hist1 = macdMain[0] - macdSignal[0];
        
        // Long Entry
        if(macdMain[0] > macdSignal[0] && hist1 > 0 && close1 > ema[0])
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.75;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_ASK);
            signal.stopLoss = signal.entryPrice - (2.0 * atr[0]);
            signal.takeProfit = signal.entryPrice + (2.5 * atr[0]);
            signal.reason = "JP225-1: Optimized MACD Bullish (4H)";
        }
        // Short Entry
        else if(macdMain[0] < macdSignal[0] && hist1 < 0 && close1 < ema[0])
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.75;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_BID);
            signal.stopLoss = signal.entryPrice + (2.0 * atr[0]);
            signal.takeProfit = signal.entryPrice - (2.5 * atr[0]);
            signal.reason = "JP225-1: Optimized MACD Bearish (4H)";
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
        double atr[];
        if(CopyBuffer(m_hAtr, 0, 1, 1, atr) > 0)
        {
            if(orderType == ORDER_TYPE_BUY) takeProfit = entryPrice + (2.5 * atr[0]);
            else takeProfit = entryPrice - (2.5 * atr[0]);
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
