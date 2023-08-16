const PolarysExchange = artifacts.require("./contracts/PolarysExchange.sol");
require("dotenv").config();


const arg1 = process.env.ADMIN_ADDRESS;

module.exports = function (deployer) {
  deployer.deploy(PolarysExchange, arg1);
};
