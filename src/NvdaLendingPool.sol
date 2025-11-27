// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

contract NvdaLendingPool {
    using SafeERC20 for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant LTV_BPS = 6000;
    uint256 public constant LIQ_THRESHOLD_BPS = 7500;
    uint256 public constant BPS_DENOM = 10_000;
    uint256 public constant LIQUIDATION_BONUS_BPS = 10_500;
    uint256 public constant RESERVE_FACTOR_WAD = 0.1e18;

    uint256 public constant BASE_RATE_WAD = 0.05e18;
    uint256 public constant RATE_SLOPE_WAD = 0.45e18;

    IERC20 public immutable nvdaToken;
    IERC20 public immutable usdcToken;
    AggregatorV2V3Interface public immutable nvdaOracle;
    uint8 public immutable oracleDecimals;
    uint8 public immutable nvdaDecimals;

    uint256 public liquidityIndex = WAD;
    uint256 public borrowIndex = WAD;
    uint40 public lastUpdateTimestamp;

    uint256 public totalScaledDeposits;
    uint256 public totalScaledDebt;
    uint256 public totalCollateralNVDA;

    struct CollateralPosition {
        uint256 amountNVDA;
        uint256 scaledDebt;
        uint256 principalBorrowed;
        uint40 lastBorrowTimestamp;
        uint40 agreedDuration;
    }

    mapping(address => uint256) internal scaledDeposits;
    mapping(address => uint256) internal principalSupplied;
    mapping(address => CollateralPosition) internal positions;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount, uint256 durationSeconds, uint256 newDebt);
    event Repaid(address indexed user, uint256 amount, uint256 remainingDebt);
    event Liquidated(address indexed user, address indexed liquidator, uint256 repaidDebt, uint256 seizedCollateral);
    event DepositedUSDC(address indexed user, uint256 amount, uint256 newBalance);
    event WithdrawnUSDC(address indexed user, uint256 amount, uint256 remainingBalance);

    error AmountZero();
    error MaxBorrowExceeded();
    error InsufficientLiquidity();
    error HealthFactorTooLow();
    error NoDebt();
    error InvalidOraclePrice();
    error CollateralShortfall();
    error PositionHealthy();
    error OutstandingDebt();

    constructor(address _nvdaToken, address _usdcToken, address _oracle) {
        require(_nvdaToken != address(0) && _usdcToken != address(0) && _oracle != address(0), "Invalid address");
        nvdaToken = IERC20(_nvdaToken);
        usdcToken = IERC20(_usdcToken);
        nvdaOracle = AggregatorV2V3Interface(_oracle);
        oracleDecimals = nvdaOracle.decimals();
        nvdaDecimals = IERC20Metadata(_nvdaToken).decimals();
        lastUpdateTimestamp = uint40(block.timestamp);
    }


    function depositCollateral(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        positions[msg.sender].amountNVDA += amount;
        totalCollateralNVDA += amount;
        nvdaToken.safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        CollateralPosition storage pos = positions[msg.sender];
        if (pos.amountNVDA < amount) revert CollateralShortfall();
        if (pos.scaledDebt > 0) revert OutstandingDebt();
        pos.amountNVDA -= amount;
        totalCollateralNVDA -= amount;
        nvdaToken.safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function depositUSDC(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        _updateIndexes();
        uint256 scaledAmount = (amount * WAD) / liquidityIndex;
        scaledDeposits[msg.sender] += scaledAmount;
        totalScaledDeposits += scaledAmount;
        principalSupplied[msg.sender] += amount;
        usdcToken.safeTransferFrom(msg.sender, address(this), amount);
        emit DepositedUSDC(msg.sender, amount, getLenderBalance(msg.sender));
    }

    function withdrawUSDC(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        _updateIndexes();
        uint256 balance = getLenderBalance(msg.sender);
        if (amount > balance) revert InsufficientLiquidity();
        uint256 available = usdcToken.balanceOf(address(this));
        if (amount > available) revert InsufficientLiquidity();
        uint256 scaledAmount = _divUp(amount * WAD, liquidityIndex);
        scaledDeposits[msg.sender] -= scaledAmount;
        totalScaledDeposits -= scaledAmount;
        usdcToken.safeTransfer(msg.sender, amount);
        uint256 principal = principalSupplied[msg.sender];
        uint256 reduction = amount > principal ? principal : amount;
        principalSupplied[msg.sender] = principal - reduction;
        emit WithdrawnUSDC(msg.sender, amount, getLenderBalance(msg.sender));
    }

    function borrow(uint256 amount, uint256 durationSeconds) external {
        if (amount == 0) revert AmountZero();
        CollateralPosition storage pos = positions[msg.sender];
        if (pos.amountNVDA == 0) revert CollateralShortfall();

        _updateIndexes();

        if (amount > maxBorrowable(msg.sender)) revert MaxBorrowExceeded();
        uint256 available = usdcToken.balanceOf(address(this));
        if (amount > available) revert InsufficientLiquidity();

        uint256 scaledAmount = _divUp(amount * WAD, borrowIndex);
        pos.scaledDebt += scaledAmount;
        pos.principalBorrowed += amount;
        pos.lastBorrowTimestamp = uint40(block.timestamp);
        pos.agreedDuration = uint40(durationSeconds);
        totalScaledDebt += scaledAmount;

        usdcToken.safeTransfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount, durationSeconds, getUserDebt(msg.sender));
    }

    function repay(uint256 amount) external {
        if (amount == 0) revert AmountZero();
        _updateIndexes();

        CollateralPosition storage pos = positions[msg.sender];
        uint256 debt = getDebtValue(pos);
        if (debt == 0) revert NoDebt();

        uint256 repayAmount = amount > debt ? debt : amount;
        uint256 scaledReduction = _divUp(repayAmount * WAD, borrowIndex);
        if (scaledReduction > pos.scaledDebt) {
            scaledReduction = pos.scaledDebt;
            repayAmount = getDebtValue(pos);
        }

        pos.scaledDebt -= scaledReduction;
        totalScaledDebt -= scaledReduction;
        uint256 principalReduction = repayAmount > pos.principalBorrowed ? pos.principalBorrowed : repayAmount;
        pos.principalBorrowed -= principalReduction;

        usdcToken.safeTransferFrom(msg.sender, address(this), repayAmount);
        emit Repaid(msg.sender, repayAmount, getDebtValue(pos));
    }

    function liquidate(address user, uint256 repayAmount) external {
        if (repayAmount == 0) revert AmountZero();
        _updateIndexes();

        CollateralPosition storage pos = positions[user];
        uint256 debt = getDebtValue(pos);
        if (debt == 0) revert NoDebt();
        if (_healthFactor(pos) >= WAD) revert PositionHealthy();

        uint256 actualRepay = repayAmount > debt ? debt : repayAmount;
        uint256 scaledReduction = _divUp(actualRepay * WAD, borrowIndex);
        if (scaledReduction > pos.scaledDebt) {
            scaledReduction = pos.scaledDebt;
            actualRepay = getDebtValue(pos);
        }

        pos.scaledDebt -= scaledReduction;
        totalScaledDebt -= scaledReduction;
        uint256 principalReduction = actualRepay > pos.principalBorrowed ? pos.principalBorrowed : actualRepay;
        pos.principalBorrowed -= principalReduction;

        usdcToken.safeTransferFrom(msg.sender, address(this), actualRepay);

        uint256 collateralSeized = _usdToNvda(actualRepay, true);
        if (collateralSeized > pos.amountNVDA) {
            collateralSeized = pos.amountNVDA;
        }
        pos.amountNVDA -= collateralSeized;
        totalCollateralNVDA -= collateralSeized;

        nvdaToken.safeTransfer(msg.sender, collateralSeized);
        emit Liquidated(user, msg.sender, actualRepay, collateralSeized);
    }


    function getLenderBalance(address user) public view returns (uint256) {
        return (scaledDeposits[user] * liquidityIndex) / WAD;
    }

    function getUserDebt(address user) public view returns (uint256) {
        CollateralPosition storage pos = positions[user];
        return getDebtValue(pos);
    }

    function getCollateralAmount(address user) external view returns (uint256) {
        return positions[user].amountNVDA;
    }

    function getCollateralValueUSD(address user) public view returns (uint256) {
        return _collateralUsdValue(positions[user].amountNVDA);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(positions[user]);
    }

    function maxBorrowable(address user) public view returns (uint256) {
        CollateralPosition storage pos = positions[user];
        uint256 capacityUsd = (_collateralUsdValue(pos.amountNVDA) * LTV_BPS) / BPS_DENOM;
        uint256 debt = getDebtValue(pos);
        if (capacityUsd <= debt) return 0;
        uint256 headroom = capacityUsd - debt;
        uint256 liquidity = availableLiquidity();
        return headroom < liquidity ? headroom : liquidity;
    }

    function getRates() external view returns (uint256 utilization, uint256 borrowAPR, uint256 supplyAPR) {
        utilization = _utilization();
        borrowAPR = BASE_RATE_WAD + (RATE_SLOPE_WAD * utilization) / WAD;
        uint256 liquidityRate = borrowAPR * utilization / WAD;
        liquidityRate = liquidityRate * (WAD - RESERVE_FACTOR_WAD) / WAD;
        supplyAPR = liquidityRate;
    }

    function getUserSnapshot(address user)
        external
        view
        returns (
            uint256 collateralNVDA,
            uint256 collateralUSD,
            uint256 debtUSDC,
            uint256 maxBorrowUSDC,
            uint256 healthFactor,
            uint40 lastBorrowTimestamp,
            uint40 durationSeconds
        )
    {
        CollateralPosition storage pos = positions[user];
        collateralNVDA = pos.amountNVDA;
        collateralUSD = _collateralUsdValue(pos.amountNVDA);
        debtUSDC = getDebtValue(pos);
        maxBorrowUSDC = maxBorrowable(user);
        healthFactor = _healthFactor(pos);
        lastBorrowTimestamp = pos.lastBorrowTimestamp;
        durationSeconds = pos.agreedDuration;
    }

    function getBorrowerPosition(address user)
        external
        view
        returns (
            uint256 debtUSDC,
            uint256 principalUSDC,
            uint256 interestUSDC,
            uint256 maxBorrowUSDC,
            uint256 healthFactor
        )
    {
        CollateralPosition storage pos = positions[user];
        debtUSDC = getDebtValue(pos);
        principalUSDC = pos.principalBorrowed;
        interestUSDC = debtUSDC > principalUSDC ? debtUSDC - principalUSDC : 0;
        maxBorrowUSDC = maxBorrowable(user);
        healthFactor = _healthFactor(pos);
    }

    function collateralRequired(uint256 borrowAmount) external view returns (uint256) {
        if (borrowAmount == 0) return 0;
        uint256 collateralUsd = _divUp(borrowAmount * BPS_DENOM, LTV_BPS);
        return _usdToNvda(collateralUsd, false);
    }

    function getLenderPosition(address user)
        external
        view
        returns (uint256 balance, uint256 principal, uint256 interest)
    {
        balance = getLenderBalance(user);
        principal = principalSupplied[user];
        interest = balance > principal ? balance - principal : 0;
    }

    function availableLiquidity() public view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }

    function getPoolStats()
        external
        view
        returns (
            uint256 deposits,
            uint256 debt,
            uint256 liquidity
        )
    {
        deposits = (totalScaledDeposits * liquidityIndex) / WAD;
        debt = (totalScaledDebt * borrowIndex) / WAD;
        liquidity = availableLiquidity();
    }


    function _updateIndexes() internal {
        uint256 elapsed = block.timestamp - lastUpdateTimestamp;
        if (elapsed == 0) return;

        uint256 utilization = _utilization();
        uint256 borrowRate = BASE_RATE_WAD + (RATE_SLOPE_WAD * utilization) / WAD;
        uint256 borrowFactor = _linearIndexFactor(borrowRate, elapsed);
        borrowIndex = (borrowIndex * borrowFactor) / WAD;

        uint256 liquidityRate = borrowRate * utilization / WAD;
        liquidityRate = liquidityRate * (WAD - RESERVE_FACTOR_WAD) / WAD;
        uint256 liquidityFactor = _linearIndexFactor(liquidityRate, elapsed);
        liquidityIndex = (liquidityIndex * liquidityFactor) / WAD;

        lastUpdateTimestamp = uint40(block.timestamp);
    }

    function _linearIndexFactor(uint256 rate, uint256 elapsed) internal pure returns (uint256) {
        return WAD + (rate * elapsed) / SECONDS_PER_YEAR;
    }

    function _utilization() internal view returns (uint256) {
        uint256 totalDeposits = (totalScaledDeposits * liquidityIndex) / WAD;
        if (totalDeposits == 0) return 0;
        uint256 totalDebt = (totalScaledDebt * borrowIndex) / WAD;
        if (totalDebt == 0) return 0;
        return (totalDebt * WAD) / totalDeposits;
    }

    function getDebtValue(CollateralPosition storage pos) internal view returns (uint256) {
        return (pos.scaledDebt * borrowIndex) / WAD;
    }

    function _healthFactor(CollateralPosition storage pos) internal view returns (uint256) {
        uint256 debt = getDebtValue(pos);
        if (debt == 0) {
            return type(uint256).max;
        }
        uint256 collateralValue = _collateralUsdValue(pos.amountNVDA);
        return (collateralValue * LIQ_THRESHOLD_BPS * WAD) / (debt * BPS_DENOM);
    }

    function _collateralUsdValue(uint256 amountNVDA) internal view returns (uint256) {
        if (amountNVDA == 0) return 0;
        uint256 price = _getLatestPrice();
        uint256 numerator = amountNVDA * price;
        uint256 scaled = numerator / (10 ** uint256(nvdaDecimals));
        return _scaleOracleToUsd(scaled);
    }

    function _usdToNvda(uint256 usdAmount, bool includeBonus) internal view returns (uint256) {
        uint256 adjustedUsd = includeBonus ? (usdAmount * LIQUIDATION_BONUS_BPS) / BPS_DENOM : usdAmount;
        uint256 price = _getLatestPrice();
        uint256 usdOracleUnits = _scaleUsdToOracle(adjustedUsd);
        return (usdOracleUnits * (10 ** uint256(nvdaDecimals))) / price;
    }

    function _getLatestPrice() internal view returns (uint256) {
        (, int256 price,,,) = nvdaOracle.latestRoundData();
        if (price <= 0) revert InvalidOraclePrice();
        return uint256(price);
    }

    function _scaleOracleToUsd(uint256 amount) internal view returns (uint256) {
        if (oracleDecimals >= 6) {
            return amount / (10 ** uint256(oracleDecimals - 6));
        } else {
            return amount * (10 ** uint256(6 - oracleDecimals));
        }
    }

    function _scaleUsdToOracle(uint256 amount) internal view returns (uint256) {
        if (oracleDecimals >= 6) {
            return amount * (10 ** uint256(oracleDecimals - 6));
        } else {
            return amount / (10 ** uint256(6 - oracleDecimals));
        }
    }

    function _divUp(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        return (numerator + denominator - 1) / denominator;
    }
}
