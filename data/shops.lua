TSSShops = TSSShops or {
    example_shop = {
        label = "McKleans Emporium",
        coords = vector4(24.47,-1346.62,28.50,266.0), -- Legion Square 24/7; ped ground position
        distance = 3.0,
        account = 'cash', -- bridge player money account, not the cash inventory item
        pedModel = 'ig_bankman', --if supplied then spawn a ped at location and use target entity else use a circle zone
        size = { x = 8 }, -- rows are calculated automatically; minimum 2,
        stock = {
            plastic = {price = 5, amount = 100}, -- price is how much you pay, amount is how much vendor has at start (false for unlimited)
            water_bottle = {price = 10, amount = false},
        },
    }

}
