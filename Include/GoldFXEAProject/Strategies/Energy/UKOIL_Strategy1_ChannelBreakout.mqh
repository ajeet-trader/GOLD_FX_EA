//+------------------------------------------------------------------+
//|                                  UKOIL_Strategy1_ChannelBreakout.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * UKOIL Strategy 1: Channel Breakout with Volume Confirmation (4H)
 * Type: Breakout / trend following
 * 
 * Rules:
 * 1. Identify channel (20-30 bars).
 * 2. Long: Close > Resistance (High of last 30 bars) + 1.0 * ATR(14).
 * 3. Short: Close < Support (Low of last 30 bars) - 1.0 * ATR(14).
 * 4. Volume > 20-bar average.
 * 5. ADX(14) > 20.
 * 6. SL: 1.5 * ATR(14).
 * 7. TP: 2.5 * ATR(14).
 */
class CUKOIL_Strategy1_ChannelBreakout : public CStrategyBase
{
private:
    int m_channelPeriod;
    int m_atrPeriod;
    int m_adxPeriod;
    int m_volPeriod;
    
    int m_hAtr;
    int m_hAdx;
    int m_hVol;
    
    datetime m_lastBarTime;

public:
    CUKOIL_Strategy1_ChannelBreakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("UKOIL_Strategy1_ChannelBreakout", logger, riskManager)
    {
        m_channelPeriod = 30;
        m_atrPeriod = 14;
        m_adxPeriod = 14;
        m_volPeriod = 20;
        
        m_hAtr = INVALID_HANDLE;
        m_hAdx = INVALID_HANDLE;
        m_hVol = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "UKOIL";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        m_hAdx = iADX(m_symbol, m_timeframe, m_adxPeriod);
        m_hVol = iVolumes(m_symbol, m_timeframe, VOLUME_TICK);
        
        if(m_hAtr == INVALID_HANDLE || m_hAdx == INVALID_HANDLE || m_hVol == INVALID_HANDLE)
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
        double atr[], adx[], vol[];
        
        if(CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1 ||
           CopyBuffer(m_hAdx, 0, 1, 1, adx) < 1 ||
           CopyBuffer(m_hVol, 0, 1, m_volPeriod + 1, vol) < m_volPeriod + 1)
        {
            return SIGNAL_NONE;
        }
        
        double close1 = iClose(m_symbol, m_timeframe, 1);
        
        // Channel Support/Resistance
        double resistance = 0;
        double support = 1000000;
        for(int i=2; i<=m_channelPeriod + 1; i++)
        {
            double h = iHigh(m_symbol, m_timeframe, i);
            double l = iLow(m_symbol, m_timeframe, i);
            if(h > resistance) resistance = h;
            if(l < support) support = l;
        }
        
        // Volume Average
        double volAvg = 0;
        for(int i=1; i<=m_volPeriod; i++) volAvg += vol[i];
        volAvg /= (double)m_volPeriod;
        
        // Long Entry Rules
        bool breakoutLong = close1 > (resistance + 1.0 * atr[0]);
        bool volCondition = vol[0] > volAvg;
        bool adxCondition = adx[0] > 20;
        
        if(breakoutLong && volCondition && adxCondition)
        {
            return SIGNAL_BUY;
        }
        
        // Short Entry Rules
        bool breakoutShort = close1 < (support - 1.0 * atr[0]);
        
        if(breakoutShort && volCondition && adxCondition)
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
