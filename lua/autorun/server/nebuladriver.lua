NebulaDriver = NebulaDriver or {}
NebulaDriver.Config = {
    sql = {
        address = "127.0.0.1",
        user = "root",
        password = "",
        port = "3306",
        database = "nebularp"
    },
    redis = {
        address = "localhost",
        port = 6379,
        password = ""
    }
}

include("drivers/mysqloo.lua")
include("drivers/redis.lua")