/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 *
 * This file requires contract dependencies which are licensed as
 * GPL-3.0-or-later, forcing it to also be licensed as such.
 *
 * This is the only file in your project that requires this license and
 * you are free to choose a different license for the rest of the project.
 */

pragma solidity 0.4.24;

import "@aragon/os/contracts/factory/DAOFactory.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";
import "@aragon/os/contracts/apm/APMNamehash.sol";

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";
import "@daonuts/token/contracts/Token.sol";

import "./Harberger.sol";


contract TemplateBase is APMNamehash {
    ENS public ens;
    DAOFactory public fac;

    event DeployDao(address dao);
    event InstalledApp(address appProxy, bytes32 appId);

    constructor(DAOFactory _fac, ENS _ens) public {
        ens = _ens;

        // If no factory is passed, get it from on-chain bare-kit
        if (address(_fac) == address(0)) {
            bytes32 bareKit = apmNamehash("bare-kit");
            fac = TemplateBase(latestVersionAppBase(bareKit)).fac();
        } else {
            fac = _fac;
        }
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }
}


contract Template is TemplateBase {
    /* MiniMeTokenFactory tokenFactory; */

    uint constant TOKEN_UNIT = 10 ** 18;
    uint64 constant PCT = 10 ** 16;
    address constant ANY_ENTITY = address(-1);

    constructor(ENS ens) TemplateBase(DAOFactory(0), ens) public {
        /* tokenFactory = new MiniMeTokenFactory(); */
    }

    function newInstance() public {
        Kernel dao = fac.newDAO(this);
        ACL acl = ACL(dao.acl());
        acl.createPermission(this, dao, dao.APP_MANAGER_ROLE(), this);

        address root = msg.sender;
        bytes32 harbergerAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("harberger-app")));
        bytes32 tokenManagerAppId = apmNamehash("token-manager");

        Harberger harberger = Harberger(dao.newAppInstance(harbergerAppId, latestVersionAppBase(harbergerAppId)));
        TokenManager tokenManager = TokenManager(dao.newAppInstance(tokenManagerAppId, latestVersionAppBase(tokenManagerAppId)));

        /* MiniMeToken token = tokenFactory.createCloneToken(MiniMeToken(0), 0, "Currency", 18, "CURRENCY", true); */
        Token token = new Token("Currency", 18, "CURRENCY", true);
        token.changeController(tokenManager);

        // Initialize apps
        tokenManager.initialize(MiniMeToken(token), true, 0);
        emit InstalledApp(tokenManager, tokenManagerAppId);
        harberger.initialize(tokenManager);
        emit InstalledApp(harberger, harbergerAppId);

        acl.createPermission(ANY_ENTITY, harberger, harberger.PURCHASE_ROLE(), root);
        acl.createPermission(ANY_ENTITY, harberger, harberger.MINT_ROLE(), root);
        acl.createPermission(root, harberger, harberger.BURN_ROLE(), root);
        acl.createPermission(ANY_ENTITY, harberger, harberger.MODIFY_ROLE(), root);
        acl.createPermission(ANY_ENTITY, tokenManager, tokenManager.MINT_ROLE(), root);
        acl.createPermission(harberger, tokenManager, tokenManager.BURN_ROLE(), root);

        tokenManager.mint(root, 1000000*TOKEN_UNIT);
        tokenManager.mint(0x8401Eb5ff34cc943f096A32EF3d5113FEbE8D4Eb, 1000000*TOKEN_UNIT);
        tokenManager.mint(0x306469457266CBBe7c0505e8Aad358622235e768, 1000000*TOKEN_UNIT);
        harberger.mint("ipfs:QmZP8YzJ5fDsk7nqtugfRzTgq38JsJUVxniJ3QCLgGyetd", 1000);

        // Clean up permissions
        acl.grantPermission(root, dao, dao.APP_MANAGER_ROLE());
        acl.revokePermission(this, dao, dao.APP_MANAGER_ROLE());
        acl.setPermissionManager(root, dao, dao.APP_MANAGER_ROLE());

        acl.grantPermission(root, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.revokePermission(this, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.setPermissionManager(root, acl, acl.CREATE_PERMISSIONS_ROLE());

        emit DeployDao(dao);
    }

}
