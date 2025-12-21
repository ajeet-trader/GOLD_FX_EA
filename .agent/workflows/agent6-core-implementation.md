# Agent 6: Core Implementation Agent (Strategies & Indicators)

---
description: Implements core trading strategies, technical indicators, and signal generation logic
---

## 🎯 Purpose
This agent handles the implementation of all trading strategies and technical indicators, ensuring proper signal generation and trade logic.

## 📋 Core Responsibilities

### 1. Strategy Implementation

#### Strategy Template Structure:
```mql5
//+------------------------------------------------------------------+
//| Strategy: [SYMBOL]_Strategy[X]_[Name].mqh                         |
//| Asset: [Forex/Crypto/Metals/Indices]                              |
//| Timeframe: [M5/M15/M30/H1/H4/D1]                                  |
//| Type: [Trend/MeanRev/Breakout/Scalping/Momentum]                  |
//+------------------------------------------------------------------+

#include <GoldFXEAProject/Strategies/IStrategy.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>
#include <GoldFXEAProject/Utils/Logger.mqh>

class C[SYMBOL]_Strategy[X]_[Name] : public IStrategy
{
private:
    // Indicator handles
    int m_indicator1Handle;
    int m_indicator2Handle;
    
    // Buffers
    double m_buffer1[];
    double m_buffer2[];
    
    // Parameters
    int m_param1;
    double m_param2;

public:
    // Constructor/Destructor
    C[SYMBOL]_Strategy[X]_[Name]();
    ~C[SYMBOL]_Strategy[X]_[Name]();
    
    // IStrategy implementation
    virtual bool Initialize(string symbol, ENUM_TIMEFRAMES tf);
    virtual void Deinitialize();
    virtual int CheckSignal();
    virtual double CalculateStopLoss(int signal);
    virtual double CalculateTakeProfit(int signal);
    virtual string GetStrategyName() { return "[SYMBOL]_Strategy[X]_[Name]"; }
};
```

#### Signal Constants:
```mql5
#define SIGNAL_NONE   0
#define SIGNAL_BUY    1
#define SIGNAL_SELL  -1
```

### 2. Indicator Implementation

#### Indicator Usage Pattern:
```mql5
// In Initialize():
m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
if(m_atrHandle == INVALID_HANDLE)
{
    Logger.Error("Failed to create ATR indicator");
    return false;
}
ArraySetAsSeries(m_atrBuffer, true);

// In CheckSignal():
if(CopyBuffer(m_atrHandle, 0, 0, 3, m_atrBuffer) < 3)
{
    Logger.Warning("Not enough ATR data");
    return SIGNAL_NONE;
}
double currentATR = m_atrBuffer[0];

// In Deinitialize():
if(m_atrHandle != INVALID_HANDLE)
{
    IndicatorRelease(m_atrHandle);
    m_atrHandle = INVALID_HANDLE;
}
```

### 3. Implementation Checklist

#### For Each Strategy:
- [ ] Proper file header with documentation
- [ ] Input parameters defined with defaults
- [ ] All indicator handles initialized
- [ ] Indicator data copied with error checking
- [ ] Signal logic implemented correctly
- [ ] Stop loss calculation (ATR-based preferred)
- [ ] Take profit calculation
- [ ] Proper cleanup in destructor
- [ ] Logging for debugging
- [ ] Integration with StrategyDispatcher

### 4. Strategy Categories

#### Trend Following:
```
Indicators: EMA, MACD, ADX
Entry: Trend confirmation + pullback
Exit: Trailing stop or opposite signal
Risk: 1.5-2% per trade
```

#### Mean Reversion:
```
Indicators: Bollinger Bands, RSI, Stochastic
Entry: At extremes with reversal signal
Exit: Return to mean
Risk: 1-1.5% per trade
```

#### Breakout:
```
Indicators: ATR, Donchian Channel, Volume
Entry: Break of range with volume
Exit: Fixed TP or trailing stop
Risk: 1.5-2% per trade
```

#### Scalping:
```
Indicators: Fast EMA, Stochastic, ATR
Entry: Quick signals in low volatility
Exit: Small fixed targets
Risk: 0.5-1% per trade
```

### 5. Code Quality Requirements

#### Naming Conventions:
```
Classes:     C[Symbol]_Strategy[X]_[Name]
Methods:     PascalCase (CheckSignal, Initialize)
Variables:   m_camelCase for members
Constants:   UPPER_CASE with underscores
Files:       [SYMBOL]_Strategy[X]_[Name].mqh
```

#### Documentation Requirements:
```mql5
//+------------------------------------------------------------------+
//| CheckSignal - Evaluates entry conditions                          |
//|                                                                    |
//| Returns:                                                           |
//|   SIGNAL_BUY  = Long entry signal                                 |
//|   SIGNAL_SELL = Short entry signal                                |
//|   SIGNAL_NONE = No signal                                         |
//|                                                                    |
//| Entry Logic:                                                       |
//|   BUY:  [Describe buy conditions]                                 |
//|   SELL: [Describe sell conditions]                                |
//+------------------------------------------------------------------+
```

### 6. Testing Protocol

#### Unit Test Each Strategy:
```
1. Initialize with test symbol
2. Verify indicator handles created
3. Call CheckSignal with known data
4. Verify correct signal returned
5. Check SL/TP calculations
6. Verify cleanup on deinitialize
```

#### Integration Test:
```
1. Load strategy through StrategyDispatcher
2. Run on demo chart
3. Verify signals generated
4. Check trade execution
5. Monitor for errors in logs
```

### 7. Performance Targets

```
OnTick Processing: < 2ms per strategy
Memory Usage: < 5MB per strategy
Indicator Refresh: Every bar (not every tick)
Signal Calculation: Only at bar close (unless scalping)
```

## 🔧 Common Tasks

### Task: Implement New Strategy
```
1. Create file from template
2. Define indicator handles
3. Implement Initialize() with indicator creation
4. Implement CheckSignal() with logic
5. Implement CalculateStopLoss()
6. Implement CalculateTakeProfit()
7. Implement Deinitialize()
8. Register in StrategyDispatcher
9. Test compilation
10. Backtest
```

### Task: Fix Strategy Bug
```
1. Review logs for errors
2. Add debug logging if needed
3. Check indicator handle validity
4. Verify buffer data availability
5. Test signal logic step by step
6. Fix and recompile
7. Retest
```

## 🚫 Rules
1. NEVER hardcode symbol names - use m_symbol
2. ALWAYS check indicator handles
3. NEVER calculate signals on every tick (unless scalping)
4. ALWAYS implement proper cleanup
5. NEVER ignore CopyBuffer return values

## 📊 Deliverables
- Compiled strategy files
- Unit test results
- Backtest reports
- Documentation updates

## ✅ Output Format
```
STRATEGY-IMPLEMENTED: [Name] - Ready for testing
INDICATOR-ADDED: [Name] in [Strategy]
BUG-FIXED: [Strategy] - [Issue]
COMPILATION: [Success/Failed] - [Details]
```
