//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundFundMe, WithdrawFundMe} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

// what can we do to work with address outside our system?
//1. Unit
//    - Testing a specific part of our code
//2. Integration
//  - Testing how our code works with other parts of our code
//3. Forked
// -Testing our code on a simulated environment
//4. STaging
// -Testing Our code in a real environment
contract InteractionsTest is ZkSyncChainChecker, StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant STARTING_USER_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        if (!isZkSyncChain()) {
            DeployFundMe deployer = new DeployFundMe();
            (fundMe, helperConfig) = deployer.deployFundMe();
        } else {
            helperConfig = new HelperConfig();
            fundMe = new FundMe(helperConfig.getConfigByChainId(block.chainid).priceFeed);
        }
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testUserCanFundInteractions() public {
        uint256 preUserBalance = address(USER).balance;
        uint256 preOwnerBalance = address(fundMe.getOwner()).balance;
        uint256 originalFundMeBalance = address(fundMe).balance;

        // Using vm.prank to simulate funding from the USER address
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        uint256 afterUserBalance = address(USER).balance;
        uint256 afterOwnerBalance = address(fundMe.getOwner()).balance;

        assert(address(fundMe).balance == 0);
        assertEq(afterUserBalance + SEND_VALUE, preUserBalance);
        assertEq(preOwnerBalance + SEND_VALUE + originalFundMeBalance, afterOwnerBalance);
    }
}
