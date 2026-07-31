# Shared verdict logic for the [output, status] pairs every container scenario
# returns, backing the succeed/succeed_showing/fail_showing matchers.
module ScenarioOutcome
  module_function

  def satisfied?(output, status, shown:, hidden:, success: true)
    exit_matches?(status, success) && missing(output, shown).empty? && leaked(output, hidden).empty?
  end

  # Process::Status#success? returns nil, not false, for a signal-terminated
  # process; count that as a failure rather than as neither outcome.
  def exit_matches?(status, success)
    status.success? ? success : !success
  end

  def missing(output, expectations)
    expectations.reject { |expectation| covers?(output, expectation) }
  end

  def leaked(output, expectations)
    expectations.select { |expectation| covers?(output, expectation) }
  end

  def covers?(output, expectation)
    expectation.is_a?(Regexp) ? output.match?(expectation) : output.include?(expectation)
  end

  def verdict(output, status, shown:, hidden:)
    unmet = missing(output, shown).map(&:inspect)
    forbidden = leaked(output, hidden).map(&:inspect)
    [("missing: #{unmet.join(", ")}" unless unmet.empty?),
     ("present but forbidden: #{forbidden.join(", ")}" unless forbidden.empty?),
     "exit status: #{status.exitstatus.inspect}", output].compact.join("\n")
  end
end

RSpec::Matchers.define :succeed do
  chain(:without) { |*absent| @absent = absent }

  match do |(output, status)|
    ScenarioOutcome.satisfied?(output, status, shown: [], hidden: Array(@absent))
  end

  failure_message do |(output, status)|
    verdict = ScenarioOutcome.verdict(output, status, shown: [], hidden: Array(@absent))
    "expected the run to succeed\n#{verdict}"
  end
end

RSpec::Matchers.define :succeed_showing do |*shown|
  chain(:without) { |*absent| @absent = absent }

  match do |(output, status)|
    ScenarioOutcome.satisfied?(output, status, shown: shown, hidden: Array(@absent))
  end

  failure_message do |(output, status)|
    verdict = ScenarioOutcome.verdict(output, status, shown: shown, hidden: Array(@absent))
    "expected the run to succeed showing #{shown.inspect}\n#{verdict}"
  end
end

RSpec::Matchers.define :fail_showing do |*shown|
  chain(:without) { |*absent| @absent = absent }

  match do |(output, status)|
    ScenarioOutcome.satisfied?(output, status, shown: shown, hidden: Array(@absent), success: false)
  end

  failure_message do |(output, status)|
    verdict = ScenarioOutcome.verdict(output, status, shown: shown, hidden: Array(@absent))
    "expected the run to fail showing #{shown.inspect}\n#{verdict}"
  end
end
