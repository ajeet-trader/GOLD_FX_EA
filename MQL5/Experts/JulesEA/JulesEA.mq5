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
      // To strictly check if *we* have an open position, we should iterate.
      // However, PositionSelect(symbol) returns true if ANY position exists for that symbol.
      // For this simple strategy, we assume one position per symbol per account or check magic.
      if(!PositionSelect(symbol)) return false;

      // If selected, check Magic Number
      // Note: PositionSelect relies on the platform selecting the position for further property access.
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

      if(m_logger) m_logger->LogInfo("SimpleMAStrategy", "Initialize", "Initializing MA Strategy on " + m_symbol);

      // Initialize Indicators via standard MT5 functions (or use IndicatorManager wrapper if implemented fully)
      // Ideally we use m_indicators->Register... but for this specific strategy logic we need handles.
      // Let's use standard iMA for simplicity in this demo strategy
      m_maHandleFast = iMA(m_symbol, m_timeframe, m_fastMaPeriod, 0, MODE_SMA, PRICE_CLOSE);
      m_maHandleSlow = iMA(m_symbol, m_timeframe, m_slowMaPeriod, 0, MODE_SMA, PRICE_CLOSE);

      if(m_maHandleFast == INVALID_HANDLE || m_maHandleSlow == INVALID_HANDLE)
      {
         if(m_logger) m_logger->LogError("SimpleMAStrategy", "Initialize", "Failed to create MA handles");
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

      // Logic: Crossover
      // Buy: Fast crosses above Slow (Fast[1] > Slow[1] && Fast[0] <= Slow[0] -> Wait, index 0 is current forming bar, index 1 is completed)
      // Usually check closed bars: index 1 and 2.
      // ArraySetAsSeries is default false for CopyBuffer unless set.
      // Let's explicitly set as series
      ArraySetAsSeries(m_maFastVal, true);
      ArraySetAsSeries(m_maSlowVal, true);

      // Index 0 is current, 1 is previous closed
      // Bullish Cross: Fast[1] > Slow[1] AND Fast[2] <= Slow[2]
      // Bearish Cross: Fast[1] < Slow[1] AND Fast[2] >= Slow[2]
      // We need 3 bars for crossover check
      // Note: With ArraySetAsSeries(true), index 0 is the newest (timestamp-wise)

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
             m_executor->CloseAllPositions(m_symbol);
             hasPosition = false; // Closed
         }

         // Open Buy
         if(!hasPosition) // Only one trade at a time for this strategy
         {
             double sl = tick.ask - 100 * _Point; // 100 points SL
             double tp = tick.ask + 200 * _Point; // 200 points TP
             double lot = m_risk->CalculateLotSize(m_symbol, sl, tick.ask);

             if(lot > 0)
                m_executor->OpenTrade(m_symbol, ORDER_TYPE_BUY, lot, sl, tp, "MA Cross Buy");
         }
      }
      else if(isSellSignal)
      {
         // Close Buys
         if(hasPosition && posType == POSITION_TYPE_BUY)
         {
             m_executor->CloseAllPositions(m_symbol);
             hasPosition = false; // Closed
         }

         // Open Sell
         if(!hasPosition)
         {
             double sl = tick.bid + 100 * _Point;
             double tp = tick.bid - 200 * _Point;
             double lot = m_risk->CalculateLotSize(m_symbol, sl, tick.bid);

             if(lot > 0)
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

   if(!g_engine->Initialize())
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
   if(g_engine != NULL)
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
   if(g_engine != NULL)
   {
      g_engine->OnTick();
   }
}

//+------------------------------------------------------------------+
//| Expert trade function                                            |
//+------------------------------------------------------------------+
void OnTrade()
{
   if(g_engine != NULL)
   {
      g_engine->OnTrade();
   }
}
