# gossip_gleamers

My attempt at [Gossip Glomers](https://fly.io/dist-sys/)

## Run

Expect [Maelstrom v0.2.3](https://github.com/jepsen-io/maelstrom/releases/tag/v0.2.3) to aleady have been downloaded and unzipped.

```sh
gleam run -m gleescript # export project as escript

./maelstrom/maelstrom test -w echo --bin ./gossip_gleamers --node-count 1 --time-limit 10 # test echo load
./maelstrom/maelstrom test -w unique-ids --bin ./gossip_gleamers --time-limit 30 --rate 1000 --node-count 3 --availabil
ity total --nemesis partition # unique ids load
```

You may need to install other Maelstrom dependencies, such as `openjdk`,`graphviz` and `gnuplot`

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
# Writeup

## Challenge 1: Echo

Biggest challenge here is to figure out the intricacies of Gleam's JSON library and getting my dev environment set up in order to run Gleam with Erlang 27.

The `use` syntactic suger together with `result.try` makes for rather elegant looking code.

## Challenge 2: Unique ID Generation

The approach taken is a signed 32-integer version of Snowflake ID.
The challenge parameter is 1000 qps for 30s, which roughly translates to 1 ID/ms.

| timestamp | node id | sequence no. | total
| - | - | - | - |
| 17        | 6       | 8            | 31 |

Since the node is assigned an ID during initialization, we do not have to account for network partiitons, since there is no communication between the nodes anyway.

Main downside here is the timestamp bits, which can only contain 2.19mins of runtime before overflowing.
Additionally, it is unlikely to start from 0.

One improvement would be to readjust the bits allocated for timestamp and sequence no.
Given the relatively low QPS, the sequence number is unlikely to require so many bits.

Another improvement is to include overflow checks for sequence number and timestamp during the ID generation itself.
