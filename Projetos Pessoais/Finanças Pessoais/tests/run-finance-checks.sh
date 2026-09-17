#!/bin/bash
set -euo pipefail

# All stores and build products are synthetic and live outside the app's data container.
finance_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$finance_root"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
finance_test_dir="$(mktemp -d /tmp/financas-checks.XXXXXX)"
finance_arch="$(uname -m)"
finance_swift_args=(-target "${finance_arch}-apple-macos14.0" -module-cache-path "$finance_test_dir/modules")
finance_package_args=(--package-path FinanceCore --scratch-path "$finance_test_dir/core" --cache-path "$finance_test_dir/cache")

# Opt-in compatibility for running Apple's macro compiler inside an existing OS sandbox.
# This does not alter the app project or grant any additional host filesystem permissions.
if [[ "${FINANCE_NESTED_SANDBOX_COMPAT:-0}" == "1" ]]; then
    finance_swift_args+=(-Xfrontend -disable-sandbox)
    finance_package_args+=(--disable-sandbox)
fi

CLANG_MODULE_CACHE_PATH="$finance_test_dir/clang-modules" \
SWIFTPM_MODULECACHE_OVERRIDE="$finance_test_dir/manifest-modules" \
xcrun swift test "${finance_package_args[@]}"

xcrun swiftc "${finance_swift_args[@]}" \
    FinancasPessoais/Models/FinanceModels.swift \
    FinancasPessoais/Services/CategorizationService.swift \
    FinancasPessoais/Services/Money.swift \
    FinancasPessoais/Services/WeeklyBudgetService.swift \
    tests/WeeklyBudgetServiceChecks.swift -o "$finance_test_dir/weekly"
"$finance_test_dir/weekly"

xcrun swiftc "${finance_swift_args[@]}" \
    FinancasPessoais/Models/FinanceModels.swift \
    FinancasPessoais/Services/RecurrenceService.swift \
    FinancasPessoais/Services/BalanceService.swift \
    tests/RecurrenceIntervalChecks.swift -o "$finance_test_dir/recurrences"
"$finance_test_dir/recurrences"

xcrun swiftc "${finance_swift_args[@]}" \
    FinancasPessoais/Models/FinanceModels.swift \
    FinancasPessoais/Models/SimulationAdjustment.swift \
    FinancasPessoais/Services/CategorizationService.swift \
    FinancasPessoais/Services/WeeklyBudgetService.swift \
    FinancasPessoais/Services/RecurrenceService.swift \
    FinancasPessoais/Services/BalanceService.swift \
    FinancasPessoais/Services/SimulationService.swift \
    tests/SimulationServiceChecks.swift -o "$finance_test_dir/simulation"
"$finance_test_dir/simulation"

xcrun swiftc "${finance_swift_args[@]}" \
    FinancasPessoais/Services/InstallationValidity.swift \
    tests/InstallationValidityChecks.swift -o "$finance_test_dir/installation-validity"
"$finance_test_dir/installation-validity"

xcrun swiftc "${finance_swift_args[@]}" \
    FinancasPessoais/Services/InstallationValidity.swift \
    FinancasPessoais/Services/InstallationReminderService.swift \
    tests/InstallationReminderServiceChecks.swift -o "$finance_test_dir/installation-reminder"
"$finance_test_dir/installation-reminder"

printf 'Verificações concluídas. Resultados temporários: %s\n' "$finance_test_dir"
