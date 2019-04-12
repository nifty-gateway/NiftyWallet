pragma solidity ^0.5.4;

contract NiftyWallet {

    /**
     * Constants
     * The address of the master contract, and the account ID for this wallet
     * Account ID is used to retrieve the signing private key for this wallet
     */

    address masterContractAdd = 0x154cECb44DC63bdd2fE3f77Eb230b1f2B0c02122;
    uint userAccountID = 0;
    uint walletTxCount = 0;

    /**
    / Events
    */

    event Execution(address indexed destinationAddress, uint value, bytes txData);
    event ExecutionFailure(address indexed destinationAddress, uint value, bytes txData);
    event Deposit(address indexed sender, uint value);

    /**
    * @dev returns signing private key that controls this wallet
    */

    function returnUserAccountAddress() public view returns(address) {
        MasterContract m_c_instance = MasterContract(masterContractAdd);
        return (m_c_instance.returnUserControlAddress(userAccountID));
    }

    function returnWalletTxCount() public view returns(uint) {
        return(walletTxCount);
    }

    /**
     * Modifier to check msg.sender
     */

    modifier onlyValidSender() {
        MasterContract m_c_instance = MasterContract(masterContractAdd);
        require(m_c_instance.returnIsValidSendingKey(msg.sender) == true);
        _;
      }

    /**
     * @dev struct to combine contract address with transaction data
     */

    struct mStruct {
        address this_add;
        address des_add;
        uint value;
        uint interalTxCount;
        bytes txData;
    }

    /**
     * @dev internal function to recreate message that has been signed off chain
     * @dev the message is a concatenation of this contracts address and transaction data
     * @dev contract address is included to make sure a transaction signature from one smart contract wallet cannot be reused by another
     * @param txData bytes - txData to hash alongside address
     */

    function returnTxMessageToSign(bytes memory txData,
                                address des_add,
                                uint value) private view returns(bytes32) {
        mStruct memory message = mStruct(address(this), des_add, value, walletTxCount, txData);
        return keccak256(abi.encode(message.this_add, message.txData));
    }


   /**
   * Recovery function for signature - taken from OpenZeppelin
   * https://github.com/OpenZeppelin/openzeppelin-solidity/blob/9e1da49f235476290d5433dac6807500e18c7251/contracts/ECRecovery.sol
   * @dev Recover signer address from a message by using their signature
   * @param hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
   * @param sig bytes signature, the signature is generated using web3.eth.sign()
   */
  function recover(bytes32 hash, bytes memory sig) internal pure returns (address) {
    bytes32 r;
    bytes32 s;
    uint8 v;

    //Check the signature length
    if (sig.length != 65) {
      return (address(0));
    }

    // Divide the signature in r, s and v variables
    // ecrecover takes the signature parameters, and the only way to get them
    // currently is to use assembly.
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      r := mload(add(sig, 32))
      s := mload(add(sig, 64))
      v := byte(0, mload(add(sig, 96)))
    }

    // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
    if (v < 27) {
      v += 27;
    }

    // If the version is correct return the signer address
    if (v != 27 && v != 28) {
      return (address(0));
    } else {
      return ecrecover(hash, v, r, s);
    }
  }

    /**
     * Default payable function
     */

    function()
        payable
        external
    {
        if (msg.value > 0)
            emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev function to call any on chain transaction
     * @dev verifies that the transaction data has been signed by the wallets controlling private key
     * @dev and that the transaction has been sent from an approved sending wallet
     * @param  _signedData bytes - signature of txData + wallet address
     * @param destination address - destination for this transaction
     * @param value uint - value of this transaction
     * @param data bytes - transaction data
     */

    function callTx(bytes memory _signedData,
                     address destination,
                     uint value,
                     bytes memory data)
    public onlyValidSender returns (bool) {
        address userSigningAddress = returnUserAccountAddress();
        bytes32 dataHash = returnTxMessageToSign(data, destination, value);
        address recoveredAddress = recover(dataHash, _signedData);
        if (recoveredAddress==userSigningAddress) {
            if (external_call(destination, value, data.length, data)) {
                emit Execution(destination, value, data);
                walletTxCount = walletTxCount + 1;
            } else {
                emit ExecutionFailure(destination, value, data);
                walletTxCount = walletTxCount +1;
            }
            return(true);
        } else {
            return(false);
        }
    }

    /** External call function
     * Taken from Gnosis Mutli Sig wallet
     * https://github.com/gnosis/MultiSigWallet/blob/master/contracts/MultiSigWallet.sol
     */

    // call has been separated into its own function in order to take advantage
    // of the Solidity's code generator to produce a loop that copies tx.data into memory.
    function external_call(address destination, uint value, uint dataLength, bytes memory data) private returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
                sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
                                   // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                   // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
                destination,
                value,
                d,
                dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
                x,
                0                  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }


    /** Functions to validate signatures so wallet can sign messages
     * @dev Two functions - isValidSignature(bytes,bytes) and isValidSignature(bytes32,bytes)
     * @dev isValidSignature(bytes,bytes) conforms to ERC1271 - https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1271.md
     * @dev This means it returns the magic value 0x20c13b0b
     * @dev isValidSignature(bytes32,bytes) conforms to - https://github.com/0xProject/0x-monorepo/blob/development/contracts/exchange/contracts/examples/Wallet.sol#L45
     */

        /// @dev Validates a signature.
    ///      The signer must match the owner of this wallet.
    /// @param hash Message hash that is signed.
    /// @param signature Proof of signing.
    /// @return Validity of signature as bool
    function isValidSignature(
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        returns (bool isValid)
    {
        require(
            signature.length == 65,
            "LENGTH_65_REQUIRED"
        );

        address recoveredAddress = recover(hash, signature);
        address WALLET_OWNER = returnUserAccountAddress();
        isValid = WALLET_OWNER == recoveredAddress;
        return isValid;
    }

    bytes4 internal MAGICVALUE = 0x20c13b0b;

        /// @dev Validates a signature.
    ///      The signer must match the owner of this wallet.
    /// @param _data Data that is signed.
    /// @param signature Proof of signing.
    /// @return Validity of signature as bytes4
    function isValidSignature(
        bytes calldata _data,
        bytes calldata signature
    )
        external
        view
       returns (bytes4 magicValue)
    {
        require(
            signature.length == 65,
            "LENGTH_65_REQUIRED"
        );

        bytes32 dataHash = keccak256(_data);
        address recoveredAddress = recover(dataHash, signature);
        address WALLET_OWNER = returnUserAccountAddress();
        if (WALLET_OWNER == recoveredAddress) {
            return MAGICVALUE;
        } else {
            return (0xdeadbeef);
        }
    }

    /**
     * @dev Safe receiver functions
    */

    /** ERC721 receiver function
     * From OpenZeppelin - https://github.com/OpenZeppelin/openzeppelin-solidity/blob/v1.12.0/contracts/token/ERC721/ERC721Receiver.sol
     * Nifty Wallets will always receive an ERC721
     */

    bytes4 internal constant ERC721_RECEIVED = 0x150b7a02;

    function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
        return (ERC721_RECEIVED);
    }

    /** Safe ERC1155 receiver
    * Nifty Wallets will always receive ERC1155s as well
    * We like all tokens
    * From Horizon Games - https://github.com/horizon-games/multi-token-standard
    */
    bytes4 constant public ERC1155_RECEIVED_SIG = 0xf23a6e61;
      bytes4 constant public ERC1155_BATCH_RECEIVED_SIG = 0xbc197c81;
      bytes4 constant public ERC1155_RECEIVED_INVALID = 0xdeadbeef;

      bytes public lastData;
      address public lastOperator;
      uint256 public lastId;
      uint256 public lastValue;

      /**
      * @notice Handle the receipt of a single ERC1155 token type.
      * @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeTransferFrom` after the balance has been updated.
      * This function MAY throw to revert and reject the transfer.
      * Return of other than the magic value MUST result in the transaction being reverted.
      * Note: The contract address is always the message sender.
      * @param _operator  The address which called the `safeTransferFrom` function
      * @param _from      The address which previously owned the token
      * @param _id        The id of the token being transferred
      * @param _value     The amount of tokens being transferred
      * @param _data      Additional data with no specified format
      * @return           `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
      */
      function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data )
        external view returns(bytes4)
      {
          return ERC1155_RECEIVED_SIG;
      }

      /**
      * @notice Handle the receipt of multiple ERC1155 token types.
      * @dev An ERC1155-compliant smart contract MUST call this function on the token recipient contract, at the end of a `safeBatchTransferFrom` after the balances have been updated.
      * This function MAY throw to revert and reject the transfer.
      * Return of other than the magic value WILL result in the transaction being reverted.
      * Note: The contract address is always the message sender.
      * @param _operator  The address which called the `safeBatchTransferFrom` function
      * @param _from      The address which previously owned the token
      * @param _ids       An array containing ids of each token being transferred
      * @param _values    An array containing amounts of each token being transferred
      * @param _data      Additional data with no specified format
      * @return           `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
      */
      function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data)
        external view returns(bytes4)
      {
          return ERC1155_BATCH_RECEIVED_SIG;
      }

}

contract MasterContract {
    function returnUserControlAddress(uint account_id) public view returns (address);
    function returnIsValidSendingKey(address sending_key) public view returns (bool);
}
