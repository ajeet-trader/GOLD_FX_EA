# 🚀 GoldFXEA Phase 1 - Complete Setup and Testing Guide

## 📋 Document Overview

This comprehensive guide covers:
- Complete file structure and organization
- Step-by-step installation from scratch
- Compilation instructions
- Testing protocols
- Troubleshooting common issues

---

## 📁 Phase 1 File Structure

### Complete Directory Layout

```
MQL5/
├── Experts/
│   └── GOLDFXEA_Experts/
│       └── GoldFXEA.mq5                    # Main EA file
│
├── Include/
│   └── GoldFXEAProject/
│       ├── Common/
│       │   └── Common.mqh                  # Common definitions, enums, structs
│       │
│       ├── Interfaces/
│       │   └── IModule.mqh                 # Base module interface
│       │
│       ├── Utils/
│       │   └── Logger.mqh                  # Logging system
│       │
│       └── Core/
│           ├── RiskManager.mqh             # Risk management module
│           ├── TradeExecutor.mqh           # Trade execution module
│           └── EAEngine.mqh                # Main EA engine orchestrator
│
└── Files/
    └── GoldFXEA_Logs/                      # Log files (auto-created)
        └── GoldFXEA_YYYYMMDD.log
```

---

## 📊 File Descriptions Table

| File Path | Description | Dependencies | Size Est. | Critical |
|-----------|-------------|--------------|-----------|----------|
| **Experts/GOLDFXEA_Experts/GoldFXEA.mq5** | Main EA entry point, handles MT5 events | EAEngine.mqh | ~150 lines | ✅ YES |
| **Include/GoldFXEAProject/Common/Common.mqh** | Common definitions: enums, structs, constants, utility functions | None | ~300 lines | ✅ YES |
| **Include/GoldFXEAProject/Interfaces/IModule.mqh** | Base interface for all modules (OOP pattern) | Common.mqh | ~60 lines | ✅ YES |
| **Include/GoldFXEAProject/Utils/Logger.mqh** | Multi-level logging system with file output | Common.mqh | ~250 lines | ✅ YES |
| **Include/GoldFXEAProject/Core/RiskManager.mqh** | Risk calculations, position sizing, safety limits | IModule.mqh, Logger.mqh | ~350 lines | ✅ YES |
| **Include/GoldFXEAProject/Core/TradeExecutor.mqh** | Trade execution with retry logic and validation | IModule.mqh, Logger.mqh, RiskManager.mqh | ~400 lines | ✅ YES |
| **Include/GoldFXEAProject/Core/EAEngine.mqh** | Core orchestration engine, manages all modules | All above | ~300 lines | ✅ YES |

**Total Lines of Code: ~1,810 lines**

---

## 🛠️ Step-by-Step Installation Guide

### Prerequisites

#### Required Software:
- **MetaTrader 5** (Latest version - Download from: https://www.metaquotes.net/en/metatrader5)
- **MetaEditor** (Comes bundled with MT5)
- **Windows 7 or later** (MT5 requirement)

#### Recommended:
- **Git** (For version control)
- **Text Editor** (VS Code, Notepad++, or similar)

### Installation Steps

#### Step 1: Locate Your MT5 Data Folder

1. Open **MetaTrader 5**
2. Click **File** → **Open Data Folder**
3. This will open Windows Explorer to your MT5 data directory
4. You should see folders like: `MQL5`, `Logs`, `Tester`, etc.

**Typical path**: `C:\Users\[YourName]\AppData\Roaming\MetaQuotes\Terminal\[TerminalID]\MQL5\`

#### Step 2: Create Folder Structure

1. Navigate to the `MQL5` folder
2. Create the following folder structure:

**For Experts:**
```
MQL5\Experts\GOLDFXEA_Experts\
```

**For Include files:**
```
MQL5\Include\GoldFXEAProject\
MQL5\Include\GoldFXEAProject\Common\
MQL5\Include\GoldFXEAProject\Interfaces\
MQL5\Include\GoldFXEAProject\Utils\
MQL5\Include\GoldFXEAProject\Core\
```

**For Log files** (optional - will be auto-created):
```
MQL5\Files\GoldFXEA_Logs\
```

#### Step 3: Copy Files to Correct Locations

Copy each file to its designated folder according to the table below:

| File | Destination |
|------|-------------|
| `GoldFXEA.mq5` | `MQL5\Experts\GOLDFXEA_Experts\` |
| `Common.mqh` | `MQL5\Include\GoldFXEAProject\Common\` |
| `IModule.mqh` | `MQL5\Include\GoldFXEAProject\Interfaces\` |
| `Logger.mqh` | `MQL5\Include\GoldFXEAProject\Utils\` |
| `RiskManager.mqh` | `MQL5\Include\GoldFXEAProject\Core\` |
| `TradeExecutor.mqh` | `MQL5\Include\GoldFXEAProject\Core\` |
| `EAEngine.mqh` | `MQL5\Include\GoldFXEAProject\Core\` |

**Quick Copy Command (if using Command Prompt from project folder):**
```batch
:: Create directories
mkdir "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Experts\GOLDFXEA_Experts"
mkdir "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Common"
mkdir "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Interfaces"
mkdir "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Utils"
mkdir "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Core"

:: Copy files (adjust source paths as needed)
copy GoldFXEA.mq5 "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Experts\GOLDFXEA_Experts\"
copy Common.mqh "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Common\"
copy IModule.mqh "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Interfaces\"
copy Logger.mqh "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Utils\"
copy RiskManager.mqh "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Core\"
copy TradeExecutor.mqh "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Core\"
copy EAEngine.mqh "%APPDATA%\MetaQuotes\Terminal\[YourTerminalID]\MQL5\Include\GoldFXEAProject\Core\"
```

**Note**: Replace `[YourTerminalID]` with your actual terminal ID folder name.

---

## 🔨 Compilation Instructions

### Method 1: Using MetaEditor (Recommended)

1. **Open MetaEditor**
   - In MT5, press **F4** or click **Tools** → **MetaQuotes Language Editor**

2. **Open the Main EA File**
   - In MetaEditor Navigator (left panel), expand **Experts**
   - Navigate to **GOLDFXEA_Experts** folder
   - Double-click **GoldFXEA.mq5**

3. **Compile the EA**
   - Press **F7** or click **Compile** button
   - Or: **File** → **Compile**

4. **Check Compilation Results**
   - Look at the **Toolbox** panel at the bottom
   - **Errors** tab should show: `0 error(s), 0 warning(s)`
   - If successful, you'll see:
     ```
     'GoldFXEA.ex5' successfully compiled.
     0 error(s), 0 warning(s)
     ```

5. **Verify .ex5 File Created**
   - Navigate to: `MQL5\Experts\GOLDFXEA_Experts\`
   - You should see: `GoldFXEA.ex5` (compiled executable)

### Method 2: Command Line Compilation

**For Advanced Users:**

```batch
cd /d "%APPDATA%\MetaQuotes\Terminal\[TerminalID]\MQL5"
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"Experts\GOLDFXEA_Experts\GoldFXEA.mq5" /log
```

---

## 🧪 Testing Protocols

### Phase 1 Testing Checklist

Phase 1 focuses on **Core Framework Testing** - ensuring all modules initialize, communicate, and handle errors correctly.

#### ✅ Test 1: Compilation Test

**Objective**: Ensure all files compile without errors

**Steps**:
1. Compile `GoldFXEA.mq5` (as shown above)
2. Check for 0 errors, 0 warnings

**Expected Result**:
- ✅ `GoldFXEA.ex5` created successfully
- ✅ No compilation errors
- ✅ No critical warnings

**If Failed**: See "Troubleshooting Compilation Errors" section below

---

#### ✅ Test 2: EA Initialization Test

**Objective**: Verify EA initializes all modules correctly

**Steps**:
1. Open MT5
2. Open any chart (e.g., EURUSD M15)
3. Drag `GoldFXEA` from **Navigator** → **Expert Advisors** → **GOLDFXEA_Experts** onto the chart
4. In the EA settings dialog:
   - Set **Enable Trading**: `false` (for safety)
   - Set **Enable Logging**: `true`
   - Set **Log Level**: `INFO`
   - Click **OK**

**Expected Result in Expert Tab (Ctrl+T)**:
```
╔════════════════════════════════════════════════════════════╗
║            GOLD FX EA - JULES Trading Systems             ║
║                  Phase 1: Core Framework                  ║
╚════════════════════════════════════════════════════════════╝
→ Step 1/3: Initializing Logger...
✓ Logger initialized
→ Step 2/3: Initializing Risk Manager...
✓ Risk Manager initialized
→ Step 3/3: Initializing Trade Executor...
✓ Trade Executor initialized
✓ GoldFXEA initialized successfully
✓ Trading Status: DISABLED
✓ Risk Per Trade: 1.5%
✓ Max Open Trades: 10
╔════════════════════════════════════════════════════════════╗
║        GoldFXEA Core Engine Ready For Trading             ║
╚════════════════════════════════════════════════════════════╝
```

**If Failed**: Check "Troubleshooting Runtime Errors" section

---

#### ✅ Test 3: Log File Creation Test

**Objective**: Verify logging system creates and writes to files

**Steps**:
1. With EA running, navigate to: `MQL5\Files\GoldFXEA_Logs\`
2. Find today's log file: `GoldFXEA_YYYYMMDD.log`
3. Open the log file in a text editor

**Expected Log Contents**:
```
================================================================================
GoldFXEA Session Started: 2025-12-13 10:30:45
================================================================================

[2025-12-13 10:30:45] [INFO] [Logger] Logger initialized successfully
[2025-12-13 10:30:45] [INFO] [RiskManager] Initializing Risk Manager
[2025-12-13 10:30:45] [INFO] [RiskManager] Initial Balance: 10000.00
[2025-12-13 10:30:45] [INFO] [RiskManager] Risk Per Trade: 1.50%
[2025-12-13 10:30:45] [INFO] [RiskManager] Max Daily Loss: 5.00%
[2025-12-13 10:30:45] [INFO] [RiskManager] Max Drawdown: 20.00%
[2025-12-13 10:30:46] [INFO] [TradeExecutor] Initializing Trade Executor
[2025-12-13 10:30:46] [INFO] [TradeExecutor] Magic Number: 20251213
[2025-12-13 10:30:46] [INFO] [TradeExecutor] Max Retries: 3
[2025-12-13 10:30:46] [INFO] [TradeExecutor] Slippage: 10 points
[2025-12-13 10:30:46] [INFO] [EAEngine] ═══════════════════════════════════════════════════
[2025-12-13 10:30:46] [INFO] [EAEngine] GoldFXEA Core Engine Initialized Successfully
```

**If Failed**: Check folder permissions, see troubleshooting section

---

#### ✅ Test 4: Tick Processing Test

**Objective**: Verify EA processes ticks without errors

**Steps**:
1. With EA running, observe the **Expert** tab
2. Let EA run for 1-2 minutes
3. Check for any error messages

**Expected Behavior**:
- No error messages
- Occasional debug messages if log level is DEBUG
- EA processes ticks silently (no spam in logs)

**Performance Check**:
- Every 1000 ticks, logger should show performance metrics
- Example: `Performance: Ticks=1000, AvgTime=0.234 ms`
- **Target**: AvgTime < 5ms

**If Failed**: Check "Performance Issues" troubleshooting section

---

#### ✅ Test 5: Risk Manager Functionality Test

**Objective**: Verify risk calculations work correctly

**Manual Test Script** (Run in MT5 Script):
```mql5
// Create a test script: TestRiskManager.mq5
#include <GoldFXEAProject/Utils/Logger.mqh>
#include <GoldFXEAProject/Core/RiskManager.mqh>

void OnStart()
{
    CLogger* logger = new CLogger(LOG_LEVEL_INFO, false, true);
    logger.Initialize();
    
    CRiskManager* risk = new CRiskManager(logger);
    risk.Initialize();
    risk.SetRiskParameters(2.0, 5.0, 20.0, 10);
    
    // Test lot size calculation
    double lots = risk.CalculateLotSize("EURUSD", 500); // 50 pips SL
    Print("Calculated lot size for 50 pip SL: ", lots);
    
    // Test trade permission
    string reason;
    bool canTrade = risk.CanOpenNewTrade("EURUSD", lots, reason);
    Print("Can open trade: ", (canTrade ? "YES" : "NO"), " Reason: ", reason);
    
    delete risk;
    delete logger;
}
```

**Expected Output**:
```
Calculated lot size for 50 pip SL: 0.04
Can open trade: YES Reason: Trade allowed
```

---

#### ✅ Test 6: Module Deinitialization Test

**Objective**: Ensure clean shutdown without memory leaks

**Steps**:
1. Remove EA from chart (drag EA off the chart or close chart)
2. Check **Expert** tab for shutdown messages

**Expected Output**:
```
╔════════════════════════════════════════════════════════════╗
║              GoldFXEA Shutdown Initiated                   ║
╚════════════════════════════════════════════════════════════╝
Deinitialize Reason: Expert removed from chart
✓ GoldFXEA deinitialized successfully
```

**In Log File**:
```
[2025-12-13 11:45:20] [INFO] [EAEngine] ═══════════════════════════════════════════════════
[2025-12-13 11:45:20] [INFO] [EAEngine] GoldFXEA Core Engine Shutting Down
[2025-12-13 11:45:20] [INFO] [EAEngine] Total Ticks Processed: 4523
[2025-12-13 11:45:20] [INFO] [EAEngine] Avg OnTick Time: 0.287 ms
[2025-12-13 11:45:20] [INFO] [TradeExecutor] Trade Executor shutting down
[2025-12-13 11:45:20] [INFO] [RiskManager] Risk Manager shutting down
[2025-12-13 11:45:20] [INFO] [Logger] Logger shutting down

================================================================================
GoldFXEA Session Ended: 2025-12-13 11:45:20
================================================================================
```

---

### Advanced Testing (Optional)

#### Test 7: Strategy Tester Validation

**Objective**: Run EA in backtester to verify basic functionality

**Steps**:
1. Press **Ctrl+R** to open Strategy Tester
2. Select **Expert Advisor**: `GOLDFXEA_Experts\GoldFXEA`
3. Settings:
   - **Symbol**: EURUSD
   - **Period**: H1
   - **Date Range**: Last 1 month
   - **Deposit**: 10000
   - **Leverage**: 1:100
4. **Inputs**:
   - **Enable Trading**: `false` (no strategies yet)
   - **Enable Logging**: `true`
5. Click **Start**

**Expected Result**:
- EA initializes successfully
- Processes all ticks without errors
- Shows 0 trades (trading disabled, no strategies)
- Log file shows proper initialization and shutdown

---

## 🐛 Troubleshooting Guide

### Compilation Errors

#### Error: "Cannot open include file 'GoldFXEAProject/...'"

**Cause**: Incorrect folder structure

**Solution**:
1. Verify `Include\GoldFXEAProject\` folder exists
2. Check all subfolders: `Common`, `Interfaces`, `Utils`, `Core`
3. Ensure `.mqh` files are in correct subfolders
4. Case sensitivity: Folder names must match exactly

#### Error: "Undeclared identifier"

**Cause**: Missing or incorrectly ordered include statements

**Solution**:
1. Check that all `#include` statements in files match the file structure
2. Verify `Common.mqh` is included before other files
3. Ensure `IModule.mqh` is included before modules that inherit from it

#### Error: "Cannot convert from 'void' to 'bool'"

**Cause**: Function return type mismatch

**Solution**:
1. Check function declarations match implementations
2. Verify all functions return correct types
3. Look for missing `return` statements

### Runtime Errors

#### Error: "EA not initializing - returns INIT_FAILED"

**Diagnostic Steps**:
1. Check **Expert** tab for error messages
2. Review log file for specific error
3. Common causes:
   - Account balance = 0 (use demo account)
   - Invalid symbol on chart
   - MT5 permissions issue

**Solution**:
```mql5
// Add more detailed error logging in EAEngine::Initialize()
if(m_logger == NULL)
{
    Print("DEBUG: Logger creation failed - possible memory issue");
    Print("DEBUG: Free memory: ", MQL5InfoInteger(MQL5_MEMORY_FREE));
    return false;
}
```

#### Error: "Access denied" when creating log file

**Cause**: File system permissions

**Solution**:
1. Run MT5 as Administrator (right-click → Run as Administrator)
2. Check Windows folder permissions for MT5 data folder
3. Temporarily disable antivirus to test
4. Alternative: Disable file logging in EA inputs

### Performance Issues

#### Issue: OnTick processing time > 5ms

**Diagnostic**:
1. Check log for "Slow OnTick" warnings
2. Review `Avg OnTick Time` in shutdown log

**Solutions**:
- **If > 10ms**: Check for blocking operations (file I/O, Sleep())
- **If random spikes**: Network latency, check broker connection
- **If consistent**: Optimize code (Phase 8 task)

#### Issue: Memory usage increasing over time

**Diagnostic**:
1. Use Windows Task Manager to monitor `terminal64.exe` memory
2. Run EA for extended period (8+ hours)
3. Check if memory grows continuously

**Solution**:
```mql5
// Add memory tracking to EAEngine
void OnTick(MqlTick &tick)
{
    if(m_tickCount % 10000 == 0)
    {
        ulong memUsed = MQL5InfoInteger(MQL5_MEMORY_USED);
        m_logger.Debug(StringFormat("Memory: %llu KB", memUsed / 1024), "EAEngine");
    }
    // ... rest of OnTick
}
```

---

## ✅ Phase 1 Success Criteria

Phase 1 is complete when ALL of the following are verified:

- [x] All files compile without errors or warnings
- [x] EA initializes all three modules successfully
- [x] Logger creates log files and writes entries
- [x] Risk Manager calculates position sizes correctly
- [x] Trade Executor validates trade requests (tested manually)
- [x] EA processes ticks with avg time < 5ms
- [x] No memory leaks detected over 8-hour run
- [x] EA deinitializes cleanly without crashes
- [x] Log files contain complete session information
- [x] All tests pass 3 consecutive times

---

## 📝 Testing Checklist Summary

| Test | Status | Notes |
|------|--------|-------|
| 1. Compilation | ⬜ | 0 errors, 0 warnings |
| 2. EA Initialization | ⬜ | All modules init |
| 3. Log File Creation | ⬜ | File exists and populated |
| 4. Tick Processing | ⬜ | No errors, <5ms avg |
| 5. Risk Manager | ⬜ | Calculations correct |
| 6. Deinitialization | ⬜ | Clean shutdown |
| 7. Strategy Tester (Optional) | ⬜ | Backtest successful |

**Completion Date**: _______________  
**Tested By**: _______________  
**Build Version**: 1.0.0

---

## 🎯 Next Steps After Phase 1

Once all tests pass:

1. **Commit to Version Control**
   ```bash
   git add .
   git commit -m "Phase 1 Complete: Core Framework Implemented"
   git tag v1.0.0-phase1
   ```

2. **Document Known Issues** (if any)
   - Create `KNOWN_ISSUES.md`
   - List any minor issues or future improvements

3. **Prepare for Phase 2**
   - Review Phase 2 requirements (Strategy Foundation)
   - Set up development environment for indicators
   - Plan first strategy implementation (EURUSD Trend Following)

4. **Backup Your Work**
   - Backup entire `MQL5\Experts\GOLDFXEA_Experts\` folder
   - Backup `MQL5\Include\GoldFXEAProject\` folder
   - Store backups securely (cloud, external drive)

---

## 📞 Support and Resources

### Official Documentation
- **MQL5 Reference**: https://www.mql5.com/en/docs
- **MetaTrader 5 Help**: Press F1 in MT5

### Community Resources
- **MQL5 Forum**: https://www.mql5.com/en/forum
- **MQL5 Code Base**: https://www.mql5.com/en/code

### Project-Specific
- **Master Prompt**: `jules_master_prompt.md`
- **Strategy Definitions**: `Define strategies for a multi-asset, multi-timeframe trading EA.md`

---

## 📄 Appendix: Quick Command Reference

### Useful MT5 Shortcuts

| Action | Shortcut |
|--------|----------|
| Open MetaEditor | F4 |
| Compile | F7 |
| Strategy Tester | Ctrl+R |
| Data Folder | File → Open Data Folder |
| Terminal Window | Ctrl+T |

### File Paths Quick Reference

```
Main EA:
%APPDATA%\MetaQuotes\Terminal\[ID]\MQL5\Experts\GOLDFXEA_Experts\GoldFXEA.mq5

Include Files:
%APPDATA%\MetaQuotes\Terminal\[ID]\MQL5\Include\GoldFXEAProject\

Log Files:
%APPDATA%\MetaQuotes\Terminal\[ID]\MQL5\Files\GoldFXEA_Logs\
```

---

## 🎉 Conclusion

Congratulations! By following this guide, you have:

✅ Set up the complete Phase 1 folder structure  
✅ Installed all core framework files  
✅ Compiled the GoldFXEA Expert Advisor  
✅ Tested all core modules  
✅ Verified logging, risk management, and trade execution foundations  

**Phase 1 Status**: Core Framework Complete ✅

You are now ready to proceed to **Phase 2: Multi-Strategy Foundation** where you will implement your first trading strategies!

---

*Document Version: 1.0*  
*Last Updated: December 13, 2025*  
*Phase: 1 - Core Framework*

**JULES Trading Systems** © 2025