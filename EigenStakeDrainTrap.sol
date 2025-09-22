// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

interface IStakingTarget {
    function totalStaked() external view returns (uint256);
}

contract EigenStakeDrainTrap is ITrap {
    // ---- CONFIG ----
    // Correctly checksummed response contract address:
    address public constant RESPONSE_CONTRACT = 0x6cE3f2F7391c7D451d2d1812FEf5B062c932267a;
    // Target staking contract (your provided address)
    IStakingTarget public constant TARGET = IStakingTarget(0xeE45e76ddbEDdA2918b8C7E3035cd37Eab3b5D41);
    uint256 public constant DRAIN_THRESHOLD_PERCENT = 20;

    // ---- ITrap implementation (minimal) ----
    /// @notice collect() returns (blockNumber, totalStaked) encoded
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

    /// @notice shouldRespond expects a timeseries: abi.encode(blockNumber, totalStaked)
    /// returns (true, abi.encode(oldStake, newStake, dropPercent)) when drop >= threshold
    function shouldRespond(bytes[] calldata data) external pure override returns (bool, bytes memory) {
        if (data.length < 2) {
            return (false, bytes(""));
        }

        (uint256 oldestBn, uint256 oldestStake) = abi.decode(data[0], (uint256, uint256));
        (uint256 newestBn, uint256 newestStake) = abi.decode(data[data.length - 1], (uint256, uint256));

        if (oldestBn == 0 || newestBn == 0) {
            return (false, bytes(""));
        }
        if (oldestStake == 0) {
            return (false, abi.encode(oldestStake, newestStake, uint256(0)));
        }

        uint256 drop;
        if (newestStake >= oldestStake) {
            drop = 0;
        } else {
            drop = ((oldestStake - newestStake) * 100) / oldestStake;
        }

        if (drop >= DRAIN_THRESHOLD_PERCENT) {
            return (true, abi.encode(oldestStake, newestStake, drop));
        }

        return (false, abi.encode(oldestStake, newestStake, drop));
    }
}
