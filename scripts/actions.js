const { ethers, getNamedAccounts } = require("hardhat")

async function startNewRound() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    // ARGS
    const roundEndTime = 600 // 10 minutes
    const ticketPriceInUsd = 10000000 // 0.1usd in  8 decimals
    const roundName = "Axelar x FVM Rocks!!!"
    const estimateGasAmount = ethers.utils.parseEther("0.3") // 18 decimals

    console.log("Starting New Round...")
    await mrKrabz.startNewRound(roundEndTime, ticketPriceInUsd, roundName, estimateGasAmount)
    console.log("New Round Started")
}

async function topUpWalletBalances() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    const estimateGasAmount = ethers.utils.parseEther("0.3")

    const option = true

    if (option) {
        const amount = ethers.utils.parseEther("1")
        console.log("Topping Up Wallet Balance....")
        await mrKrabz.topUpWalletBalance(0, option, estimateGasAmount, { value: amount })
    } else {
        const amount = ethers.utils.parseEther("10")
        const krabzToken = await ethers.getContract("KrabzToken", deployer)

        console.log("Minting Deployer Tokens....")
        await krabzToken.mintKrabz(deployer, amount)

        console.log("Approving Tokenss....")
        await krabzToken.approve(mrKrabz.address, amount)

        console.log("Topping Up Wallet Balances....")
        await mrKrabz.topUpWalletBalance(amount, option, estimateGasAmount)
    }
}

async function buyTicket() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    const selectedNumbersWinner = [3, 14, 27]
    const selectedNumbers = [4, 22, 10]

    const option = false
    const estimateGasAmount = ethers.utils.parseEther("0.3")

    if (option) {
        console.log("Buying Ticket With Native Asset...")

        // winning buy
        await mrKrabz.buyTicket(selectedNumbersWinner, option, estimateGasAmount)
    }

    if (!option) {
        console.log("Buying Ticket With Krabz...")

        await mrKrabz.buyTicket(selectedNumbers, false, estimateGasAmount)
    }
}

async function setRoundWinners() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    // 12, 10, 29 => 3, 14, 27

    const estimateGasAmount = ethers.utils.parseEther("0.3")

    console.log("Set Round Winners....")

    await mrKrabz.setRoundWinners(12, 10, 29, estimateGasAmount)
}

async function claimWinnings() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    const ticketIdOne = 1
    const ticketIdTwo = 2

    const estimateGasAmount = ethers.utils.parseEther("0.3")

    console.log("Claim Winnings....")

    await mrKrabz.claimWinnings(ticketIdOne, estimateGasAmount)
}

async function claimRefund() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    const ticketIdOne = 1
    const ticketIdTwo = 2

    const estimateGasAmount = ethers.utils.parseEther("0.3")

    console.log(" claim Refund....")

    await mrKrabz.claimRefund(ticketIdOne, estimateGasAmount)
}

async function withdrawNativeAsset() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)
    await mrKrabz.withdrawNativeAsset()
}

setRoundWinners()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

// NOTE:
