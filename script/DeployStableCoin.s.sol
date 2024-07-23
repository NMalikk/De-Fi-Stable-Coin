// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {Script, console} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployStableCoin is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        // Get the address associated with the deployerKey.
        address deployerAddress = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        //Note: The deployer becomes the initial address owner of stable coin at first. Then transfers ownership to engine
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(deployerAddress); // ensures that deployer becomes the initial owner of dsc coin in ownable contract
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(engine)); // transfers ownership from deployer to engine

        vm.stopBroadcast();
        return (dsc, engine, helperConfig);
    }
}
