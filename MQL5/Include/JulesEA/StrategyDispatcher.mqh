//+------------------------------------------------------------------+
//|                                           StrategyDispatcher.mqh |
//|                                  Copyright 2025, Jules Assistant |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Assistant"
#property link      "https://yourwebsite.com"
#property strict

#ifndef JULESEA_STRATEGYDISPATCHER_MQH
#define JULESEA_STRATEGYDISPATCHER_MQH

#include <Arrays\ArrayObj.mqh>
#include "Logger.mqh"
#include "TradeExecutor.mqh"
#include "RiskManager.mqh"
#include "IndicatorManager.mqh"

// Base Strategy Class to simplify implementations
// INHERITANCE FIX: Inherits ONLY from CObject to avoid multiple inheritance issues.
// Removed IModule interface.
class CStrategyBase : public CObject
{
protected:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    CIndicatorManager* m_indicators;
    CRiskManager* m_risk;
    CTradeExecutor* m_executor;
    CLogger* m_logger;
    bool m_initialized;

public:
    CStrategyBase() : m_initialized(false), m_indicators(NULL), m_risk(NULL), m_executor(NULL), m_logger(NULL) {}

    // Set dependencies (Dependency Injection)
    void SetDependencies(CIndicatorManager* indicators, CRiskManager* risk, CTradeExecutor* executor, CLogger* logger)
    {
        m_indicators = indicators;
        m_risk = risk;
        m_executor = executor;
        m_logger = logger;
    }

    // Interface methods directly in Base Class
    virtual bool Initialize(string params)
    {
       m_initialized = true;
       return true;
    }

    virtual void ProcessTick(MqlTick &tick) { /* Base does nothing */ }

    virtual void Deinitialize() { m_initialized = false; }

    virtual string GetModuleInfo() { return "Base Strategy"; }

    virtual string GetSymbol() { return m_symbol; }

    // Abstract methods for strategy logic
    virtual bool CheckEntryConditions() { return false; }
    virtual bool CheckExitConditions() { return false; }
};

class CStrategyDispatcher
{
private:
   CArrayObj m_strategies;
   CLogger* m_logger;
   CIndicatorManager* m_indicatorManager;
   CRiskManager* m_riskManager;
   CTradeExecutor* m_tradeExecutor;

public:
   CStrategyDispatcher(CLogger* logger, CIndicatorManager* ind, CRiskManager* risk, CTradeExecutor* exec)
      : m_logger(logger), m_indicatorManager(ind), m_riskManager(risk), m_tradeExecutor(exec)
   {
      m_strategies.FreeMode(true); // Auto-delete strategies
   }

   ~CStrategyDispatcher()
   {
      Deinitialize();
   }

   bool Initialize()
   {
      if(CheckPointer(m_logger) != POINTER_INVALID)
         m_logger->LogInfo("StrategyDispatcher", "Initialize", "Initializing Strategy Dispatcher");
      return true;
   }

   bool RegisterStrategy(CStrategyBase* strategy)
   {
      if(CheckPointer(strategy) == POINTER_INVALID) return false;

      // Inject dependencies
      strategy->SetDependencies(m_indicatorManager, m_riskManager, m_tradeExecutor, m_logger);

      // Initialize strategy
      if(!strategy->Initialize(""))
      {
         if(CheckPointer(m_logger) != POINTER_INVALID)
            m_logger->LogError("StrategyDispatcher", "RegisterStrategy", "Failed to initialize strategy: " + strategy->GetModuleInfo());
         return false;
      }

      if(m_strategies.Add(strategy))
      {
         if(CheckPointer(m_logger) != POINTER_INVALID)
            m_logger->LogInfo("StrategyDispatcher", "RegisterStrategy", "Registered strategy: " + strategy->GetModuleInfo());
         return true;
      }
      return false;
   }

   void ProcessTick(string symbol)
   {
      MqlTick tick;
      if(!SymbolInfoTick(symbol, tick)) return;

      for(int i=0; i<m_strategies.Total(); i++)
      {
         CStrategyBase* strategy = (CStrategyBase*)m_strategies.At(i);
         // Only process if symbol matches
         if(CheckPointer(strategy) != POINTER_INVALID && strategy->GetSymbol() == symbol)
         {
            strategy->ProcessTick(tick);
         }
      }
   }

   void Deinitialize()
   {
      if(CheckPointer(m_logger) != POINTER_INVALID)
         m_logger->LogInfo("StrategyDispatcher", "Deinitialize", "Deinitializing all strategies");

      for(int i=0; i<m_strategies.Total(); i++)
      {
         CStrategyBase* strategy = (CStrategyBase*)m_strategies.At(i);
         if(CheckPointer(strategy) != POINTER_INVALID)
            strategy->Deinitialize();
      }
      m_strategies.Clear();
   }
};

#endif // JULESEA_STRATEGYDISPATCHER_MQH
