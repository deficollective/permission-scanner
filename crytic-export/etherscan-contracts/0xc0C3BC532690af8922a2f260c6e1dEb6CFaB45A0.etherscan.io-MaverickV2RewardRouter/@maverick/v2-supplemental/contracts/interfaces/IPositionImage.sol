// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;
import {IMaverickV2Position} from "./IMaverickV2Position.sol";

interface IPositionImage {
    error PositionImageSetPositionError(address sender, address deployer, IMaverickV2Position currentPosition);

    function position() external view returns (IMaverickV2Position _position);
    function setPosition(IMaverickV2Position _position) external;
    function image(uint256 tokenId, address tokenOwner) external view returns (string memory);
}
