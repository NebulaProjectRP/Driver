require("mysqloo");
local shouldLog = CreateConVar("nebula_logmysql", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY});

function NebulaDriver:ConnectMySQL(force)
    if not force and self.DB and self.DB:status() == mysqloo.DATABASE_CONNECTED then
        return;
    end

    self.DB = mysqloo.connect(NebulaDriver.Config.sql.address, NebulaDriver.Config.sql.user, NebulaDriver.Config.sql.password, NebulaDriver.Config.sql.database, NebulaDriver.Config.sql.port);
    self.DB.onConnected = function()
        MsgC(Color(0, 255, 0), "[Nebula] Connected to MySQL database.\n");
        timer.Simple(.1, function()
            hook.Run("DatabaseInitialized");
            hook.Run("DatabaseCreateTables", self.MySQLCreateTable);
        end)
        
    end

    self.DB.onConnectionFailed = function(db, err, sql)
        MsgC(Color(255, 0, 0), "[Nebula] MySQL Couldn't connect\nError: " .. err .. "\n");
    end

    self.DB:connect()
end

function NebulaDriver:MySQLQuery( sQuery, fSuccess, fFail )
    local oQuery = self.DB:query( sQuery )

    function oQuery:onSuccess( xData )
        if fSuccess and xData then
            fSuccess( xData )
        end
    end

    function oQuery:onError( sError )
        if (shouldLog:GetBool()) then
            MsgN(string.rep("-", 16));
            debug.Trace()
            MsgN(string.rep("-", 16));
        end
        MsgN("\n[SQL] Query error:\n" .. sQuery .. "\n" .. sError .. "\n");
    end

    oQuery:start()
end

function NebulaDriver:MySQLDelete(table, where, cb)
    if (not where or where == "") then
        return
    end

    local query = "DELETE FROM " .. table .. " WHERE " .. where;
    self:MySQLQuery(query, cb);
end

function NebulaDriver:MySQLCreateTable(name, fields, primary)
    local fieldString = "";
    for k, v in pairs(fields) do
        fieldString = fieldString .. "`" .. k .. "` " .. v .. ", ";
    end
    //fieldString = fieldString:sub(1, #fieldString - 2);

    local target = "CREATE TABLE IF NOT EXISTS `" .. name .. "`(" .. fieldString .. "PRIMARY KEY(" .. primary .. "));"
    local query = self.DB:query(target);
    query.onSuccess = function()
        if (callback) then
            callback();
        end
    end
    query:start()
end

function NebulaDriver:MySQLSelect(tbl, condition, callback)
local queryStr = "SELECT * FROM " .. self.DB:escape(tbl) .. (condition and " WHERE " .. self.DB:escape(condition) .. ";" or "")
    local query = self.DB:query(queryStr);
    query.onSuccess = function(db, data)
        if data and callback then
            callback(data);
        end
    end
    query.onError = function(db, err, sql)
        if (shouldLog:GetBool()) then
            MsgN(string.rep("-", 16));
            debug.Trace()
            MsgN(string.rep("-", 16));
        end
        MsgC(Color(255, 0, 0), "[Nebula] MySQL Couldn't select\nError: " .. err .. "\n");
        MsgN("\n[SQL] Query error:\n" .. queryStr)
    end
    query:start()
end

local function valToSQL( xVal )
    if isstring( xVal ) and not string.EndsWith( xVal, "()" ) then
        xVal = "'" .. string.Replace( xVal, "'", "" ) .. "'"
        return xVal
    end

    if isbool( xVal ) then
        return xVal and 1 or 0
    end

    if isvector( xVal ) then
        return tostring(xVal)
    end
    
    return xVal
end

function NebulaDriver:MySQLInsert( sTable, tInsert, fCallback )
    local sFields = ""
    local sValues = ""
    local iIter = 0
    local iKeyCount = table.Count( tInsert )

    for sKey, xVal in pairs( tInsert ) do
        iIter = ( iIter + 1 )

        sFields = sFields .. sKey
        sValues = sValues .. valToSQL( xVal )

        if ( iIter ~= iKeyCount ) then
            sFields = sFields .. ", "
            sValues = sValues .. ", "
        end
    end

    local sRequest = ( "INSERT INTO " .. sTable .. " (" .. sFields .. ") VALUES (" .. sValues .. ")" )
    self:MySQLQuery( sRequest, function( tData )
        if fCallback then
            fCallback( tData )
        end
    end )
end

function NebulaDriver:MySQLUpdate( sTable, tUpdateTable, sCondition, fCallback )
    local sSet = ""

    local iIter = 0
    local iKeyCount = table.Count( tUpdateTable )

    for sKey, xVal in pairs( tUpdateTable ) do
        iIter = ( iIter + 1 )

        sSet = ( sSet .. sKey .. " = " .. valToSQL( xVal ) )

        if ( iIter ~= iKeyCount ) then
            sSet = sSet .. ", "
        end
    end

    local sRequest = ( "UPDATE " .. sTable .. " SET " .. sSet .. " WHERE " .. sCondition )
    self:MySQLQuery( sRequest, function( tData )
        if fCallback then
            fCallback( tData, sRequest )
        end
    end )
end

function NebulaDriver:MySQLPlayer(ply)
    local dataTable = {}
    local remaining = table.Count(self.Joins or {})
    for tbl, call in pairs(self.Joins or {}) do
        self:MySQLQuery("SELECT * FROM " .. tbl .. " WHERE steamid=" .. ply:SteamID64(), function(data)
            self.Joins[tbl](ply, data and data[1] or nil)
        end)
    end
end

function NebulaDriver:MySQLHook(id, callback)
    if not self.Joins then
        self.Joins = {}
    end
    MsgC(Color(255, 200, 50), "[MYSQL]", color_white, "Added driver with ID " .. id, "\n")
    self.Joins[id] = callback
end

hook.Add("PlayerInitialSpawn", "NebulaRP.LoaderDriver", function(ply)
    NebulaDriver:MySQLPlayer(ply)
end)

NebulaDriver:ConnectMySQL();
