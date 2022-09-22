// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract Hypercert is ERC1155Burnable, ERC1155Pausable, ERC1155Supply, ERC1155URIStorage {
    string public constant name = "Love Hypercert";
    string public constant symbol = "LoveHype";

    constructor() ERC1155("") {}

    function uri(uint256 id) public view override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return ERC1155URIStorage.uri(id);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        ERC1155Pausable._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        ERC1155Supply._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
