//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "../utils/HelperConfig.s.sol";
import {CreateSubscriptionContract, FundSubscriptionContract, AddConsumerContract} from "../interactions/SubscriptionInteraction.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscriptionContract createSubscriptionContract = new CreateSubscriptionContract();
            (
                config.subscriptionId,
                config.vrfCoordinator
            ) = createSubscriptionContract.createSubcriptionId(
                config.vrfCoordinator
            );
        }
        FundSubscriptionContract fundSubscriptionContract = new FundSubscriptionContract();
        fundSubscriptionContract.fundSubcriptionId(
            config.vrfCoordinator,
            config.subscriptionId,
            config.linkToken
        );
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entryFees,
            config.intervals,
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        AddConsumerContract addConsumerContract = new AddConsumerContract();
        // don't neet to broadcast as in consumer we are alrady broadcasting it
        addConsumerContract.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscriptionId
        );
        return (raffle, helperConfig);
    }
}
