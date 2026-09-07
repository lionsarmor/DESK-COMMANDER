# RetroWire v1 — Draft Protocol Plan

RetroWire is the small authenticated transport shared by Desk Commander clients
on the Commander X16, ZX Spectrum Next, and Commodore 64 Ultimate.

## Hard limits

- Protocol version is explicit in every handshake.
- A decoded application frame is at most 192 bytes in V1.
- Text is printable ASCII in V1; platform clients translate locally.
- Lengths are explicit. Delimiter characters inside encrypted payloads are safe.
- Requests have bounded deadlines and idempotency identifiers.

## Planned session

1. Client opens a raw TCP connection to the RetroWire port.
2. Client sends `HELLO`, protocol version, device ID, and platform.
3. Server returns a cryptographically random challenge and session ID.
4. Client proves possession of its provisioned 256-bit device key.
5. Both sides derive a new session key from the challenge.
6. Subsequent frames use ChaCha20-Poly1305 with monotonically increasing
   per-session sequence numbers.
7. Either side closes the session on a repeated sequence number, invalid tag,
   oversized frame, idle timeout, or unsupported command.

The challenge makes every session unique without trusting a retro machine's
clock or random-number generator. Exact byte layouts remain provisional until
the cipher and UART framing are benchmarked on physical X16 hardware.

## V1 commands

- `PING`, `CAPS`, `SYNC`
- `PRESENCE_SET`, `PRESENCE_LIST`
- `FRIEND_ADD`, `FRIEND_REMOVE`, `FRIEND_LIST`
- `GROUP_CREATE`, `GROUP_LEAVE`, `GROUP_MEMBER_ADD`, `GROUP_LIST`
- `MESSAGE_SEND`, `MESSAGE_LIST`, `MESSAGE_ACK`

Mail and game commands will receive separate capability versions after chat is
stable. No passwords, device keys, or message bodies belong in URL query strings.

