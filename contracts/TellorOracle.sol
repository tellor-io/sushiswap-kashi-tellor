// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./libraries/BoringMath.sol";
import "./interfaces/IOracle.sol";

// Tellor Oracle
interface ITellor {
    function getDataBefore(bytes32 _queryId, uint256 _timestamp)
        external
        view
        returns (
            bool _ifRetrieve,
            bytes memory _value,
            uint256 _timestampRetrieved
        );
}

contract TellorOracle is IOracle {
    using BoringMath for uint256; // Keep everything in uint256
    ITellor public tellor;

    constructor(address tellorAddress) public {
        tellor = ITellor(tellorAddress);
    }

    // Calculates the lastest exchange rate
    // Uses both divide and multiply only for tokens not supported directly by Chainlink, for example MKR/USD
    function _get(
        bytes32 multiply,
        bytes32 divide,
        uint256 decimals
    ) internal view returns (uint256) {
        uint256 price = uint256(1e36);
        bytes memory valueBytes;
        uint256 value;
        if (multiply != bytes32(0)) {
            (, valueBytes, ) = tellor.getDataBefore(
                multiply,
                block.timestamp - 15 minutes
            );
            value = abi.decode(valueBytes, (uint256));
            price = price.mul(value);
        } else {
            price = price.mul(1e18);
        }

        if (divide != bytes32(0)) {
            (, valueBytes, ) = tellor.getDataBefore(
                divide,
                block.timestamp - 15 minutes
            );
            value = abi.decode(valueBytes, (uint256));
            price = price / value;
        }

        return price / decimals;
    }

    function getDataParameter(
        bytes32 multiply,
        bytes32 divide,
        uint256 decimals
    ) public pure returns (bytes memory) {
        return abi.encode(multiply, divide, decimals);
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata data) public override returns (bool, uint256) {
        (bytes32 multiply, bytes32 divide, uint256 decimals) = abi.decode(data, (bytes32, bytes32, uint256));
        return (true, _get(multiply, divide, decimals));
    } 

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata data) public view override returns (bool, uint256) {
        (bytes32 multiply, bytes32 divide, uint256 decimals) = abi.decode(data, (bytes32, bytes32, uint256));
        return (true, _get(multiply, divide, decimals));
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view override returns (string memory) {
        return "Tellor";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return "TRB";
    }
}
