// SPDX-License-Identifier: MIT

// Handler is going to narrow down the way we call functions. Will be our target contract

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    address[] public usersWithCollateralDeposited;
    uint256 public mintCount;
    MockV3Aggregator public ethUsdPriceFeed;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        engine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        console.log("WETH TOKEN:", address(weth));
        console.log("BTC TOKEN:", address(wbtc));

        ethUsdPriceFeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(address(weth)));
    }

    function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral, uint256 amountDsc) public {
        // must be more than 0
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        vm.startPrank(msg.sender);
        //MINTING SOME COLLATERAL
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        //NOW MINTING SOME DSC
        amountDsc = bound(amountDsc, 0, MAX_DEPOSIT_SIZE);
        engine.mintDsc(amountDsc);
        vm.stopPrank();
        //double push
        usersWithCollateralDeposited.push(msg.sender);
        mintCount++;
    }

    //if the price of the system plummets quickly, it breaks the system
    // previously 2000e8 was the ETH to USD value
    // now its uint96 number smaller than that gives around 400$ / ETH, 600 or something very lower than that.

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function redeemCollateralHandler(uint256 collateralSeed, uint256 amountCollateral, uint256 addressSeed) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = engine.getCollateralBalanceOfUser(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = _getUserWithCollateralDeposited(addressSeed);
        if (amountCollateral == 0) {
            return;
        }
        vm.prank(sender);
        engine.redeemCollateral(address(collateral), amountCollateral);
    }

    //Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }

    function _getUserWithCollateralDeposited(uint256 collateralSeed) private view returns (address) {
        return usersWithCollateralDeposited[collateralSeed % usersWithCollateralDeposited.length];
    }
}
