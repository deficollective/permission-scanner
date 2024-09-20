pragma solidity ^0.8.13;

import {IPool} from "./interfaces/IPool.sol";
import {IPoolFactory} from "./interfaces/factories/IPoolFactory.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract VeloOracle {
    address public immutable factoryV1;
    address public immutable factoryV2;
    bytes32 public immutable initcodeHashV1;
    uint8 constant maxHop = 10;

    constructor(address _factoryV1, address _factoryV2, bytes32 _initcodeHashV1) {
        factoryV1 = _factoryV1;
        factoryV2 = _factoryV2;
        initcodeHashV1 = _initcodeHashV1;
    }

    struct BalanceInfo {
        uint256 bal0;
        uint256 bal1;
        bool isStable;
        bool isV1;
    }

    struct Path {
        uint8 to_i;
        uint256 rate;
    }

    struct ReturnVal {
        bool mod;
        bool isStable;
        bool isV1;
        uint256 bal0;
        uint256 bal1;
    }

    struct Arrays {
        uint256[] rates;
        Path[] paths;
        int[] decimals;
        uint8[] visited;
    }

    struct IterVars {
        uint256 cur_rate;
        uint256 rate;
        uint8 from_i;
        uint8 to_i;
        bool seen;
    }

    function _get_bal(IERC20 from, IERC20 to, uint256 in_bal0) internal view returns (ReturnVal memory out) {
        bool b0_v1;
        bool b2_v1;
        (uint256 b0, uint256 b1) = _getBalances(from, to, false, false);
        (uint256 temp0, uint256 temp1) = _getBalances(from, to, false, true);
        if (b0 < temp0) {
            (b0, b1) = (temp0, temp1);
            b0_v1 = true;
        }

        (uint256 b2, uint256 b3) = _getBalances(from, to, true, false);
        (temp0, temp1) = _getBalances(from, to, true, true);
        if (b2 < temp0) {
            (b2, b3) = (temp0, temp1);
            b2_v1 = true;
        }
        if (b0 > in_bal0 || b2 > in_bal0) {
            out.mod = true;
            if (b0 > b2) {
                (out.bal0, out.bal1, out.isStable, out.isV1) = (b0, b1, false, b0_v1);
            } else {
                (out.bal0, out.bal1, out.isStable, out.isV1) = (b2, b3, true, b2_v1);
            }
        }
    }

    function getManyRatesWithConnectors(
        uint8 src_len,
        IERC20Metadata[] memory connectors
    ) external view returns (uint256[] memory rates) {
        uint8 j_max = min(maxHop, uint8(connectors.length - src_len));
        Arrays memory arr;
        arr.rates = new uint256[](src_len);
        arr.paths = new Path[]((connectors.length - src_len));
        arr.decimals = new int[](connectors.length);

        // Caching decimals of all connector tokens
        {
            for (uint8 i = 0; i < connectors.length; i++) {
                arr.decimals[i] = int(uint(connectors[i].decimals()));
            }
        }

        // Iterating through srcTokens
        for (uint8 src = 0; src < src_len; src++) {
            IterVars memory vars;
            vars.cur_rate = 1;
            vars.from_i = src;
            arr.visited = new uint8[](connectors.length - src_len);
            // Counting hops
            for (uint8 j = 0; j < j_max; j++) {
                BalanceInfo memory balInfo = BalanceInfo(0, 0, false, false);
                vars.to_i = 0;
                // Going through all connectors
                for (uint8 i = src_len; i < connectors.length; i++) {
                    // Check if the current connector has been used to prevent cycles
                    vars.seen = false;
                    {
                        for (uint8 c = 0; c < j; c++) {
                            if (arr.visited[c] == i) {
                                vars.seen = true;
                                break;
                            }
                        }
                    }
                    if (vars.seen) {
                        continue;
                    }
                    ReturnVal memory out = _get_bal(connectors[vars.from_i], connectors[i], balInfo.bal0);
                    if (out.mod) {
                        balInfo.isStable = out.isStable;
                        balInfo.bal0 = out.bal0;
                        balInfo.bal1 = out.bal1;
                        balInfo.isV1 = out.isV1;
                        vars.to_i = i;
                    }
                }

                if (vars.to_i == 0) {
                    arr.rates[src] = 0;
                    break;
                }

                if (balInfo.isStable) {
                    vars.rate = _stableRate(
                        connectors[vars.from_i],
                        connectors[vars.to_i],
                        arr.decimals[vars.from_i] - arr.decimals[vars.to_i],
                        balInfo.isV1
                    );
                } else {
                    vars.rate = _volatileRate(
                        balInfo.bal0,
                        balInfo.bal1,
                        arr.decimals[vars.from_i] - arr.decimals[vars.to_i]
                    );
                }

                vars.cur_rate *= vars.rate;
                if (j > 0) {
                    vars.cur_rate /= 1e18;
                }

                // If from_i points to a connector, cache swap rate for connectors[from_i] : connectors[to_i]
                if (vars.from_i >= src_len) {
                    arr.paths[vars.from_i - src_len] = Path(vars.to_i, vars.rate);
                }
                // If from_i points to a srcToken, check if to_i is a connector which has already been expanded.
                // If so, directly follow the cached path to dstToken to get the final rate.
                else {
                    if (arr.paths[vars.to_i - src_len].rate > 0) {
                        while (true) {
                            vars.cur_rate = (vars.cur_rate * arr.paths[vars.to_i - src_len].rate) / 1e18;
                            vars.to_i = arr.paths[vars.to_i - src_len].to_i;
                            if (vars.to_i == connectors.length - 1) {
                                arr.rates[src] = vars.cur_rate;
                                break;
                            }
                        }
                    }
                }
                arr.visited[j] = vars.to_i;

                // Next token is dstToken, stop
                if (vars.to_i == connectors.length - 1) {
                    arr.rates[src] = vars.cur_rate;
                    break;
                }
                vars.from_i = vars.to_i;
            }
        }
        return arr.rates;
    }

    function _volatileRate(uint256 b0, uint256 b1, int dec_diff) internal pure returns (uint256 rate) {
        // b0 has less 0s
        if (dec_diff < 0) {
            rate = (1e18 * b1) / (b0 * 10 ** (uint(-dec_diff)));
        }
        // b0 has more 0s
        else {
            rate = (1e18 * 10 ** (uint(dec_diff)) * b1) / b0;
        }
    }

    function _stableRate(IERC20Metadata t0, IERC20 t1, int dec_diff, bool isV1) internal view returns (uint256 rate) {
        uint256 t0_dec = t0.decimals();
        address currentPair = _orderedPairFor(t0, t1, true, isV1);
        // newOut in t1
        uint256 newOut = IPool(currentPair).getAmountOut((10 ** t0_dec), address(t0));

        // t0 has less 0s
        if (dec_diff < 0) {
            rate = (1e18 * newOut) / (10 ** t0_dec * 10 ** (uint(-dec_diff)));
        }
        // t0 has more 0s
        else {
            rate = (1e18 * (newOut * 10 ** (uint(dec_diff)))) / (10 ** t0_dec);
        }
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function _pairFor(IERC20 tokenA, IERC20 tokenB, bool stable, bool v1) private view returns (address pair) {
        if (v1) {
            pair = address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                hex"ff",
                                factoryV1,
                                keccak256(abi.encodePacked(tokenA, tokenB, stable)),
                                initcodeHashV1
                            )
                        )
                    )
                )
            );
        } else {
            bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB, stable));
            pair = Clones.predictDeterministicAddress(IPoolFactory(factoryV2).implementation(), salt, factoryV2);
        }
    }

    // returns the reserves of a pool if it exists, preserving the order of srcToken and dstToken
    function _getBalances(
        IERC20 srcToken,
        IERC20 dstToken,
        bool stable,
        bool v1
    ) internal view returns (uint256 srcBalance, uint256 dstBalance) {
        (IERC20 token0, IERC20 token1) = srcToken < dstToken ? (srcToken, dstToken) : (dstToken, srcToken);
        address pairAddress = _pairFor(token0, token1, stable, v1);

        // if the pair doesn't exist, return 0
        if (!Address.isContract(pairAddress)) {
            srcBalance = 0;
            dstBalance = 0;
        } else {
            (uint256 reserve0, uint256 reserve1, ) = IPool(pairAddress).getReserves();
            (srcBalance, dstBalance) = srcToken == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
        }
    }

    // fetch pair from tokens using correct order
    function _orderedPairFor(
        IERC20 tokenA,
        IERC20 tokenB,
        bool stable,
        bool isV1
    ) internal view returns (address pairAddress) {
        (IERC20 token0, IERC20 token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pairAddress = _pairFor(token0, token1, stable, isV1);
    }

    function min(uint8 a, uint8 b) internal pure returns (uint8) {
        return a < b ? a : b;
    }
}
