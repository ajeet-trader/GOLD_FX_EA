//+------------------------------------------------------------------+
//|                             GBPNZD_Strategy1_CorrelationReversal.mqh |
//|                                  Copyright 2025, Gold_FX_EA Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Gold_FX_EA Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * GBPNZD Strategy 1: Correlation Reversal (Daily)
 * Type: Pairs Trading / Mean Reversion
 * 
 * Rules:
 * 1. Pair Ratio = (GBP/NZD) / (EUR/NZD).
 * 2. Short Signal: Ratio > 1.125 (GBP overstretched vs EUR).
 * 3. Long Signal: Ratio < 1.05 (EUR overstretched vs GBP - added for symmetry).
 * 4. Exit: When ratio reverts to 1.10 - 1.12.
 * 5. SL: 2.0 * ATR(14).
 * 6. TP: Dynamic based on ratio target (exit rule).
 */
class CGBPNZD_Strategy1_CorrelationReversal : public CStrategyBase
{
private:
    string m_secondarySymbol;
    double m_upperThreshold;
    double m_lowerThreshold;
    double m_exitTargetUpper;
    double m_exitTargetLower;
    int m_atrPeriod;
    
    int m_hAtr;
    datetime m_lastBarTime;

public:
    CGBPNZD_Strategy1_CorrelationReversal(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("GBPNZD_Strategy1_CorrelationReversal", logger, riskManager)
    {
        m_secondarySymbol = "EURNZD";
        m_upperThreshold = 1.125;
        m_lowerThreshold = 1.050;
        m_exitTargetUpper = 1.120;
        m_exitTargetLower = 1.100;
        m_atrPeriod = 14;
        
        m_hAtr = INVALID_HANDLE;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        if(!CStrategyBase::Initialize()) return false;
        
        // Ensure secondary symbol is available
        if(!SymbolSelect(m_secondarySymbol, true))
        {
            m_logger.Error("GBPNZD_Strategy1: Failed to select secondary symbol " + m_secondarySymbol, m_moduleName);
            return false;
        }
        
        m_hAtr = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        if(m_hAtr == INVALID_HANDLE)
        {
            m_logger.Error("GBPNZD_Strategy1: Failed to initialize ATR", m_moduleName);
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
        
        double gbpnzdClose = iClose(m_config.symbol, m_config.timeframe, 1);
        double eurnzdClose = iClose(m_secondarySymbol, m_config.timeframe, 1);
        
        if(gbpnzdClose <= 0 || eurnzdClose <= 0) return signal;
        
        double ratio = gbpnzdClose / eurnzdClose;
        double atr[];
        
        if(CopyBuffer(m_hAtr, 0, 1, 1, atr) < 1) return signal;
        
        // Short Signal: GBP overstretched
        if(ratio > m_upperThreshold)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.85;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_BID);
            signal.stopLoss = signal.entryPrice + (2.0 * atr[0]);
            signal.takeProfit = signal.entryPrice - (gbpnzdClose * (ratio - m_exitTargetUpper)); // Approx TP
            signal.reason = StringFormat("GBPNZD-1: Ratio Overstretched (%.4f > %.4f)", ratio, m_upperThreshold);
        }
        // Long Signal: EUR overstretched (GBP undervalued)
        else if(ratio < m_lowerThreshold)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.85;
            signal.entryPrice = SymbolInfoDouble(m_config.symbol, SYMBOL_ASK);
            signal.stopLoss = signal.entryPrice - (2.0 * atr[0]);
            signal.takeProfit = signal.entryPrice + (gbpnzdClose * (m_exitTargetLower - ratio)); // Approx TP
            signal.reason = StringFormat("GBPNZD-1: Ratio Undervalued (%.4f < %.4f)", ratio, m_lowerThreshold);
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
            if(orderType == ORDER_TYPE_BUY) stopLoss = entryPrice - (2.0 * atr[0]);
            else stopLoss = entryPrice + (2.0 * atr[0]);
        }
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        // TP is handled by ShouldClosePosition or GenerateSignal
        takeProfit = 0; 
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Exit when ratio reverts to 1.10 - 1.12
        double gbpnzdClose = iClose(m_config.symbol, m_config.timeframe, 0);
        double eurnzdClose = iClose(m_secondarySymbol, m_config.timeframe, 0);
        
        if(gbpnzdClose <= 0 || eurnzdClose <= 0) return false;
        
        double ratio = gbpnzdClose / eurnzdClose;
        
        if(PositionSelectByTicket(ticket))
        {
            long type = PositionGetInteger(POSITION_TYPE);
            if(type == POSITION_TYPE_SELL && ratio <= m_exitTargetUpper) return true;
            if(type == POSITION_TYPE_BUY && ratio >= m_exitTargetLower) return true;
        }
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
