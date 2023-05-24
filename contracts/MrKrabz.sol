// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// OPENZEPPLIN
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// AXELAR
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

// TELLOR
import "usingtellor/contracts/UsingTellor.sol";

contract MrKrabz is UsingTellor, AxelarExecutable {
    ////// CONTRACTS ////
    // axelar gas service
    IAxelarGasService public immutable gasService;

    ///// STRUCT's //////

    // round multi chain balance
    struct CrossChainBalance {
        uint256 fil;
        uint256 matic;
        uint256 krabz;
    }

    // ticket struct
    struct Ticket {
        address owner;
        uint256 ID;
        uint256[3] selectedNumbers;
        bool withdrawn;
        uint256 originChain;
    }

    // round struct
    struct Round {
        string roundName;
        uint256 roundId;
        uint256 ticketsPurchased;
        uint256 roundEndTime;
        uint256 ticketPrice;
        uint256[3] roundWinningNumbers;
        bool roundState; // true = winners decided ? false = anyone can participate
        CrossChainBalance balance;
    }

    // user struct
    struct User {
        address user;
        uint256 totalTicketsPurchased;
        uint256 totalWinnings;
        CrossChainBalance balance;
    }

    ////// ADDRESSES /////

    address public krabzTokenAddress;

    address public deployer;

    ///// UINT256's //////

    // chain ids (TESTNET)
    uint256 public FILECOIN_CHAIN_ID = 3141;
    uint256 public POLYGON_CHAIN_ID = 80001;

    // execution path handlers
    uint256 public topUpWalletPath = 1;
    uint256 public buyTicketPath = 2;
    uint256 public newRoundPath = 3;
    uint256 public setRandomWinnersPath = 4;
    uint256 public claimWinningsPath = 5;
    uint256 public withdrawFromWalletPath = 6;

    // current round id
    uint256 public currentRound;

    // max ticket per round
    uint256 public MAX_TICKET_PER_ROUND = 3;

    // predicatble val
    uint256 public PREDICTABLE_VALUE = 12983786;

    //// STRINGS ////

    // chain names
    string public filecoinChain = "filecoin";
    string public polygonChain = "Polygon";

    // destination address
    string public filecoinDestinationAddr;
    string public polygonDestinationAddr;

    ///// MAPPING's /////

    // user address to user struct
    mapping(address => User) public userDetails_;

    // round to ticket id to ticket
    mapping(uint256 => mapping(uint256 => Ticket)) public roundToticketId_;

    // round id to round struct
    mapping(uint256 => Round) public roundIdToRoundDetails_;

    // tickets purcahsed per round
    mapping(uint256 => mapping(address => uint256)) public ticketsPurchasedPerRound_;

    // round to tickets purchased
    mapping(uint256 => Ticket[]) public roundIdToTicketList_;

    //  CONSTRUCTOR
    constructor(
        address _gateway,
        address _gasReceiver,
        address payable _tellorAddress,
        address _krabzTokenAddress
    ) UsingTellor(_tellorAddress) AxelarExecutable(_gateway) {
        // gas service
        gasService = IAxelarGasService(_gasReceiver);

        // krabz token address
        krabzTokenAddress = _krabzTokenAddress;

        // deployer
        deployer = msg.sender;
    }

    ///// MAIN CONTRACT FUNCTIONS //////

    // top up wallet balance
    function topUpWalletBalance(
        uint256 _amount,
        bool _nativeAsset,
        uint256 _estimateGasAmountOne
    ) public payable {
        // decide amount
        uint256 amount;
        if (_nativeAsset) amount = msg.value;
        else {
            amount = _amount;
            // transfer krabz token
            IERC20(krabzTokenAddress).transferFrom(msg.sender, address(this), _amount);
        }

        // make the cross chain call
        _handleTopUpWalletBalanceCrossChain(
            amount,
            _nativeAsset,
            msg.sender,
            _estimateGasAmountOne
        );
    }

    // buy ticket
    function buyTicket(
        uint256[3] memory _selectedNumbers,
        bool _nativeAsset,
        uint256 _estimateGasAmountOne
    ) public {
        // has the end time for the round passed ?
        uint256 roundEndTime = roundIdToRoundDetails_[currentRound].roundEndTime;
        if (block.timestamp > roundEndTime) revert("Round Passed!");

        // round entry state passed: currently in deciding winners state
        if (roundIdToRoundDetails_[currentRound].roundState) revert("Entry Closed");

        // check each number selection
        for (uint i = 0; i < _selectedNumbers.length; i++) {
            if (_selectedNumbers[i] > 30) revert("Num > 30");
        }

        // check if the amount sent or approved is valid for the ticket purchase
        uint256 requiredAsset;
        uint256 roundTicketPrice = roundIdToRoundDetails_[currentRound].ticketPrice;

        if (_nativeAsset) {
            if (block.chainid == FILECOIN_CHAIN_ID) {
                requiredAsset = (roundTicketPrice * 10 ** 18) / getAssetPriceUsd("fil");
                // low wallet balance
                require(userDetails_[msg.sender].balance.fil >= requiredAsset, "Low Bal");

                // deduct from users wallet balance
                userDetails_[msg.sender].balance.fil -= requiredAsset;

                // update the lotto corss chain balance
                roundIdToRoundDetails_[currentRound].balance.fil += requiredAsset;
            }

            if (block.chainid == POLYGON_CHAIN_ID) {
                requiredAsset = (roundTicketPrice * 10 ** 18) / getAssetPriceUsd("matic");
                require(
                    userDetails_[msg.sender].balance.matic >= requiredAsset,
                    "Insufficient Wallet Balance"
                );

                // deduct from users wallet balance
                userDetails_[msg.sender].balance.matic -= requiredAsset;

                // update the lotto corss chain balance
                roundIdToRoundDetails_[currentRound].balance.matic += requiredAsset;
            }
        } else {
            requiredAsset = (roundTicketPrice * 10 ** 18) / getAssetPriceUsd("badger");
            require(
                userDetails_[msg.sender].balance.krabz >= requiredAsset,
                "Insufficient Wallet Balance"
            );

            // deduct from users wallet balance
            userDetails_[msg.sender].balance.krabz -= requiredAsset;

            // update the lotto corss chain balance
            roundIdToRoundDetails_[currentRound].balance.krabz += requiredAsset;
        }

        // if user has bought more than 3 tickets stop em
        if (ticketsPurchasedPerRound_[currentRound][msg.sender] >= MAX_TICKET_PER_ROUND)
            revert("Max Tickets");

        // increment round participations => no of tickets purchased
        uint256 ticketId = roundIdToRoundDetails_[currentRound].ticketsPurchased += 1;

        // update ticket details
        roundToticketId_[currentRound][ticketId] = Ticket({
            owner: msg.sender,
            ID: ticketId,
            selectedNumbers: _selectedNumbers,
            withdrawn: false,
            originChain: block.chainid
        });

        // update total number of tickets purchased by a user since joining mrkrabz
        userDetails_[msg.sender].totalTicketsPurchased += 1;

        // update the list of tickets
        roundIdToTicketList_[currentRound].push(roundToticketId_[currentRound][ticketId]);

        // tickets purchased by round for user
        ticketsPurchasedPerRound_[currentRound][msg.sender] += 1;

        // handle buy ticket across chains
        _handleBuyTicketCrossChain(
            ticketId,
            msg.sender,
            _selectedNumbers,
            block.chainid,
            _nativeAsset,
            requiredAsset,
            currentRound,
            roundToticketId_[currentRound][ticketId],
            _estimateGasAmountOne
        );
    }

    // claim winnings
    function claimWinnings(uint256 _ticketId, uint256 _estimateGasAmountOne) public {
        // the round state must be over
        if (!roundIdToRoundDetails_[currentRound].roundState) revert("Round On");

        // must withdraw ticket from origin chain
        if (roundToticketId_[currentRound][_ticketId].originChain != block.chainid)
            revert("! Origin Chain");

        // must be the owner of the ticket
        if (roundToticketId_[currentRound][_ticketId].owner != msg.sender) revert("! Ticket Owner");

        // check if the withdrawn state for the ticket is true
        if (roundToticketId_[currentRound][_ticketId].withdrawn) revert("Claimed");

        // check if the ticket is a winning ticket
        bool isTicketWinner = isWinner(_ticketId);
        require(isTicketWinner, "! Winner");

        // get the total number of winners
        uint256 totalWinners = getTotalRoundWinners();

        // get the total pool balance is in usd
        uint256 roundPoolBalanceInUsd = getRoundPoolBalanceUsd();

        // get individual winner amount in usd
        uint256 individualWinnerAmount = roundPoolBalanceInUsd / totalWinners;

        // get individual winner amount in krabz
        uint256 individualWinnerAmountInKrabz = (individualWinnerAmount * 10 ** 18) /
            getAssetPriceUsd("badger");

        // update users krabz balance
        userDetails_[msg.sender].balance.krabz += individualWinnerAmountInKrabz;
        // update winning count
        userDetails_[msg.sender].totalWinnings += 1;

        // update ticket withdrawal state
        roundToticketId_[currentRound][_ticketId].withdrawn = true;

        // update the balance cross chain
        _handleClaimWinningsCrossChain(
            individualWinnerAmountInKrabz,
            msg.sender,
            _estimateGasAmountOne
        );
    }

    // claim funds
    function claimRefund(uint256 _ticketId, uint256 _estimateGasAmountOne) public {
        // the round state must be over
        if (!roundIdToRoundDetails_[currentRound].roundState) revert("Round On");

        // must withdraw ticket from origin chain
        if (roundToticketId_[currentRound][_ticketId].originChain != block.chainid)
            revert("! Origin Chain");

        // must be the owner of the ticket
        if (roundToticketId_[currentRound][_ticketId].owner != msg.sender) revert("! Ticket Owner");

        // check if the withdrawn state for the ticket is true
        if (roundToticketId_[currentRound][_ticketId].withdrawn) revert("Ticket Claimed");

        // check if the ticket is a winning ticket
        bool isTicketWinner = isWinner(_ticketId);
        require(!isTicketWinner, "Winner");

        uint256 ticketPriceInUsd = roundIdToRoundDetails_[currentRound].ticketPrice;

        // get individual winner amount in krabz
        uint256 individualRefundAmountInKrabz = (ticketPriceInUsd * 10 ** 18) /
            getAssetPriceUsd("badger");

        // update users krabz balance
        userDetails_[msg.sender].balance.krabz += (individualRefundAmountInKrabz * 30) / 100;

        // update ticket withdrawal state
        roundToticketId_[currentRound][_ticketId].withdrawn = true;

        // update the balance cross chain
        _handleTopUpWalletBalanceCrossChain(
            (individualRefundAmountInKrabz * 30) / 100,
            false,
            msg.sender,
            _estimateGasAmountOne
        );
    }

    // ADMIN FUNCTIONS (TO BE LATER HANDLED BY CHAINLINK AUTOMATION)

    // start new round
    function startNewRound(
        uint256 _roundEndTime,
        uint256 _ticketPriceInUsd,
        string memory _roundName,
        uint256 _estimateGasAmountOne
    ) public {
        // special caller check
        require(msg.sender == deployer, "!Special Caller");

        if (block.timestamp < roundIdToRoundDetails_[currentRound].roundEndTime) revert("Round On");

        // set the current round
        currentRound += 1;

        // update the round details
        roundIdToRoundDetails_[currentRound].roundId = currentRound;
        roundIdToRoundDetails_[currentRound].ticketPrice = _ticketPriceInUsd;
        roundIdToRoundDetails_[currentRound].roundEndTime = block.timestamp + _roundEndTime;
        roundIdToRoundDetails_[currentRound].roundName = _roundName;

        _handleStartNewRoundCrossChain(
            currentRound,
            _roundEndTime + block.timestamp,
            _ticketPriceInUsd,
            _roundName,
            _estimateGasAmountOne
        );
    }

    // set round winner
    function setRoundWinners(
        uint256 _nonceOne,
        uint256 _nonceTwo,
        uint256 _nonceThree,
        uint256 _estimateGasAmountOne
    ) public {
        // special caller check
        require(msg.sender == deployer, "!Admin");

        // makes sure the winners for the round hasnt already been announced
        if (roundIdToRoundDetails_[currentRound].roundState) revert("Announced");

        // check that the round end time has passed
        if (block.timestamp < roundIdToRoundDetails_[currentRound].roundEndTime) revert("Round On");

        // you can only set the winners from the fvm chain
        if (block.chainid != FILECOIN_CHAIN_ID) revert("!FVM");

        //  Intentionally setting the random number to a predictable value:
        // 1. For testing
        // 2. Lack of chainlink VRF on FVM as of time of writing
        uint256 randomNumberOne = uint256(
            keccak256(abi.encodePacked(PREDICTABLE_VALUE, msg.sender, _nonceOne))
        ) % 30;

        uint256 randomNumberTwo = uint256(
            keccak256(abi.encodePacked(PREDICTABLE_VALUE, msg.sender, _nonceTwo))
        ) % 30;

        uint256 randomNumberThree = uint256(
            keccak256(abi.encodePacked(PREDICTABLE_VALUE, msg.sender, _nonceThree))
        ) % 30;

        // update round details
        roundIdToRoundDetails_[currentRound].roundState = true;
        roundIdToRoundDetails_[currentRound].roundWinningNumbers = [
            randomNumberOne,
            randomNumberTwo,
            randomNumberThree
        ];

        _handleSetRandomWinnersCrossChain(
            currentRound,
            [randomNumberOne, randomNumberTwo, randomNumberThree],
            _estimateGasAmountOne
        );
    }

    ////// CROSS CHAIN HELPER FUNCTIONS /////

    function _handleBuyTicketCrossChain(
        uint256 _ticketId,
        address _user,
        uint256[3] memory _selectedNumbers,
        uint256 _originChainId,
        bool _nativeAsset,
        uint256 _requiredAsset,
        uint256 _currentRoundId,
        Ticket memory _ticket,
        uint256 _estimateGasAmountOne
    ) internal {
        // inner payload
        bytes memory innerPayload = abi.encode(
            _ticketId,
            _user,
            _selectedNumbers,
            _originChainId,
            _nativeAsset,
            _requiredAsset,
            _currentRoundId,
            _ticket
        );

        // main payload
        bytes memory payload = abi.encode(buyTicketPath, innerPayload);

        if (block.chainid == FILECOIN_CHAIN_ID) {
            _sendPayloadFromFilecoin(payload, _estimateGasAmountOne);
        }

        if (block.chainid == POLYGON_CHAIN_ID) {
            _sendPayloadFromPolygon(payload, _estimateGasAmountOne);
        }
    }

    // handle start new round cross chain
    function _handleStartNewRoundCrossChain(
        uint256 _currentRound,
        uint256 _roundEndTime,
        uint256 _ticketPriceInUsd,
        string memory _roundName,
        uint256 _estimateGasAmountOne
    ) internal {
        // inner payload
        bytes memory innerPayload = abi.encode(
            _currentRound,
            _roundEndTime,
            _ticketPriceInUsd,
            _roundName
        );

        // payload
        bytes memory payload = abi.encode(newRoundPath, innerPayload);

        if (block.chainid == FILECOIN_CHAIN_ID)
            _sendPayloadFromFilecoin(payload, _estimateGasAmountOne);

        if (block.chainid == POLYGON_CHAIN_ID)
            _sendPayloadFromPolygon(payload, _estimateGasAmountOne);
    }

    // handle top up wallet balance cross chain
    function _handleTopUpWalletBalanceCrossChain(
        uint256 _amount,
        bool _nativeAsset,
        address _user,
        uint256 _estimateGasAmountOne
    ) internal {
        if (block.chainid == FILECOIN_CHAIN_ID) {
            // if native asset is true. pay with it. else use krabz token
            if (_nativeAsset) userDetails_[_user].balance.fil += _amount;
            else userDetails_[_user].balance.krabz += _amount;

            // inner payload
            bytes memory innerPayload = abi.encode(FILECOIN_CHAIN_ID, _nativeAsset, _amount, _user);

            // main payload
            bytes memory payload = abi.encode(topUpWalletPath, innerPayload);

            _sendPayloadFromFilecoin(payload, _estimateGasAmountOne);
        }

        if (block.chainid == POLYGON_CHAIN_ID) {
            // if native asset is true. pay with it. else use krabz token
            if (_nativeAsset) userDetails_[_user].balance.matic += _amount;
            else userDetails_[_user].balance.krabz += _amount;

            // inner payload
            bytes memory innerPayload = abi.encode(FILECOIN_CHAIN_ID, _nativeAsset, _amount, _user);

            // main payload
            bytes memory payload = abi.encode(topUpWalletPath, innerPayload);

            _sendPayloadFromPolygon(payload, _estimateGasAmountOne);
        }
    }

    function _handleClaimWinningsCrossChain(
        uint256 _individualWinnerAmountInKrabz,
        address _user,
        uint256 _estimateGasAmountOne
    ) internal {
        if (block.chainid == FILECOIN_CHAIN_ID) {
            // inner payload
            bytes memory innerPayload = abi.encode(_individualWinnerAmountInKrabz, _user);

            // main payload
            bytes memory payload = abi.encode(claimWinningsPath, innerPayload);

            _sendPayloadFromFilecoin(payload, _estimateGasAmountOne);
        }

        if (block.chainid == POLYGON_CHAIN_ID) {
            // inner payload
            bytes memory innerPayload = abi.encode(_individualWinnerAmountInKrabz, _user);

            // main payload
            bytes memory payload = abi.encode(claimWinningsPath, innerPayload);

            _sendPayloadFromPolygon(payload, _estimateGasAmountOne);
        }
    }

    function _handleSetRandomWinnersCrossChain(
        uint256 _currentRound,
        uint256[3] memory _randomWinningNumbers,
        uint256 _estimateGasAmountOne
    ) internal {
        bytes memory innerPayload = abi.encode(_currentRound, _randomWinningNumbers);

        bytes memory payload = abi.encode(setRandomWinnersPath, innerPayload);

        if (block.chainid == FILECOIN_CHAIN_ID) {
            _sendPayloadFromFilecoin(payload, _estimateGasAmountOne);
        }

        if (block.chainid == POLYGON_CHAIN_ID) {
            _sendPayloadFromPolygon(payload, _estimateGasAmountOne);
        }
    }

    // AXELAR FUNCTIONS

    // Handles calls created by setAndSend. Updates this contract's value
    function _execute(string calldata, string calldata, bytes calldata payload) internal override {
        (uint256 executionPath, bytes memory innerPayload) = abi.decode(payload, (uint256, bytes));

        // top up wallet execution path
        if (executionPath == topUpWalletPath) {
            (uint256 chainid, bool nativeAsset, uint256 amount, address user) = abi.decode(
                innerPayload,
                (uint256, bool, uint256, address)
            );

            _handleTopupWalletExecutionPath(chainid, nativeAsset, amount, user);
        }

        // buy ticket path
        if (executionPath == buyTicketPath) {
            // unpack innerpayload
            (
                uint256 ticketId,
                address user,
                uint256[3] memory selectedNumbers,
                uint256 originChainId,
                bool nativeAsset,
                uint256 requiredAsset,
                uint256 currentRoundId,
                Ticket memory ticket
            ) = abi.decode(
                    innerPayload,
                    (uint256, address, uint256[3], uint256, bool, uint256, uint256, Ticket)
                );

            _handleBuyTicketexecutionPath(
                ticketId,
                user,
                selectedNumbers,
                originChainId,
                nativeAsset,
                requiredAsset,
                currentRoundId,
                ticket
            );
        }

        if (executionPath == newRoundPath) {
            (
                uint256 currentRoundId,
                uint256 roundEndTime,
                uint256 ticketPriceInUsd,
                string memory roundName
            ) = abi.decode(innerPayload, (uint256, uint256, uint256, string));

            // start new round
            currentRound = currentRoundId;

            // update the round details
            roundIdToRoundDetails_[currentRoundId].roundId = currentRoundId;
            roundIdToRoundDetails_[currentRoundId].ticketPrice = ticketPriceInUsd;
            roundIdToRoundDetails_[currentRoundId].roundEndTime = roundEndTime;
            roundIdToRoundDetails_[currentRoundId].roundName = roundName;
        }

        if (executionPath == setRandomWinnersPath) {
            // unpack innerpayload
            (uint256 roundId, uint256[3] memory randomWinningNumbers) = abi.decode(
                innerPayload,
                (uint256, uint256[3])
            );

            // update round details
            roundIdToRoundDetails_[roundId].roundState = true;
            roundIdToRoundDetails_[roundId].roundWinningNumbers = randomWinningNumbers;
        }

        if (executionPath == claimWinningsPath) {
            // unpack inner payload
            (uint256 individualWinnerAmountInKrabz, address user) = abi.decode(
                innerPayload,
                (uint256, address)
            );

            // update users krabz balance
            userDetails_[user].balance.krabz += individualWinnerAmountInKrabz;

            // update winning count
            userDetails_[user].totalWinnings += 1;
        }

        if (executionPath == withdrawFromWalletPath) {
            (uint256 assetType, uint256 amount, address user) = abi.decode(
                innerPayload,
                (uint256, uint256, address)
            );

            if (assetType == FILECOIN_CHAIN_ID) {
                userDetails_[user].balance.fil -= amount;
            }

            if (assetType == POLYGON_CHAIN_ID) {
                userDetails_[user].balance.matic -= amount;
            }

            if (assetType == 3) {
                userDetails_[user].balance.krabz -= amount;
            }
        }
    }

    ///// EXECUTION PATH HANDLERS ////

    // handle wallet top up execution reception
    function _handleTopupWalletExecutionPath(
        uint256 _chainid,
        bool _nativeAsset,
        uint256 _amount,
        address _user
    ) internal {
        if (_chainid == FILECOIN_CHAIN_ID) {
            if (_nativeAsset) userDetails_[_user].balance.fil += _amount;
            else userDetails_[_user].balance.krabz += _amount;
        }

        if (_chainid == POLYGON_CHAIN_ID) {
            if (_nativeAsset) userDetails_[_user].balance.matic += _amount;
            else userDetails_[_user].balance.krabz += _amount;
        }
    }

    // buy ticket execution path
    function _handleBuyTicketexecutionPath(
        uint256 _ticketId,
        address _user,
        uint256[3] memory _selectedNumbers,
        uint256 _originChainId,
        bool _nativeAsset,
        uint256 _requiredAsset,
        uint256 _currentRoundId,
        Ticket memory _ticket
    ) internal {
        if (_nativeAsset) {
            if (_originChainId == FILECOIN_CHAIN_ID) {
                // deduct from users wallet balance
                userDetails_[_user].balance.fil -= _requiredAsset;

                // update the lotto corss chain balance
                roundIdToRoundDetails_[_currentRoundId].balance.fil += _requiredAsset;
            }

            if (_originChainId == POLYGON_CHAIN_ID) {
                // deduct from users wallet balance
                userDetails_[_user].balance.matic -= _requiredAsset;

                // update the lotto corss chain balance
                roundIdToRoundDetails_[_currentRoundId].balance.matic += _requiredAsset;
            }
        } else {
            // deduct from users wallet balance
            userDetails_[_user].balance.krabz -= _requiredAsset;

            // update the lotto corss chain balance
            roundIdToRoundDetails_[_currentRoundId].balance.krabz += _requiredAsset;
        }

        // increment round participations => no of tickets purchased
        roundIdToRoundDetails_[_currentRoundId].ticketsPurchased += 1;

        // update ticket details
        roundToticketId_[_currentRoundId][_ticketId] = Ticket({
            owner: _user,
            ID: _ticketId,
            selectedNumbers: _selectedNumbers,
            withdrawn: false,
            originChain: _originChainId
        });

        userDetails_[_user].totalTicketsPurchased += 1;

        roundIdToTicketList_[_currentRoundId].push(_ticket);

        ticketsPurchasedPerRound_[_currentRoundId][_user] += 1;
    }

    ///// SEND PAYLOAD CROSS CHAIN FUNCTIONS ////

    // sending cc message from filecoin
    function _sendPayloadFromFilecoin(
        bytes memory _payload,
        uint256 _estimateGasAmountOne
    ) internal {
        // Filecoin ->  Polygon

        gasService.payNativeGasForContractCall{value: _estimateGasAmountOne}(
            address(this),
            polygonChain,
            polygonDestinationAddr,
            _payload,
            address(this)
        );

        gateway.callContract(polygonChain, polygonDestinationAddr, _payload);
    }

    // sending cc message from polygon
    function _sendPayloadFromPolygon(
        bytes memory _payload,
        uint256 _estimateGasAmountOne
    ) internal {
        // Polygon -> Filecoin

        gasService.payNativeGasForContractCall{value: _estimateGasAmountOne}(
            address(this),
            filecoinChain,
            filecoinDestinationAddr,
            _payload,
            address(this)
        );

        gateway.callContract(filecoinChain, filecoinDestinationAddr, _payload);
    }

    // ASSET PRICE

    // returns asset price given asset name
    function getAssetPriceUsd(string memory _assetName) public view returns (uint256) {
        bytes memory specificQuery = abi.encode(_assetName, "usd");
        bytes memory _queryData = abi.encode("SpotPrice", specificQuery);

        bytes32 _queryId = keccak256(_queryData);

        (bytes memory _value, uint256 _timestampRetrieved) = getDataBefore(
            _queryId,
            block.timestamp - 20 minutes
        );
        if (_timestampRetrieved == 0) return 0;

        return abi.decode(_value, (uint256)) / 1e10;
    }

    ////// HELPER FUNCTIONS /////
    function isWinner(uint256 _ticketId) public view returns (bool) {
        uint256[3] memory ticketSelections = roundToticketId_[currentRound][_ticketId]
            .selectedNumbers;

        uint256[3] memory winningSelections = roundIdToRoundDetails_[currentRound]
            .roundWinningNumbers;
        bool equal = _checkEquality(ticketSelections, winningSelections);
        return equal;
    }

    function getTotalRoundWinners() public view returns (uint256) {
        uint256 totalWinners;
        for (uint i = 0; i < roundIdToTicketList_[currentRound].length; i++) {
            uint256 ticketId = roundIdToTicketList_[currentRound][i].ID;
            if (isWinner(ticketId)) {
                totalWinners += 1;
            }
        }

        return totalWinners;
    }

    function getRoundPoolBalanceUsd() public view returns (uint256) {
        // fil
        uint256 filRoundBalance = roundIdToRoundDetails_[currentRound].balance.fil;
        uint256 filPoolBalanceInUsd = (getAssetPriceUsd("fil") * filRoundBalance) / 10 ** 18;

        // matic
        uint256 maticRoundBalance = roundIdToRoundDetails_[currentRound].balance.matic;
        uint256 maticPoolBalanceInUsd = (getAssetPriceUsd("matic") * maticRoundBalance) / 10 ** 18;

        uint256 totalRoundBalance = filPoolBalanceInUsd + maticPoolBalanceInUsd;

        return (totalRoundBalance * 70) / 100;
    }

    function _checkEquality(
        uint256[3] memory _winningSelections,
        uint256[3] memory _userSelections
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < _winningSelections.length; i++) {
            if (_winningSelections[i] != _userSelections[i]) {
                return false;
            }
        }
        return true;
    }

    ////// UI GETTER FUNCTIONS /////

    // get user details
    function getUserDetails(address _user) public view returns (User memory) {
        return userDetails_[_user];
    }

    // get users tickets
    function getUserTicketsForCurrentRound(address _user) public view returns (Ticket[] memory) {
        uint256 ticketCount = 0;

        // count the number of tickets owned by the user
        for (uint i = 0; i < roundIdToTicketList_[currentRound].length; i++) {
            if (roundIdToTicketList_[currentRound][i].owner == _user) {
                ticketCount++;
            }
        }

        // create a new array to store the users tickets
        Ticket[] memory userTickets = new Ticket[](ticketCount);
        uint256 currentIndex = 0;

        // iterate over the tickets and populate the user's ticket array
        for (uint i = 0; i < roundIdToTicketList_[currentRound].length; i++) {
            if (roundIdToTicketList_[currentRound][i].owner == _user) {
                userTickets[currentIndex] = roundIdToTicketList_[currentRound][i];
            }

            currentIndex += 1;
        }

        return userTickets;
    }

    //get current round
    function getCurrentRoundDetails() public view returns (Round memory) {
        return roundIdToRoundDetails_[currentRound];
    }

    // tickets purchased per round
    function getTicketsPurchasedPerRound(address _user) public view returns (uint256) {
        return ticketsPurchasedPerRound_[currentRound][_user];
    }

    ////// UPDATE FUNCTIONS //////
    function updateDestinationAddresses(
        string memory _filDestinationAddress,
        string memory _polygonDestinationAddress
    ) public {
        filecoinDestinationAddr = _filDestinationAddress;
        polygonDestinationAddr = _polygonDestinationAddress;
    }

    // WITHDRAW FROM CROSS CHAIN WALLET //////
    function withdrawFromWallet(
        uint256 _assetType,
        uint256 _amount,
        uint256 _estimateGasAmount
    ) public {
        // asset type 3141 = fil
        // asset type 80001 = matic
        // asset type 3 = krabz

        if (_assetType == FILECOIN_CHAIN_ID) {
            if (userDetails_[msg.sender].balance.fil < _amount) revert("insufficient balance");
            userDetails_[msg.sender].balance.fil -= _amount;
            (bool success, ) = msg.sender.call{value: _amount}("");
            require(success, "!ok");
        }

        if (_assetType == POLYGON_CHAIN_ID) {
            if (userDetails_[msg.sender].balance.matic < _amount) revert("insufficient balance");
            userDetails_[msg.sender].balance.matic -= _amount;
            (bool success, ) = msg.sender.call{value: _amount}("");
            require(success, "!ok");
        }

        if (_assetType == 3) {
            if (userDetails_[msg.sender].balance.krabz < _amount) revert("insufficient balance");
            userDetails_[msg.sender].balance.krabz -= _amount;
            IERC20(krabzTokenAddress).transfer(msg.sender, _amount);
        }

        bytes memory innerPayload = abi.encode(_assetType, _amount, msg.sender);

        bytes memory payload = abi.encode(withdrawFromWalletPath, innerPayload);

        if (block.chainid == FILECOIN_CHAIN_ID) {
            _sendPayloadFromFilecoin(payload, _estimateGasAmount);
        }

        if (block.chainid == POLYGON_CHAIN_ID) {
            _sendPayloadFromPolygon(payload, _estimateGasAmount);
        }
    }

    function getCurrentTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    //// TETSING ///
    function withdrawNativeAsset() public {
        require(msg.sender == deployer, "!deployer");
        uint256 contractBalance = address(this).balance;
        (bool success, ) = msg.sender.call{value: contractBalance}("");
        require(success, "!successful");
    }

    receive() external payable {}
}
