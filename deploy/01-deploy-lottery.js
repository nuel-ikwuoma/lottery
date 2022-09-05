const { ethers, network } = require("hardhat")
const { developmentChains, networkConfig, WAIT_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
const VRF_SUB_FUND_AMT = "1000000000000000000000"    // ethers.utils.parseEther("30")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    let vrfCoordinatorv2Address, subscriptionId, vrfCoordinatorv2Mock

    if(developmentChains.includes(network.name)) {
        vrfCoordinatorv2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorv2Address = vrfCoordinatorv2Mock.address
        const txResponse = await vrfCoordinatorv2Mock.createSubscription()
        const txReceipt = await txResponse.wait(1)
        subscriptionId = txReceipt.events[0].args.subId
        // fund subscription, use LINK in reall network
        await vrfCoordinatorv2Mock.fundSubscription(subscriptionId, VRF_SUB_FUND_AMT)
    }else {
        vrfCoordinatorv2Address = networkConfig[chainId]["vrfCoordinatorv2"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
    }

    const waitBlockConfirmations = developmentChains.includes(network.name) ? 1 : WAIT_BLOCK_CONFIRMATIONS
    
    

    const {entranceFee, gasLane, callbackGasLimit, interval} = networkConfig[chainId]
    const args = [vrfCoordinatorv2Address, entranceFee, gasLane, subscriptionId, callbackGasLimit, interval]
    const lottery = await deploy("Lottery", {
        from: deployer,
        args,
        log: true,
        waitConfirmations: waitBlockConfirmations
    })

    // attempt to verify contract
    if(developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("verifying........")
        await verify(lottery.address, args)
    }
    log("----------------------------------------")
}

module.exports.tags = ["all", "lottery"]