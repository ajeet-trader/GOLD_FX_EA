//+------------------------------------------------------------------+
//|                                                    EAEngine.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Common/Common.mqh>
#include <GoldFXEAProject/Utils/Logger.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>
#include <GoldFXEAProject/Core/TradeExecutor.mqh>
#include <GoldFXEAProject/Strategies/StrategyDispatcher.mqh>

// Include strategies
#include <GoldFXEAProject/Strategies/Forex/EURUSDTrendFollowing.mqh>

//+------------------------------------------------------------------+
//| CEAEngine Class                                                  |
//| Main orchestration engine for the entire EA                      |
//+------------------------------------------------------------------+
class CEAEngine
{
private:
    // Core modules
    CLogger* m_logger;
    CRiskManager* m_riskManager;
    CTradeExecutor* m_tradeExecutor;
    CStrategyDispatcher* m_strategyDispatcher;
    
    // Configuration
    EAConfig m_config;
    
    // State
    bool m_initialized;
    datetime m_lastTickTime;
    ulong m_tickCount;
    
    // Performance tracking
    ulong m_onTickStartTime;
    double m_avgOnTickTime;
    
public:
    // Constructor
    CEAEngine()
    {
        m_logger = NULL;
        m_riskManager = NULL;
        m_tradeExecutor = NULL;
        m_strategyDispatcher = NULL;
        m_initialized = false;
        m_lastTickTime = 0;
        m_tickCount = 0;
        m_avgOnTickTime = 0.0;
    }
    
    // Destructor
    ~CEAEngine()
    {
        Deinitialize();
    }
    
    // Initialize EA engine
    bool Initialize(EAConfig &config)
    {
        Print("╔════════════════════════════════════════════════════════════╗");
        Print("║          Initializing GoldFXEA Core Engine                ║");
        Print("║                    PHASE 2: Strategies                     ║");
        Print("╚════════════════════════════════════════════════════════════╝");
        
        m_config = config;
        
        // Step 1: Initialize Logger
        Print("→ Step 1/4: Initializing Logger...");
        m_logger = new CLogger(config.logLevel, config.enableLogging, true);
        
        if(m_logger == NULL)
        {
            Print("✗ CRITICAL: Failed to create Logger instance");
            return false;
        }
        
        if(!m_logger.Initialize())
        {
            Print("✗ CRITICAL: Failed to initialize Logger");
            delete m_logger;
            m_logger = NULL;
            return false;
        }
        
        m_logger.Info("Logger initialized successfully", "EAEngine");
        Print("✓ Logger initialized");
        
        // Step 2: Initialize Risk Manager
        Print("→ Step 2/4: Initializing Risk Manager...");
        m_riskManager = new CRiskManager(m_logger);
        
        if(m_riskManager == NULL)
        {
            m_logger.Critical("Failed to create RiskManager instance", "EAEngine");
            return false;
        }
        
        m_riskManager.SetRiskParameters(config.riskPercentPerTrade, 
                                       config.maxDailyLoss,
                                       config.maxDrawdown,
                                       config.maxOpenTrades);
        
        if(!m_riskManager.Initialize())
        {
            m_logger.Critical("Failed to initialize RiskManager", "EAEngine");
            return false;
        }
        
        m_logger.Info("Risk Manager initialized successfully", "EAEngine");
        Print("✓ Risk Manager initialized");
        
        // Step 3: Initialize Trade Executor
        Print("→ Step 3/4: Initializing Trade Executor...");
        m_tradeExecutor = new CTradeExecutor(m_logger, m_riskManager);
        
        if(m_tradeExecutor == NULL)
        {
            m_logger.Critical("Failed to create TradeExecutor instance", "EAEngine");
            return false;
        }
        
        m_tradeExecutor.SetTradingEnabled(config.enableTrading);
        
        if(!m_tradeExecutor.Initialize())
        {
            m_logger.Critical("Failed to initialize TradeExecutor", "EAEngine");
            return false;
        }
        
        m_logger.Info("Trade Executor initialized successfully", "EAEngine");
        Print("✓ Trade Executor initialized");
        
        // Step 4: Initialize Strategy Dispatcher
        Print("→ Step 4/4: Initializing Strategy Dispatcher...");
        m_strategyDispatcher = new CStrategyDispatcher(m_logger, m_riskManager, m_tradeExecutor);
        
        if(m_strategyDispatcher == NULL)
        {
            m_logger.Critical("Failed to create StrategyDispatcher instance", "EAEngine");
            return false;
        }
        
        if(!m_strategyDispatcher.Initialize())
        {
            m_logger.Critical("Failed to initialize StrategyDispatcher", "EAEngine");
            return false;
        }
        
        m_logger.Info("Strategy Dispatcher initialized successfully", "EAEngine");
        Print("✓ Strategy Dispatcher initialized");
        
        // Register strategies based on config
        if(!RegisterStrategies())
        {
            m_logger.Critical("Failed to register strategies", "EAEngine");
            return false;
        }
        
        // Initialization complete
        m_initialized = true;
        m_lastTickTime = TimeCurrent();
        
        m_logger.Info("═══════════════════════════════════════════════════", "EAEngine");
        m_logger.Info("GoldFXEA Core Engine Initialized Successfully", "EAEngine");
        m_logger.Info("═══════════════════════════════════════════════════", "EAEngine");
        m_logger.Info(StringFormat("Account: %lld | Balance: %.2f | Leverage: 1:%d",
                     AccountInfoInteger(ACCOUNT_LOGIN),
                     AccountInfoDouble(ACCOUNT_BALANCE),
                     (int)AccountInfoInteger(ACCOUNT_LEVERAGE)), "EAEngine");
        m_logger.Info(StringFormat("Active Strategies: %d", 
                     m_strategyDispatcher.GetStrategyCount()), "EAEngine");
        m_logger.Info("═══════════════════════════════════════════════════", "EAEngine");
        
        Print("╔════════════════════════════════════════════════════════════╗");
        Print("║        GoldFXEA Core Engine Ready For Trading             ║");
        Print("╚════════════════════════════════════════════════════════════╝");
        
        return true;
    }
    
    // Register strategies
    bool RegisterStrategies()
    {
        m_logger.Info("Registering strategies...", "EAEngine");
        
        int registeredCount = 0;
        
        // EURUSD Trend-Following Strategy
        if(m_config.enableTrendFollowing)
        {
            CEURUSDTrendFollowing* eurusdStrategy = new CEURUSDTrendFollowing(m_logger, m_riskManager);
            
            StrategyConfig strategyConfig;
            strategyConfig.symbol = "EURUSD";
            strategyConfig.timeframe = PERIOD_H1;
            strategyConfig.strategyType = STRATEGY_TREND_FOLLOWING;
            strategyConfig.riskPercent = 1.5;
            strategyConfig.maxOpenTrades = 1;
            strategyConfig.enableTrading = true;
            strategyConfig.magicNumber = EA_MAGIC_NUMBER + 1;
            
            eurusdStrategy.SetConfig(strategyConfig);
            
            if(m_strategyDispatcher.RegisterStrategy(eurusdStrategy))
            {
                m_logger.Info("EURUSD Trend-Following strategy registered", "EAEngine");
                registeredCount++;
            }
            else
            {
                m_logger.Error("Failed to register EURUSD Trend-Following strategy", "EAEngine");
                delete eurusdStrategy;
            }
        }
        
        // Add more strategies here as they are implemented
        // Example:
        // if(m_config.enableBreakout) { ... }
        // if(m_config.enableScalping) { ... }
        
        m_logger.Info(StringFormat("Strategy registration complete: %d strategies active", registeredCount), "EAEngine");
        
        return (registeredCount > 0);
    }
    
    // Process tick event
    void OnTick(MqlTick &tick)
    {
        if(!m_initialized)
            return;

        // Start performance tracking
        m_onTickStartTime = GetMicrosecondCount();

        // Increment tick counter
        m_tickCount++;
        m_lastTickTime = tick.time;

        // Process tick in risk manager
        if(m_riskManager != NULL && m_riskManager.IsInitialized())
        {
            m_riskManager.ProcessTick(tick);
        }

        // Process tick in strategy dispatcher
        if(m_strategyDispatcher != NULL && m_strategyDispatcher.IsInitialized())
        {
            m_strategyDispatcher.ProcessTick(tick);
        }

        // Track performance
        TrackPerformance();
    }
    
    // Process trade event
    void OnTrade()
    {
        if(!m_initialized)
            return;
        
        m_logger.Debug("Trade event detected", "EAEngine");
        
        // Update risk metrics after trade
        MqlTick tick;
        if(SymbolInfoTick(_Symbol, tick))
        {
            m_riskManager.ProcessTick(tick);
        }
    }
    
    // Process timer event
    void OnTimer()
    {
        if(!m_initialized)
            return;
        
        m_logger.Debug("Timer event", "EAEngine");
        
        // Periodic health check
        if(m_tickCount % 1000 == 0)
        {
            m_logger.Info(StringFormat("Health Check - Ticks: %llu, AvgTime: %.3f ms, Strategies: %d",
                         m_tickCount, m_avgOnTickTime, 
                         m_strategyDispatcher.GetStrategyCount()), "EAEngine");
        }
    }
    
    // Deinitialize EA engine
    void Deinitialize()
    {
        if(!m_initialized)
            return;
        
        m_logger.Info("═══════════════════════════════════════════════════", "EAEngine");
        m_logger.Info("GoldFXEA Core Engine Shutting Down", "EAEngine");
        m_logger.Info("═══════════════════════════════════════════════════", "EAEngine");
        
        // Log final statistics
        m_logger.Info(StringFormat("Total Ticks Processed: %llu", m_tickCount), "EAEngine");
        m_logger.Info(StringFormat("Avg OnTick Time: %.3f ms", m_avgOnTickTime), "EAEngine");
        
        // Cleanup modules in reverse order
        if(m_strategyDispatcher != NULL)
        {
            m_strategyDispatcher.Deinitialize();
            delete m_strategyDispatcher;
            m_strategyDispatcher = NULL;
        }
        
        if(m_tradeExecutor != NULL)
        {
            m_tradeExecutor.Deinitialize();
            delete m_tradeExecutor;
            m_tradeExecutor = NULL;
        }
        
        if(m_riskManager != NULL)
        {
            m_riskManager.Deinitialize();
            delete m_riskManager;
            m_riskManager = NULL;
        }
        
        if(m_logger != NULL)
        {
            m_logger.Deinitialize();
            delete m_logger;
            m_logger = NULL;
        }
        
        m_initialized = false;
        
        Print("╔════════════════════════════════════════════════════════════╗");
        Print("║        GoldFXEA Core Engine Shutdown Complete             ║");
        Print("╚════════════════════════════════════════════════════════════╝");
    }
    
    // Get initialization status
    bool IsInitialized() const { return m_initialized; }
    
    // Get tick count
    ulong GetTickCount() const { return m_tickCount; }
    
    // Get average OnTick time
    double GetAvgOnTickTime() const { return m_avgOnTickTime; }
    
private:
    // Track performance
    void TrackPerformance()
    {
        ulong endTime = GetMicrosecondCount();
        double executionTime = (endTime - m_onTickStartTime) / 1000.0; // ms
        
        // Calculate moving average
        m_avgOnTickTime = (m_avgOnTickTime * (m_tickCount - 1) + executionTime) / m_tickCount;
        
        // Warn if OnTick is slow
        if(executionTime > ONTICK_MAX_TIME_MS)
        {
            m_logger.Warning(StringFormat("Slow OnTick: %.3f ms (Threshold: %d ms)", 
                           executionTime, ONTICK_MAX_TIME_MS), "EAEngine");
        }
    }
};
//+------------------------------------------------------------------+