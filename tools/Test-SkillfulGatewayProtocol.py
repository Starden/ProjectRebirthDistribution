"""Check public Skillful login reachability and WoW world protocol without logging in."""
import json
import socket
import struct
from datetime import datetime, timezone


def read_exact(connection, size):
    result = bytearray()
    while len(result) < size:
        chunk = connection.recv(size - len(result))
        if not chunk:
            raise RuntimeError("World connection closed before the complete challenge")
        result.extend(chunk)
    return bytes(result)


def main():
    with socket.create_connection(("134.122.124.150", 3725), timeout=8):
        pass
    with socket.create_connection(("134.122.124.150", 8085), timeout=8) as connection:
        header = read_exact(connection, 4)
        size = struct.unpack(">H", header[:2])[0]
        opcode = struct.unpack("<H", header[2:])[0]
        if not 6 <= size <= 128 or opcode != 0x1EC:
            raise RuntimeError("Unexpected initial WoW world packet")
        read_exact(connection, size - 2)
    print(json.dumps({"passed": True, "gateway": "134.122.124.150",
                      "authPort": 3725, "worldPort": 8085,
                      "worldChallengeVerified": True, "accountLoginTested": False,
                      "utc": datetime.now(timezone.utc).isoformat()}))


if __name__ == "__main__":
    main()
