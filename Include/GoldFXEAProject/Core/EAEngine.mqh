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
#include <GoldFXEAProject/Core/SymbolManager.mqh>
#include <GoldFXEAProject/Strategies/StrategyDispatcher.mqh>

// Include all strategies
#include <GoldFXEAProject/Strategies/Forex/EURUSD_Strategy1_EMA_RSI.mqh>
#include <GoldFXEAProject/Strategies/Forex/EURUSD_Strategy2_Bollinger_MeanReversion.mqh>
#include <GoldFXEAProject/Strategies/Forex/EURUSD_Strategy3_ADX_Trend.mqh>
#include <GoldFXEAProject/Strategies/Forex/GBPUSD_Strategy1_Fib_Pullback.mqh>
#include <GoldFXEAProject/Strategies/Forex/GBPUSD_Strategy2_RSI_MeanReversion.mqh>
#include <GoldFXEAProject/Strategies/Forex/GBPUSD_Strategy3_London_Breakout.mqh>
#include <GoldFXEAProject/Strategies/Forex/USDJPY_Strategy1_ADX_Trend.mqh>
#include <GoldFXEAProject/Strategies/Forex/USDJPY_Strategy2_Carry_Trade.mqh>

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
        Print("║             PHASE 2: Multi-Strategy Foundation             ║");
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
        Print("\n→ Registering Active Strategies...");
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
        
        Print("\n╔════════════════════════════════════════════════════════════╗");
        Print("║        GoldFXEA Core Engine Ready For Trading             ║");
        Print("╚════════════════════════════════════════════════════════════╝\n");
        
        return true;
    }
    
    // Register strategies
    bool RegisterStrategies()
    {
        m_logger.Info("Registering strategies based on configuration...", "EAEngine");
        
        int registeredCount = 0;
        
        // 1. EURUSD Strategies
        if(m_config.enableTrendFollowing)
        {
            // Strategy 1: EMA RSI
            CEURUSD_Strategy1_EMA_RSI* eurusd1 = new CEURUSD_Strategy1_EMA_RSI(m_logger, m_riskManager);
            StrategyConfig config1;
            config1.symbol = CSymbolManager::GetCorrectSymbol("EURUSD");
            config1.timeframe = PERIOD_H1;
            config1.strategyType = STRATEGY_TREND_FOLLOWING;
            config1.riskPercent = 1.0;
            config1.maxOpenTrades = 1;
            config1.enableTrading = true;
            config1.magicNumber = EA_MAGIC_NUMBER + 101;
            eurusd1.SetConfig(config1);
            if(m_strategyDispatcher.RegisterStrategy(eurusd1)) 
            {
                Print("    ✓ EURUSD Strategy 1 (EMA RSI) Active");
                registeredCount++;
            }
            else delete eurusd1;
            
            // Strategy 3: ADX Trend
            CEURUSD_Strategy3_ADX_Trend* eurusd3 = new CEURUSD_Strategy3_ADX_Trend(m_logger, m_riskManager);
            StrategyConfig config3;
            config3.symbol = CSymbolManager::GetCorrectSymbol("EURUSD");
            config3.timeframe = PERIOD_H1;
            config3.strategyType = STRATEGY_TREND_FOLLOWING;
            config3.riskPercent = 1.0;
            config3.maxOpenTrades = 1;
            config3.enableTrading = true;
            config3.magicNumber = EA_MAGIC_NUMBER + 103;
            eurusd3.SetConfig(config3);
            if(m_strategyDispatcher.RegisterStrategy(eurusd3)) 
            {
                Print("    ✓ EURUSD Strategy 3 (ADX Trend) Active");
                registeredCount++;
            }
            else delete eurusd3;
        }
        
        if(m_config.enableMeanReversion)
        {
            // Strategy 2: Bollinger Mean Reversion
            CEURUSD_Strategy2_Bollinger_MeanReversion* eurusd2 = new CEURUSD_Strategy2_Bollinger_MeanReversion(m_logger, m_riskManager);
            StrategyConfig config2;
            config2.symbol = CSymbolManager::GetCorrectSymbol("EURUSD");
            config2.timeframe = PERIOD_M30;
            config2.strategyType = STRATEGY_MEAN_REVERSION;
            config2.riskPercent = 1.5;
            config2.maxOpenTrades = 1;
            config2.enableTrading = true;
            config2.magicNumber = EA_MAGIC_NUMBER + 102;
            eurusd2.SetConfig(config2);
            if(m_strategyDispatcher.RegisterStrategy(eurusd2)) 
            {
                Print("    ✓ EURUSD Strategy 2 (Bollinger MeanRev) Active");
                registeredCount++;
            }
            else delete eurusd2;
        }
        
        // 2. GBPUSD Strategies
        if(m_config.enableTrendFollowing)
        {
             // Strategy 1: Fib Pullback
             CGBPUSD_Strategy1_Fib_Pullback* gbpusd1 = new CGBPUSD_Strategy1_Fib_Pullback(m_logger, m_riskManager);
             StrategyConfig configG1;
             configG1.symbol = CSymbolManager::GetCorrectSymbol("GBPUSD");
             configG1.timeframe = PERIOD_H4;
             configG1.strategyType = STRATEGY_TREND_FOLLOWING;
             configG1.riskPercent = 1.5;
             configG1.maxOpenTrades = 1;
             configG1.enableTrading = true;
             configG1.magicNumber = EA_MAGIC_NUMBER + 201;
             gbpusd1.SetConfig(configG1);
             if(m_strategyDispatcher.RegisterStrategy(gbpusd1)) 
             {
                 Print("    ✓ GBPUSD Strategy 1 (Fib Pullback) Active");
                 registeredCount++;
             }
             else delete gbpusd1;
        }
        
        if(m_config.enableMeanReversion)
        {
             // Strategy 2: RSI Mean Reversion
             CGBPUSD_Strategy2_RSI_MeanReversion* gbpusd2 = new CGBPUSD_Strategy2_RSI_MeanReversion(m_logger, m_riskManager);
             StrategyConfig configG2;
             configG2.symbol = CSymbolManager::GetCorrectSymbol("GBPUSD");
             configG2.timeframe = PERIOD_M30;
             configG2.strategyType = STRATEGY_MEAN_REVERSION;
             configG2.riskPercent = 1.5;
             configG2.maxOpenTrades = 1;
             configG2.enableTrading = true;
             configG2.magicNumber = EA_MAGIC_NUMBER + 202;
             gbpusd2.SetConfig(configG2);
             if(m_strategyDispatcher.RegisterStrategy(gbpusd2)) 
             {
                 Print("    ✓ GBPUSD Strategy 2 (RSI MeanRev) Active");
                 registeredCount++;
             }
             else delete gbpusd2;
        }
        
        if(m_config.enableBreakout)
        {
             // Strategy 3: London Breakout
             CGBPUSD_Strategy3_London_Breakout* gbpusd3 = new CGBPUSD_Strategy3_London_Breakout(m_logger, m_riskManager);
             StrategyConfig configG3;
             configG3.symbol = CSymbolManager::GetCorrectSymbol("GBPUSD");
             configG3.timeframe = PERIOD_M15;
             configG3.strategyType = STRATEGY_BREAKOUT;
             configG3.riskPercent = 1.0;
             configG3.maxOpenTrades = 1;
             configG3.enableTrading = true;
             configG3.magicNumber = EA_MAGIC_NUMBER + 203;
             gbpusd3.SetConfig(configG3);
             if(m_strategyDispatcher.RegisterStrategy(gbpusd3)) 
             {
                 Print("    ✓ GBPUSD Strategy 3 (London Breakout) Active");
                 registeredCount++;
             }
             else delete gbpusd3;
        }
        
        // 3. USDJPY Strategies
        if(m_config.enableTrendFollowing)
        {
            // Strategy 1: ADX Trend
            CUSDJPY_Strategy1_ADX_Trend* usdjpy1 = new CUSDJPY_Strategy1_ADX_Trend(m_logger, m_riskManager);
            StrategyConfig configJ1;
            configJ1.symbol = CSymbolManager::GetCorrectSymbol("USDJPY");
            configJ1.timeframe = PERIOD_H4;
            configJ1.strategyType = STRATEGY_TREND_FOLLOWING;
            configJ1.riskPercent = 1.5;
            configJ1.maxOpenTrades = 1;
            configJ1.enableTrading = true;
            configJ1.magicNumber = EA_MAGIC_NUMBER + 301;
            usdjpy1.SetConfig(configJ1);
            if(m_strategyDispatcher.RegisterStrategy(usdjpy1)) 
            {
                Print("    ✓ USDJPY Strategy 1 (ADX Trend) Active");
                registeredCount++;
            }
            else delete usdjpy1;
            
            // Strategy 2: Carry Trade
            CUSDJPY_Strategy2_Carry_Trade* usdjpy2 = new CUSDJPY_Strategy2_Carry_Trade(m_logger, m_riskManager);
            StrategyConfig configJ2;
            configJ2.symbol = CSymbolManager::GetCorrectSymbol("USDJPY");
            configJ2.timeframe = PERIOD_D1;
            configJ2.strategyType = STRATEGY_TREND_FOLLOWING; 
            configJ2.riskPercent = 2.0;
            configJ2.maxOpenTrades = 1;
            configJ2.enableTrading = true;
            configJ2.magicNumber = EA_MAGIC_NUMBER + 302;
            usdjpy2.SetConfig(configJ2);
            if(m_strategyDispatcher.RegisterStrategy(usdjpy2)) 
            {
                Print("    ✓ USDJPY Strategy 2 (Carry Trade) Active");
                registeredCount++;
            }
            else delete usdjpy2;
        }
        
         // 4. BTCUSD Momentum Strategy (Crypto)
         if(m_config.enableMeanReversion)  // Using this flag for crypto
         {
             Print("  → BTCUSD Momentum Strategy disabled (Pending implementation based on CRYPTO_Strategy_Audit.md)...");
             // Pending new implementation
         }
         
         // 4. XAUUSD Scalping Strategy (Gold)
         if(m_config.enableScalping)
         {
             Print("  → XAUUSD Scalping Strategy disabled (Pending implementation based on METALS_Strategy_Audit.md)...");
             // Pending new implementation
         }
         
         // 5. SP500 Mean Reversion Strategy (Indices)
         if(m_config.enableIndices)
         {
             Print("  → SP500 Mean Reversion Strategy disabled (Pending implementation based on INDICES_Strategy_Audit.md)...");
             // Pending new implementation
         }
        
        Print("");  // Blank line
        m_logger.Info(StringFormat("Strategy registration complete: %d strategies active", registeredCount), "EAEngine");
        Print(StringFormat("  Total Active Strategies: %d\n", registeredCount));
        
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
        
        // Periodic health check every 1000 ticks
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