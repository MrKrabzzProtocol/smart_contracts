require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()

const FVM_RPC_URL = process.env.FVM_RPC_URL
const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL
const PRIVATE_KEY = process.env.PRIVATE_KEY
const PRIVATE_KEY_TWO = process.env.PRIVATE_KEY_TWO
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
            blockConfirmations: 1,
        },
        fvm: {
            chainId: 3141,
            blockConfirmations: 1,
            url: FVM_RPC_URL,
            accounts: [PRIVATE_KEY, PRIVATE_KEY_TWO],
        },
        mumbai: {
            chainId: 80001,
            blockConfirmations: 2,
            url: MUMBAI_RPC_URL,
            accounts: [PRIVATE_KEY, PRIVATE_KEY_TWO],
        },
    },
    solidity: {
        version: "0.8.17",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000,
                details: { yul: false },
            },
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
        secondAccount: {
            default: 1,
        },
    },
}
