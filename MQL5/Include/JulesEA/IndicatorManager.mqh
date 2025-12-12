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

// Base class implementation for common indicator functionality
// Removed IIndicator interface to avoid multiple inheritance issues.
// All interface methods are now virtual methods in CIndicatorBase.
class CIndicatorBase : public CObject
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

   // Abstract/Virtual Interface Methods
   virtual bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, string params) { return false; }

   virtual bool Update()
   {
      if(m_handle == INVALID_HANDLE) return false;

      // Copy latest values (e.g., last 3 bars) to buffer
      if(CopyBuffer(m_handle, 0, 0, 3, m_buffer) < 0)
      {
         return false;
      }
      ArraySetAsSeries(m_buffer, true);
      return true;
   }

   virtual double GetValue(int index, int buffer = 0)
   {
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
   CArrayObj m_indicators; // Stores CIndicatorBase pointers
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
      if(CheckPointer(m_logger) != POINTER_INVALID)
         m_logger->LogInfo("IndicatorManager", "Initialize", "Initializing Indicator Manager");
      return true;
   }

   bool RegisterIndicator(CIndicatorBase* indicator)
   {
      if(CheckPointer(indicator) == POINTER_INVALID) return false;

      if(m_indicators.Add(indicator))
      {
         if(CheckPointer(m_logger) != POINTER_INVALID)
            m_logger->LogInfo("IndicatorManager", "RegisterIndicator", "Registered indicator: " + indicator->GetName());
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
         if(CheckPointer(ind) != POINTER_INVALID)
         {
            if(!ind->Update())
            {
               if(CheckPointer(m_logger) != POINTER_INVALID)
                  m_logger->LogWarning("IndicatorManager", "UpdateAllIndicators", "Failed to update " + ind->GetName());
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
         if(CheckPointer(ind) != POINTER_INVALID && ind->GetName() == name)
            return ind;
      }
      return NULL;
   }

   double GetIndicatorValue(string name, int index, int buffer = 0)
   {
      CIndicatorBase* ind = GetIndicator(name);
      if(CheckPointer(ind) != POINTER_INVALID)
      {
         return ind->GetValue(index, buffer);
      }

      if(CheckPointer(m_logger) != POINTER_INVALID)
         m_logger->LogError("IndicatorManager", "GetIndicatorValue", "Indicator not found: " + name);
      return 0.0;
   }

   void Deinitialize()
   {
      if(CheckPointer(m_logger) != POINTER_INVALID)
         m_logger->LogInfo("IndicatorManager", "Deinitialize", "Deinitializing Indicator Manager");
      m_indicators.Clear();
   }
};

#endif // JULESEA_INDICATORMANAGER_MQH
