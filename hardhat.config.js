//require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-waffle");
//require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
//require("solidity-coverage");
//require("hardhat-gas-reporter");
 const config = {
   "priKey": "",
   "projectId": ""
 }

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        }
      },
      // {
      //   version: "0.8.0",
      //   settings: {
      //     optimizer: {
      //       enabled: true,
      //       runs: 1000,
      //     },
      //   }
      // },
      // {
      //   version: "0.4.26",
      //   settings: {
      //     optimizer: {
      //       // enabled: true,
      //       // runs: 1000,
      //     },
      //   }
      // }
  ]
  },
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false,
    currency: "USD",
    token: "ETH",
    gasPriceApi: "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
  },
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${config.projectId}`,
      accounts: [`0x${config.priKey}`],
      //accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      chainId: 4
    },
  },
  etherscan: {
    apiKey: ""
  }
};
