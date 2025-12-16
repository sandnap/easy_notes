---
trigger: model_decision
description: Performs a code review ensuring our standards for security, performance, and style are met.
---

## Instructions

1. Fix formatting issues with `bin/lint -a` (auto-fixes Rubocop offenses)
2. Check for code smells with `bin/lint -f` (runs Rubocop + RubyCritic) and output a summary of the results
3. Check for security vulnerabilities with `bin/lint -s` (runs Brakeman + bundler-audit) and output a summary of the results
4. Verify that all checks meet the Expected Results:
   - **Rubocop:** 0 offenses
   - **Brakeman:** 0 security warnings
   - **bundler-audit:** No vulnerabilities
   - **RubyCritic:** Score > 80

If any check fails to meet these standards, report the issues and fix them before proceeding.
