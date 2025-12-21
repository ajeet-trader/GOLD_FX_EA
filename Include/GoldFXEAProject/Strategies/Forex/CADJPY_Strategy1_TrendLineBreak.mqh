//+------------------------------------------------------------------+
//|                                  CADJPY_Strategy1_TrendLineBreak.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * CADJPY Strategy 1: Trend-Line Break (Daily)
 * Type: Breakout / Reversal
 * 
 * Rules:
 * 1. Long: Close breaks above 10-bar high with volume confirmation.
 * 2. Short: Close breaks below 10-bar low with volume confirmation.
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 2.5 * ATR(14).
 */
class CCADJPY_Strategy1_TrendLineBreak : public CStrategyBase
{
private:
    int m_rangePeriod;
    int m_atrPeriod;
    int m_volPeriod;
    
    int m_hAtr;
    int m_hVol;
    
    datetime m_lastBarTime;

public:
    CCADJPY_Strategy1_TrendLineBreak(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("CADJPY_Strategy1_TrendLineBreak", logger, riskManager)
    {
        m_rangePeriod = 10;
        m_atrPeriod = 14;
        m_volPeriod = 20;
        
        m_hAtr = INVALID_HANDLE;
        m_hVol = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "CADJPY";
        m_timeframe = PERIOD_D1;
    }
    
    virtual bool Initialize() override
    {
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        m_hVol = iVolumes(m_symbol, m_timeframe, VOLUME_TICK);
        
        if(m_hAtr == INVALID_HANDLE || m_hVol == INVALID_HANDLE)
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
        double vol[];
        if(CopyBuffer(m_hVol, 0, 1, m_volPeriod + 1, vol) < m_volPeriod + 1)
            return SIGNAL_NONE;
            
        double volAvg = 0;
        for(int i=1; i<=m_volPeriod; i++) volAvg += vol[i];
        volAvg /= m_volPeriod;
        
        double high10 = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, m_rangePeriod, 2));
        double low10 = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, m_rangePeriod, 2));
        double close1 = iClose(m_symbol, m_timeframe, 1);
        
        // Long Entry
        if(close1 > high10 && vol[0] > volAvg)
            return SIGNAL_BUY;
            
        // Short Entry
        if(close1 < low10 && vol[0] > volAvg)
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
                takeProfit = entryPrice + 2.5 * atr[0];
            else
                takeProfit = entryPrice - 2.5 * atr[0];
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        return false;
    }
};
