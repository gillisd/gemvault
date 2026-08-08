# The podman command line, with the OCI runtime pinned when the environment
# names one.
#
# GitHub's ubuntu24 runner image 20260726.254 bumped podman 4.9.3 -> 5.8.4 and
# left Ubuntu 24.04's crun (1.14) where it was. podman 5 writes an OCI config
# declaring ociVersion 1.2.0; crun 1.14 refuses any version not prefixed "1.0",
# with exactly "unknown version specified". Every RUN layer of a build and every
# container therefore fails on that image, and no retry helps because nothing
# about it is intermittent.
#
# CI installs a current crun and names it in GEMVAULT_PODMAN_RUNTIME. Left
# unset -- every developer machine, and any runner whose podman and crun agree
# -- podman chooses its runtime as usual.
module Podman
  RUNTIME_VAR = "GEMVAULT_PODMAN_RUNTIME".freeze

  def self.command(*args, env: ENV)
    ["podman", *runtime_flag(env), *args]
  end

  # --runtime is a podman-level flag, so it has to precede the subcommand.
  def self.runtime_flag(env)
    runtime = env[RUNTIME_VAR].to_s
    return [] if runtime.empty?

    ["--runtime", runtime]
  end
end
