pragma solidity ^0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "@aragon/os/contracts/lib/math/SafeMath64.sol";

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@daonuts/token/contracts/Token.sol";

contract Harberger is AragonApp {
    using SafeMath for uint;
    using SafeMath64 for uint64;

    struct Asset {
        bool    active;
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
    Token public currency;

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
        currency = Token(currencyManager.token());
    }

    /**
     * @notice Purchase asset:`_tokenId`, set price=`_price` uri=`_ownerURI` credit=`_credit`
     * @param _tokenId Asset tokenId
     * @param _price Set new price
     * @param _ownerURI Set new ownerURI (if applicable)
     */
    function buy(uint _tokenId, uint _price, string _ownerURI, uint _credit) auth(PURCHASE_ROLE) external {
        Asset storage asset = assets[_tokenId];
        require(asset.active, ERROR_PERMISSION);

        // settle existing
        collectTax(_tokenId);
        if(asset.owner != address(this))
          _refund(_tokenId);

        // payment
        address seller = asset.owner;
        require(currency.transferFrom(msg.sender, seller, asset.price), ERROR_TOKEN_TRANSFER);

        // new ownership
        asset.owner = msg.sender;
        asset.price = _price;
        asset.ownerURI = _ownerURI;
        asset.lastPaymentDate = getTimestamp64();
        credit(_tokenId, _credit, true);

        emit Transfer(seller, msg.sender, _tokenId);
    }

    /**
     * @notice Collect any tax due for asset:`_tokenId`
     * @param _tokenId Asset tokenId
     */
    function collectTax(uint _tokenId) public {
        Asset storage asset = assets[_tokenId];
        if(asset.owner == address(this))
          return;
        uint amount = tax(_tokenId);
        if(amount > asset.balance) {
          amount = asset.balance;
          _reclaim(_tokenId);
        } else if(amount > 0){
          asset.balance = asset.balance.sub(amount);
          currencyManager.burn(address(this), amount);
          asset.lastPaymentDate = getTimestamp64();
        }
    }

    function _reclaim(uint _tokenId) internal {
        Asset storage asset = assets[_tokenId];
        uint balance = asset.balance;
        address delinquent = asset.owner;
        asset.owner = address(this);
        delete asset.balance;
        delete asset.price;
        delete asset.ownerURI;
        delete asset.lastPaymentDate;
        currencyManager.burn(address(this), balance);
        emit Transfer(delinquent, address(this), _tokenId);
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
        Asset storage asset = assets[_tokenId];
        if(asset.balance > tax(_tokenId))
          return asset.owner;
        else
          return address(this);
    }

    function tax(uint _tokenId) public view returns (uint) {
        Asset storage asset = assets[_tokenId];
        uint dailyTax = asset.price.mul(asset.tax).div(100*1000);
        uint numDays = getTimestamp64().sub(asset.lastPaymentDate).div(1 days);
        return dailyTax.mul(numDays);
    }

    /**
     * @notice Set price of asset:`_tokenId` (only asset owner)
     * @param _tokenId Asset tokenId
     * @param _price New price
     */
    function setPrice(uint _tokenId, uint _price) public {
        collectTax(_tokenId);
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
        // minimum credit amount is 1 day of tax
        require(_amount > asset.price.mul(asset.tax).div(100*1000), ERROR_BALANCE);
        asset.balance = asset.balance.add(_amount);
        require(currency.transferFrom(msg.sender, address(this), _amount), ERROR_TOKEN_TRANSFER);
        emit Balance(_tokenId, asset.balance);
    }

    /**
     * @notice Claim refund of `_amount` for asset:`_tokenId`
     * @param _tokenId Asset tokenId
     * @param _amount Amount to credit
     */
    function debit(uint _tokenId, uint _amount) public {
        Asset storage asset = assets[_tokenId];
        collectTax(_tokenId);
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
        uint _tokenId = ++assetsCount;
        Asset storage asset = assets[_tokenId];
        asset.active = true;
        asset.owner = address(this);
        asset.tax = _tax;
        asset.metaURI = _metaURI;
        emit Transfer(address(0), address(this), _tokenId);
    }

    /**
     * @notice Burn asset:`_tokenId`
     * @param _tokenId Asset tokenId
     */
    function burn(uint _tokenId) auth(BURN_ROLE) external {
        Asset storage asset = assets[_tokenId];
        collectTax(_tokenId);
        if(asset.owner != address(this))
          _refund(_tokenId);
        emit Transfer(asset.owner, address(0), _tokenId);
        delete assets[_tokenId];
    }

    /**
     * @notice Set asset tax
     * @param _tokenId Asset tokenId
     * @param _tax New tax
     */
    function setTax(uint _tokenId, uint24 _tax) auth(MODIFY_ROLE) external {
        Asset storage asset = assets[_tokenId];
        collectTax(_tokenId);
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
