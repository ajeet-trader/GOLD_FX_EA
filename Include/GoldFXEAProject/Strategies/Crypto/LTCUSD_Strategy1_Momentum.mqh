//+------------------------------------------------------------------+
//|                                     LTCUSD_Strategy1_Momentum.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * LTCUSD Strategy 1: RSI + MACD Momentum (4H)
 * Type: Momentum / Trend Following
 * 
 * Rules:
 * 1. Long: Close > EMA(50) AND RSI(14) crosses above 40 AND MACD histogram rising.
 * 2. Short: Close < EMA(50) AND RSI(14) crosses below 60 AND MACD histogram falling.
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: 2.5 * ATR(14).
 */
class CLTCUSD_Strategy1_Momentum : public CStrategyBase
{
private:
    int m_rsiPeriod;
    int m_emaPeriod;
    int m_macdFast;
    int m_macdSlow;
    int m_macdSignal;
    int m_atrPeriod;
    
    int m_hRsi;
    int m_hEma;
    int m_hMacd;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CLTCUSD_Strategy1_Momentum(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("LTCUSD_Strategy1_Momentum", logger, riskManager)
    {
        m_rsiPeriod = 14;
        m_emaPeriod = 50;
        m_macdFast = 12;
        m_macdSlow = 26;
        m_macdSignal = 9;
        m_atrPeriod = 14;
        
        m_hRsi = INVALID_HANDLE;
        m_hEma = INVALID_HANDLE;
        m_hMacd = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
        
        m_symbol = "LTCUSD";
        m_timeframe = PERIOD_H4;
    }
    
    virtual bool Initialize() override
    {
        m_hRsi = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_hEma = iMA(m_symbol, m_timeframe, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_hMacd = iMACD(m_symbol, m_timeframe, m_macdFast, m_macdSlow, m_macdSignal, PRICE_CLOSE);
        m_hAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
        
        if(m_hRsi == INVALID_HANDLE || m_hEma == INVALID_HANDLE || 
           m_hMacd == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
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
        double rsi[], ema[], macdMain[], macdSig[];
        
        if(CopyBuffer(m_hRsi, 0, 1, 2, rsi) < 2 ||
           CopyBuffer(m_hEma, 0, 1, 1, ema) < 1 ||
           CopyBuffer(m_hMacd, 0, 1, 2, macdMain) < 2 ||
           CopyBuffer(m_hMacd, 1, 1, 2, macdSig) < 2)
        {
            return SIGNAL_NONE;
        }
        
        double close1 = iClose(m_symbol, m_timeframe, 1);
        double hist1 = macdMain[0] - macdSig[0];
        double hist2 = macdMain[1] - macdSig[1];
        
        // Long Entry
        if(close1 > ema[0] && rsi[0] > 40 && rsi[1] <= 40 && hist1 > hist2)
            return SIGNAL_BUY;
            
        // Short Entry
        if(close1 < ema[0] && rsi[0] < 60 && rsi[1] >= 60 && hist1 < hist2)
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
