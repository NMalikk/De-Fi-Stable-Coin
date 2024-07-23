// SPDX-License-Identifier: MIT

// This file has our invariant aka properties that hold true for all time

// What are our invariants?

// 1. The total supply of DSC should be less than the total value of collateral

// 2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployStableCoin deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address weth;
    address btc;
    Handler handler;

    function setUp() external {
        deployer = new DeployStableCoin();
        (dsc, engine, helperConfig) = deployer.run();
        (,, weth, btc,) = helperConfig.activeNetworkConfig();
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
        //hey dont call redeemCollateral, unless there is collateral to redeem
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        //get the value of all the collateral in the protocol
        //compare it to all the debt (dsc)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalBtcDeposited = IERC20(btc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 btcValue = engine.getUsdValue(btc, totalBtcDeposited);

        console.log("wethValue: ", wethValue);
        console.log("btcValue: ", btcValue);
        console.log("totalSupply: ", totalSupply);
        console.log("MintCount: ", handler.mintCount());
        assert(wethValue + btcValue >= totalSupply); // just to avoid 0, 0
    }
}
