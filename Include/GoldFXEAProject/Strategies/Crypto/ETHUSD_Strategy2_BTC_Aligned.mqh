//+------------------------------------------------------------------+
//|                                  ETHUSD_Strategy2_BTC_Aligned.mqh |
//|                                  JULES Trading Systems            |
//|                                  https://julestrading.com         |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"
#property version   "1.00"
#property strict

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

/**
 * ETHUSD Strategy 2: Trend Following with BTC Confirmation (4H)
 * Type: Trend following / cross-asset confirmation
 * 
 * Concept:
 * - Only trade ETH when BTC and ETH trends align, improving signal quality.
 * 
 * Rules:
 * 1. ETH Trend: Close > ETH-EMA(20) AND ETH-EMA(20) > ETH-EMA(50).
 * 2. BTC Trend: BTC-Close > BTC-EMA(20) AND BTC-EMA(20) > BTC-EMA(50).
 * 3. Breakout: ETH breaks above recent 10-bar high by at least 0.3 * ATR(14).
 * 4. SL: 1.8 * ATR(14).
 * 5. TP: 2.5 * ATR(14).
 */
class CETHUSD_Strategy2_BTC_Aligned : public CStrategyBase
{
private:
    string m_btcSymbol;
    int m_emaFast;
    int m_emaSlow;
    int m_atrPeriod;
    int m_lookback;
    
    // BTC indicators
    int m_hBtcEmaFast;
    int m_hBtcEmaSlow;
    
    datetime m_lastBarTime;

public:
    CETHUSD_Strategy2_BTC_Aligned(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("ETHUSD_Strategy2_BTC_Aligned", logger, riskManager)
    {
        m_btcSymbol = "BTCUSD";
        m_emaFast = 20;
        m_emaSlow = 50;
        m_atrPeriod = 14;
        m_lookback = 10;
        
        m_hBtcEmaFast = INVALID_HANDLE;
        m_hBtcEmaSlow = INVALID_HANDLE;
        m_lastBarTime = 0;
    }
    
    virtual bool Initialize() override
    {
        // Default config
        if(m_config.symbol == "")
        {
            m_config.symbol = "ETHUSD";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 0.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 406; // Adjusted magic
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        // Indicators for ETH
        m_handleEMA_Fast = iMA(m_config.symbol, m_config.timeframe, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
        m_handleEMA_Slow = iMA(m_config.symbol, m_config.timeframe, m_emaSlow, 0, MODE_EMA, PRICE_CLOSE);
        m_handleATR = iATR(m_config.symbol, m_config.timeframe, m_atrPeriod);
        
        // Indicators for BTC
        m_hBtcEmaFast = iMA(m_btcSymbol, m_config.timeframe, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
        m_hBtcEmaSlow = iMA(m_btcSymbol, m_config.timeframe, m_emaSlow, 0, MODE_EMA, PRICE_CLOSE);
        
        if(m_handleEMA_Fast == INVALID_HANDLE || m_handleEMA_Slow == INVALID_HANDLE || 
           m_handleATR == INVALID_HANDLE || m_hBtcEmaFast == INVALID_HANDLE || 
           m_hBtcEmaSlow == INVALID_HANDLE)
        {
            m_logger.Error("Failed to initialize indicators for cross-asset confirmation", m_moduleName);
            return false;
        }
        
        return true;
    }
    
    virtual void ProcessTick(MqlTick &tick) override
    {
        datetime currentBar = iTime(m_config.symbol, m_config.timeframe, 0);
        if(currentBar == m_lastBarTime) return;
        m_lastBarTime = currentBar;
        
        m_openPositions = CountOpenPositions();
        TradeSignal signal = GenerateSignal();
        
        if(signal.signalType != SIGNAL_NONE && ValidateSignal(signal))
        {
            m_lastSignal = signal;
            m_lastSignalTime = TimeCurrent();
            m_logger.Info(StringFormat("Signal: %s, Reason: %s", 
                SignalTypeToString(signal.signalType), signal.reason), m_moduleName);
        }
    }
    
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        if(m_openPositions > 0) return signal;
        
        // Get ETH data
        double ethEmaF[], ethEmaS[], ethAtr[];
        if(CopyBuffer(m_handleEMA_Fast, 0, 1, 1, ethEmaF) < 1 ||
           CopyBuffer(m_handleEMA_Slow, 0, 1, 1, ethEmaS) < 1 ||
           CopyBuffer(m_handleATR, 0, 1, 1, ethAtr) < 1) return signal;
           
        // Get BTC data
        double btcEmaF[], btcEmaS[];
        if(CopyBuffer(m_hBtcEmaFast, 0, 1, 1, btcEmaF) < 1 ||
           CopyBuffer(m_hBtcEmaSlow, 0, 1, 1, btcEmaS) < 1) return signal;
           
        double ethClose = iClose(m_config.symbol, m_config.timeframe, 1);
        double btcClose = iClose(m_btcSymbol, m_config.timeframe, 1);
        
        // ETH High/Low for breakout
        double ethHigh = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_lookback, 1));
        double ethLow = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_lookback, 1));
        
        // Long Conditions
        bool ethTrendLong = ethClose > ethEmaF[0] && ethEmaF[0] > ethEmaS[0];
        bool btcTrendLong = btcClose > btcEmaF[0] && btcEmaF[0] > btcEmaS[0];
        bool ethBreakLong = ethClose > (ethHigh + 0.3 * ethAtr[0]);
        
        if(ethTrendLong && btcTrendLong && ethBreakLong)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = 0.83;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
            signal.reason = "ETH-2: BTC-Aligned Trend Breakout";
            return signal;
        }
        
        // Short Conditions
        bool ethTrendShort = ethClose < ethEmaF[0] && ethEmaF[0] < ethEmaS[0];
        bool btcTrendShort = btcClose < btcEmaF[0] && btcEmaF[0] < btcEmaS[0];
        bool ethBreakShort = ethClose < (ethLow - 0.3 * ethAtr[0]);
        
        if(ethTrendShort && btcTrendShort && ethBreakShort)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = 0.83;
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
            signal.reason = "ETH-2: BTC-Aligned Trend Breakout";
            return signal;
        }
        
        return signal;
    }
    
    virtual bool ValidateSignal(TradeSignal &signal) override { return true; }
    
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.8);
    }
    
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 2.5);
    }
    
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Exit if BTC loses trend alignment
        if(!PositionSelectByTicket(ticket)) return false;
        
        double btcEmaF[], btcEmaS[];
        if(CopyBuffer(m_hBtcEmaFast, 0, 1, 1, btcEmaF) < 1 ||
           CopyBuffer(m_hBtcEmaSlow, 0, 1, 1, btcEmaS) < 1) return false;
           
        long type = PositionGetInteger(POSITION_TYPE);
        if(type == POSITION_TYPE_BUY && btcEmaF[0] < btcEmaS[0]) return true;
        if(type == POSITION_TYPE_SELL && btcEmaF[0] > btcEmaS[0]) return true;
        
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override { return false; }
};
//+------------------------------------------------------------------+
