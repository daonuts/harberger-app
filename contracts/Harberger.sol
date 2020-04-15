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
    event Balance(uint indexed _tokenId, uint _balance, uint64 _expiration);
    event Price(uint indexed _tokenId, uint _price);
    event MetaURI(uint indexed _tokenId, string _metaURI);
    event OwnerURI(uint indexed _tokenId, string _ownerURI);
    event Tax(uint indexed _tokenId, uint24 _tax);
    event DEBUG(string a);

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
    string private constant ERROR_AMOUNT = "INSUFFICIENT_AMOUNT";
    string private constant ERROR_BALANCE = "INSUFFICIENT_BALANCE";
    string private constant ERROR_PERMISSION = "NO_PERMISSION";
    string private constant ERROR_TOKEN_TRANSFER = "TOKEN_TRANSFER_FAILED";
    string private constant ERROR_INVALID_TOKEN = "INVALID_TOKEN";
    string private constant ERROR_NOT_OWNER = "NOT_OWNER";

    function initialize(address _currencyManager) onlyInit public {
        initialized();

        currencyManager = TokenManager(_currencyManager);
        currency = Token(currencyManager.token());
    }

    function tokensReceived(
        address _operator, address _from, address _to, uint _amount, bytes _data, bytes _operatorData
    ) external {
        require( msg.sender == address(currency), ERROR_INVALID_TOKEN );

        uint8 action = uint8(_data[0]);
        if( action == 1 ) {           // buy
            _buy(_from, _amount, _data);
        } else if( action == 2 ){     // credit
            bytes memory data = _data;
            uint tokenId;
            // first byte of data should have action as uint8
            assembly {
              tokenId := mload(add(data, 33))
            }
            require( _from == assets[tokenId].owner, ERROR_NOT_OWNER );
            _credit(tokenId, _amount);
        } else {
          revert("UNKNOWN_ACTION");
        }
    }

    /**
     * @notice Purchase asset:`_tokenId`, set price=`_price` uri=`_ownerURI` credit=`_credit`
     * @param _tokenId Asset tokenId
     * @param _price Set new price
     * @param _ownerURI Set new ownerURI (if applicable)
     */
    function buy(uint _tokenId, uint _price, string _ownerURI, uint _credit) external {
        Asset storage asset = assets[_tokenId];
        // settle existing
        collectTax(_tokenId);
        // payment
        require(currency.transferFrom(msg.sender, asset.owner, asset.price), ERROR_TOKEN_TRANSFER);
        // transfer
        _transfer(_tokenId, msg.sender, _price, _ownerURI);
        // credit
        credit(_tokenId, _credit, true);
    }

    function _buy(address _from, uint _amount, bytes _data) internal {
        uint tokenId;
        uint newPrice;
        uint credit;
        string memory ownerURI;
        (tokenId, newPrice, credit, ownerURI) = extractBuyParameters(_data);

        Asset storage asset = assets[tokenId];

        // settle existing
        collectTax(tokenId);
        // check price didn't change (eg. front-running)
        uint cost = asset.price;
        require(_amount >= cost.add(credit), ERROR_AMOUNT);
        // payment to current owner
        if(cost > 0)
          require(currency.transfer(asset.owner, cost), ERROR_TOKEN_TRANSFER);
        // transfer (buyer = _from)
        _transfer(tokenId, _from, newPrice, ownerURI);
        // just credit remaining
        _credit(tokenId, _amount.sub(cost));
    }

    function extractBuyParameters(bytes _data) public view returns (uint tokenId, uint newPrice, uint credit, string ownerURI) {
        bytes memory data = _data;

        // first byte of data should have action as uint8
        assembly {
          tokenId := mload(add(data, 33))
          newPrice := mload(add(data, 65))
          credit := mload(add(data, 97))
        }

        bytes memory uri = new bytes(data.length.sub(97));
        for (uint i=0;i<uri.length;i++){
          uri[i] = data[i+97];
        }
        ownerURI = string(uri);
    }

    function _transfer(uint _tokenId, address _to, uint _price, string _ownerURI) internal {
        require(canPerform(_to, PURCHASE_ROLE, new uint256[](0)), ERROR_PERMISSION);

        Asset storage asset = assets[_tokenId];
        require(asset.active, ERROR_PERMISSION);

        if(asset.owner != address(this))
          _refund(_tokenId);

        address from = asset.owner;
        // new ownership
        asset.owner = _to;
        asset.price = _price;
        asset.ownerURI = _ownerURI;
        asset.lastPaymentDate = getTimestamp64();

        emit Transfer(from, _to, _tokenId);
        emit Price(_tokenId, _price);
        emit OwnerURI(_tokenId, _ownerURI);
    }

    /**
     * @notice Collect any tax due for asset:`_tokenId`
     * @param _tokenId Asset tokenId
     */
    function collectTax(uint _tokenId) public {
        Asset storage asset = assets[_tokenId];
        if(asset.owner == address(this))
          return;
        uint amount = taxDue(_tokenId);
        if(amount > asset.balance) {
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
        if(asset.balance > taxDue(_tokenId))
          return asset.owner;
        else
          return address(this);
    }

    function taxDue(uint _tokenId) public view returns (uint) {
        Asset storage asset = assets[_tokenId];
        uint dailyTax = asset.price.mul(asset.tax).div(100*1000);
        /* uint numDays = getTimestamp64().sub(asset.lastPaymentDate).div(1 days); */
        /* return dailyTax.mul(numDays); */
        return dailyTax.mul(getTimestamp().sub(asset.lastPaymentDate)).div(1 days);
    }

    /**
     * @notice Set price of asset:`_tokenId` (only asset owner)
     * @param _tokenId Asset tokenId
     * @param _price New price
     */
    function setPrice(uint _tokenId, uint _price) public {
        collectTax(_tokenId);
        Asset storage asset = assets[_tokenId];
        require(msg.sender == asset.owner, ERROR_NOT_OWNER);
        asset.price = _price;
        emit Price(_tokenId, _price);
        emit Balance(_tokenId, asset.balance, balanceExpiration(_tokenId));
    }

    /**
     * @notice Set ownerURI associated with asset:`_tokenId` (only asset owner)
     * @param _tokenId Asset tokenId
     * @param _ownerURI New ownerURI
     */
    function setOwnerURI(uint _tokenId, string _ownerURI) public {
        Asset storage asset = assets[_tokenId];
        require(msg.sender == asset.owner, ERROR_NOT_OWNER);
        asset.ownerURI = _ownerURI;
        emit OwnerURI(_tokenId, _ownerURI);
    }

    function balanceExpiration(uint _tokenId) public view returns (uint64){
        Asset storage asset = assets[_tokenId];
        /* uint tax = taxDue(_tokenId); */
        /* lastPaymentDate */
        uint dailyTax = asset.price.mul(asset.tax).div(100*1000);
        uint time = asset.balance.mul(1 days).div(dailyTax);
        return asset.lastPaymentDate.add(uint64(time));
    }

    /**
     * @notice Add `_amount` credit to asset:`_tokenId`
     * @param _tokenId Asset tokenId
     * @param _amount Amount to credit
     * @param _onlyIfSelfOwned Only complete if sender is owner
     */
    function credit(uint _tokenId, uint _amount, bool _onlyIfSelfOwned) public {
        if(_onlyIfSelfOwned)
          require(msg.sender == assets[_tokenId].owner, ERROR_NOT_OWNER);

        require(currency.transferFrom(msg.sender, address(this), _amount), ERROR_TOKEN_TRANSFER);
        _credit(_tokenId, _amount);
    }

    function _credit(uint _tokenId, uint _amount) public {
        Asset storage asset = assets[_tokenId];

        asset.balance = asset.balance.add(_amount);
        // minimum balance amount is 1 day of tax
        require(asset.balance > asset.price.mul(asset.tax).div(100*1000), ERROR_BALANCE);
        emit Balance(_tokenId, asset.balance, balanceExpiration(_tokenId));
    }

    /**
     * @notice Claim refund of `_amount` for asset:`_tokenId`
     * @param _tokenId Asset tokenId
     * @param _amount Amount to credit
     */
    function debit(uint _tokenId, uint _amount) public {
        Asset storage asset = assets[_tokenId];
        collectTax(_tokenId);
        require(msg.sender == asset.owner, ERROR_NOT_OWNER);
        require(_amount <= asset.balance, ERROR_BALANCE);
        require(currency.transfer(msg.sender, _amount), ERROR_TOKEN_TRANSFER);
        asset.balance = asset.balance.sub(_amount);
        emit Balance(_tokenId, asset.balance, balanceExpiration(_tokenId));
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
