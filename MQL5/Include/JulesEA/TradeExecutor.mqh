//+------------------------------------------------------------------+
//|                                                TradeExecutor.mqh |
//|                                  Copyright 2025, Jules Assistant |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Assistant"
#property link      "https://yourwebsite.com"
#property strict

#ifndef JULESEA_TRADEEXECUTOR_MQH
#define JULESEA_TRADEEXECUTOR_MQH

#include <Trade\Trade.mqh> // Standard Library CTrade
#include "Logger.mqh"

class CTradeExecutor
{
private:
   CTrade m_trade;
   CLogger* m_logger;
   ulong m_magicNumber;
   int m_maxRetries;
   int m_slippage;

public:
   CTradeExecutor(CLogger* logger) : m_logger(logger),
                                     m_magicNumber(123456),
                                     m_maxRetries(3),
                                     m_slippage(10)
   {
   }

   bool Initialize(ulong magic)
   {
      m_magicNumber = magic;
      m_trade.SetExpertMagicNumber(m_magicNumber);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC); // IOC is safer than FOK for general use

      if(m_logger != NULL)
         m_logger->LogInfo("TradeExecutor", "Initialize", StringFormat("Initialized with Magic: %d", m_magicNumber));
      return true;
   }

   // Open a market order with retry logic
   bool OpenTrade(string symbol, ENUM_ORDER_TYPE type, double volume, double sl, double tp, string comment="")
   {
      // Basic Validation
      if(volume <= 0)
      {
         if(m_logger != NULL)
            m_logger->LogWarning("TradeExecutor", "OpenTrade", "Invalid volume: " + DoubleToString(volume, 2));
         return false;
      }

      double price = 0.0;
      if(type == ORDER_TYPE_BUY) price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      else if(type == ORDER_TYPE_SELL) price = SymbolInfoDouble(symbol, SYMBOL_BID);

      if(price == 0.0)
      {
         if(m_logger != NULL)
            m_logger->LogError("TradeExecutor", "OpenTrade", "Failed to get price for " + symbol);
         return false;
      }

      // Retry Loop
      for(int i=0; i<m_maxRetries; i++)
      {
         bool result = false;
         if(type == ORDER_TYPE_BUY)
            result = m_trade.Buy(volume, symbol, price, sl, tp, comment);
         else if(type == ORDER_TYPE_SELL)
            result = m_trade.Sell(volume, symbol, price, sl, tp, comment);

         if(result)
         {
            if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
            {
               if(m_logger != NULL)
                  m_logger->LogInfo("TradeExecutor", "OpenTrade", StringFormat("Order Placed: %s %s Vol: %.2f Ticket: %d", symbol, EnumToString(type), volume, m_trade.ResultOrder()));
               return true;
            }
         }

         // Log failure and retry
         if(m_logger != NULL)
            m_logger->LogWarning("TradeExecutor", "OpenTrade", StringFormat("Attempt %d failed. Code: %d Desc: %s", i+1, m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()));
         Sleep(100); // Wait 100ms before retry

         // Refresh price
         if(type == ORDER_TYPE_BUY) price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         else if(type == ORDER_TYPE_SELL) price = SymbolInfoDouble(symbol, SYMBOL_BID);
      }

      if(m_logger != NULL)
         m_logger->LogError("TradeExecutor", "OpenTrade", "Final failure to open trade for " + symbol);
      return false;
   }

   // Close all positions for a specific symbol and magic number
   void CloseAllPositions(string symbol)
   {
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
            {
               m_trade.PositionClose(ticket);
            }
         }
      }
   }

   void SetSlippage(int slippage)
   {
      m_slippage = slippage;
      m_trade.SetDeviationInPoints(m_slippage);
   }

   void Deinitialize()
   {
      // Any cleanup if needed
   }
};

#endif // JULESEA_TRADEEXECUTOR_MQH
