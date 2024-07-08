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
        address account = config.getConfig().account;
        (uint256 subId, ) = createSubcriptionId(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubcriptionId(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        vm.startBroadcast(account);
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
        address account = config.getConfig().account;
        fundSubcriptionId(vrfCoordinator, subId, linktoken, account);
    }

    function fundSubcriptionId(
        address vrfCoordinator,
        uint256 subId,
        address linktoken,
        address account
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
            vm.startBroadcast(account);
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
        address account = config.getConfig().account;
        addConsumer(lastestDeployed, vrfCoordinator, subId, account);
    }

    function addConsumer(
        address consumerToAddVRF,
        address vrfCoordinator,
        uint subId,
        address account
    ) public {
        console.log(
            "Adding consumer to VRF coordinator %s at chainid %s",
            vrfCoordinator,
            block.chainid
        );
        vm.startBroadcast(account);
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
