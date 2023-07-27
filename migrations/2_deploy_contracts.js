const PolarysExchange = artifacts.require("./contracts/PolarysExchange.sol");
require("dotenv").config();


const arg2 = process.env.FEE_ADDRESS;
const arg1 = process.env.ADMIN_ADDRESS;
const arg3 = 2;

module.exports = function (deployer) {
  deployer.deploy(PolarysExchange, arg1, arg2, arg3);
};
