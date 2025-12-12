//+------------------------------------------------------------------+
//|                                                      JulesEA.mq5 |
//|                                  Copyright 2025, Jules Assistant |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Assistant"
#property link      "https://yourwebsite.com"
#property version   "1.00"
#property strict

// Include the Core Engine
#include <JulesEA\EAEngine.mqh>

// Include any specific strategies for Phase 1 testing
// For now, we will define a simple dummy strategy here or include it if separated.
// Let's create a simple MA Crossover class inline for demonstration/testing as per requirements.

// -------------------------------------------------------------------------
// Simple MA Crossover Strategy for Phase 1 Verification
// -------------------------------------------------------------------------
class CSimpleMAStrategy : public CStrategyBase
{
private:
   int m_fastMaPeriod;
   int m_slowMaPeriod;
   int m_maHandleFast;
   int m_maHandleSlow;
   double m_maFastVal[];
   double m_maSlowVal[];

   // Helper to check if a position belongs to this EA
   bool IsMyPosition(string symbol)
   {
      // Magic number check is done in TradeExecutor::CloseAllPositions via filtering,
      // but PositionSelect just selects by symbol.
      if(!PositionSelect(symbol)) return false;

      long magic = PositionGetInteger(POSITION_MAGIC);
      // Hardcoded magic for Phase 1 (should match TradeExecutor default)
      return (magic == 123456);
   }

public:
   CSimpleMAStrategy() : m_fastMaPeriod(10), m_slowMaPeriod(20), m_maHandleFast(INVALID_HANDLE), m_maHandleSlow(INVALID_HANDLE) {}

   virtual bool Initialize(string params)
   {
      // Parse params if needed, for now use defaults
      m_symbol = _Symbol; // Bind to current chart
      m_timeframe = Period();

      if(CheckPointer(m_logger) != POINTER_INVALID)
         m_logger->LogInfo("SimpleMAStrategy", "Initialize", "Initializing MA Strategy on " + m_symbol);

      m_maHandleFast = iMA(m_symbol, m_timeframe, m_fastMaPeriod, 0, MODE_SMA, PRICE_CLOSE);
      m_maHandleSlow = iMA(m_symbol, m_timeframe, m_slowMaPeriod, 0, MODE_SMA, PRICE_CLOSE);

      if(m_maHandleFast == INVALID_HANDLE || m_maHandleSlow == INVALID_HANDLE)
      {
         if(CheckPointer(m_logger) != POINTER_INVALID)
            m_logger->LogError("SimpleMAStrategy", "Initialize", "Failed to create MA handles");
         return false;
      }

      return CStrategyBase::Initialize(params);
   }

   virtual void ProcessTick(MqlTick &tick)
   {
      if(!m_initialized) return;

      // Update Indicator Buffers
      // Use dynamic arrays for CopyBuffer
      if(CopyBuffer(m_maHandleFast, 0, 0, 3, m_maFastVal) < 3 ||
         CopyBuffer(m_maHandleSlow, 0, 0, 3, m_maSlowVal) < 3)
      {
         return;
      }

      ArraySetAsSeries(m_maFastVal, true);
      ArraySetAsSeries(m_maSlowVal, true);

      // Index 0 is current, 1 is previous closed
      // Bullish Cross: Fast[1] > Slow[1] AND Fast[2] <= Slow[2]
      // Bearish Cross: Fast[1] < Slow[1] AND Fast[2] >= Slow[2]

      bool isBuySignal = (m_maFastVal[1] > m_maSlowVal[1]) && (m_maFastVal[2] <= m_maSlowVal[2]);
      bool isSellSignal = (m_maFastVal[1] < m_maSlowVal[1]) && (m_maFastVal[2] >= m_maSlowVal[2]);

      // Check current position state
      bool hasPosition = IsMyPosition(m_symbol);
      ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY; // Default holder
      if(hasPosition) posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(isBuySignal)
      {
         // Close Sells
         if(hasPosition && posType == POSITION_TYPE_SELL)
         {
             if(CheckPointer(m_executor) != POINTER_INVALID)
                m_executor->CloseAllPositions(m_symbol);
             hasPosition = false; // Closed
         }

         // Open Buy
         if(!hasPosition) // Only one trade at a time for this strategy
         {
             double sl = tick.ask - 100 * _Point; // 100 points SL
             double tp = tick.ask + 200 * _Point; // 200 points TP
             double lot = 0.0;
             if(CheckPointer(m_risk) != POINTER_INVALID)
                lot = m_risk->CalculateLotSize(m_symbol, sl, tick.ask);

             if(lot > 0 && CheckPointer(m_executor) != POINTER_INVALID)
                m_executor->OpenTrade(m_symbol, ORDER_TYPE_BUY, lot, sl, tp, "MA Cross Buy");
         }
      }
      else if(isSellSignal)
      {
         // Close Buys
         if(hasPosition && posType == POSITION_TYPE_BUY)
         {
             if(CheckPointer(m_executor) != POINTER_INVALID)
                m_executor->CloseAllPositions(m_symbol);
             hasPosition = false; // Closed
         }

         // Open Sell
         if(!hasPosition)
         {
             double sl = tick.bid + 100 * _Point;
             double tp = tick.bid - 200 * _Point;
             double lot = 0.0;
             if(CheckPointer(m_risk) != POINTER_INVALID)
                lot = m_risk->CalculateLotSize(m_symbol, sl, tick.bid);

             if(lot > 0 && CheckPointer(m_executor) != POINTER_INVALID)
                m_executor->OpenTrade(m_symbol, ORDER_TYPE_SELL, lot, sl, tp, "MA Cross Sell");
         }
      }
   }

   virtual void Deinitialize()
   {
      IndicatorRelease(m_maHandleFast);
      IndicatorRelease(m_maHandleSlow);
      CStrategyBase::Deinitialize();
   }

   virtual string GetModuleInfo() { return "Simple MA Strategy"; }
};

// -------------------------------------------------------------------------
// Global EA Engine Instance
// -------------------------------------------------------------------------
CEAEngine* g_engine = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_engine = new CEAEngine();

   if(CheckPointer(g_engine) == POINTER_INVALID || !g_engine->Initialize())
   {
      Print("Fatal Error: Engine failed to initialize");
      return INIT_FAILED;
   }

   // Register Strategies
   // In Phase 1 we verify with a simple MA strategy
   CSimpleMAStrategy* strategy = new CSimpleMAStrategy();
   if(!g_engine->RegisterStrategy(strategy))
   {
      Print("Failed to register strategy");
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(CheckPointer(g_engine) != POINTER_INVALID)
   {
      g_engine->Deinitialize();
      delete g_engine;
      g_engine = NULL;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(CheckPointer(g_engine) != POINTER_INVALID)
   {
      g_engine->OnTick();
   }
}

//+------------------------------------------------------------------+
//| Expert trade function                                            |
//+------------------------------------------------------------------+
void OnTrade()
{
   if(CheckPointer(g_engine) != POINTER_INVALID)
   {
      g_engine->OnTrade();
   }
}
