//+------------------------------------------------------------------+
//|                                  FTSE100_Strategy1_MeanReversion.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * FTSE100 Strategy 1: Mean Reversion (1H)
 * Type: Mean Reversion
 * 
 * Rules:
 * 1. Long: Close < MA(20) - (0.5 * ATR(14)) AND RSI(14) < 35.
 * 2. Short: Close > MA(20) + (0.5 * ATR(14)) AND RSI(14) > 65.
 * 3. SL: 1.5 * ATR(14).
 * 4. TP: MA(20).
 */
class CFTSE100_Strategy1_MeanReversion : public CStrategyBase
{
private:
    int m_maPeriod;
    int m_rsiPeriod;
    int m_atrPeriod;
    
    int m_hMa;
    int m_hRsi;
    int m_hAtr;
    
    datetime m_lastBarTime;

public:
    CFTSE100_Strategy1_MeanReversion(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("FTSE100_Strategy1_MeanReversion", logger, riskManager)
    {
        m_maPeriod = 20;
        m_rsiPeriod = 14;
        m_atrPeriod = 14;
        
        m_hMa = INVALID_HANDLE;
        m_hRsi = INVALID_HANDLE;
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        m_hMa = iMA(m_config.symbol, m_config.timeframe, m_maPeriod, 0, MODE_SMA, PRICE_CLOSE);
        m_hRsi = iRSI(m_config.symbol, m_config.timeframe, m_rsiPeriod, PRICE_CLOSE);
        m_hAtr = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_hMa == INVALID_HANDLE || m_hRsi == INVALID_HANDLE || m_hAtr == INVALID_HANDLE)
        {
            m_logger.Error("FTSE100_Strategy1: Failed to initialize indicators", m_moduleName);
            return false;
        }
        
        return true;
    }
    
    virtual void ProcessTick(MqlTick &tick) override
    {
        if(m_status != MODULE_STATUS_INITIALIZED) return;
        
        datetime currentBar = iTime(m_config.symbol, m_config.timeframe, 0);
        if(currentBar != m_lastBarTime)
        {
            m_lastBarTime = currentBar;
            m_lastSignal = GenerateSignal();
            m_lastSignalTime = TimeCurrent();
        }
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        double ma[], rsi[], atr[];
        
        if(CopyBuffer(m_hMa, 0, 1, 1, ma) < 1 ||
           CopyBuffer(m_hRsi, 0, 1, 1, rsi) < 1 ||
           CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1)
        {
            return signal;
        }
        
        double close1 = iClose(m_config.symbol, m_config.timeframe, 1);
        
        // Long Entry
        if(close1 < (ma[0] - 0.5 * atr[0]) && rsi[0] < 35)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.70;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_ASK);
            signal.stopLoss = signal.entryPrice - (1.5 * atr[0]);
            signal.takeProfit = ma[0];
            signal.reason = "FTSE100-1: Oversold Mean Reversion (1H)";
        }
        // Short Entry
        else if(close1 > (ma[0] + 0.5 * atr[0]) && rsi[0] > 65)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.70;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_BID);
            signal.stopLoss = signal.entryPrice + (1.5 * atr[0]);
            signal.takeProfit = ma[0];
            signal.reason = "FTSE100-1: Overbought Mean Reversion (1H)";
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE && signal.entryPrice > 0);
    }
    
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        double atr[];
        if(CopyBuffer(m_hAtr, 0, 1, 1, atr) > 0)
        {
            if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - (1.5 * atr[0]);
            else stopLoss = entryPrice + (1.5 * atr[0]);
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        double ma[];
        if(CopyBuffer(m_hMa, 0, 1, 1, ma) > 0)
        {
            takeProfit = ma[0];
        }
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override { return false; }
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
