//+------------------------------------------------------------------+
//|                                  AUDNZD_Strategy1_BreakoutPullback.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * AUDNZD Strategy 1: Breakout Pullback (Swing)
 * Type: Breakout / Trend Following
 * 
 * Rules:
 * 1. Long: Price broke above 20-bar High in last 5 bars AND currently pulls back to EMA(20).
 * 2. Short: Price broke below 20-bar Low in last 5 bars AND currently pulls back to EMA(20).
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 2.0 * ATR(14).
 */
class CAUDNZD_Strategy1_BreakoutPullback : public CStrategyBase
{
private:
    int m_rangePeriod;
    int m_emaPeriod;
    int m_atrPeriod;
    int m_lookback;
    
    int m_hEma;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CAUDNZD_Strategy1_BreakoutPullback(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("AUDNZD_Strategy1_BreakoutPullback", logger, riskManager)
    {
        m_rangePeriod = 20;
        m_emaPeriod = 20;
        m_atrPeriod = 14;
        m_lookback = 5;
        
        m_hEma = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "AUDNZD";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hEma = iMA(m_symbol, m_timeframe, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hEma == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
        {
            m_logger.Error(m_name + " failed to initialize indicators");
            return false;
        }
        
        return true;
    }
    
    virtual void ProcessTick(MqlTick &tick) override
    {
        datetime currentBar = iTime(m_symbol, m_timeframe, 0);
        if(currentBar != m_lastBarTime)
        {
            m_lastBarTime = currentBar;
            TradeSignal signal = GenerateSignal();
            if(signal != SIGNAL_NONE)
            {
                // Dispatcher handles execution
            }
        }
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        double ema[], atr[];
        if(CopyBuffer(m_hEma, 0, 1, 1, ema) < 1 || CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
            return SIGNAL_NONE;
            
        double close1 = iClose(m_symbol, m_timeframe, 1);
        double low1 = iLow(m_symbol, m_timeframe, 1);
        double high1 = iHigh(m_symbol, m_timeframe, 1);
        
        // Check for breakout in last 5 bars
        bool buyBreakout = false;
        bool sellBreakout = false;
        
        for(int i=2; i<=m_lookback+1; i++)
        {
            double high_i = iHigh(m_symbol, m_timeframe, i);
            double low_i = iLow(m_symbol, m_timeframe, i);
            double highPrev20 = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, m_rangePeriod, i+1));
            double lowPrev20 = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, m_rangePeriod, i+1));
            
            if(high_i > highPrev20) buyBreakout = true;
            if(low_i < lowPrev20) sellBreakout = true;
        }
        
        // Pullback condition: price touches or is near EMA
        double threshold = 0.2 * atr[0];
        
        if(buyBreakout && low1 <= ema[0] + threshold && close1 > ema[0])
            return SIGNAL_BUY;
            
        if(sellBreakout && high1 >= ema[0] - threshold && close1 < ema[0])
            return SIGNAL_SELL;
            
        return SIGNAL_NONE;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return true;
    }
    
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        double atr[];
        if(CopyBuffer(m_hAtr, 0, 0, 1, atr) > 0)
        {
            if(orderType == ORDER_TYPE_BUY)
                stopLoss = entryPrice - 1.5 * atr[0];
            else
                stopLoss = entryPrice + 1.5 * atr[0];
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        double atr[];
        if(CopyBuffer(m_hAtr, 0, 0, 1, atr) > 0)
        {
            if(orderType == ORDER_TYPE_BUY)
                takeProfit = entryPrice + 2.0 * atr[0];
            else
                takeProfit = entryPrice - 2.0 * atr[0];
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        return false;
    }
};
