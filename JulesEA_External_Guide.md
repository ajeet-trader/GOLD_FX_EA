# JulesEA - Phase 1 External Compilation and Testing Guide

## Overview
This document provides step-by-step instructions on how to setup the environment, compile, and test the **JulesEA** Expert Advisor. Since the development environment was Linux-based without a functional MetaTrader 5 compiler, these steps must be performed on a Windows machine or a fully configured Wine environment with MetaTrader 5 installed.

## File Structure
Ensure the files are placed in the correct directories within your MetaTrader 5 Data Folder. You can find the Data Folder in MT5 by going to **File -> Open Data Folder**.

| File Path | Description |
|-----------|-------------|
| `MQL5/Experts/JulesEA/JulesEA.mq5` | The main Expert Advisor file. Entry point. |
| `MQL5/Include/JulesEA/EAEngine.mqh` | Core engine managing the EA lifecycle. |
| `MQL5/Include/JulesEA/Logger.mqh` | Logging utility (File & Print). |
| `MQL5/Include/JulesEA/IndicatorManager.mqh` | Manager for technical indicators. |
| `MQL5/Include/JulesEA/RiskManager.mqh` | Risk management logic (Position sizing, Drawdown). |
| `MQL5/Include/JulesEA/TradeExecutor.mqh` | Order execution wrapper (Retry logic, Slippage). |
| `MQL5/Include/JulesEA/StrategyDispatcher.mqh` | Handles strategy registration and tick processing. |

## Prerequisites
1.  **MetaTrader 5 (MT5)** installed (latest version recommended).
2.  **MetaEditor 5** (usually comes with MT5).

## Installation Steps

1.  **Open Data Folder**: Launch MT5, go to `File` > `Open Data Folder`.
2.  **Copy Files**:
    *   Create a folder `JulesEA` inside `MQL5/Experts/`.
    *   Copy `JulesEA.mq5` into `MQL5/Experts/JulesEA/`.
    *   Create a folder `JulesEA` inside `MQL5/Include/`.
    *   Copy all `.mqh` files into `MQL5/Include/JulesEA/`.

    *Structure should look like:*
    ```text
    MQL5/
    ├── Experts/
    │   └── JulesEA/
    │       └── JulesEA.mq5
    └── Include/
        └── JulesEA/
            ├── EAEngine.mqh
            ├── IndicatorManager.mqh
            ├── Logger.mqh
            ├── RiskManager.mqh
            ├── StrategyDispatcher.mqh
            └── TradeExecutor.mqh
    ```

## Compilation

1.  Open **MetaEditor** (F4 from MT5).
2.  In the Navigator, locate `Experts/JulesEA/JulesEA.mq5`.
3.  Double-click to open it.
4.  Click **Compile** (or press F7).
5.  **Verify**: Check the "Errors" tab at the bottom. It should say `0 errors, 0 warnings` (or minimal warnings).
    *   *Note*: If you see errors related to missing standard libraries (e.g. `<Trade\Trade.mqh>`), ensure your MT5 installation is complete. These are standard MQL5 libraries.

## Testing Phase 1 (Core Framework)

To verify that the Phase 1 requirements are met (Framework works, MA Strategy trades), perform the following:

### 1. Strategy Tester (Backtest)
1.  In MT5, press `Ctrl+R` to open the **Strategy Tester**.
2.  **Settings**:
    *   **Expert**: `Experts\JulesEA\JulesEA.ex5`
    *   **Symbol**: `EURUSD` (or any major pair)
    *   **Timeframe**: `H1` (1 Hour)
    *   **Date**: Last Year (e.g., Last Month or custom period)
    *   **Delay**: Zero latency (ideal) or specific delay.
    *   **Modeling**: "Every tick" (for precise logic check) or "1 minute OHLC" (faster).
3.  Click **Start**.
4.  **Observation**:
    *   Watch the **Graph** tab: Does equity change? (Trades are happening).
    *   Watch the **Journal** tab: Look for logs starting with `[INFO] [SimpleMAStrategy]`.
    *   Check for `[CRITICAL]` or `[ERROR]` logs in the Journal.

### 2. Live/Demo Test
1.  Open a chart (e.g., EURUSD H1).
2.  Drag `JulesEA` from the Navigator onto the chart.
3.  Ensure "Allow Algo Trading" is enabled in the toolbar and in the EA properties (Common tab).
4.  **Verification**:
    *   Check the **Experts** tab in the Toolbox (`Ctrl+T`). You should see:
        *   `[...] [INFO] [EAEngine::Initialize] Initialization complete.`
    *   If the market is open and conditions are met (MA Cross), a trade should open.
    *   Check `MQL5/Files/JulesEA_Log.csv` (or Common Files if configured) to see the file logs being written.

## Troubleshooting

*   **"File Open Failed"**: If logging fails, check permissions or disk space. The default is `MQL5/Files/JulesEA_Log.csv`.
*   **"Trade Error"**: If trades fail (Retcode 10004 etc.), check if AutoTrading is enabled and if the account has sufficient balance.
*   **"Invalid Handle"**: If indicators fail, ensure data exists for the symbol/timeframe.

## Next Steps (Phase 2)
Once Phase 1 is verified:
1.  Implement specific Strategy classes (e.g., `Forex/EURUSD/TrendFollowing.mqh`) inheriting from `CStrategyBase`.
2.  Register them in `OnInit` or via a configuration file loader.
