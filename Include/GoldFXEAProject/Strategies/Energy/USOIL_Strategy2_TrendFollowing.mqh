//+------------------------------------------------------------------+
//|                                  USOIL_Strategy2_TrendFollowing.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * USOIL Strategy 2: Trend Following with ADX & Moving Average Crossover (4H)
 * Type: Trend following / breakout
 * 
 * Rules:
 * 1. ADX(14) > 25 and rising.
 * 2. +DI > -DI (for long) or -DI > +DI (for short).
 * 3. EMA(20) > EMA(50) > EMA(200) (all aligned upward for long).
 * 4. Price > EMA(20).
 * 5. Breakout trigger: Close > max(High[-5..-1]) + 0.5 * ATR(14).
 * 6. SL: 2.0 * ATR(14).
 * 7. TP: 2.0 * ATR(14).
 */
class CUSOIL_Strategy2_TrendFollowing : public CStrategyBase
{
private:
    int m_adxPeriod;
    int m_emaFast;
    int m_emaMed;
    int m_emaSlow;
    int m_atrPeriod;
    
    int m_hAdx;
    int m_hEmaFast;
    int m_hEmaMed;
    int m_hEmaSlow;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CUSOIL_Strategy2_TrendFollowing(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("USOIL_Strategy2_TrendFollowing", logger, riskManager)
    {
        m_adxPeriod = 14;
        m_emaFast = 20;
        m_emaMed = 50;
        m_emaSlow = 200;
        m_atrPeriod = 14;
        
        m_hAdx = INVALID_HANDLE;
        m_hEmaFast = INVALID_HANDLE;
        m_hEmaMed = INVALID_HANDLE;
        m_hEmaSlow = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "USOIL";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hAdx = iADX(m_symbol, m_timeframe, m_adxPeriod);
        m_hEmaFast = iMA(m_symbol, m_timeframe, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
        m_hEmaMed = iMA(m_symbol, m_timeframe, m_emaMed, 0, MODE_EMA, PRICE_CLOSE);
        m_hEmaSlow = iMA(m_symbol, m_timeframe, m_emaSlow, 0, MODE_EMA, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hAdx == INVALID_HANDLE || m_hEmaFast == INVALID_HANDLE || 
           m_hEmaMed == INVALID_HANDLE || m_hEmaSlow == INVALID_HANDLE || 
           m_hAtr == INVALID_HANDLE)
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
                // Logic to execute signal is handled by StrategyDispatcher
            }
        }
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        double adx[], diPlus[], diMinus[], emaFast[], emaMed[], emaSlow[], atr[];
        
        if(CopyBuffer(m_hAdx, 0, 1, 2, adx) < 2 ||
           CopyBuffer(m_hAdx, 1, 1, 1, diPlus) < 1 ||
           CopyBuffer(m_hAdx, 2, 1, 1, diMinus) < 1 ||
           CopyBuffer(m_hEmaFast, 0, 1, 1, emaFast) < 1 ||
           CopyBuffer(m_hEmaMed, 0, 1, 1, emaMed) < 1 ||
           CopyBuffer(m_hEmaSlow, 0, 1, 1, emaSlow) < 1 ||
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
        {
            return SIGNAL_NONE;
        }
        
        double close1 = iClose(m_symbol, m_timeframe, 1);
        
        // Find max High of last 5 bars
        double maxHigh5 = 0;
        double minLow5 = 1000000;
        for(int i=1; i<=5; i++)
        {
            double h = iHigh(m_symbol, m_timeframe, i);
            double l = iLow(m_symbol, m_timeframe, i);
            if(h > maxHigh5) maxHigh5 = h;
            if(l < minLow5) minLow5 = l;
        }
        
        // Long Entry Rules
        // 1. ADX > 25 and rising
        bool adxConditionLong = (adx[0] > 25) && (adx[0] > adx[1]);
        // 2. +DI > -DI
        bool diConditionLong = diPlus[0] > diMinus[0];
        // 3. EMA(20) > EMA(50) > EMA(200)
        bool emaConditionLong = (emaFast[0] > emaMed[0]) && (emaMed[0] > emaSlow[0]);
        // 4. Price > EMA(20)
        bool priceConditionLong = close1 > emaFast[0];
        // 5. Breakout trigger
        bool breakoutLong = close1 > (maxHigh5 + 0.5 * atr[0]);
        
        if(adxConditionLong && diConditionLong && emaConditionLong && priceConditionLong && breakoutLong)
        {
            return SIGNAL_BUY;
        }
        
        // Short Entry Rules
        // 1. ADX > 25 and rising
        bool adxConditionShort = (adx[0] > 25) && (adx[0] > adx[1]);
        // 2. -DI > +DI
        bool diConditionShort = diMinus[0] > diPlus[0];
        // 3. EMA(20) < EMA(50) < EMA(200)
        bool emaConditionShort = (emaFast[0] < emaMed[0]) && (emaMed[0] < emaSlow[0]);
        // 4. Price < EMA(20)
        bool priceConditionShort = close1 < emaFast[0];
        // 5. Breakout trigger
        bool breakoutShort = close1 < (minLow5 - 0.5 * atr[0]);
        
        if(adxConditionShort && diConditionShort && emaConditionShort && priceConditionShort && breakoutShort)
        {
            return SIGNAL_SELL;
        }
        
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
                stopLoss = entryPrice - 2.0 * atr[0];
            else
                stopLoss = entryPrice + 2.0 * atr[0];
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
        // Exit if ADX falls below 20
        double adx[];
        if(CopyBuffer(m_hAdx, 0, 0, 1, adx) > 0)
        {
            if(adx[0] < 20) return true;
        }
        return false;
    }
};
