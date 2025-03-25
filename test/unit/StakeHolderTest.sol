// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StakeHolder} from "../../src/StakeHolder.sol";
import {DeployStakeHolder} from "../../script/DeployStakeHolder.s.sol";
import {Test, console} from "forge-std/Test.sol";

contract StakeHolderTest is Test {
    StakeHolder stake;
    DeployStakeHolder deployStake;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_BALANCE = 10000 ether;
    uint256 public constant MINIMAL_STAKE = 1000 ether; // because the stake duration 1 days, so minimal amount for staking need as much as possible
    uint256 public constant STAKE_DURATION = 1 days;

    mapping(address => uint256) public s_holderBalance;

    event EnteredStaking(address holder, uint256 amount);
    event WithdrawSuccess(address holder, uint256 amount);

    modifier enterStaking() {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);
        _;
    }

    function setUp() external {
        stake = new StakeHolder();
        deployStake = new DeployStakeHolder();

        vm.deal(USER, STARTING_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                         TEST ENTER STAKING
    //////////////////////////////////////////////////////////////*/
    function test_EnterStaking() public {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);
    }

    function test_EnterStakingTwice() public enterStaking {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        uint256 contarctBalance = address(stake).balance;
        console.log(contarctBalance);
    }

    function test_EnterStakingMultipleTimes() public {
        uint256 enterNumber = 10;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < startingIndex + enterNumber; i++) {
            address newHolder = makeAddr(string(abi.encodePacked("holder", vm.toString(i))));
            hoax(newHolder, STARTING_BALANCE);

            vm.expectEmit(true, true, false, false, address(stake));
            emit EnteredStaking(USER, MINIMAL_STAKE);
            stake.enterStaking{value: MINIMAL_STAKE}();
            vm.warp(block.timestamp + 1);
            vm.roll(block.number + 1);
            stake.setStakeState(StakeHolder.StakeState.locked);

            s_holderBalance[newHolder] = newHolder.balance;
        }
    }

    function test_EnterStakingFalseWhenSendValueLessThanMinimalStake() public {
        vm.prank(USER);
        vm.expectRevert(StakeHolder.StakeHolder__NotEnoughDepositToStake.selector);
        stake.enterStaking{value: 4e15}();
    }

    function test_EnterStakingFalseWhenSendValueToMuchThanMinimalStake() public {
        vm.prank(USER);
        uint256 depoAmount = MINIMAL_STAKE;
        vm.expectRevert(
            abi.encodeWithSelector(StakeHolder.StakeHolder__NeedCorrectAmountToDeposit.selector, depoAmount)
        );
        stake.enterStaking{value: 1001 ether}();
    }

    /*//////////////////////////////////////////////////////////////
                         CHECK STAKING DURATION
    //////////////////////////////////////////////////////////////*/
    function test_CheckStakingDuration() public {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();

        bool stakingStatusBefore = stake.checkStakingDuration(USER);
        assertEq(stakingStatusBefore, false, "DEPOSIT FIRST TO ENTER STAKING AND CHECK YOUR STAKING DURATION");

        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 1);

        bool stakingStatusAfter = stake.checkStakingDuration(USER);
        assertEq(stakingStatusAfter, true, "YOUR STAKING COMPLETE");
    }

    function test_CheckStakingReturnFalseBecauseNotStakeHolder() public {
        address notHolder = makeAddr("notHolder");

        bool stakingStatusNonHolder = stake.checkStakingDuration(notHolder);
        assertEq(stakingStatusNonHolder, false, "YOUR NOT HOLDER");
    }

    /*//////////////////////////////////////////////////////////////
                          TEST UNLOCK STAKING
    //////////////////////////////////////////////////////////////*/
    function test_UnlockStaking() public {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        bool stakingStatusBefore = stake.checkStakingDuration(USER);
        assertEq(stakingStatusBefore, false, "STAKING NOT COMPLETE");

        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 1);

        bool stakingStatusAfter = stake.checkStakingDuration(USER);
        assertEq(stakingStatusAfter, true, "YOUR STAKING COMPLETE");
        stake.setStakeState(StakeHolder.StakeState.unlocked);

        vm.prank(USER);
        stake.unlockStaking();
    }

    function test_UnlockStakingReturnFalseBecauseNotHolder() public {
        address notHolder = makeAddr("notHolder");

        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        bool stakingStatusBefore = stake.checkStakingDuration(USER);
        assertEq(stakingStatusBefore, false, "STAKING NOT COMPLETE");

        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 1);

        bool stakingStatusAfter = stake.checkStakingDuration(USER);
        assertEq(stakingStatusAfter, true, "YOUR STAKING COMPLETE");
        stake.setStakeState(StakeHolder.StakeState.unlocked);

        vm.prank(notHolder);
        vm.expectRevert(StakeHolder.StakeHolder__YourNotHolder.selector);
        stake.unlockStaking();
    }

    function test_UnlockStakingBeforeStakingDurationComplete() public {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        bool stakingStatusBefore = stake.checkStakingDuration(USER);
        assertEq(stakingStatusBefore, false, "STAKING NOT COMPLETE");

        vm.prank(USER);
        vm.expectRevert(StakeHolder.StakeHolder__StakingTimeIsNotDone.selector);
        stake.unlockStaking();
    }

    /*//////////////////////////////////////////////////////////////
                         TEST CALCULATE REWARD
    //////////////////////////////////////////////////////////////*/
    function test_CalculateReward() public {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.timestamp + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.unlocked);

        uint256 ANNUAL_RATE = 2000; // 20%
        uint256 expectReward = (MINIMAL_STAKE * ANNUAL_RATE * STAKE_DURATION) / (365 days * 10000);

        vm.prank(USER);
        uint256 actualReward = stake.calculateReward(USER);

        assertEq(actualReward, expectReward, "Reward calculation incorrect for 1 day staking with 1000 ether");
        console.log("Stake amount: ", MINIMAL_STAKE / 1, "ether");
        console.log("Stake duration in days: ", STAKE_DURATION / 1 days, "days");
        console.log("Expect Reward: ", expectReward, "wei");
        console.log("Actual Reward: ", actualReward, "wei");
    }

    function test_CalculateRewardReturnZeroBecauseNoHolder() public {
        vm.prank(USER);
        stake.calculateReward(USER);
    }

    /*//////////////////////////////////////////////////////////////
                             TEST WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function test_Withdraw() public {
        vm.deal(address(stake), 2 * MINIMAL_STAKE);

        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        uint256 initialContractBalance = address(stake).balance;
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.unlocked);

        uint256 stakeAmount = stake.getHolderStakeAmount(USER);
        uint256 ANNUAL_RATE = 2000; // 20%
        uint256 expectReward = (stakeAmount * ANNUAL_RATE * STAKE_DURATION) / (365 days * 10000);

        vm.prank(USER);
        uint256 actualReward = stake.calculateReward(USER);

        assertEq(actualReward, expectReward, "Reward calculation incorrect for 1 day staking with 1000 ether");
        console.log("Stake amount: ", MINIMAL_STAKE / 1, "ether");
        console.log("Stake duration in days: ", STAKE_DURATION / 1 days, "days");
        console.log("Expect Reward: ", expectReward, "wei");
        console.log("Actual Reward: ", actualReward, "wei");

        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit WithdrawSuccess(USER, actualReward);
        stake.withdraw(USER);

        uint256 finalContractBalance = address(stake).balance;

        assertEq(stake.getHolderStakeAmount(USER), 0, "stake amount should be zero because it withdrawl");
        assertEq(stake.getHolderTimeStamps(USER), 0, "timeStamp should be zero because it withdrawl");
        assertEq(
            initialContractBalance - finalContractBalance,
            actualReward,
            "Contract balance should decrease by withdrawn amount"
        );
    }

    function test_WithdrawReturnFalseBecauseNotHolder() public {
        address notHolder = makeAddr("notHolder");

        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.unlocked);

        uint256 stakeAmount = stake.getHolderStakeAmount(USER);
        uint256 ANNUAL_RATE = 2000; // 20%
        uint256 expectReward = (stakeAmount * ANNUAL_RATE * STAKE_DURATION) / (365 days * 10000);

        vm.prank(USER);
        uint256 actualReward = stake.calculateReward(USER);

        assertEq(actualReward, expectReward, "Reward calculation incorrect for 1 day staking with 1000 ether");
        console.log("Stake amount: ", MINIMAL_STAKE / 1, "ether");
        console.log("Stake duration in days: ", STAKE_DURATION / 1 days, "days");
        console.log("Expect Reward: ", expectReward, "wei");
        console.log("Actual Reward: ", actualReward, "wei");

        vm.prank(notHolder);
        vm.expectRevert(StakeHolder.StakeHolder__YourNotHolder.selector);
        stake.withdraw(notHolder);
    }

    function test_WithdrawReturnFalseBecauseSomeoneUseHolderAddressToWithdraw() public {
        address notHolder = makeAddr("notHolder");

        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        vm.warp(block.timestamp + STAKE_DURATION);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.unlocked);

        uint256 stakeAmount = stake.getHolderStakeAmount(USER);
        uint256 ANNUAL_RATE = 2000; // 20%
        uint256 expectReward = (stakeAmount * ANNUAL_RATE * STAKE_DURATION) / (365 days * 10000);

        vm.prank(USER);
        uint256 actualReward = stake.calculateReward(USER);

        assertEq(actualReward, expectReward, "Reward calculation incorrect for 1 day staking with 1000 ether");
        console.log("Stake amount: ", MINIMAL_STAKE / 1, "ether");
        console.log("Stake duration in days: ", STAKE_DURATION / 1 days, "days");
        console.log("Expect Reward: ", expectReward, "wei");
        console.log("Actual Reward: ", actualReward, "wei");

        vm.prank(notHolder);
        vm.expectRevert(StakeHolder.StakeHolder__WithdrawFailed.selector);
        stake.withdraw(USER);
    }

    function test_WithdrawReturnFalseBecauseStakingDurationNotDone() public {
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(stake));
        emit EnteredStaking(USER, MINIMAL_STAKE);
        stake.enterStaking{value: MINIMAL_STAKE}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        stake.setStakeState(StakeHolder.StakeState.locked);

        vm.prank(USER);
        vm.expectRevert(StakeHolder.StakeHolder__StakingTimeIsNotDone.selector);
        stake.withdraw(USER);
    }

    /*//////////////////////////////////////////////////////////////
                          TEST GETTER FUNCTION
    //////////////////////////////////////////////////////////////*/
    function test_SetStakeState() public {
        stake.setStakeState(StakeHolder.StakeState.locked);
        stake.setStakeState(StakeHolder.StakeState.unlocked);
    }

    function test_GetStakeState() public view {
        // the state always default locked(0) if not set the state first
        // stake.setStakeState(StakeHolder.StakeState.unlocked);
        stake.getStakeState();
    }

    function test_GetHolderStakeAmount() public enterStaking {
        stake.getHolderStakeAmount(USER);
    }

    function test_GetHolderTimeStamp() public enterStaking {
        stake.getHolderTimeStamps(USER);
    }

    function test_DeployRun() public {
        deployStake.run();
    }
}
