//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";

// what can we do to work with address outside our system?
//1. Unit
//    - Testing a specific part of our code
//2. Integration
//  - Testing how our code works with other parts of our code
//3. Forked
// -Testing our code on a simulated environment
//4. STaging
// -Testing Our code in a real environment
contract FundMeTest is ZkSyncChainChecker, CodeConstants, StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        if (!isZkSyncChain()) {
            DeployFundMe deployer = new DeployFundMe();
            (fundMe, helperConfig) = deployer.deployFundMe();
        } else {
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
            fundMe = new FundMe(address(mockPriceFeed));
        }
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() external view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() external view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWIthoutEnoughEth() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundIsEnoughEth() public {
        fundMe.fund{value: 6e18}();
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testFundUpdatesFundedDataStructure() public funded {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFundersToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawAsaSingleFunder() public funded {
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);
        console.log("startingFundMeBalance", startingFundMeBalance);
        console.log("startingOwnerBalance", startingOwnerBalance);
        console.log("endingOwnerBalance", endingOwnerBalance);
        console.log("endingFundMeBalance", endingFundMeBalance);
    }

    function testWithdrawAsaMultipleFunders() public funded {
        uint256 numberOfFunders = 10;
        uint256 startingFunderIndex = 2;

        for (uint256 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(uint160(i)), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        uint256 endingOwnerBalance = fundMe.getOwner().balance;

        //Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == endingOwnerBalance);
    }

    function testWithdrawAsaMultipleFundersCheaper() public funded {
        uint256 numberOfFunders = 10;
        uint256 startingFunderIndex = 2;

        for (uint256 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(uint160(i)), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        uint256 endingOwnerBalance = fundMe.getOwner().balance;

        //Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == endingOwnerBalance);
    }
}
