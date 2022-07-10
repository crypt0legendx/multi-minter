const MultiMinter = artifacts.require("MultiMinter");

module.exports = function (deployer) {
  deployer.deploy(MultiMinter);
};
