// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployStableCoin deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address public USER = address(1);
    address public ALICE_LIQUIDATOR = makeAddr("alice");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant REDEEMED_COLLATERAL_AMOUNT = 5 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant AMOUNT_DSC_TO_MINT = 10000e18; // when collateral value 20k$ USD, only max 10k DSC can be taken because of threshold.
    uint256 private constant LIQUIDATION_BONUS = 10; // this means 10% percent bonus

    function setUp() public {
        deployer = new DeployStableCoin();
        (dsc, engine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_USER_BALANCE); // giving some weth tokens to user
    }

    //////////////////////////////
    /// Constructor Tests//////////////
    /////////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////////////
    /// Price Tests//////////////
    /////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18; // 15 eth
        //15e18 * 2000/ETH = 30,000e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////
    /// Deposit Collateral Tests//////////////
    /////////////////////////////

    // deposits 10 ETH as collateral. This amounts to 20,000$ or 20,000 DSC
    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(abi.encodeWithSignature("DSCEngine__NeedsMoreThanZero()"));
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 expectedDepositedAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(expectedDepositedAmount, AMOUNT_COLLATERAL);
    }

    function testDepositCollateralAndMintDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 expectedDepositedAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, AMOUNT_DSC_TO_MINT);
        assertEq(AMOUNT_COLLATERAL, expectedDepositedAmount);
        vm.stopPrank();
    }

    //////////////////////////////
    /// Redeem Collateral Tests//////////////
    /////////////////////////////

    modifier redeemedCollateral() {
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanRedeemCollateralAndGetAccountInfo() public depositedCollateral redeemedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
        assertEq(collateralValueInUsd, 0);
    }

    function testRedeemCollateralForDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        uint256 balanceUserWethBefore = AMOUNT_COLLATERAL;
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        dsc.approve(address(engine), totalDscMinted);
        engine.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, totalDscMinted);
        uint256 balanceUserWethAfter = ERC20Mock(weth).balanceOf(USER);
        (uint256 totalDscMintedAfter,) = engine.getAccountInformation(USER);
        assertEq(totalDscMintedAfter, 0);
        assertEq(balanceUserWethBefore, balanceUserWethAfter);

        vm.stopPrank();
    }

    //////////////////////////////
    /// HealthFactor Tests //////////////
    /////////////////////////////

    //Price of eth: 1 ETH = 2000$

    // takes account info and tells health factor
    function calculateNewHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        public
        pure
        returns (uint256)
    {
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function testCanNotMintMoreDscThanCollateralValue() public depositedCollateral {
        // we have deposited 10 ETH = 20,000 USD
        //Now we try to mint out > 20k USD of DSC. 1$ = 1 DSC (pegged stable coin)

        uint256 amountOfDscToMint = 25000e18; //30k Usd raised to e18

        //get account info on dsc minted.
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        //adding dsc to be minted to total dsc minted
        totalDscMinted += amountOfDscToMint;
        //expected health factor once more dsc is minted
        uint256 expectedHealthFactor = calculateNewHealthFactor(totalDscMinted, collateralValueInUsd);

        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSignature("DSCEngine__BreaksHealthFactor(uint256)", expectedHealthFactor));
        engine.mintDsc(amountOfDscToMint);
        vm.stopPrank();
    }

    //////////////////////////////
    /// Liquidate Tests //////////////
    /////////////////////////////

    function testCantLiquidateWhenHealthFactorIsGood() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        uint256 healthFactor = engine.getHealthFactor(USER);
        assert(healthFactor >= MIN_HEALTH_FACTOR);
        (uint256 debtToCover, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        vm.expectRevert(abi.encodeWithSignature("DSCEngine__HealthFactorIsOk()"));
        vm.stopPrank();
        vm.prank(ALICE_LIQUIDATOR); // another person trying to liquidate USER
        engine.liquidate(weth, USER, debtToCover);
    }

    // The test below only works when engine (liquidate function) is tweaked with the following:
    // s_collateralDeposited[user][collateral] = 7 ether; // collateral initially deposited = 10 eth, now its 7 eth worth 14000 dsc.

    // function testLiquidateWorks() public depositedCollateralAndMintedDsc {
    //     vm.startPrank(ALICE_LIQUIDATOR);
    //     uint256 debtToCoverOfUser = 10000e18;
    //     //we give alex some dsc so she can pay USERS loan
    //     ERC20Mock(weth).mint(ALICE_LIQUIDATOR, STARTING_USER_BALANCE);
    //     ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
    //     engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
    //     //have to approve to give dsc from liquidator to the contract for paying loan
    //     dsc.approve(address(engine), debtToCoverOfUser);
    //     engine.liquidate(weth, USER, debtToCoverOfUser);
    //     (uint256 totalDscMintedUSER,) = engine.getAccountInformation(USER);
    //     uint256 tokenAmountFromDebtCovered = engine.getTokenAmountFromUsd(weth, debtToCoverOfUser);
    //     uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
    //     uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral; // The amount of token weth ALICE_LIQUIDATOR gets without bonus
    //     vm.stopPrank();
    //     assertEq(totalDscMintedUSER, 0); //checking if USERS loan is payed off completely
    //     assertEq(totalCollateralToRedeem, ERC20Mock(weth).balanceOf(ALICE_LIQUIDATOR)); // LIQUIDATOR must receive this amount as token. They previously had 0 weth left.
    // }


}
