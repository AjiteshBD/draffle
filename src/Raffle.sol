// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Raffle Contract
 * @author Cryptoineer
 * @notice This contract is used to play the raffle
 * @dev Implements Chainlink VRF v2.5
 */

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /** Custom Error */
    error Raffle__InsufficientEntryFees();
    error Raffle__NotOpen();
    error Raffle__TransferFailed();
    error Raffle__UpkeepNotNeeded(
        uint256 raffleState,
        uint256 balance,
        uint256 players
    );

    /** Type Declarations */
    enum RaffleState {
        OPEN,
        PAUSED,
        CALCULATING,
        CLOSED
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIMATION = 2;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entryFees;
    // @dev This is the number of seconds between each raffle
    uint256 private immutable i_intervals;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event RaffleEntered(address indexed player, uint amount);
    event WinnerPicked(address indexed winner, uint amount);

    /** Constructor */
    constructor(
        uint256 entryFees,
        uint256 intervals,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFees = entryFees;
        i_intervals = intervals;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    /** External Functions */
    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        if (msg.value < i_entryFees) {
            revert Raffle__InsufficientEntryFees();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender, msg.value);
    }

    function checkUpkeep(
        bytes memory /*data*/
    ) public view returns (bool upKeepNeeded, bytes memory /*performData*/) {
        bool isTimePassed = ((block.timestamp - s_lastTimeStamp) >=
            i_intervals);
        bool isRaffleOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance >= 0;
        bool hasPlayer = s_players.length > 0;
        upKeepNeeded = isTimePassed && isRaffleOpen && hasBalance && hasPlayer;
        return (upKeepNeeded, "");
    }

    function performUpkeep(bytes calldata /*performData*/) external {
        (bool upKeepNeeded, ) = checkUpkeep("");

        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                uint256(s_raffleState),
                address(this).balance,
                s_players.length
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        uint winnerIndex = uint(randomWords[0] % s_players.length);

        s_recentWinner = s_players[winnerIndex];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner, address(this).balance);
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter functions */
    function getEntryFees() external view returns (uint256) {
        return i_entryFees;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerByIndex(uint index) external view returns (address) {
        return s_players[index];
    }
}
