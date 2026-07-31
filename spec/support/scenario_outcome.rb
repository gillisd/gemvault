# Shared verdict logic for the [output, status] pairs every container scenario
# returns, backing the succeed/succeed_showing/fail_showing matchers.
module ScenarioOutcome
  module_function

  def satisfied?(output, status, shown:, hidden:, success: true)
    status.success? == success &&
      shown.all? { |expectation| covers?(output, expectation) } &&
      hidden.none? { |expectation| covers?(output, expectation) }
  end

  def covers?(output, expectation)
    expectation.is_a?(Regexp) ? output.match?(expectation) : output.include?(expectation)
  end

  def transcript(output, status)
    "exit status: #{status.exitstatus.inspect}\n#{output}"
  end
end

RSpec::Matchers.define :succeed do
  chain(:without) { |*absent| @absent = absent }

  match do |(output, status)|
    ScenarioOutcome.satisfied?(output, status, shown: [], hidden: Array(@absent))
  end

  failure_message do |(output, status)|
    ["expected the run to succeed", ("without #{@absent.inspect}" if @absent),
     ScenarioOutcome.transcript(output, status)].compact.join(" ")
  end
end

RSpec::Matchers.define :succeed_showing do |*shown|
  chain(:without) { |*absent| @absent = absent }

  match do |(output, status)|
    ScenarioOutcome.satisfied?(output, status, shown: shown, hidden: Array(@absent))
  end

  failure_message do |(output, status)|
    ["expected the run to succeed showing #{shown.inspect}", ("without #{@absent.inspect}" if @absent),
     ScenarioOutcome.transcript(output, status)].compact.join(" ")
  end
end

RSpec::Matchers.define :fail_showing do |*shown|
  match do |(output, status)|
    ScenarioOutcome.satisfied?(output, status, shown: shown, hidden: [], success: false)
  end

  failure_message do |(output, status)|
    "expected the run to fail showing #{shown.inspect} #{ScenarioOutcome.transcript(output, status)}"
  end
end
