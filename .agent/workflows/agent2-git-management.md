# Agent 2: Git Management & Version Control Agent

---
description: Manages all git operations, branching strategy, and version control
---

## 🎯 Purpose
Maintains clean git history, manages branches, handles commits, and ensures proper version control throughout the project.

## 📋 Responsibilities

### 1. Branch Management
```
Main Branches:
- main           : Production-ready code only
- develop        : Integration branch for completed features
- phase-X        : Phase-specific development branches

Feature Branches (naming convention):
- feature/[phase]-[description]
- bugfix/[issue-id]-[description]
- hotfix/[critical-issue]
```

### 2. Commit Standards

#### Commit Message Format:
```
[TYPE]: Short description (max 50 chars)

[Body - what and why, not how]

[Footer - references, breaking changes]

Types:
- FEAT     : New feature
- FIX      : Bug fix
- REFACTOR : Code restructuring
- DOCS     : Documentation only
- TEST     : Test additions/changes
- STYLE    : Formatting, no code change
- CHORE    : Build tasks, config
```

#### Example:
```
FEAT: Add BTCUSD momentum strategy

Implements RSI-MACD based momentum strategy for Bitcoin.
Includes entry/exit logic and position sizing integration.

Refs: Phase-2 Strategy Audit
```

### 3. Pre-Commit Checklist
// turbo
```bash
# Before EVERY commit, verify:
git status                    # Check what's being committed
git diff --staged             # Review actual changes
```

Then verify:
- [ ] No sensitive data (passwords, API keys)
- [ ] No compiled files (.ex5)
- [ ] No IDE-specific files
- [ ] No temporary/debug code
- [ ] All tests pass
- [ ] Compile succeeds

### 4. Workflow Commands

#### Starting New Work:
```bash
# Always start from clean state
git checkout develop
git pull origin develop
git checkout -b feature/[phase]-[description]
```

#### Committing Work:
```bash
# Stage specific files (never use git add .)
git add [specific-files]
git status
git commit -m "[TYPE]: description"
```

#### Completing Work:
```bash
# After QA approval
git checkout develop
git merge --no-ff feature/[branch-name]
git push origin develop
git branch -d feature/[branch-name]
```

### 5. Daily Operations
// turbo
```bash
# Start of day
git fetch --all
git status
```

### 6. Repository Cleanup Commands
```bash
# Remove untracked files (CAREFUL!)
git clean -fd --dry-run     # Preview first
git clean -fd               # Execute

# Remove old branches
git branch -d [branch-name]     # Local
git push origin --delete [branch-name]  # Remote

# Prune remote references
git remote prune origin
```

### 7. Emergency Recovery
```bash
# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo all uncommitted changes
git checkout -- .
git clean -fd

# Recover deleted branch
git reflog
git checkout -b [branch-name] [commit-hash]
```

## 🏷️ Tagging Strategy
```
Format: v[major].[minor].[patch]-[phase]
Examples:
- v1.0.0-phase1  : Phase 1 complete
- v1.1.0-phase2  : Phase 2 complete
- v1.1.1-phase2  : Bugfix in Phase 2
```

## 📄 .gitignore Updates
Ensure these are ignored:
```
# Compiled
*.ex5
*.ex4

# MT5 specific
*.log
*.chr
*.tpl

# IDE
.vscode/
.idea/

# OS
Thumbs.db
.DS_Store

# Python
__pycache__/
*.pyc
venv/

# Project specific
/backtest_results/*.html
/Backtest_Reports/*.html
```

## 🚫 Rules
1. NEVER commit directly to main
2. NEVER force push to shared branches
3. ALWAYS use meaningful commit messages
4. ALWAYS review diff before committing
5. NEVER commit compiled binaries (.ex5)
6. ALWAYS fetch before starting new work

## 📊 Metrics to Track
- Commits per phase
- Branch lifetime (should be short)
- Merge conflict frequency
- Commit message quality

## ✅ Commands for Fresh Start (One-Time Setup)
```bash
# Reset to single clean branch with all content
git checkout -b fresh-start
git add .
git commit -m "CHORE: Fresh start - Phase 2 complete, consolidating history"
git branch -D main develop phase1-core-framework phase2-strategies-framework
git checkout -b main
git branch -D fresh-start

# Clean up remote (if needed)
git push origin --delete phase1-core-framework
git push origin --delete phase2-strategies-framework
git push -f origin main
```
