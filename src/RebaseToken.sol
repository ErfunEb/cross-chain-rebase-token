// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Erfan Ebrahimi
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );

    uint256 constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");
    uint256 private interestRate = 5e10;
    mapping(address => uint256) private userInterestRate;
    mapping(address => uint256) private userLastUpdatedTimestamp;

    event InterestRateUpdated(uint256 indexed newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grandMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @param _newInterestRate The new interest rate to set
     * @notice Set the interest rate in the contract
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                interestRate,
                _newInterestRate
            );
        }
        interestRate = _newInterestRate;
        emit InterestRateUpdated(_newInterestRate);
    }

    /**
     * @notice Get the principle balance of a user. This is the number of tokens that have currently been minted to the user, not including any interest that has accrued since the last time the user interacted with the protocol.
     * @param _user The user to get the principle balance for
     * @return The principle balance of the user
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    /**
     * @notice Mint the use rtokens when they deposit into the vault
     * @param _to The user to mint the token to
     * @param _amount The amount of tokens to mint
     */
    function mint(
        address _to,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        userInterestRate[_to] = interestRate;
        _mint(_to, _amount);
    }

    /**
     * @param _user The user to get interest rate for
     * @notice The interest rate for user
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return userInterestRate[_user];
    }

    /**
     * @notice Get the interest rate that is currently set for the contract, any future depositors will recieve this interest rate
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256) {
        return interestRate;
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            userInterestRate[_recipient] = userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _sender The user that transfers the token
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            userInterestRate[_recipient] = userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user to calculate the interest accumulated for
     * @return The interest that has accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - userLastUpdatedTimestamp[_user];
        return PRECISION_FACTOR + (userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with protocol
     * @param _user The user to mint the accured interest to
     */
    function _mintAccuredInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }
}
