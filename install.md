# Installation

1. Put `tss_bridge`, `oxmysql` and `tss-inventory` in your server's resources folder. Ensuring Youre on the latest **Release** of `tss_bridge`
2. Ensure the resources in `server.cfg` are in this order:

```cfg
ensure oxmysql
ensure tss_bridge
ensure tss-inventory
```

3. Restart your server. The inventory creates its database tables automatically.

Once your character is loaded, press **TAB** to open the inventory.

If another resource handles weapons or clothing, disable the matching built-in system in `config.lua`.

