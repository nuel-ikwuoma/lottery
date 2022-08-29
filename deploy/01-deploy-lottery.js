const { networks } = require("../hardhat.config")

module.export = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = getNamedAccounts()

    const lottery = await deploy("Lottery", {
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: networks.config.blockConfirmations || 1,
    })
}
