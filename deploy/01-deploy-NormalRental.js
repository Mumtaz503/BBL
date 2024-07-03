const { network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat.confg");

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = network.config.chainId;

    log("-------------------------------------------------");
    log("Deploying NormalRental...");

    const constructorArgs = [networkConfig[chainId].usdt];

    const normalRental = await deploy("NormalRental", {
        from: deployer,
        log: true,
        args: constructorArgs,
        waitConfirmations: network.config.blockConfirmations,
    });

    log("-------------------------------------------------");
    log("successfully deployed NormalRental...");
}

module.exports.tags = ["all", "NormalRental"];