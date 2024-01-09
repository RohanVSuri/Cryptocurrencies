// SPDX-License-Identifier: GPL-3.0-or-later
//Rohan Suri - fqu6ha

pragma solidity ^0.8.21;

import "./ITokenCC.sol";
import "./ERC20.sol";
import "./IERC20Receiver.sol";

contract TokenCC is ITokenCC, ERC20 {

    constructor() ERC20("RohanCoin", "RCN"){
        _mint(msg.sender, 100000 * 10**10);
    }

    function requestFunds() external pure {
        revert();
    }

    function decimals() public view virtual override (IERC20Metadata, ERC20) returns (uint8){
        return 10;
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
    if ( to.code.length > 0  && from != address(0) && to != address(0) ) {
        // token recipient is a contract, notify them
        try IERC20Receiver(to).onERC20Received(from, amount, address(this)) returns (bool success) {
            require(success,"ERC-20 receipt rejected by destination of transfer");
        } catch {
            // the notification failed (maybe they don't implement the `IERC20Receiver` interface?)
            // we choose to ignore this case
        }
    }
}

    function supportsInterface(bytes4 interfaceId) external pure returns (bool){
        return interfaceId == type(ITokenCC).interfaceId ||
               interfaceId == type(IERC20).interfaceId ||
               interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IERC20Metadata).interfaceId;
    }

    

}