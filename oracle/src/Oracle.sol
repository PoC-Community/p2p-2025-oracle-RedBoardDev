// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Oracle {
    struct Round {
        uint256 id;
        uint256 totalSubmissionCount;
        uint256 lastUpdatedAt;
    }

    address public owner;
    address[] public nodes;
    mapping(address => bool) public isNode;
    mapping(string => Round) public rounds;
    mapping(string => mapping(uint256 => mapping(address => uint256))) public nodePrices;
    mapping(string => mapping(uint256 => mapping(address => bool))) public hasSubmitted;
    mapping(string => uint256) public currentPrices;

    event PriceUpdated(string indexed coin, uint256 price, uint256 roundId);

    constructor() {
        owner = msg.sender;
    }

    function submitPrice(string memory coin, uint256 price) public {
        require(isNode[msg.sender], "Not a node");

        uint256 roundId = rounds[coin].id;

        require(!hasSubmitted[coin][roundId][msg.sender], "Already submitted for this round");

        nodePrices[coin][roundId][msg.sender] = price;
        hasSubmitted[coin][roundId][msg.sender] = true;
        rounds[coin].totalSubmissionCount += 1;

        if (rounds[coin].totalSubmissionCount >= getQuorum()) {
            _finalizePrice(coin, roundId);
        }
    }

    function getQuorum() public view returns (uint256) {
        uint256 nodeCount = nodes.length;
        if (nodeCount < 3) {
            return 3;
        }
        return (nodeCount * 2 + 2) / 3;
    }

    function addNode() public {
        require(!isNode[msg.sender], "Node already exists");
        isNode[msg.sender] = true;
        nodes.push(msg.sender);
    }

    function removeNode() public {
        require(isNode[msg.sender], "Node does not exist");
        isNode[msg.sender] = false;

        uint256 nodeCount = nodes.length;
        for (uint256 i = 0; i < nodeCount; i++) {
            if (nodes[i] == msg.sender) {
                nodes[i] = nodes[nodeCount - 1];
                nodes.pop();
                break;
            }
        }
    }

    function _finalizePrice(string memory coin, uint256 roundId) internal {
        uint256 totalPrice = 0;
        uint256 validSubmissionCount = 0;

        uint256 nodeCount = nodes.length;
        for (uint256 i = 0; i < nodeCount; i++) {
            address node = nodes[i];
            if (hasSubmitted[coin][roundId][node]) {
                totalPrice += nodePrices[coin][roundId][node];
                validSubmissionCount += 1;
            }
        }

        if (validSubmissionCount > 0) {
            uint256 avgPrice = totalPrice / validSubmissionCount;
            currentPrices[coin] = avgPrice;
            emit PriceUpdated(coin, avgPrice, roundId);
        }

        rounds[coin].id += 1;
        rounds[coin].totalSubmissionCount = 0;
        rounds[coin].lastUpdatedAt = block.timestamp;
    }
}
