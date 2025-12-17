//+------------------------------------------------------------------+
//|                                     EURUSD_Strategy1_EMA_RSI.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| EURUSD Strategy 1: EMA 20/50 Crossover with RSI Filter            |
//+------------------------------------------------------------------+
class CEURUSD_Strategy1_EMA_RSI : public CStrategyBase
{
private:
    // Strategy parameters
    int m_emaFastPeriod;
    int m_emaSlowPeriod;
    int m_emaTrendPeriod;
    int m_rsiPeriod;
    
    // Additional handles for MTF
    int m_handleEMA_Fast_4H;
    int m_handleEMA_Slow_4H;
    int m_handleEMA_Trend_Daily;
    
    // Buffers for MTF
    double m_emaFast_4H[];
    double m_emaSlow_4H[];
    double m_emaTrend_Daily[];
    
    // Market state
    datetime m_lastBarTime;

public:
    // Constructor
    CEURUSD_Strategy1_EMA_RSI(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("EURUSD_Strategy1_EMA_RSI", logger, riskManager)
    {
        m_emaFastPeriod = 20;
        m_emaSlowPeriod = 50;
        m_emaTrendPeriod = 200;
        m_rsiPeriod = 14;
        
        m_handleEMA_Fast_4H = INVALID_HANDLE;
        m_handleEMA_Slow_4H = INVALID_HANDLE;
        m_handleEMA_Trend_Daily = INVALID_HANDLE;
        
        ArraySetAsSeries(m_emaFast_4H, true);
        ArraySetAsSeries(m_emaSlow_4H, true);
        ArraySetAsSeries(m_emaTrend_Daily, true);
        
        m_lastBarTime = 0;
    }
    
    // Destructor
    ~CEURUSD_Strategy1_EMA_RSI()
    {
        if(m_handleEMA_Fast_4H != INVALID_HANDLE) IndicatorRelease(m_handleEMA_Fast_4H);
        if(m_handleEMA_Slow_4H != INVALID_HANDLE) IndicatorRelease(m_handleEMA_Slow_4H);
        if(m_handleEMA_Trend_Daily != INVALID_HANDLE) IndicatorRelease(m_handleEMA_Trend_Daily);
    }
    
    // Initialize
    virtual bool Initialize() override
    {
        // Default config
        if(m_config.symbol == "")
        {
            m_config.symbol = "EURUSD";
            m_config.timeframe = PERIOD_H1;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 1.0; 
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 101;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for EURUSD Strategy 1", m_moduleName);
        
        // 1H Indicators (Primary)
        m_handleEMA_Fast = CreateIndicator("EMA_Fast_1H", "MA", m_emaFastPeriod);
        m_handleEMA_Slow = CreateIndicator("EMA_Slow_1H", "MA", m_emaSlowPeriod);
        m_handleRSI = CreateIndicator("RSI_1H", "RSI", m_rsiPeriod);
        m_handleATR = CreateIndicator("ATR_1H", "ATR", 14);
        
        // 4H Indicators (Confirmation)
        m_handleEMA_Fast_4H = iMA(m_config.symbol, PERIOD_H4, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
        m_handleEMA_Slow_4H = iMA(m_config.symbol, PERIOD_H4, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
        
        // Daily Indicators (Trend Filter)
        m_handleEMA_Trend_Daily = iMA(m_config.symbol, PERIOD_D1, m_emaTrendPeriod, 0, MODE_EMA, PRICE_CLOSE);
        
        // Validate handles
        if(m_handleEMA_Fast == INVALID_HANDLE || m_handleEMA_Slow == INVALID_HANDLE ||
           m_handleRSI == INVALID_HANDLE || m_handleATR == INVALID_HANDLE ||
           m_handleEMA_Fast_4H == INVALID_HANDLE || m_handleEMA_Slow_4H == INVALID_HANDLE ||
           m_handleEMA_Trend_Daily == INVALID_HANDLE)
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
        // 1H EMA Cross
        bool emaCrossBullish = m_emaFast[0] > m_emaSlow[0]; 
        bool emaCrossBearish = m_emaFast[0] < m_emaSlow[0];
        
        // 4H EMA Cross
        bool emaCrossBullish_4H = m_emaFast_4H[0] > m_emaSlow_4H[0];
        bool emaCrossBearish_4H = m_emaFast_4H[0] < m_emaSlow_4H[0];
        
        // RSI Filter
        double rsi = m_rsi[0];
        bool rsiBullish = (rsi > 40 && rsi < 70);
        bool rsiBearish = (rsi > 30 && rsi < 60);
        
        // Daily Trend Filter
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 0);
        bool trendBullish = closePrice > m_emaTrend_Daily[0];
        bool trendBearish = closePrice < m_emaTrend_Daily[0];
        
        // Daily EMA Slope (Trend Filter - Critical)
        // EMA200[current] > EMA200[20 bars ago]
        bool dailySlopeBullish = m_emaTrend_Daily[0] > m_emaTrend_Daily[20];
        bool dailySlopeBearish = m_emaTrend_Daily[0] < m_emaTrend_Daily[20];

        // EMA 20 Slope (1H) - confirmation
        bool slopeBullish = m_emaFast[0] > m_emaFast[5];
        bool slopeBearish = m_emaFast[0] < m_emaFast[5];
        
        // Time Filter (12:00 - 16:00 GMT)
        MqlDateTime dt;
        TimeGMT(dt);
        bool timeFilter = (dt.hour >= 12 && dt.hour <= 16);
        
        // Volatility Filter (ATR > 15 pips)
        bool volatilityFilter = m_atr[0] > 0.0015; 
        
        // Long Entry
        if(emaCrossBullish && emaCrossBullish_4H && rsiBullish && trendBullish && 
           dailySlopeBullish && slopeBullish && timeFilter && volatilityFilter)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.8;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "EMA 20/50 Cross + RSI + Trend + Time";
             return signal;
        }
        
        // Short Entry
        if(emaCrossBearish && emaCrossBearish_4H && rsiBearish && trendBearish && 
           dailySlopeBearish && slopeBearish && timeFilter && volatilityFilter)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.8;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "EMA 20/50 Cross + RSI + Trend + Time";
             return signal;
        }
        
        return signal;
    }
    
    // Validate Signal
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE);
    }

    // Stop Loss (2 * ATR)
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
         stopLoss = CalculateATRStopLoss(entryPrice, orderType, 2.0);
    }
    
    // Take Profit (3 * ATR)
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
         takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 3.0);
    }
    
    // Position Management
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time Exit: 48 hours
        if(PositionSelectByTicket(ticket))
        {
            long timeOpen = PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - timeOpen > 48 * 3600) return true;
        }
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Implement trailing stop: Activate after 1.5x ATR profit
        if(!PositionSelectByTicket(ticket)) return false;
        
        double currentSL = PositionGetDouble(POSITION_SL);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        long type = PositionGetInteger(POSITION_TYPE);
        
        if(m_atr[0] == 0) return false;
        
        double atr = m_atr[0];
        double profitPips = 0;
        
        if(type == POSITION_TYPE_BUY)
        {
            profitPips = currentPrice - openPrice;
            if(profitPips > 1.5 * atr)
            {
                // Trail at 1x ATR below highest high (approximated by current price - 1ATR for now, 
                // typically we need to track highest high since entry)
                // Simplified: Trail at 1 ATR distance
                double proposedSL = currentPrice - 1.0 * atr;
                if(proposedSL > currentSL)
                {
                    newSL = proposedSL;
                    newTP = PositionGetDouble(POSITION_TP);
                    return true;
                }
            }
        }
        else if(type == POSITION_TYPE_SELL)
        {
            profitPips = openPrice - currentPrice;
            if(profitPips > 1.5 * atr)
            {
                double proposedSL = currentPrice + 1.0 * atr;
                if(proposedSL < currentSL || currentSL == 0)
                {
                    newSL = proposedSL;
                    newTP = PositionGetDouble(POSITION_TP);
                    return true;
                }
            }
        }
        
        return false;
    }

private:
    bool UpdateIndicators()
    {
        // Resize
        ArrayResize(m_emaFast, 10); 
        ArrayResize(m_emaSlow, 3);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_atr, 3);
        
        ArrayResize(m_emaFast_4H, 3);
        ArrayResize(m_emaSlow_4H, 3);
        ArrayResize(m_emaTrend_Daily, 30); // Need 20 bars ago
        
        // Copy
        if(CopyBuffer(m_handleEMA_Fast, 0, 0, 10, m_emaFast) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Slow, 0, 0, 3, m_emaSlow) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        if(CopyBuffer(m_handleEMA_Fast_4H, 0, 0, 3, m_emaFast_4H) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Slow_4H, 0, 0, 3, m_emaSlow_4H) <= 0) return false;
        if(CopyBuffer(m_handleEMA_Trend_Daily, 0, 0, 30, m_emaTrend_Daily) <= 0) return false;
        
        return true;
    }
};
