module PatchBundler
  def partition_patch_repro(output)
    _, _, after_first = output.partition("===AFTER_FIRST===")
    bug_run, _, rest = after_first.partition("===BEFORE_PATCH===")
    _, _, fixed_run = rest.partition("===AFTER_PATCH===")
    [bug_run, fixed_run]
  end
end

RSpec.configure do |config|
  config.include PatchBundler, :integration
end
