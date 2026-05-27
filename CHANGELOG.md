## 0.1.0

* Added a pluggable static-analysis frame for Dart and Flutter projects:
  * `AnalyzerRule` — abstract plugin contract for custom rules.
  * `Diagnostic`, `Severity`, `SourceLocation` — value types describing analysis findings.
  * `AnalysisContext` — carrier passed into each rule invocation, exposing the resolved compilation unit.
  * `RuleRegistry` — in-memory registration and lookup of rules, with duplicate-id rejection.
  * `AnalysisRunner` — orchestrator that resolves target files, dispatches rules, and collects diagnostics.
  * `AnalOptions` — value class describing include/exclude paths and enabled rule ids.
  * `Reporter` / `ConsoleReporter` — pluggable diagnostic output, with a stdout implementation.
  * CLI executable `anal` (`dart run anal`) with `--help`, `--version`, `--rules`, and `--exclude` flags.

### BREAKING CHANGE

* Removed the `Calculator` stub that shipped in `0.0.1`. Consumers that
  depended on it must remove the import; it was a generator placeholder and
  not part of any intended public API.

## 0.0.1

* TODO: Describe initial release.
