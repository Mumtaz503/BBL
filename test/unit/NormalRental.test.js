const { expect, assert } = require( "chai" );
const { developmentChains, testURI, networkConfig } = require( "../../helper-hardhat.confg" );
const { network, getNamedAccounts, ethers, deployments } = require( "hardhat" );

!developmentChains.includes( network.name ) ? describe.skip :

    describe( "NormalRental unit tests", () =>
    {
        let normalRental, deployer, user, userSigner, signer, routerV2, usdt;
        const chainId = network.config.chainId;
        beforeEach( async function ()
        {
            deployer = ( await getNamedAccounts() ).deployer;
            user = ( await getNamedAccounts() ).user;
            signer = await ethers.provider.getSigner();
            userSigner = await ethers.getSigner( user );
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
            it( "Should updated the price decimals adjusted", async () =>
            {
                const price = BigInt( 50000 );
                const seed = Math.floor( Math.random() * 7652 );

                const tx = await normalRental.addProperty( testURI, price, seed );
                await tx.wait( 1 );

                const newTokenId = await normalRental.getTokenId();

                const propertyListing = await normalRental.getProperties( newTokenId );

                expect( ( price ) * BigInt( 1e6 ) ).to.equal( propertyListing[ 1 ] );
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
            let tokenId, amountToSubmit;
            beforeEach( async () =>
            {
                const price = BigInt( 200000 );
                const seed = Math.floor( Math.random() * 7895 );
                await normalRental.addProperty( testURI, price, seed );
                tokenId = await normalRental.getTokenId();
                console.log( "token Id", tokenId );

                //Buying USDT from Uniswap
                const amountOutMin = 100;
                const path = [
                    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", //weth
                    "0xdac17f958d2ee523a2206206994597c13d831ec7"  //usdt
                ];

                const deadline = Math.floor( Date.now() / 1000 ) + 60 * 10;
                const transactionResponse = await routerV2.swapExactETHForTokens(
                    amountOutMin,
                    path,
                    deployer,
                    deadline,
                    {
                        value: ethers.parseEther( "1" ),
                    }
                );
                await transactionResponse.wait( 1 );
                amountToSubmit = await usdt.balanceOf( deployer );
                await usdt.approve( normalRental.target, amountToSubmit );
            } );
            it( "Should revert if the user balance isn't enough", async () =>
            {
                const depositAmount = ( await usdt.balanceOf( deployer ) ) + 10n;
                await expect( normalRental.submitRent( depositAmount, tokenId ) ).to.be.revertedWith( "Not enough Balance" );
            } );
            it( "Should revert if the tokenId is not found", async () =>
            {
                await expect( normalRental.submitRent( amountToSubmit, 323 ) ).to.be.revertedWith( "Property not found" );
            } );
            it( "Should transfer funds from the owner to the contract", async () =>
            {
                await normalRental.submitRent( amountToSubmit, tokenId );
                const contractUsdtBalance = await usdt.balanceOf( normalRental.target );

                assert.equal( contractUsdtBalance, amountToSubmit );
            } );
        } );

        describe( "mint function", function ()
        {
            let tokenId, amountToSubmit, price;
            beforeEach( async () =>
            {
                price = BigInt( 20000 );
                const seed = Math.floor( Math.random() * 7895 );
                await normalRental.addProperty( testURI, price, seed );
                tokenId = await normalRental.getTokenId();
                console.log( "token Id", tokenId );

                //Buying USDT from Uniswap
                const amountOutMin = 30000n;
                const path = [
                    "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", //weth
                    "0xdac17f958d2ee523a2206206994597c13d831ec7"  //usdt
                ];

                const deadline = Math.floor( Date.now() / 1000 ) + 60 * 10;
                const transactionResponse = await routerV2.swapExactETHForTokens(
                    amountOutMin,
                    path,
                    deployer,
                    deadline,
                    {
                        value: ethers.parseEther( "10" ),
                    }
                );
                await transactionResponse.wait( 1 );
                amountToSubmit = await usdt.balanceOf( deployer );
            } );
            it( "Should revert if the min amount is less than 1", async () =>
            {
                const amountToOwn = 0n;
                await expect( normalRental.mint( tokenId, amountToOwn ) ).to.be.revertedWith( "Min investment 1%" );
            } );
            it( "Should revert if no supply left", async () =>
            {
                const amountToOwn = 101n;
                await expect( normalRental.mint( tokenId, amountToOwn ) ).to.be.revertedWith( "Not enough supply left" );
            } );
            it( "Should revert if balance is not enough", async () =>
            {
                const amountToOwn = 12n;
                await expect( normalRental.connect( userSigner ).mint( tokenId, amountToOwn ) ).to.be.revertedWith( "Not enough balance" );
            } );
            it( "Should revert if minting is paused", async () =>
            {
                const amountToOwn = 5n;
                const paused = true;
                await normalRental.pause( paused );

                await expect( normalRental.connect( userSigner ).mint( tokenId, amountToOwn ) ).to.be.revertedWith( "Minting Paused" );
            } );

            it( "Should transfer funds from investor to the contract", async () =>
            {
                const amountToOwn = BigInt( 10 );
                const contractUsdtBalanceBefore = await usdt.balanceOf( normalRental );
                const approvalAmount = ( price * amountToOwn ) / BigInt( 100 );

                await usdt.approve( normalRental.target, approvalAmount * BigInt( 1e6 ) );
                const tx = await normalRental.mint( tokenId, amountToOwn );

                const contractUsdtBalanceAfter = await usdt.balanceOf( normalRental );

                expect( contractUsdtBalanceAfter ).to.be.greaterThan( contractUsdtBalanceBefore );
            } );
            it( "Should update the property listings", async () =>
            {
                const amountToOwn = BigInt( 5 );
                const approvalAmount = ( price * amountToOwn ) / BigInt( 100 );

                await usdt.approve( normalRental.target, approvalAmount * BigInt( 1e6 ) );
                const tx = await normalRental.mint( tokenId, amountToOwn );

                const propertyListing = await normalRental.getProperties( tokenId );

                const amountGenerated = propertyListing.amountGenerated;
                const amountMinted = propertyListing.amountMinted;

                assert.equal( amountGenerated, ( approvalAmount * BigInt( 1e6 ) ) );
                assert.equal( amountMinted, amountToOwn );
            } );
            it( "Should update the data structure for investors", async function ()
            {
                const amountToOwn = BigInt( 5 );
                const approvalAmount = ( price * amountToOwn ) / BigInt( 100 );

                await usdt.approve( normalRental.target, approvalAmount * BigInt( 1e6 ) );
                const tx = await normalRental.mint( tokenId, amountToOwn );

                const investorListing = await normalRental.getInvestments( deployer, tokenId );

                assert.equal( investorListing, amountToOwn );
            } );
            it( "Should mint the shares to the investor", async () =>
            {
                const amountToOwn = BigInt( 5 );
                const approvalAmount = ( price * amountToOwn ) / BigInt( 100 );

                await usdt.approve( normalRental.target, approvalAmount * BigInt( 1e6 ) );
                const tx = await normalRental.mint( tokenId, amountToOwn );

                const investorBalance = await normalRental.balanceOf( deployer, tokenId );

                assert.equal( investorBalance, amountToOwn );
            } );
        } );

        /**
         * Make the _isValidUri() function public and uncomment the following lines to run the test
         */
        // describe( "_isValidUri function", function ()
        // {
        //     it( "Should return true for a valid Uri", async () =>
        //     {
        //         const isValid = true;
        //         //Make this function public in contract
        //         const returnedValue = await normalRental._isValidUri( testURI );
        //         assert.equal( isValid, returnedValue );
        //     } );
        // } );
    } );