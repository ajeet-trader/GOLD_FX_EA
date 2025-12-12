//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Copyright 2025, Jules Assistant |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Assistant"
#property link      "https://yourwebsite.com"
#property strict

#ifndef JULESEA_RISKMANAGER_MQH
#define JULESEA_RISKMANAGER_MQH

#include "Logger.mqh"

class CRiskManager
{
private:
   CLogger* m_logger;
   double m_fixedRiskPercent; // e.g., 1.0 = 1%
   double m_maxDrawdownPercent; // e.g., 20.0 = 20%
   double m_maxDailyLossPercent; // e.g., 5.0 = 5%

   double m_initialBalance;

public:
   CRiskManager(CLogger* logger) : m_logger(logger),
                                   m_fixedRiskPercent(1.0),
                                   m_maxDrawdownPercent(20.0),
                                   m_maxDailyLossPercent(5.0),
                                   m_initialBalance(0.0)
   {
   }

   bool Initialize()
   {
      m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(m_logger) m_logger->LogInfo("RiskManager", "Initialize", StringFormat("Initialized with Balance: %.2f", m_initialBalance));
      return true;
   }

   // Check if we are allowed to trade based on global risk rules
   bool IsTradingAllowed()
   {
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

      // 1. Max Drawdown check (from initial or high watermark - keeping simple here vs initial)
      double drawdown = (m_initialBalance - currentEquity) / m_initialBalance * 100.0;

      if(drawdown >= m_maxDrawdownPercent)
      {
         if(m_logger) m_logger->LogCritical("RiskManager", "IsTradingAllowed", StringFormat("Max Drawdown exceeded! Current: %.2f%%, Max: %.2f%%", drawdown, m_maxDrawdownPercent));
         return false;
      }

      // Additional checks like Daily Loss could be implemented here requiring history tracking

      return true;
   }

   // Calculate Lot Size based on Fixed Risk Percentage and Stop Loss
   double CalculateLotSize(string symbol, double stopLossPrice, double entryPrice)
   {
      if(!IsTradingAllowed()) return 0.0;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (m_fixedRiskPercent / 100.0);

      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(tickSize == 0 || tickValue == 0)
      {
         if(m_logger) m_logger->LogError("RiskManager", "CalculateLotSize", "Invalid symbol info for " + symbol);
         return 0.0;
      }

      double slPoints = MathAbs(entryPrice - stopLossPrice);
      if(slPoints == 0) return 0.0; // Avoid division by zero

      // Amount lost per lot if SL hit
      double lossPerLot = (slPoints / tickSize) * tickValue;

      if(lossPerLot == 0) return 0.0;

      double lots = riskAmount / lossPerLot;

      // Normalize lots
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      lots = MathFloor(lots / stepLot) * stepLot;

      if(lots < minLot) lots = minLot; // Or 0 if strict risk management
      if(lots > maxLot) lots = maxLot;

      return lots;
   }

   // Calculate Lot Size based on ATR (Volatility Adjusted)
   double CalculateLotSizeATR(string symbol, double atrValue, double atrMultiplier=1.0)
   {
       // Simple implementation: assume stop loss distance is atr * multiplier
       // Get current price
       double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
       double slDist = atrValue * atrMultiplier;

       return CalculateLotSize(symbol, ask - slDist, ask);
   }

   void SetFixedRiskPercent(double percent) { m_fixedRiskPercent = percent; }
   void SetMaxDrawdownPercent(double percent) { m_maxDrawdownPercent = percent; }

   void Deinitialize()
   {
      if(m_logger) m_logger->LogInfo("RiskManager", "Deinitialize", "Deinitialized Risk Manager");
   }
};

#endif // JULESEA_RISKMANAGER_MQH
