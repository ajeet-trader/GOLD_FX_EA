//+------------------------------------------------------------------+
//|                                COPPER_Strategy1_EMA_Crossover.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * COPPER Strategy 1: EMA Crossover (4H)
 * Type: Trend Following
 * 
 * Rules:
 * 1. Long: EMA(20) > EMA(50) AND EMA(50) > EMA(200).
 * 2. Short: EMA(20) < EMA(50) AND EMA(50) < EMA(200).
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 3.0 * ATR(14).
 */
class CCOPPER_Strategy1_EMA_Crossover : public CStrategyBase
{
private:
    int m_emaFast;
    int m_emaMed;
    int m_emaSlow;
    int m_atrPeriod;
    
    int m_hEmaFast;
    int m_hEmaMed;
    int m_hEmaSlow;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CCOPPER_Strategy1_EMA_Crossover(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("COPPER_Strategy1_EMA_Crossover", logger, riskManager)
    {
        m_emaFast = 20;
        m_emaMed = 50;
        m_emaSlow = 200;
        m_atrPeriod = 14;
        
        m_hEmaFast = INVALID_HANDLE;
        m_hEmaMed = INVALID_HANDLE;
        m_hEmaSlow = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "COPPER";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hEmaFast = iMA(m_symbol, m_timeframe, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
        m_hEmaMed = iMA(m_symbol, m_timeframe, m_emaMed, 0, MODE_EMA, PRICE_CLOSE);
        m_hEmaSlow = iMA(m_symbol, m_timeframe, m_emaSlow, 0, MODE_EMA, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hEmaFast == INVALID_HANDLE || m_hEmaMed == INVALID_HANDLE || 
           m_hEmaSlow == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double emaF[], emaM[], emaS[];
        
        if(CopyBuffer(m_hEmaFast, 0, 1, 1, emaF) < 1 ||
           CopyBuffer(m_hEmaMed, 0, 1, 1, emaM) < 1 ||
           CopyBuffer(m_hEmaSlow, 0, 1, 1, emaS) < 1)
        {
            return SIGNAL_NONE;
        }
        
        if(emaF[0] > emaM[0] && emaM[0] > emaS[0])
            return SIGNAL_BUY;
            
        if(emaF[0] < emaM[0] && emaM[0] < emaS[0])
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
        // Close if EMA20 crosses back over EMA50
        double emaF[], emaM[];
        if(CopyBuffer(m_hEmaFast, 0, 0, 1, emaF) > 0 && CopyBuffer(m_hEmaMed, 0, 0, 1, emaM) > 0)
        {
            // Position details would be needed here to know if it's buy or sell
            // For now, return false and let TP/SL handle it, or implement properly with ticket info
        }
        return false;
    }
};
