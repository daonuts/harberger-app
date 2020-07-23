# Harberger App
An Aragon app for owning harberger-controlled assets

## Instalation (rinkeby)
Four permissions need to be created for the Harberger app to function properly
* `PURCHASE_ROLE`
* `MINT_ROLE`
* `BURN_ROLE`
* `MODIFY_ROLE`

<br>

**Envoronment Variables**

```bash
f="--env aragon:rinkeby"
ANY_ADDRESS=0xffffffffffffffffffffffffffffffffffffffff
dao=0xFAfa30208Dc997de769Ed0B68c6e9d8fC368Cc01
tokenManager=0x4d81eea839ba43589a3276ae7c87f7a718540513
harberger=0xdf03805568546b1cb2fbec574da7a3d30a971489
voting=0x44e8067e7cbd2ce7051073e543ff6bd0b2acf78c
```

<br>

**Commands**

```bash
dao install $dao harberger-app.open.aragonpm.eth --app-init-args $tokenManager $f

dao acl create $dao $harberger PURCHASE_ROLE $ANY_ADDRESS $voting $f
dao acl create $dao $harberger MINT_ROLE $voting $voting $f
dao acl create $dao $harberger BURN_ROLE $voting $voting $f
dao acl create $dao $harberger MODIFY_ROLE $voting $voting $f
```