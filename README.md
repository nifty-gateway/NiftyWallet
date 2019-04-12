## Synopsis

This is the source code for the Nifty Wallet, a smart contract wallet that makes accessing dapps and web3 applications radically easier.

Below are some notes on design choices that were made, further detail on how the wallet is secured and general information about the wallet.

## Security

Secure system design should be the #1 priority for any project that helps users manage crypto assets of any kind, and that is certainly the case for the Nifty Wallet.

Each Nifty Wallet is secured by two separate private keys, both of which are stored on [HSMs](https://en.wikipedia.org/wiki/Hardware_security_module).

This is implemented by assigning each wallet a specific signing key, which signs information for that wallet, and only permitting transactions that come approved sending keys which are controlled by Nifty Gateway.

Signing keys and sending keys are both stored in a master contract so that they can be changed or disabled in an emergency scenario if an HSM is somehow compromised. The key that has control over the master contract is stored in a completely cold environment. 

Each instance of the Nifty Wallet has a ID from 0 - 4 denoting which signing key is authorized to sign transactions for it.

For example, in NiftyWallet.sol, you can see that this wallet is defined as a wallet with ID 0:
```
uint userAccountID = 0;
```

That means that the signing key for this wallet is the wallet that the master contract has at index 0.

## Transaction Execution

All transactions are executed via the callTx function in NiftyWallet.sol.

For a Nifty Wallet to execute a transaction that it has been sent, the transaction must be signed by a wallets signing key. More precisely, a concatenation of the transaction data, the Nifty Wallet instances address, the transaction value, destination address and Nifty wallet instances internal transaction count must be signed, to make each signature globally unique. Each signature is one specific instance of the Nifty Wallet executing one specific transaction. 

The internal transaction count is basically equivalent to the nonce of an Ethereum account, and is implemented for the same reason, to prevent replay attacks. 

The Nifty Wallet also checks that the transaction it received was sent by an approved sending account. The master contract holds the list of approved sending accounts, and all sending accounts are also stored on HSMs.

After an transaction has been executed, an Execution() event is emitted with the transactions destination, value and data. If the execution failed, an ExecutionFailure() event is emitted with the same fields.

You can build systems to track transaction executions if you like, but we provide many tools that make it extremely easy to see how a transaction is progressing and provide detailed user feedback in our NiftyGatewayJS package, we recommend you simply use those.

The transaction execution function borrows heavily from [Gnosis Multi Sig Wallet](https://github.com/gnosis/MultiSigWallet/blob/master/contracts/MultiSigWallet.sol). To reduce potential security vulnerabilites, we avoided rolling our own smart contract functions whenver possible.

## Signature functions

The main limitation of smart contract wallets is that they cannot sign messages. The Nifty Wallet implements two functions that allow another smart contract to detect in a signature submitted is valid for a specific instance of a Nifty Wallet - isValidSignature(bytes32,bytes), which returns a bool, and isValidSiganture(bytes,bytes), which returns a bytes4 value and aligns with [EIP1271](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1271.md).

If a message or piece of data has been signed by the signing wallet for a specific instance of the Nifty Wallet, then isValidSignature will return a true for the (bytes32,bytes) version or the EIP1271 magic value 0x20c13b0b for the (bytes,bytes) version.

There are two separate versions of this function to accomodate both EIP1271 and existing smart contracts (like 0x's) that use the (bytes32,bytes) version and return a bool.

## Receivers

The Nifty Wallet also has a safe ERC721 receiver and a safe ERC1155 receiver, meaning that it can receive ERC721 and ERC1155 tokens sent with the safeTransferFrom or safeTransferBatchFrom methods.

The Nifty Wallet will always return the received signature, and will always receive any ERC721 or ERC1155 token it is sent.


