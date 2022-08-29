// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

error Lottery__NotEnoughETH();
error Lottery__TransferFailed();
error Lottery__NotOpen();
error Lottery_UpKeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 lotteryState);

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract Lottery is VRFConsumerBaseV2, KeeperCompatible {
    /* Type declaration */
    enum LotteryState {
        Open,
        Calculating
    }
    /* state variables */
    uint256 private immutable entranceFee;
    VRFCoordinatorV2Interface private vrfCoordinator;
    bytes32 private immutable gasLane;
    uint64 subscriptionId;
    uint32 private immutable callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    address payable[] private players;
    uint256 private lastTimeStamp;
    uint256 private immutable interval;

    address recentWinner;
    LotteryState private lotteryState;

    /* events */
    event RaffleEntered(address indexed player);
    event RequestedLotteryWinner(uint256 requestId);
    event WinnerPicked(address recentWinner);

    constructor(
        address _vrfCoordinator,
        uint256 _entranceFee,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        uint256 _interval
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        entranceFee = _entranceFee;
        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        gasLane = _gasLane;
        lotteryState = LotteryState.Open;
        lastTimeStamp = block.timestamp;
        interval = _interval;
    }

    function enterLottery() public payable {
        if (msg.value < entranceFee) {
            revert Lottery__NotEnoughETH();
        }
        if (lotteryState != LotteryState.Open) {
            revert Lottery__NotOpen();
        }
        players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // called by chainlink keeper nodes to perform upkeep when returns 'true'
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = LotteryState.Open == lotteryState;
        bool timePassed = (block.timestamp - lastTimeStamp) > interval;
        bool hasPlayers = players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    function performUpkeep(
        bytes calldata /*performData*/
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery_UpKeepNotNeeded(
                address(this).balance,
                players.length,
                uint256(lotteryState)
            );
        }
        // Will revert if subscription is not set and funded.
        uint256 requestId = vrfCoordinator.requestRandomWords(
            gasLane,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            NUM_WORDS
        );
        lotteryState = LotteryState.Calculating;
        emit RequestedLotteryWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /*requestId*/
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % players.length;
        address payable winner = players[indexOfWinner];
        recentWinner = winner;
        lotteryState = LotteryState.Calculating;
        players = new address payable[](0);
        lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    function getEntranceFee() public view returns (uint256) {
        return entranceFee;
    }

    function getPlayer(uint256 _index) public view returns (address) {
        return players[_index];
    }

    function getRecentWinner() public view returns (address) {
        return recentWinner;
    }

    function getLotteryState() public view returns (LotteryState) {
        return lotteryState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return players.length;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return lastTimeStamp;
    }

    function getRequestConfirmatons() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
}
