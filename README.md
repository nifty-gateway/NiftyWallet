## Synopsis

This is the source code for the Nifty Wallet, a smart contract wallet that makes accessing dapps and web3 applications radically easier.

Below are some notes on design choices that were made, further detail on how the wallet is secured and general information about the wallet.

## Architecture

There are three contracts that interact to form the Nifty Wallet - deployed instances of the Nifty Wallet contract, a master contract, and a static calls contract.

The master contract stores the critical information, such as which keys are permitted to send transactions, and which key is supposed to have signed a transaction. A deployed Nifty Wallet instance checks with the master contract when it is evaluating whether or not it should execute a specific transaction. The master contract is secured with a multi sig architecture based on the Gnosis Multi Sig contract - any changes to the master contract can only be made by a multi sig transaction confirmed by 3 owners.

We cannot anticipate all future static calls that the Nifty Wallet will have to make. So the Nifty Wallet redirects static calls to another contract. This is implemented using the fallback function of the main Nifty Wallet contract, NiftyWallet.sol.

This architecture has two purposes - it reduces the deployment cost of deploying a Nifty Wallet instance, and it measn that we can add support for additional static calls in the future as the need arises. 

The master contract stores a reference to the location of the static call contract. This reference can be changed with a multi sig transaction.

Here is a visualization of how the Nifty Wallet setup works:

![Nifty Wallet Visual](https://s3-us-west-1.amazonaws.com/nftgimagebucket/Screen+Shot+2019-04-20+at+3.30.53+PM.png
 "Nifty Wallet Visual")
 
## Security

Secure system design should be the #1 priority for any project that helps users manage crypto assets of any kind, and was our #1 priority building the Nifty Wallet.

Our design is not yet finalized! If you notice a vulnerability, please let us know immediately! (You can email duncan@niftygateway.com or leave a comment). We really appreciate it!

Each Nifty Wallet is secured by two separate private keys, both of which are stored on a [HSM](https://en.wikipedia.org/wiki/Hardware_security_module). So a Nifty Wallet can be thought of as a kinda of multisig, but one that executes transactions instantly.

This mechanism is implemented by assigning each wallet a specific signing key, which signs information for that wallet, and only permitting transactions that come approved sending keys which are controlled by Nifty Gateway.

Signing keys and sending keys are both stored in a master contract so that they can be changed or disabled in an emergency scenario if an HSM is somehow compromised. As stated previously, the master contract is a multisig.

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

## Static Calls

We want to be able to upgrade the static calls that each deployed Nifty Wallet instance can support. To accomplish this, the Nifty Wallet uses the fallback function to redirect an unknown call to our static calls contract, which can be found in NiftyStaticCalls.sol.

The main limitation of smart contract wallets is that they cannot sign messages. The Nifty Wallet implements two functions that allow another smart contract to detect in a signature submitted is valid for a specific instance of a Nifty Wallet - isValidSignature(bytes32,bytes), which returns a bool, and isValidSiganture(bytes,bytes), which returns a bytes4 value and aligns with [EIP1271](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1271.md).

If a message or piece of data has been signed by the signing wallet for a specific instance of the Nifty Wallet, then isValidSignature will return a true for the (bytes32,bytes) version or the EIP1271 magic value 0x20c13b0b for the (bytes,bytes) version.

Because there are only 5 signing keys, and potentially millions of deployed instances of NiftyWallet.sol, we need to make sure that a signature from one deployed instance of a Nifty Wallet cannot be used for another deployed instance of a Nifty Wallet. To ensure a signature is globally unique, the data to be signed is concatenated with the address of the deployed instance of the Nifty Wallet before the recover function is executed. 

This ensures that a signature used for one deployed Nifty Wallet with ID of 0 cannot also be used for another deployed Nifty Wallet with id of 0. You can see this implemented in NiftyStaticCalls.sol.

There are two separate versions of this function to accomodate both EIP1271 and existing smart contracts (like 0x's) that use the (bytes32,bytes) version and return a bool.

The Nifty Wallet also has a safe ERC721 receiver and a safe ERC1155 receiver, meaning that it can receive ERC721 and ERC1155 tokens sent with the safeTransferFrom or safeTransferBatchFrom methods.

The Nifty Wallet will always return the received signature, and will always receive any ERC721 or ERC1155 token it is sent.

## Testing the wallet

This respository cannot be cloned by itself and tested. It is intended to describe and show the Nifty Wallet works.

We have deployed a test setup on the Rinkeby network. You can see the master contract [here](https://rinkeby.etherscan.io/address/0x0ec7a8e03e3c3cac031257d479c59356cc419a38#code), the static calls contract [here](https://rinkeby.etherscan.io/address/0x0a6f11803bc89e3280e24d720ec0813e4c3cfdbe#code), and a deployed instance of a Nifty Wallet [here](https://rinkeby.etherscan.io/address/0xb34fe0c56ec6e500377fcaa89125cef31a40b4b7#code).

We included another smart contract, appropriately named TestContractCalls, which will allow you to test static calls made to the Nifty Wallet. It is also included in this repository and named TestContractCalls.sol.

We deployed an instance of TestContractCalls which points to our example deployed Nifty Wallet. It can be found [here](https://rinkeby.etherscan.io/address/0xa76b3e42a071bff3598a8d47b4cfde05f6bf423e#readContract). You can test out some static calls that the Nifty Wallet currently supports.

## Auditing & Commenting

A preliminary audit has been completed for the Nifty Wallet. We are completing another one prior to the wallet going live.

Please give us your thoughts on the Nifty Wallet! If you notice something wrong, or have suggestions, send an email to duncan@niftygateway.com 
