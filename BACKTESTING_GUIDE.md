# Automated Backtesting Guide

## Overview
This project includes a Python-based automation system that streamlines the backtesting process for the Gold FX EA. Instead of manually running the Strategy Tester for each strategy, this system:
1.  Automatically configures MT5 for each strategy.
2.  Runs the backtests sequentially.
3.  Detects when a backtest is complete by monitoring report generation.
4.  Saves the HTML reports and automatically converts them to Excel (XLSX) format.
5.  Organizes everything in the `Backtest_Reports` folder.

## Prerequisites
Before running the automation, ensure you have:
1.  **MetaTrader 5 (MT5)** installed and logged in (to ensure historical data is available).
2.  **Python 3.x** installed.
3.  **Required Python Libraries**:
    Run this command to install dependencies:
    ```bash
    pip install pandas openpyxl MetaTrader5 lxml
    ```

## Project Structure
*   `automation/automate_backtest.py`: The main script that controls the entire process.
*   `Backtest_Reports/`: The output folder where all HTML and XLSX reports are saved.
*   `Experts/...`: Your compiled EA (`.ex5`) must be present here.

## How It Works (The Logic)
The automation follows these steps for every strategy defined in the script:

1.  **Cleanup**: Checks for and removes any existing reports to avoid false positives.
2.  **Configuration**: Creates a temporary `.ini` file containing the settings for the current strategy (Symbol, Period, Date Range, Specific Strategy Inputs).
3.  **Execution**: Launches MT5 in "Headless" mode (or standard mode with arguments) pointing to the `.ini` file.
    *   *Technical Note*: The script instructs MT5 to save the report using a relative filename. This forces MT5 to write to its internal "Data Folder" (bypassing permission issues with external drives).
4.  **Monitoring**: The script enters a loop, checking every few seconds if the report file has been generated in the MT5 Data Folder.
5.  **Processing**:
    *   Once the report is detected, the script moves it from the MT5 Data Folder to your local `Backtest_Reports` folder.
    *   It then converts the HTML table data into a clean Excel (`.xlsx`) file.
6.  **Completion**: Closes the MT5 terminal (if it didn't close itself) and proceeds to the next strategy.

## How to Run
1.  Open your terminal/command prompt in the project root.
2.  Run the script:
    ```bash
    python automation/automate_backtest.py
    ```
3.  The script will print its progress to the console.

## Adding/Modifying Strategies
To add a new strategy or change parameters:
1.  Open `automation/automate_backtest.py`.
2.  Locate the `STRATEGIES` list near the top of the file.
3.  Add a new dictionary entry:
    ```python
    {
        "name": "My_New_Strategy",
        "symbol": "XAUUSDm",
        "inputs": "Enable_My_Strategy=true||Other_Param=123"
    }
    ```
    *   **inputs**: This string is critical. It sets the specific input parameters for the EA. Use `||` to separate multiple inputs.

## Troubleshooting
*   **"Report not found"**: Ensure MT5 is logged in and has history data for the requested dates.
*   **MT5 opens but does nothing**: Check the `Journal` tab in MT5 for errors (often "History not found" or "Invalid license").
*   **Conversion fails**: Ensure `lxml` is installed (`pip install lxml`).

---
Generated for Gold FX EA Project.
