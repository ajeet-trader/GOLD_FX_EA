//+------------------------------------------------------------------+
//|                                     SP500MeanReversion.mqh     |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Strategies/StrategyBase.mqh>

//+------------------------------------------------------------------+
//| SP500 H1 Mean Reversion Strategy                                  |
//| Uses: Bollinger Bands (20,2) + RSI (14)                         |
//+------------------------------------------------------------------+
class CSP500MeanReversion : public CStrategyBase
{
private:
    // Strategy parameters
    int m_bbPeriod;
    double m_bbDeviation;
    int m_rsiPeriod;
    double m_rsiOverbought;
    double m_rsiOversold;
    double m_atrMultiplierSL;
    double m_atrMultiplierTP;
    int m_minBarsSinceSignal;

    // Market state
    datetime m_lastBarTime;

public:
    // Constructor
    CSP500MeanReversion(CLogger* logger, CRiskManager* riskManager)
        : CStrategyBase("SP500_MeanReversion", logger, riskManager)
    {
        // Default parameters
        m_bbPeriod = 20;
        m_bbDeviation = 2.0;
        m_rsiPeriod = 14;
        m_rsiOverbought = 70.0;
        m_rsiOversold = 30.0;
        m_atrMultiplierSL = 2.0;
        m_atrMultiplierTP = 4.0;
        m_minBarsSinceSignal = 2;
        m_lastBarTime = 0;
    }

    // Initialize strategy
    virtual bool Initialize() override
    {
        // Set default config if not set
        if(m_config.symbol == "")
        {
            m_config.symbol = "SP500";
            m_config.timeframe = PERIOD_H1;
            m_config.strategyType = STRATEGY_MEAN_REVERSION;
            m_config.riskPercent = 1.0;
            m_config.maxOpenTrades = 1;
            m_config.magicNumber = EA_MAGIC_NUMBER + 5; // New magic number
        }

        // Call base initialization
        if(!CStrategyBase::Initialize())
            return false;

        m_logger.Info("Creating indicators for SP500 Mean Reversion", m_moduleName);

        // Create indicators
        m_handleBB = CreateIndicator("Bollinger Bands", "BANDS", m_bbPeriod);
        m_handleRSI = CreateIndicator("RSI", "RSI", m_rsiPeriod);
        m_handleATR = CreateIndicator("ATR", "ATR", 14);

        // Validate indicators
        if(m_handleBB == INVALID_HANDLE || m_handleRSI == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
        {
            m_logger.Error("Failed to create required indicators", m_moduleName);
            return false;
        }

        // Wait for indicator data
        if(!WaitForIndicatorData(m_handleBB, m_bbPeriod + 10) ||
           !WaitForIndicatorData(m_handleRSI, m_rsiPeriod + 10) ||
           !WaitForIndicatorData(m_handleATR, 14 + 10))
        {
            m_logger.Error("Timeout waiting for indicator data", m_moduleName);
            return false;
        }

        m_logger.Info("SP500 Mean Reversion strategy ready", m_moduleName);
        m_status = MODULE_STATUS_RUNNING;
        return true;
    }

    // Process tick
    virtual void ProcessTick(MqlTick &tick) override
    {
        // Check if new bar
        datetime currentBarTime = iTime(m_config.symbol, m_config.timeframe, 0);
        if(currentBarTime == m_lastBarTime)
            return;

        m_lastBarTime = currentBarTime;

        // Update open positions count
        m_openPositions = CountOpenPositions();

        // Generate and process signal
        TradeSignal signal = GenerateSignal();

        if(signal.signalType != SIGNAL_NONE && ValidateSignal(signal))
        {
            m_lastSignal = signal;
            m_lastSignalTime = TimeCurrent();

            m_logger.Info(StringFormat("New %s signal generated: Confidence=%.2f, Reason=%s",
                         SignalTypeToString(signal.signalType), signal.confidence, signal.reason),
                         m_moduleName);
        }
    }

    // Generate trading signal
    virtual TradeSignal GenerateSignal() override
    {
        TradeSignal signal;
        signal.timestamp = TimeCurrent();

        // Update indicator values
        if(!UpdateIndicators())
        {
            m_logger.Debug("Failed to update indicators", m_moduleName);
            return signal;
        }

        // Check if already in trade
        if(m_openPositions > 0)
        {
            signal.signalType = SIGNAL_NONE;
            return signal;
        }

        // Get current values
        double bbUpper = m_bbUpper[0];
        double bbLower = m_bbLower[0];
        double rsiCurrent = m_rsi[0];

        // Get current price
        MqlRates rates[];
        if(CopyRates(m_config.symbol, m_config.timeframe, 0, 1, rates) <= 0)
            return signal;
        double currentPrice = rates[0].close;

        // Check for buy signal (price at lower BB and RSI oversold)
        if(currentPrice <= bbLower && rsiCurrent < m_rsiOversold)
        {
            signal.signalType = SIGNAL_BUY;
            signal.confidence = CalculateConfidence(true, rsiCurrent);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_BUY);

            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_BUY, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_BUY, signal.takeProfit);

            signal.reason = StringFormat("Mean Reversion Buy: Price at Lower BB and RSI=%.1f", rsiCurrent);
            return signal;
        }

        // Check for sell signal (price at upper BB and RSI overbought)
        if(currentPrice >= bbUpper && rsiCurrent > m_rsiOverbought)
        {
            signal.signalType = SIGNAL_SELL;
            signal.confidence = CalculateConfidence(false, rsiCurrent);
            signal.entryPrice = GetCurrentPrice(ORDER_TYPE_SELL);

            CalculateStopLoss(signal.entryPrice, ORDER_TYPE_SELL, signal.stopLoss);
            CalculateTakeProfit(signal.entryPrice, ORDER_TYPE_SELL, signal.takeProfit);

            signal.reason = StringFormat("Mean Reversion Sell: Price at Upper BB and RSI=%.1f", rsiCurrent);
            return signal;
        }

        signal.signalType = SIGNAL_NONE;
        return signal;
    }

    // Validate signal
    virtual bool ValidateSignal(TradeSignal &signal) override
    {
        if(signal.signalType == SIGNAL_NONE)
            return false;

        if(signal.confidence < 0.60)
        {
            m_logger.Debug(StringFormat("Signal confidence too low: %.2f", signal.confidence), m_moduleName);
            return false;
        }

        if(!IsTradingAllowed())
        {
            m_logger.Debug("Trading not allowed currently", m_moduleName);
            return false;
        }
        
        if(m_lastSignalTime > 0)
        {
            int barsSinceSignal = Bars(m_config.symbol, m_config.timeframe, m_lastSignalTime, TimeCurrent());
            if(barsSinceSignal < m_minBarsSinceSignal)
            {
                m_logger.Debug(StringFormat("Too soon since last signal (%d bars)", barsSinceSignal), m_moduleName);
                return false;
            }
        }

        return true;
    }

    // Calculate stop loss
    virtual void CalculateStopLoss(double entryPrice, ENUM_ORDER_TYPE orderType, double &stopLoss) override
    {
        stopLoss = CalculateATRStopLoss(entryPrice, orderType, m_atrMultiplierSL);
    }

    // Calculate take profit
    virtual void CalculateTakeProfit(double entryPrice, ENUM_ORDER_TYPE orderType, double &takeProfit) override
    {
        takeProfit = CalculateATRTakeProfit(entryPrice, orderType, m_atrMultiplierTP);
    }

    // Should close position
    virtual bool ShouldClosePosition(ulong ticket) override
    {
        if(!PositionSelectByTicket(ticket))
            return false;

        if(!UpdateIndicators())
            return false;

        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double bbMiddle = m_bbMiddle[0];

        MqlTick tick;
        if(!SymbolInfoTick(m_config.symbol, tick))
            return false;

        double currentPrice = (tick.ask + tick.bid) / 2.0;

        // Close when price returns to the mean (middle BB)
        if(posType == POSITION_TYPE_BUY)
        {
            if(currentPrice >= bbMiddle)
            {
                m_logger.Info("Closing BUY position - Price returned to mean", m_moduleName);
                return true;
            }
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            if(currentPrice <= bbMiddle)
            {
                m_logger.Info("Closing SELL position - Price returned to mean", m_moduleName);
                return true;
            }
        }

        return false;
    }

    // Should modify position
    virtual bool ShouldModifyPosition(ulong ticket, double &newSL, double &newTP) override
    {
        return false;
    }

    // Get market condition
    virtual string GetMarketCondition() override
    {
        if(!UpdateIndicators())
            return "UNKNOWN";

        double rsiCurrent = m_rsi[0];
        if(rsiCurrent > m_rsiOverbought) return "OVERBOUGHT";
        if(rsiCurrent < m_rsiOversold) return "OVERSOLD";
        return "NEUTRAL";
    }

private:
    // Update all indicators
    bool UpdateIndicators()
    {
        ArrayResize(m_bbUpper, 3);
        ArrayResize(m_bbMiddle, 3);
        ArrayResize(m_bbLower, 3);
        ArrayResize(m_rsi, 3);
        ArrayResize(m_atr, 3);

        if(CopyBuffer(m_handleBB, 1, 0, 3, m_bbUpper) <= 0) return false;
        if(CopyBuffer(m_handleBB, 0, 0, 3, m_bbMiddle) <= 0) return false;
        if(CopyBuffer(m_handleBB, 2, 0, 3, m_bbLower) <= 0) return false;
        if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi) <= 0) return false;
        if(CopyBuffer(m_handleATR, 0, 0, 3, m_atr) <= 0) return false;

        return true;
    }

    // Calculate signal confidence
    double CalculateConfidence(bool isBullish, double rsi)
    {
        double confidence = 0.6; // Base confidence for mean reversion

        // RSI extremity component (max +0.40)
        if(isBullish)
        {
            if(rsi < 20) confidence += 0.40;
            else if(rsi < 30) confidence += 0.20;
        }
        else
        {
            if(rsi > 80) confidence += 0.40;
            else if(rsi > 70) confidence += 0.20;
        }

        return MathMin(confidence, 1.0);
    }
    
    // Deinitialize
    virtual void Deinitialize() override
    {
        CStrategyBase::Deinitialize();
    }
};
//+------------------------------------------------------------------+
