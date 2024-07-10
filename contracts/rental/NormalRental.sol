// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NormalRental is ERC1155, Ownable {
    error NormalRental__TRANSFER_FAILED_submitRent();
    error NormalRental__TRANSFER_FAILED_mint();
    error NormalRental__TRANSFER_FAILED_distributeRent();

    using SafeERC20 for IERC20;

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
    uint256 private s_currentTokenID;
    bool public paused = false;
    uint256 public constant MAX_MINT_PER_PROPERTY = 100;
    uint256 public constant DECIMALS = 10 ** 6;

    mapping(uint256 => string) private s_tokenIdToTokenURIs;
    mapping(uint256 => Property) private s_tokenIdToProperties;
    mapping(uint256 => uint256) private s_tokenIdToRentGenerated;
    mapping(address => mapping(uint256 => uint256))
        private s_userToTokenIdToShares;
    mapping(uint256 => address[]) private s_tokenIdToInvestors;

    event PropertyMinted(uint256 indexed tokenId_);

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
        require(_isValidUri(_uri), "Please place a valid URI");
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
        emit PropertyMinted(newTokenID);
    }

    ///////////////////////////////////////////
    //              Testing Done             //
    ///////////////////////////////////////////
    function mint(uint256 _tokenId, uint256 _amount) external {
        require(paused == false, "Minting Paused");
        require(_amount >= 1, "Min investment 1%");
        Property storage property = s_tokenIdToProperties[_tokenId];
        uint256 remainingSupply = MAX_MINT_PER_PROPERTY - property.amountMinted;

        require(remainingSupply >= _amount, "Not enough supply left");
        uint256 usdtAmount = (property.price * _amount) / 100;

        require(
            i_usdt.balanceOf(msg.sender) > usdtAmount,
            "Not enough balance"
        );

        //Approve first in the front-end / scripts
        try this.attemptTransfer(msg.sender, address(this), usdtAmount) {
            uint256 _newAmoutnGenerated = property.amountGenerated + usdtAmount;
            property.amountGenerated = _newAmoutnGenerated;
            property.amountMinted += _amount;
            s_userToTokenIdToShares[msg.sender][_tokenId] += _amount;

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
            if (!isInvestorPresent) {
                s_tokenIdToInvestors[_tokenId].push(msg.sender);
            }
            _mint(msg.sender, _tokenId, _amount, "");
        } catch {
            revert NormalRental__TRANSFER_FAILED_mint();
        }
    }

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
        bytes memory startsWith = bytes("ipfs://");
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
