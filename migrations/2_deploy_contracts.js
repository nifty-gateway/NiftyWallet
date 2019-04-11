var NiftyWallet = artifacts.require("./NiftyWallet.sol");

module.exports = function(deployer) {
  deployer.deploy(NiftyWallet);
};
