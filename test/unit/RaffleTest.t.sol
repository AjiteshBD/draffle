//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/deploy/deployRaffle.s.sol";
import {HelperConfig} from "script/utils/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstant} from "script/utils/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstant {
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

    modifier checkUpkeepTrue() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRY_FEE}();
        vm.warp(block.timestamp + intervals + 1); // keeping time little more then intervals
        vm.roll(block.number + 1);
        _;
    }

    modifier checkUpkeepFalse() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRY_FEE}();
        vm.warp(block.timestamp + intervals - 1); // keeping time little more then intervals
        vm.roll(block.number + 1);
        _;
    }

    modifier skipForkTest() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

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

    function testRaffleRevertsWhenRaffleNotOpen() public checkUpkeepTrue {
        // Arrange

        raffle.performUpkeep("");

        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRY_FEE}();
    }

    /*//////////////////////////////////////////////////////////////
                                 UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testUpkeepReturnFalseIfNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testcheckUpReturnsFalseIfRaffleNotOpen() public checkUpkeepTrue {
        // Arrange

        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testcheckUpReturnsFalseIEnoughTimeNotPassed()
        public
        checkUpkeepFalse
    {
        // Arrange

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood()
        public
        checkUpkeepTrue
    {
        // Arrange

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepOnlyCalledIfUpkeepNeeded()
        public
        checkUpkeepTrue
    {
        // Arrange

        // Act/assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfUpkeepIsFalse() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRY_FEE}();

        Raffle.RaffleState s_raffleState = raffle.getRaffleState();
        uint balance = address(raffle).balance;
        uint s_players = 1;

        // Act/assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                s_raffleState,
                balance,
                s_players
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRaffleStateandEmitRequestId()
        public
        checkUpkeepTrue
    {
        // Arrange
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState s_raffleState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(s_raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                          FULLFILL RANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint randomRequestId
    ) public skipForkTest {
        // Arrange/Act/ Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulFillRandomWordsPickWinnerResetAndSendMoney()
        public
        checkUpkeepTrue
        skipForkTest
    {
        // Arrange
        uint256 startingIndex = 1;
        uint256 extraEnterants = 3;
        address expectedWinner = address(1);
        for (uint256 i = 1; i < startingIndex + extraEnterants; i++) {
            address player = address(uint160(i));
            hoax(player, INITIAL_BALANCE);
            raffle.enterRaffle{value: ENTRY_FEE}();
        }
        uint256 startingTimestamp = raffle.getLastTimestamp();

        uint winnerLastBalance = expectedWinner.balance;
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        // Assert

        Raffle.RaffleState s_raffleState = raffle.getRaffleState();
        address winner = raffle.getRecentWinner();
        uint balance = address(raffle).balance;
        uint prize = ENTRY_FEE * (extraEnterants + 1);
        uint resetTimestamp = raffle.getLastTimestamp();
        uint256 winnerBalance = winner.balance;
        console.log("winner", winner);
        assert(s_raffleState == Raffle.RaffleState.OPEN);
        assert(winner == expectedWinner);
        assert(winnerBalance == winnerLastBalance + prize);
        assert(balance == 0);
        assert(resetTimestamp > startingTimestamp);
    }
}
