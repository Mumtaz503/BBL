const networkConfig = {
    31337: {
        name: "localhost",
    },
    11155111: {
        name: "sepolia",
    },
};

const developmentChains = ["hardhat", "localhost"];
const testURI = "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

module.exports = {
    networkConfig,
    developmentChains,
    testURI
};