# Shifupool

To start your BMB pool server:

  * Install dependencies with `mix deps.get`
  * Important: The pool operation requires you to run a local http server written in C++ that signs transactions/creates blocks.
  * Start the backend server (see readme file in the parent directory) 
  * Start the pool with `mix phx.server` or inside IEx with `iex -S mix phx.server.
  * Important: The pool uses a sqlite database `data.db3` that is saved and loaded **from the current working directory**. This means that you should restart the pool from the same directory.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser. 

## Run in production

Read the Phoenix guideline: *Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).*

Basically run it boils down to this (don't forget to start the C++ backend server):
  * `SECRET_KEY_BASE=fV9ZuIH2i/1yfckwHU3bORjFffQICkTtyvF/O7+BZT3cs3l6jUPh1A3cgYv0RE6V PORT=5000 MIX_ENV=prod mix phx.server` 
  * You should set a *secret* `SECRET_KEY_BASE` environment variable, create it with `mix phx.gen.secret` (within this directory)
  * The port can be modified via the `PORT` environment variable.

## Environment variables

|Name | Default | Description|
|----|---|---|
|`SHIFUPOOL_FEE_PERCENT`| 4 | Pool fee in percent|
|`SHIFUPOOL_PAYOUT_ADDRESS` |`BE5E70FDBCDFE84FD46B841731C218C43DA7C92BAFE0E349B75EC4ECEB3D7B55`| Pool payout address|
|`SHIFUPOOL_POOL_PORT`| `5555`| Port for miners|
|`SHIFUPOOL_ROUND_BLOCKS`|`1500`|Number of blocks in each round|
|`SHIFUPOOL_BACKEND_PORT`|`4002`|C++ backend port|
|`SHIFUPOOL_PAYOUTDELAY_BLOCKS`| `150`| Delay before payout after round is complete|
|`SHIFUPOOL_HOST`| `185.215.180.7`| Will appear in API `config["poolHost"]`|
|`SHIFUPOOL_NODES`| see below | These nodes are used to interact with the Bamboo network|
|`PORT`| 80 | HTTP Frontend Port|


### Node configuration
The nodes need to be supplied as an environment variable `SHIFUPOOL_NODES` separated by "`|`". The default value is 

```
http://173.230.139.86:3001|http://173.230.139.86:3002|http://173.230.139.86:3000
```
Hence the pool will contact the nodes
```
"http://173.230.139.86:3001",
"http://173.230.139.86:3002",
"http://173.230.139.86:3000"
```
