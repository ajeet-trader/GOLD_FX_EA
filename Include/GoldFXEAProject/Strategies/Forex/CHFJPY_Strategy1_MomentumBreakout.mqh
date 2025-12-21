//+------------------------------------------------------------------+
//|                                  CHFJPY_Strategy1_MomentumBreakout.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * CHFJPY Strategy 1: Momentum + Breakout (4H)
 * Type: Trend Following / Momentum
 * 
 * Rules:
 * 1. Long: MACD Histogram > 0 AND RSI(14) > 50 AND Close > 20-bar High.
 * 2. Short: MACD Histogram < 0 AND RSI(14) < 50 AND Close < 20-bar Low.
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 2.5 * ATR(14).
 */
class CCHFJPY_Strategy1_MomentumBreakout : public CStrategyBase
{
private:
    int m_macdFast;
    int m_macdSlow;
    int m_macdSignal;
    int m_rsiPeriod;
    int m_rangePeriod;
    int m_atrPeriod;
    
    int m_hMacd;
    int m_hRsi;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CCHFJPY_Strategy1_MomentumBreakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("CHFJPY_Strategy1_MomentumBreakout", logger, riskManager)
    {
        m_macdFast = 12;
        m_macdSlow = 26;
        m_macdSignal = 9;
        m_rsiPeriod = 14;
        m_rangePeriod = 20;
        m_atrPeriod = 14;
        
        m_hMacd = INVALID_HANDLE;
        m_hRsi = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "CHFJPY";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hMacd = iMACD(m_symbol, m_timeframe, m_macdFast, m_macdSlow, m_macdSignal, PRICE_CLOSE);
        m_hRsi = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hMacd == INVALID_HANDLE || m_hRsi == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double macdMain[], macdSig[], rsi[];
        
        if(CopyBuffer(m_hMacd, 0, 1, 1, macdMain) < 1 ||
           CopyBuffer(m_hMacd, 1, 1, 1, macdSig) < 1 ||
           CopyBuffer(m_hRsi, 0, 1, 1, rsi) < 1)
        {
            return SIGNAL_NONE;
        }
        
        double hist = macdMain[0] - macdSig[0];
        double high20 = iHigh(m_symbol, m_timeframe, iHighest(m_symbol, m_timeframe, MODE_HIGH, m_rangePeriod, 2));
        double low20 = iLow(m_symbol, m_timeframe, iLowest(m_symbol, m_timeframe, MODE_LOW, m_rangePeriod, 2));
        double close1 = iClose(m_symbol, m_timeframe, 1);
        
        // Long Entry
        if(hist > 0 && rsi[0] > 50 && close1 > high20)
            return SIGNAL_BUY;
            
        // Short Entry
        if(hist < 0 && rsi[0] < 50 && close1 < low20)
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
