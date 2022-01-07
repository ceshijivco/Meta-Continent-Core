// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract METAHero721 is ERC721Enumerable, ERC721URIStorage, Ownable {
    using SafeMath for uint;
    using Address for address;
    using Strings for uint256;

    mapping(address => mapping(uint => uint)) public minters;
    address public superMinter;

    function setSuperMinter(address newSuperMinter_) public onlyOwner {
        superMinter = newSuperMinter_;
    }

    function setMinter(address newMinter_, uint cardId_, uint amount_) public onlyOwner {
        minters[newMinter_][cardId_] = amount_;
    }


    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct NFTBaseInfo {
        uint id;
        string name;
        string ipfs;
        uint currentAmount;
        uint totalAmount;
        string uri;

        uint hp;
        uint attack;
    }
    struct NFTInfo {
        uint id;
        uint hp;
        uint attack;
        string uri;
    }

    // 发行id => 初始信息
    mapping(uint => NFTBaseInfo) public NFTBaseInfoes;
    // Nftid => 铸造信息
    mapping(uint => uint) public nftIdMap;
    mapping(uint => NFTInfo) public NFTInfos;
    string public nftBaseURI;

    constructor(string memory name_, string memory symbol_, string memory baseURI_) ERC721(name_, symbol_) {
        nftBaseURI = baseURI_;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        nftBaseURI = baseURI_;
    }

    function newCard(string memory name_, uint nftBaseId_, uint totalAmount_, string memory ipfs_, string memory uri_, uint hp_, uint attack_) public onlyOwner {
        require(nftBaseId_ != 0 && NFTBaseInfoes[nftBaseId_].id == 0, "ERC721: wrong cardId");

        NFTBaseInfoes[nftBaseId_] = NFTBaseInfo({
            id : nftBaseId_,
            name : name_,
            ipfs: ipfs_,
            currentAmount : 0,
            totalAmount : totalAmount_,
            uri : uri_,

            hp : hp_,
            attack:attack_
        });
    }

    function updateCard(string memory name_, uint nftBaseId_, uint totalAmount_, string memory uri_) public onlyOwner {
        require(nftBaseId_ != 0 && NFTBaseInfoes[nftBaseId_].id != 0, "ERC721: wrong cardId");
        require(totalAmount_ > NFTBaseInfoes[nftBaseId_].currentAmount, "ERC721: maxAmount less than current amount");

        NFTBaseInfoes[nftBaseId_].name = name_;
        NFTBaseInfoes[nftBaseId_].totalAmount = totalAmount_;
        NFTBaseInfoes[nftBaseId_].uri = uri_;
    }

    function mint(address player_, uint nftBaseId_) public returns (uint256) {
        require(nftBaseId_ != 0 && NFTBaseInfoes[nftBaseId_].id != 0, "ERC721: wrong cardId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][nftBaseId_] > 0, "ERC721: not minter's calling");
            minters[_msgSender()][nftBaseId_] -= 1;
        }

        require(NFTBaseInfoes[nftBaseId_].currentAmount < NFTBaseInfoes[nftBaseId_].totalAmount, "ERC721: Token amount is out of limit");
        NFTBaseInfoes[nftBaseId_].currentAmount += 1;

        _tokenIds.increment();
        uint tokenId = _tokenIds.current();

        nftIdMap[tokenId] = nftBaseId_;
        _mint(player_, tokenId);

        return tokenId;
    }

    function mintMulti(address player_, uint nftBaseId_, uint amount_) public returns (uint256) {
        require(amount_ > 0, "ERC721: missing amount");
        require(nftBaseId_ != 0 && NFTBaseInfoes[nftBaseId_].id != 0, "ERC721: wrong cardId");

        if (superMinter != _msgSender()) {
            require(minters[_msgSender()][nftBaseId_] >= amount_, "ERC721: not minter's calling");
            minters[_msgSender()][nftBaseId_] -= amount_;
        }

        require(NFTBaseInfoes[nftBaseId_].totalAmount.sub(NFTBaseInfoes[nftBaseId_].currentAmount) >= amount_, "ERC721: Token amount is out of limit");
        NFTBaseInfoes[nftBaseId_].currentAmount += amount_;

        uint tokenId;
        for (uint i = 0; i < amount_; ++i) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();

            nftIdMap[tokenId] = nftBaseId_;
            _mint(player_, tokenId);

        }

        return tokenId;

    }

    function burn(uint tokenId_) public returns (bool){
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "ERC721: burn caller is not owner nor approved");

        delete nftIdMap[tokenId_];
        _burn(tokenId_);
        return true;
    }

    function burnMulti(uint[] calldata tokenIds_) public returns (bool){
        for (uint i = 0; i < tokenIds_.length; ++i) {
            uint tokenId_ = tokenIds_[i];
            require(_isApprovedOrOwner(_msgSender(), tokenId_), "ERC721: burn caller is not owner nor approved");

            delete nftIdMap[tokenId_];
            _burn(tokenId_);
        }
        return true;
    }


    // for inherit                      
    function _burn (uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        ERC721URIStorage._burn(tokenId);            
    }
    function _beforeTokenTransfer (address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return interfaceId == type(IERC721).interfaceId
        || interfaceId == type(IERC721Enumerable).interfaceId
        || interfaceId == type(IERC721Metadata).interfaceId
        || super.supportsInterface(interfaceId);
    }
    function tokenURI(uint256 tokenId_) override(ERC721URIStorage, ERC721) public view returns (string memory) {
        require(_exists(tokenId_), "ERC721Metadata: URI query for nonexistent token");

        string memory URI = NFTBaseInfoes[nftIdMap[tokenId_]].uri;
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, URI)) : URI;
    }
    function _baseURI() internal view override returns (string memory) {
        return nftBaseURI;
    }
}