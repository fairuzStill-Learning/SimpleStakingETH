// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {StakeHolder} from "../src/StakeHolder.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployStakeHolder is Script {
    StakeHolder stake;

    function run() external {
        vm.startBroadcast();
        stake = new StakeHolder();
        vm.stopBroadcast();
    }
}
