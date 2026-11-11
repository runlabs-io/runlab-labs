# runlab-labs

The labs runlab publishes. `tutorial/` is the hands-on course that teaches how to write runlab labs, as labs. Each lab adds one idea, and a lab only uses what an earlier lab taught.

| # | Lab | What it teaches |
|---|---|---|
| 1 | `get-started` | The page, the terminal, one code block, how to finish |
| 2 | `your-first-lab` | A lab is a folder with an `index.md`; `config.yaml` is for the catalog |
| 3 | `run-and-view` | A block that runs a command, and one that shows a file |
| 4 | `layout-card` | Panes: arrange the terminal; press a key in a pane |
| 5 | `open-a-web-page` | A service block opens a web page in a tab |
| 6 | `watch-a-request` | Serve in one pane, call from the other, watch the log |
| 7 | `build-your-own` | The author pack, `trylab`, and publishing |

`pr-reviews/` holds labs for trying a pull request of an open source project on your own machine with `trylab pr`. They are not for runlabs.io: see its README.

`samples/` holds the other labs: earlier samples (`alerts`, `basics`, `capture`, `docker`), `nginx`, which has its own disk and snapshot, and `directives` and `layout`, which share a disk built from their `data/` folder. Connecting this repository and pressing Refresh builds the disks that need building.

A lab that uses the shared default disk (no `setup.sh`, no `data/` that the lesson reads inside the lab) needs no disk build.

## License

Apache License 2.0. See [LICENSE](LICENSE). Copyright © 2026 Eitan Suez. You may copy these labs, change them and use them as the start of your own.
