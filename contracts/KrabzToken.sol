// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

// OPENZEPPLIN
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KrabzToken is ERC20 {
    constructor() ERC20("Krabz", "KRB") {}

    function mintKrabz(address _to, uint256 _amonut) public {
        _mint(_to, _amonut);
    }
}
