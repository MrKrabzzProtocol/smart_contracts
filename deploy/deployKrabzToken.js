const { network } = require("hardhat")
const { networkConfig } = require("../helper-hardhat-config")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    console.log("Deploying Krabz Token...")

    const KrabzToken = await deploy("KrabzToken", {
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    console.log("Deployed")
}

module.exports.tags = ["all", "krabzToken"]
