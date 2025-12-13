//+------------------------------------------------------------------+
//|                                                       Logger.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Common/Common.mqh>

//+------------------------------------------------------------------+
//| CLogger Class                                                    |
//| Comprehensive logging system with multiple levels                |
//+------------------------------------------------------------------+
class CLogger
{
private:
    ENUM_LOG_LEVEL m_logLevel;
    bool m_enableFileLogging;
    bool m_enableConsoleLogging;
    string m_logFilePath;
    int m_fileHandle;
    
public:
    // Constructor
    CLogger(ENUM_LOG_LEVEL logLevel = LOG_LEVEL_INFO, 
            bool enableFileLogging = true, 
            bool enableConsoleLogging = true)
    {
        m_logLevel = logLevel;
        m_enableFileLogging = enableFileLogging;
        m_enableConsoleLogging = enableConsoleLogging;
        m_fileHandle = INVALID_HANDLE;
        
        // Create log file path
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        m_logFilePath = StringFormat("GoldFXEA_Logs\\GoldFXEA_%04d%02d%02d.log",
                                     dt.year, dt.mon, dt.day);
    }
    
    // Destructor
    ~CLogger()
    {
        CloseLogFile();
    }
    
    // Initialize logger
    bool Initialize()
    {
        if(m_enableFileLogging)
        {
            // Ensure log directory exists
            if(!OpenLogFile())
            {
                Print("WARNING: Failed to open log file, file logging disabled");
                m_enableFileLogging = false;
            }
        }
        return true;
    }
    
    // Log methods for different levels
    void Debug(string message, string module = "", string function = "")
    {
        Log(LOG_LEVEL_DEBUG, message, module, function);
    }
    
    void Info(string message, string module = "", string function = "")
    {
        Log(LOG_LEVEL_INFO, message, module, function);
    }
    
    void Warning(string message, string module = "", string function = "")
    {
        Log(LOG_LEVEL_WARNING, message, module, function);
    }
    
    void Error(string message, string module = "", string function = "")
    {
        Log(LOG_LEVEL_ERROR, message, module, function);
    }
    
    void Critical(string message, string module = "", string function = "")
    {
        Log(LOG_LEVEL_CRITICAL, message, module, function);
    }
    
    // Main log method
    void Log(ENUM_LOG_LEVEL level, string message, string module = "", string function = "")
    {
        // Check if this log level should be logged
        if(level < m_logLevel)
            return;
        
        // Format log entry
        string levelStr = LogLevelToString(level);
        string timestamp = GetTimestamp();
        string contextStr = "";
        
        if(module != "" || function != "")
        {
            if(module != "" && function != "")
                contextStr = StringFormat("[%s::%s] ", module, function);
            else if(module != "")
                contextStr = StringFormat("[%s] ", module);
            else
                contextStr = StringFormat("[%s] ", function);
        }
        
        string logEntry = StringFormat("[%s] [%s] %s%s", 
                                      timestamp, levelStr, contextStr, message);
        
        // Console logging
        if(m_enableConsoleLogging)
        {
            // Add color coding for console output
            if(level == LOG_LEVEL_ERROR || level == LOG_LEVEL_CRITICAL)
                Print("❌ ", logEntry);
            else if(level == LOG_LEVEL_WARNING)
                Print("⚠️ ", logEntry);
            else if(level == LOG_LEVEL_INFO)
                Print("ℹ️ ", logEntry);
            else
                Print("🔍 ", logEntry);
        }
        
        // File logging
        if(m_enableFileLogging && m_fileHandle != INVALID_HANDLE)
        {
            FileWriteString(m_fileHandle, logEntry + "\n");
            FileFlush(m_fileHandle);
        }
    }
    
    // Performance logging
    void LogPerformance(string operation, ulong startTime, string module = "")
    {
        ulong endTime = GetMicrosecondCount();
        double executionTime = (endTime - startTime) / 1000.0; // Convert to milliseconds
        
        string message = StringFormat("Performance: %s completed in %.3f ms", 
                                     operation, executionTime);
        
        if(executionTime > ONTICK_MAX_TIME_MS)
            Warning(message + " (SLOW!)", module);
        else
            Debug(message, module);
    }
    
    // Trade logging
    void LogTrade(string action, string symbol, ENUM_ORDER_TYPE orderType, 
                  double volume, double price, double sl, double tp, 
                  ulong ticket = 0, string result = "")
    {
        string orderTypeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
        string message = StringFormat("Trade %s: %s %s %.2f lots @ %.5f [SL:%.5f TP:%.5f]",
                                     action, symbol, orderTypeStr, volume, price, sl, tp);
        
        if(ticket > 0)
            message += StringFormat(" Ticket: %llu", ticket);
        
        if(result != "")
            message += StringFormat(" Result: %s", result);
        
        Info(message, "TradeExecutor");
    }
    
    // Set log level at runtime
    void SetLogLevel(ENUM_LOG_LEVEL level)
    {
        m_logLevel = level;
        Info(StringFormat("Log level changed to: %s", LogLevelToString(level)), "Logger");
    }
    
    // Get current log level
    ENUM_LOG_LEVEL GetLogLevel() const { return m_logLevel; }
    
    // Cleanup
    void Deinitialize()
    {
        Info("Logger shutting down", "Logger");
        CloseLogFile();
    }
    
private:
    // Open log file
    bool OpenLogFile()
    {
        m_fileHandle = FileOpen(m_logFilePath, 
                               FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ,
                               '\n');
        
        if(m_fileHandle == INVALID_HANDLE)
        {
            Print("ERROR: Failed to open log file: ", m_logFilePath, 
                  " Error: ", GetLastError());
            return false;
        }
        
        // Move to end of file for appending
        FileSeek(m_fileHandle, 0, SEEK_END);
        
        // Write session start marker
        string separator = "================================================================================";
        FileWriteString(m_fileHandle, "\n" + separator + "\n");
        FileWriteString(m_fileHandle, StringFormat("GoldFXEA Session Started: %s\n", GetTimestamp()));
        FileWriteString(m_fileHandle, separator + "\n\n");
        FileFlush(m_fileHandle);
        
        return true;
    }
    
    // Close log file
    void CloseLogFile()
    {
        if(m_fileHandle != INVALID_HANDLE)
        {
            string separator = "================================================================================";
            FileWriteString(m_fileHandle, "\n" + separator + "\n");
            FileWriteString(m_fileHandle, StringFormat("GoldFXEA Session Ended: %s\n", GetTimestamp()));
            FileWriteString(m_fileHandle, separator + "\n\n");
            
            FileClose(m_fileHandle);
            m_fileHandle = INVALID_HANDLE;
        }
    }
    
    // Convert log level to string
    string LogLevelToString(ENUM_LOG_LEVEL level)
    {
        switch(level)
        {
            case LOG_LEVEL_DEBUG:    return "DEBUG";
            case LOG_LEVEL_INFO:     return "INFO";
            case LOG_LEVEL_WARNING:  return "WARNING";
            case LOG_LEVEL_ERROR:    return "ERROR";
            case LOG_LEVEL_CRITICAL: return "CRITICAL";
            default:                 return "UNKNOWN";
        }
    }
};
//+------------------------------------------------------------------+