# Global Debugging & Analysis Contract

---
description: Defines a strict, evidence-based contract for all debugging and analysis tasks. Enforces scope control, prohibits assumptions and unsolicited fixes, requires file-level evidence, and ensures every investigation terminates deterministically without loops.
---

## 🎯 Purpose
This contract defines the rules EVERY agent must follow when debugging, analyzing, or investigating issues. It prevents scope creep, assumption-based changes, and infinite investigation loops.

## ⚠️ MANDATORY RULES - NO EXCEPTIONS

### Rule 1: Evidence-Based Conclusions Only
```
EVERY conclusion MUST reference:
✓ A specific file (absolute path)
✓ A specific function/class/line number
✓ Actual code or log evidence

FORBIDDEN:
✗ "It probably..."
✗ "It might be..."
✗ "I assume..."
✗ "This could cause..."
```

### Rule 2: Scope Control
```
BEFORE starting ANY investigation:
1. Define EXACTLY what you're investigating
2. Define CLEAR success criteria
3. Define MAX investigation depth (number of files/calls)
4. Define STOP conditions

If scope wants to expand:
→ STOP
→ Document what was found
→ Ask user if expansion is warranted
```

### Rule 3: No Unsolicited Modifications
```
FORBIDDEN without explicit user request:
✗ Refactoring "while we're here"
✗ "Improving" unrelated code
✗ Adding features during bug fixes
✗ Changing patterns/architecture
✗ "Cleaning up" code

ALLOWED:
✓ Fixing the specific reported issue
✓ Fixing directly related issues discovered
✓ Documenting issues for later
```

### Rule 4: Termination Guarantee
```
Every investigation MUST terminate:

Maximum iterations: 10 file/function lookups
Maximum depth: 5 levels of call chain
Maximum time: Define before starting

If limits reached without resolution:
→ STOP
→ Document findings so far
→ Document what remains unknown
→ Request guidance
```

### Rule 5: No Assumption Chains
```
FORBIDDEN:
You CANNOT chain assumptions:
"A might cause B, which could lead to C, so D probably happens"

REQUIRED:
Each step must be verified before proceeding:
1. Verify A exists (evidence)
2. Verify A causes B (evidence)
3. Verify B leads to C (evidence)
4. Verify D happens (evidence)
```

## 📋 Investigation Protocol

### Starting an Investigation
```markdown
## Investigation: [ID] - [Brief Description]

### Scope Definition:
- Target: [What specifically are we investigating]
- Success Criteria: [When is this investigation complete]
- Max Depth: [How deep will we trace]
- Stop Conditions: [When to stop even if not resolved]

### Initial Evidence:
- Error/Issue: [Exact error message or behavior]
- Location: [File:Line if known]
- Reproduction: [Steps to reproduce]
```

### During Investigation
```markdown
### Trace [N]:
- File: [path]
- Function: [name]
- Line: [number]
- Finding: [what was found]
- Evidence: [actual code/log]
- Next: [logical next step, if any]
```

### Completing Investigation
```markdown
### Conclusion:
- Root Cause: [with evidence]
- File: [path]
- Line: [number]
- Code: [actual problematic code]

### Fix (if authorized):
- Change: [what to change]
- Reason: [why this fixes it]
- Risk: [potential side effects]

### Remaining Unknowns:
- [Any aspects not fully traced]
```

## 🚫 Anti-Patterns to Avoid

### Anti-Pattern 1: The Infinite Loop
```
BAD:
"Let me check this... which calls that... which uses this..."
[Never ending, no clear goal]

GOOD:
"Tracing Initialize() call chain, max 5 levels:
1. OnInit → EAEngine.Initialize ✓
2. EAEngine.Initialize → RiskManager.Initialize ✓
3. [stop at level 5 or finding]"
```

### Anti-Pattern 2: The Assumption Cascade
```
BAD:
"If this fails, then that would fail, leading to this error"
[No verification of each step]

GOOD:
"OnInit returns INIT_FAILED (evidence: log line X)
Because: Initialize() returns false (evidence: code line Y)
Because: Handle is INVALID (evidence: log line Z)"
```

### Anti-Pattern 3: The Scope Creep
```
BAD:
"While investigating order execution, I noticed the logger
could be improved, and also the risk manager uses an old
pattern, so I'll refactor those too"

GOOD:
"Investigation complete. Related observations documented:
- Logger improvement opportunity (see note #1)
- Risk manager pattern consideration (see note #2)
These are separate tasks, not part of current scope."
```

### Anti-Pattern 4: The Vague Conclusion
```
BAD:
"The issue is probably in the strategy initialization
or maybe the indicator handling"

GOOD:
"Root cause: iATR() returns INVALID_HANDLE
File: Include/GoldFXEAProject/Strategies/Forex/EURUSD_Strategy1.mqh
Line: 47
Code: m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
Reason: m_symbol is empty string at this point"
```

## 📊 Evidence Types

### Acceptable Evidence:
```
1. Code Reference:
   "File: X, Line: Y, Code: [actual code]"

2. Log Output:
   "Log entry: [timestamp] [level] [message]"

3. Compilation Error:
   "Error: [file](line): [error message]"

4. Test Result:
   "Test [name] failed: expected [X], got [Y]"

5. Debugger Output:
   "Variable [name] = [value] at breakpoint [location]"
```

### Unacceptable Evidence:
```
✗ "It usually works this way"
✗ "The documentation says..."
✗ "In similar systems..."
✗ "Based on experience..."
✗ "It makes sense that..."
```

## 🔒 Scope Lock Example

```markdown
## Investigation: COMP-001 - Compilation Error in Strategy

### Scope Lock:
- IN SCOPE: Finding cause of compilation error in EURUSD_Strategy1.mqh
- OUT OF SCOPE: 
  - Other strategy files (unless directly referenced)
  - Optimization suggestions
  - Code style improvements
  - Refactoring opportunities
  
### Boundaries:
- Max files to examine: 5
- Max call depth: 3
- Stop if: Error cause identified OR limit reached

### Scope Change Request:
If investigation requires examining more:
→ STOP
→ Document current findings
→ Request: "Need to expand scope to include [X] because [Y]"
→ Wait for approval
```

## ✅ Checklist Before Completing Investigation

- [ ] Root cause identified with specific file/line
- [ ] Evidence is actual code/log, not assumption
- [ ] Scope was not exceeded
- [ ] No unsolicited changes made
- [ ] Fix proposal is minimal and targeted
- [ ] Side effects assessed
- [ ] Unknowns documented
- [ ] Clear next steps defined

## 📝 Output Format

```
INVESTIGATION: [ID] - [Status: COMPLETE/INCOMPLETE/BLOCKED]
ROOT-CAUSE: [File:Line] - [Description]
EVIDENCE: [Actual code/log]
FIX: [Proposed change] (if authorized)
UNKNOWNS: [List remaining uncertainties]
SCOPE-STATUS: [Stayed within scope / Expansion needed]
```
