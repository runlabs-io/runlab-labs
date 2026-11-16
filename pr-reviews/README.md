# pr-reviews

Labs for trying a pull request of an open source project in a microVM on your own machine, with `trylab pr`.

| project | lab |
|---|---|
| [kagent](https://github.com/kagent-dev/kagent) | [`kagent`](kagent): build the pull request's images, install it in a kind cluster, read its diff, open the kagent UI |
| [agentgateway](https://github.com/agentgateway/agentgateway) | [`agentgateway`](agentgateway): build the UI and the proxy, run it standalone on an example config or your own, read its diff, open the UI |

## How a lab is used

`trylab pr <number>`, run from inside a checkout of the project, looks for the project's own lab at `.runlab/pr-review/` in that checkout. Until a project carries one, copy the lab here into the project's checkout (and leave it untracked):

```
cp -r pr-reviews/kagent ~/src/kagent/.runlab/pr-review
cd ~/src/kagent && trylab pr 3564
```

`trylab pr` reads the pull request with your own `gh`, **checks it out in your checkout** (as `gh pr checkout` does: your checkout is switched to the pull request's branch, and the command stops, changing nothing, if tracked files of yours have changes that are not committed), opens the lab, and puts the pull request, drawn as a card with its changed files, below the first step. The microVM is *given* the checkout's commits as one small file over its own connection: it fetches nothing from GitHub, holds no token, and cannot write to your files. Your checkout stays on the pull request's branch when the lab ends, which is where you review and commit; run `trylab pr` again to send a new microVM your commits.

The lab itself is an ordinary lab folder. Three things in it are written for `trylab pr`: the lesson writes the pull request's number as `<pr>` and the commit it branched from as `<merge-base>`, its layout has a pane named `view`, where a click on a file of the card types that file's diff, and its `setup.sh` clones the project with its full history and its `config.yaml` sets `workdir:` to that clone.

## What each lab needs

- A Linux x86_64 machine with KVM, and the [author pack](https://runlabs.io/author-pack) (`./prereqs` once).
- `gh`, logged in, on your machine.
- Whatever the lab's `config.yaml` lists under `env:`, in your environment when you start. The kagent lab needs `OPENAI_API_KEY`; the agentgateway lab needs nothing. No lab needs a GitHub token: the guest is given the pull request, it does not fetch it.
- Space: the kagent lab's disk is about 23 GB and its snapshot about 17 GB. The agentgateway lab's disk is about 10 GB and its snapshot about 16 GB.
- A lab that clones its project does so with the full history, not `--depth 1`: trylab sends the guest a git bundle of the commits the clone lacks (1.5 KB for a one-commit pull request), and a bundle needs the commits it was cut from, so a shallow clone refuses it.

## Not for runlabs.io

These labs need a pull request number and your checkout of the project, and some build a large disk. Do not Include them when you connect this repository to runlabs.io and press Refresh.

To learn how labs are written, start at [runlabs.io/learn](https://runlabs.io/learn).
