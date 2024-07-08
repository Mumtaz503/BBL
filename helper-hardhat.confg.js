const networkConfig = {
    31337: {
        name: "localhost",
        usdt: "0xdAC17F958D2ee523a2206206994597C13D831ec7",  //Mainnet USDT for forked network testing
    },
    11155111: {
        name: "sepolia",
        usdt: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0",  //Sepolia USDT for testnet testing
    },
};

const developmentChains = [ "hardhat", "localhost" ];
const testURI = "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json"; //Test URI

module.exports = {
    networkConfig,
    developmentChains,
    testURI
};