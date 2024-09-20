// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IWitnetRandomness, WitnetV2 } from "witnet/interfaces/IWitnetRandomness.sol";
import { IRng } from "pt-v5-draw-manager/interfaces/IRng.sol";
import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";

import { Requestor } from "./Requestor.sol";

error UnknownRequest(uint32 requestId);

/// @title RngWitnet
/// @author G9 Software Inc.
/// @notice A contract that requests random numbers from the Witnet Randomness Oracle
contract RngWitnet is IRng {

    /// @notice Emitted when a new random number is requested
    /// @param requestId The id of the request
    /// @param sender The address that requested the random number
    /// @param paid The amount paid to the Witnet
    /// @param cost The actual cost of the RNG request. The paid amount less the cost is refunded to the Requestor contract for the caller.
    event RandomNumberRequested(
        uint32 indexed requestId,
        address indexed sender,
        uint256 paid,
        uint256 cost
    );
    
    /// @notice The Witnet Randomness contract
    IWitnetRandomness public immutable witnetRandomness;

    /// @notice A mapping of addresses that requested RNG to their corresponding Requestor contract
    mapping(address user => Requestor) public requestors;

    /// @notice The last request id used by the RNG service
    uint32 public lastRequestId;

    /// @notice A mapping of request ids to the block number at which the request was made
    mapping(uint32 requestId => uint256 lockBlock) public requests;

    /// @notice Creates a new instance of the RngWitnet contract
    /// @param _witnetRandomness The address of the Witnet Randomness contract to use
    constructor(IWitnetRandomness _witnetRandomness) {
        witnetRandomness = _witnetRandomness;
    }

    /// @notice Gets the Requestor contract for the given user. Creates a new one if it doesn't exist
    /// @dev The Requestor contract holds the balance of Ether that a user has sent, so that they can withdraw
    /// @param user The address of the user
    /// @return The Requestor contract for the given user
    function getRequestor(address user) public returns (Requestor) {
        Requestor requestor = requestors[user];
        if (address(requestor) == address(0)) {
            requestor = new Requestor();
            requestors[user] = requestor;
        }
        return requestor;
    }

    /// @notice Gets the block number at which the request was made
    /// @param _requestId The ID of the request used to get the results of the RNG service
    /// @return The block number at which the request was made
    function requestedAtBlock(uint32 _requestId) onlyValidRequest(_requestId) external override view returns (uint256) {
        return requests[_requestId];
    }

    /// @notice Gets the last request id used by the RNG service
    /// @return requestId The last request id used in the last request
    function getLastRequestId() external view returns (uint32 requestId) {
        return lastRequestId;
    }

    /// @notice Estimates the cost of the witnet randomness request
    /// @param _gasPrice The gas price that would be used for the randomize() request
    /// @return The estimated gas cost of the randomize() request
    function estimateRandomizeFee(uint256 _gasPrice) external view returns (uint256) {
        return witnetRandomness.estimateRandomizeFee(_gasPrice);
    }

    /// @notice Requests a random number from the Witnet Randomness Oracle
    /// @param rngPaymentAmount The amount of Ether to send to the Witnet Randomness Oracle. This amount should be sent in this call, remaining from a previous call, or a combination thereof. The Requestor holds the current balance.
    /// @return requestId The id of the request
    /// @return lockBlock The block number at which the request was made
    /// @return cost The actual cost of the RNG request
    function requestRandomNumber(uint256 rngPaymentAmount) public payable returns (uint32 requestId, uint256 lockBlock, uint256 cost) {
        Requestor requestor = getRequestor(msg.sender);
        unchecked {
            requestId = ++lastRequestId;
            lockBlock = block.number;
        }
        requests[requestId] = lockBlock;
        cost = requestor.randomize{value: msg.value}(rngPaymentAmount, witnetRandomness);

        emit RandomNumberRequested(requestId, msg.sender, rngPaymentAmount, cost);
    }

    /// @notice Withdraws the balance of the Requestor contract of the caller
    /// @return The amount of Ether withdrawn
    function withdraw() external returns (uint256) {
        Requestor requestor = requestors[msg.sender];
        return requestor.withdraw(payable(msg.sender));
    }

    /// @notice Checks if the request for randomness from the 3rd-party service has completed
    /// @dev For time-delayed requests, this function is used to check/confirm completion
    /// @param _requestId The ID of the request used to get the results of the RNG service
    /// @return isCompleted True if the request has completed and a random number is available, false otherwise
    function isRequestComplete(uint32 _requestId) onlyValidRequest(_requestId) external view returns (bool) {
        return witnetRandomness.isRandomized(requests[_requestId]);
    }

    /// @notice Checks if a given request has failed. If it has, `requestRandomNumber` can be triggered again.
    /// @param _requestId The ID of the request to check
    /// @return True if the Witnet request failed, false otherwise
    function isRequestFailed(uint32 _requestId) onlyValidRequest(_requestId) public view returns (bool) {
        (uint256 witnetQueryId,,) = witnetRandomness.getRandomizeData(requests[_requestId]);
        return witnetRandomness.witnet().getQueryResponseStatus(witnetQueryId) == WitnetV2.ResponseStatus.Error;
    }

    /// @notice Gets the random number produced by the 3rd-party service
    /// @param _requestId The ID of the request used to get the results of the RNG service
    /// @return randomNum The random number
    function randomNumber(uint32 _requestId) onlyValidRequest(_requestId) external view returns (uint256) {    
        return uint256(witnetRandomness.fetchRandomnessAfter(requests[_requestId]));
    }

    /// @notice Starts a draw using the random number from the Witnet Randomness Oracle
    /// @param rngPaymentAmount The amount of Ether to send to the Witnet Randomness Oracle
    /// @param _drawManager The DrawManager contract to call
    /// @param _rewardRecipient The address of the reward recipient
    /// @return The id of the draw
    function startDraw(uint256 rngPaymentAmount, DrawManager _drawManager, address _rewardRecipient) external payable returns (uint24) {
        (uint32 requestId,,) = requestRandomNumber(rngPaymentAmount);
        return _drawManager.startDraw(_rewardRecipient, requestId);
    }

    /// @notice Reverts if the request id is unknown
    /// @param _requestId The ID of the request to check
    modifier onlyValidRequest(uint32 _requestId) {
        if (requests[_requestId] == 0) {
            revert UnknownRequest(_requestId);
        }
        _;
    }
}
