// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SubscriptionManager} from "../src/SubscriptionManager.sol";
import {SubscriptionPlan} from "../src/SubscriptionPlan.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// A simple mock ERC20 token for testing purposes.
contract MockUSDC is IERC20 {
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract SubscriptionManagerTest is Test {
    SubscriptionManager public manager;
    MockUSDC public usdc;

    address creator = address(0x1);
    address subscriber = address(0x2);
    address beneficiary = address(0x3);

    // Re-declare the event here to make the test contract aware of its signature.
    event PlanCreated(
        address indexed creator,
        address indexed planAddress,
        address token,
        uint256 price,
        uint256 duration
    );

    // This function is run before each test case
    function setUp() public {
        manager = new SubscriptionManager();
        usdc = new MockUSDC();

        // Give the test users some mock USDC
        vm.startPrank(creator);
        usdc.mint(creator, 1000 * 10**6);
        vm.stopPrank();

        vm.startPrank(subscriber);
        usdc.mint(subscriber, 1000 * 10**6);
        vm.stopPrank();
    }

    // Test 1: Successful Plan Creation
    function test_CreatePlan_Success() public {
        vm.prank(creator);

        // --- THE FIX IS HERE ---
        // We tell Foundry to NOT check the second topic (planAddress) because we can't know it in advance.
        vm.expectEmit(true, false, false, true, address(manager));

        // Now that the event is declared above, this line will compile correctly.
        emit PlanCreated(
            creator,
            address(0), // This value is now ignored by the test, which is what we want.
            address(usdc),
            5 * 10**6,
            30 days
        );

        // Call the function that should create the plan
        manager.createSubscriptionPlan(
            address(usdc),
            5 * 10**6, // 5 USDC
            30 days,
            beneficiary
        );

        // Verify the state was updated correctly
        address planAddress = manager.creatorToPlan(creator);
        assertTrue(planAddress != address(0));
        assertEq(manager.getPlanCount(), 1);
        assertEq(manager.allPlans(0), planAddress);
    }

    // Test 2: Revert if a creator tries to create a second plan
    function test_Fail_CreatePlan_When_AlreadyExists() public {
        // First, create a plan successfully
        vm.startPrank(creator);
        manager.createSubscriptionPlan(address(usdc), 5 * 10**6, 30 days, beneficiary);
        vm.stopPrank();

        // Now, expect the second attempt to fail with the correct error message
        vm.prank(creator);
        vm.expectRevert("Creator already has a plan");
        manager.createSubscriptionPlan(address(usdc), 10 * 10**6, 60 days, beneficiary);
    }
    
    // Test 3: Revert on invalid creation parameters
    function test_Fail_CreatePlan_With_InvalidParams() public {
        vm.prank(creator);

        // Test zero address for token
        vm.expectRevert("Token cannot be zero address");
        manager.createSubscriptionPlan(address(0), 5 * 10**6, 30 days, beneficiary);

        // Test zero address for beneficiary
        vm.expectRevert("Beneficiary cannot be zero address");
        manager.createSubscriptionPlan(address(usdc), 5 * 10**6, 30 days, address(0));

        // Test zero price
        vm.expectRevert("Price must be greater than zero");
        manager.createSubscriptionPlan(address(usdc), 0, 30 days, beneficiary);
    }

    // Test 4: Full User Journey - Subscribe, Check Status, Expire
    function test_Full_Subscription_Flow() public {
        // --- 1. Creator creates a plan ---
        vm.startPrank(creator);
        manager.createSubscriptionPlan(address(usdc), 10 * 10**6, 30 days, beneficiary);
        vm.stopPrank();

        address planAddress = manager.creatorToPlan(creator);
        SubscriptionPlan plan = SubscriptionPlan(planAddress);

        // --- 2. Subscriber approves tokens ---
        vm.startPrank(subscriber);
        usdc.approve(planAddress, 10 * 10**6);
        assertEq(usdc.allowance(subscriber, planAddress), 10 * 10**6);
        vm.stopPrank();

        // --- 3. Subscriber subscribes ---
        uint256 subBalanceBefore = usdc.balanceOf(subscriber);
        uint256 benBalanceBefore = usdc.balanceOf(beneficiary);

        vm.prank(subscriber);
        plan.subscribe();

        uint256 subBalanceAfter = usdc.balanceOf(subscriber);
        uint256 benBalanceAfter = usdc.balanceOf(beneficiary);

        // Verify balances changed correctly
        assertEq(subBalanceAfter, subBalanceBefore - 10 * 10**6);
        assertEq(benBalanceAfter, benBalanceBefore + 10 * 10**6);
        
        // --- 4. Verify subscription status ---
        assertTrue(plan.isSubscriptionActive(subscriber));

        // --- 5. Time-travel to the future to test expiry ---
        vm.warp(block.timestamp + 31 days);
        
        // --- 6. Verify subscription is now inactive ---
        assertFalse(plan.isSubscriptionActive(subscriber));
    }
}

