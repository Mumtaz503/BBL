// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NormalRental is ERC1155, Ownable {
    error NormalRental__TRANSFER_FAILED();

    IERC20 private immutable i_usdt;
    struct Property {
        uint256 id;
        uint256 price;
        address owner;
        uint256 amountMinted;
        uint256 amountGenerated;
        uint256 timestamp;
    }

    string private constant BASE_EXTENSION = ".json";
    string public s_baseURI = "";
    uint256 private s_currentTokenID;
    bool public paused = true;
    uint256 public constant MAX_MINT_PER_PROPERTY = 100;
    uint256 public constant DECIMALS = 10 ** 6;
    // address tokenAddress = address(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);

    mapping(uint256 => string) private s_tokenIdToTokenURIs;
    mapping(uint256 => Property) private s_tokenIdToProperties;
    mapping(uint256 => uint256) private s_tokenIdToRentGenerated;

    ///////////////////////////////////////////
    //              Testing Done             //
    ///////////////////////////////////////////
    constructor(address _usdtAddress) ERC1155("") Ownable(msg.sender) {
        i_usdt = IERC20(_usdtAddress);
        s_currentTokenID = 0;
    }

    ///////////////////////////////////////////
    //              Testing Done             //
    ///////////////////////////////////////////
    function addProperty(
        string memory _uri,
        uint256 _price,
        uint256 _seed
    ) external onlyOwner {
        // Possible block timestamp manipulation vulnerability here.
        // Need to add a check for valid tokenURIs.
        /**
         * Must convert the uri in the hash form
         * and check if the starting of that hash is the same as
         * the hash of "ipfs://"
         */

        require(_price > 0 && _seed > 0, "Please enter appropriate values");
        uint256 newTokenID = uniqueId(_seed, msg.sender);
        s_currentTokenID = newTokenID;
        uint256 priceDecimals = _price * DECIMALS;

        s_tokenIdToProperties[newTokenID] = Property({
            id: newTokenID,
            price: priceDecimals,
            owner: msg.sender,
            amountMinted: 0, //Shares in %
            amountGenerated: 0, // amount in usdt
            timestamp: block.timestamp
        });

        s_tokenIdToTokenURIs[newTokenID] = _uri;
    }

    function mint(uint256 tokenId, uint256 amount) external {
        Property storage property = s_tokenIdToProperties[tokenId];
        uint256 _remainingSupply = MAX_MINT_PER_PROPERTY -
            property.amountMinted;

        require(_remainingSupply > 0, "Not enough supply left");
        uint256 usdtAmount = (property.price * amount) / 100;

        require(
            i_usdt.balanceOf(msg.sender) > usdtAmount,
            "Not enough balance"
        );
        i_usdt.transferFrom(msg.sender, address(this), usdtAmount);
        uint256 _newAmoutnGenerated = property.amountGenerated + usdtAmount;

        _mint(msg.sender, tokenId, amount, "");

        property.amountGenerated = _newAmoutnGenerated;
        property.amountMinted += 1;
    }

    function submitRent(
        uint256 _usdtAmount,
        uint256 _tokenId
    ) external onlyOwner {
        require(
            i_usdt.balanceOf(msg.sender) >= _usdtAmount,
            "Not enough Balance"
        );
        require(
            keccak256(bytes(s_tokenIdToTokenURIs[_tokenId])).length != 0,
            "Property not found"
        );

        bool success = i_usdt.transferFrom(
            msg.sender,
            address(this),
            _usdtAmount
        );

        if (success) {
            s_tokenIdToRentGenerated[_tokenId] += _usdtAmount;
        } else {
            revert NormalRental__TRANSFER_FAILED();
        }
    }

    function _automatedRentDistribution(
        uint256 responseId,
        bytes calldata /*response*/
    ) internal {}

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    /** View and Pure helper functions */
    function uri(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return s_tokenIdToTokenURIs[_tokenId];
    }

    function _isValidUri(string memory _uri) internal view returns (bool) {
        bytes32 startsWith = keccak256(bytes("ipfs://"));
        bytes32 endsWith = keccak256(bytes(BASE_EXTENSION));

        // if(keccak256(bytes(_uri)))
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

        return uniqueNumber;
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
}
