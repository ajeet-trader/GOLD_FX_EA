//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Interfaces/IModule.mqh>
#include <GoldFXEAProject/Utils/Logger.mqh>

//+------------------------------------------------------------------+
//| CRiskManager Class                                               |
//| Manages all risk-related calculations and limits                 |
//+------------------------------------------------------------------+
class CRiskManager : public IModule
{
private:
    CLogger* m_logger;
    
    // Risk parameters
    double m_riskPercentPerTrade;
    double m_maxDailyLoss;
    double m_maxDrawdown;
    int m_maxOpenTrades;
    
    // Current metrics
    RiskMetrics m_currentMetrics;
    double m_startingBalance;
    double m_peakBalance;
    double m_dailyStartBalance;
    datetime m_lastDailyReset;
    
    // Daily tracking
    double m_dailyProfit;
    double m_dailyLoss;
    
public:
    // Constructor
    CRiskManager(CLogger* logger) : IModule("RiskManager")
    {
        m_logger = logger;
        m_riskPercentPerTrade = 1.5;
        m_maxDailyLoss = 5.0;
        m_maxDrawdown = 20.0;
        m_maxOpenTrades = 10;
        m_startingBalance = 0.0;
        m_peakBalance = 0.0;
        m_dailyStartBalance = 0.0;
        m_lastDailyReset = 0;
        m_dailyProfit = 0.0;
        m_dailyLoss = 0.0;
    }
    
    // Destructor
    ~CRiskManager()
    {
        Deinitialize();
    }
    
    // Initialize risk manager
    virtual bool Initialize() override
    {
        m_logger.Info("Initializing Risk Manager", m_moduleName);
        
        m_status = MODULE_STATUS_INITIALIZING;
        
        // Get initial account metrics
        m_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_peakBalance = m_startingBalance;
        m_dailyStartBalance = m_startingBalance;
        m_lastDailyReset = TimeCurrent();
        
        UpdateRiskMetrics();
        
        m_logger.Info(StringFormat("Initial Balance: %.2f", m_startingBalance), m_moduleName);
        m_logger.Info(StringFormat("Risk Per Trade: %.2f%%", m_riskPercentPerTrade), m_moduleName);
        m_logger.Info(StringFormat("Max Daily Loss: %.2f%%", m_maxDailyLoss), m_moduleName);
        m_logger.Info(StringFormat("Max Drawdown: %.2f%%", m_maxDrawdown), m_moduleName);
        
        m_status = MODULE_STATUS_INITIALIZED;
        return true;
    }
    
    // Process tick
    virtual void ProcessTick(MqlTick &tick) override
    {
        // Update metrics on each tick
        UpdateRiskMetrics();
        
        // Check for daily reset
        CheckDailyReset();
    }
    
    // Deinitialize
    virtual void Deinitialize() override
    {
        if(m_status == MODULE_STATUS_UNINITIALIZED)
            return;
        
        m_logger.Info("Risk Manager shutting down", m_moduleName);
        m_status = MODULE_STATUS_STOPPED;
    }
    
    // Get module info
    virtual string GetModuleInfo() override
    {
        return StringFormat("RiskManager v1.0 - Risk: %.2f%% | Max DD: %.2f%%", 
                          m_riskPercentPerTrade, m_maxDrawdown);
    }
    
    // Configure risk parameters
    void SetRiskParameters(double riskPercent, double maxDailyLoss, 
                          double maxDrawdown, int maxOpenTrades)
    {
        m_riskPercentPerTrade = riskPercent;
        m_maxDailyLoss = maxDailyLoss;
        m_maxDrawdown = maxDrawdown;
        m_maxOpenTrades = maxOpenTrades;
        
        m_logger.Info("Risk parameters updated", m_moduleName);
    }
    
    // Calculate lot size based on risk
    double CalculateLotSize(string symbol, double stopLossPoints)
    {
        if(stopLossPoints <= 0)
        {
            m_logger.Warning("Invalid stop loss points", m_moduleName);
            return 0.0;
        }

        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * (m_riskPercentPerTrade / 100.0);

        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        // Ensure we have valid values
        if(tickValue <= 0 || tickSize <= 0 || point <= 0)
        {
            m_logger.Error("Invalid symbol information", m_moduleName);
            return 0.0;
        }

        double pointValue = tickValue * (point / tickSize);

        double lotSize = riskAmount / (stopLossPoints * pointValue);
        lotSize = NormalizeLotSize(symbol, lotSize);

        m_logger.Debug(StringFormat("Lot Calc: Risk=%.2f, SL=%.1f pts, TickVal=%.5f, Point=%.5f, Lots=%.2f",
                      riskAmount, stopLossPoints, tickValue, point, lotSize), m_moduleName);

        return lotSize;
    }
    
    // Calculate volatility-adjusted lot size (ATR-based)
    double CalculateVolatilityAdjustedLotSize(string symbol, double atrValue, double atrMultiplier = 2.0)
    {
        double stopLossPoints = atrValue * atrMultiplier / SymbolInfoDouble(symbol, SYMBOL_POINT);
        return CalculateLotSize(symbol, stopLossPoints);
    }
    
    // Check if new trade is allowed
    bool CanOpenNewTrade(string symbol, double lotSize, string &reason)
    {
        // Check max open trades
        if(m_currentMetrics.openPositions >= m_maxOpenTrades)
        {
            reason = "Maximum open trades limit reached";
            m_logger.Warning(reason, m_moduleName);
            return false;
        }
        
        // Check daily loss limit
        if(IsDailyLossLimitReached())
        {
            reason = "Daily loss limit reached";
            m_logger.Warning(reason, m_moduleName);
            return false;
        }
        
        // Check maximum drawdown
        if(IsMaxDrawdownReached())
        {
            reason = "Maximum drawdown limit reached";
            m_logger.Critical(reason, m_moduleName);
            return false;
        }
        
        // Check if symbol is valid and trading is allowed
        long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
        if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
        {
            reason = StringFormat("Trading not allowed for symbol (mode: %d)", tradeMode);
            m_logger.Warning(reason, m_moduleName);
            return false;
        }

        // Verify symbol exists and is selected in Market Watch
        if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
        {
            // Try to select it
            if(!SymbolSelect(symbol, true))
            {
                reason = "Symbol not found or cannot be selected";
                m_logger.Warning(reason, m_moduleName);
                return false;
            }
        }
        
        // Check margin requirements
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        double requiredMargin = 0.0;
        
        if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lotSize, 
                           SymbolInfoDouble(symbol, SYMBOL_ASK), requiredMargin))
        {
            reason = "Failed to calculate required margin";
            m_logger.Error(reason, m_moduleName);
            return false;
        }
        
        if(requiredMargin > freeMargin)
        {
            reason = StringFormat("Insufficient margin (Required: %.2f, Free: %.2f)", 
                                 requiredMargin, freeMargin);
            m_logger.Warning(reason, m_moduleName);
            return false;
        }
        
        reason = "Trade allowed";
        return true;
    }
    
    // Check if daily loss limit is reached
    bool IsDailyLossLimitReached()
    {
        double dailyLossLimit = m_dailyStartBalance * (m_maxDailyLoss / 100.0);
        return (m_dailyLoss >= dailyLossLimit);
    }
    
    // Check if maximum drawdown is reached
    bool IsMaxDrawdownReached()
    {
        return (m_currentMetrics.drawdownPercent >= m_maxDrawdown);
    }
    
    // Get current risk metrics
    RiskMetrics GetCurrentMetrics() { return m_currentMetrics; }
    
    // Get risk percentage per trade
    double GetRiskPercentPerTrade() { return m_riskPercentPerTrade; }
    
private:
    // Update risk metrics
    void UpdateRiskMetrics()
    {
        m_currentMetrics.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_currentMetrics.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        m_currentMetrics.usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
        m_currentMetrics.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        m_currentMetrics.marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
        
        // Update peak balance for drawdown calculation
        if(m_currentMetrics.accountBalance > m_peakBalance)
            m_peakBalance = m_currentMetrics.accountBalance;
        
        // Calculate drawdown
        double drawdown = m_peakBalance - m_currentMetrics.accountEquity;
        m_currentMetrics.drawdownPercent = (drawdown / m_peakBalance) * 100.0;
        
        // Calculate daily P&L
        m_currentMetrics.dailyPnL = m_currentMetrics.accountEquity - m_dailyStartBalance;
        
        // Count open positions
        m_currentMetrics.openPositions = PositionsTotal();
        
        // Calculate total exposure
        m_currentMetrics.totalExposure = CalculateTotalExposure();
    }
    
    // Calculate total exposure
    double CalculateTotalExposure()
    {
        double totalExposure = 0.0;
        
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
                double volume = PositionGetDouble(POSITION_VOLUME);
                string symbol = PositionGetString(POSITION_SYMBOL);
                double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
                
                totalExposure += volume * contractSize;
            }
        }
        
        return totalExposure;
    }
    
    // Check for daily reset
    void CheckDailyReset()
    {
        MqlDateTime current, last;
        TimeToStruct(TimeCurrent(), current);
        TimeToStruct(m_lastDailyReset, last);
        
        // Reset if new day
        if(current.day != last.day || current.mon != last.mon || current.year != last.year)
        {
            m_logger.Info("Daily metrics reset", m_moduleName);
            m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            m_dailyProfit = 0.0;
            m_dailyLoss = 0.0;
            m_lastDailyReset = TimeCurrent();
        }
    }
};
//+------------------------------------------------------------------+