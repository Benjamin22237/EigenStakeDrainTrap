# EigenStakeDrainTrap — Drosera PoC Trap (updated)

## Overview
**EigenStakeDrainTrap** monitors an EigenLayer-like staking contract on the Hoodi testnet and signals when total stake falls by a configurable threshold. This revision improves precision (BPS), addresses sample ordering (Drosera supplies newest→oldest), and adds persistence checks to reduce false positives.

## Key design choices
- **Sample ordering**: Drosera passes collected samples *newest → oldest* (index 0 is the most recent block). The trap treats data accordingly.
- **BPS precision**: thresholds are in basis points (BPS, 10_000 == 100%). Default `DRAIN_THRESHOLD_BPS = 2000` (20%).
- **Baseline**: computed as the maximum stake across up to the previous 3 samples (data[1..3]).
- **Persistence check**: to avoid single-block flukes, the trap requires at least 2 of those previous samples to be at or below the threshold floor before triggering.
- **Rich response payload**: when triggering (or returning diagnostics) the trap returns `abi.encode(target, baseline, newest, dropBps, thresholdBps)`. The responder emits an event including thresholdBps for provenance.

## Contracts
- `EigenStakeDrainTrap.sol`
  - `collect()` → `abi.encode(blockNumber, totalStaked)` (view)
  - `shouldRespond(bytes[] newestToOldest)` → `(bool, bytes)` where `bytes = abi.encode(address target, uint256 baseline, uint256 newest, uint256 dropBps, uint256 thresholdBps)`

- `EigenResponder.sol` (updated)
  - `respondToStakeDrain(address target, uint256 baselineStake, uint256 newestStake, uint256 dropBps, uint256 thresholdBps)`
  - Emits `StakeDrainAlert(caller, target, baselineStake, newestStake, dropBps, thresholdBps, timestamp)`

## drosera.toml (response_function)
Set:

