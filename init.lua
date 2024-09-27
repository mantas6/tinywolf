-- Import necessary Lua libraries
local socket = require("socket")
local http = require("socket.http")

-- Configuration
local leases_file = "/var/lib/misc/dnsmasq.leases" -- Path to your dnsmasq leases file
local wol_port = 9 -- Default WOL port

-- Function to read the leases file and find the MAC address based on hostname
local function get_mac_from_hostname(hostname)
    local file = io.open(leases_file, "r")
    if not file then
        return nil, "Leases file not found"
    end

    for line in file:lines() do
        -- dnsmasq leases file format: <timestamp> <MAC> <IP> <hostname> <client-id>
        local _, mac, _, lease_hostname = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+")
        if lease_hostname == hostname then
            file:close()
            return mac
        end
    end

    file:close()
    return nil, "Hostname not found in leases"
end

-- Function to execute the wol command
local function wake_on_lan(mac)
    -- Remove colons from MAC address if present
    mac = mac:gsub(":", "")

    -- Create a magic packet
    local packet = "\xFF\xFF\xFF\xFF\xFF\xFF" -- 6 bytes of 0xFF
    for _ = 1, 16 do
        packet = packet .. mac:sub(1, 2):char(tonumber(mac:sub(1, 2), 16)) .. 
                         mac:sub(3, 4):char(tonumber(mac:sub(3, 4), 16)) ..
                         mac:sub(5, 6):char(tonumber(mac:sub(5, 6), 16)) ..
                         mac:sub(7, 8):char(tonumber(mac:sub(7, 8), 16)) ..
                         mac:sub(9, 10):char(tonumber(mac:sub(9, 10), 16)) ..
                         mac:sub(11, 12):char(tonumber(mac:sub(11, 12), 16))
    end

    -- Create a UDP socket
    local udp = socket.udp()
    udp:setpeername("255.255.255.255", wol_port) -- Broadcast to the WOL port
    udp:send(packet) -- Send the magic packet
    udp:close()
end

-- Function to handle HTTP requests
local function handle_request(client)
    local request = client:receive()

    -- Parse the GET request
    local method, path = request:match("^(%w+)%s+([^%s]+)")

    if method == "GET" and path:match("^/wol/") then
        -- Extract the hostname from the path
        local hostname = path:match("^/wol/(%S+)")

        if hostname then
            -- Find the MAC address from the leases file
            local mac, err = get_mac_from_hostname(hostname)
            if mac then
                -- Trigger the Wake-on-LAN
                wake_on_lan(mac)
                client:send("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nWOL packet sent to " .. mac .. "\n")
            else
                client:send("HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\nError: " .. err .. "\n")
            end
        else
            client:send("HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nInvalid hostname\n")
        end
    else
        client:send("HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\nInvalid request\n")
    end

    client:close()
end

-- Create and bind the server socket
local server = assert(socket.bind("0.0.0.0", 5001))
print("Server running on port 5001...")

-- Main loop to accept and handle client connections
while true do
    local client = server:accept()
    handle_request(client)
end
