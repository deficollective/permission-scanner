// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Math} from "@maverick/v2-common/contracts/libraries/Math.sol";

import {IMaverickV2VotingEscrowFactory} from "./interfaces/IMaverickV2VotingEscrowFactory.sol";
import {IMaverickV2VotingEscrow} from "./interfaces/IMaverickV2VotingEscrow.sol";

import {VotingEscrowDeployer} from "./libraries/VotingEscrowDeployer.sol";
import {ILegacyVeMav} from "./votingescrowbase/ILegacyVeMav.sol";
import {VotingEscrowWSyncDeployer} from "./libraries/VotingEscrowWSyncDeployer.sol";

/**
 * @notice Factory to deploy veTokens.  The resulting ve contracts are deployed
 * using create2 and have deterministic addresses.
 */
contract MaverickV2VotingEscrowFactory is IMaverickV2VotingEscrowFactory {
    /// @inheritdoc IMaverickV2VotingEscrowFactory
    IERC20 public baseTokenParameter;
    /// @inheritdoc IMaverickV2VotingEscrowFactory
    mapping(IMaverickV2VotingEscrow => bool) public isFactoryToken;
    /// @inheritdoc IMaverickV2VotingEscrowFactory
    mapping(IERC20 => IMaverickV2VotingEscrow) public veForBaseToken;
    /// @inheritdoc IMaverickV2VotingEscrowFactory
    IERC20 public immutable legacyVeMav;

    IMaverickV2VotingEscrow[] private _allVotingEscrow;

    constructor(IERC20 legacyVeMav_) {
        legacyVeMav = legacyVeMav_;
    }

    /**
     *
     * @notice Create a ve token for an input base token.
     *
     */
    /// @inheritdoc IMaverickV2VotingEscrowFactory
    function createVotingEscrow(IERC20 baseToken) public returns (IMaverickV2VotingEscrow veToken) {
        if (veForBaseToken[baseToken] != IMaverickV2VotingEscrow(address(0)))
            revert VotingEscrowTokenAlreadyExists(baseToken, veForBaseToken[baseToken]);
        baseTokenParameter = baseToken;

        (string memory name, string memory symbol) = _nameSymbolGetter(baseToken);
        // deploy veToken
        if (address(legacyVeMav) != address(0) && baseToken == ILegacyVeMav(address(legacyVeMav)).mav()) {
            veToken = VotingEscrowWSyncDeployer.deploy(baseToken, name, symbol);
        } else {
            veToken = VotingEscrowDeployer.deploy(baseToken, name, symbol);
        }
        delete baseTokenParameter;
        _allVotingEscrow.push(veToken);
        veForBaseToken[baseToken] = veToken;
        isFactoryToken[veToken] = true;

        emit CreateVotingEscrow(baseToken, veToken);
    }

    /// @inheritdoc IMaverickV2VotingEscrowFactory
    function votingEscrows(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (IMaverickV2VotingEscrow[] memory returnElements) {
        endIndex = Math.min(_allVotingEscrow.length, endIndex);
        returnElements = new IMaverickV2VotingEscrow[](endIndex - startIndex);
        unchecked {
            for (uint256 i = startIndex; i < endIndex; i++) {
                returnElements[i - startIndex] = _allVotingEscrow[i];
            }
        }
    }

    /// @inheritdoc IMaverickV2VotingEscrowFactory
    function votingEscrowsCount() external view returns (uint256 count) {
        return _allVotingEscrow.length;
    }

    function _nameSymbolGetter(IERC20 baseToken) internal view returns (string memory name, string memory symbol) {
        symbol = string.concat("ve", IERC20Metadata(address(baseToken)).symbol());
        name = symbol;
    }
}
