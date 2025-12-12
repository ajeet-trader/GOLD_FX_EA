//+------------------------------------------------------------------+
//|                                             IndicatorManager.mqh |
//|                                  Copyright 2025, Jules Assistant |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Assistant"
#property link      "https://yourwebsite.com"
#property strict

#ifndef JULESEA_INDICATORMANAGER_MQH
#define JULESEA_INDICATORMANAGER_MQH

#include <Arrays\ArrayObj.mqh>
#include "Logger.mqh"

// Interface for all indicators
interface IIndicator
{
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, string params);
   bool Update(); // Re-calculate or fetch latest values
   double GetValue(int index, int buffer = 0);
   string GetName();
   void Deinitialize();
};

// Base class implementation for common indicator functionality
class CIndicatorBase : public CObject, public IIndicator
{
protected:
   int m_handle;
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   string m_name;
   double m_buffer[]; // Main buffer cache

public:
   CIndicatorBase() : m_handle(INVALID_HANDLE) {}
   ~CIndicatorBase() { Deinitialize(); }

   virtual bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, string params) { return false; } // Override

   virtual bool Update()
   {
      if(m_handle == INVALID_HANDLE) return false;

      // Copy latest values (e.g., last 3 bars) to buffer
      // In a real scenario, we might want to copy more or manage a circular buffer.
      // Here we keep it simple: copy last 2 bars (0 and 1)
      if(CopyBuffer(m_handle, 0, 0, 3, m_buffer) < 0)
      {
         return false;
      }
      ArraySetAsSeries(m_buffer, true);
      return true;
   }

   virtual double GetValue(int index, int buffer = 0)
   {
      // Note: This base implementation assumes single buffer indicators.
      // Multi-buffer indicators should override this or manage multiple arrays.
      if(index >= 0 && index < ArraySize(m_buffer))
      {
         return m_buffer[index];
      }
      return 0.0;
   }

   virtual string GetName() { return m_name; }

   virtual void Deinitialize()
   {
      if(m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
   }
};

// Manager class
class CIndicatorManager
{
private:
   CArrayObj m_indicators; // Stores IIndicator pointers (casted as CObject)
   CLogger* m_logger;

   struct IndicatorCache {
       string name;
       datetime lastUpdate;
       double value; // Cached value for index 0
   };

public:
   CIndicatorManager(CLogger* logger) : m_logger(logger)
   {
      m_indicators.FreeMode(true); // Auto-delete objects
   }

   ~CIndicatorManager()
   {
      m_indicators.Clear();
   }

   bool Initialize()
   {
      if(m_logger) m_logger->LogInfo("IndicatorManager", "Initialize", "Initializing Indicator Manager");
      return true;
   }

   bool RegisterIndicator(CIndicatorBase* indicator)
   {
      if(indicator == NULL) return false;

      if(m_indicators.Add(indicator))
      {
         if(m_logger) m_logger->LogInfo("IndicatorManager", "RegisterIndicator", "Registered indicator: " + indicator->GetName());
         return true;
      }
      return false;
   }

   bool UpdateAllIndicators()
   {
      bool allSuccess = true;
      for(int i=0; i<m_indicators.Total(); i++)
      {
         CIndicatorBase* ind = (CIndicatorBase*)m_indicators.At(i);
         if(ind != NULL)
         {
            if(!ind->Update())
            {
               if(m_logger) m_logger->LogWarning("IndicatorManager", "UpdateAllIndicators", "Failed to update " + ind->GetName());
               allSuccess = false;
            }
         }
      }
      return allSuccess;
   }

   // Helper to find indicator by name
   CIndicatorBase* GetIndicator(string name)
   {
      for(int i=0; i<m_indicators.Total(); i++)
      {
         CIndicatorBase* ind = (CIndicatorBase*)m_indicators.At(i);
         if(ind != NULL && ind->GetName() == name)
            return ind;
      }
      return NULL;
   }

   double GetIndicatorValue(string name, int index, int buffer = 0)
   {
      CIndicatorBase* ind = GetIndicator(name);
      if(ind != NULL)
      {
         return ind->GetValue(index, buffer);
      }

      if(m_logger) m_logger->LogError("IndicatorManager", "GetIndicatorValue", "Indicator not found: " + name);
      return 0.0;
   }

   void Deinitialize()
   {
      if(m_logger) m_logger->LogInfo("IndicatorManager", "Deinitialize", "Deinitializing Indicator Manager");
      m_indicators.Clear();
   }
};

#endif // JULESEA_INDICATORMANAGER_MQH
