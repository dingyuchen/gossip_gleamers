# gossip_gleamers

My attempt at [Gossip Glomers](https://fly.io/dist-sys/)

## Run

Expect [https://github.com/jepsen-io/maelstrom/releases/tag/v0.2.3] to aleady have been downloaded and unzipped.

```sh
gleam run -m gleescript # export project as escript
./maelstrom/maelstrom test -w echo --bin ./gossip_gleamers --node-count 1 --time-limit 3 # test echo load
```

You may need to install other Maelstrom dependencies, such as `openjdk`,`graphviz` and `gnuplot`

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
