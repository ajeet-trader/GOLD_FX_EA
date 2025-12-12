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
       // Using standard local file "JulesEA_Log.csv"
       if(CheckPointer(m_logger) != POINTER_INVALID)
       {
          if(!m_logger->Initialize("JulesEA_Log.csv", LOG_LEVEL_INFO))
          {
             Print("CRITICAL: Failed to initialize Logger!");
             return false;
          }
          m_logger->LogInfo("EAEngine", "Initialize", "Starting initialization sequence...");
       }
       else
       {
          Print("CRITICAL: Logger allocation failed!");
          return false;
       }

       // 2. Initialize Components
       m_indicatorManager = new CIndicatorManager(m_logger);
       if(CheckPointer(m_indicatorManager) != POINTER_INVALID)
       {
          if(!m_indicatorManager->Initialize()) return false;
       }
       else return false;

       m_riskManager = new CRiskManager(m_logger);
       if(CheckPointer(m_riskManager) != POINTER_INVALID)
       {
          if(!m_riskManager->Initialize()) return false;
       }
       else return false;

       m_tradeExecutor = new CTradeExecutor(m_logger);
       if(CheckPointer(m_tradeExecutor) != POINTER_INVALID)
       {
          if(!m_tradeExecutor->Initialize(123456)) return false; // Magic number could be param
       }
       else return false;

       // 3. Initialize Strategy Dispatcher
       m_strategyDispatcher = new CStrategyDispatcher(m_logger, m_indicatorManager, m_riskManager, m_tradeExecutor);
       if(CheckPointer(m_strategyDispatcher) != POINTER_INVALID)
       {
          if(!m_strategyDispatcher->Initialize()) return false;
       }
       else return false;

       m_initialized = true;
       if(CheckPointer(m_logger) != POINTER_INVALID)
          m_logger->LogInfo("EAEngine", "Initialize", "Initialization complete.");
       return true;
    }

    // Allow registering strategies externally (e.g. from main .mq5)
    bool RegisterStrategy(CStrategyBase* strategy)
    {
       if(!m_initialized || CheckPointer(m_strategyDispatcher) == POINTER_INVALID) return false;
       return m_strategyDispatcher->RegisterStrategy(strategy);
    }

    void OnTick()
    {
       if(!m_initialized) return;

       // Update all indicators first
       if(CheckPointer(m_indicatorManager) != POINTER_INVALID)
          m_indicatorManager->UpdateAllIndicators();

       // Process Strategy Logic for the current symbol
       if(CheckPointer(m_strategyDispatcher) != POINTER_INVALID)
          m_strategyDispatcher->ProcessTick(_Symbol);
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
       if(CheckPointer(m_logger) != POINTER_INVALID)
          m_logger->LogInfo("EAEngine", "Deinitialize", "Shutting down...");

       if(CheckPointer(m_strategyDispatcher) != POINTER_INVALID) { delete m_strategyDispatcher; m_strategyDispatcher = NULL; }
       if(CheckPointer(m_tradeExecutor) != POINTER_INVALID) { delete m_tradeExecutor; m_tradeExecutor = NULL; }
       if(CheckPointer(m_riskManager) != POINTER_INVALID) { delete m_riskManager; m_riskManager = NULL; }
       if(CheckPointer(m_indicatorManager) != POINTER_INVALID) { delete m_indicatorManager; m_indicatorManager = NULL; }

       // Delete logger last
       if(CheckPointer(m_logger) != POINTER_INVALID) { delete m_logger; m_logger = NULL; }

       m_initialized = false;
    }
};

#endif // JULESEA_EAENGINE_MQH
