const TokenMinter = artifacts.require("TokenMinter");

module.exports = function (deployer) {
  deployer.deploy(TokenMinter);
};
