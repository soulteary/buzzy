# Run using bin/ci

require_relative "../lib/buzzy"

OSS_ENV = "BUNDLE_GEMFILE=Gemfile"
SYSTEM_TEST_ENV = "PARALLEL_WORKERS=1" # system tests can't run reliably in parallel

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Gemfile: Drift check", "bin/bundle-drift check"
  step "Security: Gem audit", "bin/bundler-audit check --update"
  step "Security: Importmap audit", "bin/importmap audit"
  step "Security: Brakeman audit", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Gitleaks audit", "bin/gitleaks-audit"

  step "Tests: SQLite",        "#{OSS_ENV} bin/rails test"
  step "Tests: SQLite System", "#{OSS_ENV} #{SYSTEM_TEST_ENV} bin/rails test:system"

  if success?
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
