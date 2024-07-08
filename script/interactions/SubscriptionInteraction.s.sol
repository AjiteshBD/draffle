//SPDX-Licenser-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstant} from "../utils/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mock/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscriptionContract is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        (uint256 subId, ) = createSubcriptionId(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubcriptionId(
        address vrfCoordinator
    ) public returns (uint256, address) {
        vm.startBroadcast();
        uint subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscriptionContract is Script, CodeConstant {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 Link

    function fundSubscriptionConfig() public {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint subId = config.getConfig().subscriptionId;
        address linktoken = config.getConfig().linkToken;
        fundSubcriptionId(vrfCoordinator, subId, linktoken);
    }

    function fundSubcriptionId(
        address vrfCoordinator,
        uint256 subId,
        address linktoken
    ) public {
        if (LOCAL_CHAIN_ID == block.chainid) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT * 100
            );
            vm.stopBroadcast();
        } else {
            console.log("Starting deployment at %network", block.chainid);
            vm.startBroadcast();
            LinkToken(linktoken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionConfig();
    }
}

contract AddConsumerContract is Script {
    function addConsumerConfig(address lastestDeployed) public {
        HelperConfig config = new HelperConfig();
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        uint subId = config.getConfig().subscriptionId;

        addConsumer(lastestDeployed, vrfCoordinator, subId);
    }

    function addConsumer(
        address consumerToAddVRF,
        address vrfCoordinator,
        uint subId
    ) public {
        console.log(
            "Adding consumer to VRF coordinator %s at chainid %s",
            vrfCoordinator,
            block.chainid
        );
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            consumerToAddVRF
        );
        vm.stopBroadcast();
    }

    function run() public {
        address lastestDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerConfig(lastestDeployed);
    }
}
