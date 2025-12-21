//+------------------------------------------------------------------+
//|                                COPPER_Strategy2_BollingerBreakout.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * COPPER Strategy 2: Bollinger Breakout (4H)
 * Type: Breakout / Trend Following
 * 
 * Rules:
 * 1. Long: Close crosses above Upper Bollinger Band(20, 2.5).
 * 2. Short: Close crosses below Lower Bollinger Band(20, 2.5).
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 2.5 * ATR(14).
 */
class CCOPPER_Strategy2_BollingerBreakout : public CStrategyBase
{
private:
    int m_bbPeriod;
    double m_bbStdDev;
    int m_atrPeriod;
    
    int m_hBB;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CCOPPER_Strategy2_BollingerBreakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("COPPER_Strategy2_BollingerBreakout", logger, riskManager)
    {
        m_bbPeriod = 20;
        m_bbStdDev = 2.5;
        m_atrPeriod = 14;
        
        m_hBB = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "COPPER";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hBB = iBands(m_symbol, m_timeframe, m_bbPeriod, 0, m_bbStdDev, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hBB == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double bbUpper[], bbLower[];
        
        if(CopyBuffer(m_hBB, 1, 1, 2, bbUpper) < 2 ||
           CopyBuffer(m_hBB, 2, 1, 2, bbLower) < 2)
        {
            return SIGNAL_NONE;
        }
        
        double close1 = iClose(m_symbol, m_timeframe, 1);
        double close2 = iClose(m_symbol, m_timeframe, 2);
        
        if(close1 > bbUpper[0] && close2 <= bbUpper[1])
            return SIGNAL_BUY;
            
        if(close1 < bbLower[0] && close2 >= bbLower[1])
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
