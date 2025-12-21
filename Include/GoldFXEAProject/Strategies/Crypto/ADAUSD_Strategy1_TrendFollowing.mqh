//+------------------------------------------------------------------+
//|                                  ADAUSD_Strategy1_TrendFollowing.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * ADAUSD Strategy 1: Trend Following (4H)
 * Type: Trend Following
 * 
 * Rules:
 * 1. Long: EMA(20) > EMA(50) AND ADX(14) > 25.
 * 2. Short: EMA(20) < EMA(50) AND ADX(14) > 25.
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 3.0 * ATR(14).
 */
class CADAUSD_Strategy1_TrendFollowing : public CStrategyBase
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
    CADAUSD_Strategy1_TrendFollowing(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("ADAUSD_Strategy1_TrendFollowing", logger, riskManager)
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
        
        m_symbol = "ADAUSD";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hEmaFast = iMA(m_symbol, m_timeframe, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
        m_hEmaSlow = iMA(m_symbol, m_timeframe, m_emaSlow, 0, MODE_EMA, PRICE_CLOSE);
        m_hAdx = iADX(m_symbol, m_timeframe, m_adxPeriod);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hEmaFast == INVALID_HANDLE || m_hEmaSlow == INVALID_HANDLE || 
           m_hAdx == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double emaF[], emaS[], adx[];
        
        if(CopyBuffer(m_hEmaFast, 0, 1, 1, emaF) < 1 ||
           CopyBuffer(m_hEmaSlow, 0, 1, 1, emaS) < 1 ||
           CopyBuffer(m_hAdx, 0, 1, 1, adx) < 1)
        {
            return SIGNAL_NONE;
        }
        
        if(emaF[0] > emaS[0] && adx[0] > 25)
            return SIGNAL_BUY;
            
        if(emaF[0] < emaS[0] && adx[0] > 25)
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
                takeProfit = entryPrice + 3.0 * atr[0];
            else
                takeProfit = entryPrice - 3.0 * atr[0];
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        return false;
    }
};
