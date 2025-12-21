//+------------------------------------------------------------------+
//|                                  XAUEUR_Strategy2_MeanReversion.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * XAUEUR Strategy 2: Mean Reversion (1H)
 * Type: Mean Reversion
 * 
 * Rules:
 * 1. Long: RSI(14) < 30 AND Close < Lower Bollinger Band(20, 2).
 * 2. Short: RSI(14) > 70 AND Close > Upper Bollinger Band(20, 2).
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: Middle Bollinger Band (MA 20).
 */
class CXAUEUR_Strategy2_MeanReversion : public CStrategyBase
{
private:
    int m_rsiPeriod;
    int m_bbPeriod;
    double m_bbDev;
    int m_atrPeriod;
    
    int m_hRsi;
    int m_hBb;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CXAUEUR_Strategy2_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("XAUEUR_Strategy2_MeanReversion", logger, riskManager)
    {
        m_rsiPeriod = 14;
        m_bbPeriod = 20;
        m_bbDev = 2.0;
        m_atrPeriod = 14;
        
        m_hRsi = INVALID_HANDLE;
        m_hBb = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "XAUEUR";
        m_timeframe = PERIOD_H1;
    }
    
    virtual bool Initialize() override
    {
        m_hRsi = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_hBb = iBands(m_symbol, m_timeframe, m_bbPeriod, 0, m_bbDev, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hRsi == INVALID_HANDLE || m_hBb == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double rsi[], bbUpper[], bbLower[], bbMid[];
        if(CopyBuffer(m_hRsi, 0, 1, 1, rsi) < 1 || 
           CopyBuffer(m_hBb, 1, 1, 1, bbUpper) < 1 ||
           CopyBuffer(m_hBb, 2, 1, 1, bbLower) < 1 ||
           CopyBuffer(m_hBb, 0, 1, 1, bbMid) < 1)
        {
            return SIGNAL_NONE;
        }
        
        double close1 = iClose(m_symbol, m_timeframe, 1);
        
        // Long Entry
        if(rsi[0] < 30 && close1 < bbLower[0])
            return SIGNAL_BUY;
            
        // Short Entry
        if(rsi[0] > 70 && close1 > bbUpper[0])
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
        double bbMid[];
        if(CopyBuffer(m_hBb, 0, 0, 1, bbMid) > 0)
        {
            takeProfit = bbMid[0];
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        return false;
    }
};
