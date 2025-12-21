//+------------------------------------------------------------------+
//|                                       FRA40_Strategy1_MACD_EMA.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * FRA40 Strategy 1: MACD EMA Trend (1H)
 * Type: Trend Following
 * 
 * Rules:
 * 1. Long: MACD > 0 AND Close > EMA(100).
 * 2. Short: MACD < 0 AND Close < EMA(100).
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 2.0 * ATR(14).
 */
class CFRA40_Strategy1_MACD_EMA : public CStrategyBase
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
    CFRA40_Strategy1_MACD_EMA(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("FRA40_Strategy1_MACD_EMA", logger, riskManager)
    {
        m_macdFast = 12;
        m_macdSlow = 26;
        m_macdSignal = 9;
        m_emaPeriod = 100;
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
            m_logger.Error("FRA40_Strategy1: Failed to initialize indicators", m_moduleName);
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
        
        double macdMain[], ema[], atr[];
        
        if(CopyBuffer(m_hMacd, 0, 1, 1, macdMain) < 1 ||
           CopyBuffer(m_hEma, 0, 1, 1, ema) < 1 ||
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
        {
            return signal;
        }
        
        double close1 = iClose(m_config.symbol, m_config.timeframe, 1);
        
        // Long Entry
        if(macdMain[0] > 0 && close1 > ema[0])
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.70;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_ASK);
            signal.stopLoss = signal.entryPrice - (1.5 * atr[0]);
            signal.takeProfit = signal.entryPrice + (2.0 * atr[0]);
            signal.reason = "FRA40-1: Bullish Trend Alignment (1H)";
        }
        // Short Entry
        else if(macdMain[0] < 0 && close1 < ema[0])
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.70;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_BID);
            signal.stopLoss = signal.entryPrice + (1.5 * atr[0]);
            signal.takeProfit = signal.entryPrice - (2.0 * atr[0]);
            signal.reason = "FRA40-1: Bearish Trend Alignment (1H)";
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
            if(orderType == ORDER_TYPE_BUY) takeProfit = entryPrice + (2.0 * atr[0]);
            else takeProfit = entryPrice - (2.0 * atr[0]);
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
