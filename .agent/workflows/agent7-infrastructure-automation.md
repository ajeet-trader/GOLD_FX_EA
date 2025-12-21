# Agent 7: Infrastructure & Automation Agent

---
description: Handles infrastructure, automation, testing framework, and deployment pipelines
---

## 🎯 Purpose
This agent manages all infrastructure components including the backtesting automation, file management, testing frameworks, and build/deploy processes.

## 📋 Core Responsibilities

### 1. Automated Backtesting System

#### Current System Components:
```
automation/
└── automate_backtest.py
    ├── Copy source to MT5 data folder
    ├── Compile EA with MetaEditor
    ├── Generate strategy configs (.ini)
    ├── Run backtests sequentially
    ├── Monitor for report generation
    └── Convert HTML reports to Excel
```

#### Backtest Automation Improvements:
```python
# Enhanced backtest runner structure

class BacktestAutomation:
    def __init__(self):
        self.config = load_config()
        self.results = []
        
    def run_all(self):
        self.copy_source()
        if not self.compile():
            return False
        for strategy in self.strategies:
            result = self.run_single(strategy)
            self.results.append(result)
        self.generate_report()
        
    def run_single(self, strategy):
        ini = self.create_ini(strategy)
        self.run_terminal(ini)
        return self.collect_results(strategy)
```

### 2. File Synchronization

#### Project to MT5 Sync:
```
Source: J:/Gold_FX_EA/GOLD_FX_EA/
Target: C:/Users/[user]/AppData/Roaming/MetaQuotes/Terminal/[ID]/MQL5/

Sync Map:
Experts/GOLDFXEA_Experts/ → MQL5/Experts/GOLDFXEA_Experts/
Include/GoldFXEAProject/  → MQL5/Include/GoldFXEAProject/
Scripts/GOLDFXEA_Scripts/ → MQL5/Scripts/GOLDFXEA_Scripts/
```

#### Sync Script Template:
```python
# turbo
def sync_to_mt5():
    source = PROJECT_ROOT
    target = MT5_DATA_DIR + "/MQL5"
    
    folders = [
        ("Experts/GOLDFXEA_Experts", "Experts/GOLDFXEA_Experts"),
        ("Include/GoldFXEAProject", "Include/GoldFXEAProject"),
        ("Scripts/GOLDFXEA_Scripts", "Scripts/GOLDFXEA_Scripts"),
    ]
    
    for src, dst in folders:
        sync_folder(
            os.path.join(source, src),
            os.path.join(target, dst)
        )
```

### 3. Build System

#### Compilation Pipeline:
```
1. Clean previous .ex5 files
2. Copy source to MT5
3. Run MetaEditor compiler
4. Parse compile.log for errors
5. Report success/failure
```

#### MetaEditor Command:
```bash
# turbo
"C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"path\to\file.mq5" /log:"compile.log"
```

#### Compile Log Parser:
```python
def parse_compile_log(log_path):
    errors = []
    warnings = []
    with open(log_path, 'r', encoding='utf-16') as f:
        for line in f:
            if 'error' in line.lower():
                errors.append(line)
            elif 'warning' in line.lower():
                warnings.append(line)
    return errors, warnings
```

### 4. Report Generation

#### Backtest Report Structure:
```
Backtest_Reports/
├── [Strategy]_[Date].html     # Raw MT5 report
├── [Strategy]_[Date].xlsx     # Converted Excel
├── Summary_[Date].csv         # All strategies summary
└── Comparison_[Date].png      # Equity curves comparison
```

#### Report Processing:
```python
def process_report(html_path, strategy_name):
    # Parse HTML
    df = pd.read_html(html_path)
    
    # Extract metrics
    metrics = extract_metrics(df)
    
    # Save Excel
    save_excel(df, strategy_name)
    
    # Update summary
    update_summary(strategy_name, metrics)
    
    return metrics
```

### 5. Testing Framework

#### Test Types:
```
1. Unit Tests:   Individual function testing
2. Integration:  Module interaction testing
3. System:       Full EA testing
4. Regression:   Ensure no functionality lost
```

#### Test Script Template:
```python
# tests/test_strategy.py

class TestStrategy:
    def test_initialization(self):
        # Test strategy initializes correctly
        pass
        
    def test_signal_generation(self):
        # Test signals generated properly
        pass
        
    def test_stop_loss(self):
        # Test SL calculation
        pass
        
    def test_cleanup(self):
        # Test proper deinitialization
        pass
```

### 6. Environment Setup

#### Requirements Management:
```
requirements.txt:
MetaTrader5
pandas
openpyxl
beautifulsoup4
lxml
pytest
numpy
matplotlib
```

#### Virtual Environment:
```bash
# turbo
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

### 7. Deployment Checklist

#### Before Deployment:
- [ ] All tests pass
- [ ] Compilation successful
- [ ] Backtest results acceptable
- [ ] Documentation updated
- [ ] Version tagged in git
- [ ] Release notes written

#### Deployment Steps:
```
1. Tag version in git
2. Create release branch
3. Export compiled .ex5
4. Package with documentation
5. Test on fresh MT5 installation
6. Deploy to target accounts
```

### 8. Automation Scripts

#### Daily Tasks:
```python
# daily_automation.py

def daily_run():
    # Sync source files
    sync_to_mt5()
    
    # Compile
    if not compile_all():
        notify("Compilation failed")
        return
    
    # Run backtests (if configured)
    run_daily_backtests()
    
    # Generate summary report
    generate_daily_summary()
    
    # Backup
    backup_results()
```

## 🔧 Common Tasks

### Task: Setup New Development Machine
```bash
# turbo
1. Clone repository
2. Create virtual environment
3. Install dependencies
4. Configure MT5 data folder path
5. Run initial sync
6. Verify compilation
```

### Task: Add New Strategy to Backtest
```python
# In automate_backtest.py, add to STRATEGIES list:
{
    "name": "NEW_Strategy_Name",
    "symbol": "SYMBOL",
    "period": "H1",
    "input": "Enable_NEW_Strat1"
}
```

### Task: Generate Comparison Report
```python
def compare_strategies():
    results = load_all_results()
    comparison = create_comparison_table(results)
    plot_equity_curves(results)
    save_comparison_report(comparison)
```

## 🚫 Rules
1. NEVER run automation without backup
2. ALWAYS verify paths before sync
3. NEVER overwrite production .ex5 without testing
4. ALWAYS parse compile logs for hidden errors
5. NEVER skip the wait times for MT5 operations

## 📊 Deliverables
- Working automation scripts
- Test framework
- Build pipeline
- Deployment documentation

## ✅ Output Format
```
BUILD: [Success/Failed] - [X] errors, [Y] warnings
SYNC: [Source] → [Target] - [X] files
TEST: [X] passed, [Y] failed
BACKTEST: [Strategy] - PF: [X], DD: [Y]%
DEPLOY: [Version] to [Environment]
```
