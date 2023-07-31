// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    FundMe fundMe1;
    HelperConfig helperConfig = new HelperConfig();
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        //new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306); //Since constructor dont take any parameters hence FundMe() contains no parameters
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        fundMe1 = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMyTestToCheckTwoDeployedAddressAreSame() public view {
        assert(address(fundMe) != address(fundMe1));
    }

    function testPriceFeedSetCorrectly() public view {
        address retrievedPriceFeed = address(fundMe.getPriceFeed());
        address expectedPriceFeed = helperConfig.activeNetworkConfig();
        assert(expectedPriceFeed == retrievedPriceFeed);
    }

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.getMinimumUSD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); //the next line should fail
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructures() public {
        vm.prank(USER); //the next tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(USER, funder);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(USER); //skip this line as it contains "vm" cheatcode
        fundMe.withdraw();
    }

    function testWithdrawWithSingleFunder() public funded {
        //Aarrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd);
        console.log(gasUsed);

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            endingOwnerBalance,
            startingFundMeBalance + startingOwnerBalance
        );
    }

    function testWithdrawWithMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2; //sometimes 0 index reverts
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            //vm.prank
            //vm.default
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(
            fundMe.getOwner().balance ==
                startingFundMeBalance + startingOwnerBalance
        );
    }

    function testWithdrawWithMultipleFundersCheaper() public funded {
        //Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2; //sometimes 0 index reverts
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            //vm.prank
            //vm.default
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(
            fundMe.getOwner().balance ==
                startingFundMeBalance + startingOwnerBalance
        );
    }

    function testAddressName() public view {
        console.log(fundMe.getOwner());
        console.log(address(fundMe));
    }
}
