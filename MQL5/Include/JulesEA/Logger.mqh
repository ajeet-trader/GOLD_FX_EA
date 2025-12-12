//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Copyright 2025, Jules Assistant |
//|                                          https://yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Jules Assistant"
#property link      "https://yourwebsite.com"
#property strict

#ifndef JULESEA_LOGGER_MQH
#define JULESEA_LOGGER_MQH

// Log levels
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_INFO = 0,
   LOG_LEVEL_WARNING = 1,
   LOG_LEVEL_ERROR = 2,
   LOG_LEVEL_CRITICAL = 3,
   LOG_LEVEL_NONE = 4
};

class CLogger
{
private:
   int m_fileHandle;
   ENUM_LOG_LEVEL m_minLogLevel;
   string m_fileName;
   bool m_logToPrint;
   bool m_logToFile;

   // Helper to convert level to string
   string GetLevelString(ENUM_LOG_LEVEL level)
   {
      switch(level)
      {
         case LOG_LEVEL_INFO: return "INFO";
         case LOG_LEVEL_WARNING: return "WARNING";
         case LOG_LEVEL_ERROR: return "ERROR";
         case LOG_LEVEL_CRITICAL: return "CRITICAL";
         default: return "UNKNOWN";
      }
   }

public:
   CLogger() : m_fileHandle(INVALID_HANDLE),
               m_minLogLevel(LOG_LEVEL_INFO),
               m_logToPrint(true),
               m_logToFile(true)
   {
   }

   ~CLogger()
   {
      Deinitialize();
   }

   // Initialize the logger
   bool Initialize(string fileName, ENUM_LOG_LEVEL minLevel=LOG_LEVEL_INFO, bool logToPrint=true, bool logToFile=true)
   {
      m_fileName = fileName;
      m_minLogLevel = minLevel;
      m_logToPrint = logToPrint;
      m_logToFile = logToFile;

      if(m_logToFile)
      {
         // Reset error state
         ResetLastError();
         // Open file for writing (shared read/write, common folder or local)
         // Using FILE_COMMON allows sharing between terminals, but for specific EA usually local is fine.
         // Let's use local MQL5/Files folder.
         m_fileHandle = FileOpen(m_fileName, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, "\t");

         if(m_fileHandle == INVALID_HANDLE)
         {
            PrintFormat("CLogger::Initialize: Failed to open log file %s. Error: %d", m_fileName, GetLastError());
            return false;
         }

         // Move to end of file to append
         FileSeek(m_fileHandle, 0, SEEK_END);

         // Write header if file is empty (size 0)
         if(FileSize(m_fileHandle) == 0)
         {
            FileWrite(m_fileHandle, "Timestamp", "Level", "Module", "Function", "Message");
         }
      }

      Log(LOG_LEVEL_INFO, "Logger", "Initialize", "Logger initialized successfully");
      return true;
   }

   // Close file handle
   void Deinitialize()
   {
      if(m_fileHandle != INVALID_HANDLE)
      {
         Log(LOG_LEVEL_INFO, "Logger", "Deinitialize", "Closing logger");
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
      }
   }

   // Main log function
   void Log(ENUM_LOG_LEVEL level, string module, string function, string message)
   {
      if(level < m_minLogLevel) return;

      string levelStr = GetLevelString(level);
      string timeStr = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);

      // Format: [TIME] [LEVEL] [MODULE::FUNCTION] Message
      string logMsg = StringFormat("[%s] [%s] [%s::%s] %s",
                                   timeStr, levelStr, module, function, message);

      // Print to MT5 Experts tab
      if(m_logToPrint)
      {
         Print(logMsg);
      }

      // Write to file
      if(m_logToFile && m_fileHandle != INVALID_HANDLE)
      {
         FileWrite(m_fileHandle, timeStr, levelStr, module, function, message);
         // Flush to ensure data is written immediately
         FileFlush(m_fileHandle);
      }
   }

   // Convenience methods
   void LogInfo(string module, string function, string message)
   {
      Log(LOG_LEVEL_INFO, module, function, message);
   }

   void LogWarning(string module, string function, string message)
   {
      Log(LOG_LEVEL_WARNING, module, function, message);
   }

   void LogError(string module, string function, string message)
   {
      Log(LOG_LEVEL_ERROR, module, function, message);
   }

   void LogCritical(string module, string function, string message)
   {
      Log(LOG_LEVEL_CRITICAL, module, function, message);
   }
};

#endif // JULESEA_LOGGER_MQH
