Stratum protocol specification for Bamboo (BMB)

## Protocol
Communication is based on newline terminated ("\n") JSON messages that are sent over a plain TCP connection.

### Startup 

The first message from the miner to the pool specifies the Bamboo payout address to which the shares are credited. 

```
{
    "address": <address that pool shares are awareded to>,
    "type": "Initialize",
    "worker_name": <worker name, this field is optional>,
    "useragent": <useragent string, currently not used>
}
```
### After startup

#### Work (pool -> miner)
The pool assigns new mining problem to the miner. JSON structure:

```
{
    "type": "Work",
    "blockhash": <block hash of mining problem>,
}
```
If received, the worker should discard the old mining jobs and mine on the new problem.

#### Submit (pool -> miner)

The miner submits a proof of work to the pool. JSON structure:

```
{
    "type": "Submit",
    "pow": <32 byte proof of work>,
}
```
**Note**: The first byte of the submitted proof of work encodes the difficulty level `d` chosen by the miner and determines the amount of pool shares (2^`d`) rewarded for this proof of work. This means that miners cannot use the full set variations in the nonce. However, BMB's remaining nonce space usable for mining is still huge (32-1=31 bytes compared to bitcoin's 4 bytes)  
**Note** The difficulty level `d` needs to be chosen large enough such that corresponding proofs of work are not sent too often to the pool (A good number is 1 submission in 15 seconds). Pools limit the number of submissions to not get overwhelmend by submissions.

#### Accept (pool -> miner) 

The pool will acknowlege valid submissions. JSON structure:

```
{
    "type": "Accept",
    "pow": <32 byte proof of work>,
}
```
The `pow` field will echo the previously submitted proof of work.

#### Reject (pool -> miner) 

The pool will reject invalid submissions. JSON structure:

```
{
    "type": "Accept",
    "pow": <32 byte proof of work>,
}
```
The `pow` field will echo the previously submitted but invalid proof of work.
If done repeatedly, rejected submissions may result in ban.

# Shifupool specifications
## Connection to pool
Shifupool accepts TCP connections only via IPv4 and only one TCP connection per IPv4 address. The pool software may be updated at any time in which case miners should reconnect. There is no pool uptime guarrantee.

## Malicious behavior
The pool may ban peers showing malicious behavior including but not limited to the following actions:

* Sending invalid proof of work.
* Sending duplicate proof of work.
* Sending malformed or unknown JSON messages.
* Sending proof of work too frequently. The an optimal rate is 3 times per 10 seconds. The miner must choose proof of work difficulty accordingly considering the own hashrate (of course the pool shares are awarded proportionally to chosen difficulty level).


## Pool payout rules
This is alpha software and nothing is guarranteed to work. Use it at your own risk. In particular there is no right to receive payouts if things break. Under normal circumstances payout is done as follows:

* One *round* consists of a range of blocks, currently 1500 blocks (can be modified).
* After a round is over (range of blocks has been mined), the pool will determine the amount of BMB it has mined in this round. 
* This amount of BMB is distributed proportionally among all participants according to their shares but a pool fee of 4% is subtracted. The amount is floored on leaf level (i.e. rounding may cause loss of less than 1 leaf in worst case compared to the exact contribution based on pool shares).
* The pool tries to send everyone's BMB out, there is no guarrantee that these payments propagate through the network. The fee for these transactions will be set to 0 for now.
* The hexdump of these transactions will be saved such that participants can resend failed transactions. 

**Note**: The Bamboo software provides functionality to resend transaction hexdump.

