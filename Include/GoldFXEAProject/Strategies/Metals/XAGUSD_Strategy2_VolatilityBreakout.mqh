//+------------------------------------------------------------------+
//|                                  XAGUSD_Strategy2_VolatilityBreakout.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * XAGUSD Strategy 2: Volatility Breakout (1H)
 * Type: Breakout / Scalping
 * 
 * Rules:
 * 1. Long: Close > Upper Keltner Channel AND Volume > MA(Volume, 20).
 * 2. Short: Close < Lower Keltner Channel AND Volume > MA(Volume, 20).
 * 3. SL: 1.0 * ATR(14).
 * 4. TP: 2.0 * ATR(14).
 */
class CXAGUSD_Strategy2_VolatilityBreakout : public CStrategyBase
{
private:
    int m_kcPeriod;
    double m_kcMult;
    int m_atrPeriod;
    int m_volPeriod;
    
    int m_hEma;
    int m_hAtr;
    int m_hVol;
    
    datetime m_lastBarTime;

public:
    CXAGUSD_Strategy2_VolatilityBreakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("XAGUSD_Strategy2_VolatilityBreakout", logger, riskManager)
    {
        m_kcPeriod = 20;
        m_kcMult = 2.0;
        m_atrPeriod = 14;
        m_volPeriod = 20;
        
        m_hEma = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_hVol = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "XAGUSD";
        m_timeframe = PERIOD_H1;
    }
    
    virtual bool Initialize() override
    {
        m_hEma = iMA(m_symbol, m_timeframe, m_kcPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        m_hVol = iVolumes(m_symbol, m_timeframe, VOLUME_TICK);
        
        if(m_hEma == INVALID_HANDLE || m_hAtr == INVALID_HANDLE || m_hVol == INVALID_HANDLE)
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
        double ema[], atr[], vol[];
        if(CopyBuffer(m_hEma, 0, 1, 1, ema) < 1 || 
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1 ||
           CopyBuffer(m_hVol, 0, 1, m_volPeriod + 1, vol) < m_volPeriod + 1)
        {
            return SIGNAL_NONE;
        }
        
        double volAvg = 0;
        for(int i=1; i<=m_volPeriod; i++) volAvg += vol[i];
        volAvg /= m_volPeriod;
        
        double kcUpper = ema[0] + (m_kcMult * atr[0]);
        double kcLower = ema[0] - (m_kcMult * atr[0]);
        double close1 = iClose(m_symbol, m_timeframe, 1);
        
        // Long Entry
        if(close1 > kcUpper && vol[0] > volAvg)
            return SIGNAL_BUY;
            
        // Short Entry
        if(close1 < kcLower && vol[0] > volAvg)
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
                stopLoss = entryPrice - 1.0 * atr[0];
            else
                stopLoss = entryPrice + 1.0 * atr[0];
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
