![Nifty Gateway Logo](https://s3-us-west-1.amazonaws.com/nftgimagebucket/FaviconNFTG.png "Nifty Gateway Logo")

## Synopsis

This is the source code for the Nifty Wallet, a smart contract wallet that makes accessing dapps and web3 applications radically easier.

Below are some notes on design choices that were made, further detail on how the wallet is secured and general information about the wallet.

## Security

Secure system design is the #1 priority for any project that helps users manage crypto assets of any kind.

Each Nifty Wallet is secured by two separate private keys, both of which are stored on HSMs(https://en.wikipedia.org/wiki/Hardware_security_module).

Each instance of the Nifty Wallet has a signing key specific to that wallet. Signing keys are stored in a Master Contract, and can be changed in the event of one being compromised. Each instance of the Nifty Wallet has a ID from 0 - 4 denoting which signing key is authorized to sign transactions for it.

For example, on line 12 of NiftyWallet.sol, you will see that this wallet is defined as a wallet with ID 0:
```
uint userAccountID = 0;
```

That means that the signing key for this wallet is the wallet that the Master Contract has at index 0.

For a Nifty Wallet to execute a transaction that it has been sent, the transaction data must be signed by a wallets specific signing key. Specifically, a concatenation of the transaction data + the Nifty Wallets address must be signed, to make each signature globally unique (each signature is one specific wallet executing specific transaction data).

The transaction also must be sent by an approved sending wallet. The master contract also holds the list of approved sending wallets, and all sending wallets are also stored on HSMs.
