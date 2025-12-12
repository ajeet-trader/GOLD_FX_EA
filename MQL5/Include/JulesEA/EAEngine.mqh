//+------------------------------------------------------------------+
//|                                                     EAEngine.mqh |
//|                                  Copyright 2025, Jules Assistant |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Assistant"
#property link      "https://yourwebsite.com"
#property strict

#ifndef JULESEA_EAENGINE_MQH
#define JULESEA_EAENGINE_MQH

#include "Logger.mqh"
#include "IndicatorManager.mqh"
#include "RiskManager.mqh"
#include "TradeExecutor.mqh"
#include "StrategyDispatcher.mqh"

class CEAEngine
{
private:
    CStrategyDispatcher* m_strategyDispatcher;
    CTradeExecutor* m_tradeExecutor;
    CRiskManager* m_riskManager;
    CIndicatorManager* m_indicatorManager;
    CLogger* m_logger;
    bool m_initialized;

public:
    CEAEngine() : m_strategyDispatcher(NULL),
                  m_tradeExecutor(NULL),
                  m_riskManager(NULL),
                  m_indicatorManager(NULL),
                  m_logger(NULL),
                  m_initialized(false)
    {
    }

    ~CEAEngine()
    {
       Deinitialize();
    }

    bool Initialize()
    {
       // 1. Initialize Logger
       m_logger = new CLogger();
       // Using "Common" folder might be better for logs if we want them persisted easily across tests,
       // but strictly speaking file write should be careful.
       // Using standard local file "JulesEA_Log.csv"
       if(!m_logger->Initialize("JulesEA_Log.csv", LOG_LEVEL_INFO))
       {
          Print("CRITICAL: Failed to initialize Logger!");
          return false;
       }

       m_logger->LogInfo("EAEngine", "Initialize", "Starting initialization sequence...");

       // 2. Initialize Components
       m_indicatorManager = new CIndicatorManager(m_logger);
       if(!m_indicatorManager->Initialize()) return false;

       m_riskManager = new CRiskManager(m_logger);
       if(!m_riskManager->Initialize()) return false;

       m_tradeExecutor = new CTradeExecutor(m_logger);
       if(!m_tradeExecutor->Initialize(123456)) return false; // Magic number could be param

       // 3. Initialize Strategy Dispatcher
       m_strategyDispatcher = new CStrategyDispatcher(m_logger, m_indicatorManager, m_riskManager, m_tradeExecutor);
       if(!m_strategyDispatcher->Initialize()) return false;

       m_initialized = true;
       m_logger->LogInfo("EAEngine", "Initialize", "Initialization complete.");
       return true;
    }

    // Allow registering strategies externally (e.g. from main .mq5)
    bool RegisterStrategy(CStrategyBase* strategy)
    {
       if(!m_initialized || m_strategyDispatcher == NULL) return false;
       return m_strategyDispatcher->RegisterStrategy(strategy);
    }

    void OnTick()
    {
       if(!m_initialized) return;

       // Update all indicators first (optimization: could be per symbol)
       m_indicatorManager->UpdateAllIndicators();

       // Process Strategy Logic for the current symbol (or iterate all if multi-currency on one chart)
       // Standard MT5 EA OnTick triggers for the chart symbol.
       // For multi-currency, we might need OnTimer or check other symbols here.
       // Assuming this EA runs on specific charts or manages specific symbols.
       // We pass the current chart symbol to the dispatcher.
       m_strategyDispatcher->ProcessTick(_Symbol);

       // If this is a true multi-currency EA running on one chart (e.g. EURUSD) but trading others,
       // we would need to iterate a list of symbols here.
       // For Phase 1, we will stick to the chart symbol mostly, but the architecture supports others.
    }

    void OnTrade()
    {
       // Handle trade events (optional for now, can be used for position sync)
    }

    void OnTimer()
    {
       // Timer based events
    }

    void Deinitialize()
    {
       if(m_logger) m_logger->LogInfo("EAEngine", "Deinitialize", "Shutting down...");

       if(m_strategyDispatcher != NULL) { delete m_strategyDispatcher; m_strategyDispatcher = NULL; }
       if(m_tradeExecutor != NULL) { delete m_tradeExecutor; m_tradeExecutor = NULL; }
       if(m_riskManager != NULL) { delete m_riskManager; m_riskManager = NULL; }
       if(m_indicatorManager != NULL) { delete m_indicatorManager; m_indicatorManager = NULL; }

       // Delete logger last
       if(m_logger != NULL) { delete m_logger; m_logger = NULL; }

       m_initialized = false;
    }
};

#endif // JULESEA_EAENGINE_MQH
