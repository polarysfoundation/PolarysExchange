var PolarysExchangeV1 = artifacts.require("./contracts/PolarysExchangeV1.sol");

module.exports = function (deployer) {
  deployer.deploy(PolarysExchangeV1);
};
