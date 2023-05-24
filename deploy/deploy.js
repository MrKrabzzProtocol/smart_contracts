const { network } = require("hardhat")
const { networkConfig } = require("../helper-hardhat-config")
const verify = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const gateway = networkConfig[chainId].gateway
    const gasReceiver = networkConfig[chainId].gasReceiver
    const tellorOracle = networkConfig[chainId].tellorOracle
    const krabzToken = networkConfig[chainId].krabzToken

    const args = [gateway, gasReceiver, tellorOracle, krabzToken]

    const MrKrabz = await deploy("MrKrabz", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
}

module.exports.tags = ["all", "main"]
