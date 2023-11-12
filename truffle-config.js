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
    dashboard: {
      /*       provider: function () {
        return new HDWalletProvider(
          `${process.env.MNEMONIC}`,
          "http://localhost:24012/rpcs"
        );
      }, */
      host: "localhost",
      port: 24012,
      network_id: 1337,
      /*       verbose: true, */
    },
    rpc: {
      host: "127.0.0.1",
      port: 8545,
    },
  },
  compilers: {
    solc: {
      version: "0.8.20", // Replace with the latest version of Solidity compiler
      evmVersion: "istanbul",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
  plugins: ["truffle-plugin-stdjsonin", "truffle-plugin-verify"],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
  },
};
