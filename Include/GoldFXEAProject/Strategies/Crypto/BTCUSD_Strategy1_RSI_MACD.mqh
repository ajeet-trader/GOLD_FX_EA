//+------------------------------------------------------------------+
//|                                     BTCUSD_Strategy1_RSI_MACD.mqh |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| BTCUSD Strategy 1: RSI + MACD Swing Strategy (4H)                |
//+------------------------------------------------------------------+
class CBTCUSD_Strategy1_RSI_MACD : public CStrategyBase
{
private:
    // Strategy parameters
    int m_rsiPeriod;
    int m_macdFast;
    int m_macdSlow;
    int m_macdSignal;
    int m_emaTrendPeriod;
    int m_atrPeriod;
    
    // Market state
    datetime m_lastBarTime;

public:
    // Constructor
    CBTCUSD_Strategy1_RSI_MACD(CLogger* logger, CRiskManager* riskManager) 
        : CStrategyBase("BTCUSD_Strategy1_RSI_MACD", logger, riskManager)
    {
        m_rsiPeriod = 14;
        m_macdFast = 12;
        m_macdSlow = 26;
        m_macdSignal = 9;
        m_emaTrendPeriod = 50;
        m_atrPeriod = 14;
        
        m_lastBarTime = 0;
    }
    
    // Destructor
    ~CBTCUSD_Strategy1_RSI_MACD()
    {
    }
    
    // Initialize
    virtual bool Initialize() override
    {
        // Default config
        if(m_config.symbol == "")
        {
            m_config.symbol = "BTCUSD";
            m_config.timeframe = PERIOD_H4;
            m_config.strategyType = STRATEGY_TREND_FOLLOWING;
            m_config.riskPercent = 0.5; // Lower risk for crypto
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 401;
        }
        
        if(!CStrategyBase::Initialize()) return false;
        
        m_logger.Info("Creating indicators for BTCUSD Strategy 1", m_moduleName);
        
        // Indicators
        m_handleEMA_Slow = CreateIndicator("EMA_50_4H", "MA", m_emaTrendPeriod);
        m_handleRSI = CreateIndicator("RSI_14_4H", "RSI", m_rsiPeriod);
        m_handleMACD = CreateIndicator("MACD_12_26_9_4H", "MACD", m_macdFast, m_macdSlow, m_macdSignal);
        m_handleATR = CreateIndicator("ATR_14_4H", "ATR", m_atrPeriod);
        
        // Validate handles
        if(m_handleEMA_Slow == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE ||
           m_handleMACD == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
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
        double closePrice = iClose(m_config.symbol, m_config.timeframe, 1);
        double ema50 = m_emaSlow[1];
        double rsi = m_rsi[1];
        double macdHist0 = m_macdMain[1] - m_macdSignal[1];
        double macdHist1 = m_macdMain[2] - m_macdSignal[2];
        
        // Trend filter: Close > EMA(50) and EMA(50) sloping up
        bool trendBullish = (closePrice > ema50) && (m_emaSlow[1] > m_emaSlow[6]);
        bool trendBearish = (closePrice < ema50) && (m_emaSlow[1] < m_emaSlow[6]);
        
        // Pullback / exhaustion: RSI(14) crosses up from below 40
        bool rsiBullish = (m_rsi[1] > 40 && m_rsi[2] <= 40);
        bool rsiBearish = (m_rsi[1] < 60 && m_rsi[2] >= 60);
        
        // Momentum resumption: MACD histogram turns upward
        bool macdBullish = (m_macdMain[1] < 0) && (macdHist0 > macdHist1);
        bool macdBearish = (m_macdMain[1] > 0) && (macdHist0 < macdHist1);
        
        // Session filter (08:00 - 22:00 UTC)
        MqlDateTime dt;
        TimeGMT(dt);
        bool timeFilter = (dt.hour >= 8 && dt.hour <= 22);
        
        // Long Entry
        if(trendBullish && rsiBullish && macdBullish && timeFilter)
        {
             signal.signalType = SIGNAL_BUY;
             signal.confidence = 0.88;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);
             signal.reason = "BTC-1: RSI + MACD + Trend (4H)";
             return signal;
        }
        
        // Short Entry
        if(trendBearish && rsiBearish && macdBearish && timeFilter)
        {
             signal.signalType = SIGNAL_SELL;
             signal.confidence = 0.88;
             signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);
             CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
             CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);
             signal.reason = "BTC-1: RSI + MACD + Trend (4H)";
             return signal;
        }
        
        return signal;
    }
    
    // Validate Signal
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        return (signal.signalType != SIGNAL_NONE);
    }

    // Stop Loss (1.5 * ATR)
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
         stopLoss = CalculateATRStopLoss(entryPrice, orderType, 1.5);
    }
    
    // Take Profit 1 (1.5 * ATR)
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
         takeProfit = CalculateATRTakeProfit(entryPrice, orderType, 1.5);
    }
    
    // Position Management
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        // Time stop: 10 bars (40 hours)
        if(PositionSelectByTicket(ticket))
        {
            long timeOpen = PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - timeOpen > 10 * 4 * 3600) return true;
        }
        return false;
    }
    
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        // Trailing stop: 1.0 * ATR behind price after 1.5 * ATR profit
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
        ArrayResize(m_emaSlow, 10);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_macdMain, 3);
        ArrayResize(m_macdSignal, 3);
        ArrayResize(m_atr, 3);
        
        // Copy
        if(CopyBuffer(m_handleEMA_Slow, 0, 0, 10, m_emaSlow) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 0, 0, 3, m_macdMain) <= 0) return false;
        if(CopyBuffer(m_handleMACD, 1, 0, 3, m_macdSignal) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;
        
        return true;
    }
};
