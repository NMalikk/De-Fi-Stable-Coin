// SPDX-License-Identifier: MIT

// // This file has our invariant aka properties that hold true for all time

// // What are our invariants?

// // 1. The total supply of DSC should be less than the total value of collateral

// // 2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

// Open InVariants Testing is not a good option, invariants test is better since it allows more specific testing methods.

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployStableCoin} from "../../script/DeployStableCoin.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//     DeployStableCoin deployer;
//     DSCEngine engine;
//     DecentralizedStableCoin dsc;
//     HelperConfig helperConfig;
//     address weth;
//     address btc;

//     function setUp() external {
//         deployer = new DeployStableCoin();
//         (dsc, engine, helperConfig) = deployer.run();
//         (,, weth, btc,) = helperConfig.activeNetworkConfig();
//         targetContract(address(engine));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         //get the value of all the collateral in the protocol
//         //compare it to all the debt (dsc)
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
//         uint256 totalBtcDeposited = IERC20(btc).balanceOf(address(engine));

//         uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
//         uint256 btcValue = engine.getUsdValue(btc, totalBtcDeposited);

//         console.log("wethValue: ", wethValue);
//         console.log("btcValue: ", btcValue);
//         console.log("totalSupply: ", totalSupply);
//         assert(wethValue + btcValue >= totalSupply); // just to avoid 0, 0
//             // status: [PASS] invariant_protocolMustHaveMoreValueThanTotalSupply() (runs: 128, calls: 16384, reverts: 16384)
//             //same amount of calls and reverts which means its making silly calls and its reverting from the coin but
//             //We have fail_on_revert = false so any revert is shown as [PASS]
//     }
// }
