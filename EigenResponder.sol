// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

interface IStakingTarget {
    function totalStaked() external view returns (uint256);
}

/*
 EigenStakeDrainTrap (updated)
 - Assumes Drosera passes samples newest -> oldest (index 0 = newest/current).
 - Uses BPS (basis points) for threshold precision.
 - Baseline = max of up to previous 3 samples (data[1..min(3, len-1)]).
 - Requires that at least 2 of those previous samples are <= threshold floor (persistence).
 - shouldRespond returns (true, abi.encode(address target, uint256 baselineStake, uint256 newestStake, uint256 dropBps, uint256 thresholdBps))
*/
contract EigenStakeDrainTrap is ITrap {
    // ---- CONFIG (tune these as desired) ----
    IStakingTarget public constant TARGET = IStakingTarget(0xeE45e76ddbEDdA2918b8C7E3035cd37Eab3b5D41);

    uint256 internal constant BPS = 10_000;
    // 2000 BPS == 20%. Change if you want a different threshold.
    uint256 internal constant DRAIN_THRESHOLD_BPS = 2_000;

    // How many previous samples to consider as baseline (we use up to 3)
    uint256 internal constant BASELINE_SAMPLE_WINDOW = 3;

    // ---- ITrap implementation ----
    /// @notice collect() returns abi.encode(block.number, totalStaked) for current block.
    function collect() external view override returns (bytes memory) {
        uint256 staked = 0;
        if (address(TARGET) != address(0)) {
            try TARGET.totalStaked() returns (uint256 s) {
                staked = s;
            } catch {
                staked = 0;
            }
        }
        return abi.encode(block.number, staked);
    }

    /**
     * @notice shouldRespond expects samples array newest -> oldest (index 0 newest).
     * Each sample: abi.encode(uint256 blockNumber, uint256 totalStaked).
     * Returns (true, payload) where payload = abi.encode(address target, uint256 baselineStake, uint256 newestStake, uint256 dropBps, uint256 thresholdBps)
     */
    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        // need at least two samples (newest + >=1 prior)
        if (data.length < 2) {
            return (false, bytes(""));
        }

        // newest sample is data[0]; ignore block number
        (, uint256 newestStake) = abi.decode(data[0], (uint256, uint256));

        // Build baseline from the previous samples data[1..]
        uint256 availablePrev = data.length - 1; // number of previous samples present
        uint256 window = availablePrev < BASELINE_SAMPLE_WINDOW ? availablePrev : BASELINE_SAMPLE_WINDOW;

        if (window == 0) {
            // no previous samples to form baseline
            return (false, bytes(""));
        }

        // Compute baseline = max(previous window stakes)
        uint256 baseline = 0;
        for (uint256 i = 1; i <= window; i++) {
            (, uint256 s) = abi.decode(data[i], (uint256, uint256));
            if (s > baseline) {
                baseline = s;
            }
        }

        if (baseline == 0) {
            // nothing to compare against (baseline zero) — avoid division by zero
            return (false, abi.encode(address(0), baseline, newestStake, uint256(0), DRAIN_THRESHOLD_BPS));
        }

        // compute drop in BPS: ((baseline - newest) * BPS) / baseline
        uint256 dropBps;
        if (newestStake >= baseline) {
            dropBps = 0;
        } else {
            dropBps = ((baseline - newestStake) * BPS) / baseline;
        }

        // Persistence check: require at least 2 of the previous window samples are <= threshold floor
        uint256 requiredViolations = 2;
        uint256 violations = 0;
        uint256 thresholdStakeFloor = (baseline * (BPS - DRAIN_THRESHOLD_BPS)) / BPS; // stake <= this means drop >= threshold

        for (uint256 i = 1; i <= window; i++) {
            (, uint256 s) = abi.decode(data[i], (uint256, uint256));
            if (s <= thresholdStakeFloor) {
                violations++;
            }
        }

        if (dropBps >= DRAIN_THRESHOLD_BPS && violations >= requiredViolations) {
            // Trigger response. Include target address and dropBps and threshold in payload for richer downstream logs.
            return (true, abi.encode(address(TARGET), baseline, newestStake, dropBps, DRAIN_THRESHOLD_BPS));
        }

        // No trigger, but return diagnostics payload so operators can inspect.
        return (false, abi.encode(address(TARGET), baseline, newestStake, dropBps, DRAIN_THRESHOLD_BPS));
    }
}
