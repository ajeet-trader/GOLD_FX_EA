//+------------------------------------------------------------------+
//|                                         StrategyDispatcher.mqh   |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Interfaces/IModule.mqh>
#include <GoldFXEAProject/Strategies/IStrategy.mqh>
#include <GoldFXEAProject/Utils/Logger.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>
#include <GoldFXEAProject/Core/TradeExecutor.mqh>

//+------------------------------------------------------------------+
//| CStrategyDispatcher Class                                         |
//| Manages multiple strategies and coordinates execution             |
//+------------------------------------------------------------------+
class CStrategyDispatcher : public IModule
{
private:
    CLogger* m_logger;
    CRiskManager* m_riskManager;
    CTradeExecutor* m_tradeExecutor;
    
    // Strategy management
    IStrategy* m_strategies[];
    int m_strategyCount;
    bool m_initialized;
    
    // Execution control
    bool m_enableTrading;
    datetime m_lastProcessTime;
    
public:
    // Constructor
    CStrategyDispatcher(CLogger* logger, CRiskManager* riskManager, CTradeExecutor* tradeExecutor) 
        : IModule("StrategyDispatcher")
    {
        m_logger = logger;
        m_riskManager = riskManager;
        m_tradeExecutor = tradeExecutor;
        m_strategyCount = 0;
        m_initialized = false;
        m_enableTrading = true;
        m_lastProcessTime = 0;
    }
    
    // Destructor
    ~CStrategyDispatcher()
    {
        Deinitialize();
    }
    
    // Initialize dispatcher
    virtual bool Initialize() override
    {
        m_logger.Info("Initializing Strategy Dispatcher", m_moduleName);
        
        m_status = MODULE_STATUS_INITIALIZING;
        m_initialized = true;
        m_status = MODULE_STATUS_INITIALIZED;
        
        return true;
    }
    
    // Register a strategy
    bool RegisterStrategy(IStrategy* strategy)
    {
        if(strategy == NULL)
        {
            m_logger.Error("Cannot register NULL strategy", m_moduleName);
            return false;
        }
        
        // Initialize the strategy
        if(!strategy.Initialize())
        {
            m_logger.Error("Failed to initialize strategy: " + strategy.GetModuleName(), m_moduleName);
            return false;
        }
        
        // Add to array
        int newSize = ArraySize(m_strategies) + 1;
        ArrayResize(m_strategies, newSize);
        m_strategies[newSize - 1] = strategy;
        m_strategyCount++;
        
        m_logger.Info(StringFormat("Strategy registered: %s (Total: %d)", 
                     strategy.GetModuleName(), m_strategyCount), m_moduleName);
        
        return true;
    }
    
    // Process tick for all strategies
    virtual void ProcessTick(MqlTick &tick) override
    {
        if(!m_initialized || !m_enableTrading)
            return;
        
        // Process each strategy
        for(int i = 0; i < m_strategyCount; i++)
        {
            if(m_strategies[i] == NULL)
                continue;
            
            // Let strategy process the tick
            m_strategies[i].ProcessTick(tick);
            
            // Check for signals and execute trades
            ProcessStrategySignals(m_strategies[i]);
            
            // Check for position management
            ManageStrategyPositions(m_strategies[i]);
        }
        
        m_lastProcessTime = TimeCurrent();
    }
    
    // Deinitialize
    virtual void Deinitialize() override
    {
        if(!m_initialized)
            return;
        
        m_logger.Info("Strategy Dispatcher shutting down", m_moduleName);
        
        // Deinitialize all strategies
        for(int i = 0; i < m_strategyCount; i++)
        {
            if(m_strategies[i] != NULL)
            {
                m_strategies[i].Deinitialize();
                delete m_strategies[i];
                m_strategies[i] = NULL;
            }
        }
        
        ArrayFree(m_strategies);
        m_strategyCount = 0;
        m_initialized = false;
        m_status = MODULE_STATUS_STOPPED;
    }
    
    // Get module info
    virtual string GetModuleInfo() override
    {
        return StringFormat("StrategyDispatcher - Managing %d strategies", m_strategyCount);
    }
    
    // Enable/disable trading
    void SetTradingEnabled(bool enabled)
    {
        m_enableTrading = enabled;
        m_logger.Info(StringFormat("Trading %s", enabled ? "ENABLED" : "DISABLED"), m_moduleName);
    }
    
    // Get strategy count
    int GetStrategyCount() { return m_strategyCount; }
    
    // Get strategy by index
    IStrategy* GetStrategy(int index)
    {
        if(index < 0 || index >= m_strategyCount)
            return NULL;
        
        return m_strategies[index];
    }
    
private:
    // Process strategy signals
    void ProcessStrategySignals(IStrategy* strategy)
    {
        if(strategy == NULL)
            return;
        
        TradeSignal signal = strategy.GetLastSignal();
        
        // Check if signal is recent (within last 5 seconds)
        if(TimeCurrent() - signal.timestamp > 5)
            return;
        
        // Skip if no signal
        if(signal.signalType == SIGNAL_NONE)
            return;
        
        // Execute the signal
        if(signal.signalType == SIGNAL_BUY || signal.signalType == SIGNAL_SELL)
        {
            ExecuteTradeSignal(strategy, signal);
        }
    }
    
    // Execute trade based on signal
    void ExecuteTradeSignal(IStrategy* strategy, TradeSignal &signal)
    {
        StrategyConfig config = strategy.GetConfig();
        
        // Prepare trade request
        TradeRequest request;
        request.symbol = config.symbol;
        request.orderType = (signal.signalType == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        request.price = signal.entryPrice;
        request.stopLoss = signal.stopLoss;
        request.takeProfit = signal.takeProfit;
        request.magicNumber = config.magicNumber;
        request.comment = StringFormat("%s Signal (Conf: %.2f)", 
                                       strategy.GetModuleName(), signal.confidence);
        
        // Calculate lot size
        double slPoints = MathAbs(signal.entryPrice - signal.stopLoss) / 
                         SymbolInfoDouble(config.symbol, SYMBOL_POINT);
        request.volume = m_riskManager.CalculateLotSize(config.symbol, slPoints);
        
        // Validate lot size
        if(request.volume <= 0)
        {
            m_logger.Error("Invalid lot size calculated", m_moduleName);
            return;
        }
        
        // Execute trade
        m_logger.Info(StringFormat("Executing %s signal for %s: %.2f lots @ %.5f [SL:%.5f TP:%.5f]",
                     SignalTypeToString(signal.signalType), config.symbol, 
                     request.volume, signal.entryPrice, signal.stopLoss, signal.takeProfit),
                     m_moduleName);
        
        TradeResult result = m_tradeExecutor.OpenTrade(request);
        
        if(result.success)
        {
            m_logger.Info(StringFormat("Trade executed successfully - Ticket: %llu", result.ticket), 
                         m_moduleName);
            
            // Notify strategy
            strategy.OnTradeOpened(result.ticket, result.executedPrice);
            strategy.SetOpenPositions(strategy.GetOpenPositions() + 1);
        }
        else
        {
            m_logger.Error(StringFormat("Trade execution failed: %s", result.message), m_moduleName);
        }
    }
    
    // Manage existing positions for strategy
    void ManageStrategyPositions(IStrategy* strategy)
    {
        if(strategy == NULL)
            return;
        
        StrategyConfig config = strategy.GetConfig();
        
        // Check each position
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0)
                continue;
            
            // Check if position belongs to this strategy
            long posMagic = PositionGetInteger(POSITION_MAGIC);
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            
            if(posMagic != config.magicNumber || posSymbol != config.symbol)
                continue;
            
            // Check if position should be closed
            if(strategy.ShouldClosePosition(ticket))
            {
                string errorMsg;
                if(m_tradeExecutor.ClosePosition(ticket, errorMsg))
                {
                    double exitPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    
                    strategy.OnTradeClosed(ticket, exitPrice, profit);
                    strategy.SetOpenPositions(strategy.GetOpenPositions() - 1);
                    
                    m_logger.Info(StringFormat("Position closed by strategy - Ticket: %llu, Profit: %.2f",
                                 ticket, profit), m_moduleName);
                }
            }
            
            // Check if position should be modified
            double newSL, newTP;
            if(strategy.ShouldModifyPosition(ticket, newSL, newTP))
            {
                string errorMsg;
                if(m_tradeExecutor.ModifyPosition(ticket, newSL, newTP, errorMsg))
                {
                    strategy.OnTradeModified(ticket, newSL, newTP);
                    m_logger.Info(StringFormat("Position modified by strategy - Ticket: %llu", ticket),
                                 m_moduleName);
                }
            }
        }
    }
};
//+------------------------------------------------------------------+