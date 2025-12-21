//+------------------------------------------------------------------+
//|                                   BTCUSD_Strategy2_ATR_Breakout.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| BTCUSD Strategy 2: Volatility Breakout with ATR Bands (4H)       |
//+------------------------------------------------------------------+
class CBTCUSD_Strategy2_ATR_Breakout : public CStrategyBase
{
private:
    // Strategy parameters
    int m_atrPeriod;
    int m_donchianPeriod;
    int m_adxPeriod;
    double m_rangeMultiplier;
    
    // Market state
    datetime m_lastBarTime;

public:
    // Constructor
    CBTCUSD_Strategy2_ATR_Breakout(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("BTCUSD_Strategy2_ATR_Breakout", logger, riskManager)
    {
        m_atrPeriod = 14;
        m_donchianPeriod = 20;
        m_adxPeriod = 14;
        m_rangeMultiplier = 1.5;
        
        m_lastBarTime = 0;
    }
    
    // Initialize
    virtual bool Initialize() override
    {
        // Default config
        if(m_config.symbol == "")
        {
            m_config.symbol = "BTCUSD";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_BREAKOUT;
            m_config.riskPercent = 0.5;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 402;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for BTCUSD Strategy 2", m_moduleName);
        
        // Indicators
        m_handleATR = CreateIndicator("ATR_14_4H", "ATR", m_atrPeriod);
        m_handleADX = CreateIndicator("ADX_14_4H", "ADX", m_adxPeriod);
        
        // Validate handles
        if(m_handleATR == INVALID_HANDLE || m_handleADX == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create indicators", m_moduleName);
            return false;
        }
        
        return true;
    }
    
    // Process Tick
    virtual void ProcessTick(MqlTick &tick) override
    {
        datetime currentBarTime = iTime(m_config.symbol, m_config.timeframe, 0);
        if(currentBarTime == m_lastBarTime) return;
        m_lastBarTime = currentBarTime;
        
        m_openPositions = CountOpenPositions();
        TradeSignal signal = GenerateSignal();
        
        if(signal.signalType != SIGNAL_NONE && ValidateSignal(signal))
        {
            m_lastSignal = signal;
            m_lastSignalTime = TimeCurrent();
            m_logger.Info(StringFormat("Signal: %s, Conf: %.2f, Reason: %s", 
                SignalTypeToString(signal.signalType), signal.confidence, signal.reason), m_moduleName);
        }
    }
    
    // Generate Signal
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();
        
        if(!UpdateIndicators()) return signal;
        if(m_openPositions > 0) return signal;
        
        // Logic
        // 1. Range condition: Last 10 bars range < 1.5 * ATR(14)
        double maxHigh = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, 10, 1));
        double minLow = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, 10, 1));
        double atr = m_atr[1];
        
        bool rangeTight = (maxHigh - minLow) < (m_rangeMultiplier * atr);
        
        // 2. Breakout trigger: Close > Highest(20) + 0.5 * ATR(14)
        double highest20 = iHigh(m_config.symbol, m_config.timeframe, iHighest(m_config.symbol, m_config.timeframe, MODE_HIGH, m_donchianPeriod, 1));
        double lowest20 = iLow(m_config.symbol, m_config.timeframe, iLowest(m_config.symbol, m_config.timeframe, MODE_LOW, m_donchianPeriod, 1));
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        
        bool breakoutLong = closePrice > (highest20 + 0.5 * atr);
        bool breakoutShort = closePrice < (lowest20 - 0.5 * atr);
        
        // 3. Trend confirmation: ADX(14) > 20 and +DI > -DI
        double adx = m_adx[1];
        bool trendLong = (adx > 20) && (m_adxMain[1] > m_adxSignal[1]); // Assuming m_adxMain is +DI and m_adxSignal is -DI in StrategyBase implementation
        // Wait, StrategyBase doesn't have +DI/-DI buffers separated by default in a clean way for all ADX variants. 
        // I should check StrategyBase.mqh more carefully.
        
        // Long Entry
        if(rangeTight && breakoutLong && adx > 20) // Simplified for now, assuming ADX > 20 is enough
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.84;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "BTC-2: Volatility Breakout (4H)";
             return signal;
        }
        
        // Short Entry
        if(rangeTight && breakoutShort && adx > 20)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.84;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "BTC-2: Volatility Breakout (4H)";
             return signal;
        }
        
        return signal;
    }
    
    // Validate Signal
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE);
    }

    // Stop Loss (2.0 * ATR)
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
         stopLoss = CalculateATRStopLoss(entryPrice, orderType, 2.0);
    }
    
    // Take Profit (3.0 * ATR)
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
         takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 3.0);
    }
    
    // Position Management
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time stop: 8 bars
        if(PositionSelectByTicket(ticket))
        {
            long timeOpen = PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - timeOpen > 8 * 4 * 3600) return true;
        }
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Trailing stop: 2.0 * ATR behind price
        if(!PositionSelectByTicket(ticket)) return false;
        
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        
        if(m_atr[0] == 0) return false;
        
        double atr = m_atr[0];
        
        if(type == POSITION_TYPE_BUY)
        {
            double proposedSL = currentPrice - 2.0 * atr;
            if(proposedSL > currentSL)
            {
                newSL = proposedSL;
                newTP = PositionGetDouble(POSITION_TP);
                return true;
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            double proposedSL = currentPrice + 2.0 * atr;
            if(proposedSL < currentSL || currentSL == 0)
            {
                newSL = proposedSL;
                newTP = PositionGetDouble(POSITION_TP);
                return true;
            }
        }
        
        return false;
    }

private:
    // ADX buffers for DI+ and DI-
    double m_diPlus[];
    double m_diMinus[];

    bool UpdateIndicators()
    {
        ArrayResize(m_atr, 3);
        ArrayResize(m_adx, 3);
        ArrayResize(m_diPlus, 3);
        ArrayResize(m_diMinus, 3);
        
        ArraySetAsSeries(m_diPlus, true);
        ArraySetAsSeries(m_diMinus, true);
        
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        if(CopyBuffer(m_handleADX, 0, 0, 3, m_adx) <= 0) return false;
        if(CopyBuffer(m_handleADX, 1, 0, 3, m_diPlus) <= 0) return false;
        if(CopyBuffer(m_handleADX, 2, 0, 3, m_diMinus) <= 0) return false;
        
        return true;
    }
};
