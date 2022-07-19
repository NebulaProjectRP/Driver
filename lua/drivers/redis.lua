if (not file.Exists("lua/bin/gmsv_redis.core_linux.dll", "MOD")) then
	MsgN("[Redis] Redis core DLL not found!\n")
	return
end

require "redis.core"
local REDIS_CLIENT = FindMetaTable "redis_client"

local color_prefix, color_text = Color(225,0,0), Color(250,250,250)

redis_clients =	redis_clients or setmetatable({}, {__mode = "v"})
redis_clientCount = redis_clientCount or 0

function redis.GetClients()
	for i = 1, redis_clientCount do
		if (redis_clients[i] == nil) then
			table.remove(redis_clients, i)
			i = i - 1
			redis_clientCount = redis_clientCount - 1
		end
	end

	return redis_clients
end

function redis.ConnectClient(hostname, port, password, database, autopoll, autocommit)
	for k, v in ipairs(redis.GetSubscribers()) do
		if (v.Hostname == hostname) and (v.Port == port) and (v.Password == password) and (v.Database == database) and (v.AutoPoll == autopoll) and (v.AutoCommit == autocommit) then
			v:Log("Recycled connection.")
			return v
		end
	end

	local s, err = redis.CreateClient()

	if (not s) then
		error(err)
	end

	s.Hostname = hostname
	s.Port = port
	s.Password = password
	s.AutoPoll = autopoll
	s.AutoCommit = autocommit
	s.Database = database or 0
	s.PendingCommands = 0

	if (not s:TryConnect(hostname, port, password, database)) then
		return s
	end

	if (autopoll ~= false) or (autocommit ~= false) then
		hook.Add("Think", s, function()
			if (autocommit ~= false) and (s.PendingCommands > 0) then
				s:Commit()
			end
			if (autopoll ~= false) then
				s:Poll()
			end
		end)
	end

	table.insert(redis_clients, s)
	redis_clientCount = redis_clientCount + 1

	return s
end


-- Internal
function REDIS_CLIENT:OnDisconnected()
	if (not hook.Call("RedisClientDisconnected", nil, self)) then
		self:Log("Connection Lost.")
		local id = tostring(self)
		timer.Create("RedisClientRetryConnect" .. id, 1, 0, function()
			if (not IsValid(self)) or self:TryConnect(self.Hostname, self.Port, self.Password, self.Database) then
				timer.Remove("RedisClientRetryConnect" .. id)
			end
		end)
	end
end

function REDIS_CLIENT:Wait(func, ...)
	local dat
	func(self, ..., function(s, ...)
		dat = {...}
	end)

	self:Commit()

	self.IsWaiting = true
	local endwait = SysTime() + 1

	while self.IsWaiting and (endwait >= SysTime()) and (dat == nil) do
		self:Poll()
	end

	self:StopWait()

	return unpack(dat)
end

function REDIS_CLIENT:StopWait()
	self.IsWaiting = false
end

function REDIS_CLIENT:TryConnect(ip, port, password, database)
	local succ, err = self:Connect(ip, port)

	if (not succ) then
		self:Log(err)
		return false
	end

	if (password ~= nil) then
		local resp = self:Wait(self.Auth, password)
		if (resp ~= "OK") then
			self:Log(resp)
			return false
		end
	end

	if (database ~= nil) then
		local resp = self:Wait(self.Select, database)
		if (resp ~= "OK") then
			self:Log(resp)
			return false
		end
	end

	self:Log("Connected successfully.")

	hook.Call("RedisClientConnected", nil, self)

	return true
end

function REDIS_CLIENT:Log(message)
	MsgC(color_prefix, "[Redis-Client] ", color_text, "db" .. self.Database .. "@" .. self.Hostname .. ":" .. self.Port .. " => ", tostring(message) .. "\n")
end

local send = REDIS_CLIENT.Send
function REDIS_CLIENT:Send(tab, callback)
	self.PendingCommands = self.PendingCommands + 1
	return send(self, tab, callback)
end

local publish = REDIS_CLIENT.Publish
function REDIS_CLIENT:Publish(channel, value, callback)
	self.PendingCommands = self.PendingCommands + 1
	return publish(self, channel, value, callback)
end

local commit = REDIS_CLIENT.Commit
function REDIS_CLIENT:Commit()
	self.PendingCommands = 0
	return commit(self)
end


function REDIS_CLIENT:Auth(password, callback)
	return self:Send({"AUTH", password}, callback)
end

function REDIS_CLIENT:Select(database, callback)
	return self:Send({"SELECT", database}, callback)
end

function REDIS_CLIENT:State(callback)
	return self:Send({"CLUSTER", "INFO"}, callback)
end

function REDIS_CLIENT:Save(callback)
	return self:Send("BGSAVE", callback)
end

function REDIS_CLIENT:LastSave(callback)
	return self:Send("LASTSAVE", callback)
end

-- Strings: https://redis.io/commands#string
function REDIS_CLIENT:Append(key, value, callback)
	return self:Send({"APPEND", key, value}, callback)
end

function REDIS_CLIENT:BitCount(key, value, starti, endi, callback)
	return self:Send({"BITCOUNT", key, starti, endi}, callback)
end

function REDIS_CLIENT:Set(key, value, callback)
	return self:Send({"SET", key, value}, callback)
end

function REDIS_CLIENT:SetEx(key, secs, value, callback)
	return self:Send({"SETEX", key, secs, value}, callback)
end

function REDIS_CLIENT:Get(key, callback)
	return self:Send({"GET", key}, callback)
end

function REDIS_CLIENT:Exists(key, callback)
	return self:Send({"EXISTS", key}, callback)
end

function REDIS_CLIENT:Expire(key, secs, callback)
	return self:Send({"EXPIRE", key, secs}, callback)
end

function REDIS_CLIENT:TTL(key, callback)
	return self:Send({"TTL", key}, callback)
end

function REDIS_CLIENT:Delete(key, callback)
	return self:Send({"DEL", key}, callback)
end

function REDIS_CLIENT:Publish(channel, message, callback)
	return self:Send({"PUBLISH", channel, message}, callback)
end


-- Config
function REDIS_CLIENT:GetConfig(param, callback)
	return self:Send({"CONFIG", "GET", param}, callback)
end

function REDIS_CLIENT:SetConfig(param, value, callback)
	return self:Send({"CONFIG", "SET", param, value}, callback)
end


-- Lists: https://redis.io/commands#list
function REDIS_CLIENT:BLPop(key, keys, timeout, callback)
	return self:Send({"BLPOP", key, unpack(keys), timeout}, callback)
end

function REDIS_CLIENT:BRPop(key, keys, timeout, callback)
	return self:Send({"BRPOP", key, unpack(keys), timeout}, callback)
end

function REDIS_CLIENT:BRPopLPush(source, destination, callback)
	return self:Send({"BRPOP", source, destination}, callback)
end

function REDIS_CLIENT:LIndex(key, callback)
	return self:Send({"LINDEX", key}, callback)
end

function REDIS_CLIENT:LInsert(key, value, callback)
	return self:Send({"LINSERT", key, value}, callback)
end

function REDIS_CLIENT:LLen(key, callback)
	return self:Send({"LLEN", key}, callback)
end

function REDIS_CLIENT:LPop(key, callback)
	return self:Send({"LPOP", key}, callback)
end

function REDIS_CLIENT:LPush(key, values, callback)
	return self:Send({"LPUSH", key, isstring(values) and values or unpack(values)}, callback)
end

function REDIS_CLIENT:LPushX(key, value, callback)
	return self:Send({"LPUSHX", key, value}, callback)
end

function REDIS_CLIENT:LRange(key, start, stop, callback)
	return self:Send({"LRANGE", key, start, stop}, callback)
end

function REDIS_CLIENT:LRem(key, count, value, callback)
	return self:Send({"LREM", key, count, value}, callback)
end

function REDIS_CLIENT:LSet(key, index, value, callback)
	return self:Send({"LSET", key, index, value}, callback)
end

function REDIS_CLIENT:LTrim(key, start, stop, callback)
	return self:Send({"LSET", key, start, stop}, callback)
end

function REDIS_CLIENT:LPop(key, callback)
	return self:Send({"LPOP", key}, callback)
end

function REDIS_CLIENT:RPopLPush(source, destination, callback)
	return self:Send({"RPOPLPUSH", source, destination}, callback)
end

function REDIS_CLIENT:RPush(key, values, callback)
	return self:Send({"RPUSH", key, isstring(values) and values or unpack(values)}, callback)
end

function REDIS_CLIENT:RPushX(key, value, callback)
	return self:Send({"PRUSHX", key, value}, callback)
end

--https://redis.io/commands#hash
function REDIS_CLIENT:HMGet(key, values, callback)
	return self:Send({"HMGET", key, isstring(values) and values or unpack(values)}, callback)
end

local REDIS_SUBSCRIBER = FindMetaTable "redis_subscriber"

local subscribers =	setmetatable({}, {__mode = "v"})
local subscribercount = 0

function redis.GetSubscribers()
	for i = 1, subscribercount do
		if subscribers[i] == nil then
			table.remove(subscribers, i)
			i = i - 1
			subscribercount = subscribercount - 1
		end
	end

	return subscribers
end

function redis.ConnectSubscriber(hostname, port, autopoll, autocommit) -- no auth like redis_clients, iptables or localhost it I suppose.
	for k, v in ipairs(redis.GetSubscribers()) do
		if (v.Hostname == hostname) and (v.Port == port) and (v.AutoPoll == autopoll) and (v.AutoCommit == autocommit) then
			v:Log("Recycled connection.")
			return v
		end
	end

	local s, err = redis.CreateSubscriber()

	if (not s) then
		error(err)
	end

	s.Hostname = hostname
	s.Port = port
	s.AutoPoll = autopoll
	s.AutoCommit = autocommit
	s.PendingCommands = 0
	s.Subscriptions = {}
	s.PSubscriptions = {}

	if (not s:TryConnect(hostname, port)) then
		return s
	end

	if (autopoll ~= false) or (autocommit ~= false) then
		hook.Add("Think", s, function()
			if (autocommit ~= false) and (s.PendingCommands > 0) then
				s:Commit()
			end
			if (autopoll ~= false) then
				s:Poll()
			end
		end)
	end

	table.insert(subscribers, s)
	subscribercount = subscribercount + 1

	return s
end


-- Internal
function REDIS_SUBSCRIBER:OnMessage(channel, message) -- No point in doing our own hook system
	hook.Call("RedisSubscriberMessage", nil, self, channel, message)
end

function REDIS_SUBSCRIBER:OnDisconnected()
	if (not hook.Call("RedisSubscriberDisconnected", nil, self)) then
		self:Log("Connection Lost.")
		local id = tostring(self)
		timer.Create("RedisSubscriberRetryConnect" .. id, 1, 0, function()
			if (not IsValid(self)) or self:TryConnect(self.Hostname, self.Port) then
				timer.Remove("RedisSubscriberRetryConnect" .. id)
			end
		end)
	end
end

function REDIS_SUBSCRIBER:TryConnect(ip, port)
	local succ, err = self:Connect(ip, port)

	if (not succ) then
		self:Log(err)
		return false
	end

	self.PendingCommands = self.PendingCommands or 0

	self:Log("Connected successfully.")

	hook.Call("RedisSubscriberConnected", nil, self)

	for k, v in pairs(self.Subscriptions) do
		self:Subscribe(v.Channel, v.Callback, v.OnMessage)
	end

	for k, v in pairs(self.PSubscriptions) do
		self:PSubscribe(v.Channel, v.Callback, v.OnMessage)
	end

	return true
end

function REDIS_SUBSCRIBER:Log(message)
	MsgC(color_prefix, "[Redis-Subscriber] ", color_text, self.Hostname .. ":" .. self.Port .. " => ", tostring(message) .. "\n")
end

local commit_sub = REDIS_SUBSCRIBER.Commit
function REDIS_SUBSCRIBER:Commit()
	self.PendingCommands = 0
	return commit_sub(self)
end

local subscribe = REDIS_SUBSCRIBER.Subscribe
function REDIS_SUBSCRIBER:Subscribe(channel, callback, onmessage)
	if onmessage then
		hook.Add("RedisSubscriberMessage", channel, function(db, _channel, message)
			if (db == self) and (_channel == channel) then
				return onmessage(self, message)
			end
		end)
	end
	self.Subscriptions[channel] = {
		Channel = channel,
		Callback = callback,
		OnMessage = onmessage
	}
	self.PendingCommands = self.PendingCommands + 1
	return subscribe(self, channel, callback)
end

local unsubscribe = REDIS_SUBSCRIBER.Unsubscribe
function REDIS_SUBSCRIBER:Unsubscribe(channel, callback)
	hook.Remove("RedisSubscriberMessage", channel)
	self.Subscriptions[channel] = nil
	self.PendingCommands = self.PendingCommands + 1
	return unsubscribe(self, channel, callback)
end

local psubscribe = REDIS_SUBSCRIBER.PSubscribe
function REDIS_SUBSCRIBER:PSubscribe(channel, callback, onmessage)
	if onmessage then
		hook.Add("RedisPSubscriberMessage", channel, function(db, _channel, message)
			if (db == self) and (_channel == channel) then
				return onmessage(self, message)
			end
		end)
	end
	self.PSubscriptions[channel] = {
		Channel = channel,
		Callback = callback,
		OnMessage = onmessage
	}
	self.PendingCommands = self.PendingCommands + 1
	return psubscribe(self, channel, callback)
end

local punsubscribe = REDIS_SUBSCRIBER.PUnsubscribe
function REDIS_SUBSCRIBER:PUnsubscribe(channel, callback)
	hook.Remove("RedisPSubscriberMessage", channel)
	self.PSubscriptions[channel] = nil
	self.PendingCommands = self.PendingCommands + 1
	return punsubscribe(self, channel, callback)
end

NebulaDriver.Redis = NebulaDriver.Redis or redis.ConnectClient(NebulaDriver.Config.redis.address, NebulaDriver.Config.redis.port, NebulaDriver.Config.redis.user, NebulaDriver.Config.redis.pass, true, true)
