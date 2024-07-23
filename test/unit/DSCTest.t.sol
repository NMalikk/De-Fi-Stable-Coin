// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";


contract DSCTest is Test {
    address public constant dscOwner =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    DecentralizedStableCoin dsc;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant amount = 1 ether;
    uint256 public totalSupply = 100 ether;

    //from IERC20 (interface ERC20)
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() external {
        vm.startBroadcast(dscOwner);
        dsc = new DecentralizedStableCoin(dscOwner);
        // // Set expectations for the event
        // vm.expectEmit(true, true, true, true);
        // emit Transfer(address(0), dscOwner, startingOwnerBalance);
        dsc.mint(dscOwner, totalSupply);
        vm.stopBroadcast();
    }

    function testOnlyOwnerCanMintAndBurn() public {
        //testing mint
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                alice
            )
        );
        dsc.mint(bob, amount);
        // testing burn
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                alice
            )
        );
        dsc.burn(amount);
    }

    //testing burn()
    function testBurnFailsWhenAmountLessThanZero() public {
        vm.prank(dscOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "DecentralizedStableCoin__MustBeMoreThanZero()"
            )
        );
        dsc.burn(0);
    }

    function testBurnFailsWhenInsufficientBalance() public {
        vm.prank(dscOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "DecentralizedStableCoin__BurnAmountExceedsBalance()"
            )
        );
        dsc.burn(totalSupply + 1 ether);
    }

    function testBurnReducesTotalSupply() public {
        vm.prank(dscOwner);
        // // Set expectations for the event
        vm.expectEmit(true, true, true, true);
        emit Transfer(dscOwner, address(0), amount);
        dsc.burn(amount);
        totalSupply -= amount;
        assertEq(dsc.totalSupply(), totalSupply);
    }

    //test Mint()
    function testMintRevertsOnZeroAddress() public {
        vm.prank(dscOwner);
        vm.expectRevert(
            abi.encodeWithSignature("DecentralizedStableCoin__NotZeroAddress()")
        );
        dsc.mint(address(0), amount);
    }

    function testMintRevertsOnZeroAmount() public {
        vm.prank(dscOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "DecentralizedStableCoin__MustBeMoreThanZero()"
            )
        );
        dsc.mint(alice, 0);
    }
}
