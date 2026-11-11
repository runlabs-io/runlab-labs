# pr-reviews

Labs for trying a pull request of an open source project in a microVM on your own machine, with `trylab pr`.

| project | lab |
|---|---|
| [kagent](https://github.com/kagent-dev/kagent) | [`kagent`](kagent): check the pull request out, build its images, install it in a kind cluster, read its diff, open the kagent UI |

## How a lab is used

`trylab pr <number>`, run from inside a checkout of the project, looks for the project's own lab at `.runlab/pr-review/` in that checkout. Until a project carries one, copy the lab here into the project's checkout (and leave it untracked):

```
cp -r pr-reviews/kagent ~/src/kagent/.runlab/pr-review
cd ~/src/kagent && trylab pr 3564
```

`trylab pr` reads the pull request with your own `gh`, opens the lab, and puts the pull request, drawn as a card with its changed files, below the first step. The lab itself is an ordinary lab folder. Two things in it are written for `trylab pr`: the lesson writes the pull request's number as `<pr>`, and its layout has a pane named `view`, where a click on a file of the card types that file's diff.

## What each lab needs

- A Linux x86_64 machine with KVM, and the [author pack](https://runlabs.io/author-pack) (`./prereqs` once).
- `gh`, logged in, on your machine.
- Whatever the lab's `config.yaml` lists under `env:`, in your environment when you start. The kagent lab needs `OPENAI_API_KEY` and `GH_TOKEN`. The guest runs the pull request's code, so make `GH_TOKEN` a fine-grained token that can only read public repositories, never your login's token.
- Space: the kagent lab's disk is about 23 GB and its snapshot about 17 GB.

## Not for runlabs.io

These labs need a pull request number and a token, and some build a large disk. Do not Include them when you connect this repository to runlabs.io and press Refresh.

To learn how labs are written, start at [runlabs.io/learn](https://runlabs.io/learn).
