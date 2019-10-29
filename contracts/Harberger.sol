pragma solidity ^0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "@aragon/os/contracts/lib/math/SafeMath64.sol";

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

contract Harberger is AragonApp {
    using SafeMath for uint;
    using SafeMath64 for uint64;

    struct Asset {
        address owner;
        uint64  lastPaymentDate;
        uint24  tax;
        uint    price;
        uint    balance;
        string  metaURI;
        string  ownerURI;
    }

    /// Events
    event Transfer(address indexed _from, address indexed _to, uint indexed _tokenId);
    event Balance(uint indexed _tokenId, uint _balance);
    event Price(uint indexed _tokenId, uint _price);
    event MetaURI(uint indexed _tokenId, string _metaURI);
    event OwnerURI(uint indexed _tokenId, string _ownerURI);
    event Tax(uint indexed _tokenId, uint24 _tax);

    /// State
    mapping(uint => Asset) public assets;
    uint public assetsCount;
    TokenManager public currencyManager;
    MiniMeToken public currency;

    uint24 public constant PCT = 1000;

    /// ACL
    bytes32 public constant PURCHASE_ROLE = keccak256("PURCHASE_ROLE");
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");
    bytes32 public constant MODIFY_ROLE = keccak256("MODIFY_ROLE");

    // Errors
    string private constant ERROR = "ERROR";
    string private constant ERROR_BALANCE = "BALANCE";
    string private constant ERROR_PERMISSION = "PERMISSION";
    string private constant ERROR_TOKEN_TRANSFER = "TOKEN_TRANSFER";

    function initialize(address _currencyManager) onlyInit public {
        initialized();

        currencyManager = TokenManager(_currencyManager);
        currency = currencyManager.token();
    }

    /**
     * @notice Purchase asset:`_tokenId`, set price=`_price` uri=`_ownerURI` credit=`_credit`
     * @param _tokenId Asset tokenId
     * @param _price Set new price
     * @param _ownerURI Set new ownerURI (if applicable)
     */
    function buy(uint _tokenId, uint _price, string _ownerURI, uint _credit) auth(PURCHASE_ROLE) external {
        Asset storage asset = assets[_tokenId];
        if(asset.owner != address(this)) {
          payTax(_tokenId);
        }

        _transferFrom(asset.owner, msg.sender, _tokenId);
        // require min balance of 1 day of tax
        require(_credit > _price.mul(asset.tax).div(100*PCT), ERROR_BALANCE);
        credit(_tokenId, _credit, true);
        asset.price = _price;
        asset.ownerURI = _ownerURI;
        asset.lastPaymentDate = getTimestamp64();
    }

    /**
     * @notice Pay any tax due for asset:`_tokenId`
     * @param _tokenId Asset tokenId
     */
    function payTax(uint _tokenId) public {
        Asset storage asset = assets[_tokenId];
        uint amount = taxDue(_tokenId);
        if(amount > asset.balance) {
          amount = asset.balance;
          _reclaim(_tokenId);
        } else if(amount > 0){
          asset.balance = asset.balance.sub(amount);
          currencyManager.burn(address(this), amount);
          asset.lastPaymentDate = getTimestamp64();
        }
    }

    function _transferFrom(address _from, address _to, uint _tokenId) internal {
        Asset storage asset = assets[_tokenId];

        require(_to != address(0), ERROR_PERMISSION);
        require(_from == asset.owner, ERROR_PERMISSION);

        // current owner can transfer
        // if initiated by non-owner
        if(asset.owner != msg.sender) {
          // ...owner must sell at asset.price (Harberger rules)
          require(currency.transferFrom(msg.sender, asset.owner, asset.price), ERROR_TOKEN_TRANSFER);
        }

        _refund(_tokenId);

        asset.owner = _to;

        emit Transfer(_from, _to, _tokenId);
    }

    function _reclaim(uint _tokenId) internal {
        Asset storage asset = assets[_tokenId];
        currencyManager.burn(address(this), asset.balance);
        delete asset.balance;
        asset.owner = address(this);
        delete asset.price;
        delete asset.ownerURI;
        delete asset.lastPaymentDate;
        emit Transfer(asset.owner, address(this), _tokenId);
        emit Price(_tokenId, asset.price);
        emit OwnerURI(_tokenId, asset.ownerURI);
    }

    function _refund(uint _tokenId) internal {
        Asset storage asset = assets[_tokenId];
        uint refund = asset.balance;
        delete asset.balance;
        require(currency.transfer(asset.owner, refund), ERROR_TOKEN_TRANSFER);
    }

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint _tokenId) external view returns (address) {
        /* TODO owner reverts to `this` or 0x0 if taxDue is greater than balance `!hasSurplusBalance` */
        return assets[_tokenId].owner;
    }

    function taxDue(uint _tokenId) public view returns (uint) {
        Asset storage asset = assets[_tokenId];
        uint dailyTax = asset.price.mul(asset.tax).div(100*PCT);
        uint numDays = getTimestamp64().sub(asset.lastPaymentDate).div(1 days);
        return dailyTax.mul(numDays);
    }

    function dayTax(uint _tokenId) public view returns (uint) {
        Asset storage asset = assets[_tokenId];
        return asset.price.mul(asset.tax).div(100*PCT);
    }

    function numDays(uint _tokenId) public view returns (uint64) {
        Asset storage asset = assets[_tokenId];
        return getTimestamp64().sub(asset.lastPaymentDate).div(1 days);
    }

    function hasSurplusBalance(uint _tokenId) public view returns (bool) {
        return assets[_tokenId].balance > taxDue(_tokenId);
    }

    /**
     * @notice Set price of asset:`_tokenId` (only asset owner)
     * @param _tokenId Asset tokenId
     * @param _price New price
     */
    function setPrice(uint _tokenId, uint _price) public {
        payTax(_tokenId);
        Asset storage asset = assets[_tokenId];
        require(msg.sender == asset.owner, ERROR_PERMISSION);
        asset.price = _price;
        emit Price(_tokenId, _price);
    }

    /**
     * @notice Set ownerURI associated with asset:`_tokenId` (only asset owner)
     * @param _tokenId Asset tokenId
     * @param _ownerURI New ownerURI
     */
    function setOwnerURI(uint _tokenId, string _ownerURI) public {
        Asset storage asset = assets[_tokenId];
        require(msg.sender == asset.owner, ERROR_PERMISSION);
        asset.ownerURI = _ownerURI;
        emit OwnerURI(_tokenId, _ownerURI);
    }

    /**
     * @notice Add `_amount` credit to asset:`_tokenId`
     * @param _tokenId Asset tokenId
     * @param _amount Amount to credit
     * @param _onlyIfSelfOwned Only complete if sender is owner
     */
    function credit(uint _tokenId, uint _amount, bool _onlyIfSelfOwned) public {
        Asset storage asset = assets[_tokenId];
        if(_onlyIfSelfOwned)
          require(msg.sender == asset.owner, ERROR_PERMISSION);

        require(currency.transferFrom(msg.sender, address(this), _amount), ERROR_TOKEN_TRANSFER);
        asset.balance = asset.balance.add(_amount);
        emit Balance(_tokenId, asset.balance);
    }

    /**
     * @notice Claim refund of `_amount` for asset:`_tokenId`
     * @param _tokenId Asset tokenId
     * @param _amount Amount to credit
     */
    function debit(uint _tokenId, uint _amount) public {
        Asset storage asset = assets[_tokenId];
        payTax(_tokenId);
        require(msg.sender == asset.owner, ERROR_PERMISSION);
        require(_amount <= asset.balance, ERROR_BALANCE);
        require(currency.transfer(msg.sender, _amount), ERROR_TOKEN_TRANSFER);
        asset.balance = asset.balance.sub(_amount);
        emit Balance(_tokenId, asset.balance);
    }

    /**
     * @notice Mint a new asset: tax:`_tax`
     * @param _metaURI Asset description uri
     * @param _tax Tax
     */
    function mint(string _metaURI, uint24 _tax) auth(MINT_ROLE) external {
        uint _tokenId = assetsCount++;
        Asset storage asset = assets[_tokenId];
        asset.owner = address(this);
        asset.metaURI = _metaURI;
        asset.tax = _tax;
        emit Transfer(address(0), address(this), _tokenId);
    }

    /**
     * @notice Burn asset:`_tokenId`
     * @param _tokenId Asset tokenId
     */
    function burn(uint _tokenId) auth(BURN_ROLE) external {
        Asset storage asset = assets[_tokenId];
        payTax(_tokenId);
        _refund(_tokenId);
        delete assets[_tokenId];
        emit Transfer(asset.owner, address(0), _tokenId);
    }

    /**
     * @notice Set asset tax
     * @param _tokenId Asset tokenId
     * @param _tax New tax
     */
    function setTax(uint _tokenId, uint24 _tax) auth(MODIFY_ROLE) external {
        Asset storage asset = assets[_tokenId];
        if(asset.owner != address(this))
          payTax(_tokenId);
        asset.tax = _tax;
        emit Tax(_tokenId, _tax);
    }

    /**
     * @notice Set asset metaURI
     * @param _tokenId Asset tokenId
     * @param _metaURI New metaURI
     */
    function setMetaURI(uint _tokenId, string _metaURI) auth(MODIFY_ROLE) external {
        Asset storage asset = assets[_tokenId];
        asset.metaURI = _metaURI;
        emit MetaURI(_tokenId, _metaURI);
    }
}
