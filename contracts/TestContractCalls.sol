pragma solidity ^0.5.4;

contract TestContractCalls {

    address ExampleWallet = 0xcc5a36BF104bBE0223367D6bC45e8b936b89357F;

    function onERC721Received(address add1, address add2, uint256 id, bytes memory dat) public view returns (bytes4) {
        StaticContract new_c = StaticContract(ExampleWallet);
        return (new_c.onERC721Received(add1, add2, id, dat));
    }

    function add() public view returns(address) {
        StaticContract new_c = StaticContract(ExampleWallet);
        return (new_c.retAdd());
    }

    function isValidSignature(bytes calldata hash, bytes calldata signature) external view returns (bytes4) {
        StaticContract new_c = StaticContract(ExampleWallet);
        return (new_c.isValidSignature(hash, signature));
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bool) {
        StaticContract new_c = StaticContract(ExampleWallet);
        return (new_c.isValidSignature(hash, signature));
    }

}

contract StaticContract {
    function onERC721Received(address, address, uint256, bytes memory) public view returns (bytes4);
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bool);
    function isValidSignature(bytes calldata hash, bytes calldata signature) external view returns (bytes4);
    function retAdd() external view returns (address);
}
