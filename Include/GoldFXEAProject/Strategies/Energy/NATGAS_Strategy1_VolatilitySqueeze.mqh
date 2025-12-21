//+------------------------------------------------------------------+
//|                               NATGAS_Strategy1_VolatilitySqueeze.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * NATGAS Strategy 1: Volatility Squeeze (Daily)
 * Type: Breakout / Trend Following
 * 
 * Rules:
 * 1. Squeeze: Bollinger Bands (20, 2.0) are inside Keltner Channel (20, 1.5).
 * 2. Breakout: Price closes above/below Bollinger Bands when squeeze releases.
 * 3. Filter: ADX(14) > 20 for trend confirmation.
 * 4. SL: 1.5 * ATR(14)
 * 5. TP: 3.0 * ATR(14)
 */
class CNATGAS_Strategy1_VolatilitySqueeze : public CStrategyBase
{
private:
    int m_bbPeriod;
    double m_bbStdDev;
    int m_kcPeriod;
    double m_kcMult;
    int m_adxPeriod;
    int m_atrPeriod;
    
    int m_hBB;
    int m_hKC; // We'll use iEnvelopes or custom logic for KC if needed, but MQL5 has no native KC. 
               // KC = EMA(Period) +/- Mult * ATR(Period).
    int m_hEmaKC;
    int m_hAtr;
    int m_hAdx;
    
    datetime m_lastBarTime;

public:
    CNATGAS_Strategy1_VolatilitySqueeze(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("NATGAS_Strategy1_VolatilitySqueeze", logger, riskManager)
    {
        m_bbPeriod = 20;
        m_bbStdDev = 2.0;
        m_kcPeriod = 20;
        m_kcMult = 1.5;
        m_adxPeriod = 14;
        m_atrPeriod = 14;
        
        m_hBB = INVALID_HANDLE;
        m_hEmaKC = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_hAdx = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "NATGAS";
        m_timeframe = PERIOD_D1;
    }
    
    virtual bool Initialize() override
    {
        m_hBB = iBands(m_symbol, m_timeframe, m_bbPeriod, 0, m_bbStdDev, PRICE_CLOSE);
        m_hEmaKC = iMA(m_symbol, m_timeframe, m_kcPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        m_hAdx = iADX(m_symbol, m_timeframe, m_adxPeriod);
        
        if(m_hBB == INVALID_HANDLE || m_hEmaKC == INVALID_HANDLE || 
           m_hAtr == INVALID_HANDLE || m_hAdx == INVALID_HANDLE)
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
        double bbUpper[], bbLower[], emaKC[], atr[], adx[];
        
        if(CopyBuffer(m_hBB, 1, 1, 2, bbUpper) < 2 ||
           CopyBuffer(m_hBB, 2, 1, 2, bbLower) < 2 ||
           CopyBuffer(m_hEmaKC, 0, 1, 2, emaKC) < 2 ||
           CopyBuffer(m_hAtr, 0, 1, 2, atr) < 2 ||
           CopyBuffer(m_hAdx, 0, 1, 2, adx) < 2)
        {
            return SIGNAL_NONE;
        }
        
        // Calculate Keltner Channels for previous bar
        double kcUpper1 = emaKC[0] + (m_kcMult * atr[0]);
        double kcLower1 = emaKC[0] - (m_kcMult * atr[0]);
        
        // Squeeze check: BB inside KC
        bool isSqueezed1 = (bbUpper[0] < kcUpper1) && (bbLower[0] > kcLower1);
        
        // Breakout check
        double close1 = iClose(m_symbol, m_timeframe, 1);
        
        if(isSqueezed1)
        {
            if(close1 > bbUpper[0] && adx[0] > 20)
                return SIGNAL_BUY;
            if(close1 < bbLower[0] && adx[0] > 20)
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
