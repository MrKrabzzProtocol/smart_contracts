const { ethers, getNamedAccounts } = require("hardhat")

async function updateDestinationAddresses() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    // ARGS
    const filDestinationAddress = "0x0eC3f91fd87b7832CF950A58A8E9994969DEF606".toString()
    const polygonDestinationAddr = "0x698F44D5e14E51a23772C9c1CEC41B837FD08983".toString()

    await mrKrabz.updateDestinationAddresses(filDestinationAddress, polygonDestinationAddr)
    console.log("Destination Addresses Updated!")
}

async function fundContractWithKrabz() {
    const { deployer } = await getNamedAccounts()
    const krabzToken = await ethers.getContract("KrabzToken", deployer)

    const filDestinationAddress = "0x0eC3f91fd87b7832CF950A58A8E9994969DEF606"
    const polygonDestinationAddr = "0x698F44D5e14E51a23772C9c1CEC41B837FD08983"

    const amount = ethers.utils.parseEther("20000")
    // ARGS
    await krabzToken.mintKrabz(polygonDestinationAddr, amount)
}

fundContractWithKrabz()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
