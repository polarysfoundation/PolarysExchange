const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();

module.exports = {
  networks: {
    sepolia: {
      provider: function () {
        return new HDWalletProvider(
          `${process.env.MNEMONIC}`,
          `https://sepolia.infura.io/v3/${process.env.INFURA_API}`
        );
      },
      network_id: 11155111,
    },
  },
  compilers: {
    solc: {
      version: "0.8.20", // Replace with the latest version of Solidity compiler
      settings: {
        optimizer: {
          enabled: true,
          runs: 1500,
        },
        viaIR: true, // Add viaIR to enable reading the IR (Intermediate Representation)
      },
    },
  },
  plugins: ["truffle-plugin-stdjsonin", "truffle-plugin-verify"],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
  },
};
