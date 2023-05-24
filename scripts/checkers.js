const { ethers, getNamedAccounts } = require("hardhat")

async function getRoundDetails() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz", deployer)

    // ARGS
    const filDestinationAddress = "0x88A7254E939DF3209809022F6D75aA5c5282b57D"
    const polygonDestinationAddr = "0x1B187597EEAfCD738Ce2a91BB26DaCF5BF2f48e5"

    console.log("Getting User Details...")
    const userDetails = await mrKrabz.getUserDetails(deployer)
    console.log("User Details: ", userDetails)

    console.log("Getting Round Details....")
    const roundDetails = await mrKrabz.getCurrentRoundDetails()
    console.log("Round Details: ", roundDetails)

    const currentRound = await mrKrabz.currentRound()

    console.log("Current Round ID: ", currentRound.toString())

    console.log("Current Round ID: ", roundDetails.roundId.toString())
    console.log("Current Ticket Price: ", roundDetails.ticketPrice.toString() / 10 ** 8)
    console.log("Round End Time: ", roundDetails.roundEndTime.toString())
    console.log("Round Name: ", roundDetails.roundName)
    console.log("Round Tickets Purchased: ", roundDetails.ticketsPurchased.toString())
    console.log("Round State: ", roundDetails.roundState)
    console.log("Round Winning Numbers: ", roundDetails.roundWinningNumbers.toString())

    console.log("Round Fil Balance: ", roundDetails.balance.fil.toString())
    console.log("Round Matic Balance: ", roundDetails.balance.matic.toString())
    console.log("Round Krabz Balance: ", roundDetails.balance.krabz.toString())
}

async function getWalletBalance() {
    console.log("Getting wallet balance....")
    const { deployer } = await getNamedAccounts()

    const mrKrabz = await ethers.getContract("MrKrabz")
    const crossChainBalance = await mrKrabz.getUserDetails(deployer)

    console.log("User Balance: ")
    console.log("FIL :", crossChainBalance.balance.fil.toString())
    console.log("KRABZ :", crossChainBalance.balance.krabz.toString())
    console.log("MATIC :", crossChainBalance.balance.matic.toString())
}

async function getTicketPrice() {
    const { deployer } = await getNamedAccounts()
    const mrKrabz = await ethers.getContract("MrKrabz")

    const tw = await mrKrabz.getUserTicketsForCurrentRound(deployer)

    console.log(tw[0].selectedNumbers.toString())
    const filUsdPrice = await mrKrabz.roundToticketId_(1, 1)
    console.log(filUsdPrice.selectedNumbers.toString())

    console.log(filUsdPrice)
    console.log(maticPriceUsd)
    console.log(krabzPriceUsd)
}

getRoundDetails()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

// 12, 10, 29 => 3, 14, 27
