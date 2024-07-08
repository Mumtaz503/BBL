const { expect, assert } = require( "chai" );
const { developmentChains, testURI, networkConfig } = require( "../../helper-hardhat.confg" );
const { network, getNamedAccounts, ethers, deployments } = require( "hardhat" );

!developmentChains.includes( network.name ) ? describe.skip :

    describe( "NormalRental unit tests", () =>
    {
        let normalRental, deployer, user, signer, routerV2, usdt;
        const chainId = network.config.chainId;
        beforeEach( async function ()
        {
            deployer = ( await getNamedAccounts() ).deployer;
            user = ( await getNamedAccounts() ).user;
            signer = await ethers.provider.getSigner();
            await deployments.fixture( [ "all" ] );
            normalRental = await ethers.getContract( "NormalRental", deployer );
            usdt = await ethers.getContractAt( "IErc20", "0xdac17f958d2ee523a2206206994597c13d831ec7", signer );
            routerV2 = await ethers.getContractAt( "UniswapV2Router02", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", signer );
        } );
        describe( "constructor", function ()
        {
            it( "Should initialize the usdt address correctly", async () =>
            {
                const usdt = networkConfig[ chainId ].usdt;
                const addressFromCall = await normalRental.getUsdtAddress();
                assert.equal( usdt, addressFromCall );
            } );
            it( "Should initialize the current Token Id correctly", async () =>
            {
                const curTokenId = await normalRental.getTokenId();
                assert.equal( curTokenId, 0 );
            } );
        } );
        describe( "addProperty function", function ()
        {
            it( "Should revert if the passed URI is invalid", async () =>
            {
                const testingUri = "Brick Block add";
                const price = BigInt( 100000 );
                const seed = Math.floor( Math.random() * 767 );

                await expect( normalRental.addProperty( testingUri, price, seed ) ).to.be.revertedWith( "Please place a valid URI" );
            } );

            it( "Should revert if appropriate values are not passed", async () =>
            {
                const price = 0;
                const seed = 0;

                await expect( normalRental.addProperty( testURI, price, seed ) ).to.be.revertedWith( "Please enter appropriate values" );
            } );
            it( "Should update the token ID upon call", async () =>
            {
                const currentTokenId = await normalRental.getTokenId();
                const price = BigInt( 50000 );
                const seed = Math.floor( Math.random() * 7652 );

                const tx = await normalRental.addProperty( testURI, price, seed );
                await tx.wait( 1 );

                const newTokenId = await normalRental.getTokenId();
                assert( newTokenId > currentTokenId );
            } );
            it( "Should return the property listing added", async () =>
            {
                const price = BigInt( 50000 );
                const seed = Math.floor( Math.random() * 7652 );

                const tx = await normalRental.addProperty( testURI, price, seed );
                await tx.wait( 1 );

                const newTokenId = await normalRental.getTokenId();

                const propertyListing = await normalRental.getProperties( newTokenId );

                expect( newTokenId ).to.equal( propertyListing[ 0 ] );
            } );
            it( "Should update the token Uri against the tokenId", async () =>
            {
                const price = BigInt( 50000 );
                const seed = Math.floor( Math.random() * 7652 );

                const tx = await normalRental.addProperty( testURI, price, seed );
                await tx.wait( 1 );

                const newTokenId = await normalRental.getTokenId();

                const uri = await normalRental.uri( newTokenId );

                assert.equal( testURI.toLowerCase(), uri.toLowerCase() );
            } );
        } );
        //////////////////////////////////////////////
        //        View and Pure func Testing        //
        //////////////////////////////////////////////

        describe( "submitRent function", function ()
        {
            let tokenId;
            beforeEach( async () =>
            {
                // Parameters of `addProperty()` function
                const price = BigInt( 200000 );
                const seed = Math.floor( Math.random() * 7895 );

                // Calls `addProperty()` function on contract `normalRental` 
                const tx = await normalRental.addProperty( testURI, price, seed );
                await tx.wait( 1 );

                await new Promise( async ( resolve, reject ) =>
                {
                    normalRental.once( "PropertyMinted", async ( tokenId_ ) =>
                    {
                        try
                        {
                            console.log( "Property Minted", tokenId_.toString() );
                            resolve();
                        } catch ( error )
                        {
                            reject( error );
                        }
                    } );
                } );
            } );
            it( "Should revert if the user balance isn't enough", async () =>
            {

            } );
        } );

        describe( "_isValidUri function", function ()
        {
            it( "Should return true for a valid Uri", async () =>
            {
                const isValid = true;
                //Make this function public in contract
                const returnedValue = await normalRental._isValidUri( testURI );
                assert.equal( isValid, returnedValue );
            } );
        } );
    } );