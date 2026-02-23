// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault__RedeemFailed();

    IRebaseToken private immutable REBASE_TOKEN;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        REBASE_TOKEN = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint rebase token in return
     */
    function deposit() external payable {
        uint256 interestRate = REBASE_TOKEN.getInterestRate();
        REBASE_TOKEN.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to deposit ETH into the vault and mint rebase token in return
     * @param _amount The amount of rebase tokens to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = REBASE_TOKEN.balanceOf(msg.sender);
        }
        REBASE_TOKEN.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Get the address of rebase token
     * @return address The address of rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(REBASE_TOKEN);
    }
}
