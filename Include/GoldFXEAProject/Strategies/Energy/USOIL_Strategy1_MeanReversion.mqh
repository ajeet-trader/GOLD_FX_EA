//+------------------------------------------------------------------+
//|                                USOIL_Strategy1_MeanReversion.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * USOIL Strategy 1: RSI + MACD Mean Reversion (Daily)
 * Type: Mean Reversion / Exhaustion-based swing
 * 
 * Rules:
 * 1. Price extremity: Close < Lower BB(20, 2) OR RSI(14) < 30
 * 2. Momentum setup: MACD histogram is negative but rising (for long)
 * 3. Volume confirmation: Volume > 20-day MA
 * 4. SL: 1.8 * ATR(14)
 * 5. TP1: MA(20), TP2: Opposite BB or 2.0 * ATR
 */
class CUSOIL_Strategy1_MeanReversion : public CStrategyBase
{
private:
    int m_rsiPeriod;
    int m_bbPeriod;
    double m_bbStdDev;
    int m_macdFast;
    int m_macdSlow;
    int m_macdSignal;
    int m_volPeriod;
    int m_atrPeriod;
    
    int m_hRsi;
    int m_hBB;
    int m_hMacd;
    int m_hVol;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CUSOIL_Strategy1_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("USOIL_Strategy1_MeanReversion", logger, riskManager)
    {
        m_rsiPeriod = 14;
        m_bbPeriod = 20;
        m_bbStdDev = 2.0;
        m_macdFast = 12;
        m_macdSlow = 26;
        m_macdSignal = 9;
        m_volPeriod = 20;
        m_atrPeriod = 14;
        
        m_hRsi = INVALID_HANDLE;
        m_hBB = INVALID_HANDLE;
        m_hMacd = INVALID_HANDLE;
        m_hVol = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "USOIL";
        m_timeframe = PERIOD_D1;
    }
    
    virtual bool Initialize() override
    {
        m_hRsi = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_hBB = iBands(m_symbol, m_timeframe, m_bbPeriod, 0, m_bbStdDev, PRICE_CLOSE);
        m_hMacd = iMACD(m_symbol, m_timeframe, m_macdFast, m_macdSlow, m_macdSignal, PRICE_CLOSE);
        m_hVol = iVolumes(m_symbol, m_timeframe, VOLUME_TICK);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hRsi == INVALID_HANDLE || m_hBB == INVALID_HANDLE || m_hMacd == INVALID_HANDLE || 
           m_hVol == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double rsi[], bbUpper[], bbLower[], bbMain[], macdMain[], macdSig[], vol[], atr[];
        
        if(CopyBuffer(m_hRsi, 0, 1, 2, rsi) < 2 ||
           CopyBuffer(m_hBB, 0, 1, 2, bbMain) < 2 ||
           CopyBuffer(m_hBB, 1, 1, 2, bbUpper) < 2 ||
           CopyBuffer(m_hBB, 2, 1, 2, bbLower) < 2 ||
           CopyBuffer(m_hMacd, 0, 1, 2, macdMain) < 2 ||
           CopyBuffer(m_hMacd, 1, 1, 2, macdSig) < 2 ||
           CopyBuffer(m_hVol, 0, 1, 21, vol) < 21 ||
           CopyBuffer(m_hAtr, 0, 1, 2, atr) < 2)
        {
            return SIGNAL_NONE;
        }
        
        double close1 = iClose(m_symbol, m_timeframe, 1);
        double macdHist1 = macdMain[0] - macdSig[0];
        double macdHist2 = macdMain[1] - macdSig[1];
        
        double volAvg = 0;
        for(int i=1; i<=20; i++) volAvg += vol[i];
        volAvg /= 20.0;
        
        // Long Entry Rules
        // 1. Price extremity: Close < Lower BB OR RSI < 30
        bool isOversold = (close1 < bbLower[0]) || (rsi[0] < 30);
        // 2. Momentum setup: MACD histogram rising (getting less negative or more positive)
        bool isMomentumRising = macdHist1 > macdHist2;
        // 3. Volume confirmation
        bool isVolHigh = vol[0] > volAvg;
        
        if(isOversold && isMomentumRising && isVolHigh)
        {
            return SIGNAL_BUY;
        }
        
        // Short Entry Rules
        bool isOverbought = (close1 > bbUpper[0]) || (rsi[0] > 70);
        bool isMomentumFalling = macdHist1 < macdHist2;
        
        if(isOverbought && isMomentumFalling && isVolHigh)
        {
            return SIGNAL_SELL;
        }
        
        return SIGNAL_NONE;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return true; // Simple implementation for now
    }
    
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        double atr[];
        if(CopyBuffer(m_hAtr, 0, 0, 1, atr) > 0)
        {
            if(orderType == ORDER_TYPE_BUY)
                stopLoss = entryPrice - 1.8 * atr[0];
            else
                stopLoss = entryPrice + 1.8 * atr[0];
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        double bbMain[];
        if(CopyBuffer(m_hBB, 0, 0, 1, bbMain) > 0)
        {
            takeProfit = bbMain[0]; // TP1 is the MA(20)
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Add logic to close based on time (5 days) or opposite band
        return false;
    }
};
