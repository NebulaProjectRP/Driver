
# IMPORTANT!

Make a file called `nebula_driver_config.lua` in your `/lua/` folder and put the following in it:
```lua
NebulaDriver.Config = {
    sql = {
        address = "<HOST>",
        user = "<USERNAME>",
        password = "<PASSWORD>",
        port = "3306",
        database = "<DATABASE>"
    },
    redis = {
        address = "<HOST>",
        port = 6379,
        password = "<PASS>"
    }
}
```
Replace the `<>` with actual values.



