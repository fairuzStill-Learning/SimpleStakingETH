pragma solidity ^0.8.19;
//SPDX-License-Identifier: MIT

contract StakeHolder {
    /* Custom Errors */
    error StakeHolder__YourNotHolder();
    error StakeHolder__NotEnoughDepositToStake();
    error StakeHolder__NeedCorrectAmountToDeposit(uint256 depoAmount);
    error StakeHolder__StakingTimeIsNotDone();
    error StakeHolder__WithdrawFailed();

    enum StakeState {
        locked,
        unlocked
    }

    event EnteredStaking(address holder, uint256 amount);
    event WithdrawSuccess(address holder, uint256 amount);

    /* State Variables */
    address payable[] private s_holders;
    uint256 public constant MINIMAL_STAKE = 1000 ether; // 5000000000000000 wei or $9.77
    uint256 public constant STAKE_DURATION = 1 days;
    StakeState private s_StakeState;

    mapping(address => uint256) private s_depositTimeStamps;
    mapping(address => StakeState) private s_holderStakeState;
    mapping(address => uint256) private s_stakedAmount;

    receive() external payable {}
    fallback() external payable {}

    function enterStaking() public payable {
        // Check if msg.value not less than minimal amount stake.
        // Check if msg.sender not send to much msg.value for deposit.
        // Push or add msg.sender to array s_holders.
        // Track holder time stake using mapping.
        // Change stake state to locked.
        // Emit the holder
        if (msg.value < MINIMAL_STAKE) {
            revert StakeHolder__NotEnoughDepositToStake();
        }

        if (msg.value > MINIMAL_STAKE) {
            revert StakeHolder__NeedCorrectAmountToDeposit(uint256(MINIMAL_STAKE));
        }

        s_holders.push(payable(msg.sender));
        s_depositTimeStamps[msg.sender] = block.timestamp;
        s_holderStakeState[msg.sender] = StakeState.locked;
        s_stakedAmount[msg.sender] += msg.value;

        emit EnteredStaking(msg.sender, msg.value);
    }

    function checkStakingDuration(address holder) public view returns (bool) {
        // Check if mapping have holder.
        // If have holder, check if block.timestamp greater than time whenDeposit + stake_time.
        if (s_depositTimeStamps[holder] == 0) {
            return false;
        }

        return (block.timestamp >= s_depositTimeStamps[holder] + STAKE_DURATION);
    }

    function unlockStaking() public {
        // Check if mapping have msg.sender.
        // Check if block.timestamp greater than time whenDeposit + stake_time.
        // And unlocked the stake
        if (s_depositTimeStamps[msg.sender] == 0) {
            revert StakeHolder__YourNotHolder();
        }

        if (checkStakingDuration(msg.sender)) {
            s_holderStakeState[msg.sender] = StakeState.unlocked;
        } else {
            revert StakeHolder__StakingTimeIsNotDone();
        }
    }

    function calculateReward(address holder) public view returns (uint256) {
        if (s_stakedAmount[holder] == 0) {
            return 0;
        }

        uint256 ANNUAL_RATE = 2000;
        uint256 reward = (s_stakedAmount[holder] * ANNUAL_RATE * STAKE_DURATION) / (365 days * 10000);
        return reward;
    }

    function withdraw(address holder) public {
        if (s_depositTimeStamps[holder] == 0) {
            revert StakeHolder__YourNotHolder();
        }

        if (s_StakeState != StakeState.unlocked) {
            if (checkStakingDuration(holder)) {
                s_holderStakeState[holder] = StakeState.unlocked;
            } else {
                revert StakeHolder__StakingTimeIsNotDone();
            }
        }

        uint256 stakeAmount = s_stakedAmount[holder];
        uint256 reward = calculateReward(holder);
        uint256 totalReward = stakeAmount + reward;

        s_stakedAmount[holder] = 0;
        s_depositTimeStamps[holder] = 0;

        (bool success,) = payable(holder).call{value: totalReward}("");
        if (!success) {
            revert StakeHolder__WithdrawFailed();
        }

        emit WithdrawSuccess(holder, totalReward);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setStakeState(StakeState _state) public {
        s_StakeState = _state;
    }

    function getStakeState() public view returns (StakeState) {
        return s_StakeState;
    }

    function getHolder(uint256 indexOfHolder) public view returns (address) {
        return s_holders[indexOfHolder];
    }

    function getHolderStakeAmount(address holder) public view returns (uint256) {
        return s_stakedAmount[holder];
    }

    function getHolderTimeStamps(address holder) public view returns (uint256) {
        return s_depositTimeStamps[holder];
    }
}
