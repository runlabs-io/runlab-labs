# Review an agentgateway pull request

This lab holds the Rust and Node toolchains and a clone of `main`, with the build caches warm.
It builds the pull request and runs it standalone: one binary and a config file.

## Start the build

Check out the pull request, build the UI and the proxy.

```shell panel="build"
gh pr checkout <pr> &&
  (cd ui && pnpm install --frozen-lockfile && pnpm build) &&
  cargo build --profile quick-release --features ui
```

The build takes a while. Read about the pull request below while it runs.

## Read the changes

Once the checkout in the build pane has finished, show what the pull request changes (until then there is nothing to compare):

```shell panel="view"
gh pr diff <pr>
```

## Run it

Start the proxy on a config: any of the project's `examples/` will do, or your own. The build runs again first (it finishes at once when nothing changed), so the proxy only starts when the build succeeded:

```shell panel="build"
cargo build --profile quick-release --features ui && ./target/quick-release/agentgateway -f examples/mcp-basic/config.yaml
```

The link opens the agentgateway UI on this pull request:

```service ui
```
