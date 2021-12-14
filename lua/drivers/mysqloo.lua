require("mysqloo");
local shouldLog = CreateConVar("nebula_logmysql", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY});

function NebulaDriver:ConnectMySQL()
    if self.DB and self.DB:status() == mysqloo.DATABASE_CONNECTED then
        return;
    end

    self.DB = mysqloo.connect(NebulaDriver.Config.sql.address, NebulaDriver.Config.sql.user, NebulaDriver.Config.sql.password, NebulaDriver.Config.sql.database, NebulaDriver.Config.sql.port);
    self.DB.onConnected = function()
        MsgC(Color(0, 255, 0), "[Nebula] Connected to MySQL database.\n");
        hook.Run("DatabaseInitialized");
        hook.Run("DatabaseCreateTables", self.MySQLCreateTable);
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
        MsgN("\n[SQL] Query error:\n" .. sQuery)
    end

    oQuery:start()
end

function NebulaDriver:MySQLCreateTable(name, fields, primary)
    local fieldString = "";
    for k, v in pairs(fields) do
        fieldString = fieldString .. "`" .. k .. "` " .. v .. ", ";
    end
    //fieldString = fieldString:sub(1, #fieldString - 2);

    local target = "CREATE TABLE IF NOT EXISTS `" .. name .. "`(" .. fieldString .. "PRIMARY KEY(" .. primary .. "));"
    local query = self.DB:query(target);
    query:start()
end

function NebulaDriver:MySQLSelect(tbl, condition, callback)
    local queryStr = "SELECT * FROM " .. self.DB:escape(tbl) .. " WHERE " .. self.DB:escape(condition) .. ";"
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
        xVal = "'" .. xVal .. "'"
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
            fCallback( tData )
        end
    end )
end

NebulaDriver:ConnectMySQL();