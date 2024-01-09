# Cryptocurrencies 4501 Projects

Hand-selected Contracts written for CS 4501, UVA's Cryptocurrencies course. 

## Contracts Included
There are 4 contracts that are included in this repository:
- `Auctioneer`: Manages auctions for NFTs. It allows the creation of auctions for NFTs generated using the NFTManager contract.
- `NFTManager`: A utility for managing and creating NFTs.
- `DEX`: Enables the exchange of ETH with the TokenCC cryptocurrency.
- `TokenCC`: A custom ERC20 Token


The **Auctioneer** contract depends on **NFTManager** for it's usage, while the **DEX** contract relies on **TokenCC** for exchanges; the two pairs act independently. 
