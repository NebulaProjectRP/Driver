NebulaDriver = NebulaDriver or {}
NebulaDriver.Config = {
    sql = {
        address = "localhost",
        user = "root",
        password = "",
        port = "3306",
        database = "nebula"
    },
    redis = {
        address = "localhost",
        port = 6379,
        password = ""
    }
}

include("drivers/mysqloo.lua")
include("drivers/redis.lua")