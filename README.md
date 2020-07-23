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
dao=
tokenManager=
voting=
harberger=
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
