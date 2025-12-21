//+------------------------------------------------------------------+
//|                                     XAGUSD_Strategy4_PairsTrading.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * XAGUSD Strategy 4: Pairs Trading (Gold/Silver Spread)
 * Type: Mean Reversion / Pairs Trading
 * 
 * Rules:
 * 1. Ratio = XAUUSD / XAGUSD.
 * 2. Long XAGUSD: Ratio > 90 (Gold overvalued relative to Silver).
 * 3. Short XAGUSD: Ratio < 75 (Silver overvalued relative to Gold).
 * 4. Exit: When ratio reverts to historical mean (approx 82-84).
 * 5. SL: 3.0 * ATR(14).
 */
class CXAGUSD_Strategy4_PairsTrading : public CStrategyBase
{
private:
    string m_goldSymbol;
    double m_upperThreshold;
    double m_lowerThreshold;
    double m_meanRatio;
    int m_atrPeriod;
    
    int m_hAtr;
    datetime m_lastBarTime;

public:
    CXAGUSD_Strategy4_PairsTrading(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("XAGUSD_Strategy4_PairsTrading", logger, riskManager)
    {
        m_goldSymbol = "XAUUSD";
        m_upperThreshold = 90.0;
        m_lowerThreshold = 75.0;
        m_meanRatio = 83.0;
        m_atrPeriod = 14;
        
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        // Ensure gold symbol is available
        if(!SymbolSelect(m_goldSymbol, true))
        {
            m_logger.Error("XAGUSD_Strategy4: Failed to select gold symbol " + m_goldSymbol, m_moduleName);
            return false;
        }
        
        m_hAtr = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_hAtr == INVALID_HANDLE)
        {
            m_logger.Error("XAGUSD_Strategy4: Failed to initialize ATR", m_moduleName);
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
        
        double xauClose = iClose(m_goldSymbol, m_config.timeframe, 1);
        double xagClose = iClose(m_config.symbol, m_config.timeframe, 1);
        
        if(xauClose <= 0 || xagClose <= 0) return signal;
        
        double ratio = xauClose / xagClose;
        double atr[];
        
        if(CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1) return signal;
        
        // Long XAGUSD: Silver is undervalued (Ratio too high)
        if(ratio > m_upperThreshold)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.80;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_ASK);
            signal.stopLoss = signal.entryPrice - (3.0 * atr[0]);
            signal.takeProfit = signal.entryPrice * (ratio / m_meanRatio);
            signal.reason = StringFormat("XAGUSD-4: Ratio Overstretched (%.2f > %.2f)", ratio, m_upperThreshold);
        }
        // Short XAGUSD: Silver is overvalued (Ratio too low)
        else if(ratio < m_lowerThreshold)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.80;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_BID);
            signal.stopLoss = signal.entryPrice + (3.0 * atr[0]);
            signal.takeProfit = signal.entryPrice * (ratio / m_meanRatio);
            signal.reason = StringFormat("XAGUSD-4: Ratio Undervalued (%.2f < %.2f)", ratio, m_lowerThreshold);
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
            if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - (3.0 * atr[0]);
            else stopLoss = entryPrice + (3.0 * atr[0]);
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        takeProfit = 0; // Handled by ShouldClosePosition
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        double xauClose = iClose(m_goldSymbol, m_config.timeframe, 0);
        double xagClose = iClose(m_config.symbol, m_config.timeframe, 0);
        
        if(xauClose <= 0 || xagClose <= 0) return false;
        
        double ratio = xauClose / xagClose;
        
        if(PositionSelectByTicket(ticket))
        {
            long type = PositionGetInteger(POSITION_TYPE);
            // Close when ratio reverts to mean
            if(type == POSITION_TYPE_BUY && ratio <= m_meanRatio) return true;
            if(type == POSITION_TYPE_SELL && ratio >= m_meanRatio) return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
