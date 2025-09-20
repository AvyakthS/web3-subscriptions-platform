// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SubscriptionPlan.sol"; // Assumes SubscriptionPlan.sol is in the same directory

/**
 * @title SubscriptionManager
 * @author YourName
 * @notice A factory contract to deploy and manage individual SubscriptionPlan contracts.
 * It acts as a registry, allowing anyone to find the subscription plan for a given creator.
 */
contract SubscriptionManager {
    // --- State Variables ---

    // Mapping from a creator's address to their deployed SubscriptionPlan contract address.
    mapping(address => address) public creatorToPlan;

    // An array to store the addresses of all created SubscriptionPlan contracts.
    // Useful for frontends that may want to display a list of all available plans.
    address[] public allPlans;

    // --- Events ---

    // Emitted when a new subscription plan is successfully created.
    event PlanCreated(
        address indexed creator,
        address indexed planAddress,
        address token,
        uint256 price,
        uint256 duration
    );

    // --- Core Function ---

    /**
     * @notice Deploys a new SubscriptionPlan contract for the caller (msg.sender).
     * @dev Each creator can only have one plan. This prevents a single creator
     * from spamming the factory with multiple plan contracts.
     * @param _token The ERC20 stablecoin contract address (e.g., USDC).
     * @param _price The price for one subscription period, in the token's smallest unit.
     * @param _duration The duration of one subscription period in seconds.
     * @param _beneficiary The address that will receive the subscription payments.
     */
    function createSubscriptionPlan(
        address _token,
        uint256 _price,
        uint256 _duration,
        address _beneficiary
    ) external {
        // Ensure the creator does not already have a plan.
        require(creatorToPlan[msg.sender] == address(0), "Creator already has a plan");
        require(_token != address(0), "Token cannot be zero address");
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_price > 0, "Price must be greater than zero");
        require(_duration > 0, "Duration must be greater than zero");

        // Deploy a new SubscriptionPlan contract.
        // The owner of the new plan is set to the creator (msg.sender).
        SubscriptionPlan newPlan = new SubscriptionPlan(
            msg.sender,
            _token,
            _price,
            _duration,
            _beneficiary
        );

        // Store the new plan's address in our registry.
        address newPlanAddress = address(newPlan);
        creatorToPlan[msg.sender] = newPlanAddress;
        allPlans.push(newPlanAddress);

        // Emit an event to log the creation of the new plan.
        emit PlanCreated(msg.sender, newPlanAddress, _token, _price, _duration);
    }

    // --- View Functions ---

    /**
     * @notice Gets the total number of subscription plans created.
     * @return The count of all plans.
     */
    function getPlanCount() external view returns (uint256) {
        return allPlans.length;
    }
}