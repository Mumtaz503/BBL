// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NormalRental is ERC1155, Ownable {
    /* Custom Error Codes */
    error NormalRental__TRANSFER_FAILED_submitRent();
    error NormalRental__TRANSFER_FAILED_mint();
    error NormalRental__TRANSFER_FAILED_distributeRent();
    error NormalRental__TRANSFER_FAILED_mintOffplanInstalments();

    /* Using SafeERC20 library because of transfer calls for usdt */
    using SafeERC20 for IERC20;

    /* Type declarations */
    IERC20 private immutable i_usdt;
    struct Property {
        uint256 id;
        uint256 price;
        address owner;
        uint256 amountMinted;
        uint256 amountGenerated;
        uint256 timestamp;
        bool isOffplan;
    }

    struct OffplanInvestor {
        address investor;
        uint256 remainingInstalmentsAmount;
    }

    /* State Variables */
    string private constant BASE_EXTENSION = ".json";
    uint256 private s_currentTokenID;
    bool public paused = false;
    uint256 public constant MAX_MINT_PER_PROPERTY = 100;
    uint256 public constant DECIMALS = 10 ** 6;

    /* Mappings */
    mapping(uint256 => string) private s_tokenIdToTokenURIs;
    mapping(uint256 => Property) private s_tokenIdToProperties;
    mapping(uint256 => uint256) private s_tokenIdToRentGenerated;
    mapping(address => mapping(uint256 => uint256))
        private s_userToTokenIdToShares;
    mapping(uint256 => address[]) private s_tokenIdToInvestors;
    mapping(uint256 => Property) private s_tokenIdToOffplanProperties;
    mapping(uint256 => string) private s_offplanTokenIdToURIs;
    mapping(uint256 => OffplanInvestor) private s_tokenIdToInstallments;

    /* Events */
    event PropertyMinted(uint256 indexed tokenId_);
    event OffplanPropertyMinted(uint256 indexed tokenId_);

    /**
     * Sets the usdt address upon deployment and initializes the current token ID
     * @param _usdtAddress setting up usdt address upon deployment and deployer as the contract owner
     */
    constructor(address _usdtAddress) ERC1155("") Ownable(msg.sender) {
        i_usdt = IERC20(_usdtAddress);
        s_currentTokenID = 0;
    }

    //============================================================================================================//

    /**
     * Allows the owner to add a property listing either in offplan or normal category
     * @param _uri The pinata URI of the property that needs to be added passed from the front-end
     * @param _price The price of the property passed as BigInt
     * @param _seed A random unassigned 256 bit integer passed encoded in the contract to provide a unique ID to the NFT
     * @param _isOffPlan Boolean that indicates if the property is offplan or normal
     */
    function addProperty(
        string memory _uri,
        uint256 _price,
        uint256 _seed,
        bool _isOffPlan
    ) external onlyOwner {
        // Internal check to validate the incoming URI
        require(_isValidUri(_uri), "Please place a valid URI");
        // Ensuring that the price and seed values are not null
        require(_price > 0 && _seed > 0, "Please enter appropriate values");

        // Generates a unique ID for the property NFT
        uint256 newTokenID = uniqueId(_seed, msg.sender);
        //Sets the current ID as the new ID generated
        s_currentTokenID = newTokenID;
        // Adjusting the decimals of the property's price passed by the owner
        uint256 priceDecimals = _price * DECIMALS;
        // If the owner sets the property as normal then the following logic executes
        if (_isOffPlan == false) {
            // A new instance of the mapping is created where all the property data is saved
            s_tokenIdToProperties[newTokenID] = Property({
                id: newTokenID,
                price: priceDecimals,
                owner: msg.sender,
                amountMinted: 0, //Shares in %
                amountGenerated: 0, // amount in usdt
                timestamp: block.timestamp,
                isOffplan: false
            });
            // Token URI is also saved in another mapping
            s_tokenIdToTokenURIs[newTokenID] = _uri;
            // An event is emitted for the token ID to save gas by logging it off-chain for the front-end
            emit PropertyMinted(newTokenID);
            // If the owner sets the property as offplan then the following logic executes
        } else {
            // A different instance of mapping is created to save all the property data
            s_tokenIdToOffplanProperties[newTokenID] = Property({
                id: newTokenID,
                price: priceDecimals,
                owner: msg.sender,
                amountMinted: 0,
                amountGenerated: 0,
                timestamp: block.timestamp,
                isOffplan: true
            });
            // URI is saved in a different instance as well for offplan property
            s_offplanTokenIdToURIs[newTokenID] = _uri;
            // And a different event is emitted
            emit OffplanPropertyMinted(newTokenID);
        }
    }

    //============================================================================================================//

    /**
     * Allows the users to buy shares in normal rental properties that are ready to pay out rent
     * @param _tokenId The ID of the NFT for which the shares are to be minted
     * @param _amount The amount of shares that the user requests
     */
    function mint(uint256 _tokenId, uint256 _amount) external {
        // Doesn't allow investors to buy shares if the minting is paused
        require(paused == false, "Minting Paused");
        // Minimum investment value is 1%
        require(_amount >= 1, "Min investment 1%");
        // Loads the property data structure from  s_tokenIdToProperties mapping
        Property storage property = s_tokenIdToProperties[_tokenId];
        // Check if there's enough remaining supply for shares
        uint256 remainingSupply = MAX_MINT_PER_PROPERTY - property.amountMinted;

        require(remainingSupply >= _amount, "Not enough supply left");
        // Calculate the amount that the investor needs to pay
        uint256 usdtAmount = (property.price * _amount) / 100;

        require(
            i_usdt.balanceOf(msg.sender) > usdtAmount,
            "Not enough balance"
        );

        //Approve first in the front-end / scripts
        try this.attemptTransfer(msg.sender, address(this), usdtAmount) {
            // Transfers usdt from investor to the contract

            // Update the given _tokenId's amount generated
            uint256 _newAmoutnGenerated = property.amountGenerated + usdtAmount;
            property.amountGenerated = _newAmoutnGenerated;
            // Update the shares of a property
            property.amountMinted += _amount;
            s_userToTokenIdToShares[msg.sender][_tokenId] += _amount;

            // Check if the investor is already presenet in s_tokenIdToInvestors mapping
            bool isInvestorPresent = false;
            for (
                uint256 i = 0;
                i < s_tokenIdToInvestors[_tokenId].length;
                i++
            ) {
                if (s_tokenIdToInvestors[_tokenId][i] == msg.sender) {
                    isInvestorPresent = true;
                    break;
                }
            }
            // Update if this is a new investor
            if (!isInvestorPresent) {
                s_tokenIdToInvestors[_tokenId].push(msg.sender);
            }
            // Mint the required shares to the investor
            _mint(msg.sender, _tokenId, _amount, "");
        } catch {
            // Revert if the transfer fails following the Checks, effects, interactions model
            revert NormalRental__TRANSFER_FAILED_mint();
        }
    }

    //============================================================================================================//

    /**
     * Figure out what to do here.
     */
    function mintOffplanInstallments(
        uint256 _tokenId,
        uint256 _amountToOwn,
        uint256 _firstInstalment
    ) external {
        require(
            s_tokenIdToOffplanProperties[_tokenId].isOffplan = true,
            "Property not found"
        );
        require(_amountToOwn >= 1, "Max investment 1%");
        require(paused == false, "Minting Paused");
        require(
            s_tokenIdToInstallments[_tokenId].investor != msg.sender,
            "Already have instalments"
        );
        Property storage offplanProperty = s_tokenIdToOffplanProperties[
            _tokenId
        ];
        uint256 remainingsupplyOffplan = MAX_MINT_PER_PROPERTY -
            offplanProperty.amountGenerated;

        require(remainingsupplyOffplan >= _amountToOwn, "Not enough supply");
        require(
            i_usdt.balanceOf(msg.sender) >= (_firstInstalment * DECIMALS),
            "Not enough balance"
        );

        try this.attemptTransfer(msg.sender, address(this), _firstInstalment) {
            uint256 newAmountGeneratedOffplan = offplanProperty
                .amountGenerated + _firstInstalment;
            offplanProperty.amountGenerated = newAmountGeneratedOffplan;
            offplanProperty.amountMinted += _amountToOwn;

            uint256 amountToPay = (offplanProperty.price * _amountToOwn) / 100;
            uint256 remainingInstalments = amountToPay - _firstInstalment;

            s_tokenIdToInstallments[_tokenId].investor = msg.sender;
            s_tokenIdToInstallments[_tokenId]
                .remainingInstalmentsAmount = remainingInstalments;

            bool isInvestorPresent = false;
            for (
                uint256 i = 0;
                i < s_tokenIdToInvestors[_tokenId].length;
                i++
            ) {
                if (s_tokenIdToInvestors[_tokenId][i] == msg.sender) {
                    isInvestorPresent = true;
                    break;
                } else {
                    s_tokenIdToInvestors[_tokenId].push(msg.sender);
                }
            }
            _mint(msg.sender, _tokenId, _amountToOwn, "");
        } catch {
            revert NormalRental__TRANSFER_FAILED_mintOffplanInstalments();
        }
    }

    function payInstallments(uint256 _tokenId) external {}

    ///////////////////////////////////////////
    //              Testing Done             //
    ///////////////////////////////////////////
    function submitRent(
        uint256 _usdtAmount,
        uint256 _tokenId
    ) external onlyOwner {
        require(
            i_usdt.balanceOf(msg.sender) >= _usdtAmount,
            "Not enough Balance"
        );
        require(
            bytes(s_tokenIdToTokenURIs[_tokenId]).length != 0,
            "Property not found"
        );

        //Approve first in the front-end / scripts
        try this.attemptTransfer(msg.sender, address(this), _usdtAmount) {
            s_tokenIdToRentGenerated[_tokenId] += _usdtAmount;
        } catch {
            revert NormalRental__TRANSFER_FAILED_submitRent();
        }
    }

    ///////////////////////////////////////////
    //              Testing Done             //
    ///////////////////////////////////////////
    function distributeRent(uint256 _tokenId) external onlyOwner {
        require(s_tokenIdToRentGenerated[_tokenId] > 0, "Rent not generated");
        for (uint256 i = 0; i < s_tokenIdToInvestors[_tokenId].length; i++) {
            address investor = s_tokenIdToInvestors[_tokenId][i];
            uint256 amountToSend = s_userToTokenIdToShares[investor][_tokenId];
            i_usdt.safeTransfer(investor, amountToSend);
            s_userToTokenIdToShares[investor][_tokenId] -= amountToSend;
            s_tokenIdToRentGenerated[_tokenId] -= amountToSend;
        }
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    /** Helper functions */
    function attemptTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external {
        require(msg.sender == address(this), "contract call only");
        i_usdt.safeTransferFrom(_from, _to, _amount);
    }

    /** View and Pure functions */
    function uri(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return s_tokenIdToTokenURIs[_tokenId];
    }

    function _isValidUri(string memory _uri) internal pure returns (bool) {
        bytes memory startsWith = bytes("https://nft.brick");
        bytes memory endsWith = bytes(BASE_EXTENSION);
        bytes memory bytesUri = bytes(_uri);

        if (bytesUri.length < startsWith.length + endsWith.length) {
            return false;
        }

        for (uint256 i = 0; i < startsWith.length; i++) {
            if (bytesUri[i] != startsWith[i]) {
                return false;
            }
        }

        for (uint256 i = 0; i < endsWith.length; i++) {
            if (
                bytesUri[bytesUri.length - endsWith.length + i] != endsWith[i]
            ) {
                return false;
            }
        }

        return true;
    }

    function uniqueId(
        uint256 _seed,
        address _caller
    ) public view returns (uint256) {
        uint256 uniqueNumber = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    _caller,
                    _seed,
                    s_currentTokenID
                )
            )
        );

        return (uniqueNumber % 10 ** 20);
    }

    function getUsdtAddress() public view returns (IERC20) {
        return i_usdt;
    }

    function getTokenId() public view returns (uint256) {
        return s_currentTokenID;
    }

    function getProperties(
        uint256 _tokenId
    ) public view returns (Property memory) {
        return s_tokenIdToProperties[_tokenId];
    }

    function getInvestments(
        address _investor,
        uint256 _tokenId
    ) public view returns (uint256) {
        return s_userToTokenIdToShares[_investor][_tokenId];
    }

    function getInvestors(
        uint256 _tokenId
    ) public view returns (address[] memory) {
        return s_tokenIdToInvestors[_tokenId];
    }
}
