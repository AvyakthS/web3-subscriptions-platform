// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SubscriptionPlan is ReentrancyGuard {
    // --- State Variables ---
    address public immutable owner; // The creator who owns this plan
    IERC20 public immutable token; // The stablecoin (e.g., USDC)
    uint256 public immutable price; // Price per subscription period
    uint256 public immutable duration; // Duration in seconds (e.g., 30 days)
    address public immutable beneficiary; // Address to receive funds

    struct Subscription {
        uint256 expiry;
        bool active;
    }

    mapping(address => Subscription) public subscriptions;

    // --- Events ---
    event Subscribed(address indexed user, uint256 expiry);
    event Cancelled(address indexed user);

    // --- Constructor ---
    constructor(
        address _owner,
        address _token,
        uint256 _price,
        uint256 _duration,
        address _beneficiary
    ) {
        owner = _owner;
        token = IERC20(_token);
        price = _price;
        duration = _duration;
        beneficiary = _beneficiary;
    }

    // --- Core Functions ---
    function subscribe() external nonReentrant {
        // Transfer funds from user to beneficiary
        // The user must have already called `approve()` on the token contract
        uint256 currentAllowance = token.allowance(msg.sender, address(this));
        require(currentAllowance >= price, "Check token allowance");
        token.transferFrom(msg.sender, beneficiary, price);

        // Update the user's subscription status
        Subscription storage sub = subscriptions[msg.sender];
        uint256 newExpiry = block.timestamp > sub.expiry ? block.timestamp + duration : sub.expiry + duration;
        
        sub.expiry = newExpiry;
        sub.active = true;

        emit Subscribed(msg.sender, newExpiry);
    }

    function cancel() external {
        require(subscriptions[msg.sender].active, "Not subscribed");
        subscriptions[msg.sender].active = false;
        // Note: This model doesn't handle pro-rata refunds for simplicity.
        emit Cancelled(msg.sender);
    }

    // --- View Functions ---
    function isSubscriptionActive(address _user) external view returns (bool) {
        Subscription memory sub = subscriptions[_user];
        return sub.active && sub.expiry > block.timestamp;
    }
}