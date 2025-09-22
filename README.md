# EigenStakeDrainTrap
# EigenStakeDrainTrap — Drosera PoC Trap

## Overview
**EigenStakeDrainTrap** is a small proof-of-concept Drosera trap that monitors an EigenLayer-style staking contract on the Hoodi testnet.  
It detects sudden drains in the target's `totalStaked()` value: if total stake drops by **≥ 20%** over a configured sample window, the trap signals and the configured responder contract is called.

This repo contains:
- `src/EigenStakeDrainTrap.sol` — the trap contract implementing `ITrap` (`collect()` + `shouldRespond()`).
- `src/EigenResponder.sol` — the response contract that emits a `StakeDrainAlert` event when invoked.
- `drosera.toml` — example Drosera configuration for running the trap with the Hoodi relay.

## Deployed addresses (Hoodi testnet)
- Trap: `0xb2909a5B9bA59A566f014AE58bfb08a92a9e948b`  
- Responder: `0x6ce3f2f7391c7d451d2d1812fef5b062c932267a`  
- Monitored target: `0xeE45e76ddbEDdA2918b8C7E3035cd37Eab3b5D41`  
- RPC: `https://ethereum-hoodi-rpc.publicnode.com`

## What the trap does (high level)
1. `collect()` (view) — returns `abi.encode(block.number, totalStaked)` for the target contract (one sample per block).  
2. Operators maintain a small time-series of samples (configurable in `drosera.toml`).  
3. `shouldRespond(bytes[] calldata samples)` (pure) — takes the array of samples (oldest → newest) and compares the first and last `totalStaked` values. If the drop percentage ≥ 20%, it returns `true` and a payload `abi.encode(oldStake, newStake, dropPercent)`.  
4. Drosera operators call the configured `response_function` on the responder contract with the payload — the responder emits an on-chain `StakeDrainAlert` for auditing.

## How to test locally (with `cast`)
See full command list in this README. Typical workflow:

1. Inspect the trap:
   ```bash
   cast call <TRAP_ADDRESS> "collect()(bytes)" --rpc-url <HOODI_RPC>
Build bytes samples:

cast abi-encode "uint256,uint256" <block> <totalStaked>


Simulate shouldRespond:

cast call <TRAP_ADDRESS> "shouldRespond(bytes[])(bool,bytes)" '["0x...","0x..."]' --rpc-url <HOODI_RPC>


If true, call the responder on-chain:

cast send <RESPONDER_ADDRESS> "respondToStakeDrain(uint256,uint256,uint256)" <oldStake> <newStake> <dropPercent> --rpc-url <HOODI_RPC> --private-key $PRIVKEY

drosera.toml (example)
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]
[traps.eigen_stake_drain]
path = "out/EigenStakeDrainTrap.sol/EigenStakeDrainTrap.json"
response_contract = "0x6ce3f2f7391c7d451d2d1812fef5b062c932267a"
response_function = "respondToStakeDrain(uint256,uint256,uint256)"
cooldown_period_blocks = 30
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
private_trap = true
whitelist = ["YOUR_OPERATOR_ADDRESS"]
