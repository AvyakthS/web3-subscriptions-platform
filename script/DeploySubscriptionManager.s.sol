// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {SubscriptionManager} from "../src/SubscriptionManager.sol";

contract DeploySubscriptionManager is Script {
    function run() external returns (SubscriptionManager) {
        // --- THIS IS THE NEW, ROBUST WAY ---
        // 1. Load the private key directly from the .env file using a Foundry cheatcode.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 2. Start broadcasting transactions signed with the loaded private key.
        vm.startBroadcast(deployerPrivateKey);

        // 3. Deploy the contract. The transaction will be signed automatically.
        SubscriptionManager manager = new SubscriptionManager();

        // 4. Stop broadcasting.
        vm.stopBroadcast();

        return manager;
    }
}


// What's Next? The Final Command

// Once you have saved the changes to this script file, the entire setup is complete. The only thing left to do is run the new, much simpler deployment command.

// In your **Command Prompt**, run this:

// forge script script/DeploySubscriptionManager.s.sol:DeploySubscriptionManager --rpc-url amoy --broadcast
