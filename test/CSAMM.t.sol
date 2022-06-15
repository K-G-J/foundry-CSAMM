// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/test.sol";
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

    function test__constructorNonZeror() public {
        vm.expectRevert(bytes("invalid address"));
        new CSAMM(address(0), address(token1));
    }

    function test__addLiquidity() public {
        CSAMMcontract.addLiquidity(100, 100);
        assertEq(CSAMMcontract.balanceOf(address(this)), 200);
        assertEq(CSAMMcontract.reserve0(), 100);
        assertEq(CSAMMcontract.reserve1(), 100);
        assertEq(CSAMMcontract.totalSupply(), 200);
    }

    function test__addLiquidityMultiple() public {
        CSAMMcontract.addLiquidity(100, 100);
        vm.startPrank(bob);
        token0.mint(address(bob), 2e18);
        token1.mint(address(bob), 2e18);
        token0.approve(address(CSAMMcontract), 200);
        token1.approve(address(CSAMMcontract), 200);
        CSAMMcontract.addLiquidity(200, 200);
        vm.stopPrank();
        assertEq(CSAMMcontract.balanceOf(address(bob)), 400);
        assertEq(CSAMMcontract.reserve0(), 300);
        assertEq(CSAMMcontract.reserve1(), 300);
        assertEq(CSAMMcontract.totalSupply(), 600);
    }

    function test__swapToken0() public {
        CSAMMcontract.addLiquidity(50, 50);
        uint token0BalBefore = token0.balanceOf(address(this));
        uint token1BalBefore = token1.balanceOf(address(this));
        CSAMMcontract.swap(address(token0), 10);
        assertEq(CSAMMcontract.reserve0(), 60);
        assertEq(token0.balanceOf(address(this)), token0BalBefore - 10);
        // 0.3% fee -> 10 * .997 = 9
        assertEq(CSAMMcontract.reserve1(), 41);
        assertEq(token1.balanceOf(address(this)), token1BalBefore + 9);
    }

    function test__swapToken1() public {
        CSAMMcontract.addLiquidity(50, 50);
        uint token0BalBefore = token0.balanceOf(address(this));
        uint token1BalBefore = token1.balanceOf(address(this));
        CSAMMcontract.swap(address(token1), 10);
         // 0.3% fee -> 10 * .997 = 9
        assertEq(CSAMMcontract.reserve0(), 41);
        assertEq(token0.balanceOf(address(this)), token0BalBefore + 9);
        assertEq(CSAMMcontract.reserve1(), 60);
        assertEq(token1.balanceOf(address(this)), token1BalBefore - 10);
    }

    function test__removeLiquidity() public {
        CSAMMcontract.addLiquidity(100, 100);
        uint _shares = CSAMMcontract.balanceOf(address(this));
        CSAMMcontract.removeLiquidity(_shares);
        assertEq(token0.balanceOf(address(this)), 1e18);
        assertEq(token1.balanceOf(address(this)), 1e18);
        assertEq(CSAMMcontract.balanceOf(address(this)), 0);
        assertEq(CSAMMcontract.totalSupply(), 0);
        assertEq(CSAMMcontract.reserve0(), 0);
        assertEq(CSAMMcontract.reserve1(), 0);
    }

    function testFuzz__addLiquidity(uint256 amount0, uint256 amount1) public {
        vm.assume(amount0 > 0 && amount1 > 0);
        vm.assume(amount0 <= token0.totalSupply());
        vm.assume(amount1 <= token1.totalSupply());
        vm.assume(amount0 <= token0.balanceOf(address(this)));
        vm.assume(amount1 <= token1.balanceOf(address(this)));

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);
        token0.approve(address(this), amount0);
        token1.approve(address(this), amount1);
        CSAMMcontract.addLiquidity(amount0, amount1);
        assertEq(CSAMMcontract.reserve0(), amount0);
        assertEq(CSAMMcontract.reserve1(), amount1);
        assertEq(CSAMMcontract.balanceOf(address(this)), amount0 + amount1);
        assertEq(CSAMMcontract.totalSupply(), amount0 + amount1);
    }
}
