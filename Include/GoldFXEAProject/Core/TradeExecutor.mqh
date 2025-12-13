//+------------------------------------------------------------------+
//|                                               TradeExecutor.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <Trade/Trade.mqh>
#include <GoldFXEAProject/Interfaces/IModule.mqh>
#include <GoldFXEAProject/Utils/Logger.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>

//+------------------------------------------------------------------+
//| CTradeExecutor Class                                             |
//| Handles all trade execution with retry logic and validation      |
//+------------------------------------------------------------------+
class CTradeExecutor : public IModule
{
private:
    CLogger* m_logger;
    CRiskManager* m_riskManager;
    CTrade m_trade;
    
    int m_magicNumber;
    int m_maxRetries;
    int m_retryDelayMs;
    int m_slippagePoints;
    bool m_enableTrading;
    
public:
    // Constructor
    CTradeExecutor(CLogger* logger, CRiskManager* riskManager) : IModule("TradeExecutor")
    {
        m_logger = logger;
        m_riskManager = riskManager;
        m_magicNumber = EA_MAGIC_NUMBER;
        m_maxRetries = MAX_RETRIES;
        m_retryDelayMs = RETRY_DELAY_MS;
        m_slippagePoints = SLIPPAGE_POINTS;
        m_enableTrading = true;
        
        // Configure CTrade object
        m_trade.SetExpertMagicNumber(m_magicNumber);
        m_trade.SetDeviationInPoints(m_slippagePoints);
        m_trade.SetTypeFilling(ORDER_FILLING_IOC);
        m_trade.SetAsyncMode(false);
    }
    
    // Destructor
    ~CTradeExecutor()
    {
        Deinitialize();
    }
    
    // Initialize trade executor
    virtual bool Initialize() override
    {
        m_logger.Info("Initializing Trade Executor", m_moduleName);
        
        m_status = MODULE_STATUS_INITIALIZING;
        
        m_logger.Info(StringFormat("Magic Number: %d", m_magicNumber), m_moduleName);
        m_logger.Info(StringFormat("Max Retries: %d", m_maxRetries), m_moduleName);
        m_logger.Info(StringFormat("Slippage: %d points", m_slippagePoints), m_moduleName);
        
        m_status = MODULE_STATUS_INITIALIZED;
        return true;
    }
    
    // Process tick
    virtual void ProcessTick(MqlTick &tick) override
    {
        // Trade executor doesn't need to process every tick
        // It only acts when explicitly called
    }
    
    // Deinitialize
    virtual void Deinitialize() override
    {
        if(m_status == MODULE_STATUS_UNINITIALIZED)
            return;
        
        m_logger.Info("Trade Executor shutting down", m_moduleName);
        m_status = MODULE_STATUS_STOPPED;
    }
    
    // Get module info
    virtual string GetModuleInfo() override
    {
        return StringFormat("TradeExecutor v1.0 - Magic: %d | Status: %s", 
                          m_magicNumber, (m_enableTrading ? "ENABLED" : "DISABLED"));
    }
    
    // Set trading enabled/disabled
    void SetTradingEnabled(bool enabled)
    {
        m_enableTrading = enabled;
        m_logger.Info(StringFormat("Trading %s", enabled ? "ENABLED" : "DISABLED"), m_moduleName);
    }
    
    // Open a trade
    TradeResult OpenTrade(TradeRequest &request)
    {
        TradeResult result;
        
        if(!m_enableTrading)
        {
            result.success = false;
            result.message = "Trading is disabled";
            m_logger.Warning(result.message, m_moduleName);
            return result;
        }
        
        // Validate request
        if(!ValidateTradeRequest(request, result.message))
        {
            result.success = false;
            m_logger.Error("Trade validation failed: " + result.message, m_moduleName);
            return result;
        }
        
        // Check with risk manager
        string riskReason;
        if(!m_riskManager.CanOpenNewTrade(request.symbol, request.volume, riskReason))
        {
            result.success = false;
            result.message = "Risk check failed: " + riskReason;
            m_logger.Warning(result.message, m_moduleName);
            return result;
        }
        
        // Execute trade with retry logic
        for(int attempt = 1; attempt <= m_maxRetries; attempt++)
        {
            result = ExecuteOrder(request, attempt);
            
            if(result.success)
            {
                m_logger.LogTrade("OPENED", request.symbol, request.orderType, 
                                 request.volume, result.executedPrice, 
                                 request.stopLoss, request.takeProfit, 
                                 result.ticket, "SUCCESS");
                break;
            }
            
            if(attempt < m_maxRetries)
            {
                m_logger.Warning(StringFormat("Trade failed (Attempt %d/%d): %s - Retrying...", 
                               attempt, m_maxRetries, result.message), m_moduleName);
                Sleep(m_retryDelayMs);
            }
            else
            {
                m_logger.Error(StringFormat("Trade failed after %d attempts: %s", 
                             m_maxRetries, result.message), m_moduleName);
            }
        }
        
        return result;
    }
    
    // Close a position
    bool ClosePosition(ulong ticket, string &errorMessage)
    {
        if(!PositionSelectByTicket(ticket))
        {
            errorMessage = "Position not found";
            return false;
        }
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double volume = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        bool success = m_trade.PositionClose(ticket);
        
        if(success)
        {
            m_logger.LogTrade("CLOSED", symbol, 
                            (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                            volume, 0, 0, 0, ticket, "SUCCESS");
        }
        else
        {
            errorMessage = StringFormat("Close failed: %s (Code: %d)", 
                                       m_trade.ResultRetcodeDescription(), 
                                       m_trade.ResultRetcode());
            m_logger.Error(errorMessage, m_moduleName);
        }
        
        return success;
    }
    
    // Close all positions for a symbol
    int CloseAllPositions(string symbol = "")
    {
        int closedCount = 0;
        
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                long posMagic = PositionGetInteger(POSITION_MAGIC);
                
                // Check if this position belongs to our EA
                if(posMagic != m_magicNumber)
                    continue;
                
                // Check symbol filter
                if(symbol != "" && posSymbol != symbol)
                    continue;
                
                string errorMsg;
                if(ClosePosition(ticket, errorMsg))
                    closedCount++;
            }
        }
        
        if(closedCount > 0)
            m_logger.Info(StringFormat("Closed %d position(s)", closedCount), m_moduleName);
        
        return closedCount;
    }
    
    // Modify position
    bool ModifyPosition(ulong ticket, double stopLoss, double takeProfit, string &errorMessage)
    {
        if(!PositionSelectByTicket(ticket))
        {
            errorMessage = "Position not found";
            return false;
        }
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        stopLoss = NormalizePrice(symbol, stopLoss);
        takeProfit = NormalizePrice(symbol, takeProfit);
        
        bool success = m_trade.PositionModify(ticket, stopLoss, takeProfit);
        
        if(success)
        {
            m_logger.Info(StringFormat("Position %llu modified - SL: %.5f TP: %.5f", 
                        ticket, stopLoss, takeProfit), m_moduleName);
        }
        else
        {
            errorMessage = StringFormat("Modify failed: %s (Code: %d)", 
                                       m_trade.ResultRetcodeDescription(), 
                                       m_trade.ResultRetcode());
            m_logger.Error(errorMessage, m_moduleName);
        }
        
        return success;
    }
    
    // Get open positions count
    int GetOpenPositionsCount(string symbol = "")
    {
        int count = 0;
        
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
                long posMagic = PositionGetInteger(POSITION_MAGIC);
                if(posMagic != m_magicNumber)
                    continue;
                
                if(symbol != "")
                {
                    string posSymbol = PositionGetString(POSITION_SYMBOL);
                    if(posSymbol == symbol)
                        count++;
                }
                else
                {
                    count++;
                }
            }
        }
        
        return count;
    }
    
private:
    // Validate trade request
    bool ValidateTradeRequest(TradeRequest &request, string &errorMessage)
    {
        // Check symbol
        if(request.symbol == "")
        {
            errorMessage = "Invalid symbol";
            return false;
        }

        // Check volume
        double minVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
        double maxVolume = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);

        if(request.volume < minVolume || request.volume > maxVolume)
        {
            errorMessage = StringFormat("Invalid volume: %.2f (Min: %.2f, Max: %.2f)",
                                       request.volume, minVolume, maxVolume);
            return false;
        }

        // Check stop loss and take profit
        double point = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
        long stopsLevelLong = SymbolInfoInteger(request.symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int stopsLevel = (int)stopsLevelLong;

        if(stopsLevel > 0)
        {
            double currentPrice = (request.orderType == ORDER_TYPE_BUY) ?
                                 SymbolInfoDouble(request.symbol, SYMBOL_ASK) :
                                 SymbolInfoDouble(request.symbol, SYMBOL_BID);

            double minDistance = stopsLevel * point;

            if(request.stopLoss > 0)
            {
                double slDistance = MathAbs(currentPrice - request.stopLoss);
                if(slDistance < minDistance)
                {
                    errorMessage = StringFormat("Stop loss too close (Min: %.5f)", minDistance);
                    return false;
                }
            }
        }

        return true;
    }
    
    // Execute order
    TradeResult ExecuteOrder(TradeRequest &request, int attempt)
    {
        TradeResult result;
        bool success = false;
        
        // Normalize prices
        request.stopLoss = NormalizePrice(request.symbol, request.stopLoss);
        request.takeProfit = NormalizePrice(request.symbol, request.takeProfit);
        
        // Execute based on order type
        if(request.orderType == ORDER_TYPE_BUY)
        {
            success = m_trade.Buy(request.volume, request.symbol, 0, 
                                 request.stopLoss, request.takeProfit, request.comment);
        }
        else if(request.orderType == ORDER_TYPE_SELL)
        {
            success = m_trade.Sell(request.volume, request.symbol, 0, 
                                  request.stopLoss, request.takeProfit, request.comment);
        }
        
        // Process result
        result.success = success;
        result.retcode = m_trade.ResultRetcode();
        result.message = m_trade.ResultRetcodeDescription();
        
        if(success)
        {
            result.ticket = m_trade.ResultOrder();
            result.executedPrice = m_trade.ResultPrice();
            result.executedVolume = m_trade.ResultVolume();
        }
        
        return result;
    }
};
//+------------------------------------------------------------------+