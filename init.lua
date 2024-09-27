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

-- Function to send Wake-on-LAN magic packet
local function send_wol(mac)
    -- Remove colons from MAC address if present
    mac = mac:gsub(":", "")

    -- Create a magic packet
    local packet = "\xFF\xFF\xFF\xFF\xFF\xFF" -- 6 bytes of 0xFF
    for _ = 1, 16 do
        packet = packet .. string.char(
            tonumber(mac:sub(1, 2), 16),
            tonumber(mac:sub(3, 4), 16),
            tonumber(mac:sub(5, 6), 16),
            tonumber(mac:sub(7, 8), 16),
            tonumber(mac:sub(9, 10), 16),
            tonumber(mac:sub(11, 12), 16)
        )
    end

    -- Create a UDP socket
    local udp = socket.udp()
    if not udp then
        print("Error creating UDP socket")
        return
    end

    -- Set socket options for broadcasting
    udp:setoption("broadcast", true)

    -- Send the magic packet
    local success, err = udp:sendto(packet, "255.255.255.255", wol_port) -- Use sendto for broadcasting
    if not success then
        print("Error sending WOL packet:", err)
    end

    udp:close() -- Close the socket
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
                send_wol(mac)
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
