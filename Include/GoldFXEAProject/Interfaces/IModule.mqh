//+------------------------------------------------------------------+
//|                                                      IModule.mqh  |
//|                                  JULES Trading Systems            |
//+------------------------------------------------------------------+
#property copyright "JULES Trading Systems"
#property link      "https://julestrading.com"

#include <GoldFXEAProject/Common/Common.mqh>

//+------------------------------------------------------------------+
//| IModule Interface                                                |
//| Base interface for all EA modules                                |
//+------------------------------------------------------------------+
class IModule
{
protected:
    string m_moduleName;
    ENUM_MODULE_STATUS m_status;
    string m_lastError;
    
public:
    // Constructor
    IModule(string moduleName)
    {
        m_moduleName = moduleName;
        m_status = MODULE_STATUS_UNINITIALIZED;
        m_lastError = "";
    }
    
    // Virtual destructor
    virtual ~IModule() {}
    
    // Pure virtual methods that must be implemented
    virtual bool Initialize() = 0;
    virtual void ProcessTick(MqlTick &tick) = 0;
    virtual void Deinitialize() = 0;
    
    // Common methods
    virtual string GetModuleName() const { return m_moduleName; }
    virtual ENUM_MODULE_STATUS GetStatus() const { return m_status; }
    virtual string GetLastError() const { return m_lastError; }
    virtual string GetModuleInfo() = 0;
    
    // Status management
    virtual void SetStatus(ENUM_MODULE_STATUS status) { m_status = status; }
    virtual bool IsInitialized() const { return m_status == MODULE_STATUS_INITIALIZED || m_status == MODULE_STATUS_RUNNING; }
    virtual bool IsRunning() const { return m_status == MODULE_STATUS_RUNNING; }
    virtual bool HasError() const { return m_status == MODULE_STATUS_ERROR; }
    
protected:
    // Set error message
    virtual void SetError(string error)
    {
        m_lastError = error;
        m_status = MODULE_STATUS_ERROR;
    }
    
    // Clear error
    virtual void ClearError()
    {
        m_lastError = "";
        if(m_status == MODULE_STATUS_ERROR)
            m_status = MODULE_STATUS_INITIALIZED;
    }
};
//+------------------------------------------------------------------+