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

        token0.mint(address(this), 100);
        token0.approve(address(CSAMMcontract), 100);
        token1.mint(address(this), 100);
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
        uint res0prebal = CSAMMcontract.reserve0();
        uint res1prebal = CSAMMcontract.reserve1();
        CSAMMcontract.swap(address(token0), 10);
        assertEq(CSAMMcontract.reserve0(), res0prebal + 10);
        assertEq(CSAMMcontract.reserve0(), 60);
        assertEq(token0.balanceOf(address(this)), token0BalBefore - 10);
        // 0.3% fee -> 10 * .997 = 9
        uint amountOut = uint(10 * 997) / 1000;
        assertEq(CSAMMcontract.reserve1(), res1prebal - amountOut);
        assertEq(CSAMMcontract.reserve1(), 41);
        assertEq(token1.balanceOf(address(this)), token1BalBefore + amountOut);
    }

    function test__swapToken1() public {
        CSAMMcontract.addLiquidity(50, 50);
        uint token0BalBefore = token0.balanceOf(address(this));
        uint token1BalBefore = token1.balanceOf(address(this));
        uint res0prebal = CSAMMcontract.reserve0();
        uint res1prebal = CSAMMcontract.reserve1();
        CSAMMcontract.swap(address(token1), 10);
        // 0.3% fee -> 10 * .997 = 9
        uint amountOut = uint(10 * 997) / 1000;
        assertEq(CSAMMcontract.reserve0(), res0prebal - amountOut);
        assertEq(CSAMMcontract.reserve0(), 41);
        assertEq(token0.balanceOf(address(this)), token0BalBefore + amountOut);
        assertEq(CSAMMcontract.reserve1(), res1prebal + 10);
        assertEq(CSAMMcontract.reserve1(), 60);
        assertEq(token1.balanceOf(address(this)), token1BalBefore - 10);
    }

    function test_RemoveLiquidityInvalidShares() public {
        CSAMMcontract.addLiquidity(100, 100);
        uint _shares = CSAMMcontract.balanceOf(address(this));
        vm.expectRevert(bytes("invalid quantity"));
        CSAMMcontract.removeLiquidity(_shares + 1);
    }

    function test__removeLiquidity() public {
        CSAMMcontract.addLiquidity(100, 100);
        uint _shares = CSAMMcontract.balanceOf(address(this));
        CSAMMcontract.removeLiquidity(_shares);
        assertEq(token0.balanceOf(address(this)), 100);
        assertEq(token1.balanceOf(address(this)), 100);
        assertEq(CSAMMcontract.balanceOf(address(this)), 0);
        assertEq(CSAMMcontract.totalSupply(), 0);
        assertEq(CSAMMcontract.reserve0(), 0);
        assertEq(CSAMMcontract.reserve1(), 0);
    }

    function test__removeLiquidityMultiple() public {
        CSAMMcontract.addLiquidity(100, 100);
        vm.startPrank(bob);
        token0.mint(address(bob), 200);
        token1.mint(address(bob), 200);
        token0.approve(address(CSAMMcontract), 200);
        token1.approve(address(CSAMMcontract), 200);
        CSAMMcontract.addLiquidity(150, 150);
        // shares = ((d0 + d1) * totalSupply) / (reserve0 + reserve1)
        uint _bobShares = ((150 + 150) * CSAMMcontract.totalSupply()) /
            (CSAMMcontract.reserve0() + CSAMMcontract.reserve1());
        CSAMMcontract.removeLiquidity(_bobShares);
        // d0 = (reserve0 * _shares) / totalSupply;
        // d1 = (reserve1 * _shares) / totalSupply;
        assertEq(
            token0.balanceOf(address(bob)),
            50 +
                ((CSAMMcontract.reserve0() * _bobShares) /
                    CSAMMcontract.totalSupply())
        );
        assertEq(
            token1.balanceOf(address(bob)),
            50 +
                ((CSAMMcontract.reserve1() * _bobShares) /
                    CSAMMcontract.totalSupply())
        );
        vm.stopPrank();
    }

    function testFuzz__addLiquidity(uint256 amount0, uint256 amount1) public {
        vm.assume(amount0 > 0 && amount1 > 0);
        vm.assume(amount0 <= token0.totalSupply());
        vm.assume(amount1 <= token1.totalSupply());
        vm.assume(amount0 <= token0.balanceOf(address(this)));
        vm.assume(amount1 <= token1.balanceOf(address(this)));
        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);
        token0.approve(address(CSAMMcontract), amount0);
        token1.approve(address(CSAMMcontract), amount1);
        CSAMMcontract.addLiquidity(amount0, amount1);
        assertEq(CSAMMcontract.reserve0(), amount0);
        assertEq(CSAMMcontract.reserve1(), amount1);
        assertEq(CSAMMcontract.balanceOf(address(this)), amount0 + amount1);
        assertEq(CSAMMcontract.totalSupply(), amount0 + amount1);
    }

    function testFuzz__swap(uint256 swapAmount) public {
        vm.assume(swapAmount > 0);
        vm.assume(swapAmount <= token0.totalSupply());
        vm.assume(swapAmount <= token1.totalSupply());
        vm.assume(swapAmount <= token0.balanceOf(address(this)));

        token0.mint(address(this), 100);
        token1.mint(address(this), 100);
        token0.approve(address(CSAMMcontract), 200);
        token1.approve(address(CSAMMcontract), 200);
        CSAMMcontract.addLiquidity(100, 100);
        uint token0BalBefore = token0.balanceOf(address(this));
        uint token1BalBefore = token1.balanceOf(address(this));
        uint res0prebal = CSAMMcontract.reserve0();
        uint res1prebal = CSAMMcontract.reserve1();
        token0.approve(address(CSAMMcontract), swapAmount);
        CSAMMcontract.swap(address(token0), swapAmount);
        assertEq(CSAMMcontract.reserve0(), res0prebal + swapAmount);
        assertEq(token0.balanceOf(address(this)), token0BalBefore - swapAmount);
        uint amountOut = uint(swapAmount * 997) / 1000;
        assertEq(CSAMMcontract.reserve1(), res1prebal - amountOut);
        assertEq(token1.balanceOf(address(this)), token1BalBefore + amountOut);
    }

    function testFuzz__multiSwap(uint256 swapAmount0, uint256 swapAmount1)
        public
    {
        vm.assume(swapAmount0 > 0 && swapAmount1 > 0);
        vm.assume(swapAmount0 <= token0.totalSupply());
        vm.assume(swapAmount1 <= token1.totalSupply());
        vm.assume(swapAmount0 <= token0.balanceOf(address(this)));
        vm.assume(swapAmount1 <= token1.balanceOf(address(this)));

        token0.mint(address(this), 100);
        token1.mint(address(this), 100);
        token0.approve(address(CSAMMcontract), 200);
        token1.approve(address(CSAMMcontract), 200);
        CSAMMcontract.addLiquidity(100, 100);
        token0.approve(address(CSAMMcontract), swapAmount0);
        // first swap
        CSAMMcontract.swap(address(token0), swapAmount0);
        uint token0BalBefore = token0.balanceOf(address(this));
        uint token1BalBefore = token1.balanceOf(address(this));
        uint res0prebal = CSAMMcontract.reserve0();
        uint res1prebal = CSAMMcontract.reserve1();
        uint amountOut = (swapAmount1 * 997) / 1000;
        token1.approve(address(CSAMMcontract), swapAmount1);
        // second swap
        CSAMMcontract.swap(address(token1), swapAmount1);
        assertEq(
            token1.balanceOf(address(this)),
            token1BalBefore - swapAmount1
        );
        assertEq(CSAMMcontract.reserve1(), res1prebal + swapAmount1);
        assertEq(token0.balanceOf(address(this)), token0BalBefore + amountOut);
        assertEq(CSAMMcontract.reserve0(), res0prebal - amountOut);
    }

    function testFuzz__RemoveLiquidity(uint256 shares) public {
        vm.assume(shares <= CSAMMcontract.balanceOf(address(this)));

        CSAMMcontract.addLiquidity(100, 100);
        uint token0prebal = token0.balanceOf(address(this));
        uint token1prebal = token1.balanceOf(address(this));
        uint contractSharesBefore = CSAMMcontract.totalSupply();
        uint res0prebal = CSAMMcontract.reserve0();
        uint res1prebal = CSAMMcontract.reserve1();
        uint d0 = (CSAMMcontract.reserve0() * shares) /
            CSAMMcontract.totalSupply();
        uint d1 = (CSAMMcontract.reserve1() * shares) /
            CSAMMcontract.totalSupply();
        CSAMMcontract.removeLiquidity(shares);
        assertEq(token0.balanceOf(address(this)), token0prebal + d0);
        assertEq(token1.balanceOf(address(this)), token1prebal + d1);
        assertEq(CSAMMcontract.totalSupply(), contractSharesBefore - shares);
        assertEq(CSAMMcontract.reserve0(), res0prebal - d0);
        assertEq(CSAMMcontract.reserve1(), res1prebal - d1);
    }
}
