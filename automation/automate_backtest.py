import MetaTrader5 as mt5
import os
import time
import shutil
import pandas as pd
from datetime import datetime
import subprocess

# --- Configuration ---
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MT5_DATA_DIR = r"C:\Users\gupta\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
MQL5_DIR = os.path.join(MT5_DATA_DIR, "MQL5")
EXPERTS_DIR = os.path.join(MQL5_DIR, "Experts")
INCLUDE_DIR = os.path.join(MQL5_DIR, "Include")

# EA Path relative to MQL5/Experts
EA_REL_PATH = r"GOLDFXEA_Experts\GoldFXEA.ex5"
EA_SOURCE_REL_PATH = r"GOLDFXEA_Experts\GoldFXEA.mq5"
EA_PATH = EA_REL_PATH # For config file

OUTPUT_DIR = os.path.join(PROJECT_ROOT, "Backtest_Reports")

# Strategy Definitions
# Based on EA comments:
# EnableTrendFollowing = true;       // Trend Following (EURUSD, H1)
# EnableBreakout = false;            // Breakout (GBPUSD, M30)
# EnableMeanReversion = false;       // Momentum (BTCUSD, M30)
# EnableScalping = false;            // Scalping (XAUUSD, M15)
# EnableIndices = false;             // Mean Reversion (SP500, H1)

STRATEGIES = [
    {"name": "EURUSD_Strategy1_EMA_RSI", "symbol": "EURUSD", "period": "H1", "input": "Enable_EURUSD_Strat1"},
    {"name": "EURUSD_Strategy2_Bollinger_MeanRev", "symbol": "EURUSD", "period": "M30", "input": "Enable_EURUSD_Strat2"},
    {"name": "EURUSD_Strategy3_ADX_Trend", "symbol": "EURUSD", "period": "H1", "input": "Enable_EURUSD_Strat3"},
    {"name": "GBPUSD_Strategy1_Fib_Pullback", "symbol": "GBPUSD", "period": "H4", "input": "Enable_GBPUSD_Strat1"},
    {"name": "GBPUSD_Strategy2_RSI_MeanRev", "symbol": "GBPUSD", "period": "M30", "input": "Enable_GBPUSD_Strat2"},
    {"name": "GBPUSD_Strategy3_London_Breakout", "symbol": "GBPUSD", "period": "M15", "input": "Enable_GBPUSD_Strat3"},
    {"name": "USDJPY_Strategy1_ADX_Trend", "symbol": "USDJPY", "period": "H4", "input": "Enable_USDJPY_Strat1"},
    {"name": "USDJPY_Strategy2_Carry_Trade", "symbol": "USDJPY", "period": "D1", "input": "Enable_USDJPY_Strat2"},
    # Metals
    {"name": "XAUUSD_Strategy1_ADX_Trend", "symbol": "XAUUSD", "period": "H1", "input": "Enable_XAUUSD_Strat1"},
    {"name": "XAUUSD_Strategy2_Bollinger_MeanReversion", "symbol": "XAUUSD", "period": "M15", "input": "Enable_XAUUSD_Strat2"},
    {"name": "XAUUSD_Strategy3_Keltner_Scalp", "symbol": "XAUUSD", "period": "M5", "input": "Enable_XAUUSD_Strat3"},
    # Remaining Forex
    {"name": "EURGBP_Strategy1_SMA_Trend", "symbol": "EURGBP", "period": "H4", "input": "Enable_EURGBP_Strat1"},
    {"name": "AUDUSD_Strategy1_Breakout_MeanReversion", "symbol": "AUDUSD", "period": "H1", "input": "Enable_AUDUSD_Strat1"},
]

# Backtest Settings
DEPOSIT = 10000
LEVERAGE = "1:100"
EXECUTION_MODE = 0  # 0: Normal, 1: Random delay, 2: Random delay and slippage
MODEL = 1  # 0: Every tick, 1: 1 minute OHLC, 2: Open prices only, 3: Math calculations, 4: Every tick based on real ticks
OPTIMIZATION = 0  # 0: Disabled
FROM_DATE = "2024.01.01"
TO_DATE = "2024.12.31"

def get_terminal_path():
    """Initialize MT5 and get the terminal executable path."""
    # Try default location first to avoid initializing if possible
    default_path = r"C:\Program Files\MetaTrader 5\terminal64.exe"
    if os.path.exists(default_path):
        return default_path

    if not mt5.initialize():
        print("MetaTrader5 initialization failed")
        return None
    
    terminal_info = mt5.terminal_info()
    path = terminal_info.path
    mt5.shutdown()
    
    # Check if path points to executable or directory
    if os.path.isdir(path):
        path = os.path.join(path, "terminal64.exe")
        
    if not os.path.exists(path):
        print(f"Warning: Terminal executable not found at {path}")
        
    return path

def get_metaeditor_path(terminal_path):
    """Get MetaEditor path based on terminal path."""
    return os.path.join(os.path.dirname(terminal_path), "metaeditor64.exe")

def copy_source_code():
    """Copy source code from project to MT5 data folder."""
    print("Copying source code to MT5 Data Folder...")
    
    # Copy Experts
    src_experts = os.path.join(PROJECT_ROOT, "Experts", "GOLDFXEA_Experts")
    dst_experts = os.path.join(EXPERTS_DIR, "GOLDFXEA_Experts")
    
    if os.path.exists(src_experts):
        if os.path.exists(dst_experts):
            shutil.rmtree(dst_experts)
        shutil.copytree(src_experts, dst_experts)
        print(f"Copied Experts to {dst_experts}")
    else:
        print(f"Error: Source Experts not found at {src_experts}")
        return False

    # Copy Include
    src_include = os.path.join(PROJECT_ROOT, "Include", "GoldFXEAProject")
    dst_include = os.path.join(INCLUDE_DIR, "GoldFXEAProject")
    
    if os.path.exists(src_include):
        if os.path.exists(dst_include):
            shutil.rmtree(dst_include)
        shutil.copytree(src_include, dst_include)
        print(f"Copied Include to {dst_include}")
    else:
        print(f"Error: Source Include not found at {src_include}")
        return False
        
    return True

def compile_ea(metaeditor_path):
    """Compile the EA using MetaEditor."""
    print("Compiling EA...")
    
    mq5_path = os.path.join(EXPERTS_DIR, EA_SOURCE_REL_PATH)
    log_path = os.path.join(OUTPUT_DIR, "compile.log")
    
    if not os.path.exists(mq5_path):
        print(f"Error: EA source file not found at {mq5_path}")
        return False
        
    cmd = f'"{metaeditor_path}" /compile:"{mq5_path}" /log:"{log_path}"'
    print(f"Running: {cmd}")
    
    process = subprocess.Popen(cmd, shell=True)
    process.wait()
    
    # Check if compilation was successful by checking if .ex5 exists and is newer than .mq5
    ex5_path = os.path.splitext(mq5_path)[0] + ".ex5"
    
    if os.path.exists(ex5_path):
        mq5_time = os.path.getmtime(mq5_path)
        ex5_time = os.path.getmtime(ex5_path)
        
        if ex5_time > mq5_time:
            print("Compilation successful.")
            return True
    
    print("Compilation failed. Check log:")
    if os.path.exists(log_path):
        with open(log_path, 'r', encoding='utf-16') as f: # MT5 logs are often UTF-16
            try:
                print(f.read())
            except:
                # Try default encoding if utf-16 fails
                 with open(log_path, 'r') as f2:
                    print(f2.read())
    return False


def create_ini_file(strategy_name, symbol, period, active_inputs, report_path):
    """Create a configuration .ini file for the backtest."""
    
    # Base inputs - all false initially
    inputs = {s["input"]: "false" for s in STRATEGIES}
    
    # Enable specific inputs
    for inp in active_inputs:
        inputs[inp] = "true"
        
    # Other EA inputs (defaults)
    inputs["EnableTrading"] = "true"
    inputs["EnableLogging"] = "true"
    
    # Use C:\Temp for reliability
    safe_report_dir = r"C:\Temp\BacktestReports"
    if not os.path.exists(safe_report_dir):
        try:
            os.makedirs(safe_report_dir)
        except:
            safe_report_dir = r"C:\Temp"
            if not os.path.exists(safe_report_dir):
                os.makedirs(safe_report_dir)

    safe_report_path = os.path.join(safe_report_dir, f"{strategy_name}.html")
    
    print(f"Configuring report generation at: {safe_report_path}")
    
    # Use relative path for report to ensure it saves in MT5 Data Folder
    report_filename = os.path.basename(safe_report_path)
    
    ini_content = f"""
[Tester]
Expert={EA_PATH}
Symbol={symbol}
Period={period}
Deposit={DEPOSIT}
Leverage={LEVERAGE}
Model={MODEL}
ExecutionMode={EXECUTION_MODE}
Optimization={OPTIMIZATION}
FromDate={FROM_DATE}
ToDate={TO_DATE}
Report={report_filename}
ReplaceReport=1
ShutdownTerminal=1

[TesterInputs]
"""
    for key, value in inputs.items():
        ini_content += f"{key}={value}\n"
        
    ini_path = os.path.join(safe_report_dir, f"{strategy_name}.ini")
    with open(ini_path, "w") as f:
        f.write(ini_content)
    
    # Also save a copy to project folder for reference
    try:
        project_ini = os.path.join(OUTPUT_DIR, f"{strategy_name}.ini")
        with open(project_ini, "w") as f:
            f.write(ini_content)
    except:
        pass
    
    return ini_path, safe_report_path

def kill_terminal():
    """Kill any running terminal64.exe processes."""
    try:
        subprocess.run("taskkill /IM terminal64.exe /F", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(2) # Wait for it to close
    except Exception as e:
        print(f"Error killing terminal: {e}")

def process_report(safe_report_path, strategy_name, terminal_path):
    """Find, move and convert the report."""
    # Check if file exists
    final_report_path = safe_report_path
    
    if not os.path.exists(safe_report_path):
        print(f"Report NOT found at {safe_report_path}")
        # Search in MT5 folder
        possible_locs = [
            os.path.join(os.path.dirname(terminal_path), os.path.basename(safe_report_path)),
            os.path.join(MT5_DATA_DIR, os.path.basename(safe_report_path))
        ]
        found = False
        for p in possible_locs:
            if os.path.exists(p):
                print(f"Found report at {p}")
                final_report_path = p
                found = True
                break
        if not found:
            print("Report generation failed or file not found.")
            return

    # Copy HTML report to project folder
    project_report_html = os.path.join(OUTPUT_DIR, f"{strategy_name}.html")
    
    # Check if we need to copy
    if os.path.abspath(final_report_path).lower() != os.path.abspath(project_report_html).lower():
        try:
            shutil.copy2(final_report_path, project_report_html)
            print(f"Copied HTML report to {project_report_html}")
        except Exception as e:
            print(f"Failed to copy HTML report: {e}")
    else:
        print(f"Report already in place: {project_report_html}")
        
    xlsx_file = os.path.join(OUTPUT_DIR, f"{strategy_name}.xlsx")
    convert_report_to_xlsx(final_report_path, xlsx_file)

def is_terminal_running():
    """Check if terminal64.exe is running."""
    try:
        # Run tasklist and check output
        result = subprocess.run("tasklist /FI \"IMAGENAME eq terminal64.exe\"", shell=True, capture_output=True, text=True)
        return "terminal64.exe" in result.stdout
    except:
        return False

def run_backtest(terminal_path, ini_path, report_path):
    """Run the MT5 terminal with the given config."""
    # Ensure terminal is closed before starting
    kill_terminal()
    
    # Remove existing report if any (to avoid false positives)
    if os.path.exists(report_path):
        try:
            os.remove(report_path)
        except:
            pass
            
    cmd = [terminal_path, f"/config:{ini_path}"]
    print(f"Running: {cmd}")
    process = subprocess.Popen(cmd, shell=False)
    
    # Wait for terminal to start
    time.sleep(5)
    
    print("Waiting for backtest to complete (Monitoring report generation)...")
    start_time = time.time()
    max_duration = 600 # 10 mins max per strategy
    
    report_found = False
    
    while True:
        # 1. Check if report generated
            # Check in MT5 Data Directory (primary location for relative paths)
            report_filename = os.path.basename(report_path)
            mt5_report_path = os.path.join(MT5_DATA_DIR, report_filename)
            
            if os.path.exists(mt5_report_path) and os.path.getsize(mt5_report_path) > 0:
                print(f"Report detected at {mt5_report_path}!")
                # Give it a moment to finish writing
                time.sleep(2)
                try:
                    # Move to destination
                    shutil.move(mt5_report_path, report_path)
                    print(f"Moved report to {report_path}")
                    report_found = True
                    break
                except Exception as e:
                    print(f"Error moving report: {e}")

            # Check if it appeared at destination (if absolute path worked somehow)
            if os.path.exists(report_path) and os.path.getsize(report_path) > 0:
                print(f"Report detected at {report_path}!")
                # Give it a moment to finish writing
                time.sleep(5) 
                report_found = True
                break
            
            # Check in the tester directory for any html report if the specific one is not found
            # Sometimes MT5 saves it with a different name or in the tester folder
            tester_report_path = os.path.join(os.path.dirname(ini_path), "Report.html")
            if os.path.exists(tester_report_path) and os.path.getsize(tester_report_path) > 0:
                 print(f"Report detected at {tester_report_path} (default name)!")
                 # Rename/Move it
                 try:
                     shutil.move(tester_report_path, report_path)
                     report_found = True
                     break
                 except Exception as e:
                     print(f"Error moving report: {e}")
            
            # 2. Check if terminal is still running
            if not is_terminal_running():
                print("Terminal process ended.")
                break
                
            # 3. Timeout
            if time.time() - start_time > max_duration:
                print("Timeout waiting for backtest.")
                kill_terminal()
                break
                
            time.sleep(2)
    
    if report_found:
        # If terminal is still running (it should close itself due to ShutdownTerminal=1, but if not...)
        if is_terminal_running():
            print("Report done, waiting for terminal to close self...")
            time.sleep(10)
            if is_terminal_running():
                print("Force closing terminal.")
                kill_terminal()
    else:
        print("Warning: Backtest finished but Report not found.")
    
    # Wait a bit to ensure file is written and process fully releases
    time.sleep(2) 

def convert_report_to_xlsx(report_path, xlsx_path):
    """Convert the HTML/XML report to XLSX."""
    if not os.path.exists(report_path):
        print(f"Error: Report file not found: {report_path}")
        return False
    
    try:
        # MT5 reports are often HTML tables
        # Note: MT5 HTML reports can be complex. 
        # For simplicity, we try to read tables. The "Deals" or "Orders" are usually what we want.
        # But standard Report includes a Summary table and then a list of trades.
        
        dfs = pd.read_html(report_path)
        
        # Usually the last table is the trades list or it contains "Ticket", "Time", etc.
        # We'll save all tables to different sheets
        with pd.ExcelWriter(xlsx_path, engine='openpyxl') as writer:
            for i, df in enumerate(dfs):
                sheet_name = f"Sheet{i+1}"
                # Try to identify the table
                if "Total net profit" in str(df.columns):
                    sheet_name = "Summary"
                elif "Ticket" in df.columns or "Time" in df.columns:
                    sheet_name = "Trades"
                
                df.to_excel(writer, sheet_name=sheet_name, index=False)
                
        print(f"Report saved to {xlsx_path}")
        return True
    except Exception as e:
        print(f"Failed to convert report: {e}")
        return False

def resolve_symbol(base_name):
    """Find the actual symbol name in the terminal (e.g. EURUSD -> EURUSDm)."""
    if not mt5.initialize():
        print("Failed to initialize MT5 for symbol resolution")
        return base_name
        
    # Check if exact match exists
    if mt5.symbol_info(base_name):
        return base_name
        
    # Search for partial matches
    symbols = mt5.symbols_get()
    if not symbols:
        return base_name
        
    for s in symbols:
        if base_name in s.name:
            # Prefer shorter matches (e.g. EURUSDm over EURUSDm.pro if both exist?)
            # Actually usually just check if it contains the base name
            # Common suffixes: m, pro, +, .ecn, etc.
            # Let's return the first one that contains the base name and is visible or enabled
            return s.name
            
    return base_name

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        
    terminal_path = get_terminal_path()
    if not terminal_path:
        print("Could not find MT5 terminal.")
        return

    print(f"Terminal found at: {terminal_path}")
    
    # Get MetaEditor path
    metaeditor_path = get_metaeditor_path(terminal_path)
    if not os.path.exists(metaeditor_path):
        print(f"Error: MetaEditor not found at {metaeditor_path}")
        # Continue anyway if user wants to run without compiling (assuming ex5 exists)
        # return 
    
    # 0. Copy Source and Compile
    if copy_source_code():
        if not compile_ea(metaeditor_path):
            print("Compilation failed. Stopping.")
            return
    else:
        print("Copying failed. Stopping.")
        return
        
    # Resolve symbols
    print("Resolving symbols...")
    if mt5.initialize():
        for strat in STRATEGIES:
            original = strat["symbol"]
            resolved = resolve_symbol(original)
            if resolved != original:
                print(f"Mapped {original} -> {resolved}")
                strat["symbol"] = resolved
            
            # Ensure symbol is selected/enabled
            if not mt5.symbol_select(resolved, True):
                 print(f"Warning: Could not select symbol {resolved}")
        mt5.shutdown()
    
    # 1. Run Individual Strategies
    for strat in STRATEGIES:
        print(f"\n--- Running Backtest: {strat['name']} ---")
        report_file = os.path.join(OUTPUT_DIR, f"{strat['name']}.html")
        ini_path, safe_report_path = create_ini_file(
            strategy_name=strat['name'],
            symbol=strat['symbol'],
            period=strat['period'],
            active_inputs=[strat['input']],
            report_path=report_file
        )
        
        run_backtest(terminal_path, ini_path, safe_report_path)
        process_report(safe_report_path, strat['name'], terminal_path)
        
    # 2. Run Combined Strategy
    print(f"\n--- Running Backtest: COMBINED ---")
    # For combined, we pick a primary symbol, e.g., EURUSD, but enable ALL strategies.
    combined_inputs = [s['input'] for s in STRATEGIES]
    
    # Use resolved EURUSD symbol or first available
    primary_symbol = STRATEGIES[0]["symbol"]
    for s in STRATEGIES:
        if "EURUSD" in s["symbol"]:
            primary_symbol = s["symbol"]
            break
            
    report_file = os.path.join(OUTPUT_DIR, "Combined.html")
    
    ini_path, safe_report_path = create_ini_file(
        strategy_name="Combined",
        symbol=primary_symbol,
        period="H1",
        active_inputs=combined_inputs,
        report_path=report_file
    )
    
    run_backtest(terminal_path, ini_path, safe_report_path)
    process_report(safe_report_path, "Combined", terminal_path)
    
    print("\nAll backtests completed.")

if __name__ == "__main__":
    main()
