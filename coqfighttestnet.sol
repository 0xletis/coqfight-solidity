// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract CoqFightTestnet is VRFConsumerBaseV2, ConfirmedOwner {
    using SafeMath for uint256;

    // Counter to avoid generation of same gameIDs
    uint256 private gameCounter = 1;  

    // Array to track active (not completed) game IDs
    uint256[] public activeGameIds;

    // Token used for wagers
    // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
    // IERC20 public coqToken;

    // Minimum wager required to start a game
    uint256 public minimumWager;

    // State variable to store the fee percentage ( 1000 = 1%, will be used for maintaining costs of VRF + automation )
    // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
    // uint256 public fee = 0; 

    // Game bot address that calls CompleteGame function when a game is joined 
    address public botAddress = 0xc5b407677BFaf9f5a1523ac54E630C046aFe3B49;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // pPast requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network, see
    // https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    // Currently using Avalanche Fuji Testnet Keyhash for testnet purposes
    bytes32 keyHash =
        0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe* for this contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    // Currently using 100.000 for tesnet automatisation of games, will
    // change the logic for an automatic bot in mainnet
    uint32 callbackGasLimit = 100000;

    // Number of confirmations, set to 3 by default
    uint16 requestConfirmations = 3;

    // Retrieve one random word from VRF
    uint32 numWords = 1;

    // Struct to represent a game
    struct Game {
        address player1;
        address player2;
        uint256 wager;
        bool completed;
        address winner;
    }

    // Struct to represent requests
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Mapping from game ID to Game
    mapping(uint256 => Game) public games;
    // Mapping from game ID to request ID
    mapping(uint256 => uint256) public gameIdByRequestId;

    // Event emitted when randomness request to VRF
    event RequestSent(uint256 requestId, uint32 numWords);

    // Event emmited when randomness fulfilled by VRF
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    // Event emitted when a new game is started
    event GameStarted(uint256 indexed gameId, address indexed player1, uint256 wager);

    // Event emitted when a player joins a game
    event PlayerJoined(uint256 indexed gameId, address indexed player2);

    // Event emitted when a game is cancelled
    event GameCancelled(uint256 indexed gameId);

    // Event emitted when a game is completed, and a winner is determined
    event GameCompleted(uint256 indexed gameId, address indexed winner);

    // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
    // constructor(address _coqToken) {
    //     coqToken = IERC20(_coqToken);
    // }
    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x2eD832Ba664535e5886b75D64C46EB9a228C2610)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x2eD832Ba664535e5886b75D64C46EB9a228C2610
        );
        // Set initial VRF subscriptionId
        s_subscriptionId = subscriptionId;
        // Set an initial minimum wager (can be updated by the owner)
        minimumWager = 100000000000000000; // 0.1 AVAX (adjust as needed)
        // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
        // coqToken = IERC20(0x420FcA0121DC28039145009570975747295f2329);
    }

    // * * * * * * * *
    // GAME FUNCTIONS
    // * * * * * * * *

    // Function to start a new game
    function startGame(uint256 _wager) external payable {
        // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
        // require(coqToken.transferFrom(msg.sender, address(this), _wager), "Transfer failed");
        require(msg.value >= minimumWager, "Wager amount is less than minimumWager");

        uint256 gameId = _generateGameId();
        games[gameId] = Game(msg.sender, address(0), _wager, false, address(0));
        activeGameIds.push(gameId); // Add the new game to activeGameIds

        emit GameStarted(gameId, msg.sender, _wager);
    }

    // Function to join an existing game
    function joinGame(uint256 _gameId) external payable {
        Game storage game = games[_gameId];
        require(!game.completed, "Game is completed");
        require(game.player2 == address(0), "Game is already joined");
        // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
        // require(coqToken.transferFrom(msg.sender, address(this), game.wager), "Transfer failed");
        require(msg.value == game.wager, "Incorrect amount sent");
        require(game.player1 != address(0), "Game does not exist");
        require(msg.sender != game.player1, "You cannot join your own game"); 

        // Update player 2 in the struct
        game.player2 = msg.sender;

        // Request randomness and store the request ID
        uint256 requestId = requestRandomWords();
        gameIdByRequestId[requestId] = _gameId;

        emit PlayerJoined(_gameId, msg.sender);
    }
    
    // Function to get active (not completed) game IDs
    function getActiveGameIds() external view returns (uint256[] memory) {
        return activeGameIds;
    }

    // Function to cancel a game if no one joins, onlyOwner for now, 
    // can be implemented that player1 can cancel if no one joined in the future
    function cancelGame(uint256 _gameId) external onlyOwner {
        Game storage game = games[_gameId];
        require(game.player1 != address(0), "Game does not exist"); 
        require(!game.completed, "Game is completed");

        // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
        // Return money to player 1 and player 2 if it exists
        //coqToken.transfer(game.player1, game.wager);
        //if(game.player2 != address(0)){
        //    coqToken.transfer(game.player2, game.wager);
        //}
        payable(game.player1).transfer(game.wager);
        // In case the player2 joined and VRF failed to fullfillRandomWords();
        if(game.player2 != address(0)){
             payable(game.player2).transfer(game.wager);
        }

        // Remove the canceled game from activeGameIds
        _removeGameFromActiveList(_gameId);

        delete games[_gameId];

        emit GameCancelled(_gameId);
    }

    // Function to complete a game and determine the winner using Chainlink VRF randomness
    function completeGame(uint256 _gameId, uint256[] memory _randomWords) external {
        Game storage game = games[_gameId];
        require(!game.completed, "Game is already completed");
        require(msg.sender == botAddress,"Caller is not game bot");

        // Use the random words to determine the winner
        // No need to hash the number as its already random
        //uint256 randomValue = uint256(keccak256(abi.encodePacked(_randomWords)));
        game.winner = (_randomWords[0] % 2 == 0) ? game.player1 : game.player2;
        game.completed = true;

        // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
        // Calculate the fee (4.269% of the total wager) and the prize amount
        // uint256 gamefee = game.wager.mul(2).mul(fee).div(100000);
        // uint256 prize = game.wager.mul(2).sub(gamefee);

        // Transfer winnings to the winner
        // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
        //require(coqToken.transfer(game.winner, prize), "Prize transfer failed");
        payable(game.winner).transfer(game.wager.mul(2));

        // Remove the completed game from activeGameIds
        _removeGameFromActiveList(_gameId);

        emit GameCompleted(_gameId, game.winner);
    }

    // Function to remove a game from the activeGameIds array
    function _removeGameFromActiveList(uint256 _gameId) internal {
        for (uint256 i = 0; i < activeGameIds.length; i++) {
            if (activeGameIds[i] == _gameId) {
                // Move the last element to the position of the removed element and then shorten the array
                activeGameIds[i] = activeGameIds[activeGameIds.length - 1];
                activeGameIds.pop();
                break;
            }
        }
    }

    // Function to generate a unique game ID (simplified for example purposes)
    function _generateGameId() private returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, gameCounter++)));
    }

    // Function to set the minimum wager by the contract owner
    function setMinimumWager(uint256 _newMinimumWager) external onlyOwner {
        minimumWager = _newMinimumWager;
    }

    // Function to set callbackGasLimit of VRF in case its too low to be able to handle games
    function setCallback(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

     // Function to set callbackGasLimit of VRF in case its too low to be able to handle games
    function setBotAddress(address _botAddress) external onlyOwner {
        botAddress = _botAddress;
    }

    // COMMENTED FOR REMIX TESTING PURPOSE WITH NATIVE TOKEN
    // Function to set playable token address wager by the contract owner, in case of issue in constructor
    //function setCoqToken(IERC20 _coqToken) external onlyOwner {
    //    coqToken = _coqToken;
    //}

    // Function to set a new fee percentage (onlyOwner)
    //function setFee(uint256 _newFee) external onlyOwner {
    //    require(_newFee <= 4269, "Fee must be less or equal than 4.269%");
    //    fee = _newFee;
    //}

    // Function to withdraw accumulated fees in the contract
    //function withdraw() external onlyOwner {
    //    uint256 contractBalance = coqToken.balanceOf(address(this));
    //    require(contractBalance > 0, "No funds to withdraw");
    //    require(coqToken.transfer(msg.sender, contractBalance), "Withdrawal failed");
    //}

    // * * * * * * * * 
    //  VRF FUNCTIONS
    // * * * * * * * *

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() internal returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        // HANDLED BY THE GAME BOT WHEN HE HEARD REQUESTFULFILLED NOW
        // Retrieve the game ID using the stored request ID
        //uint256 gameId = gameIdByRequestId[_requestId];

        // Use the game ID to complete the game based on the received random words
        //_completeGame(gameId, _randomWords);

        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}