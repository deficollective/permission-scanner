// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMaverickV2VotingEscrow} from "../interfaces/IMaverickV2VotingEscrow.sol";
import {MaverickV2VotingEscrow} from "../MaverickV2VotingEscrow.sol";

library VotingEscrowDeployer {
    function deploy(
        IERC20 baseToken,
        string memory name,
        string memory symbol
    ) external returns (IMaverickV2VotingEscrow votingEscrow) {
        votingEscrow = IMaverickV2VotingEscrow(
            address(new MaverickV2VotingEscrow{salt: keccak256(abi.encode(baseToken))}(name, symbol))
        );
    }
}
