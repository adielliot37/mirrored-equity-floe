// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockEquityToken} from "../src/MockEquityToken.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {NvdaLendingPool} from "../src/NvdaLendingPool.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

contract NvdaLendingPoolTest is Test {
    MockEquityToken internal nvda;
    MockUSDC internal usdc;
    NvdaLendingPool internal pool;
    MockOracle internal oracle;

    address internal lender = address(0xBEEF);
    address internal borrower = address(0xCAFE);
    address internal liquidator = address(0xD00D);

    function setUp() external {
        nvda = new MockEquityToken("NVIDIA Token", "NVDA", 18);
        oracle = new MockOracle(8);
        oracle.setPrice(500 * 1e8);
        usdc = new MockUSDC();
        pool = new NvdaLendingPool(address(nvda), address(usdc), address(oracle));

        nvda.mint(borrower, 1_000 ether);
        usdc.mint(lender, 1_000_000 * 1e6);
        usdc.mint(liquidator, 1_000_000 * 1e6);

        vm.prank(lender);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(borrower);
        nvda.approve(address(pool), type(uint256).max);
        vm.prank(borrower);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(liquidator);
        usdc.approve(address(pool), type(uint256).max);
    }

    function testBorrowFlow() external {
        vm.startPrank(lender);
        pool.depositUSDC(200_000 * 1e6);
        vm.stopPrank();

        vm.startPrank(borrower);
        pool.depositCollateral(100 ether);

        pool.borrow(20_000 * 1e6, 30 days);

        uint256 debt = pool.getUserDebt(borrower);
        assertApproxEqAbs(debt, 20_000 * 1e6, 2);
        vm.stopPrank();
    }

    function testCannotWithdrawWhenHealthLow() external {
        vm.prank(lender);
        pool.depositUSDC(200_000 * 1e6);

        vm.startPrank(borrower);
        pool.depositCollateral(100 ether);
        pool.borrow(30_000 * 1e6, 60 days);

        oracle.setPrice(300 * 1e8); // price drop hurts collateral
        vm.expectRevert(NvdaLendingPool.OutstandingDebt.selector);
        pool.withdrawCollateral(10 ether);
        vm.stopPrank();
    }

    function testCannotWithdrawWhileDebtOutstanding() external {
        vm.prank(lender);
        pool.depositUSDC(200_000 * 1e6);

        vm.startPrank(borrower);
        pool.depositCollateral(100 ether);
        pool.borrow(10_000 * 1e6, 30 days);
        vm.expectRevert(NvdaLendingPool.OutstandingDebt.selector);
        pool.withdrawCollateral(1 ether);
        vm.stopPrank();
    }

    function testLiquidationPath() external {
        vm.prank(lender);
        pool.depositUSDC(200_000 * 1e6);

        vm.startPrank(borrower);
        pool.depositCollateral(100 ether);
        pool.borrow(25_000 * 1e6, 90 days);
        vm.stopPrank();

        oracle.setPrice(250 * 1e8);

        vm.startPrank(liquidator);
        pool.liquidate(borrower, 10_000 * 1e6);
        vm.stopPrank();

        uint256 debt = pool.getUserDebt(borrower);
        assertLt(debt, 25_000 * 1e6);
        assertGt(nvda.balanceOf(liquidator), 0);
    }

    function testLenderPositionTracksPrincipal() external {
        vm.prank(lender);
        pool.depositUSDC(100_000 * 1e6);
        (uint256 balance, uint256 principal, uint256 interest) = pool.getLenderPosition(lender);
        assertEq(balance, 100_000 * 1e6);
        assertEq(principal, 100_000 * 1e6);
        assertEq(interest, 0);

        vm.startPrank(borrower);
        pool.depositCollateral(200 ether);
        pool.borrow(30_000 * 1e6, 30 days);
        vm.stopPrank();

        vm.prank(lender);
        pool.withdrawUSDC(20_000 * 1e6);
        (, principal,) = pool.getLenderPosition(lender);
        assertEq(principal, 80_000 * 1e6);
    }

    function testBorrowerPositionShowsInterest() external {
        vm.prank(lender);
        pool.depositUSDC(200_000 * 1e6);

        vm.startPrank(borrower);
        pool.depositCollateral(200 ether);
        pool.borrow(40_000 * 1e6, 45 days);
        vm.stopPrank();

        (uint256 debt,, uint256 interest,,) = pool.getBorrowerPosition(borrower);
        assertEq(debt, 40_000 * 1e6);
        assertEq(interest, 0);

        vm.warp(block.timestamp + 30 days);
        vm.prank(lender);
        pool.depositUSDC(1_000); // triggers index update
        (debt,, interest,,) = pool.getBorrowerPosition(borrower);
        assertGt(debt, 40_000 * 1e6);
        assertGt(interest, 0);

        vm.startPrank(borrower);
        pool.repay(10_000 * 1e6);
        vm.stopPrank();
        (, uint256 principalAfter,,,) = pool.getBorrowerPosition(borrower);
        assertEq(principalAfter, 30_000 * 1e6);
    }

    function testAvailableLiquidityCapsBorrow() external {
        vm.prank(lender);
        pool.depositUSDC(40_000 * 1e6);

        vm.startPrank(borrower);
        pool.depositCollateral(500 ether);
        vm.stopPrank();

        uint256 liquidity = pool.availableLiquidity();
        assertEq(liquidity, 40_000 * 1e6);
        uint256 maxBorrow = pool.maxBorrowable(borrower);
        assertEq(maxBorrow, liquidity);
    }
}

contract MockOracle is AggregatorV2V3Interface {
    uint8 public immutable override decimals;
    int256 private _price;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setPrice(int256 price) external {
        _price = price;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80)
    {
        return (0, _price, 0, block.timestamp, 0);
    }

    function description() external pure override returns (string memory) {
        return "MOCK";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function latestAnswer() external view override returns (int256) {
        return _price;
    }

    function latestTimestamp() external view override returns (uint256) {
        return block.timestamp;
    }

    function latestRound() external pure override returns (uint256) {
        return 0;
    }

    function getAnswer(uint256) external view override returns (int256) {
        return _price;
    }

    function getTimestamp(uint256) external view override returns (uint256) {
        return block.timestamp;
    }

    function getRoundData(uint80)
        external
        pure
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert("not-implemented");
    }
}

