pragma solidity ^0.5.4;

contract TestContractCalls {

    address ExampleNiftyWalletAddress = 0x72947f7e561e66E902D9210d6f7261DD06A2Ec96;

    function onERC721Received(address add1, address add2, uint256 id, bytes memory dat) public view returns (bytes4) {
        NiftyWallet new_c = NiftyWallet(ExampleNiftyWalletAddress);
        return (new_c.onERC721Received(add1, add2, id, dat));
    }

    function add() public view returns(address) {
        NiftyWallet new_c = NiftyWallet(ExampleNiftyWalletAddress);
        return (new_c.retAdd());
    }

    function isValidSignature(bytes calldata hash, bytes calldata signature) external view returns (bytes4) {
        NiftyWallet new_c = NiftyWallet(ExampleNiftyWalletAddress);
        return (new_c.isValidSignature(hash, signature));
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bool) {
        NiftyWallet new_c = NiftyWallet(ExampleNiftyWalletAddress);
        return (new_c.isValidSignature(hash, signature));
    }

}

contract NiftyWallet {
    function onERC721Received(address, address, uint256, bytes memory) public view returns (bytes4);
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bool);
    function isValidSignature(bytes calldata hash, bytes calldata signature) external view returns (bytes4);
    function retAdd() external view returns (address);
}
