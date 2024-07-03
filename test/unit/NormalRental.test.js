const { expect, assert } = require("chai");
const { developmentChains, testURI, networkConfig } = require("../../helper-hardhat.confg");
const { network, getNamedAccounts, ethers, deployments } = require("hardhat");

!developmentChains.includes(network.name) ? describe.skip :

    describe("NormalRental unit tests", () => {
        let normalRental, deployer, user;
        const chainId = network.config.chainId;
        beforeEach(async function () {
            deployer = (await getNamedAccounts()).deployer;
            user = (await getNamedAccounts()).user;
            await deployments.fixture(["all"]);
            normalRental = await ethers.getContract("NormalRental", deployer);
        });
        describe("constructor", function () {
            it("Should initialize the usdt address correctly", async () => {
                const usdt = networkConfig[chainId].usdt;
                const addressFromCall = await normalRental.getUsdtAddress();
                assert.equal(usdt, addressFromCall);
            });
            it("Should initialize the current Token Id correctly", async () => {
                const curTokenId = await normalRental.getTokenId();
                assert.equal(curTokenId, 0);
            });
        });
        describe("addProperty function", function () {
            it("Should update the token ID upon call", async () => {
                const currentTokenId = await normalRental.getTokenId();
                const price = BigInt(50000);
                const seed = Math.floor(Math.random() * 7652);

                const tx = await normalRental.addProperty(testURI, price, seed);
                await tx.wait(1);

                const newTokenId = await normalRental.getTokenId();
                assert(newTokenId > currentTokenId);
            });
            it("Should return the property listing added", async () => {
                const price = BigInt(50000);
                const seed = Math.floor(Math.random() * 7652);

                const tx = await normalRental.addProperty(testURI, price, seed);
                await tx.wait(1);

                const newTokenId = await normalRental.getTokenId();

                const propertyListing = await normalRental.getProperties(newTokenId);

                expect(newTokenId).to.equal(propertyListing[0]);
            });
            it("Should update the token Uri against the tokenId", async () => {
                const price = BigInt(50000);
                const seed = Math.floor(Math.random() * 7652);

                const tx = await normalRental.addProperty(testURI, price, seed);
                await tx.wait(1);

                const newTokenId = await normalRental.getTokenId();

                const uri = await normalRental.uri(newTokenId);

                assert.equal(testURI.toLowerCase(), uri.toLowerCase());
            });
        });
    });