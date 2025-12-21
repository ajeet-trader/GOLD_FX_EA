//+------------------------------------------------------------------+
//|                                   US500_Strategy1_MeanReversion.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * US500 Strategy 1: Mean Reversion (Daily)
 * Type: Mean Reversion
 * 
 * Rules:
 * 1. Long: Close < MA(20) - (0.5 * ATR(14)) AND RSI(7) < 30 AND Close > Open.
 * 2. Short: Close > MA(20) + (0.5 * ATR(14)) AND RSI(7) > 70 AND Close < Open.
 * 3. SL: 2.0 * ATR(14).
 * 4. TP: MA(20).
 */
class CUS500_Strategy1_MeanReversion : public CStrategyBase
{
private:
    int m_rsiPeriod;
    int m_maPeriod;
    int m_atrPeriod;
    
    int m_hRsi;
    int m_hMa;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CUS500_Strategy1_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("US500_Strategy1_MeanReversion", logger, riskManager)
    {
        m_rsiPeriod = 7;
        m_maPeriod = 20;
        m_atrPeriod = 14;
        
        m_hRsi = INVALID_HANDLE;
        m_hMa = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "US500";
        m_timeframe = PERIOD_D1;
    }
    
    virtual bool Initialize() override
    {
        m_hRsi = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_hMa = iMA(m_symbol, m_timeframe, m_maPeriod, 0, MODE_SMA, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hRsi == INVALID_HANDLE || m_hMa == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double rsi[], ma[], atr[];
        
        if(CopyBuffer(m_hRsi, 0, 1, 1, rsi) < 1 ||
           CopyBuffer(m_hMa, 0, 1, 1, ma) < 1 ||
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
        {
            return SIGNAL_NONE;
        }
        
        double close1 = iClose(m_symbol, m_timeframe, 1);
        double open1 = iOpen(m_symbol, m_timeframe, 1);
        
        // Long Entry
        if(close1 < (ma[0] - 0.5 * atr[0]) && rsi[0] < 30 && close1 > open1)
            return SIGNAL_BUY;
            
        // Short Entry
        if(close1 > (ma[0] + 0.5 * atr[0]) && rsi[0] > 70 && close1 < open1)
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
                stopLoss = entryPrice - 2.0 * atr[0];
            else
                stopLoss = entryPrice + 2.0 * atr[0];
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        double ma[];
        if(CopyBuffer(m_hMa, 0, 0, 1, ma) > 0)
        {
            takeProfit = ma[0];
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        return false;
    }
};
