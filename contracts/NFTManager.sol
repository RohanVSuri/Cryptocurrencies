// SPDX-License-Identifier: GPL-3.0-or-later
//Rohan Suri - fqu6ha

pragma solidity ^0.8.21;

import "./INFTManager.sol";
import "./ERC721.sol";
import "./Strings.sol";
import "./Address.sol";
import "./Context.sol";

contract NFTManager is INFTManager, ERC721 {
    using Strings for uint256;

    mapping(uint256 => string) private tokenID;
    mapping(string => bool) private tokenIDExist;
    uint private tokenNumber;

    constructor() ERC721("RohanNFTManager", "RCNNFT"){
        tokenNumber = 0;
    }
    
    //dupilcate uri should cause revert
    function mintWithURI(address _to, string memory _uri) external returns (uint){
        require(!tokenIDExist[_uri], "URI Already Exists");

        _safeMint(_to, tokenNumber);
        tokenID[tokenNumber] = _uri;
        tokenIDExist[_uri] = true;

        tokenNumber += 1;
        return tokenNumber - 1;
    }
    
    function mintWithURI(string memory _uri) external returns (uint){
        return this.mintWithURI(msg.sender, _uri);
    }

    function _baseURI() internal pure override virtual returns (string memory) {
        return "https://andromeda.cs.virginia.edu/ccc/ipfs/files/";

    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, IERC721Metadata) returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();

        return string.concat(baseURI, tokenID[tokenId]);

    }
    function count() public view override returns(uint){
        return tokenNumber;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(INFTManager).interfaceId ||
               interfaceId == type(IERC721).interfaceId ||
               interfaceId == type(IERC165).interfaceId ||
               interfaceId == type(IERC721Metadata).interfaceId;
    }
    
    
}