// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 Simple Response contract: Drosera operators will call this when shouldRespond() returns true.
 The response function signature matches the payload returned by shouldRespond:
   respondToStakeDrain(uint256 oldStake, uint256 newStake, uint256 dropPercent)
*/
contract EigenResponder {
    event StakeDrainAlert(address indexed caller, uint256 oldStake, uint256 newStake, uint256 dropPercent, uint256 timestamp);

    /// This is the response function Drosera operators will call.
    /// It emits an on-chain event so the action is auditable / verifiable.
    function respondToStakeDrain(uint256 oldStake, uint256 newStake, uint256 dropPercent) external {
        emit StakeDrainAlert(msg.sender, oldStake, newStake, dropPercent, block.timestamp);
        // Keep response simple and permissionless. Optional followup actions can be added here.
    }
}
