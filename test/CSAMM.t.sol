// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/test.sol";
import "forge-std/Vm.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "../src/CSAMM.sol";
import "../src/interfaces/IERC20.sol";

contract CSAMMTest is Test {

    address alice = address(0x1337);
    address bob = address(0x133702);

    MockERC20 token0;
    MockERC20 token1;
    CSAMM CSAMMcontract;

    function setUp() public {
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(this), "CSAMMTest");

        token0 = new MockERC20("Token0", "TTO", 18);
        token1 = new MockERC20("Token1", "TT1", 18);
        vm.label(address(token0), "Token0");
        vm.label(address(token1), "Token1");

        CSAMMcontract = new CSAMM(address(token0), address(token1));

        token0.mint(address(this), 1e18);
        token0.approve(address(CSAMMcontract), 100);
        token1.mint(address(this), 1e18);
        token1.approve(address(CSAMMcontract), 100);
    }

    function testExample() public {
        assertTrue(true);
    }
}
