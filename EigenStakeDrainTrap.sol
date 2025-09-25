// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 Updated EigenResponder:
 Signature: respondToStakeDrain(address target, uint256 baselineStake, uint256 newestStake, uint256 dropBps, uint256 thresholdBps)
 Emits StakeDrainAlert(address caller, address target, uint256 baselineStake, uint256 newestStake, uint256 dropBps, uint256 thresholdBps, uint256 timestamp)
*/
contract EigenResponder {
    event StakeDrainAlert(
        address indexed caller,
        address indexed target,
        uint256 baselineStake,
        uint256 newestStake,
        uint256 dropBps,
        uint256 thresholdBps,
        uint256 timestamp
    );

    /// Called by operators when shouldRespond() returns true. Emits a rich event with the configured threshold.
    function respondToStakeDrain(address target, uint256 baselineStake, uint256 newestStake, uint256 dropBps, uint256 thresholdBps) external {
        emit StakeDrainAlert(msg.sender, target, baselineStake, newestStake, dropBps, thresholdBps, block.timestamp);
        // Optional follow-ups could be added, but keep it permissionless and auditable.
    }
}
