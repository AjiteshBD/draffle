//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/deploy/deployRaffle.s.sol";
import {HelperConfig} from "script/utils/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entryFees;
    uint256 intervals;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address private PLAYER = makeAddr("Player");
    uint private constant INITIAL_BALANCE = 10 ether;
    uint private constant ENTRY_FEE = 5 ether;

    event RaffleEntered(address indexed player, uint amount);
    event WinnerPicked(address indexed winner, uint amount);

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entryFees = config.entryFees;
        intervals = config.intervals;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, INITIAL_BALANCE);
    }

    function testRaffleInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientEntryFees.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsWhenPlayerEnters() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: ENTRY_FEE}();
        // Assert
        assertEq(raffle.getPlayerByIndex(0), PLAYER);
    }

    function testRaffleEntryEventEmits() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER, ENTRY_FEE);
        raffle.enterRaffle{value: ENTRY_FEE}();
    }

    function testRaffleRevertsWhenRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRY_FEE}();
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRY_FEE}();
    }
}
