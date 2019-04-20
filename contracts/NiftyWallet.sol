pragma solidity ^0.5.4;

contract NiftyWallet {

    /**
     * Constants
     * The address of the master contract, and the account ID for this wallet
     * Account ID is used to retrieve the signing private key for this wallet
     */

    address masterContractAdd = 0xdE2D9906B516bFB62559676E180c7731679429C9;
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
     * Fall back function - get paid and static calls
     */

    function()
        payable
        external
    {
        if (msg.value > 0)
            emit Deposit(msg.sender, msg.value);
        else if (msg.data.length > 0) {
            //static call
            MasterContract m_c_instance = MasterContract(masterContractAdd);
            address loc =  (m_c_instance.returnStaticContractAddress());
                assembly {
                    calldatacopy(0, 0, calldatasize())
                    let result := staticcall(gas, loc, 0, calldatasize(), 0, 0)
                    returndatacopy(0, 0, returndatasize())
                    switch result
                    case 0 {revert(0, returndatasize())}
                    default {return (0, returndatasize())}
                }
        }
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
        MasterContract m_c_instance = MasterContract(masterContractAdd);
        bytes32 dataHash = returnTxMessageToSign(data, destination, value);
        address recoveredAddress = m_c_instance.recover(dataHash, _signedData);
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

}

contract MasterContract {
    function returnUserControlAddress(uint account_id) public view returns (address);
    function returnIsValidSendingKey(address sending_key) public view returns (bool);
    function returnStaticContractAddress() public view returns (address);
    function recover(bytes32 hash, bytes memory sig) public pure returns (address);
}
