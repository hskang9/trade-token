import "./oracle/OracleRegistry.sol";


pragma solidity ^0.8.0;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes("approve(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "AF");
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes("transfer(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TF");
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TFF");
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, "ETF");
    }
}


contract Trader is OracleRegistry {

    address tradeToken;
    address weth;
    bool oracleOn;
    uint256 rate; // amountFrom/amountTo rate in 8 decimal

    constructor() {
        _setupRole(ORACLE_OPERATOR_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function initialize(address tradeToken_, address tradeTo_, bool oracleOn_, address oracleFrom_, address oracleTo_) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "IA"); // Invalid Access
        tradeToken = tradeToken_;
        oracleOn = oracleOn_;
        PriceFeeds[tradeToken_] = oracleFrom_;
        PriceFeeds[tradeTo_] = oracleTo_;
    }

    function setRate(uint256 rate_) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "IA"); // Invalid Access
        rate=rate_;
    }

    function getAssetPrice(address asset_) public view returns (uint) {
        address aggregator = PriceFeeds[asset_];
        require(
            aggregator != address(0x0),
            "Trader: Asset not registered"
        );
        int256 result = IPrice(aggregator).getThePrice();
        return uint(result);
    }

    function trade2ETH(uint256 amountFrom, uint256 amountTo) public {
        // validate rate
        _validateRate(amountTo, amountFrom);
        // trade
        TransferHelper.safeTransferFrom(tradeToken, msg.sender, address(this), amountFrom);
        TransferHelper.safeTransferETH(msg.sender, amountTo);
    }

    function trade2Token(uint256 amountTo) public payable {
        // validate rate
        _validateRate(amountTo, msg.value);
        // trade
        TransferHelper.safeTransfer(tradeToken, msg.sender, amountTo);
    }

    function _validateRate(uint amountTo, uint amountFrom) internal view {
        // validate rate
        if(oracleOn) {
            uint priceFrom = getAssetPrice(tradeToken);
            uint priceTo = getAssetPrice(weth);
            require(amountTo*priceTo/1e8 - amountFrom*priceFrom/1e8 <= 1e8, "Trader: error rate over allowance");
        } else {
            require(amountFrom/rate*1e8 - amountTo <= 1e8, "Trader: error rate over allowance");
        }
    }

}