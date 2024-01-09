// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.21;

import "./IAuctioneer.sol";
import "./NFTManager.sol";
import "./IERC721Receiver.sol";

contract Auctioneer is IAuctioneer, IERC721Receiver{

    // struct Auction {
    //     uint id;            // the auction id
    //     uint num_bids;      // how many bids have been placed
    //     string data;        // a text description of the auction or NFT data
    //     uint highestBid;    // the current highest bid, in wei
    //     address winner;     // the current highest bidder
    //     address initiator;  // who started the auction
    //     uint nftid;         // the NFT token ID
    //     uint endTime;       // when the auction ends
    //     bool active;        // if the auction is active
    // }

    uint public num_auctions; //number of auctions
    
    uint public totalAuctionAmount; //lifetime amount of how much eth put in auction

    uint public totalFees;

    uint public currentFees; //current fees to be sent 
    
    mapping(uint => Auction) public auctions; //mapping of all auctions from id

    mapping(uint => bool) public auctionExist;
    
    address public deployer; //deployer of this contract


    NFTManager public nft_manager;

    constructor() {
        nft_manager = new NFTManager();
        deployer = msg.sender;
        num_auctions = 0;

    }
    function nftmanager() external view returns (address) {
        return address(nft_manager);
    }

    // function num_auctions() external view returns (uint){

    // }

    // function totalFees() external view returns (uint) {
    //     return totalAuctionAmount / 100;
    // }

    function uncollectedFees() external view returns (uint){
        return currentFees;
    }

    // function auctions(uint id) external view returns (uint, uint, string memory, uint, address, address, uint, uint, bool){

    // }

    // function deployer() external view returns (address) {

    // }

    function collectFees() external{
        (bool success, ) = payable(deployer).call{value: currentFees}("");
        require(success, "Failed to transfer ETH");
        currentFees = 0;
    }

    function startAuction(uint m, uint h, uint d, string memory data,
                          uint reserve, uint nftid) external returns (uint){
        //require that the nft owner is the one starting the auction
        require(msg.sender == nft_manager.ownerOf(nftid));
        require(m != 0 || h != 0 || d != 0, "auction must have duration");
        require(bytes(data).length > 0, "data must exist");
        require(auctionExist[nftid] == false, "auction already exists with this nft");

        nft_manager.safeTransferFrom(msg.sender, address(this), nftid);

        uint newtime = block.timestamp + m * 1 minutes + h * 1 hours + d * 1 days;

        Auction memory currentAuction = Auction(num_auctions, 0, data, reserve, msg.sender, msg.sender, nftid, newtime, true);
        auctions[num_auctions] = currentAuction;
        num_auctions += 1;
        auctionExist[nftid] = true;
        emit auctionStartEvent(num_auctions-1);

        return num_auctions - 1;

    }

    function closeAuction(uint id) external {
        Auction memory current_auction = auctions[id];
        require(block.timestamp >= current_auction.endTime, "auction is not over yet");
        require(current_auction.active, "auction not active");

        if(current_auction.num_bids > 0){
            
            uint toSendBack = (current_auction.highestBid / 100) * 99;
            currentFees += current_auction.highestBid / 100;
            totalFees += currentFees;
            // totalAuctionAmount += current_auction.highestBid;
    
            (bool success, ) = payable(current_auction.initiator).call{value: toSendBack}("");
            require(success, "Failed to transfer ETH");
            nft_manager.safeTransferFrom(address(this), current_auction.winner, current_auction.nftid);
            
        }else{
            // (bool success, ) = payable(current_auction.winner).call{value: current_auction.highestBid}("");
            // require(success, "Failed to transfer ETH");
            nft_manager.safeTransferFrom(address(this), current_auction.winner, current_auction.nftid);
        }
        auctions[id].active = false;
        auctionExist[current_auction.nftid] = false;

        emit auctionCloseEvent(id);
    }

    function placeBid(uint id) payable external {
        Auction memory current_auction = auctions[id];
        require(current_auction.active, "auction not active");
        require(msg.value >= current_auction.highestBid, "your bid is lower than the current highest bid");
        require(block.timestamp < current_auction.endTime, "auction is over");
        
        if(current_auction.num_bids > 0 ){
            (bool success, ) = payable(current_auction.winner).call{value: current_auction.highestBid}("");
            require(success, "Failed to transfer ETH");
        }
        
        //if bid is valid:
        auctions[id].highestBid = msg.value;
        auctions[id].num_bids += 1;
        auctions[id].winner = msg.sender;
        emit higherBidEvent(id);
    
    }


    function auctionTimeLeft(uint id) external view returns (uint) {
        if (auctions[id].active && block.timestamp < auctions[id].endTime){
            return auctions[id].endTime - block.timestamp;
        } else {
            return 0;
        }
        
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool){
        return interfaceId == type(IAuctioneer).interfaceId ||
               interfaceId == type(IERC721Receiver).interfaceId ||
               interfaceId == type(IERC165).interfaceId;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external pure returns (bytes4){
        return IERC721Receiver.onERC721Received.selector;
    }


}