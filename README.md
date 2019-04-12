## Synopsis

This is the source code for the Nifty Wallet, a smart contract wallet that makes accessing dapps and web3 applications radically easier.

Below are some notes on design choices that were made, further detail on how the wallet is secured and general information about the wallet.

## Security

Secure system design should be the #1 priority for any project that helps users manage crypto assets of any kind, and that is certainly the case for the Nifty Wallet.

Each Nifty Wallet is secured by two separate private keys, both of which are stored on [HSMs](https://en.wikipedia.org/wiki/Hardware_security_module).

This implemented by assigning each wallet a specific signing key, which signs information for that wallet, and making sure all transactions come from a sending key, which are keys we control and have approved to send transactions.

Signing keys and sending keys are both stored in a Master Contract so that they can be changed in an emergency scenario if an HSM is somehow compromised. The key that has control over the master wallet is stored in a completely cold environment. 

Each instance of the Nifty Wallet has a ID from 0 - 4 denoting which signing key is authorized to sign transactions for it.

For example, on line 12 of NiftyWallet.sol, you will see that this wallet is defined as a wallet with ID 0:
```
uint userAccountID = 0;
```

That means that the signing key for this wallet is the wallet that the Master Contract has at index 0.

## Transaction Execution

All transactions are executed via the callTx function, located on line 125 of NiftyWallet.sol.

For a Nifty Wallet to execute a transaction that it has been sent, the transaction must be signed by a wallets signing key. More precisely, a concatenation of the transaction data, the Nifty Wallet instances address, the transaction value, destination address and Nifty wallet instances internal transaction count must be signed, to make each signature globally unique. Each signature is one specific instance of the Nifty Wallet executing one specific transaction). 

The internal transaction count is basically equivalent to the nonce of an Ethereum account, and is implemented for the same reason, to prevent replay attacks. 

The Nifty Wallet also checks that the transaction it received was sent by an approved sending account. The master contract holds the list of approved sending accounts, and all sending accounts are also stored on HSMs.

After an transaction has been executed, an Execution() event is emitted with the transactions destination, value and data. If the execution failed, an ExecutionFailure() event is emitted with the same fields.

You can build systems to track transaction executions if you like, but we provide many tools that make it extremely easy to see how a transaction is progressing and provide detailed user feedback in our NiftyGatewayJS package, we recommend you simply use those.

The transaction execution function borrows heavily from [Gnosis Multi Sig Wallet](https://github.com/gnosis/MultiSigWallet/blob/master/contracts/MultiSigWallet.sol). To reduce potential security vulnerabilites, we avoided rolling our own smart contract functions whenver possible.


