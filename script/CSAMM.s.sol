// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {CSAMM} from "src/CSAMM.sol";

contract ContractScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        // new CSAMM(_token0, _token1);
        vm.stopBroadcast();
    }
}
