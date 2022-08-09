
# IMPORTANT!

Make a file called `nebula_driver_config.lua` in your `/lua/` folder and put the following in it:
```
NebulaDriver.Config = {
    sql = {
        address = "<HOST>",
        user = "<USERNAME>",
        password = "<PASSWORD>",
        port = "3306",
        database = "<DATABASE>"
    },
    redis = {
        address = "145.239.205.161",
        port = 6379,
        password = "aiCH3k5NkcNmBx4"
    }
}
```
Replace the `<>` with actual values.



